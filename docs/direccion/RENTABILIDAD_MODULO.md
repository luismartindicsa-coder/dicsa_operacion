# Rentabilidad operativa por empresa — motor 3

Ruta: **Dirección → Rentabilidad**. La entrada muestra únicamente empresas del catálogo de Compras Mayoreo y sus plantas vinculadas, con el mes hasta hoy por defecto. Muestra **lo que genera**, **lo que cuesta atender** y **aporte operativo**. Es un modelo de atención de cuentas: combina registros e inferencias visibles. No calcula utilidad contable realizada del inventario.

## Uso

1. Seleccionar mes, semana, día o periodo personalizado.
2. Abrir una empresa/planta. La lista se ordena por aporte.
3. Revisar materiales/servicios y costos comunes de esa cuenta. Las líneas con pérdida muestran la compensación adicional por kg o servicio necesaria para cubrir sus costos atribuidos. Personal y equipo dedicados que permanecen a nivel cuenta se muestran por separado.
4. Abrir **Cómo se calculó** para ver importes, fórmula, fecha, procedencia y tipo de cada componente: registro, reparto o estimación.
5. **Ajustar concepto de esta cuenta** permite cambiar una base por mes, año, servicio, kg, tonelada o cargo único, con cantidad y vigencia. Una nueva condición conserva los tramos anteriores y posteriores de la condición sustituida.

Opciones contiene exportación de tabla/bases, guardar análisis, históricos, parámetros auxiliares y conciliación documental. La antigua auditoría sigue disponible. La pantalla principal no exige completar una auditoría para calcular.

## Consolidado y decisiones

La pestaña **Consolidado** comparte el periodo seleccionado con **Empresas**. Siempre incluye todas las cuentas operativas, independientemente del texto del buscador de empresas. Reutiliza el arquetipo de tabs de Almacén presente en el módulo, las cards de Dirección y los formularios/pickers compartidos; no es un grid de transacciones editable.

Muestra el resultado global, prioridades por empresa y un simulador para una cuenta a la vez. El resultado incluye estructura adicional si existe, cuantificada explícitamente. La lista prioriza cuentas sin ingreso atribuido, posibles mejoras al salir y déficits; una pérdida después del reparto no implica automáticamente que convenga abandonar la cuenta.

**Salida.** `Cambio en DICSA = costos que se ahorrarían − valor/ingresos que se pierden − costo de transición + aporte neto de capacidad reutilizada`. El resultado simulado es el resultado global actual más ese cambio. El costo de la cuenta que permanece no se resta otra vez: ya está dentro del resultado base y sigue a cargo de DICSA aunque no queden clientes. No se recalculan los costos base borrando la empresa, porque eso podría hacer desaparecer indebidamente recursos y gastos compartidos.

Como supuesto inicial, se evitan el 100% de compra, combustible, recolección/transporte, disposición y báscula. Personal dedicado, nómina común, equipo, proceso, mantenimiento, capacitación, otros gastos y estructura permanecen al 100%. Estos porcentajes son hipótesis operativas revisables por rubro, no evidencia de cancelación de contratos ni garantías de ahorro. La lista de prioridades utiliza siempre estos supuestos iniciales; el simulador utiliza los porcentajes editados de la cuenta elegida.

**Ajustar operación.** Permite cambiar precio de compra, valor recuperable y tarifa de servicios entre −100% y +100%, así como reducir viajes/km entre 0% y 100%. Se conserva el volumen material: menos viajes supone consolidación o entrega directa y requiere validar capacidad/frecuencia. Combustible, recolección/transporte y báscula disminuyen proporcionalmente a los viajes; nómina y equipo no. Por defecto el ingreso por servicios también baja con los viajes; se puede indicar que permanece fijo. La tarifa modificada se aplica al ingreso después de esa reducción. Sin viajes de base, el control de reducción no crea ahorros ni pérdidas de ingreso ficticios.

Los costos de transición y el aporte neto adicional de reutilizar capacidad empiezan en cero. El aporte de reemplazo debe descontar sus costos incrementales; no es facturación bruta ni se infiere de la capacidad liberada. Se cuantifica cuánto aporte neto de reemplazo haría falta para conservar el resultado actual, además de viajes/km liberados y material perdido al salir. La capacidad física no se convierte automáticamente en vehículos/plazas disponibles.

