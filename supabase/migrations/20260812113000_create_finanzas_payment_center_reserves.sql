create table if not exists public.finanzas_payment_center_reserves (
  id text primary key,
  reserve_name text not null,
  reserve_type text not null default 'EXTRAORDINARIO',
  classification text not null default 'DURA',
  scope_type text not null default 'GLOBAL',
  target_company text,
  target_branch text,
  amount numeric(14,2) not null default 0,
  effective_date timestamptz not null default timezone('utc', now()),
  end_date timestamptz,
  note text not null default '',
  blocks_cash boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint finanzas_payment_center_reserves_id_trim_chk
    check (id = btrim(id) and length(id) > 0),
  constraint finanzas_payment_center_reserves_name_trim_chk
    check (reserve_name = btrim(reserve_name) and length(reserve_name) > 0),
  constraint finanzas_payment_center_reserves_type_chk
    check (reserve_type in ('NOMINA', 'IMPUESTOS', 'COLCHON_CUENTA', 'EXTRAORDINARIO')),
  constraint finanzas_payment_center_reserves_classification_chk
    check (classification in ('DURA', 'PROVISIONAL')),
  constraint finanzas_payment_center_reserves_scope_chk
    check (scope_type in ('GLOBAL', 'CUENTA')),
  constraint finanzas_payment_center_reserves_amount_chk
    check (amount >= 0),
  constraint finanzas_payment_center_reserves_scope_consistency_chk
    check (
      (scope_type = 'GLOBAL' and target_company is null and target_branch is null)
      or
      (scope_type = 'CUENTA'
        and target_company in ('DICSA', 'VH')
        and target_branch in ('CELAYA', 'MAZATLAN'))
    )
);

create index if not exists finanzas_payment_center_reserves_active_idx
  on public.finanzas_payment_center_reserves (is_active, effective_date);

create index if not exists finanzas_payment_center_reserves_scope_idx
  on public.finanzas_payment_center_reserves (
    scope_type,
    target_company,
    target_branch
  );

drop trigger if exists trg_finanzas_payment_center_reserves_updated_at
on public.finanzas_payment_center_reserves;
create trigger trg_finanzas_payment_center_reserves_updated_at
before update on public.finanzas_payment_center_reserves
for each row execute function public.set_updated_at_v2();

alter table public.finanzas_payment_center_reserves enable row level security;

drop policy if exists finanzas_payment_center_reserves_select
on public.finanzas_payment_center_reserves;
create policy finanzas_payment_center_reserves_select
on public.finanzas_payment_center_reserves
for select
to authenticated
using (true);

drop policy if exists finanzas_payment_center_reserves_insert
on public.finanzas_payment_center_reserves;
create policy finanzas_payment_center_reserves_insert
on public.finanzas_payment_center_reserves
for insert
to authenticated
with check (true);

drop policy if exists finanzas_payment_center_reserves_update
on public.finanzas_payment_center_reserves;
create policy finanzas_payment_center_reserves_update
on public.finanzas_payment_center_reserves
for update
to authenticated
using (true)
with check (true);

drop policy if exists finanzas_payment_center_reserves_delete
on public.finanzas_payment_center_reserves;
create policy finanzas_payment_center_reserves_delete
on public.finanzas_payment_center_reserves
for delete
to authenticated
using (true);
