create table if not exists public.hr_vacation_entitlement_rules (
  rule_key text primary key,
  sort_order integer not null,
  min_years integer not null,
  max_years integer,
  days_entitled integer not null,
  legal_basis text not null default 'LFT Art. 76',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_vacation_entitlement_rules_years_check
    check (min_years >= 0 and (max_years is null or max_years >= min_years)),
  constraint hr_vacation_entitlement_rules_days_check
    check (days_entitled >= 0),
  constraint hr_vacation_entitlement_rules_sort_order_unique
    unique (sort_order)
);

create table if not exists public.hr_employee_vacation_balances (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.hr_employee_profiles(id) on delete cascade,
  employee_name text not null default '',
  empresa text not null default '',
  exercise_year integer not null,
  base_date_policy text not null default 'fecha_ingreso',
  base_fecha_ingreso date,
  base_fecha_alta date,
  base_manual_date date,
  antiguedad_years integer not null default 0,
  entitlement_rule_key text references public.hr_vacation_entitlement_rules(rule_key),
  days_entitled integer not null default 0,
  days_taken numeric(8,2) not null default 0,
  days_available numeric(8,2) not null default 0,
  salary_snapshot numeric(12,2),
  salary_perceived_snapshot numeric(12,2),
  status text not null default 'pendiente',
  manual_override boolean not null default false,
  manual_override_reason text not null default '',
  source_snapshot jsonb not null default '{}'::jsonb,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_employee_vacation_balances_policy_check
    check (base_date_policy in ('fecha_ingreso', 'fecha_alta', 'manual_rh')),
  constraint hr_employee_vacation_balances_status_check
    check (status in ('pendiente', 'calculado', 'aplicado', 'con_ajuste_rh', 'listo_prenomina')),
  constraint hr_employee_vacation_balances_days_check
    check (days_entitled >= 0 and days_taken >= 0 and days_available >= 0),
  constraint hr_employee_vacation_balances_employee_exercise_unique
    unique (employee_id, exercise_year)
);

create table if not exists public.hr_employee_vacation_events (
  id uuid primary key default gen_random_uuid(),
  balance_id uuid references public.hr_employee_vacation_balances(id) on delete cascade,
  employee_id text not null references public.hr_employee_profiles(id) on delete cascade,
  employee_name text not null default '',
  exercise_year integer not null,
  event_type text not null default 'vacaciones_disfrutadas',
  start_date date not null,
  end_date date not null,
  days_applied numeric(8,2) not null default 0,
  attendance_period_label text not null default '',
  attendance_sync_status text not null default 'pendiente',
  prenomina_sync_status text not null default 'pendiente',
  impact_attendance boolean not null default true,
  impact_prenomina boolean not null default false,
  generate_receipt boolean not null default false,
  receipt_group_key text not null default '',
  status text not null default 'pendiente',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_employee_vacation_events_type_check
    check (event_type in ('vacaciones_disfrutadas', 'vacaciones_pagadas', 'vacaciones_pendientes', 'ajuste_rh')),
  constraint hr_employee_vacation_events_status_check
    check (status in ('pendiente', 'aprobado', 'aplicado', 'cancelado')),
  constraint hr_employee_vacation_events_attendance_sync_check
    check (attendance_sync_status in ('pendiente', 'aplicado', 'omitido')),
  constraint hr_employee_vacation_events_prenomina_sync_check
    check (prenomina_sync_status in ('pendiente', 'aplicado', 'omitido')),
  constraint hr_employee_vacation_events_dates_check
    check (end_date >= start_date),
  constraint hr_employee_vacation_events_days_check
    check (days_applied >= 0)
);

