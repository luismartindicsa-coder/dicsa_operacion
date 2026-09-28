# Rentabilidad por empresa: diagnóstico y diseño del análisis

Revisión: 21 de septiembre de 2026. Objetivo: decidir qué relaciones comerciales conviene conservar, renegociar, reorganizar o terminar.

Se revisaron las fuentes y cálculos del código local, sus migraciones y documentación, y se consultó la base operativa mediante GET, con paginación y conteos exactos. Los conteos corresponden a los registros visibles con la sesión de la app; no certifican que se haya capturado toda la operación real. Se inspeccionó la implementación de las pantallas, no se realizó una prueba visual de cada interacción. El repositorio tenía cambios en curso, especialmente en Dirección; este diagnóstico corresponde al código disponible al revisar.

El [anexo por página](AUDITORIA_PAGINAS_RENTABILIDAD_2026-09-21.md) detalla el papel de cada pantalla. Los [resúmenes verificables de datos](../../../../work/rentabilidad_empresas_20260921/cobertura_datos.json) y las [validaciones adicionales](../../../../work/rentabilidad_empresas_20260921/validaciones_adicionales.json) conservan los resultados agregados. No se modificaron registros operativos ni código funcional de la app.

**Conclusión**

Tenemos las fuentes principales para construir el análisis dentro de DICSA. La pieza que falta es una capa común de identidad, atribución de costos y conciliación. No basta con sumar lo que muestran los dashboards: representan fechas, unidades y hechos distintos.

La primera versión debe medir la **contribución estimada por empresa generadora/planta**, conservando el detalle por material y mostrando la calidad de la evidencia. Después puede incorporar resultado realizado con inventario valuado y origen trazable. Para clientes compradores, el análisis usa sus ventas reales y el costo del material vendido. Una empresa puede tener ambos papeles, pero las dos lecturas no se suman como si fueran ingresos independientes.

La decisión final requiere dos resultados: cuánto aporta hoy la empresa y cómo cambiaría el resultado de DICSA si dejamos de atenderla. Un reparto de gastos fijos, por sí solo, no responde la segunda pregunta.

**Lo que existe y qué tan completo está**

| Fuente observada | Cobertura al consultar | Implicación |
|---|---:|---|
| Compras Mayoreo | 4,127 tickets; proveedor y material en todos | Base sólida para importe de adquisición histórico; el historial visible llega al 18/09/2026 e incluye registros antiguos que exigen un corte explícito. |
| Menudeo | 5,652 tickets; 5,650 con contraparte | Compra y venta se distinguen por `direction`. No volver a sumar la pantalla Ventas, que usa estos mismos tickets. |
| Ventas Mayoreo | 385 reportes; 384 con peso e importe aprobado positivos | Separar la fila pendiente de aprobación. Existe una venta fechada después del 21/09; excluirla del realizado a esa fecha y revisar su naturaleza. |
| Catálogos de empresas | 73 `sites`, 48 proveedores de Compras, 36 clientes de Mayoreo, 110 contrapartes de Menudeo | Son universos por función, no un total de empresas distintas. |
| Vista comercial unificada | 194 contrapartes y 10,164 eventos | Ya reúne los tres canales; la unión conserva identidades de origen, no resuelve por sí sola todas las equivalencias. |
| Servicios de Logística | 959; todos con empresa, 818 con unidad, 937 con chofer; 861 completados | Buena base de atención por empresa. Debe usarse ejecución confirmada y resolver unidades faltantes. |
| Diésel | 101 registros, desde 07/08 hasta 21/09 | Guarda litros comprados/solicitados y unidad; no precio por litro ni empresa atendida. |
| Gasolina | 6 registros, desde 09/09 hasta 21/09 | Guarda cargas por unidad; tampoco importe o empresa. No demuestra ausencia de consumo anterior. |
| Kilometraje | 93 registros, desde 07/09 hasta 19/09 | Hay km por unidad/día; falta distancia individual de cada viaje. |
| Prenómina/Nómina | 234 filas; todas con empresa; 228 publicadas | Solo hay tres periodos cerrados visibles: 35, 37 y 38. Los otros seis registros son borradores o parciales. |
| Bancos | 652 movimientos | `company` indica DICSA/VH, no la empresa generadora a la que debemos cargar el costo. La contraparte bancaria tampoco equivale necesariamente al beneficiario del gasto. |
| Bóveda | 825 vales y 825 renglones | De sus 662 renglones de egreso, solo 14 traen empresa; esos 14 pertenecen a compras de material. Los 28 renglones de gastos operativos no tienen empresa. |
| Caja Menudeo | 2,166 vales y 2,320 renglones | En el rubro Operativo hay 1,442 renglones; 284 tienen empresa. La asignación por campo existe, pero su captura es parcial. |
| Mantenimiento | 163 OT; 101 con costo real positivo; 152 con equipo identificado | El vínculo usado por la pantalla es `equipment_id`, no el campo antiguo `vehicle_id`. Falta distribuir el uso del equipo entre empresas. |
| Órdenes de compra | 378; 349 compradas; 347 con importe real capturado | No confundir solicitado, estimado, autorizado, comprado y pagado. La OT, su compra y su pago pueden representar un solo costo. |
| Inventario V2 | 10,699 movimientos; 8,229 con contraparte de Operación | Registra existencia y movimientos físicos. No constituye por sí mismo un inventario valuado con costo de venta por origen. |
| Transformación V2 | 1,230 corridas | 1,067 tienen entrada igual a suma de salidas; 157 tienen salida superior a entrada, todas en abril. No inferir rendimiento real sin validar medición. |
| Gestión Documental | 5 registros visibles: cuatro legales y uno ambiental | Hay pantallas de contratos y seguros, pero la tabla consultada no contiene expedientes de esas categorías. No asumir que los compromisos están documentados ahí. |

