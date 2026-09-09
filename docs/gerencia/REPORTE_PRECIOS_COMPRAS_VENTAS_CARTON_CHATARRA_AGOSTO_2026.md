# Rentabilidad y política de precios — CARTÓN y CHATARRA — agosto de 2026

**Periodo exclusivo:** 1 al 31 de agosto de 2026. **Extracción:** 8 de septiembre de 2026, 13:59 h, Ciudad de México (19:59 UTC). **Moneda:** MXN; precios por kilogramo, salvo alertas de unidad. **Alcance:** análisis y propuestas; no se modificó ningún dato, tarifa, ticket ni corrida en DICSA.

El cartón nacional confirmado deja **$0.6720/kg y 29.47%** de margen bruto referencial; el americano, **$1.4021/kg y 39.37%**; y el limpio de empresas, **$1.5773/kg y 59.67%**. La rebaba comprada directamente deja **$1.9135/kg y 40.71%**. No existe evidencia suficiente para convertir las corridas registradas de chatarra en una tarifa rentable de compra de entrada: el rendimiento registrado es 100%, hay salidas sin precio de mayoreo y falta enlace entre lotes comprados, transformados y vendidos.

## 1. Fuentes, corte y método

Se consultó directamente la base operativa de DICSA mediante solicitudes `GET`, con paginación y `count=exact`. Se usaron las fechas operativas del módulo, no las fechas de captura o modificación. Los registros capturados en septiembre cuyo día operativo es agosto sí se incluyen. No se usaron cifras del reporte del 15 de agosto ni registros operativos de otros meses; tampoco se excluyeron las promociones del 13 y 14 de agosto.

| Fuente | Filtro operativo | Filas leídas del mes | Uso |
| --- | --- | --- | --- |
| Menudeo — `men_tickets` | `ticket_date >= 2026-08-01` y `< 2026-09-01` | 1,206 | Separación estricta por `direction`; las 1,206 están PAGADO |
| Compras Mayoreo — `compras_tickets` | Mismo intervalo en `ticket_date` | 459 | Compras devengadas; incluye pendientes de pago/factura |
| Ventas Mayoreo — `mayoreo_sales_reports` | Mismo intervalo en `sale_date` | 57 | Peso e importe aprobados |
| Cuenta El Palomar — `mayoreo_palomar_movements` | Mismo intervalo en `date` | 30 | Conciliación; no se suman otra vez como ventas |
| Transformaciones — `material_transformation_runs_v2` y sus salidas | Mismo intervalo en `op_date` | 215; 19 de CHATARRA | Entrada una vez por ID de corrida; salida una vez por ID de detalle |
| Catálogos de tarifas y materiales | Consulta vigente al extraer | Menudeo: 289 líneas; compra mayoreo: 81 | Sólo referencia de tarifa actual y clasificación; no son operaciones de septiembre |

Las fechas `timestamptz` se interpretan por su día de calendario almacenado, como fechas operativas: muchos registros están a `00:00:00+00:00`. Convertirlos a hora local antes de filtrar desplazaría artificialmente el 1 de agosto al 31 de julio. El rango consultado abarca todo el mes; la primera compra registrada en ambos canales es del 3 de agosto y la última del 31. Ventas abarca del 1 al 31. Esto certifica la cobertura de la consulta, no que no falten capturas de la operación física.

- **Compra ponderada:** `Σ amount_total / Σ payable_weight` en Menudeo compra (`direction=purchase`); `Σ amount / Σ payable_weight` en Compras Mayoreo. Los importes incluyen los premios/descuentos registrados; no se sustituyen por la tarifa de catálogo.
- **Venta ponderada:** `Σ amount_total / Σ payable_weight` en Menudeo venta (`direction=sale`); `Σ approved_amount / Σ approved_weight` en Ventas Mayoreo. Nunca se usa `exit_weight` como sustituto de kilos aprobados ni `price_snapshot` como sustituto del importe aprobado.
- **Utilidad bruta referencial/kg:** venta ponderada menos compra ponderada de la misma calidad. **Margen bruto:** utilidad/kg dividida entre venta ponderada. No es el recargo sobre costo.
- Todas las cifras se calculan con decimales sin redondear precios intermedios. Se muestran kilos con dos decimales y precios con cuatro; tarifas sugeridas con dos. N/D significa que no hay una base comparable suficiente, y no equivale a cero.
- Los importes usados corresponden al material según el módulo, sin agregar IVA, cobranza, cheques, saldos ni anticipos. No se calculó flujo de caja ni utilidad neta.

### Clasificación y excepciones

| Material/origen | Tratamiento |
| --- | --- |
| CARTON NACIONAL | Nacional, salvo la regla expresa de El Palomar |
| CARTON AMERICANO y CARTON CELANESE | Americano; incluye Celanese de Grupak y Queretana Toluca |
| El Palomar: CARTON NACIONAL y ORDINARIO DE PRIMERA | Limpio, exclusivamente para sus partidas de cartón; su chatarra permanece chatarra |
| Ricardo García Mendieta | Nacional; se excluye CAPLE y se respetaría una identificación explícita de limpio |
| Bio Papel, registrado BIO PAPPEL | Nacional; incluye ORDINARIO DE PRIMERA RECOGIDO |
| AVON, DECASA, KS, LICBOX, MONROE, SETEXMES, TRUPER y WHIRLPOOL | Cartón limpio por procedencia empresarial/fábrica; no se encontró descuento de humedad en sus compras de cartón |
| Grupak | Celanese americano. No tiene venta CARTON NACIONAL en agosto; no se reclasifica ese material a americano por cliente |
| Queretana Carrillo: CARTON RECOGIDO | 109,040 kg, $261,696.00, $2.4000/kg, separados: el material no dice nacional, americano ni limpio. No se impone una calidad por el nombre del cliente |
| Rocío Carvajal / Rodolfo Vera / Víctor García STROKPACK | Cartón con calidad pendiente; no se presume origen industrial. Rocío tiene descuentos de humedad de hasta 25%; Rodolfo tiene descuentos de basura |
| CARTON RECOGIDO / CARTONRECOGIDO de Menudeo y POLI CARTON | Se presentan fuera de las tres bandas; no se mezclan con nacional, americano o limpio |
| CHATARRA MIXTA / CHATARRA / CHATARRA GENERAL | Entrada explícita mixta y entradas genéricas separadas. Estas últimas requieren confirmar composición antes de homologarlas a mixta |
| REBABA | Compra directa separada de la entrada mixta y de la rebaba obtenida de transformación |
| CHATARRA/MOTOR | Se excluye de la canasta de entrada mixta. Su venta de Menudeo se muestra aparte |
| LAMINA, RACKS y CINTAS SIERRA | Otras salidas/compras de familia chatarra, separadas por material; no se convierten a pesado, retorno ni placa |
| ACERO y PISTON DE ACERO | Fuera de alcance: catálogo los ubica en METAL. No se usa la venta de ACERO a $40.95/kg para valuar chatarra |
| MADERA PIEZA | Un registro de venta de 5 unidades y $150 está ligado a CHATARRA: se excluye de sus kilos y se reporta la inconsistencia |

