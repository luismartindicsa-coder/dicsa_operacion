# Plan Base de Area Logistica

Fecha: 2026-07-28

## Objetivo

Convertir Logistica en un area operativa propia dentro de `apps/dicsa_operacion`, separando la programacion diaria de viajes de Operacion y ampliando el alcance para cubrir control de flota, incidencias, rutas frecuentes, disponibilidad real y seguimiento semanal.

El objetivo rector del area no es solo programar viajes. Es generar ahorro operativo sostenido sin volver mas complicada la operacion diaria.

La referencia funcional de negocio para este plan es el manual:

- `DICSA Manual Operativo Inicial Logistica Transporte v2.0.docx`

## Lo que pide el manual

El manual de julio de 2026 define a Logistica como responsable de:

- recibir, registrar, priorizar, asignar, monitorear, cerrar e informar viajes
- operar con un `Control Diario` vivo, no con una programacion rigida
- manejar estados operativos claros: `PENDIENTE`, `ASIGNADO`, `EN RUTA`, `EN SITIO`, `TERMINADO`, `INCIDENCIA`, `CANCELADO`
- centralizar la asignacion de choferes y unidades
- documentar evidencias, horarios, kilometraje, gastos e incidencias
- mantener registros basicos de gasolina, mantenimiento, llantas, aceites y disponibilidad
- documentar rutas, accesos, contactos y respaldos por ruta
- entregar un resumen semanal corto con problemas, costos y decisiones pendientes

Conclusion: el modulo actual de `Viajes y Servicios` cubre solo una parte del alcance.

## Objetivos reales del area

La app de Logistica debe ayudar a reducir costo y desorden en estas fuentes:

- diesel y gasolina
- mantenimientos correctivos repetidos
- uso ineficiente de choferes y unidades
- duplicidad de viajes a una misma zona
- recolecciones mal calendarizadas por costumbre
- falta de control de contenedores en clientes

Traducido a producto, Logistica debe responder cinco preguntas todos los dias:

1. Que viaje si se tiene que hacer hoy y cual puede reagendarse sin perder el servicio.
2. Que unidad y que chofer son realmente necesarios para cubrir el plan del dia.
3. Que servicios pueden agruparse por zona, ruta o ventana horaria.
4. Que clientes requieren recoleccion temprana de verdad y cuales pueden moverse.
5. Que contenedores y volumen instalado en clientes obligan urgencia y cuales dan margen.

## Rol operativo del encargado de Logistica

La app debe estar construida alrededor de la decision principal del encargado:

- planificar rutas y choferes en base a disponibilidad, priorizacion y optimizacion

Eso significa que el encargado debe poder hacer, desde la experiencia principal:

- agendar un servicio o viaje
- ver que servicios ya estan comprometidos por hora, zona y prioridad
- ver que choferes estan disponibles
- ver que unidades estan disponibles o bloqueadas
- asignar un chofer especifico a una unidad especifica
- reasignar cuando cambie la prioridad o exista incidencia
- combinar servicios cuando una misma ruta o zona lo permita
- dejar programado el siguiente movimiento sin perder visibilidad del actual

La pregunta central de la pantalla principal debe ser:

- `a quien mando, en que unidad, a que servicio, en que orden y por que`

## MVP funcional del encargado

Si reducimos el area a su esencia operativa, el MVP debe permitir estas tres cosas sin friccion:

1. Capturar y agendar servicios.
2. Asignar chofer y unidad segun disponibilidad.
3. Reordenar el plan segun prioridad y oportunidad de optimizacion.

### Datos minimos para tomar esa decision

Para cada servicio, el encargado necesita ver como minimo:

- prioridad
- fecha y hora compromiso
- zona
- origen y destino
- cliente o sitio
- material o tipo de servicio
- urgencia real
- chofer asignado
- unidad asignada
- estado actual

Para cada chofer, necesita ver:

- disponible o no
- unidad actual o ultima unidad asignada
- zona actual o siguiente zona
- carga de servicios del dia

Para cada unidad, necesita ver:

- disponible o no
- chofer actual
- estado mecanico
- si ya tiene otro servicio comprometido

### Regla de simplicidad

La pantalla no debe obligar al encargado a abrir cinco modales para decidir algo tan basico como:

- `este viaje se lo asigno a este chofer en esta unidad`

La experiencia correcta es:

- ver servicios pendientes
- ver recursos disponibles
- asignar rapido
- poder corregir rapido

## Catalogos criticos del area

Logistica no puede depender solo de los catalogos actuales de Operacion tal como estan hoy. Si sirven como base, pero quedan cortos para la asignacion real.

La razon es simple:

