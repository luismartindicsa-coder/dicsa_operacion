-- El complemento de sueldo en efectivo se calcula automáticamente contra el
-- salario percibido. Solo se conserva un importe capturado cuando RH lo fija.
alter table public.hr_prenomina_draft_rows
  add column if not exists cash_salary_is_manual boolean not null default false;

comment on column public.hr_prenomina_draft_rows.cash_salary_is_manual is
  'Indica que RH capturó manualmente el complemento de sueldo en efectivo. Si es falso se recalcula como salario percibido semanal menos neto fiscal.';
