begin;

create table if not exists public.finanzas_catalog_companies (
  id text primary key,
  name text not null,
  source text not null default 'DIRECTO',
  linked_name text,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_catalog_companies_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_catalog_companies_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  ),
  constraint finanzas_catalog_companies_source_chk check (
    source in ('VENTAS', 'COMPRAS', 'DIRECTO')
  )
);

create table if not exists public.finanzas_catalog_concepts (
  id text primary key,
  name text not null,
  family text not null,
  direction text not null,
  requires_company boolean not null default true,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_catalog_concepts_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_catalog_concepts_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  ),
  constraint finanzas_catalog_concepts_family_chk check (
    family in ('AJUSTE', 'COBRO', 'GASTO', 'OTRO', 'PAGO', 'PRESTAMO')
  ),
  constraint finanzas_catalog_concepts_direction_chk check (
    direction in ('ENTRADA', 'SALIDA', 'AMBAS')
  )
);

create table if not exists public.finanzas_catalog_relations (
  id text primary key,
  company_id text not null references public.finanzas_catalog_companies(id) on delete cascade,
  concept_id text not null references public.finanzas_catalog_concepts(id) on delete cascade,
  mode text not null default 'MANUAL',
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_catalog_relations_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_catalog_relations_mode_chk check (
    mode in ('AUTOMATICA', 'MANUAL', 'MIXTA')
  )
);

drop trigger if exists trg_finanzas_catalog_companies_updated_at on public.finanzas_catalog_companies;
create trigger trg_finanzas_catalog_companies_updated_at
before update on public.finanzas_catalog_companies
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_finanzas_catalog_concepts_updated_at on public.finanzas_catalog_concepts;
create trigger trg_finanzas_catalog_concepts_updated_at
before update on public.finanzas_catalog_concepts
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_finanzas_catalog_relations_updated_at on public.finanzas_catalog_relations;
create trigger trg_finanzas_catalog_relations_updated_at
before update on public.finanzas_catalog_relations
for each row execute function public.set_updated_at_v2();

create unique index if not exists finanzas_catalog_companies_name_unique_idx
  on public.finanzas_catalog_companies (upper(name));

create unique index if not exists finanzas_catalog_concepts_name_unique_idx
  on public.finanzas_catalog_concepts (upper(name));

create unique index if not exists finanzas_catalog_relations_company_concept_unique_idx
  on public.finanzas_catalog_relations (company_id, concept_id);

alter table public.finanzas_catalog_companies enable row level security;
alter table public.finanzas_catalog_concepts enable row level security;
alter table public.finanzas_catalog_relations enable row level security;

grant select, insert, update, delete on public.finanzas_catalog_companies to authenticated;
grant select, insert, update, delete on public.finanzas_catalog_concepts to authenticated;
grant select, insert, update, delete on public.finanzas_catalog_relations to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_catalog_companies'
      and policyname = 'finanzas_catalog_companies_authenticated_all'
  ) then
    create policy finanzas_catalog_companies_authenticated_all
      on public.finanzas_catalog_companies
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_catalog_concepts'
      and policyname = 'finanzas_catalog_concepts_authenticated_all'
  ) then
    create policy finanzas_catalog_concepts_authenticated_all
      on public.finanzas_catalog_concepts
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_catalog_relations'
      and policyname = 'finanzas_catalog_relations_authenticated_all'
  ) then
    create policy finanzas_catalog_relations_authenticated_all
      on public.finanzas_catalog_relations
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
