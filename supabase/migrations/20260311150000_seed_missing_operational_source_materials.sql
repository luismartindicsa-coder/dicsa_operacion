do $$
declare
  v_area_id uuid;
begin
  select id
    into v_area_id
    from public.areas
   where upper(btrim(name)) in ('LOGISTICA', 'OPERACIONES')
   order by case when upper(btrim(name)) = 'LOGISTICA' then 0 else 1 end,
            created_at nulls last,
            id
   limit 1;

  update public.materials
     set inventory_material_code = 'PAPER'::public.inv_material,
         is_active = true
   where upper(btrim(coalesce(name, ''))) = 'PAPEL'
     and inventory_material_code is distinct from 'PAPER'::public.inv_material;

  if not exists (
    select 1
      from public.materials
     where inventory_material_code = 'PAPER'::public.inv_material
  ) then
    insert into public.materials (
      name,
      area_id,
      inventory_material_code,
      is_active
    ) values (
      'PAPEL',
      v_area_id,
      'PAPER'::public.inv_material,
      true
    );
  end if;

  update public.materials
     set inventory_material_code = 'SCRAP'::public.inv_material,
         is_active = true
   where upper(btrim(coalesce(name, ''))) in ('CHATARRA', 'SCRAP')
     and inventory_material_code is distinct from 'SCRAP'::public.inv_material;

  if not exists (
    select 1
      from public.materials
     where inventory_material_code = 'SCRAP'::public.inv_material
  ) then
    insert into public.materials (
      name,
      area_id,
      inventory_material_code,
      is_active
    ) values (
      'CHATARRA',
      v_area_id,
      'SCRAP'::public.inv_material,
      true
    );
  end if;

  update public.materials
     set inventory_material_code = 'METAL'::public.inv_material,
         is_active = true
   where upper(btrim(coalesce(name, ''))) = 'METAL'
     and inventory_material_code is distinct from 'METAL'::public.inv_material;

  if not exists (
    select 1
      from public.materials
     where inventory_material_code = 'METAL'::public.inv_material
  ) then
    insert into public.materials (
      name,
      area_id,
      inventory_material_code,
      is_active
    ) values (
      'METAL',
      v_area_id,
      'METAL'::public.inv_material,
      true
    );
  end if;

  update public.materials
     set inventory_material_code = 'WOOD'::public.inv_material,
         is_active = true
   where upper(btrim(coalesce(name, ''))) = 'MADERA'
     and inventory_material_code is distinct from 'WOOD'::public.inv_material;

  if not exists (
    select 1
      from public.materials
     where inventory_material_code = 'WOOD'::public.inv_material
  ) then
    insert into public.materials (
      name,
      area_id,
      inventory_material_code,
      is_active
    ) values (
      'MADERA',
      v_area_id,
      'WOOD'::public.inv_material,
      true
    );
  end if;

  update public.materials
     set inventory_material_code = 'PLASTIC'::public.inv_material,
         is_active = true
   where upper(btrim(coalesce(name, ''))) = 'PLASTICO'
     and inventory_material_code is distinct from 'PLASTIC'::public.inv_material;

  if not exists (
    select 1
      from public.materials
     where inventory_material_code = 'PLASTIC'::public.inv_material
  ) then
    insert into public.materials (
      name,
      area_id,
      inventory_material_code,
      is_active
    ) values (
      'PLASTICO',
      v_area_id,
      'PLASTIC'::public.inv_material,
      true
    );
  end if;
end
$$;
