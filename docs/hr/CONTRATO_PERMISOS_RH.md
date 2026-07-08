# Contrato: Permisos RH

Este documento congela cómo debe nacer la pantalla `Permisos` dentro de RH.

No es una exploración.

No es un mock.

Es un contrato replicable y ejecutable sobre el arquetipo ya congelado en `Asistencia`.

La referencia base obligatoria es:

- `docs/hr/CONTRATO_ASISTENCIA_RH.md`
- `docs/hr/CONTRATO_VACACIONES_RH.md`

## Regla madre

`Permisos` debe copiar 1:1 el contrato visual, de interacción y de shell de `Asistencia` y `Vacaciones`.

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
- lógica de captura y cálculo
- estados de permisos

## Propósito de la pantalla

`Permisos` es la superficie donde RH registra, corrige y confirma permisos administrativos del colaborador por periodo operativo.

Debe resolver:

- permisos con goce
- permisos sin goce
- incapacidades
- ajustes administrativos RH
- si el permiso fue por día o por hora
- qué periodo de asistencia toca
- si ya fue aprobado o aplicado
- si debe impactar asistencia
- si después debe empujar prenómina

No es todavía:

- la prenómina final
- la nómina final
- el recibo final

Pero sí debe dejar la trazabilidad lista para llegar ahí sin rehacer el módulo.

## Relación obligatoria con otros módulos

### Personal

`Permisos` debe leer de `Personal`:

- `employee_id`
- nombre homologado
- empresa
- `fecha_ingreso`
- `fecha_alta`
- `salario`
- `salario percibido`
- jornadas capturadas

### Asistencia

`Permisos` debe convivir con `Asistencia` porque los permisos son parte del cierre real del colaborador antes de vacaciones, prenómina y nómina.

La primera versión debe guardar:

- periodo operativo
- tipo de permiso
- rango de fechas
- horas cuando aplique
- notas RH
- bandera de impacto en asistencia

La sincronización fina hacia `Asistencia` puede seguir endureciéndose, pero el evento debe quedar listo para alimentar y justificar el cierre.

### Importación y conciliación

`Permisos` no nace de NGTeco como fuente principal.

Pero sí debe usar el periodo activo de importaciones para:

- registrar el permiso dentro de una semana operativa concreta
- no mezclar cierres distintos
- dejar trazabilidad para conciliación y prenómina

### Vacaciones

`Permisos` y `Vacaciones` son superficies hermanas.

No se deben mezclar como un solo módulo, pero ambas deben alimentar después:

- justificación administrativa
- prenómina
- nómina

### Prenómina / Nómina

`Permisos` debe exponer después:

- días con goce
- días sin goce
- horas administrativas
- incapacidades
- observaciones RH
- trazabilidad por periodo

## Contrato visual del área

Debe usar exactamente el contrato visual vigente de RH:

- header superior con logo `DicsaLogoD`
- título principal `Recursos Humanos`
- subtítulo del módulo `Permisos`
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

- título `Permisos`
- botón principal `Editar permisos`
- bloque derecho de selección
- tarjeta métrica alineada a la derecha debajo del toolbar

### Bloque de selección

Debe mostrar:

- cantidad de registros seleccionados
- periodo activo
- `activeCellLabel` si existe

### Tarjeta métrica

Debe usar el mismo lenguaje visual de `Asistencia` y `Vacaciones`.

Label congelado:

- `PERMISOS RH`

Número principal:

- total de registros visibles

Leyenda inferior:

- `Filtrado (N registros)`

## Contrato del grid

El grid de `Permisos` es un grid editable homologado a `Asistencia`.

### Columnas congeladas

La primera versión debe mostrar estas columnas:

- `ID`
- `Nombre`
- `Con goce`
- `Sin goce`
- `Incapacidad`
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

## Contrato del diálogo

El diálogo debe mantener:

- ficha izquierda fija del trabajador
- scroll solo en la columna derecha
- edición por tarjetas
- navegación `←` y `→` entre trabajadores
- `Esc` cierra
- `Enter` guarda
- click fuera cierra

### Secciones mínimas del diálogo

- `Resumen del periodo`
- `Eventos del colaborador`

### Campos mínimos por evento

- tipo
- estatus
- unidad `día / hora`
- fecha inicio
- fecha fin
- hora inicio
- hora fin
- cantidad capturada
- impacta asistencia
- impacta prenómina
- notas RH

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

## Secuencia funcional congelada

`Permisos` no es un módulo aislado.

Opera dentro de una secuencia RH congelada:

1. `Importación y conciliación` define el periodo operativo activo.
2. `Asistencia` concentra el cierre editable diario por colaborador.
3. `Vacaciones` justifica y reserva eventos vacacionales.
4. `Permisos` registra permisos administrativos sobre ese mismo periodo.
5. Después vendrán `Prenómina` y `Nómina`.

La regla es:

- nunca mezclar semanas activas distintas
- nunca escribir un permiso fuera del periodo operativo seleccionado
- nunca pisar automáticamente un día ya tomado por otra superficie RH sin validación

## Reglas de sincronización con Asistencia

La sincronización actual queda congelada así:

- solo sincronizan a `Asistencia` los eventos con `estatus = Aplicado`
- solo sincronizan automáticamente los eventos con `unidad = Día`
- el evento debe tener `impacta asistencia = true`
- si el permiso está `Pendiente`, `Aprobado` o `Cancelado`, no debe cerrar automáticamente el día en `Asistencia`
- si el permiso es por `Hora`, no debe convertir el día completo en `No aplica`

### Qué hace la sincronización

Cuando un permiso cumple las reglas anteriores:

- localiza el periodo activo de asistencia
- identifica las fechas del rango del permiso
- intenta marcar esos días como justificados para el colaborador
- registra trazabilidad en notas RH del día afectado

### Qué no puede hacer la sincronización

La sincronización debe omitir el cambio si:

- el día ya tiene fichajes reales
- el día ya está bloqueado por una nota de `Vacaciones RH`
- la fecha cae fuera del periodo activo
- el colaborador no tiene jornada laborable esperada para ese día

### Reversibilidad

Si RH elimina o cambia un permiso ya aplicado:

- el sistema debe retirar la marca previa de `Permisos RH`
- si no existe otra justificación RH, el día vuelve a su estado base
- si el día también estaba justificado por `Vacaciones RH`, esa justificación permanece

## Reglas de convivencia con Vacaciones

`Permisos` y `Vacaciones` no se fusionan.

Pero sí comparten superficie de impacto sobre `Asistencia`.

Congelamos estas reglas:

- `Vacaciones RH` tiene prioridad cuando un día ya fue reservado como vacaciones
- `Permisos RH` no puede sobreescribir automáticamente una vacación aplicada
- ambos módulos deben dejar trazabilidad independiente en notas
- ambos deben poder alimentar después los cálculos de prenómina y nómina

## Regla de trazabilidad para prenómina

Aunque `Permisos` todavía no construye la prenómina final, desde esta versión debe dejar listo:

- tipo de permiso
- unidad de captura
- rango de fechas
- cantidad en días u horas
- estatus RH
- bandera `impacta prenómina`
- periodo operativo usado

Esto permite que más adelante RH distinga:

- permiso con goce
- permiso sin goce
- incapacidad
- ajuste administrativo
- evento capturado pero no aplicado todavía

## Regla de lectura actual

En la versión actual del sistema:

- `Asistencia` es el cierre diario editable
- `Vacaciones` ya puede empujar justificaciones por día
- `Permisos` ya debe empujar justificaciones por día bajo reglas seguras
- los permisos por hora quedan registrados y trazables, pero todavía no cierran automáticamente el día

Ese comportamiento no es provisional.

Es la base congelada sobre la que se montará después el cálculo de `Prenómina`.
