# Aporte de las páginas de DICSA al análisis por empresa

Anexo del [diagnóstico y diseño](RENTABILIDAD_POR_EMPRESA_2026-09-21.md), con corte del 21/09/2026. Revisión del flujo de datos y cálculo en código, apoyada por consultas de lectura; no es una certificación visual ni prueba integral de cada pantalla.

El inventario abarca los 75 archivos `*page.dart` de las áreas de negocio revisadas, además de páginas/clases y pestañas compartidas dentro de esos archivos. Login, selección de rol, animaciones y componentes visuales no son fuentes económicas. Un dashboard, su detalle y su PDF no representan operaciones adicionales.

**Operación, báscula y almacén**

Referencias: [páginas y grids de Operación](../../lib/app/services), [dashboard operativo](../../lib/app/dashboard/dashboard_page.dart).

| Página o vista | Aporte y regla de integración |
|---|---|
| Dashboard Operación | Indicadores de material, producción, patio y pendientes. Usar como conciliación y acceso a detalle; no sumar indicadores encima de sus movimientos. |
| Entradas y salidas (`InventoryPage` / `InventoryMovementsGrid`) | Fecha, contraparte, material, pesos, unidad, chofer y referencias. Base física para saber qué originó cada empresa. El importe expresado en `total_amount_kg` sigue siendo kg. Falta relación inequívoca con el ticket comercial para demostrar el costo. |
| Producción (`InventoryProductionPage` / transformación V2) | Insumo, salida comercial, turno y unidades/pacas. Sirve para costos de proceso y mezcla de recuperación. La entrada puede completarse con el peso de salida: un 100% registrado no demuestra ausencia de merma. |
| Inventario (`InventoryStockPage` / stock V2) | Existencias de material general y comercial, movimientos y cortes. Se necesita para separar vendido de pendiente de vender. Agregar valuación y procedencia; no contar traslados de general a comercial como nuevas compras. |
| Programación de viajes y servicios | Empresa, fecha prevista, material, unidad, chofer y estado. Es la misma fuente `services` utilizada en Control Diario de Logística. Un viaje programado no es servicio ejecutado ni costo de combustible probado. |
| Pesadas | Registra fecha, ticket, proveedor y precio de la pesada. Es una actividad/servicio independiente que debe verificarse como ingreso de báscula, sin confundir su precio con el precio por kg del material. |
| Almacén | Artículos, entradas/salidas, cantidades, área, responsable, motivo y cortes. Permite asignar consumibles efectivamente usados, pero necesita costo unitario y vínculo a compra. Las existencias compradas y no consumidas no son automáticamente gasto del periodo. |
| Catálogos de Operación | Sitios, materiales, empleados, unidades y otras listas operativas. Proporcionan llaves y unidades. Un material general no sustituye la calidad comercial usada para fijar precios. |
| Directorio de Operación | Contactos, áreas y especialidades. Facilita responsable y seguimiento; no genera un costo por sí mismo. |

**Mantenimiento y órdenes de compra**

Referencias: [Mantenimiento](../../lib/app/maintenance/maintenance_page.dart), [órdenes de compra](../../lib/app/maintenance/purchase_orders_page.dart).

| Página o vista | Aporte y regla de integración |
|---|---|
| Mantenimiento / OT | Costos estimados y reales, equipo, materiales, trabajo, tiempos y estados. El formulario guarda la unidad seleccionada en `equipment_id`; 152 OT tienen ese campo. No buscar únicamente `vehicle_id`, que está vacío en el historial consultado. |
| Reportes dentro de Mantenimiento | Resúmenes por equipo/mecánico/estado ayudan a comparar costo y disponibilidad. Deben derivarse de la misma OT; no son otra bolsa de gastos. |
| Órdenes de compra | Destino, proveedor, partidas, importe real, aprobación y compra. `target_label` debe traducirse a activo/centro/empresa cuando sea posible. Una compra vinculada a OT y pagada en caja es un solo hecho económico. |

**Logística**

