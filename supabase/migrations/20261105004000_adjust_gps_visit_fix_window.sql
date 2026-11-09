begin;
-- Stationary trackers can send a new position approximately every ten minutes.
-- Allow two distinct recent fixes in that interval; duplicate timestamps still
-- never confirm an event, and loss of signal never creates a departure.
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
commit;
