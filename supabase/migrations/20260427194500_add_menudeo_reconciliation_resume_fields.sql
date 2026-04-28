begin;

alter table public.men_cash_cuts
  add column if not exists reconciliation_batch_index integer not null default 0;

alter table public.men_cash_cuts
  add column if not exists reconciliation_item_index integer not null default 0;

alter table public.men_cash_cuts
  add column if not exists reconciliation_focus_source_type text;

alter table public.men_cash_cuts
  add column if not exists reconciliation_focus_source_id text;

alter table public.men_cash_cuts
  add column if not exists reconciliation_focus_source_folio text;

alter table public.men_cash_cuts
  drop constraint if exists men_cash_cuts_status_chk;

alter table public.men_cash_cuts
  add constraint men_cash_cuts_status_chk
  check (status in ('ABIERTO', 'EN_CONCILIACION', 'CERRADO', 'CON_PENDIENTES'));

drop view if exists public.vw_men_cash_cuts_grid;

create view public.vw_men_cash_cuts_grid as
select
  c.id,
  c.cut_date,
  c.opened_at,
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
  c.reconciliation_batch_index,
  c.reconciliation_item_index,
  c.reconciliation_focus_source_type,
  c.reconciliation_focus_source_id,
  c.reconciliation_focus_source_folio,
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
order by coalesce(c.closed_at, c.opened_at) desc, c.opened_at desc;

comment on view public.vw_men_cash_cuts_grid is
  'Vista historica de bloques de caja de menudeo ordenada por cierre/apertura real, incluyendo cursor de reanudacion de conciliacion.';

grant select on public.vw_men_cash_cuts_grid to authenticated;

commit;
