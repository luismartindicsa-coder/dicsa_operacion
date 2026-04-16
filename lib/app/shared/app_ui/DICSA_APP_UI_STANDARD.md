# DICSA App UI Standard

Contrato maestro de UI/UX para toda la app.

Su objetivo es evitar que una página nueva herede reglas incorrectas por copiar un módulo que pertenece a otro tipo de superficie o a otra area.

## Regla de oro

No existe un único contrato visual/funcional para toda la app.

La app tiene varios arquetipos de página. Cada módulo nuevo o refactor debe declarar primero a qué arquetipo pertenece y solo después copiar la referencia correcta.

Operacion no es una excepcion visual ni funcional: es la primera implementacion homologada del sistema UI transversal de DICSA.

Formula obligatoria para cualquier pagina nueva:

`pagina nueva = arquetipo funcional + implementacion homologada de referencia + paleta del area + datos del modulo`

## Orden obligatorio de implementación

1. Identificar el arquetipo correcto de la página.
2. Clonar 1:1 la referencia funcional de ese arquetipo.
3. Adaptar únicamente campos, columnas, copy y validaciones del módulo.
4. Reusar tokens visuales existentes.
5. Validar paridad funcional antes de cerrar estilo fino.

## Fuente de verdad por arquetipo

### 1. Grid Editable

Referencia funcional principal:
- `Entradas y Salidas`

Referencia visual secundaria:
- `Servicios`, pero solo para tokens o acabados visuales que ya existan

Aplica a:
- cualquier pagina con tabla editable como superficie principal
- implementaciones homologadas actuales:
  - `Entradas y Salidas`
  - `Servicios`
  - `Pesadas`

### 2. Grid Editable Tabulado

Referencia funcional principal:
- `Producción`

Aplica a:
- `Producción`
- secciones tabuladas que reutilicen el mismo patron de grid

### 3. Workflow Master-Detail

Referencia funcional principal:
- `Mantenimiento`

Aplica a:
- flujos tipo lista + detalle + acciones de proceso

### 4. Operación Híbrida por Tabs

Referencia funcional principal:
- `Almacén`

Aplica a:
- páginas con resumen, catálogo, movimientos, cortes o reportes dentro de un mismo módulo tabulado

### 5. Dashboard

Referencia funcional principal:
- `Dashboard`

Aplica a:
- páginas de resumen ejecutivo u operativo basadas en widgets

### 6. Superficies Auxiliares

Aplica a:
- `Login`
- `Splash`
- diálogos operativos
- pickers
- catálogos modales

## Contrato global compartido

Estas reglas sí aplican a toda la app, sin importar arquetipo.

### Shell y navegación

- Reusar `ServicesShell` o `AppShell` según el arquetipo existente.
- El botón de navegación abre overlay; no debe empujar el layout base.
- No agregar un botón manual de recarga si ya existe auto refresh.
- `Cerrar sesión`, ayudas, instructivos y overlays deben usar la misma familia visual.

### Estilo visual

- Reusar el mismo lenguaje visual base de la app.
- Reusar radios, paddings, sombras y elevación del kit existente.
- No introducir tonos nuevos si ya existe equivalente visual aprobado.
- Todos los diálogos deben sentirse de la misma familia glass de DICSA.

### Contrato de identidad visual por area

Esta regla aplica a cualquier area nueva o futura (`Operacion`, `Dashboard general`, `Ventas`, `Finanzas`, `RH`, `Administracion`, etc.).

La identidad visual de la app se divide en dos capas:

1. `Lenguaje visual base` inmutable
2. `Paleta cromatica por area` intercambiable

#### 1. Lenguaje visual base inmutable

Estos elementos no se redisenan por area:

- suavidad general
- glass, blur y opacidad
- radios
- sombras y elevacion
- tipografia
- spacing
- jerarquia visual
- estructura de cards, badges, tablas, modales y shells
- tamano, forma y comportamiento de botones
- hover, focus, selected y pressed
- densidad, animacion y ritmo visual

Regla explicita:
- Un cambio de area no justifica cambiar layout, componentes, comportamiento ni microinteracciones.

#### 2. Paleta cromatica por area

Cada area puede cambiar solo su gama de color a traves de tokens semanticos. Nunca debe cambiar el estilo base del componente.

Tokens minimos por area:

- `area-primary`
- `area-primary-strong`
- `area-primary-soft`
- `area-accent`
- `area-surface-tint`
- `area-border`
- `area-badge-bg`
- `area-badge-text`
- `area-glow`

