do $$
declare
  v_mat_paper uuid;
  v_mat_scrap uuid;
  v_mat_plastic uuid;
begin
  select id
    into v_mat_paper
    from public.materials
   where inventory_material_code = 'PAPER'::public.inv_material
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_mat_paper is not null then
    insert into public.commercial_material_catalog (
      code,
      name,
      family,
      material_id,
      inventory_material,
      active
    ) values (
      'PAPEL_REVUELTO',
      'PAPEL REVUELTO',
      'fiber',
      v_mat_paper,
      'PAPER'::public.inv_material,
      true
    )
    on conflict (code) do update
      set name = excluded.name,
          family = excluded.family,
          material_id = excluded.material_id,
          inventory_material = excluded.inventory_material,
          active = true;
  end if;

  select id
    into v_mat_scrap
    from public.materials
   where inventory_material_code = 'SCRAP'::public.inv_material
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_mat_scrap is not null then
    insert into public.commercial_material_catalog (
      code,
      name,
      family,
      material_id,
      inventory_material,
      active
    ) values (
      'CHATARRA_MIXTA',
      'CHATARRA MIXTA',
      'metal',
      v_mat_scrap,
      'SCRAP'::public.inv_material,
      true
    )
    on conflict (code) do update
      set name = excluded.name,
          family = excluded.family,
          material_id = excluded.material_id,
          inventory_material = excluded.inventory_material,
          active = true;
  end if;

  select id
    into v_mat_plastic
    from public.materials
   where inventory_material_code = 'PLASTIC'::public.inv_material
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_mat_plastic is not null then
    insert into public.commercial_material_catalog (
      code,
      name,
      family,
      material_id,
      inventory_material,
      active
    ) values (
      'PLASTICO_MIXTO',
      'PLASTICO MIXTO',
      'polymer',
      v_mat_plastic,
      'PLASTIC'::public.inv_material,
      true
    )
    on conflict (code) do update
      set name = excluded.name,
          family = excluded.family,
          material_id = excluded.material_id,
          inventory_material = excluded.inventory_material,
          active = true;
  end if;
end
$$;
