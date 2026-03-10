do $$
declare
  v_area_id uuid;
  v_caple_material_id uuid;
  v_paca_limpia_material_id uuid;
begin
  select id
    into v_area_id
    from public.areas
   where upper(name) = 'LOGISTICA'
   limit 1;

  select id
    into v_caple_material_id
    from public.materials
   where upper(name) = 'CAPLE'
   limit 1;

  if v_caple_material_id is null then
    insert into public.materials (
      name,
      area_id,
      is_active,
      inventory_material_code
    )
    values (
      'CAPLE',
      v_area_id,
      true,
      'CAPLE'
    )
    returning id into v_caple_material_id;
  else
    update public.materials
       set is_active = true,
           area_id = coalesce(area_id, v_area_id),
           inventory_material_code = coalesce(nullif(inventory_material_code, ''), 'CAPLE')
     where id = v_caple_material_id;
  end if;

  select id
    into v_paca_limpia_material_id
    from public.materials
   where upper(name) = 'PACA LIMPIA'
   limit 1;

  if v_paca_limpia_material_id is null then
    insert into public.materials (
      name,
      area_id,
      is_active,
      inventory_material_code
    )
    values (
      'PACA LIMPIA',
      v_area_id,
      true,
      'BALE_CLEAN'
    )
    returning id into v_paca_limpia_material_id;
  else
    update public.materials
       set is_active = true,
           area_id = coalesce(area_id, v_area_id),
           inventory_material_code = coalesce(nullif(inventory_material_code, ''), 'BALE_CLEAN')
     where id = v_paca_limpia_material_id;
  end if;

  if v_caple_material_id is not null then
    if exists (
      select 1
        from public.commercial_material_catalog
       where code = 'CAPLE'
    ) then
      update public.commercial_material_catalog
         set name = 'CAPLE',
             active = true,
             material_id = v_caple_material_id,
             inventory_material = 'CAPLE'
       where code = 'CAPLE';
    else
      insert into public.commercial_material_catalog (
        code,
        name,
        family,
        material_id,
        inventory_material,
        active
      )
      values (
        'CAPLE',
        'CAPLE',
        'other',
        v_caple_material_id,
        'CAPLE',
        true
      );
    end if;
  end if;

  if v_paca_limpia_material_id is not null then
    if exists (
      select 1
        from public.commercial_material_catalog
       where code = 'PACA_LIMPIA'
    ) then
      update public.commercial_material_catalog
         set name = 'PACA LIMPIA',
             active = true,
             material_id = v_paca_limpia_material_id,
             inventory_material = 'BALE_CLEAN'
       where code = 'PACA_LIMPIA';
    else
      insert into public.commercial_material_catalog (
        code,
        name,
        family,
        material_id,
        inventory_material,
        active
      )
      values (
        'PACA_LIMPIA',
        'PACA LIMPIA',
        'other',
        v_paca_limpia_material_id,
        'BALE_CLEAN',
        true
      );
    end if;
  end if;
end
$$;
