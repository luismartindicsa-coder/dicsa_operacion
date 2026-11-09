begin;

-- Preserve historical events and identify the confirmation rule used for each.
alter table public.logistics_gps_visits add column minimum_dwell_seconds integer not null default 60
  check(minimum_dwell_seconds in (60,300));
alter table public.logistics_gps_visits alter column minimum_dwell_seconds set default 300;
update public.logistics_gps_presence set candidate_at=null,candidate_mode=null;
alter table public.logistics_gps_units add column speed_kph double precision
  check(speed_kph is null or (position_at is not null and speed_kph between 0 and 1000));

create or replace function public.complete_logistics_gps_sync(
  p_run_id uuid, p_units jsonb, p_error text default null, p_token_expires_at timestamptz default null
) returns boolean language plpgsql security definer set search_path = '' as $$
declare started timestamptz;
begin
  select last_attempt_at into started from public.logistics_gps_sync_state
    where singleton and run_id = p_run_id for update;
  if not found then return false; end if;
  if p_error is not null then
    if p_error not in ('not_configured','authorization','provider_unavailable','invalid_response','storage') then
      raise exception 'Invalid GPS error code';
    end if;
    update public.logistics_gps_sync_state set status='error', error_code=p_error,
      token_expires_at=p_token_expires_at, run_id=null, lease_until=null where singleton;
    return true;
  end if;
  if p_units is null or jsonb_typeof(p_units) <> 'array' then raise exception 'Invalid GPS snapshot'; end if;
  if jsonb_array_length(p_units) > 10000 then raise exception 'GPS snapshot too large'; end if;
  if exists (
    select 1 from jsonb_array_elements(p_units) x
    where jsonb_typeof(x) <> 'object' or coalesce(x->>'provider_unit_id','') !~ '^[0-9]+$'
      or nullif(btrim(x->>'provider_name'), '') is null
  ) then raise exception 'Invalid GPS unit'; end if;
  if (select count(*) <> count(distinct x->>'provider_unit_id') from jsonb_array_elements(p_units) x) then
    raise exception 'Duplicate GPS unit';
  end if;
  insert into public.logistics_gps_units(provider_unit_id, provider_name, latitude, longitude, position_at, observed_at, provider_visible, speed_kph)
    select x.provider_unit_id, x.provider_name, x.latitude, x.longitude, x.position_at, started, true, case when x.position_at is not null then x.speed_kph end
    from jsonb_to_recordset(p_units) as x(provider_unit_id text, provider_name text, latitude double precision,
      longitude double precision, position_at timestamptz, speed_kph double precision)
    on conflict(provider_unit_id) do update set provider_name=excluded.provider_name,
      latitude=excluded.latitude, longitude=excluded.longitude, position_at=excluded.position_at,
      observed_at=excluded.observed_at, provider_visible=true, speed_kph=excluded.speed_kph;
  -- Missing/private positions and revoked unit access must not expose an old location.
  update public.logistics_gps_units set provider_visible=false, latitude=null, longitude=null, position_at=null, speed_kph=null
    where provider_unit_id not in (select x->>'provider_unit_id' from jsonb_array_elements(p_units) x);
  update public.logistics_gps_sync_state set status='ok', last_success_at=started, error_code=null,
    token_expires_at=p_token_expires_at, run_id=null, lease_until=null where singleton;
  return true;
end;
$$;

create or replace function public.process_logistics_gps_visits(p_now timestamptz default now()) returns integer
language plpgsql security definer set search_path='' as $$
declare enabled timestamptz; r record; s public.logistics_gps_presence%rowtype;
  margin double precision; sample text; new_visit uuid; processed integer:=0; paused boolean;
