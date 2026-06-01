# Contrato Base: Dashboard Finanzas

Este documento fija el contrato funcional del `Dashboard Finanzas` como superficie ejecutiva crítica para análisis y toma de decisiones.

## Regla madre

`Dashboard Finanzas` no es una pantalla de navegación.

`Dashboard Finanzas` es un centro de lectura ejecutiva para responder, de forma inmediata:

- cuánto efectivo y liquidez real tiene la operación
- cuánto está comprometido
- qué pagos presionan la caja
- qué proveedores concentran mayor riesgo
- qué compromisos vienen por vencer
- cómo impacta compras al flujo financiero

La navegación ya vive en el menú lateral. El canvas principal debe usarse para análisis.

## Alcance aprobado

En esta fase, `Dashboard Finanzas` se construye como dashboard de:

- tesorería
- cuentas por pagar
- compromisos
- ejecución de pagos
- riesgo proveedor
- cruce con compras

No entra todavía la capa contable formal de:

- balance general
- estado de resultados
- utilidad neta oficial
- razones financieras formales

Esa capa se reserva para `Dirección` cuando exista el modelo contable completo.

## Horizonte temporal

`Finanzas` no debe vivir solo en el instante.

Los horizontes mínimos del dashboard deben ser:

- `mes actual`
- `mes anterior`
- `últimos 90 días`

Y, cuando aplique por bloque:

- `semana actual`
- `próximos 7 días`
- `próximos 30 días`

Regla explícita:

- Si una métrica no gana valor en lectura diaria, debe privilegiarse mes/periodo.
- Si una métrica presiona liquidez o vencimientos, sí puede usar ventana corta.

## Contrato funcional del dashboard

El dashboard se organiza en 6 bloques principales.

### 1. Fila superior: lectura ejecutiva

Debe responder en segundos el estado financiero operativo del periodo.

Cards aprobadas:

- `Saldo disponible`
- `Cuentas por pagar`
- `Vencido`
- `Compromisos del mes`
- `Flujo neto proyectado`
- `Presión de caja`

Cada card debe tener:

- valor principal
- comparación vs periodo anterior cuando exista
- contexto corto
- semáforo o tono ejecutivo cuando aplique

### 2. Bloque: liquidez

Debe responder:

- cuánto dinero hay disponible de verdad
- dónde está
- cuánto ya está comprometido

Contenido aprobado:

- saldo total disponible
- saldo por banco
- disponibilidad real vs comprometida
- proyección de flujo de caja a corto plazo

Preguntas que debe resolver:

- `¿Qué tanto dinero real podemos mover hoy?`
- `¿Qué tanto de ese dinero ya está comprometido?`
- `¿Qué banco concentra más capacidad o más tensión?`

### 3. Bloque: cuentas por pagar

Debe responder:

- cuánto debemos
- qué parte está vencida
- qué parte vence pronto
- dónde está concentrado el pasivo

Contenido aprobado:

- total por pagar
- vencido
- por vencer en 7 días
- por vencer en 30 días
- antigüedad de saldos
- top proveedores por saldo pendiente

Preguntas que debe resolver:

- `¿Cuál es el tamaño real del pasivo operativo?`
- `¿Qué tan urgente es?`
- `¿En qué proveedores está la mayor exposición?`

### 4. Bloque: ejecución de pagos

Debe responder:

- qué se puede pagar
- qué se debe pagar primero
- qué pasa si se ejecuta el plan sugerido

Contenido aprobado:

- pagos sugeridos hoy
- monto sugerido total
- pagos ejecutados del periodo
- pagos fijos vs variables
- impacto de la ejecución sobre caja disponible

Preguntas que debe resolver:

- `¿Qué pagos sí podemos ejecutar hoy sin romper caja?`
- `¿Qué pagos deben esperar?`
- `¿Qué tanto del mes ya se ejecutó?`

### 5. Bloque: proveedores

Debe responder:

- qué proveedores son más críticos
- cuáles están atrasados
- cuáles están bajo convenio
- dónde hay mayor riesgo financiero-operativo

Contenido aprobado:

- proveedores con mayor saldo
- proveedores con mayor atraso
- convenios activos
- cumplimiento de convenios
- facturas de mayor antigüedad

Preguntas que debe resolver:

- `¿Quién es el proveedor más delicado hoy?`
- `¿Dónde hay riesgo de ruptura operativa o comercial?`
- `¿Qué convenios están funcionando y cuáles no?`

### 6. Bloque: cruce con compras

Debe responder:

- cómo compras está cargando tesorería
- qué compras ya generaron pasivo
- qué sigue incompleto entre operación y finanzas

Contenido aprobado:

- compras del mes que ya generaron compromiso
- tickets pendientes de factura
- tickets facturados vs no facturados
- proveedores/materiales que más cargan flujo

Preguntas que debe resolver:

- `¿Qué parte de la presión financiera viene de compras recientes?`
- `¿Qué tickets siguen sin formalizarse en factura?`
- `¿Qué proveedor o material está jalando más caja?`

## Visualización recomendada

El dashboard debe usar mezcla de:

- cards ejecutivas
- barras horizontales de concentración
- tablas cortas de top y riesgo
- comparativos vs periodo anterior
- alertas con jerarquía visual fuerte

No debe depender principalmente de:

- texto largo
- descripciones contractuales
- widgets decorativos
- navegación repetida

## Alertas ejecutivas

El dashboard debe tener una zona de alertas con señales accionables, no solo informativas.

Alertas aprobadas:

- saldo disponible insuficiente vs compromisos
- proveedor con saldo vencido relevante
- concentración excesiva por proveedor
- convenios incumplidos o deteriorados
- tickets de compras sin factura
- presión alta de pagos próximos

Regla explícita:

- una alerta debe implicar una posible decisión
- si solo “informa” pero no orienta acción, no merece lugar prioritario

## Qué no debe ser

`Dashboard Finanzas` no debe:

- ser menú glorificado
- ser solo una lista de pendientes
- fingir contabilidad formal sin base contable real
- mezclar métricas decorativas sin consecuencia
- duplicar la navegación del panel lateral dentro del canvas

## Capa contable reservada

La capa contable formal queda explícitamente fuera de esta fase y se reserva para una futura superficie ejecutiva de `Dirección`.

Queda apartado para más adelante:

- balance general formal
- estado de resultados formal
- utilidad neta oficial
- razones financieras formales
- cortes y cierres contables

## Checklist de cierre

`Dashboard Finanzas` no debe considerarse homologado si falla cualquiera de estos puntos:

- responde preguntas reales de liquidez, pasivo y ejecución
- privilegia análisis sobre navegación
- separa tesorería operativa de contabilidad formal
- usa horizontes temporales útiles
- muestra concentración y riesgo por proveedor
- cruza compras con impacto financiero
- incluye alertas que ayuden a decidir
- no inventa estados financieros oficiales sin soporte contable
