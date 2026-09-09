# Prenómina: diagnóstico por empleado

Alcance: estructura y presentación del editor de Prenómina. La petición de refactor sustituye la distribución del diálogo descrita en el contrato visual anterior; mantiene su contrato funcional. Los cambios previos de asistencia, permisos y vinculación de importaciones no forman parte de este refactor.

## Inventario de la implementación de partida

A. **Automáticos:** empleado, empresa, salario semanal, percibido semanal, fechas de ingreso/alta, periodo seleccionado, fuentes operativas, importaciones y cierre del periodo. No hay área/puesto en el modelo cargado; no se inventan.

B. **Editables por RH:** 21 importes, estatus del borrador, canal, referencia y notas. El complemento tiene además la bandera existente `cash_salary_is_manual`, que se activa al editarlo. Mapeo completo abajo.

C. **Calculados:** base visible, tasas diarias/horarias, vacaciones preliminares, referencias de permisos, retardo fiscal, horas extra monetizadas, complemento sugerido, fiscal tras retardo, fiscal total, distribución fiscal, subtotal/deducciones/neto operativo, sobre y pago semanal. Permanecen en `_buildPrenominaSummaryRows` y `_HrPrenominaSummaryRow`.

D. **Asistencia:** `hr_attendance_daily_records`; estatus, fecha, minutos de retardo, extra, modo y notas. Se mantiene el filtro operacional existente. El lateral cuenta `laboro` y `falto` en los registros ya cargados del empleado y periodo. “Asistencia lista” no se utiliza como sinónimo de días trabajados.

E. **Vacaciones/permisos:** `hr_employee_vacation_events`, `hr_employee_permission_events` y la tabla compartida de impactos por periodo. Se conservan aprobaciones, cancelaciones, unidades día/hora, impacto, conciliación y estado de aplicación. Las incapacidades mantienen sus días y horas.

F. **CONTPAQ:** lotes y entradas de `hr_attendance_import_lots`, selección por el periodo actual. Referencias: salario, neto, extra, vacaciones, faltas, IMSS, INFONAVIT y FONACOT. Los ajustes fiscales que RH ya podía editar siguen editables; las referencias originales se muestran como lectura.

G. **Guardar:** `_saveDraftRow` conserva el `upsert` a `hr_prenomina_draft_rows` con conflicto `period_label,employee_id`, lectura del registro, actualización de caché y recarga. El payload conserva ID, periodo, empleado, empresa, 21 importes, bandera manual, estatus, canal, referencia, notas y `source_snapshot`.

H. **Confirmar/publicar:** sigue siendo el mismo guardado con `draft_status: publicado`, la confirmación existente y `_settleOperationalEventsForPublishedDraft`. Se conserva el cierre de periodo y su validación. No existía una acción de eliminar borrador; no se agregó. El botón indica “Guardar y publicar” al seleccionar Publicado en Notas.

## Distribución final

- `human_resources_prenomina_page.dart`: contenedor, fuentes, cálculos, modelos y acciones existentes; pasa registros cargados al editor. Los agregados monetarios principales son Fiscal, Flujo y Total.
- `prenomina/prenomina_employee_editor.dart`: borrador único, selección local de sección, bindings, validación y barra fija de acciones.
- `prenomina/prenomina_employee_sidebar.dart`: identidad, periodo y diagnóstico por sección.
- `prenomina/prenomina_editor_sections.dart`: Resumen, Asistencia y Vacaciones/permisos de lectura.
- `prenomina/prenomina_editor_widgets.dart`: totales, indicadores, desglose, paneles y picker compartido. Percepciones, Descuentos y Notas se componen con estos widgets y mantienen sus bindings en el editor.
- `prenomina/prenomina_editor_test_support.dart`: adaptador explícito para pruebas sin Supabase; usa la proyección y el editor de producción.
- `test/hr/human_resources_prenomina_editor_test.dart`: regresiones de importes, captura y navegación.

El lateral reemplaza las seis tarjetas Salario/Percibido/Base/Prev/Fiscal/Semana. Las referencias salariales quedan en Percepciones. Cambiar de sección no ejecuta navegación ni peticiones; el contenido derecho tiene su propio desplazamiento. Los tres totales y las acciones permanecen visibles.

## Mapeo de todos los importes editables

