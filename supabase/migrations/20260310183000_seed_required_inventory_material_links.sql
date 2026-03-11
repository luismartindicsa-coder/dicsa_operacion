begin;

do $$
declare
  v_area_id uuid;
  v_carton_nacional_id uuid;
  v_carton_americano_id uuid;
  v_paca_nacional_id uuid;
  v_paca_americana_id uuid;
  v_paca_limpia_id uuid;
  v_paca_basura_id uuid;
  v_caple_id uuid;
begin
  select id
    into v_area_id
    from public.areas
   where upper(btrim(name)) in ('LOGISTICA', 'OPERACIONES')
   order by case when upper(btrim(name)) = 'LOGISTICA' then 0 else 1 end,
            created_at nulls last,
            id
   limit 1;

  select id
    into v_carton_nacional_id
    from public.materials
   where inventory_material_code = 'CARDBOARD_BULK_NATIONAL'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_carton_nacional_id is null then
    select id
      into v_carton_nacional_id
      from public.materials
     where upper(btrim(name)) = 'CARTON NACIONAL'
       and (v_area_id is null or area_id = v_area_id)
     order by is_active desc, created_at nulls last, id
     limit 1;
    if v_carton_nacional_id is null then
      insert into public.materials (name, area_id, inventory_material_code, is_active)
      values ('CARTON NACIONAL', v_area_id, 'CARDBOARD_BULK_NATIONAL', true)
      returning id into v_carton_nacional_id;
    else
      update public.materials
         set inventory_material_code = 'CARDBOARD_BULK_NATIONAL',
             is_active = true
       where id = v_carton_nacional_id;
    end if;
  end if;

  select id
    into v_carton_americano_id
    from public.materials
   where inventory_material_code = 'CARDBOARD_BULK_AMERICAN'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_carton_americano_id is null then
    select id
      into v_carton_americano_id
      from public.materials
     where upper(btrim(name)) = 'CARTON AMERICANO'
       and (v_area_id is null or area_id = v_area_id)
     order by is_active desc, created_at nulls last, id
     limit 1;
    if v_carton_americano_id is null then
      insert into public.materials (name, area_id, inventory_material_code, is_active)
      values ('CARTON AMERICANO', v_area_id, 'CARDBOARD_BULK_AMERICAN', true)
      returning id into v_carton_americano_id;
    else
      update public.materials
         set inventory_material_code = 'CARDBOARD_BULK_AMERICAN',
             is_active = true
       where id = v_carton_americano_id;
    end if;
  end if;

  select id
    into v_paca_nacional_id
    from public.materials
   where inventory_material_code = 'BALE_NATIONAL'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_paca_nacional_id is null then
    select id
      into v_paca_nacional_id
      from public.materials
     where upper(btrim(name)) = 'PACA NACIONAL'
       and (v_area_id is null or area_id = v_area_id)
     order by is_active desc, created_at nulls last, id
     limit 1;
    if v_paca_nacional_id is null then
      insert into public.materials (name, area_id, inventory_material_code, is_active)
      values ('PACA NACIONAL', v_area_id, 'BALE_NATIONAL', true)
      returning id into v_paca_nacional_id;
    else
      update public.materials
         set inventory_material_code = 'BALE_NATIONAL',
             is_active = true
       where id = v_paca_nacional_id;
    end if;
  end if;

  select id
    into v_paca_americana_id
    from public.materials
   where inventory_material_code = 'BALE_AMERICAN'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_paca_americana_id is null then
    select id
      into v_paca_americana_id
      from public.materials
     where upper(btrim(name)) = 'PACA AMERICANA'
       and (v_area_id is null or area_id = v_area_id)
     order by is_active desc, created_at nulls last, id
     limit 1;
    if v_paca_americana_id is null then
      insert into public.materials (name, area_id, inventory_material_code, is_active)
      values ('PACA AMERICANA', v_area_id, 'BALE_AMERICAN', true)
      returning id into v_paca_americana_id;
    else
      update public.materials
         set inventory_material_code = 'BALE_AMERICAN',
             is_active = true
       where id = v_paca_americana_id;
    end if;
  end if;

  select id
    into v_paca_limpia_id
    from public.materials
   where inventory_material_code = 'BALE_CLEAN'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_paca_limpia_id is null then
    select id
      into v_paca_limpia_id
      from public.materials
     where upper(btrim(name)) = 'PACA LIMPIA'
       and (v_area_id is null or area_id = v_area_id)
     order by is_active desc, created_at nulls last, id
     limit 1;
    if v_paca_limpia_id is null then
      insert into public.materials (name, area_id, inventory_material_code, is_active)
      values ('PACA LIMPIA', v_area_id, 'BALE_CLEAN', true)
      returning id into v_paca_limpia_id;
    else
      update public.materials
         set inventory_material_code = 'BALE_CLEAN',
             is_active = true
       where id = v_paca_limpia_id;
    end if;
  end if;

  select id
    into v_paca_basura_id
    from public.materials
   where inventory_material_code = 'BALE_TRASH'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_paca_basura_id is null then
    select id
      into v_paca_basura_id
      from public.materials
     where upper(btrim(name)) = 'PACA BASURA'
       and (v_area_id is null or area_id = v_area_id)
     order by is_active desc, created_at nulls last, id
     limit 1;
    if v_paca_basura_id is null then
      insert into public.materials (name, area_id, inventory_material_code, is_active)
      values ('PACA BASURA', v_area_id, 'BALE_TRASH', true)
      returning id into v_paca_basura_id;
    else
      update public.materials
         set inventory_material_code = 'BALE_TRASH',
             is_active = true
       where id = v_paca_basura_id;
    end if;
  end if;

  select id
    into v_caple_id
    from public.materials
   where inventory_material_code = 'CAPLE'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_caple_id is null then
    select id
      into v_caple_id
      from public.materials
     where upper(btrim(name)) = 'CAPLE'
       and (v_area_id is null or area_id = v_area_id)
     order by is_active desc, created_at nulls last, id
     limit 1;
    if v_caple_id is null then
      insert into public.materials (name, area_id, inventory_material_code, is_active)
      values ('CAPLE', v_area_id, 'CAPLE', true)
      returning id into v_caple_id;
    else
      update public.materials
         set inventory_material_code = 'CAPLE',
             is_active = true
       where id = v_caple_id;
    end if;
  end if;

  insert into public.commercial_material_catalog (
    code, name, family, material_id, inventory_material, active
  )
  values
    ('CARTON_NACIONAL', 'CARTON NACIONAL', 'fiber', v_carton_nacional_id, 'CARDBOARD_BULK_NATIONAL', true),
    ('CARTON_AMERICANO', 'CARTON AMERICANO', 'fiber', v_carton_americano_id, 'CARDBOARD_BULK_AMERICAN', true),
    ('PACA_NACIONAL', 'PACA NACIONAL', 'fiber', v_paca_nacional_id, 'BALE_NATIONAL', true),
    ('PACA_AMERICANA', 'PACA AMERICANA', 'fiber', v_paca_americana_id, 'BALE_AMERICAN', true),
    ('PACA_LIMPIA', 'PACA LIMPIA', 'fiber', v_paca_limpia_id, 'BALE_CLEAN', true),
    ('PACA_BASURA', 'PACA BASURA', 'fiber', v_paca_basura_id, 'BALE_TRASH', true),
    ('CAPLE', 'CAPLE', 'fiber', v_caple_id, 'CAPLE', true)
  on conflict (code) do update
    set name = excluded.name,
        family = excluded.family,
        material_id = excluded.material_id,
        inventory_material = excluded.inventory_material,
        active = true;
end
$$;

commit;
