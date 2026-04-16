# Contrato de Corte de Caja Menudeo

Este documento fija el contrato funcional y operativo del `corte de caja` de Menudeo para poder:

- mantener consistencia dentro del módulo actual
- replicar el mismo flujo en otras áreas de la app
- evitar reinterpretaciones posteriores del proceso de caja

La intención es que el frontend, backend y UX trabajen sobre la misma definición.

## Objetivo

El corte de caja no es solo un resumen diario. Es un flujo guiado de conciliación entre:

- dinero real en caja
- dinero teórico calculado por el sistema
- tickets y vouchers digitales
- documentos físicos entregados a caja

El sistema debe permitir:

- abrir caja al inicio del día
- conocer cuánto dinero debería existir en caja durante el día
- ejecutar corte al final del día
- comprobar digital vs físico por lotes ordenados
- dejar trazabilidad de lo comprobado y de lo pendiente
- arrastrar pendientes a días siguientes hasta su resolución

## Entidades del contrato

### 1. Apertura de caja

Registro manual de inicio del día.

Campos mínimos:

- `cut_date`
- `opening_cash`
- `status = ABIERTO`

Reglas:

- solo existe una apertura por día
- la apertura antecede al corte
- si existen pendientes heredados, el sistema debe notificar antes de continuar con la apertura

### 2. Corte de caja

Resumen diario persistido.

Campos mínimos:

- `cut_date`
- `opening_cash`
- `sales_total`
- `purchases_total`
- `deposits_total`
- `expenses_total`
- `theoretical_cash_total`
- `counted_cash_total`
- `difference_total`
- `pending_checks_count`
- `status`
- `notes`
- `closed_at`

Estados permitidos:

- `ABIERTO`
- `CERRADO`
- `CON_PENDIENTES`

### 3. Checks de corte

Detalle de comprobación por documento.

Cada check representa un documento evaluado dentro del corte.

Campos mínimos:

- `cash_cut_id`
- `source_type`
- `source_id`
- `source_folio`
- `is_verified`
- `reason`
- `verified_at`

Tipos permitidos:

- `expense_voucher`
- `deposit_voucher`
- `sale_ticket`
- `purchase_ticket`

## Fórmula de caja teórica

La caja teórica del día se calcula así:

`apertura + ventas cobradas + depósitos - compras pagadas - gastos`

En términos de sistema:

- `opening_cash`
- `+ sales_total`
- `+ deposits_total`
- `- purchases_total`
- `- expenses_total`

La diferencia del corte es:

`counted_cash_total - theoretical_cash_total`

## Cards visibles del dashboard

Los cards visibles para el usuario son únicamente:

- `Venta de hoy`
- `Compra de hoy`
- `Gastos de hoy`
- `Depósitos de hoy`
- `Total en caja`

Notas:

- la lógica interna puede calcular más cosas
- esos otros datos no deben saturar la vista principal
- `Total en caja` representa la caja teórica viva del día

## Flujo obligatorio de corte

El flujo correcto del corte es:

1. Capturar `conteo real de caja`
2. Entrar al navegador de virtuales
3. Recorrer todos los lotes en orden contractual
4. Marcar cada documento como comprobado o no comprobado
5. Guardar automáticamente el corte al terminar el último documento

No debe existir una captura paralela manual del historial del corte como flujo principal.

El historial se genera como resultado del corte.

## Orden contractual de lotes

Los lotes del corte no se mezclan.

El orden obligatorio es:

1. `Gastos`
2. `Depósitos`
3. `Ventas`
4. `Compras`

Dentro de cada lote, el orden es ascendente por:

- `folio` en vouchers
- `ticket_number` en tickets

Justificación:

- los documentos físicos llegan ordenados así a caja
- esto permite revisión continua y rápida sin reordenamientos mentales

## Navegación contractual dentro del corte

El corte debe abrir un navegador de virtuales dentro del dashboard, sin redirigir al usuario a la página origen.

### Comportamiento esperado

- el usuario entra una sola vez al flujo de virtuales
- no debe abrir y cerrar un diálogo distinto por cada documento
- el mismo diálogo debe avanzar documento por documento

### Teclado obligatorio

- `Enter`
  - marca el documento actual como `comprobado`
  - avanza automáticamente al siguiente virtual

- `Space`
  - abre popup de comentario
  - guarda el documento como `no comprobado`
  - avanza automáticamente al siguiente virtual

- `ArrowLeft`
  - regresa al virtual anterior

- `ArrowRight`
  - avanza manualmente al siguiente virtual

### Cierre del flujo

Al terminar el último virtual del último lote:

- se cierra el navegador
- se guardan los checks
- se actualiza el corte
- se recalcula `pending_checks_count`
- el corte queda:
  - `CERRADO` si no hay pendientes
  - `CON_PENDIENTES` si hay no comprobados

