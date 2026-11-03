begin;

alter table public.logistics_vehicle_profiles
  add column assigned_driver_employee_id uuid
    references public.employees(id) on delete set null;

create index logistics_vehicle_profiles_assigned_driver_idx
  on public.logistics_vehicle_profiles (assigned_driver_employee_id)
  where assigned_driver_employee_id is not null;

comment on column public.logistics_vehicle_profiles.assigned_driver_employee_id is
  'Chofer asignado a la unidad desde el catálogo de Logística. NULL si no tiene asignación.';

commit;
