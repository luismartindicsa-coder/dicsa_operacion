# Auditoría crítica de Rentabilidad operativa

La pantalla sirve para explorar la operación, pero su resultado por empresa todavía no es suficientemente confiable para decidir una salida. Hay repartos que conservan el dinero total pero lo atribuyen de forma poco representativa, y errores reproducibles que cambian el propio total. Esta revisión no modifica datos, tarifas, reglas ni código de producción. El alcance solicitado de Compras Mayoreo queda pendiente de implementar después de esta revisión.

**Evidencia y límites.** Revisión de motor documental, motor operativo, inferencias, fuentes, nómina, materiales, pantalla principal y consolidado. Consulta autenticada de solo lectura del 22/09/2026 a las 16:05, periodo 01–22/09/2026. Evidencia temporal: `/private/tmp/dicsa_profit_audit_current.json`. El resultado puede cambiar con nuevos registros. Las cifras siguientes describen el modelo actual; no certifican el resultado real de DICSA. No hay reglas maestras ni ajustes manuales guardados en la lectura auditada.

| Medida del modelo actual | Importe / cantidad |
|---|---:|
| Cuentas operativas | 75 |
| Generación estimada: material + servicios | $4,146,334.71 |
| Costos atribuidos | $4,193,379.56 |
| Aporte calculado | -$47,044.85 |
| Cuentas negativas después de soporte | 58 |
| Cuentas negativas antes del soporte marcado como compartido | 9 |
| Cuentas que pasan a negativo al añadir dicho soporte | 49 |
| Soporte compartido total | $1,267,090.80 |
| RH dentro del soporte compartido | $402,070.13 |
| Otros gastos repartidos por igual entre cuentas | $865,020.67 |

Quitar el soporte no demuestra que las cuentas sean rentables: el gasto sigue existiendo. Sí demuestra que gran parte del color rojo depende de la política de reparto.

## Hallazgos con datos reales

### 1. El reparto uniforme sigue siendo material

En `profitability_inference.dart:787` administración, otros y capacitación conservan peso 1 por cuenta. La nueva proporción de nómina no sustituyó ese reparto financiero.

Se distribuyen $865,020.67 entre 75 cuentas: $11,533.61 por cuenta, antes de sumar su RH compartido proporcional. Representa aproximadamente 20.63% de todos los costos del modelo. OSCAR LARA, con 34 kg y cero viajes, recibe esa misma cantidad que LICBOX, con 97,710 kg y cuatro servicios. Esa igualdad no demuestra el esfuerzo real de atención de cada cuenta.

El IMSS reconocido en el corte, $232,282.51, también se divide entre 75 cuentas. No sigue la nómina dedicada ni la compartida que origina la carga. La cifra proviene de un pago de $316,748.88 del 17/09 con descripción «IMSS SEPTIEMBRE», multiplicado por 22/30. Falta validar periodo cubierto y composición del pago antes de tratarlo como carga laboral de septiembre.

**Cambio recomendado:** separar remuneraciones, cargas laborales, administración recurrente, gastos extraordinarios y capacidad ociosa. Las cargas laborales deben acompañar a la nómina correspondiente cuando haya evidencia; los gastos generales requieren una base explícita y un subtotal independiente. No repartir a partes iguales por defecto solo porque no se identificó la causa.

### 2. Se mezclan centros de costo y fechas de pago

Los hechos bancarios y las facturas manuales se crean sin identidad de empresa operativa (`profitability_engine.dart:436` y `:458`). Se leen `company`, `branch`, `target_company` y `target_branch`, pero no se usan para delimitar las bolsas automáticas.

En los componentes realmente reconocidos se incluyen movimientos bancarios de VH/Mazatlán por $82,733.20 y DICSA/Mazatlán por $30,906.92, además de Celaya. No se ha demostrado que sean costos de las cuentas evaluadas. Tampoco se concluye que deban excluirse todos: falta definir el alcance económico y las relaciones entre centros.

