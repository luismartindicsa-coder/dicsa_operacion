# Blueprint: Seguimiento Semanal de Pacas Gerencia

Este documento aterriza la primera pantalla operativa-ejecutiva de `Gerencia` para dar seguimiento semanal a:

- producción de pacas
- embarque de pacas
- cumplimiento contra plan
- proyección de cierre de semana

La intención es que `Gerencia` capture el plan una vez por semana y que el cumplimiento real se alimente automáticamente desde `Operación`.

## Propósito

La pantalla debe responder rápido:

- qué se esperaba producir esta semana
- qué se esperaba embarcar esta semana
- cuánto ya se produjo
- cuánto ya se embarcó
- si vamos arriba o abajo del plan
- qué faltante queda por tipo de paca
- si al ritmo actual llegamos al cierre semanal

No debe duplicar captura operativa.

El plan lo captura `Gerencia`.

La ejecución real viene de:

- `Producción`
- `Entradas y Salidas -> Salidas`

## Usuarios

Usuarios principales:

- `gerencia@dicsamx.com`
- `direccion@dicsamx.com`

Usuarios lectores potenciales a futuro:

- responsables de operación
- responsables comerciales

## Frecuencia de uso

Flujo principal:

1. El lunes el gerente captura el plan semanal.
2. Durante la semana la pantalla se consulta varias veces al día.
3. El cierre semanal compara `plan vs real vs estimación`.

## Fuentes reales de datos

### 1. Plan semanal manual

Fuente nueva a crear.

Se captura dentro de `Gerencia`.

### 2. Producción real

Fuente actual:

- tabla `production_runs`

Campos ya visibles en la app:

- `op_date`
- `shift`
- `bale_material`
- `bale_count`
- `avg_bale_weight_kg`
- `source_bulk`

Referencia actual:

- [inventory_movements_grid.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/inventory_movements_grid.dart)

### 3. Embarque real

Fuente actual:

- salidas de pacas capturadas en `Entradas y Salidas -> Salidas`
- tabla base operativa: `inventory_movements_v2`

La consulta final debe filtrar solo movimientos de salida que correspondan a materiales comerciales tipo paca y sumar:

- fecha
- tipo de paca
- pacas embarcadas
- kg embarcados cuando existan

Referencia actual:

- [inventory_page.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/inventory_page.dart)
- [inventory_movements_grid.dart](/Users/martinvelzat/DICSA/apps/dicsa_operacion/lib/app/services/inventory_movements_grid.dart)

## Regla base del módulo

`Gerencia` no captura producción real ni embarque real.

`Gerencia` solo captura:

- meta semanal de producción
- meta semanal de embarque
- opcionalmente notas o comentario ejecutivo

Todo lo demás se deriva de datos ya existentes.

## Catálogo inicial de tipos de paca

Fase 1 debe trabajar con estos tres renglones ejecutivos:

- `Limpio`
- `Revuelto`
- `Americano`

No deben quedar hardcodeados como copy de UI suelto.

Deben vivir en un mapeo formal entre datos operativos y vista ejecutiva.

## Mapeo de datos operativos a tipos ejecutivos

Debe existir una capa explícita de homologación.

Ejemplo inicial esperado:

- `PACA_LIMPIA` -> `Limpio`
- `PACA_BASURA` o equivalente operativo -> `Revuelto`
- `PACA_AMERICANA` -> `Americano`

Si la operación usa más variantes, se normalizan en un solo sitio.

No se vale esconder esta equivalencia dispersa en widgets.

## Estructura de pantalla

Nombre recomendado:

- `Seguimiento Semanal de Pacas`

Ubicación recomendada:

- `Gerencia -> Seguimiento Semanal de Pacas`

Tabs recomendadas:

- `Semana actual`
- `Histórico`

## Layout recomendado

### 1. Header ejecutivo

Debe mostrar:

- semana activa
- rango de fechas
- estatus de la semana
- botón `Editar plan`
- botón `Duplicar semana anterior`
- botón `Cerrar semana`

Estados:

- `Sin plan`
- `Planeada`
- `En curso`
- `Cerrada`

### 2. KPI row superior

Seis cards ejecutivas:

- `Meta producción`
- `Producción real`
- `% avance producción`
- `Meta embarque`
- `Embarque real`
- `% avance embarque`

Reglas:

- cards homogéneas
- lectura numérica dominante
- subtítulo corto con faltante o exceso
- color semántico suave, no saturado

### 3. Bloque central: matriz semanal

La pantalla principal debe tener dos bloques grandes:

#### A. Producción semanal

Tabla por tipo:

- `Tipo`
- `Meta`
- `Producción`
- `%`
- `Estimación`
- `% est`
- `Necesidad`