- no todas las unidades son del mismo tipo
- no todos los choferes manejan todos los tipos de unidad
- no todos los servicios aceptan cualquier tipo de carga o contenedor

Por eso Logistica necesita catalogos mas ricos y reglas de compatibilidad.

### 1. Catalogo de tipos de unidad

Debe clasificar la flota al menos por:

- camion
- camioneta
- trailer
- pick up
- grua

Y para cada unidad, guardar:

- codigo o nombre
- tipo de unidad
- capacidad operativa
- tipo de carga o implemento principal
- estado actual
- disponibilidad
- si requiere licencia, experiencia o maniobra especial

### 2. Catalogo de tipos de carga o configuracion operativa

No basta saber la unidad. Tambien hay que saber para que tipo de carga sirve.

Ejemplos iniciales:

- contenedor chico
- contenedor grande
- plataforma
- jaula
- carga general
- maniobra con grua

Relacion esperada:

- `camioneta -> contenedor chico`
- `camion -> contenedor grande`
- `trailer -> plataforma`
- `grua -> jaula` o maniobra especial

La app debe permitir que una unidad tenga una o varias capacidades compatibles, no solo una etiqueta simple.

### 3. Catalogo de habilidades del chofer

El catalogo actual de choferes debe crecer para incluir:

- tipos de unidad que puede manejar
- tipos de carga o maniobra que puede cubrir
- licencias o permisos relevantes
- rutas o clientes que conoce
- estatus operativo

Esto evita errores como asignar:

- un chofer sin experiencia de trailer a un trailer
- un chofer sin maniobra de grua a una grua
- un chofer que no cubre cierto tipo de carga a un servicio inadecuado

### 4. Matriz de compatibilidad

La asignacion del servicio debe validarse contra tres cosas:

1. El servicio requiere cierto tipo de unidad o carga.
2. La unidad seleccionada si soporta ese tipo.
3. El chofer seleccionado si puede operar esa unidad y esa carga.

Si falla alguno de esos tres puntos, la app debe advertirlo o bloquear la asignacion.

### 5. Catalogo de plantillas operativas de servicio

Conviene que ciertos tipos de viaje ya nazcan con sugerencias operativas.

Ejemplos:

- `recoleccion con contenedor chico`
- `recoleccion con contenedor grande`
- `viaje con plataforma`
- `servicio con grua`

Cada plantilla podria sugerir:

- tipo de unidad requerido
- tipo de carga
- nivel de urgencia comun
- maniobra especial
- tiempo estimado

Esto ayuda a que la captura siga siendo simple aunque el modelo operativo sea mas completo.

## Principios de diseno del area

La herramienta no debe ser complicada. Debe ser simple para operar y potente para decidir.

Principios:

- primero control visible, despues optimizacion avanzada
- la pantalla principal no debe parecer tablero de BI pesado
- cada dato nuevo debe servir para una decision operativa concreta
- la captura debe ser corta; el analisis puede vivir en vistas secundarias
- la mejor optimizacion es la que el usuario entiende y puede ejecutar hoy

Traduccion practica:

- `Control Diario` para operar
- `Ahorro y Planeacion` para detectar oportunidades
- `Activos y Contenedores` para saber capacidad real instalada

## Contrato visual inicial del area

Logistica queda aprobada desde este arranque con paleta `plateada`, no verde y no teal.

Direccion cromatica oficial:

- familia: `plateado operativo / grafito / hielo`
- lectura dominante:
  - fondo grafito profundo
  - cards y paneles `dark glass`
  - acentos plateados para foco, seleccion y acciones
- distribucion sugerida:
  - `72%` grafito
  - `18%` acero medio
  - `10%` plateado claro

Aplicacion obligatoria del contrato:

- `Dashboard Logistica`
- `Control Diario`
- `Estado de Unidades`
- `Catalogos Operativos`
- `Incidencias`
- `Ahorro y Planeacion`

Superficies que deben heredar esta paleta desde el primer desarrollo:

- calendarios y date pickers
- botones primarios, secundarios y ghost
- filtros popup
- dropdowns y menus contextuales
- badges, tabs y overlays
- modales y dialogos auxiliares

Prohibiciones iniciales:

- no reciclar el verde menta o teal heredado de `Servicios`
- no caer al azul base del sistema en popups o pickers
- no resolver contraste aclarando toda la interfaz; el contraste debe salir del grafito y del plateado

## Estado actual en la app

Hoy la base existente esta principalmente en:

- [services_page.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/services_page.dart)
- [services_shell.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/services_shell.dart)
- [dashboard_page.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/dashboard/dashboard_page.dart)
- [auth_access.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/auth/auth_access.dart)
- [role_router.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/auth/role_router.dart)
- [services_catalog_page.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/services_catalog_page.dart)