Referencias: [Rendimiento](../../lib/app/logistica/logistics_performance_page.dart), [fuente de diésel](../../lib/app/logistica/logistics_diesel_store.dart), [fuente de gasolina](../../lib/app/logistica/logistics_gasoline_store.dart), [Control Diario](../../lib/app/logistica/logistics_control_daily_page.dart).

| Página o vista | Aporte y regla de integración |
|---|---|
| Dashboard Logística | Actividad de servicios y combustible. Útil para detectar cobertura y pendientes; sus litros no son todavía costo en pesos por empresa. |
| Control Diario | Reutiliza `ServicesPage`. Da la empresa atendida y los recursos programados; usar estados ejecutados y conservar cancelaciones con costo real separado. |
| Consumo de Diésel | Compras al tanque, solicitudes/cargas, saldo de litros, unidad y operador. No tiene precio por litro, empresa ni viaje; monetización y reparto son trabajo pendiente. |
| Control de Gasolina | Litros cargados a unidad, operador, origen y notas. Conciliar el importe con comprobantes y consumo; no sumar toda la factura y los litros valuados como cargos distintos. |
| Rendimiento | Une kilometraje, combustible y destinos por unidad/día. Solo genera filas a partir del kilometraje, por lo que una carga sin registro de km puede quedar fuera de esa vista. No calcula costo ni distribución por empresa. La relación km/carga del día tampoco equivale siempre al rendimiento físico de un intervalo de tanque. |
| Ahorro y Planeación | Cruza programación, zonas y empresas para sugerir agrupaciones. Puede servir al simulador de frecuencias/rutas; una sugerencia no equivale a ahorro conseguido. |
| Catálogos Operativos | Empresas, ubicación, ventanas, zonas, choferes, unidades, compatibilidades y contenedores. Aporta restricciones reales del servicio. La tabla de contenedores tiene cero filas visibles; no afirmar que los recursos estacionados en clientes ya estén valuados. |
| Estado de Unidades — entrada de menú | En el flujo revisado muestra aviso de una siguiente fase. No tomar su presencia en navegación como un módulo terminado de disponibilidad/costos. |
| Incidencias — entrada de menú | En el flujo revisado muestra aviso de habilitación pendiente. Los costos por retraso, espera y reprogramación necesitarán evidencia disponible o captura específica. |

**Recursos Humanos**

Referencias: [Nómina](../../lib/app/hr/human_resources_nomina_page.dart), [Prenómina](../../lib/app/hr/human_resources_prenomina_page.dart), [componentes de RH](../../lib/app/hr).

| Página | Aporte y regla de integración |
|---|---|
| Dashboard RH | Periodos, incidencias, vacaciones y pendientes. Indica estado de captura, no costo completo de personal por empresa. |
| Personal | Empresa actual, salario y condición laboral. Base para asignación futura y personal dedicado. El análisis histórico debe respetar el periodo y empresa guardados en nómina. |
| Asistencia | Días, entradas/salidas, retardos y horas extra. Base de tiempo, sin atribución directa a cada servicio; requiere repartir al personal que atiende varias empresas. |
| Incidencias de asistencia | Ajustes y hechos de la jornada. Ayuda a explicar costo/productividad. Una incidencia ya incluida en nómina no se suma de nuevo como gasto. |
| Prenómina | Desglose y revisión de importes. Sirve para escenarios o previsión mientras está abierta; marcarla como provisional. |
| Nómina | Periodo, empresa histórica, publicación/cierre, fiscal, efectivo, complementos y deducciones. Fuente primaria del desembolso del periodo; construir encima la conciliación a costo laboral. Cheque fiscal y Flujo se traslapan. |
| Vacaciones | Fechas, eventos, cálculos y pagos. Impacta disponibilidad, prestación y costo. Evitar sumar el pago y el mismo importe incorporado a nómina o provisión. |
| Permisos | Ausencias y condiciones con impacto en periodo. Explican tiempo y costo; no son un gasto independiente automáticamente. |
| Préstamos y fondo | Capital prestado y recuperación. Separar activo/flujo de remuneración: recuperar un préstamo no hace más barato el trabajo del empleado. |
| Finiquitos/bajas | Costos de terminación y movimientos de personal. Usar en escenario de salida solo cuando realmente se originen por esa decisión; no repartir todos los finiquitos históricos a clientes actuales. |

