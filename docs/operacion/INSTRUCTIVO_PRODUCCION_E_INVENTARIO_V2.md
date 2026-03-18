# Instructivo Produccion e Inventario V2

Este documento explica el funcionamiento operativo de las pantallas de `Produccion` e `Inventario` en el modelo `v2`.

## Objetivo

La app debe permitir responder estas preguntas sin recurrir a backend manual:

- cuanto material base tengo
- cuanto material clasificado tengo en patio
- cuanto se produjo o clasifico
- cuanto se vendio
- como se arrastra el inventario con el tiempo

## Conceptos Base

### Material general

Es la familia base o materia prima.

Ejemplos:
- `CARTON`
- `CHATARRA`
- `METAL`
- `PLASTICO`
- `MADERA`
- `PAPEL`

### Material comercial

Es la clasificacion real con la que compras, produces o vendes.

Ejemplos:
- `CARTON_NACIONAL`
- `CARTON_AMERICANO`
- `PACA_AMERICANA`
- `ARCHIVO`
- `ALUMINIO`
- `TARIMA`

### Inventario general

Es el saldo de materia prima o material base.

### Inventario comercial

Es el saldo clasificado de patio.

## Flujo General

1. La entrada suma a `inventario general`.
2. La produccion o clasificacion baja `inventario general`.
3. La produccion o clasificacion sube `inventario comercial`.
4. La salida baja `inventario comercial`.

## Produccion

Pantalla: `Servicios > Produccion`

### Para que sirve

Sirve para registrar la clasificacion o produccion que sale a patio.

No registra compras ni ventas.

### Que hace internamente

- toma material de una familia base
- descuenta ese material del inventario general
- crea material clasificado en patio
- suma ese material al inventario comercial

### Ejemplo

- entra `CARTON_NACIONAL`
- eso suma a `CARTON`
- en Produccion registras `PACA_AMERICANA`
- el sistema baja `CARTON`
- el sistema sube `PACA_AMERICANA`

### Campos importantes

#### Fecha

Dia operativo de la produccion o clasificacion.

#### Turno

Turno en que se realizo el trabajo.

#### Origen

Describe el modo operativo del material de entrada.

Ejemplos:
- `MEZCLADO`
- `DIRECTO`

#### Clasificado

Material comercial que realmente salio a patio.

Ejemplos:
- `PACA_AMERICANA`
- `ARCHIVO`
- `ALUMINIO`

#### Kg salida

Kilogramos que realmente quedaron clasificados en patio.

Este valor siempre es obligatorio.

#### Unidades / pacas

Cantidad de pacas o unidades producidas, cuando aplica.

Es un complemento visual y operativo.

#### Consumo

Es el consumo real del material base.

En la practica equivale al antiguo `kg entrada`.

Su uso es este:
- si se captura, representa cuanto material general se consumio realmente
- si no se captura, el sistema usa `kg salida` como descuento del general

Entonces:
- `kg salida` = lo que salio clasificado
- `consumo` = lo que realmente se gasto del material base

Si no miden merma en patio, pueden dejarlo vacio.

#### Comentario / notas

Observaciones operativas.

### Regla clave

En Produccion no se vende nada.

Produccion solo transforma:
- baja general
- sube comercial

### Validaciones

- no permite `kg salida <= 0`
- no permite consumo negativo
- no permite unidades negativas
- no permite consumir mas inventario general del disponible

## Inventario

Pantalla: `Servicios > Inventario`

### Para que sirve

Sirve para revisar existencias y aperturas.

Debe leerse en dos niveles:
- materia prima
- patio clasificado

### Pestaña de inventario general

Aqui se ve la materia prima o familia base.

Ejemplos:
- `CARTON`
- `CHATARRA`
- `METAL`

### Pestaña de inventario comercial

Aqui se ve lo que ya existe clasificado en patio.

Ejemplos:
- `PACA_AMERICANA`
- `ARCHIVO`
- `PESADO`
- `ALUMINIO`

### Como leer las columnas

#### Apertura

Es el saldo con el que se arranco.

Puede ser una apertura inicial o una apertura de periodo si asi se decide operar.

#### Movimiento

Es todo lo que paso despues de la apertura.

Incluye:
- entradas
- salidas
- produccion o clasificacion
- ajustes

No es una captura manual separada. Es el resultado neto de los movimientos.

#### Existencia actual

Es el saldo final del sistema.

Formula:

`Apertura + Movimiento = Existencia actual`

### Ejemplo general

- apertura de `CARTON`: `1000`
- entrada: `+500`
- produccion: `-300`
- movimiento neto: `+200`
- existencia actual: `1200`

### Ejemplo comercial

- apertura de `PACA_AMERICANA`: `0`
- produccion: `+920`
- salida: `-300`
- movimiento neto: `+620`
- existencia actual: `620`

## Aperturas

### Que son

Son el punto de arranque del inventario.

### Cuando se hacen

La apertura inicial si es obligatoria para arrancar limpio.

Despues hay dos formas validas de operar:

- continua
  - haces una sola apertura inicial
  - el saldo se arrastra solo con los movimientos

- por periodos
  - haces apertura al inicio de cada mes
  - normalmente basada en el cierre fisico del mes anterior

### Recomendacion

Para operacion diaria, la app no debe depender de una apertura nueva cada mes.

Lo mas sano es:
- apertura inicial
- operacion normal
- cortes fisicos periodicos
- apertura mensual solo si la administracion quiere controlar meses por separado

## Cortes

### Siguen existiendo

Si, los cortes siguen existiendo.

Lo correcto ahora es cortar dos cosas:

- inventario general
- inventario comercial

### Que se compara

- saldo sistema
- conteo fisico

Si no cuadran:
- se detecta diferencia
- se registra ajuste cuando aplique

## Arrastre entre meses

El inventario se arrastra naturalmente con el tiempo.

Ejemplo:

- enero arranca con apertura
- febrero hereda lo que dejo enero
- marzo hereda lo acumulado de enero y febrero

Eso significa que no necesitas crear una apertura mensual solo para que el saldo siga existiendo.

## Regla Operativa Final

- `Entrada` suma a general
- `Produccion` baja general y sube comercial
- `Salida` baja comercial
- `Inventario` muestra ambos niveles
- `Apertura` define arranque
- `Movimiento` resume lo ocurrido despues
- `Existencia actual` muestra el saldo final

## Casos Rapidos

### Caso 1: carton

- compras `CARTON_NACIONAL`
- suma a `CARTON`
- produces `PACA_AMERICANA`
- baja `CARTON`
- sube `PACA_AMERICANA`
- vendes `PACA_AMERICANA`
- baja `PACA_AMERICANA`

### Caso 2: papel

- compras `REVUELTO`
- suma a `PAPEL`
- produces `ARCHIVO`
- baja `PAPEL`
- sube `ARCHIVO`
- vendes `ARCHIVO`
- baja `ARCHIVO`

### Caso 3: metal

- compras `MIXTO`
- suma a `METAL`
- clasificas `ALUMINIO`
- baja `METAL`
- sube `ALUMINIO`
- vendes `ALUMINIO`
- baja `ALUMINIO`

## Que no debe pasar

- descontar ventas desde el material general cuando lo vendido ya esta clasificado
- pedir trazabilidad imposible entre compra mezclada y paca final
- usar Produccion para registrar compras o ventas
- depender de una apertura mensual obligatoria para que la app siga funcionando