### Capacidades ya existentes que si reutilizan valor

- captura y edicion inline de servicios en la tabla `services`
- campos base: fecha, empresa, material, tipo, chofer, unidad, comentario, estado, fecha compromiso
- catalogos iniciales de choferes y unidades
- acceso para roles `services`, `logistics`, `logistica`
- resumen en dashboard de viajes y servicios por fecha
- estructura UI homologada tipo grid que conviene conservar

### Limites del modulo actual

El modulo actual esta pensado como programacion compacta de servicios y no como area completa de Logistica. Le faltan pantallas o capacidades para:

- bandeja operacional con prioridad `AHORA / HOY / PROGRAMABLE`
- estados del manual alineados al flujo real
- seguimiento de incidencias con protocolo y resolucion
- cierre con evidencia, kilometraje, gastos y diferencias
- disponibilidad real de unidades
- bitacora de combustible
- estado mecanico y carpeta operativa de unidad
- carpeta de chofer
- rutas frecuentes con chofer titular y respaldo
- reporte semanal consolidado
- analisis historico de servicios por chofer, unidad, zona y cliente
- mapa operativo por zonas de la ciudad
- control de contenedores por cliente, capacidad y urgencia real de recoleccion
- soporte para negociacion de ventanas horarias con clientes
- tipos de unidad suficientemente detallados
- compatibilidad entre chofer y tipo de unidad
- compatibilidad entre unidad y tipo de carga
- validaciones reales de asignacion

## Decision de producto

No conviene solo renombrar `Servicios` a `Logistica`.

Si conviene:

1. usar `services` como base del `Control Diario`
2. crear una nueva entrada de navegacion de area: `Logistica`
3. dejar `Operacion` sin responsabilidad primaria sobre la programacion de viajes
4. abrir submodulos nuevos alrededor del control diario
5. usar el historico existente para construir ahorro, no solo captura

## Arquitectura funcional propuesta

### 1. Centro de Control Diario

Pantalla principal del area. Debe ser la evolucion directa de `services_page`.

Objetivo:

- mostrar todo lo que entra hoy y lo programable
- permitir registrar y reasignar sin friccion
- responder en menos de un minuto: quien lo hace, con que unidad, donde va y en que estado va
- permitir decidir rapido a que chofer y unidad asignar cada servicio

Secciones sugeridas:

- vista `Hoy`
- vista `Pendientes`
- vista `Programables`
- vista `Incidencias`
- vista `Cierre del dia`

Columnas minimas:

- folio
- prioridad
- fecha solicitud
- fecha compromiso
- tipo `recoleccion / entrega / movimiento interno / apoyo`
- solicitante
- area solicitante
- origen
- destino
- empresa o sitio
- material y cantidad aproximada
- tipo de carga o configuracion
- tipo de unidad requerida
- chofer
- unidad
- estado
- evidencia pendiente
- comentario operativo
- incidencia activa

Acciones clave:

- registrar solicitud rapida
- agendar servicio o viaje
- asignar chofer y unidad
- validar compatibilidad chofer-unidad-carga
- cambiar prioridad
- cambiar secuencia
- reprogramar horario
- marcar salida, llegada, termino
- abrir incidencia
- cerrar con evidencia y gasto

Bloques visuales sugeridos dentro de la misma pantalla:

- lista de servicios pendientes o programados
- franja lateral o superior de choferes disponibles
- franja lateral o superior de unidades disponibles
- alertas de conflicto: doble asignacion, unidad bloqueada, choque de horarios

### 2. Tablero de Salidas y Monitoreo

Vista enfocada en ejecucion del dia.

Objetivo:

- ver rapido que sigue pendiente, que ya salio, que esta en sitio y que viene retrasado

Widgets sugeridos:

- unidades disponibles
- choferes disponibles
- servicios `AHORA`
- servicios retrasados
- incidencias abiertas
- proximas salidas

No necesita GIS completo en fase 1. Puede arrancar con semaforos operativos y ultimo reporte manual.

### 2.1 Mapa por Zonas

Subvista ligera dentro de `Monitoreo` o `Planeacion`.

Objetivo:

- evitar mandar varias unidades a la misma zona cuando una sola ya estara ahi
- ayudar a combinar servicios de una misma zona o corredor

La primera version no necesita mapa sofisticado. Puede arrancar con:

- catalogo de zonas de la ciudad
- cada cliente o sitio asignado a una zona
- vista por columnas o tarjetas: `Norte`, `Sur`, `Centro`, `Oriente`, `Poniente`, `Industrial`, o las zonas reales que defina DICSA
- agrupacion de servicios pendientes por zona y ventana horaria