**Compras Mayoreo**

Referencias: [tickets](../../lib/app/compras/compras_tickets_store.dart), [catálogos y precios](../../lib/app/compras/compras_data_store.dart).

| Página | Aporte y regla de integración |
|---|---|
| Dashboard Compras | Volumen, actividad y situación comercial. Contrastar con tickets; no usar totales de dashboard como una segunda fuente de costo. |
| Tickets | Proveedor/material, neto, humedad, basura, kg pagables, precio histórico, prima e importe. Fuente primaria de compra comercial. Distinguir kilos físicos de kilos pagables. |
| Catálogo | Proveedores, materiales y relación de precios. La empresa proveedora debe mapearse a la planta de Operación cuando corresponda. |
| Ajustes de precio | Vigencia e historial comercial. Útil para renegociación y simulación. No recalcular con el precio actual compras que ya ocurrieron. |
| Directorio de proveedores | Identidad y datos comerciales. Fuente para resolver alias y contexto; no demuestra por sí sola que dos nombres sean la misma planta. |

**Ventas Mayoreo**

Referencias: [Reporte de ventas](../../lib/app/mayoreo/mayoreo_sales_report_page.dart), [cuentas](../../lib/app/mayoreo/mayoreo_accounts_page.dart), [reglas de cobranza](../../lib/app/mayoreo/mayoreo_expected_collections.dart).

| Página | Aporte y regla de integración |
|---|---|
| Dashboard Ventas Mayoreo | Actividad, cartera y cobranza. Separar valor vendido, pendiente y cobrado. |
| Reporte de ventas | Cliente, remisión, material y peso/precio/importe aprobados. Fuente de ingreso comercial y de referencias ponderadas. No sustituir aprobación pendiente por salida de báscula en el cálculo definitivo. |
| Cuentas | Documentación, vencimiento, saldo y liquidación. Aporta capital ocupado y comportamiento de cobro. Los abonos bancarios asociados sustituyen el pago capturado según la regla actual; no sumarlos dos veces. |
| El Palomar | Cuenta auxiliar con cheques, aplicaciones de remisiones y ajustes. `source_report_id` vincula remisiones ya presentes en ventas. Financiamiento recibido no es venta nueva ni utilidad. |
| Catálogo | Clientes, materiales y tarifas. Define calidad y canal de referencia. Catálogo no equivale a venta efectiva. |
| Ajustes de precio | Escenarios de venta y vigencia. Distinguir tarifa vigente de importe realmente aprobado en la remisión. |

**Menudeo**

Referencias: [tickets](../../lib/app/menudeo/menudeo_tickets_page.dart), [Ventas como reutilización de Tickets](../../lib/app/menudeo/menudeo_sales_page.dart), [gastos](../../lib/app/menudeo/menudeo_deposits_expenses_page.dart).

| Página | Aporte y regla de integración |
|---|---|
| Dashboard Menudeo | Compra, venta, caja y pendientes. Reconciliar por fecha y corte; no sumar tickets y movimientos de caja sin identificar el mismo hecho. |
| Tickets de compra | Importe histórico, contraparte, calidad, neto/pagable y estado. Sirve a precio y costo por empresa. Revisar posibles coincidencias con Compras Mayoreo sin deduplicar por folio aislado. |
| Ventas | La misma pantalla Tickets con `flow=sale`. Es otra dirección comercial de `men_tickets`, no una tabla independiente. |
| Gastos y depósitos | Renglones con empresa, unidad, chofer, destino, concepto e importe. Fuente directa cuando la atribución esté capturada. El campo `unit` se usa también como código de vehículo; no interpretarlo siempre como unidad física de cantidad. |
| Cortes de caja | Cierre, diferencias y control de efectivo. Aporta conciliación y confiabilidad. Una diferencia de caja debe investigarse, no asignarse arbitrariamente a una generadora. |
| Catálogo | Contrapartes, relaciones de material y precios. Aprovechar IDs; `site_id` solo está poblado en 5 contrapartes del universo consultado. |
| Ajustes de precio | Cambios históricos y precios vigentes. Útil para simular renegociación sin alterar tickets anteriores. |
| Catálogo/taxonomía de caja | Clasificación de rubros, conceptos y campos. Normalizar rubros equivalentes y distinguir gasto, compra, nómina, interno y capital. No convertir un catálogo en un hecho económico. |

