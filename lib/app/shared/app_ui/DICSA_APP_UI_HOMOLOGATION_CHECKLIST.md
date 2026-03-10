# DICSA App UI Homologation Checklist

Checklist de homologación UI/UX módulo por módulo contra `DICSA_APP_UI_STANDARD.md`.

## Cómo usar este archivo

1. Identificar el módulo.
2. Confirmar su arquetipo.
3. Ejecutar únicamente el checklist de su arquetipo.
4. Marcar como `N/A` lo que no aplique por diseño del arquetipo.
5. No cerrar un módulo si falta paridad funcional aunque visualmente “se vea bien”.

## Prioridad de cierre

1. `Pesadas`
2. `Servicios`
3. `Almacén`
4. `Mantenimiento`
5. `Dashboard`
6. `Auxiliares`

## Estados permitidos

- `Cumple`: el comportamiento ya coincide con el contrato del arquetipo.
- `Cumple parcial`: hay base correcta, pero falta homologación fina.
- `Pendiente`: la revisión o ajuste no se ha cerrado.
- `N/A`: el punto no aplica por arquetipo o por diseño del módulo.

## Foto actual del sistema

- `Entradas y Salidas`: `Cumple base / referencia funcional`
- `Servicios`: `Cumple parcial alto`
- `Pesadas`: `Cumple parcial medio-alto`
- `Producción`: `Cumple parcial alto`
- `Almacén`: `Cumple parcial`
- `Mantenimiento`: `Cumple parcial alto`
- `Dashboard`: `Cumple parcial alto`
- `Auxiliares`: `Cumple parcial`

## Módulo: Entradas y Salidas

Arquetipo:
- `Grid Editable`

Rol:
- referencia funcional principal

Estado actual:
- `Cumple base / referencia funcional`

Checklist:
- [ ] Mantiene toolbar externa consistente
- [ ] Mantiene info de selección alineada a la derecha
- [ ] Insert row inicia en fecha
- [ ] Dropdowns/pickers del insert row empiezan en `—` cuando no hay selección
- [ ] Todas las celdas del insert row empiezan vacías por defecto
- [ ] `Arrow Left/Right/Down/Enter/Esc/Delete/Backspace/Space` conservan comportamiento base
- [ ] Flechas en insert row mueven highlight y foco real a la celda activa
- [ ] `Space` abre fecha/picker/dropdown de la celda activa sin click extra
- [ ] `ArrowDown` desde insert row entra al grid sin click previo
- [ ] `ArrowUp` desde la primera fila visible regresa al insert row sin click previo
- [ ] Al entrar al insert row desde el grid, con flechas o click, se limpia la selección activa de filas
- [ ] Multiselección por mouse y teclado funciona como referencia
- [ ] Click derecho y `...` operan sobre la misma selección
- [ ] Filtros por columna siguen siendo la referencia aprobada
- [ ] Refresh silencioso no roba foco
- [ ] No hay regresiones antes de homologar otros módulos

## Módulo: Servicios

Arquetipo:
- `Grid Editable`

Objetivo:
- igualar paridad funcional de `Entradas y Salidas`
- conservar solo los tokens visuales que ya sean consistentes

Estado actual:
- `Cumple parcial alto`

Checklist:
- [ ] Revisar foco y caret en edición inline contra `Entradas y Salidas`
- [ ] Revisar `Enter` y `Esc` en selección simple, multiselección y edición
- [ ] Revisar `Delete/Backspace` dentro de inputs para que no eliminen fila
- [ ] Revisar paridad de multiedición por teclado y mouse
- [ ] Revisar click derecho y menú `...` sobre selección múltiple
- [ ] Revisar persistencia de selección al abrir menú contextual
- [ ] Revisar hover editable y borde de celda activa contra referencia
- [ ] Revisar filtros por columna y su popup contra referencia
- [ ] Revisar densidad/responsive de tabla sin overflow no intencional
- [ ] Revisar refresh silencioso mientras hay edición/captura activa

## Módulo: Pesadas

Arquetipo:
- `Grid Editable`

Objetivo:
- converger visual y funcionalmente al mismo lenguaje de `Entradas y Salidas`

Estado actual:
- `Cumple parcial medio-alto`

Checklist:
- [ ] Validar toolbar externa ya homologada con el shell de la app
- [ ] Validar foco inicial del insert row
- [ ] Validar navegación completa con flechas, `Space`, `Enter`, `Esc`
- [ ] Validar que flechas en insert row cambien también el foco real entre fecha, ticket, proveedor y precio
- [ ] Validar que `Space` abra fecha cuando esa celda esté activa
- [ ] No existe botón o toggle persistente de `Edición cuadrícula`
- [ ] Validar multiselección por `Ctrl/Cmd + click`
- [ ] Validar multiedición del grupo con `Enter`
- [ ] Validar cancelación de edición con `Esc` y click afuera
- [ ] Validar click derecho y `...` con la misma lógica
- [ ] Validar filtros por columna con popup, búsqueda, checkboxes y `Aplicar/Limpiar/Cancelar`
- [ ] Validar rango de fechas contra referencia
- [ ] Validar paginación y cambio de filas por página sin romper foco
- [ ] Validar estados hover/selected/active contra referencia visual
- [ ] Validar refresh silencioso sin romper edición

## Módulo: Producción

Arquetipo:
- `Grid Editable Tabulado`

Objetivo:
- cerrar paridad entre tabs sin que cada tab se sienta como módulo distinto

Estado actual:
- `Cumple parcial alto`

