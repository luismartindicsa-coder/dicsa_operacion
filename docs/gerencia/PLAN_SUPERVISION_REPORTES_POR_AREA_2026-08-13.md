# Plan Maestro: Supervision por Reportes de Area

Fecha: 2026-08-13

## Vision de gestion

Este plan parte de una idea central:

- la gestion no es apagar incendios
- la gestion no es ejecutar por otros
- la gestion profesional es disenar, priorizar, coordinar, desarrollar y supervisar
- el fracaso operativo casi nunca nace de la gente; normalmente nace de la falta de sistema

La app debe ayudar a que la supervision deje de depender de urgencias, memoria o persecucion manual.

La supervision correcta para este contexto debe construir:

- seguridad operativa
- claridad en roles y metas
- confianza y credibilidad
- comunicacion abierta y asertiva
- compromiso con el proposito del area
- seguimiento metodico, no supervision tradicional reactiva

La consecuencia de producto es clara:

- cada area debe tener reportes ejecutivos cortos, comparables y accionables
- los reportes deben salir de datos ya capturados o de capturas formales controladas
- el gerente no debe resolver todo; debe leer, decidir, asignar, dar seguimiento y supervisar

## Objetivo del producto

Construir dentro de `apps/dicsa_operacion` una superficie de `Supervision` donde cada area tenga botones para generar reportes en PDF.

Los reportes seran de dos tipos:

- `Diario`
- `Semanal Viernes`

Regla de calendario:

- si un punto dice `Diario`, debe estar disponible todos los dias
- si un punto dice `Viernes`, forma parte del cierre semanal y de la junta del viernes
- si un punto no indica dia, por ahora se considera `Viernes`
- el primer corte semanal de arranque, con la fecha actual, corresponde al viernes `2026-08-14`

## Resultado esperado en la app

### 1. Nueva superficie de supervision

Ubicacion recomendada:

- `Dashboard General -> Supervision`

Acceso secundario recomendado:

- `Gerencia -> Supervision por Areas`

Acceso obligatorio adicional:

- cada `Dashboard de Area` debe tener sus propios botones de generacion de reportes

Esto crea un modelo de doble entrada:

- `Supervision` como vista central de gerencia
- `Dashboard de Area` como punto de trabajo del responsable directo

La pantalla debe vivir como un hub ejecutivo y no como otro dashboard operativo pesado.

### 2. Cada area tendra una tarjeta

Cada tarjeta de area debe mostrar:

- nombre del area
- responsable del area
- estatus de captura
- semaforo de completitud
- ultimo reporte diario generado
- ultimo reporte semanal generado
- botones de generacion

Botones minimos por area:

- `Generar diario`
- `Generar viernes`
- `Ver historial`

Estos mismos botones deben existir tambien dentro del dashboard correspondiente del area.

Ejemplos:

- `FinanzasDashboardPage`
- `LogisticsDashboardPage`
- `GerenciaDashboardPage`
- `HumanResourcesDashboardPage`
- dashboards equivalentes de las demas areas

Si un area no tiene reportes diarios, el boton diario no se muestra.

Si un area sigue pendiente de modelado, el boton debe existir solo como placeholder bloqueado con leyenda:

- `Pendiente de fuentes`

## Modelo de adopcion y delegacion

La implementacion debe respetar una transicion de responsabilidad:

### Etapa 1. Generacion dirigida por gerencia

Al inicio, los reportes seran generados por gerencia o direccion para:

- revisar que el contenido si sirva
- validar que los datos esten bien interpretados
- presentarlos junto con el encargado del area

### Etapa 2. Generacion compartida

Despues, cada encargado de area debe poder:

- generar su propio reporte
- estudiarlo antes de la junta
- preparar explicacion de desviaciones
- llegar con pendientes y propuestas

### Etapa 3. Presentacion liderada por el area

La meta final del sistema es que cada area:

- genere sus reportes sin depender de gerencia
- los entienda
- los presente
- asuma responsabilidad por sus acciones de seguimiento

