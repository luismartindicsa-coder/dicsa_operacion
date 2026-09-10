# Vacaciones importadas: cálculo normal de pagos

Los pagos confirmados del Excel se registran con el mismo editor y las mismas funciones que **+ Pago**. La ausencia de un monto en el archivo no impide calcular vacaciones, prima, Fiscal, Flujo e ISR a partir de los días y los datos del expediente. Esta es la corrección final indicada por el usuario el 9 de septiembre de 2026.

## Datos y comportamiento

- Los días se toman de **Pagos**, y el ingreso de **Vacaciones** cuando está disponible. El viernes del aniversario se asigna por semana con inicio en domingo: un aniversario en domingo corresponde al viernes siguiente.
- Los eventos permanecen aplicados en su fecha y periodo históricos. La conversión no añade disfrutes, domingos ni cargos nuevos a prenómina.
- Los 35 eventos inicialmente importados sin cálculo pasan al flujo normal: edición de días/domingos, resumen de pago, guardado de componentes y generación de recibo.
- `import_source` conserva archivo, SHA256, hoja, fila, identificador de origen y criterio de fecha. `initial_app_calculation` conserva salarios, días y fecha del cálculo inicial. Los importes se identifican como calculados por la app; el archivo no contenía montos.
- El guardado del editor no sobrescribe `import_source`; así un detalle abierto antes de la migración no elimina datos de procedencia añadidos después.
- El criterio manual de fecha conserva su fecha al abrir y guardar, incluida la diferencia de ingreso encontrada entre un expediente y el Excel.

La primera importación usó una marca de historial sin importe y restricciones que lo excluían del resumen. La migración `20260909224500_use_standard_vacation_payment_calculation.sql` elimina esas restricciones y convierte únicamente los eventos de esa importación que carecen de tramos liquidados y recibos emitidos. La protección normal de pagos realmente liquidados se conserva.

## Alcance y trazabilidad

Se agregaron inicialmente 35 eventos, se vincularon 3 pagos ya existentes y se crearon 18 periodos históricos. La corrección añade los cálculos automáticos a los 35 nuevos; conserva los importes de los 3 previamente capturados. Quedan 8 registros pendientes de aclaraciones de identidad o coincidencia con pagos anteriores. Los 10 pendientes y 4 por confirmar del Excel no se convirtieron en pagos realizados.

Respaldo, plan y resultados por empleado se conservan fuera del repositorio en `/Users/martinvelzat/DICSA/.local/hr_vacations_2026_import/`:

- `before.json`: estado previo a la primera importación.
- `before_calculation_correction.json`: estado previo a esta corrección.
- `calculation_payloads.json`: cálculos generados mediante las funciones reales del editor Flutter.
- `apply_standard_calculations.py`: aplica o verifica esos cálculos, preservando registros ajenos al cambio.
- `standard_calculations_applied.json`: resultado de la aplicación.
- `RESULTADO.md`: detalle de la primera importación y actualización del criterio vigente.

El ejecutor inicial `import_history.py` está archivado para auditoría y rechaza nuevas escrituras. Las próximas importaciones deben preparar pagos estándar y cálculos desde la app. No contiene ni guarda contraseñas. Datos personales y respaldos permanecen fuera del repositorio.

## Validación

- 23 pruebas pasaron: cálculo con salario percibido, reparto Fiscal/Flujo, prima, días adicionales, tabs, edición, conservación de fecha manual, generación de recibo y exportación de los 35 cálculos.
- Las 5 pruebas de historial/tabs se repitieron al proteger la procedencia durante el guardado.
- El ensayo de esquema y datos se revirtió antes de aplicar.
- La verificación compara los 35 cálculos contra sus payloads y conserva los 10 cálculos anteriores. Fechas, periodos, días, disfrutes e impactos previos permanecen intactos.
- Personal, asistencias, borradores de prenómina y cierres de nómina se comparan contra el respaldo. El periodo 37 queda intacto.
- `dart analyze` conserva dos advertencias previas de funciones de asistencia sin uso, sin nuevos errores.

Este archivo documenta pagos; no incorpora disfrutes anteriores que no estén capturados. La disponibilidad definitiva de días depende de completar ese historial de disfrute.