Checklist:
- [ ] Validar tabs folder contra contrato
- [ ] Validar que la toolbar externa represente siempre el tab activo
- [ ] Validar grid de producción principal contra referencia funcional
- [ ] Validar grid de separación de materiales contra el mismo lenguaje de teclado
- [ ] Validar extensión de selección con modificadores de forma consistente entre tabs
- [ ] Validar `Enter/Esc/Delete/Space` en todos los tabs
- [ ] Validar que el cambio de tab no robe foco ni rompa selección
- [ ] Validar métricas/top bar por tab
- [ ] Validar refresh silencioso y diferido dentro de cada tab

## Módulo: Almacén

Arquetipo:
- `Operación Híbrida por Tabs`

Objetivo:
- cerrar consistencia del módulo como una sola superficie
- validar cada tab interna contra el subarquetipo que corresponda

Estado actual:
- `Cumple parcial`

Checklist global:
- [ ] Tabs folder consistentes con la familia visual de la app
- [ ] Toolbar externa consistente con el resto de módulos
- [ ] Refresh silencioso uniforme en todo el módulo
- [ ] Paleta, diálogos y botones alineados a la familia visual de la app
- [ ] Cambio de tab sin sensación de “subapp” separada

Tabs internas:

### Resumen
- [ ] Cards y resumen siguen la familia visual del módulo
- [ ] No hay desalineaciones ni espacios muertos grandes
- [ ] La composición conserva jerarquía clara entre KPIs y acciones

### Inventario
- [ ] Filtros y acciones son consistentes con la familia visual de la app
- [ ] La tabla responde sin overflow no intencional
- [ ] La lectura de existencias y unidades es entendible sin ambigüedad visual

### Movimientos
- [ ] Selección por teclado y mouse es consistente
- [ ] Click derecho y `...` comparten lógica
- [ ] `Enter/Esc/Delete` operan correctamente
- [ ] El refresh no rompe captura ni contexto de selección

### Corte mensual
- [ ] Flujo de corte y ajuste no rompe consistencia visual
- [ ] Dialogs y acciones conservan jerarquía correcta
- [ ] Confirmaciones y estados de éxito/error son claros

### Reportes
- [ ] Se siente parte del mismo módulo y no una pantalla aislada
- [ ] Los filtros y exportes conservan el lenguaje operativo del resto del módulo

## Módulo: Mantenimiento

Arquetipo:
- `Workflow Master-Detail`

Objetivo:
- cerrar consistencia de lista, detalle y subflujos de proceso

Estado actual:
- `Cumple parcial alto`

Checklist:
- [ ] Lista izquierda o superior mantiene navegación por teclado consistente
- [ ] Selección de OT actualiza detalle sin sobrescribir edición de forma agresiva
- [ ] Toolbar externa mantiene la familia visual de la app
- [ ] Cards/resumen de estado se sienten parte del mismo sistema visual
- [ ] Menú contextual de OT y botón `...` comparten lógica
- [ ] Dialogs de estado, aprobaciones, materiales, evidencias y tiempo comparten look & feel
- [ ] `Esc` cierra dialogs y subflujos correctamente
- [ ] `Enter` confirma acción primaria donde aplique
- [ ] Refresh silencioso no rompe captura del detalle
- [ ] Evidencias, aprobaciones y exportes PDF siguen jerarquía visual consistente

## Módulo: Dashboard

Arquetipo:
- `Dashboard`

Objetivo:
- cerrar responsive, composición y consistencia de widgets

Estado actual:
- `Cumple parcial alto`

Checklist:
- [ ] Overlay de navegación no empuja la grilla base
- [ ] No existe scroll horizontal global
- [ ] Gaps horizontales y verticales son consistentes
- [ ] Widgets del mismo tamaño comparten altura
- [ ] Hover/lift es consistente entre widgets
- [ ] No hay espacio muerto innecesario
- [ ] Reacomodo responsive sin overflow
- [ ] Los paneles de servicios, mantenimiento, almacén e inventario conviven como una sola composición

## Superficies Auxiliares

Arquetipo:
- `Superficies Auxiliares`

Incluye:
- `Login`
- `Splash`
- diálogos
- pickers
- catálogos modales

Estado actual:
- `Cumple parcial`

Checklist:
- [ ] Acción primaria y secundaria claras
- [ ] `Esc` cierra cuando aplica
- [ ] `Enter` confirma cuando aplica
- [ ] Foco inicial correcto
- [ ] Misma familia visual que la app operativa

## Criterio para marcar “cerrado”

Un módulo solo puede marcarse como homologado si:

- cumple el contrato global
- cumple el checklist de su arquetipo
- no tiene excepciones funcionales sin documentar
- no depende de una interpretación vieja del contrato anterior
- tiene su estado final actualizado a `Cumple`

## Secuencia recomendada de ejecución

1. Cerrar primero `Pesadas` porque ya está cerca del arquetipo `Grid Editable`.
2. Cerrar `Servicios` para dejar una sola referencia funcional real en grids.
3. Cerrar `Almacén` tab por tab, sin medirlo como grid puro.
4. Cerrar `Mantenimiento` sobre el arquetipo `Workflow Master-Detail`.
5. Cerrar `Dashboard` y luego `Auxiliares` para terminar consistencia transversal.
- [ ] La seleccion aditiva/extensible funciona con `Shift` y `Ctrl/Cmd` en flechas, click y marquee.
- [ ] Ningun campo del `insert row` que visualmente arranca en `—` se completa con defaults invisibles al guardar.
