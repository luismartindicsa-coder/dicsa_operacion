begin;

drop view if exists public.vw_men_tickets_grid;
create view public.vw_men_tickets_grid as
select
  t.id,
  t.split_batch_id,
  t.cash_cut_id,
  t.ticket_date,
  t.ticket_base,
  t.ticket_suffix,
  t.ticket_number,
  t.counterparty_id,
  t.counterparty_name_snapshot,
  t.price_id,
  t.general_material_id,
  t.commercial_material_id,
  t.material_alias_id,
  t.material_label_snapshot,
  t.price_at_entry,
  t.gross_weight,
  t.tare_weight,
  t.humidity_percent,
  t.trash_weight,
  t.premium_per_kg,
  t.net_weight,
  t.payable_weight,
  t.amount_total,
  t.status,
  t.comment,
  t.created_by,
  t.created_at,
  t.updated_at,
  t.direction,
  t.exit_order_number
from public.men_tickets t
order by t.ticket_date desc, t.ticket_number;

comment on view public.vw_men_tickets_grid is
  'Vista operativa para grid y detalle de tickets de menudeo, separable por direction y asociada a bloque de caja.';

grant select on public.vw_men_tickets_grid to authenticated;

commit;
