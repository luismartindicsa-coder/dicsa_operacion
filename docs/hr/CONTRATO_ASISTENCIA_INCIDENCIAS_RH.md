# Contrato: Asistencia e Incidencias RH

Este documento congela el contrato funcional inicial de `Asistencia e incidencias` para RH dentro de la app DICSA.

No define todavía el cálculo final de nómina.

Define la capa previa que convierte:

- fichajes
- incidencias
- permisos
- vacaciones
- horas extra
- correcciones manuales

en una fuente auditable para `Prenómina / Nómina`.

## Regla madre

`Asistencia e incidencias` no es la nómina.

Es la capa de consolidación y validación previa.

Su responsabilidad es:

- recibir fuentes parciales
- normalizarlas por colaborador y periodo
- permitir correcciones controladas
- dejar trazabilidad
- entregar resultado semanal listo para prenómina

## Fuentes oficiales

Esta pantalla trabaja con tres tipos de fuente:

1. `Personal RH`
2. `NGTeco`
3. `CONTPAQ`

### 1. Personal RH

Es el padrón maestro.

Debe ser la fuente oficial para:

- `employee_id`
- nombre homologado
- empresa / adscripción
- horario base
- fecha de ingreso
- fecha de alta
- salario
- salario real percibido

### 2. NGTeco

Es fuente parcial de asistencia.

No representa necesariamente a todo el personal.

Razones:

- hay plantas o frentes que no fichan en ese reloj
- hay personal de otras sedes
- puede haber días sin registro o con registros incompletos

NGTeco aporta:

- `employee_id`
- nombre fuente NGTeco
- fecha de fichaje
- hora de fichaje
- tipo de verificación
- fuente / dispositivo

### 3. CONTPAQ

Es fuente parcial de nómina del periodo.

No representa necesariamente a todo el padrón maestro.

Razones:

- puede haber personal aún no dado de alta al 100%
- puede haber transiciones administrativas
- puede haber movimientos de semana que aún no se reflejan

CONTPAQ aporta:

- `employee_id` / `Código`
- nombre fuente CONTPAQ
- sueldo
- percepciones
- deducciones
- neto
- obligaciones
- conceptos nominales ya corridos

## Regla de identidad

La llave de cruce oficial es:

- `employee_id`

El nombre no debe ser la llave primaria del cruce.

### Regla de nombre homologado

El `display_name` de RH debe normalizarse al estilo de `CONTPAQ`.

Además deben conservarse nombres fuente:

- `source_name_ngteco`
- `source_name_contpaq`

Objetivo:

- no perder trazabilidad del archivo importado
- permitir auditoría de identidad
- evitar depender de texto libre del usuario

## Regla crítica de cobertura parcial

La ausencia en una fuente no equivale automáticamente a error.

Casos válidos:

- existe en `Personal` pero no en `NGTeco`
- existe en `Personal` pero no en `CONTPAQ`
- existe en `Personal` y en `NGTeco` pero no en `CONTPAQ`
- existe en `Personal` y en `CONTPAQ` pero no en `NGTeco`

Por eso la pantalla debe mostrar estado de cobertura por periodo:

- `presente_en_ngteco`
- `presente_en_contpaq`
- `requiere_captura_manual`

## Resultado que debe producir el módulo

Por cada colaborador y por cada periodo semanal, RH debe poder consolidar:

- horario esperado
- entradas registradas
- retardos en minutos
- faltas
- horas ausentes
- horas extra
- permisos
- vacaciones
- incapacidades
- correcciones manuales
- observaciones

## Contrato de cálculo previo

La pantalla no debe calcular nómina completa todavía.

Pero sí debe producir métricas fuente que luego alimenten prenómina:

- minutos de retardo
- horas trabajadas
- faltas justificadas
- faltas injustificadas
- tiempo extra
- días con permiso
- días de vacaciones
- incidencias manuales

## Regla para retardos

El objetivo es eliminar la talacha manual actual.

La app debe calcular de forma reproducible:

- minutos tarde
- proporción del tiempo respecto al tramo horario esperado
- equivalencia de descuento potencial

Ejemplo conceptual:

- si el turno esperado es de `08:00` a `18:00`
- y existe comida de `13:00` a `14:00`
- la jornada efectiva no se toma como 10 horas corridas
- se toma como tiempo laborable efectivo

Por lo tanto el cálculo futuro debe considerar:

- jornada efectiva
- tramo de comida opcional
- tolerancias parametrizables

## Regla de staging

Ninguna importación pega directo a prenómina.

Siempre debe existir:

1. importación
2. staging
3. validación
4. corrección manual
5. aprobación
6. publicación a prenómina

## Flujo funcional de pantalla

La pantalla debe vivir como `Operación Híbrida por Tabs`.

### Tabs obligatorios

1. `Resumen`
2. `Importaciones`
3. `Asistencia`
4. `Retardos`
5. `Faltas y ausencias`
6. `Permisos y vacaciones`
7. `Correcciones`

### 1. Resumen

Debe responder rápido:

- cuántos empleados quedaron cruzados por `ID`
- cuántos vinieron en NGTeco
- cuántos vinieron en CONTPAQ
- cuántos requieren captura manual
- cuántos tienen incidencias pendientes de revisar

### 2. Importaciones

Debe soportar:

- subir archivo NGTeco
- subir archivo CONTPAQ
- ver lote importado
- ver filas válidas
- ver filas rechazadas
- ver motivos de rechazo

### 3. Asistencia

Vista principal semanal por colaborador.

Debe mostrar al menos:

- `ID`
- nombre homologado
- adscripción
- horario esperado
- presencia en NGTeco
- presencia en CONTPAQ
- primer fichaje
- último fichaje
- horas esperadas
- horas detectadas
- estado de revisión

### 4. Retardos

Vista especializada para:

- minutos tarde
- tolerancia aplicada
- descuento potencial
- justificación
- aprobación RH

### 5. Faltas y ausencias

Debe capturar y revisar:

- falta justificada
- falta injustificada
- ausencia parcial
- ausencia con obligación empresarial o sin ella

### 6. Permisos y vacaciones

Debe capturar:

- permisos con goce
- permisos sin goce
- vacaciones
- incapacidades

### 7. Correcciones

Es obligatoria porque ya sabemos que hay cobertura parcial real.

Debe permitir:

- captura manual de horas
- corrección de retardos
- ajuste de faltas
- alta de incidencia sin fichaje
- justificación obligatoria
- evidencia opcional u obligatoria según tipo

## Regla de captura manual

La captura manual no es excepción técnica.

Es parte del negocio real.

Debe existir explícitamente para:

- personal fuera de DICSA Celaya
- personal sin reloj en la planta
- correcciones de fichaje
- incidencias no cubiertas por NGTeco
- personal aún no reflejado en CONTPAQ

Toda captura manual debe dejar:

- usuario
- timestamp
- motivo
- valor anterior si existía
- valor nuevo

## Entidades sugeridas

### Identidad / homologación

- `hr_employee_identity_aliases`

Campos mínimos:

- `employee_id`
- `canonical_name`
- `source_system`
- `source_name`
- `active`

### Lotes de importación

- `hr_attendance_import_batches`

Campos mínimos:

- `id`
- `source_type` (`ngteco`, `contpaq`)
- `period_start`
- `period_end`
- `uploaded_by`
- `uploaded_at`
- `rows_received`
- `rows_valid`
- `rows_rejected`
- `status`

### Filas crudas importadas

- `hr_attendance_import_rows`

Campos mínimos:

- `batch_id`
- `source_type`
- `employee_id_raw`
- `employee_name_raw`
- `event_date`
- `event_time`
- `payload_json`
- `validation_status`
- `validation_notes`

### Consolidado semanal

- `hr_attendance_period_rows`

Campos mínimos:

- `period_start`
- `period_end`
- `employee_id`
- `employee_name_snapshot`
- `worksite_snapshot`
- `schedule_snapshot`
- `present_in_ngteco`
- `present_in_contpaq`
- `requires_manual_capture`
- `review_status`

### Incidencias consolidadas

- `hr_attendance_incidents`

Campos mínimos:

- `period_row_id`
- `incident_type`
- `minutes_late`
- `hours_absent`
- `hours_extra`
- `days_value`
- `justification`
- `source_origin`
- `approved_by`
- `approved_at`

### Correcciones manuales

- `hr_attendance_manual_adjustments`

Campos mínimos:

- `period_row_id`
- `adjustment_type`
- `old_value_json`
- `new_value_json`
- `reason`
- `created_by`
- `created_at`

## Reglas de UI

Esta pantalla debe heredar contrato RH, pero funcionalmente acercarse a una superficie operativa seria.

Debe conservar:

- paleta RH
- fondo RH
- cards RH
- overlays RH

Debe parecer:

- operación auditada
- revisión semanal
- staging con validación

No debe parecer:

- dashboard decorativo
- formulario aislado
- pantalla blanca con tabla improvisada

## Regla de publicación hacia Prenómina

La salida de esta pantalla no debe ser pago.

La salida debe ser un consolidado semanal aprobado.

Entidad conceptual:

- `hr_attendance_period_rows` aprobados

Ese consolidado es el input de:

- `Prenómina / Nómina`

## Qué debe responder esta pantalla antes de pasar a Prenómina

1. `Quién sí vino en NGTeco`
2. `Quién sí apareció en CONTPAQ`
3. `Quién requiere captura manual`
4. `Quién tiene retardos y cuántos minutos`
5. `Quién tiene faltas`
6. `Qué incidencias siguen pendientes`
7. `Qué quedó aprobado para publicarse a prenómina`

## Decisiones congeladas al 2026-06-30

- `employee_id` es la llave principal del cruce
- `Personal RH` es el padrón maestro
- `NGTeco` es fuente parcial de asistencia
- `CONTPAQ` es fuente parcial de nómina del periodo
- nombre homologado RH debe alinearse al formato de `CONTPAQ`
- la captura manual es obligatoria como capacidad del sistema
- la publicación a prenómina debe salir desde staging aprobado, no desde importación cruda
