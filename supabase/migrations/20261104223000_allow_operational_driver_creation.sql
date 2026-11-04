begin;

-- The Operations fleet catalog is available to Operations and Direction.
-- Keep the existing employee policies; authorize only a new active driver
-- without a linked login or unrelated employee details.
create policy employees_insert_operational_drivers
on public.employees
for insert to authenticated
with check (
  is_driver is true
  and is_active is true
  and user_id is null
  and area_id is null
  and role_title is null
  and phone is null
  and length(btrim(full_name)) > 0
  and exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.is_active is true
      and lower(btrim(p.role)) in (
        'admin', 'ops_manager', 'operacion', 'operations',
        'direccion', 'direction', 'auxiliar_direccion', 'direccion_general'
      )
  )
);

commit;
