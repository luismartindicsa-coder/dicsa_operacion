# New Operational Page Template

Usa esta plantilla para crear una página operativa nueva sin romper el estándar.

## 1) Definir blueprint

```dart
const blueprint = OperationalPageBlueprint.tabbedGrid(
  pageName: 'inventario_movimientos',
  headerTitle: 'Entradas y Salidas',
  tabs: [
    OperationalTabSpec(id: 'in', label: 'Entradas', icon: Icons.download_rounded),
    OperationalTabSpec(id: 'out', label: 'Salidas', icon: Icons.local_shipping_rounded),
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
- navegación con flechas/space/enter/esc/delete
- multiselección con `Cmd/Ctrl`
- multiselección con mouse: `Cmd/Ctrl + click`
- multiedición con teclado: multiselección + `Enter`
- multiedición con mouse: multiselección + doble click en celda editable
- mientras haya multiedición activa, no colapsar multiselección por navegación/clicks válidos
- filtros header + rango de fechas
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

- filtros: paleta teal
- pickers operativos: paleta azul clara (como `services`)
- toolbar externa y cards: glass style estándar
- grids: copiar tokens/estados visuales desde `services` (no aproximar)
  - selección primaria (azul oscuro) + borde + sombra
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
- [ ] filtros de columna funcionan igual que `services` (icono, popup, Esc, Aplicar/Limpiar/Cancelar)
- [ ] acciones de fila en `...` (si aplica por ancho)
- [ ] click derecho abre menú contextual con mismas acciones
- [ ] click derecho no dispara cancelación por "click afuera"
- [ ] hover editable + doble click para editar
- [ ] hover editable no se extiende por todo el renglón/módulo
- [ ] doble click no colapsa multiselección activa
- [ ] click afuera cancela edición inline sin guardar
- [ ] selección/hover/fila activa usan la misma paleta y volumen que `services`
- [ ] recarga no corta captura
- [ ] `dart format`
- [ ] `dart analyze` sin errores
