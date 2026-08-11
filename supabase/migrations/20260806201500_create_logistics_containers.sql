begin;

create table if not exists public.logistics_containers (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null default current_date,
  operator_employee_id uuid references public.employees(id) on delete set null,
  operator_name text,
  container_label text not null,
  legacy_code text,
  material_name text,
  site_id uuid references public.sites(id) on delete set null,
  site_name text,
  location_label text not null,
  tare_weight_kg numeric(12,2) not null default 0,
  width_m numeric(12,3) not null default 0,
  height_m numeric(12,3) not null default 0,
  length_m numeric(12,3) not null default 0,
  capacity_m3 numeric(12,3) not null default 0,
  compatible_unit_types jsonb not null default '[]'::jsonb,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_containers_container_label_trim_chk check (
    container_label = btrim(container_label) and length(container_label) > 0
  ),
  constraint logistics_containers_location_label_trim_chk check (
    location_label = btrim(location_label) and length(location_label) > 0
  ),
  constraint logistics_containers_dimensions_non_negative_chk check (
    tare_weight_kg >= 0 and
    width_m >= 0 and
    height_m >= 0 and
    length_m >= 0 and
    capacity_m3 >= 0
  ),
  constraint logistics_containers_compatible_unit_types_array_chk check (
    jsonb_typeof(compatible_unit_types) = 'array'
  )
);

create index if not exists logistics_containers_entry_date_idx
  on public.logistics_containers (
    entry_date desc,
    container_label
  );

create index if not exists logistics_containers_site_idx
  on public.logistics_containers (
    site_id,
    site_name
  );

create index if not exists logistics_containers_operator_idx
  on public.logistics_containers (
    operator_employee_id,
    operator_name
  );

create or replace function public.set_logistics_containers_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_containers_set_updated_at
on public.logistics_containers;

create trigger logistics_containers_set_updated_at
before update on public.logistics_containers
for each row
execute function public.set_logistics_containers_updated_at();

alter table public.logistics_containers enable row level security;

grant select, insert, update, delete
on public.logistics_containers
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_containers'
      and policyname = 'logistics_containers_authenticated_all'
  ) then
    create policy logistics_containers_authenticated_all
      on public.logistics_containers
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
