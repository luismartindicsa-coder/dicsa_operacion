# Blueprint: Recursos Humanos Fase 1

Este documento aterriza el arranque de `Recursos Humanos` dentro de la app DICSA como un area nueva de la misma plataforma, no como una subapp aparte.

La referencia base para esta fase es el dashboard inicial de RH ya activado en la app, el mock visual existente y los contratos compartidos en:

- `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md`
- `lib/app/shared/app_ui/AREA_PALETTES_CONTRACT.md`
- `lib/app/shared/archetypes/`

La referencia visual congelada para nuevas pantallas de RH es:

- `lib/app/hr/human_resources_dashboard_page.dart`

La referencia funcional congelada para el siguiente modulo fuente queda en:

- `docs/hr/CONTRATO_ASISTENCIA_INCIDENCIAS_RH.md`

## Proposito

`Recursos Humanos` debe convertirse en la superficie fuente para:

- personal
- asistencia
- incidencias
- permisos
- vacaciones
- reclutamiento
- prenomina y nomina
- impuestos de nomina
- IMSS
- exportaciones e importaciones operativas desde reloj checador u otras fuentes externas

No debe nacer como un modulo aislado con reglas especiales de UI o formulas escondidas en widgets.

## Regla madre

La verdad operativa de calculo de RH nace en `Recursos Humanos`.

La verdad de ejecucion bancaria y salida de dinero nace en `Finanzas`.

Regla critica:

- RH calcula
- RH explica
- RH deja trazabilidad
- Finanzas paga
- Finanzas registra el movimiento bancario final

Eso aplica para:

- nomina
- anticipos nominales
- impuestos relacionados con nomina
- IMSS
- otras obligaciones patronales que salgan desde cuentas bancarias

## Restriccion absoluta de formulas

Toda formula que afecte dinero, dias, horas o descuentos debe cumplir estas condiciones:

- reproducible
- auditable
- parametrizable
- versionable
- explicable en lenguaje negocio

Queda prohibido resolver calculos criticos:

- solo en el frontend
- repartidos entre varios widgets
- sin parametros visibles
- con redondeos implicitos no documentados
- con dependencias ocultas a importaciones manuales

## Regla de trazabilidad minima

Cada corrida relevante de RH debe poder reconstruirse con:

- periodo
- empresa
- adscripcion o centro de trabajo cuando aplique
- persona
- fuente de asistencia o incidencia
- parametros aplicados
- formula aplicada
- resultado por concepto
- usuario que ejecuto o autorizo
- timestamp

## Cruce principal con Finanzas

El cruce principal de RH con otras areas es `Finanzas`.

Objetos de cruce esperados:

- cuentas bancarias desde donde se paga nomina
- cuentas bancarias desde donde se pagan impuestos de nomina
- cuentas bancarias desde donde se pagan IMSS y obligaciones relacionadas
- calendario de pagos fijos o recurrentes
- conciliacion entre corrida de RH y salida bancaria ejecutada

Regla operativa:

- RH no debe capturar el movimiento bancario final como verdad maestra
- Finanzas no debe recalcular la nomina como verdad maestra

La interfaz entre ambas areas debe apoyarse en una entidad puente futura, por ejemplo:

- `payroll_run`
- `payroll_run_line`
- `payroll_payment_instruction`
- `payroll_tax_obligation`
- `payroll_imss_obligation`

## Contrato visual de area

RH ya tiene paleta congelada oficial:

- familia: `morado corporativo / violeta profundo`
- anclas principales: `#9F6BFF`, `#B68CFF`, `#6E47A8`, `#2B114F`, `#24103D`, `#130B22`

Reglas obligatorias:

- RH no puede parecer `Menudeo`
- RH no puede reciclar azules base de `Menudeo`
- la pagina debe entrar por `AreaThemeScope`
- los componentes deben consumir tokens del area
- popups, pickers, menus y overlays deben heredar la paleta anfitriona

### Regla de lectura visual

La lectura correcta de RH debe ser:

- fondo oscuro
- cards oscuras
- acentos morados claros

No debe ser:

- fondo oscuro
- cards blancas
- brillo blanco dominante

### Regla de distribucion de color

Objetivo visual por masa:

- `70%` morado oscuro
- `20%` morado medio
- `10%` morado claro

Regla explicita:

- el color claro se usa para llamar la atencion
- no se usa como relleno dominante de heroes o cards grandes

### Reglas por superficie RH

- hero:
  - oscuro premium
  - titulo blanco puro
  - subtitulo blanco translúcido
  - badge morado claro
- card base:
  - oscura
  - borde tenue
  - sombra profunda
- estado vacio:
  - elegante
  - oscuro
  - borde punteado tenue
- panel lateral o contractual:
  - premium oscuro
  - acciones internas en morado medio
  - hover claro en la misma familia
- cards de acceso:
  - deben leerse como navegacion
  - icono + titulo + descripcion + flecha

### Regla de no desvio para futuras pantallas

Si una pantalla nueva de RH necesita mas claridad:

- primero ajustar contraste
- luego ajustar jerarquia
- luego ajustar distribucion de color

No se permite resolverlo con:

- superficies blancas dominantes
- cambio de familia cromatica
- verde, azul o naranja como color principal
- reinterpretacion local del glass

## Contrato de interaccion

RH debe heredar la misma secuencia institucional de la app:

- shell comun
- header comun
- side panel comun
- transiciones comunes
- overlays homologados
- refresh silencioso

No se debe resolver RH con layouts aislados que rompan:

- navegacion
- foco
- accesibilidad operativa
- comportamiento de overlays

## Contrato funcional por tipo de pantalla

No todas las pantallas de RH deben nacer como dashboard. La fase correcta es elegir arquetipo por trabajo real.

### 1. Dashboard

Para:

- resumen ejecutivo del area
- alertas de incidencias
- proximos cierres
- estatus de prenomina
- pendientes de impuestos o IMSS

Arquetipo homologado:

- `shared/archetypes/dashboard/`

### 2. Workflow Master-Detail

Para:

- reclutamiento
- expedientes
- solicitudes de permiso
- vacaciones por aprobar
- incidencias por revisar

Uso recomendado cuando exista:

- listado de items
- seleccion activa
- panel de detalle
- acciones contextuales

Arquetipo homologado:

- `shared/archetypes/workflow_master_detail/`

### 3. Operacion Hibrida por Tabs

Para:

- prenomina
- nomina por estatus
- calculo por etapas
- validacion previa
- corrida final

Porque mezcla bien:

- resumen
- tabs por estado o periodo
- superficie de trabajo mas profunda

Arquetipo homologado:

- `shared/archetypes/operacion_hibrida_tabs/`

### 4. Grid Editable o Grid Editable Tabulado

Para:

- catalogo de personal
- percepciones y deducciones parametrizadas
- tablas fiscales o factores controlados
- incidencias capturables
- ajustes importados revisables

Arquetipos homologados:

- `shared/archetypes/grid_editable/`
- `shared/archetypes/grid_editable_tabbed/`

## Secuencia inicial sugerida de pantallas

Fase 1 no debe abrir demasiados frentes. La secuencia minima recomendada es:

1. `Dashboard RH`
2. `Personal`
3. `Asistencia e incidencias`
4. `Prenomina / Nomina`
5. `Obligaciones RH`:
   impuestos de nomina, IMSS y pagos relacionados
6. `Reclutamiento`

## Modulos minimos de Fase 1

### Dashboard RH

Debe responder estas preguntas diarias:

1. `Cuantas incidencias impactan el periodo actual`
2. `Cuanto dinero nominal se esta preparando`
3. `Que obligaciones o cierres vencen pronto`
4. `Que exportacion o importacion operativa esta pendiente`

### Personal

Objetivo:

- consolidar expediente operativo minimo
- alta y estatus
- puesto
- empresa
- adscripcion operativa o centro de trabajo
- tipo de contrato
- salario base o esquema de pago

Regla de interpretacion:

- en RH, referencias como `WHIRLPOOL`, `MONROE` o `KS` pueden representar planta anfitriona o frente de trabajo del colaborador DICSA
- no deben asumirse por default como empresa legal distinta ni como contraparte comercial

No debe mezclar desde el inicio:

- calculo nominal
- reclutamiento
- cumplimiento IMSS

Aunque se relacionen, su flujo funcional no es el mismo.

