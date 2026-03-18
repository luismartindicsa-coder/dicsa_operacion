begin;

create or replace function public.fn_normalize_manual_movement_material()
returns trigger
language plpgsql
as $$
declare
  v_commercial_code text := nullif(btrim(coalesce(new.commercial_material_code, '')), '');
  v_inventory_material public.inv_material;
  v_product_material_id uuid;
  v_source_code text;
  v_has_rule boolean := false;
begin
  if upper(coalesce(new.movement_origin, 'MANUAL')) <> 'MANUAL' then
    return new;
  end if;

  if v_commercial_code is null then
    return new;
  end if;

  select cmc.inventory_material, cmc.material_id
    into v_inventory_material, v_product_material_id
    from public.commercial_material_catalog cmc
   where upper(cmc.code) = upper(v_commercial_code)
   limit 1;

  if v_inventory_material is null then
    return new;
  end if;

  if new.material_id is not null then
    select coalesce(m.inventory_material_code::text, m.inventory_general_code::text)
      into v_source_code
      from public.materials m
     where m.id = new.material_id
     limit 1;
  end if;

  v_source_code := upper(btrim(coalesce(v_source_code, new.material::text, '')));

  if v_source_code <> '' then
    select exists(
      select 1
        from public.commercial_material_source_rules r
       where upper(r.commercial_material_code) = upper(v_commercial_code)
         and r.allowed_source_material::text = v_source_code
         and r.is_active
    )
      into v_has_rule;
  end if;

  if v_has_rule or upper(v_inventory_material::text) = v_source_code then
    new.material := v_inventory_material;
    if v_product_material_id is not null then
      new.material_id := v_product_material_id;
    end if;
    return new;
  end if;

  raise exception 'El material comercial "%" no corresponde al material general seleccionado', v_commercial_code;
end
$$;

drop trigger if exists trg_normalize_manual_movement_material on public.movements;

create trigger trg_normalize_manual_movement_material
before insert or update of material_id, material, commercial_material_code, movement_origin
on public.movements
for each row
execute function public.fn_normalize_manual_movement_material();

commit;