Beneficio:

- detectar rapido cuando un chofer ya puede cubrir un segundo servicio cercano
- reducir salidas duplicadas
- bajar consumo de combustible

### 3. Incidencias de Viaje

Pantalla nueva.

Objetivo:

- registrar y dar seguimiento a eventos que bloquean o degradan un servicio

Tipos iniciales:

- retraso
- material no listo
- acceso cerrado
- falla mecanica
- cambio de unidad
- negativa de chofer
- accidente o seguridad
- cancelacion

Campos minimos:

- viaje relacionado
- hora reporte
- quien reporta
- descripcion corta
- impacto operativo
- accion tomada
- responsable
- estado de resolucion

### 4. Disponibilidad y Estado de Unidades

Pantalla nueva.

Objetivo:

- saber si una unidad esta disponible, asignada, fuera de servicio o restringida

Estados sugeridos:

- disponible
- asignada
- en_ruta
- en_taller
- bloqueada_documentos
- bloqueada_seguridad

Vista:

- tarjeta o grid por unidad
- unidad actual
- tipo de unidad
- tipo de carga compatible
- chofer actual
- ultimo servicio
- kilometraje
- documentos por vencer
- proximo mantenimiento

Fuente recomendada:

- reutilizar `maintenance_orders` para leer bloqueos, OT abiertas y proximos trabajos
- filtrar primero por el area de mantenimiento `FLOTILLA`
- usar ese filtro para quedarse solo con unidades de transporte y no mezclar maquinaria

### 5. Bitacora de Combustible y Gastos de Viaje

Pantalla nueva.

Objetivo:

- capturar litros, importe, ticket, kilometraje y gasto operativo por viaje o por unidad

Campos minimos:

- fecha
- unidad
- chofer
- viaje
- odometro
- litros
- importe
- ticket o evidencia
- observaciones

Salida util:

- consumo por unidad
- comparativo km/L
- gastos pendientes de validar

### 6. Mantenimiento Ligado a Disponibilidad

No necesita duplicar todo `maintenance_page`, pero si necesita integracion operativa.

Objetivo:

- que Logistica vea el estado de la unidad antes de asignarla

Integracion esperada:

- lectura de OT abierta por unidad
- semaforo de liberacion
- motivo de bloqueo
- fecha estimada de regreso

Nota de integracion:

- `maintenance_orders` ya existe y conviene reutilizarlo
- Mantenimiento puede seguir manejando OT de unidades y maquinaria en el mismo modulo
- Logistica solo debe consumir la porcion de OT relacionada con unidades de transporte
- hoy la mejor forma de hacerlo es aprovechar que ya existe el area `FLOTILLA`

Regla funcional:

- una OT ligada a maquinaria no debe bloquear ni ensuciar la disponibilidad diaria de choferes y rutas
- una OT ligada a unidad de transporte si debe reflejarse en Logistica como restriccion, alerta o bloqueo
- en primera instancia, la lectura de Logistica debe tomar OT del area `FLOTILLA`

Objetivo de negocio:

- pasar gradualmente de correctivo a preventivo
- evitar que Logistica siga asignando unidades con falla repetitiva
- volver visibles los patrones de gasto por unidad

### 7. Rutas Frecuentes y Respaldos

Pantalla nueva.

Objetivo:

- documentar conocimiento operativo y evitar que una ruta dependa de una sola persona

Campos minimos:

- cliente o sitio
- tipo de servicio
- origen y destino base
- horarios
- contacto
- restricciones de acceso
- maniobras especiales
- documentos requeridos
- chofer titular
- chofer respaldo
- unidad preferente
- notas

### 8. Carpeta de Chofer

Pantalla nueva o subvista de catalogo.

Objetivo:

- concentrar licencia, contacto, unidades autorizadas, rutas conocidas e incidencias relevantes

Campos minimos:

- nombre
- licencias o permisos
- tipos de unidad autorizados
- tipos de maniobra o carga autorizados
- rutas conocidas
- disponibilidad operativa
- incidencias relevantes

### 8.1 Catalogos Operativos

Pantalla nueva o evolucion de `services_catalog_page`.

Objetivo:

- administrar la base maestra que vuelve posible una asignacion correcta

Catalogos minimos:

- tipos de unidad
- unidades
- tipos de carga o configuracion
- choferes
- matriz de compatibilidad chofer-unidad
- matriz de compatibilidad unidad-carga
- zonas
- plantillas de servicio

Nota:

- si el area `FLOTILLA` ya separa correctamente las OT de transporte, no hace falta crear de inicio otra clasificacion solo para este corte

### 9. Reporte Semanal de Logistica

Pantalla nueva simple, no un BI pesado.

