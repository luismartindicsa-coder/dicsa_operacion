create table if not exists public.compras_provider_directory (
  provider_id text primary key references public.compras_counterparties (id) on delete cascade,
  provider_code text not null,
  provider_name text not null,
  catalog_contact text,
  operational_contact text,
  phone text,
  location text,
  has_containers boolean not null default false,
  container_count integer not null default 0 check (container_count >= 0),
  credit_days integer not null default 0 check (credit_days >= 0),
  critical_supplier boolean not null default false,
  is_active boolean not null default true,
  payment_notes text,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists compras_provider_directory_name_idx
on public.compras_provider_directory (provider_name);

create index if not exists compras_provider_directory_credit_idx
on public.compras_provider_directory (credit_days desc, critical_supplier desc);

create or replace function public.set_compras_provider_directory_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists compras_provider_directory_set_updated_at
on public.compras_provider_directory;

create trigger compras_provider_directory_set_updated_at
before update on public.compras_provider_directory
for each row
execute function public.set_compras_provider_directory_updated_at();
