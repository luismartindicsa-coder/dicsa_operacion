alter table public.finanzas_fixed_payments
add column if not exists execution_method text
  check (execution_method in ('BANCO', 'EFECTIVO'));

alter table public.finanzas_fixed_payments
add column if not exists linked_bank_movement_id text references public.finanzas_bank_movements(id) on delete set null;

alter table public.finanzas_fixed_payments
add column if not exists settled_at timestamptz;

create index if not exists finanzas_fixed_payments_execution_method_idx
  on public.finanzas_fixed_payments (execution_method);

create index if not exists finanzas_fixed_payments_linked_bank_movement_idx
  on public.finanzas_fixed_payments (linked_bank_movement_id);

alter table public.finanzas_bank_movements
add column if not exists linked_fixed_payment_id text references public.finanzas_fixed_payments(id) on delete set null;

alter table public.finanzas_bank_movements
drop constraint if exists finanzas_bank_movements_source_type_check;

alter table public.finanzas_bank_movements
add constraint finanzas_bank_movements_source_type_check
check (source_type in ('MANUAL', 'COMPRA_FACTURA', 'VENTA_FACTURA', 'PAGO_FIJO'));

create index if not exists finanzas_bank_movements_linked_fixed_payment_idx
  on public.finanzas_bank_movements (linked_fixed_payment_id);
