# Verificación del periodo 35 — 8 de septiembre de 2026

Periodo operativo original: **Periodo 35 semanal · 21/08/2026 - 27/08/2026**.

## Hallazgo

Las 372 capturas manuales de 77 colaboradores seguían intactas, con origen `daily`. Su última modificación era del 27 de agosto de 2026. Los totales guardados son 457 minutos de retardo y 990 minutos extra; son datos capturados, no valores recalculados del reloj.

La sincronización antigua generó otros 125 registros con origen `importado`, todos creados el 8 de septiembre de 2026 a las 18:03:07 UTC, bajo la etiqueta duplicada `Periodo 35 semanal · 21/08/2026 - 27/08/2026 · Archivo 12:48:09`.

## Acción aplicada en Supabase

Se vinculó únicamente el campo `period_label` de los lotes `NGTco 35.csv` y `contpaq35.xlsx` al periodo operativo original, con comprobación del identificador, etiqueta y fecha de modificación anteriores.

No se sobrescribieron ni eliminaron capturas. La verificación posterior confirmó igualdad completa de las 497 filas de asistencia con la copia previa. Los 125 registros automáticos permanecen como evidencia en la base, pero el código corregido los excluye de la asistencia operativa, prenómina, dashboard y reporte semanal.

## Archivos

- `hr_attendance_daily_records.json`: copia previa de las 497 filas, incluidas las 372 capturas originales.
- `hr_attendance_import_lots.json`: copia previa del lote CONTPAQ.
- `ngteco_period35_metadata.json`: metadatos previos del lote NGTeco; no incluye sus fichajes.
- `hr_attendance_operational_periods.json`: periodo manual original.
- `link_plan.json` y `link_result.json`: cambios de vinculación previstos y aplicados.
- `verification.json`: conteos, totales y checksum de la verificación posterior.

La corrección de la aplicación requiere ejecutar la versión actualizada. Las pruebas de regresión cubren la conservación de estatus y totales, la apertura del editor y la vinculación de importaciones a periodos previamente existentes.
