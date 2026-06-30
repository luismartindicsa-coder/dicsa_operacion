alter table public.hr_employee_profiles
  add column if not exists fecha_alta date,
  add column if not exists salario numeric(12,2),
  add column if not exists salario_real_percibido numeric(12,2);

comment on column public.hr_employee_profiles.fecha_alta is
  'Fecha de alta administrativa usada como referencia para procesos laborales y cruces con prenomina.';

comment on column public.hr_employee_profiles.salario is
  'Salario base capturado para cruces con CONTPAQ y calculos de prenomina.';

comment on column public.hr_employee_profiles.salario_real_percibido is
  'Salario real percibido o remanente operativo usado para completar pagos fuera de deposito.';
