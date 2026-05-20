create table if not exists public.finanzas_company_directory (
  company_id text primary key references public.finanzas_catalog_companies (id) on delete cascade,
  company_name text not null,
  source text not null default 'DIRECTO',
  linked_name text,
  operational_contact text,
  phone text,
  location text,
  has_containers boolean not null default false,
  container_count integer not null default 0 check (container_count >= 0),
  credit_days integer not null default 0 check (credit_days >= 0),
  payment_stage text not null default 'AL_CORRIENTE',
  is_active boolean not null default true,
  payment_notes text,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists finanzas_company_directory_name_idx
on public.finanzas_company_directory (company_name);

create index if not exists finanzas_company_directory_stage_idx
on public.finanzas_company_directory (payment_stage, credit_days desc);

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'compras_provider_directory'
  ) then
    insert into public.finanzas_company_directory (
      company_id,
      company_name,
      source,
      linked_name,
      operational_contact,
      phone,
      location,
      has_containers,
      container_count,
      credit_days,
      payment_stage,
      is_active,
      payment_notes
    )
    select
      fc.id,
      fc.name,
      fc.source,
      fc.linked_name,
      coalesce(cpd.operational_contact, ''),
      coalesce(cpd.phone, ''),
      coalesce(cpd.location, ''),
      coalesce(cpd.has_containers, false),
      coalesce(cpd.container_count, 0),
      coalesce(cpd.credit_days, 0),
      coalesce(cpd.payment_stage, 'AL_CORRIENTE'),
      coalesce(fc.is_active, true),
      coalesce(cpd.payment_notes, '')
    from public.compras_provider_directory cpd
    join public.finanzas_catalog_companies fc
      on fc.source = 'COMPRAS'
     and fc.linked_name = cpd.provider_name
    on conflict (company_id) do update
      set company_name = excluded.company_name,
          source = excluded.source,
          linked_name = excluded.linked_name,
          operational_contact = excluded.operational_contact,
          phone = excluded.phone,
          location = excluded.location,
          has_containers = excluded.has_containers,
          container_count = excluded.container_count,
          credit_days = excluded.credit_days,
          payment_stage = excluded.payment_stage,
          is_active = excluded.is_active,
          payment_notes = excluded.payment_notes;
  end if;
end
$$;

create or replace function public.set_finanzas_company_directory_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists finanzas_company_directory_set_updated_at
on public.finanzas_company_directory;

create trigger finanzas_company_directory_set_updated_at
before update on public.finanzas_company_directory
for each row
execute function public.set_finanzas_company_directory_updated_at();
