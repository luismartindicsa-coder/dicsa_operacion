# Préstamos a colaboradores — 9 de septiembre de 2026

## Alcance implementado

- Nueva pantalla accesible desde el menú de Recursos Humanos, con paleta RH y arquetipo compartido Workflow Master-Detail.
- Card principal: disponible, capital inicial, saldo por recuperar, abonos confirmados y préstamos activos.
- Capital inicial de $15,000. Disponible = capital − entregas registradas + abonos confirmados.
- Captura de colaborador de Personal, importe, fecha de entrega, primer vencimiento, número de cuotas, forma de pago y referencia.
- Cuotas semanales, cada 14 días o mensuales. Sin intereses; los centavos de redondeo se conservan en la última cuota.
- Pagos por nómina o efectivo. Se admiten abonos en efectivo anticipados para cualquier préstamo, con historial por folio.
- No se ejecutan transferencias: «Registrar entrega» registra una entrega realizada y «Registrar abono recibido» registra efectivo ya recibido.
- Búsqueda con edición nativa, selección por click/flechas, detalle con plazos e historial. Recarga silenciosa diferida durante la captura.

## Conexión con Prenómina

La propuesta reúne las cuotas vencidas hasta el final del periodo y las muestra en Descuentos como «Préstamos del fondo». Los préstamos manuales anteriores conservan su importe en «Préstamo adicional (manual)»; nunca se convierten automáticamente en abonos del nuevo fondo.

Guardar un borrador no recupera dinero. El cierre de nómina confirma los abonos nominales y recupera el fondo en la misma transacción. Los abonos en efectivo se recuperan al registrarlos. Las claves de solicitud y el vínculo préstamo/cierre evitan duplicados en reintentos.

El servidor valida saldos, disponibilidad, permisos, desglose y cambios ocurridos desde la última captura; si el préstamo cambió, rechaza el cierre y solicita actualizar la prenómina. Los cierres existentes y sus préstamos se mantienen congelados.

## Regla aprobada y activación — 10 de septiembre de 2026

RH definió el cobro por canal: **Flujo** reduce el pago de la app; **Fiscal** ya viene descontado en el neto oficial de CONTPAQ y se presenta únicamente como informativo en Prenómina. La app no cambia de canal automáticamente cuando falta flujo.

El selector está disponible al crear un préstamo por nómina y en el botón «Cobro: Flujo / Fiscal · CONTPAQ» de su detalle. Cambiarlo afecta cuotas pendientes; los abonos confirmados conservan su canal. Se registra el cambio con autor, fecha, canal anterior/nuevo y referencia de RH en `hr_loan_channel_changes`.

El snapshot `loan_fund` versión 2 conserva `amount` como descuento de flujo, añade `fiscal_amount` informativo y asigna canal a cuotas y abonos. `loan_deduction_amount` sigue conteniendo sólo flujo más el préstamo manual adicional. Resumen, Descuentos y diagnóstico del colaborador muestran el importe fiscal como informativo.

El cierre confirma ambos canales y recupera el fondo una sola vez. Para Fiscal debe existir el neto oficial de CONTPAQ del periodo. La selección de RH indica que la cuota programada ya fue incluida en CONTPAQ; la app no puede comprobar esa inclusión a partir del neto por sí solo. Si cambia el saldo o el canal desde la última captura, se exige actualizar el borrador antes del cierre.

Aplicadas:

- `20260910010000_create_hr_loan_fund.sql`.
- `20260910100000_add_hr_loan_payroll_channels.sql`.

La migración provisional `20260910011000_limit_loan_withholding_to_available_flow.sql` nunca se aplicó y fue retirada: el cambio definitivo se probó y aplicó por separado después de que la revisión automática objetó incluir ambos. La migración definitiva incluye por sí misma la validación del flujo disponible, excluye pagos por fuera y trata Fiscal según la nueva decisión de RH.

Verificación de activación: `.local/hr_loan_fund_activation/channels_verification.json`. Fondo inicial y disponible $15,000; cero préstamos y abonos reales. Se compararon firmas de Personal, Prenómina, cierres y fondo antes/después; se conservaron todos los importes y registros existentes.

## Validación

