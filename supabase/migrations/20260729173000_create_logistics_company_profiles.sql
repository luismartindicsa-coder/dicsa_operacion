begin;

create table if not exists public.logistics_company_profiles (
  site_id uuid primary key references public.sites (id) on delete cascade,
  site_name text not null,
  operational_contact text,
  contact_phone text,
  address_line text,
  address_reference text,
  pickup_window text,
  schedule_flexibility text not null default 'POR_DEFINIR',
  early_pickup_required boolean not null default false,
  has_containers boolean not null default false,
  container_count integer not null default 0,
  container_capacity_note text,
  collection_urgency text not null default 'MEDIA',
  volume_pressure text not null default 'POR_DEFINIR',
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_company_profiles_site_name_trim_chk check (
    site_name = btrim(site_name) and length(site_name) > 0
  ),
  constraint logistics_company_profiles_schedule_flexibility_chk check (
    schedule_flexibility in ('POR_DEFINIR', 'FIJO', 'NEGOCIABLE', 'RESTRINGIDO')
  ),
  constraint logistics_company_profiles_collection_urgency_chk check (
    collection_urgency in ('BAJA', 'MEDIA', 'ALTA', 'CRITICA')
  ),
  constraint logistics_company_profiles_volume_pressure_chk check (
    volume_pressure in ('POR_DEFINIR', 'BAJO', 'MEDIO', 'ALTO')
  ),
  constraint logistics_company_profiles_container_count_chk check (
    container_count >= 0 and
    (
      (has_containers and container_count >= 0) or
      (not has_containers and container_count = 0)
    )
  )
);

create index if not exists logistics_company_profiles_site_name_idx
  on public.logistics_company_profiles (site_name);

create index if not exists logistics_company_profiles_urgency_idx
  on public.logistics_company_profiles (
    collection_urgency,
    early_pickup_required desc,
    has_containers desc
  );

create index if not exists logistics_company_profiles_container_idx
  on public.logistics_company_profiles (
    has_containers,
    container_count desc
  );

create or replace function public.set_logistics_company_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_company_profiles_set_updated_at
on public.logistics_company_profiles;

create trigger logistics_company_profiles_set_updated_at
before update on public.logistics_company_profiles
for each row
execute function public.set_logistics_company_profiles_updated_at();

create or replace function public.sync_logistics_company_profile_from_site()
returns trigger
language plpgsql
as $$
begin
  if coalesce(new.type, '') = 'cliente' then
    insert into public.logistics_company_profiles (
      site_id,
      site_name
    )
    values (
      new.id,
      new.name
    )
    on conflict (site_id) do update
      set site_name = excluded.site_name;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sites_sync_logistics_company_profile
on public.sites;

create trigger trg_sites_sync_logistics_company_profile
after insert or update of name, type on public.sites
for each row
execute function public.sync_logistics_company_profile_from_site();

insert into public.logistics_company_profiles (
  site_id,
  site_name
)
select
  s.id,
  s.name
from public.sites s
where s.type = 'cliente'
on conflict (site_id) do update
  set site_name = excluded.site_name;

alter table public.logistics_company_profiles enable row level security;

grant select, insert, update, delete
on public.logistics_company_profiles
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_company_profiles'
      and policyname = 'logistics_company_profiles_authenticated_all'
  ) then
    create policy logistics_company_profiles_authenticated_all
      on public.logistics_company_profiles
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
