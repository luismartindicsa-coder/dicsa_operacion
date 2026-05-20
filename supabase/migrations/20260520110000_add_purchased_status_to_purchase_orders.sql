do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typnamespace = 'public'::regnamespace
      and t.typname = 'maintenance_purchase_order_status'
      and e.enumlabel = 'purchased'
  ) then
    alter type public.maintenance_purchase_order_status
      add value 'purchased';
  end if;
end
$$;

alter table public.maintenance_purchase_orders
  add column if not exists purchased_by uuid,
  add column if not exists purchased_by_name text,
  add column if not exists purchased_at timestamptz;

create or replace view public.v_maintenance_authorized_purchase_order_lines as
select
  pol.id as purchase_order_line_id,
  po.id as purchase_order_id,
  po.folio,
  po.order_date,
  po.target_label,
  po.quote_vendor_name,
  po.quote_vendor_type,
  pol.line_no,
  pol.line_type,
  pol.qty,
  pol.unit,
  pol.description,
  pol.amount,
  coalesce(
    pol.line_total,
    coalesce(pol.qty, 0) * coalesce(pol.amount, 0)
  ) as line_total,
  pol.notes
from public.maintenance_purchase_order_lines pol
join public.maintenance_purchase_orders po
  on po.id = pol.purchase_order_id
where po.status::text in ('authorized', 'purchased');
