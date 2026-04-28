begin;

create table if not exists public.mayoreo_accounts (
  id text primary key,
  ticket text not null,
  sale_date timestamptz not null,
  client_id text references public.mayoreo_counterparties(id) on delete set null,
  client_name_snapshot text not null,
  remision text not null default '',
  material_name_snapshot text not null,
  approved_weight numeric(14,4) not null default 0,
  approved_price numeric(14,4) not null default 0,
  approved_amount numeric(14,4) not null default 0,
  operation_type text not null default 'factura',
  sale_notes text,
  document_number text not null default '',
  document_date timestamptz,
  estimated_payment_date timestamptz,
  settlement_date timestamptz,
  status text not null default 'porRevisar',
  financial_notes text,
  paid_amount numeric(14,4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mayoreo_palomar_movements (
  id text primary key,
  created_at timestamptz not null default now(),
  date timestamptz not null,
  type text not null,
  reference text not null default '',
  check_number text not null default '',
  remision text not null default '',
  ticket text not null default '',
  client_name_snapshot text not null default '',
  material_name_snapshot text not null default '',
  exit_weight numeric(14,4),
  approved_weight numeric(14,4),
  approved_price numeric(14,4),
  amount numeric(14,4) not null default 0,
  notes text,
  bank_reference text,
  source_report_id text references public.mayoreo_sales_reports(id) on delete set null,
  period_start timestamptz,
  period_end timestamptz,
  period_opening_balance numeric(14,4),
  period_closing_balance numeric(14,4),
  period_checks_total numeric(14,4),
  period_applied_total numeric(14,4),
  period_adjustments_total numeric(14,4)
);

create table if not exists public.mayoreo_pending_items (
  id text primary key,
  title text not null,
  due_date timestamptz not null,
  source text not null default 'VENTAS',
  is_done boolean not null default false,
  detail text,
  is_system_generated boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_mayoreo_accounts_updated_at on public.mayoreo_accounts;
create trigger trg_mayoreo_accounts_updated_at
before update on public.mayoreo_accounts
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_mayoreo_pending_items_updated_at on public.mayoreo_pending_items;
create trigger trg_mayoreo_pending_items_updated_at
before update on public.mayoreo_pending_items
for each row execute function public.set_updated_at_v2();

create index if not exists mayoreo_accounts_sale_date_idx
  on public.mayoreo_accounts (sale_date desc, updated_at desc);
create index if not exists mayoreo_accounts_client_idx
  on public.mayoreo_accounts (client_id, sale_date desc);
create index if not exists mayoreo_palomar_movements_date_idx
  on public.mayoreo_palomar_movements (date asc, created_at asc);
create index if not exists mayoreo_pending_items_due_date_idx
  on public.mayoreo_pending_items (due_date asc, is_done, source);

alter table public.mayoreo_accounts enable row level security;
alter table public.mayoreo_palomar_movements enable row level security;
alter table public.mayoreo_pending_items enable row level security;

grant select, insert, update, delete on public.mayoreo_accounts to authenticated;
grant select, insert, update, delete on public.mayoreo_palomar_movements to authenticated;
grant select, insert, update, delete on public.mayoreo_pending_items to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_accounts'
      and policyname = 'mayoreo_accounts_authenticated_all'
  ) then
    create policy mayoreo_accounts_authenticated_all
      on public.mayoreo_accounts
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_palomar_movements'
      and policyname = 'mayoreo_palomar_movements_authenticated_all'
  ) then
    create policy mayoreo_palomar_movements_authenticated_all
      on public.mayoreo_palomar_movements
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_pending_items'
      and policyname = 'mayoreo_pending_items_authenticated_all'
  ) then
    create policy mayoreo_pending_items_authenticated_all
      on public.mayoreo_pending_items
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