Si se confirma que CARTON RECOGIDO de Queretana Carrillo es nacional, las ventas nacionales serían **823,679 kg**, **$1,891,194.40** y **$2.2960/kg**, en vez de $2.2802/kg. Esa sensibilidad no modifica la banda sugerida; no se usa para elevar el precio base mientras falte la confirmación.

## 2. Tabla ejecutiva por material/calidad

| Material/calidad | Canal compra | Kg comprados | Compra ponderada | Canal venta | Kg vendidos | Venta ponderada | Utilidad bruta/kg | Margen bruto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cartón nacional | Menudeo | 495,251.40 | $1.6082 | Ventas Mayoreo | 714,639.00 | $2.2802 | $0.6720 | 29.47% |
| Cartón americano | Menudeo | 218,000.74 | $2.1595 | Ventas Mayoreo | 143,719.00 | $3.5616 | $1.4021 | 39.37% |
| Cartón limpio | Compras Mayoreo | 396,090.00 | $1.0662 | Ventas Mayoreo | 210,935.00 | $2.6435 | $1.5773 | 59.67% |
| REBABA (compra directa) | Compras Mayoreo | 60,600.00 | $2.7865 | Ventas Mayoreo | 20,930.00 | $4.7000 | $1.9135 | 40.71% |
| Cartón nacional — venta de Menudeo | Costo Menudeo de fila nacional | — | $1.6082 | Menudeo — sale | 10,619.20 | $4.4367 | $2.8285 | 63.75% |
| CHATARRA MIXTA — entrada | Menudeo | 2,830.80 | $3.5846 | Canasta de transformación; ver §3 | — | N/D verificado | N/D | N/D |
| CHATARRA — entrada | Menudeo | 2,655.00 | $1.5000 | Canasta de transformación; ver §3 | — | N/D verificado | N/D | N/D |
| CHATARRA — entrada | Compras Mayoreo | 82,520.00 | $3.2256 | Canasta de transformación; ver §3 | — | N/D verificado | N/D | N/D |
| CHATARRA GENERAL — entrada | Compras Mayoreo | 6,990.00 | $3.3400 | Canasta de transformación; ver §3 | — | N/D verificado | N/D | N/D |
| PESADO — salida | Sin compra directa identificada | 0.00 | N/D | Ventas Mayoreo | 70,115.00 | $5.1000 | N/D | N/D |
| RETORNO INDUSTRIAL — salida | Sin compra directa identificada | 0.00 | N/D | Ventas Mayoreo | 73,740.00 | $5.8492 | N/D | N/D |
| PLACA Y ESTRUCTURA — salida | Sin compra directa identificada | 0.00 | N/D | Ventas Mayoreo | 26,375.00 | $5.2000 | N/D | N/D |
| MIXTO — salida | Sin compra directa identificada | 0.00 | N/D | Ventas Mayoreo | 5,490.00 | $5.0000 | N/D | N/D |
| CHATARRA MIXTA — salida | Costo de lote de salida no trazado | — | N/D | Menudeo — sale | 3,707.20 | $14.7474 | N/D | N/D |
| CHATARRA — salida | Costo de lote de salida no trazado | — | N/D | Menudeo — sale | 20.00 | $28.0000 | N/D | N/D |
| CHATARRA/MOTOR — salida | Costo de lote de salida no trazado | — | N/D | Menudeo — sale | 555.00 | $28.0000 | N/D | N/D |
| LAMINA — salida | Costo de lote de salida no trazado | — | N/D | Menudeo — sale | 1,765.00 | $11.4504 | N/D | N/D |
| RACKS — salida | Costo de lote de salida no trazado | — | N/D | Menudeo — sale | 4,356.67 | $9.0000 | N/D | N/D |

La fila nacional de venta de Menudeo reutiliza sólo el costo unitario, sin volver a sumar los kilos comprados. Las ventas de Menudeo a $4.4367/kg de nacional y $14.7474/kg de CHATARRA MIXTA corresponden a otro canal comercial; no justifican pagar más por toda la compra destinada a mayoreo. Tampoco se compara la chatarra mixta comprada con una única salida como pesado.

### Partidas que requieren clasificación o revisión de unidad

| Material sin homologar | Canal | Dirección | Registros | Kg registrados | Importe | Ponderado |
| --- | --- | --- | --- | --- | --- | --- |
| CARTON RECOGIDO [calidad pendiente] | Compras Mayoreo | Compra | 3 | 17,884.00 | $26,196.60 | $1.4648 |
| CARTON STROKPACK [calidad pendiente] | Compras Mayoreo | Compra | 1 | 6,720.00 | $10,080.00 | $1.5000 |
| CARTON [calidad pendiente] | Compras Mayoreo | Compra | 7 | 42,970.25 | $64,455.38 | $1.5000 |
| CINTAS SIERRA | Compras Mayoreo | Compra | 2 | 25.00 | $3,300.00 | $132.0000 |
| CARTON RECOGIDO [calidad pendiente] | Menudeo | Compra | 2 | 3,230.00 | $3,798.00 | $1.1759 |
| CARTONRECOGIDO [calidad pendiente] | Menudeo | Compra | 1 | 685.00 | $753.50 | $1.1000 |
| POLI CARTON [calidad pendiente] | Menudeo | Compra | 3 | 2,436.50 | $2,436.50 | $1.0000 |
| CARTON RECOGIDO [calidad pendiente] | Ventas Mayoreo | Venta | 4 | 109,040.00 | $261,696.00 | $2.4000 |

CINTAS SIERRA aparece en catálogo con unidad KG, pero su compra a $132/kg amerita confirmar unidad y composición. No se incorpora al costo de chatarra mixta. Ninguna partida de esta tabla se utiliza para calcular márgenes entre calidades que no estén confirmadas.

## 3. Chatarra: rendimiento y valor recuperado por kilogramo de entrada

La fórmula requerida es `VR = Σ [(kg de salida j / kg de entrada) × venta ponderada j]`. El denominador se suma una vez por ID de corrida, antes de unir sus salidas. No se usa el porcentaje de ventas de cada material como sustituto del rendimiento físico.

Las 19 corridas de CHATARRA registran **141,389 kg de entrada y 141,389 kg de salida**. Ninguna tiene salida superior a entrada: **0 corridas inválidas por sobre-rendimiento**. Se separa la corrida de CHATARRA/MOTOR del 4 de agosto, **555 kg**, y quedan **18 corridas, 140,834 kg de entrada y salida**. Todas tienen una sola salida y todas registran exactamente 100%.

Ese resultado pasa la comprobación aritmética, pero **no acredita un rendimiento medido de chatarra mixta**. Todas las corridas parten de la familia general CHATARRA y `source_mode=MIXED`; no identifican ticket/lote de compra. Además, el código de captura permite `inputKg ?? outputKg`: si no se captura entrada, se toma la salida como entrada ([código local](../../lib/app/services/inventory_transformation_grid.dart), método `_effectiveInputKg`, línea 136). No puede determinarse cuáles entradas fueron pesadas y cuáles autocompletadas.

