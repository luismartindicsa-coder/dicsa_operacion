# Contrato Funcional Cuentas Bancarias

Fuente de verdad funcional para la homologación de `Cuentas Bancarias` dentro del arquetipo `Grid Editable`.

## Arquetipo

- `Grid Editable`
- referencia funcional principal: `Entradas y Salidas`
- referencia visual del área: `Centro de pagos`

## Objetivo

`Cuentas Bancarias` debe funcionar como superficie operativa de movimientos financieros.

No debe sentirse como:
- visor pasivo
- reporte estático
- formulario aislado con tabla debajo

Sí debe sentirse como:
- grid operativa principal
- captura / edición rápida
- selección múltiple consistente
- filtros de columna homologados

## Estructura de pantalla

Orden de la página:

1. header del área
2. barra superior de acciones
3. franja de resúmenes por cuenta
4. grid principal de movimientos
5. modales auxiliares de captura, edición, evidencia y pickers

## Barra superior

Debe incluir:
- `Descargar CSV`
- `Nuevo movimiento`
- contador de selección alineado a la derecha

No debe incluir:
- botones duplicados de vista
- tabs decorativos sin función operativa real

## Resúmenes por cuenta

Cada cuenta visible debe mostrar:
- `Abonos`
- `Cargos`
- `Neto`

Reglas:
- cards homogéneas en tamaño
- lectura de un vistazo
- sin saltos de línea en montos importantes

## Grid principal

Columnas base actuales:
- `Fecha`
- `Empresa`
- `Cuenta`
- `Nombre`
- `Categoría`
- `Comentario`
- `Referencia`
- `Abono`
- `Cargo`
- `Acciones`

Reglas:
- la grid es la superficie principal de la página
- headers y rows siguen el lenguaje de `Grid Editable`
- filtros viven en headers de columna
- filas oscuras / glass limpias, no blancas

## Orden por defecto

- fecha más reciente arriba
- en empate, identificador estable visible

## Selección

### Click simple

- selecciona una sola fila
- fija ancla de selección

### Ctrl/Cmd + click

- suma o quita la fila de la selección activa

### Shift + click

- selecciona rango entre ancla y fila objetivo

### Drag

- extiende selección por filas de forma continua

### Escape

- limpia selección actual

## Doble click

- abre edición del movimiento
- no debe abrir vista detalle si la fila ya resume la información suficiente

## Enter

- con fila manual seleccionada: abrir edición
- con captura activa: confirmar acción primaria

## Click derecho y botón `...`

- operan sobre la misma selección activa
- si la fila no está seleccionada, primero debe quedar seleccionada
- no deben inventar una lógica distinta a la del click simple

## Filtros por columna

Contrato:
- popup homologado del sistema
- búsqueda
- opciones ordenadas alfabéticamente por label visible
- multiselección cuando la columna lo permita
- acciones `Aplicar`, `Limpiar`, `Cancelar`

No debe haber:
- filtros hechos ad hoc por columna
- diálogos distintos entre columnas equivalentes

## Modal `Nuevo movimiento` / `Editar movimiento`

Secciones base:

1. `Identidad`
- origen
- fecha
- empresa
- cuenta

2. `Contraparte`
- nombre / factura / cuenta por cobrar / pago fijo
- categoría

3. `Monto`
- referencia
- abono
- cargo

4. `Comentario`

Reglas:
- shell glass oscuro del área
- campos oscuros y legibles
- pickers homologados
- foco claro
- navegación por flechas y enter donde aplique

## Pickers auxiliares

Aplica a:
- contraparte
- factura proveedor
- cuenta cliente
- pago fijo
- fecha

Reglas:
- orden alfabético si no existe secuencia operativa mejor
- foco inicial en buscador
- navegación con flechas
- enter confirma opción resaltada
- misma familia visual glass de Finanzas

## Detalle

Estado deseado:
- no es el flujo principal
- solo se conserva si aporta algo que la fila no muestra:
  - evidencias
  - historial
  - metadata extendida

Si no aporta valor operativo real:
- eliminarlo del flujo principal

## Evidencia

Subir evidencia debe:
- sentirse parte de Finanzas
- usar modal homologado
- no caer a `AlertDialog` nativo

## Hardcode prohibido

No deben quedar hardcodeados en la página:
- colores semánticos repetidos
- catálogos que ya vivan en stores o contrato
- comportamiento de filtros si existe helper del sistema
- menú contextual si existe wrapper compartido
- lógica de selección si existe contrato compartido

## Prioridad de cierre

1. selección / teclado / menú contextual
2. filtros de columna homologados
3. edición vs detalle
4. pickers auxiliares
5. evidencias
6. deshardcode de catálogos y semánticas