- 18 pruebas del módulo: fondo, redondeo, vencimientos, abonos anticipados, flujo insuficiente/cero, cheque fiscal, pagos por fuera, no duplicar deducciones manuales, cierres congelados, búsqueda y flechas, formularios y reintentos; ambos canales, fiscal informativo con flujo cero, cambios en borradores abiertos y conservación de cierres.
- 19 pruebas existentes de editor, historia y grid de Prenómina aprobadas.
- 7 verificaciones SQL del selector (ambos canales, reintentos, falta de CONTPAQ, validación de flujo, cambios auditados, cierre mixto sin doble descuento, historia y acceso) aprobadas con rollback, aplicando sólo la migración definitiva.
- 9 verificaciones SQL transaccionales previas de creación, límites, abonos, cierre, idempotencia, inmutabilidad y acceso aprobadas con rollback; no dejaron préstamos de prueba.
- Análisis dirigido de Flutter sin incidencias. `git diff --check` limpio.
- Capturas de prueba con datos ficticios revisadas en `/private/tmp/dicsa_loans_workspace.png` y `/private/tmp/dicsa_loans_new_loan.png`.

Comandos de pruebas:

```sh
flutter test --no-pub test/hr/human_resources_loans_test.dart test/hr/human_resources_prenomina_editor_test.dart test/hr/human_resources_prenomina_history_test.dart test/hr/human_resources_prenomina_grid_test.dart
flutter analyze --no-pub lib/app/hr/human_resources_loans.dart lib/app/hr/human_resources_loans_page.dart lib/app/hr/loans lib/app/hr/human_resources_prenomina_page.dart lib/app/hr/human_resources_area_chrome.dart test/hr/human_resources_loans_test.dart
```


## Migración de préstamos activos — 10 de septiembre de 2026

Aplicada `20260910110000_support_hr_loan_opening_balances.sql`. Se registraron seis préstamos a partir de la tabla y aclaraciones del usuario, enlazados a los cinco expedientes de Personal. Miguel Ángel tiene dos préstamos independientes. Iliana queda con ocho cuotas de $250. Los primeros abonos pendientes vencen al terminar el periodo 37, el 10 de septiembre; después, semanalmente.

Totales comprobados en base de datos y en la pantalla: principal original $10,700, abonado previamente $2,000, pendiente $8,700, disponible del fondo $6,300. Las cuotas del periodo 37 suman $1,750: $1,500 Fiscal y $250 Flujo. Sólo Iliana va por Flujo; los demás por Fiscal, conforme a la igualdad de salario total y salario base comprobada en Personal. Esta asignación se conserva por préstamo; cambios posteriores siguen siendo explícitos con su auditoría.

El importe regular se conserva en `installment_amount`; la última cuota es el remanente exacto. El préstamo de $2,500 a cuotas de $300 tiene ocho cuotas de $300 y una de $100. El formulario también permite capturar el monto por abono y calcular el número de cuotas.

Los pagos anteriores se conservan como `opening_paid_amount` y `opening_paid_installments`. No se crearon recibos ni abonos en efectivo ficticios. Las fechas de solicitud y la fuente están en `opening_snapshot`; `issued_on` representa la fecha de corte del saldo inicial para estos registros importados, identificada así en el detalle. `first_due_on` corresponde a la primera cuota pendiente; las cuotas anteriores se muestran cubiertas, sin fecha documentada. El disponible, saldo, calendario y validación de abonos descuentan una sola vez el importe inicial recuperado.

La carga fue atómica e idempotente, con UUIDs de origen estables. Se verificaron firmas de Personal, borradores, cierres, periodos, capital del fondo y abonos antes/después: sin cambios. Los préstamos importados no generan cuotas para periodos 35 o 36. No se cerró ni publicó el periodo 37.

Evidencia local restringida: `.local/hr_current_loans_20260910/` contiene preflight, plan con origen y salarios utilizados, respaldo anterior, script sin credenciales, filas guardadas y verificación. Se aprobaron 40 pruebas Flutter (21 préstamos y 19 de Prenómina), análisis dirigido sin incidencias y 10 verificaciones SQL revertidas. El cierre de prueba recuperó $1,750 una sola vez sin modificar el neto fiscal; los abonos previos no se cobraron nuevamente. Se comprobó además el límite del saldo restante y la cuota final de $100.

La sesión macOS recibió recarga en caliente; se verificó la pantalla real con seis préstamos, el saldo disponible de $6,300 y el calendario desde el periodo 37.