Objetivo:

- producir una pagina accionable para Direccion

Contenido sugerido:

- viajes completados
- cancelados
- incidencias recurrentes
- unidades con mas afectaciones
- gastos relevantes
- rutas sin respaldo
- decisiones pendientes

### 10. Ahorro y Planeacion

Pantalla nueva de decision, separada del `Control Diario`.

Objetivo:

- convertir el historico operativo en acciones de ahorro simples

Preguntas que debe responder:

- que clientes concentran mas viajes por semana
- que zonas generan mas salidas duplicadas
- que choferes o unidades estan subutilizados o sobrecargados
- que servicios suelen poder combinarse
- que clientes siempre piden temprano pero realmente toleran otro horario
- que unidades estan costando mas por combustible o mantenimiento

Vista sugerida:

- tarjetas de oportunidad
- tablas cortas con ranking
- filtros por periodo, zona, cliente, chofer y unidad

No debe ser una pantalla compleja. Debe parecer lista de hallazgos accionables.

### 11. Contenedores

Pantalla nueva o submodulo de `Activos y Contenedores`.

Objetivo:

- saber donde estan los contenedores, cuantos hay, que capacidad tienen y que urgencia real generan

Campos minimos:

- cliente
- sitio
- contenedor
- capacidad
- cantidad instalada
- material esperado
- nivel de llenado estimado
- frecuencia historica de llenado
- ventana recomendada de recoleccion
- urgencia operativa
- notas

Clasificacion operativa recomendada:

- `urgente`
- `mismo_dia`
- `puede_esperar`

Insight clave:

- no todos los clientes con contenedor necesitan primera hora
- la urgencia debe venir de volumen y capacidad, no solo de costumbre

Nota de reutilizacion:

- ya existe base parcial de contenedores en directorio de compras con `has_containers` y `container_count`; conviene reutilizarla como punto de partida y despues ampliar a capacidad, sitio y urgencia

## Navegacion propuesta

Nueva area principal: `Logistica`

Submodulos recomendados:

1. `Control Diario`
2. `Monitoreo`
3. `Ahorro y Planeacion`
4. `Incidencias`
5. `Unidades`
6. `Combustible y Gastos`
7. `Rutas`
8. `Contenedores`
9. `Choferes`
10. `Catalogos`
11. `Reporte Semanal`

## Diseno funcional exacto

Esta seccion baja el plan a pantallas concretas para implementacion.

### Pantalla 1. Control Diario de Logistica

Esta debe ser la pantalla principal del area y la primera que abre el encargado.

#### Objetivo de la pantalla

- ver que servicios existen hoy
- ver que recursos tiene disponibles
- asignar rapido chofer y unidad
- detectar conflictos antes de sacar una unidad

#### Estructura visual propuesta

##### Franja superior de contexto

Contenido:

- fecha operativa
- contador de `Pendientes`
- contador de `Asignados`
- contador de `En ruta`
- contador de `Incidencias`
- contador de `Unidades disponibles`
- contador de `Choferes disponibles`

Acciones:

- `Nuevo servicio`
- `Ver incidencias`
- `Vista por zonas`
- `Cierre del dia`

##### Banda de filtros rapidos

Filtros visibles:

- fecha
- prioridad
- estado
- zona
- tipo de servicio
- tipo de unidad requerida
- tipo de carga
- chofer
- unidad

Busqueda:

- folio
- cliente
- origen
- destino

##### Cuerpo principal en tres paneles

Panel izquierdo: `Servicios`

- grid principal
- muestra los servicios del dia o del filtro activo
- orden por prioridad, hora compromiso y secuencia operativa

Panel central o superior derecho: `Choferes disponibles`

- tarjetas compactas por chofer
- disponibilidad
- tipos de unidad autorizados
- carga del dia
- zona actual o siguiente compromiso

Panel derecho o inferior derecho: `Unidades disponibles`

- tarjetas compactas por unidad
- tipo de unidad
- tipo de carga compatible
- estado mecanico
- siguiente disponibilidad
- chofer actual si aplica

##### Banda inferior opcional: `Conflictos y sugerencias`

Debe mostrar alertas simples:

- doble asignacion
- unidad bloqueada
- chofer incompatible
- tipo de carga no compatible
- servicio combinable con otro de la misma zona

#### Grid exacto de servicios

Columnas recomendadas para MVP:

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

Columnas que pueden vivir en detalle lateral y no forzosamente en el grid:

- solicitante
- telefono contacto
- material listo
- observaciones especiales
- evidencia requerida

#### Estados visuales de servicio

