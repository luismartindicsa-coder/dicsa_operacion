# Matriz De Ejecucion Segura Conciliacion Bancaria 2026-06-25

Base de analisis:
- Excel: `reporte_conciliacion_bancaria_2026-06-25.xlsx`
- Snapshot remoto verificado: `2026-06-26`
- No se aplico ningun cambio en base ni en app

## Conclusion

El Excel si se entiende y su logica interna es consistente.

Si se aplicaran todas sus propuestas, las 4 cuentas cuadrarian contra el `saldo banco tabla` del propio Excel:
- `DICSA CELAYA`: cuadra contra tabla; queda una diferencia adicional de `$10.00` contra `saldo disponible`
- `DICSA MAZATLAN`: cuadra
- `VH CELAYA`: cuadra
- `VH MAZATLAN`: cuadra

El riesgo real no esta en la aritmetica, sino en ejecutar las correcciones dentro de una app donde:
- editar `VENTA_FACTURA` revierte y reaplica `mayoreo_accounts`
- borrar movimientos ligados revierte proveedor o mayoreo
- editar monto en `COMPRA_FACTURA` no recalcula automaticamente el saldo de la factura proveedor

## Reglas De Ejecucion

1. `VENTA_FACTURA` con cuenta o fecha incorrecta:
Editar el movimiento existente. No borrar y recrear.

2. `COMPRA_FACTURA` con cuenta o fecha incorrecta, pero mismo monto:
Editar el movimiento existente y conservar el `linked_supplier_invoice_id`.

3. `COMPRA_FACTURA` con monto incorrecto:
No editar directo en UI. Requiere correccion controlada porque el monto y el saldo proveedor pueden desalinearse.

4. `Ya incluido en apertura`:
No corregir como si fuera un error normal de movimiento. Primero hay que aprobar si el corte/apertura es el que manda o si se quiere reconstruir el historial completo.

5. `App agrupo movimientos del banco`:
No partirlo ahorita en UI. Hoy el flujo de proveedor no es buen candidato para representar pagos parciales divididos sin revisar el modelo.

## Bloque Seguro Ahora

Si solo se ejecuta este bloque "seguro ahora", el residual estimado contra `saldo banco tabla` seria:
- `DICSA CELAYA`: `-15,846.40`
- `DICSA MAZATLAN`: `-3,914.64`
- `VH CELAYA`: `0.00`
- `VH MAZATLAN`: `0.00`

Eso significa que este bloque limpia bastante, pero no cierra totalmente `DICSA`.

### 1. Editar Movimiento Existente

| Prioridad | Match | ID actual | Cuenta actual | Fecha actual | Cambio sugerido | Riesgo | Motivo |
|---|---|---|---|---|---|---|---|
| 1 | `M0070` | `fin-bank-mov-1781636303504870` | `DICSA CELAYA` | `2026-06-11` | mover a `DICSA MAZATLAN` | Medio | `VENTA_FACTURA` ligada a mayoreo `B-3172`; el edit debe conservar `linked_external_ref` |
| 1 | `M0069` | `fin-bank-mov-1781729073499508` | `DICSA CELAYA` | `2026-06-16` | mover a `DICSA MAZATLAN` | Medio | `VENTA_FACTURA` ligada a mayoreo `B-3178` |
| 1 | `M0068` | `fin-bank-mov-1782345402796985` | `DICSA CELAYA` | `2026-06-23` | mover a `DICSA MAZATLAN` | Medio | `VENTA_FACTURA` ligada a mayoreo `B-3190` |
| 1 | `M0071` | `fin-bank-mov-1781638519021834` | `VH CELAYA` | `2026-06-15` | mover a `VH MAZATLAN` | Medio | `VENTA_FACTURA` ligada a mayoreo `C-582` |
| 2 | `M0074` | `fin-bank-mov-1782397541637266` | `DICSA CELAYA` | `2026-06-25` | cambiar fecha a `2026-06-24` | Bajo | `MANUAL`, sin liga externa |
| 2 | `M0077` | `fin-bank-mov-1782397479781447` | `DICSA MAZATLAN` | `2026-06-25` | cambiar fecha a `2026-06-24` | Bajo | `MANUAL`, sin liga externa |
| 2 | `M0076` | `fin-bank-mov-1782321849139687` | `DICSA CELAYA` | `2026-06-24` | cambiar fecha a `2026-06-18` | Bajo | `MANUAL`, concepto `NOMINA 25 SRA MARI` |
| 2 | `M0075` | `fin-bank-mov-1782252552364220` | `DICSA CELAYA` | `2026-06-23` | cambiar fecha a `2026-06-22` | Medio | `COMPRA_FACTURA` ligada a `CBICENTENARIO 10403`; monto no cambia |

