# Conciliación del incremento de costos — 22/09/2026

## Corrección vigente

La revisión reprodujo los importes de la última captura (01–22/09/2026) y ejecutó ambos motores sobre **exactamente la misma lectura de fuentes**, realizada a `2026-09-22T22:18:00.052596`. Se encontraron reservas históricas acumuladas encima del consumo actual y una clasificación no sustentada de Maricruz como gasto común.

1. El historial complementa solamente la diferencia faltante. Para cada grupo comparable: **reserva = máximo(0, referencia histórica de la cobertura pendiente − consumo puntual actual comparable)**. Las facturas con cobertura explícita de varios días sustituyen esos días; no se descuentan dos veces. Los comprobantes reconocidos mediante revisión también reducen la reserva.
2. En mantenimiento, cambiar de taller o folio no crea una reserva adicional. Se conserva la separación de centro, empresa y equipo; los costos de otra unidad no cancelan la referencia de esta unidad. Los gastos actuales no se reducen aunque superen la referencia.
3. Los **$465,920 de Maricruz** quedan por conciliar, **sin reparto a empresas**. No se eliminaron: se conservan provisionalmente como importe retenido en el resultado global. Finanzas los identifica como compra de material y la aclaración “Maricruz no es compra” no basta para fijar el concepto ni su relación con tickets. Un tratamiento revisado y vigente puede resolver esa clasificación.
4. El aviso de resultado provisional aparece en Empresas, Consolidado y el PDF. La conciliación distingue importes por clasificar de capacidad sin actividad. Los cortes guardados anteriores no se reescriben.

## Efecto por empresa con las mismas fuentes

| Empresa | Costo de la captura | Costo corregido | Aporte corregido | Complemento histórico incluido |
|---|---:|---:|---:|---:|
| AVON | $327,988.91 | $283,952.95 | $3,661.79 | $37,812.84 |
| DECASA | $105,065.32 | $91,706.47 | $-29,480.95 | $15,456.63 |
| WHIRLPOOL | $382,539.17 | $341,611.44 | $-55,990.10 | $47,690.83 |
| KS | $277,896.11 | $258,670.91 | $-95,010.66 | $28,962.71 |
| MONROE | $600,850.84 | $542,128.04 | $-204,787.13 | $57,457.37 |

Los importes de generación y compra de material permanecen iguales en todas las cuentas. El cálculo de americano/Celanese, recuperación y compra inferida no se modificó.

## Conservación global

| Concepto | Antes | Después |
|---|---:|---:|
| Remuneración RH | $649,082.39 | $649,082.39 |
| Complementos históricos atribuidos | $420,651.36 | $351,507.32 |
| Importes retenidos fuera de empresas | $26,811.80 | $492,731.80 |
| Resultado de toda la operación modelada | $-812,325.15 | $-743,181.11 |

**El resultado global mejora $69,144.04 exclusivamente por la corrección de reservas.** Retirar Maricruz del reparto cambia dónde se presenta ese importe, no lo borra ni mejora por sí mismo el resultado global. El complemento histórico restante de $351,507.32 sigue siendo una estimación, no un gasto nuevo comprobado. No debe interpretarse el color de una empresa como una conclusión definitiva sobre su continuidad.

## Nómina y confirmaciones anteriores

La remuneración RH total permanece en $649,082.39: $423,428.77 de periodos publicados y $225,653.62 de sueldo de referencia para días no publicados. La sonda anterior verificó cero empleado/día con publicaciones superpuestas y cero referencias RH atribuidas simultáneamente a choferes y patio/soporte. El problema identificado aquí no era repetir esa nómina, sino costos de Finanzas y reservas agregados al mismo resultado.

Las líneas distinguen “Nómina de patio y soporte”, “Nómina de transporte compartida”, cargas laborales de Finanzas y gastos administrativos. No se presume que todo el personal sin puesto identificado sea administrativo.

FONACOT $3,613.76 del 01/09/2026 continúa fuera del costo adicional por confirmación de que es entero de retenciones; permanece visible en conciliación. No se afirma que corresponda a deducciones específicas del RH publicado en este corte. Mauricio Alcalá y Mónica Chávez continúan cubiertos por tickets según la confirmación de Dirección; Maricruz no recibe esa exclusión.

## Límites y evidencia

La base de 90 días es una referencia operativa. Una reserva residual puede cambiar al ampliar el periodo o al llegar comprobantes: no es una póliza contable ni una suma necesariamente aditiva entre subperiodos. La cobertura explícita mensual sí conserva su importe entre vistas adyacentes. Se mantienen todos los centros y la participación de actividades fuera del catálogo de Compras Mayoreo.

Evidencia temporal local: `/private/tmp/dicsa_residual_same_sources.json` y `/private/tmp/dicsa_residual_compare.log`. Prueba autenticada de solo lectura: conservación de RH, generación y compra por cada cuenta; conciliación de Maricruz, valores finitos y snapshot menor a 20 MB. No se cambiaron registros de RH, bancos, facturas ni migraciones.

## Verificación de la corrección

- 114 casos comprobados: suite de rentabilidad de 113 pruebas y caso adicional de aviso provisional en ambas pestañas. La prueba del PDF se repitió tras precisar el texto final del complemento histórico.
- Análisis estático sin incidencias y compilación macOS debug correcta. Se envió la recarga a la sesión Flutter abierta; la inspección nativa solo expuso el contenedor de la ventana, por lo que no se usa como prueba de sus cifras visibles.
- Inspección de widgets a 1440 y 760 px, y de las seis páginas renderizadas del PDF de prueba; aviso provisional legible, sin desbordamiento.
- Comparación byte a byte del archivo de base material y del bloque de valoración: sin cambios.
- Logs temporales: `/private/tmp/dicsa_residual_full_tests.log`, `/private/tmp/dicsa_residual_pending_ui.log`, `/private/tmp/dicsa_residual_analyze.log`, `/private/tmp/dicsa_residual_build.log`.
