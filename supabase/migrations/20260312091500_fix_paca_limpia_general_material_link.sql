begin;

do $$
declare
  v_carton_nacional_id uuid;
begin
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
     order by is_active desc, created_at nulls last, id
     limit 1;
  end if;

  if v_carton_nacional_id is null then
    raise exception 'No existe el material general CARTON NACIONAL / CARDBOARD_BULK_NATIONAL';
  end if;

  update public.commercial_material_catalog
     set material_id = v_carton_nacional_id,
         inventory_material = 'BALE_CLEAN'::public.inv_material,
         active = true
   where code = 'PACA_LIMPIA';
end
$$;

commit;