create table if not exists public.hr_employee_vacation_calculations (
  id uuid primary key default gen_random_uuid(),
  vacation_event_id uuid not null references public.hr_employee_vacation_events(id) on delete cascade,
  employee_id text not null references public.hr_employee_profiles(id) on delete cascade,
  exercise_year integer not null,
  sequence_no integer not null default 1,
  component_label text not null default '',
  calculation_mode text not null default 'salario',
  base_date_policy text not null default 'fecha_ingreso',
  days_paid numeric(8,2) not null default 0,
  daily_salary_used numeric(12,2) not null default 0,
  daily_salary_perceived_used numeric(12,2) not null default 0,
  vacation_pay numeric(12,2) not null default 0,
  vacation_bonus_rate numeric(6,4) not null default 0.25,
  vacation_bonus_pay numeric(12,2) not null default 0,
  transfer_component numeric(12,2) not null default 0,
  cash_component numeric(12,2) not null default 0,
  difference_component numeric(12,2) not null default 0,
  status text not null default 'borrador',
  is_final boolean not null default false,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_employee_vacation_calculations_sequence_unique
    unique (vacation_event_id, sequence_no),
  constraint hr_employee_vacation_calculations_mode_check
    check (calculation_mode in ('salario', 'salario_percibido', 'mixto', 'manual_rh')),
  constraint hr_employee_vacation_calculations_policy_check
    check (base_date_policy in ('fecha_ingreso', 'fecha_alta', 'manual_rh')),
  constraint hr_employee_vacation_calculations_status_check
    check (status in ('borrador', 'vigente', 'descartado')),
  constraint hr_employee_vacation_calculations_values_check
    check (
      sequence_no > 0
      and days_paid >= 0
      and daily_salary_used >= 0
      and daily_salary_perceived_used >= 0
      and vacation_pay >= 0
      and vacation_bonus_rate >= 0
      and vacation_bonus_pay >= 0
      and transfer_component >= 0
      and cash_component >= 0
    )
);

create index if not exists hr_vacation_entitlement_rules_active_idx
  on public.hr_vacation_entitlement_rules (active, sort_order);

create index if not exists hr_employee_vacation_balances_employee_idx
  on public.hr_employee_vacation_balances (employee_id, exercise_year desc);

create index if not exists hr_employee_vacation_balances_status_idx
  on public.hr_employee_vacation_balances (status, exercise_year desc);

create index if not exists hr_employee_vacation_events_employee_idx
  on public.hr_employee_vacation_events (employee_id, start_date, end_date);

create index if not exists hr_employee_vacation_events_exercise_idx
  on public.hr_employee_vacation_events (exercise_year, status, start_date);

create index if not exists hr_employee_vacation_events_attendance_idx
  on public.hr_employee_vacation_events (attendance_period_label, attendance_sync_status);

create index if not exists hr_employee_vacation_calculations_event_idx
  on public.hr_employee_vacation_calculations (vacation_event_id, sequence_no);

create index if not exists hr_employee_vacation_calculations_employee_idx
  on public.hr_employee_vacation_calculations (employee_id, exercise_year);

drop trigger if exists set_hr_vacation_entitlement_rules_updated_at
  on public.hr_vacation_entitlement_rules;
create trigger set_hr_vacation_entitlement_rules_updated_at
before update on public.hr_vacation_entitlement_rules
for each row
execute function public.set_updated_at();

drop trigger if exists set_hr_employee_vacation_balances_updated_at
  on public.hr_employee_vacation_balances;
create trigger set_hr_employee_vacation_balances_updated_at
before update on public.hr_employee_vacation_balances
for each row
execute function public.set_updated_at();

drop trigger if exists set_hr_employee_vacation_events_updated_at
  on public.hr_employee_vacation_events;
create trigger set_hr_employee_vacation_events_updated_at
before update on public.hr_employee_vacation_events
for each row
execute function public.set_updated_at();

drop trigger if exists set_hr_employee_vacation_calculations_updated_at
  on public.hr_employee_vacation_calculations;
create trigger set_hr_employee_vacation_calculations_updated_at
before update on public.hr_employee_vacation_calculations
for each row
execute function public.set_updated_at();

alter table public.hr_vacation_entitlement_rules enable row level security;
alter table public.hr_employee_vacation_balances enable row level security;
alter table public.hr_employee_vacation_events enable row level security;
alter table public.hr_employee_vacation_calculations enable row level security;

drop policy if exists "hr_vacation_entitlement_rules_authenticated_select"
  on public.hr_vacation_entitlement_rules;
create policy "hr_vacation_entitlement_rules_authenticated_select"
on public.hr_vacation_entitlement_rules
for select
to authenticated
using (true);

drop policy if exists "hr_vacation_entitlement_rules_authenticated_insert"
  on public.hr_vacation_entitlement_rules;
create policy "hr_vacation_entitlement_rules_authenticated_insert"
on public.hr_vacation_entitlement_rules
for insert
to authenticated
with check (true);

drop policy if exists "hr_vacation_entitlement_rules_authenticated_update"
  on public.hr_vacation_entitlement_rules;
create policy "hr_vacation_entitlement_rules_authenticated_update"
on public.hr_vacation_entitlement_rules
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_vacation_entitlement_rules_authenticated_delete"
  on public.hr_vacation_entitlement_rules;
create policy "hr_vacation_entitlement_rules_authenticated_delete"
on public.hr_vacation_entitlement_rules
for delete
to authenticated
using (true);

