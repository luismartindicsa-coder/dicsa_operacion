# Operations UI Standard (DICSA)

Base de reproducibilidad para módulos operativos (`Servicios`, `Entradas/Salidas`, `Producción`, etc.).

## Objetivo

Evitar rediseñar/reparar interacción en cada página nueva.

Toda página operativa debe reutilizar:
- layout shell
- toolbar de acciones
- cards de conteo
- tabs tipo folder (si aplica)
- navegación de teclado
- filtros (incluyendo rango de fechas)
- estilo visual (colores, paddings, radios)

## Regla de Oro

No implementar UX de grid/picker/filtros desde cero en una página nueva.

Se configura una base existente.

## Réplica Visual (Obligatorio)

- Las páginas nuevas/migradas deben ser una réplica visual e interactiva del grid de referencia (`services`) y no una aproximación.
- Antes de estilizar, identificar y reutilizar los mismos tokens/estados del grid base:
  - color de selección primaria
  - color de multiselección
  - color de hover
  - borde de celda activa
  - sombras/elevación de fila
  - radios, paddings y alturas de header/insert row/fila
- Prohibido “inventar” tonos nuevos (ej. azul diferente, teal diferente) si el patrón ya existe en `services`/`inventory`.
- Si no se puede reutilizar un widget completo, extraer constantes/estilos compartidos a `shared/operational_ui` y reutilizarlos.
- Criterio de aceptación visual: no debe sentirse como “otra app” ni cambiar comportamiento/estética entre módulos.

## Layout Estándar

1. Header (`ServicesShell`)
2. `topContent` externo (fuera del módulo glass principal)
   - botones de acción
   - conteo de selección (alineado a la derecha)
3. Módulo principal glass
   - tabs tipo folder (si aplica)
   - card de conteo (kg / pacas / total) si aplica
   - tabla/grid
   - paginación

## Contrato de Widgets de Dashboard (Obligatorio)

Este contrato aplica al dashboard operativo y a cualquier dashboard nuevo.

### Tamaños canónicos

- `S` (Small): cards KPI/resumen corto.
- `M` (Medium): resumen por bloque (ej. material operativo por categoría).
- `L` (Large): gráficos principales.
- `XL` (Giant): paneles verticales tipo teléfono (ej. resumen de servicios).

### Relación de ancho (regla rígida)

- `3 x S` = `1 x L`
- `2 x M` = `1 x L`
- `M` equivale al ancho de `1.5 x S`
- `XL` puede romper esta regla por intención de layout, pero no debe forzar overflow.

### Espaciado

- Usar un único `gap` horizontal/vertical por sección (no mezclar separaciones distintas sin razón funcional).
- No dejar “espacio muerto” entre bloques por alturas fijas artificiales.
- Si un bloque tiene menos contenido, conservar tamaño del widget y resolver sobrante con padding interno o scroll interno.

### Alturas y contenido interno

- Los widgets de un mismo tamaño deben compartir altura fija por categoría (`S`, `M`, `L`, `XL`).
- Los gráficos `L` deben ocupar el alto útil del card (sin `SizedBox` interno que deje vacío innecesario).
- En breakdowns `M` con listas largas, usar scroll interno para no romper la grilla.

### Interacción visual

- Hover desktop: todos los widgets con el mismo comportamiento (mismo lift en px, no porcentual por tamaño).
- Prohibido que el hover de un widget grande invada visualmente el espacio de otro por un desplazamiento desproporcionado.

### Responsive

- Reordenamiento automático al reducir ancho (sin overflow).
- Permitir scroll vertical de página cuando no quepa todo.
- Evitar scroll horizontal global del dashboard (solo usar horizontal dentro de widgets que lo requieran, como series históricas).

### Menú lateral en dashboard

- El botón de navegación vive en el header.
- El panel de navegación se despliega por encima del dashboard (overlay), sin empujar ni recalcular la grilla base.
- No duplicar encabezado “Navegación” dentro del panel si ya existe en el botón disparador.