Reglas obligatorias:

- Los componentes consumen tokens semanticos; no colores hardcodeados.
- Un boton primario sigue siendo el mismo boton; solo cambia el token de color del area.
- Una card glass sigue siendo la misma card; solo cambia el tinte permitido por el area.
- Los estados de exito, alerta, error o neutral no deben contaminarse con el color de area salvo que el contrato lo declare de forma explicita.

#### Restricciones para evitar contraindicaciones

- No cambiar mas de un color dominante y un acento por area sin actualizar este documento.
- No usar una paleta de area para redefinir semanticas de sistema como error, warning o success.
- No subir o bajar blur, opacidad, sombras o bordes para "hacer sentir diferente" un area.
- No meter excepciones visuales por pantalla si el area ya tiene tokens aprobados.
- No resolver necesidades de contraste tocando tipografia o layout antes de corregir la paleta.

#### Implementacion obligatoria

- El tema debe aplicarse por contenedor, shell o contexto de area; no por widget aislado.
- Una pagina nueva debe declarar primero su arquetipo funcional y despues su area visual.
- Si una pagina mezcla modulos de varias areas, domina la paleta del shell anfitrion y los modulos internos no redefinen el kit visual base.

#### Checklist minimo antes de aprobar una pagina de area nueva

- El arquetipo funcional es correcto.
- La pagina reutiliza el mismo lenguaje visual base de la app.
- Todos los colores del area entran por tokens.
- No hay colores hardcodeados dentro de componentes.
- El contraste sigue siendo legible.
- La pagina se siente parte de la misma app, no una subapp distinta.

### Foco y accesibilidad operativa

- Click simple sobre un campo editable debe permitir escribir al primer intento.
- No se permite perder caret por rebuilds estructurales evitables.
- `Esc` debe cerrar overlays, menús y diálogos cuando aplique.
- `Enter` debe confirmar la acción primaria visible del contexto.

### Refresh

- Debe ser silencioso.
- Debe diferirse si hay edición/captura activa.
- Debe hacer coalescing entre timer, realtime y reentrada a foreground.
- No debe robar foco ni tumbar edición inline.

## Arquetipo 1: Grid Editable

Este es el contrato más estricto y el que debe usarse como base cuando una página es realmente una tabla editable.

### Layout

1. Header en `ServicesShell`
2. `topContent` externo:
   - botones de acción
   - info de selección alineada a la derecha
3. Módulo principal glass:
   - header filters
   - insert row
   - grid
   - paginación
   - métricas cuando aplique

Regla de draft inicial:
- Dropdowns y pickers del insert row deben iniciar vacíos (`—`) si el usuario aún no selecciona un valor.
- No precargar el primer valor de una lista como default implícito, salvo que exista una razón operativa explícita.
- El insert row completo debe iniciar vacío; no precargar fecha, estado o catálogos por conveniencia visual.

### Interacción base

- Foco inicial: fecha del insert row
- `Arrow Left/Right`: mover celda activa y transferir el foco operativo a esa celda cuando aplique
- `Arrow Down`: pasar del insert row al grid
- `Arrow Up`: desde la primera fila visible puede regresar al insert row
- `Space`: abrir picker/dropdown o activar la celda activa del insert row o grid
- `Enter`: insertar o guardar
- `Esc`: cancelar edición; un segundo `Esc` puede limpiar selección
- `Delete/Backspace`:
  - dentro de texto: editar texto
  - fuera de texto: eliminar selección

Regla explícita:
- Si el usuario navega el insert row con flechas, no basta con mover el highlight; el foco real debe seguir a la celda activa.
- Si la celda activa es `fecha`, picker o dropdown, `Space` debe abrir esa celda sin requerir click adicional.
- Desde el insert row se puede entrar al grid con flechas verticales; no debe requerirse click para “soltar” el foco.
- Desde la primera fila visible del grid se puede regresar al insert row con `Arrow Up`; no debe requerirse click.
- Al entrar al insert row desde el grid, ya sea con flechas o con click, la selección de filas activa debe limpiarse.

### Selección

- Selección simple por click
- Multiselección con `Ctrl/Cmd + click`
- Extensión por teclado con modificador
- Marquee drag cuando el módulo ya lo soporte
- La selección debe persistir al abrir menú contextual o `...`

Nota:
- El contrato acepta `Ctrl/Cmd` y también `Shift` donde la implementación actual ya lo use para extender selección.
- No imponer una sola variante si eso rompe módulos ya consistentes.

### Edición

