alter table public.hr_employee_profiles
  add column if not exists employment_status text not null default 'activo',
  add column if not exists termination_date date,
  add column if not exists termination_reason text,
  add column if not exists termination_notes text,
  add column if not exists terminated_at timestamptz,
  add column if not exists terminated_by uuid;

alter table public.hr_employee_profiles
  drop constraint if exists hr_employee_profiles_employment_status_check;

alter table public.hr_employee_profiles
  add constraint hr_employee_profiles_employment_status_check
    check (employment_status in ('activo', 'baja'));

create index if not exists hr_employee_profiles_employment_status_idx
  on public.hr_employee_profiles (employment_status, id);

comment on column public.hr_employee_profiles.employment_status is
  'Estado operativo del colaborador. Baja conserva el expediente pero lo excluye de operaciones futuras de RH.';
