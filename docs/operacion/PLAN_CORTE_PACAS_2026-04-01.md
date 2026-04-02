# Plan De Corte Pacas 2026-04-01

## Objetivo
Reiniciar la operacion de inventario desde el **1 de abril de 2026** con una estructura nueva donde las **pacas contadas** sean la verdad operativa para patio, produccion y salidas, sin arrastrar estimaciones historicas basadas en promedio kg/paca.

## Alcance
Este corte aplica a los modulos operativos de inventario:

- Entradas y salidas
- Produccion / transformacion
- Pesadas
- Aperturas y saldos operativos de inventario

Este corte **no toca Mantenimiento**:

- `maintenance_orders`
- `maintenance_tasks`
- `maintenance_materials`
- `maintenance_time_logs`
- `maintenance_evidence`
- `maintenance_approvals`
- `maintenance_status_log`

## Criterio Del Corte
El historico hasta el **31 de marzo de 2026** se conserva en respaldos CSV.

La operacion nueva inicia el **1 de abril de 2026** con:

- aperturas nuevas
- produccion nueva
- entradas nuevas
- salidas nuevas

## Problema Que Resuelve
Hoy el sistema mezcla dos modelos:

1. `kg` reales
2. `pacas` estimadas por promedio

Eso genera desfases diarios porque:

- produccion puede capturar pacas, pero el inventario termina valuandolas por peso
- salidas historicas no guardan un conteo estructurado de pacas en el movimiento
- patio calcula pacas a partir de kg / promedio en varios puntos del sistema

## Nueva Regla Operativa
Para materiales tipo paca:

- `kg` siguen siendo verdad fisica de peso
- `unit_count` o `pacas` pasan a ser la verdad operativa para conteo

Para materiales no unitarios:

- solo se controla `kg`

## Tablas Que Deben Respaldarse
### Runtime v2
- `public.inventory_opening_balances_v2`
- `public.inventory_movements_v2`
- `public.material_transformation_runs_v2`
- `public.material_transformation_run_outputs_v2`

### Runtime legacy que conviene congelar tambien
- `public.movements`
- `public.production_runs`
- `public.material_separation_runs`
- `public.opening_balances`

### Soporte operativo
- `public.pesadas`

### Catalogos para referencia del corte
- `public.material_general_catalog_v2`
- `public.material_commercial_catalog_v2`
- `public.sites`
- `public.vehicles`
- `public.employees`

## Carpeta Sugerida De Respaldo
`backups/operacion_corte_2026-04-01/`

Archivos sugeridos:

- `inventory_opening_balances_v2.csv`
- `inventory_movements_v2.csv`
- `material_transformation_runs_v2.csv`
- `material_transformation_run_outputs_v2.csv`
- `movements.csv`
- `production_runs.csv`
- `material_separation_runs.csv`
- `opening_balances.csv`
- `pesadas.csv`
- `snapshot_2026-03-31.md`

## Orden Recomendado Del Corte
1. Congelar captura operativa.
2. Exportar CSV de todas las tablas de runtime y soporte.
3. Ejecutar las queries de snapshot del cierre del **2026-03-31**.
4. Validar que los CSV abren y tienen filas.
5. Aplicar migraciones nuevas de modelo de pacas contadas.
6. Vaciar solo runtime operativo.
7. Crear aperturas nuevas al **2026-04-01**.
8. Validar saldos iniciales con usuarios de operacion.
9. Reanudar captura diaria.

## Validaciones Minimas Antes De Vaciar
- Confirmar que los CSV existen fisicamente.
- Confirmar conteo de filas por tabla.
- Confirmar snapshot de saldos de cierre.
- Confirmar que Mantenimiento no entra en el script de limpieza.

## Validaciones Minimas Despues De Vaciar
- `inventory_movements_v2 = 0`
- `material_transformation_runs_v2 = 0`
- `material_transformation_run_outputs_v2 = 0`
- `inventory_opening_balances_v2 = 0`
- `pesadas = 0`
- tablas `maintenance_*` sin cambios

## Validaciones Minimas Despues De La Apertura
- Patio muestra kg correctos de apertura.
- Para materiales tipo paca, patio muestra pacas contadas correctas.
- Una produccion nueva suma `kg` y `pacas`.
- Una salida nueva resta `kg` y `pacas`.
- Dashboard e inventario ya no estiman pacas con promedio cuando exista conteo real.

## Riesgos A Controlar
- Mezclar historico estimado con nuevo conteo real.
- Vaciar tablas de runtime sin validar CSV.
- Dejar aperturas nuevas solo en kg y no en pacas.
- Mantener fallbacks de promedio activos en pantallas donde ya debe existir conteo real.

## Decisiones Tecnicas Recomendadas
1. Agregar `unit_count` a `inventory_movements_v2`.
2. Agregar `unit_count` a `inventory_opening_balances_v2`.
3. Copiar `output_unit_count` desde produccion v2 al movimiento comercial sincronizado.
4. Obligar captura de `unit_count` en salidas de materiales tipo paca.
5. Exponer balances con `opening_units`, `movement_units` y `on_hand_units`.
6. Usar promedio solo como fallback temporal para historico viejo, nunca como verdad principal.

## Comandos Sugeridos De Exportacion
Los CSV deben salir de la base remota real. Si se usa `psql`, el patron recomendado es:

```bash
psql "$SUPABASE_DB_URL" -c "\copy (select * from public.inventory_movements_v2 order by op_date, created_at) to 'backups/operacion_corte_2026-04-01/inventory_movements_v2.csv' csv header"
```

Repetir el mismo patron para cada tabla del corte.

## Scripts Preparados En El Repo
- [pre_cutover_snapshot_queries.sql](/Users/martinvelzat/DICSA/apps/dicsa_operacion/backups/operacion_corte_2026-04-01/pre_cutover_snapshot_queries.sql)
- [clear_operacion_keep_maintenance.sql](/Users/martinvelzat/DICSA/apps/dicsa_operacion/backups/operacion_corte_2026-04-01/clear_operacion_keep_maintenance.sql)

## Nota Final
El corte resuelve el problema solo si el arranque del **1 de abril de 2026** nace ya con la nueva estructura de pacas contadas. Si se reinicia con el mismo modelo estimado, el desfase volvera a aparecer.
