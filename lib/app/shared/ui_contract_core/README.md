# UI Contract Core

Infraestructura transversal para paginas nuevas.

Esta capa existe para volver ejecutable el contrato global de UI/UX de DICSA. No resuelve negocio; resuelve comportamiento base compartido.

## Responsabilidades

- foco y escritura al primer click
- guardas de teclado para inputs vs grid
- refresh silencioso y diferido
- shells base de dialogos y overlays
- tokens semanticos por area

## No debe contener

- consultas a Supabase
- logica de modulos especificos
- columnas concretas de grids de negocio
- defaults operativos de una pantalla en particular

## Regla de uso

Toda pagina nueva debe consumir esta capa antes de implementar `FocusNode`, `TextField`, `KeyboardListener` o dialogos base desde cero.

Si un comportamiento transversal ya existe aqui, no debe reescribirse localmente salvo excepcion justificada.

## Primera fase

- `focus/focus_utils.dart`
- `keyboard/editable_input_key_guard.dart`
- `refresh/deferred_refresh_controller.dart`
- `dialogs/contract_dialog_shell.dart`
- `theme/contract_tokens.dart`

## Checklist de adopcion

- el primer click debe dejar escribir
- `Delete/Backspace` dentro de input no deben borrar filas
- `Esc` y `Enter` deben respetar el contexto
- el refresh no debe robar foco
- el wrapper debe ser independiente del dominio
