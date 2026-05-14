create table if not exists public.operation_directory_areas (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.operation_directory_specialties (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.operation_directory_contact_areas (
  contact_id uuid not null references public.operation_directory_contacts(id) on delete cascade,
  area_id uuid not null references public.operation_directory_areas(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (contact_id, area_id)
);

create table if not exists public.operation_directory_contact_specialties (
  contact_id uuid not null references public.operation_directory_contacts(id) on delete cascade,
  specialty_id uuid not null references public.operation_directory_specialties(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (contact_id, specialty_id)
);

create index if not exists operation_directory_areas_name_idx
  on public.operation_directory_areas(name);

create index if not exists operation_directory_specialties_name_idx
  on public.operation_directory_specialties(name);

create index if not exists operation_directory_contact_areas_contact_idx
  on public.operation_directory_contact_areas(contact_id);

create index if not exists operation_directory_contact_specialties_contact_idx
  on public.operation_directory_contact_specialties(contact_id);

drop trigger if exists trg_operation_directory_areas_updated_at
  on public.operation_directory_areas;
create trigger trg_operation_directory_areas_updated_at
before update on public.operation_directory_areas
for each row execute function public.set_maintenance_updated_at();

drop trigger if exists trg_operation_directory_specialties_updated_at
  on public.operation_directory_specialties;
create trigger trg_operation_directory_specialties_updated_at
before update on public.operation_directory_specialties
for each row execute function public.set_maintenance_updated_at();

alter table public.operation_directory_areas enable row level security;
alter table public.operation_directory_specialties enable row level security;
alter table public.operation_directory_contact_areas enable row level security;
alter table public.operation_directory_contact_specialties enable row level security;

drop policy if exists "operation_directory_areas_auth_all" on public.operation_directory_areas;
create policy "operation_directory_areas_auth_all"
on public.operation_directory_areas
for all
to authenticated
using (true)
with check (true);

drop policy if exists "operation_directory_specialties_auth_all" on public.operation_directory_specialties;
create policy "operation_directory_specialties_auth_all"
on public.operation_directory_specialties
for all
to authenticated
using (true)
with check (true);

drop policy if exists "operation_directory_contact_areas_auth_all" on public.operation_directory_contact_areas;
create policy "operation_directory_contact_areas_auth_all"
on public.operation_directory_contact_areas
for all
to authenticated
using (true)
with check (true);

drop policy if exists "operation_directory_contact_specialties_auth_all" on public.operation_directory_contact_specialties;
create policy "operation_directory_contact_specialties_auth_all"
on public.operation_directory_contact_specialties
for all
to authenticated
using (true)
with check (true);

grant all on public.operation_directory_areas to authenticated;
grant all on public.operation_directory_specialties to authenticated;
grant all on public.operation_directory_contact_areas to authenticated;
grant all on public.operation_directory_contact_specialties to authenticated;

with raw_areas as (
  select distinct trim(value) as name
  from public.operation_directory_contacts c
  cross join lateral regexp_split_to_table(coalesce(c.area, ''), E'[,;/\\n\\r]+') value
  where trim(value) <> ''
)
insert into public.operation_directory_areas(name)
select name
from raw_areas
on conflict (name) do update
  set active = true,
      updated_at = now();

insert into public.operation_directory_contact_areas(contact_id, area_id)
select distinct c.id, a.id
from public.operation_directory_contacts c
cross join lateral regexp_split_to_table(coalesce(c.area, ''), E'[,;/\\n\\r]+') value
join public.operation_directory_areas a
  on a.name = trim(value)
where trim(value) <> ''
on conflict do nothing;

with raw_specialties as (
  select distinct trim(value) as name
  from public.operation_directory_contacts c
  cross join lateral regexp_split_to_table(coalesce(c.specialty, ''), E'[,;/\\n\\r]+') value
  where trim(value) <> ''
)
insert into public.operation_directory_specialties(name)
select name
from raw_specialties
on conflict (name) do update
  set active = true,
      updated_at = now();

insert into public.operation_directory_contact_specialties(contact_id, specialty_id)
select distinct c.id, s.id
from public.operation_directory_contacts c
cross join lateral regexp_split_to_table(coalesce(c.specialty, ''), E'[,;/\\n\\r]+') value
join public.operation_directory_specialties s
  on s.name = trim(value)
where trim(value) <> ''
on conflict do nothing;