Gerencia entonces deja de ser capturista o perseguidor y se enfoca en:

- cuestionar
- priorizar
- coordinar
- decidir
- supervisar cumplimiento

### 3. Cada reporte PDF debe responder cuatro cosas

Todo PDF debe responder, sin perderse en detalle:

1. Que paso.
2. Que se desvio.
3. Que requiere decision.
4. Quien es responsable del siguiente paso.

Esto evita reportes llenos de numeros sin gestion.

## Principios funcionales del sistema

### Gestion por sistema

El sistema debe obligar a que cada reporte tenga:

- fuente de datos clara
- responsable de lectura
- frecuencia
- KPIs
- alertas
- pendientes
- fecha de corte

### No duplicar captura

Si una fuente ya existe en otra area:

- `Operacion`
- `Pesadas`
- `Inventario`
- `Logistica`
- `Finanzas`
- `RH`
- `Menudeo`
- `Contabilidad`

entonces `Supervision` solo la lee y la resume.

### Datos primero, opinion despues

Cada PDF debe separar:

- `Hechos`
- `Alertas`
- `Pendientes`
- `Decisiones sugeridas`

### Reporte corto y repetible

Un reporte ejecutivo no debe intentar reemplazar la operacion fuente.

Debe dejar listo:

- el resumen
- la excepcion
- la asignacion
- el seguimiento

## Arquitectura recomendada

## Capa 1. Catalogo de reportes

Se recomienda modelar un catalogo central de definiciones de reporte.

Entidad sugerida:

- `management_report_catalog`

Campos sugeridos:

- `id`
- `area_key`
- `report_key`
- `title`
- `frequency`
- `day_rule`
- `is_enabled`
- `owner_role`
- `data_status`
- `sort_order`
- `pdf_template_key`
- `notes`

Valores ejemplo:

- `frequency`: `DAILY`, `WEEKLY`
- `day_rule`: `ANY_DAY`, `FRIDAY_ONLY`
- `data_status`: `READY`, `PARTIAL`, `PENDING`

## Capa 2. Ejecucion del reporte

Entidad sugerida:

- `management_report_runs`

Campos sugeridos:

- `id`
- `catalog_id`
- `area_key`
- `report_key`
- `range_start`
- `range_end`
- `generated_at`
- `generated_by`
- `status`
- `source_snapshot_json`
- `summary_json`
- `pdf_file_name`
- `pdf_storage_path`
- `warnings_json`

Esto permitira:

- historial
- auditoria
- comparar versiones
- reconstruir que vio gerencia en una fecha concreta

## Capa 3. Motor de construccion

Se recomienda una capa compartida en Flutter para:

- resolver rango de fechas
- leer fuentes
- normalizar datos
- calcular KPIs
- generar resumen
- construir PDF

Estructura sugerida:

- `lib/app/management_reports/management_report_catalog.dart`
- `lib/app/management_reports/management_report_models.dart`
- `lib/app/management_reports/management_report_runner.dart`
- `lib/app/management_reports/management_report_pdf_builder.dart`
- `lib/app/management_reports/management_supervision_page.dart`

Subcarpetas por area:

- `lib/app/management_reports/operations/...`
- `lib/app/management_reports/bascula/...`
- `lib/app/management_reports/logistica/...`
- `lib/app/management_reports/menudeo/...`
- `lib/app/management_reports/rh/...`
- `lib/app/management_reports/ventas/...`
- `lib/app/management_reports/gastos/...`
- `lib/app/management_reports/gestion/...`
- `lib/app/management_reports/finanzas/...`
- `lib/app/management_reports/gerencia/...`
- `lib/app/management_reports/desarrollo_comercial/...`
- `lib/app/management_reports/direccion_general/...`
- `lib/app/management_reports/contabilidad/...`

## Capa 4. PDF estandar ejecutivo

Todos los PDFs deben compartir una estructura homologada:

1. Portada corta
2. Resumen ejecutivo
3. KPIs
4. Hallazgos y alertas
5. Tabla detalle
6. Pendientes y responsables
7. Nota de trazabilidad

Campos fijos recomendados en encabezado:

- area
- nombre del reporte
- rango de corte
- fecha y hora de generacion
- usuario que lo genero
- estado de confiabilidad del dato

### Contrato visual del PDF

El PDF de supervision no debe sentirse como poster ni como dashboard impreso.

Debe sentirse como:

- ficha ejecutiva limpia
- hoja blanca estable
- lectura rapida para junta
- identidad clara del area

Reglas obligatorias:

- fondo general blanco liso
- portada corta
- encabezado dentro de una tarjeta blanca con borde suave
- nombre del reporte visible desde arriba
- area y fecha de corte visibles desde arriba
- badges de contexto compactos y legibles
- jerarquia visual sobria antes que decorativa

El encabezado debe incluir:

- leyenda corta tipo `Reporte de seguimiento`
- nombre del area
- nombre especifico del reporte
- subtitulo de una sola idea
- fecha o rango de corte
- fecha y hora de generacion
- responsable del area

Elementos prohibidos:

- usar isotipos, logos o ilustraciones como fondo de pagina
- meter arte decorativo gigante detras del contenido
- convertir la portada en una composicion visual pesada
- usar recursos que puedan escalarse de forma impredecible y romper la hoja

Aprendizaje operativo consolidado el lunes `2026-08-17`:

- el logo o wordmark, si existe, debe vivir solo dentro del header
- nunca debe funcionar como background
- cualquier recurso grafico del header debe tener caja fija y tamano controlado

### Regla de color por area

Todos los reportes de supervision deben diferenciarse visualmente por area sin cambiar el arquetipo base del PDF.

Esto significa:

- la estructura del PDF permanece homologada
- lo que cambia entre areas es el color acento del reporte

El color del area debe vivir en:

- eyebrow o etiqueta superior
- borde o acento del header
- badges de contexto
- headers de tabla
- tarjetas KPI
- detalles de resaltado y alertas cuando aplique

Lo que no debe cambiar por area:

- fondo general
- layout
- radios base
- espaciado
- patron de secciones
- comportamiento de tablas

Regla practica:

- si alguien ve el PDF de lejos, debe distinguir rapido de que area es por el color
- si alguien compara dos PDFs, debe reconocer que ambos pertenecen al mismo sistema porque comparten exactamente el mismo arquetipo

Fuente de verdad para el color del reporte:

- el accent oficial del area en `management_reports_registry.dart`
- o el token homologado del area cuando exista contrato mas formal

No se permite:

- inventar una paleta nueva solo para un reporte aislado
- usar un color que contradiga la identidad visual del area
- compensar con background decorativo lo que debe resolverse con un acento claro y controlado

### Regla de detalle ejecutivo

El PDF debe resumir todo el universo del corte, pero no esta obligado a imprimir todas las filas visibles si eso destruye la lectura ejecutiva.

Se permite:

- mostrar top areas
- mostrar top equipos
- mostrar solo los casos mas riesgosos
- resumir el resto en KPIs y notas de trazabilidad

Esto debe quedar explicitado cuando aplique:

- cuantas filas se muestran
- cuantas filas totales existen
- que el resto ya esta resumido en KPIs, alertas o agregados

## Capa 5. Estado de confiabilidad

Cada reporte debe llevar semaforo de calidad:

- `Verde`: fuente completa y consistente
- `Amarillo`: fuente parcial o con faltantes conocidos
- `Rojo`: reporte incompleto o sin fuente confiable

Esto es clave para no dirigir con falsa certeza.

## Experiencia de usuario recomendada

## Pantalla principal

La pantalla `Supervision` debe dividirse en:

### A. Encabezado ejecutivo

Debe mostrar:

- fecha actual
- semana operativa activa
- porcentaje de reportes al dia
- reportes faltantes
- areas con alertas