| Salida de corrida | Kg salida | Rendimiento registrado | Canal de precio | Kg vendidos en ese canal | Venta ponderada | Aporte nominal $/kg entrada |
| --- | --- | --- | --- | --- | --- | --- |
| PESADO | 67,980.00 | 48.27% | Ventas Mayoreo | 70,115.00 | $5.1000 | $2.4617 |
| RETORNO INDUSTRIAL | 14,570.00 | 10.35% | Ventas Mayoreo | 73,740.00 | $5.8492 | $0.6051 |
| PLACA Y ESTRUCTURA | 0.00 | 0.00% | Ventas Mayoreo | 26,375.00 | $5.2000 | $0.0000 |
| MIXTO | 400.00 | 0.28% | Ventas Mayoreo | 5,490.00 | $5.0000 | $0.0142 |
| REBABA | 20,930.00 | 14.86% | Ventas Mayoreo | 20,930.00 | $4.7000 | $0.6985 |
| LAMINA | 10,315.00 | 7.32% | Menudeo venta (sólo sensibilidad) | 1,765.00 | $11.4504 | $0.8387 |
| CHATARRA | 19,649.00 | 13.95% | Menudeo venta (sólo sensibilidad) | 20.00 | $28.0000 | $3.9065 |
| RACKS | 6,990.00 | 4.96% | Menudeo venta (sólo sensibilidad) | 4,356.67 | $9.0000 | $0.4467 |

**Canasta con precios de Ventas Mayoreo:** $3.7796/kg de entrada, equivalente a $532,291.84 de valuación de salidas registradas. Sólo cubre 73.76% del peso transformado. Faltan precios de mayoreo comparables para **36,954.00 kg (26.24%)** de LAMINA, CHATARRA genérica y RACKS. Es un subtotal de valuación, no un ingreso realizado ni el valor recuperado total. El aporte de PLACA es cero porque no se registró esa salida, aunque se vendieron 26,375 kg; no se renombra LAMINA como PLACA.

**Sensibilidad nominal usando también las ventas de Menudeo, separadas por material y canal:** $8.9714/kg de entrada. Es la suma de los aportes anteriores, sin promediar precios por ticket. No se usa para recomendar compras: aplica la venta de apenas **20 kg de CHATARRA a $28/kg** a **19,649 kg** de salida genérica y supone rendimientos que no están medidos independientemente. Sólo esa extrapolación aporta **$3.9065/kg de entrada**. Presentarla como rentabilidad alcanzable sobrestimaría la capacidad de pago.

**Valor recuperado validado, utilidad de entrada mixta y tarifa de compra rentable: N/D.** Se mantienen las tarifas individuales mientras se verifican pesajes de entrada, lotes, mermas y composición. No se utiliza ni el subtotal $3.7796 ni la sensibilidad $8.9714 como precio de venta representativo de toda la entrada.

La compra directa de rebaba (60,600 kg) se analiza contra su venta de mayoreo por la misma calidad, pero no se prueba que los 20,930 kg transformados provengan de mixta: podrían incluir rebaba ya comprada como tal. La venta de CHATARRA/MOTOR (555 kg, $15,540) tiene registro de transformación separado y no tiene compra directa identificada en agosto; no se le asigna el costo de mixta.

## 4. Política recomendada de precios

**Propuesta de Gerencia, no tarifa aplicada.** Las bandas siguientes son referencias para negociación por calidad aceptada. No constituyen un aumento automático a todo el catálogo ni reemplazan las tarifas de contratos existentes. Para cartón se propone un piso de margen bruto referencial de **25%** sobre venta, calculado contra la compra aceptada, antes de costos; este 25% es un criterio propuesto, no un objetivo histórico proporcionado por la empresa.

| Material/calidad | Compra estándar menudeo | Compra preferente menudeo | Compra mayoreo objetivo | Venta mayoreo mínima | Venta mayoreo objetivo |
| --- | --- | --- | --- | --- | --- |
| Cartón nacional | $1.60 | $1.70 | $1.60, condicionado a calidad y costo de recepción | $2.30 | $2.40 |
| Cartón americano | $2.10 | $2.20 | $2.10, propuesta sin compra mayoreo comparable en agosto | $3.20 | $3.60 |
| Cartón limpio | $1.10, sólo lote piloto clasificado | $1.20, sólo lote piloto clasificado | $1.20; conservar contratos limpios hasta $1.40 según costos | $2.50 | $2.70 |
| CHATARRA MIXTA — entrada | Sin alza; tarifa individual vigente | Sin nueva preferencia | Sin alza; confirmar mezcla y rendimiento | N/D: debe valuarse la canasta | N/D: debe valuarse la canasta |
| CHATARRA / CHATARRA GENERAL — entrada | Sin alza; revisar clasificación | N/D | Sin alza; tarifa individual vigente | N/D: composición no homologada | N/D: composición no homologada |
| REBABA — compra directa | N/D: sin compras de Menudeo | N/D | $2.80; revisar cada contrato vigente | $4.70 | $4.70 |
| PESADO — salida | N/D | N/D | N/D: sin compra directa comparable | $5.10* | $5.10* |
| RETORNO INDUSTRIAL — salida | N/D | N/D | N/D: sin compra directa comparable | $5.60* | $5.85* |
| PLACA Y ESTRUCTURA — salida | N/D | N/D | N/D: sin compra directa comparable | $5.20* | $5.20* |
| MIXTO — salida separada | N/D | N/D | N/D: no equivale a la entrada mixta | $5.00* | $5.00* |
| CHATARRA/MOTOR | N/D: sin costo de adquisición trazado | N/D | N/D | N/D: sin ventas de mayoreo | N/D |
| LAMINA / RACKS / CINTAS SIERRA | N/D por material | N/D por material | Sin nueva tarifa hasta validar calidad/unidad | N/D por material | N/D por material |
| Cartón de calidad pendiente / POLI CARTON | Conservar tarifa individual; clasificar | N/D | Conservar tarifa individual; clasificar | N/D por calidad | N/D por calidad |

*Para las salidas de chatarra, los mínimos son referencias comerciales observadas en agosto, no precios de equilibrio ni garantía de margen; no existe asignación de costo por salida. Retorno tuvo operaciones a $5.60 y $6.00, con ponderado $5.8492; se propone $5.85 como objetivo comercial. La rebaba sólo tiene una venta de mayoreo: no se presupone que pueda subirse por encima de $4.70.*

El mínimo nacional de $2.30 redondea hacia arriba `$1.70 / 0.75 = $2.2667`; al precio ponderado realmente obtenido ($2.2802), pagar $1.70 dejaría 25.44% antes de costos. Por ello **$1.80–$2.20 no deben convertirse en tarifa general del nacional**. Americano a $2.20 dejaría 38.23% contra su venta ponderada; el mínimo de $3.20 respeta el menor precio observado, y $3.60 aproxima hacia arriba su promedio de agosto. Limpio a $1.20 dejaría 54.61%; su mínimo $2.50 y objetivo $2.70 están dentro de las ventas observadas de El Palomar. Las bandas piloto de limpio de Menudeo se apoyan en compras industriales, no en una compra de Menudeo de esa calidad inexistente en el mes.

