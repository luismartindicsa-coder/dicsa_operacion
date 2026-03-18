# QA Flujos Operativos V2

Objetivo: validar en la app el flujo completo de operación sin recurrir a backend manual.

## Caso 1: Compra de materia prima

Pantalla: `Servicios > Entradas`

Pasos:
- Capturar una entrada con material comercial de compra, por ejemplo `CARTON_NACIONAL`.
- Guardar con peso neto válido.
- Verificar en Inventario:
  - `Materia Prima` aumenta en `CARTON`.
  - `Patio` no cambia.

Resultado esperado:
- Se crea un movimiento `IN / GENERAL`.
- La existencia sube en el material general correcto.

## Caso 2: Transformación de materia prima a patio clasificado

Pantalla: `Servicios > Producción`

Pasos:
- En la familia correspondiente, por ejemplo `CARTON`, capturar:
  - `Kg entrada`
  - material comercial de salida, por ejemplo `PACA_AMERICANA`
  - `Kg salida`
- Guardar.

Validaciones esperadas:
- No permite `kg entrada <= 0`.
- No permite `kg salida <= 0`.
- No permite `kg salida > kg entrada`.
- No permite descontar más materia prima de la disponible.

Resultado esperado:
- Baja `Materia Prima` en `CARTON`.
- Sube `Patio` en `PACA_AMERICANA`.

## Caso 3: Venta de material clasificado

Pantalla: `Servicios > Salidas`

Pasos:
- Capturar una salida de `PACA_AMERICANA` o cualquier material comercial con patio.
- Guardar.

Validaciones esperadas:
- No permite salida con inventario insuficiente.

Resultado esperado:
- Baja solo `Patio` en el material comercial vendido.
- `Materia Prima` no cambia.

## Caso 4: Apertura de mes

Pantalla: `Servicios > Inventario > Aperturas`

Pasos:
- Crear una apertura `GENERAL` para una familia base.
- Crear una apertura `COMMERCIAL` para un material clasificado de patio.

Validaciones esperadas:
- La apertura se refleja en la pestaña correcta.
- Si se intenta duplicar una apertura del mismo material y periodo, el mensaje debe ser claro.

Resultado esperado:
- `Materia Prima` refleja la apertura general.
- `Patio` refleja la apertura comercial.

## Caso 5: Revisión integral de patio

Pantallas:
- `Servicios > Inventario`
- `Dashboard`

Pasos:
- Ejecutar los casos 1, 2 y 3 en ese orden.
- Revisar:
  - pestaña `Materia Prima`
  - pestaña `Patio`
  - panel de inventario del dashboard

Resultado esperado:
- Las existencias coinciden entre Inventario y Dashboard.
- Patio muestra materiales clasificados.
- Materia prima muestra solo familias base.

## Set mínimo recomendado para prueba inicial

- Entrada:
  - `CARTON_NACIONAL` -> `CARTON`
- Transformación:
  - `CARTON` -> `PACA_AMERICANA`
- Salida:
  - `PACA_AMERICANA`
- Aperturas:
  - `CARTON`
  - `PACA_AMERICANA`

## Incidencias a registrar si aparecen

- El material comercial no aparece en el combo correcto.
- Inventario no se mueve en la pestaña esperada.
- Dashboard muestra saldos distintos a Inventario.
- La app permite salida o transformación con saldo insuficiente.
- El mensaje de error no explica el problema operativo.
