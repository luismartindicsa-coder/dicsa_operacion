begin;

create table if not exists public.men_cash_cuts (
  id uuid primary key default gen_random_uuid(),
  cut_date date not null,
  opening_cash numeric(12,2) not null default 0,
  sales_total numeric(12,2) not null default 0,
  purchases_total numeric(12,2) not null default 0,
  deposits_total numeric(12,2) not null default 0,
  expenses_total numeric(12,2) not null default 0,
  theoretical_cash_total numeric(12,2) not null default 0,
  counted_cash_total numeric(12,2) not null default 0,
  difference_total numeric(12,2) not null default 0,
  pending_checks_count integer not null default 0,
  status text not null default 'ABIERTO',
  notes text not null default '',
  created_by text,
  closed_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint men_cash_cuts_cut_date_key unique (cut_date)
);

create index if not exists men_cash_cuts_cut_date_idx
  on public.men_cash_cuts (cut_date desc);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'men_cash_cuts_status_chk'
  ) then
    alter table public.men_cash_cuts
      add constraint men_cash_cuts_status_chk
      check (status in ('ABIERTO', 'CERRADO', 'CON_PENDIENTES'));
  end if;
end $$;

create table if not exists public.men_cash_cut_checks (
  id uuid primary key default gen_random_uuid(),
  cash_cut_id uuid not null references public.men_cash_cuts(id) on delete cascade,
  source_type text not null,
  source_id text,
  source_folio text not null default '',
  is_verified boolean not null default false,
  reason text not null default '',
  verified_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists men_cash_cut_checks_cut_idx
  on public.men_cash_cut_checks (cash_cut_id, is_verified, source_type);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'men_cash_cut_checks_source_type_chk'
  ) then
    alter table public.men_cash_cut_checks
      add constraint men_cash_cut_checks_source_type_chk
      check (source_type in ('expense_voucher', 'deposit_voucher', 'sale_ticket', 'purchase_ticket'));
  end if;
end $$;

create or replace function public.set_men_cash_cuts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_set_men_cash_cuts_updated_at on public.men_cash_cuts;
create trigger trg_set_men_cash_cuts_updated_at
before update on public.men_cash_cuts
for each row
execute function public.set_men_cash_cuts_updated_at();

drop trigger if exists trg_set_men_cash_cut_checks_updated_at on public.men_cash_cut_checks;
create trigger trg_set_men_cash_cut_checks_updated_at
before update on public.men_cash_cut_checks
for each row
execute function public.set_men_cash_cuts_updated_at();

create or replace view public.vw_men_cash_cuts_grid as
select
  c.id,
  c.cut_date,
  c.opening_cash,
  c.sales_total,
  c.purchases_total,
  c.deposits_total,
  c.expenses_total,
  c.theoretical_cash_total,
  c.counted_cash_total,
  c.difference_total,
  coalesce(p.pending_checks_count, c.pending_checks_count, 0) as pending_checks_count,
  c.status,
  c.notes,
  c.created_by,
  c.closed_at,
  c.created_at,
  c.updated_at
from public.men_cash_cuts c
left join (
  select
    cash_cut_id,
    count(*) filter (where is_verified is false) as pending_checks_count
  from public.men_cash_cut_checks
  group by cash_cut_id
) p on p.cash_cut_id = c.id
order by c.cut_date desc;

comment on table public.men_cash_cuts is
  'Resumen diario de caja de menudeo: apertura, movimientos del dia, total teorico, conteo real y diferencia.';

comment on table public.men_cash_cut_checks is
  'Detalle de comprobacion por ticket o voucher dentro del corte de caja de menudeo.';

comment on view public.vw_men_cash_cuts_grid is
  'Vista historica para grid de cortes de caja de menudeo.';

alter table public.men_cash_cuts enable row level security;
alter table public.men_cash_cut_checks enable row level security;

grant select, insert, update, delete on public.men_cash_cuts to authenticated;
grant select, insert, update, delete on public.men_cash_cut_checks to authenticated;
grant select on public.vw_men_cash_cuts_grid to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'men_cash_cuts'
      and policyname = 'men_cash_cuts_authenticated_all'
  ) then
    create policy men_cash_cuts_authenticated_all
      on public.men_cash_cuts
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'men_cash_cut_checks'
      and policyname = 'men_cash_cut_checks_authenticated_all'
  ) then
    create policy men_cash_cut_checks_authenticated_all
      on public.men_cash_cut_checks
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end $$;

commit;