### B. Grilla de areas

Cada area en una card con:

- responsable
- reportes disponibles
- ultimo corte
- semaforo
- accesos rapidos

### C. Cola de pendientes

Lista global de seguimiento:

- reportes no generados
- reportes con datos incompletos
- reportes con alertas rojas
- reportes que requieren decision gerencial

### D. Historial

Vista de historial por area:

- fecha
- tipo de reporte
- usuario
- estatus
- descargar PDF

## Formato ejecutivo de cada reporte

Para evitar reportes descriptivos sin accion, cada reporte debe cerrar con:

- `Responsable`
- `Siguiente accion`
- `Fecha compromiso`
- `Bloqueo`

Si el reporte no puede producir una accion, probablemente aun no esta bien disenado.

## Experiencia en dashboard de area

Cada dashboard de area debe incluir un bloque visible de `Reportes de supervision`.

Ese bloque debe mostrar:

- boton `Generar diario` cuando aplique
- boton `Generar viernes`
- ultimo reporte generado
- estatus del corte actual
- advertencias de datos incompletos
- acceso a `Historial`

Objetivo de producto:

- que el encargado del area no tenga que salir del dashboard para preparar su junta
- que el estudio del reporte ocurra donde ya vive la operacion del area
- que la adopcion futura no dependa del dashboard central de gerencia

## Catalogo inicial por area

## 1. Operaciones

Frecuencia esperada:

- mixto diario y viernes

Reportes:

- `Seguimiento de OTs` - `Viernes`
- `OTs diarias nuevas` - `Diario`
- `Gastos en OTs` - `Viernes`
- `Incidencias en patio` - `Viernes`
- `KPIs de limpieza` - `Diario`
- `Analisis de produccion` - `Viernes`

Fuentes probables ya existentes:

- `maintenance_orders`
- `maintenance_page.dart`
- `production_runs`
- `inventory_movements_v2`
- modulos de `Operacion` y `Mantenimiento`

Valor gerencial real:

- saber avance, costo, desviacion e incidencia
- no perseguir manualmente cada OT

## 2. Bascula

Frecuencia esperada:

- viernes

Reportes:

- `Que material entro (peso y material)` - `Viernes`
- `Que material salio` - `Viernes`
- `Entradas de publico vs proveedor` - `Viernes`
- `Comparacion semana actual vs pasada` - `Viernes`
- `KPIs de errores en tickets` - `Viernes`

Fuentes probables ya existentes:

- `pesadas`
- `inventory_movements_v2`
- `weighings_page.dart`
- `inventory_movements_grid.dart`

KPIs minimos sugeridos:

- peso total entrante
- peso total saliente
- mix por material
- errores por tipo
- tickets pendientes de captura
- tickets cancelados

## 3. Logistica

Frecuencia esperada:

- viernes

Reportes:

- `Cuanto diesel se consumio` - `Viernes`
- `Cuanta gasolina se consumio` - `Viernes`
- `Que unidad consumio mas combustible` - `Viernes`
- `Numero de viajes por operador` - `Viernes`
- `Numero de viajes por unidad` - `Viernes`
- `Kilometros recorridos` - `Viernes`
- `Complicaciones con choferes` - `Viernes`
- `Complicaciones con unidades` - `Viernes`
- `Viajes cancelados` - `Viernes`
- `Destinos con mas viajes` - `Viernes`
- `KPIs de complicaciones personales con choferes, empresas y equipo DICSA` - `Viernes`

Fuentes probables ya existentes:

- `logistics_diesel_consumption`
- `logistics_gasoline_control`
- `logistics_fixed_services`
- catalogos de choferes, unidades y empresas de Logistica

Valor gerencial real:

- detectar costo, saturacion, falla recurrente y mala asignacion

## 4. Menudeo

Frecuencia esperada:

- viernes

Reportes:

- `Gastos principales` - `Viernes`
- `Compras resumidas` - `Viernes`
- `Precios ajustados` - `Viernes`
- `Proveedores ausentes` - `Viernes`
- `Comparativa semanal en kg, importe y precio` - `Viernes`
- `KPIs de caja no cuadrante en cierre` - `Viernes`

Fuentes probables ya existentes:

- `men_tickets`
- `men_cash_cuts`
- `men_cash_vouchers`
- `men_price_adjustment_history`
- analiticas ya presentes en `direction_menudeo_analysis_page.dart`

Valor gerencial real:

- entender margen, disciplina comercial y salud de caja

## 5. RH

Frecuencia esperada:

- viernes

Estatus actual:

- `PENDIENTE`

Reportes:

- `Reporte de nomina fiscal y efectivo` - `Viernes`
- `Reporte de ausencias, permisos y vacaciones` - `Viernes`
- `Incidencias frecuentes` - `Viernes`
- `Reporte de accidentes` - `Viernes`
- `Avances en reclutamiento` - `Viernes`
- `Informe de bajas` - `Viernes`
- `Plantilla por cubrir` - `Viernes`

Fuentes parciales ya existentes:

- `hr_attendance_daily_records`
- `hr_employee_permission_events`
- `hr_employee_vacation_events`
- pantallas de asistencia, permisos, vacaciones y prenomina

Bloqueo actual:

- falta homologar completamente reclutamiento, bajas y plantilla abierta

## 6. Ventas

Frecuencia esperada:

- mixto diario y viernes

Reportes:

- `Facturas y cheques pendientes de cobrar` - `Viernes`
- `Ventas pendientes de facturar o relacionar` - `Diario`
- `Atrasos en patio / motivo KPIs` - `Viernes`
- `Ajustes en precios` - `Viernes`
- `Resumen de clientes y proveedores contactados por WhatsApp` - `Viernes`
- `Analisis de tiempos de pago` - `Viernes`

Fuentes probables:

- `mayoreo_accounts`
- `mayoreo_sales_reports`
- `commercial` y `finanzas`

Bloqueos:

- WhatsApp requiere definicion de fuente formal; no debe capturarse como texto libre disperso

## 7. Gastos

Frecuencia esperada:

- mixto diario y viernes

Reportes:

- `Compras urgentes` - `Diario`
- `Real vs estimado` - `Viernes`
- `Compras ligadas a OTs` - `Diario`
- `Retroalimentacion del flujo de compras` - `Diario`
- `Compras en efectivo, tarjeta y factura` - `Viernes`

Fuentes probables:

- `compras`
- `maintenance_orders`
- `finanzas_bank_movements`
- `direction_cash_entries_exits`

Valor gerencial real:

- vigilar urgencia real contra mala planeacion

## 8. Gestion

Frecuencia esperada:

- viernes, salvo remisiones

Estatus actual:

- `PENDIENTE`

Reportes:

- `Seguimiento de permisos` - `Viernes`
- `Analisis de cantidad, material y destino de manifiestos` - `Viernes`
- `Reporte de remisiones y carta porte` - `Diario`
- `Seguimiento a apoyos y subsidios del gobierno` - `Viernes`
- `Seguimiento a cursos, vencimientos y caducidades de documentos` - `Viernes`
- `Resumenes de contratos` - `Viernes`

Bloqueo actual:

- falta aterrizar fuentes formales y catalogos documentales

## 9. Finanzas

Frecuencia esperada:

- mixto diario y viernes

Reportes:

- `Presupuesto` - `Diario y Viernes`
- `Avance de convenios` - `Viernes`
- `Forecast de pagos` - `Viernes`
- `Facturas vencidas` - `Viernes`
- `Pagos urgentes` - `Diario`
- `Flujo bancario` - `Viernes`

Fuentes ya existentes:

- `finanzas_provider_accounts`
- `finanzas_bank_movements`
- `finanzas_fixed_payments`
- `finanzas_payment_center`

Valor gerencial real:

- entender tension de caja y obligaciones reales sin improvisacion

