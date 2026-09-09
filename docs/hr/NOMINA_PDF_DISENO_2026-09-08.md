# Reporte de cierre de Nómina: inventario previo

Alcance: presentación del PDF del periodo. No incluye recibos individuales, cambios a la UI, cálculos, importaciones, consultas, payloads ni cierre de Prenómina.

## Generación e integración actuales

- `HumanResourcesNominaPage._exportPeriodPayrollReportPdf` utiliza `_allRows`, `_HrNominaMetrics.fromRows`, periodo activo, fecha de emisión y estado de cierre.
- `_allRows` proviene de `_buildNominaRows`: filas guardadas de Prenómina filtradas por periodo, con distribución fiscal resuelta por el modelo existente. Se exportan todas las filas del periodo, independientemente del filtro visual o página de la UI.
- DTOs existentes: `_HrNominaDraftRecord`, `_HrNominaSummaryRow`, `_HrNominaMetrics`, `_HrNominaPeriodClosure`. Permanecen intactos.
- Librería local: `pdf` 3.11.3 (`pw.Document`, `pw.MultiPage`, `pw.Table`). Logo: `assets/images/logo_dicsa.png`. Fuentes PDF estándar, sin descargas ni nuevas dependencias.
- Archivo: mismo `saveBytesAs`, nombre `nomina_${slug(periodo)}.pdf`, diálogo y handler. Los recibos individuales usan otra función y no entran en este refactor.

## A-J: campos y semántica

| Grupo | Datos existentes que utiliza el reporte |
| --- | --- |
| A. Periodo | Etiqueta, fecha de emisión, estado cerrado/preliminar, número de filas y métricas agregadas. Fechas de inicio/fin se leen de la etiqueta con el parser existente. No hay versión de reporte ni firma impresa en este flujo. |
| B. Colaborador | ID, nombre, empresa; importes fiscales y operativos; indicador `incidencesInformational`. Se mantienen orden y población originales. |
| C. Fiscal | `row.fiscalAmount`, total `metrics.fiscal`. La columna antes llamada Fiscal base usa `fiscalAmount + (incidencesInformational ? 0 : fiscalLateDeductionAmount)`; se conserva esa expresión y se presenta como Fiscal de origen. |
| D. Distribución | `row.fiscalDepositedAmount`, `row.fiscalCashAmount`, `metrics.fiscalDeposited`, `metrics.fiscalCash`. Cheque ya está dentro del fiscal. |
| E. Flujo | `row.operationalCashAmount`, total `metrics.operationalCash`. Componentes: sueldo, vacaciones, transporte, festivo, horas extra más bono y ajuste RH. Se usa `metrics.complements` para percepciones; no se recalcula el resultado final desde el PDF. |
| F. Deducciones | ISR operativo, faltas cuando no son informativas, INFONAVIT, FONACOT y préstamo. `row.deductionsAmount` y `metrics.deductions` son los totales existentes. El valor registrado de faltas se conserva aunque sea informativo. |
| G. Total | `row.totalAmount`, `metrics.total`; pago fuera usa `row.paymentOutsideAmount`, `metrics.outside`. La conciliación visual comprueba las relaciones, no sustituye esos importes. |
| H. Informativos | Retardo y faltas bajo `incidencesInformational` no se vuelven a deducir. Los registros anteriores sin ese indicador conservan su tratamiento original. |
| I. Notas | MXN; depósito + cheque = fiscal; cheque no se suma de nuevo al flujo; neto fiscal conserva descuentos de origen; incidencias informativas no se descuentan nuevamente; flujo después de deducciones. Estado preliminar no se presenta como cierre confirmado. |
| J. Paginación | Antes: un `MultiPage` A3 horizontal con 22 columnas, fuente 5.2/5.4 pt y encabezado de tabla repetido; resumen de conceptos al terminar. Después: ejecutivo A4 vertical y tablas A4 horizontales que fluyen y repiten encabezados, sin límite fijo de páginas. |

## Conservación de los 22 campos originales