begin
  select enabled_at into enabled from public.logistics_gps_visit_monitor where singleton for update skip locked;
  if not found then return 0; end if;
  begin
    -- Invalidate occupancy on a changed link, geometry, visibility or vehicle.
    -- Interruption has no invented departure time; historical labels stay intact.
    for s in select * from public.logistics_gps_presence loop
      if not exists(select 1 from public.logistics_geofences g
        join public.logistics_gps_units u on u.provider_unit_id=s.provider_unit_id
        join public.vehicles v on v.id=u.vehicle_id
        left join public.sites c on c.id=g.site_id
        where g.resource_id=s.resource_id and g.geofence_id=s.geofence_id
          and g.provider_visible and u.provider_visible and u.vehicle_id=s.vehicle_id
          and (g.classification='base' or (g.classification='company' and c.is_active and c.type='cliente'))
          and md5(jsonb_build_array(g.shape_type,g.width_m,g.points,g.provider_created_at,g.site_id,g.classification)::text)=s.definition_hash) then
        update public.logistics_gps_visits set status='interrupted',has_gap=true,
          interruption_reason='definition_or_access_changed' where id=s.active_visit_id and status='open';
        delete from public.logistics_gps_presence where provider_unit_id=s.provider_unit_id and resource_id=s.resource_id and geofence_id=s.geofence_id;
      end if;
    end loop;
    paused:=not exists(select 1 from public.logistics_gps_sync_state where status='ok' and last_success_at>=p_now-interval '3 minutes')
      or not exists(select 1 from public.logistics_geofence_sync_state where status='ok' and last_success_at>=p_now-interval '25 minutes');
    if paused then
      update public.logistics_gps_presence set candidate_at=null,candidate_mode=null,continuity_lost=true;
      update public.logistics_gps_visits set has_gap=true where status='open';
      update public.logistics_gps_visit_monitor set last_run_at=p_now,status='paused',reason='source_unavailable' where singleton;
      return 0;
    end if;
    for r in select u.provider_unit_id,u.vehicle_id,u.latitude,u.longitude,u.position_at,v.code unit_label,
      g.resource_id,g.geofence_id,g.provider_name,g.site_id,g.classification,g.shape_type,g.width_m,g.points,
      case when g.classification='base' then g.provider_name else c.name end place_label,
      md5(jsonb_build_array(g.shape_type,g.width_m,g.points,g.provider_created_at,g.site_id,g.classification)::text) signature
      from public.logistics_gps_units u join public.vehicles v on v.id=u.vehicle_id
      cross join public.logistics_geofences g left join public.sites c on c.id=g.site_id
      where u.provider_visible and g.provider_visible
        and (g.classification='base' or (g.classification='company' and c.is_active and c.type='cliente')) loop
      insert into public.logistics_gps_presence(provider_unit_id,resource_id,geofence_id,vehicle_id,definition_hash)
        values(r.provider_unit_id,r.resource_id,r.geofence_id,r.vehicle_id,r.signature) on conflict do nothing;
      select * into s from public.logistics_gps_presence where provider_unit_id=r.provider_unit_id and resource_id=r.resource_id and geofence_id=r.geofence_id;
      if r.position_at is null or r.latitude is null or r.longitude is null or r.position_at<enabled
        or r.position_at<p_now-interval '15 minutes' or r.position_at>p_now then
        update public.logistics_gps_presence set candidate_at=null,candidate_mode=null,continuity_lost=true
          where provider_unit_id=r.provider_unit_id and resource_id=r.resource_id and geofence_id=r.geofence_id;
        update public.logistics_gps_visits set has_gap=true where id=s.active_visit_id;
        continue;
      end if;
      -- Repeated polling of the same GPS fix is not a second confirmation.
      if s.last_position_at is not null and r.position_at<=s.last_position_at then continue; end if;
      if s.continuity_lost or (s.last_position_at is not null and r.position_at-s.last_position_at>interval '15 minutes') then
        s.candidate_at:=null; s.candidate_mode:=null;
        if s.mode<>'inside' then s.mode:='unknown'; end if;
        update public.logistics_gps_visits set has_gap=true where id=s.active_visit_id;
      end if;
      margin:=public.logistics_geofence_margin(r.latitude,r.longitude,r.shape_type,r.width_m,r.points);
      sample:=case when margin>=20 then 'inside' when margin<=-20 then 'outside' else null end;
      if s.active_visit_id is not null and margin>=0 then
        update public.logistics_gps_visits set last_inside_at=r.position_at where id=s.active_visit_id;
      end if;
      if sample is null or sample=s.mode then
        s.candidate_at:=null; s.candidate_mode:=null;
      elsif s.candidate_mode is distinct from sample then
        s.candidate_at:=r.position_at; s.candidate_mode:=sample;
      elsif r.position_at-s.candidate_at >= (case when sample='inside' then interval '5 minutes' else interval '60 seconds' end) then
        if sample='inside' then
          insert into public.logistics_gps_visits(provider_unit_id,vehicle_id,unit_label,resource_id,geofence_id,
            geofence_name,site_id,place_label,classification,started_at,last_inside_at,arrival_kind)
            values(r.provider_unit_id,r.vehicle_id,r.unit_label,r.resource_id,r.geofence_id,r.provider_name,
              r.site_id,r.place_label,r.classification,s.candidate_at,r.position_at,
              case when s.mode='outside' then 'arrival' else 'first_seen' end) returning id into new_visit;
          s.active_visit_id:=new_visit;
        elsif s.active_visit_id is not null then
          update public.logistics_gps_visits set status='closed',ended_at=s.candidate_at where id=s.active_visit_id;
          s.active_visit_id:=null;
        end if;
        s.mode:=sample; s.candidate_at:=null; s.candidate_mode:=null;
      end if;
      update public.logistics_gps_presence set mode=s.mode,last_position_at=r.position_at,candidate_mode=s.candidate_mode,
        candidate_at=s.candidate_at,active_visit_id=s.active_visit_id,continuity_lost=false
        where provider_unit_id=r.provider_unit_id and resource_id=r.resource_id and geofence_id=r.geofence_id;
      processed:=processed+1;
    end loop;
    update public.logistics_gps_visit_monitor set last_run_at=p_now,status='ok',reason=null where singleton;
  exception when others then
    -- All partial detections roll back together; GPS ingestion remains independent.
    update public.logistics_gps_visit_monitor set last_run_at=p_now,status='error',reason='processing_failed' where singleton;
    return -1;
  end;
  return processed;
