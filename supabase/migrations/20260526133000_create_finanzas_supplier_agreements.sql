begin;

create table if not exists public.finanzas_supplier_agreements (
  id text primary key,
  provider_id text not null references public.finanzas_catalog_companies(id) on delete restrict,
  provider_name_snapshot text not null,
  start_date timestamptz not null default now(),
  frequency text not null
    check (frequency in ('SEMANAL', 'QUINCENAL', 'MENSUAL')),
  installment_amount numeric(14,2) not null default 0,
  installment_count integer not null default 1,
  total_amount numeric(14,2) not null default 0,
  remaining_amount numeric(14,2) not null default 0,
  next_due_date timestamptz,
  status text not null default 'ACTIVO'
    check (status in ('ACTIVO', 'CUMPLIDO', 'ATRASADO', 'CANCELADO')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_supplier_agreements_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_supplier_agreements_installment_amount_chk check (
    installment_amount >= 0
  ),
  constraint finanzas_supplier_agreements_installment_count_chk check (
    installment_count > 0
  ),
  constraint finanzas_supplier_agreements_total_amount_chk check (
    total_amount >= 0
  ),
  constraint finanzas_supplier_agreements_remaining_amount_chk check (
    remaining_amount >= 0
  )
);

create table if not exists public.finanzas_supplier_agreement_installments (
  id text primary key,
  agreement_id text not null references public.finanzas_supplier_agreements(id) on delete cascade,
  sequence_number integer not null,
  due_date timestamptz not null,
  amount numeric(14,2) not null default 0,
  paid_amount numeric(14,2) not null default 0,
  status text not null default 'PENDIENTE'
    check (status in ('PENDIENTE', 'PAGADO', 'VENCIDO')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint finanzas_supplier_agreement_installments_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint finanzas_supplier_agreement_installments_sequence_chk check (
    sequence_number > 0
  ),
  constraint finanzas_supplier_agreement_installments_amount_chk check (
    amount >= 0
  ),
  constraint finanzas_supplier_agreement_installments_paid_amount_chk check (
    paid_amount >= 0
  )
);

drop trigger if exists trg_finanzas_supplier_agreements_updated_at on public.finanzas_supplier_agreements;
create trigger trg_finanzas_supplier_agreements_updated_at
before update on public.finanzas_supplier_agreements
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_finanzas_supplier_agreement_installments_updated_at on public.finanzas_supplier_agreement_installments;
create trigger trg_finanzas_supplier_agreement_installments_updated_at
before update on public.finanzas_supplier_agreement_installments
for each row execute function public.set_updated_at_v2();

create index if not exists finanzas_supplier_agreements_provider_idx
  on public.finanzas_supplier_agreements (provider_id, start_date desc);

create index if not exists finanzas_supplier_agreement_installments_agreement_idx
  on public.finanzas_supplier_agreement_installments (agreement_id, due_date asc);

create unique index if not exists finanzas_supplier_agreement_installments_unique_sequence_idx
  on public.finanzas_supplier_agreement_installments (agreement_id, sequence_number);

alter table public.finanzas_supplier_agreements enable row level security;
alter table public.finanzas_supplier_agreement_installments enable row level security;

grant select, insert, update, delete on public.finanzas_supplier_agreements to authenticated;
grant select, insert, update, delete on public.finanzas_supplier_agreement_installments to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_supplier_agreements'
      and policyname = 'finanzas_supplier_agreements_authenticated_all'
  ) then
    create policy finanzas_supplier_agreements_authenticated_all
      on public.finanzas_supplier_agreements
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_supplier_agreement_installments'
      and policyname = 'finanzas_supplier_agreement_installments_authenticated_all'
  ) then
    create policy finanzas_supplier_agreement_installments_authenticated_all
      on public.finanzas_supplier_agreement_installments
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
