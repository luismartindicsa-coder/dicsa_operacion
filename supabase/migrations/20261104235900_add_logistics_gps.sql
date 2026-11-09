begin;

-- GPS locations are available only to active Logistics and Direction users.
create function public.can_view_logistics_gps() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p join auth.users u on u.id = p.user_id
    where p.user_id = auth.uid() and p.is_active
      and lower(btrim(p.role)) <> 'bascula'
      and lower(btrim(coalesce(u.email, ''))) <> 'bascula@dicsamx.com'
      and (
        lower(btrim(p.role)) in ('services', 'logistics', 'logistica', 'direccion', 'direction', 'auxiliar_direccion', 'direccion_general')
        or lower(btrim(p.role)) like 'direccion\_%' escape '\'
        or lower(btrim(p.role)) like '%\_direccion' escape '\'
        or lower(btrim(p.role)) like '%direction%'
        or lower(btrim(coalesce(u.email, ''))) = 'direccion@dicsamx.com'
      )
  );
$$;
revoke all on function public.can_view_logistics_gps() from public, anon;
grant execute on function public.can_view_logistics_gps() to authenticated, service_role;

create table public.logistics_gps_units (
  provider_unit_id text primary key check (provider_unit_id ~ '^[0-9]+$'),
  provider_name text not null,
  vehicle_id uuid unique references public.vehicles(id) on delete set null,
  latitude double precision,
  longitude double precision,
  position_at timestamptz,
  observed_at timestamptz,
  provider_visible boolean not null default false,
  constraint logistics_gps_position_complete check (
    (latitude is null and longitude is null and position_at is null) or
    (latitude is not null and longitude is not null and position_at is not null
      and latitude between -90 and 90 and longitude between -180 and 180)
  )
);
create table public.logistics_gps_sync_state (
  singleton boolean primary key default true check (singleton),
  status text not null default 'pending' check (status in ('pending','ok','error')),
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  error_code text,
  token_expires_at timestamptz,
  run_id uuid,
  lease_until timestamptz
);
insert into public.logistics_gps_sync_state(singleton) values(true);

alter table public.logistics_gps_units enable row level security;
alter table public.logistics_gps_sync_state enable row level security;
revoke all on public.logistics_gps_units, public.logistics_gps_sync_state from anon, authenticated;
grant select on public.logistics_gps_units, public.logistics_gps_sync_state to authenticated;
grant all on public.logistics_gps_units, public.logistics_gps_sync_state to service_role;
create policy logistics_gps_read on public.logistics_gps_units for select to authenticated
  using ((select public.can_view_logistics_gps()));
create policy logistics_gps_status_read on public.logistics_gps_sync_state for select to authenticated
  using ((select public.can_view_logistics_gps()));

-- A lease and a minimum interval prevent overlapping callers from multiplying requests.
create function public.claim_logistics_gps_sync() returns uuid
language plpgsql security definer set search_path = '' as $$
declare claimed uuid;
begin
  update public.logistics_gps_sync_state
    set run_id = gen_random_uuid(), lease_until = now() + interval '90 seconds', last_attempt_at = now()
    where singleton and (lease_until is null or lease_until < now())
      and (last_attempt_at is null or last_attempt_at < now() - interval '45 seconds')
    returning run_id into claimed;
  return claimed;
end;
$$;

-- Publish an entire snapshot atomically. Failed pulls retain the last known data.
create function public.complete_logistics_gps_sync(
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
  insert into public.logistics_gps_units(provider_unit_id, provider_name, latitude, longitude, position_at, observed_at, provider_visible)
    select x.provider_unit_id, x.provider_name, x.latitude, x.longitude, x.position_at, started, true
    from jsonb_to_recordset(p_units) as x(provider_unit_id text, provider_name text, latitude double precision,
      longitude double precision, position_at timestamptz)
    on conflict(provider_unit_id) do update set provider_name=excluded.provider_name,
      latitude=excluded.latitude, longitude=excluded.longitude, position_at=excluded.position_at,
      observed_at=excluded.observed_at, provider_visible=true;
  -- Missing/private positions and revoked unit access must not expose an old location.
  update public.logistics_gps_units set provider_visible=false, latitude=null, longitude=null, position_at=null
    where provider_unit_id not in (select x->>'provider_unit_id' from jsonb_array_elements(p_units) x);
  update public.logistics_gps_sync_state set status='ok', last_success_at=started, error_code=null,
    token_expires_at=p_token_expires_at, run_id=null, lease_until=null where singleton;
  return true;
end;
$$;
revoke all on function public.claim_logistics_gps_sync() from public, anon, authenticated;
revoke all on function public.complete_logistics_gps_sync(uuid,jsonb,text,timestamptz) from public, anon, authenticated;
grant execute on function public.claim_logistics_gps_sync() to service_role;
grant execute on function public.complete_logistics_gps_sync(uuid,jsonb,text,timestamptz) to service_role;

-- Explicit associations reviewed against the current DICSA catalog. No fuzzy auto-linking.
do $$
declare item record; matched uuid; matches integer;
begin
  for item in select * from (values
    ('25592942','C-001','C1'), ('25592956','C-002','C2'), ('25705018','C-003','C3'),
    ('27447480','C-004','C4'), ('28998370','C-005','C5'),
    ('30587070','F-001','F1'), ('25705017','F-002','F2'), ('25592952','F-003','F3'),
    ('25705011','G-001','G1'), ('25705014','G-003','G3'), ('26969434','G-004','G4'), ('26969435','G-005','G5'),
    ('25592946','T-001','T1'), ('26969433','T-003','T3'), ('30510007','T-004','T4')
  ) as links(provider_id, provider_name, vehicle_code) loop
    select count(*) into matches from public.vehicles where upper(btrim(code))=item.vehicle_code;
    if matches > 1 then raise exception 'Ambiguous GPS vehicle code: %', item.vehicle_code; end if;
    select id into matched from public.vehicles where upper(btrim(code))=item.vehicle_code;
    insert into public.logistics_gps_units(provider_unit_id, provider_name, vehicle_id)
      values(item.provider_id, item.provider_name, matched);
  end loop;
end;
$$;
commit;