## Comportamiento Estándar (Teclado)

- `Arrow keys`: navegar insert row y grid
- `Space`: abrir dropdown/fecha o activar celda
- `Enter`: insertar / guardar / confirmar acción primaria
- `Esc`: cancelar edición / limpiar selección
- `Delete`: borrar selección
- `Cmd/Ctrl + Arrow`: extender multiselección
- No permitir subir “por arriba” de la tabla al navegar con flechas
- Foco inicial al abrir página: fecha del insert row

## Filtros

- Header filters en todas las columnas relevantes
- Fechas con rango (inicio/fin)
- Colores de filtros: paleta teal estandarizada
- Dropdown/picker operativo: paleta azul (igual que `services`)
- Hover + foco por teclado deben mostrar opción activa claramente
- Filtros de columnas deben comportarse y verse tipo Excel (`services`):
  - icono de filtro en header por columna
  - icono de filtro colocado a la izquierda del label (como en `services`)
  - estado visual activo/inactivo del icono
  - popup/dialog de filtro con el mismo look operativo (gris-azulado + highlights azules)
  - multiselección con checkboxes cuando el filtro es por valores discretos (estilo `services`)
  - búsqueda + `Seleccionar visibles` + contador de seleccionados en el popup
  - `Esc` cierra filtro sin aplicar
  - `Cancelar / Limpiar / Aplicar` con la misma jerarquía visual del patrón

## Auto Refresh

- Silencioso (sin cortar UI)
- Diferido cuando hay captura/edición activa
- Coalescing de eventos realtime/timer

## Grid

- Insert row inline arriba
- Edición en cuadrícula
- Multiselección
- Borrado masivo
- CSV
- Conteos ajustados por filtro

## Paridad Teclado / Mouse (Obligatorio)

- La tabla debe ofrecer las mismas acciones por teclado y por mouse (misma intención, distinto input)
- Multiselección:
  - Teclado: `Cmd/Ctrl + flechas` (extender selección)
  - Mouse: `Cmd/Ctrl + click`
- Multiedición / edición inline:
  - Teclado: multiselección + `Enter`
  - Mouse: multiselección + doble click en celda editable
- Mientras la multiedición esté activa, no se debe colapsar ni perder la multiselección por navegación/clicks válidos dentro del grid
- Salir de edición sin guardar:
  - Teclado: `Esc` (sale de edición y conserva selección); segundo `Esc` puede limpiar selección
  - Mouse: click fuera de la celda/campo editable (click primario)
- Eliminar / multieliminar:
  - Teclado: `Delete` / `Backspace`
  - Mouse: click derecho sobre fila/selección -> `Eliminar`
- Guardar:
  - Teclado: `Enter`
  - Mouse: menú contextual (`...` o click derecho) -> `Guardar`

## Grid Responsive (Obligatorio)

- La tabla debe ajustarse automáticamente al tamaño del módulo/página para evitar `overflow`
- Priorizar reducción de densidad antes de depender de scroll horizontal
- Scroll horizontal solo como fallback (último recurso)
- Considerar en el cálculo de ancho: paddings internos/externos, márgenes y scrollbars
- En pantallas/módulos compactos usar acciones por menú `...` en vez de múltiples iconos

## Acciones de Fila

- Estándar preferido: menú `...` (overflow menu) para `Editar / Eliminar`
- Soportar también click derecho sobre fila para abrir el mismo menú contextual (misma lógica de acciones)
- Si el click derecho ocurre sobre una fila no seleccionada, primero se selecciona esa fila y luego se abre el menú
- Si el click derecho ocurre sobre una fila ya seleccionada (o grupo seleccionado), el menú debe operar sobre esa selección
- En modo edición, el menú `...` debe ofrecer `Guardar / Cancelar / Eliminar`
- En multiedición, `Esc` sale de edición sin guardar y mantiene la multiselección; un segundo `Esc` (ya fuera de edición) puede limpiar selección
- Evitar iconos inline múltiples cuando roban espacio o provocan overflow
- Recomendado mantener `...` aunque exista click derecho (descubribilidad + soporte touch/trackpad + consistencia visual)

