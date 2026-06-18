# Blueprint: Desarrollo Comercial Fase 1

Este documento aterriza el área `Desarrollo Comercial` a nivel de propósito, pantallas, modelo de datos y derivaciones de lectura usando la información real que ya existe en `Menudeo`, `Mayoreo Ventas` y `Mayoreo Compras`.

## Propósito

`Desarrollo Comercial` debe ser una superficie ligera para:

- aprender el negocio actual
- entender materiales, precios, volúmenes y actores clave
- detectar oportunidades nuevas
- detectar caídas de volumen o enfriamiento comercial
- dar seguimiento puntual a prospectos, clientes y proveedores

No debe convertirse en un cuarto catálogo maestro del negocio.

## Regla madre

`Desarrollo Comercial` no captura la verdad maestra de:

- materiales
- precios vigentes operativos
- tickets
- reportes de venta
- compras históricas

La verdad maestra sigue naciendo en:

- `Menudeo`
- `Mayoreo Ventas`
- `Mayoreo Compras`

`Desarrollo Comercial` solo agrega su propia capa:

- seguimiento
- clasificación comercial
- priorización
- observaciones
- alertas
- oportunidades

## Restricción operativa absoluta

`Desarrollo Comercial` es un área de lectura, análisis y seguimiento.

No es un área operativa autorizada para cambiar información fuente de:

- `Menudeo`
- `Mayoreo Ventas`
- `Mayoreo Compras`

Regla absoluta:

- el usuario de `Desarrollo Comercial` no puede hacer cambios o ajustes en precios, tickets, catálogos, directorios operativos o configuraciones de esas áreas

Eso incluye:

- no ajustar precios
- no editar contrapartes maestras
- no editar materiales maestros
- no capturar tickets operativos
- no modificar reportes de venta
- no tocar configuraciones de alertas operativas de otras áreas

Su función es:

- leer
- analizar
- dar seguimiento
- detectar señales
- registrar actividad comercial propia

## Regla crítica de segmentación analítica

En `Desarrollo Comercial` no se deben mezclar referencias de precio unitario, volumen típico o benchmark comercial entre contextos que responden a lógicas distintas.

La regla explícita es:

- sí se pueden consolidar importes globales cuando la lectura buscada es empresarial
- no se deben mezclar precios unitarios entre `menudeo` y `mayoreo`
- no se deben mezclar precios unitarios entre tipos distintos de contraparte dentro del mismo canal

Ejemplo operativo:

- no se debe comparar el precio de cartón pagado a un proveedor grande de `menudeo`
con
- el precio de cartón pagable a una `empresa` donde ese material entra como desecho

Porque eso infla o distorsiona promedios y puede llevar a decisiones comerciales peligrosas.

## Qué sí se puede mezclar y qué no

### Sí se puede mezclar

- importes totales comprados
- importes totales vendidos
- lectura empresarial de volumen total
- participación relativa de materiales
- concentración de negocio a nivel empresa

Siempre que la lectura buscada sea:

- empresarial
- ejecutiva
- de escala total

### No se debe mezclar

- precio promedio de compra
- precio promedio de venta
- benchmark unitario de material
- frecuencia típica por tipo de cuenta
- volumen esperado por tipo de contraparte
- alertas de variación que dependan de comportamiento normal

Si la lectura guía una llamada comercial, una compra o una cotización, debe venir segmentada.

## Ejes mínimos de segmentación

Toda lectura comercial relevante debe soportar estos ejes:

- `canal`: `menudeo`, `mayoreo`
- `flujo`: `compra`, `venta`
- `tipo_comercial_contraparte`
- `material`

## Tipos comerciales de contraparte

Además del `kind` básico de la contraparte, `Desarrollo Comercial` necesita una capa más útil para análisis real de mercado.

Campos sugeridos:

- `counterparty_business_type`
- `counterparty_business_group`

