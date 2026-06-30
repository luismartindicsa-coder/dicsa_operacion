alter table public.hr_employee_profiles
  add column if not exists dias_labora text[] not null default '{}'::text[],
  add column if not exists talla_uniforme text;

comment on column public.hr_employee_profiles.dias_labora is
  'Dias de la semana en los que el colaborador se presenta regularmente.';

comment on column public.hr_employee_profiles.talla_uniforme is
  'Talla de uniforme del colaborador para control operativo y expediente.';
