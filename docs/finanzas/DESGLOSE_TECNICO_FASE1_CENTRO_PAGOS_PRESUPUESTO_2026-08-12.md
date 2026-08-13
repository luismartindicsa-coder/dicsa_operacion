# Desglose técnico Fase 1: Centro de pagos como presupuesto

Fecha de aterrizaje: miércoles, 12 de agosto de 2026.

Este documento aterriza únicamente la `Fase 1` del plan general.

Referencia madre:

- `BLUEPRINT_CENTRO_PAGOS_PRESUPUESTO_DIARIO_Y_SEMANAL_2026-08-12.md`
- `PLAN_IMPLEMENTACION_CENTRO_PAGOS_PRESUPUESTO_POR_FASES_2026-08-12.md`

## Objetivo real de Fase 1

La `Fase 1` no es todavía la pantalla presupuestal final.

La `Fase 1` existe para separar la lógica actual de `Centro de pagos` y dejar una base técnica limpia para construir después:

- `Reservas protegidas`
- `Presupuesto > Hoy`
- `Presupuesto > Próximos 7 días`
- `Cobranza objetivo`

En otras palabras:

- en `Fase 1` todavía no ganamos toda la experiencia final
- en `Fase 1` sí ganamos una arquitectura que ya no esté amarrada a un solo widget gigante

## Regla de alcance

En esta fase no se deben tocar:

- `Cuentas por proveedor`
- `Cuentas bancarias`
- `Pagos fijos`
- `Catálogo Finanzas`
- `Ventas Mayoreo`

Y tampoco se debe abrir todavía:

- nueva captura presupuestal compleja
- tablas nuevas de otras áreas
- cambios de reglas contables

## Resultado esperado al cerrar Fase 1

La pantalla puede seguir viéndose casi igual, pero por dentro debe cambiar esto:

- la carga de datos ya no vive dentro del widget principal
- la construcción de items ya no vive dentro del widget principal
- la priorización y optimización ya no viven mezcladas con el render
- `finanzas_payment_center_page.dart` queda concentrado en UI, navegación y acciones de pantalla

## Punto de partida técnico actual

Hoy `apps/dicsa_operacion/lib/app/finanzas/finanzas_payment_center_page.dart` concentra demasiadas responsabilidades juntas.

### Responsabilidades que hoy conviven en la misma page

- carga de fuentes remotas
- normalización de proveedores
- cálculo de saldos por cuenta
- clasificación por urgencia
- cruce entre convenios, facturas y pagos fijos
- optimización de ejecución por cuenta
- armado de presets de navegación a bancos
- render principal
- vista de aprendizaje

### Cortes naturales que ya existen en el archivo

Bloque de carga:

- `_loadPage`

Bloque de cálculo:

- `_computeBalances`
- `_bucketBaseScore`
- `_maxUrgencyBucket`
- `_buildPriorityMeta`
- `_buildItems`
- `_inferTarget`
- `_resolveComprasProviderId`

Bloque de navegación y acciones:

- `_openBankExecutionForRow`
- `_buildBankLaunchPreset`
- `_openFixedPaymentsForRow`
- `_handleNavigationAction`

Bloque visual:

- `build`
- widgets privados de cards, columnas y paneles

## Fuentes que Fase 1 sí puede leer

La separación debe seguir leyendo exactamente estas fuentes existentes:

- `FinanzasCompanyDirectoryStore.loadDirectory()`
- `ComprasTicketsStore.loadTickets()`
- `ComprasTicketsStore.loadTicketPaymentApplications()`
- `FinanzasProviderAccountsStore.loadInvoices()`
- `FinanzasProviderAccountsStore.loadAgreements()`
- `FinanzasProviderAccountsStore.loadAgreementInstallments()`
- `FinanzasProviderAccountsStore.loadAgreementInvoices()`
- `FinanzasBankAccountsStore.loadMovements()`
- `FinanzasFixedPaymentsStore.loadPayments()`
- `FinanzasPaymentLearningStore.loadLogs()`

## Arquitectura objetivo al cierre de Fase 1

### Archivo 1. `finanzas_payment_center_budget_models.dart`

Responsabilidad:

- exponer modelos públicos reutilizables
- sacar del widget los enums y modelos que hoy son privados

Modelos sugeridos:

- `FinanzasPaymentCenterPriorityBucket`
- `FinanzasPaymentCenterExecutionDecision`
- `FinanzasPaymentCenterSourceSnapshot`
- `FinanzasPaymentCenterOperationalItem`
- `FinanzasPaymentCenterPriorityMeta`
- `FinanzasPaymentCenterOperationalSnapshot`