Ejemplos de `counterparty_business_type`:

- `empresa_generadora`
- `proveedor_directo`
- `proveedor_grande`
- `acopiador`
- `cliente_final`
- `intermediario`
- `prospecto`

Ejemplos de `counterparty_business_group`:

- `menudeo_proveedor_directo`
- `menudeo_empresa`
- `menudeo_triciclo`
- `mayoreo_proveedor`
- `mayoreo_cliente`
- `mayoreo_intermediario`

Regla explícita:

- los precios unitarios y benchmarks deben calcularse al menos por `canal + flujo + tipo_comercial_contraparte + material`

No basta con saber si una cuenta es `supplier` o `customer`.
Para análisis comercial, eso es demasiado amplio.

## Resultado esperado de Fase 1

La primera entrega debe resolver dos preguntas diarias:

1. `¿A quién debo marcar hoy y por qué?`
2. `¿Qué material, proveedor o cliente se está moviendo mejor o peor que antes?`

Y una tercera regla implícita:

- `¿Cuál precio o volumen es realmente comparable para este tipo de cuenta?`

## Superficie propuesta

Fase 1 se limita a dos páginas:

1. `Radar Comercial`
2. `Directorio y Seguimiento`

No se recomienda una tercera página al inicio.

Las alertas deben vivir dentro de `Radar Comercial` como bloque prioritario.

## Página 1: Radar Comercial

## Propósito de la página

Debe ser la pantalla de lectura principal para la persona de `Desarrollo Comercial`.

Tiene que mezclar:

- contexto del negocio
- lectura de mercado interno
- alertas de variación
- oportunidades de acción inmediata

## Horizontes recomendados

La página debe trabajar con estas ventanas:

- `Últimos 7 días`
- `Últimos 30 días`
- `Mes actual`
- `Mes anterior`
- `Promedio 3 meses`

Para alertas de enfriamiento:

- `Últimos 14 días`
- `Últimos 28 días`
- `Días desde última operación`

## Layout de pantalla

### 1. Fila superior: KPI comerciales

Seis cards homogéneas:

- `Volumen comprado`
- `Volumen vendido`
- `Importe comprado`
- `Importe vendido`
- `Materiales activos`
- `Cuentas con movimiento`

Cada card debe incluir:

- valor principal
- comparación corta contra periodo anterior
- contexto de periodo

Nota:

Estas cards sí pueden consolidar `menudeo` y `mayoreo` cuando la lectura sea empresarial por importe o volumen total.
No deben usarse como fuente de benchmark unitario.

### 2. Segunda fila: alertas y oportunidades

Dos bloques grandes:

Bloque izquierdo:

- `Alertas de variación`

Bloque derecho:

- `Oportunidades comerciales`

### 3. Tercera fila: lectura de mercado

Dos bloques grandes:

Bloque izquierdo:

- `Materiales`

Bloque derecho:

- `Contrapartes`

### 4. Cuarta fila: precios y aprendizaje

Dos bloques grandes:

Bloque izquierdo:

- `Precio compra vs venta`

Bloque derecho:

- `Nuevos para aprender`

## Bloques del Radar

### A. Alertas de variación

Pregunta:

- `¿Qué se enfrió o se movió raro y requiere llamada o visita?`

Debe listar alertas accionables, no solo métricas.

Tipos mínimos:

- caída de volumen por proveedor
- caída de volumen por cliente
- caída de volumen por material
- caída de frecuencia
- concentración de riesgo
- cambio atípico de precio

Cada alerta debe incluir:

- severidad: `informativa`, `atención`, `crítica`
- entidad afectada
- material cuando aplique
- periodo comparado
- explicación corta
- acción sugerida

Ejemplos:

- `Proveedor X bajó 34% su volumen de cartón en los últimos 14 días`
- `Cliente Y tiene 11 días sin compra; su frecuencia normal era cada 4 días`
- `PET cayó 22% contra su promedio reciente`
- `Aluminio depende demasiado de 2 proveedores y uno viene bajando`

