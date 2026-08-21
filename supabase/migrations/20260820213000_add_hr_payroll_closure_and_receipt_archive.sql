-- Cierre global semanal: separa el trabajo operativo anual del periodo ya
-- validado y conservado para nómina/recibos.
create table if not exists public.hr_payroll_period_closures (
  id uuid primary key default gen_random_uuid(),
  period_label text not null unique,
  status text not null default 'abierto',
  closed_at timestamptz,
  closed_by uuid references auth.users(id) on delete set null,
  notes text not null default '',
  summary_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_payroll_period_closures_status_check
    check (status in ('abierto', 'cerrado', 'anulado'))
);

create table if not exists public.hr_payroll_receipt_documents (
  id uuid primary key default gen_random_uuid(),
  period_closure_id uuid references public.hr_payroll_period_closures(id) on delete restrict,
  prenomina_draft_row_id uuid not null references public.hr_prenomina_draft_rows(id) on delete restrict,
  employee_id text not null references public.hr_employee_profiles(id) on delete restrict,
  receipt_type text not null default 'nomina',
  version integer not null default 1,
  status text not null default 'emitido',
  storage_bucket text not null default 'hr_payroll_receipts',
  storage_path text not null unique,
  file_size_bytes integer not null default 0,
  emitted_at timestamptz not null default now(),
  emitted_by uuid references auth.users(id) on delete set null,
  snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_payroll_receipt_documents_type_check
    check (receipt_type in ('nomina', 'vacaciones', 'ajuste')),
  constraint hr_payroll_receipt_documents_status_check
    check (status in ('emitido', 'anulado', 'sustituido')),
  constraint hr_payroll_receipt_documents_version_check
    check (version >= 1),
  constraint hr_payroll_receipt_documents_version_unique
    unique (prenomina_draft_row_id, receipt_type, version)
);

create index if not exists hr_payroll_receipt_documents_employee_period_idx
  on public.hr_payroll_receipt_documents (employee_id, emitted_at desc);

drop trigger if exists set_hr_payroll_period_closures_updated_at
  on public.hr_payroll_period_closures;
create trigger set_hr_payroll_period_closures_updated_at
before update on public.hr_payroll_period_closures
for each row execute function public.set_updated_at();

drop trigger if exists set_hr_payroll_receipt_documents_updated_at
  on public.hr_payroll_receipt_documents;
create trigger set_hr_payroll_receipt_documents_updated_at
before update on public.hr_payroll_receipt_documents
for each row execute function public.set_updated_at();

-- Un cierre no puede reabrirse ni borrarse desde una operación normal. Si la
-- corrida requiere corrección, RH debe crear un ajuste trazable.
create or replace function public.guard_hr_payroll_period_closure()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' and old.status = 'cerrado' then
    raise exception 'El cierre de nómina no se puede borrar; registra un ajuste RH.';
  end if;
  if tg_op = 'UPDATE' and old.status = 'cerrado' and new.status <> 'cerrado' then
    raise exception 'El cierre de nómina no se puede reabrir; registra un ajuste RH.';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_hr_payroll_period_closure
  on public.hr_payroll_period_closures;
create trigger guard_hr_payroll_period_closure
before update or delete on public.hr_payroll_period_closures
for each row execute function public.guard_hr_payroll_period_closure();

-- Las filas de Prenómina de un periodo cerrado ya no son un borrador. Solo se
-- permite completar el snapshot inmutable del recibo que se emite desde Nómina.
create or replace function public.guard_hr_prenomina_closed_period()
returns trigger
language plpgsql
as $$
declare
  protected_period text;
  old_payload jsonb;
  new_payload jsonb;