- `Pendiente`: sin chofer o sin unidad
- `Asignado`: con chofer y unidad confirmados
- `En ruta`: unidad ya salio
- `En sitio`: cargando, descargando o esperando
- `Terminado`: cerrado con evidencia minima
- `Incidencia`: requiere accion
- `Cancelado`: no se realizara

#### Acciones por fila

- `Asignar`
- `Reasignar`
- `Cambiar prioridad`
- `Mover horario`
- `Abrir incidencia`
- `Marcar salida`
- `Marcar llegada`
- `Marcar termino`
- `Ver detalle`

#### Flujo exacto de asignacion

1. El usuario selecciona un servicio pendiente.
2. La app resalta choferes compatibles.
3. La app resalta unidades compatibles.
4. La app oculta o marca en rojo las combinaciones invalidas.
5. El usuario asigna chofer y unidad.
6. La app valida:
   - horario disponible
   - compatibilidad chofer-unidad
   - compatibilidad unidad-carga
   - estado mecanico y documental
7. Si todo pasa, el servicio cambia a `Asignado`.

#### Reglas de compatibilidad en pantalla

Compatibilidad minima:

- el chofer puede manejar ese tipo de unidad
- la unidad soporta ese tipo de carga
- la unidad no esta bloqueada
- el chofer no esta ocupado en un solape critico

Respuesta visual:

- verde: compatible
- amarillo: compatible con advertencia
- rojo: no compatible

#### Detalle lateral del servicio

Al abrir un servicio, mostrar:

- datos generales
- horario solicitado
- horario prometido
- zona
- contacto
- tipo de unidad requerida
- tipo de carga
- urgencia
- contenedores si aplica
- incidencias previas del cliente o ruta
- sugerencias de asignacion

#### Sugerencias automaticas del MVP

La app debe sugerir, sin decidir sola:

- mejor chofer disponible
- mejor unidad disponible
- segundo servicio combinable por zona
- riesgo de retraso por saturacion

### Pantalla 2. Vista por Zonas

No necesita mapa geoespacial en MVP.

#### Objetivo

- agrupar servicios del dia para decidir combinaciones

#### Layout

- columnas por zona
- cada columna contiene servicios pendientes y asignados
- arriba de cada zona: conteo de servicios, unidades ya enviadas y oportunidades de combinacion

#### Acciones

- mover servicio de prioridad
- asignar desde la zona
- ver servicios cercanos combinables

### Pantalla 3. Incidencias

#### Layout

- lista izquierda de incidencias abiertas
- detalle derecho de la incidencia

#### Datos visibles en la lista

- hora
- viaje
- cliente
- tipo de incidencia
- impacto
- responsable
- estado

#### Acciones

- reasignar unidad
- reasignar chofer
- reprogramar horario
- cerrar incidencia

### Pantalla 4. Estado de Unidades

#### Objetivo

- saber en segundos que flota esta utilizable

#### Layout

- grid o tarjetas por unidad

Cada tarjeta muestra:

- codigo
- tipo de unidad
- tipo de carga compatible
- estado actual
- chofer actual
- proximo servicio
- km relevantes
- mantenimiento proximo
- bloqueo si existe

#### Vistas

- `Disponibles`
- `Asignadas`
- `En ruta`
- `En taller`
- `Bloqueadas`

### Pantalla 5. Catalogos Operativos

Debe ser la base maestra del area. No un catalogo plano.

#### Modulos internos

1. `Tipos de unidad`
2. `Unidades`
3. `Tipos de carga`
4. `Choferes`
5. `Compatibilidad chofer-unidad`
6. `Compatibilidad unidad-carga`
7. `Zonas`
8. `Plantillas de servicio`

### 5.1 Tipos de unidad

Grid con columnas:

- codigo
- nombre
- descripcion
- requiere licencia especial
- maniobra especial
- activo

Ejemplos:

- CAMIONETA
- CAMION
- TRAILER
- PICK_UP
- GRUA

### 5.2 Unidades

Grid con columnas:

- codigo
- tipo de unidad
- placa o identificador
- capacidad operativa
- carga principal
- estado
- activo

Acciones:

- editar capacidad
- bloquear unidad
- marcar mantenimiento

### 5.3 Tipos de carga

Grid con columnas:

- codigo
- nombre
- descripcion
- maniobra especial
- activo

Ejemplos:

- CONTENEDOR_CHICO
- CONTENEDOR_GRANDE
- PLATAFORMA
- JAULA
- CARGA_GENERAL
- GRUA_MANIOBRA

### 5.4 Choferes

Grid con columnas:

- nombre
- activo
- disponibilidad operativa
- tipos de unidad autorizados
- tipos de carga autorizados
- rutas conocidas

Acciones:

- editar habilidades
- desactivar
- marcar no disponible

