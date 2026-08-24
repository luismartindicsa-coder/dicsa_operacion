-- La captura diaria de RH puede iniciar antes de que existan archivos de
-- NGTeco o CONTPAQ. Estos periodos son el contexto operativo explícito.
create table if not exists public.hr_attendance_operational_periods (
  id uuid primary key default gen_random_uuid(),
  period_label text not null unique,
  period_number integer,
  start_date date not null,
  end_date date not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_attendance_operational_periods_dates_check
    check (end_date >= start_date)
);

create index if not exists hr_attendance_operational_periods_range_idx
  on public.hr_attendance_operational_periods (start_date desc, end_date desc);

drop trigger if exists set_hr_attendance_operational_periods_updated_at
  on public.hr_attendance_operational_periods;
create trigger set_hr_attendance_operational_periods_updated_at
before update on public.hr_attendance_operational_periods
for each row
execute function public.set_updated_at();

alter table public.hr_attendance_operational_periods enable row level security;

drop policy if exists "hr_attendance_operational_periods_authenticated_all"
  on public.hr_attendance_operational_periods;
create policy "hr_attendance_operational_periods_authenticated_all"
on public.hr_attendance_operational_periods
for all
to authenticated
using (true)
with check (true);

-- Una jornada todavía no capturada no debe contarse como falta. El estado
-- pendiente permite a RH completar el día desde la hoja física.
alter table public.hr_attendance_daily_records
  drop constraint if exists hr_attendance_daily_records_status_check;

alter table public.hr_attendance_daily_records
  add constraint hr_attendance_daily_records_status_check
    check (status in ('pendiente', 'laboro', 'falto', 'no_aplica'));

alter table public.hr_attendance_daily_records
  alter column status set default 'pendiente';

comment on table public.hr_attendance_operational_periods is
  'Periodos explícitos para la captura diaria de asistencia RH; no dependen de importaciones.';
