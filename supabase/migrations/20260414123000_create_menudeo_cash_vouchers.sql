begin;

create table if not exists public.men_cash_vouchers (
  id uuid primary key default gen_random_uuid(),
  voucher_date date not null,
  folio text not null,
  voucher_type text not null,
  person_label text not null,
  rubric text not null,
  comment text not null default '',
  total_amount numeric(12,2) not null default 0,
  created_by text,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create table if not exists public.men_cash_voucher_lines (
  id uuid primary key default gen_random_uuid(),
  voucher_id uuid not null references public.men_cash_vouchers(id) on delete cascade,
  line_order integer not null default 1,
  concept text not null,
  unit text not null default '',
  quantity text not null default '',
  company text not null default '',
  driver text not null default '',
  destination text not null default '',
  subconcept text not null default '',
  mode text not null default '',
  amount numeric(12,2) not null default 0,
  comment text not null default '',
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists men_cash_vouchers_date_idx
  on public.men_cash_vouchers (voucher_date desc, folio);

create index if not exists men_cash_vouchers_type_idx
  on public.men_cash_vouchers (voucher_type, voucher_date desc);

create index if not exists men_cash_voucher_lines_voucher_idx
  on public.men_cash_voucher_lines (voucher_id, line_order);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'men_cash_vouchers_type_chk'
  ) then
    alter table public.men_cash_vouchers
      add constraint men_cash_vouchers_type_chk
      check (voucher_type in ('deposit', 'expense'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'men_cash_vouchers_folio_trim_chk'
  ) then
    alter table public.men_cash_vouchers
      add constraint men_cash_vouchers_folio_trim_chk
      check (folio = btrim(folio) and length(folio) > 0);
  end if;
end $$;

create or replace function public.set_men_cash_vouchers_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_set_men_cash_vouchers_updated_at on public.men_cash_vouchers;
create trigger trg_set_men_cash_vouchers_updated_at
before update on public.men_cash_vouchers
for each row
execute function public.set_men_cash_vouchers_updated_at();

drop trigger if exists trg_set_men_cash_voucher_lines_updated_at on public.men_cash_voucher_lines;
create trigger trg_set_men_cash_voucher_lines_updated_at
before update on public.men_cash_voucher_lines
for each row
execute function public.set_men_cash_vouchers_updated_at();

create or replace view public.vw_men_cash_vouchers_grid as
with first_line as (
  select distinct on (l.voucher_id)
    l.voucher_id,
    l.concept
  from public.men_cash_voucher_lines l
  order by l.voucher_id, l.line_order asc, l.created_at asc
),
line_totals as (
  select
    l.voucher_id,
    count(*) as line_count,
    coalesce(sum(l.amount), 0) as line_total
  from public.men_cash_voucher_lines l
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
  v.created_by,
  v.created_at,
  v.updated_at
from public.men_cash_vouchers v
left join first_line fl on fl.voucher_id = v.id
left join line_totals lt on lt.voucher_id = v.id
order by v.voucher_date desc, folio_sort desc nulls last, v.folio desc;

comment on table public.men_cash_vouchers is
  'Encabezado de vouchers de depositos y gastos de menudeo.';

comment on table public.men_cash_voucher_lines is
  'Renglones detallados por concepto para cada voucher de depositos y gastos.';

comment on view public.vw_men_cash_vouchers_grid is
  'Vista resumida para grid operativo de vouchers de depositos y gastos.';

alter table public.men_cash_vouchers enable row level security;
alter table public.men_cash_voucher_lines enable row level security;

grant select, insert, update, delete on public.men_cash_vouchers to authenticated;
grant select, insert, update, delete on public.men_cash_voucher_lines to authenticated;
grant select on public.vw_men_cash_vouchers_grid to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'men_cash_vouchers'
      and policyname = 'men_cash_vouchers_authenticated_all'
  ) then
    create policy men_cash_vouchers_authenticated_all
      on public.men_cash_vouchers
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
      and tablename = 'men_cash_voucher_lines'
      and policyname = 'men_cash_voucher_lines_authenticated_all'
  ) then
    create policy men_cash_voucher_lines_authenticated_all
      on public.men_cash_voucher_lines
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end $$;

commit;