## 10. Gerencia

Frecuencia esperada:

- viernes

Reportes:

- `Cumplimiento de metas` - `Viernes`
- `Analisis KPI de problemas en DICSA y otras empresas` - `Viernes`
- `Seguimiento a nuevos negocios` - `Viernes`
- `Cobros y pagos pendientes` - `Viernes`
- `Manejo de bonos y comisiones` - `Viernes`

Fuentes probables:

- `gerencia_bale_weekly_tracking`
- `finanzas`
- `commercial`
- futuras capturas de seguimiento comercial y de bonos

## 11. Desarrollo Comercial

Frecuencia esperada:

- viernes

Estatus actual:

- `PENDIENTE`

Reportes:

- `Reporte de visitas` - `Viernes`
- `Meta 10 prospectos nuevos a la semana` - `Viernes`
- `Agenda de convenciones` - `Viernes`
- `Agenda de nuevos contactos` - `Viernes`
- `Seguimiento a prospectos` - `Viernes`
- `Seguimiento de ventas de piezas` - `Viernes`

Bloqueo actual:

- no se detecta todavia una base CRM formal homologada

## 12. Direccion General

Frecuencia esperada:

- viernes

Reportes:

- `Analisis de produccion y embarques` - `Viernes`
- `Horarios de embarques` - `Viernes`
- `Cumplimiento de metas` - `Viernes`
- `Reportes de supervision` - `Viernes`
- `Avance en desarrollo de app` - `Viernes`

Fuentes probables:

- `production_runs`
- `inventory_movements_v2`
- `gerencia`
- historico de reportes generados
- backlog o hitos de desarrollo si se formalizan

## 13. Contabilidad

Frecuencia esperada:

- viernes o mensual segun corte

Reportes:

- `Resultado comercial`
- `Flujo general`
- `Analisis de gastos`
- `Estado de resultados`
- `Balance`

Fuentes ya encaminadas:

- `contabilidad_dashboard_page.dart`
- analisis de flujo
- analisis comercial
- estado de resultados
- bancos, boveda, compras y ventas

Nota:

- aunque el consumo gerencial puede ser en viernes, algunos de estos reportes pueden requerir corte mensual como version formal

## Priorizacion por fases

## Fase 1. Supervision base con fuentes maduras

Objetivo:

- salir rapido con reportes utiles donde ya hay datos reales y modulos vivos

Areas sugeridas:

- `Finanzas`
- `Logistica`
- `Bascula`
- `Operaciones`
- `Menudeo`
- `Gerencia`
- `Contabilidad`

Entregables:

- pantalla hub de supervision
- catalogo de reportes
- boton PDF por area
- historial de generacion
- semaforo de calidad

## Fase 2. Ventas y direccion

Objetivo:

- integrar cobranza, facturacion pendiente y lectura de direccion

Areas sugeridas:

- `Ventas`
- `Direccion General`

Bloqueo principal:

- homologar contacto comercial y pendientes de facturacion

## Fase 3. RH y Gestion

Objetivo:

- convertir procesos administrativos en seguimiento visible y comparable

Areas sugeridas:

- `RH`
- `Gestion`

Bloqueo principal:

- faltan algunas fuentes operativas y catalogos completos

## Fase 4. Desarrollo Comercial

Objetivo:

- introducir gestion de prospectos con disciplina comercial real

Bloqueo principal:

- no hay aun estructura CRM formal suficiente

## Reglas de negocio clave

### 1. El gerente no edita el dato fuente desde el PDF

El PDF es salida ejecutiva.

Si un dato esta mal:

- se corrige en el modulo fuente
- se vuelve a generar el reporte

### 2. Todo reporte debe poder regenerarse

No debe depender de texto manual pegado cada semana.

### 3. Los reportes deben guardar huella

Para cada corrida:

- quien lo genero
- cuando
- con que rango
- con que advertencias

### 4. Debe haber corte consistente

Para diarios:

- fecha actual o fecha elegida

