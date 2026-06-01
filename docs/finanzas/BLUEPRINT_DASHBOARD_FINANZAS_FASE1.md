# Blueprint: Dashboard Finanzas Fase 1

Este documento aterriza el `Dashboard Finanzas` a nivel de pantalla, bloques, métricas y fuentes reales de datos.

Se construye sobre el contrato base de [CONTRATO_BASE_DASHBOARD_FINANZAS.md](./CONTRATO_BASE_DASHBOARD_FINANZAS.md).

## Propósito

`Dashboard Finanzas` debe ser la superficie de lectura ejecutiva para tomar decisiones rápidas sobre:

- liquidez real
- presión de caja
- compromisos de pago
- riesgo por proveedor
- ejecución financiera
- cruce entre compras y pasivo operativo

No es una pantalla de navegación.

## Horizonte recomendado

El dashboard debe trabajar con 3 horizontes principales:

- `Mes actual`
- `Mes anterior`
- `Últimos 90 días`

Y con ventanas cortas solo para riesgo de caja:

- `Próximos 7 días`
- `Próximos 30 días`

## Layout de pantalla

### 1. Fila superior: KPI ejecutivos

Seis cards homogéneas, en una sola fila, con comparación corta y contexto.

Cards:

- `Saldo disponible`
- `Cuentas por pagar`
- `Vencido`
- `Compromisos del mes`
- `Flujo neto proyectado`
- `Presión de caja`

Regla visual:

- cards uniformes
- icono con acento naranja/plata/verde/azul según semántica
- valor principal fuerte
- subtítulo corto con comparación contra periodo anterior
- sin navegación dentro de la card

### 2. Segunda fila: lectura de liquidez y pasivo

Dos bloques grandes lado a lado.

Bloque izquierdo:

- `Liquidez y bancos`

Bloque derecho:

- `Cuentas por pagar`

### 3. Tercera fila: ejecución y proveedores

Dos bloques grandes lado a lado.

Bloque izquierdo:

- `Ejecución de pagos`

Bloque derecho:

- `Riesgo / concentración por proveedor`

### 4. Cuarta fila: cruce operativo y alertas

Dos bloques grandes lado a lado.

Bloque izquierdo:

- `Cruce con compras`

Bloque derecho:

- `Alertas ejecutivas`

## Bloques y métricas

### A. Saldo disponible

Pregunta:

- `¿Cuánto dinero líquido tenemos hoy?`

Métrica principal:

- saldo neto total de bancos

Comparativo:

- saldo contra cierre del mes anterior

Fuente:

- `finanzas_bank_accounts_store.dart`
- clase `FinanzasBankMovementRecord`

Disponibilidad:

- `Disponible hoy`

Derivación:

- suma de créditos menos débitos por cuenta bancaria

### B. Cuentas por pagar

Pregunta:

- `¿Cuánto pasivo operativo abierto tenemos?`

Métrica principal:

- saldo pendiente total de facturas de proveedor

Comparativo:

- saldo pendiente contra mes anterior

Fuente:

- `finanzas_provider_accounts_store.dart`
- clase `FinanzasSupplierInvoiceRecord`

Disponibilidad:

- `Disponible hoy`

Derivación:

- suma de `balanceAmount` de facturas abiertas

### C. Vencido

Pregunta:

- `¿Cuánto del pasivo ya está fuera de tiempo?`

Métrica principal:

- saldo vencido

Comparativo:

- vencido vs mes anterior

Fuente:

- `finanzas_provider_accounts_store.dart`

Disponibilidad:

- `Disponible hoy`

Derivación:

- facturas con `dueDate` menor a hoy y saldo pendiente mayor a cero

### D. Compromisos del mes

Pregunta:

- `¿Cuánto está comprometido este mes entre pagos fijos y proveedores?`

Métrica principal:

- suma de pagos fijos pendientes del mes
- más pasivo con vencimiento dentro del mes

Comparativo:

- compromiso del mes actual vs mes anterior

Fuentes:

- `finanzas_fixed_payments_store.dart`
- `finanzas_provider_accounts_store.dart`

Disponibilidad:

- `Disponible hoy`

Derivación:

- mezcla de pagos fijos calendarizados + facturas con vencimiento dentro del periodo

### E. Flujo neto proyectado

Pregunta:

- `¿Si mantenemos el ritmo actual, el flujo de corto plazo cierra positivo o tenso?`

Métrica principal:

- entradas esperadas menos salidas comprometidas

Comparativo:

- proyección actual vs mes anterior cuando exista base

Fuentes:

- `finanzas_bank_accounts_store.dart`
- `finanzas_fixed_payments_store.dart`
- `finanzas_provider_accounts_store.dart`

Disponibilidad:

- `Disponible como derivación fase 1`

Derivación:

- entradas esperadas desde cuentas de cobro / movimientos de entrada esperados
- menos pagos fijos pendientes
- menos pagos prioritarios sugeridos a proveedores

Nota:

- debe marcarse como `proyectado`, no como caja real

### F. Presión de caja

Pregunta:

- `¿Qué tan tensa está la liquidez frente a lo que viene?`

Métrica principal:

- ratio entre liquidez disponible y compromisos próximos

Representación:

- semáforo
- baja / media / alta

Fuentes:

- `finanzas_bank_accounts_store.dart`
- `finanzas_fixed_payments_store.dart`
- `finanzas_provider_accounts_store.dart`

Disponibilidad:

- `Disponible como derivación fase 1`

Derivación sugerida:

- `saldo disponible / (vencido + próximos 7 días + pagos fijos inmediatos)`

## Bloque: Liquidez y bancos

Preguntas:

- `¿Dónde está el dinero?`
- `¿Qué cuentas concentran la caja?`
- `¿Qué parte ya está comprometida?`

Contenido:

- card o barra de `Saldo disponible total`
- barras horizontales `Saldo por banco`
- tabla corta `Top cuentas con mayor saldo`
- mini comparativo `Disponible vs comprometido`

Fuentes:

- `finanzas_bank_accounts_store.dart`

Componentes recomendados:

- barras horizontales
- tabla top 5
- donut o barra comparativa para libre vs comprometido

## Bloque: Cuentas por pagar

Preguntas:

- `¿Cuánto debemos?`
- `¿Qué parte es urgente?`
- `¿Con quién está concentrado el pasivo?`

Contenido:

- total abierto
- vencido
- por vencer en 7 días
- por vencer en 30 días
- top proveedores por saldo
- antigüedad de saldos

Fuentes:

- `finanzas_provider_accounts_store.dart`

Componentes recomendados:

- cards internas
- barras por proveedor
- tabla corta de antigüedad

## Bloque: Ejecución de pagos

Preguntas:

- `¿Qué pagos conviene ejecutar ya?`
- `¿Qué peso tienen los pagos fijos?`
- `¿Qué tanto se ha atendido del mes?`

Contenido:

- monto ejecutado del mes
- monto pendiente del mes
- pagos fijos pagados vs pendientes
- pagos a proveedor aplicados vs pendientes
- lista corta de `pagos sugeridos hoy`

Fuentes:

- `finanzas_fixed_payments_store.dart`
- `finanzas_bank_accounts_store.dart`
- `finanzas_provider_accounts_store.dart`

Componentes recomendados:

- barra de progreso
- tabla corta de sugerencias
- chips de prioridad

Nota:

- la lógica de `sugeridos hoy` puede iniciar simple con prioridad por vencimiento, saldo y convenio

## Bloque: Riesgo / concentración por proveedor

Preguntas:

- `¿Qué proveedor concentra mayor exposición?`
- `¿Dónde hay mayor atraso?`
- `¿Qué convenios están en riesgo?`

Contenido:

- top proveedores por saldo pendiente
- top proveedores por vencido
- convenios activos
- cumplimiento de convenios
- facturas de mayor antigüedad

Fuentes:

- `finanzas_provider_accounts_store.dart`

Componentes recomendados:

- barras horizontales
- ranking top 5
- tabla corta de facturas críticas

## Bloque: Cruce con compras

Preguntas:

- `¿Qué compras ya nos cargaron flujo?`
- `¿Qué tickets siguen incompletos para finanzas?`
- `¿Qué proveedor o material está jalando más compromiso?`