Para cuentas con déficit se muestran alternativas independientes: mejorar margen por kg, reducir compra o recuperar una tarifa adicional por servicio. Son escenarios de equilibrio, no precios de mercado recomendados ni mejoras que puedan sumarse entre sí sin comprobar sus efectos.

Las simulaciones son temporales, no escriben en Supabase ni modifican la operación. Se restablecen al cambiar de empresa o periodo; al actualizar la misma cuenta conservan sus supuestos y utilizan la nueva lectura. El refresh permanece cada 30 segundos y se aplaza mientras se edita un formulario. Enter aplica, Esc cancela, y una validación fallida conserva el borrador. Si falla una fuente, se señala la última lectura y se suspenden los ajustes hasta recuperarla. Exportar/guardar el análisis sigue correspondiendo al corte base, no a una simulación.

Validación del consolidado (22/09/2026): 88 pruebas del módulo verificadas, análisis estático sin observaciones y compilación macOS debug. Se conciliaron las 75 salidas individuales contra el corte real 01–22/09: `resultado sin la cuenta = resultado de las demás − costos de la cuenta que permanecen`, sin eliminar nómina compartida ni dedicada. Se revisaron capturas a 1440 y 600 px y la pestaña real en la app macOS con el periodo 21–22/09 (30 cuentas en esa lectura). No se escribieron operaciones ni escenarios en Supabase.

## Consolidación de las cinco áreas

| Área | Base utilizada | Aplicación operativa |
|---|---|---|
| Compras Mayoreo y tickets de Menudeo | Empresa, material, kg físicos/pagables e importe | Compra real del material; kg físicos para recuperación |
| Ventas Mayoreo | Ventas elegibles con unidad kg; importe y peso aprobados | Precio ponderado `Σ importe / Σ kg`; servicios se separan del material |
| RH | Nómina cerrada/publicada y salario semanal de perfiles | Personal dedicado por empresa; choferes comunes por viajes/km; resto por kg/movimientos |
| Logística | Servicios completados, unidad, km, litros despachados/cargados, contenedores | Actividad, combustible y reparto por unidad/servicios/km |
| Finanzas, caja/bóveda y mantenimiento | Movimientos, facturas manuales/notas, vales, OT y órdenes compradas | Clasificación operativa, costos directos y bolsas compartidas |

Todas las lecturas se paginan. Las finanzas consultan hasta 90 días anteriores como referencia; ventas usa el corte o hasta 90 días previos por comparable. Los nombres de RH y del catálogo de choferes se consultan transitoriamente para inferir coincidencias únicas y se eliminan antes de construir el análisis. No se consultan cuentas bancarias personales ni recibos. No se exportan nombres ni salarios individuales de perfiles; la evidencia guarda grupos/cantidades/huellas y referencias a nómina publicada.

## Reglas del modelo

**Identidades.** Primero prevalecen las equivalencias vigentes aprobadas y vínculos explícitos. Después se consolidan nombres normalizados inequívocos entre catálogos. MONROE NORTE y MONROE se reconocen como el mismo nombre; MONROE SUR conserva su planta. SETEX/SETEXMES y BOSCH/BOCHS/DESPERDICIOS QUERETANA BOSCH son equivalencias confirmadas por Dirección el 22/09/2026; el nombre visible sigue el catálogo de Compras. Si dos sitios comparten el mismo nombre normalizado no se fusionan automáticamente. El alcance visible se aplica después del reparto: otras actividades conservan sus costos y aparecen resumidas en la conciliación. Se incluyen todos los centros legales y sucursales, también VH y Mazatlán, por confirmación de Dirección.

**Valor recuperable.** Una receta aprobada conserva prioridad. Sin receta se infiere recuperación del 100% sin merma capturada: comparable de Mayoreo por nombre/calidad y, después, el promedio ponderado de los comparables de su familia de catálogo (mezcla inferida, no selección del precio mínimo). El detalle declara esta aproximación. Las ventas de Menudeo por viaje/pieza no entran como precios automáticos por kg. RSU tiene valor material cero. Leña sin venta comparable tiene valor recuperable cero. Para otro material sin comparable se utiliza compra como valor neutral de referencia, con margen comercial base cero antes de atender la cuenta; queda marcado como estimación de baja confianza. Esta base no afirma que exista una venta.