Todas las bandas de compra suponen recepción y aceptación de la calidad indicada. **El flete, maniobra y proceso a cargo de DICSA deben restarse de la capacidad de compra**, no absorberse implícitamente. Con rendimiento validado `r` y costo adicional `c` por kg de entrada: `compra máxima = r × venta × (1 − margen objetivo) − c`; para chatarra se sustituye `r × venta` por el VR completo. La venta mínima económica sería `(compra + c) / [r × (1 − margen objetivo)]`. Sin `r` y `c` medidos, los mínimos anteriores son provisionales.

## 5. Lista de proveedores y acciones

**Tarifa actual** es el catálogo vigente al 8 de septiembre; **compra ponderada** es lo realmente registrado en agosto, incluyendo premios/descuentos. La diferencia entre ambas no prueba un error ni autoriza aplicar otra vez alzas ya reflejadas. Los proveedores se agrupan por ID y material, conservando separados Menudeo y Compras Mayoreo.

Criterio propuesto para alzas: material confirmado, tarifa por debajo de la banda preferente, al menos tres tickets de compra en agosto, incremento máximo de **$0.10/kg** y costo incremental de hasta **$1,000/mes por proveedor-material**. El umbral es un límite de exposición propuesto, no un dato histórico. Se marca **No subir por alto impacto** cuando ese siguiente escalón de $0.10 excede $1,000 al volumen de agosto. **Revisar calidad** incluye dudas de calidad, unidad, trazabilidad, margen insuficiente o tarifa ambigua. **Reactivar** significa evaluar contacto/visita para una relación de catálogo sin compras de ese material en agosto; no demuestra abandono ni promete volumen futuro. No se contactó a nadie.

**Impacto mensual estimado = kg comprados en agosto × (nueva tarifa − tarifa actual)**, repitiendo exactamente ese volumen de 31 días. Mide sólo el cambio de tarifa, no diferencia frente al gasto histórico, crecimiento de kilos ni utilidad neta. Si se mantiene, es $0; para reactivaciones sin volumen base, N/D.

**Alzas selectivas propuestas: 4 líneas, $1,768.10/mes adicionales** a volumen constante de agosto, sujetas a calidad aceptada. El resto de las tarifas permanece sin aumento hasta cumplir los criterios descritos.

### Menudeo

