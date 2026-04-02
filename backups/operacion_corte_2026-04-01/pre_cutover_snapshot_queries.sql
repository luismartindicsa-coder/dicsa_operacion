-- Snapshot manual previo al corte operativo del 2026-04-01.
-- Ejecutar ANTES de vaciar tablas.
-- Guardar el resultado en un archivo de apoyo, por ejemplo:
-- backups/operacion_corte_2026-04-01/snapshot_2026-03-31.md

-- 1) Conteo de filas por tabla operativa.
select 'inventory_opening_balances_v2' as table_name, count(*) as row_count
from public.inventory_opening_balances_v2
union all
select 'inventory_movements_v2', count(*) from public.inventory_movements_v2
union all
select 'material_transformation_runs_v2', count(*) from public.material_transformation_runs_v2
union all
select 'material_transformation_run_outputs_v2', count(*) from public.material_transformation_run_outputs_v2
union all
select 'movements', count(*) from public.movements
union all
select 'production_runs', count(*) from public.production_runs
union all
select 'material_separation_runs', count(*) from public.material_separation_runs
union all
select 'opening_balances', count(*) from public.opening_balances
union all
select 'pesadas', count(*) from public.pesadas
order by 1;

-- 2) Saldos v2 generales al cierre.
select
  code,
  name,
  opening_kg,
  movement_kg,
  on_hand_kg
from public.v_inventory_general_balance_v2
where coalesce(on_hand_kg, 0) <> 0
order by code;

-- 3) Saldos v2 comerciales al cierre.
select
  code,
  name,
  family,
  general_code,
  opening_kg,
  movement_kg,
  on_hand_kg
from public.v_inventory_commercial_balance_v2
where coalesce(on_hand_kg, 0) <> 0
order by general_code, code;

-- 4) Produccion v2 con unidades historicas disponibles.
select
  r.op_date,
  r.shift,
  gm.code as source_general_code,
  cm.code as output_commercial_code,
  o.output_weight_kg,
  o.output_unit_count,
  coalesce(o.notes, r.notes) as notes
from public.material_transformation_run_outputs_v2 o
join public.material_transformation_runs_v2 r
  on r.id = o.run_id
join public.material_general_catalog_v2 gm
  on gm.id = r.source_general_material_id
join public.material_commercial_catalog_v2 cm
  on cm.id = o.commercial_material_id
order by r.op_date, r.created_at, cm.code;

-- 5) Salidas v2 de comercial al cierre.
select
  op_date,
  flow,
  origin_type,
  c.code as commercial_code,
  c.name as commercial_name,
  weight_kg,
  net_kg,
  scale_ticket,
  counterparty,
  reference,
  notes
from public.inventory_movements_v2 m
join public.material_commercial_catalog_v2 c
  on c.id = m.commercial_material_id
where m.inventory_level = 'COMMERCIAL'
  and m.flow = 'OUT'
order by op_date, created_at;

-- 6) Pesadas historicas.
select *
from public.pesadas
order by fecha, created_at;
