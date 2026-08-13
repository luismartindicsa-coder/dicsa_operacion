alter table public.maintenance_orders
  add column if not exists category_snapshot text;

comment on column public.maintenance_orders.category_snapshot is
  'Snapshot textual de la especialidad seleccionada en la OT cuando proviene del directorio operativo.';