Fuente: consultas del 21/09/2026 guardadas en los dos JSON enlazados. Las ventanas son de registros existentes, no declaraciones de integridad histórica.

**Las conexiones que debemos resolver**

1. **Empresa, planta y papel comercial.** `sites.id`, proveedor de Compras, cliente de Ventas, contraparte Menudeo y texto `empresa` de RH no son una sola llave. La vista comercial deja `related_site_id` vacío para Compras y Ventas; solo 5 de 110 contrapartes Menudeo tienen `site_id`. Por nombre normalizado aparecen candidatos para 17 de 48 proveedores y 9 de 36 compradores. Son candidatos, no equivalencias aprobadas. Algunos proveedores no necesitan un sitio logístico; el faltante debe evaluarse según su operación. MONROE y MONROE SUR deben conservarse como plantas distintas aunque se agrupen comercialmente. SETEX/SETEXMES o las variantes de APASEO requieren resolver su significado, sin fusiones automáticas.

2. **Dinero gastado frente a operación beneficiada.** Pagar a una gasolinera identifica al vendedor de combustible; no indica qué generadora originó el gasto. Pagar desde DICSA identifica la entidad pagadora. Necesitamos tres dimensiones separadas: entidad que paga, contraparte a quien se paga y empresa/planta/activo beneficiario.

3. **Valor del material originado frente a ventas al mismo nombre.** Compramos material a una empresa y lo vendemos a otra. Para valorar a una generadora no se restan simplemente sus compras de sus ventas como cliente: necesitamos el valor recuperable del material que nos entrega, o las ventas trazadas a ese origen.

4. **Periodos comparables.** La nómina se devenga por periodo trabajado; no por fecha de publicación ni fecha bancaria. Una compra usa fecha operativa; una cobranza usa fecha de cobro. Los litros de una carga no tienen que consumirse ese mismo día. El informe debe usar un calendario común y conservar por separado las fechas de operación, devengo y pago.

5. **Grano del hecho económico.** Ticket comercial, entrada de báscula, factura, abono bancario y comprobante no son cinco costos. Se conservarán como evidencia de un solo hecho con sus relaciones. Un folio repetido tampoco demuestra duplicidad: puede tener materiales o renglones distintos.