| Proveedor | Material | Tarifa actual | Kg agosto | Compra ponderada | Acción recomendada | Nueva tarifa sugerida | Impacto mensual estimado |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ABEL ARCIA | CARTON NACIONAL | $1.70 | 2,820.00 | $1.7000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| ADAN GARCIA CABALLERO | CARTON NACIONAL | $1.80 | 1,065.00 | $1.8000 | Revisar calidad — Tarifa rebasa banda preferente | $1.80 (sin cambio) | $0.00 |
| ADRIAN CARDENAS | CARTON AMERICANO | $2.10 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.10 (sin cambio) | N/D |
| ADRIAN CARDENAS | CARTON NACIONAL | $1.70 | 5,525.00 | $1.6320 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| ALBERTO MENDEZ | CARTON AMERICANO | $2.40 | 2,481.50 | $2.4000 | Mantener — Conservar acuerdo vigente; sin alza general | $2.40 (sin cambio) | $0.00 |
| ALBERTO MENDEZ | CARTON NACIONAL | $2.20 | 23,203.50 | $2.2000 | Revisar calidad — Tarifa rebasa banda preferente | $2.20 (sin cambio) | $0.00 |
| AMBROCIO PEÑAFLOR | CARTON AMERICANO | $2.30 | 2,950.00 | $2.3000 | Mantener — Conservar acuerdo vigente; sin alza general | $2.30 (sin cambio) | $0.00 |
| ANTONIO GARCIA | CARTON AMERICANO | $2.10 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.10 (sin cambio) | N/D |
| ANTONIO GARCIA | CARTON NACIONAL | $1.90 | 37,685.00 | $1.8232 | Revisar calidad — Tarifa rebasa banda preferente | $1.90 (sin cambio) | $0.00 |
| ANTONIO MORALES | CARTON AMERICANO | $2.30 | 117,052.24 | $2.1769 | Mantener — Conservar acuerdo vigente; sin alza general | $2.30 (sin cambio) | $0.00 |
| ANTONIO MORALES | CARTON NACIONAL | $1.90 | 18,254.50 | $1.7616 | Revisar calidad — Tarifa rebasa banda preferente | $1.90 (sin cambio) | $0.00 |
| CARLOS DE LA VEGA | CARTON NACIONAL | $1.70 | 4,735.00 | $1.6220 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| CARLOS ZARATE | CARTON AMERICANO | $2.20 | 10,240.00 | $2.1724 | Mantener — Conservar acuerdo vigente; sin alza general | $2.20 (sin cambio) | $0.00 |
| CARLOS ZARATE | CARTON NACIONAL | $1.60 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.60 (sin cambio) | N/D |
| CASOIS | CARTON NACIONAL | $1.60 | 1,906.00 | $1.4000 | Subir — 3 tickets; verificar calidad aceptada antes de aplicar | $1.70 | $190.60 |
| CATALINA HERNANDEZ J | CARTON AMERICANO | $2.20 | 4,615.00 | $2.1737 | Mantener — Conservar acuerdo vigente; sin alza general | $2.20 (sin cambio) | $0.00 |
| CATALINA HERNANDEZ J | CARTON NACIONAL | $1.90 | 4,055.00 | $1.8483 | Revisar calidad — Tarifa rebasa banda preferente | $1.90 (sin cambio) | $0.00 |
| CLISMAN | CARTON NACIONAL | $1.40 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.40 (sin cambio) | N/D |
| CLISMAN | CARTONRECOGIDO | N/D (sin línea activa equivalente) | 685.00 | $1.1000 | Revisar calidad — Tarifa de compra vigente ausente o múltiple; no sustituir por precio de ticket | N/D; conciliar tarifa | N/D |
| DANIEL MUÑOS | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| DAVID SALINAS | CARTON AMERICANO | $2.10 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.10 (sin cambio) | N/D |
| DAVID SALINAS | CARTON NACIONAL | $1.90 | 15,851.75 | $1.7421 | Revisar calidad — Tarifa rebasa banda preferente | $1.90 (sin cambio) | $0.00 |
| EDUARDO FRIAS | CARTON NACIONAL | $1.70 | 1,720.00 | $1.6497 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| EDUARDO FRIAS | CHATARRA MIXTA | $3.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $3.70 (sin cambio) | N/D |
| ENRIQUE PEREZ | CARTON NACIONAL | $1.60 | 2,615.00 | $1.5566 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $1.60 (sin cambio) | $0.00 |
| ENRIQUE VAZQUEZ | CARTON NACIONAL | $1.70 | 1,565.00 | $1.8000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| ERNESTO EDUARDO | CARTON NACIONAL | $1.60 | 1,280.00 | $1.5434 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $1.60 (sin cambio) | $0.00 |
| FELIX HERNANDEZ | CARTON NACIONAL | $1.70 | 7,406.25 | $1.6397 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| FERNANDO RUBIO | CARTON RECOGIDO | $1.20 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.20 (sin cambio) | N/D |
| FRANCISCO CHIMAL | CARTON AMERICANO | $2.10 | 8,837.50 | $2.0801 | Subir — 8 tickets; verificar calidad aceptada antes de aplicar | $2.20 | $883.75 |
| FRANCISCO CHIMAL | CARTON NACIONAL | $1.60 | 1,282.50 | $1.6000 | Subir — 6 tickets; verificar calidad aceptada antes de aplicar | $1.70 | $128.25 |
| FRIOCIMA | CARTON NACIONAL | $1.60 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.60 (sin cambio) | N/D |
| IGNACIO PEREZ | CARTON AMERICANO | $2.30 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.30 (sin cambio) | N/D |
| IGNACIO PEREZ | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| ISAIAS CABELLO | CARTON AMERICANO | $2.00 | 3,624.00 | $1.9636 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $2.00 (sin cambio) | $0.00 |
| ISAIAS CABELLO | CARTON NACIONAL | $1.70 | 4,021.00 | $1.6841 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| ISAIAS CABELLO | CARTON RECOGIDO | $1.40 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.40 (sin cambio) | N/D |
| ISAIAS CABELLO | CHATARRA MIXTA | $3.60 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $3.60 (sin cambio) | N/D |
| JESUS HRDZ | CARTON RECOGIDO | $1.60 | 1,860.00 | $1.6000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $1.60 (sin cambio) | $0.00 |
| JESUS PATIÑO | CARTON NACIONAL | $1.60 | 5,655.00 | $1.5112 | Subir — 3 tickets; verificar calidad aceptada antes de aplicar | $1.70 | $565.50 |
| JONATHAN JIMENEZ | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| JORGE ARREGUIN | CARTON AMERICANO | $1.80 | 132.50 | $1.8000 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $1.80 (sin cambio) | $0.00 |
| JORGE ARREGUIN | CARTON NACIONAL | $1.70 | 8,837.50 | $1.6539 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| JOSE ANGEL MEDINA | CARTON AMERICANO | $1.90 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.90 (sin cambio) | N/D |
| JOSE ANGEL MEDINA | CARTON NACIONAL | $1.30 | 17,250.00 | $1.2000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $1,725.00/mes | $1.30 (sin cambio) | $0.00 |
| JOSE LUIS MUÑIS | CARTON AMERICANO | $2.20 | 14,760.00 | $2.1265 | Mantener — Conservar acuerdo vigente; sin alza general | $2.20 (sin cambio) | $0.00 |
| JOSE LUIS MUÑIS | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| JOSE URIBE | CARTON NACIONAL | $1.70 | 2,890.00 | $1.6211 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| JUAN CARLOS TORRES | CARTON NACIONAL | $1.90 | 1,295.00 | $1.7714 | Revisar calidad — Tarifa rebasa banda preferente | $1.90 (sin cambio) | $0.00 |
| JUAN ESTRADA | CARTON NACIONAL | $1.90 | 2,175.00 | $1.8421 | Revisar calidad — Tarifa rebasa banda preferente | $1.90 (sin cambio) | $0.00 |
| JUAN SOLIS | CARTON AMERICANO | $2.00 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.00 (sin cambio) | N/D |
| JUAN SOLIS | CARTON NACIONAL | $1.40 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.40 (sin cambio) | N/D |
| JUAN SOLIS | CARTON RECOGIDO | $0.90 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $0.90 (sin cambio) | N/D |
| JUAN SOLIS | CARTON SCREEN | $0.90 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $0.90 (sin cambio) | N/D |
| JUAN SOLIS | CHATARRA MIXTA | $4.60 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $4.60 (sin cambio) | N/D |
| LOURDES CORONILLA | CARTON NACIONAL | $1.70 | 7,019.50 | $1.6335 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| MANUEL ORTIZ | CARTON NACIONAL | $1.70 | 46,303.00 | $1.6528 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| MANUEL ORTIZ | CARTON RECOGIDO | $1.30 / $1.40 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | N/D; conciliar tarifa | N/D |
| MANUEL ORTIZ | CHATARRA MIXTA | $3.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $3.70 (sin cambio) | N/D |
| MANUEL VILLAFUERTE | CARTON AMERICANO | $2.20 | 1,315.00 | $2.2000 | Mantener — Conservar acuerdo vigente; sin alza general | $2.20 (sin cambio) | $0.00 |
| MANUEL VILLAFUERTE | CARTON NACIONAL | $1.80 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.80 (sin cambio) | N/D |
| MARION SALINAS LLAMAS | CARTON NACIONAL | $1.70 | 306.00 | $1.6000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| MARTELL | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| MARTIN ZATARAIN | CARTON AMERICANO | $2.00 | 340.00 | $2.0000 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $2.00 (sin cambio) | $0.00 |
| MIGUEL AYALA | CHATARRA MIXTA | $3.55 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $3.55 (sin cambio) | N/D |
| MIGUEL MUÑOS | CHATARRA | $1.50 | 2,655.00 | $1.5000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $1.50 (sin cambio) | $0.00 |
| MIGUEL MUÑOZ | POLI CARTON | $1.00 | 2,436.50 | $1.0000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $1.00 (sin cambio) | $0.00 |
| MIGUEL QUINTANA | CARTON AMERICANO | $2.40 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.40 (sin cambio) | N/D |
| MIGUEL QUINTANA | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| MIGUEL SANCHEZ | CARTON NACIONAL | $1.60 | 94,570.75 | $1.5000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $9,457.08/mes | $1.60 (sin cambio) | $0.00 |
| MILENIO | CARTON NACIONAL | $2.00 | 6,859.50 | $2.0000 | Revisar calidad — Tarifa rebasa banda preferente | $2.00 (sin cambio) | $0.00 |
| OSCAR FRIAS | CARTON AMERICANO | $2.10 | 1,855.00 | $2.1000 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $2.10 (sin cambio) | $0.00 |
| OSCAR FRIAS | CARTON NACIONAL | $1.70 | 4,648.25 | $1.6000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| PACO CERVANTES | CHATARRA | $28.00 | 0.00 | N/D | Revisar calidad — Sólo venta en agosto; el catálogo de compra no acredita abastecimiento | $28.00 (sin cambio) | N/D |
| PPT | CARTON NACIONAL | $1.50 | 19,542.50 | $1.4000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $1,954.25/mes | $1.50 (sin cambio) | $0.00 |
| PUBLICO GENERAL | CARTON AMERICANO | $1.60 | 658.00 | $1.6000 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $1.60 (sin cambio) | $0.00 |
| PUBLICO GENERAL | CARTON NACIONAL | $1.40 | 53,684.55 | $1.4258 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $5,368.46/mes | $1.40 (sin cambio) | $0.00 |
| PUBLICO GENERAL | CHATARRA MIXTA | $4.00 | 1,850.80 | $4.0000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $4.00 (sin cambio) | $0.00 |
| RAUL LEDEZMA | CARTON AMERICANO | $2.10 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.10 (sin cambio) | N/D |
| RAUL LEDEZMA | CARTON NACIONAL | $1.50 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.50 (sin cambio) | N/D |
| RAUL MENDOZA | CARTON AMERICANO | $2.20 | 34,945.00 | $2.1603 | Mantener — Conservar acuerdo vigente; sin alza general | $2.20 (sin cambio) | $0.00 |
| RAUL MENDOZA | CARTON NACIONAL | $1.60 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.60 (sin cambio) | N/D |
| REAUT | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| RITA | CARTON NACIONAL | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| ROSA MARIA PATIÑO | CARTON NACIONAL | $1.70 | 590.00 | $1.6000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| SALVADOR GONZALES | CARTON AMERICANO | $2.10 | 14,080.00 | $2.1000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $1,408.00/mes | $2.10 (sin cambio) | $0.00 |
| SALVADOR GONZALES | CARTON NACIONAL | $1.70 | 1,335.00 | $1.6000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| SALVADOR SANCHEZ | CARTON NACIONAL | $1.80 | 4,775.00 | $1.6994 | Revisar calidad — Tarifa rebasa banda preferente | $1.80 (sin cambio) | $0.00 |
| SAUL RODRIGUEZ | CARTON AMERICANO | $1.90 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.90 (sin cambio) | N/D |
| SAUL RODRIGUEZ | CARTON NACIONAL | $1.40 | 1,270.00 | $1.4000 | Mantener — Recurrencia insuficiente en agosto para prima preferente | $1.40 (sin cambio) | $0.00 |
| SEAH | CARTON RECOGIDO | $0.60 | 1,370.00 | $0.6000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $0.60 (sin cambio) | $0.00 |
| SEAH | CHATARRA MIXTA | $2.80 | 980.00 | $2.8000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $2.80 (sin cambio) | $0.00 |
| TRICICLOS | CARTON AMERICANO | $2.20 | 115.00 | $2.2000 | Mantener — Conservar acuerdo vigente; sin alza general | $2.20 (sin cambio) | $0.00 |
| TRICICLOS | CARTON NACIONAL | $1.50 | 30,554.35 | $1.4837 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $3,055.44/mes | $1.50 (sin cambio) | $0.00 |
| VICTOR ALCALA | CARTON NACIONAL | $1.70 | 43,980.00 | $1.6310 | Mantener — Conservar acuerdo vigente; sin alza general | $1.70 (sin cambio) | $0.00 |
| VICTOR ALCALA | CARTON RECOGIDO | $1.40 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.40 (sin cambio) | N/D |
| VICTOR ALCALA | CHATARRA MIXTA | $4.20 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $4.20 (sin cambio) | N/D |
| VICTOR GARCIA | CARTON NACIONAL | $1.70 | 6,720.00 | $1.5500 | Revisar calidad — Ticket 84338 también registrado en Compras Mayoreo | $1.70 (sin cambio) | $0.00 |
| VICTOR GARCIA | CHATARRA MIXTA | $4.10 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $4.10 (sin cambio) | N/D |

