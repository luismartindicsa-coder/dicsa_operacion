# Plan de implementación por fases: Centro de pagos como presupuesto diario y semanal

Fecha de aterrizaje: miércoles, 12 de agosto de 2026.

Este documento baja el blueprint funcional a una ruta de ejecución real.

Importante:

- este plan no aprueba cambios en `Cuentas por proveedor`
- este plan no aprueba cambios en `Cuentas bancarias`
- este plan no aprueba cambios en `Pagos fijos`
- este plan no aprueba cambios en `Catálogo Finanzas`
- este plan no aprueba captura nueva en `Ventas Mayoreo`
- todo lo nuevo vive dentro de `Centro de pagos`

## Objetivo

Convertir la pantalla actual de `Centro de pagos` en un módulo de presupuesto operativo de caja que permita, desde la mañana:

- definir cuánto sí se puede pagar hoy
- proteger dinero que no se debe tocar
- visualizar qué se necesita cobrar hoy
- anticipar la presión consolidada de los próximos 7 días

## Punto de partida técnico actual

Hoy la base ya existe en:

- `apps/dicsa_operacion/lib/app/finanzas/finanzas_payment_center_page.dart`
- `apps/dicsa_operacion/lib/app/finanzas/finanzas_financial_rules.dart`

La pantalla actual ya carga:

- saldos bancarios
- facturas proveedor
- convenios y parcialidades
- pagos fijos
- directorio de empresas
- tickets y aplicaciones de compras
- bitácora de aprendizaje

Eso es bueno porque evita pedir más trabajo en otras pantallas.

El problema es que hoy todo está armado para una lógica de:

- `Obligatorio`
- `Urgente`
- `Recomendado`
- `Postergable`

Y no todavía para una lógica de:

- `Presupuesto de hoy`
- `Reservas protegidas`
- `Cobranza objetivo`
- `Presión de 7 días`

## Decisiones ya cerradas

- la caja disponible parte solo del saldo bancario real actual
- la cobranza esperada no aumenta disponibilidad hasta que entre al banco
- `Nómina`, `Impuestos` y `Colchón de cuenta` viven como `Reservas protegidas`
- la vista semanal es una ventana móvil de 7 días
- no se agregan nuevas capturas en otros módulos
- los convenios y las facturas próximas del mismo proveedor deben convivir, no fusionarse de forma ciega

## Regla operativa para proveedores con convenio y facturas próximas

Este es el punto más delicado del motor y debe quedar fijo desde el inicio.

### Regla base

El proveedor se analiza en dos carriles simultáneos:

- `Convenio`
- `Fuera de convenio`

### Cómo se comporta

- si existe parcialidad vencida o que vence hoy, entra como `mínimo`
- si existe parcialidad dentro de los próximos 7 días, entra como `presión semanal`
- si además hay factura fuera de convenio y próxima a vencer, esa factura no se mezcla con el monto del convenio
- la factura fuera de convenio puede entrar como `recomendada` o `mínimo`, según su `due_date`

### Resultado esperado

En un mismo proveedor podemos ver al mismo tiempo:

- un mínimo por convenio
- una recomendación por factura próxima

Eso evita esconder presión real.

## Arquitectura recomendada dentro de Centro de pagos

La recomendación es no seguir creciendo todo dentro de `finanzas_payment_center_page.dart`.

### Capa 1. Orquestación de datos

Responsabilidad:

- cargar fuentes existentes
- normalizar insumos
- entregar un snapshot único al motor

Archivo sugerido:

- `finanzas_payment_center_budget_loader.dart`

### Capa 2. Motor presupuestal

Responsabilidad:

- calcular reservas
- calcular disponible presupuestable
- calcular mínimos de hoy
- calcular presión de 7 días
- separar cobranza objetivo de caja ejecutable

Archivos sugeridos:

- `finanzas_payment_center_budget_models.dart`
- `finanzas_payment_center_budget_engine.dart`

### Capa 3. Persistencia propia de Centro de pagos

Responsabilidad:

- guardar reservas protegidas
- guardar configuración operativa del módulo

Archivos sugeridos:

- `finanzas_payment_center_reserves_store.dart`

Si se requiere tabla nueva, debe ser solo para `Centro de pagos`.

### Capa 4. Superficie visual

Responsabilidad:

- tabs
- resumen del día
- resumen semanal
- reservas
- cobranza objetivo
- pendientes

Archivo principal:

- `finanzas_payment_center_page.dart`

## Fase 0. Cierre de reglas y fórmulas

Objetivo:

Cerrar el contrato funcional antes de tocar UI.

Entregables:

