alter table public.finanzas_supplier_invoices
add column if not exists origin_type text not null default 'TICKETS'
  check (origin_type in ('TICKETS', 'MANUAL'));

update public.finanzas_supplier_invoices
set origin_type = 'TICKETS'
where origin_type is null
   or origin_type not in ('TICKETS', 'MANUAL');

create index if not exists finanzas_supplier_invoices_origin_type_idx
  on public.finanzas_supplier_invoices (origin_type);