drop policy if exists "hr_employee_vacation_balances_authenticated_select"
  on public.hr_employee_vacation_balances;
create policy "hr_employee_vacation_balances_authenticated_select"
on public.hr_employee_vacation_balances
for select
to authenticated
using (true);

drop policy if exists "hr_employee_vacation_balances_authenticated_insert"
  on public.hr_employee_vacation_balances;
create policy "hr_employee_vacation_balances_authenticated_insert"
on public.hr_employee_vacation_balances
for insert
to authenticated
with check (true);

drop policy if exists "hr_employee_vacation_balances_authenticated_update"
  on public.hr_employee_vacation_balances;
create policy "hr_employee_vacation_balances_authenticated_update"
on public.hr_employee_vacation_balances
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_employee_vacation_balances_authenticated_delete"
  on public.hr_employee_vacation_balances;
create policy "hr_employee_vacation_balances_authenticated_delete"
on public.hr_employee_vacation_balances
for delete
to authenticated
using (true);

drop policy if exists "hr_employee_vacation_events_authenticated_select"
  on public.hr_employee_vacation_events;
create policy "hr_employee_vacation_events_authenticated_select"
on public.hr_employee_vacation_events
for select
to authenticated
using (true);

drop policy if exists "hr_employee_vacation_events_authenticated_insert"
  on public.hr_employee_vacation_events;
create policy "hr_employee_vacation_events_authenticated_insert"
on public.hr_employee_vacation_events
for insert
to authenticated
with check (true);

drop policy if exists "hr_employee_vacation_events_authenticated_update"
  on public.hr_employee_vacation_events;
create policy "hr_employee_vacation_events_authenticated_update"
on public.hr_employee_vacation_events
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_employee_vacation_events_authenticated_delete"
  on public.hr_employee_vacation_events;
create policy "hr_employee_vacation_events_authenticated_delete"
on public.hr_employee_vacation_events
for delete
to authenticated
using (true);

drop policy if exists "hr_employee_vacation_calculations_authenticated_select"
  on public.hr_employee_vacation_calculations;
create policy "hr_employee_vacation_calculations_authenticated_select"
on public.hr_employee_vacation_calculations
for select
to authenticated
using (true);

drop policy if exists "hr_employee_vacation_calculations_authenticated_insert"
  on public.hr_employee_vacation_calculations;
create policy "hr_employee_vacation_calculations_authenticated_insert"
on public.hr_employee_vacation_calculations
for insert
to authenticated
with check (true);

drop policy if exists "hr_employee_vacation_calculations_authenticated_update"
  on public.hr_employee_vacation_calculations;
create policy "hr_employee_vacation_calculations_authenticated_update"
on public.hr_employee_vacation_calculations
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_employee_vacation_calculations_authenticated_delete"
  on public.hr_employee_vacation_calculations;
create policy "hr_employee_vacation_calculations_authenticated_delete"
on public.hr_employee_vacation_calculations
for delete
to authenticated
using (true);

insert into public.hr_vacation_entitlement_rules (
  rule_key,
  sort_order,
  min_years,
  max_years,
  days_entitled
) values
  ('1', 1, 1, 1, 12),
  ('2', 2, 2, 2, 14),
  ('3', 3, 3, 3, 16),
  ('4', 4, 4, 4, 18),
  ('5', 5, 5, 5, 20),
  ('6_10', 6, 6, 10, 22),
  ('11_15', 7, 11, 15, 24),
  ('16_20', 8, 16, 20, 26),
  ('21_25', 9, 21, 25, 28),
  ('26_30', 10, 26, 30, 30),
  ('31_35', 11, 31, 35, 32)
on conflict (rule_key) do update
set
  sort_order = excluded.sort_order,
  min_years = excluded.min_years,
  max_years = excluded.max_years,
  days_entitled = excluded.days_entitled,
  legal_basis = excluded.legal_basis,
  active = true;

comment on table public.hr_vacation_entitlement_rules is
  'Tabla legal auditable de dias de vacaciones por antigüedad usada por RH para vacaciones.';

comment on table public.hr_employee_vacation_balances is
  'Saldo anual de vacaciones por colaborador y ejercicio; congela base de fecha, antigüedad, dias correspondientes y snapshots salariales.';

comment on table public.hr_employee_vacation_events is
  'Eventos o rangos de vacaciones capturados por RH; pueden impactar asistencia, prenómina y recibos.';

comment on table public.hr_employee_vacation_calculations is
  'Componentes monetarios y escenarios de cálculo por evento vacacional; soporta salario, salario percibido y componentes multiples.';
