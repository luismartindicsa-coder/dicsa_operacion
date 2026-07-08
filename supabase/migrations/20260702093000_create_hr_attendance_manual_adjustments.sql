create table if not exists public.hr_attendance_manual_adjustments (
  id text primary key,
  period_label text not null,
  employee_id text not null,
  employee_name text not null default '',
  source_date text not null,
  adjustment_type text not null,
  notes text not null default '',
  impacts_payroll boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists hr_attendance_manual_adjustments_period_idx
  on public.hr_attendance_manual_adjustments (period_label, source_date);

comment on table public.hr_attendance_manual_adjustments is
  'Correcciones manuales de RH por periodo activo de asistencia para faltas, permisos, vacaciones, incapacidades, horas extra y ajustes operativos.';
