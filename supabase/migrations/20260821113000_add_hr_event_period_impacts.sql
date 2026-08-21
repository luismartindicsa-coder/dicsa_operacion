-- Un evento conserva su expediente fuente, pero sus efectos operativos se
-- reparten por semana para evitar liquidar anticipadamente periodos futuros.
create table if not exists public.hr_employee_event_period_impacts (
  id uuid primary key default gen_random_uuid(),
  event_kind text not null,
  vacation_event_id uuid references public.hr_employee_vacation_events(id) on delete cascade,
  permission_event_id uuid references public.hr_employee_permission_events(id) on delete cascade,
  employee_id text not null references public.hr_employee_profiles(id) on delete cascade,
  period_label text not null default '',
  period_start_date date not null,
  period_end_date date not null,
  days_applied numeric(8,2) not null default 0,
  additional_paid_days numeric(8,2) not null default 0,
  quantity_hours numeric(8,2) not null default 0,
  impact_attendance boolean not null default true,
  impact_prenomina boolean not null default false,
  attendance_sync_status text not null default 'pendiente',
  prenomina_sync_status text not null default 'pendiente',
  payroll_settlement_status text not null default 'pendiente',
  payroll_settled_at timestamptz,
  source_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_event_period_impacts_kind_check
    check (event_kind in ('vacacion', 'permiso')),
  constraint hr_event_period_impacts_parent_check
    check (
      (event_kind = 'vacacion' and vacation_event_id is not null and permission_event_id is null)
      or
      (event_kind = 'permiso' and permission_event_id is not null and vacation_event_id is null)
    ),
  constraint hr_event_period_impacts_dates_check
    check (period_end_date >= period_start_date),
  constraint hr_event_period_impacts_values_check
    check (days_applied >= 0 and additional_paid_days >= 0 and quantity_hours >= 0),
  constraint hr_event_period_impacts_attendance_check
    check (attendance_sync_status in ('pendiente', 'aplicado', 'omitido')),
  constraint hr_event_period_impacts_prenomina_check
    check (prenomina_sync_status in ('pendiente', 'aplicado', 'omitido')),
  constraint hr_event_period_impacts_settlement_check
    check (payroll_settlement_status in ('pendiente', 'liquidado', 'ajuste'))
);

create unique index if not exists hr_event_period_impacts_vacation_period_unique
  on public.hr_employee_event_period_impacts (
    vacation_event_id, period_start_date, period_end_date
  ) where vacation_event_id is not null;

create unique index if not exists hr_event_period_impacts_permission_period_unique
  on public.hr_employee_event_period_impacts (
    permission_event_id, period_start_date, period_end_date
  ) where permission_event_id is not null;

create index if not exists hr_event_period_impacts_payroll_idx
  on public.hr_employee_event_period_impacts (
    employee_id, period_start_date, period_end_date, payroll_settlement_status
  );

drop trigger if exists set_hr_employee_event_period_impacts_updated_at
  on public.hr_employee_event_period_impacts;
create trigger set_hr_employee_event_period_impacts_updated_at
before update on public.hr_employee_event_period_impacts
for each row execute function public.set_updated_at();

alter table public.hr_employee_event_period_impacts enable row level security;

drop policy if exists hr_employee_event_period_impacts_authenticated_all
  on public.hr_employee_event_period_impacts;
create policy hr_employee_event_period_impacts_authenticated_all
on public.hr_employee_event_period_impacts
for all to authenticated using (true) with check (true);

create or replace function public.guard_hr_settled_event_impact_immutability()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' and old.payroll_settlement_status = 'liquidado' then
    raise exception 'El impacto liquidado no se puede borrar; registra un ajuste RH.';
  end if;
  if tg_op = 'UPDATE' and old.payroll_settlement_status = 'liquidado' then
    raise exception 'El impacto liquidado es inmutable; registra un ajuste RH.';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists guard_hr_settled_event_period_impacts
  on public.hr_employee_event_period_impacts;
create trigger guard_hr_settled_event_period_impacts
before update or delete on public.hr_employee_event_period_impacts
for each row execute function public.guard_hr_settled_event_impact_immutability();

-- Un expediente no puede alterarse después de que cualquiera de sus tramos
-- haya sido liquidado. La corrección posterior debe ser un ajuste nuevo.
create or replace function public.guard_hr_settled_event_immutability()
returns trigger
language plpgsql
as $$
declare
  old_payload jsonb;
  new_payload jsonb;
  has_liquidated_impact boolean;
begin
  select exists (
    select 1
    from public.hr_employee_event_period_impacts impact
    where impact.payroll_settlement_status = 'liquidado'
      and (
        (tg_table_name = 'hr_employee_vacation_events' and impact.vacation_event_id = old.id)
        or
        (tg_table_name = 'hr_employee_permission_events' and impact.permission_event_id = old.id)
      )
  ) into has_liquidated_impact;

  if has_liquidated_impact then
    raise exception 'El evento tiene un tramo liquidado; registra un ajuste RH.';
  end if;

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
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

comment on table public.hr_employee_event_period_impacts is
  'Tramos semanales de eventos RH. Prenómina liquida el tramo del periodo, no el expediente completo.';
