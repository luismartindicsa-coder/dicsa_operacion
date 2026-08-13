# Blueprint: Centro de Pagos como Presupuesto Diario y Semanal

Fecha de aterrizaje: miércoles, 12 de agosto de 2026.

Este documento redefine `Centro de pagos` como una superficie de presupuesto operativo de caja para decidir, desde la mañana:

- qué se va a pagar hoy
- cuánto se va a pagar hoy
- desde qué cuenta se va a pagar
- qué se va a cobrar hoy
- qué presión trae la semana

El diseño parte de una restricción explícita:

- no agregar captura nueva en `Ventas Mayoreo`
- no tocar `Cuentas por proveedor`
- no tocar `Cuentas bancarias`
- no tocar `Pagos fijos`
- no tocar `Catálogos`

Todo lo nuevo debe vivir dentro de `Centro de pagos` y reutilizar información ya existente en Finanzas.

## Regla madre

`Centro de pagos` deja de ser una cola de urgencias y se convierte en un `presupuesto conservador de caja`.

Conservador significa:

- la capacidad de pago parte solo del saldo real actual en bancos
- la cobranza esperada no aumenta la caja disponible hasta que realmente entre al banco
- `Nómina`, `Impuestos` y `Colchón de cuenta` se protegen como reservas antes de sugerir pagos

## Objetivo operativo

La pantalla debe permitir responder en minutos:

- cuánto dinero real puedo mover hoy
- cuánto dinero no debo tocar
- qué pagos sí o sí deben salir hoy
- qué pagos conviene ejecutar hoy si todavía hay margen
- qué presión trae la semana
- qué cobranza debo perseguir hoy aunque no la pueda contar todavía como caja

## Problema actual

La pantalla actual de `Centro de pagos` ya agrupa:

- facturas abiertas
- convenios
- pagos fijos
- saldos por cuenta bancaria

Pero hoy la lógica principal está orientada a:

- `obligatorio`
- `urgente`
- `recomendado`
- `postergable`

Eso sirve para priorizar pendientes, pero no para presupuestar caja real del día.

El hueco más importante hoy es que la pantalla no protege explícitamente:

- nómina
- impuestos
- colchones mínimos por cuenta

Y tampoco consolida por proveedor la relación entre:

- convenio activo o vencido
- facturas próximas a vencer fuera del convenio

## Alcance aprobado

En esta fase, `Centro de pagos` se reconstruye como módulo de:

- presupuesto diario de pagos
- presupuesto consolidado de próximos 7 días
- reservas protegidas
- cobranza objetivo
- lectura táctica de pendientes

No entra en esta fase:

- proyección contable formal
- predicción probabilística de cobranza
- captura nueva en ventas mayoreo
- nuevas capas de contexto en otras pantallas
- reestructura de `Cuentas por proveedor`, `Cuentas bancarias` o `Pagos fijos`

## Horizonte temporal

El módulo trabajará con dos horizontes principales:

- `Hoy`
- `Próximos 7 días`

Regla explícita:

- `Hoy` es la vista de ejecución.
- `Próximos 7 días` es la vista de anticipación.

Recomendación de fase 1:

- la vista semanal debe ser una ventana móvil de 7 días a partir de hoy
- por ejemplo, el miércoles 12 de agosto de 2026 la semana operativa va del miércoles 12 al martes 18 de agosto de 2026

Esto es más útil para tesorería que una semana calendario rígida de lunes a domingo.

## Fuentes reales de datos a reutilizar

### 1. Saldo real en bancos

Fuente:

- `finanzas_bank_accounts_store.dart`
- `FinanzasBankMovementRecord`

Uso:

- saldo por cuenta
- saldo total
- capacidad real de pago hoy

### 2. Cobranza abierta de Mayoreo

Fuente:

- `finanzas_bank_accounts_store.dart`
- `FinanzasClientPaymentAccountRecord`

Uso:

- cobranza objetivo del día
- cobranza objetivo de próximos 7 días

Regla:

- no suma disponibilidad de caja hasta que exista movimiento bancario real

### 3. Facturas de proveedor

Fuente:

- `finanzas_provider_accounts_store.dart`
- `FinanzasSupplierInvoiceRecord`

Uso:

- facturas vencidas
- facturas por vencer
- facturas sin convenio
- facturas sin `due_date`

### 4. Convenios y parcialidades

Fuente:

- `finanzas_provider_accounts_store.dart`
- `FinanzasSupplierAgreementRecord`
- `FinanzasSupplierAgreementInstallmentRecord`
- `FinanzasSupplierAgreementInvoiceRecord`

Uso:

- compromiso mínimo por proveedor
- cumplimiento de parcialidades
- cruce entre convenio y facturas ligadas

### 5. Pagos fijos

Fuente:

- `finanzas_fixed_payments_store.dart`
- `FinanzasFixedPaymentRecord`

Uso:

- compromisos periódicos
- presión semanal
- pagos mínimos por fecha

### 6. Contexto operativo de proveedor

Fuente:

- `finanzas_company_directory_store.dart`
- prioridad manual
- `payment_stage`
- notas y contexto operativo

Uso:

- desempates
- priorización operativa
- lectura comercial de riesgo

## Arquitectura funcional recomendada

`Centro de pagos` se divide en cuatro vistas internas:

- `Presupuesto`
- `Reservas protegidas`
- `Cobranza objetivo`
- `Pendientes`

Y dentro de `Presupuesto` habrá dos subtabs:

- `Hoy`
- `Próximos 7 días`

## Vista 1: Presupuesto > Hoy

Es la vista principal del módulo.

Debe responder:

- cuánto puedo pagar hoy de verdad
- qué pagos debo ejecutar hoy
- qué pagos puedo ejecutar hoy sin romper caja

### Bloque superior

Cards ejecutivas:

- `Saldo real en bancos`
- `Reservas protegidas de hoy`
- `Disponible presupuestable`
- `Pagos mínimos de hoy`
- `Pagos recomendados de hoy`
- `Margen libre después de proteger caja`

### Bloque de cuentas bancarias

Tabla o cards por cuenta:

- cuenta
- saldo actual
- reserva aplicada
- disponible libre
- presión de pagos asignados

Preguntas que debe resolver:

- `¿Qué cuenta está más presionada hoy?`
- `¿Qué cuenta todavía tiene espacio real?`

### Bloque de pagos del día

Agrupación primaria:

- por cuenta bancaria

Agrupación secundaria:

- por proveedor

Cada proveedor debe mostrar tres bandas:

- `Mínimo hoy`
- `Recomendado hoy`
- `Postergable`

### Definición de bandas

#### Mínimo hoy

Incluye:

- convenio vencido
- convenio que vence hoy
- factura vencida fuera de convenio
- pago fijo no negociable del día
- pagos fijos ya vencidos

#### Recomendado hoy

Incluye:

- mínimo hoy
- facturas próximas a vencer fuera de convenio
- siguiente parcialidad cercana cuando convenga anticiparse

#### Postergable

Incluye:

- facturas sin vencimiento inmediato
- saldos generales no formalizados en factura
- pagos que pueden esperar sin deteriorar operación o relación

## Regla clave: proveedor con convenio + facturas próximas

Esta es la regla más importante del módulo.

### Regla de no duplicidad

Si una factura ya está ligada a un convenio:

- no se vuelve a contar como factura independiente

### Regla de complemento

Si el mismo proveedor tiene facturas próximas que no están ligadas al convenio:

- sí se agregan aparte como presión adicional

### Resultado esperado por proveedor

Para cada proveedor debe existir una consolidación única con:

- `Compromiso mínimo`
- `Compromiso recomendado`
- `Compromiso total abierto`

Ejemplo operativo:

- convenio vencido: `50,000`
- facturas fuera de convenio con vencimiento próximo: `20,000`

Resultado:

- mínimo hoy: `50,000`
- recomendado hoy: `70,000`
- postergable: lo que quede fuera de la presión inmediata

Esto evita dos errores:

- tratar al convenio como si resolviera todo el proveedor
- sumar dos veces facturas ya absorbidas por el convenio

## Vista 2: Presupuesto > Próximos 7 días

Esta vista no es para ejecutar, sino para anticipar presión.

Debe responder:

- qué días de la próxima semana traen más tensión
- en qué día cae nómina, impuestos o pagos fijos delicados
- qué proveedores concentran la presión semanal

### Resumen superior semanal

Cards:

- `Saldo real actual`
- `Reservas protegidas dentro de 7 días`
- `Pagos mínimos de 7 días`
- `Pagos recomendados de 7 días`
- `Cobranza objetivo de 7 días`
- `Presión neta semanal`

### Desglose por día