Intención:

- que el motor regrese objetos públicos
- que la page deje de depender de clases privadas para toda la lógica

### Archivo 2. `finanzas_payment_center_budget_loader.dart`

Responsabilidad:

- cargar todas las fuentes actuales
- devolver un snapshot único listo para calcular

Método sugerido:

- `loadFinanzasPaymentCenterSourceSnapshot()`

Este loader no debe:

- calcular buckets
- optimizar pagos
- pintar UI

Solo carga y entrega.

### Archivo 3. `finanzas_payment_center_budget_engine.dart`

Responsabilidad:

- calcular saldos por cuenta
- construir items operativos
- resolver bucket, score y razones
- ejecutar la optimización por cuenta reutilizando `optimizePaymentExecution`

Funciones sugeridas:

- `computeFinanzasPaymentCenterBalances(...)`
- `buildFinanzasPaymentCenterOperationalItems(...)`
- `buildFinanzasPaymentCenterOperationalSnapshot(...)`

### Archivo 4. `finanzas_payment_center_page.dart`

Responsabilidad al cierre de fase:

- pedir carga al loader
- pedir cálculo al engine
- pintar lo que ya recibe procesado
- conservar navegación y acciones de pantalla

## Decisión importante sobre la vista actual

En `Fase 1` no conviene rediseñar todavía la home.

La meta correcta es:

- conservar el comportamiento visual actual
- sustituir el origen interno de datos por loader + engine

Eso reduce riesgo y nos deja listos para la `Fase 2` y `Fase 3`.

## Subfases recomendadas

## Fase 1A. Extraer modelos públicos

Objetivo:

Sacar del widget principal lo mínimo necesario para que el cálculo pueda vivir fuera.

Trabajo puntual:

- mover enums privados a modelos públicos
- mover `_PaymentCenterItem` a una clase pública reutilizable
- definir un snapshot fuente con todas las listas cargadas
- definir un snapshot calculado con:
  - balances por cuenta
  - items operativos
  - logs de aprendizaje

Archivos tocados:

- nuevo `finanzas_payment_center_budget_models.dart`
- `finanzas_payment_center_page.dart`

No debe pasar todavía:

- rediseño visual
- cambio de reglas
- alta de nuevas tabs

Definición de terminado:

- ya no dependemos de `_PaymentCenterItem` privado para la lógica central
- los enums clave ya pueden ser usados por engine y page

## Fase 1B. Extraer el loader

Objetivo:

Sacar la carga remota del widget.

Trabajo puntual:

- mover `Future.wait` del `_loadPage` actual a un loader dedicado
- devolver un `FinanzasPaymentCenterSourceSnapshot`
- mantener intactas las mismas fuentes y el mismo orden de lectura

Archivos tocados:

- nuevo `finanzas_payment_center_budget_loader.dart`
- `finanzas_payment_center_page.dart`

Regla:

- el loader no debe mezclar reglas de negocio
- el loader no debe optimizar nada

Definición de terminado:

- la page ya no conoce directamente todas las llamadas a store
- el loader es el único punto que arma el snapshot fuente

## Fase 1C. Extraer el motor operativo actual

Objetivo:

Mover toda la lógica de clasificación y armado de items fuera del widget.

Trabajo puntual:

- mover `_computeBalances`
- mover `_bucketBaseScore`
- mover `_maxUrgencyBucket`
- mover `_buildPriorityMeta`
- mover `_buildItems`
- mover `_inferTarget`
- mover `_resolveComprasProviderId`
- reutilizar `optimizePaymentExecution` desde `finanzas_financial_rules.dart`

Punto fino:

La intención no es reescribir la lógica.

La intención es:

- sacar la lógica tal cual está
- dejarla testeable
- dejarla lista para evolucionar a presupuesto después

Archivos tocados:

- nuevo `finanzas_payment_center_budget_engine.dart`
- `finanzas_payment_center_page.dart`

Definición de terminado:

- el widget principal ya no decide buckets ni arma items
- el engine entrega un resultado listo para render

## Fase 1D. Adaptar la page sin cambio visual fuerte

Objetivo:

Hacer que la page consuma loader + engine sin abrir todavía el frente de UX final.

Trabajo puntual:

- cambiar `_loadPage` para usar loader y engine
- mantener métricas actuales:
  - `Disponible total`
  - `Pendientes`
  - `Monto sugerido`
  - `Cobertura inmediata`
- mantener columnas:
  - `Obligatorio`
  - `Urgente`
  - `Recomendado`
  - `Postergable`