**Finanzas**

Referencias: [Bancos](../../lib/app/finanzas/finanzas_bank_accounts_store.dart), [identidades](../../lib/app/finanzas/finanzas_company_identity.dart), [presupuesto](../../lib/app/finanzas/finanzas_payment_center_budget_loader.dart).

| Página | Aporte y regla de integración |
|---|---|
| Dashboard Finanzas | Obligaciones, vencimientos y liquidez. Sirve para capital requerido; no sustituye el estado económico por empresa. |
| Cuentas bancarias | Movimientos, categoría, contraparte y vínculos a factura/cuenta/pago fijo. `company` es DICSA/VH y `branch` la sucursal propia. Necesita beneficiario del costo y conciliación con hechos comerciales. |
| Cuentas de proveedores | Facturas, saldos, convenios y asociación a tickets. Una factura originada en tickets no crea otra compra. Las facturas manuales sí necesitan clasificar si son gasto, inventario, activo u otra obligación. |
| Pagos fijos | Compromisos recurrentes. Sirven a previsión y a repartir costo del periodo de servicio; un pago planificado no equivale automáticamente a gasto consumido. |
| Centro de pagos | Programación, prioridades, reservas y presupuesto. Fuente de flujo futuro. No usar reservas o propuestas como costo adicional a la factura. |
| Catálogo | Empresas, conceptos y relaciones de clasificación. La identidad canónica de Finanzas ya ayuda, pero no conecta por sí sola todas las plantas, RH y Logística. |
| Directorio de empresas | Datos maestros de contrapartes. Apoya el mapa común y condiciones; requiere separar proveedor de combustible de empresa que consumió el servicio. |

**Contabilidad**

Referencias: [pantalla de resultados](../../lib/app/contabilidad/contabilidad_income_statement_page.dart), [motor](../../lib/app/contabilidad/contabilidad_income_statement_store.dart), [navegación](../../lib/app/contabilidad/contabilidad_area_chrome.dart).

| Página o entrada | Aporte y regla de integración |
|---|---|
| Dashboard Contabilidad | Presenta los módulos y su intención. Su descripción no sustituye revisar el método que realmente invoca la pantalla. |
| Flujo General / Análisis de Flujo | Consolida Bancos, Bóveda y Caja; interpreta y concilia internos. Útil para dinero disponible y control. Las reglas de clasificación y coincidencias deben permanecer visibles. |
| Estado de Resultados | La pantalla utiliza `loadSimplified`: entradas/salidas bancarias y vales, agrupados por categoría/rubro. No incorpora directamente el costo laboral de RH ni el consumo de Logística. El método comercial más amplio del mismo archivo no es el utilizado por esta pantalla. No usar sus etiquetas de utilidad como resultado económico definitivo por empresa. |
| Resultado Comercial / Compra–Venta | Reutiliza la pantalla de Dirección y `CommercialStore`. Calcula compra/venta ponderada y diferencias por material. Buena pieza reutilizable; todavía no es resultado después de atención ni costo del inventario vendido. |
| Análisis de Gastos — entrada de menú | En la navegación revisada el callback es opcional y cae en `_noop`; no se encontró una pantalla funcional independiente conectada desde el dashboard. Es una pieza pendiente, aunque existan desgloses en otras pantallas. |
| Confiabilidad — entrada de menú | Mismo patrón de acceso sin pantalla independiente conectada en el flujo revisado. Los controles del nuevo análisis necesitan implementación explícita. |

**Desarrollo Comercial**

Referencias: [repositorio/vistas comerciales](../../lib/app/commercial/commercial_store.dart), [directorio](../../lib/app/commercial/commercial_directory_page.dart).

