do $$
declare
  v_type_oid oid;
begin
  for v_type_oid in
    select a.atttypid
      from pg_attribute a
      join pg_class c on c.oid = a.attrelid
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and (
         (c.relname = 'materials' and a.attname = 'inventory_material_code')
         or (c.relname = 'materials' and a.attname = 'inventory_general_code')
         or (c.relname = 'commercial_material_catalog' and a.attname = 'inventory_material')
       )
       and a.attnum > 0
       and not a.attisdropped
  loop
    if exists (select 1 from pg_type t where t.oid = v_type_oid and t.typtype = 'e')
       and not exists (
         select 1 from pg_enum e where e.enumtypid = v_type_oid and e.enumlabel = 'LODOS'
       )
    then
      execute format('alter type %s add value %L', v_type_oid::regtype, 'LODOS');
    end if;
  end loop;
end
$$;
