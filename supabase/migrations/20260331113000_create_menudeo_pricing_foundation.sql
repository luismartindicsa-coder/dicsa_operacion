begin;

create table if not exists public.men_counterparties (
  id uuid primary key default gen_random_uuid(),
  site_id uuid references public.sites(id) on delete set null,
  name text not null,
  kind text not null default 'supplier',
  group_code text not null default 'general',
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint men_counterparties_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  ),
  constraint men_counterparties_kind_chk check (
    kind in ('supplier', 'customer', 'both')
  ),
  constraint men_counterparties_group_trim_chk check (
    group_code = btrim(group_code) and length(group_code) > 0
  )
);

create table if not exists public.men_material_aliases (
  id uuid primary key default gen_random_uuid(),
  general_material_id uuid references public.material_general_catalog_v2(id) on delete set null,
  commercial_material_id uuid references public.material_commercial_catalog_v2(id) on delete set null,
  label text not null,
  normalized_label text not null,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint men_material_aliases_label_trim_chk check (
    label = btrim(label) and length(label) > 0
  ),
  constraint men_material_aliases_normalized_trim_chk check (
    normalized_label = btrim(normalized_label) and length(normalized_label) > 0
  ),
  constraint men_material_aliases_target_chk check (
    general_material_id is not null or commercial_material_id is not null
  )
);

create table if not exists public.men_counterparty_material_prices (
  id uuid primary key default gen_random_uuid(),
  counterparty_id uuid not null references public.men_counterparties(id) on delete cascade,
  general_material_id uuid references public.material_general_catalog_v2(id) on delete set null,
  commercial_material_id uuid references public.material_commercial_catalog_v2(id) on delete set null,
  material_alias_id uuid references public.men_material_aliases(id) on delete set null,
  material_label_snapshot text not null,
  final_price numeric(14,4) not null,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint men_counterparty_material_prices_label_trim_chk check (
    material_label_snapshot = btrim(material_label_snapshot)
    and length(material_label_snapshot) > 0
  ),
  constraint men_counterparty_material_prices_positive_chk check (
    final_price >= 0
  ),
  constraint men_counterparty_material_prices_target_chk check (
    general_material_id is not null
    or commercial_material_id is not null
    or material_alias_id is not null
  )
);

create or replace function public.set_men_normalized_label()
returns trigger
language plpgsql
as $$
begin
  new.label := btrim(new.label);
  new.normalized_label := upper(regexp_replace(new.label, '\s+', ' ', 'g'));
  return new;
end
$$;

create or replace function public.set_men_price_snapshot()
returns trigger
language plpgsql
as $$
begin
  new.material_label_snapshot := btrim(new.material_label_snapshot);

  if new.material_label_snapshot = '' then
    raise exception 'El material es obligatorio';
  end if;

  return new;
end
$$;

drop trigger if exists trg_men_counterparties_updated_at on public.men_counterparties;
create trigger trg_men_counterparties_updated_at
before update on public.men_counterparties
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_men_material_aliases_normalized on public.men_material_aliases;
create trigger trg_men_material_aliases_normalized
before insert or update on public.men_material_aliases
for each row execute function public.set_men_normalized_label();

drop trigger if exists trg_men_material_aliases_updated_at on public.men_material_aliases;
create trigger trg_men_material_aliases_updated_at
before update on public.men_material_aliases
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_men_counterparty_material_prices_snapshot on public.men_counterparty_material_prices;
create trigger trg_men_counterparty_material_prices_snapshot
before insert or update on public.men_counterparty_material_prices
for each row execute function public.set_men_price_snapshot();

drop trigger if exists trg_men_counterparty_material_prices_updated_at on public.men_counterparty_material_prices;
create trigger trg_men_counterparty_material_prices_updated_at
before update on public.men_counterparty_material_prices
for each row execute function public.set_updated_at_v2();

create unique index if not exists men_counterparties_site_name_unique_idx
  on public.men_counterparties (
    coalesce(site_id, '00000000-0000-0000-0000-000000000000'::uuid),
    upper(name)
  );

create index if not exists men_counterparties_kind_group_idx
  on public.men_counterparties (kind, group_code, is_active);

create unique index if not exists men_material_aliases_label_unique_idx
  on public.men_material_aliases (normalized_label);

create index if not exists men_counterparty_material_prices_counterparty_idx
  on public.men_counterparty_material_prices (counterparty_id, is_active, created_at desc);

create index if not exists men_counterparty_material_prices_general_idx
  on public.men_counterparty_material_prices (general_material_id, is_active);

create index if not exists men_counterparty_material_prices_commercial_idx
  on public.men_counterparty_material_prices (commercial_material_id, is_active);

alter table public.men_counterparties enable row level security;
alter table public.men_material_aliases enable row level security;
alter table public.men_counterparty_material_prices enable row level security;

grant select, insert, update, delete on public.men_counterparties to authenticated;
grant select, insert, update, delete on public.men_material_aliases to authenticated;
grant select, insert, update, delete on public.men_counterparty_material_prices to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'men_counterparties'
      and policyname = 'men_counterparties_authenticated_all'
  ) then
    create policy men_counterparties_authenticated_all
      on public.men_counterparties
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'men_material_aliases'
      and policyname = 'men_material_aliases_authenticated_all'
  ) then
    create policy men_material_aliases_authenticated_all
      on public.men_material_aliases
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'men_counterparty_material_prices'
      and policyname = 'men_counterparty_material_prices_authenticated_all'
  ) then
    create policy men_counterparty_material_prices_authenticated_all
      on public.men_counterparty_material_prices
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

create or replace view public.vw_men_counterparty_price_catalog as
select
  cp.id as counterparty_id,
  cp.site_id,
  cp.name as counterparty_name,
  cp.kind,
  cp.group_code,
  cp.is_active as counterparty_active,
  price.id as price_id,
  price.general_material_id,
  gen.code as general_material_code,
  gen.name as general_material_name,
  price.commercial_material_id,
  com.code as commercial_material_code,
  com.name as commercial_material_name,
  price.material_alias_id,
  alias.label as material_alias_label,
  price.material_label_snapshot,
  price.final_price,
  price.is_active as price_active,
  price.notes,
  price.created_at,
  price.updated_at
from public.men_counterparties cp
left join public.men_counterparty_material_prices price
  on price.counterparty_id = cp.id
left join public.material_general_catalog_v2 gen
  on gen.id = price.general_material_id
left join public.material_commercial_catalog_v2 com
  on com.id = price.commercial_material_id
left join public.men_material_aliases alias
  on alias.id = price.material_alias_id;

grant select on public.vw_men_counterparty_price_catalog to authenticated;

commit;