Para viernes:

- semana operativa homologada

### 5. El sistema debe exponer faltantes

Si el reporte no puede calcular algo:

- no inventa
- lo marca como pendiente o parcial

## Modelo de PDF recomendado

Cada PDF debe incluir estas secciones:

## A. Resumen ejecutivo

- 3 a 6 hallazgos maximo

## B. KPIs

- solo los indispensables para decidir

## C. Alertas

- atrasos
- incidencias
- sobrecostos
- faltantes

## D. Tabla detalle

- soporte numerico

## E. Seguimiento

- responsable
- accion
- fecha compromiso

## F. Trazabilidad

- fuentes usadas
- hora de corte
- confiabilidad

## Riesgos que debemos evitar

- reportes largos sin accion
- duplicar captura en supervision
- mezclar datos manuales con automaticos sin etiqueta
- creer que un dashboard equivale a gestion
- depender de WhatsApp, memoria o comentarios sueltos como fuente principal
- lanzar muchas areas a la vez sin semaforo de confiabilidad

## Implementacion tecnica sugerida

## Paso 1. Crear la pantalla hub

Crear:

- `management_supervision_page.dart`

Debe mostrar areas, frecuencias y botones.

## Paso 2. Crear modelos base

Crear:

- definicion de area
- definicion de reporte
- resultado de corrida
- warning de fuente

## Paso 3. Crear builders por area

Arrancar con:

- `finanzas`
- `logistica`
- `bascula`
- `operaciones`

## Paso 4. Homologar PDF

Reusar el patron ya existente de PDFs dentro de la app:

- `direction_menudeo_analysis_page.dart`
- `finanzas_provider_accounts_page.dart`
- `maintenance_page.dart`
- `mayoreo_accounts_page.dart`

Y ademas respetar este contrato:

- mismo arquetipo ejecutivo
- fondo blanco limpio
- header compacto
- identidad del area por color acento
- sin fondos graficos gigantes
- sin logos usados como background

## Paso 5. Agregar historial

Guardar cada corrida y permitir:

- descargar
- revisar advertencias
- comparar ultimo diario y ultimo viernes

## Paso 6. Conectar a Gerencia y Dashboard General

Agregar acceso desde:

- `GerenciaDashboardPage`
- `GeneralDashboardPage`

Y agregar bloque local de reportes en cada dashboard de area prioritario de Fase 1:

- `FinanzasDashboardPage`
- `LogisticsDashboardPage`
- dashboard operativo de `Bascula`
- dashboard operativo de `Operaciones`

## Definition of done de la Fase 1

La fase 1 estara realmente terminada cuando:

1. Exista la pantalla `Supervision`.
2. Al menos 4 areas puedan generar PDF real.
3. Cada PDF tenga resumen, KPI, alertas y seguimiento.
4. Exista historial de corridas.
5. Cada reporte tenga semaforo de confiabilidad.
6. La junta del viernes pueda correr sin pedir informacion por WhatsApp o memoria para esos reportes.

## Recomendacion final de arranque

El mejor arranque no es intentar construir los 13 frentes al mismo tiempo.

El arranque correcto es:

1. `Finanzas`
2. `Logistica`
3. `Bascula`
4. `Operaciones`
5. `Gerencia`

Razon:

- ya hay fuentes mas tangibles en la app
- ya existe infraestructura PDF
- ya existe estructura de dashboards por area
- estas areas cargan mas tension directiva semanal

## Siguiente paso recomendado

Tomar este plan como contrato y construir enseguida la `Fase 1` con:

- pantalla `Supervision`
- catalogo base de reportes
- primeros 4 reportes conectados a datos reales

Orden de primera entrega sugerido:

1. `Finanzas -> Presupuesto diario y pagos urgentes`
2. `Logistica -> Diesel semanal y viajes por unidad`
3. `Bascula -> Entradas y salidas semanales`
4. `Operaciones -> OTs nuevas diarias y seguimiento semanal de OTs`
