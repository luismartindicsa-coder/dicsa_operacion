# Contrato: Asistencia RH

Este documento congela exactamente como quedó la pantalla `Asistencia` dentro de RH.

No es una propuesta.

No es un mock.

Es un contrato replicable para futuras pantallas operativas como `Vacaciones`, `Permisos` y otras superficies semanales que deban nacer sobre el mismo arquetipo.

La referencia viva es:

- `lib/app/hr/human_resources_attendance_page.dart`

La referencia madre de interacción y visual para este contrato es:

- `lib/app/hr/human_resources_personnel_page.dart`

## Regla madre

`Asistencia` ya no se debe reinterpretar.

Las futuras pantallas que reciclen este patrón deben copiar:

- shell del área
- top bar del módulo
- tarjeta métrica
- grid editable
- footer de paginación
- diálogo de edición
- navegación por teclado
- selección múltiple
- menú contextual
- navegación entre registros dentro del diálogo

Lo único que puede cambiar por negocio es:

- nombre del módulo
- columnas del grid
- métricas del resumen
- campos del diálogo
- lógica de cálculo propia del dominio

## Propósito de la pantalla

`Asistencia` es la superficie donde RH cierra la asistencia por colaborador y periodo antes de continuar a:

- permisos
- vacaciones
- prenómina
- nómina
- efectivo

No es una pantalla de importación.

No es una pantalla de conciliación.

No es una pantalla de incidencias generales.

Es una pantalla de cierre editable por colaborador y por semana.

## Contrato visual del área

La pantalla usa exactamente el contrato visual vigente de RH:

- header superior con logo `DicsaLogoD`
- título principal `Recursos Humanos`
- subtítulo del módulo `Asistencia`
- fondo del área compartido con RH
- contenedor principal oscuro translúcido
- toolbar lavanda translúcido
- tarjeta métrica lila clara a la derecha
- grid blanco con selección morada
- footer lavanda translúcido
- diálogo claro con acentos morados RH

No se deben introducir:

- tonos verdes para estados primarios
- botones azules ajenos a RH
- listas nativas sin homologación RH
- layout alterno al shell de `Personal`

## Estructura exacta de la pantalla

La pantalla se arma en este orden:

1. `Header` del área RH
2. `Título del módulo`
3. `Toolbar del módulo`
4. `Tarjeta métrica`
5. `Grid editable`
6. `Footer de paginación`

## Contrato del top bar

El top bar replica el patrón de `Personal`.

Debe incluir:

- título `Asistencia`
- botón principal `Editar asistencia`
- bloque derecho de selección
- tarjeta métrica alineada a la derecha debajo del toolbar

### Bloque de selección

Debe mostrar:

- cantidad de registros seleccionados
- leyenda `Shift/Ctrl amplian la selección activa` cuando haya multiselección
- `activeCellLabel` si existe

### Tarjeta métrica

Debe usar el mismo lenguaje visual de `Personal`:

- icono a la izquierda
- etiqueta superior en mayúsculas
- número principal grande
- leyenda inferior `Filtrado (N registros)`

En `Asistencia` el label congelado es:

- `ASISTENCIA RH`

## Contrato del grid

El grid de `Asistencia` es un grid editable homologado al de `Personal`.

### Columnas congeladas

Las columnas actuales son:

- `ID`
- `Nombre`
- `Días laboró`
- `Días faltó`
- `Retardo`
- `Horas extra`
- `Acciones`

### Reglas del grid

- filas blancas con bordes suaves
- fila seleccionada en lila/morado
- hover fino sobre fila
- botón de acciones al extremo derecho
- filtros por columna en header
- selección sincronizada entre mouse y teclado
- scroll principal del grid separado del footer

### Formato de columnas

- `ID`: entero o string corto, centrado
- `Nombre`: nombre del colaborador, peso visual principal
- `Días laboró`: count entero
- `Días faltó`: count entero
- `Retardo`: proporcional de hora, no minutos crudos
- `Horas extra`: proporcional de hora
- `Acciones`: menú contextual de fila

