create table if not exists public.finanzas_payment_center_learning (
  id text primary key,
  captured_at timestamptz not null default now(),
  provider_id text not null,
  provider_name text not null,
  bucket text not null,
  item_type text not null,
  source_label text not null,
  due_date timestamptz,
  target_company text not null default '',
  target_branch text not null default '',
  suggested_action text not null,
  suggested_amount numeric(14,2) not null default 0,
  recommendation text not null default '',
  status text not null default 'PENDIENTE',
  executed_action text,
  executed_amount numeric(14,2),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists finanzas_payment_center_learning_captured_idx
  on public.finanzas_payment_center_learning (captured_at desc, created_at desc);

create index if not exists finanzas_payment_center_learning_provider_idx
  on public.finanzas_payment_center_learning (provider_id, captured_at desc);

drop trigger if exists trg_finanzas_payment_center_learning_updated_at
on public.finanzas_payment_center_learning;
create trigger trg_finanzas_payment_center_learning_updated_at
before update on public.finanzas_payment_center_learning
for each row execute function public.set_updated_at_v2();

alter table public.finanzas_payment_center_learning enable row level security;

drop policy if exists finanzas_payment_center_learning_select
on public.finanzas_payment_center_learning;
create policy finanzas_payment_center_learning_select
on public.finanzas_payment_center_learning
for select
to authenticated
using (true);

drop policy if exists finanzas_payment_center_learning_insert
on public.finanzas_payment_center_learning;
create policy finanzas_payment_center_learning_insert
on public.finanzas_payment_center_learning
for insert
to authenticated
with check (true);

drop policy if exists finanzas_payment_center_learning_update
on public.finanzas_payment_center_learning;
create policy finanzas_payment_center_learning_update
on public.finanzas_payment_center_learning
for update
to authenticated
using (true)
with check (true);

