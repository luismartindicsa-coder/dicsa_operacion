# Precios de venta y unidades en rentabilidad operativa

## Corrección

La inferencia automática consultaba exclusivamente comparables `ventas:` de Mayoreo. Menudeo ya se cargaba, pero no participaba en esa valoración. Ahora se usan ambas áreas, sin consultas adicionales:

**Precio = suma de importes vendidos / suma de cantidades vendidas del mismo material y unidad.**

- Si solo un área tiene ventas elegibles, aporta su promedio ponderado completo.
- El periodo seleccionado tiene prioridad; la referencia histórica de hasta 90 días solo se usa si no hay comparables actuales.
- Una calidad comercial específica conserva su nombre/equivalencia. Un material genérico (cartón, chatarra, papel, plástico) utiliza la familia, identificado como mezcla estimada. Servicios y estados de venta no elegibles no entran.
- Americano sigue siendo Celanese. Nacional/corrugado de AVON no se reclasifica como americano.
- Las reglas explícitas de recuperación también combinan áreas y conservan su rendimiento. No convierten piezas a kilos.
- Las bases muestran área, importe, cantidad, unidad, fechas y precio. Los importes finales de los tickets determinan el ponderado; el precio capturado inicialmente puede diferir por ajustes.

## Tarimas: confirmaciones de Dirección

El 29/09/2026 Dirección confirmó:

- Las cantidades 66 y 222 de MONROE, vendidas a Emilio Sandoval, son piezas.
- Las ventas a Víctor García a $20 también son piezas.
- Las cargas vendidas a Braulio (por ejemplo, 6,605 a $2.40) son kilos.

La excepción se limita a material y contraparte; no clasifica unidades por un umbral de precio. Otras tarimas de Menudeo con unidad desconocida quedan pendientes de conciliación. El catálogo de Compras declara KG para las tarimas de MONROE, por lo que rentabilidad aplica la confirmación sin modificar los tickets originales.

Las piezas se guardan y muestran separadas de los kg en el análisis, su snapshot, CSV operativo y PDF. No se suman como toneladas ni entran como kilos en repartos o referencias de compra por peso. Los gastos de la cuenta siguen conciliados; la actividad y los servicios mantienen sus bases propias.

## Conciliación con los mismos datos, 1–29 de septiembre

Lectura conservada del 29/09/2026, 09:45. Es una comparación reproducible con el mismo origen; no una lectura nueva de Supabase.

| Venta de tarimas | Cantidad | Importe | Precio efectivo |
|---|---:|---:|---:|
| Emilio Sandoval | 288 piezas | $9,504.00 | $33.00/pieza |
| Víctor García | 515 piezas | $10,300.00 | $20.00/pieza |
| Total por pieza | 803 piezas | $19,804.00 | $24.6625/pieza |
| Braulio | 25,310 kg | $60,744.00 | $2.40/kg |

Compras de MONROE: folios 7076 y 7098, 222 + 66 = **288 piezas**, por **$3,744.00**. Valor operativo: 288 × $24.6625 = **$7,102.80**. Los mismos dos folios aparecen en las ventas a Emilio por $9,504.00; esa observación documental no se suma al valor operativo ponderado.

La referencia verbal de $40,000 mensuales de tarimas de MONROE **no está conciliada con este corte**. No se atribuyen todas las ventas globales de tarima a una sola empresa. Harían falta cantidades/origen adicionales o un periodo distinto para respaldar esa cifra.

## Cajón de madera: inferencia solicitada, no equivalencia confirmada

Dirección indicó que no conocía la unidad/salida y pidió inferirla de los datos. Las compras de CAJON MADERA suman 490 + 970 = 1,460, por $17,520; una venta posterior de MADERA PIEZA del 21/09 registra 1,460 por $1,168 ($0.80 por cantidad capturada).

Se utiliza esa salida **provisionalmente** solo cuando hay un único origen de CAJON MADERA, la suma de cantidades coincide y las ventas ocurren después de las compras dentro del periodo. Se conserva KG según el catálogo de Compras, expresamente pendiente de confirmar en la venta. La coincidencia no prueba la trazabilidad ni que ambas unidades sean iguales. La advertencia aparece junto al resultado, en las bases y en el PDF. No se crea una equivalencia global permanente ni se cambia el precio de compra registrado.

Además, MADERA PIEZA estaba vinculada al catálogo general CHATARRA; se impide que su venta sirva como comparable de metal. Esto se limita al precio de venta, conservando la conciliación física previa.

## Costos y límites

Las compras documentadas y los ingresos de servicios se conservan. Separar las 288 piezas cambia ligeramente los repartos por peso. También elimina la contaminación del costo por kilo de una entrada de tarima estimada de AVON: baja de $624.73 a $443.25. La reducción global de costo es **$181.48**, explicada enteramente por esa referencia de compra; no se crea ni elimina nómina.

El nuevo precio puede aumentar o disminuir el valor operativo. Se sigue valorando el material recuperable aunque no se haya vendido, con el rendimiento configurado o 100% por defecto. La calidad comercial genérica, las unidades pendientes y la equivalencia inferida de madera siguen siendo limitaciones explícitas.

Validación: pruebas de mezcla de áreas con volúmenes diferentes, área única, calidad/Celanese, periodo e histórico, piezas contra kilos, reglas de recuperación, inferencia de cajón y ausencia de coincidencia; conciliación con fuentes congeladas; revisión de pantalla ancha/angosta y PDF.
