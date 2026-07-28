# Base minima: Estado de Resultados

Fecha: 2026-07-27

## Objetivo

Definir la clasificacion contable minima para construir `Contabilidad > Estado de Resultados` sin inflar utilidad por meter todo egreso de flujo como si fuera gasto real.

## Criterio aprobado

El `Estado de Resultados` no se construye desde "todo lo que entro y salio".

Tampoco baja al `concepto` para clasificar el resultado.

Para esta pantalla:

- `categoria` en bancos
- `rubro` en boveda y menudeo

se homologan como el mismo nivel contable.

El `concepto` se reserva para `Analisis de Gastos`.

Se construye desde:

- ingresos
- costo comercial
- gastos que si pegan al resultado

Y deja fuera:

- movimientos internos
- ajustes sin aclarar
- pagos de deuda o capital que no necesariamente son gasto
- rubros que todavia requieren revision

## Clasificacion minima actual

## Mapa contable maestro

- `VENTAS` / `Venta de material` -> ingreso
- `COMPRA DE MATERIAL` / `Compra de material` -> costo comercial
- `GASTOS OPERATIVOS` / `Gastos operativos` -> gasto operativo
- `SERVICIOS` + `GASTOS ADMINISTRATIVOS` / `Gastos administrativos` -> gasto administrativo
- `GASTOS FINANCIEROS` / `Gastos financieros` -> gasto financiero
- `NOMINA` / `Nómina` -> nomina
- `MOVIMIENTOS INTERNOS` / `Reposición de fondo` / `Movimientos internos` -> interno

Casos que siguen fuera o en revision:

- `GASTOS PERSONALES`
- `AJUSTES`
- `OTROS`
- `Cheque`

### Bancos

Entran al resultado:

- `VENTAS` -> ingreso
- `COMPRA DE MATERIAL` -> costo comercial
- `GASTOS OPERATIVOS` -> gasto operativo
- `SERVICIOS` -> gasto administrativo provisional
- `GASTOS ADMINISTRATIVOS` -> gasto administrativo
- `GASTOS FINANCIEROS` -> gasto financiero con vigilancia
- `NOMINA` -> nomina

Quedan fuera:

- `MOVIMIENTOS INTERNOS`

Quedan en revision:

- `GASTOS PERSONALES`
- `AJUSTES`
- `OTROS`

### Caja y Boveda: entradas

Entran al resultado:

- `Venta de material` -> ingreso comercial

Quedan fuera:

- `Reposicion de fondo` -> movimiento interno

Quedan en revision:

- `Cheque`
- `Otro`

### Caja y Boveda: salidas

Entran al resultado:

- `Compra de material` -> costo comercial
- `Gastos operativos` -> gasto operativo
- `Gastos administrativos` -> gasto administrativo
- `Gastos financieros` -> gasto financiero con vigilancia
- `Nomina` -> nomina

Quedan fuera:

- `Movimientos internos`

Quedan en revision:

- `Gastos personales`
- cualquier rubro no homologado

## Riesgo principal pendiente

El caso mas delicado sigue siendo este:

- un `pago de tarjeta`
- un `pago de prestamo`
- una `amortizacion de capital`

pueden aparecer como salida de dinero, pero no por eso deben entrar automatico como gasto del resultado.

Por eso esta base deja visible que:

- flujo no es utilidad
- salida de dinero no es igual a gasto
- pago de pasivo no es lo mismo que consumo del periodo

## Formula ejecutiva aprobada

`Ingresos - Costo comercial = Resultado comercial`

`Resultado comercial - Gastos operativos - Gastos administrativos - Gastos financieros - Nomina = Utilidad del periodo`

Siempre excluyendo:

- movimientos internos
- ajustes sin aclarar
- rubros en revision

## Implicacion practica

Si hoy se construyera una utilidad metiendo todo egreso de bancos, boveda y menudeo, la lectura podria inflarse o castigarse mal.

Con esta base minima ya existe una primera barrera para evitar eso, aunque todavia faltara:

1. separar mejor pagos financieros vs gasto financiero real
2. incorporar futura fuente de Logistica
3. construir despues el `Analisis de Gastos` fino