### B. Oportunidades comerciales

Pregunta:

- `¿Dónde hay espacio para crecer, recuperar o abrir relación?`

Casos:

- material con alta demanda y poca base de proveedores
- cliente activo con baja frecuencia reciente
- proveedor con material interesante pero ticket pequeño
- spread compra/venta atractivo en material relevante
- prospecto parecido a cuentas activas ya rentables

Cada oportunidad debe incluir:

- prioridad
- motivo
- entidad
- material
- acción sugerida

### C. Materiales

Pregunta:

- `¿Qué materiales mueven el negocio y cómo se comportan?`

Regla de visualización:

- primero mostrar lectura consolidada de empresa cuando sirva
- pero toda lectura de precio unitario debe poder desglosarse por segmento comparable

Por fila:

- material
- volumen comprado
- volumen vendido
- importe comprado
- importe vendido
- precio promedio compra
- precio promedio venta
- tendencia
- alertas asociadas

Los precios promedio deben estar segmentados al menos por:

- canal
- flujo
- tipo comercial de contraparte

Orden sugerido:

- mayor volumen reciente
- o mayor variación negativa

### D. Contrapartes

Pregunta:

- `¿Quiénes son las cuentas más importantes y qué está pasando con ellas?`

La tabla debe mezclar:

- proveedores clave
- clientes clave
- prospectos con seguimiento

Por fila:

- nombre
- tipo
- tipo comercial
- canal principal
- materiales principales
- volumen reciente
- importe reciente
- última operación
- frecuencia histórica
- estado comercial
- siguiente seguimiento

### E. Precio compra vs venta

Pregunta:

- `¿En qué materiales se ve mejor o peor el espacio comercial?`

Regla crítica:

Esta vista no puede mezclar precios de segmentos no comparables.

Debe ofrecer primero selector o partición por:

- `Menudeo`
- `Mayoreo`

Y dentro de cada canal:

- tipo comercial de contraparte

Por material:

- precio promedio compra reciente
- precio promedio venta reciente
- spread estimado
- tendencia de compra
- tendencia de venta
- observación

Nota:

No debe presentarse como margen contable exacto.
Debe presentarse como lectura comercial aproximada.

Nota adicional:

Si no existe comparabilidad limpia entre compra y venta de un material en un segmento dado, la pantalla debe preferir:

- mostrar `sin benchmark comparable`

en vez de inventar un promedio mezclado.

### F. Nuevos para aprender

Pregunta:

- `¿Qué debe estudiar primero una persona nueva en el mercado?`

Debe destacar:

- materiales top por volumen
- proveedores top
- clientes top
- materiales con mayor cambio de precio
- materiales con mayor volatilidad

Este bloque sirve como onboarding vivo.

## Página 2: Directorio y Seguimiento

## Propósito de la página

Debe ser un CRM ligero y operativo.

Desde una sola vista la persona debe poder:

- ver cuentas activas y prospectos
- abrir contactos
- registrar interacción
- programar siguiente seguimiento
- anotar interés por material
- anotar volumen estimado
- marcar prioridad
- ver contexto comercial básico sin salir de la página

## Arquetipo sugerido

- `Grid con panel lateral`

El grid lista cuentas.
El panel lateral muestra:

- contactos
- notas
- últimas interacciones
- próximos pasos
- materiales de interés
- contexto de negocio

## Campos mínimos del grid

- nombre de cuenta
- tipo: `proveedor`, `cliente`, `mixto`, `prospecto`
- origen: `menudeo`, `mayoreo ventas`, `mayoreo compras`, `manual`
- tipo comercial
- grupo comercial
- ciudad o zona
- materiales de interés
- última interacción
- siguiente seguimiento
- prioridad
- estado comercial
- responsable

## Modelo de datos recomendado