- Doble click en celda editable entra a edición inline
- Click afuera cancela edición inline sin guardar
- `Enter` guarda
- `Esc` cancela
- Multiedición:
  - `Enter` aplica al grupo
  - `Esc` cancela el grupo y conserva selección

No introducir:
- botones o toggles persistentes de `Edición cuadrícula`
- modos globales de edición que cambien el contrato base del grid

La edición debe entrar por interacción directa:
- doble click
- `Enter`
- activación de la celda seleccionada
- multiselección + edición del grupo

### Filtros

- Filtros por columna en header
- Fechas con rango
- Popup de filtro con:
  - búsqueda
  - checkboxes de multiselección
  - contador
  - seleccionar/deseleccionar visibles
  - `Aplicar`, `Limpiar`, `Cancelar`
  - `Esc` para cerrar

No usar como patrón base:
- filtros de texto libre simples cuando el grid de referencia ya usa popup por valores
- campos de clasificación estable como texto libre cuando representan catálogos operativos o comerciales repetibles

### Catálogos controlados

- Cuando un campo clasifique entidades de forma repetible y deba usarse después en precios, reglas, reportes o filtros, no debe capturarse como comentario o texto libre.
- Ese tipo de campo debe resolverse como picker/catálogo controlado, aunque visualmente viva dentro del `insert row` o de la edición inline.
- Si existen valores legacy fuera del catálogo:
  - se pueden mostrar para no romper registros históricos
  - pero los nuevos registros y la edición normal deben empujar a los valores homologados
- Catálogo homologado actual para `grupo de contraparte` en Menudeo:
  - `PUBLICO GENERAL`
  - `PROVEEDOR GRANDE`
  - `TRICICLOS`

### Regla de vigencia para precios de Menudeo

- El sistema opera siempre sobre `precio vigente actual`.
- Cada ajuste nuevo absorbe al precio vigente anterior y produce un nuevo vigente.
- Ese nuevo vigente se vuelve la nueva base operativa para el siguiente ajuste.
- No recalcular desde una base histórica congelada.
- No reaplicar automáticamente alzas o bajas que ya quedaron absorbidas por el vigente.
- El modelo se divide en:
  - `precio vigente`
  - `historial de movimientos`
- La tabla o vista de consulta operativa muestra el vigente.
- El historial registra:
  - precio anterior
  - precio nuevo
  - modo de ajuste
  - valor del ajuste
  - motivo
  - usuario
  - fecha

### Acciones por fila

- Mantener menú `...` por descubribilidad
- Soportar click derecho con la misma lógica
- Si el click derecho cae sobre fila no seleccionada:
  - primero selecciona
  - luego abre menú
- El menú debe operar sobre la selección actual

### Checklist de cierre homologado para Menudeo

Este checklist ya quedó probado en `Contrapartes y precios` y debe reutilizarse como contrato para futuras páginas del área.

- Navegación y shell:
  - El botón principal de navegación abre panel lateral/overlay con glass del área.
  - El panel no empuja el layout base; aparece sobre la página.
  - Botones de header y tiles del panel deben tener hover con lift perceptible:
    - leve escala
    - leve desplazamiento vertical
    - sombra/glow más profundos
  - `Esc` cierra panel lateral, menús y diálogos.
- Grid y layout:
  - `insert row`, filas, edición inline y headers comparten exactamente la misma huella horizontal.
  - El slot final de acciones queda siempre anclado y reservado.
  - No se aceptan overflows “pequeños” residuales; deben resolverse estructuralmente.
- Mouse:
  - Click simple selecciona.
  - `Cmd/Ctrl + click` alterna selección dentro del grupo.
  - `Shift + click` extiende rango cuando el arquetipo lo soporte.
  - Drag selection debe seguir el movimiento del mouse, continuar por autoscroll y no resetear selección al soltar.
  - Click derecho primero alinea selección y luego abre contexto.
  - Click afuera cancela edición inline o multiedición sin guardar.
- Teclado:
  - Flechas izquierda/derecha recorren el `insert row`.
  - `ArrowDown` pasa del `insert row` al grid.
  - `ArrowUp` desde la primera fila visible puede regresar al `insert row`.
  - La fila seleccionada debe volver al viewport si el usuario siguió con flechas después de haber hecho scroll.
  - `Enter` guarda edición inline o multiedición.
  - `Esc` cancela edición.
  - `Delete/Backspace` dentro de texto editan texto; fuera de texto operan sobre selección.