### 2. Crear Movimiento Nuevo

Regla segura para este bloque:
- si no hay candidato claro de proveedor o mayoreo, crear como `MANUAL`
- no forzar liga falsa solo para que cuadre

| Prioridad | Cuenta | Fecha banco | Monto | Tipo sugerido | Riesgo | Ruta segura |
|---|---|---|---:|---|---|---|
| 3 | `DICSA CELAYA` | `2026-06-17` | `-92,801.35` | `MANUAL` | Bajo | alta nueva; categoria fiscal/administrativa; concepto `SIPARE H3412184108 202605 937019` |
| 3 | `DICSA CELAYA` | `2026-06-17` | `-12,336.00` | `MANUAL` | Bajo | alta nueva; categoria fiscal/administrativa; no confundir con `647256852` del 10-jun |
| 3 | `DICSA CELAYA` | `2026-06-16` | `-25,834.21` | `MANUAL` | Bajo | alta nueva; concepto `AXA` |
| 3 | `DICSA CELAYA` | `2026-06-15` | `-17,642.60` | `MANUAL` provisional | Medio | alta nueva; primero registrar banco, luego si aparece soporte ligarlo fuera de conciliacion |
| 3 | `DICSA CELAYA` | `2026-06-15` | `-21,899.38` | `MANUAL` | Bajo | alta nueva; concepto `PAGO TARJETA DE CREDITO` |
| 3 | `DICSA CELAYA` | `2026-06-12` | `+0.02` | `MANUAL` | Bajo | alta nueva; categoria `AJUSTES` |
| 3 | `DICSA CELAYA` | `2026-06-12` | `-115,264.00` | `MANUAL` | Medio | alta nueva; categoria `NOMINA`; validar contra soporte de nomina |
| 3 | `DICSA CELAYA` | `2026-06-11` | `+34,277.42` | `MANUAL` provisional | Medio | no hay candidato exacto hoy en `mayoreo_accounts`; no forzar liga |
| 3 | `DICSA MAZATLAN` | `2026-06-25` | `-45,884.96` | `MANUAL` provisional | Medio | no hay candidato exacto hoy en `finanzas_supplier_invoices`; registrar primero banco |
| 3 | `VH MAZATLAN` | `2026-06-15` | `-3,457.11` | `MANUAL` | Bajo | alta nueva; concepto `PAGO TARJETA DE CREDITO` |

## Bloque No Ejecutar Directo

Este bloque si mueve la conciliacion, pero no es buena idea resolverlo con edicion normal en UI.

### 1. Sobra En App / Revisar

| ID actual | Cuenta | Fecha | Monto | Riesgo | Recomendacion |
|---|---|---|---:|---|---|
| `fin-bank-mov-1782411332526740` | `DICSA CELAYA` | `2026-06-25` | `-117,366.80` | Medio | no borrar todavia; validar contra estado de cuenta posterior al 25-jun y soporte de `NOMINA 26` |

Nota:
- el Excel la marca como "sobra" porque no la encuentra en su banco filtrado
- hoy sigue existiendo en remoto como movimiento real de app
- sin soporte adicional no conviene tumbarla

### 2. Ya Incluido En Apertura

| ID actual | Cuenta | Fecha | Monto | Tipo | Riesgo | Recomendacion |
|---|---|---|---:|---|---|---|
| `fin-bank-mov-1782230074610828` | `DICSA CELAYA` | `2026-06-11` | `-47,730.52` | `COMPRA_FACTURA` | Alto | no borrar ni editar por ahora; resolver primero si el corte del 11-jun manda |
| `fin-bank-mov-1782228701763751` | `DICSA MAZATLAN` | `2026-06-11` | `-3,913.84` | `COMPRA_FACTURA` | Alto | mismo criterio |
| `fin-bank-mov-1781731236765963` | `DICSA CELAYA` | `2026-06-16` | `+73,225.00` | `VENTA_FACTURA` | Alto | ligado a mayoreo; no tocar hasta aprobar tratamiento de apertura |
| `fin-bank-mov-1781731256308832` | `DICSA CELAYA` | `2026-06-17` | `+76,027.50` | `VENTA_FACTURA` | Alto | mismo criterio |