### Formato congelado de cálculo en grid

`Retardo` y `Horas extra` no se muestran como:

- `29 min`
- `01:15`

Se muestran como proporcional horario:

- `0.48 h`
- `1.25 h`

## Contrato de interacción del grid

El grid debe conservar exactamente esta interacción:

- click selecciona fila
- teclado mueve fila activa
- la fila activa por teclado también queda seleccionada visualmente
- `Enter` abre el registro activo
- `Esc` limpia selección o devuelve foco al grid según el estado actual
- click derecho abre menú contextual de fila
- drag entre filas crea selección por rango
- `Ctrl/Cmd` permite selección aditiva
- `Shift` amplía rango de selección

### Regla de sincronización

No puede existir una fila “pintada” por click y otra distinta activa por teclado.

La selección visible y la fila activa deben quedar sincronizadas.

## Contrato del menú de acciones

La última columna usa `EditableRowActionsButton`.

En `Asistencia`, la acción congelada actual es:

- `Editar asistencia`

La acción primero debe preparar la selección de la fila y luego abrir el diálogo.

## Contrato del footer

El footer replica el de `Personal`.

Debe incluir:

- `Anterior`
- `Página X de Y`
- `Siguiente`
- `Filas/pág`
- `Mostrando`
- `Total`
- `Selección`

Los tamaños de página congelados son:

- `40`
- `80`
- `120`

## Contrato del diálogo de edición

El diálogo de `Asistencia` no es libre.

Está congelado como expediente operativo semanal.

### Apertura y cierre

Debe abrir con `ContractDialogShell`.

Debe soportar:

- click fuera para cerrar sin guardar
- botón `X`
- botón `Cancelar`
- `Esc` para cerrar
- `Enter` para guardar

### Navegación dentro del diálogo

Debe soportar navegación entre colaboradores con:

- botón `Anterior`
- botón `Siguiente`
- tecla `←`
- tecla `→`

La navegación lateral solo debe dispararse cuando el usuario no está escribiendo en un campo de texto.

### Shell del diálogo

El diálogo se divide en tres zonas:

1. `Header del diálogo`
2. `Cuerpo en dos columnas`
3. `Footer del diálogo`

### Header del diálogo

Debe incluir:

- título `Asistencia del colaborador`
- subtítulo operativo corto
- chips de contexto:
  - `#ID`
  - empresa o `Empresa pendiente`
  - periodo activo o `Sin periodo activo`
- botón `X` a la derecha

## Contrato del cuerpo del diálogo

El cuerpo se divide en:

- ficha izquierda fija del colaborador
- columna derecha operativa

### Ficha izquierda

La ficha izquierda:

- tiene ancho fijo
- no se desplaza junto con los días
- sí puede tener scroll interno si su contenido crece

Debe incluir:

- nombre del colaborador
- `ID`
- empresa
- separador
- periodo
- `Días laboró`
- `Días faltó`
- `Retardo`
- `Horas extra`
- bloque `Jornadas`

### Jornadas

Si el colaborador tiene varias jornadas en `Personal`, la ficha izquierda debe permitir seleccionar:

- `Automática`
- `Jornada 1`
- `Jornada 2`
- `Jornada 3`

`Automática` significa:

- usar la jornada detectada originalmente para cada día

Si el usuario fuerza una jornada específica, esa jornada se usa para recalcular los días visibles del cierre abierto.

Si no hay jornadas en `Personal`, debe mostrarse explícitamente:

- `No hay jornadas capturadas en Personal.`

### Columna derecha

La columna derecha se divide en:

- `Resumen semanal`
- `Días del periodo`

`Resumen semanal` queda fijo arriba.

`Días del periodo` es la zona con scroll principal.

### Resumen semanal

Debe mostrar mini cards con:

- `DIAS LABORÓ`
- `DIAS FALTÓ`
- `RETARDO`
- `HORAS EXTRA`

Los valores se recalculan en vivo.

### Días del periodo

La sección debe incluir:

- título `Días del periodo`
- subtítulo operativo
- botón `Día` para agregar un día manual

Cada día se representa como tarjeta independiente editable.

## Contrato de cada día

Cada tarjeta diaria representa una fecha del periodo activo.

Debe permitir editar:

- `Estatus`
- `Primer fichaje`
- `Último fichaje`
- notas RH o comentario equivalente

No debe capturar manualmente:

- `Retardo`
- `Horas extra`

Esos dos valores son calculados.

### Lista de estatus

`Estatus` no usa dropdown nativo.

Debe usar picker homologado RH con la misma gramática visual de listas de `Personal`.

### Cálculo de retardo y horas extra

`Retardo` y `Horas extra` se recalculan de inmediato cuando cambia:

- `Estatus`
- `Primer fichaje`
- `Último fichaje`
- jornada seleccionada en la ficha izquierda

La base del cálculo es:

- jornada esperada del día
- primer fichaje
- último fichaje

La presentación en el diálogo debe ser la misma que en el grid:

- proporcional de hora

No debe mostrarse en el diálogo como:

- `hh:mm`
- minutos crudos

Debe mostrarse como:

- `0.48 h`
- `1.25 h`

## Contrato del periodo

`Asistencia` no puede mezclar días fuera del periodo activo.

Si existe rango activo leído desde importaciones/conciliación:

- los fichajes de NGTeco se filtran al rango
- los registros guardados también se filtran al rango
- los días manuales se agregan dentro de esa lógica de cierre

La pantalla no debe construir días abiertos mezclando registros de otras semanas.

## Contrato del footer del diálogo

El footer debe incluir:

- mensaje informativo a la izquierda
- `Anterior` si existe registro previo
- `Siguiente` si existe registro siguiente
- `Cancelar`
- `Guardar asistencia`

`Guardar asistencia` debe usar filled morado RH.

## Contrato de persistencia

La pantalla trabaja con estas tablas:

- `hr_employee_profiles`
- `hr_attendance_import_lots`
- `hr_attendance_daily_records`

### Fuente de verdad funcional

- `Personal` aporta padrón, jornadas y contexto del colaborador
- `Importación y conciliación` aporta periodo activo y lectura fuente
- `Asistencia` guarda el cierre editable por colaborador y día

## Reglas de replicación para futuras pantallas

Las siguientes pantallas deben copiar este contrato base:

- `Vacaciones`
- `Permisos`
- otras superficies semanales editables RH

### Partes que se copian 1:1

- header RH
- top bar del módulo
- tarjeta métrica
- grid editable
- footer del grid
- foco y selección
- menú contextual
- drag selection
- diálogo con ficha izquierda fija
- columna derecha con sección fija superior y zona scrollable inferior
- footer del diálogo con navegación lateral

### Partes que sí cambian por dominio

- columnas del grid
- métricas del resumen
- tipos de estatus
- campos diarios o por registro
- lógica de cálculo del negocio
- textos del módulo

## Prohibiciones

Para futuras pantallas que reciclen este contrato, queda prohibido:

- inventar otro shell
- cambiar el patrón de top bar
- mover la tarjeta izquierda al scroll principal
- volver a usar dropdown nativo para listas RH
- mostrar tiempos en formatos inconsistentes entre grid y diálogo
- capturar manualmente campos que el sistema ya calcula
- mezclar periodos o fichajes fuera del rango activo
- volver a introducir doble `Dialog` o romper el cierre por click fuera

## Estado de congelamiento

Este contrato queda congelado contra la implementación viva de:

- `lib/app/hr/human_resources_attendance_page.dart`

Si `Asistencia` cambia en código, este documento debe actualizarse en la misma intervención.
