create or replace function public.fn_autofill_commercial_inventory_material()
returns trigger
language plpgsql
as $$
declare
  v_inventory_material public.inv_material;
  v_general_name text;
begin
  case upper(coalesce(new.code, ''))
    when 'LODOS' then
      v_inventory_material := 'LODOS'::public.inv_material;
    else
      v_inventory_material := null;
  end case;

  if v_inventory_material is null and new.material_id is not null then
    select m.inventory_material_code, upper(btrim(coalesce(m.name, '')))
      into v_inventory_material, v_general_name
      from public.materials m
     where m.id = new.material_id
     limit 1;
  end if;

  if v_inventory_material is null then
    case upper(coalesce(new.code, ''))
      when 'CARTON_NACIONAL' then
        v_inventory_material := 'CARDBOARD_BULK_NATIONAL'::public.inv_material;
      when 'CARTON_AMERICANO' then
        v_inventory_material := 'CARDBOARD_BULK_AMERICAN'::public.inv_material;
      when 'PACA_NACIONAL' then
        v_inventory_material := 'BALE_NATIONAL'::public.inv_material;
      when 'PACA_AMERICANA' then
        v_inventory_material := 'BALE_AMERICAN'::public.inv_material;
      when 'PACA_LIMPIA' then
        v_inventory_material := 'BALE_CLEAN'::public.inv_material;
      when 'PACA_BASURA' then
        v_inventory_material := 'BALE_TRASH'::public.inv_material;
      when 'BASURA' then
        v_inventory_material := 'BALE_TRASH'::public.inv_material;
      when 'CAPLE' then
        v_inventory_material := 'CAPLE'::public.inv_material;
      else
        v_inventory_material := null;
    end case;
  end if;

  if v_inventory_material is null then
    case v_general_name
      when 'PAPEL' then
        v_inventory_material := 'PAPER'::public.inv_material;
      when 'CHATARRA' then
        v_inventory_material := 'SCRAP'::public.inv_material;
      when 'PLASTICO' then
        v_inventory_material := 'PLASTIC'::public.inv_material;
      when 'MADERA' then
        v_inventory_material := 'WOOD'::public.inv_material;
      when 'METAL' then
        v_inventory_material := 'METAL'::public.inv_material;
      when 'BASURA' then
        v_inventory_material := 'BALE_TRASH'::public.inv_material;
      else
        v_inventory_material := null;
    end case;
  end if;

  if v_inventory_material is not null then
    new.inventory_material := v_inventory_material;
  end if;

  return new;
end
$$;

update public.commercial_material_catalog
   set inventory_material = 'LODOS'
 where upper(coalesce(code, '')) = 'LODOS';