### 5.5 Compatibilidad chofer-unidad

Vista matricial.

Filas:

- choferes

Columnas:

- tipos de unidad

Celda:

- permitido
- con restriccion
- no permitido

Esto debe poder editarse muy rapido.

### 5.6 Compatibilidad unidad-carga

Vista matricial.

Filas:

- unidades o tipos de unidad

Columnas:

- tipos de carga

Celda:

- compatible
- compatible con restriccion
- incompatible

### 5.7 Zonas

Grid con columnas:

- codigo
- nombre
- descripcion
- clientes asociados
- activo

### 5.8 Plantillas de servicio

Grid con columnas:

- nombre
- tipo de servicio
- tipo de unidad sugerido
- tipo de carga sugerido
- prioridad sugerida
- duracion estimada
- activo

#### Uso dentro del Control Diario

Cuando el usuario crea un servicio desde plantilla:

- se llenan automaticamente los campos base
- se sugieren unidad y tipo de carga
- se acelera la captura

## Secuencia real de implementacion UX

Para no sobredisenar desde el inicio, conviene construir en este orden:

1. `Control Diario` con grid, banda de choferes, banda de unidades y validaciones.
2. `Catalogos Operativos` con tipos de unidad, tipos de carga, choferes y compatibilidades.
3. `Estado de Unidades`.
4. `Incidencias`.
5. `Vista por Zonas`.

## Criterio de aceptacion del MVP

El MVP de Logistica estara listo cuando el encargado pueda:

- registrar un servicio
- ver la prioridad y zona del servicio
- ver choferes y unidades disponibles
- asignar una combinacion valida
- recibir advertencia si intenta asignar una invalida
- reprogramar o reasignar sin perder el control del dia

Si eso funciona bien, la optimizacion y el ahorro ya tienen una base real.

## Dos capas del producto

Para que el area no se vuelva complicada, la experiencia debe separarse en dos capas:

### Capa 1. Operacion diaria

Pantallas:

- `Control Diario`
- `Monitoreo`
- `Incidencias`

Meta:

- sacar el dia con orden y rapidez

### Capa 2. Ahorro y mejora

Pantallas:

- `Ahorro y Planeacion`
- `Unidades`
- `Combustible y Gastos`
- `Rutas`
- `Contenedores`
- `Reporte Semanal`

Meta:

- reducir costo y dependencia de decisiones improvisadas

## Migracion desde Operacion

### Lo que migra directo

De `services_page` a `Control Diario`:

- tabla `services` como base inicial
- captura inline
- seleccion de chofer
- seleccion de unidad
- filtros
- refresh en tiempo real
- resumen diario

### Lo que debe cambiar en esa migracion

- el nombre ya no debe ser `Programacion de Viajes y Servicios`
- debe convertirse en `Control Diario de Logistica`
- los estados deben homologarse al manual
- hay que agregar prioridad
- hay que agregar origen, destino, contacto y material listo
- el cierre debe registrar evidencia, kilometraje, gasto e incidencia
- el dashboard principal ya no debe anunciarlo como modulo de Operacion
- debe poder alimentar una capa posterior de analisis por zona, cliente, chofer y unidad

### Lo que no debe quedarse mezclado

- programacion de viajes como responsabilidad cotidiana de Operacion
- cambios de chofer o unidad fuera del canal de Logistica
- lectura de viajes solo como una lista simple sin contexto de disponibilidad

## Propuesta de datos por fases

### Fase 1: ampliar `services`

Objetivo:

- mover rapido la operacion real sin abrir demasiadas tablas nuevas
- conservar el historico y empezar a explotar ahorro desde lo ya capturado

Campos nuevos sugeridos en `services`:

- `priority`
- `request_channel`
- `requester_name`
- `requester_area`
- `origin_text`
- `destination_text`
- `site_contact_name`
- `site_contact_phone`
- `material_ready`
- `special_conditions`
- `required_vehicle_type`
- `required_load_type`
- `zone_id` o `zone_label`
- `requested_time_window`
- `promised_time_window`
- `assigned_at`
- `departed_at`
- `arrived_at`
- `completed_at`
- `evidence_status`
- `evidence_notes`
- `odometer_start`
- `odometer_end`
- `trip_expense_amount`
- `fuel_liters`
- `fuel_amount`
- `incident_status`
- `incident_summary`
- `container_required`
- `container_count_snapshot`
- `container_capacity_snapshot`

### Fase 2: tablas satelite

Separar en nuevas entidades:

- `logistics_trip_incidents`
- `logistics_fuel_logs`
- `logistics_route_profiles`
- `logistics_driver_profiles`
- `logistics_vehicle_availability_snapshots`
- `logistics_vehicle_types`
- `logistics_load_types`
- `logistics_driver_unit_skills`
- `logistics_unit_load_capabilities`
- `logistics_service_templates`
- `logistics_zones`
- `logistics_customer_time_windows`
- `logistics_containers`
- `logistics_container_capacity_profiles`
- `logistics_savings_opportunities`

### Fase 3: vista consolidada de area

Crear vistas tipo:

- `v_logistics_control_daily`
- `v_logistics_vehicle_status`
- `v_logistics_weekly_summary`

## Fases de implementacion

### Fase A. Separacion de identidad del area

- crear entrada de navegacion `Logistica`
- actualizar copy de menu, dashboard y headers
- mantener operativa la pantalla actual mientras se migra

### Fase B. Control Diario v2

- evolucionar `services_page`
- agregar prioridad, origen, destino, contacto, material listo
- agregar tipo de unidad requerida y tipo de carga
- agregar zona y ventana horaria
- homologar estados con el manual
- agregar cierre operativo
- validar asignaciones incompatibles

### Fase C. Incidencias y disponibilidad

- crear modulo de incidencias
- crear vista de disponibilidad por unidad
- integrar semaforo con mantenimiento

### Fase D. Ahorro operativo

- crear zonas
- agrupar servicios por zona
- explotar historico por cliente, unidad y chofer
- detectar viajes combinables y cargas duplicadas
- crear vista simple de oportunidades

### Fase E. Flota, contenedores y control semanal

- combustible y gastos
- rutas frecuentes y respaldos
- contenedores por cliente y capacidad
- carpeta de chofer
- reporte semanal

## Riesgos si hacemos solo un renombre

- Logistica seguiria sin herramientas para controlar flota
- Direccion seguiria preguntando por fuera el estado real de las unidades
- incidencias y gastos seguirian viviendo en chats o memoria
- no habria base para respaldos por ruta ni rotacion gradual
- mantenimiento y programacion seguirian desalineados

## Recomendacion concreta

La mejor ruta es:

1. convertir `services` en el primer modulo de `Logistica`, no en el modulo completo
2. cambiar el ownership funcional de programacion desde ahora
3. usar una Fase 1 con cambios ligeros a datos para no frenar la operacion
4. abrir despues modulos satelite de incidencias, unidades y combustible
5. construir la optimizacion sobre historico real, no sobre supuestos
6. separar muy claro lo diario de lo analitico para que la app siga siendo simple

## Primer backlog recomendado

1. Renombrar experiencia actual a `Control Diario de Logistica`.
2. Mover acceso y navegacion para que `logistics/logistica/services` entren al area nueva.
3. Agregar prioridad, origen, destino, contacto y bandera `material listo`.
4. Agregar tipo de unidad requerida y tipo de carga por servicio.
5. Agregar zona y ventana horaria solicitada.
6. Homologar estados al manual.
7. Agregar cierre operativo con evidencia, kilometraje, combustible y gasto.
8. Mostrar disponibilidad resumida de choferes y unidades dentro del `Control Diario`.
9. Validar conflictos de asignacion de chofer/unidad/horario.
10. Crear catalogo de tipos de unidad y tipos de carga.
11. Ampliar catalogo de choferes con habilidades por tipo de unidad.
12. Crear validacion de compatibilidad chofer-unidad-carga.
13. Crear pantalla `Incidencias`.
14. Crear pantalla `Estado de Unidades`.
15. Crear catalogo de zonas y asignacion de clientes a zona.
16. Crear pantalla simple de `Ahorro y Planeacion` basada en historico.
17. Integrar contenedores por cliente como base de urgencia.
18. Integrar resumen semanal simple.

## Insight operativo que la app debe habilitar

El valor grande de Logistica no es solo despachar mejor hoy. Es poder demostrar con datos cosas como estas:

- este cliente pide primera hora, pero por capacidad de contenedor puede pasar a media manana
- esta zona se esta cubriendo con dos unidades cuando una sola podria absorber dos servicios
- esta unidad consume demasiado frente a otras rutas parecidas
- este chofer o esta unidad tienen huecos para absorber mas carga
- este patron de fallas justifica mantenimiento preventivo antes de volver a parar una unidad

Si la app logra volver visibles esas decisiones de manera simple, entonces si va a generar ahorro real.

## Decisiones abiertas

- si `services` conservara ese nombre tecnico o se renombrara a una entidad mas clara como `logistics_trips`
- si el monitoreo GPS sera manual en Fase 1 o si ya existe una fuente integrable
- si `Combustible y Gastos` arranca por viaje o por unidad
- si `Rutas` vivira como modulo independiente o como parte de catalogos operativos
