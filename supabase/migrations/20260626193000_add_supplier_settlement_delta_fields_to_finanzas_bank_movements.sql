alter table public.finanzas_bank_movements
add column if not exists applied_supplier_amount numeric(14,2);

alter table public.finanzas_bank_movements
add column if not exists settlement_difference_amount numeric(14,2) not null default 0;

alter table public.finanzas_bank_movements
add column if not exists settlement_difference_reason text;

alter table public.finanzas_bank_movements
add column if not exists settlement_difference_note text;

alter table public.finanzas_bank_movements
drop constraint if exists finanzas_bank_movements_supplier_delta_chk;

alter table public.finanzas_bank_movements
add constraint finanzas_bank_movements_supplier_delta_chk
check (
  (
    source_type = 'COMPRA_FACTURA'
    and linked_supplier_invoice_id is not null
  )
  or (
    applied_supplier_amount is null
    and coalesce(settlement_difference_amount, 0) = 0
    and settlement_difference_reason is null
    and settlement_difference_note is null
  )
);