### Compras Mayoreo

| Proveedor | Material | Tarifa actual | Kg agosto | Compra ponderada | Acción recomendada | Nueva tarifa sugerida | Impacto mensual estimado |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AVON | CHATARRA | $2.80 | 925.00 | $2.8000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $2.80 (sin cambio) | $0.00 |
| AVON | CORRUGADO CARTON | $1.20 | 114,125.00 | $1.2000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.20 (sin cambio) | $0.00 |
| DECASA | CARTON | $1.10 | 33,545.00 | $1.1000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $3,354.50/mes | $1.10 (sin cambio) | $0.00 |
| KS | CARTON | $1.00 | 14,870.00 | $1.0000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $1,487.00/mes | $1.00 (sin cambio) | $0.00 |
| KS | CHATARRA GENERAL | $3.34 | 6,990.00 | $3.3400 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $3.34 (sin cambio) | $0.00 |
| KS | CINTAS SIERRA | $132.00 | 25.00 | $132.0000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $132.00 (sin cambio) | $0.00 |
| KS | REBABA | $3.01 | 43,880.00 | $3.0100 | Mantener — Conservar acuerdo vigente; sin alza general | $3.01 (sin cambio) | $0.00 |
| LICBOX | CARTON | $1.40 | 75,820.00 | $1.4000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.40 (sin cambio) | $0.00 |
| MIGAVID | CHATARRA | $2.75 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.75 (sin cambio) | N/D |
| MIGAVID | REBABA | $2.55 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.55 (sin cambio) | N/D |
| MIGUEL SANCHEZ | CARTON | $1.70 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.70 (sin cambio) | N/D |
| MONROE | CARTON | $1.40 | 42,440.00 | $1.4000 | Mantener — Conservar acuerdo vigente; sin alza general | $1.40 (sin cambio) | $0.00 |
| MONROE | REBABA | $2.20 | 16,720.00 | $2.2000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $1,672.00/mes | $2.20 (sin cambio) | $0.00 |
| PLASTICOS DE INGENIERIA MEXICANOS | CARTON | $1.35 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.35 (sin cambio) | N/D |
| RDC WHIRLPOOL | CARTON | $0.30 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $0.30 (sin cambio) | N/D |
| RDC WHIRLPOOL | CHATARRA | $2.50 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $2.50 (sin cambio) | N/D |
| RECICLA METAL | CARTON RECOGIDO | $1.60 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $1.60 (sin cambio) | N/D |
| ROCIO CARVAJAL | CARTON | $1.50 | 42,970.25 | $1.5000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $1.50 (sin cambio) | $0.00 |
| RODOLFO VERA | CARTON RECOGIDO | $1.50 | 17,884.00 | $1.4648 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $1.50 (sin cambio) | $0.00 |
| RODOLFO VERA | CHATARRA | $4.20 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $4.20 (sin cambio) | N/D |
| SETEXMES | CARTON | $0.90 | 11,105.00 | $0.9000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $1,110.50/mes | $0.90 (sin cambio) | $0.00 |
| SETEXMES | CHATARRA | $2.30 | 3,325.00 | $2.3000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $2.30 (sin cambio) | $0.00 |
| TENNECO | CHATARRA | $3.27 | 78,270.00 | $3.2700 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $3.27 (sin cambio) | $0.00 |
| TRUPER | CARTON | $1.00 | 27,255.00 | $1.0000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $2,725.50/mes | $1.00 (sin cambio) | $0.00 |
| VICTOR GARCIA | CARTON STROKPACK | $1.30 | 6,720.00 | $1.5000 | Revisar calidad — Calidad, unidad o rendimiento pendiente; sin alza | $1.30 (sin cambio) | $0.00 |
| WHIRLPOOL | CARTON | $0.40 | 76,930.00 | $0.4000 | No subir por alto impacto — Siguiente escalón +$0.10/kg costaría $7,693.00/mes | $0.40 (sin cambio) | $0.00 |
| YOROZU | CARTON | $0.50 | 0.00 | N/D | Reactivar — Sin compras de este material en agosto; validar interés y calidad antes de oferta | $0.50 (sin cambio) | N/D |