| Página | Aporte y regla de integración |
|---|---|
| Dashboard Desarrollo Comercial | Seguimientos, prioridades y cuentas. Puede presentar las acciones sugeridas por rentabilidad; no aporta por sí mismo costos. |
| Radar Comercial | Eventos y comparativos de compras/ventas por canal, material y contraparte. Reutilizar filtros y ponderados, endureciendo aprobación/calidad y corte temporal. |
| Directorio Comercial | Cuentas, contactos, origen, tipo y prioridad. Candidato para enlazar la relación comercial con una identidad común, preservando planta y rol. |
| Agenda Comercial | Visitas, cotizaciones y seguimiento. Sirve para ejecutar la renegociación y registrar acuerdos; una cotización no es ingreso reconocido. |

**Dirección**

Referencias: [dashboard general](../../lib/app/dashboard/general_dashboard_page.dart), [análisis Menudeo](../../lib/app/direction/analysis/menudeo), [Embarques](../../lib/app/direction/direction_shipments_page.dart), [Proyección](../../lib/app/direction/direction_projection_page.dart).

| Página o vista | Aporte y regla de integración |
|---|---|
| Dashboard Dirección | Reúne indicadores multiárea. Lugar natural para un resumen de rentabilidad, reutilizando el motor del detalle. Evitar sumar los totales de sus tarjetas entre sí. |
| Bóveda / Entradas y salidas de efectivo | Vales y renglones transaccionales, rubro, empresa e importe. Fuente de comprobación de gastos y pagos. Separar movimientos internos y costos ya reconocidos en RH/compras. |
| Taxonomía de Bóveda | Definiciones de rubro, concepto y opciones. Homologar con Caja/Bancos sin asumir que todo egreso es gasto. |
| Análisis Menudeo — Mercado | Precios, contrapartes y cambios. Referencia comercial por material, no contribución neta por empresa. |
| Análisis Menudeo — Operación | Volúmenes, recurrencia y actividad. Complementa productividad y concentración; no es una entrada adicional de inventario. |
| Análisis Menudeo — Caja | Rubros, vales y cortes. Útil a conciliación, no sumable como costo adicional al mismo vale original. |
| Compra–Venta | Pantalla compartida con Contabilidad. Ya proporciona promedios ponderados; exige homologación de calidad y fuentes antes de usarla para recomendar continuidad. |
| Seguimiento de Mantenimiento | Consume las mismas OT, pendientes y prioridades. Ayuda a estimar disponibilidad e impacto de reasignar capacidad. |
| Seguimiento/Autorización de órdenes de compra | Lee las mismas órdenes y partidas de Operación. La autorización no es un gasto realizado ni otro registro económico independiente. |
| Embarques — planeación | Material, cliente y programa de salidas. Fuente de escenarios de utilización de capacidad, no de ventas realizadas por sí sola. |
| Embarques — Programa operativo | Producción necesaria, turnos, maquinaria, inventario y metas. Permite comprobar si una alternativa de negocio cabe realmente en la capacidad disponible. |
| Proyección — Ingresos | Embarques guardados, cobranza, ventas vinculadas y financiamiento de El Palomar. Distingue ingreso esperado, cobro pendiente y financiamiento; no sumarlos como utilidad. |
| Proyección — Egresos | Propuesta de pagos, ajustes y obligaciones. Estima necesidades de caja, sin crear nuevos gastos económicos. |
| Proyección — Flujo semanal | Saldos y cobros/pagos pendientes. Complementa viabilidad financiera de la empresa; no mide su contribución por origen. |

**Gerencia y supervisión**

Referencias: [seguimiento semanal de pacas](../../lib/app/gerencia/gerencia_bale_weekly_tracking_store.dart), [reportes](../../lib/app/management_reports).

| Página | Aporte y regla de integración |
|---|---|
| Dashboard Gerencia | Producción y cumplimiento. Útil para revisar capacidad y metas después de priorizar empresas; no constituye venta. |
| Seguimiento semanal de pacas | Metas, producción y turnos. Puede alimentar reparto de proceso y escenarios, pero necesita bases de consumo/horas y costos consistentes. |
| Supervisión / Reportes por área | Ya combina fuentes operativas, comerciales y financieras. Reutilizar extracción, controles, cortes y exportación. El diferencial comercial de $1/kg usado en una lógica de Menudeo no es costo completo ni regla universal de continuidad. |

