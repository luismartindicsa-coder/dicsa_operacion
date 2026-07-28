begin;

create table if not exists public.direction_vault_vouchers (
  id text primary key,
  voucher_date date not null,
  folio text not null,
  voucher_type text not null,
  person_label text not null,
  rubric text not null,
  comment text not null default '',
  total_amount numeric(12,2) not null default 0,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint direction_vault_vouchers_id_trim_chk
    check (id = btrim(id) and length(id) > 0),
  constraint direction_vault_vouchers_folio_trim_chk
    check (folio = btrim(folio) and length(folio) > 0),
  constraint direction_vault_vouchers_person_trim_chk
    check (person_label = btrim(person_label) and length(person_label) > 0),
  constraint direction_vault_vouchers_rubric_trim_chk
    check (rubric = btrim(rubric) and length(rubric) > 0),
  constraint direction_vault_vouchers_type_chk
    check (voucher_type in ('deposit', 'expense'))
);

create table if not exists public.direction_vault_voucher_lines (
  id text primary key,
  voucher_id text not null references public.direction_vault_vouchers(id) on delete cascade,
  line_order integer not null default 1,
  concept text not null,
  unit text not null default '',
  quantity text not null default '',
  price text not null default '',
  company text not null default '',
  driver text not null default '',
  destination text not null default '',
  subconcept text not null default '',
  mode text not null default '',
  amount numeric(12,2) not null default 0,
  comment text not null default '',
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint direction_vault_voucher_lines_id_trim_chk
    check (id = btrim(id) and length(id) > 0)
);

create index if not exists direction_vault_vouchers_date_idx
  on public.direction_vault_vouchers (voucher_date desc, folio);

create index if not exists direction_vault_vouchers_type_idx
  on public.direction_vault_vouchers (voucher_type, voucher_date desc);

create index if not exists direction_vault_voucher_lines_voucher_idx
  on public.direction_vault_voucher_lines (voucher_id, line_order);

drop trigger if exists trg_direction_vault_vouchers_updated_at
  on public.direction_vault_vouchers;
create trigger trg_direction_vault_vouchers_updated_at
before update on public.direction_vault_vouchers
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_direction_vault_voucher_lines_updated_at
  on public.direction_vault_voucher_lines;
create trigger trg_direction_vault_voucher_lines_updated_at
before update on public.direction_vault_voucher_lines
for each row execute function public.set_updated_at_v2();

create or replace view public.vw_direction_vault_vouchers_grid as
with first_line as (
  select distinct on (l.voucher_id)
    l.voucher_id,
    l.concept
  from public.direction_vault_voucher_lines l
  order by l.voucher_id, l.line_order asc, l.created_at asc
),
line_totals as (
  select
    l.voucher_id,
    count(*) as line_count,
    coalesce(sum(l.amount), 0) as line_total
  from public.direction_vault_voucher_lines l
  group by l.voucher_id
)
select
  v.id,
  v.voucher_date,
  v.folio,
  v.voucher_type,
  v.person_label,
  v.rubric,
  v.comment,
  coalesce(lt.line_total, v.total_amount, 0) as total_amount,
  coalesce(lt.line_count, 0) as line_count,
  case
    when coalesce(lt.line_count, 0) <= 1 then coalesce(fl.concept, '')
    else coalesce(fl.concept, '') || ' +' || (lt.line_count - 1)::text
  end as concepts_preview,
  case
    when regexp_replace(v.folio, '[^0-9]', '', 'g') = '' then null
    else regexp_replace(v.folio, '[^0-9]', '', 'g')::bigint
  end as folio_sort,
  v.created_at,
  v.updated_at
from public.direction_vault_vouchers v
left join first_line fl on fl.voucher_id = v.id
left join line_totals lt on lt.voucher_id = v.id
order by v.voucher_date desc, folio_sort desc nulls last, v.folio desc;

comment on table public.direction_vault_vouchers is
  'Libro transaccional de movimientos de Boveda en Direccion.';

comment on table public.direction_vault_voucher_lines is
  'Renglones detallados por concepto para cada movimiento de Boveda.';

comment on view public.vw_direction_vault_vouchers_grid is
  'Vista resumida para grid operativo de Boveda.';

alter table public.direction_vault_vouchers enable row level security;
alter table public.direction_vault_voucher_lines enable row level security;

