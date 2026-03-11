# UI Contract Implementation Backlog

Backlog tecnico para convertir el contrato UI/UX de DICSA en infraestructura reusable para paginas nuevas.

No reemplaza `DICSA_APP_UI_STANDARD.md`.

Su objetivo es traducir el contrato a componentes, controladores, shells y utilidades implementables.

## Regla de alcance

- pantallas existentes: solo fixes puntuales
- pantallas nuevas: uso obligatorio del kit reusable que aplique
- este backlog se cierra por bloques reutilizables, no por modulo de negocio

## Estado actual

Base ya creada:

- `shared/ui_contract_core/`
- `shared/archetypes/grid_editable/`
- `shared/archetypes/grid_editable_tabbed/`
- `shared/archetypes/auxiliary_surfaces/`
- `shared/archetypes/workflow_master_detail/`
- `shared/archetypes/dashboard/`
- `shared/archetypes/operacion_hibrida_tabs/`

Cobertura actual:

- foco y coordinacion de escritura reutilizable
- guardas de teclado e intents base
- refresh diferido/lifecycle base
- shell modal, popup, menu, date picker y confirm dialog base
- tokens, glass y botones base
- permisos UI base
- `grid_editable` con seleccion, contexto, filtros, marquee y demos
- `grid_editable_tabbed` con acciones, metricas, refresh y demo
- `auxiliary_surfaces` con picker buscable y date picker
- `workflow_master_detail`, `dashboard` y `operacion_hibrida_tabs` con shell + demo

Madurez actual por arquetipo:

- `grid_editable`: fuerte
- `auxiliary_surfaces`: fuerte
- `grid_editable_tabbed`: fuerte
- `workflow_master_detail`: media-alta
- `dashboard`: media-alta
- `operacion_hibrida_tabs`: media

Cobertura pendiente:

- subir `operacion_hibrida_tabs` a media-alta
- mas componentes de detalle/contexto en `workflow_master_detail`
- overlays/responsive/hover mas finos en `dashboard`
- mayor integracion de refresh real por timer/realtime
- snippets y adopcion formal por equipo

## Definicion de terminado

Un bloque reusable se considera cerrado solo si:

- no depende de negocio
- tiene API utilizable por una pagina nueva
- esta documentado
- tiene demo o caso minimo de uso
- pasa `dart analyze`
- cubre mouse y teclado cuando el contrato lo exige

## Fase 1: Core transversal

Prioridad: critica

Objetivo:
- cerrar reglas que aplican a toda la app antes de profundizar arquetipos

### 1.1 Foco y escritura

Archivos objetivo:

- `ui_contract_core/focus/focus_utils.dart`
- `ui_contract_core/focus/editable_focus_coordinator.dart`
- `ui_contract_core/focus/focus_contract.dart`

Entregables:

- helper para detectar `EditableText` activo
- activacion por `pointer down`
- `requestFocus` y seleccion diferida estandarizados
- proteccion contra rebuilds que roban caret
- helper para click afuera / `TapRegion`

Criterio de terminado:

- primer click escribe
- caret no se pierde en refresh o rebuild esperado
- click afuera respeta guardar/cancelar segun contexto

### 1.2 Teclado y shortcuts

Archivos objetivo:

- `ui_contract_core/keyboard/editable_input_key_guard.dart`
- `ui_contract_core/keyboard/grid_keyboard_contract.dart`
- `ui_contract_core/keyboard/shortcut_maps.dart`

Entregables:

- guardas para `Delete`, `Backspace`, `Enter`, `Esc`, `Space`
- distincion formal entre foco en input y foco en grid
- mapa base de shortcuts reutilizable
- helpers para `Cmd/Ctrl`, `Shift`, `Alt` cuando apliquen

Criterio de terminado:

- dentro de input, borrar texto nunca elimina filas
- fuera de input, el grid puede ejecutar su accion
- `Enter/Esc/Space` respetan el contrato activo

### 1.3 Refresh silencioso

Archivos objetivo:

- `ui_contract_core/refresh/deferred_refresh_controller.dart`
- `ui_contract_core/refresh/realtime_refresh_coordinator.dart`
- `ui_contract_core/refresh/edit_safe_refresh_guard.dart`

Entregables:

- coalescing entre timer, realtime y resume
- refresh diferido durante edicion/captura
- hooks para reintento o pending refresh

