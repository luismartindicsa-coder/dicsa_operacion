alter table public.hr_employee_vacation_events
  add column if not exists isr_method text not null default 'articulo_174',
  add column if not exists isr_ordinary_monthly_income_override numeric(12,2),
  add column if not exists isr_retention_override numeric(12,2);

alter table public.hr_employee_vacation_events
  drop constraint if exists hr_employee_vacation_events_isr_method_check;
alter table public.hr_employee_vacation_events
  add constraint hr_employee_vacation_events_isr_method_check
  check (isr_method in ('articulo_174', 'tarifa_semanal', 'manual_rh'));

alter table public.hr_employee_vacation_calculations
  add column if not exists isr_taxable_base numeric(12,2) not null default 0,
  add column if not exists isr_exempt_amount numeric(12,2) not null default 0,
  add column if not exists isr_retention_amount numeric(12,2) not null default 0,
  add column if not exists isr_method text not null default 'articulo_174',
  add column if not exists isr_tariff_year integer;

alter table public.hr_employee_vacation_calculations
  drop constraint if exists hr_employee_vacation_calculations_isr_method_check;
alter table public.hr_employee_vacation_calculations
  add constraint hr_employee_vacation_calculations_isr_method_check
  check (isr_method in ('articulo_174', 'tarifa_semanal', 'manual_rh'));

alter table public.hr_employee_vacation_calculations
  drop constraint if exists hr_employee_vacation_calculations_isr_values_check;
alter table public.hr_employee_vacation_calculations
  add constraint hr_employee_vacation_calculations_isr_values_check
  check (
    isr_taxable_base >= 0
    and isr_exempt_amount >= 0
    and isr_retention_amount >= 0
  );

comment on column public.hr_employee_vacation_events.isr_method is
  'Método de retención usado para el evento: artículo 174, tarifa semanal o manual RH.';
comment on column public.hr_employee_vacation_events.isr_ordinary_monthly_income_override is
  'Ingreso ordinario mensual gravado confirmado por RH para el cálculo del artículo 174.';
comment on column public.hr_employee_vacation_events.isr_retention_override is
  'Retención ISR confirmada por RH o CFDI; reemplaza el cálculo sugerido.';
comment on column public.hr_employee_vacation_calculations.isr_retention_amount is
  'ISR asociado al pago vacacional calculado o confirmado para el recibo.';
