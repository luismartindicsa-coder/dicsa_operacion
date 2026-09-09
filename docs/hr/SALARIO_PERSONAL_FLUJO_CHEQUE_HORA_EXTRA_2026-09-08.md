# Salario en Personal y fuentes de prenómina

Personal registra Base semanal, Flujo semanal y Total calculado (Base + Flujo). El total sigue disponible como `salario_real_percibido` para vacaciones y prima. El flujo se guarda por separado en `salario_flujo`; prenómina lo toma directamente, sin completar diferencias respecto al neto de CONTPAQ.

El expediente selecciona depósito o cheque para el fiscal, y tarifa de $60 u $80 por hora extra. Cheque representa fiscal timbrado entregado en efectivo: se resta del depósito, entra en el sobre y se incluye una sola vez en el total. La columna fiscal del grid y el resumen muestran esta distribución. La tarifa individual sólo monetiza los minutos de días que exceden 15 minutos; las capturas manuales y publicaciones existentes conservan sus importes.

Un flujo manual de cero se guarda como `0.00` y conserva `cash_salary_is_manual=true`. Al reabrir no se sustituye por el automático; se reconoce también el caso antiguo de manual=true con monto nulo. Los borradores automáticos siguen los datos de Personal. Las excepciones de tarifa y distribución fiscal del periodo quedan en `source_snapshot`.

Se mantienen la fuente manual de asistencia, los cinco minutos de tolerancia para retardos, el neto oficial de CONTPAQ y la liquidación separada de vacaciones ya pagadas. No se capturaron movimientos de Ramón ni se reprodujo el pago erróneo a Rebeca del Excel.

## Migración y validación

Migración `20260908233000_add_hr_personal_compensation.sql` aplicada en Supabase. Se verificaron los 86 perfiles: conserva base y total y materializa el flujo contractual existente. No modifica importaciones CONTPAQ ni movimientos. Se inicia en depósito y $60/hora; RH configura cheque y $80 cuando corresponda. Copias locales limitadas de id/base/total y los nuevos campos: `/private/tmp/dicsa_personal_compensation/`.

Validación: 73 pruebas de RH aprobadas; análisis de Dart sin problemas. Incluye total calculado, cero explícito, conservación tras guardar/reabrir/publicar y en recibo, cheque sin duplicación, cambio de tarifa automático y excepción manual, vacaciones prepagadas con semana completa sin pago, y captura real del expediente sin overflow.

Por instrucción posterior del usuario se configuraron como cheque los 11 perfiles con importe positivo en la columna S (CHEQUE) de NOMINA35.xlsx: 114, 217, 252, 285, 286, 287, 289, 290, 297, 298 y 299. Se cotejaron ID y nombre antes de actualizar; una consulta posterior confirmó los 11 medios de pago y que base, flujo, total y tarifa permanecieron iguales. Copia previa y resultado: `/private/tmp/dicsa_personal_compensation/cheques_before.json` y `cheques_applied.json`.