**Equivalencia confirmada.** Cartón americano se valora con las ventas de Cartón Celanese por confirmación de Dirección del 22/09/2026. La equivalencia y el precio ponderado utilizado quedan en cada componente. No se carga una tarifa inventada. Dirección aclaró que esta equivalencia aplica únicamente al material identificado como americano, también en AVON: no reclasifica todo su corrugado, nacional o cartón genérico. Un servicio de americano sin peso no aporta kilos nuevos ni cambia la calidad del material registrado en compras/entradas.

**Entradas físicas.** Se consultan las entradas GENERAL/IN/DIRECT_PURCHASE de inventario. Un enlace único por folio, material y kg, con desfase máximo de 31 días, atribuye compra y valor juntos a la planta física. Sin enlace, se toma el máximo entre kg físicos y compras por planta/familia; solo la diferencia recibe compra y valor estimados. El cartón genérico y americano comparten conciliación física, conservando precios de venta específicos. Las entradas genéricas PUBLICO, las salidas y transformaciones no agregan material. El desfase de fechas y las contrapartes distintas siguen siendo una limitación explícita.

**Servicios.** Se usa el importe aprobado del servicio en Mayoreo, sin volver a multiplicarlo por kg. Las pesadas aportan el cargo registrado, separado del material. La facturación de RSU cubre solamente los servicios equivalentes documentados; los restantes conservan una tarifa de servicio comparable con unidad servicio/viaje. Un parámetro, incluso de importe cero, cubre solamente los servicios dentro de su vigencia. Para MONROE, sin tarifa propia capturada, la referencia del documento es **$5,800 por recolección como ingreso**: MONROE paga a DICSA. No se confunde ese importe con disposición de basura.

**Combustible.** Los litros despachados de diésel y cargados de gasolina son una aproximación al consumo. Se asignan por km de esa unidad y día; cuando no hay actividad de ese día se usa la actividad de la misma unidad en el periodo, identificada como inferencia. Los km de otra unidad nunca alteran el reparto. Las cargas sin actividad asociable permanecen cuantificadas fuera de las cuentas. Los recorridos de otras unidades o días no cubiertos conservan su propia estimación. Los litros comprados reponen inventario y no se suman otra vez como consumo. Precio inferido de finanzas/litros comprados cuando resulta compatible con la referencia documental; en ausencia de una base compatible, $23.67/L del documento MONROE. No es un precio de mercado actualizado. Sin litros, se usa gasto financiero o referencia histórica; después km / 3 km/L × precio. Toda aproximación conserva su procedencia.

**Km.** Km medidos por unidad/día se dividen entre sus servicios completados. Si faltan, se usa km/servicio observado de la flota; para MONROE las rutas documentadas Norte 31.6 y Sur 49.8 km. Sin observaciones, 31.6 km es una referencia provisional visible, no una ruta medida de la otra empresa.

**Nómina.** Nómina publicada dividida entre días del periodo, restituyendo descuentos de préstamo y retenciones de flujo para no reducir artificialmente la remuneración. En días sin publicación, salario semanal base+flujo de RH / 7, respetando ingreso y baja. Un cierre publicado por empresa/día impide agregar salarios de perfiles de otro grupo funcional en ese mismo día. RH con empresa dedicada permanece en esa empresa.

El personal común se divide en dos bolsas, con proporciones calculadas sobre todas las cuentas del periodo seleccionado:

- **Nómina de transporte compartida:** promedio de participación en viajes completados y participación en km (50% cada proporción cuando existen ambas). Se infieren choferes mediante coincidencias únicas de al menos dos palabras del catálogo Logística con RH; las coincidencias ambiguas no se fuerzan.
- **Nómina de patio y soporte:** promedio de participación en kg y participación en movimientos (50% cada proporción cuando existen ambas). Movimiento = máximo diario por cuenta entre documentos canónicos de compra/entrada, servicios completados y documentos de venta de servicio. Es una aproximación conservadora para no sumar varias fuentes del mismo movimiento; no una conciliación individual de todos los documentos. Incluye el personal interno sin función identificada; no se presume exclusivamente administrativo ni que todos trabajen en patio.