grant select, insert, update, delete on public.direction_vault_vouchers to authenticated;
grant select, insert, update, delete on public.direction_vault_voucher_lines to authenticated;
grant select on public.vw_direction_vault_vouchers_grid to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'direction_vault_vouchers'
      and policyname = 'direction_vault_vouchers_authenticated_all'
  ) then
    create policy direction_vault_vouchers_authenticated_all
      on public.direction_vault_vouchers
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'direction_vault_voucher_lines'
      and policyname = 'direction_vault_voucher_lines_authenticated_all'
  ) then
    create policy direction_vault_voucher_lines_authenticated_all
      on public.direction_vault_voucher_lines
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end $$;

with source_rows as (
  select row_payload
  from public.cash_taxonomy_configs c
  cross join lateral jsonb_array_elements(
    coalesce(c.payload -> 'rows', '[]'::jsonb)
  ) as row_payload
  where c.area = 'direccion_boveda_vouchers'
),
normalized_vouchers as (
  select
    coalesce(
      nullif(btrim(row_payload ->> 'id'), ''),
      'dir-vault-' || substr(md5(row_payload::text), 1, 24)
    ) as id,
    case
      when coalesce(row_payload ->> 'date', '') ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' then
        to_date(row_payload ->> 'date', 'DD/MM/YYYY')
      else
        coalesce((row_payload ->> 'date')::date, current_date)
    end as voucher_date,
    coalesce(nullif(btrim(row_payload ->> 'folio'), ''), 'SIN-FOLIO') as folio,
    case
      when coalesce(row_payload ->> 'type', '') = 'deposit' then 'deposit'
      else 'expense'
    end as voucher_type,
    coalesce(nullif(btrim(row_payload ->> 'person'), ''), 'SIN PERSONA') as person_label,
    coalesce(nullif(btrim(row_payload ->> 'rubric'), ''), 'Sin rubro') as rubric,
    coalesce(row_payload ->> 'comment', '') as comment,
    coalesce((
      select sum(
        coalesce(nullif(btrim(line_payload ->> 'amount'), ''), '0')::numeric
      )
      from jsonb_array_elements(coalesce(row_payload -> 'lines', '[]'::jsonb)) line_payload
    ), 0)::numeric(12,2) as total_amount
  from source_rows
),
normalized_lines as (
  select
    coalesce(
      nullif(btrim(row_payload ->> 'id'), ''),
      'dir-vault-' || substr(md5(row_payload::text), 1, 24)
    ) as voucher_id,
    line_payload,
    ordinality::integer as line_order
  from source_rows
  cross join lateral jsonb_array_elements(
    coalesce(row_payload -> 'lines', '[]'::jsonb)
  ) with ordinality as lines(line_payload, ordinality)
)
insert into public.direction_vault_vouchers (
  id,
  voucher_date,
  folio,
  voucher_type,
  person_label,
  rubric,
  comment,
  total_amount
)
select
  id,
  voucher_date,
  folio,
  voucher_type,
  person_label,
  rubric,
  comment,
  total_amount
from normalized_vouchers
on conflict (id) do nothing;

with source_rows as (
  select row_payload
  from public.cash_taxonomy_configs c
  cross join lateral jsonb_array_elements(
    coalesce(c.payload -> 'rows', '[]'::jsonb)
  ) as row_payload
  where c.area = 'direccion_boveda_vouchers'
),
normalized_lines as (
  select
    coalesce(
      nullif(btrim(row_payload ->> 'id'), ''),
      'dir-vault-' || substr(md5(row_payload::text), 1, 24)
    ) as voucher_id,
    line_payload,
    ordinality::integer as line_order
  from source_rows
  cross join lateral jsonb_array_elements(
    coalesce(row_payload -> 'lines', '[]'::jsonb)
  ) with ordinality as lines(line_payload, ordinality)
)
insert into public.direction_vault_voucher_lines (
  id,
  voucher_id,
  line_order,
  concept,
  unit,
  quantity,
  price,
  company,
  driver,
  destination,
  subconcept,
  mode,
  amount,
  comment
)
select
  voucher_id || '-line-' || line_order::text as id,
  voucher_id,
  line_order,
  coalesce(line_payload ->> 'concept', '') as concept,
  coalesce(line_payload ->> 'unit', '') as unit,
  coalesce(line_payload ->> 'quantity', '') as quantity,
  coalesce(line_payload ->> 'price', '') as price,
  coalesce(line_payload ->> 'company', '') as company,
  coalesce(line_payload ->> 'driver', '') as driver,
  coalesce(line_payload ->> 'destination', '') as destination,
  coalesce(line_payload ->> 'subconcept', '') as subconcept,
  coalesce(line_payload ->> 'mode', '') as mode,
  coalesce(nullif(btrim(line_payload ->> 'amount'), ''), '0')::numeric(12,2) as amount,
  coalesce(line_payload ->> 'comment', '') as comment
from normalized_lines
on conflict (id) do nothing;

commit;