Ejemplo concreto: $77,925 de CFE, pagados el 11/09, empresa VH y sucursal Mazatlán. La factura vinculada describe «31 JUL–31 AGO». Se incorpora íntegro como proceso en septiembre y se reparte por kg de las cuentas. El modelo no distingue ese consumo de un gasto generado en septiembre.

El tratamiento de pagos/facturas evita algunos duplicados mediante vínculos, pero cambia de consumo documentado a dinero pagado cuando existe un pago. No hay conciliación universal entre bancos, bóveda, caja, factura, compra de mantenimiento y OT. No se certifica ausencia de duplicados sin vínculos; tampoco se afirma un importe duplicado adicional no comprobado.

**Cambio recomendado:** reconocer cada consumo una sola vez, con centro, naturaleza y cobertura operativa; vincular pagos como liquidaciones. Gastos de otro centro, inventario de refacciones, finiquitos y remodelaciones necesitan tratamiento propio. Es necesario incluso para un análisis operativo, porque fecha de desembolso y costo de atender el periodo son distintos.

### 3. La nómina proporcional mejora la aproximación, pero no completa la clasificación

RH conserva $649,082.39: $247,012.26 dedicados y $402,070.13 compartidos. De estos últimos, $118,979.44 se atribuyen a transporte y $283,090.69 a patio/soporte.

Los choferes se infieren por coincidencia única de nombres entre dos catálogos. El resto del personal común no está clasificado entre administración, patio, mantenimiento, supervisión y otras funciones. Se reparte conjuntamente con 50% de peso de kg y 50% de movimientos. No son tiempos observados ni una proporción calibrada.

Las cuentas sin viajes reciben cero de los choferes identificados cuando existen viajes en el corte; este comportamiento funciona en la lectura auditada. No permite asegurar que todo el costo de transporte esté identificado: los choferes sin coincidencia quedan en el resto del personal. Si todo el corte carece de viajes, el algoritmo vuelve a repartir esa capacidad por kg/movimientos.

Los movimientos son documentos de compra/entrada + servicios + documentos de venta de servicio. No se concilian a una actividad física única, por lo que un mismo servicio puede aumentar la base por aparecer en varios documentos. Los porcentajes usan toda la actividad del periodo, incluso para repartir nómina día a día; la suma por empresa de subperiodos puede diferir del periodo completo.

**Cambio recomendado:** función laboral y centro explícitos, identidad estable de empleado, personal dedicado primero y bolsas compartidas por actividad pertinente. Transporte por tiempo de ruta/servicio y km; patio por toneladas realmente recibidas/procesadas y maniobras; administración por actividad comercial/gestiones. Mantener inferencias proporcionales donde falte detalle, con sensibilidad y trazabilidad. La capacidad no utilizada debe quedar visible, sin convertirla automáticamente en consumo de entregas directas.

### 4. Combustible y mantenimiento no siguen correctamente unidad y uso

En `profitability_inference.dart:935`, para cada carga se identifican cuentas que utilizaron la unidad, pero la proporción posterior usa `w.km`: todos los km de cada cuenta, incluidas otras unidades y fechas. Una empresa que trabaja mucho con otro camión puede absorber combustible del primero sin haberlo consumido.

De 324 servicios completados en la lectura, 177 tienen registro de kilometraje de la misma unidad/día y 147 no. Además, los km medidos por unidad/día se dividen por número de servicios; no se dispone ahí de distancia por ruta individual. Para faltantes se usan promedios de flota o rutas MONROE.

Diésel y gasolina comparten el precio inferido o el respaldo de $23.67/L. Las cargas sin unidad asociable se reparten por flota. Cuando hay algún componente de combustible en una cuenta, puede suprimirse el respaldo para viajes no cubiertos. Una compra de combustible y una carga tampoco prueban por sí solas el consumo del mismo periodo.

Mantenimiento sin planta directa se reparte globalmente por km. Esto incluye órdenes y compras cuyo equipo o destino es almacén, montacargas o ropa de trabajo, aunque estén disponibles esas referencias. Ejemplo: una compra por $5,200 con descripción «CAMISOLAS CHALECOS» se distribuye como mantenimiento por km.

