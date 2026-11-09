begin;

-- Delivery dates are existing business data. Creation time is NOT delivery time.
alter table public.logistics_diesel_consumption add column loaded_at timestamptz;
alter table public.logistics_gasoline_control add column loaded_at timestamptz;
alter table public.logistics_diesel_consumption add constraint diesel_loaded_day_check
  check(loaded_at is null or (loaded_at at time zone 'America/Mexico_City')::date=entry_date);
alter table public.logistics_gasoline_control add constraint gasoline_loaded_day_check
  check(loaded_at is null or (loaded_at at time zone 'America/Mexico_City')::date=entry_date);

create function public.guard_logistics_load_time() returns trigger
language plpgsql set search_path='' as $$
begin
  if tg_op='UPDATE' and (new.entry_date<>old.entry_date or new.vehicle_id is distinct from old.vehicle_id) then
    new.loaded_at:=null;
  end if;
  if new.loaded_at>now() then raise exception 'La hora de carga no puede estar en el futuro.'; end if;
  return new;
end; $$;
create trigger logistics_diesel_load_time before insert or update on public.logistics_diesel_consumption
  for each row execute function public.guard_logistics_load_time();
create trigger logistics_gasoline_load_time before insert or update on public.logistics_gasoline_control
  for each row execute function public.guard_logistics_load_time();

create function public.set_logistics_fuel_load_time(p_fuel text,p_id uuid,p_loaded_at timestamptz,
  p_vehicle_id uuid,p_entry_date date,p_liters numeric) returns boolean
language plpgsql security definer set search_path='' as $$
declare changed integer;
begin
  if not public.can_view_logistics_gps() then raise insufficient_privilege; end if;
  if p_loaded_at is null or p_loaded_at>now() or
    (p_loaded_at at time zone 'America/Mexico_City')::date<>p_entry_date then
    raise exception 'La hora debe corresponder al día de la carga y no estar en el futuro.';
  end if;
  if p_fuel='diesel' then
    update public.logistics_diesel_consumption set loaded_at=p_loaded_at
      where id=p_id and vehicle_id=p_vehicle_id and entry_date=p_entry_date and liters_requested=p_liters and liters_requested>0;
  elsif p_fuel='gasoline' then
    update public.logistics_gasoline_control set loaded_at=p_loaded_at
      where id=p_id and vehicle_id=p_vehicle_id and entry_date=p_entry_date and liters_loaded=p_liters and liters_loaded>0;
  else raise exception 'Combustible inválido.';
  end if;
  get diagnostics changed=row_count;
  return changed=1;
end; $$;
revoke all on function public.set_logistics_fuel_load_time(text,uuid,timestamptz,uuid,date,numeric) from public,anon;
grant execute on function public.set_logistics_fuel_load_time(text,uuid,timestamptz,uuid,date,numeric) to authenticated;

-- All loads on the latest business day participate in the signature. If any
-- time is unknown, the order of multiple same-day loads must not be invented.
create view public.logistics_latest_fuel_loads as
with loads as (
  select 'diesel' fuel,id,vehicle_id,entry_date,loaded_at,liters_requested liters
    from public.logistics_diesel_consumption where liters_requested>0 and vehicle_id is not null
  union all
  select 'gasoline',id,vehicle_id,entry_date,loaded_at,liters_loaded
    from public.logistics_gasoline_control where liters_loaded>0 and vehicle_id is not null
), dated as (
  select *,max(entry_date) over(partition by vehicle_id) latest_date from loads
  where entry_date<=(now() at time zone 'America/Mexico_City')::date
)
select vehicle_id,entry_date,
  case when bool_and(loaded_at is not null) then max(loaded_at) end loaded_at,
  jsonb_agg(jsonb_build_object('fuel',fuel,'id',id,'liters',liters,'loaded_at',loaded_at) order by fuel,id) load_snapshot
from dated where entry_date=latest_date group by vehicle_id,entry_date;
revoke all on public.logistics_latest_fuel_loads from public,anon,authenticated;
grant select on public.logistics_latest_fuel_loads to service_role;

create table public.logistics_gps_load_mileage (
  vehicle_id uuid primary key references public.vehicles(id) on delete cascade,
  provider_unit_id text not null references public.logistics_gps_units(provider_unit_id),
  load_date date not null,
  load_snapshot jsonb not null,
  window_kind text not null check(window_kind in ('since_load','after_load_day','load_day')),
  from_at timestamptz not null,
  through_at timestamptz,
  requested_through_at timestamptz,
  status text not null default 'pending' check(status in ('pending','running','ok','no_data','error')),
  kilometers numeric(14,3),
  message_count integer,
  fetched_at timestamptz,
  last_attempt_at timestamptz,
  error_code text,
  retry_at timestamptz,
  run_id uuid,
  lease_until timestamptz,
  check(kilometers is null or kilometers between 0 and 155000),
  check(through_at is null or through_at>=from_at)
);
alter table public.logistics_gps_load_mileage enable row level security;
revoke all on public.logistics_gps_load_mileage from public,anon,authenticated;
grant select on public.logistics_gps_load_mileage to authenticated;
grant all on public.logistics_gps_load_mileage to service_role;
create policy logistics_load_mileage_read on public.logistics_gps_load_mileage for select to authenticated
  using ((select public.can_view_logistics_gps()));

create function public.claim_logistics_gps_load_mileage(p_now timestamptz default now()) returns jsonb
language plpgsql security definer set search_path='' as $$
declare today date:=(p_now at time zone 'America/Mexico_City')::date;
  job public.logistics_gps_load_mileage%rowtype;
