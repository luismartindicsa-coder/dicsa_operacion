begin;

-- Legacy compatibility: some projects still have old required columns in maintenance_orders.
-- We only relax known legacy columns that conflict with the new OT sheet flow.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'maintenance_orders'
      and column_name = 'vehicle_id'
  ) then
    execute 'alter table public.maintenance_orders alter column vehicle_id drop not null';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'maintenance_orders'
      and column_name = 'driver_id'
  ) then
    execute 'alter table public.maintenance_orders alter column driver_id drop not null';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'maintenance_orders'
      and column_name = 'site_id'
  ) then
    execute 'alter table public.maintenance_orders alter column site_id drop not null';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'maintenance_orders'
      and column_name = 'opened_by'
  ) then
    execute 'alter table public.maintenance_orders alter column opened_by drop not null';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'maintenance_orders'
      and column_name = 'opened_at'
  ) then
    execute 'alter table public.maintenance_orders alter column opened_at drop not null';
  end if;
end
$$;

commit;
