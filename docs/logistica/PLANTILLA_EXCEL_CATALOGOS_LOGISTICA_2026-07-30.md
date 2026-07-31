# Plantilla Excel Catalogos Logistica

Fecha: 2026-07-30

## Objetivo

Dejar una plantilla de captura externa para que el equipo de Logistica empiece a juntar informacion util para la app sin esperar a que todas las pantallas esten cerradas.

La meta de esta plantilla no es guardar datos administrativos. La meta es alimentar:

- Control Diario
- zonas y mapa
- priorizacion por horario y urgencia
- compatibilidades chofer-unidad-carga
- control de contenedores
- futura optimizacion de rutas

## Regla clave para no ensuciar catalogos

No capturar ids manuales.

Siempre usar nombres operativos reales:

- `empresa_nombre`
- `unidad_codigo`
- `chofer_nombre`
- `zona_codigo`

Si una empresa ya existe en la app, su nombre debe escribirse exactamente igual.

Si una empresa todavia no existe en la app, se captura por nombre operativo y despues nosotros la homologamos al catalogo real. No se deben inventar ids, claves tecnicas ni relaciones manuales.

## Lo que si se debe capturar

- datos operativos reales
- direccion de servicio
- horario
- restricciones
- contenedores
- urgencia
- compatibilidad
- incidencias repetitivas

## Lo que no se debe capturar

- razon social si nadie la usa en operacion
- RFC
- codigos fiscales
- datos contables
- cualquier id tecnico inventado para "amarrar" registros

## Estructura del archivo Excel

Crear un solo libro de Excel con estas pestanas:

1. `01_empresas`
2. `02_direcciones_mapa`
3. `03_zonas_base`
4. `04_asignacion_zonas`
5. `05_contenedores`
6. `06_unidades`
7. `07_choferes`
8. `08_compatibilidad_chofer_unidad`
9. `09_compatibilidad_unidad_carga`
10. `10_servicios_frecuentes`
11. `11_incidencias_recurrentes`

Los encabezados exactos ya estan listos como CSV en:

- `apps/dicsa_operacion/docs/logistica/plantilla_excel_catalogos/`

## Pestana 01. Empresas

Proposito:

- capturar la base operativa minima de cada empresa antes de entrar a zonas, contenedores y programacion

Columnas:

- `empresa_nombre`
  - nombre operativo con el que el equipo reconoce a la empresa
  - ejemplo: `WHIRLPOOL`
- `ya_existe_en_operacion`
  - escribir `SI` o `NO`
  - sirve para saber si la empresa ya vive en catalogos base o si habra que darla de alta despues
- `activa_en_logistica`
  - escribir `SI` o `NO`
  - indica si hoy si participa en servicios reales
- `servicio_principal`
  - tipo de trabajo mas comun
  - ejemplo: `Recoleccion`, `Entrega`, `Intercambio de contenedor`
- `material_principal`
  - material mas comun que mueve la empresa
  - ejemplo: `Carton`, `Plastico`, `Chatarra mixta`
- `frecuencia_servicio`
  - cada cuando pide servicio
  - ejemplo: `Diario`, `Lunes-Miercoles-Viernes`, `Semanal`, `Bajo llamada`
- `contacto_operativo`
  - nombre de quien realmente coordina el servicio en piso
- `telefono_contacto`
  - telefono o celular operativo
- `horario_solicitado`
  - hora o ventana que acostumbra pedir
  - ejemplo: `7:00 a.m.` o `6:00-8:00 a.m.`
- `flexibilidad_horario`
  - usar solo: `FIJO`, `NEGOCIABLE`, `RESTRINGIDO`, `POR_DEFINIR`
  - `FIJO`: no acepta cambio real
  - `NEGOCIABLE`: si acepta mover horario
  - `RESTRINGIDO`: tiene reglas parciales
  - `POR_DEFINIR`: aun no se confirma
- `recoleccion_temprana`
  - usar `SI` o `NO`
  - marcar `SI` solo si de verdad necesita primera hora
- `restricciones_acceso`
  - escribir restricciones concretas de entrada o maniobra
  - ejemplo: `Solo recibe hasta 2 p.m.`, `Entrada por lateral`, `Hay fila`
- `observaciones_operativas`
  - cualquier contexto util para programar mejor

## Pestana 02. Direcciones y mapa

Proposito:

- juntar la direccion real de servicio y dejar lista la capa para mapa y zonas

Columnas:

- `empresa_nombre`
  - debe coincidir exactamente con la pestana `01_empresas`
- `direccion_operativa`
  - direccion donde realmente entra la unidad
- `referencia_de_llegada`
  - referencia visual o practica para encontrar el acceso correcto
- `google_maps_link`
  - link compartido de Google Maps si ya lo tienen
- `latitud`
  - opcional si ya se conoce
- `longitud`
  - opcional si ya se conoce
- `municipio`
  - ejemplo: `Celaya`, `Apaseo el Grande`
- `comentario_ubicacion`
  - sirve para aclarar si la direccion comercial y la de acceso son distintas

## Pestana 03. Zonas base

Proposito:

- definir el catalogo base de zonas que despues pintaremos como poligonos en el mapa

Columnas:

- `zona_codigo`
  - clave corta y estable
  - ejemplo: `NO`, `NE`, `SO`, `SE`, `IND-1`
- `zona_nombre`
  - nombre facil de entender
  - ejemplo: `Noroeste`, `Zona Industrial Poniente`
- `cobertura_sugerida`
  - descripcion simple del area que cubre
  - ejemplo: `Salida a Queretaro y corredor industrial`
- `municipio`
  - municipio principal de la zona
- `estado`
  - ejemplo: `Guanajuato`
- `color_sugerido`
  - opcional, por ejemplo `#AAB4BE`
- `notas`
  - cualquier detalle para quien dibuje el poligono despues

## Pestana 04. Asignacion de zonas

Proposito:

- proponer en que zona cae cada empresa antes de cerrar el mapa final

Columnas:

- `empresa_nombre`
  - debe coincidir exactamente con `01_empresas`
- `zona_codigo_sugerido`
  - debe coincidir con `03_zonas_base`
- `subzona_o_corredor`
  - detalle opcional
  - ejemplo: `Salida a Salamanca`, `Eje Norponiente`
- `empresas_cercanas`
  - listar empresas vecinas que podrian combinar ruta
- `fuera_de_zona_clara`
  - usar `SI` o `NO`
  - `SI` si la empresa queda aislada o dificil de clasificar
- `justificacion_zona`
  - nota simple explicando por que se asigno ahi
- `nota_zona`
  - comentario adicional

## Pestana 05. Contenedores

Proposito:

- alimentar la capa que define urgencia real y margen de recoleccion

Columnas:

- `empresa_nombre`
  - debe coincidir exactamente con `01_empresas`
- `tiene_contenedores`
  - usar `SI` o `NO`
- `cantidad_contenedores`
  - numero total en sitio
- `tipo_contenedor`
  - ejemplo: `Chico`, `Grande`, `Plataforma`, `Jaula`
- `capacidad_o_nota`
  - puede ser capacidad, medida o descripcion operativa
- `urgencia_recoleccion`
  - usar solo: `BAJA`, `MEDIA`, `ALTA`, `CRITICA`
- `presion_volumen`
  - usar solo: `BAJO`, `MEDIO`, `ALTO`, `POR_DEFINIR`
- `acepta_recoleccion_tardia`
  - usar `SI` o `NO`
- `tiempo_estimado_de_llenado`
  - ejemplo: `1 dia`, `3 dias`, `1 semana`
- `nota_contenedor`
  - detalle de uso, saturacion o excepciones

## Pestana 06. Unidades

Proposito:

- dejar limpia la base operativa de unidades que Logistica si podra programar

Columnas:

- `unidad_codigo`
  - codigo real con el que la unidad se identifica hoy
- `tipo_unidad`
  - ejemplo: `Camion`, `Camioneta`, `Trailer`, `Pick up`, `Grua`
- `estatus_operativo`
  - ejemplo: `Activa`, `Limitada`, `Respaldo`, `Mantenimiento frecuente`
- `carga_compatible_principal`
  - la carga o configuracion que mejor cubre
- `cargas_compatibles_secundarias`
  - otras cargas que si podria cubrir
- `capacidad_operativa`
  - capacidad real con la que se programa
- `restricciones_operativas`
  - limitantes importantes
- `base_operativa`
  - patio, planta o base desde donde normalmente sale
- `observaciones_unidad`
  - comentarios utiles para despacho

## Pestana 07. Choferes

Proposito:

- capturar disponibilidad operativa real del personal que programara Logistica

