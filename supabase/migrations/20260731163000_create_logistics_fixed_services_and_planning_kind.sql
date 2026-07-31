begin;

create table if not exists public.logistics_fixed_services (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites(id) on delete restrict,
  site_name text not null,
  material_id uuid references public.material_commercial_catalog_v2(id) on delete set null,
  material_name text not null,
  movement text not null default 'recoleccion',
  scheduled_time time without time zone not null,
  weekdays jsonb not null default '[]'::jsonb,
  default_driver_employee_id uuid references public.employees(id) on delete set null,
  default_vehicle_id uuid references public.vehicles(id) on delete set null,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_fixed_services_site_name_trim_chk check (
    site_name = btrim(site_name) and length(site_name) > 0
  ),
  constraint logistics_fixed_services_material_name_trim_chk check (
    material_name = btrim(material_name) and length(material_name) > 0
  ),
  constraint logistics_fixed_services_movement_chk check (
    movement in ('recoleccion', 'entrega')
  ),
  constraint logistics_fixed_services_weekdays_array_chk check (
    jsonb_typeof(weekdays) = 'array'
  )
);

create index if not exists logistics_fixed_services_site_time_idx
  on public.logistics_fixed_services (
    site_name,
    scheduled_time,
    is_active desc
  );

create index if not exists logistics_fixed_services_driver_vehicle_idx
  on public.logistics_fixed_services (
    default_driver_employee_id,
    default_vehicle_id
  );

create or replace function public.set_logistics_fixed_services_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_fixed_services_set_updated_at
on public.logistics_fixed_services;

create trigger logistics_fixed_services_set_updated_at
before update on public.logistics_fixed_services
for each row
execute function public.set_logistics_fixed_services_updated_at();

alter table public.services
  add column if not exists planning_kind text not null default 'VARIANTE',
  add column if not exists fixed_service_id uuid references public.logistics_fixed_services(id) on delete set null;

update public.services
set planning_kind = 'VARIANTE'
where coalesce(planning_kind, '') = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'services_planning_kind_chk'
  ) then
    alter table public.services
      add constraint services_planning_kind_chk check (
        planning_kind in ('FIJO', 'VARIANTE')
      );
  end if;
end
$$;

create index if not exists services_planning_kind_idx
  on public.services (
    area,
    planning_kind,
    due_date desc,
    scheduled_time
  );

create index if not exists services_fixed_service_id_idx
  on public.services (
    fixed_service_id,
    service_date desc
  );

alter table public.logistics_fixed_services enable row level security;

grant select, insert, update, delete
on public.logistics_fixed_services
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_fixed_services'
      and policyname = 'logistics_fixed_services_authenticated_all'
  ) then
    create policy logistics_fixed_services_authenticated_all
      on public.logistics_fixed_services
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