end; $$;

create table public.logistics_gps_stops (
  id uuid primary key default gen_random_uuid(),
  provider_unit_id text not null, vehicle_id uuid not null, unit_label text not null,
  latitude double precision not null check(latitude between -90 and 90),
  longitude double precision not null check(longitude between -180 and 180),
  started_at timestamptz not null, last_stationary_at timestamptz not null, ended_at timestamptz,
  status text not null default 'open' check(status in ('open','closed','interrupted')),
  end_reason text, review_note text check(char_length(review_note)<=1000),
  reviewed_at timestamptz, reviewed_by uuid references auth.users(id) on delete set null,
  review_version bigint not null default 0, recorded_at timestamptz not null default now(),
  check(last_stationary_at>=started_at+interval '5 minutes'),
  check((status='closed' and ended_at>=last_stationary_at) or (status<>'closed' and ended_at is null))
);
create unique index logistics_gps_stops_one_open on public.logistics_gps_stops(provider_unit_id) where status='open';
create index logistics_gps_stops_recent on public.logistics_gps_stops(started_at desc,unit_label,id);
create table public.logistics_gps_stop_state (
  provider_unit_id text primary key, vehicle_id uuid not null,
  definition_hash text not null, last_position_at timestamptz,
  anchor_latitude double precision, anchor_longitude double precision,
  candidate_at timestamptz, last_stationary_at timestamptz,
  active_stop_id uuid references public.logistics_gps_stops(id)
);
create table public.logistics_gps_stop_monitor (
  singleton boolean primary key default true check(singleton),
  enabled_at timestamptz not null default now(), last_run_at timestamptz,
  status text not null default 'pending' check(status in ('pending','ok','paused','error')), reason text
);
insert into public.logistics_gps_stop_monitor(singleton) values(true);
alter table public.logistics_gps_stops enable row level security;
alter table public.logistics_gps_stop_state enable row level security;
alter table public.logistics_gps_stop_monitor enable row level security;
revoke all on public.logistics_gps_stops,public.logistics_gps_stop_state,public.logistics_gps_stop_monitor from public,anon,authenticated;
grant select on public.logistics_gps_stops,public.logistics_gps_stop_monitor to authenticated;
grant all on public.logistics_gps_stops,public.logistics_gps_stop_state,public.logistics_gps_stop_monitor to service_role;
create policy logistics_stops_read on public.logistics_gps_stops for select to authenticated using ((select public.can_view_logistics_gps()));
create policy logistics_stop_monitor_read on public.logistics_gps_stop_monitor for select to authenticated using ((select public.can_view_logistics_gps()));