### 1. `commercial_accounts`

Tabla maestra ligera de cuentas comerciales.

Campos sugeridos:

- `id`
- `display_name`
- `kind`
- `counterparty_business_type`
- `counterparty_business_group`
- `source_area`
- `source_record_id`
- `city`
- `zone`
- `status`
- `priority`
- `owner_user_id`
- `notes`
- `is_active`
- `created_at`
- `updated_at`

Valores sugeridos:

- `kind`: `supplier`, `customer`, `both`, `prospect`
- `counterparty_business_type`: `empresa_generadora`, `proveedor_directo`, `proveedor_grande`, `acopiador`, `cliente_final`, `intermediario`, `prospecto`
- `counterparty_business_group`: clave analítica compacta del segmento comparable
- `source_area`: `menudeo`, `mayoreo_ventas`, `mayoreo_compras`, `manual`
- `status`: `activo`, `prospecto`, `dormido`, `cerrado`
- `priority`: `baja`, `media`, `alta`, `estrategica`

### 2. `commercial_account_contacts`

Contactos por cuenta.

Campos sugeridos:

- `id`
- `account_id`
- `name`
- `role`
- `phone`
- `email`
- `preferred_channel`
- `notes`
- `is_primary`
- `is_active`
- `created_at`
- `updated_at`

### 3. `commercial_follow_ups`

Bitácora comercial y próximos pasos.

Campos sugeridos:

- `id`
- `account_id`
- `contact_id`
- `interaction_at`
- `interaction_type`
- `summary`
- `next_action`
- `next_follow_up_at`
- `material_interest_snapshot`
- `estimated_volume_snapshot`
- `price_reference_snapshot`
- `status`
- `created_by`
- `created_at`

Valores sugeridos:

- `interaction_type`: `llamada`, `whatsapp`, `visita`, `correo`, `cotizacion`, `seguimiento`
- `status`: `abierto`, `hecho`, `pospuesto`, `sin_respuesta`

### 4. `commercial_account_material_focus`

Relación opcional entre cuenta y materiales prioritarios.

Campos sugeridos:

- `id`
- `account_id`
- `material_key`
- `material_label`
- `interest_type`
- `priority`
- `notes`

Valores sugeridos:

- `interest_type`: `compra`, `venta`, `ambos`

## Vistas o derivaciones recomendadas

Fase 1 no debe duplicar todo en tablas nuevas.
Debe apoyarse en vistas de lectura que unifiquen áreas.

## Vista 1: `v_commercial_unified_counterparties`

Objetivo:

- unificar contrapartes relevantes de compras, ventas y menudeo

Columnas sugeridas:

- `source_area`
- `source_record_id`
- `name`
- `kind`
- `counterparty_business_type`
- `counterparty_business_group`
- `contact`
- `active`

Uso:

- sembrar cuentas iniciales
- alimentar lookup de directorio
- mostrar origen real del negocio

## Vista 2: `v_commercial_material_market_snapshot`

Objetivo:

- resumir comportamiento reciente por material

Columnas sugeridas:

- `material_key`
- `material_label`
- `channel`
- `flow`
- `counterparty_business_type`
- `counterparty_business_group`
- `buy_volume_7d`
- `buy_volume_30d`
- `sell_volume_7d`
- `sell_volume_30d`
- `buy_amount_30d`
- `sell_amount_30d`
- `avg_buy_price_30d`
- `avg_sell_price_30d`
- `last_activity_at`

Uso:

- bloque de materiales
- bloque de precio compra vs venta
- apoyo para oportunidades

Regla:

- no debe existir una sola fila agregada que mezcle segmentos no comparables para precios

## Vista 3: `v_commercial_counterparty_activity_snapshot`

Objetivo:

- resumir actividad reciente por cuenta

Columnas sugeridas:

- `source_area`
- `source_record_id`
- `name`
- `kind`
- `channel`
- `flow`
- `counterparty_business_type`
- `counterparty_business_group`
- `material_label`
- `volume_14d`
- `volume_30d`
- `amount_30d`
- `last_activity_at`
- `activity_count_30d`
- `avg_days_between_operations`

Uso:

- alertas por proveedor o cliente
- ranking de cuentas
- contexto en el directorio

## Vista 4: `v_commercial_variation_alerts`

Objetivo:

- concentrar alertas derivadas ya calculadas

Columnas sugeridas:

- `alert_type`
- `severity`
- `entity_type`
- `entity_id`
- `entity_label`
- `channel`
- `flow`
- `counterparty_business_type`
- `counterparty_business_group`
- `material_key`
- `material_label`
- `current_value`
- `baseline_value`
- `delta_percent`
- `days_since_last_activity`
- `message`
- `suggested_action`
- `detected_at`

Uso:

- bloque principal de alertas
- filtros por severidad
- exportación o seguimiento posterior

## Reglas de alertas

Las alertas no deben dispararse por una sola comparación débil.

Se recomiendan estas reglas:

### 1. Caída de volumen por proveedor o cliente

Comparar:

- `volumen últimos 14 días`
contra
- `promedio móvil equivalente de 28 o 56 días`

Siempre dentro del mismo segmento:

- canal
- flujo
- tipo comercial de contraparte
- material cuando aplique

Disparar cuando:

- caída mayor a `20%` para alerta de atención
- caída mayor a `35%` para alerta crítica
- con base mínima de volumen histórico para evitar ruido

### 2. Caída de frecuencia

Comparar:

- `días desde última operación`
contra
- `promedio histórico entre operaciones`

Disparar cuando:

- el silencio actual sea al menos `2x` su frecuencia normal

La frecuencia normal debe calcularse contra la propia historia de esa cuenta y contra pares comparables, no contra medias mezcladas del negocio.

Ejemplo:

- si normalmente aparece cada 4 días y ya van 9, debe alertar

### 3. Caída de volumen por material

Comparar:

- `volumen 7d o 14d`
contra
- `promedio de 4 semanas`

Disparar cuando:

- el material tenga masa crítica suficiente
- la caída sea consistente y no un simple hueco de uno o dos días

La referencia debe segmentarse por canal y por tipo comercial cuando el comportamiento esperado sea distinto.

### 4. Riesgo de concentración

Calcular:

- porcentaje del volumen del material concentrado en top 1 o top 2 cuentas

Disparar cuando:

- top 1 supere umbral alto
- o top 2 concentren demasiado
- y además uno de ellos venga cayendo

### 5. Cambio atípico de precio

Comparar:

- precio reciente promedio
contra
- precio vigente o precio promedio de ventana previa

Disparar cuando:

- el delta sea materialmente relevante
- y exista repetición suficiente para no reaccionar a un solo ticket raro

Regla estricta:

- comparar solo contra benchmark del mismo `canal + flujo + tipo comercial de contraparte + material`

## Acciones sugeridas por tipo de alerta

- `Marcar`
- `Mandar WhatsApp`
- `Visitar`
- `Validar precio`
- `Buscar reemplazo`
- `Recuperar relación`
- `Ofrecer compra`
- `Ofrecer venta`

La alerta debe sugerir una acción concreta, no solo describir el problema.

## Integración con datos existentes

## Fuentes principales

`Menudeo`

- tickets
- contrapartes
- precios

`Mayoreo Compras`

- contrapartes
- materiales
- precios
- tickets
- directorio de proveedores

`Mayoreo Ventas`

- contrapartes
- materiales
- precios
- reportes de venta

## Regla de integración

`Desarrollo Comercial` debe leer y cruzar.

No debe:

- reimportar catálogos manualmente
- volver a capturar precios operativos
- obligar a mantener dos directorios paralelos de la misma cuenta
- modificar información maestra de `Menudeo`
- modificar información maestra de `Mayoreo Ventas`
- modificar información maestra de `Mayoreo Compras`

