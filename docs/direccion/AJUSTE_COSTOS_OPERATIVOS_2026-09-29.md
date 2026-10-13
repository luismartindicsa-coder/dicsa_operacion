# Retiro contable y ajuste de costos operativos — 29/09/2026

Nota posterior del mismo día: la valoración comercial y las unidades se ajustaron en [Precios ponderados y unidades](PRECIOS_PONDERADOS_Y_UNIDADES_2026-09-29.md). Las cifras de este documento describen el corte anterior a ese cambio.

## Cambio solicitado

Se retira íntegramente la utilidad contable agregada: motor, reconstrucción de inventario, lecturas históricas adicionales, carga en segundo plano, paneles, anexo PDF y espera de exportación. Se restituye el flujo de carga operativo anterior. No se borran registros de negocio ni cortes históricos de Supabase. La copia reversible del código retirado está en `/private/tmp/dicsa_accounting_removed_20260929.tar.gz`.

## Corrección confirmada por Dirección

El IMSS de julio ($304,252.15, 20/07/2026) aparece en Finanzas como Mazatlán. El de septiembre ($316,748.88, 17/09/2026) aparece como Celaya. Dirección confirmó el 29/09/2026 que ambos corresponden a **la misma plantilla de DICSA**.

El modelo estaba formando dos grupos históricos distintos por ese centro de captura. La cobertura de septiembre cancelaba el histórico de Celaya, pero dejaba una reserva adicional para Mazatlán. Se corrige la identidad del grupo histórico del registro de julio, sin alterar su centro original ni su importe en Finanzas. La regla está limitada a ese ID, fecha, importe, empresa, centro y contraparte; no fusiona todos los gastos de Mazatlán ni otras plantillas.

En el corte 01–29/09/2026, se elimina una reserva adicional de **$98,036.80** en toda la operación modelada: **$71,892.88** correspondían a empresas visibles de Compras Mayoreo y el resto a otras actividades. El cargo documentado del IMSS de septiembre conserva su cobertura e importe aplicable. No se rebaja la remuneración de RH.

Las **comisiones de Caja Menudeo por $200,248** del mismo periodo se mantienen: Dirección confirmó que son comisiones adicionales, no compras ya capturadas ni pagos incluidos en RH.

## Comparación con las mismas fuentes

Periodo 01–29/09/2026; lectura local `2026-09-29T09:45:43.452748`. No comparar estos valores directamente con capturas anteriores del 1–22 de septiembre.

| Empresa | Costo antes | Costo corregido | Reducción | Aporte corregido |
|---|---:|---:|---:|---:|
| AVON | $348,688.83 | $342,202.03 | $6,486.80 | $25,639.93 |
| DECASA | $118,122.05 | $115,834.17 | $2,287.87 | $-35,076.46 |
| WHIRLPOOL | $426,427.80 | $408,546.49 | $17,881.30 | $-82,266.27 |
| KS | $314,353.90 | $303,102.30 | $11,251.60 | $-139,253.36 |
| MONROE | $664,097.21 | $644,109.44 | $19,987.77 | $-271,889.30 |
| LICBOX | $237,496.19 | $235,530.36 | $1,965.83 | $76,363.90 |

La generación, cada componente de compra y valor del material, los ingresos por servicios y los importes de RH se conservaron. La diferencia del resultado global coincide con la reserva eliminada, no con un cambio de precios o de volumen.

## ¿Se considera que todo lo comprado se vende?

El operativo valora por defecto el 100% de los kg físicos comerciales comprados o recibidos a su precio comparable ponderado, aunque aún no hayan salido del patio. Es un valor recuperable estimado; no exige que la venta ocurra en el mismo periodo. Las reglas específicas de recuperación pueden sustituir esa base; residuos de disposición y leña sin salida tienen tratamiento separado.

Se conserva Americano → Celanese únicamente para el material identificado como americano. No se cambia el cartón nacional o corrugado de AVON a Celanese.

Sin precio comparable, el motor usa el costo de compra como valor y supone margen comercial cero. En esta lectura eso ocurre, entre las empresas revisadas, en AVON ($876.23), MONROE ($21,264.00) y WHIRLPOOL ($8,698.50), principalmente tarimas y madera. No se inventó un precio de venta para aumentar su aporte.

## Desglose visible del costo

El mismo total ahora se puede abrir en cinco bases mutuamente excluyentes:

- Documentos y nómina publicada, directos o repartidos.
- Compra estimada o pendiente de conciliar.
- Nómina estimada para días sin cierre.
- Complementos históricos.
- Otras estimaciones y tarifas.

El desglose usa los componentes ya calculados. No introduce consultas, historial ni otro motor. La suma de las cinco bases es exactamente el costo mostrado. La atribución documental también puede ser proporcional; el desglose no certifica precisión causal. No se calcula una supuesta utilidad quitando todos los estimados, porque eso conservaría ingresos de material inferido mientras eliminaría su costo.

## Pendientes reales

Esta corrección no demuestra que todos los demás costos estén bien. Permanecen compras inferidas al conciliar entradas contra tickets, referencias de nómina para días sin cierre, reservas históricas de mantenimiento/proceso y tarifas de operación. Por ejemplo, KS conserva $96,716.13 de compra inferida; MONROE conserva $81,470.50. Son las siguientes bases importantes que requieren conciliación, no importes confirmados como duplicados.

No se encontraron filas publicadas repetidas para el mismo empleado y periodo en esta lectura. Esto no descarta por sí solo solapamientos de periodos diferentes ni otros problemas de captura. Maricruz sigue pendiente fuera del reparto entre empresas. Los pendientes de cobertura parcial y tarifas descritos en `PENDIENTES_CONFIABILIDAD_RENTABILIDAD_2026-09-23.md` no se dan por resueltos por este cambio.

## Evidencia y validación

Se usó una lectura local congelada para comparar antes y después sin cambios en fuentes. La regresión verifica conservación exacta de componentes de valor, compra e ingresos; conservación de RH; reparto exhaustivo del costo; y diferencia global igual a la reserva eliminada. Hay una prueba adicional que conserva separadas plantillas distintas y limita la conciliación al registro confirmado. La pantalla se revisó en 1440 y 760 px.

Evidencias locales temporales: `/private/tmp/dicsa_operating_sources_20260929.json`, `/private/tmp/dicsa_operating_corrected_20260929.json`, `/private/tmp/dicsa_operating_imss_tests.log`. Las fuentes completas no se incorporan al repositorio.
