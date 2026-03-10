# New Archetype Page Template

Usa esta plantilla solo para páginas del arquetipo `Grid Editable` o `Grid Editable Tabulado`.

Si la página pertenece a `Workflow Master-Detail`, `Operación Híbrida por Tabs` o `Dashboard`, consulta primero `DICSA_APP_UI_STANDARD.md` y toma la referencia funcional correcta.

## 1) Definir blueprint

```dart
const blueprint = AppPageBlueprint.tabbedGrid(
  pageName: 'inventario_movimientos',
  headerTitle: 'Entradas y Salidas',
  tabs: [
    AppTabSpec(id: 'in', label: 'Entradas', icon: Icons.download_rounded),
    AppTabSpec(id: 'out', label: 'Salidas', icon: Icons.local_shipping_rounded),
  ],
);
```

## 2) Estructura de página (alto nivel)

- `ServicesShell(headerTitle: ..., topContent: ...)`
- `topContent` = toolbar externa (acciones + selección)
- `child` = módulo principal glass
  - tabs folder (si aplica)
  - card de métrica (kg/pacas)
  - grid

## 3) Reglas obligatorias

- misma lógica por teclado y mouse (paridad de acciones)
- foco inicial en fecha del insert row
- dropdowns/pickers del insert row empiezan en `—` si no hay selección previa
- todas las celdas del insert row empiezan vacías por defecto
- navegación con flechas/space/enter/esc/delete
- flechas en insert row mueven highlight y también el foco real de la celda activa
- `Space` abre la celda activa del insert row cuando sea fecha, picker o dropdown
- `ArrowDown` desde insert row entra al grid sin requerir click previo
- `ArrowUp` desde la primera fila visible regresa al insert row sin click previo
- al entrar al insert row desde el grid, con flechas o click, se limpia la selección activa de filas
- multiselección con `Cmd/Ctrl`
- multiselección con mouse: `Cmd/Ctrl + click`
- multiedición con teclado: multiselección + `Enter`
- multiedición con mouse: multiselección + doble click en celda editable
- mientras haya multiedición activa, no colapsar multiselección por navegación/clicks válidos
- no agregar botón o toggle persistente de `Edición cuadrícula`
- filtros header + rango de fechas
- filtros de columna con popup, búsqueda, checkboxes y `Aplicar/Limpiar/Cancelar`
- filtros de columna tipo Excel (icono a la izquierda + popup con checkboxes + Esc + Aplicar/Limpiar/Cancelar como `services`)
- recarga silenciosa (timer + realtime, diferida si hay edición)
- CSV + edición en cuadrícula
- picker dropdown con highlight visible (hover + foco)
- tabla responsive al tamaño del módulo (sin overflow)
- acciones de fila con menú `...` cuando el ancho sea limitado
- click derecho sobre fila abre el mismo menú contextual (`Editar/Eliminar` o `Guardar/Cancelar/Eliminar`)
- click derecho sobre fila no seleccionada: selecciona fila y luego abre menú
- click derecho sobre selección activa: opera sobre esa selección
- hover/sombreado solo en celdas editables + doble click para editar inline
- hover/sombreado editable debe quedar encapsulado en la celda (no extenderse por todo el renglón/módulo)
- doble click en celda editable respeta multiselección activa (entra a multiedición inline sin colapsar selección)
- click afuera de edición inline cancela sin guardar (si no se confirmó)
- `Esc` en multiedición cancela edición sin guardar y conserva selección (otro `Esc` puede limpiar)
- mantener menú `...` aunque exista click derecho (descubribilidad/consistencia; click derecho como acelerador)

## 4) Colores / look

- filtros: usar tokens del area activa sin romper contraste
- pickers de app: usar la misma familia visual del sistema
- toolbar externa y cards: glass style estándar
- grids: copiar tokens/estados visuales desde la implementación homologada del arquetipo (no aproximar)
  - selección primaria
  - multiselección
  - hover de fila
  - borde de celda activa
  - hover de celda editable (cápsula local)

## 5) Validación mínima antes de cerrar

- [ ] mouse + flechas en dropdown muestran opción activa
- [ ] `Enter` inserta/guarda
- [ ] `Esc` cancela/limpia selección
- [ ] `Delete` borra selección
- [ ] `Cmd/Ctrl + flechas` extiende selección
- [ ] `Cmd/Ctrl + click` multiselecciona
- [ ] `Enter` + multiselección entra a multiedición inline
- [ ] tabla se ajusta sin overflow en ancho/alto del módulo
- [ ] filtros de columna funcionan igual que la implementación homologada del arquetipo (icono, popup, Esc, Aplicar/Limpiar/Cancelar)
- [ ] acciones de fila en `...` (si aplica por ancho)
- [ ] click derecho abre menú contextual con mismas acciones
- [ ] click derecho no dispara cancelación por "click afuera"
- [ ] hover editable + doble click para editar
- [ ] hover editable no se extiende por todo el renglón/módulo
- [ ] doble click no colapsa multiselección activa
- [ ] click afuera cancela edición inline sin guardar
- [ ] selección/hover/fila activa usan los mismos tokens y volumen que la implementación homologada del arquetipo
- [ ] recarga no corta captura
- [ ] `dart format`
- [ ] `dart analyze` sin errores
- La logica de seleccion aditiva debe aceptar `Shift` y `Ctrl/Cmd`.
- Los campos del `insert row` que muestran `—` deben guardarse solo si el usuario los selecciona; no se deben mandar defaults ocultos.
