begin;

create table if not exists public.logistics_diesel_consumption (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null,
  operator_employee_id uuid references public.employees(id) on delete set null,
  operator_name text not null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  vehicle_label text not null,
  liters_purchased numeric(12,2) not null default 0,
  liters_requested numeric(12,2) not null default 0,
  balance_liters numeric(12,2) generated always as (
    liters_purchased - liters_requested
  ) stored,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_diesel_operator_name_trim_chk check (
    operator_name = btrim(operator_name) and length(operator_name) > 0
  ),
  constraint logistics_diesel_vehicle_label_trim_chk check (
    vehicle_label = btrim(vehicle_label) and length(vehicle_label) > 0
  ),
  constraint logistics_diesel_purchased_nonnegative_chk check (
    liters_purchased >= 0
  ),
  constraint logistics_diesel_requested_nonnegative_chk check (
    liters_requested >= 0
  )
);

create index if not exists logistics_diesel_consumption_entry_date_idx
  on public.logistics_diesel_consumption (
    entry_date desc,
    created_at desc
  );

create index if not exists logistics_diesel_consumption_operator_idx
  on public.logistics_diesel_consumption (
    operator_employee_id,
    entry_date desc
  );

create index if not exists logistics_diesel_consumption_vehicle_idx
  on public.logistics_diesel_consumption (
    vehicle_id,
    entry_date desc
  );

create or replace function public.set_logistics_diesel_consumption_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_diesel_consumption_set_updated_at
on public.logistics_diesel_consumption;

create trigger logistics_diesel_consumption_set_updated_at
before update on public.logistics_diesel_consumption
for each row
execute function public.set_logistics_diesel_consumption_updated_at();

alter table public.logistics_diesel_consumption enable row level security;

grant select, insert, update, delete
on public.logistics_diesel_consumption
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_diesel_consumption'
      and policyname = 'logistics_diesel_consumption_authenticated_all'
  ) then
    create policy logistics_diesel_consumption_authenticated_all
      on public.logistics_diesel_consumption
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
