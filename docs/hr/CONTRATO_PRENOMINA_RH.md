# Contrato: Prenómina RH

Este documento congela cómo debe nacer la pantalla `Prenómina` dentro de RH.

No es una exploración.

No es un mock.

Es un contrato replicable y ejecutable sobre el arquetipo ya congelado en `Asistencia`.

Las referencias base obligatorias son:

- `docs/hr/CONTRATO_ASISTENCIA_RH.md`
- `docs/hr/CONTRATO_VACACIONES_RH.md`
- `docs/hr/CONTRATO_PERMISOS_RH.md`

## Regla madre

`Prenómina` debe copiar 1:1 el contrato visual, de interacción y de shell de `Asistencia`, adaptándolo a una corrida borrador semanal.

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
- reglas de consolidación del borrador
- estados de corrida semanal

## Propósito de la pantalla

`Prenómina` es la superficie donde RH consolida por colaborador lo ya aprobado desde:

- `Asistencia`
- `Vacaciones`
- `Permisos`

Su primera versión debe resolver:

- cuál es el periodo semanal activo
- qué asistencia ya quedó lista para prenómina
- qué vacaciones impactan el borrador
- qué permisos impactan el borrador
- qué colaboradores siguen en revisión RH
- qué ajustes manuales nominales decide RH
- qué observaciones deben acompañar la corrida

No es todavía:

- la nómina final
- el timbrado
- la salida de pago
- la conciliación final con Finanzas

Pero sí debe dejar:

- el borrador semanal trazable
- el estado por colaborador
- la evidencia de ajustes RH

## Relación obligatoria con otros módulos

### Personal

`Prenómina` debe leer de `Personal`:

- `employee_id`
- nombre homologado
- empresa
- salario
- salario percibido

### Asistencia

`Prenómina` debe tomar únicamente cierre semanal ya consolidado desde `Asistencia`.

Regla operativa inicial:

- días en revisión RH no deben contarse como listos
- días justificados por `Vacaciones RH` o `Permisos RH` sí deben entrar como fuente válida
- la corrida borrador no nace directo de importación cruda

### Vacaciones

`Prenómina` debe leer:

- días pagados
- días disfrutados relevantes al periodo
- trazabilidad fiscal sembrada desde `CONTPAQ`
- estado de impacto en prenómina por evento

### Permisos

`Prenómina` debe leer:

- permisos con goce
- permisos sin goce
- incapacidades
- eventos con `impacta prenómina = true`

### Importación y conciliación

`Prenómina` debe usar el periodo activo que viene de importaciones RH.

Reglas:

- no mezclar periodos
- no “tomar el último” ambiguamente
- usar la semana activa como llave de consolidación semanal

## Contrato visual del área

Debe usar exactamente el contrato visual vigente de RH:

- header superior con logo `DicsaLogoD`
- título principal `Recursos Humanos`
- subtítulo del módulo `Prenómina`
- fondo del área compartido con RH
- contenedor principal oscuro translúcido
- toolbar lavanda translúcido
- tarjeta métrica lila clara a la derecha
- grid blanco con selección morada
- footer lavanda translúcido
- diálogo claro con acentos morados RH

## Estructura exacta de la pantalla

La pantalla debe armarse así:

1. `Header` del área RH
2. `Título del módulo`
3. `Toolbar del módulo`
4. `Tarjeta métrica`
5. `Grid editable`
6. `Footer de paginación`

## Contrato del top bar

Debe incluir:

- título `Prenómina`
- botón principal `Editar borrador`
- bloque derecho de selección
- tarjeta métrica alineada a la derecha debajo del toolbar

### Tarjeta métrica

Label congelado:

- `PRENÓMINA RH`

Debe resumir:

- registros visibles
- colaboradores listos
- colaboradores en revisión RH
- vacaciones con huella fiscal
- permisos con huella pendiente

## Contrato del grid

La primera versión debe mostrar estas columnas:

- `ID`
- `Nombre`
- `Sueldo`
- `Asistencia`
- `Vacaciones`
- `Permisos`
- `Estado`
- `Acciones`

## Contrato del diálogo

El diálogo mantiene:

- ficha izquierda fija del colaborador
- scroll solo en la columna derecha
- navegación `←` y `→`
- `Esc`
- `Enter`
- click fuera

### Secciones mínimas del diálogo

- `Resumen fuente`
- `Vacaciones y permisos`
- `Borrador RH`

### Campos mínimos iniciales

- estatus de borrador RH
- ajuste manual nominal
- notas RH

## Regla de negocio de esta primera versión

La primera versión de `Prenómina` no debe fingir fórmulas finales invisibles.

Debe consolidar fuentes reales ya existentes y permitir solo:

- lectura clara
- estatus semanal RH
- ajuste manual controlado
- observación RH

La fórmula final completa de nómina vendrá después, sobre esta base ya limpia.
