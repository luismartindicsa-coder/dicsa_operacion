begin;

alter table public.inventory_movements_v2
  add column if not exists source_commercial_material_id uuid references public.material_commercial_catalog_v2(id) on delete restrict,
  add column if not exists gross_kg numeric(14,3),
  add column if not exists tare_kg numeric(14,3),
  add column if not exists net_kg numeric(14,3),
  add column if not exists humidity_percent numeric(8,3),
  add column if not exists trash_kg numeric(14,3),
  add column if not exists total_amount_kg numeric(14,3),
  add column if not exists driver_employee_id uuid,
  add column if not exists vehicle_id uuid,
  add column if not exists scale_ticket text,
  add column if not exists movement_reason text;

create index if not exists inventory_movements_v2_source_commercial_idx
  on public.inventory_movements_v2 (source_commercial_material_id);

commit;
