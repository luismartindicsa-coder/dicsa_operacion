alter table public.hr_employee_vacation_events
  add column if not exists additional_paid_days numeric(8,2) not null default 0
  check (additional_paid_days >= 0);

comment on column public.hr_employee_vacation_events.additional_paid_days is
  'Domingos, festivos u otros días adicionales que se pagan junto con las vacaciones sin consumir el derecho vacacional.';
