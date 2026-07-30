begin;

create table if not exists public.logistics_zones (
  id text primary key,
  code text not null,
  name text not null,
  city text not null default 'Celaya',
  state text not null default 'Guanajuato',
  color_hex text not null default '#C7CDD4',
  coverage_hint text,
  display_order integer not null default 0,
  polygon_points jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_zones_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint logistics_zones_code_trim_chk check (
    code = btrim(code) and length(code) > 0
  ),
  constraint logistics_zones_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  ),
  constraint logistics_zones_color_hex_chk check (
    color_hex ~ '^#[0-9A-Fa-f]{6}$'
  ),
  constraint logistics_zones_polygon_points_array_chk check (
    jsonb_typeof(polygon_points) = 'array'
  )
);

create unique index if not exists logistics_zones_code_unique_idx
  on public.logistics_zones (upper(code));

create unique index if not exists logistics_zones_name_unique_idx
  on public.logistics_zones (upper(name));

create index if not exists logistics_zones_active_order_idx
  on public.logistics_zones (is_active, display_order, name);

create or replace function public.set_logistics_zones_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_zones_set_updated_at
on public.logistics_zones;

create trigger logistics_zones_set_updated_at
before update on public.logistics_zones
for each row
execute function public.set_logistics_zones_updated_at();

alter table public.logistics_company_profiles
  add column if not exists zone_id text references public.logistics_zones(id) on delete set null,
  add column if not exists zone_notes text,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7);

create index if not exists logistics_company_profiles_zone_idx
  on public.logistics_company_profiles (
    zone_id,
    collection_urgency,
    early_pickup_required desc
  );

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'logistics_company_profiles_latitude_chk'
  ) then
    alter table public.logistics_company_profiles
      add constraint logistics_company_profiles_latitude_chk check (
        latitude is null or (latitude >= -90 and latitude <= 90)
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'logistics_company_profiles_longitude_chk'
  ) then
    alter table public.logistics_company_profiles
      add constraint logistics_company_profiles_longitude_chk check (
        longitude is null or (longitude >= -180 and longitude <= 180)
      );
  end if;
end
$$;

alter table public.logistics_zones enable row level security;

grant select, insert, update, delete
on public.logistics_zones
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_zones'
      and policyname = 'logistics_zones_authenticated_all'
  ) then
    create policy logistics_zones_authenticated_all
      on public.logistics_zones
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