-- Notes are a human explanation, separate from immutable GPS observations.
create function public.review_logistics_gps_stop(p_id uuid,p_note text,p_expected_version bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare version bigint;
begin
  if not public.can_view_logistics_gps() then raise insufficient_privilege; end if;
  if p_note is null or nullif(btrim(p_note),'') is null or char_length(p_note)>1000 then
    raise exception 'Escribe un motivo o nota de hasta 1000 caracteres.';
  end if;
  update public.logistics_gps_stops set review_note=btrim(p_note),reviewed_at=now(),reviewed_by=auth.uid(),review_version=review_version+1
    where id=p_id and review_version=p_expected_version returning review_version into version;
  if not found then raise exception using errcode='40001',message='La revisión cambió. Cierra y vuelve a abrir la parada.'; end if;
  return version;
end; $$;
revoke all on function public.review_logistics_gps_stop(uuid,text,bigint) from public,anon;
grant execute on function public.review_logistics_gps_stop(uuid,text,bigint) to authenticated;

-- Distinct fixes spanning five minutes, speed <=3 km/h, within 50 m of the
-- original anchor. All visible EPCOM fences count, including unlinked ones.
create function public.process_logistics_gps_stops(p_now timestamptz default now()) returns integer
language plpgsql security definer set search_path='' as $$
declare enabled timestamptz; r record; s public.logistics_gps_stop_state%rowtype;
  signature text; outside_fences boolean; stationary boolean; near_anchor boolean;
  new_stop uuid; processed integer:=0;
begin
  select enabled_at into enabled from public.logistics_gps_stop_monitor where singleton for update skip locked;
  if not found then return 0; end if;
  begin
    for s in select * from public.logistics_gps_stop_state loop
      if not exists(select 1 from public.logistics_gps_units u join public.vehicles v on v.id=u.vehicle_id
        where u.provider_unit_id=s.provider_unit_id and u.provider_visible and u.vehicle_id=s.vehicle_id) then
        update public.logistics_gps_stops set status='interrupted',end_reason='unit_unavailable' where id=s.active_stop_id and status='open';
        delete from public.logistics_gps_stop_state where provider_unit_id=s.provider_unit_id;
      end if;
    end loop;
    if not exists(select 1 from public.logistics_gps_sync_state where status='ok' and last_success_at>=p_now-interval '3 minutes')
      or not exists(select 1 from public.logistics_geofence_sync_state where status='ok' and last_success_at>=p_now-interval '25 minutes') then
      update public.logistics_gps_stops set status='interrupted',end_reason='source_unavailable' where status='open';
      delete from public.logistics_gps_stop_state;
      update public.logistics_gps_stop_monitor set last_run_at=p_now,status='paused',reason='source_unavailable' where singleton;
      return 0;
    end if;
    select md5(coalesce(jsonb_agg(jsonb_build_array(resource_id,geofence_id,shape_type,width_m,points,provider_created_at)
      order by resource_id,geofence_id)::text,'[]')) into signature from public.logistics_geofences where provider_visible;
    for r in select u.*,v.code unit_label from public.logistics_gps_units u join public.vehicles v on v.id=u.vehicle_id where u.provider_visible loop
      insert into public.logistics_gps_stop_state(provider_unit_id,vehicle_id,definition_hash)
        values(r.provider_unit_id,r.vehicle_id,signature) on conflict do nothing;
      select * into s from public.logistics_gps_stop_state where provider_unit_id=r.provider_unit_id;
      if s.definition_hash<>signature then
        update public.logistics_gps_stops set status='interrupted',end_reason='geofences_changed' where id=s.active_stop_id and status='open';
        s.active_stop_id:=null; s.candidate_at:=null; s.definition_hash:=signature;
      end if;
      if r.position_at is null or r.latitude is null or r.longitude is null or r.position_at<enabled
        or r.position_at<p_now-interval '15 minutes' or r.position_at>p_now then
        update public.logistics_gps_stops set status='interrupted',end_reason='position_unavailable' where id=s.active_stop_id and status='open';
        update public.logistics_gps_stop_state set candidate_at=null,active_stop_id=null,definition_hash=signature where provider_unit_id=r.provider_unit_id;
        continue;
      end if;
      if s.last_position_at is not null and r.position_at<=s.last_position_at then
        -- A geometry change still invalidates state on a repeated GPS fix.
        update public.logistics_gps_stop_state set candidate_at=s.candidate_at,active_stop_id=s.active_stop_id,definition_hash=signature where provider_unit_id=r.provider_unit_id;
        continue;
      end if;
      if s.last_position_at is not null and r.position_at-s.last_position_at>interval '15 minutes' then
        update public.logistics_gps_stops set status='interrupted',end_reason='signal_gap' where id=s.active_stop_id and status='open';
        s.active_stop_id:=null; s.candidate_at:=null;
      end if;
      outside_fences:=not exists(select 1 from public.logistics_geofences g where g.provider_visible
        and public.logistics_geofence_margin(r.latitude,r.longitude,g.shape_type,g.width_m,g.points)>=-20);
      stationary:=r.speed_kph is not null and r.speed_kph<=3;
      near_anchor:=s.candidate_at is not null and public.logistics_geofence_margin(r.latitude,r.longitude,3::smallint,50,
        jsonb_build_array(jsonb_build_object('lat',s.anchor_latitude,'lng',s.anchor_longitude)))>=0;
      if not outside_fences or not stationary or not near_anchor then
        if s.active_stop_id is not null then
          update public.logistics_gps_stops set
            status=case when r.speed_kph is null and outside_fences then 'interrupted' else 'closed' end,
            ended_at=case when r.speed_kph is null and outside_fences then null else r.position_at end,
            end_reason=case when not outside_fences then 'geofence_entered' when r.speed_kph is null then 'speed_unavailable' else 'movement' end
            where id=s.active_stop_id and status='open';
        end if;
        s.active_stop_id:=null; s.candidate_at:=null;
      end if;
      if outside_fences and stationary then
        if s.candidate_at is null then
          s.candidate_at:=r.position_at; s.anchor_latitude:=r.latitude; s.anchor_longitude:=r.longitude;
        end if;
        s.last_stationary_at:=r.position_at;
        if s.active_stop_id is not null then
          update public.logistics_gps_stops set last_stationary_at=r.position_at where id=s.active_stop_id;
        elsif r.position_at-s.candidate_at>=interval '5 minutes' then
          insert into public.logistics_gps_stops(provider_unit_id,vehicle_id,unit_label,latitude,longitude,started_at,last_stationary_at)
            values(r.provider_unit_id,r.vehicle_id,r.unit_label,s.anchor_latitude,s.anchor_longitude,s.candidate_at,r.position_at) returning id into new_stop;
          s.active_stop_id:=new_stop;
        end if;
      end if;
      update public.logistics_gps_stop_state set definition_hash=signature,last_position_at=r.position_at,
        anchor_latitude=s.anchor_latitude,anchor_longitude=s.anchor_longitude,candidate_at=s.candidate_at,
        last_stationary_at=s.last_stationary_at,active_stop_id=s.active_stop_id where provider_unit_id=r.provider_unit_id;
      processed:=processed+1;
    end loop;
    update public.logistics_gps_stop_monitor set last_run_at=p_now,status='ok',reason=null where singleton;
  exception when others then
    update public.logistics_gps_stop_monitor set last_run_at=p_now,status='error',reason='processing_failed' where singleton;
    return -1;
  end;
  return processed;
end; $$;
revoke all on function public.process_logistics_gps_stops(timestamptz) from public,anon,authenticated;
grant execute on function public.process_logistics_gps_stops(timestamptz) to service_role;
notify pgrst,'reload schema';
commit;