Columnas:

- `chofer_nombre`
  - nombre completo o identificacion con la que todos lo conocen
- `activo_en_logistica`
  - usar `SI` o `NO`
- `tipos_unidad_que_maneja`
  - ejemplo: `Camioneta, Camion`
- `maniobras_o_cargas_que_maneja`
  - ejemplo: `Contenedor grande`, `Plataforma`, `Grua`
- `horario_disponible`
  - ejemplo: `6:00 a.m. a 4:00 p.m.`
- `zonas_que_conoce`
  - sectores o corredores donde se mueve mejor
- `restringido_para`
  - escribir lo que no debe asignarsele
- `observaciones_chofer`
  - cualquier dato operativo util

## Pestana 08. Compatibilidad chofer-unidad

Proposito:

- dejar clara la relacion exacta de que chofer si puede usar que unidad

Columnas:

- `chofer_nombre`
  - debe coincidir exactamente con `07_choferes`
- `unidad_codigo`
  - debe coincidir exactamente con `06_unidades`
- `permitido`
  - usar `SI` o `NO`
- `motivo_o_restriccion`
  - explicar por que si o por que no
- `prioridad_de_uso`
  - opcional
  - ejemplo: `Alta`, `Normal`, `Solo respaldo`

## Pestana 09. Compatibilidad unidad-carga

Proposito:

- definir que tipo de carga o servicio si soporta cada unidad

Columnas:

- `unidad_codigo`
  - debe coincidir exactamente con `06_unidades`
- `tipo_carga_o_servicio`
  - ejemplo: `Contenedor chico`, `Contenedor grande`, `Plataforma`, `Jaula`
- `permitido`
  - usar `SI` o `NO`
- `restriccion_o_condicion`
  - nota concreta de limite o condicion
- `prioridad_de_uso`
  - opcional

## Pestana 10. Servicios frecuentes

Proposito:

- identificar servicios repetitivos para que despues la app sugiera planeacion en vez de vivir al dia

Columnas:

- `empresa_nombre`
  - debe coincidir exactamente con `01_empresas`
- `tipo_servicio`
  - ejemplo: `Recoleccion`, `Entrega`, `Cambio de contenedor`
- `material`
  - material que normalmente mueve
- `dias_habituales`
  - ejemplo: `Lunes a sabado`, `Martes y jueves`
- `horario_habitual`
  - hora o ventana comun
- `duracion_estimada_min`
  - tiempo aproximado total del servicio
- `zona_codigo_sugerido`
  - si ya se conoce
- `requiere_unidad_especial`
  - escribir `SI` o `NO`
- `requiere_chofer_especial`
  - escribir `SI` o `NO`
- `observaciones`
  - detalle extra que ayude a programar

## Pestana 11. Incidencias recurrentes

Proposito:

- documentar problemas repetitivos que hoy encarecen o frenan la operacion

Columnas:

- `empresa_nombre`
  - si la incidencia no pertenece a empresa, escribir una referencia clara como `GENERAL`
- `tipo_incidencia`
  - ejemplo: `Cambio de horario`, `Acceso complicado`, `Saturacion`, `Falta de chofer`
- `descripcion`
  - que pasa exactamente
- `causa_probable`
  - por que suele pasar
- `impacto_operativo`
  - ejemplo: `Retraso de ruta`, `Mayor combustible`, `Doble vuelta`
- `frecuencia`
  - ejemplo: `Diario`, `Semanal`, `Ocasional`
- `accion_sugerida`
  - que solucion preliminar ve el equipo

## Reglas de captura para la persona que investigara

- una fila por empresa, unidad, chofer o incidencia segun corresponda
- no juntar varias empresas en una sola celda
- si no sabe un dato, dejarlo vacio o poner `POR_DEFINIR`
- no inventar horarios, zonas ni capacidades
- si un dato se contradice entre personas, anotarlo en observaciones
- si una empresa tiene dos ubicaciones reales, registrar ambas con claridad en direccion o comentario

## Resultado esperado

Con esta plantilla, aunque la app siga en desarrollo, Logistica ya puede empezar a construir la base que despues alimentara:

- catalogos homologados
- mapa con zonas
- priorizacion por horario
- lectura de contenedores
- compatibilidad chofer-unidad-carga
- programacion previa del dia siguiente
- optimizacion de rutas por sector
