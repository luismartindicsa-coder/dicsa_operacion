# Plan de Reportes: Area Operaciones

Fecha de diseno: 2026-08-13

## Contexto

Este plan aterriza el arranque de `Operaciones` dentro del esquema de supervision por reportes.

La regla acordada es:

- no disenar todos los reportes al mismo tiempo
- construir uno por uno
- validar que cada reporte si responda lo que Gerencia necesita en junta
- no inflar el PDF con datos que no ayudan a decidir

## Fecha de referencia

La fecha actual del sistema es:

- `Thursday, August 13, 2026`

Por lo tanto:

- el primer corte diario de arranque corresponde a `Thursday, August 13, 2026`
- el primer corte semanal de arranque para junta corresponde a `Friday, August 14, 2026`
- ese primer corte semanal debe cubrir `Monday, August 10, 2026` a `Friday, August 14, 2026`

## Objetivo real del area

El area `Operaciones` no debe reportar por costumbre.

Debe responder con claridad:

1. Que trabajo nuevo aparecio.
2. Que trabajo sigue abierto o atorado.
3. Que costo genero.
4. Que produccion real salio.
5. Que incidente o desorden de patio amerita decision.

## Fuentes reales hoy disponibles

## 1. OTs

Fuente base:

- tabla `public.maintenance_orders`

Campos confirmados hoy:

- `id`
- `ot_folio`
- `status`
- `priority`
- `type`
- `category`
- `impact`
- `requested_at`
- `area_label`
- `equipment_label`
- `requester_name`
- `assigned_to_name`
- `cost_estimated_total`
- `cost_actual_total`

Flujo real de estatus homologado:

- `aviso_falla`
- `cotizacion`
- `autorizacion_finanzas`
- `supervision`
- `cerrado`
- `rechazado`

Conclusion:

- `OTs diarias nuevas` si tiene fuente madura
- `Seguimiento de OTs` si tiene fuente madura
- `Gastos en OTs` tiene base parcial y depende de compras OT para quedar fuerte

## 2. Produccion

Fuente base:

- tabla `public.production_runs`

Campos confirmados en lectura actual:

- `op_date`
- `shift`
- `bale_material`
- `bale_count`
- `notes`

Conclusion:

- `Analisis de produccion` si tiene fuente madura

## 3. Patio e incidencias

Hoy no se detecta un modulo formal y homologado para:

- incidencias de patio
- KPIs de limpieza

Conclusion:

- estos dos reportes no deben maquillarse como listos
- necesitan captura formal o una fuente operativa homologada antes de prometer PDF real

## Inventario de reportes de Operaciones

## 1. OTs diarias nuevas

Frecuencia:

- `Diario`

Madurez:

- `Lista para construir primero`

Fuente:

- `maintenance_orders`

Motivo:

- es el reporte mas claro para arrancar disciplina diaria
- responde rapido que aparecio hoy
- obliga a Operaciones a explicar urgencias, prioridades y prevencion

## 2. Seguimiento de OTs

Frecuencia:

- `Viernes`

Madurez:

- `Lista para construir segundo`

Fuente:

- `maintenance_orders`

Motivo:

- sirve para junta semanal
- obliga a explicar abiertas, atrasadas, rechazadas y cerradas

## 3. Analisis de produccion

Frecuencia:

- `Viernes`

Madurez:

- `Lista para construir tercero`

Fuente:

- `production_runs`

Motivo:

- ya existe la fuente real
- puede cruzarse despues con patio y embarques

## 4. Gastos en OTs

Frecuencia:

- `Viernes`

Madurez:

- `Parcial`

Fuente:

- `maintenance_orders`
- `maintenance_purchase_orders`
- flujo de compras OT

Motivo:

- si se hace demasiado pronto, el reporte saldra incompleto o enganoso

## 5. Incidencias en patio

Frecuencia:

- `Viernes`

Madurez:

- `Pendiente de fuente`

Motivo:

- hoy no hay una captura formal clara para hacerlo confiable

## 6. KPIs de limpieza

Frecuencia:

- `Diario`

Madurez:

- `Pendiente de fuente`

Motivo:

- hoy no existe una fuente homologada suficientemente clara

## Orden recomendado de implementacion

1. `OTs diarias nuevas`
2. `Seguimiento de OTs`
3. `Analisis de produccion`
4. `Gastos en OTs`
5. `Incidencias en patio`
6. `KPIs de limpieza`

## Razon de este orden

- empieza por lo que ya existe
- construye primero habitos diarios
- luego consolida la junta semanal
- deja para despues los reportes que aun no tienen fuente firme

## Regla de calidad para Operaciones

Ningun reporte de Operaciones debe responder solo:

- cuantos
- cuanto costo
- cuanto se produjo

Cada reporte debe cerrar tambien con:

- que se desvio
- que no debio pasar
- que decision se necesita
- quien queda responsable

## Primer reporte recomendado

El primer reporte a construir dentro de `Operaciones` debe ser:

- `OTs diarias nuevas`

## Por que ese primero

- usa una sola fuente madura
- tiene valor inmediato en la operacion del dia
- ayuda a separar urgencia real de mala planeacion
- permite que el encargado de Operaciones llegue a junta diaria con claridad

## Lo que debe responder ese primer reporte

1. Cuantas OTs nuevas nacieron hoy.
2. Cuantas son de prioridad alta.
3. Cuantas pegan a paro total o parcial.
4. Que areas concentraron mas OTs nuevas.
5. Cuantas siguen sin responsable claro o sin avance.
6. Cuales nacieron hoy pero realmente revelan falla repetitiva.

## Lo que NO debe hacer ese primer reporte

- no mezclar historico viejo si el corte es diario
- no meter costo real si todavia no existe
- no aparentar que ya mide limpieza o incidencias de patio
- no llenarse de tabla enorme sin resumen gerencial

## Siguiente documento

El contrato funcional detallado del primer reporte queda en:

- `docs/operacion/CONTRATO_REPORTE_OPERACIONES_OTS_DIARIAS_NUEVAS_2026-08-13.md`
