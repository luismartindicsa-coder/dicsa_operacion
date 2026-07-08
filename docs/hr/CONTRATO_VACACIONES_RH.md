# Contrato: Vacaciones RH

Este documento congela cómo debe nacer la pantalla `Vacaciones` dentro de RH.

No es una exploración.

No es un mock.

Es un contrato replicable y ejecutable sobre el arquetipo ya congelado en `Asistencia`.

La referencia base obligatoria es:

- `docs/hr/CONTRATO_ASISTENCIA_RH.md`

La referencia de negocio fuente para este módulo es:

- `docs/hr/PLAN_VACACIONES_RH.md`

## Regla madre

`Vacaciones` debe copiar 1:1 el contrato visual, de interacción y de shell de `Asistencia`.

No se debe inventar otro patrón.

Se copian sin reinterpretación:

- shell del área RH
- top bar del módulo
- tarjeta métrica
- grid editable
- footer de paginación
- diálogo con ficha izquierda fija
- scroll solo en el bloque principal derecho
- navegación por teclado
- selección múltiple
- menú contextual
- navegación entre registros con `←` y `→`
- `Esc`
- `Enter`
- click fuera para cerrar

Solo cambia el negocio:

- columnas del grid
- métricas del resumen
- campos del diálogo
- lógica de cálculo
- estados de vacaciones

## Propósito de la pantalla

`Vacaciones` es la superficie donde RH administra el derecho, captura y aplicación de vacaciones por colaborador y ejercicio.

Debe resolver:

- cuántos días le corresponden
- por qué le corresponden
- qué base de fecha se usó
- cuántos días ya se pagaron
- cuántos días ya se disfrutaron
- cuántos días quedaron reservados
- cuántos días siguen comprometidos operativamente
- cuántos quedan disponibles
- cuánto debe pagarse
- si existe prima vacacional
- si impacta asistencia
- si queda listo para prenómina

No es todavía:

- el generador final de recibos
- la nómina final
- el timbrado

Pero sí debe dejar el sistema listo para llegar ahí sin rehacer el módulo.

## Relación obligatoria con otros módulos

### Personal

`Vacaciones` debe leer de `Personal`:

- `employee_id`
- nombre homologado
- empresa
- `fecha_ingreso`
- `fecha_alta`
- `salario`
- `salario percibido`

### Asistencia

`Vacaciones` debe poder justificar ausencias en `Asistencia`.

Cuando un evento vacacional esté aplicado:

- los días del rango deben poder reflejarse como ausencia justificada
- no deben quedarse como falta probable
- deben poder alimentar el cierre semanal editable

Regla operativa actual:

- solo los eventos en estado `Aplicado` sincronizan asistencia
- la sincronización no pisa días con fichajes reales
- si RH elimina o cancela un evento aplicado, el ajuste de vacaciones en asistencia debe revertirse
- los días `pagados` no descuentan por sí solos disponibilidad operativa
- los días `disfrutados` y `reservados` sí consumen disponibilidad operativa

### Importación y conciliación

`Vacaciones` no nace de NGTeco.

Pero sí debe usar el contexto de periodo activo para:

- sincronizar semanas
- entender cierres en revisión
- cruzar eventos vacacionales contra asistencia

Regla operativa actual:

- los lotes `CONTPAQ` con importe positivo en `Vacaciones a tiempo` deben sembrar o actualizar automáticamente un evento `Vacaciones pagadas`
- ese evento queda vinculado por `periodo + empleado`
- el evento autoimportado no debe impactar asistencia por sí solo
- el cálculo monetario del evento autoimportado debe conservar el importe fiscal leído de CONTPAQ

### Prenómina / Nómina

`Vacaciones` debe exponer después:

- días pagables
- prima vacacional
- base salarial usada
- separación de componentes si existen
- trazabilidad para recibo

## Contrato visual del área

Debe usar exactamente el contrato visual vigente de RH:

- header superior con logo `DicsaLogoD`
- título principal `Recursos Humanos`
- subtítulo del módulo `Vacaciones`
- fondo del área compartido con RH
- contenedor principal oscuro translúcido
- toolbar lavanda translúcido
- tarjeta métrica lila clara a la derecha
- grid blanco con selección morada
- footer lavanda translúcido
- diálogo claro con acentos morados RH

No se permite:

- otro shell
- botones azules ajenos a RH
- dropdowns nativos crudos
- chips verdes no homologados
- diseño alterno al patrón de `Asistencia`

## Estructura exacta de la pantalla

La pantalla debe armarse así:

1. `Header` del área RH
2. `Título del módulo`
3. `Toolbar del módulo`
4. `Tarjeta métrica`
5. `Grid editable`
6. `Footer de paginación`

## Contrato del top bar

El top bar replica el de `Asistencia`.

Debe incluir:

- título `Vacaciones`
- botón principal `Editar vacaciones`
- bloque derecho de selección
- tarjeta métrica alineada a la derecha debajo del toolbar

### Bloque de selección

Debe mostrar:

- cantidad de registros seleccionados
- leyenda `Shift/Ctrl amplian la selección activa` cuando haya multiselección
- `activeCellLabel` si existe

### Tarjeta métrica

Debe usar el mismo lenguaje visual de `Asistencia` y `Personal`.

Label congelado:

- `VACACIONES RH`

Número principal:

- total de registros visibles

Leyenda inferior:

- `Filtrado (N registros)`

## Contrato del grid

El grid de `Vacaciones` es un grid editable homologado a `Asistencia`.

### Columnas congeladas

La primera versión debe mostrar estas columnas:

- `ID`
- `Nombre`
- `Fecha ingreso`
- `Fecha alta`
- `Días corresponden`
- `Días aplicados`
- `Días disponibles`
- `Estado`
- `Acciones`

### Reglas del grid

- filas blancas con bordes suaves
- fila seleccionada en lila/morado
- hover fino
- filtros por columna en header
- selección sincronizada entre mouse y teclado
- scroll del grid independiente del footer
- botón de acciones al extremo derecho

### Formato de columnas

- `Fecha ingreso`: formato fecha RH
- `Fecha alta`: formato fecha RH
- `Días corresponden`: entero
- `Días aplicados`: entero
- `Días disponibles`: entero
- `Estado`: badge corto y legible

## Contrato de interacción del grid

Debe conservar exactamente esta interacción:

- click selecciona fila
- teclado mueve fila activa
- la fila activa por teclado también queda seleccionada visualmente
- `Enter` abre el registro activo
- `Esc` limpia selección o devuelve foco al grid según el estado actual
- click derecho abre menú contextual de fila
- drag crea selección por rango
- `Ctrl/Cmd` permite selección aditiva
- `Shift` amplía rango

No puede existir una fila activa distinta de la fila seleccionada visualmente.

## Contrato del menú de acciones

La última columna usa `EditableRowActionsButton`.

La acción mínima congelada es:

- `Editar vacaciones`

Más adelante podrán existir otras, pero la primera acción siempre abre el expediente editable del colaborador.

## Contrato del footer

Replica el de `Asistencia`.

Debe incluir:

- `Anterior`
- `Página X de Y`
- `Siguiente`
- `Filas/pág`
- `Mostrando`
- `Total`
- `Selección`

Los tamaños de página iniciales quedan congelados en:

- `40`
- `80`
- `120`

## Contrato del diálogo de edición

El diálogo de `Vacaciones` debe copiar el shell exacto de `Asistencia`.

### Apertura y cierre

Debe abrir con `ContractDialogShell`.

Debe soportar:

- click fuera para cerrar sin guardar
- botón `X`
- botón `Cancelar`
- `Esc` para cerrar
- `Enter` para guardar

La ficha izquierda debe permanecer fija.

El scroll principal debe quedarse en la columna derecha.

### Navegación entre colaboradores

Debe soportar:

- botón `Anterior`
- botón `Siguiente`
- tecla `←`
- tecla `→`

La navegación lateral solo corre cuando el usuario no está escribiendo en un campo de texto.

### Shell del diálogo

El diálogo se divide en:

1. `Header`
2. `Cuerpo en dos columnas`
3. `Footer`

## Contrato del header del diálogo

Debe incluir:

- título `Vacaciones del colaborador`
- subtítulo operativo corto
- chips de contexto:
  - `#ID`
  - empresa o `Empresa pendiente`
  - ejercicio o periodo activo
- botón `X`

## Contrato del cuerpo del diálogo

El cuerpo se divide en:

- ficha izquierda fija del colaborador
- columna derecha operativa con scroll principal

### Ficha izquierda fija

La ficha izquierda:

- tiene ancho fijo
- no se desplaza junto con los bloques principales
- no debe depender de scroll principal

Debe incluir:

- nombre
- `ID`
- empresa
- separador
- `Fecha ingreso`
- `Fecha alta`
- `Salario`
- `Salario percibido`
- `Base de fecha`
- `Antigüedad calculada`
- `Días corresponden`
- `Días aplicados`
- `Días pagados`
- `Días disfrutados`
- `Días reservados`
- `Días disponibles`
- `Estado`

### Selector de base de cálculo

La ficha izquierda debe permitir seleccionar explícitamente la base de cálculo:

- `Fecha de ingreso`
- `Fecha de alta`
- `Manual RH`

#### Reglas

- `Fecha de ingreso` calcula contra la antigüedad de ingreso
- `Fecha de alta` calcula contra la antigüedad de alta
- `Manual RH` permite override controlado con justificación obligatoria

Esta decisión no puede quedar oculta.

Debe ser visible y auditable.

## Columna derecha

La columna derecha se divide en:

- `Resumen`
- `Reglas de cálculo`
- `Eventos de vacaciones`
- `Componentes de pago`

El bloque con scroll principal debe vivir aquí.

### 1. Resumen

Debe mostrar mini cards con:

- `DIAS CORRESPONDEN`
- `DIAS APLICADOS`
- `DIAS PAGADOS`
- `DIAS DISFRUTADOS`
- `DIAS RESERVADOS`
- `DIAS DISPONIBLES`
- `VACACIONES`
- `PRIMA VACACIONAL`

### 2. Reglas de cálculo

Debe dejar visible:

- fecha base usada
- antigüedad resultante
- tramo legal aplicado
- días que corresponden según tabla
- si existe override RH

No se permite esconder la lógica en un número final sin explicación.

### 3. Eventos de vacaciones

Debe permitir capturar uno o varios eventos/rangos.

Cada evento debe incluir como mínimo:

- `Fecha inicio`
- `Fecha fin`
- `Días`
- `Tipo`
- `Estado`
- `Impacta asistencia`
- `Impacta prenómina`
- `Genera recibo`
- `Observación RH`

Regla de cálculo del evento:

- el rango propone automáticamente los días del evento
- RH puede sobreescribir manualmente el valor de `Días`
- si el valor manual se limpia, el sistema vuelve al cálculo automático por rango

Regla de sincronía visible:

- cada evento debe dejar visible su estado de sincronización con `Asistencia`
- cada evento debe dejar visible su estado de sincronización con `Prenómina`
- si el evento impactó asistencia, debe poder mostrar el o los periodos RH tocados

### Tipos mínimos de evento

- `Vacaciones disfrutadas`
- `Vacaciones pagadas`
- `Vacaciones pendientes`
- `Ajuste RH`

### 4. Componentes de pago

Debe permitir ver y, cuando aplique, ajustar:

- base con `salario`
- base con `salario percibido`
- vacaciones calculadas
- prima vacacional
- diferencia
- componente por transferencia
- componente por efectivo

No todos los casos usarán todas las piezas, pero el modelo debe soportarlas.

## Tabla legal de días

La primera versión debe congelar esta tabla:

- `1 año -> 12 días`
- `2 años -> 14 días`
- `3 años -> 16 días`
- `4 años -> 18 días`
- `5 años -> 20 días`
- `6 a 10 años -> 22 días`
- `11 a 15 años -> 24 días`
- `16 a 20 años -> 26 días`
- `21 a 25 años -> 28 días`
- `26 a 30 años -> 30 días`
- `31 a 35 años -> 32 días`

## Contrato de cálculo

La pantalla debe resolver al menos estas capas:

### Derecho

- calcular antigüedad
- identificar tramo legal
- devolver días que corresponden

### Aplicación

- descontar días aplicados
- devolver días disponibles
- permitir eventos múltiples

### Pago

- calcular importe de vacaciones
- calcular prima vacacional
- considerar salario y salario percibido
- dejar abierta la posibilidad de dos bases o dos componentes

## Regla sobre fecha de ingreso vs fecha de alta

No se debe asumir que una reemplaza a la otra.

El sistema debe soportar explícitamente:

- cálculo por `fecha_ingreso`
- cálculo por `fecha_alta`
- comparación de ambos escenarios
- override RH con justificación

Esto existe porque el negocio real ya anticipa casos donde:

- el derecho puede leerse con una fecha
- el pago puede resolverse con otra
- pueden existir dos cálculos y dos importes

## Regla sobre salario y salario percibido

El sistema debe soportar:

- cálculo con `salario`
- cálculo con `salario percibido`
- coexistencia de ambos importes
- justificación RH del criterio final

No se debe colapsar desde la primera versión a una sola base fija.

## Contrato de conexión con asistencia

Cuando un evento vacacional esté marcado con `Impacta asistencia`:

- los días del rango deben poder justificarse en `Asistencia`
- no deben quedarse como faltas probables
- debe existir trazabilidad de que la justificación vino de `Vacaciones`

La captura en `Vacaciones` debe poder alimentar la semana correspondiente sin volver a registrar a mano lo mismo.

## Contrato de persistencia

El módulo debe construirse al menos sobre estas entidades:

- `hr_employee_vacation_balances`
- `hr_employee_vacation_events`
- `hr_employee_vacation_calculations`

### Balance

Representa el saldo anual o por ejercicio del colaborador.

Debe separar al menos:

- `days_paid`
- `days_enjoyed`
- `days_reserved`
- `days_taken` como comprometido operativo (`disfrutados + reservados`)
- `days_available`

### Event

Representa rangos o movimientos vacacionales.

### Calculation

Representa el cálculo monetario y de base usado para un evento o resolución RH.

## Estados mínimos

La pantalla debe soportar al menos estos estados:

- `Pendiente`
- `Calculado`
- `Aplicado`
- `Con ajuste RH`
- `Listo para prenómina`

## Excepciones obligatorias

El módulo debe soportar desde el inicio:

- fechas de ingreso en serial Excel
- fechas de ingreso en texto español
- casos `SIN ALTA`
- casos `BAJA`
- filas sin `ID`
- colaboradores con `0` días
- diferencias entre `fecha_ingreso` y `fecha_alta`
- diferencias entre `salario` y `salario percibido`

Estas no son anomalías descartables.

Son parte del negocio.

## Prohibiciones

Para futuras implementaciones queda prohibido:

- inventar otro arquetipo distinto al de `Asistencia`
- esconder la base de cálculo de fecha
- esconder la base salarial usada
- forzar una sola fecha sin trazabilidad
- forzar un solo salario sin trazabilidad
- capturar vacaciones sin dejar estado de impacto en asistencia o prenómina
- resolver el cálculo final solo en frontend y sin explicación
- romper el cierre por click fuera
- perder navegación de teclado y entre registros

## Estado de congelamiento

Este contrato queda congelado como especificación fuente para construir la pantalla `Vacaciones`.

En cuanto exista la implementación viva en código, este documento deberá mantenerse sincronizado con ella en la misma intervención.