- mantener navegación a:
  - `Cuentas bancarias`
  - `Pagos fijos`
  - `Cuentas por proveedor`

Se puede quedar en la page por ahora:

- `_buildBankLaunchPreset`
- `_openBankExecutionForRow`
- `_openFixedPaymentsForRow`
- `_handleNavigationAction`
- `_money`
- `_dateLabel`

Razón:

Esas piezas son de borde de UI y navegación.

No es necesario sacarlas todavía para que `Fase 1` cumpla su objetivo.

Definición de terminado:

- el usuario sigue viendo una experiencia funcionalmente equivalente
- por dentro la lógica ya está desacoplada

## Fase 1E. Regresión y cierre

Objetivo:

Confirmar que la extracción no cambió el comportamiento operativo.

Qué se debe validar:

- mismo total de items
- mismos buckets por item
- mismo monto sugerido
- mismo monto ejecutable
- mismas decisiones de:
  - `PAGAR_COMPLETO`
  - `ABONAR`
  - `ESPERAR`
- mismos presets de navegación a banco para:
  - factura
  - convenio
  - saldo general
  - pago fijo

Definición de terminado:

- la extracción no alteró salida operativa
- la page quedó preparada para las siguientes fases

## Orden recomendado de ejecución

1. Crear `budget_models`
2. Crear `budget_loader`
3. Crear `budget_engine`
4. Adaptar `finanzas_payment_center_page.dart`
5. Validar regresión

Ese orden baja riesgo porque primero crea estructuras y luego cambia el consumo.

## Qué se queda fuera de Fase 1 a propósito

No entra todavía:

- `Reservas protegidas`
- nueva tab `Presupuesto`
- nueva tab `Cobranza objetivo`
- vista `Próximos 7 días`
- nuevas tablas para reservas
- nuevos cálculos de caja protegida
- nueva semántica visual de presupuesto

Eso arranca hasta la siguiente fase.

## Contrato de no regresión

Para considerar `Fase 1` aceptada, estas reglas deben seguir iguales:

- el saldo disponible sigue saliendo de movimientos bancarios existentes
- la optimización por cuenta sigue usando `optimizePaymentExecution`
- los convenios siguen conviviendo con facturas y pagos fijos como hoy
- la navegación desde cada tarjeta sigue apuntando a la misma pantalla destino

## Riesgos concretos de implementación

### Riesgo 1. Cambiar lógica mientras se extrae

Consecuencia:

- se vuelve imposible distinguir si falló la refactorización o cambió la regla

Control:

- mover lógica primero
- rediseñar después

### Riesgo 2. Dejar modelos todavía privados

Consecuencia:

- el engine nuevo termina dependiendo otra vez del widget

Control:

- crear modelos públicos desde el inicio

### Riesgo 3. Meter reservas demasiado pronto

Consecuencia:

- se mezclan `Fase 1` y `Fase 2`

Control:

- `Fase 1` solo desacopla

### Riesgo 4. Tocar la vista de aprendizaje sin necesidad

Consecuencia:

- se abre un frente innecesario

Control:

- dejar `FinanzasPaymentLearningStore` y su vista lo más intactos posible en esta fase

## Sugerencia de pruebas mínimas

### Pruebas unitarias del engine

Casos base:

- pago fijo vencido
- parcialidad de convenio vencida
- factura vencida sin convenio
- factura próxima con proveedor bajo convenio
- saldo general abierto sin convenio
- cuenta sin saldo suficiente

Resultados esperados:

- bucket correcto
- score correcto
- decisión correcta

### Pruebas manuales de smoke

Checklist:

- abrir `Centro de pagos`
- revisar que cargue sin errores
- confirmar que las cuatro columnas sigan presentes
- abrir una factura hacia banco
- abrir un pago fijo desde su tarjeta
- confirmar que los totales superiores se sigan calculando

## Definition of Done de Fase 1

La fase queda bien cerrada cuando:

- `finanzas_payment_center_page.dart` deja de contener la lógica pesada de cálculo
- ya existen `budget_models`, `budget_loader` y `budget_engine`
- la pantalla actual sigue funcionando
- no hubo cambios a otros módulos de Finanzas
- la base quedó lista para arrancar `Reservas protegidas`

## Lo que habilita inmediatamente después

Una vez cerrada esta fase, el siguiente trabajo ya cae mucho más limpio:

- `Fase 2`: persistencia y pantalla de `Reservas protegidas`
- `Fase 3`: nueva home `Presupuesto > Hoy`

Ese es justamente el valor de esta fase:

- no luce tanto por fuera
- pero evita que el resto del proyecto se vuelva frágil
