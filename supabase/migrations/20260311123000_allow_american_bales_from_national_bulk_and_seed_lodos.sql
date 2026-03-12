begin;

alter table if exists public.production_runs
  drop constraint if exists production_runs_source_bulk_check;

alter table if exists public.production_runs
  add constraint production_runs_source_bulk_check
  check (
    (
      bale_material = 'BALE_AMERICAN'
      and source_bulk in ('CARDBOARD_BULK_AMERICAN', 'CARDBOARD_BULK_NATIONAL')
    )
    or (
      bale_material in ('BALE_NATIONAL', 'BALE_CLEAN', 'BALE_TRASH')
      and source_bulk = 'CARDBOARD_BULK_NATIONAL'
    )
    or (
      bale_material = 'CAPLE'
      and source_bulk = 'CAPLE'
    )
  );

do $$
declare
  v_area_logistica_id uuid;
  v_basura_material_id uuid;
begin
  select id
    into v_area_logistica_id
    from public.areas
   where upper(btrim(name)) = 'LOGISTICA'
   order by created_at nulls last, id
   limit 1;

  select id
    into v_basura_material_id
    from public.materials
   where upper(btrim(name)) = 'BASURA'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_basura_material_id is null then
    insert into public.materials (
      name,
      area_id,
      inventory_material_code,
      is_active
    )
    values (
      'BASURA',
      v_area_logistica_id,
      'BALE_TRASH',
      true
    )
    returning id into v_basura_material_id;
  else
    update public.materials
       set name = 'BASURA',
           area_id = coalesce(area_id, v_area_logistica_id),
           inventory_material_code = 'BALE_TRASH',
           is_active = true
     where id = v_basura_material_id;
  end if;

  insert into public.commercial_material_catalog (
    code,
    name,
    family,
    material_id,
    inventory_material,
    active
  )
  values (
    'LODOS',
    'LODOS',
    'fiber',
    v_basura_material_id,
    'BALE_TRASH',
    true
  )
  on conflict (code) do update
    set name = excluded.name,
        family = excluded.family,
        material_id = excluded.material_id,
        inventory_material = excluded.inventory_material,
        active = true;
end
$$;

commit;
