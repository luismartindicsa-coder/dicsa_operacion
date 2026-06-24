# Mapeo: Excel `Semana 26` a App RH

Este documento traduce el archivo `Semana 26.xlsx` a decisiones de producto, modelo de datos y pantallas dentro de la app.

Su objetivo no es copiar Excel dentro de la app.

Su objetivo es separar:

- captura fuente
- reglas de negocio
- calculo de nomina
- salidas de pago
- vistas de control para RH
- vistas ejecutivas para Direccion

## Aclaracion operativa importante

En este workbook, referencias como:

- `WHIRLPOOL`
- `MONROE`
- `KS`

no significan que el trabajador pertenezca a otra empresa pagadora.

Significan que el colaborador de DICSA se encuentra laborando `in situ` dentro de esa planta.

La columna `Empresa` en `SEM 26` debe leerse como:

- adscripcion operativa
- planta o frente donde trabaja el colaborador
- ubicacion funcional del servicio

Cuando esa columna viene vacia, debe interpretarse como base DICSA, por ejemplo:

- `DICSA CELAYA`
- `DICSA APASEO`

segun el contexto operativo real.

Regla de modelado:

- esto no debe modelarse como cliente de nomina independiente
- tampoco como empresa legal distinta por default
- debe modelarse primero como `centro de trabajo`, `frente operativo` o `adscripcion`

## Conclusion ejecutiva

El Excel **si es adaptable** a la app.

Pero **no conviene replicarlo 1:1**.

La razon:

- mezcla datos maestros, incidencias, reglas, calculo, salidas de pago, estadistica y formatos de impresion
- depende fuertemente de formulas entre hojas
- tiene referencias externas
- tiene referencias rotas en salidas
- varias hojas son reportes derivados, no captura fuente

La adaptacion correcta es por capas.

## Diagnostico rapido del archivo

El archivo contiene estas capas funcionales:

1. maestro de empleados
2. catalogo de reglas o prestaciones
3. prestamos y descuentos
4. incidencias de asistencia
5. corrida semanal de nomina
6. dispersion por transferencia
7. pagos en efectivo
8. estadistica historica
9. formatos satelite por adscripcion o etiqueta

Hallazgos relevantes:

- `SEM 26` es la hoja nucleo
- `TRANSFERENCIA` y `EFECTIVO` son salidas derivadas
- `CONTROL DE FALTAS` y `AUSENCIA DE HORAS` son capturas o semicapuras operativas
- `LISTA DE EMPLEADOS` funciona como maestro de personal y sueldo
- `PRESTACIONES` es un catalogo de reglas con montos y porcentajes
- `PRESTAMOS` es cartera viva de descuentos por prestamo
- `ESTADISTICA` es dashboard historico
- `ETIQUETAS` no conviene modelarla como fuente; hoy parece exporte fragil

Riesgo tecnico observado en el workbook inspeccionado:

- miles de formulas
- referencias externas a otros libros
- muchas referencias `#REF!` en hojas derivadas

Eso confirma que la app debe absorber la logica, no solo el formato.

## Decision de producto

La app debe tomar este Excel como:

- especificacion de negocio
- referencia de formulas
- referencia de salidas

No como:

- modelo tecnico final
- estructura de base de datos
- experiencia de usuario definitiva

## Mapeo hoja por hoja

### 1. `LISTA DE EMPLEADOS`

Funcion actual en Excel:

- maestro de personas
- datos fiscales y laborales
- sueldo vigente
- historial de sueldos y modificaciones

Campos visibles relevantes:

- numero interno
- nombre
- adscripcion operativa actual
- NSS
- RFC
- CURP
- fecha de ingreso
- telefono
- numero de cuenta
- sueldo diario
- dias
- total
- historial de sueldo anterior
- fecha de aumento
- fecha/modificacion

#### En la app se vuelve

Tablas:

- `hr_employees`
- `hr_worksites`
- `hr_employee_work_assignments`
- `hr_employee_bank_accounts`
- `hr_employee_salary_history`
- `hr_employee_change_log`

Pantallas:

- `Personal`
- `Detalle de empleado`
- `Historial salarial`

Formulas parametrizadas:

- `sueldo_diario = sueldo_periodo / dias_base`

Exportes:

- listado maestro de empleados
- historial de movimientos salariales

Notas:

- esta hoja no debe seguir siendo una sola tabla plana
- el historial salarial debe separarse del dato vigente
- cuenta bancaria no debe vivir repetida por corrida semanal
- la adscripcion operativa no debe confundirse con empresa pagadora

### 2. `PRESTACIONES`

Funcion actual en Excel:

- catalogo de bonos, prestaciones y reglas de pago

Ejemplos vistos:

- hora extra general
- bono sabatino
- bono dominical
- incapacidad al 50%
- bonos por planta o frente operativo
- falta injustificada

#### En la app se vuelve

Tablas:

- `hr_payroll_rules`
- `hr_payroll_rule_rates`
- `hr_payroll_concepts`

Pantallas:

- `Reglas y prestaciones RH`
- `Conceptos de nomina`

Formulas parametrizadas:

- pago por hora extra
- pago por sabado/domingo
- porcentaje de incapacidad
- descuento por falta injustificada

Exportes:

- catalogo de conceptos y reglas vigentes

Notas:

- no debe quedar como texto libre por fila
- conviene versionar reglas por vigencia
- varios conceptos son realmente `conceptos de nomina`, no solo “prestaciones”

### 3. `PRESTAMOS`

Funcion actual en Excel:

- control de prestamos por colaborador
- monto solicitado
- descuento por periodo
- pagos acumulados
- restante
- estatus

Problema actual:

- el restante se calcula con restas manuales o formulas no estructuradas

#### En la app se vuelve

Tablas:

- `hr_employee_loans`
- `hr_employee_loan_installments`
- `hr_employee_loan_deductions`

Pantallas:

- `Prestamos RH`
- `Detalle de prestamo`

Formulas parametrizadas:

- saldo_restante
- calendario de descuento por corrida

Exportes:

- estado de cartera de prestamos
- descuentos aplicados por semana

Notas:

- esta parte es muy buen candidato para pasar a la app
- ganaríamos trazabilidad y saldo correcto por corrida

### 4. `CONTROL DE FALTAS`

Funcion actual en Excel:

- control semanal y acumulado de faltas
- base para descuentos y control de incidencia

Campos visibles:

- faltas acumuladas por mes
- faltas por dia
- total de faltas

#### En la app se vuelve

Tablas:

- `hr_attendance_incidents`
- `hr_absence_events`
- `hr_employee_period_summaries`

Pantallas:

- `Asistencia e incidencias`
- `Detalle por empleado`
- `Resumen por periodo`

Formulas parametrizadas:

- total de faltas por semana
- acumulado mensual
- impacto economico de faltas

Exportes:

- resumen de faltas por semana
- acumulado por colaborador

Notas:

- esto no debe depender de editar celdas por dia dentro de una hoja cerrada
- conviene que la app soporte importacion y tambien ajuste manual justificado

### 5. `AUSENCIA DE HORAS`

Funcion actual en Excel:

- control de horas ausentes o ausencias parciales
- base para descuentos u observacion operativa

Campos visibles:

- horas acumuladas
- horas por dia
- total de horas

#### En la app se vuelve

Tablas:

- `hr_missing_hours_events`
- `hr_employee_period_hour_summaries`

Pantallas:

- `Asistencia e incidencias`
- tab o vista `Ausencia de horas`

Formulas parametrizadas:

- total de horas ausentes
- conversion a impacto economico si aplica

Exportes:

- resumen de horas ausentes por semana

Notas:

- debe vivir junto con incidencias, no como modulo separado de negocio
- pero sí puede ser una subvista propia por tipo de incidencia

### 6. `SEM 26`

Funcion actual en Excel:

- corrida semanal central de nomina
- mezcla sueldo, jornada, septimo dia, finiquito, ISR, IMSS, faltas, retardos, Infonavit, Fonacot, pago por fuera, efectivo, bonos, vacaciones y total
- incluye columna `Empresa` para identificar donde labora el trabajador de DICSA

Esta es la hoja mas importante del workbook.

#### En la app se vuelve

Tablas:

- `hr_payroll_runs`
- `hr_payroll_run_lines`
- `hr_payroll_line_concepts`
- `hr_payroll_adjustments`
- `hr_payroll_line_funding_split`
- `hr_payroll_line_work_context`

Pantallas:

- `Prenomina / Nomina`
- `Detalle de corrida`
- `Detalle por colaborador`
- `Revision de conceptos`

Formulas parametrizadas:

- jornada
- septimo dia
- total depositado
- sueldo en efectivo
- vacaciones en efectivo
- descuentos
- total final