Se promedian proporciones, nunca cantidades de unidades diferentes. Si falta una base se usa la otra. Una empresa sin viajes ni km recibe cero de la bolsa de choferes identificados mientras exista actividad de transporte en el corte. Si no hay viajes ni km en toda la operación, la nómina de transporte se conserva como capacidad sin actividad atribuida, fuera de las cuentas. Lo mismo sucede con el personal común sin base de kg ni movimientos. Esos importes se restan al conciliar el resultado de toda la operación modelada. Ninguna empresa queda etiquetada permanentemente como entrega directa: su participación cambia con el periodo. Los pesos iguales son una aproximación operativa inicial, no horas medidas.

No se inventa una tasa patronal. Las cargas laborales identificadas en Finanzas siguen la remuneración RH atribuida y su separación dedicada/compartida; la parte correspondiente a nómina sin actividad también permanece fuera de las cuentas. No se presume una tasa ni una periodicidad no descrita en el comprobante. El detalle y el PDF muestran las bases del cálculo. La falta de un catálogo uniforme de puestos sigue limitando la separación completa de funciones.

**Otros costos.** Finanzas se clasifica con conceptos, comentarios y notas. Administración se reparte por movimientos; otros comunes por la media de participaciones en kg/movimientos; capacitación y cargas laborales por remuneración RH. Transporte/báscula siguen servicios; proceso y equipos de patio, kg sin RSU; mantenimiento de unidad identificada, km de esa unidad; disposición, kg RSU; contenedores, unidades instaladas. Sin actividad causal, el importe se conserva fuera de las cuentas: no hay reparto igualitario automático. Compras de mantenimiento para almacén sin OT vinculada se muestran como inventario pendiente de consumo, separado del gasto. Varios documentos del mismo día se conservan completos. Una factura manual válida conserva su consumo completo aunque tenga pagos parciales o totales vinculados: la liquidación no reemplaza el consumo ni se suma otra vez. OT/compra vinculada se cuentan una vez. Las facturas de material de MAURICIO ALCALA y MONICA CHAVEZ se concilian fuera del gasto adicional porque Dirección confirmó el 22/09/2026 que ya están en tickets, aunque con otro nombre. Se conserva importe, documento y confirmación en `material_invoices_covered_by_tickets`; no se afirma un enlace individual inexistente. MARICRUZ QUIROGA ACOSTA permanece como gasto: Dirección aclaró que no es compra de material. Nómina bancaria no se agrega a RH. Depósitos, transferencias entre cuentas, reposiciones de fondo y pagos de tarjeta identificables no se tratan como un segundo gasto operativo. Gastos financieros, préstamos cobrados automáticamente y personales identificados se separan del aporte operativo, con importe y referencia visibles; no se confunde pago de deuda con consumo operativo. No se pueden eliminar por certeza duplicados sin vínculo documental: la conciliación permite corregirlos.

**Tiempo.** Cargos explícitamente mensuales (por ejemplo, IMSS SEPTIEMBRE) se prorratean por días calendario del mes correspondiente. Los conceptos mensuales de cuenta usan los días reales de cada mes; los anuales se dividen en 12 mensualidades. Una vigencia corta solo reemplaza los días cubiertos. Se reconocen primero los rangos de consumo indicados en factura/notas. Una factura fechada después del subperiodo puede cubrirlo si su consumo corresponde; la consulta amplía Finanzas hasta el final del mes o hasta hoy. Las referencias históricas de 90 días cubren solamente días sin comprobante del mismo proveedor/concepto/centro. Gastos extraordinarios y otros/administración históricos sin recurrencia identificable no se convierten en gastos nuevos. Las agrupaciones históricas conservan documentos, cobertura y huellas en la evidencia. Son estimaciones, no gastos ocurridos en el corte.

**Referencias manuales MONROE.** El documento del 06/01/2026 analiza enero–abril de 2025. Se usan cantidades y fórmulas, no su total final inconsistente: Norte 5 contenedores / $20,657 mensuales; Sur 3 / $11,123; disposición $707.60/t; una pesada externa estimada por recolección a $100; capacitación $27,000/año distribuida entre Norte/Sur por personal RH. Si falta peso RSU de MONROE, referencia 112,380 kg / 85 servicios. Las bases históricas y las extrapolaciones a otras cuentas están identificadas como tales. No se insertaron tarifas de ejemplo ni contratos ficticios en la base.