**Cómo calcularlo**

El registro mínimo de análisis será **empresa → planta → material/calidad → periodo**, con detalle de servicio, documento y costo cuando corresponda. Se podrá resumir después por grupo empresarial.

Para los precios observados:

```text
Compra ponderada empresa-material = suma de importes de compra / suma de kg pagables
Venta ponderada material-calidad = suma de ventas netas elegibles / suma de kg aprobados correspondientes
```

Se usan importes y pesos de las mismas filas. No se promedian precios de tickets, ni se reconstruye el pasado con la tarifa vigente. Antes de consolidar importes hay que confirmar moneda, unidad y tratamiento de impuestos en cada fuente: excluir impuestos recuperables y conservar costos no recuperables según la política contable acordada. Los campos consultados no justifican suponer que todos los importes tienen idéntico tratamiento fiscal.

El ponderado de venta se segmenta por calidad comercial y salida comparable: nacional, limpio y americano; rebaba, pesado, mixto, etc. Servicios, piezas y toneladas requieren unidades propias o conversiones verificadas. Un ponderado general de CARTÓN o CHATARRA puede ocultar diferencias decisivas.

Para una **empresa generadora**, la primera lectura será:

```text
Valor recuperable estimado del material
  = suma, por salida comercial, de:
    kg físicos recibidos × rendimiento recuperable × precio neto de venta comparable

Aporte operativo estimado
  = valor recuperable estimado
  + ingresos por servicios efectivamente prestados y reconocibles
  − importe real de compra del material
  − transporte y maniobras atribuibles
  − personal dedicado y trabajo compartido atribuible
  − transformación y otros costos operativos atribuibles

Resultado después de estructura
  = aporte operativo − gastos comunes y cargos de activos asignados
```

El rendimiento relaciona kg físicos de entrada con kg vendibles de cada salida, no necesariamente kg pagables. Humedad y basura descontadas al comprar no prueban el rendimiento de clasificación. Si un material genera varias salidas, se suma su valor recuperado sin duplicar el peso de entrada. Sin rendimiento defendible se mostrarán escenarios identificados y resultado pendiente; no se fija 100% por comodidad.

Este valor es una **estimación económica del material originado**, no venta realizada. Cuando haya trazabilidad, otra vista mostrará ventas reales atribuidas a ese origen menos el costo correspondiente al inventario vendido. Los kg pendientes de venta se mantienen como inventario, no como ingreso realizado. No sumar el valor estimado y la venta real en el mismo resultado.

Para un **cliente comprador**: venta neta real menos costo del material vendido, entrega, servicio comercial y costos específicos. Si el cliente también es generador, mostrar ambos papeles y una conciliación de la cadena para evitar contar dos veces el mismo margen.

