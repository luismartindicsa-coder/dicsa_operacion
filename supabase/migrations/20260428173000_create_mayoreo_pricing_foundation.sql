begin;

create table if not exists public.mayoreo_counterparties (
  id text primary key,
  code text not null,
  name text not null,
  contact text,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mayoreo_counterparties_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint mayoreo_counterparties_code_trim_chk check (
    code = btrim(code) and length(code) > 0
  ),
  constraint mayoreo_counterparties_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  )
);

create table if not exists public.mayoreo_material_catalog (
  id text primary key,
  code text not null,
  level text not null,
  name text not null,
  unit text not null default 'KG',
  category text not null,
  family text,
  general_material_id text references public.mayoreo_material_catalog(id) on delete restrict,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mayoreo_material_catalog_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint mayoreo_material_catalog_code_trim_chk check (
    code = btrim(code) and length(code) > 0
  ),
  constraint mayoreo_material_catalog_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  ),
  constraint mayoreo_material_catalog_level_chk check (
    level in ('GENERAL', 'COMERCIAL')
  ),
  constraint mayoreo_material_catalog_category_trim_chk check (
    category = btrim(category) and length(category) > 0
  ),
  constraint mayoreo_material_catalog_general_link_chk check (
    (level = 'GENERAL' and general_material_id is null) or
    (level = 'COMERCIAL' and general_material_id is not null)
  )
);

create table if not exists public.mayoreo_counterparty_material_prices (
  id text primary key,
  company_id text not null references public.mayoreo_counterparties(id) on delete cascade,
  material_id text not null references public.mayoreo_material_catalog(id) on delete cascade,
  final_price numeric(14,4) not null,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mayoreo_counterparty_material_prices_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint mayoreo_counterparty_material_prices_positive_chk check (
    final_price >= 0
  )
);

create table if not exists public.mayoreo_price_adjustment_history (
  id text primary key,
  price_id text not null references public.mayoreo_counterparty_material_prices(id) on delete cascade,
  company_id text references public.mayoreo_counterparties(id) on delete set null,
  company_name_snapshot text not null,
  material_id text references public.mayoreo_material_catalog(id) on delete set null,
  material_name_snapshot text not null,
  previous_price numeric(14,4) not null,
  new_price numeric(14,4) not null,
  reason text,
  created_at timestamptz not null default now(),
  constraint mayoreo_price_adjustment_history_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  )
);

drop trigger if exists trg_mayoreo_counterparties_updated_at on public.mayoreo_counterparties;
create trigger trg_mayoreo_counterparties_updated_at
before update on public.mayoreo_counterparties
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_mayoreo_material_catalog_updated_at on public.mayoreo_material_catalog;
create trigger trg_mayoreo_material_catalog_updated_at
before update on public.mayoreo_material_catalog
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_mayoreo_counterparty_material_prices_updated_at on public.mayoreo_counterparty_material_prices;
create trigger trg_mayoreo_counterparty_material_prices_updated_at
before update on public.mayoreo_counterparty_material_prices
for each row execute function public.set_updated_at_v2();

create or replace function public.log_mayoreo_price_history()
returns trigger
language plpgsql
as $$
declare
  v_company_name text;
  v_material_name text;
  v_reason text;
begin
  select name into v_company_name
  from public.mayoreo_counterparties
  where id = new.company_id;

  select name into v_material_name
  from public.mayoreo_material_catalog
  where id = new.material_id;

  if tg_op = 'INSERT' then
    v_reason := coalesce(nullif(btrim(new.notes), ''), 'ALTA INICIAL');
    insert into public.mayoreo_price_adjustment_history (
      id,
      price_id,
      company_id,
      company_name_snapshot,
      material_id,
      material_name_snapshot,
      previous_price,
      new_price,
      reason,
      created_at
    ) values (
      'hist_' || replace(gen_random_uuid()::text, '-', ''),
      new.id,
      new.company_id,
      coalesce(v_company_name, ''),
      new.material_id,
      coalesce(v_material_name, ''),
      0,
      new.final_price,
      v_reason,
      now()
    );
    return new;
  end if;

  if new.final_price is distinct from old.final_price
     or new.is_active is distinct from old.is_active
     or coalesce(new.notes, '') is distinct from coalesce(old.notes, '') then
    v_reason := coalesce(nullif(btrim(new.notes), ''), 'AJUSTE MANUAL');
    insert into public.mayoreo_price_adjustment_history (
      id,
      price_id,
      company_id,
      company_name_snapshot,
      material_id,
      material_name_snapshot,
      previous_price,
      new_price,
      reason,
      created_at
    ) values (
      'hist_' || replace(gen_random_uuid()::text, '-', ''),
      new.id,
      new.company_id,
      coalesce(v_company_name, ''),
      new.material_id,
      coalesce(v_material_name, ''),
      old.final_price,
      new.final_price,
      v_reason,
      now()
    );
  end if;

  return new;
