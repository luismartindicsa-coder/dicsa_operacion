# Backlog Tecnico Area Logistica

Fecha: 2026-07-28

Documento complementario de:

- [logistica_area_plan_2026-07-28.md](/Users/martinvelzat/DICSA/apps/dicsa_operacion/docs/logistica_area_plan_2026-07-28.md)

## Objetivo de este backlog

Traducir la vision funcional de Logistica a trabajo ejecutable de producto, frontend, datos y validaciones.

Este backlog esta ordenado para construir primero la capacidad base del encargado:

- capturar servicios
- asignar chofer y unidad
- validar compatibilidad
- operar el dia con orden

Y despues abrir ahorro, zonas, contenedores y optimizacion.

## Estrategia general

Construir en cinco etapas:

1. Fundacion de datos y catalogos.
2. Control Diario de Logistica.
3. Disponibilidad, incidencias y estado de unidades.
4. Zonas, ahorro y combinacion de servicios.
5. Contenedores, mantenimiento preventivo y consolidacion.

## Etapa 1. Fundacion de datos y catalogos

Objetivo:

- dejar listo el modelo minimo para que la asignacion no sea solo manual y textual

### 1.1 Reutilizacion de catalogos actuales

Reutilizar como base:

- `employees` para choferes
- `vehicles` para unidades
- `services` para viajes y servicios
- catalogos actuales de clientes o sitios usados por Operacion

Limitacion actual:

- estos catalogos no modelan suficiente compatibilidad para Logistica

### 1.2 Nuevas entidades recomendadas

#### `logistics_vehicle_types`

Proposito:

- clasificar tipos de unidad

Campos minimos:

- `id`
- `code`
- `name`
- `requires_special_license`
- `requires_special_maneuver`
- `notes`
- `is_active`
- `created_at`
- `updated_at`

Valores iniciales sugeridos:

- `CAMIONETA`
- `CAMION`
- `TRAILER`
- `PICK_UP`
- `GRUA`

#### `logistics_load_types`

Proposito:

- clasificar tipo de carga o configuracion operativa

Campos minimos:

- `id`
- `code`
- `name`
- `requires_special_maneuver`
- `notes`
- `is_active`
- `created_at`
- `updated_at`

Valores iniciales sugeridos:

- `CONTENEDOR_CHICO`
- `CONTENEDOR_GRANDE`
- `PLATAFORMA`
- `JAULA`
- `CARGA_GENERAL`
- `GRUA_MANIOBRA`

#### `logistics_driver_profiles`

Proposito:

- extender choferes con informacion operativa propia de Logistica

Relacion:

- `employee_id -> employees.id`

Campos minimos:

- `id`
- `employee_id`
- `availability_status`
- `known_routes_notes`
- `licenses_notes`
- `is_active_for_logistics`
- `created_at`
- `updated_at`

#### `logistics_driver_unit_skills`

Proposito:

- definir que tipo de unidad puede operar cada chofer

Campos minimos:

- `id`
- `driver_profile_id`
- `vehicle_type_id`
- `skill_level`
- `restrictions_notes`
- `is_allowed`
- `created_at`
- `updated_at`

#### `logistics_driver_load_skills`

Proposito:

- definir que tipo de carga o maniobra puede cubrir cada chofer

Campos minimos:

- `id`
- `driver_profile_id`
- `load_type_id`
- `skill_level`
- `restrictions_notes`
- `is_allowed`
- `created_at`
- `updated_at`

#### `logistics_unit_load_capabilities`

Proposito:

- definir que tipos de carga soporta cada unidad o tipo de unidad

Campos minimos:

- `id`
- `vehicle_id`
- `load_type_id`
- `is_compatible`
- `restrictions_notes`
- `created_at`
- `updated_at`

#### `logistics_zones`

Proposito:

- agrupar clientes y servicios por zona operativa

Campos minimos:

- `id`
- `code`
- `name`
- `notes`
- `is_active`
- `created_at`
- `updated_at`

#### `logistics_service_templates`

Proposito:

- acelerar captura de servicios repetitivos

Campos minimos:

- `id`
- `code`
- `name`
- `service_type`
- `default_priority`
- `default_vehicle_type_id`
- `default_load_type_id`
- `estimated_duration_minutes`
- `special_conditions`
- `is_active`
- `created_at`
- `updated_at`

### 1.3 Cambios a tablas existentes

#### `vehicles`

Agregar o confirmar:

- `vehicle_type_id`
- `capacity_notes`
- `availability_status`
- `operational_status`
- `special_maneuver_notes`

#### `services`

Agregar:

- `priority`
- `request_channel`
- `requester_name`
- `requester_area`
- `origin_text`
- `destination_text`
- `zone_id`
- `requested_time_window`
- `promised_time_window`
- `required_vehicle_type_id`
- `required_load_type_id`
- `site_contact_name`
- `site_contact_phone`
- `material_ready`
- `special_conditions`
- `assigned_at`
- `departed_at`
- `arrived_at`
- `completed_at`
- `evidence_status`
- `evidence_notes`
- `odometer_start`
- `odometer_end`
- `fuel_liters`
- `fuel_amount`
- `trip_expense_amount`
- `incident_status`
- `incident_summary`
- `container_required`
- `container_count_snapshot`
- `container_capacity_snapshot`

