begin;

-- Signed distance to the boundary: positive inside. Circles use a spherical
-- distance; polygon/corridor edges use a local metric projection. A 20 m neutral
-- band prevents boundary jitter from creating visits (not survey geometry).
create function public.logistics_geofence_margin(p_lat double precision,p_lng double precision,
  p_shape smallint,p_width double precision,p_points jsonb) returns double precision
language plpgsql immutable strict set search_path='' as $$
declare a jsonb; b jsonb; n integer; i integer; ax double precision; ay double precision;
  bx double precision; by_ double precision; dx double precision; dy double precision;
  t double precision; d double precision; nearest double precision := 'Infinity';
  inside boolean := false; earth constant double precision := 6371008.8;
begin
  n:=jsonb_array_length(p_points);
  if p_shape=3 then
    a:=p_points->0;
    d:=2*earth*asin(sqrt(least(1.0,
      power(sin(radians((a->>'lat')::double precision-p_lat)/2),2)+
      cos(radians(p_lat))*cos(radians((a->>'lat')::double precision))*
      power(sin(radians((a->>'lng')::double precision-p_lng)/2),2))));
    return p_width-d;
  end if;
  for i in 0..(case when p_shape=2 then n-1 else n-2 end) loop
    a:=p_points->i; b:=p_points->((i+1)%n);
    ax:=earth*cos(radians(p_lat))*atan2(sin(radians((a->>'lng')::double precision-p_lng)),cos(radians((a->>'lng')::double precision-p_lng)));
    bx:=earth*cos(radians(p_lat))*atan2(sin(radians((b->>'lng')::double precision-p_lng)),cos(radians((b->>'lng')::double precision-p_lng)));
    ay:=earth*radians((a->>'lat')::double precision-p_lat);
    by_:=earth*radians((b->>'lat')::double precision-p_lat);
    dx:=bx-ax; dy:=by_-ay;
    t:=case when dx*dx+dy*dy=0 then 0 else greatest(0,least(1,-(ax*dx+ay*dy)/(dx*dx+dy*dy))) end;
    nearest:=least(nearest,sqrt(power(ax+t*dx,2)+power(ay+t*dy,2)));
    if (ay>0)<>(by_>0) then
      if 0 < ax+(bx-ax)*(-ay)/(by_-ay) then inside:=not inside; end if;
    end if;
  end loop;
  if p_shape=1 then return p_width/2-nearest; end if;
  return case when inside then nearest else -nearest end;
end; $$;

create table public.logistics_gps_visit_monitor (
  singleton boolean primary key default true check(singleton),
  enabled_at timestamptz not null default now(),
  last_run_at timestamptz,
  status text not null default 'pending' check(status in ('pending','ok','paused','error')),
  reason text
);
insert into public.logistics_gps_visit_monitor(singleton) values(true);

-- Names and links are snapshots: later catalog changes do not rewrite history.
create table public.logistics_gps_visits (
  id uuid primary key default gen_random_uuid(),
  provider_unit_id text not null, vehicle_id uuid not null, unit_label text not null,
  resource_id text not null, geofence_id text not null,
  geofence_name text not null, site_id uuid, place_label text not null,
  classification text not null check(classification in ('company','base')),
  started_at timestamptz not null, last_inside_at timestamptz not null,
  ended_at timestamptz,
  arrival_kind text not null check(arrival_kind in ('arrival','first_seen')),
  status text not null default 'open' check(status in ('open','closed','interrupted')),
  has_gap boolean not null default false,
  interruption_reason text,
  recorded_at timestamptz not null default now(),
  check(last_inside_at>=started_at),
  check((status='closed' and ended_at>=last_inside_at) or (status<>'closed' and ended_at is null))
);
create unique index logistics_gps_visits_one_open on public.logistics_gps_visits(provider_unit_id,resource_id,geofence_id) where status='open';
create index logistics_gps_visits_recent on public.logistics_gps_visits(started_at desc,unit_label,id);

create table public.logistics_gps_presence (
  provider_unit_id text not null, resource_id text not null, geofence_id text not null,
  vehicle_id uuid not null, definition_hash text not null,
  mode text not null default 'unknown' check(mode in ('unknown','inside','outside')),
  last_position_at timestamptz,
  candidate_mode text check(candidate_mode in ('inside','outside')),
  candidate_at timestamptz,
  active_visit_id uuid references public.logistics_gps_visits(id),
  continuity_lost boolean not null default false,
  primary key(provider_unit_id,resource_id,geofence_id)
);

alter table public.logistics_gps_visits enable row level security;
alter table public.logistics_gps_presence enable row level security;
alter table public.logistics_gps_visit_monitor enable row level security;
revoke all on public.logistics_gps_visits,public.logistics_gps_presence,public.logistics_gps_visit_monitor from anon,authenticated;
grant select on public.logistics_gps_visits,public.logistics_gps_presence,public.logistics_gps_visit_monitor to authenticated;
grant all on public.logistics_gps_visits,public.logistics_gps_presence,public.logistics_gps_visit_monitor to service_role;
create policy logistics_visits_read on public.logistics_gps_visits for select to authenticated using ((select public.can_view_logistics_gps()));
create policy logistics_presence_read on public.logistics_gps_presence for select to authenticated using ((select public.can_view_logistics_gps()));
create policy logistics_visit_monitor_read on public.logistics_gps_visit_monitor for select to authenticated using ((select public.can_view_logistics_gps()));

-- Runs independently of GPS ingestion. No changes to services/Control Diario.
create function public.process_logistics_gps_visits(p_now timestamptz default now()) returns integer
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
        or r.position_at<p_now-interval '5 minutes' or r.position_at>p_now then
        update public.logistics_gps_presence set candidate_at=null,candidate_mode=null,continuity_lost=true
          where provider_unit_id=r.provider_unit_id and resource_id=r.resource_id and geofence_id=r.geofence_id;
        update public.logistics_gps_visits set has_gap=true where id=s.active_visit_id;
        continue;
      end if;
      -- Repeated polling of the same GPS fix is not a second confirmation.
      if s.last_position_at is not null and r.position_at<=s.last_position_at then continue; end if;
      if s.continuity_lost or (s.last_position_at is not null and r.position_at-s.last_position_at>interval '5 minutes') then
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
      elsif r.position_at-s.candidate_at>=interval '60 seconds' then
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
revoke all on function public.process_logistics_gps_visits(timestamptz) from public,anon,authenticated;
grant execute on function public.process_logistics_gps_visits(timestamptz) to service_role;
commit;
