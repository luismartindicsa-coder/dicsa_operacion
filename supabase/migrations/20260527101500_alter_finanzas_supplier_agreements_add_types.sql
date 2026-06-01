begin;

alter table public.finanzas_supplier_agreements
  add column if not exists agreement_type text not null default 'POR_MONTO'
    check (agreement_type in ('POR_MONTO', 'POR_FACTURAS')),
  add column if not exists invoices_per_period integer not null default 0,
  add column if not exists scheduled_invoice_count integer not null default 0;

alter table public.finanzas_supplier_agreement_installments
  add column if not exists commitment_type text not null default 'MONTO'
    check (commitment_type in ('MONTO', 'FACTURAS')),
  add column if not exists scheduled_invoice_count integer not null default 0;

create table if not exists public.finanzas_supplier_agreement_invoices (
  id text primary key,
  agreement_id text not null references public.finanzas_supplier_agreements(id) on delete cascade,
  installment_id text references public.finanzas_supplier_agreement_installments(id) on delete cascade,
  invoice_id text not null references public.finanzas_supplier_invoices(id) on delete cascade,
  sequence_number integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_supplier_agreement_invoices_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_supplier_agreement_invoices_sequence_chk check (
    sequence_number > 0
  )
);

drop trigger if exists trg_finanzas_supplier_agreement_invoices_updated_at on public.finanzas_supplier_agreement_invoices;
create trigger trg_finanzas_supplier_agreement_invoices_updated_at
before update on public.finanzas_supplier_agreement_invoices
for each row execute function public.set_updated_at_v2();

create index if not exists finanzas_supplier_agreement_invoices_agreement_idx
  on public.finanzas_supplier_agreement_invoices (agreement_id, sequence_number);

create index if not exists finanzas_supplier_agreement_invoices_installment_idx
  on public.finanzas_supplier_agreement_invoices (installment_id);

create unique index if not exists finanzas_supplier_agreement_invoices_invoice_unique_idx
  on public.finanzas_supplier_agreement_invoices (invoice_id);

alter table public.finanzas_supplier_agreement_invoices enable row level security;

grant select, insert, update, delete on public.finanzas_supplier_agreement_invoices to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_supplier_agreement_invoices'
      and policyname = 'finanzas_supplier_agreement_invoices_authenticated_all'
  ) then
    create policy finanzas_supplier_agreement_invoices_authenticated_all
      on public.finanzas_supplier_agreement_invoices
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
