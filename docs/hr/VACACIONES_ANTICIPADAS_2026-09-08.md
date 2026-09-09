# Vacaciones pagadas por anticipado y sueldo del periodo

Regla confirmada por RH: descontar sólo los días de vacaciones ya pagados que se disfrutan en el periodo, conservando los días trabajados. No volver a pagar vacaciones ni prima por la parte cubierta por el anticipo.

## Implementación

- `human_resources_prepaid_vacation.dart`: cruza eventos `vacaciones_pagadas` y `vacaciones_disfrutadas` con estado `aplicado`, por empleado y ejercicio. Consume el saldo en orden cronológico; descuenta los disfrutes anteriores antes de resolver el periodo consultado. No usa pagos futuros ni eventos cancelados/pendientes/aprobados como comprobación de pago. El reparto de días de un evento entre periodos sigue las fechas del intervalo y sus días registrados.
- `human_resources_prenomina_page.dart`: consulta la historia ya cargada, incluyendo disfrutes sólo de asistencia. Reduce el sueldo por `salario percibido / 7 × días cubiertos`, con límite del sueldo ordinario disponible; distribuye la compensación entre Fiscal y Flujo según sus importes disponibles, redondeados a centavos. No afecta bonos, extra ni otros conceptos. Excluye de la sugerencia de vacaciones/prima los días disfrutados cubiertos por el anticipo y actualiza sugerencias previas del borrador. Importes fiscales reportados por CONTPAQ conservan su fuente.
- Guardado: los campos existentes `fiscal_net_amount` y `cash_salary_amount` contienen el sueldo pendiente de pagar. El `source_snapshot.prepaid_vacation` conserva días y compensaciones, junto con los metadatos anteriores. Al reabrir se recupera la base y se vuelve a aplicar una sola compensación. Nómina consume los netos guardados por su vía existente; no requiere nuevas columnas ni migración.
- Las filas publicadas conservan la compensación guardada y no reciben ajustes históricos nuevos automáticamente.
- `prenomina_editor_sections.dart`: muestra la compensación fiscal/flujo en Resumen y los días cubiertos y el total en Vacaciones y permisos.

## Validación

43 pruebas RH aprobadas; seis específicas del anticipo. Fixture de mayo con 12 días pagados, 6 disfrutados anteriormente y 3 disfrutados en el periodo 35: cubre sólo los 3 días actuales. Con percibido semanal 3,500, sueldo fiscal 2,100 y flujo 1,400, reduce 1,500: Fiscal pendiente 1,200 + Flujo pendiente 800; un bono de 200 permanece, total 2,200. Tres ciclos de guardado/reapertura conservan el resultado. También se prueban saldo parcial, cambios de ejercicio/empleado, cancelaciones, pagos futuros, cruce de periodos, redondeo, flujo automático y filas publicadas.

No se consultaron ni modificaron registros productivos de Rebeca en esta tarea. Para aplicar su caso, el pago de mayo debe estar registrado como vacaciones pagadas/aplicadas del ejercicio y el disfrute con sus días y fechas reales. El cambio se refleja al recargar Prenómina; el neto se persiste mediante su guardado/cierre habitual. No se reescribieron recibos emitidos.


## Corrección de pertenencia al periodo

El pago histórico cubre el saldo de vacaciones, pero no reduce por sí mismo el sueldo semanal. El descuento y los días disfrutados visibles ahora comparten la asignación al periodo: impactos por periodo cuando existen; en su ausencia, periodo explícito del evento (comparando fechas del periodo) y fechas efectivas de disfrute. Un evento sin periodo asignado se limita por sus fechas. Se excluyen eventos cancelados y sin impacto en prenómina; sólo el disfrute aplicado puede consumir sueldo. El estado de sincronización no elimina del periodo original un disfrute ya aplicado. Los eventos que cruzan periodos se limitan al solapamiento y a los días asignados.

El historial completo continúa consumiendo anticipos cronológicamente por empleado y ejercicio, para no reutilizar días ya disfrutados. Los borradores restauran la deducción previa registrada en source_snapshot antes de recalcular; las filas publicadas conservan sus importes. No se modificaron registros de producción ni se verificó la captura concreta de Javier.

Validación: 50 pruebas de RH aprobadas; análisis estático de los archivos afectados sin incidencias. Regresiones: otro periodo aun con fechas coincidentes, fechas fuera de periodo, pago histórico sin disfrute, evento sin impacto, disfrute sincronizado, evento repartido entre periodos y recuperación idempotente de un borrador descontado indebidamente.


## Cobertura salarial por fechas y excepción al neto fiscal

Confirmación del usuario: disfrute de Rebeca del 21/08 al 04/09; cantidad aproximada 12 días más 2 domingos. La cantidad cargada al saldo y la cobertura de sueldo son magnitudes distintas. Un evento completamente cubierto por un pago anterior cubre cada fecha de su rango, incluidos descansos: el periodo 35 completo tiene 7 días de sueldo cubiertos, no 3.27. El prorrateo histórico de impactos se utiliza para identificar pertenencia al periodo, no para reducir las fechas cubiertas. El saldo histórico sigue consumiéndose por empleado y ejercicio; si el anticipo sólo cubre parte, la cobertura salarial también queda limitada cronológicamente.

Se restablece la liquidación fiscal y de flujo por vacaciones anticipadas incluso cuando existe neto oficial CONTPAQ. Faltas, retardos y permisos continúan informativos. Pruebas con ambas cantidades de saldo (12 y 14), fechas indicadas, impacto histórico de 3.27 y guardado/recarga reiterados producen fiscal cero y flujo cero en el periodo 35. Pruebas de límites: 7 días periodo 35, 7 periodo siguiente, 1 día en el periodo que comienza el 04/09 y cero después. No se alteraron fechas, saldos ni registros reales.