- Pickers y filtros:
  - Pickers y filtros popup deben aceptar `ArrowUp/ArrowDown`, `Enter`, `Space` y `Esc`.
  - Los diálogos de filtros heredan tokens del área anfitriona.
  - Clasificaciones operativas/comerciales estables viven como catálogos controlados.
  - En Menudeo, capturas nominales deben normalizarse a mayúsculas limpias cuando aplique.
- Multiedición:
  - La multiedición debe vivir dentro del grid, sobre las filas seleccionadas, no como banda ajena al arquetipo de referencia.
  - `Enter`, `Esc` y `Cmd/Ctrl + S` deben respetar el mismo contrato contextual de la app.
  - La selección no se pierde al abrir `...`, menú contextual o acciones de grupo.

### Descubribilidad visual

- Hover editable solo en celdas editables
- El hover editable debe renderizarse como cápsula local de celda, no como tinte de fila completa
- La cápsula editable puede crecer levemente y sobresalir dentro de la celda para comunicar affordance, siempre sin romper el ancho contractual del row
- El color, glow, borde y tinte del hover editable deben salir de tokens del área; el comportamiento visual y la microanimación se mantienen constantes entre módulos
- La fila debe acomodarse visualmente al hover de celda sin generar saltos bruscos, overflow ni desalineación con header o `insert row`
- La cápsula/hover no debe invadir otras celdas
- Los separadores verticales entre celdas forman parte del contrato visual cuando el arquetipo los use; deben permanecer visibles en estado normal y desvanecerse al entrar el hover editable o la edición activa en esa fila
- Borde de celda activa único, limpio y alineado
- Celdas no editables no deben aparentar edición

### Responsive

- Reducir densidad antes de depender de scroll horizontal
- El scroll horizontal es fallback, no estrategia base
- En ancho limitado, acciones van a `...`
- El contrato responsive de grids debe apoyarse en helpers compartidos, no en ajustes por pantalla

### Ancho estructural y overflow

- Header, `insert row` y filas del grid deben compartir la misma huella horizontal dentro del módulo.
- El ancho contractual de fila debe definirse una sola vez y reutilizarse en header, captura inline, filas normales y filas en edición.
- El wrapper estructural del row debe venir de un helper compartido equivalente a `ContractGridScaledRow`.
- El patrón contractual base para filas escalables es:
  - `Card`
  - `Padding`
  - `ContractGridScaledRow`
  - `Row(mainAxisSize: MainAxisSize.min, children: [...])`
- Las columnas con acción final deben usar un helper compartido equivalente a `AnchoredActionSlot`.
- `AnchoredActionSlot` reserva el ancho del botón/menú y deja el contenido principal anclado a la izquierda para evitar overflow y overlap.
- Si aparece overflow:
  - primero validar que el problema no sea una desalineación entre el ancho del `insert row` y el de las filas renderizadas
  - después revisar celdas compactas con controles como `Switch`, badges o menú `...`
  - después validar que la última columna reserve explícitamente su slot de acción
  - solo al final ajustar densidad o copy; no introducir parches de pixeles como estrategia base
- Si los filtros por columna ya cubren la búsqueda requerida, no duplicar una segunda banda de búsqueda global debajo del `insert row`.

### Definition of Done

- Toolbar externa consistente
- Info de selección alineada
- Insert row con foco inicial correcto
- Navegación completa por teclado
- Edición inline consistente
- Multiselección y multiedición
- Filtros completos por columna
- CSV si el módulo es exportable
- Menú contextual y `...` alineados
- Refresh silencioso sin romper edición
- Sin overflow no intencional

## Arquetipo 2: Grid Editable Tabulado

Hereda todo el contrato de Grid Editable y agrega:

- Tabs tipo folder arriba del módulo principal
- Cambio de tab sin romper shell ni toolbar
- La toolbar externa debe seguir representando el tab activo
- El cambio de tab no debe disparar rebuilds que roben foco innecesariamente
- Cada tab puede tener grid distinto, pero debe conservar el mismo lenguaje visual y de teclado

### Definition of Done

- Tabs con comportamiento folder consistente
- Toolbar/metric/card sincronizadas con el tab activo
- La paridad de grid se mantiene dentro de cada tab

## Arquetipo 3: Workflow Master-Detail

Referencia homologada: `Mantenimiento`

Este arquetipo no se evalúa con el checklist de insert-row/grid puro.

### Layout

- Lista principal a la izquierda o arriba
- Detalle editable a la derecha o abajo
- Toolbar externa con acciones globales
- Cards o resumen de estado cuando aplique