Sí puede:

- guardar snapshot comercial
- clasificar cuentas
- relacionar materiales de interés
- registrar interacciones

Pero al cruzar debe preservar el contexto analítico original de cada operación:

- si el dato viene de `menudeo`, se mantiene como `menudeo`
- si el dato viene de `mayoreo`, se mantiene como `mayoreo`
- si la cuenta es `empresa_generadora`, no se rebenchmarca con `proveedor_directo`

Y además debe preservar el límite de escritura:

- el cruce de datos no da permiso de edición
- abrir contexto desde `Desarrollo Comercial` no habilita botones para editar el origen
- cualquier dato fuente debe tratarse como `solo lectura` dentro del módulo

## Navegación sugerida

El área debe iniciar con dos accesos:

- `Radar Comercial`
- `Directorio y Seguimiento`

Accesos cruzados recomendados:

- desde una alerta abrir la cuenta en `Directorio y Seguimiento`
- desde una cuenta abrir su contexto de materiales y actividad
- desde una oportunidad abrir filtro de material correspondiente

## Permisos mínimos

### Usuario de desarrollo comercial

- ver radar
- ver alertas
- ver oportunidades
- alta y edición de cuentas comerciales
- alta y edición de contactos
- registro de seguimientos
- edición exclusiva de sus propios snapshots, notas y clasificaciones comerciales
- sin permisos de edición sobre catálogos, tickets, precios o directorios operativos de otras áreas

### Dirección o administración

- todo lo anterior
- ver todos los responsables
- re-clasificar cuentas
- depurar duplicados
- ajustar umbrales de alertas en fase futura

Nota de permisos:

- incluso con acceso de `Dirección`, los accesos de `Desarrollo Comercial` no deben reutilizar componentes editables de `Menudeo` o `Mayoreo`
- si un perfil necesita editar `Menudeo` o `Mayoreo`, eso debe ocurrir entrando a esas áreas con sus permisos y flujos propios, no desde `Desarrollo Comercial`

## Contrato de UI y permisos

Dentro de `Desarrollo Comercial`, cualquier dato proveniente de otras áreas debe mostrarse como lectura:

- labels
- métricas
- tablas
- snapshots
- contexto histórico

No deben aparecer:

- botones de `Editar precio`
- acciones de `Guardar catálogo`
- acciones de `Crear ticket`
- acciones de `Modificar contraparte maestra`
- accesos inline que reusen formularios operativos de otras áreas

Si existe navegación cruzada, debe ser:

- a detalle de lectura
- o a abrir explícitamente otra área según permisos del usuario

Pero nunca como edición embebida desde `Desarrollo Comercial`.

## Criterios de éxito de Fase 1

La fase queda bien resuelta si la persona nueva puede:

- entender cuáles son los materiales más importantes
- identificar proveedores y clientes clave
- detectar rápido una caída de volumen o frecuencia
- distinguir qué benchmark aplica para cada tipo de cuenta
- saber a quién marcar hoy
- registrar sus seguimientos sin salir a hojas externas

## Qué no hacer en Fase 1

- construir ERP nuevo dentro de desarrollo comercial
- duplicar catálogos completos
- crear demasiados estatus o pipelines
- meter automatizaciones complejas de scoring
- convertirlo en CRM pesado

## Recomendación de implementación

Orden sugerido:

1. Crear tablas ligeras de seguimiento comercial
2. Crear vistas unificadas de lectura
3. Construir `Radar Comercial`
4. Construir `Directorio y Seguimiento`
5. Agregar alertas derivadas por variación

## Nota final

El mayor valor de esta área no está en capturar más datos.

Está en transformar los datos que ya existen en:

- señales
- contexto
- prioridades
- seguimiento accionable

Ese debe ser el criterio rector de todo el módulo.