### 1.4 Validaciones base de datos

Agregar validaciones para:

- no permitir `required_vehicle_type_id` nulo cuando el servicio lo requiera
- no permitir `required_load_type_id` nulo cuando aplique
- normalizar `priority`
- normalizar `incident_status`
- evitar estados invalidos de servicio

### 1.5 Entregables de la etapa

- migraciones nuevas
- seeds iniciales de tipos de unidad y tipos de carga
- catalogos enlazados con `vehicles` y `employees`

## Etapa 2. Control Diario de Logistica

Objetivo:

- sustituir la experiencia de `Programacion de Viajes y Servicios` por un `Control Diario` real de Logistica

### 2.1 Cambios de navegacion

Actualizar:

- nombre de modulo
- accesos
- dashboard
- rutas de entrada para roles `logistics`, `logistica`, `services`

### 2.2 Pantalla principal

Construir o evolucionar:

- `services_page.dart`

Cambios funcionales:

- header nuevo de Logistica
- filtros por prioridad, zona, tipo de unidad y tipo de carga
- vista de servicios del dia
- banda de choferes disponibles
- banda de unidades disponibles
- alertas de conflicto

### 2.3 Grid del Control Diario

Columnas MVP:

- folio
- prioridad
- hora compromiso
- zona
- cliente o sitio
- origen
- destino
- tipo de servicio
- tipo de carga
- unidad requerida
- chofer asignado
- unidad asignada
- estado
- comentario
- alerta

### 2.4 Alta rapida de servicio

Formulario o insert row con:

- plantilla
- prioridad
- cliente
- origen
- destino
- zona
- horario compromiso
- tipo de servicio
- tipo de carga
- unidad requerida
- observaciones

### 2.5 Flujo de asignacion

Implementar:

1. seleccionar servicio
2. mostrar choferes compatibles
3. mostrar unidades compatibles
4. bloquear combinaciones invalidas
5. guardar asignacion

### 2.6 Validaciones frontend y backend

Validar:

- chofer compatible con tipo de unidad
- chofer compatible con tipo de carga
- unidad compatible con tipo de carga
- unidad no bloqueada
- chofer no ocupado en conflicto horario
- unidad no ocupada en conflicto horario

### 2.7 Entregables de la etapa

- `Control Diario de Logistica` navegable
- captura de servicio
- asignacion con compatibilidad
- alertas basicas de conflicto

## Etapa 3. Disponibilidad, incidencias y estado de unidades

Objetivo:

- darle al encargado visibilidad real de recursos y problemas
- reutilizar mantenimiento existente sin mezclar unidades con maquinaria

### 3.1 Modulo Estado de Unidades

Pantalla nueva con:

- unidades disponibles
- asignadas
- en ruta
- en taller
- bloqueadas

Datos visibles:

- tipo de unidad
- carga compatible
- chofer actual
- proximo servicio
- mantenimiento proximo

Fuente recomendada:

- consumir `maintenance_orders` existentes
- filtrar OT del area `FLOTILLA`
- excluir OT de maquinaria del resumen diario de Logistica

### 3.2 Modulo Incidencias

Crear tabla:

- `logistics_trip_incidents`

Campos minimos:

- `id`
- `service_id`
- `incident_type`
- `reported_at`
- `reported_by`
- `summary`
- `impact_level`
- `action_taken`
- `responsible_name`
- `resolution_status`
- `resolved_at`
- `notes`

Pantalla:

- lista de incidencias abiertas
- detalle lateral
- acciones de reasignar, reprogramar o cerrar

### 3.3 Disponibilidad resumida en tiempo real

Crear vistas o consultas para:

- choferes disponibles
- unidades disponibles
- conflictos activos

Agregar lectura de mantenimiento para:

- unidades bloqueadas por OT abierta
- unidades con mantenimiento programado proximo
- unidades en riesgo por OT no cerrada

Nota de modelado:

- `maintenance_orders` hoy usa concepto general de `equipment`
- para el primer corte, la separacion principal debe ser `area_label = 'FLOTILLA'` o su equivalente real en los datos
- solo si ese filtro no alcanza, entonces se agrega una clasificacion operativa adicional

### 3.4 Entregables de la etapa

- pantalla de estado de unidades
- pantalla de incidencias
- disponibilidad resumida integrada al `Control Diario`

## Etapa 4. Zonas, ahorro y combinacion de servicios

Objetivo:

- empezar a generar ahorro real usando historico y agrupacion operativa

### 4.1 Vista por zonas

Pantalla:

- columnas por zona
- servicios pendientes y asignados agrupados por zona
- oportunidades de combinacion

### 4.2 Enlace cliente o sitio -> zona

Agregar relacion operativa para que:

- nuevos servicios hereden zona automaticamente
- el historico pueda agruparse por zona

### 4.3 Sugerencias de combinacion

Reglas MVP:

- mismo dia
- misma zona
- ventanas compatibles
- mismo tipo de unidad requerido

Resultado:

- alertas tipo `este servicio puede combinarse con otro`

### 4.4 Modulo Ahorro y Planeacion

Vista ligera con rankings por:

- cliente
- zona
- chofer
- unidad
- duplicidad de salidas

Hallazgos esperados:

- clientes que piden demasiado temprano
- zonas con doble cobertura
- unidades subutilizadas
- choferes subutilizados o saturados

### 4.5 Datos historicos a explotar

Fuentes iniciales:

- `services`
- historico de entradas y salidas con `driver_employee_id` y `vehicle_id`

### 4.6 Entregables de la etapa

- vista por zonas
- sugerencias basicas de combinacion
- pantalla inicial de ahorro y planeacion

## Etapa 5. Contenedores, preventivo y consolidacion

Objetivo:

- convertir Logistica en una herramienta de decision madura sin complicar la operacion diaria

### 5.1 Contenedores

Crear:

- `logistics_containers`

Campos minimos:

- `id`
- `client_id` o `site_id`
- `container_type`
- `capacity`
- `installed_count`
- `fill_level_estimate`
- `recommended_pickup_window`
- `urgency_level`
- `notes`
- `created_at`
- `updated_at`

Reutilizar base parcial:

- `has_containers`
- `container_count`

### 5.2 Integracion con servicio

Cuando aplique:

- el servicio debe heredar snapshot de contenedores
- la urgencia debe poder justificarse con capacidad y llenado

### 5.3 Preventivo vs correctivo

Cruzar:

- kilometraje
- uso por unidad
- incidencias por unidad
- mantenimiento abierto

Objetivo:

- anticipar unidades con alto riesgo operativo

### 5.4 Reporte semanal

Pantalla o salida consolidada con:

- viajes
- incidencias
- costo combustible
- unidades mas afectadas
- oportunidades de ahorro
- decisiones pendientes

### 5.5 Entregables de la etapa

- modulo de contenedores
- indicadores simples de urgencia
- integracion operativa con mantenimiento
- reporte semanal

## Backlog de frontend por archivo o modulo

### Reutilizar o evolucionar

- [services_page.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/services_page.dart)
- [services_shell.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/services_shell.dart)
- [services_catalog_page.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/services_catalog_page.dart)
- [dashboard_page.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/dashboard/dashboard_page.dart)
- [auth_access.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/auth/auth_access.dart)
- [role_router.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/auth/role_router.dart)

### Crear modulos nuevos

- `lib/app/logistica/logistics_control_daily_page.dart` o evolucion equivalente de `services_page.dart`
- `lib/app/logistica/logistics_units_page.dart`
- `lib/app/logistica/logistics_incidents_page.dart`
- `lib/app/logistica/logistics_zones_board_page.dart`
- `lib/app/logistica/logistics_savings_page.dart`
- `lib/app/logistica/logistics_containers_page.dart`
- `lib/app/logistica/logistics_catalogs_page.dart`

## Backlog de datos por migracion

### Migracion A

- crear `logistics_vehicle_types`
- crear `logistics_load_types`
- agregar campos base a `vehicles`

### Migracion B

- crear `logistics_driver_profiles`
- crear `logistics_driver_unit_skills`
- crear `logistics_driver_load_skills`

### Migracion C

- agregar campos de Logistica a `services`

### Migracion D

- crear `logistics_unit_load_capabilities`
- crear `logistics_zones`
- crear `logistics_service_templates`

### Migracion E

- crear `logistics_trip_incidents`
- crear vistas de disponibilidad
- crear vista derivada de mantenimiento para Logistica filtrando `maintenance_orders` del area `FLOTILLA`

### Migracion F

- crear `logistics_containers`
- crear vistas de ahorro y consolidacion

## Riesgos tecnicos a cuidar

- duplicar demasiada logica entre `services` y nuevo modulo
- meter optimizacion compleja demasiado pronto
- depender de texto libre en campos que deben ser catalogo
- no validar compatibilidad y terminar con datos inutiles
- romper historico existente de Operacion al migrar naming o flujo

## Decisiones de implementacion recomendadas

- conservar `services` como base inicial del `Control Diario`
- mover experiencia de `services` gradualmente hacia `logistica`
- evitar rediseño total desde cero
- construir catalogos y validaciones antes de automatizaciones complejas
- tratar zonas y ahorro como segunda capa, no como bloqueo del MVP diario

## Definition of Done del MVP

El MVP tecnico de Logistica estara listo cuando:

- existan catalogos de tipos de unidad y tipos de carga
- los choferes tengan habilidades por tipo de unidad y carga
- los servicios puedan capturar unidad requerida y carga requerida
- el `Control Diario` permita asignar chofer y unidad con validacion
- la app muestre disponibilidad resumida y conflictos
- la operacion diaria ya no dependa de memoria o chats dispersos para asignar

## Siguiente corte recomendado

Si queremos iniciar desarrollo ya, el primer corte debe abarcar solo:

1. migraciones A, B y C
2. evolucion de `services_page.dart` a `Control Diario`
3. validacion de compatibilidad
4. disponibilidad resumida de choferes y unidades

Ese corte ya cambia de verdad la operacion del encargado.