**Gestión Documental**

Referencias: [catálogo de categorías](../../lib/app/gestion_documental/gestion_documental_catalog.dart), [tipos implementados](../../lib/app/gestion_documental/gestion_documental_records.dart), [repositorio](../../lib/app/gestion_documental/gestion_documental_store.dart).

Dashboard, Calendario y el contenedor de categorías comparten el repositorio documental. Los once tipos de expediente están representados en código; la consulta solo encontró datos en Legal y Medio Ambiente.

| Página o categoría | Aporte y regla de integración |
|---|---|
| Dashboard Documental | Cobertura y vencimientos. Sirve a confiabilidad contractual, no a valor económico por sí solo. |
| Calendario | Fechas y renovaciones. Usar para horizonte de decisión y compromisos. No deducir una penalización de una fecha sin leer el acuerdo. |
| Documentación Legal | Sustenta identidad y facultades. No demuestra equivalencias entre plantas o calidad de cliente por sí sola. |
| Permisos y Trámites | Costos y condiciones de continuidad si están documentados. Requiere expediente/evidencia, no asumir captura por existir pantalla. |
| Seguridad e Higiene | Obligaciones de personal/operación que pueden originar costos directos o compartidos. No asignar importes sin comprobante. |
| Medio Ambiente | Condiciones y obligaciones de manejo que pueden cambiar el costo por material/empresa. La revisión no determinó costos a partir del único expediente visible. |
| Vehículos | Permisos y documentación de unidades; posibles restricciones de ruta/capacidad. No sustituye el costo del activo. |
| Personal | Expedientes vinculados a RH; apoya vigencia y restricciones, sin duplicar nómina. |
| Protección Civil | Requisitos por instalación y costos compartidos verificables. |
| Contratos | Fuente necesaria para exclusividad, frecuencia mínima, precio, vigencia, renovación y salida. No había registros visibles de esta categoría al consultar. |
| Seguros | Cobertura y sujeto asegurado para distribuir costos del periodo. Sin expedientes visibles no afirmar que las primas estén integradas. |
| Mantenimiento documental | Programas y certificaciones; distinto de ejecutar una OT y consumir materiales. |
| Auditorías | Hallazgos y acciones que condicionan continuidad/calidad de información. No equivalen a una provisión monetaria automática. |

**Puntos técnicos que condicionan la consolidación**

La extracción nueva debe ser estricta, paginada y filtrada por corte. Hay módulos que ya usan `fetchAllSupabaseRows`, pero Rendimiento tiene lecturas directas de servicios y kilometraje sin paginación explícita. No construir el histórico financiero capturando lo que alcanzó a cargar la pantalla.

La vista comercial usa una unión de canales y tiene sustituciones de peso/precio aprobado por datos de salida/catálogo. Para resultado realizado se deben separar datos definitivos y provisionales. También debe aplicarse fecha de corte explícita: la pantalla Compra–Venta puede basar su ventana en la última fecha registrada, y hay una venta futura en la base revisada.

Las corridas con salida superior a entrada se concentran en abril. Esto no prueba que la operación física generara material: requiere revisar migración/captura y unidades. Las corridas con igualdad tampoco prueban medición independiente, porque el formulario puede copiar la salida a la entrada. No convertir esos cocientes automáticamente en rendimientos por proveedor.

El campo `scale_ticket` está vacío en los 10,699 movimientos de inventario consultados; puede existir información en otras referencias, pero no hay enlace estructurado al ticket comercial demostrado por ese campo. La relación lote de origen → transformación → venta requiere validación adicional antes de declarar utilidad realizada por generadora.

El análisis se puede construir aprovechando las fuentes actuales. Los trabajos nuevos son el mapa de identidades, el registro de atribución, las reglas de reconocimiento/reparto, la conciliación y la vista de decisión. No hace falta crear un segundo sistema de captura de compras, ventas o nómina.