Contenido:

- importe de compras del mes
- tickets sin factura
- tickets pendientes de pago
- top proveedores por compra del mes
- top materiales por compra del mes
- compra facturada vs no facturada

Fuentes:

- `compras_tickets_store.dart`
- clase `ComprasTicketRecord`

Componentes recomendados:

- cards internas
- barras por proveedor/material
- tabla corta de tickets críticos

## Bloque: Alertas ejecutivas

Preguntas:

- `¿Qué debo atender primero?`
- `¿Qué representa riesgo inmediato?`

Alertas aprobadas:

- saldo disponible insuficiente vs vencido
- proveedor con saldo vencido alto
- convenio con cumplimiento delicado
- pagos fijos cercanos sin cobertura clara
- compras altas del mes no formalizadas en factura
- concentración excesiva en un solo proveedor

Fuentes:

- todas las anteriores, derivadas por reglas

Componentes recomendados:

- lista de alertas con icono, color y texto corto
- severidad `alta`, `media`, `seguimiento`

## Mapeo de datos reales disponibles hoy

### 1. Finanzas proveedores

Archivo:

- `lib/app/finanzas/finanzas_provider_accounts_store.dart`

Datos útiles confirmados:

- proveedor
- fecha de factura
- vencimiento
- monto total
- saldo pendiente
- estatus
- prioridad manual
- convenios
- parcialidades
- vínculos factura-ticket

Bloques que alimenta:

- cuentas por pagar
- vencido
- compromisos del mes
- ejecución de pagos
- proveedores
- alertas

### 2. Finanzas bancos

Archivo:

- `lib/app/finanzas/finanzas_bank_accounts_store.dart`

Datos útiles confirmados:

- movimientos bancarios
- crédito / débito
- categoría
- referencia
- cuenta / empresa / sucursal
- vínculo a factura proveedor
- vínculo a pago fijo
- cuentas de cobro con saldo aprobado/pagado/pendiente

Bloques que alimenta:

- saldo disponible
- liquidez y bancos
- flujo neto proyectado
- ejecución de pagos
- presión de caja

### 3. Finanzas pagos fijos

Archivo:

- `lib/app/finanzas/finanzas_fixed_payments_store.dart`

Datos útiles confirmados:

- monto
- fecha de pago
- estatus
- empresa / sucursal
- método de ejecución
- fecha de liquidación

Bloques que alimenta:

- compromisos del mes
- flujo neto proyectado
- presión de caja
- ejecución de pagos
- alertas

### 4. Compras tickets

Archivo:

- `lib/app/compras/compras_tickets_store.dart`

Datos útiles confirmados:

- proveedor
- material
- fecha
- peso pagable
- precio
- sobreprecio
- importe
- estatus de factura
- estatus de pago

Bloques que alimenta:

- cruce con compras
- alertas
- concentración por proveedor/material ligada a flujo

## Qué sí se puede implementar ya

### Implementación directa

- saldo disponible
- cuentas por pagar
- vencido
- top proveedores por saldo
- top proveedores por vencido
- saldo por banco
- pagos fijos pendientes del mes
- tickets sin factura
- tickets pendientes de pago
- compras del mes por proveedor
- compras del mes por material

### Implementación con derivación simple

- compromisos del mes
- flujo neto proyectado
- presión de caja
- pagos sugeridos hoy
- cumplimiento de convenios
- libre vs comprometido
- compra facturada vs no facturada

### Mejor dejar para iteración posterior

- pronóstico financiero más sofisticado
- simulador de escenarios
- clasificación avanzada de riesgo
- modelos contables formales

## Orden recomendado de implementación

### Fase 1A

- fila superior de KPI ejecutivos
- bloque `Liquidez y bancos`
- bloque `Cuentas por pagar`

### Fase 1B

- bloque `Ejecución de pagos`
- bloque `Riesgo / concentración por proveedor`

### Fase 1C

- bloque `Cruce con compras`
- bloque `Alertas ejecutivas`

## Regla final

Si un dato no es formalmente contable, debe presentarse como:

- `operativo`
- `estimado`
- `proyectado`
- `preliminar`

Nunca como estado financiero oficial.
