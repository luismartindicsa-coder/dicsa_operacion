begin;

-- Corte operativo para reinicio del 2026-04-01.
-- Este script NO toca mantenimiento.
-- Ejecutar solo despues de:
-- 1) exportar CSV
-- 2) guardar snapshot de cierre
-- 3) aplicar la nueva estructura de pacas contadas

do $$
begin
  raise notice 'Iniciando limpieza de runtime operativo. Mantenimiento no se toca.';

  -- Runtime v2
  delete from public.inventory_movements_v2;
  delete from public.inventory_opening_balances_v2;
  delete from public.material_transformation_run_outputs_v2;
  delete from public.material_transformation_runs_v2;

  -- Soporte operativo
  delete from public.pesadas;

  -- Runtime legacy. Se limpia para evitar que pantallas antiguas sigan
  -- mostrando historico mezclado con el nuevo arranque.
  delete from public.movements;
  truncate table public.material_separation_runs restart identity;
  truncate table public.production_runs restart identity;
  delete from public.opening_balances;

  raise notice 'Limpieza operativa terminada.';
end
$$;

commit;