#### B. Embarque semanal

Tabla por tipo:

- `Tipo`
- `Meta`
- `Embarque`
- `%`
- `Estimación`
- `% est`
- `Necesidad`

Esta estructura replica la lógica del Excel mostrado por usuario, pero ya conectada a la app.

### 4. Desglose diario

Debajo de la matriz debe existir una banda diaria de la semana:

- `Lunes`
- `Martes`
- `Miércoles`
- `Jueves`
- `Viernes`
- `Sábado`

Cada día debe mostrar por tipo:

- producción real del día
- embarque real del día
- acumulado de semana
- brecha contra el plan acumulado

### 5. Alertas y seguimiento

Bloque lateral o inferior con insights:

- tipo de paca con mayor atraso
- tipo de paca arriba del plan
- riesgo de no llegar a meta
- producción suficiente pero embarque retrasado
- embarque mayor que producción semanal y dependiente de patio

## Fórmulas ejecutivas

### Porcentaje de avance

`% avance = real / meta`

Si `meta = 0`, el porcentaje debe mostrarse como `—`.

### Estimación de cierre

Fase 1:

- `estimación = promedio diario actual x días operativos de la semana`

Donde:

- promedio diario actual = `real acumulado / días transcurridos con corte`

Semana operativa inicial sugerida:

- `lunes a sábado`

### Porcentaje estimado

`% est = estimación / meta`

### Necesidad

`necesidad = max(meta - real, 0)`

### Brecha acumulada contra plan

Debe calcularse también:

- `real acumulado - plan acumulado esperado al día`

Esto permite ver no solo el total final sino el ritmo.

## Modelo de captura del plan

## Tabla recomendada: encabezado semanal

Nombre sugerido:

- `gerencia_bale_weekly_plans`

Campos sugeridos:

- `id`
- `week_start_date`
- `week_end_date`
- `status`
- `notes`
- `created_by`
- `created_at`
- `updated_at`
- `closed_at`

Reglas:

- una sola semana abierta por rango
- `week_start_date` debe ser lunes
- `week_end_date` debe ser sábado o domingo según contrato final

## Tabla recomendada: detalle por tipo

Nombre sugerido:

- `gerencia_bale_weekly_plan_lines`

Campos sugeridos:

- `id`
- `plan_id`
- `bale_type_key`
- `sort_order`
- `production_target_bales`
- `shipment_target_bales`
- `notes`
- `created_at`
- `updated_at`

Restricción sugerida:

- único por `plan_id + bale_type_key`

## Opción fase 2: detalle diario planeado

Solo si después se necesita control más fino.

Nombre sugerido:

- `gerencia_bale_weekly_plan_day_lines`

Campos sugeridos:

- `id`
- `plan_line_id`
- `op_date`
- `production_target_bales`
- `shipment_target_bales`

Esto no debe ser fase 1 obligatoria.

## Consultas derivadas recomendadas

## 1. Producción real semanal por tipo

Fuente:

- `production_runs`

Agrupación:

- semana
- fecha
- tipo ejecutivo homologado

Agregado principal:

- suma de `bale_count`

## 2. Embarque real semanal por tipo

Fuente:

- `inventory_movements_v2`

Filtros esperados:

- movimientos de `salida`
- materiales comerciales tipo paca
- fecha dentro de la semana

Agregado principal:

- suma de unidades o pacas

## 3. Vista ejecutiva consolidada

Se recomienda crear una capa de consulta o repositorio que combine:

- plan manual semanal
- producción real semanal
- embarque real semanal
- detalle por día

Nombre sugerido a nivel app:

- `GerenciaBaleWeeklyTrackingStore`

Nombre sugerido para bundle principal:

- `GerenciaBaleWeeklyTrackingBundle`

## Interacciones de la pantalla

### 1. Crear plan

Si la semana activa no tiene plan:

- mostrar estado vacío ejecutivo
- CTA principal: `Crear plan semanal`

### 2. Editar plan

Debe abrir superficie compacta con renglones:

- `Limpio`
- `Revuelto`
- `Americano`

Columnas editables:

- meta producción
- meta embarque
- nota opcional

No debe sentirse como grid operativa pesada.

Debe sentirse como captura ejecutiva.

### 3. Duplicar semana previa

Acción importante para no recapturar desde cero.

Debe copiar:

- líneas
- metas
- orden

No debe copiar:

- estatus de cierre
- notas de cierre

### 4. Cerrar semana

Congela plan y permite histórico.

Después de cerrar:

- no editar accidentalmente
- permitir `Reabrir` solo si el usuario lo autoriza y el rol lo permite

## Estados vacíos y errores

### Sin plan

