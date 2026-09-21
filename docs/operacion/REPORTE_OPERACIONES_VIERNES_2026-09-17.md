# Operaciones: corte de viernes

El botón existente `Generar viernes` reúne seguimiento de OTs, gastos y
producción. Se conserva la identidad azul y el formato ejecutivo de Supervisión.
El diario queda limitado a OTs nuevas; limpieza se retira del catálogo y del PDF.

## Corte y fuentes

- Lunes al viernes de la semana de generación, acumulado hasta el momento de
  generación. Sábado y domingo conservan el viernes recién terminado.
- OTs: `maintenance_orders`. Mantiene abiertas, atrasadas, críticas, responsables,
  equipos y movimientos resueltos; las fechas futuras se excluyen.
- Compras: `maintenance_purchase_orders` y sus renglones. Solo las OCs con
  referencia explícita de OT participan en gastos de Operaciones.
- Producción: `material_transformation_runs_v2` y sus salidas, por material,
  fecha operativa y turno. Incluye los materiales de transformación registrados,
  no solo cartón. Comparación contra el mismo avance de la semana anterior.
- `production_runs` sirve como respaldo de pacas para cada ventana sin
  transformaciones de cartón. Nunca se suma encima de cartón V2; tampoco se
  suman otra vez los movimientos de inventario que genera la transformación.

## Interpretación de importes y cantidades

- Gasto semanal: importe real registrado de OCs compradas, usando `purchased_at`,
  aunque la OC se haya creado antes. Comprada no equivale a pagada.
- Costo de OT: acumulado vigente de la OT. Se presenta separado del gasto
  semanal de OCs para evitar sumarlos dos veces. Se muestran OTs abiertas,
  con movimiento en la semana o con compras dentro del corte.
- Sobrecosto: real menos estimado, sobre la misma OT u OC y solo con ambos
  importes positivos. Ceros automáticos y faltantes no prueban ahorro.
- OCs sin fecha de compra se muestran para corregir y no se asignan a una semana.
- El UUID de OT tiene prioridad. El folio solo resuelve cuando falta UUID y
  existe una coincidencia única. Referencias rotas quedan visibles como tales.
- Kilos son los pesos registrados; no se calculan desde unidades. El respaldo
  histórico de pacas conserva unidades, pero no inventa peso.
- Unidades se muestran por material; no se suman materiales distintos como si
  todas las unidades fueran pacas. La producción tiene fecha operativa, sin hora.
- Variación semanal no equivale a cumplimiento de meta ni prueba un cuello de
  botella. No se crean metas o causas a partir del volumen.
- Estatus e importes son los vigentes al generar, no un snapshot histórico.

## Cobertura pendiente

Incidencias en patio conserva su estatus pendiente y aparece como tal en el PDF.
No existe todavía una captura formal para afirmar un número de incidencias.

## Validación

Pruebas en `test/management_reports/operations_weekly_analysis_test.dart`:
separación de costos, fechas de compra, faltantes, vínculos, exclusión de
duplicados V2/histórico, comparación equivalente, fines de semana y generación
con datos densos/vacíos. Los PDF de QA usan datos ficticios.

Para exportar muestras al ejecutar pruebas:

```sh
DICSA_OPERATIONS_QA_DIR=/private/tmp/dicsa_operations_qa flutter test --no-pub test/management_reports/operations_weekly_analysis_test.dart
```
