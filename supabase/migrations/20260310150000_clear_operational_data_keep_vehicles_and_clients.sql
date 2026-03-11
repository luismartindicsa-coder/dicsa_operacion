begin;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'employee_id'
  ) then
    update public.profiles
    set employee_id = null
    where employee_id is not null;
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'vehicle_driver_assignments'
  ) then
    delete from public.vehicle_driver_assignments;
  end if;

  delete from public.maintenance_evidence;
  delete from public.maintenance_approvals;
  delete from public.maintenance_status_log;
  delete from public.maintenance_time_logs;
  delete from public.maintenance_materials;
  delete from public.maintenance_tasks;
  delete from public.maintenance_orders;

  delete from public.dashboard_inventory_widgets;

  delete from public.opening_balances;
  delete from public.inventory_monthly_cut_lines;
  delete from public.inventory_monthly_cuts;
  delete from public.inventory_movements;
  delete from public.inventory_items;

  delete from public.services;
  delete from public.pesadas;
  truncate table public.material_separation_runs;
  truncate table public.production_runs;
  truncate table public.movements;

  delete from public.inventory_opening_templates;
  delete from public.commercial_material_catalog;
  delete from public.materials;
  delete from public.employees;

  delete from public.sites
  where coalesce(type, '') <> 'cliente';
end
$$;

commit;
