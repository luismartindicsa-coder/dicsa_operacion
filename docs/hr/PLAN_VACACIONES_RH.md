# Plan de Ataque: Vacaciones RH

Este documento aterriza cómo debe nacer `Vacaciones` dentro de RH a partir del Excel real `VACACIONES DICSA 2026.xlsx`.

No es todavía el contrato final de pantalla.

Es el plan de ataque que vamos a seguir para construir:

- grid editable
- ventana de edición
- cálculo automático
- conexión con `Personal`
- conexión con `Asistencia`
- futura conexión con `Prenómina / Nómina`
- base para generador de recibos

## Regla madre

`Vacaciones` no será una pantalla aislada.

Va a vivir como superficie operativa propia de RH, pero alimentando después:

- `Asistencia`
- `Permisos`
- `Prenómina`
- `Nómina`
- recibos de vacaciones

## Qué trae el Excel real

El archivo fuente contiene estas hojas:

- `RECIBOS`
- `VACACIONES DICSA`
- `POR MESES`
- `CALCULO DE VACACIONES`

## Lectura negocio del Excel

### 1. Hoja `VACACIONES DICSA`

Es el padrón anual base de vacaciones por trabajador.

Trae al menos:

- `No.`
- `Empleado`
- `NSS`
- `RFC`
- `CURP`
- `Fecha de ingreso`
- `Antigüedad en años`
- `Días de vacaciones`
- `Observaciones`

Hallazgos:

- trae `69` empleados útiles
- mezcla fechas de ingreso como serial Excel y como texto en español
- hay `20` casos con `0` días de vacaciones
- no usa observaciones en esta hoja, pero eso no significa que el negocio esté limpio

### 2. Hoja `POR MESES`

Es la distribución operativa del año por mes de vencimiento o disfrute.

Trae al menos:

- `Mes`
- `Fecha de ingreso`
- `No.`
- `Empleado`
- `NSS`
- `RFC`
- `CURP`
- `Antigüedad en años`
- `Días de vacaciones`
- `Observaciones`

Hallazgos:

- trae `70` renglones útiles
- distribuye el año por mes
- hay observaciones reales de negocio:
  - `SIN ALTA`
  - `BAJA ...`
- hay `6` filas sin `ID`
- no es un padrón totalmente limpio

Conclusión:

`POR MESES` no puede usarse como llave única o fuente maestra.

Debe tratarse como calendario operativo/anualización.

### 3. Hoja `RECIBOS`

Es la pista más importante para el futuro cálculo de pago y recibo.

La hoja ya deja ver la estructura del negocio:

- nombre del colaborador
- empresa
- antigüedad
- fecha de ingreso
- días de vacaciones
- fecha o rango del disfrute
- sueldo diario
- semana
- vacaciones
- menos ISR
- más ISR ajustado
- combustible
- extra
- préstamo
- diferencia
- cálculo de vacaciones
- prima vacacional
- pago por transferencia
- pago en efectivo
- pago de nómina por transferencia
- pago de nómina en efectivo

Conclusión:

`Vacaciones` no solo debe registrar días.

Debe quedar preparada para soportar después:

- recibo
- pago
- prima vacacional
- separación entre pago en transferencia y efectivo
- coexistencia con el pago normal de nómina

Regla operativa aterrizada:

- si `CONTPAQ` ya trae un importe positivo en vacaciones, la app debe poder sembrar automáticamente la huella de `vacación pagada`
- eso no significa que el colaborador ya disfrutó los días
- el disfrute real puede ocurrir después y debe registrarse como evento distinto

### 4. Hoja `CALCULO DE VACACIONES`

Es la base legal y aritmética.

Trae explícitamente la tabla:

- `1 año -> 12 días`
- `2 años -> 14 días`
- `3 años -> 16 días`
- `4 años -> 18 días`
- `5 años -> 20 días`
- `6 a 10 años -> 22 días`
- `11 a 15 años -> 24 días`
- `16 a 20 -> 26 días`
- `21 a 25 -> 28 días`
- `26 a 30 -> 30 días`
- `31 a 35 -> 32 días`

También deja visible:

- sueldo actual
- sueldo diario
- pago de vacaciones
- prima vacacional `25%`

## Conclusión funcional

La futura pantalla `Vacaciones` debe resolver dos capas:

1. `Derecho`
2. `Aplicación`

### Capa 1. Derecho

Debe contestar:

- cuántos días le corresponden al trabajador
- por qué
- con qué fecha base se calculó
- qué antigüedad aplicó
- cuántos días ya se pagaron
- cuántos días ya se disfrutaron
- cuántos días quedaron reservados
- cuánto queda disponible operativamente

### Capa 2. Aplicación

Debe contestar:

- qué días se tomaron
- en qué rango
- si ya se pagaron
- cuánto se debe pagar
- si existe prima vacacional
- si parte del pago cae en efectivo o transferencia
- si impacta prenómina o solo deja reserva/pendiente

## Relación con `Personal`

`Vacaciones` debe tomar de `Personal` al menos:

- `employee_id`
- nombre homologado
- empresa
- `fecha_ingreso`
- `fecha_alta`
- `salario`
- `salario percibido`

### Regla importante

No podemos asumir que `fecha_ingreso` y `fecha_alta` son equivalentes.

El sistema debe ser capaz de considerar ambas porque el negocio real ya anticipa que:

- pueden cambiar el cálculo de días
- pueden cambiar el recibo
- pueden cambiar el pago
- pueden producir escenarios mixtos

Ejemplos de negocio que debemos soportar:

- un cálculo por `fecha_ingreso`
- un pago por `fecha_alta`
- dos bases distintas que obliguen a separar recibo o importe
- casos con alta incompleta o sin alta

## Relación con `Asistencia`

`Vacaciones` debe justificar faltas en `Asistencia`.

Eso implica que, cuando exista una vacación aprobada/aplicada:

- los días del rango deben poder reflejarse como ausencia justificada
- no deben quedarse como falta probable
- deben alimentar el cierre semanal editable

No se debe duplicar captura si ya existe un rango formal de vacaciones.

## Relación con `Importación y conciliación`

`Vacaciones` no nace de NGTeco.

Pero sí debe usar `Importación y conciliación` para:

- conocer el periodo activo
- entender la semana en revisión
- sincronizar vacaciones contra cierres semanales
- marcar ausencias que ya tienen respaldo administrativo

## Relación futura con `Prenómina / Nómina`

`Vacaciones` debe quedar lista para alimentar después:

- días pagables de vacaciones
- prima vacacional
- importe base por salario
- importe alterno por salario percibido
- ajuste o separación por esquema de pago
- integración al recibo de vacaciones

### Regla importante

Desde hoy debemos modelar la posibilidad de:

- dos bases salariales
- dos cálculos
- dos importes
- dos recibos o dos componentes del mismo recibo

No porque siempre ocurra, sino porque el usuario ya aclaró que sí existe ese escenario.

## Qué NO va a ser la primera versión

La primera versión no debe intentar resolver de inmediato:

- timbrado
- nómina final
- ISR completo
- dispersión bancaria
- generación final de recibos PDF

Pero sí debe dejar listas las columnas, tablas y cálculos para llegar ahí sin rearmar el módulo.

## Propuesta de pantalla

La pantalla `Vacaciones` debe nacer sobre el mismo contrato que `Asistencia`.

Eso significa:

- grid editable
- ventana editable
- contrato RH 1:1
- ficha izquierda fija
- panel derecho operativo
- navegación por teclado
- `Esc`
- `Enter`
- navegación entre registros con `←` y `→`
- click fuera para cerrar

## Grid propuesto

El grid base recomendado es:

- `ID`
- `Nombre`
- `Fecha ingreso`
- `Fecha alta`
- `Antigüedad base`
- `Días que corresponden`
- `Días capturados`
- `Días disponibles`
- `Estado`
- `Acciones`

### Notas

`Estado` deberá distinguir al menos:

- pendiente
- calculado
- capturado
- aplicado a asistencia
- listo para prenómina

## Ventana de edición propuesta

La ventana debe dividirse como `Asistencia`:

### Izquierda fija

- nombre
- ID
- empresa
- fecha ingreso
- fecha alta
- salario
- salario percibido
- base seleccionada para cálculo
- antigüedad calculada
- días que corresponden
- días disponibles
- estado

### Derecha scrollable

Bloques sugeridos:

1. `Resumen`
- días que corresponden
- días aplicados
- días disponibles
- importe vacaciones
- prima vacacional

2. `Reglas de cálculo`
- base por fecha de ingreso
- base por fecha de alta
- selector de criterio o modo de cálculo
- explicación del resultado

3. `Eventos / periodos de vacaciones`
- rango inicio-fin
- días
- tipo
- observación
- si impacta asistencia
- si impacta prenómina
- si genera recibo