**Cero cuantificado.** Cuando no hay actividad, cargo o referencia aplicable a un bloque, el modelo usa incremento cero explícito (`zero_basis`), con baja confianza y posibilidad de ajuste. No significa costo cero comprobado. Todos los componentes monetarios del estado operativo son finitos y no nulos; las limitaciones documentales permanecen en la auditoría.

**Resultado.** `Genera = valor recuperable + ingresos por servicios`. `Cuesta = compra + costos de atención + soporte asignado`. `Aporte = genera − cuesta`. Estructura adicional se muestra separadamente. Se distingue aporte antes del soporte compartido y después de asignarlo. Una cuenta que cubre atención pero queda negativa tras el reparto dice «Cubre atención; revisar soporte». Sin ingreso atribuido se indica revisar ese ingreso. Otros negativos dicen revisar condiciones y bases; ningún estado ordena abandonar una cuenta. El equilibrio por línea no incluye dos veces los costos que se muestran a nivel cuenta.

## Persistencia y compatibilidad

Migraciones aplicadas, sin ejecutar otras migraciones pendientes:

- `20260922000000_create_direction_profitability.sql`: revisiones y cortes.
- `20260922020000_extend_profitability_executive.sql`: maestro con vigencias e historial.
- `20260922030000_profitability_operational_accounts.sql`: conceptos operativos y snapshots motor 3.
- `20260922040000_profitability_inference_correction.sql`: admite el modelo corregido y conserva las versiones anteriores.

Cuatro tablas con RLS de Dirección, escrituras por RPC y control de revisión. La migración 3 no modifica operaciones ni snapshots previos. El maestro sigue sin importes precargados. El snapshot guarda `engine_version: 3`, `inference_model: operational-account-v2`, `payroll_allocation_model: activity-proportions-v2`, `cost_allocation_model: consumption-coverage-v1`, parámetros, revisión, evidencia y cuentas calculadas. El reparto proporcional no requiere otra migración. Se conservan los snapshots anteriores sin recalcularlos.

La actualización silenciosa ocurre cada 30 segundos y se aplaza al editar. Enter/Esc conservan la interacción de las superficies auxiliares. Si falla una fuente, no se convierte su ausencia en costo cero: se conserva la lectura anterior, se advierte el fallo y se suspende guardar/exportar.

## Verificación inicial del 22/09/2026 (modelo v1; sustituido para nuevos cálculos)

- 45 pruebas de motor, repositorio y widgets: importes, unidades, reparto completo, vínculos duplicados, nómina, MONROE, calendario normal/bisiesto, vigencias, foco, conflictos y anchos amplio/reducido.
- Análisis estático sin observaciones y compilación macOS debug completada.
- Pruebas SQL: permisos, RLS, revisión concurrente, rechazo de reglas inválidas y conservación de snapshots anteriores.
- Lectura real: piloto 11–17/09/2026, 243 tickets de compra y **49 cuentas operativas cuantificadas** (53 entidades en el resultado completo, incluyendo superficies auxiliares).
- Verificación visual en la app macOS abierta: mes 01–22/09 con 70 cuentas, búsqueda y detalle MONROE, plantas separadas e ingresos RSU visibles.
- Guardado y relectura con sesión normal de Dirección: `b76b7684-2484-4bb3-855a-1da08593add6`.
- Cortes anteriores conservados: `7a260d85-9084-4346-8a81-51820e78160e` y `da7c0db2-8623-4571-9501-8296a065a270`.
- Evidencia local: `work/rentabilidad_empresas_20260921/piloto_operativo.json` y `.saved.json`, en la raíz del workspace. Los conteos y valores dependen de la lectura; no son datos sembrados.

```sh
flutter test --no-pub test/direction/profitability_test.dart test/direction/profitability_repository_test.dart test/direction/profitability_operating_test.dart test/direction/profitability_account_test.dart test/direction/profitability_view_test.dart
DICSA_PGLITE_MODULE=/ruta/a/pglite/dist/index.js node tool/test_direction_profitability_sql.mjs
flutter build macos --debug --no-pub
```