### Asistencia e incidencias

Objetivo:

- importar reloj checador
- revisar faltas
- revisar retardos
- capturar permisos
- capturar vacaciones
- marcar horas extra
- dejar evidencia de ajustes

Regla critica:

- importacion no debe pegar directo a nomina final
- primero debe quedar una capa de staging, validacion y aprobacion

Entidades sugeridas:

- `attendance_import_batch`
- `attendance_event`
- `attendance_adjustment`
- `hr_incident`
- `leave_request`

Contrato ampliado:

- usar `employee_id` como llave principal del cruce
- tratar `Personal RH` como padrón maestro
- tratar `NGTeco` como fuente parcial de asistencia
- tratar `CONTPAQ` como fuente parcial de nómina del periodo
- soportar captura manual justificada como capacidad nativa
- publicar a prenómina solo desde staging aprobado

Referencia directa:

- `docs/hr/CONTRATO_ASISTENCIA_INCIDENCIAS_RH.md`

### Prenomina / Nomina

Objetivo:

- consolidar entradas validadas
- correr formulas
- producir resultados por colaborador y concepto
- congelar corrida
- preparar instruccion para pago

Reglas criticas:

- una corrida debe ser inmutable despues de cerrarse
- si se recalcula, debe abrirse nueva version o nueva corrida
- los parametros usados deben quedar persistidos

Conceptos minimos que deben soportar trazabilidad:

- sueldo base
- dias trabajados
- faltas
- retardos si impactan
- horas extra
- vacaciones
- prima vacacional
- prestamos o descuentos
- subsidios o ajustes manuales controlados
- deducciones legales

### Obligaciones RH

Objetivo:

- separar obligaciones patronales de la corrida nominal
- preparar importes y fechas de pago
- enlazar el pago con Finanzas

Ejemplos:

- IMSS
- ISR de nomina
- otros impuestos y obligaciones futuras

### Reclutamiento

Objetivo:

- pipeline ligero de candidatos
- vacantes
- etapas
- documentos
- conversion a alta de personal

No debe contaminar el catalogo maestro de personal hasta que exista contratacion efectiva.

## Contrato de importaciones y exportaciones

RH depende de archivos externos, asi que esta area necesita una disciplina mas estricta.

Toda importacion debe dejar:

- archivo fuente
- tipo de fuente
- layout esperado
- fecha de carga
- usuario
- cantidad de filas recibidas
- cantidad de filas validas
- cantidad de filas rechazadas
- motivo de rechazo por fila

Toda exportacion relevante debe poder regenerarse.

Ejemplos:

- exportacion para IMSS
- reporte de prenomina
- layout de dispersion
- resumen de incidencias

## Reglas de calculo que deben parametrizarse

No fijar estas reglas dentro del UI:

- tolerancias de retardo
- formula de horas extra
- reglas de descuento por falta
- reglas de vacaciones
- prima vacacional
- topes o reglas de subsidio
- periodicidad de pago
- redondeo por concepto

Cada una debe vivir en parametros o motor de reglas visible para la app.

## Riesgos que RH no debe repetir

- mezclar captura, calculo y pago en una sola pantalla
- usar el mock como pantalla final de operacion
- meter formulas en callbacks del frontend
- importar xlsx/csv directo a tablas finales
- recalcular nomina sin versionado
- permitir que Finanzas ajuste conceptos nominales fuente
- permitir ajustes manuales sin evidencia

## Estado actual en codigo

A la fecha de este blueprint:

- RH ya tiene paleta oficial congelada
- existe un mock visual de RH
- RH ya fue activado como area navegable desde `Direccion`
- el usuario `rh@dicsamx.com` ya puede aterrizar en su dashboard inicial por ruteo
- el dashboard inicial de RH usa el arquetipo compartido `empty_area_dashboard`

## Siguiente paso recomendado

La siguiente entrega no deberia intentar abrir nomina completa de una vez.

El orden recomendado es:

1. `Personal`
2. `Asistencia e incidencias` con staging de importaciones
3. `Prenomina` con formulas parametrizadas
4. `Obligaciones RH` enlazadas con Finanzas

Ese orden protege el calculo, reduce retrabajo y evita que la nomina nazca sin datos fuente confiables.