4. `Componentes de pago`
- cálculo con salario
- cálculo con salario percibido
- diferencia
- criterio final RH

## Modelo de datos recomendado

No debe meterse todo a una sola tabla.

Se recomienda separar:

### 1. Cabecera anual o saldo

- `hr_employee_vacation_balances`

Campos mínimos:

- `employee_id`
- `exercise_year`
- `base_date_policy`
- `base_fecha_ingreso`
- `base_fecha_alta`
- `antiguedad_years`
- `days_entitled`
- `days_paid`
- `days_enjoyed`
- `days_reserved`
- `days_taken`
- `days_available`
- `salary_snapshot`
- `salary_perceived_snapshot`
- `status`
- `notes`

### 2. Eventos o movimientos

- `hr_employee_vacation_events`

Campos mínimos:

- `id`
- `employee_id`
- `exercise_year`
- `start_date`
- `end_date`
- `days_applied`
- `impact_attendance`
- `impact_prenomina`
- `generate_receipt`
- `status`
- `notes`

### 3. Componentes de cálculo

- `hr_employee_vacation_calculations`

Campos mínimos:

- `vacation_event_id`
- `calculation_mode`
- `base_salary`
- `base_salary_perceived`
- `daily_salary_used`
- `vacation_pay`
- `vacation_bonus`
- `effective_component`
- `transfer_component`
- `cash_component`
- `difference_component`

## Política de cálculo recomendada

La política debe ser explícita y auditable.

No escondida en frontend.

### Reglas mínimas

1. calcular antigüedad desde una fecha base elegida
2. resolver días que corresponden usando la tabla legal
3. permitir override manual RH con justificación
4. congelar snapshot salarial al momento del cálculo
5. permitir más de un cálculo por evento si el caso lo requiere
6. separar pago, disfrute y reserva del saldo vacacional
7. descontar disponibilidad solo por días disfrutados o reservados

## Excepciones que el sistema debe soportar desde el inicio

A partir del Excel real ya sabemos que existen:

- fechas mezcladas entre serial y texto
- colaboradores sin `ID`
- casos `SIN ALTA`
- casos de `BAJA`
- antigüedad `0`
- días de vacaciones `0`
- posibles diferencias entre fecha de ingreso y fecha de alta
- posibles diferencias entre salario y salario percibido

Esto no es ruido.

Es parte del negocio.

## Plan por fases

### Fase 0. Congelar reglas

- analizar Excel real
- fijar tabla de días por antigüedad
- decidir política entre fecha de ingreso y fecha de alta
- decidir qué salidas deben alimentar a asistencia y prenómina

### Fase 1. Contrato de pantalla

- crear `CONTRATO_VACACIONES_RH.md`
- copiar 1:1 el arquetipo de `Asistencia`
- definir grid exacto
- definir diálogo exacto

### Fase 2. Modelo de datos

- crear tablas Supabase de saldos, eventos y cálculos
- snapshot de salario y salario percibido
- soporte de estado y trazabilidad

### Fase 3. Motor de cálculo

- antigüedad
- tabla de días
- base date policy
- días disponibles
- importe vacaciones
- prima vacacional
- componentes de pago

### Fase 4. Pantalla operativa

- grid editable
- diálogo editable
- cálculo automático con override RH
- navegación homologada a `Asistencia`

### Fase 5. Integración con asistencia

- aplicar rango vacacional a días semanales
- justificar ausencias
- evitar doble captura

### Fase 6. Integración con prenómina

- exponer componentes pagables
- exponer prima vacacional
- exponer separación transferencia/efectivo si aplica

### Fase 7. Recibos

- usar la hoja `RECIBOS` como referencia real
- construir después el generador de recibos
- no bloquear la operación actual esperando esa fase

## Recomendación de ejecución inmediata

El siguiente paso correcto no es empezar a codear a ciegas.

El siguiente paso correcto es:

1. congelar el contrato de pantalla `Vacaciones`
2. congelar la política de cálculo `fecha_ingreso vs fecha_alta`
3. crear el modelo Supabase
4. luego sí construir el grid + ventana

## Decisión práctica para seguir

Mi recomendación es seguir exactamente así:

1. `Contrato Vacaciones RH`
2. `Migraciones Supabase`
3. `Pantalla Vacaciones`
4. `Integración con Asistencia`

Ese orden nos evita parches y nos deja listo el terreno para `Permisos` y después `Prenómina`.