Los candidatos sin compras de agosto aparecen para reactivación o revisión, sin inferir kilos de otros meses. Las dos líneas activas de JUAN ESTRADA/CARTON NACIONAL coinciden en $1.90; se muestra una sola tarifa por proveedor-material. MANUEL ORTIZ/CARTON RECOGIDO tiene líneas de $1.30 y $1.40; no se elige una arbitrariamente. CLISMAN/CARTONRECOGIDO no tiene una línea activa equivalente identificada y su ponderado $1.10 no se presenta como tarifa vigente.

## 6. Tres decisiones concretas para Gerencia

1. **Separar formalmente las bandas de cartón.** Adoptar como referencias de nuevas compras nacional $1.60 estándar/$1.70 preferente y americano $2.10/$2.20; para limpio industrial, negociar alrededor de $1.20 y conservar contratos justificados hasta $1.40. Negociar ventas objetivo de $2.40, $3.60 y $2.70, respectivamente. Revisar nacional por encima de $1.70 antes de cualquier alza: a $2.20 de compra, el precio ponderado confirmado sólo deja $0.0802/kg antes de costos.
2. **Limitar las alzas a los 4 casos cuantificados.** FRANCISCO CHIMAL (CARTON AMERICANO): $2.10 → $2.20, +$883.75/mes; CASOIS (CARTON NACIONAL): $1.60 → $1.70, +$190.60/mes; FRANCISCO CHIMAL (CARTON NACIONAL): $1.60 → $1.70, +$128.25/mes; JESUS PATIÑO (CARTON NACIONAL): $1.60 → $1.70, +$565.50/mes. Tope conjunto estimado: **$1,768.10/mes** a kilos constantes. Mantener sin alza los casos de alto impacto y validar calidad antes de otorgar la prima.
3. **Congelar alzas de chatarra de entrada y conciliar la trazabilidad.** Exigir peso de entrada independiente y vínculo a lotes por corrida; separar compra directa de rebaba y CHATARRA/MOTOR; confirmar LAMINA frente a PLACA; conciliar las tres diferencias de El Palomar y el ticket 84338. Con esa base, recalcular VR y costo operativo/kg para decidir la compra rentable. Las referencias comerciales de salidas pueden usarse para negociar, pero no para prometer margen de la entrada.

## 7. Riesgos y datos faltantes

### Diferencias de El Palomar

| Ticket | Dato Ventas Mayoreo usado | Dato auxiliar El Palomar | Diferencia auxiliar − reporte |
| --- | --- | --- | --- |
| 624 | 29,540 kg × $2.50 = $73,850.00 | 29,540 kg × $2.70 = $79,758.00 | +$5,908.00 |
| 625 | 30,046 kg × $2.50 = $75,115.00 | 30,046 kg × $2.70 = $81,124.20 | +$6,009.20 |
| 659 — REBABA | 20,930 kg × $4.70 = $98,371.00 | 20,870 kg × $4.70 = $98,089.00 | −60 kg; −$282.00 |

Las **16 remisiones aplicadas** de la cuenta auxiliar tienen `source_report_id` encontrado en Ventas Mayoreo: se cuentan una sola vez desde el reporte de ventas. Las otras 14 filas auxiliares son cheques o ajustes; no son toneladas vendidas. Las diferencias suman **$11,635.20** netos en la cuenta auxiliar; no se corrigen ni se sustituyen valores en este análisis.

### Otros controles y pendientes

- **Posible solapamiento entre compras:** Víctor García, ticket **84338**, 27 de agosto: Menudeo registra 3,360 kg de nacional y $5,040; Compras Mayoreo registra 6,720 kg de STROKPACK y $10,080. Se conservan como registros de sus canales, se aísla STROKPACK y no se construye un total combinado de costo de cartón. Falta determinar si son lotes distintos o doble registro. No se elimina ninguno sin evidencia.
- **Folios repetidos KS:** un mismo folio puede contener varios materiales y pesos distintos. Se verificó unicidad por ID; no se deduplican por número de ticket solamente. La recurrencia comercial propuesta se basa en tickets registrados y no demuestra elasticidad del proveedor.
- **Aprobaciones:** las 50 ventas del alcance CARTÓN/CHATARRA tienen kilos e importe aprobados positivos. No se reemplazó una aprobación faltante por peso de salida ni se usaron tickets de otro mes. Ventas fuera de alcance: 7 registros de servicios, papel, caple o metal.
- **Calidad no resuelta:** Queretana Carrillo CARTON RECOGIDO, cartones de personas sin origen industrial acreditado y POLI CARTON no se homologan por intuición. Los porcentajes de humedad y basura registrados no son un rendimiento de transformación.
- **Inventarios:** compras, transformaciones y ventas de agosto no corresponden necesariamente a los mismos lotes. Que se venda más de un material que lo producido o comprado ese mes puede provenir de inventario inicial; sin conciliación por lote no se declara merma negativa ni ganancia real.
- **Rendimiento:** se verificaron individualmente las 19 corridas de chatarra y ninguna supera 100%; se sumaron las entradas antes de expandir salidas. El problema encontrado es de medición y procedencia, no un sobre-rendimiento aritmético. Si una revisión detecta salida mayor que entrada, esa corrida debe excluirse de recomendaciones hasta conciliarse.
- **Tarifas vs pago histórico:** precios actuales pueden diferir de los que rigieron al inicio de agosto. Las tarifas actuales no se usan para reconstruir importes históricos. Ejemplos: Antonio Morales/americano ya está en $2.30, Raúl Mendoza y José Luis Muñis/americano ya están en $2.20; no se repite la propuesta antigua de subirlos a esos niveles.
- **Costos faltantes:** flete por proveedor/cliente, maniobra, consumo de proceso, rendimiento medido, inventario inicial/final y asignación de gastos fijos. No se inventó un costo fijo por kg ni un rendimiento estándar para llenar los huecos.

## 8. Utilidad referencial frente a utilidad real

La diferencia entre venta ponderada y compra ponderada es **utilidad bruta referencial de precios**: compara dos flujos del mismo mes y calidad, sin demostrar que sean el mismo inventario. No debe multiplicarse indiscriminadamente por todos los kilos comprados ni sumarse entre las filas que reutilizan una referencia de costo.

La utilidad bruta contable requiere costo del lote efectivamente vendido e inventarios conciliados. De ese resultado deben descontarse los costos que correspondan de flete, merma no absorbida ya en el costo, maniobra y proceso; después, los gastos fijos y demás gastos operativos para obtener utilidad operativa. La utilidad neta requeriría además resultados financieros e impuestos. No se debe descontar dos veces una merma o flete ya incorporado al costo.

Por tanto, los márgenes de 29.47%, 39.37%, 59.67% y 40.71% **no son márgenes netos**. Las recomendaciones son límites comerciales provisionales para revisión gerencial, con mayor restricción en nacional y suspensión de nuevas alzas en chatarra de entrada hasta medir su recuperación real.

## 9. Anexo de conciliación y reproducibilidad

Los siguientes totales permiten reproducir cada ponderado como importe dividido entre kilos, sin promediar tickets. Las partidas pendientes no se suman a una calidad confirmada.

