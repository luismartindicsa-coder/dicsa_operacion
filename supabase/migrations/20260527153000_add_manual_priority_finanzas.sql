alter table public.finanzas_company_directory
add column if not exists manual_priority text not null default 'NORMAL'
  check (manual_priority in ('NORMAL', 'ALTA', 'CRITICA'));

alter table public.finanzas_company_directory
add column if not exists priority_note text;

alter table public.finanzas_supplier_invoices
add column if not exists manual_priority text not null default 'NORMAL'
  check (manual_priority in ('NORMAL', 'ALTA', 'CRITICA'));

alter table public.finanzas_supplier_invoices
add column if not exists priority_note text;

create index if not exists finanzas_company_directory_manual_priority_idx
  on public.finanzas_company_directory (manual_priority);

create index if not exists finanzas_supplier_invoices_manual_priority_idx
  on public.finanzas_supplier_invoices (manual_priority);
