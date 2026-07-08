create table if not exists public.hr_attendance_daily_records (
  id uuid primary key default gen_random_uuid(),
  period_label text not null,
  employee_id text not null,
  employee_name text not null default '',
  source_date text not null,
  weekday_label text not null default '',
  status text not null default 'laboro',
  source_mode text not null default 'manual',
  first_punch text not null default '',
  last_punch text not null default '',
  punch_timeline jsonb not null default '[]'::jsonb,
  late_minutes integer not null default 0,
  overtime_minutes integer not null default 0,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_attendance_daily_records_status_check
    check (status in ('laboro', 'falto', 'no_aplica')),
  constraint hr_attendance_daily_records_source_mode_check
    check (source_mode in ('importado', 'manual', 'ajuste')),
  constraint hr_attendance_daily_records_employee_day_unique
    unique (period_label, employee_id, source_date)
);

create index if not exists hr_attendance_daily_records_period_idx
  on public.hr_attendance_daily_records (period_label, employee_id, source_date);

drop trigger if exists set_hr_attendance_daily_records_updated_at
  on public.hr_attendance_daily_records;
create trigger set_hr_attendance_daily_records_updated_at
before update on public.hr_attendance_daily_records
for each row
execute function public.set_updated_at();

alter table public.hr_attendance_daily_records enable row level security;

drop policy if exists "hr_attendance_daily_records_authenticated_select"
  on public.hr_attendance_daily_records;
create policy "hr_attendance_daily_records_authenticated_select"
on public.hr_attendance_daily_records
for select
to authenticated
using (true);

drop policy if exists "hr_attendance_daily_records_authenticated_insert"
  on public.hr_attendance_daily_records;
create policy "hr_attendance_daily_records_authenticated_insert"
on public.hr_attendance_daily_records
for insert
to authenticated
with check (true);

drop policy if exists "hr_attendance_daily_records_authenticated_update"
  on public.hr_attendance_daily_records;
create policy "hr_attendance_daily_records_authenticated_update"
on public.hr_attendance_daily_records
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_attendance_daily_records_authenticated_delete"
  on public.hr_attendance_daily_records;
create policy "hr_attendance_daily_records_authenticated_delete"
on public.hr_attendance_daily_records
for delete
to authenticated
using (true);

comment on table public.hr_attendance_daily_records is
  'Cierre editable de asistencia diaria por colaborador y periodo activo de RH; mezcla lectura importada y corrección manual antes de permisos, vacaciones y prenómina.';