**Cambio recomendado:** unidad → intervalo de uso → ruta/servicio → empresa. Separar combustible y mantenimiento de transporte, patio y equipos dedicados; distinguir compra de refacciones para almacén de consumo. Para rutas compartidas, asignar distancia y tiempo de forma explícita y conservar la parte no atribuida.

### 5. El valor generado y parte de la compra dependen fuertemente de inferencias

El modelo valora material por $4,067,943.03. De él, $1,829,103.48 se calcula por mezcla de ventas de una familia y $28,963.96 usa compra = valor de venta por falta de comparable. El resto usa coincidencias de nombre/calidad, que tampoco prueban por sí solas destino, transformación ni recuperación. La equivalencia americano → Celanese confirmada se conserva.

Se supone recuperación 100% salvo regla explícita. El precio se obtiene de ventas actuales por material y, si faltan, del historial de 90 días. En una comparación por familia pueden convivir precios actuales e históricos. No se calibra el rendimiento ni la combinación real de productos obtenidos por origen.

La conciliación física agrega el exceso de entradas sobre compras por planta/familia (`profitability_material_basis.dart:167`). Es mejor que sumar ambas fuentes, pero el máximo no prueba que el excedente sea una nueva compra: puede haber desfases, identidades pendientes o material recibido sin compra. Hay $532,675.31 de compra inferida, 23.79% de toda la compra atribuida, y $1,081,700.00 de valor ligado a entradas residuales.

Como sensibilidad aritmética, variar 5% el bloque completo de valor material mueve el resultado $203,397.15, frente a una pérdida modelada de $47,044.85. No se afirma que ese sea el error real ni un intervalo estadístico: muestra que el signo global no es robusto frente a cambios pequeños de una base dominante.

**Cambio recomendado:** conciliar documentos y kilos físicos por origen; separar kg comprados, recibidos, procesados y recuperables. Rendimientos y comparables por material/destino con vigencia, ventana y confianza explícitas. Mantener estimación central y escenarios. Un precio faltante debe ser una incertidumbre cuantificada, no una supuesta igualdad entre compra y venta.

### 6. Referencias antiguas y ceros no prueban cobertura completa

El motor contiene referencias MONROE para combustible, rutas, renta, disposición, báscula y capacitación. Algunas se aplican a otras cuentas: contenedores a $31,780/8 al mes, disposición a $707.60/t y báscula a $100/servicio. Que fueran válidas para el documento no acredita aplicabilidad actual a todas las empresas. Las referencias monetarias/temporales deben tener vigencia y alcance, además de fuente.

Cuando falta un bloque se añade un componente cero (`profitability_inference.dart:1437`). La explicación reconoce que es una base inferida, pero los totales y semáforos operan como si ese cero completara el costo. El porcentaje de estimación excluye los repartos clasificados como `allocated`; no representa exactitud de atribución. OSCAR LARA muestra aproximadamente 1.7% estimado aunque absorbe miles de pesos por reparto uniforme. La confianza 0.85 de un reparto es un valor fijo del programa, no una validación.

**Cambio recomendado:** distinguir cero por actividad ausente, cero confirmado y costo pendiente de estimar. Cuantificar faltantes mediante rango y supuesto rastreable, manteniendo visible la incertidumbre. Separar calidad del importe fuente de calidad de su asignación.

### 7. El alcance empresarial y el consolidado requieren límites explícitos

Las 75 cuentas provienen de varios catálogos; Compras Mayoreo tiene 48 registros en esta lectura. Hay alias que un filtro literal rompería: SETEX frente a SETEXMES; MONROE y MONROE SUR frente al catálogo MONROE; GKN frente a varias plantas del catálogo. No se debe afirmar que nombres parecidos sean iguales sin validación.

**Cambio recomendado:** catálogo de Compras Mayoreo como identidad maestra, con sus plantas y alias confirmados. Mostrar solamente ese alcance, manteniendo la parte de Menudeo y otras actividades en la conciliación de costos del conjunto. Ocultarlas no autoriza pasar sus costos a las empresas restantes. El subtotal de ese catálogo no debe presentarse como resultado de «toda DICSA».

