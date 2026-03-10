do $$
declare
  v_type_oid oid;
begin
  select a.atttypid
    into v_type_oid
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'materials'
     and a.attname = 'inventory_material_code'
     and a.attnum > 0
     and not a.attisdropped
   limit 1;

  if v_type_oid is not null
     and exists (select 1 from pg_type t where t.oid = v_type_oid and t.typtype = 'e')
     and not exists (
       select 1 from pg_enum e where e.enumtypid = v_type_oid and e.enumlabel = 'CAPLE'
     )
  then
    execute format('alter type %s add value %L', v_type_oid::regtype, 'CAPLE');
  end if;

  select a.atttypid
    into v_type_oid
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'materials'
     and a.attname = 'inventory_general_code'
     and a.attnum > 0
     and not a.attisdropped
   limit 1;

  if v_type_oid is not null
     and exists (select 1 from pg_type t where t.oid = v_type_oid and t.typtype = 'e')
     and not exists (
       select 1 from pg_enum e where e.enumtypid = v_type_oid and e.enumlabel = 'CAPLE'
     )
  then
    execute format('alter type %s add value %L', v_type_oid::regtype, 'CAPLE');
  end if;

  select a.atttypid
    into v_type_oid
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'commercial_material_catalog'
     and a.attname = 'inventory_material'
     and a.attnum > 0
     and not a.attisdropped
   limit 1;

  if v_type_oid is not null
     and exists (select 1 from pg_type t where t.oid = v_type_oid and t.typtype = 'e')
     and not exists (
       select 1 from pg_enum e where e.enumtypid = v_type_oid and e.enumlabel = 'CAPLE'
     )
  then
    execute format('alter type %s add value %L', v_type_oid::regtype, 'CAPLE');
  end if;
end
$$;
