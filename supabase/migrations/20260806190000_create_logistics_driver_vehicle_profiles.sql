begin;

create table if not exists public.logistics_driver_profiles (
  employee_id uuid primary key references public.employees(id) on delete cascade,
  driver_name text not null,
  compatible_unit_types jsonb not null default '[]'::jsonb,
  planning_status text not null default 'ACTIVO',
  coverage_note text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_driver_profiles_driver_name_trim_chk check (
    driver_name = btrim(driver_name) and length(driver_name) > 0
  ),
  constraint logistics_driver_profiles_planning_status_chk check (
    planning_status in ('ACTIVO', 'RESTRINGIDO', 'NO_PROGRAMAR')
  ),
  constraint logistics_driver_profiles_unit_types_array_chk check (
    jsonb_typeof(compatible_unit_types) = 'array'
  )
);

create index if not exists logistics_driver_profiles_name_idx
  on public.logistics_driver_profiles (driver_name);

create index if not exists logistics_driver_profiles_planning_status_idx
  on public.logistics_driver_profiles (planning_status, driver_name);

create or replace function public.set_logistics_driver_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_driver_profiles_set_updated_at
on public.logistics_driver_profiles;

create trigger logistics_driver_profiles_set_updated_at
before update on public.logistics_driver_profiles
for each row
execute function public.set_logistics_driver_profiles_updated_at();

create or replace function public.sync_logistics_driver_profile_from_employee()
returns trigger
language plpgsql
as $$
begin
  if coalesce(new.is_driver, false) then
    insert into public.logistics_driver_profiles (
      employee_id,
      driver_name
    )
    values (
      new.id,
      new.full_name
    )
    on conflict (employee_id) do update
      set driver_name = excluded.driver_name;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_employees_sync_logistics_driver_profile
on public.employees;

create trigger trg_employees_sync_logistics_driver_profile
after insert or update of full_name, is_driver on public.employees
for each row
execute function public.sync_logistics_driver_profile_from_employee();

insert into public.logistics_driver_profiles (
  employee_id,
  driver_name
)
select
  e.id,
  e.full_name
from public.employees e
where e.is_driver = true
on conflict (employee_id) do update
  set driver_name = excluded.driver_name;

alter table public.logistics_driver_profiles enable row level security;

grant select, insert, update, delete
on public.logistics_driver_profiles
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_driver_profiles'
      and policyname = 'logistics_driver_profiles_authenticated_all'
  ) then
    create policy logistics_driver_profiles_authenticated_all
      on public.logistics_driver_profiles
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

create table if not exists public.logistics_vehicle_profiles (
  vehicle_id uuid primary key references public.vehicles(id) on delete cascade,
  vehicle_code text not null,
  serial_number text,
  source_vehicle_type text,
  source_status text not null default 'activo',
  logistics_unit_type text not null default 'POR_DEFINIR',
  compatible_load_types jsonb not null default '[]'::jsonb,
  planning_status text not null default 'ACTIVO',
  capacity_note text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_vehicle_profiles_vehicle_code_trim_chk check (
    vehicle_code = btrim(vehicle_code) and length(vehicle_code) > 0
  ),
  constraint logistics_vehicle_profiles_planning_status_chk check (
    planning_status in ('ACTIVO', 'RESTRINGIDO', 'NO_PROGRAMAR')
  ),
  constraint logistics_vehicle_profiles_logistics_unit_type_chk check (
    logistics_unit_type in (
      'POR_DEFINIR',
      'CAMIONETA',
      'CAMION',
      'PICK_UP',
      'GRUA',
      'TRAILER'
    )
  ),
  constraint logistics_vehicle_profiles_load_types_array_chk check (
    jsonb_typeof(compatible_load_types) = 'array'
  )
);

create index if not exists logistics_vehicle_profiles_code_idx
  on public.logistics_vehicle_profiles (vehicle_code);

create index if not exists logistics_vehicle_profiles_unit_type_idx
  on public.logistics_vehicle_profiles (
    logistics_unit_type,
    planning_status,
    vehicle_code
  );

create or replace function public.set_logistics_vehicle_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_vehicle_profiles_set_updated_at
on public.logistics_vehicle_profiles;

create trigger logistics_vehicle_profiles_set_updated_at
before update on public.logistics_vehicle_profiles
for each row
execute function public.set_logistics_vehicle_profiles_updated_at();

create or replace function public.sync_logistics_vehicle_profile_from_vehicle()
returns trigger
language plpgsql
as $$
begin
  insert into public.logistics_vehicle_profiles (
    vehicle_id,
    vehicle_code,
    serial_number,
    source_vehicle_type,
    source_status
  )
  values (
    new.id,
    new.code,
    new.serial_number,
    new.type,
    new.status
  )
  on conflict (vehicle_id) do update
    set vehicle_code = excluded.vehicle_code,
        serial_number = excluded.serial_number,
        source_vehicle_type = excluded.source_vehicle_type,
        source_status = excluded.source_status;

  return new;
end;
$$;

drop trigger if exists trg_vehicles_sync_logistics_vehicle_profile
on public.vehicles;

create trigger trg_vehicles_sync_logistics_vehicle_profile
after insert or update of code, serial_number, type, status on public.vehicles
for each row
execute function public.sync_logistics_vehicle_profile_from_vehicle();

insert into public.logistics_vehicle_profiles (
  vehicle_id,
  vehicle_code,
  serial_number,
  source_vehicle_type,
  source_status
)
select
  v.id,
  v.code,
  v.serial_number,
  v.type,
  v.status
from public.vehicles v
on conflict (vehicle_id) do update
  set vehicle_code = excluded.vehicle_code,
      serial_number = excluded.serial_number,
      source_vehicle_type = excluded.source_vehicle_type,
      source_status = excluded.source_status;

alter table public.logistics_vehicle_profiles enable row level security;

grant select, insert, update, delete
on public.logistics_vehicle_profiles
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_vehicle_profiles'
      and policyname = 'logistics_vehicle_profiles_authenticated_all'
  ) then
    create policy logistics_vehicle_profiles_authenticated_all
      on public.logistics_vehicle_profiles
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