La simulación de salida conserva por defecto nómina, soporte, mantenimiento, proceso y equipo: ese principio es correcto. Pero presupone ahorro total en compra, combustible, transporte, disposición y báscula. Requiere comprobar qué costo desaparece efectivamente y cuánto tiempo tarda. No modela rutas compartidas, contratos mínimos, continuidad del material ni capacidad de reemplazo. Sus operaciones aritméticas pueden cuadrar y su recomendación seguir dependiendo de bases equivocadas.

## Errores reproducidos con datos sintéticos

Se ejecutaron 39 pruebas existentes de cuentas, reparto RH y consolidado; pasaron. Cinco sondas temporales adicionales confirmaron los comportamientos siguientes. Las sondas verificaban la reproducción de la anomalía, no la corrección económica. Se retiraron después de la auditoría, sin cambiar producción.

| Caso controlado | Resultado observado | Implicación |
|---|---|---|
| Dos empresas usan 50 km cada una de U1; 100 L a $23.67. A utiliza además 900 km de U2. | Combustible U1 atribuido a A pasa de $1,183.50 a $2,248.65. | Otra unidad altera indebidamente el reparto de U1. |
| Historia administrativa de $9,000 en 90 días, corte de siete días. Se registra $1 actual. | La estimación de $700 se sustituye por $1. | Un documento actual suprime toda la bolsa histórica, aunque no cubra los mismos conceptos. |
| Renta de $3,000 mensuales, documentada el día 12. | Días 1–22: $2,200. Días 1–11: $0. Días 12–22: $1,100. | Los subperiodos suman $1,100 y el conjunto $2,200. La cobertura depende del filtro. |
| MONROE tiene cinco servicios a $5,800 y se registra la venta de uno. | Ingreso de $29,000 pasa a $5,800. | La presencia de una venta suprime la estimación de los otros servicios sin conciliarlos. |
| Factura de consumo de $1,000 con pago parcial de $200. | Costo de $1,000 pasa a $200. | El pago parcial sustituye al costo completo documentado. No se halló diferencia equivalente en los pagos vinculados actuales revisados. |

Localización: combustible `profitability_inference.dart:935`; historia `:973`; mensualidad `:993`; servicios `:1277`; pagos/facturas `:729`.

## Qué conservar y qué hacer primero

Conservar integración de áreas, procedencia de componentes, personal dedicado, separación valor/servicio/compra, exclusión de retiros de nómina confirmados, vistas por empresa/periodo y principio de costos que permanecen tras una salida. La trazabilidad disponible permite corregir el motor sin rehacer toda la app.

Orden propuesto:

1. Corregir los cinco errores reproducidos y añadir pruebas que exijan conservación por concepto, cobertura y periodo. Cada consumo debe reconocerse una vez; agregar evidencia parcial solo sustituye la porción que cubre.
2. Delimitar centros de costo y reconocer el periodo operativo. Conciliar la bolsa original con lo atribuido, lo estimado, otras operaciones, estructura y exclusiones justificadas.
3. Definir identidad maestra de Compras Mayoreo y relaciones de plantas. Aplicar alcance sin redistribuir arbitrariamente costos ajenos.
4. Separar bolsas laborales, cargas patronales, proceso, equipos y administración; calibrar bases con actividad observada. Mostrar la capacidad ociosa.
5. Validar kilos, compras residuales, calidades, rendimientos, servicios realizados/facturados y precios comparables.
6. Mostrar tres lecturas: aporte después de costos directos e incrementales; resultado tras soporte/estructura; cambio real estimado si se sale. Los costos evitables deben tener horizonte y evidencia propios.
7. Incorporar escenario conservador/base/favorable y alertar cuando el signo cambie. Permitir decisiones fuertes solo cuando sean robustas frente a las bases inciertas.

La pantalla puede seguir siendo sencilla: empresa, valor recuperable estimado, costo directo, soporte asignado, aporte y solidez de la conclusión. Al abrir un importe debe mostrarse su origen y fórmula. «Cuantificar todo» debe significar representar también la incertidumbre y los costos del resto de la operación, no rellenar vacíos con cifras que aparenten certeza.