Exportes:

- prenomina semanal
- nomina final semanal
- concentrado por colaborador

Notas:

- esta hoja no debe migrarse como grid libre igualito
- se debe dividir en:
  - cabecera de corrida
  - lineas por empleado
  - conceptos por linea
  - totales y salidas
- `Empresa` debe entrar como contexto operativo de asignacion, no como entidad comercial externa

### 7. `TRANSFERENCIA`

Funcion actual en Excel:

- salida de dispersion bancaria
- toma columnas derivadas de `SEM 26`

Campos visibles:

- sueldo semanal
- sueldo a depositar
- vacaciones
- mas ISR ajustado
- menos ISR
- faltas
- retardos
- Infonavit
- Fonacot
- total depositado
- numero de cuenta

#### En la app se vuelve

Tablas:

- `hr_payroll_payment_instructions`
- `hr_payroll_bank_payment_lines`

Pantallas:

- `Salida de pago`
- vista `Transferencia`

Formulas parametrizadas:

- total depositado por transferencia

Exportes:

- layout de transferencia
- concentrado bancario por corrida

Notas:

- esta vista no debe recalcular nomina
- solo debe consumir la corrida cerrada y preparar la salida
- aqui se conecta RH con Finanzas

### 8. `EFECTIVO`

Funcion actual en Excel:

- salida para pagos en efectivo
- separa componentes pagados fuera de deposito
- incluye espacio de firma

#### En la app se vuelve

Tablas:

- `hr_payroll_cash_payment_lines`
- `hr_payroll_cash_acknowledgements`

Pantallas:

- `Salida de pago`
- vista `Efectivo`

Formulas parametrizadas:

- total efectivo por persona
- total efectivo de corrida

Exportes:

- recibo o lista de firma
- resumen de efectivo requerido

Notas:

- muy adaptable a la app
- incluso mejora mucho si despues soporta firma digital o evidencia de entrega

### 9. `ESTADISTICA`

Funcion actual en Excel:

- historico semanal de montos
- comparativo de transferencia, efectivo, por fuera, vacaciones y horas extra

#### En la app se vuelve

Tablas:

- no necesita tabla nueva si la corrida historica queda bien modelada
- puede salir de vistas o agregados sobre `hr_payroll_runs` y `hr_payroll_run_lines`

Pantallas:

- `Dashboard RH`
- widgets para `Direccion`

Formulas parametrizadas:

- agregaciones por semana
- agregaciones por tipo de salida
- tendencia de vacaciones y horas extra

Exportes:

- historico semanal
- resumen ejecutivo

Notas:

- es candidato perfecto para dashboard nativo
- no debe seguir dependiendo de captura manual acumulada

### 10. `WHIRLPOOL`, `MONROE`, `KS`

Funcion actual en Excel:

- vistas satelite por adscripcion operativa o planta anfitriona
- parecen ser formatos de desglose o apoyo operativo

Aclaracion:

- representan personal DICSA laborando dentro de esas plantas
- no representan una nomina separada de otra empresa
- no deben modelarse primero como modulo comercial ni como contraparte financiera

#### En la app se vuelve

Tablas:

- no necesariamente tablas nuevas
- probablemente filtros sobre corrida y lineas por adscripcion, planta o frente operativo

Pantallas:

- `Detalle de corrida`
- filtros por adscripcion operativa

Formulas parametrizadas:

- ninguna nueva si ya existe la corrida base

Exportes:

- reporte por adscripcion
- reporte por planta anfitriona

Notas:

- no son prioridad 1 como pantalla dedicada
- primero conviene modelar el dominio comun y luego generar estas vistas
- esto refuerza la necesidad de un catalogo de `centros de trabajo` o `adscripciones`

### 11. `PAGOS RAMON`

Funcion actual en Excel:

- caso especial de incapacidades o pagos diferenciados
- parece servir para seguimiento excepcional

#### En la app se vuelve

Tablas:

- `hr_special_cases`
- `hr_special_case_payments`

Pantallas:

- no una pantalla principal al inicio
- mejor una capacidad dentro de `Incidencias` o `Casos especiales`

Formulas parametrizadas:

- diferencia entre pago IMSS y pago empresa

Exportes:

- reporte de caso especial

Notas:

- no conviene diseñar una pantalla solo por este caso al principio
- sí conviene garantizar que el modelo soporte excepciones

### 12. `ETIQUETAS`

Funcion actual en Excel:

- salida altamente dependiente de referencias
- hoy presenta muchas referencias rotas

#### En la app se vuelve

Tablas:

- ninguna como fuente maestra

Pantallas:

- ninguna al inicio

Formulas parametrizadas:

- ninguna nueva

Exportes:

- si negocio la necesita, debe rehacerse como exporte controlado

Notas:

- no conviene migrarla como esta
- primero hay que reconstruir el objetivo de negocio de esta hoja

## Mapeo por dominio de app

### Dominio 1. Personal

Entra:

- `LISTA DE EMPLEADOS`
- parte del historial salarial
- datos bancarios base
- adscripcion operativa vigente

### Dominio 2. Reglas y catalogos

Entra:

- `PRESTACIONES`
- descuentos fijos o parametrizables

### Dominio 3. Prestamos

Entra:

- `PRESTAMOS`

### Dominio 4. Asistencia e incidencias

Entra:

- `CONTROL DE FALTAS`
- `AUSENCIA DE HORAS`
- despues: reloj checador, vacaciones, permisos, retardos

### Dominio 5. Corrida de nomina

Entra:

- `SEM 26`

### Dominio 6. Salidas de pago

Entra:

- `TRANSFERENCIA`
- `EFECTIVO`
- `PAGO POR FUERA`

### Dominio 7. Ejecutivo / Dashboard

Entra:

- `ESTADISTICA`
- indicadores derivados de corridas reales

## Lo que sí conviene adaptar ya

- maestro de empleados
- salarios e historial
- prestamos
- faltas
- horas ausentes
- corrida semanal
- salida por transferencia
- salida por efectivo
- dashboard ejecutivo

## Lo que no conviene copiar literal

- etiquetas
- formatos satelite como fuente
- formulas entre hojas
- referencias externas
- referencias rotas
- columnas de comentario mixtas con dato maestro

## Propuesta de pantallas iniciales derivadas del Excel

### 1. `Personal`

Arquetipo:

- `Grid Editable`

Motivo:

- maestro de empleados y datos base

### 2. `Prestamos RH`

Arquetipo:

- `Workflow Master-Detail` o `Grid Editable`

Motivo:

- cartera viva y descuentos por semana

### 3. `Asistencia e incidencias`

Arquetipo:

- `Operacion Hibrida por Tabs`

Tabs sugeridos:

- faltas
- horas
- retardos
- vacaciones
- permisos
- importaciones

### 4. `Prenomina / Nomina`

Arquetipo:

- `Operacion Hibrida por Tabs`

Tabs sugeridos:

- borrador
- validacion
- cerrada
- salidas

### 5. `Salida de pago`

Arquetipo:

- `Operacion Hibrida por Tabs`

Tabs sugeridos:

- transferencia
- efectivo
- por fuera
- exportes

### 6. `Dashboard RH`

Arquetipo:

- `Dashboard`

### 7. `Vista Direccion RH`

Arquetipo:

- `Dashboard`

Motivo:

- Direccion no necesita capturar todo
- necesita ver:
  - monto semanal
  - variaciones
  - faltas
  - horas extra
  - vacaciones
  - prestamos
  - incidencias criticas

## Cruce con Finanzas

La parte del Excel que mas valor da a Direccion y a la app completa es el cruce:

- corrida nominal
- salida de transferencia
- salida en efectivo
- pagos por fuera

Eso debe conectarse a Finanzas con entidades puente como:

- `payroll_payment_instruction`
- `payroll_payment_batch`
- `payroll_obligation_payment`

Regla:

- RH calcula y prepara
- Finanzas ejecuta y concilia

## Recomendacion de aterrizaje

No hacer una sola pantalla “Nomina como Excel”.

Hacer este orden:

1. `Personal`
2. `Prestamos`
3. `Asistencia e incidencias`
4. `Prenomina / Nomina`
5. `Salida de pago`
6. `Dashboard RH`
7. `Vista Direccion RH`

## Juicio final

El Excel no perjudica la app.

Lo que perjudicaria seria:

- copiarlo completo
- respetar su fragilidad tecnica
- volver la UI una hoja enorme con formulas invisibles

Lo que sí ayuda mucho es usarlo como:

- mapa de negocio
- inventario de conceptos
- evidencia de formulas reales
- lista de salidas que RH sí necesita

La app puede absorberlo bien si tratamos el archivo como dominio de negocio descompuesto y no como layout a clonar.
