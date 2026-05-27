begin;

create table if not exists public.finanzas_supplier_invoices (
  id text primary key,
  provider_id text not null references public.finanzas_catalog_companies(id) on delete restrict,
  provider_name_snapshot text not null,
  invoice_folio text not null,
  invoice_date timestamptz not null default now(),
  due_date timestamptz,
  total_amount numeric(14,2) not null default 0,
  balance_amount numeric(14,2) not null default 0,
  status text not null default 'PENDIENTE'
    check (status in ('PENDIENTE', 'PARCIAL', 'PAGADA', 'VENCIDA', 'CONVENIO')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_supplier_invoices_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_supplier_invoices_folio_trim_chk check (
    invoice_folio = btrim(invoice_folio) and length(invoice_folio) > 0
  )
);

create table if not exists public.finanzas_supplier_invoice_tickets (
  id text primary key,
  invoice_id text not null references public.finanzas_supplier_invoices(id) on delete cascade,
  ticket_id text not null references public.compras_tickets(id) on delete cascade,
  applied_amount numeric(14,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_supplier_invoice_tickets_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  )
);

drop trigger if exists trg_finanzas_supplier_invoices_updated_at on public.finanzas_supplier_invoices;
create trigger trg_finanzas_supplier_invoices_updated_at
before update on public.finanzas_supplier_invoices
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_finanzas_supplier_invoice_tickets_updated_at on public.finanzas_supplier_invoice_tickets;
create trigger trg_finanzas_supplier_invoice_tickets_updated_at
before update on public.finanzas_supplier_invoice_tickets
for each row execute function public.set_updated_at_v2();

create index if not exists finanzas_supplier_invoices_provider_idx
  on public.finanzas_supplier_invoices (provider_id, invoice_date desc);

create unique index if not exists finanzas_supplier_invoices_provider_folio_unique_idx
  on public.finanzas_supplier_invoices (provider_id, upper(invoice_folio));

create unique index if not exists finanzas_supplier_invoice_tickets_ticket_unique_idx
  on public.finanzas_supplier_invoice_tickets (ticket_id);

create index if not exists finanzas_supplier_invoice_tickets_invoice_idx
  on public.finanzas_supplier_invoice_tickets (invoice_id);

alter table public.finanzas_supplier_invoices enable row level security;
alter table public.finanzas_supplier_invoice_tickets enable row level security;

grant select, insert, update, delete on public.finanzas_supplier_invoices to authenticated;
grant select, insert, update, delete on public.finanzas_supplier_invoice_tickets to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_supplier_invoices'
      and policyname = 'finanzas_supplier_invoices_authenticated_all'
  ) then
    create policy finanzas_supplier_invoices_authenticated_all
      on public.finanzas_supplier_invoices
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_supplier_invoice_tickets'
      and policyname = 'finanzas_supplier_invoice_tickets_authenticated_all'
  ) then
    create policy finanzas_supplier_invoice_tickets_authenticated_all
      on public.finanzas_supplier_invoice_tickets
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