## Descubribilidad de Edición (Mouse)

- Hover/sombreado de celda debe aparecer solo en celdas editables
- El sombreado/hover editable debe quedar contenido en la celda (no expandirse visualmente a todo el ancho del renglón/módulo)
- Celdas no editables no deben aparentar que aceptan edición
- Doble click en celda editable entra a modo edición inline
- Si existe multiselección activa y se hace doble click en una fila seleccionada, debe preservarse la multiselección y entrar a multiedición inline del grupo (igual que `Enter`)
- Click fuera de la celda/campo en edición inline cancela edición sin guardar (si no se confirmó con `Enter`/Guardar)

## Estilo

- Reusar radios/padding/espaciado del kit operativo
- Mantener consistencia visual entre módulos
- Evitar variantes nuevas de botones/diálogos si ya existe patrón
- Para grids: replicar estructura visual de `services` (header, insert row, filas tipo card, selección azul oscuro con borde/sombra suave y volumen 3D)

## Checklist (Definition of Done)

- [ ] Toolbar externa debajo del logo (fuera del módulo principal)
- [ ] Conteo de selección alineado con botones
- [ ] Card(s) de métrica con altura consistente
- [ ] Insert row con foco inicial en fecha
- [ ] Navegación por flechas/Space/Enter/Esc/Delete
- [ ] Multiselección con `Cmd/Ctrl`
- [ ] Paridad teclado/mouse en selección, edición, guardado y eliminación
- [ ] Filtros header + rango de fechas
- [ ] Filtros de columna tipo Excel (icono + popup con mismo look/acciones de `services`)
- [ ] Picker con highlight hover/foco visible
- [ ] CSV
- [ ] Recarga silenciosa sin cortes visuales
- [ ] Tabla ajusta al tamaño del módulo sin overflow
- [ ] Acciones de fila en menú `...` cuando el ancho es limitado
- [ ] Click derecho abre menú contextual con la misma lógica de acciones
- [ ] Click derecho no cancela edición por conflicto con "click afuera"
- [ ] Hover/sombreado solo en celdas editables + doble click para editar
- [ ] Hover/sombreado editable queda encapsulado en la celda (no invade todo el módulo)
- [ ] Doble click respeta multiselección activa (no colapsa selección)
- [ ] Click afuera cancela edición inline sin guardar
- [ ] Paleta/estados visuales (hover/selección/activa) coinciden con `services` (sin tonos alternos)
- [ ] Dashboard cumple contrato de widgets (`S/M/L/XL`, regla `3S=1L=2M`, gaps consistentes y sin espacio muerto)
- [ ] `dart format` y `dart analyze` sin errores

## Contrato Maestro Replicable (Base Entradas/Salidas)

Aplicar este bloque completo en cualquier página operativa nueva o migrada.

### 1) Botones de acción (`Navegación`, `Cerrar sesión`, `Recargar`, `EXTRAS`, `Agregar`, `...`)

- Estilo `glass see-through` (no botón plano de texto).
- Hover con elevación clara: escala + traslación + sombra profunda.
- Debe sentirse que “sale de la pantalla” en hover.
- Diferenciar intención por tinte:
  - `EXTRAS`: verde más claro.
  - `Agregar`: verde más intenso.
  - Navegación/sesión/recarga: mismo lenguaje visual del dashboard (no variantes aisladas).
- Todos los botones operativos deben mantener radios, alturas y peso tipográfico consistentes.

### 2) Insert Row

- Foco inicial en fecha.
- Navegación por teclado total:
  - `Arrow Left/Right`: mover celda.
  - `Arrow Down`: pasar al grid.
  - `Space`: abrir picker/celda activa.
  - `Enter`: insertar.
  - `Esc`: salir de campo y conservar contexto.
  - `Delete/Backspace`: limpiar valor de celda activa (sin borrar fila).