El promedio ponderado de ventas es una referencia comercial. El costo promedio de inventario es otro cálculo: incorpora inventario inicial y adquisiciones/costos incorporables, y aplica el costo al material vendido. La separación entre existencia y costo de venta sigue el principio descrito por [IAS 2, IFRS Foundation](https://www.ifrs.org/issued-standards/list-of-standards/ias-2-inventories/). La elección y aplicación contable concreta se debe alinear con el cierre de DICSA.

**Cómo integrar cada costo**

| Costo | Fuente de importe | Regla de asignación | Control indispensable |
|---|---|---|---|
| Material comprado | Tickets de Compras/Menudeo | Empresa y material del ticket | Vincular factura/pago como evidencia, sin sumarlos otra vez. |
| Combustible | Documento de compra/gasto en Caja/Bancos/Finanzas, conciliado con litros | Consumo por unidad y periodo; después a viajes mediante km medidos o una estimación documentada | Comprar al tanque, cargar a unidad y consumir no son lo mismo. No valorar cada litro dos veces. |
| Chofer y ayudante | Costo laboral reconocido en RH | Horas atribuibles al servicio; estimación temporal por jornada/ruta cuando se declare | La relación entre ID de empleado de Operación y RH necesita validación; no asumir igualdad de IDs. |
| Personal fijo en planta del cliente | Nómina del periodo, prestaciones y cargas patronales verificadas | Directo a la planta durante la asignación efectiva | Conservar la empresa histórica. Cambiar hoy al empleado no debe reasignar nóminas cerradas. |
| Personal de patio/proceso | RH + actividad productiva | Horas de trabajo/máquina; toneladas por proceso si se usa una base provisional | No cargar el mismo salario directo y como gasto común. |
| Mantenimiento de unidades | OT, materiales/servicios efectivamente consumidos y compras vinculadas | A unidad por `equipment_id`, luego a empresas según uso | No sumar total OT, sus líneas, orden y pago. Separar gasto, refacción en existencia y mejora de activo. |
| Consumibles de almacén | Compra valuada y salida consumida | Centro o proceso consumidor, luego empresa | La pantalla actual registra cantidades; requiere costo unitario comprobable. |
| Gastos específicos | Renglones de vales, facturas u otros comprobantes | Directo cuando exista beneficiario verificable | Campo vacío queda pendiente o común justificado, nunca costo cero de la empresa. |
| Costos de estructura | Gastos reconocidos, seguros y uso de activos | Base causal: horas, capacidad usada, espacio o toneladas homogéneas | Publicar base, periodo y porcentaje; no repartir todo por ventas automáticamente. |
| Costo del capital ocupado | Inventario + cuentas a cobrar − financiamiento comercial atribuible | Tasa y días explícitos, como escenario gerencial | No duplicar intereses ya incluidos. Cobrar tarde no elimina una venta, pero inmoviliza dinero. |

En combustible, Rendimiento hoy cruza unidad/día y muestra los destinos. No reparte litros ni pesos. De 96 cargas de diésel positivas, el cruce temporal arroja 47 sin destino coincidente, 28 con un destino y 21 con varios; incluye distintos estados del servicio y solo sirve como diagnóstico de vinculación. Una carga abastece días posteriores y algunos equipos consumen en patio. No repartirla automáticamente entre los servicios del día ni tratar los casos sin coincidencia como pérdidas.

En nómina, la app distingue origen fiscal y forma de entrega: un cheque fiscal también puede estar dentro de Flujo. El resumen existente advierte que el desembolso es depósito + flujo, no fiscal + flujo. Además, desembolso neto y costo laboral no son iguales: recuperación de préstamos o descuentos a favor de terceros no reducen por sí mismos la remuneración devengada. Campos como IMSS del trabajador no prueban que se tenga toda la carga patronal. Debe conciliarse el costo laboral y separar préstamos, prestaciones, provisiones y pagos de obligaciones ya reconocidas.

**Qué significa “vale la pena quedarnos”**

El informe debe exponer, sin esconder los componentes:

| Lectura | Pregunta que responde |
|---|---|
| Diferencia comercial por kg | ¿La calidad y el precio dejan espacio antes de atender la empresa? |
| Aporte después de operación atribuible | ¿Cuánto deja después de compra, recolección, trabajo y proceso? |
| Resultado después de estructura | ¿Cuánto deja al participar en los costos comunes? |
| Flujo y capital ocupado | ¿Cuánto dinero exige y en qué plazos se recupera? |
| Cambio por terminar la relación | ¿Mejoraría DICSA si retiramos esta operación y reasignamos sus recursos? |

Para la última pregunta:

```text
Mejora por salir
  = costos que realmente desaparecen
  + contribución adicional de una alternativa factible
  − ingresos que se pierden
  − costos de salida y transición
```

Todos los términos deben cubrir el mismo horizonte futuro y una cadena de material consistente. Al dejar una generadora no desaparece el inventario que ya compramos; la pérdida futura depende de si sustituimos ese abasto y a qué costo. Si se parte del aporte perdido en vez de ingresos perdidos, no volver a sumar los costos ya descontados para calcular ese aporte. La alternativa no puede dar por disponible capacidad ya comprometida. Un chofer reasignado no representa automáticamente ahorro de toda su nómina. Un camión propio que queda parado conserva costos. La distinción entre costos evitables y asignados está respaldada por [ACCA: Relevant costs](https://www.accaglobal.com/gb/en/student/exam-support-resources/fundamentals-exams-study-resources/f5/technical-articles/relevant-costs.html).

La clasificación propuesta es: **Conservar/crecer**, **Renegociar**, **Reorganizar operación**, **Evaluar salida** o **Información insuficiente**. Cada recomendación debe explicar su causa y el cambio requerido. No heredar como regla universal el diferencial fijo de $1/kg usado por un reporte de Menudeo: es una referencia comercial previa al costo operativo, no el umbral de rentabilidad de todas las empresas.

Las palancas concretas serán precio máximo de compra, tarifa mínima de servicio, kg mínimos por recolección, frecuencia de visita, ruta compartida, personal dedicado y condiciones de cobro/pago. Un simulador debe conservar inventarios, capacidad y costos fijos que no cambian; no extrapolar automáticamente que bajar precio mantiene el mismo volumen.

**Diseño dentro de la app**

Propuesta: **Dirección → Rentabilidad por empresa**, con acceso de revisión desde Contabilidad y Gerencia. Mantener una sola fuente de cálculo para pantalla y exportación.

La tabla principal mostrará empresa/planta, periodo, kg recibidos y pagables, compra real, valor recuperable estimado o venta realizada —con selector explícito de base—, margen comercial, combustible, nómina, proceso, mantenimiento, otros gastos, aporte, estructura asignada, resultado, $/kg, $/servicio, cambio estimado por salir y confiabilidad. Al ordenar por resultado se distinguirán los casos incompletos.

Al abrir una empresa habrá cinco vistas:

1. **Resultado y tendencia:** composición del resultado, periodos comparables, contribución y flujo separados.
2. **Materiales y precios:** calidad, kg físicos/pagables/vendibles, precios históricos, rendimiento y procedencia de la referencia de venta.
3. **Atención y costos:** servicios ejecutados, unidades, km, litros, personal, OT y regla de reparto de cada gasto.
4. **Escenarios:** precio, recolecciones, volumen, personal y alternativa de capacidad; impacto esperado y punto de equilibrio bajo supuestos visibles.
5. **Evidencia y pendientes:** documentos fuente, posibles duplicados, importes sin empresa, periodos faltantes y cambios posteriores al cierre.

Cada importe será marcado como directo comprobado, asignado con regla, estimado o pendiente. La confianza se medirá por bloque e importe, no con un semáforo único que oculte un costo crítico faltante. Una empresa sin combustible valuado no puede aparecer como rentable solo porque esa celda quedó en cero.

**Implementación propuesta**

1. **Identidades y corte piloto.** Crear equivalencias verificadas entre catálogos, conservando plantas y roles. Empezar por el periodo 38, del **11 al 17 de septiembre de 2026**, porque tiene 75 nóminas publicadas y cierre. En esas fechas hay 92 servicios completados, todos con unidad, 40 registros de kilometraje, 9 registros de diésel y 3 de gasolina. La cobertura temporal permite conciliar, pero no demuestra consumo completo: el diésel del corte está registrado solo el 11 y el 14.
2. **Hechos comerciales y gastos normalizados.** Reutilizar eventos comerciales y comprobantes existentes con reglas más estrictas de aprobación, fecha, calidad y unidad. Asignar identificador de hecho económico y relación entre documentos. Mantener un bloque de importes no asignados.
3. **Costo de atención.** Incorporar nómina cerrada, valuación de combustible, distribución de unidades y proceso. Mostrar estimaciones sin presentarlas como hechos medidos. Conciliar cada bolsa de costos antes de repartirla.
4. **Ranking, detalle y escenarios.** Comparar empresas con misma base de cálculo y cobertura. Mostrar contribución, estructura y efecto de salida por separado. Dar prioridad a revisar las relaciones con mayor gasto/capacidad comprometida y mayor incertidumbre material.
5. **Cierres reproducibles y evolución.** Congelar fuentes, reglas y corte revisado; comparar después 4 y 13 semanas cuando exista historial compatible. Reabrir o versionar correcciones. Agregar trazabilidad de lotes/costos de inventario para el resultado realizado por origen.

Se proponen entidades analíticas para equivalencias de empresa/planta, equivalencias de material/calidad, hechos económicos, relaciones entre evidencias, asignaciones de costos y cierres. Los nombres y el esquema definitivo se decidirán al implementar. Las equivalencias y porcentajes deben tener vigencia y autor; no modificar retrospectivamente documentos de origen para hacer que el reporte cuadre.

**Condiciones para confiar en el resultado**

- Importe comercial conciliado con sus documentos, después de explicar exclusiones; cobros y pagos conciliados por separado.
- Costo total asignado + costo común identificado + costo pendiente = total elegible de cada fuente, sin duplicados y con tolerancias de redondeo explícitas.
- Un mismo costo no pertenece simultáneamente a combustible, factura, OT y caja como cuatro cargos independientes.
- Porcentajes de reparto por costo suman 100%; el remanente pendiente permanece visible.
- Periodos y zona horaria definidos; fechas futuras, borradores y servicios cancelados fuera del realizado, sin borrar sus costos reales de cancelación si los hay.
- Stock físico conciliado por etapa; inventario inicial y final valuados para reportar costo de venta realizado.
- Referencia de venta de la calidad correcta, con antigüedad, volumen y tamaño de muestra visibles. Sin referencia comparable, resultado pendiente o escenario explícito.
- Sin fallos de fuente disfrazados de listas vacías, sin límites silenciosos de 1,000 filas y con totales consistentes al abrir detalle/exportar.
- Casos de revisión funcional: empresa con dos plantas, varios destinos por unidad, carga de combustible de días previos, material con varias salidas, compra aún en inventario, sueldo pagado por varios medios, factura con varios abonos, OT ligada a compra, mes sin nómina cerrada y empresa con gastos sin asignar.

**Referencias de implementación revisadas**

- [Eventos comerciales y su carga](../../lib/app/commercial/commercial_store.dart), [definición de la vista comercial](../../supabase/migrations/20260617193000_add_general_material_views_to_commercial_radar.sql) y [Compra–Venta](../../lib/app/direction/direction_trade_analysis_page.dart).
- [Estado de Resultados: pantalla](../../lib/app/contabilidad/contabilidad_income_statement_page.dart) y [motor con `loadSimplified`](../../lib/app/contabilidad/contabilidad_income_statement_store.dart). La pantalla llama ese método; la existencia de otro método `load` más elaborado no significa que lo esté utilizando.
- [Rendimiento](../../lib/app/logistica/logistics_performance_page.dart), [diésel](../../lib/app/logistica/logistics_diesel_store.dart) y [gasolina](../../lib/app/logistica/logistics_gasoline_store.dart).
- [Nómina y resumen de entrega](../../lib/app/hr/human_resources_nomina_page.dart), [identidad en Finanzas](../../lib/app/finanzas/finanzas_company_identity.dart) y [Bóveda](../../lib/app/shared/direction_vault/direction_vault_repository.dart).
- [Transformación](../../lib/app/services/inventory_transformation_grid.dart), donde el peso de entrada puede tomar por defecto el peso de salida, y [movimientos de inventario](../../lib/app/services/inventory_movements_grid.dart), donde `total_amount_kg` es peso ajustado, no pesos monetarios.
- [Mantenimiento](../../lib/app/maintenance/maintenance_page.dart), [precios ponderados de supervisión](../../lib/app/management_reports/menudeo_weighted_price_analysis.dart) y [reporte previo de precios de agosto](../gerencia/REPORTE_PRECIOS_COMPRAS_VENTAS_CARTON_CHATARRA_AGOSTO_2026.md).

La recomendación concreta es construir primero el consolidado de contribución por empresa con el corte piloto y sus pendientes visibles. La información existente permite empezar; una recomendación firme de retirar una empresa exige cerrar las asignaciones y comprobar que salir mejora el resultado de DICSA.