Interpretacion:
- estos renglones pueden ser "duplicados post-apertura"
- pero corregirlos en banco tambien revierte proveedor o mayoreo
- primero hay que decidir si la verdad contable es `mantener apertura y limpiar historia` o `rehacer apertura`

### 3. Monto Diferente En COMPRA_FACTURA

No recomiendo editar estos montos directamente desde la UI actual.

Motivo:
- son movimientos ya ligados a facturas proveedor
- hoy la app no recalcula automaticamente el saldo proveedor cuando editas el monto de un `COMPRA_FACTURA` existente

IDs reales de movimientos con diferencia:
- `fin-bank-mov-1782153828346441` `DICSA CELAYA` `2026-06-12` `AVON C-929` `app 49,503.50` vs `banco 49,502.70`
- `fin-bank-mov-1781800477588413` `DICSA CELAYA` `2026-06-12` `DECASA AB 00004111` `app 8,255.50` vs `banco 8,255.51`
- `fin-bank-mov-1782153187750705` `DICSA CELAYA` `2026-06-19` `AVON C-928` `app 67,338.50` vs `banco 67,337.70`
- `fin-bank-mov-1781800259533059` `DICSA CELAYA` `2026-06-17` `DECASA AB 00004116` `app 8,893.50` vs `banco 8,893.51`
- `fin-bank-mov-1782154813800806` `DICSA MAZATLAN` `2026-06-16` `AVON 948` `app 39,064.50` vs `banco 39,064.10`
- `fin-bank-mov-1781801972890152` `DICSA MAZATLAN` `2026-06-16` `AVON 955` `app 30,096.00` vs `banco 30,095.60`
- `fin-bank-mov-1782407616237957` `DICSA MAZATLAN` `2026-06-25` `DECASA AB 000004191` `app 9,383.00` vs `banco 9,383.01`
- `fin-bank-mov-1782251347153937` `DICSA MAZATLAN` `2026-06-23` `BIEN BAJADO B-50729` `app 13,850.01` vs `banco 13,850.00`

Ruta segura sugerida:
- no tocar por ahora en UI
- primero validar si el error esta en el movimiento bancario o en la factura importada
- si se decide corregir, hacerlo con procedimiento controlado de reversa/reaplicacion o con ajuste de fuente, no como edit comun

### 4. App Agrupo Movimientos Del Banco

| ID actual | Cuenta | Fecha app | Monto app | Banco real | Riesgo | Recomendacion |
|---|---|---|---:|---|---|---|
| `fin-bank-mov-1782236633520707` | `DICSA MAZATLAN` | `2026-06-23` | `-15,763.24` | dos cargos banco que suman el mismo total (`2026-06-18` `8,500.00` y `2026-06-23` `7,263.24`) | Alto | no partir en UI por ahora; hoy el flujo de proveedor no esta modelado para representar este split con tranquilidad |

## Orden Recomendado

1. Ejecutar solo el bloque `Editar movimiento existente`
2. Ejecutar el bloque `Crear movimiento nuevo` solo en los renglones marcados como `MANUAL` o `MANUAL provisional`
3. Reconciliar otra vez
4. Separar en mesa contable los bloques `Ya incluido en apertura`, `Monto diferente en COMPRA_FACTURA` y `App agrupo movimientos`
5. Solo despues decidir si conviene corregir apertura o rehacer ciertos movimientos ligados

## Lectura Practica

Si el objetivo es avanzar sin romper interconectividad:
- si conviene ejecutar ya: `cuenta equivocada`, `fecha diferente`, `faltan en app` manuales
- si no conviene ejecutar ya: `ya incluido en apertura`, `monto diferente` ligado a proveedor, `app agrupada`, `sobra en app` sin soporte adicional

Eso deja una ruta de trabajo segura:
- primero limpiar lo obvio
- luego volver a medir
- y solo al final meterse con lo que toca mayoreo/proveedor de forma mas profunda