Criterio de terminado:

- no roba foco
- no tumba inline edit
- no dispara doble recarga innecesaria

### 1.4 Tema, glass y botones base

Archivos objetivo:

- `ui_contract_core/theme/contract_tokens.dart`
- `ui_contract_core/theme/area_theme_scope.dart`
- `ui_contract_core/theme/glass_styles.dart`
- `ui_contract_core/theme/contract_buttons.dart`

Entregables:

- tokens semanticos por area
- `ThemeExtension` o wrapper equivalente
- boton primario/secundario/ghost homologado
- utilidades glass de cards, paneles y modales

Criterio de terminado:

- una pagina nueva no necesita hardcodear color/sombra/radio
- cambio de area no cambia el comportamiento del componente

### 1.5 Dialogos, popups y superficies auxiliares

Archivos objetivo:

- `ui_contract_core/dialogs/contract_dialog_shell.dart`
- `ui_contract_core/dialogs/contract_popup_surface.dart`
- `ui_contract_core/dialogs/contract_menu_surface.dart`

Entregables:

- shell modal homologado
- popup anclado homologado
- menu contextual homologado
- cierre con `Esc`
- foco inicial configurable

Criterio de terminado:

- dialogos, pickers y menus se sienten de la misma familia
- no se reimplementa blur, padding, borde o close behavior por pantalla

### 1.6 Roles y permisos de UI

Archivos objetivo:

- `ui_contract_core/permissions/visibility_guard.dart`
- `ui_contract_core/permissions/action_permission.dart`

Entregables:

- wrappers para mostrar/ocultar acciones
- wrappers para habilitar/deshabilitar acciones con copy consistente
- integracion limpia con permisos del modulo

Criterio de terminado:

- el componente no decide negocio
- la UI no duplica la misma regla de permiso en cada pagina

## Fase 2: Arquetipo Grid Editable

Prioridad: critica

Objetivo:
- convertir la referencia funcional de `Entradas y Salidas` en kit reusable

### 2.1 Shell y estructura

Archivos objetivo:

- `archetypes/grid_editable/grid_editable_shell.dart`
- `archetypes/grid_editable/grid_editable_controller.dart`

Entregables:

- shell con toolbar externa, insert row, body, footer, metricas
- controlador de celda activa y modo de edicion
- hooks para seleccion, filtros y contexto

### 2.2 Insert row completo

Archivos objetivo:

- `insert_row/insert_row_text_field.dart`
- `insert_row/insert_row_number_field.dart`
- `insert_row/insert_row_date_field.dart`
- `insert_row/insert_row_picker_cell.dart`

Entregables:

- texto
- numero
- fecha
- dropdown/picker
- foco inicial configurable
- `Space` abre picker si la celda activa lo requiere

### 2.3 Inline edit completo

Archivos objetivo:

- `inline/inline_editable_text_cell.dart`
- `inline/inline_editable_number_cell.dart`
- `inline/inline_editable_date_cell.dart`
- `inline/inline_editable_picker_cell.dart`

Entregables:

- edicion por doble click cuando aplique
- `Enter` guarda
- `Esc` cancela
- click afuera cancela o guarda segun contrato
- multiedicion compatible

### 2.4 Seleccion y navegacion

Archivos objetivo:

- `grid_selection_controller.dart`
- `grid_navigation_controller.dart`
- `row/editable_grid_row_shell.dart`

Entregables:

- seleccion simple
- `Ctrl/Cmd + click`
- `Shift` para extension
- anchor row
- navegacion con flechas
- coordinacion insert row <-> grid

### 2.5 Context menu, click derecho y acciones de fila

Archivos objetivo:

- `row/editable_grid_context_menu.dart`
- `row/editable_row_actions_button.dart`

Entregables:

- click derecho homologado
- menu `...` con mismas acciones
- click derecho sobre no seleccionada selecciona y luego abre menu
- persistencia de seleccion valida al abrir menu

### 2.6 Hovers, active cell y estados visuales

Archivos objetivo:

- `row/editable_grid_row_shell.dart`
- `inline/editable_cell_hover_shell.dart`

Entregables:

- hover de fila
- hover de celda editable encapsulado
- borde de celda activa
- estado selected / multiselect / editing

### 2.7 Filtros homologados