La integración real usa la sesión autorizada mediante variables de entorno; no guarda credenciales. Por defecto solo consulta. `DICSA_PROFIT_SAVE_PILOT=1` guarda un análisis real, nunca operaciones de prueba.

## Corrección posterior del 22/09/2026

El modelo inicial subestimaba recuperación y mezclaba flujos de financiamiento con costos de atención. Ver [comparación y límites](CORRECCION_RENTABILIDAD_2026-09-22.md). Se verificaron 53 pruebas de motor/repositorio/widgets, análisis estático, compilación macOS y validación SQL. La integración real guardó y releyó el nuevo corte `d6d35e4b-4fab-4eff-9be6-d992872f72dc` (11–17/09), conservando los tres anteriores.

Las cifras de 01–22/09 son estimaciones y corresponden a la hora de consulta. No se ha eliminado ni modificado ningún ticket, servicio, nómina ni operación financiera de origen. La equivalencia americano/Celanese vive en el motor documentado; los importes se obtienen de ventas, no de una tarifa sembrada.

## PDF por empresa y periodo

La [auditoría de nómina y soporte del 22/09/2026](AUDITORIA_NOMINA_COMPARTIDA_2026-09-22.md) documenta la exclusión de los cheques DICSA para fondeo de nómina/caja y el posterior cambio de nómina RH a proporciones de actividad. Los otros gastos administrativos conservan sus bases actuales.

En la vista operativa: seleccionar el periodo, abrir una empresa y pulsar **Generar PDF**. El diálogo permite elegir dónde guardarlo. El nombre incluye la empresa y las fechas del corte. Cancelar no guarda el archivo; un error permite reintentar. Si falla la actualización de una fuente, se suspende la exportación hasta recuperar la lectura.

El documento sigue la referencia LaTeX: portada con logo y doble marco azul/cian, papel carta, marca de agua, secciones numeradas, tablas y paginación. Incluye resultado operativo, materiales y servicios, compra, personal, logística, equipo/residuos, resumen y bases principales del cálculo. Se distinguen importes registrados, repartidos y estimados. Las tres fórmulas principales de cada rubro se muestran con su importe y el resto queda cuantificado; la auditoría completa sigue disponible en la app.

`ProfitabilityPdfData` congela la empresa y el periodo de la lectura visible. Antes de exportar verifica que los componentes, líneas y totales concilien; no consulta otras fechas ni recalcula precios. El puente de costos de material más costos a nivel empresa explica el total sin duplicar cargos. El soporte compartido también queda identificado dentro del costo total. Esta función no escribe en Supabase ni incorpora tarifas del documento de referencia al modelo.

Validación inicial del PDF: 67 pruebas del módulo, análisis estático sin observaciones y compilación macOS debug. Se probó el diálogo nativo de guardado con la selección vigente, además de guardado real, cancelación, errores y recuperación de fuentes mediante widgets. El ejemplo histórico LICBOX del 21–22/09/2026 se revisó visualmente en sus siete páginas: genera $50,125.00, costo atribuido al cartón $40,965.22, costo total $42,216.45 y aporte $7,908.55. Esas cifras corresponden al reparto anterior, no a los nuevos cálculos. Se comprobó la paginación de 100 líneas con nombre de empresa extenso.

```sh
flutter test --no-pub test/direction/profitability_pdf_test.dart test/direction/profitability_export_test.dart
```

## Corrección de reparto y alcance tras la auditoría crítica

Ver [cambios, confirmaciones y verificación](CORRECCIONES_REPARTO_Y_ALCANCE_2026-09-22.md). Esta revisión conserva las reglas de material por indicación de Dirección, incorpora los alias confirmados y evita sumar como otros gastos las facturas de material ya cubiertas por tickets. Los centros VH y Mazatlán siguen incluidos.

## Nómina y reservas históricas: conciliación posterior

Ver [comparación sobre fuentes idénticas](CONCILIACION_INCREMENTO_COSTOS_2026-09-22.md). Las líneas de RH se distinguen de cargas laborales de Finanzas y gastos administrativos. El entero FONACOT de $3,613.76 del 01/09 confirmado como retenciones no se suma como costo. Las reservas históricas ya incluidas y el aporte antes de ellas se muestran expresamente; no son nuevos cargos comprobados del corte.