begin
  perform pg_advisory_xact_lock(78461106);
  delete from public.logistics_gps_load_mileage m where not exists(
    select 1 from public.logistics_latest_fuel_loads l join public.logistics_gps_units u on u.vehicle_id=l.vehicle_id
    where l.vehicle_id=m.vehicle_id and u.provider_visible and l.entry_date>=today-30);
  insert into public.logistics_gps_load_mileage(vehicle_id,provider_unit_id,load_date,load_snapshot,window_kind,from_at)
    select l.vehicle_id,u.provider_unit_id,l.entry_date,l.load_snapshot,
      case when l.loaded_at is not null then 'since_load' when l.entry_date<today then 'after_load_day' else 'load_day' end,
      coalesce(l.loaded_at,(case when l.entry_date<today then l.entry_date+1 else today end)::timestamp at time zone 'America/Mexico_City')
    from public.logistics_latest_fuel_loads l join public.logistics_gps_units u on u.vehicle_id=l.vehicle_id
    where u.provider_visible and l.entry_date between today-30 and today
    on conflict(vehicle_id) do update set provider_unit_id=excluded.provider_unit_id,load_date=excluded.load_date,
      load_snapshot=excluded.load_snapshot,window_kind=excluded.window_kind,from_at=excluded.from_at,
      through_at=null,requested_through_at=null,status='pending',kilometers=null,message_count=null,fetched_at=null,
      last_attempt_at=null,error_code=null,retry_at=null,run_id=null,lease_until=null
    where logistics_gps_load_mileage.load_snapshot<>excluded.load_snapshot
      or logistics_gps_load_mileage.load_date<>excluded.load_date
      or logistics_gps_load_mileage.provider_unit_id<>excluded.provider_unit_id
      or logistics_gps_load_mileage.from_at<>excluded.from_at;
  if not exists(select 1 from public.logistics_gps_sync_state where status='ok' and last_success_at>=p_now-interval '3 minutes') then return null; end if;
  if exists(select 1 from public.logistics_gps_load_mileage where error_code='authorization' and last_attempt_at>p_now-interval '1 hour') then return null; end if;
  select m.* into job from public.logistics_gps_load_mileage m
    join public.logistics_gps_units u on u.vehicle_id=m.vehicle_id and u.provider_unit_id=m.provider_unit_id
    where u.provider_visible and u.position_at>m.from_at and u.position_at<=p_now
      and u.position_at>=p_now-interval '15 minutes'
      and (m.lease_until is null or m.lease_until<p_now)
      and (m.retry_at is null or m.retry_at<=p_now)
      and (m.fetched_at is null or m.fetched_at<p_now-interval '5 minutes')
    order by m.last_attempt_at nulls first,m.vehicle_id limit 1 for update of m skip locked;
  if not found then return null; end if;
  update public.logistics_gps_load_mileage m set status='running',run_id=gen_random_uuid(),
    last_attempt_at=p_now,lease_until=p_now+interval '90 seconds',requested_through_at=date_trunc('second',u.position_at)
    from public.logistics_gps_units u where m.vehicle_id=job.vehicle_id and u.provider_unit_id=m.provider_unit_id returning m.* into job;
  return jsonb_build_object('run_id',job.run_id,'provider_unit_id',job.provider_unit_id,
    'time_from',ceil(extract(epoch from job.from_at))::bigint,
    'time_to',extract(epoch from job.requested_through_at)::bigint);
end; $$;

create function public.complete_logistics_gps_load_mileage(p_run_id uuid,p_kilometers double precision default null,
  p_message_count integer default null,p_error text default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare job public.logistics_gps_load_mileage%rowtype;
begin
  select * into job from public.logistics_gps_load_mileage where run_id=p_run_id for update;
  if not found then return false; end if;
  if not exists(select 1 from public.logistics_latest_fuel_loads l join public.logistics_gps_units u on u.vehicle_id=l.vehicle_id
    where l.vehicle_id=job.vehicle_id and l.load_snapshot=job.load_snapshot and l.entry_date=job.load_date
      and u.provider_unit_id=job.provider_unit_id and u.provider_visible) then
    delete from public.logistics_gps_load_mileage where vehicle_id=job.vehicle_id;
    return false;
  end if;
  if p_error is not null then
    if p_error not in ('authorization','not_configured','provider_unavailable','invalid_response','storage') then raise exception 'Invalid error'; end if;
    update public.logistics_gps_load_mileage set status='error',error_code=p_error,
      retry_at=now()+case when p_error='authorization' then interval '1 hour' else interval '5 minutes' end,
      run_id=null,lease_until=null where vehicle_id=job.vehicle_id;
    return true;
  end if;
  if p_message_count is null or p_message_count<0 or
    (p_message_count<2 and p_kilometers is not null) or
    (p_message_count>=2 and (p_kilometers is null or not(p_kilometers between 0 and 155000))) then
    raise exception 'Invalid mileage result';
  end if;
  update public.logistics_gps_load_mileage set status=case when p_message_count>=2 then 'ok' else 'no_data' end,
    kilometers=p_kilometers,message_count=p_message_count,through_at=requested_through_at,fetched_at=now(),
    error_code=null,retry_at=null,run_id=null,lease_until=null where vehicle_id=job.vehicle_id;
  return true;
end; $$;
revoke all on function public.claim_logistics_gps_load_mileage(timestamptz),
  public.complete_logistics_gps_load_mileage(uuid,double precision,integer,text) from public,anon,authenticated;
grant execute on function public.claim_logistics_gps_load_mileage(timestamptz),
  public.complete_logistics_gps_load_mileage(uuid,double precision,integer,text) to service_role;

commit;