| Canal | Dirección | Material/calidad | Registros | Kg | Importe total |
| --- | --- | --- | --- | --- | --- |
| Compras Mayoreo | purchase | CARTON RECOGIDO [calidad pendiente] | 3 | 17,884.00 | $26,196.6000 |
| Compras Mayoreo | purchase | CARTON STROKPACK [calidad pendiente] | 1 | 6,720.00 | $10,080.0000 |
| Compras Mayoreo | purchase | CARTON [calidad pendiente] | 7 | 42,970.25 | $64,455.3800 |
| Compras Mayoreo | purchase | CHATARRA | 27 | 82,520.00 | $266,180.4000 |
| Compras Mayoreo | purchase | CHATARRA GENERAL | 4 | 6,990.00 | $23,346.6000 |
| Compras Mayoreo | purchase | CINTAS SIERRA | 2 | 25.00 | $3,300.0000 |
| Compras Mayoreo | purchase | Cartón limpio | 199 | 396,090.00 | $422,305.0000 |
| Compras Mayoreo | purchase | REBABA | 29 | 60,600.00 | $168,862.8000 |
| Menudeo | purchase | CARTON RECOGIDO [calidad pendiente] | 2 | 3,230.00 | $3,798.0000 |
| Menudeo | purchase | CARTONRECOGIDO [calidad pendiente] | 1 | 685.00 | $753.5000 |
| Menudeo | purchase | CHATARRA | 1 | 2,655.00 | $3,982.5000 |
| Menudeo | purchase | CHATARRA MIXTA | 41 | 2,830.80 | $10,147.2000 |
| Menudeo | purchase | Cartón americano | 118 | 218,000.74 | $470,781.8520 |
| Menudeo | purchase | Cartón nacional | 803 | 495,251.40 | $796,468.5750 |
| Menudeo | purchase | POLI CARTON [calidad pendiente] | 3 | 2,436.50 | $2,436.5000 |
| Menudeo | sale | CHATARRA | 1 | 20.00 | $560.0000 |
| Menudeo | sale | CHATARRA MIXTA | 20 | 3,707.20 | $54,671.6000 |
| Menudeo | sale | CHATARRA/MOTOR | 1 | 555.00 | $15,540.0000 |
| Menudeo | sale | Cartón nacional | 25 | 10,619.20 | $47,114.0800 |
| Menudeo | sale | LAMINA | 6 | 1,765.00 | $20,210.0000 |
| Menudeo | sale | RACKS | 1 | 4,356.67 | $39,209.9940 |
| Ventas Mayoreo | sale | CARTON RECOGIDO [calidad pendiente] | 4 | 109,040.00 | $261,696.0000 |
| Ventas Mayoreo | sale | Cartón americano | 5 | 143,719.00 | $511,869.2000 |
| Ventas Mayoreo | sale | Cartón limpio | 7 | 210,935.00 | $557,607.3000 |
| Ventas Mayoreo | sale | Cartón nacional | 23 | 714,639.00 | $1,629,498.4000 |
| Ventas Mayoreo | sale | MIXTO | 1 | 5,490.00 | $27,450.0000 |
| Ventas Mayoreo | sale | PESADO | 3 | 70,115.00 | $357,586.5000 |
| Ventas Mayoreo | sale | PLACA Y ESTRUCTURA | 2 | 26,375.00 | $137,150.0000 |
| Ventas Mayoreo | sale | REBABA | 1 | 20,930.00 | $98,371.0000 |
| Ventas Mayoreo | sale | RETORNO INDUSTRIAL | 4 | 73,740.00 | $431,320.0000 |

### Corridas de chatarra verificadas

| Fecha | ID corrida | Salida | Entrada kg | Salida kg | Rendimiento registrado |
| --- | --- | --- | --- | --- | --- |
| 2026-08-04 | 54442fa4-282b-4c91-91bc-d35e04812972 | PESADO | 20,760.00 | 20,760.00 | 100.00% |
| 2026-08-04 | c1f6d96d-a7fe-4429-92e4-016c1462260e | MIXTO | 400.00 | 400.00 | 100.00% |
| 2026-08-04 | ea4354b7-ab82-4afc-a806-bc399fe31df5 | CHATARRA/MOTOR | 555.00 | 555.00 | 100.00% |
| 2026-08-05 | b792844a-55c6-43b8-922c-8e6f5c168fbb | LAMINA | 10,315.00 | 10,315.00 | 100.00% |
| 2026-08-05 | d238cb7e-7ffe-4c6b-aa2b-a18607d66d54 | PESADO | 24,455.00 | 24,455.00 | 100.00% |
| 2026-08-07 | 1a0f6bbd-8353-41f4-92ed-d2a3bed2abbb | CHATARRA | 5.40 | 5.40 | 100.00% |
| 2026-08-07 | 40ad47ad-6cd5-4097-8ea1-80dd5e8e1a3d | CHATARRA | 1.00 | 1.00 | 100.00% |
| 2026-08-10 | d3e15a7c-f456-4df7-b0a1-e09822d8e754 | CHATARRA | 5.40 | 5.40 | 100.00% |
| 2026-08-12 | ca1784d7-d163-4b5f-97e1-5a56de68930c | CHATARRA | 580.00 | 580.00 | 100.00% |
| 2026-08-12 | d88167d4-5f2e-4b71-b7db-d9ebd6e5c57c | CHATARRA | 90.60 | 90.60 | 100.00% |
| 2026-08-13 | 01d68443-2b02-468c-891d-53076b7be4c0 | CHATARRA | 1.00 | 1.00 | 100.00% |
| 2026-08-13 | 1bbb8cbe-b6db-425b-87a9-e9bd268ae898 | CHATARRA | 1,170.00 | 1,170.00 | 100.00% |
| 2026-08-14 | a478ce31-fd86-4396-b3d5-191828af02f2 | CHATARRA | 315.00 | 315.00 | 100.00% |
| 2026-08-21 | d99a619c-1fe5-4af0-938d-4323b6606248 | CHATARRA | 17,450.00 | 17,450.00 | 100.00% |
| 2026-08-24 | 10e0c9db-b008-454c-bd43-58f4307cdd8e | RACKS | 6,990.00 | 6,990.00 | 100.00% |
| 2026-08-24 | 4e25f1fa-907d-4f3f-a922-4822e6a373fa | REBABA | 20,930.00 | 20,930.00 | 100.00% |
| 2026-08-25 | 4997a1f0-f2c2-4111-8198-3d437aac5965 | CHATARRA | 30.60 | 30.60 | 100.00% |
| 2026-08-26 | ce56136a-71e6-446d-9301-1d5e686e2c34 | PESADO | 22,765.00 | 22,765.00 | 100.00% |
| 2026-08-27 | 960427b7-a86e-4325-9ef9-9b425a446b94 | RETORNO INDUSTRIAL | 14,570.00 | 14,570.00 | 100.00% |

Las fuentes JSON, su manifiesto SHA-256, las filas normalizadas y los scripts de cálculo se conservan en [work/reporte_precios_agosto_2026](../../../../work/reporte_precios_agosto_2026). No contienen credenciales. El manifiesto registra hora de extracción, filtros, conteos exactos y hashes. Se usaron IDs únicos, suma decimal y comprobaciones de intervalo, aprobación, importes y balance por corrida. Los datos de trabajo son copias locales de lectura; la fuente operativa quedó intacta.

