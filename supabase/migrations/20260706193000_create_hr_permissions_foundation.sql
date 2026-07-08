create table if not exists public.hr_employee_permission_events (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.hr_employee_profiles(id) on delete cascade,
  employee_name text not null default '',
  empresa text not null default '',
  attendance_period_label text not null default '',
  permission_type text not null default 'permiso_con_goce',
  request_unit text not null default 'dia',
  start_date date not null,
  end_date date not null,
  start_time text not null default '',
  end_time text not null default '',
  quantity_days numeric(8,2) not null default 0,
  quantity_hours numeric(8,2) not null default 0,
  attendance_sync_status text not null default 'pendiente',
  prenomina_sync_status text not null default 'pendiente',
  impact_attendance boolean not null default true,
  impact_prenomina boolean not null default false,
  source_mode text not null default 'manual',
  status text not null default 'pendiente',
  notes text not null default '',
  source_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_employee_permission_events_type_check
    check (permission_type in ('permiso_con_goce', 'permiso_sin_goce', 'incapacidad', 'ajuste_rh')),
  constraint hr_employee_permission_events_unit_check
    check (request_unit in ('dia', 'hora')),
  constraint hr_employee_permission_events_status_check
    check (status in ('pendiente', 'aprobado', 'aplicado', 'cancelado')),
  constraint hr_employee_permission_events_attendance_sync_check
    check (attendance_sync_status in ('pendiente', 'aplicado', 'omitido')),
  constraint hr_employee_permission_events_prenomina_sync_check
    check (prenomina_sync_status in ('pendiente', 'aplicado', 'omitido')),
  constraint hr_employee_permission_events_source_mode_check
    check (source_mode in ('manual', 'importado', 'ajuste')),
  constraint hr_employee_permission_events_dates_check
    check (end_date >= start_date),
  constraint hr_employee_permission_events_quantities_check
    check (quantity_days >= 0 and quantity_hours >= 0)
);

create index if not exists hr_employee_permission_events_employee_idx
  on public.hr_employee_permission_events (employee_id, start_date, end_date);

create index if not exists hr_employee_permission_events_period_idx
  on public.hr_employee_permission_events (attendance_period_label, employee_id, start_date);

create index if not exists hr_employee_permission_events_status_idx
  on public.hr_employee_permission_events (status, permission_type, start_date);

drop trigger if exists set_hr_employee_permission_events_updated_at
  on public.hr_employee_permission_events;
create trigger set_hr_employee_permission_events_updated_at
before update on public.hr_employee_permission_events
for each row
execute function public.set_updated_at();

alter table public.hr_employee_permission_events enable row level security;

drop policy if exists "hr_employee_permission_events_authenticated_select"
  on public.hr_employee_permission_events;
create policy "hr_employee_permission_events_authenticated_select"
on public.hr_employee_permission_events
for select
to authenticated
using (true);

drop policy if exists "hr_employee_permission_events_authenticated_insert"
  on public.hr_employee_permission_events;
create policy "hr_employee_permission_events_authenticated_insert"
on public.hr_employee_permission_events
for insert
to authenticated
with check (true);

drop policy if exists "hr_employee_permission_events_authenticated_update"
  on public.hr_employee_permission_events;
create policy "hr_employee_permission_events_authenticated_update"
on public.hr_employee_permission_events
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_employee_permission_events_authenticated_delete"
  on public.hr_employee_permission_events;
create policy "hr_employee_permission_events_authenticated_delete"
on public.hr_employee_permission_events
for delete
to authenticated
using (true);

comment on table public.hr_employee_permission_events is
  'Ledger operativo de permisos RH por colaborador y periodo; prepara asistencia, prenómina y nómina sin mezclar semanas activas.';
