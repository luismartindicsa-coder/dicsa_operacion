# Backup Manifest 2026-04-01

Respaldo generado antes del corte operativo para pacas contadas.

## Archivos generados

| Archivo | Tamano bytes |
|---|---:|
| employees.csv | 1680 |
| inventory_movements_v2.csv | 261740 |
| inventory_opening_balances_v2.csv | 1760 |
| material_commercial_catalog_v2.csv | 18968 |
| material_general_catalog_v2.csv | 1223 |
| material_separation_runs.csv | 1 |
| material_transformation_run_outputs_v2.csv | 17246 |
| material_transformation_runs_v2.csv | 16886 |
| movements.csv | 1 |
| opening_balances.csv | 1 |
| pesadas.csv | 6941 |
| production_runs.csv | 1 |
| sites.csv | 4265 |
| snapshot_v_inventory_commercial_balance_v2.csv | 6270 |
| snapshot_v_inventory_general_balance_v2.csv | 488 |
| vehicles.csv | 2879 |

## Notas

- `inventory_movements_v2.csv`, `material_transformation_runs_v2.csv`, `material_transformation_run_outputs_v2.csv`, `pesadas.csv` y catalogos salieron con contenido.
- `snapshot_v_inventory_general_balance_v2.csv` y `snapshot_v_inventory_commercial_balance_v2.csv` quedaron como corte de saldos visibles.
- `movements.csv`, `production_runs.csv`, `opening_balances.csv` y `material_separation_runs.csv` quedaron vacios en esta exportacion; se interpretan como tablas sin runtime activo o sin historico vigente en este proyecto actual.
- El intento de `supabase db dump` a SQL completo fallo porque la maquina no tiene Docker activo; el respaldo operativo se sostiene con los CSV generados arriba.
