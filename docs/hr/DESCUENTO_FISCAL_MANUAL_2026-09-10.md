# Descuento fiscal manual — 10 de septiembre de 2026

En Prenómina, detalle del colaborador, sección Descuentos, RH puede capturar un descuento fiscal adicional y su motivo. Reduce el fiscal y el total a pagar una sola vez; no modifica el flujo ni el neto original importado de CONTPAQ. Los conceptos informativos de incidencias y préstamos fiscales mantienen su tratamiento anterior.

El importe se conserva en `fiscal_manual_deduction_amount` y el motivo en `fiscal_manual_deduction_reason`. Ambos sobreviven guardados, reapertura, publicación y nuevas importaciones. Su valor inicial es cero. El motivo es obligatorio cuando el importe es positivo; no se permiten importes negativos, no finitos, más de dos decimales en la captura o descuentos mayores al fiscal disponible. Para quitarlo se captura cero.

El cálculo se refleja en el resumen y diagnóstico del colaborador, grid y cards de Prenómina, distribución depósito/cheque, Nómina, detalle, snapshot del recibo, PDF individual, anexo fiscal del reporte de periodo y agregados del dashboard/reporte de RH. Los agregados ahora respetan el indicador existente de incidencias informativas al considerar la deducción explícita. Los recibos anteriores sin estos campos se leen con descuento cero.

Aplicada la migración `20260910120000_add_prenomina_manual_fiscal_deduction.sql`. La tabla `hr_prenomina_fiscal_deduction_changes` registra fecha, actor, periodo, colaborador, importe/motivo anterior y nuevo, neto fiscal y referencia CONTPAQ. El servidor valida acceso RH/Dirección y conserva la protección de periodos cerrados. Los guardados sin cambio no duplican entradas de auditoría.

No se registraron descuentos para empleados reales. Las firmas de Personal, borradores, cierres, recibos, préstamos y abonos coincidieron antes y después de activar el esquema. Evidencia local restringida en `.local/hr_manual_fiscal_20260910/`.

Validación: 65 pruebas Flutter de Prenómina, Nómina, préstamos, compensación y PDFs aprobadas; la prueba existente del contrato de campos se actualizó para admitir los dos nuevos campos en cero y volvió a pasar. Se aprobaron seis comprobaciones SQL con rollback: conservación del neto y flujo, auditoría con actor y reintentos, límites/motivo, borrado lógico del descuento mediante cero, permisos y protección del cierre. Análisis dirigido sin errores nuevos; permanecen dos avisos repetidos sobre `_HrDashboardWorkspace` no usado, también presente sin referencias en HEAD.

El formulario real y los PDF de prueba fueron renderizados y revisados. Caso: neto original $1,700; descuento $150; fiscal $1,550; flujo $300; total $1,850, tanto en depósito como en cheque. Pruebas incluyen descuento completo, reapertura, varias guardadas y cambio posterior del neto importado. Los PDF de QA son datos ficticios, no reportes reales del periodo 37.

Se envió recarga en caliente a la sesión Flutter abierta. La inspección de la ventana real quedó limitada por `Sky Computer Use native pipe startup failed`; se verificó el mismo formulario mediante pruebas de widgets, incluido su diseño.