end
$$;

drop trigger if exists trg_mayoreo_counterparty_material_prices_history on public.mayoreo_counterparty_material_prices;
create trigger trg_mayoreo_counterparty_material_prices_history
after insert or update on public.mayoreo_counterparty_material_prices
for each row execute function public.log_mayoreo_price_history();

create unique index if not exists mayoreo_counterparties_name_unique_idx
  on public.mayoreo_counterparties (upper(name));

create unique index if not exists mayoreo_material_catalog_code_level_unique_idx
  on public.mayoreo_material_catalog (upper(code), level);

create unique index if not exists mayoreo_material_catalog_name_level_unique_idx
  on public.mayoreo_material_catalog (upper(name), level);

create unique index if not exists mayoreo_counterparty_material_prices_company_material_unique_idx
  on public.mayoreo_counterparty_material_prices (company_id, material_id);

create index if not exists mayoreo_counterparty_material_prices_company_idx
  on public.mayoreo_counterparty_material_prices (company_id, is_active, updated_at desc);

create index if not exists mayoreo_counterparty_material_prices_material_idx
  on public.mayoreo_counterparty_material_prices (material_id, is_active);

create index if not exists mayoreo_price_adjustment_history_price_idx
  on public.mayoreo_price_adjustment_history (price_id, created_at desc);

alter table public.mayoreo_counterparties enable row level security;
alter table public.mayoreo_material_catalog enable row level security;
alter table public.mayoreo_counterparty_material_prices enable row level security;
alter table public.mayoreo_price_adjustment_history enable row level security;

grant select, insert, update, delete on public.mayoreo_counterparties to authenticated;
grant select, insert, update, delete on public.mayoreo_material_catalog to authenticated;
grant select, insert, update, delete on public.mayoreo_counterparty_material_prices to authenticated;
grant select on public.mayoreo_price_adjustment_history to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_counterparties'
      and policyname = 'mayoreo_counterparties_authenticated_all'
  ) then
    create policy mayoreo_counterparties_authenticated_all
      on public.mayoreo_counterparties
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_material_catalog'
      and policyname = 'mayoreo_material_catalog_authenticated_all'
  ) then
    create policy mayoreo_material_catalog_authenticated_all
      on public.mayoreo_material_catalog
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_counterparty_material_prices'
      and policyname = 'mayoreo_counterparty_material_prices_authenticated_all'
  ) then
    create policy mayoreo_counterparty_material_prices_authenticated_all
      on public.mayoreo_counterparty_material_prices
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_price_adjustment_history'
      and policyname = 'mayoreo_price_adjustment_history_authenticated_read'
  ) then
    create policy mayoreo_price_adjustment_history_authenticated_read
      on public.mayoreo_price_adjustment_history
      for select
      to authenticated
      using (true);
  end if;
end
$$;

create or replace view public.vw_mayoreo_price_audit_catalog as
select
  price.id as price_id,
  price.company_id,
  cp.name as company_name,
  price.material_id,
  mat.name as material_name,
  mat.level as material_level,
  mat.category,
  mat.family,
  mat.general_material_id,
  gen.name as general_material_name,
  price.final_price,
  price.is_active,
  price.notes,
  price.created_at,
  price.updated_at
from public.mayoreo_counterparty_material_prices price
join public.mayoreo_counterparties cp on cp.id = price.company_id
join public.mayoreo_material_catalog mat on mat.id = price.material_id
left join public.mayoreo_material_catalog gen on gen.id = mat.general_material_id;

create or replace view public.vw_mayoreo_price_adjustment_history as
select
  hist.id,
  hist.price_id,
  hist.company_id,
  hist.company_name_snapshot as company_name,
  hist.material_id,
  hist.material_name_snapshot as material_name,
  hist.previous_price,
  hist.new_price,
  hist.reason,
  hist.created_at
from public.mayoreo_price_adjustment_history hist;

grant select on public.vw_mayoreo_price_audit_catalog to authenticated;
grant select on public.vw_mayoreo_price_adjustment_history to authenticated;

commit;
