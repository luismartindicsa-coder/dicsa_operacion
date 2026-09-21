# Finanzas: presupuesto semanal de viernes

## Alcance acordado

`Supervisión > Finanzas > Generar viernes` genera el presupuesto requerido para el siguiente lunes a domingo. El máximo global es **$500,000 MXN, incluidos facturas de proveedores y pagos fijos**. La propuesta no depende del saldo en cuentas ni de estimaciones de cobros. No incluye partidas independientes de nómina o efectivo.

Conserva la estructura visual de la referencia `Presupuesto_Semanal_21_27_Sep_2026.pdf`: encabezado, importes destacados, detalle, composición y firmas; adaptada a los colores de Finanzas, con anexo de requerimientos e historial.

## Regla de selección

1. Incluir pagos fijos pendientes vencidos o con fecha hasta el domingo del periodo, descontando cargos bancarios ya ligados. Seleccionar importes completos en orden de fecha e ID hasta el tope. El método de ejecución del pago fijo no altera su obligación.
2. Seleccionar la factura más antigua por vencimiento de cada proveedor, con desempate por emisión e ID. Un proveedor recibe una sola factura en la primera vuelta aunque opere por varias empresas/sucursales pagadoras. Se muestra la cuenta de pago de cada registro.
3. Las facturas se proponen por su saldo completo pendiente. Si una no cabe, queda pendiente; no se divide ni se salta para elegir una más nueva del mismo proveedor. Se puede atender a otro proveedor cuya primera factura sí quepa.
4. Solo después de cubrir todos los pagos fijos y una factura por cada proveedor elegible se consideran facturas adicionales. Como criterio inicial de carga alta se usa **$100,000 en facturas elegibles pendientes por proveedor**, declarado en el PDF.
5. Para adicionales, priorizar al proveedor con mayor deuda restante y tomar su siguiente factura más antigua. Recalcular la prioridad después de cada selección. Si su siguiente factura no cabe completa, detener adicionales de ese proveedor; no saltar a una más pequeña y reciente.
6. Nunca rebasar $500,000. El importe es un máximo, no una meta: puede quedar margen sin asignar. Si los pagos fijos solos superan el tope, mostrar lo requerido y lo pendiente, seleccionar únicamente pagos fijos completos que quepan y no añadir facturas.
7. Excluir de selección automática facturas pagadas/canceladas, emitidas después del corte, sin vencimiento, que vencen después del periodo, sin identificación de proveedor/cuenta o sujetas a convenio. Las sujetas a convenio conservan su calendario y se explican en el anexo; no se mezclan con la selección libre.
8. Conciliar saldos de facturas sin incrementarlos por historial incompleto: usar el menor entre saldo guardado y total menos abonos ligados. Calcular en centavos enteros.

La necesidad base es `pagos fijos requeridos + una factura elegible por proveedor`. Se muestran el excedente respecto al tope, los proveedores sin primera factura y todas las facturas que quedan pendientes. Los adicionales no ocultan necesidades de la primera vuelta.

## Fuentes reales

Seis fuentes paginadas y de solo lectura:

- `finanzas_bank_movements`: conciliación de abonos e historial, sin calcular disponibilidad para seleccionar pagos.
- `finanzas_supplier_invoices`: facturas y saldos por proveedor.
- `finanzas_fixed_payments`: obligaciones pendientes con fecha.
- `finanzas_supplier_agreements`, `finanzas_supplier_agreement_installments` y `finanzas_supplier_agreement_invoices`: calendario y vínculos para no adelantar facturas comprometidas.

La generación propaga errores de consulta. Las reservas de disponibilidad bancaria no se consultan ni se descuentan del presupuesto de requerimientos. Se conserva el flujo central de guardado e historial del PDF; no se registran pagos ni se modifican facturas.

## Historial y lectura del PDF

- Tarjetas de facturas propuestas, pagos fijos propuestos y total; tope de $500,000 y margen sin asignar.
- Facturas identificadas como primera del proveedor o adicional por carga alta.
- Pagos fijos con fecha, arrastre, importe requerido e importe propuesto.
- Desglose de presupuesto por empresa/sucursal pagadora; resumen de deuda por proveedor y pendientes fuera de la selección.
- Hasta ocho semanas completas de flujo y sus medianas, únicamente como referencia. No incluye semanas anteriores al primer registro, pero sí semanas posteriores sin actividad. Excluye traspasos internos, ajustes y movimientos identificados como Bóveda, reposición de fondo o efectivo.
- Los compromisos de convenio se muestran informativamente y requieren revisión de su calendario. No se añaden por duplicado al total de facturas libres y pagos fijos.

La lectura corresponde a registros visibles al generar; no reconstruye estados históricos ni concilia contra estados de cuenta externos. El PDF es una propuesta pendiente de autorización. El diario conserva su comportamiento.

## Validación

Pruebas de independencia del saldo y del historial bancario, una factura por proveedor entre cuentas, prioridad de carga alta, importes completos, tope exacto incluyendo centavos y pagos fijos, obligaciones superiores al límite, fechas, abonos y convenios. Integración de seis fuentes, paginación superior a 500 filas y ruta central de viernes. PDFs simulados normal, extenso, vacío, con requerimientos superiores al tope y con pagos fijos superiores al tope, revisados mediante renderizado.

Resultado: 19 pruebas específicas y 132 pruebas en la suite conjunta de Supervisión, Dirección y Finanzas aprobadas; análisis estático sin observaciones.

Implementación local; requiere el despliegue habitual para producción. Sin migraciones nuevas.
