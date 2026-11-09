begin;
-- Require at least two position-bearing messages before accepting zero distance.
create or replace function public.complete_logistics_gps_mileage(p_run_id uuid,p_kilometers double precision default null,
  p_trip_count integer default null,p_message_count integer default null,p_error text default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare job public.logistics_gps_daily_mileage%rowtype;
begin
  select * into job from public.logistics_gps_daily_mileage where run_id=p_run_id for update;
  if not found then return false; end if;
  if p_error is not null then
    if p_error not in ('authorization','not_configured','provider_unavailable','invalid_response','storage') then
      raise exception 'Invalid mileage error';
    end if;
    update public.logistics_gps_daily_mileage set status='error',error_code=p_error,
      retry_at=now()+interval '1 hour',run_id=null,lease_until=null
      where provider_unit_id=job.provider_unit_id and entry_date=job.entry_date;
    return true;
  end if;
  if p_message_count is null or p_message_count<0 or p_trip_count is null or p_trip_count<0
    or (p_message_count<2 and (p_kilometers is not null or p_trip_count<>0))
    or (p_message_count>=2 and (p_kilometers is null or not(p_kilometers between 0 and 5000))) then
    raise exception 'Invalid mileage result';
  end if;
  -- A job is tied to the reviewed unit/vehicle association at claim time.
  if not exists(select 1 from public.logistics_gps_units u where u.provider_unit_id=job.provider_unit_id
    and u.vehicle_id=job.vehicle_id and u.provider_visible) then
    update public.logistics_gps_daily_mileage set status='error',error_code='authorization',
      retry_at=now()+interval '1 hour',run_id=null,lease_until=null
      where provider_unit_id=job.provider_unit_id and entry_date=job.entry_date;
    return false;
  end if;
  update public.logistics_gps_daily_mileage set status=case when p_message_count<2 then 'no_data' else 'ok' end,
    kilometers=p_kilometers,trip_count=p_trip_count,message_count=p_message_count,
    fetched_at=now(),retry_at=null,error_code=null,run_id=null,lease_until=null
    where provider_unit_id=job.provider_unit_id and entry_date=job.entry_date;
  return true;
end; $$;

-- Recalculate the initial snapshot with location-bearing messages only.
update public.logistics_gps_daily_mileage set status='pending',retry_at=null,error_code=null where status in ('ok','no_data');
commit;