- fórmulas definitivas de:
  - saldo real disponible
  - reserva protegida total
  - disponible presupuestable
  - margen libre de hoy
  - presión semanal
  - gap semanal conservador
- criterio definitivo para:
  - convenios
  - facturas fuera de convenio
  - pagos fijos
  - facturas sin `due_date`
  - cobranza visible pero no presupuestable
- lista cerrada de tipos de reserva

Tipos de reserva sugeridos desde el día 1:

- `NOMINA`
- `IMPUESTOS`
- `COLCHON_CUENTA`
- `COMPROMISO_PROTEGIDO`

Criterio de salida:

- ya no hay dudas sobre cómo tratar convenio vs factura próxima
- ya no hay dudas sobre qué sí descuenta caja y qué solo se muestra como presión

## Fase 1. Separación técnica del motor actual

Objetivo:

Separar cálculo y UI para que el rediseño no rompa la operación actual.

Trabajo:

- extraer la carga de datos del page widget
- extraer modelos de entrada y salida del presupuesto
- extraer reglas de clasificación y cálculo
- dejar la pantalla actual funcional mientras nace la nueva home interna

Archivos esperados:

- nuevo `budget_loader`
- nuevo `budget_engine`
- nuevos `budget_models`
- `finanzas_payment_center_page.dart` más delgado

Riesgo que resuelve:

- hoy la lógica vive muy pegada al render y eso vuelve caro cualquier cambio

Criterio de salida:

- el cálculo del centro de pagos ya corre fuera del widget principal
- la pantalla sigue leyendo exactamente las mismas fuentes de datos

## Fase 2. Reservas protegidas

Objetivo:

Construir primero la capa que evita sobrepresupuestar caja.

Trabajo:

- crear tab `Reservas protegidas`
- permitir alta y edición de reservas dentro de `Centro de pagos`
- soportar reservas globales y por cuenta
- calcular impacto inmediato sobre cada cuenta y sobre el total

Campos mínimos sugeridos por reserva:

- tipo de reserva
- nombre visible
- monto
- cuenta objetivo opcional
- fecha efectiva
- fecha límite opcional
- activa o inactiva
- nota

Reglas:

- `Nómina` e `Impuestos` pueden ser reserva global
- `Colchón de cuenta` debe afectar cuenta específica
- si no hay reservas cargadas, la pantalla debe advertir que el presupuesto es incompleto

Persistencia:

- nueva tabla o almacenamiento propio del centro de pagos
- sin tocar tablas existentes de otros módulos

Criterio de salida:

- Finanzas puede proteger nómina, impuestos y colchones sin salir de `Centro de pagos`
- el saldo disponible ya refleja esas protecciones

## Fase 3. Presupuesto > Hoy

Objetivo:

Entregar la vista principal de decisión diaria.

Trabajo:

- nueva home de `Presupuesto`
- subtab `Hoy`
- KPIs de:
  - saldo real en bancos
  - reservas protegidas
  - disponible presupuestable
  - pagos mínimos de hoy
  - pagos recomendados de hoy
  - margen libre
- bloque por cuenta bancaria
- bloque por proveedor
- separación clara entre:
  - mínimo hoy
  - recomendado hoy
  - riesgo a revisar

Reglas de cálculo:

- primero se resta reserva
- luego se apartan mínimos de hoy
- después se sugiere recomendado si todavía existe margen
- la cobranza del día se muestra aparte y no aumenta el disponible

Tratamiento de casos:

- convenio vencido: `mínimo hoy`
- factura vencida sin convenio: `mínimo hoy`
- factura próxima fuera de convenio: `recomendada hoy` o `mínimo hoy` según fecha
- factura sin `due_date`: `riesgo a revisar`
- pago fijo cercano: entra como mínimo o presión según fecha

Criterio de salida:

- a las 8:00 a.m. se puede abrir la pantalla y saber cuánto sí puede salir hoy
- el monto protegido ya no se confunde con dinero libre

## Fase 4. Presupuesto > Próximos 7 días

Objetivo:

Agregar la lectura consolidada semanal sin irse a una proyección contable compleja.

Trabajo:

- subtab `Próximos 7 días`
- timeline móvil de 7 días
- total diario de presión
- consolidado semanal por proveedor
- consolidado semanal por cuenta
- detección automática del día más presionado

Qué debe sumar presión semanal:

- parcialidades de convenio en 7 días
- facturas con vencimiento en 7 días
- pagos fijos próximos
- reservas protegidas con fecha dentro de la ventana

Qué no debe sumar caja:

- cobranza esperada no depositada

Criterio de salida:

- Finanzas puede detectar desde la mañana si el jueves, viernes o lunes viene apretado
- la semana se ve como ventana operativa, no como listado suelto

