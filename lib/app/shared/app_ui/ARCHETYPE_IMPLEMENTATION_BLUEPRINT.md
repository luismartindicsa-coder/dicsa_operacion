# Arquetipos Implementables

Plan base para convertir el contrato UI/UX de DICSA en infraestructura reusable para paginas nuevas.

## Objetivo

Evitar que foco, teclado, seleccion, refresh, dialogos y estructura visual se vuelvan a resolver pantalla por pantalla.

Las pantallas existentes no se migran por default.

Las pantallas nuevas deben construirse sobre esta base.

## Capas

### 1. `ui_contract_core`

Reglas transversales a toda la app:

- foco y escritura al primer click
- guardas de teclado para `Delete`, `Backspace`, `Enter`, `Esc`
- refresh diferido y silencioso
- shells base para dialogos
- tokens semanticos de area

### 2. `archetypes`

Implementacion reusable por arquetipo:

- `grid_editable`
- `grid_editable_tabbed`
- `workflow_master_detail`
- `operacion_hibrida_tabs`
- `dashboard`
- `auxiliary_surfaces`

## Regla obligatoria

Una pagina nueva debe declarar primero su arquetipo.

No se permite implementar interacciones base del arquetipo desde cero si ya existe wrapper oficial.

## Ubicacion de la infraestructura reusable

```text
lib/app/shared/ui_contract_core/
lib/app/shared/archetypes/
```

Uso esperado:

1. declarar arquetipo
2. importar `ui_contract_core`
3. importar el kit del arquetipo
4. adaptar solo columnas, validaciones y persistencia del modulo

## Orden recomendado

1. `ui_contract_core`
2. `grid_editable`
3. `grid_editable_tabbed`
4. `auxiliary_surfaces`
5. `workflow_master_detail`
6. `operacion_hibrida_tabs`
7. `dashboard`

## Kit minimo inicial

### `ui_contract_core`

- `focus/focus_utils.dart`
- `keyboard/editable_input_key_guard.dart`
- `refresh/deferred_refresh_controller.dart`
- `dialogs/contract_dialog_shell.dart`
- `theme/contract_tokens.dart`

### `grid_editable`

- `grid_editable_shell.dart`
- `grid_editable_controller.dart`
- `grid_selection_controller.dart`
- `insert_row/insert_row_text_field.dart`
- `insert_row/insert_row_number_field.dart`
- `inline/inline_editable_text_cell.dart`
- `inline/inline_editable_number_cell.dart`
- `row/editable_grid_row_shell.dart`

### `grid_editable_tabbed`

- `grid_tabbed_shell.dart`
- `grid_tabbed_controller.dart`

### `auxiliary_surfaces`

- `modal_shell.dart`

## Criterios de aceptacion

Antes de cerrar un wrapper base:

- primer click escribe en inputs editables
- `Delete/Backspace` dentro de input no elimina filas
- `Enter`, `Esc`, `Space` y flechas respetan contrato
- refresh no roba foco
- la implementacion no depende de un modulo de negocio

## Estrategia de adopcion

- pantallas existentes: solo fixes puntuales
- pantallas nuevas: uso obligatorio del arquetipo correspondiente
- modulo nuevo sin arquetipo declarado: no se considera listo para implementacion

## Criterio para aceptar una pagina nueva

Antes de aprobar implementacion:

- el arquetipo esta declarado
- el modulo usa wrappers base del arquetipo
- no hay foco/teclado/refresh reimplementados localmente sin justificacion
- la pagina pasa la checklist del contrato correspondiente

## Entregables minimos

1. carpetas base por capa
2. wrappers reutilizables iniciales
3. pagina demo por arquetipo critico
4. checklist de adopcion tecnica
5. regla de uso documentada en `AGENTS.md` si se decide volverla obligatoria a nivel repo

## Backlog de implementacion

Para cerrar cobertura completa del contrato reusable, seguir:

- `UI_CONTRACT_IMPLEMENTATION_BACKLOG.md`
