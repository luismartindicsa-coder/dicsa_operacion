begin;

-- Daily distance comes from EPCOM's historical trip calculation. Imported
-- mileage remains in its original table and takes precedence in Rendimiento.
create table public.logistics_gps_daily_mileage (
  provider_unit_id text not null references public.logistics_gps_units(provider_unit_id),
  entry_date date not null,
  vehicle_id uuid not null references public.vehicles(id),
  vehicle_label text not null,
  status text not null default 'pending' check(status in ('pending','running','ok','no_data','error')),
  kilometers numeric(12,3),
  trip_count integer,
  message_count integer,
  fetched_at timestamptz,
  last_attempt_at timestamptz,
  retry_at timestamptz,
  error_code text,
  run_id uuid,
  lease_until timestamptz,
  diesel_price_per_liter numeric(8,2),
  gasoline_price_per_liter numeric(8,2),
  primary key(provider_unit_id,entry_date),
  unique(vehicle_id,entry_date),
  check(kilometers is null or (kilometers>=0 and kilometers<=5000)),
  check(trip_count is null or trip_count>=0),
  check(message_count is null or message_count>=0),
  check(diesel_price_per_liter is null or diesel_price_per_liter>0),
  check(gasoline_price_per_liter is null or gasoline_price_per_liter>0)
);
create index logistics_gps_mileage_date on public.logistics_gps_daily_mileage(entry_date desc,vehicle_id);
alter table public.logistics_gps_daily_mileage enable row level security;
revoke all on public.logistics_gps_daily_mileage from anon,authenticated;
grant select on public.logistics_gps_daily_mileage to authenticated;
grant update(diesel_price_per_liter,gasoline_price_per_liter) on public.logistics_gps_daily_mileage to authenticated;
grant all on public.logistics_gps_daily_mileage to service_role;
create policy logistics_gps_mileage_read on public.logistics_gps_daily_mileage for select to authenticated
  using ((select public.can_view_logistics_gps()));
create policy logistics_gps_mileage_prices on public.logistics_gps_daily_mileage for update to authenticated
  using ((select public.can_view_logistics_gps())) with check ((select public.can_view_logistics_gps()));

create function public.claim_logistics_gps_mileage(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path='' as $$
declare local_today date:=(p_now at time zone 'America/Mexico_City')::date;
  from_day date; job public.logistics_gps_daily_mileage%rowtype;
begin
  -- Serialize queue seeding/claiming, independently of location ingestion.
  perform pg_advisory_xact_lock(78461105);
  select greatest(date '2026-11-01',coalesce(max(entry_date)-2,date '2026-11-01'))
    into from_day from public.logistics_gps_daily_mileage;
  insert into public.logistics_gps_daily_mileage(provider_unit_id,entry_date,vehicle_id,vehicle_label)
    select u.provider_unit_id,d::date,u.vehicle_id,v.code
    from public.logistics_gps_units u join public.vehicles v on v.id=u.vehicle_id
    cross join generate_series(from_day::timestamp,(local_today-1)::timestamp,interval '1 day') d
    where u.provider_visible
    on conflict do nothing;
  -- Authorization failures must not cause a request storm for every vehicle.
  if exists(select 1 from public.logistics_gps_daily_mileage
    where error_code='authorization' and last_attempt_at>p_now-interval '1 hour') then return null; end if;
  select m.* into job from public.logistics_gps_daily_mileage m
    join public.logistics_gps_units u using(provider_unit_id)
    where u.provider_visible and u.vehicle_id=m.vehicle_id and m.entry_date<local_today
      and (m.lease_until is null or m.lease_until<p_now)
      and (m.retry_at is null or m.retry_at<=p_now)
      and (m.status in ('pending','running','error') or
        (m.entry_date>=local_today-3 and m.fetched_at<p_now-interval '12 hours'))
    order by case when m.status='pending' then 0 else 1 end,m.entry_date,m.vehicle_label
    limit 1 for update of m skip locked;
  if not found then return null; end if;
  update public.logistics_gps_daily_mileage set status='running',run_id=gen_random_uuid(),
    lease_until=p_now+interval '90 seconds',last_attempt_at=p_now
    where provider_unit_id=job.provider_unit_id and entry_date=job.entry_date returning * into job;
  return jsonb_build_object('run_id',job.run_id,'provider_unit_id',job.provider_unit_id,
    'entry_date',job.entry_date,
    'time_from',extract(epoch from(job.entry_date::timestamp at time zone 'America/Mexico_City'))::bigint,
    'time_to',extract(epoch from((job.entry_date+1)::timestamp at time zone 'America/Mexico_City'))::bigint-1);
end; $$;

create function public.complete_logistics_gps_mileage(p_run_id uuid,p_kilometers double precision default null,
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
    or (p_message_count=0 and (p_kilometers is not null or p_trip_count<>0))
    or (p_message_count>0 and (p_kilometers is null or not(p_kilometers between 0 and 5000))) then
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
  update public.logistics_gps_daily_mileage set status=case when p_message_count=0 then 'no_data' else 'ok' end,
    kilometers=p_kilometers,trip_count=p_trip_count,message_count=p_message_count,
    fetched_at=now(),retry_at=null,error_code=null,run_id=null,lease_until=null
    where provider_unit_id=job.provider_unit_id and entry_date=job.entry_date;
  return true;
end; $$;
revoke all on function public.claim_logistics_gps_mileage(timestamptz) from public,anon,authenticated;
revoke all on function public.complete_logistics_gps_mileage(uuid,double precision,integer,integer,text) from public,anon,authenticated;
grant execute on function public.claim_logistics_gps_mileage(timestamptz) to service_role;
grant execute on function public.complete_logistics_gps_mileage(uuid,double precision,integer,integer,text) to service_role;
commit;
