alter table public.maintenance_purchase_orders
  add column if not exists linked_ot_id uuid references public.maintenance_orders(id) on delete set null,
  add column if not exists linked_ot_folio text,
  add column if not exists linked_material_label text,
  add column if not exists generated_from_ot boolean not null default false;

create index if not exists maintenance_purchase_orders_linked_ot_idx
  on public.maintenance_purchase_orders (linked_ot_id);