### Interacción

- Flechas mueven la selección de la lista
- La lista conserva foco navegable
- Seleccionar elemento debe cargar detalle sin romper edición activa de forma agresiva
- Acciones del proceso viven en menús, dialogs o toolbar según contexto

### Refresh

- Igual de silencioso que en grids
- No debe sobrescribir detalle mientras el usuario está editando
- Debe actualizar contadores, estatus, adjuntos y aprobaciones sin jitter

### Dialogs y subflujos

- Evidencias, aprobaciones, cambio de estado y exportes deben compartir familia visual
- `Esc` cierra
- `Enter` confirma si hay acción primaria clara

### Definition of Done

- Lista y detalle se entienden como una sola superficie
- El refresh no interrumpe captura
- Los subflujos siguen la misma jerarquía visual y de foco

## Arquetipo 4: Operación Híbrida por Tabs

Referencia homologada: `Almacén`

Este arquetipo mezcla resumen, catálogo, movimientos y reportes en una misma página.

### Reglas

- No forzar que todas las tabs se comporten como un grid editable
- Cada tab puede tener contrato interno distinto, pero todos deben compartir:
  - shell
  - tabs
  - toolbar externa
  - tokens visuales
  - refresh silencioso

### Definition of Done

- La página se siente como un solo módulo
- Las tabs no parecen subapps distintas
- Los grids/listas internas sí respetan el arquetipo que les corresponda

## Arquetipo 5: Dashboard

Referencia homologada: `Dashboard`

### Layout

- Navegación overlay
- Grilla responsive de widgets
- Sin scroll horizontal global
- Scroll vertical permitido

### Widgets

- Tamaños canónicos:
  - `S`
  - `M`
  - `L`
  - `XL`
- Mantener alturas consistentes por categoría
- Hover consistente en todos los widgets
- Sin espacio muerto artificial

### Definition of Done

- Reacomodo limpio por ancho
- Sin overflow
- Gaps consistentes
- Overlay nav no empuja la grilla

## Arquetipo 6: Superficies Auxiliares

### Aplica a

- Login
- Splash
- dialogs
- popups de confirmación
- selectores de fecha
- catálogos modales

### Reglas

- Misma familia visual que la app
- Acción primaria y secundaria claras
- `Esc` cierra si aplica
- `Enter` confirma si aplica
- Foco inicial definido cuando haya captura

## Reglas que quedan descartadas o ajustadas

Estas reglas no deben seguir tratándose como verdad universal:

- “Toda página de la app debe ser réplica 1:1 de Entradas y Salidas”
  - Incorrecto para `Mantenimiento`, `Almacén` y `Dashboard`

- “Servicios” como base funcional general
  - `Servicios` puede seguir siendo referencia visual puntual, no segunda fuente de verdad funcional

- “Un solo checklist para toda la app”
  - Debe haber checklist por arquetipo

- “Cmd/Ctrl + Arrow” como único patrón válido de extensión
  - El estándar definitivo acepta también `Shift` donde ya forma parte del comportamiento consistente del módulo

## Criterio de aceptación final por módulo

Un módulo se considera terminado solo si:

1. Está clasificado en el arquetipo correcto.
2. Respeta el contrato global compartido.
3. Respeta el contrato específico de su arquetipo.
4. Mantiene consistencia visual con el resto de la app.
5. No introduce comportamiento nuevo sin actualizar este documento.

## Uso obligatorio en cambios futuros

Antes de crear o refactorizar una página:

1. Declarar arquetipo.
2. Declarar referencia funcional.
3. Declarar tokens visuales a reutilizar.
4. Validar Definition of Done del arquetipo correspondiente.

## Relación con otros archivos

- `AGENTS.md` define la regla base de paridad frontend a nivel repositorio.
- `NEW_ARCHETYPE_PAGE_TEMPLATE.md` debe usarse solo para páginas del arquetipo `Grid Editable` o `Grid Editable Tabulado`.
- `AREA_PALETTES_CONTRACT.md` define las areas oficiales, las paletas congeladas y la direccion cromatica aprobada para areas nuevas.
- La extension de seleccion en grids debe aceptar `Shift` y `Ctrl/Cmd` en flechas, click aditivo y marquee. No se permite limitarla solo a `Ctrl/Cmd`.
- Si un dropdown o picker del `insert row` inicia vacio con `—`, el guardado no debe inyectar un default implicito al enviar. El usuario debe elegir el valor o la pagina debe declararlo de forma operativa y visible.
