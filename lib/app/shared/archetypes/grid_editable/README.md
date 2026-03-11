# Grid Editable Archetype

Arquetipo base para tablas editables como superficie principal.

Referencia funcional homologada: `Entradas y Salidas`.

## Alcance

Usalo para paginas nuevas que necesiten:

- toolbar externa con acciones
- insert row
- grid editable
- seleccion simple o multiple
- edicion inline
- paginacion o metricas dentro del modulo

## Piezas iniciales

- `grid_editable_shell.dart`
- `grid_editable_controller.dart`
- `grid_keyboard_shell.dart`
- `grid_navigation_controller.dart`
- `grid_selection_controller.dart`
- `filters/date_range_filter_bar.dart`
- `filters/grid_filter_dialog.dart`
- `filters/grid_filter_state.dart`
- `insert_row/insert_row_text_field.dart`
- `insert_row/insert_row_number_field.dart`
- `insert_row/insert_row_date_field.dart`
- `insert_row/insert_row_picker_cell.dart`
- `inline/inline_editable_text_cell.dart`
- `inline/inline_editable_number_cell.dart`
- `inline/inline_editable_date_cell.dart`
- `inline/inline_editable_picker_cell.dart`
- `row/editable_grid_row_shell.dart`
- `row/editable_grid_context_menu.dart`
- `row/editable_row_actions_button.dart`

## Regla de adopcion

Una pagina nueva no debe volver a resolver foco, teclado, hover editable o seleccion de filas con widgets ad hoc si ya existe wrapper oficial aqui.

## Contrato minimo

- foco inicial en el primer campo del insert row
- primer click escribe
- `ArrowUp/ArrowDown` coordinan insert row y grid
- `ArrowLeft/ArrowRight` coordinan la celda activa
- el shell de teclado debe centralizar `Esc`, `Enter`, `Delete`, `Space` y flechas
- `Enter` guarda o inserta
- `Esc` cancela sin destruir seleccion valida
- `Delete/Backspace` fuera de input operan sobre seleccion
- click derecho y `...` deben poder compartir acciones
- los filtros popup deben ofrecer `Aplicar`, `Limpiar` y `Cancelar`
