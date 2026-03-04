-- Fix Supabase security lints:
-- - 0007 policy_exists_rls_disabled
-- - 0010 security_definer_view
-- - 0013 rls_disabled_in_public

begin;

-- 1) Enable RLS and create baseline authenticated policies for exposed public tables.
do $$
declare
  tbl text;
  tables text[] := array[
    'profiles',
    'vehicles',
    'areas',
    'odometer_logs',
    'trip_cargo',
    'trip_documents',
    'sites',
    'fuel_logs',
    'maintenance_orders',
    'maintenance_items',
    'production_events',
    'inventory_lots',
    'trip_materials',
    'vehicle_driver_assignments',
    'services',
    'dispatch_rules',
    'trips',
    'vehicle_capabilities',
    'production_runs',
    'movements',
    'materials',
    'inventory_monthly_cuts',
    'opening_balances',
    'commercial_material_catalog',
    'inventory_opening_templates'
  ];
  policy_name text;
begin
  foreach tbl in array tables loop
    execute format('alter table if exists public.%I enable row level security', tbl);

    -- Keep API behavior working for signed-in users once RLS is enabled.
    execute format('grant select, insert, update, delete on table public.%I to authenticated', tbl);

    policy_name := format('%s_authenticated_all', tbl);

    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = tbl
        and policyname = policy_name
    ) then
      execute format(
        'create policy %I on public.%I for all to authenticated using (true) with check (true)',
        policy_name,
        tbl
      );
    end if;
  end loop;
end
$$;

-- 2) Convert SECURITY DEFINER views to SECURITY INVOKER.
do $$
declare
  vw text;
  views text[] := array[
    'v_vehicle_current_driver',
    'v_inventory_summary',
    'v_services_grid',
    'v_cardboard_widget',
    'v_trip_summary',
    'v_dispatch_candidates'
  ];
begin
  foreach vw in array views loop
    execute format('alter view if exists public.%I set (security_invoker = true)', vw);
    execute format('grant select on table public.%I to authenticated', vw);
  end loop;
end
$$;

commit;
