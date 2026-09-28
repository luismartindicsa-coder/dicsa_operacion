# Confiabilidad de Rentabilidad: pendientes al 23/09/2026

**Dictamen:** diagnóstico operativo provisional. Las correcciones anteriores y sus pruebas no certifican que todos los importes, coberturas y repartos representen la operación real. No usar el saldo aislado ni el semáforo para decidir la salida de una empresa.

Revisión del código actual y de la conciliación del 22/09, sin una nueva consulta de datos productivos. Los importes reales citados corresponden al corte 01–22/09/2026, lectura `2026-09-22T22:18:00.052596`. No son un cierre actualizado del día 23.

## Falla adicional reproducida: cobertura parcial de referencias

`referenceDays` en `profitability_inference.dart` devuelve cero días pendientes si existe cualquier componente del bloque que no sea parámetro. Para disposición y báscula hay condiciones equivalentes por presencia de cualquier componente. No se comprueba cobertura completa del periodo/actividad.

Una prueba aislada ejecutada con el motor actual reprodujo:

| Caso sintético | Sin comprobante actual | Con un comprobante parcial | Problema |
|---|---:|---:|---|
| Un contenedor, corte del 1 al 22 de septiembre | $2,913.17 estimados | $100.00 | Un importe fechado elimina toda la referencia del resto del corte. |
| Dos servicios en días diferentes, báscula a la referencia de $100/servicio | $200.00 estimados | $100.00 por una pesada | La presencia de una pesada suprime también la referencia del segundo servicio. |

Son cifras sintéticas: demuestran la falla de cobertura, no un costo real perdido de una empresa. La prueba aprobó porque comprobaba la reproducción de la anomalía, no su corrección. **La falla sigue pendiente.** La tarifa usada también requiere validación operativa independiente.

Evidencia temporal: `/private/tmp/dicsa_profit_remaining_audit_20260923.json`, `.log` y `_test.dart`. La sonda se retiró del directorio de pruebas para no confundir una reproducción del defecto con una regresión que avale el comportamiento.

## Pendientes de base operativa

- **Maricruz:** $465,920 sin concepto conciliado. Permanecen en el resultado global provisional, sin repartir a empresas. La clasificación puede cambiar el costo total o su destino.
- **Históricos:** $351,507.32 de complemento atribuido, ya neto del gasto actual comparable. Corregir su fórmula no demuestra que el nivel histórico sea representativo del consumo actual.
- **RH:** $225,653.62 del total de $649,082.39 son sueldo de referencia para días sin nómina publicada. Los choferes se identifican por coincidencia entre catálogos; el personal común restante mezcla funciones. Transporte promedia participaciones de viajes y km; patio/soporte promedia kg y movimientos. Cuando existen ambas bases tienen igual peso. Son aproximaciones, no horas comprobadas.
- **Tarifas y actividad:** persisten respaldos del documento MONROE, entre ellos combustible a 3 km/L y $23.67/L, báscula a $100/servicio y renta/disposición de referencia. Parte de esas bases se utiliza fuera de MONROE. Los km medidos de la unidad/día se dividen por servicios y los faltantes se infieren. Falta comprobar vigencia y aplicabilidad.
- **Material:** se mantiene el bloque expresamente excluido de modificación. Sin regla específica, se usa recuperación del 100%; hay comparables por familia, compras inferidas por exceso de entradas y valor igual a compra cuando falta comparable. El valor recuperable no prueba una venta del material de esa empresa. Americano → Celanese permanece confirmado únicamente para americano.
- **Conciliación documental:** los enlaces explícitos y las confirmaciones eliminan duplicados identificados; no prueban ausencia de duplicación entre documentos sin vínculo. La composición de pagos mixtos de cargas/retenciones también requiere desglose para certificar su costo incremental.
- **Ceros y confianza:** se generan ceros cuando no existe base aplicable; eso no confirma gratuidad. El porcentaje de estimación no incorpora como estimadas todas las asignaciones proporcionales y la confianza de un componente repartido usa un valor fijo. No son medidas estadísticas de exactitud.
- **Salida de empresas:** el simulador supone por defecto ahorro completo en compra, combustible, transporte, disposición y báscula, y retención de otras categorías. No verifica contratos, rutas compartidas, sustitución de volumen ni plazos para liberar capacidad.

## Criterio para usarlo en decisiones

Usarlo para localizar los costos dominantes y priorizar conciliaciones. Antes de recomendar una salida: corregir cobertura parcial; conciliar importes globales con fuentes sin duplicados; validar puestos, actividad, tarifas y conceptos pendientes; calcular escenarios de los supuestos materiales y comprobar qué costos realmente desaparecen. La decisión es más defendible cuando permanece igual bajo escenarios plausibles, aunque no exista contabilidad de costos exacta por empresa.