Cada día dentro de la ventana debe mostrar:

- reservas del día
- pagos mínimos del día
- pagos recomendados del día
- cobranza objetivo del día
- alerta de presión

Ejemplo para la semana operativa iniciando el miércoles 12 de agosto de 2026:

- miércoles 12 de agosto de 2026
- jueves 13 de agosto de 2026
- viernes 14 de agosto de 2026
- sábado 15 de agosto de 2026
- domingo 16 de agosto de 2026
- lunes 17 de agosto de 2026
- martes 18 de agosto de 2026

### Regla de cobranza en semanal

La cobranza se muestra como:

- objetivo diario
- objetivo semanal acumulado

Pero no se suma al disponible real.

Sirve para responder:

- `¿Qué pagos de la semana dependen de que realmente cobremos?`

## Vista 3: Reservas protegidas

Esta es la única captura nueva aprobada para la fase 1.

Debe vivir solo dentro de `Centro de pagos`.

### Tipos de reserva

- `Nómina`
- `Impuestos`
- `Colchón de cuenta`
- `Extraordinario`

### Clasificación

Cada reserva puede ser:

- `Dura`
- `Provisional`

### Campos mínimos

- `Nombre`
- `Tipo`
- `Monto`
- `Cuenta objetivo` o `Global`
- `Fecha objetivo`
- `Nota`
- `Bloquea caja: sí/no`

### Reglas funcionales

- una reserva dura siempre descuenta disponibilidad real
- una reserva provisional debe verse y pesar en la semana, pero puede tener un tono menos severo
- un colchón por cuenta no puede mezclarse como reserva global
- si una reserva es global, el motor debe distribuirla solo a nivel de lectura total, no inventar saldo disponible por cuenta

### Ejemplos aprobados

- `Nómina jueves 13 de agosto de 2026`: reserva dura
- `Impuestos lunes 17 de agosto de 2026`: reserva provisional o dura según definición interna
- `Colchón mínimo DICSA Celaya`: reserva dura recurrente

## Vista 4: Cobranza objetivo

No es una pantalla de predicción estadística.

Es una pantalla de enfoque operativo usando solo las cuentas abiertas ya existentes.

### Contenido aprobado

- cliente
- documento
- saldo pendiente
- fecha de liquidación si existe
- agrupación por cliente
- total de cobranza objetivo del día
- total de cobranza objetivo de próximos 7 días

### Regla explícita

`Cobranza objetivo` no incrementa el presupuesto ejecutable hasta que el dinero aparezca como movimiento bancario real.

Su función es responder:

- `¿Qué cobros debo perseguir hoy?`
- `¿Qué clientes sostienen la presión de caja de la semana?`

## Vista 5: Pendientes

Esta vista conserva la lógica actual de:

- obligatorio
- urgente
- recomendado
- postergable

Pero deja de ser la vista principal.

Su nuevo rol es:

- lectura táctica
- auditoría rápida de pendientes
- navegación de apoyo a proveedor, banco o pago fijo

## Fórmulas de presupuesto

### 1. Saldo real disponible

`Saldo real disponible = suma neta actual de bancos`

### 2. Reserva protegida total

`Reserva protegida total = reservas duras + colchones de cuenta + reservas provisionales visibles`

### 3. Disponible presupuestable

`Disponible presupuestable = saldo real disponible - reservas duras - colchones`

### 4. Margen libre de hoy

`Margen libre hoy = disponible presupuestable - pagos mínimos de hoy`

### 5. Presión semanal

`Presión semanal = pagos mínimos de 7 días + reservas de 7 días`

### 6. Gap semanal conservador

`Gap semanal conservador = saldo real actual - presión semanal`

Regla:

- la cobranza objetivo se ve aparte
- no se suma a este gap

## Reglas de asignación por cuenta

El presupuesto debe correr por cuenta bancaria, no solo por total consolidado.

### Regla primaria

Un pago se intenta cubrir desde su cuenta objetivo natural.

### Regla secundaria

No se debe “brincar” automáticamente a otra cuenta solo porque el total global alcanza.

### Regla de seguridad

Si una cuenta queda sin margen después de reservas y pagos mínimos:

- el sistema debe marcarla como presionada
- no debe simular capacidad que realmente pertenece a otra cuenta

## Reglas sobre datos incompletos

### Facturas sin `due_date`

No deben entrar a presupuesto mínimo automático.