## Fase 5. Cobranza objetivo

Objetivo:

Separar claramente lo que debo cobrar de lo que realmente puedo gastar.

Trabajo:

- tab `Cobranza objetivo`
- resumen:
  - cobranza objetivo de hoy
  - cobranza objetivo de 7 días
  - principales clientes por monto
- lista operativa por documento o cliente, según lo que mejor soporte la fuente actual

Reglas:

- visible para empuje operativo
- no incrementa disponible presupuestable
- debe poder cruzarse visualmente con la presión semanal para entender la tensión

Criterio de salida:

- el usuario puede ver qué cobro necesita perseguir hoy sin confundirlo con caja ya disponible

## Fase 6. Pendientes, convivencia y transición

Objetivo:

Conservar la lectura de pendientes actual como vista secundaria, sin dejarla como home principal.

Trabajo:

- mover la lógica actual de:
  - `Obligatorio`
  - `Urgente`
  - `Recomendado`
  - `Postergable`
- reubicarla en tab `Pendientes`
- ajustar copy y jerarquía visual para que la home sea `Presupuesto`

Razón:

- la operación actual no se pierde
- el equipo mantiene una lectura táctica complementaria
- el cambio de mentalidad ocurre sin borrar información útil

Criterio de salida:

- el usuario entra primero a presupuesto
- pendientes queda como apoyo, no como motor principal

## Fase 7. Validación operativa y endurecimiento

Objetivo:

Pulir el módulo con casos reales antes de darlo por estable.

Pruebas mínimas:

- día con saldo alto pero nómina protegida
- día con convenio vencido y factura próxima del mismo proveedor
- día con poco saldo y varios pagos fijos
- día con cobranza fuerte pendiente de entrar
- cuentas con presión desigual entre Celaya y Mazatlán

Checklist de cierre:

- la suma por cuenta cuadra con el total consolidado
- la reserva por cuenta no se fuga a otra cuenta por error
- no se sugiere pagar más de lo realmente disponible
- la cobranza nunca infla disponibilidad
- los casos sin `due_date` no contaminan el mínimo automático

## Orden recomendado de ejecución real

1. Fase 0
2. Fase 1
3. Fase 2
4. Fase 3
5. Fase 4
6. Fase 5
7. Fase 6
8. Fase 7

Este orden prioriza seguridad de caja antes que sofisticación visual.

## Qué sí se entrega temprano

El primer corte realmente útil para operación no debería esperar hasta el final.

Meta recomendada del primer release usable:

- Fase 1 terminada
- Fase 2 terminada
- Fase 3 terminada

Con eso ya existiría una versión útil para decidir la mañana.

## Qué no entra en este plan

- nueva captura en `Ventas Mayoreo`
- meter niveles de certeza manuales
- tocar flujos de `Cuentas por proveedor`
- tocar flujos de `Cuentas bancarias`
- tocar flujos de `Pagos fijos`
- rehacer catálogos
- proyección contable avanzada
- forecast probabilístico

## Riesgos principales

### Riesgo 1. Mezclar convenio y factura próxima en una sola bolsa

Consecuencia:

- se oculta presión real del proveedor

Control:

- mantener doble carril por proveedor

### Riesgo 2. Sobreusar saldo consolidado y no respetar cuenta objetivo

Consecuencia:

- el sistema aparenta liquidez que no existe en la cuenta correcta

Control:

- presupuesto por cuenta antes de consolidado global

### Riesgo 3. Soltar `Hoy` sin reservas protegidas funcionales

Consecuencia:

- el presupuesto nace inflado y peligroso

Control:

- reservas antes de abrir el presupuesto como pantalla confiable

### Riesgo 4. Querer resolver demasiada inteligencia comercial en esta fase

Consecuencia:

- se alarga el proyecto y se mete trabajo a otras áreas

Control:

- usar solo la data existente

## Criterio final de éxito

El proyecto queda bien logrado cuando, al abrir `Centro de pagos` cada mañana, Finanzas puede responder en pocos minutos:

- cuánto dinero real hay
- cuánto dinero está protegido
- cuánto sí puede salir hoy
- qué pagos mínimos no se deben brincar
- qué parte del recomendado cabe hoy
- qué día de la semana viene más presionado
- qué cobranza se necesita empujar para sostener la semana

## Resumen ejecutivo

La implementación correcta no empieza por una pantalla más bonita.

Empieza por:

- separar el motor
- proteger reservas
- construir `Hoy`
- después construir `7 días`
- y finalmente dejar `Pendientes` como capa secundaria

Ese orden nos da una pantalla poderosa sin meter más trabajo en el resto de Finanzas.