- Resumen: ID, nombre, empresa, fiscal neto, depósito, cheque, flujo neto, deducciones existentes, pago fuera y total a pagar.
- Anexo A: ID, nombre, empresa, fiscal de origen (antes Fiscal base), retardo, fiscal neto, depósito y cheque.
- Anexo B: ID, nombre, sueldo flujo, vacaciones flujo, ISR operativo, transporte, festivo, bonos/H.E., ajuste RH y flujo neto.
- Anexo C: ID, nombre, ISR operativo, faltas registradas, INFONAVIT, FONACOT, préstamo y deducciones existentes.

Se conserva `$0.00`: el DTO actual ya convierte valores ausentes a cero y el diseño no cambia esa semántica.

## Observaciones preexistentes fuera del alcance

- El reporte no recibe el detalle de vacaciones fiscales, ISR fiscal, INFONAVIT fiscal ni FONACOT fiscal; no se agregan consultas ni columnas inventadas.
- La UI calcula su etiqueta Flujo como total menos fiscal (incluye pago fuera), mientras el PDF actual usa flujo operativo y presenta pago fuera aparte. El PDF conserva exactamente su definición anterior.
- “Fiscal base” no equivale al salario base contractual. Se aclara la etiqueta visible sin alterar su importe.
- Los cobros separados de préstamos están documentados en los datos del cierre, pero no son una retención de esta nómina. No se agregan al total de deducciones.

## Implementación y archivos

| Archivo | Cambio |
| --- | --- |
| `lib/app/hr/human_resources_nomina_page.dart` | Extrae el generador del reporte y sus dos helpers exclusivos; incorpora el nuevo `part`. El resto del archivo se comprobó idéntico byte por byte al anterior. |
| `lib/app/hr/nomina/nomina_period_pdf.dart` | Presentación del reporte por periodo, paleta, portada, conciliación, validaciones, tablas y anexos. |
| `lib/app/hr/nomina/nomina_test_support.dart` | Fecha opcional de emisión únicamente en el helper de pruebas, conservando su valor predeterminado anterior. |
| `test/hr/human_resources_nomina_pdf_test.dart` | Casos informativos y anteriores, flujo negativo, cheque, pago fuera, cero y población de 110 personas; generación opcional con fixture real local. |
| `docs/hr/NOMINA_PDF_DISENO_2026-09-08.md` | Inventario previo, mapeo y evidencia de validación. |

`_buildHrNominaPeriodReportPdf` mantiene su firma. La presentación está encapsulada en `_HrNominaPeriodPdf` y `_HrNominaPdfPalette`. Helpers principales: `executiveHeader`, `summary`, `reconciliation`, `flowComposition`, `validation`, `employeeSummaryTable`, `fiscalAppendix`, `flowAppendix`, `deductionsAppendix`, `table`, `runningHeader` y `footer`.

Se conserva el handler `_exportPeriodPayrollReportPdf`, la selección de todas las filas del periodo, las consultas, modelos, fuentes, fórmulas, endpoints, payloads, esquemas, permisos, rutas, nombre de archivo, diálogo de guardado e integración Prenómina → Nómina. No se alteran recibos individuales. No se escribió en la base de datos ni se trabajó sobre el periodo 37.

## Estructura final y paginación

Para el periodo 35 completo el reporte ocupa **13 páginas A4**:

| Páginas | Contenido |
| --- | --- |
| 1, vertical | Cierre ejecutivo, cuatro indicadores, distribución fiscal, conciliación, composición del flujo, validaciones y trazabilidad. |
| 2–4, horizontal | Resumen por colaborador. |
| 5–7, horizontal | Anexo A: fiscal. |
| 8–10, horizontal | Anexo B: flujo. |
| 11–13, horizontal | Anexo C: deducciones. |

El número de páginas depende de los datos. Se utiliza una página ejecutiva y un `MultiPage` para las cuatro tablas. Los cambios de sección sólo solicitan página nueva cuando no hay espacio suficiente para iniciar el siguiente bloque. Los encabezados de tabla se repiten, las filas permanecen completas y el pie utiliza numeración global. Fuente de datos de tabla: 8.5 pt; encabezados: 8 pt. No se eliminó ninguna de las 22 columnas originales: se reorganizaron entre resumen y anexos.

