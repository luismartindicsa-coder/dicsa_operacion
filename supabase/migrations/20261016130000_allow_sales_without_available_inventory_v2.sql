begin;

-- Entradas y Salidas records commercial OUT movements with origin SALE.
-- Record and edit these shipments even when the available stock is insufficient;
-- the movement still participates in the inventory balance, including negatives.
drop trigger if exists trg_validate_inventory_movement_stock_v2
  on public.inventory_movements_v2;

create trigger trg_validate_inventory_movement_stock_v2
before insert or update on public.inventory_movements_v2
for each row
when (not (
  new.flow = 'OUT'
  and new.inventory_level = 'COMMERCIAL'
  and new.origin_type = 'SALE'
))
execute function public.fn_validate_inventory_movement_stock_v2();

comment on trigger trg_validate_inventory_movement_stock_v2
  on public.inventory_movements_v2 is
  'Valida existencias excepto en salidas comerciales de venta: Entradas y Salidas permite registrar y editar salidas con saldo insuficiente o negativo.';

commit;
