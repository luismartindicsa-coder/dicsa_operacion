begin;

create table if not exists public.logistics_vehicle_mileage (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  vehicle_label text not null,
  vehicle_key text not null,
  kilometers numeric(12,2) not null,
  source_file_name text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_vehicle_mileage_label_trim_chk check (
    vehicle_label = btrim(vehicle_label) and length(vehicle_label) > 0
  ),
  constraint logistics_vehicle_mileage_key_trim_chk check (
    vehicle_key = btrim(vehicle_key) and length(vehicle_key) > 0
  ),
  constraint logistics_vehicle_mileage_kilometers_nonnegative_chk check (
    kilometers >= 0
  ),
  unique (entry_date, vehicle_key)
);

create index if not exists logistics_vehicle_mileage_date_idx
  on public.logistics_vehicle_mileage (entry_date desc, vehicle_key);

create index if not exists logistics_vehicle_mileage_vehicle_idx
  on public.logistics_vehicle_mileage (vehicle_id, entry_date desc);

create or replace function public.set_logistics_vehicle_mileage_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_vehicle_mileage_set_updated_at
on public.logistics_vehicle_mileage;

create trigger logistics_vehicle_mileage_set_updated_at
before update on public.logistics_vehicle_mileage
for each row
execute function public.set_logistics_vehicle_mileage_updated_at();

alter table public.logistics_vehicle_mileage enable row level security;

grant select, insert, update, delete
on public.logistics_vehicle_mileage
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_vehicle_mileage'
      and policyname = 'logistics_vehicle_mileage_authenticated_all'
  ) then
    create policy logistics_vehicle_mileage_authenticated_all
      on public.logistics_vehicle_mileage
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
