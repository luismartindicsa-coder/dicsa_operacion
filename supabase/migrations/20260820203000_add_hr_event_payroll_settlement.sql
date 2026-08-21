-- Los eventos operativos viven todo el ejercicio; el cierre semanal los consume
-- una sola vez. Esta separación evita que una corrección posterior reabra una
-- semana ya liquidada.
alter table public.hr_employee_vacation_events
  add column if not exists payroll_period_label text not null default '',
  add column if not exists payroll_settlement_status text not null default 'pendiente',
  add column if not exists payroll_settled_at timestamptz,
  add column if not exists receipt_status text not null default 'pendiente',
  add column if not exists receipt_issued_at timestamptz,
  add column if not exists receipt_version integer not null default 0,
  add column if not exists receipt_snapshot jsonb not null default '{}'::jsonb;

alter table public.hr_employee_vacation_events
  drop constraint if exists hr_employee_vacation_events_payroll_settlement_status_check;
alter table public.hr_employee_vacation_events
  add constraint hr_employee_vacation_events_payroll_settlement_status_check
    check (payroll_settlement_status in ('pendiente', 'liquidado', 'ajuste'));

alter table public.hr_employee_vacation_events
  drop constraint if exists hr_employee_vacation_events_receipt_status_check;
alter table public.hr_employee_vacation_events
  add constraint hr_employee_vacation_events_receipt_status_check
    check (receipt_status in ('pendiente', 'emitido', 'anulado', 'sustituido'));

alter table public.hr_employee_permission_events
  add column if not exists payroll_period_label text not null default '',
  add column if not exists payroll_settlement_status text not null default 'pendiente',
  add column if not exists payroll_settled_at timestamptz;

alter table public.hr_employee_permission_events
  drop constraint if exists hr_employee_permission_events_payroll_settlement_status_check;
alter table public.hr_employee_permission_events
  add constraint hr_employee_permission_events_payroll_settlement_status_check
    check (payroll_settlement_status in ('pendiente', 'liquidado', 'ajuste'));

update public.hr_employee_vacation_events
set payroll_period_label = attendance_period_label
where payroll_period_label = '' and attendance_period_label <> '';

update public.hr_employee_permission_events
set payroll_period_label = attendance_period_label
where payroll_period_label = '' and attendance_period_label <> '';

create index if not exists hr_employee_vacation_events_payroll_settlement_idx
  on public.hr_employee_vacation_events
    (payroll_period_label, payroll_settlement_status, employee_id);

create index if not exists hr_employee_permission_events_payroll_settlement_idx
  on public.hr_employee_permission_events
    (payroll_period_label, payroll_settlement_status, employee_id);

comment on column public.hr_employee_vacation_events.payroll_period_label is
  'Periodo semanal que consume el evento en prenomina. Se congela al liquidarse.';
comment on column public.hr_employee_vacation_events.receipt_snapshot is
  'Fotografia inmutable del calculo que se usa al emitir el recibo despues de prenomina.';
