create table if not exists public.finanzas_fixed_payments (
  id text primary key,
  received_date timestamptz not null,
  company_id text not null,
  company_name_snapshot text not null default '',
  amount numeric(14,2) not null default 0,
  payment_date timestamptz not null,
  status text not null default 'PENDIENTE'
    check (status in ('PENDIENTE', 'PAGADO', 'VENCIDO')),
  notes text,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists finanzas_fixed_payments_payment_date_idx
  on public.finanzas_fixed_payments (payment_date);

create index if not exists finanzas_fixed_payments_company_id_idx
  on public.finanzas_fixed_payments (company_id);

create trigger trg_finanzas_fixed_payments_updated_at
before update on public.finanzas_fixed_payments
for each row execute function public.set_updated_at();

alter table public.finanzas_fixed_payments enable row level security;

drop policy if exists "Authenticated users can read finanzas fixed payments"
  on public.finanzas_fixed_payments;
create policy "Authenticated users can read finanzas fixed payments"
  on public.finanzas_fixed_payments
  for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can write finanzas fixed payments"
  on public.finanzas_fixed_payments;
create policy "Authenticated users can write finanzas fixed payments"
  on public.finanzas_fixed_payments
  for all
  to authenticated
  using (true)
  with check (true);

grant select, insert, update, delete on public.finanzas_fixed_payments
to authenticated;
