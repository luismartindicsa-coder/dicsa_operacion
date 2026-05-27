begin;

create table if not exists public.finanzas_bank_movements (
  id text primary key,
  movement_date timestamptz not null default now(),
  company text not null
    check (company in ('DICSA', 'VH')),
  branch text not null
    check (branch in ('CELAYA', 'MAZATLAN')),
  account_key text not null
    check (account_key in ('DICSA_CELAYA', 'DICSA_MAZATLAN', 'VH_CELAYA', 'VH_MAZATLAN')),
  counterparty_company_id text references public.finanzas_catalog_companies(id) on delete restrict,
  counterparty_name_snapshot text not null,
  category text not null
    check (category in (
      'VENTAS',
      'COMPRA DE MATERIAL',
      'GASTOS OPERATIVOS',
      'SERVICIOS',
      'GASTOS ADMINISTRATIVOS',
      'GASTOS FINANCIEROS',
      'NOMINA',
      'GASTOS PERSONALES',
      'MOVIMIENTOS INTERNOS',
      'AJUSTES',
      'OTROS'
    )),
  comment text,
  reference text,
  credit_amount numeric(14,2) not null default 0,
  debit_amount numeric(14,2) not null default 0,
  source_type text not null default 'MANUAL'
    check (source_type in ('MANUAL', 'COMPRA_FACTURA', 'VENTA_FACTURA')),
  linked_supplier_invoice_id text references public.finanzas_supplier_invoices(id) on delete restrict,
  linked_external_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_bank_movements_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_bank_movements_counterparty_trim_chk check (
    counterparty_name_snapshot = btrim(counterparty_name_snapshot) and length(counterparty_name_snapshot) > 0
  ),
  constraint finanzas_bank_movements_credit_debit_chk check (
    credit_amount >= 0 and debit_amount >= 0 and (credit_amount = 0 or debit_amount = 0)
  )
);

create index if not exists finanzas_bank_movements_date_idx
  on public.finanzas_bank_movements (movement_date desc);

create index if not exists finanzas_bank_movements_account_idx
  on public.finanzas_bank_movements (account_key, movement_date desc);

create index if not exists finanzas_bank_movements_counterparty_idx
  on public.finanzas_bank_movements (counterparty_company_id, movement_date desc);

drop trigger if exists trg_finanzas_bank_movements_updated_at on public.finanzas_bank_movements;
create trigger trg_finanzas_bank_movements_updated_at
before update on public.finanzas_bank_movements
for each row execute function public.set_updated_at_v2();

alter table public.finanzas_bank_movements enable row level security;
grant select, insert, update, delete on public.finanzas_bank_movements to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_bank_movements'
      and policyname = 'finanzas_bank_movements_authenticated_all'
  ) then
    create policy finanzas_bank_movements_authenticated_all
      on public.finanzas_bank_movements
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
