alter table public.maintenance_purchase_orders
  add column if not exists sent_to_cash_by uuid,
  add column if not exists sent_to_cash_by_name text,
  add column if not exists sent_to_cash_at timestamptz;
