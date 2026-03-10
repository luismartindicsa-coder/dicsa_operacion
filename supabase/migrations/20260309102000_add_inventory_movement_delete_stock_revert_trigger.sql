begin;

create or replace function public.revert_inventory_movement_from_stock()
returns trigger
language plpgsql
as $$
declare
  v_delta numeric(14,3);
begin
  if old.movement_type::text in ('entrada', 'apertura') then
    v_delta := old.quantity;
  elsif old.movement_type::text in ('salida', 'cierre') then
    v_delta := -old.quantity;
  else
    -- ajuste accepts signed quantity
    v_delta := old.quantity;
  end if;

  update public.inventory_items
  set current_stock = current_stock - v_delta,
      updated_at = now()
  where id = old.item_id
    and (current_stock - v_delta) >= 0;

  if not found then
    raise exception 'Eliminar movimiento invalido: stock quedaria negativo para item_id=%', old.item_id;
  end if;

  return old;
end;
$$;

drop trigger if exists trg_revert_inventory_movement_from_stock on public.inventory_movements;
create trigger trg_revert_inventory_movement_from_stock
after delete on public.inventory_movements
for each row
execute function public.revert_inventory_movement_from_stock();

commit;