- Validación antes de insertar:
  - Mostrar popup con campos faltantes (sin deshabilitar permanentemente el botón).
- Colores:
  - fondo glass azul pastel.
  - foco azul operativo.
  - sin verde chillón.

### 3) Listas de dropdown y menús de acciones

- Dropdowns y menús deben ser glass (see-through) y redondeados.
- Foco inicial al abrir lista: cuadro de búsqueda.
- Navegación por teclado:
  - flechas mueven foco.
  - `Enter` selecciona.
  - `Esc` cierra.
- La opción enfocada debe permanecer visible (auto-scroll interno).
- Hover de opciones: rápido, sin “arrastre” visual entre items.
- Menú de acciones (`...`) y click derecho deben compartir la misma lógica.

### 4) Edición por celdas y multiedición

- Click simple en celda editable: selecciona fila de inmediato.
- Doble click en celda editable: entra a edición.
- Click fuera de edición inline: cancelar sin guardar.
- `Enter` guarda; `Esc` cancela.
- En multiedición:
  - `Enter` aplica guardado a todas las filas en edición del grupo.
  - `Esc` cancela edición de todo el grupo (no solo celda actual).
- `Delete`/`Backspace`:
  - en modo edición de texto: editar texto (no eliminar fila).
  - en modo selección: eliminar fila(s) seleccionadas.

### 5) Multiselección (todos los medios)

- Soportar:
  - `Cmd/Ctrl + click`
  - `Shift`/teclado extendido
  - marquee drag (cuadro de selección con mouse)
  - click derecho sobre selección existente
- La selección debe persistir al abrir menú contextual.
- Click derecho sobre selección múltiple debe habilitar acciones en bloque.
- Auto-scroll durante drag debe mantener el ancla de selección.

### 6) Focos, contornos y hover

- Foco de celda activa: un solo perímetro azul, limpio y alineado.
- No permitir doble borde (interno + externo compitiendo).
- Hover editable:
  - visible, pero contenido dentro de celda.
  - no invadir la celda vecina.
  - no tapar texto.
  - sombra recortada (si se usa), nunca atravesar divisores.
- En fila seleccionada azul, el hover de celda debe armonizar (no verde discordante).

### 7) Visualización de tabla

- Filas tipo card con volumen suave.
- Divisores verticales finos entre celdas (consistentes).
- Material en badge de color por categoría.
- Unidad en badge/cápsula compacta.
- `IN/OUT` en badge compacto (sin ancho sobrante artificial).
- Columnas de números con tipografía/peso legible y estable.

### 8) Números y formato

- Todo número visible al usuario debe llevar separador de miles con coma:
  - contadores
  - totales
  - métricas
  - kg/peso/promedios
  - paginación (cuando aplique)
- Mantener decimales por tipo de dato (ej. kg con 2, promedio configurable).

### 9) Popups, filtros y dialogs

- Mismo estilo glass operativo.
- Botones y jerarquía consistentes: `Cancelar / Limpiar / Aplicar`.
- `Esc` cierra dialogs y menús contextuales.
- Filtros de columna tipo Excel con estados claros y búsqueda.

### 10) Rendimiento percibido y rapidez operativa

- Selección de fila/celda debe sentirse inmediata (sin lag perceptible).
- Recarga automática silenciosa y diferida durante captura/edición.
- No interrumpir trabajo activo por refresh.

### Criterio de aceptación global

- Cualquier página operativa nueva debe verse y comportarse igual que `Entradas/Salidas` actual.
- Si requiere una excepción, documentarla explícitamente en este contrato antes de implementarla.

## Recomendación de Implementación

Para nueva página:

1. Definir columnas y tipos
2. Definir query/tabla Supabase
3. Definir métricas (kg/pacas/etc.)
4. Conectar a widgets base de `shared/operational_ui`
5. Validar con checklist