## Validación contra el PDF anterior del periodo 35

Fuente anterior: `Downloads/nomina_periodo_35_semanal_21_08_2026_27_08_2026.pdf`, emitido el 08/09/2026 a las 18:35. Nuevo ejemplo: `output/pdf/nomina35_cierre.pdf`, emitido el 08/09/2026 a las 18:52 usando las 78 filas del cierre existente, sin consultar ni modificar Supabase.

La comprobación extrajo texto directamente de ambos PDF, identificó cada fila por ID y comparó importes en centavos. Resultado: **2,028 comparaciones monetarias, cero diferencias**. Se comprobaron 78 filas en cada una de las cuatro tablas, más los 78 nombres completos y empresas. Los 19 conceptos monetarios originales permanecen disponibles. Las deducciones agregadas añadidas al resumen proceden del total existente del modelo.

| Concepto | PDF anterior | PDF nuevo | Diferencia |
| --- | ---: | ---: | ---: |
| Colaboradores | 78 | 78 | 0 |
| Fiscal | $148,725.80 | $148,725.80 | $0.00 |
| Depósito fiscal | $122,888.40 | $122,888.40 | $0.00 |
| Cheque fiscal | $25,837.40 | $25,837.40 | $0.00 |
| Flujo | $53,067.24 | $53,067.24 | $0.00 |
| Pago fuera | $0.00 | $0.00 | $0.00 |
| Total a pagar | $201,793.04 | $201,793.04 | $0.00 |
| Retardos informados | $269.76 | $269.76 | $0.00 |
| Sueldo flujo | $29,068.88 | $29,068.88 | $0.00 |
| Vacaciones flujo | $1,687.08 | $1,687.08 | $0.00 |
| Transporte | $600.00 | $600.00 | $0.00 |
| Festivo | $0.00 | $0.00 | $0.00 |
| Bonos y horas extra | $21,343.00 | $21,343.00 | $0.00 |
| Ajustes RH | $1,194.64 | $1,194.64 | $0.00 |
| Deducciones RH / Flujo | $826.36 | $826.36 | $0.00 |

Ejemplos individuales (también se comprobaron todos sus componentes):

| Colaborador | Fiscal, ambos PDF | Flujo, ambos PDF | Total, ambos PDF |
| --- | ---: | ---: | ---: |
| Rebeca Solórzano, 8 | $0.00 | $0.00 | $0.00 |
| Javier Martínez, 135 | $1,890.20 | $3,009.80 | $4,900.00 |
| Dania de la Vega, 293 | $2,177.60 | $82.40 | $2,260.00 |
| Fernando Axel Soto, 298 | $2,202.00 | -$315.04 | $1,886.96 |
| Ramón Miranda, 257 | $5,040.60 | $1,687.08 | $6,727.68 |

Pruebas adicionales:

- `flutter test test/hr --no-pub`: **85 pruebas aprobadas**.
- Análisis de los cuatro archivos Dart afectados: **sin incidencias**.
- Generación con la población real completa: aprobada.
- Extracción independiente de PDF sintético: neto fiscal informativo sin doble descuento, tratamiento anterior conservado, deducciones informativas distinguidas con `(ref.)`, flujo negativo y pago fuera separados.
- PDF preliminar con 110 colaboradores: las cuatro tablas incluyen las 110 filas y la portada indica que no existe cierre confirmado.
- Revisión de las 13 páginas renderizadas: sin recortes, filas partidas ni saltos artificiales con grandes espacios vacíos; encabezados y folios presentes.

Huellas SHA-256 de la comparación:

```text
Anterior: 4151df79b17f184883f3a960c51bad665a027fcc653187fd527473b9a212ef9d
Nuevo:    30491173a3e281d71e968d71acbf329fcb8c24ced0885e195288cc0ff87a9eef
```

No se encontró una diferencia monetaria nueva entre reportes. Las observaciones semánticas preexistentes listadas arriba quedan documentadas y no modificadas. Esta validación acredita la conservación de los datos y del cálculo existente; no reinterpreta ni vuelve a conciliar el Excel histórico.
