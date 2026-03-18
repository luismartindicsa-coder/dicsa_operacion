begin;

create or replace function public.fn_validate_inventory_movement_stock_v2()
returns trigger
language plpgsql
as $$
declare
  v_opening numeric := 0;
  v_movements numeric := 0;
  v_available numeric := 0;
  v_delta numeric := 0;
  v_material_name text := '';
begin
  if new.flow = 'IN' then
    return new;
  end if;

  if new.inventory_level = 'GENERAL' then
    select coalesce(sum(weight_kg), 0)
      into v_opening
      from public.inventory_opening_balances_v2
     where inventory_level = 'GENERAL'
       and general_material_id = new.general_material_id
       and site = new.site;

    select coalesce(sum(
      case flow
        when 'IN' then weight_kg
        when 'OUT' then -weight_kg
        else weight_kg
      end
    ), 0)
      into v_movements
      from public.inventory_movements_v2
     where inventory_level = 'GENERAL'
       and general_material_id = new.general_material_id
       and site = new.site
       and id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

    select coalesce(name, code, 'material general')
      into v_material_name
      from public.material_general_catalog_v2
     where id = new.general_material_id;
  else
    select coalesce(sum(weight_kg), 0)
      into v_opening
      from public.inventory_opening_balances_v2
     where inventory_level = 'COMMERCIAL'
       and commercial_material_id = new.commercial_material_id
       and site = new.site;

    select coalesce(sum(
      case flow
        when 'IN' then weight_kg
        when 'OUT' then -weight_kg
        else weight_kg
      end
    ), 0)
      into v_movements
      from public.inventory_movements_v2
     where inventory_level = 'COMMERCIAL'
       and commercial_material_id = new.commercial_material_id
       and site = new.site
       and id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

    select coalesce(name, code, 'material comercial')
      into v_material_name
      from public.material_commercial_catalog_v2
     where id = new.commercial_material_id;
  end if;

  v_available := v_opening + v_movements;
  v_delta := case new.flow
    when 'OUT' then -new.weight_kg
    when 'ADJUSTMENT' then new.weight_kg
    else new.weight_kg
  end;

  if v_available + v_delta < 0 then
    raise exception
      using errcode = 'P0001',
            message = format(
              'Inventario insuficiente para %s. Disponible: %s kg, intento: %s kg.',
              v_material_name,
              trim(to_char(v_available, 'FM9999999990.000')),
              trim(to_char(abs(v_delta), 'FM9999999990.000'))
            );
  end if;

  return new;
end
$$;

drop trigger if exists trg_validate_inventory_movement_stock_v2
  on public.inventory_movements_v2;

create trigger trg_validate_inventory_movement_stock_v2
before insert or update on public.inventory_movements_v2
for each row execute function public.fn_validate_inventory_movement_stock_v2();

commit;