## Regla de comprobación

Cada documento debe terminar en uno de estos dos estados:

### 1. Comprobado

Condición:

- físico y digital coinciden para ese documento según el criterio operativo del área

Persistencia:

- `is_verified = true`
- `reason = ''`

### 2. No comprobado

Condición:

- el documento no pudo comprobarse o presenta diferencia relevante

Persistencia:

- `is_verified = false`
- `reason` obligatorio

Ejemplos válidos de motivo:

- `Falta ticket de comprobación`
- `No coincide el importe con el voucher físico`
- `No coincide el material físico con el digital`
- `No era el precio aprobado`
- `Falta factura`
- `Falta orden de salida`

## Visualización contractual del virtual

Dentro del corte, el documento debe abrirse como `virtual` real.

Eso implica:

- para tickets:
  - mostrar ticket digital completo
  - no solo una fila resumida

- para vouchers:
  - mostrar encabezado y renglones reales
  - no solo folio e importe

El virtual del corte es de revisión, no de edición operativa.

## Campos que deben ser verificables por tipo

### Gastos

Verificar contra voucher físico:

- folio
- persona
- rubro
- conceptos / renglones
- importes
- total
- comentario si aplica

### Depósitos

Verificar contra comprobante físico:

- folio
- persona / origen
- rubro
- renglón o concepto
- importe
- total

### Ventas

Verificar contra ticket físico y orden de salida:

- ticket
- cliente
- material
- precio
- pesos
- importe
- orden de salida

### Compras

Verificar contra ticket físico:

- ticket
- proveedor
- material
- precio de entrada
- pesos
- importe

## Pendientes heredados

Todo documento no comprobado debe heredarse al día siguiente hasta resolverse.

### Reglas

- si un check queda con `is_verified = false`, no desaparece al cerrar el día
- antes de `Apertura de caja`, el sistema debe mostrar popup de pendientes heredados
- el usuario puede cerrar el popup y reabrirlo desde campana/notificación
- esos pendientes también vuelven a formar parte de la atención del área en cortes posteriores hasta ser resueltos

### UX mínima

- popup automático antes de apertura
- campana arriba a la derecha para reabrir pendientes
- cada pendiente debe mostrar:
  - tipo
  - folio/ticket
  - fecha del corte en que quedó abierto
  - motivo

## Historial de cortes

Debe existir una página de historial.

El historial no es la forma principal de captura.

Es la vista persistida de lo que ya ocurrió.

Columnas recomendadas:

- `Fecha`
- `Apertura`
- `Venta`
- `Compra`
- `Gastos`
- `Depósitos`
- `Caja teórica`
- `Conteo real`
- `Diferencia`
- `Pendientes`
- `Estado`

## Reglas de contrato para replicarlo en otras áreas

Este contrato debe poder clonarse después para otros módulos.

Las piezas reutilizables del patrón son:

- apertura de caja o apertura operativa
- cálculo teórico del día
- captura de conteo real
- lotes de documentos por tipo
- orden contractual fijo por lote
- navegador de virtuales dentro del dashboard
- `Enter = comprobado`
- `Space = no comprobado con motivo`
- pendientes heredados
- historial persistido

Lo que cambia por área:

- tipos de documento
- orden de lotes si el negocio lo exige
- campos específicos a validar por virtual
- motivos frecuentes de no comprobación

Lo que no debe cambiar:

- existencia de apertura
- existencia de corte persistido
- comprobación documento por documento
- motivo obligatorio para no comprobados
- arrastre de pendientes
- cierre automático al terminar el último virtual

## Contrato temporal de datos demo

Mientras no exista intro/producción total de la app:

- se permite usar `mock/fallback data` para revisar contratos visuales y de interacción
- esos fallbacks deben ser fáciles de ubicar y borrar después
- no se consideran parte permanente del producto

Pero el contrato funcional del corte sí se considera definitivo.

## Checklist de aceptación del corte

Un corte se considera homologado solo si cumple todo esto:

- existe `Apertura de caja`
- el dashboard muestra los 5 cards principales
- el sistema calcula `caja teórica`
- el corte captura `conteo real`
- el flujo abre virtuales dentro del dashboard
- los lotes no se mezclan
- el orden es `Gastos -> Depósitos -> Ventas -> Compras`
- cada lote va en ascendente
- `Enter` comprueba y avanza
- `Space` pide motivo, marca no comprobado y avanza
- `← →` permiten navegar
- al terminar el último documento se guarda el corte automáticamente
- los no comprobados se persisten con motivo
- los pendientes reaparecen al día siguiente
- existe historial de cortes

Si falta uno de estos puntos, el contrato no debe considerarse cerrado.
