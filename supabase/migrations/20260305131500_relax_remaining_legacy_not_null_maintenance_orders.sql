begin;

-- Relax legacy NOT NULL constraints that conflict with the new OT sheet model.
-- Only applies if these columns exist in old schemas.
do $$
declare
  c text;
  legacy_cols text[] := array[
    'description',
    'issue',
    'failure_description',
    'details',
    'vehicle_id',
    'driver_id',
    'site_id',
    'opened_by',
    'opened_at',
    'approved_by',
    'approved_at',
    'closed_by',
    'closed_at',
    'cost',
    'estimated_cost'
  ];
begin
  foreach c in array legacy_cols loop
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'maintenance_orders'
        and column_name = c
        and is_nullable = 'NO'
    ) then
      execute format('alter table public.maintenance_orders alter column %I drop not null', c);
    end if;
  end loop;
end
$$;

commit;
