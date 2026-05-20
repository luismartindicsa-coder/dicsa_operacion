alter table public.maintenance_purchase_orders
  add column if not exists estimated_total numeric(12,2),
  add column if not exists actual_total numeric(12,2),
  add column if not exists actual_total_by uuid,
  add column if not exists actual_total_by_name text,
  add column if not exists actual_total_at timestamptz;

update public.maintenance_purchase_orders po
set estimated_total = totals.estimated_total
from (
  select
    pol.purchase_order_id,
    round(
      sum(
        coalesce(
          pol.line_total,
          coalesce(pol.qty, 0) * coalesce(pol.amount, 0)
        )
      )::numeric,
      2
    ) as estimated_total
  from public.maintenance_purchase_order_lines pol
  group by pol.purchase_order_id
) totals
where po.id = totals.purchase_order_id
  and po.estimated_total is null;