Mensaje:

- `Aún no existe plan semanal para esta semana.`

Acción:

- `Crear plan`
- `Duplicar semana anterior`

### Sin datos reales

Mensaje:

- `Todavía no hay producción o embarques registrados para esta semana.`

Esto no es error si la semana apenas inicia.

### Mapeo incompleto

Si aparece un tipo de paca operativo sin homologar:

- mostrar alerta de configuración
- no perder el dato
- registrar `sin mapear`

## Semántica visual recomendada

Paleta:

- usar tokens rojos de `Gerencia`

La pantalla debe verse ejecutiva, no alarmista.

Reglas:

- fondo oscuro vino
- cards oscuras
- acentos rojo/coral para foco
- verde solo para cumplimiento claramente favorable
- ámbar para riesgo
- rojo para desviación fuerte

No usar rojo de error en toda la pantalla.

## Componentes visuales recomendados

- cards KPI
- tabla ejecutiva ancha con barras sutiles de progreso
- chips de estatus:
  - `48% real`
  - `91% estimado`
  - `faltan 37`
- mini barras por día
- panel de alertas ejecutivas

## Navegación recomendada

Dentro de `Gerencia`, la navegación inicial puede quedar:

- `Dashboard Gerencia`
- `Seguimiento Semanal de Pacas`

En fase 1 esta página puede ser el primer módulo real del área.

## MVP recomendado

### Fase 1

Entregable mínimo útil:

- pantalla semanal actual
- captura de plan manual
- lectura automática de producción real
- lectura automática de embarque real
- matriz por tipo
- cálculo de `%`, `estimación`, `necesidad`
- desglose diario
- historial básico por semana

### Fase 2

- metas por día
- alertas automáticas más finas
- comparativo de 4 a 8 semanas
- comentario ejecutivo de cierre
- exportación

### Fase 3

- sugerencia automática de metas usando histórico
- proyección por ritmo de turno
- cruce con inventario en patio
- explicación automática de desvíos

## Preguntas que la pantalla debe responder al gerente

- `¿Vamos bien o vamos cortos esta semana?`
- `¿Cuál tipo de paca está atrasado?`
- `¿Dónde estamos fallando: producción o embarque?`
- `¿Lo real ya rebasa lo planeado?`
- `¿Qué hace falta para cerrar la semana?`
- `¿Qué patrón traen las últimas semanas?`

## Riesgos de implementación

### 1. Homologación de tipos

Es el riesgo principal.

Si producción y salidas usan nombres distintos, el tablero puede mentir.

Debe resolverse primero.

### 2. Conteo de embarques

Hay que validar exactamente qué columna en salidas representa la cantidad oficial de pacas embarcadas:

- unidades
- pacas
- output_unit_count
- campo equivalente según flujo

### 3. Semana operativa

Hay que congelar si la semana de seguimiento es:

- `lunes a sábado`
- `lunes a domingo`

Para esta pantalla se recomienda iniciar con:

- `lunes a sábado`

Porque el usuario dijo explícitamente que el plan se captura los lunes.

### 4. Reglas de estimación

La estimación simple por ritmo diario es suficiente para fase 1.

No conviene meter modelos más complejos al arranque.

## Blueprint técnico sugerido en app

Archivos sugeridos:

- `lib/app/gerencia/gerencia_bale_weekly_tracking_page.dart`
- `lib/app/gerencia/gerencia_bale_weekly_tracking_store.dart`
- `lib/app/gerencia/gerencia_bale_weekly_tracking_models.dart`

Extensiones posibles después:

- side panel de `Gerencia` con entrada a esta página
- card resumen dentro de `Dashboard Gerencia`

## Orden recomendado de implementación

1. Congelar catálogo ejecutivo de tipos de paca y su mapeo operativo.
2. Confirmar consulta de embarques reales desde salidas.
3. Crear tablas de plan semanal manual.
4. Construir store consolidado.
5. Construir pantalla `Semana actual`.
6. Agregar histórico.
7. Agregar alertas.

## Criterio de éxito

La pantalla se considera bien resuelta si el gerente puede:

- capturar el plan del lunes en menos de 2 minutos
- abrir el tablero entre semana y entender en menos de 15 segundos el estado real
- detectar rápido si el problema está en `producción`, `embarque` o `mezcla de tipos`
- comparar fácilmente `meta`, `real`, `estimación` y `necesidad`

## Decisión recomendada

Sí conviene construir esta pantalla como el primer módulo formal de `Gerencia`.

Es una superficie con alto valor porque:

- reutiliza datos ya existentes
- evita captura duplicada
- traduce operación a lectura ejecutiva
- abre la puerta a más seguimiento semanal por metas