| Campo persistido | Sección | Etiqueta |
| --- | --- | --- |
| `fiscal_net_amount` | Percepciones | Neto fiscal |
| `fiscal_vacation_amount` | Percepciones | Vacaciones fiscales |
| `cash_salary_amount` | Percepciones | Complemento en Flujo |
| `cash_vacation_amount` | Percepciones | Vacaciones en Flujo |
| `transport_support_amount` | Percepciones | Transporte |
| `holiday_amount` | Percepciones | Festivo |
| `overtime_monetized_amount` | Percepciones | Horas extra |
| `manual_bonus_amount` | Percepciones | Bonos |
| `payment_outside_amount` | Percepciones | Pago por fuera |
| `manual_adjustment_amount` | Percepciones | Ajuste RH (+ / −) |
| `fiscal_imss_amount` | Descuentos | IMSS |
| `fiscal_infonavit_amount` | Descuentos | INFONAVIT fiscal |
| `fiscal_fonacot_amount` | Descuentos | FONACOT fiscal |
| `fiscal_absence_amount` | Descuentos | Faltas fiscales |
| `fiscal_late_deduction_amount` | Descuentos | Retardo fiscal adicional |
| `cash_isr_amount` | Descuentos | ISR en Flujo |
| `cash_absence_deduction_amount` | Descuentos | Faltas en Flujo |
| `cash_infonavit_deduction_amount` | Descuentos | INFONAVIT en Flujo |
| `cash_fonacot_deduction_amount` | Descuentos | FONACOT en Flujo |
| `loan_deduction_amount` | Descuentos | Préstamo |
| `check_amount` | Notas | Fiscal sin depósito |

`draft_status`, `payment_channel`, `payment_reference` y `notes` quedan en Notas. Los valores internos del canal siguen iguales; `efectivo` se presenta como Flujo y `cheque` como Fiscal sin depósito. El archivo/exportación de sobres conserva su nombre, estructura y significado existente.

## Importes y contratos preservados

- Fiscal utiliza exactamente el neto existente después del retardo más vacaciones. IMSS/INFONAVIT/FONACOT/faltas fiscales son referencias del neto: se muestran, no se descuentan por segunda vez. La suma de descuentos registrados es informativa; no reconstruye un bruto fiscal inexistente.
- Flujo es la agrupación visual `weeklyPaymentVisibleAmount - fiscalTotalAmount`: neto operativo + pago por fuera + ajuste RH. Mantiene el signo de los ajustes.
- `check_amount` distribuye el fiscal, no genera una nueva percepción. No se añade al Flujo.
- La vista previa llama a la misma proyección existente usando un payload local del borrador. No guarda ni consulta durante la captura o al cambiar de sección. Las validaciones siguen bloqueando el guardado inválido; mientras hay un importe inválido se conserva la última vista previa válida.
- La verificación contra una copia de la implementación anterior confirmó igualdad ignorando sólo espacios en: loaders/fuentes/rutas/roles; guardar/publicar/cerrar/exportar/liquidar; modelos/payloads/proyección/fórmulas; validación/teclado/ciclo de vida del diálogo.
- No hay cambios de schema, endpoints, rutas, IDs de filtros o navegación, ni permisos.

## Validación y límites

Resultado final: 22 pruebas de RH aprobadas (9 del nuevo editor) y análisis estático sin incidencias en los archivos del refactor. También se revisó la captura del editor con tipografía e iconos reales.

Las pruebas usan un empleado ficticio y las funciones reales. Resultado de referencia: Fiscal 3,070.00, Flujo 1,305.00, Total 4,375.00; deducciones fiscales registradas 440.00 y operativas 150.00. Incluye vacaciones, permiso sin goce, retardo y extra; valida también complemento automático y límite del retardo fiscal.

Se prueban los 21 inputs al cambiar de sección, guardar a payload y reabrirlo; referencia/notas; anterior/siguiente; bloqueo de datos inválidos; cancelación; publicación y canal con sus valores persistidos originales; diseños de 1440×1000 y 900×700. Captura visual opcional con fuente real mediante variables de entorno del test.

El guardado/reapertura y publicación se validan sin escribir en producción. Los handlers de Supabase se conservaron y compararon, pero no se publicó una nómina real como prueba. La instalación que esté abierta necesita recompilarse para mostrar este cambio.

Deuda existente conservada: los descuentos fiscales son referencias, no una reconstrucción contable bruta; la lista de asistencia conserva el modelo previo y no inventa un estatus detallado cuando no es `laboro`/`falto`. Las fórmulas, redondeos y sugerencias financieras existentes no se reinterpretan en este trabajo de UI.