Deben caer en:

- `Riesgos a revisar`

### Proveedores sin convenio pero con saldo general abierto

Pueden entrar en `Postergable` o `Recomendado` según `payment_stage`, pero no deben contaminar el mínimo si no hay vencimiento claro.

### Nómina e impuestos no capturados todavía

Si no existe la reserva, el motor no puede protegerla solo por intuición.

Por eso la vista `Reservas protegidas` es obligatoria para que el presupuesto sea confiable.

## Casos límite críticos

### Caso 1: hay dinero en bancos, pero la nómina del jueves está protegida

Ejemplo:

- saldo real hoy miércoles 12 de agosto de 2026: `200,000`
- nómina protegida para jueves 13 de agosto de 2026: `121,000`

Resultado:

- el motor no puede presupuestar `200,000`
- el techo real de trabajo arranca en `79,000` antes de otros compromisos

### Caso 2: hay convenio vencido y factura próxima del mismo proveedor

Resultado esperado:

- convenio en mínimo
- factura próxima fuera de convenio en recomendado

### Caso 3: hay cobranza abierta fuerte, pero no ha entrado a banco

Resultado esperado:

- visible en cobranza objetivo
- no aumenta presupuesto ejecutable

### Caso 4: hay pago fijo semanal y colchón de cuenta

Resultado esperado:

- ambos descuentan capacidad real antes de proponer pagos negociables

## Flujo operativo diario

### Apertura de mañana

1. abrir `Centro de pagos`
2. revisar saldo real por cuenta
3. revisar reservas protegidas
4. confirmar disponible presupuestable
5. revisar pagos mínimos de hoy
6. decidir qué parte del recomendado sí saldrá hoy
7. revisar cobranza objetivo del día

### Lectura semanal

1. abrir tab `Próximos 7 días`
2. detectar día de mayor presión
3. confirmar si la semana ya está tensionada por nómina, impuestos o pagos fijos
4. ubicar proveedores más delicados de la semana

## Layout recomendado

### Home de Centro de pagos

Tabs superiores:

- `Presupuesto`
- `Reservas protegidas`
- `Cobranza objetivo`
- `Pendientes`

Dentro de `Presupuesto`:

- `Hoy`
- `Próximos 7 días`

### Home > Hoy

- fila de KPIs
- bloque de cuentas
- bloque de pagos del día
- bloque de riesgos

### Home > Próximos 7 días

- fila de KPIs semanales
- timeline de 7 días
- consolidado por proveedor
- riesgos de la semana

### Reservas protegidas

- tabla editable
- filtros por tipo
- filtros por cuenta
- resaltado de reservas duras

### Cobranza objetivo

- top clientes
- total del día
- total de 7 días
- lista operativa

### Pendientes

- conservar columnas tipo kanban existentes

## No tocar en esta fase

- `Cuentas por proveedor`
- `Cuentas bancarias`
- `Pagos fijos`
- `Catálogo Finanzas`
- `Ventas Mayoreo`

La fase 1 solo lee de esas superficies.

## Fases de implementación

### Fase 1

- nueva home `Centro de pagos` como presupuesto
- vista `Hoy`
- vista `Próximos 7 días`
- reservas protegidas
- reutilizar pendientes actuales como subvista

### Fase 1.1

- refinamiento de agrupación por proveedor
- ajuste visual de riesgos
- afinación de lectura por cuenta

### Fase 2

- corte histórico plan vs ejecución real
- comparativo entre presupuesto matutino y movimientos bancarios del día

## Criterio de éxito

La fase está bien lograda si a las 8:00 a.m. del miércoles 12 de agosto de 2026, o de cualquier día operativo, Finanzas puede abrir `Centro de pagos` y responder en pocos minutos:

- cuánto puede pagar hoy sin tocar dinero protegido
- qué proveedor exige pago mínimo
- qué pagos conviene mover hoy si sobra margen
- qué día de la próxima semana trae más presión
- qué cobranza necesita empujarse hoy para sostener la semana

## Resumen ejecutivo

La mejor versión de `Centro de pagos` no es una lista más sofisticada de urgencias.

Es un `presupuesto conservador de caja` con dos velocidades:

- `Hoy` para decidir ejecución
- `Próximos 7 días` para anticipar presión

Y con una capa explícita de `Reservas protegidas` para que la pantalla deje de sobreestimar lo que realmente se puede pagar.
