alter table public.hr_employee_profiles
  add column if not exists labor_schedules jsonb not null default '[]'::jsonb;

comment on column public.hr_employee_profiles.labor_schedules is
  'Lista de jornadas laborales posibles del colaborador, cada una con horario y dias laborables, para soportar roles o rotaciones.';