Archivos objetivo:

- `filters/grid_filter_dialog.dart`
- `filters/grid_filter_state.dart`
- `filters/date_range_filter_bar.dart`

Entregables:

- popup de filtro tipo Excel
- busqueda
- checkboxes
- `Aplicar / Limpiar / Cancelar`
- cierre con `Esc`
- rango de fechas homologado

### 2.8 Drag y marquee

Archivos objetivo:

- `selection/marquee_selection_overlay.dart`
- `selection/drag_selection_controller.dart`

Entregables:

- arrastre de seleccion cuando el modulo lo soporte
- compatibilidad con scroll del grid

## Fase 3: Arquetipo Grid Editable Tabulado

Prioridad: alta

Objetivo:
- volver reusable el patron de `Produccion`

### 3.1 Coordinacion de tabs

Archivos objetivo:

- `grid_editable_tabbed/grid_tabbed_controller.dart`
- `grid_editable_tabbed/grid_tabbed_shell.dart`

Entregables:

- tab activa
- toolbar coherente con tab activa
- persistencia de contexto al cambiar tab

### 3.2 Metricas y resumen por tab

Archivos objetivo:

- `grid_editable_tabbed/tab_metric_header.dart`

Entregables:

- card de metrica reutilizable
- subtitulo y conteo homologados

### 3.3 Refresh y foco entre tabs

Entregables:

- cambio de tab sin robar foco innecesario
- refresh diferido por tab
- coordinacion con seleccion y edicion

## Fase 4: Auxiliary Surfaces

Prioridad: alta

Objetivo:
- cerrar modales, pickers y catalogos modales como familia reusable

Bloques:

- `modal_shell.dart`
- `searchable_picker.dart`
- `catalog_modal_shell.dart`
- `date_picker_surface.dart`
- `confirmation_dialog.dart`

Criterio de terminado:

- `Esc` cierra cuando aplica
- `Enter` confirma cuando aplica
- foco inicial consistente
- glass y botones homologados

## Fase 5: Workflow Master-Detail

Prioridad: media

Objetivo:
- bajar el patron de `Mantenimiento` a infraestructura reusable

Bloques:

- shell lista + detalle
- controlador de seleccion master-detail
- toolbar de workflow
- panel de resumen/estado
- menu contextual del item de workflow

## Fase 6: Operacion Hibrida por Tabs

Prioridad: media

Objetivo:
- soportar modulos tipo `Almacen` sin volver a armar shells compuestos desde cero

Bloques:

- shell tabulado operativo
- resumen + tabs + area de trabajo
- coordinador de subarquetipos internos
- refresh unificado del modulo

## Fase 7: Dashboard

Prioridad: media

Objetivo:
- volver reusable la composicion y comportamiento de widgets

Bloques:

- dashboard shell
- widget card homologada
- hover/lift y layout responsivo
- coordinador de recarga silenciosa
- overlays de detalle

## Matriz de cobertura solicitada

Items pedidos y donde se implementan:

- popups: Fase 1.5 y Fase 4
- fechas: Fase 2.2, Fase 2.3 y Fase 4
- filtros: Fase 2.7
- clicks simples: Fase 1.1
- teclado: Fase 1.2
- doble click: Fase 2.3
- arrastre: Fase 2.8
- click derecho: Fase 2.5
- menus: Fase 1.5 y Fase 2.5
- glass: Fase 1.4
- botones: Fase 1.4
- recarga: Fase 1.3
- hovers: Fase 2.6 y Fase 7
- sombras: Fase 1.4
- roles: Fase 1.6
- navegacion: Fase 1.2, Fase 2.4 y Fase 3.3

## Orden recomendado de implementacion real

1. Fase 1.1
2. Fase 1.2
3. Fase 1.3
4. Fase 1.4
5. Fase 1.5
6. Fase 2.2
7. Fase 2.3
8. Fase 2.4
9. Fase 2.5
10. Fase 2.7
11. Fase 3
12. Fase 4
13. Fase 5
14. Fase 6
15. Fase 7

## Regla operativa para trabajo futuro

No arrancar una pagina nueva hasta marcar:

- arquetipo declarado
- wrappers requeridos existentes o planificados
- huecos del contrato identificados
- decision explicita de si el hueco se resuelve en infraestructura o como excepcion justificada