begin
  protected_period := case when tg_op = 'INSERT' then new.period_label else old.period_label end;
  if not exists (
    select 1
    from public.hr_payroll_period_closures
    where period_label = protected_period and status = 'cerrado'
  ) then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    raise exception 'El periodo de Prenómina está cerrado; registra un ajuste RH.';
  end if;
  if tg_op = 'DELETE' then
    raise exception 'El periodo de Prenómina está cerrado; no se puede borrar.';
  end if;

  old_payload := to_jsonb(old) - array['updated_at', 'source_snapshot'];
  new_payload := to_jsonb(new) - array['updated_at', 'source_snapshot'];
  if old_payload is distinct from new_payload then
    raise exception 'El periodo de Prenómina está cerrado; registra un ajuste RH.';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_hr_prenomina_closed_period
  on public.hr_prenomina_draft_rows;
create trigger guard_hr_prenomina_closed_period
before insert or update or delete on public.hr_prenomina_draft_rows
for each row execute function public.guard_hr_prenomina_closed_period();

alter table public.hr_payroll_period_closures enable row level security;
alter table public.hr_payroll_receipt_documents enable row level security;

do $$
declare
  tbl text;
  policy_name text;
begin
  foreach tbl in array array['hr_payroll_period_closures', 'hr_payroll_receipt_documents'] loop
    policy_name := tbl || '_authenticated_all';
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = tbl and policyname = policy_name
    ) then
      execute format(
        'create policy %I on public.%I for all to authenticated using (true) with check (true)',
        policy_name, tbl
      );
    end if;
  end loop;
end
$$;

insert into storage.buckets (id, name, public)
select 'hr_payroll_receipts', 'hr_payroll_receipts', false
where not exists (
  select 1 from storage.buckets where id = 'hr_payroll_receipts'
);

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'hr_payroll_receipts_authenticated_read'
  ) then
    create policy hr_payroll_receipts_authenticated_read
      on storage.objects for select to authenticated
      using (bucket_id = 'hr_payroll_receipts');
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'hr_payroll_receipts_authenticated_write'
  ) then
    create policy hr_payroll_receipts_authenticated_write
      on storage.objects for insert to authenticated
      with check (bucket_id = 'hr_payroll_receipts');
  end if;
end
$$;

-- Una vez liquidado, un evento es historia. Solo se admite completar su
-- metadata de recibo; cualquier corrección debe registrarse como ajuste nuevo.
create or replace function public.guard_hr_settled_event_immutability()
returns trigger
language plpgsql
as $$
declare
  old_payload jsonb;
  new_payload jsonb;
begin
  if tg_op = 'DELETE' and old.payroll_settlement_status = 'liquidado' then
    raise exception 'El evento liquidado no se puede borrar; registra un ajuste RH.';
  end if;

  if tg_op = 'UPDATE' and old.payroll_settlement_status = 'liquidado' then
    old_payload := to_jsonb(old) - array[
      'updated_at', 'receipt_status', 'receipt_issued_at',
      'receipt_version', 'receipt_snapshot'
    ];
    new_payload := to_jsonb(new) - array[
      'updated_at', 'receipt_status', 'receipt_issued_at',
      'receipt_version', 'receipt_snapshot'
    ];
    if old_payload is distinct from new_payload then
      raise exception 'El evento liquidado es inmutable; registra un ajuste RH.';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_hr_vacation_settled_events
  on public.hr_employee_vacation_events;
create trigger guard_hr_vacation_settled_events
before update or delete on public.hr_employee_vacation_events
for each row execute function public.guard_hr_settled_event_immutability();

drop trigger if exists guard_hr_permission_settled_events
  on public.hr_employee_permission_events;
create trigger guard_hr_permission_settled_events
before update or delete on public.hr_employee_permission_events
for each row execute function public.guard_hr_settled_event_immutability();

comment on table public.hr_payroll_period_closures is
  'Cierre semanal global de RH. Congela la corrida aprobada y su resumen.';
comment on table public.hr_payroll_receipt_documents is
  'Archivo inmutable de PDFs emitidos desde Nómina, con snapshot y ubicación en Storage.';
