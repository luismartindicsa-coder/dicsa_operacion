# Programa operativo semanal de cartón

## Alcance

La página conserva los embarques existentes, su captura, destinos, prioridades,
estados, observaciones y unidades. La proyección histórica sigue disponible
como referencia desplegable. Los cambios ajenos de Gestión Documental y los
cambios previos del card de Embarques se conservaron.

La segunda pestaña programa **lunes a viernes**, a partir de embarques
**confirmados** de paca nacional, limpia y americana. Los registros de sábado,
caple, paca basura y granel permanecen en Embarques y se señalan fuera de este
programa. No se cambian estados ni cantidades de embarques al programar.

## Uso

Los subtabs **Planeado** y **Real** separan la programación de lo ejecutado.
Real precarga Producción de Operación por fecha, turno y material y permite
confirmar o corregir el resultado, conservando la versión planeada como referencia.
Ver [Resultados reales](RESULTADOS_REALES.md) para el efecto en futuras planeaciones.

1. Capturar y confirmar embarques de la semana, o revisar
   [Embarques sugeridos](EMBARQUES_SUGERIDOS_CARTON.md) y usar **Aceptar embarques**
   para incorporar la selección semanal. Se pueden editar después; la generación
   vuelve a leer la lista final de embarques confirmados guardados.
2. Programa operativo precarga el patio inicial del lunes a partir del conteo
   fechado y los movimientos posteriores, o de las condiciones guardadas de la
   semana. Los saldos estimados se señalan en la propuesta y pueden editarse.
   La referencia calculada permite generar sin volver a capturar el patio.
3. Revisar Histórico de Producción: periodo, semanas con registros y promedios
   por material/día/turno. La capacidad diaria parte del percentil 75 de los
   totales diarios observados, o de la capacidad guardada para esa semana.
   Sin historial se conserva el valor editable previo de 100 como configuración,
   no como capacidad verificada. Se pueden ajustar capacidad diaria, porcentaje
   de capacidad del turno día, días laborables y disponibilidad de cada turno.
   La proporción inicial Día/Noche viene de los registros reales; el botón
   Aplicar proporción histórica permite recuperarla después de un ajuste manual.
4. Generar programa semanal: toma los embarques confirmados finales de la semana,
   descuenta el patio disponible de cada material y distribuye la producción
   faltante de lunes a viernes entre día y noche, antes de las fechas de salida.
   Calcula y guarda una nueva versión Borrador; los faltantes por capacidad se
   muestran con su material, fecha y destino.
5. Ajustar celdas o usar Mover producción. La validación se recalcula mientras
   se escribe. Enter confirma una celda; Esc o clic afuera cancela esa edición.
   Guardar nueva versión conserva los ajustes como otra versión persistente.
6. Aprobar fija una sola versión operativa por semana; sus cantidades quedan
   inmutables. Crear nuevo borrador conserva la versión anterior y permite
   cambios. Iniciar ejecución cambia el estado de la versión vigente aprobada.
7. Exportar PDF para operador desde una versión guardada: A4 horizontal con
   logo DICSA, semana/versión/estado y patio inicial. Conserva una sola página
   cuando cabe. Embarques esperados y destino se presentan como una matriz:
   cinco filas de lunes a viernes, una columna por destino y total por día.
   Cada celda consolida las cargas del mismo destino/día y separa cantidades por
   material. El total semanal queda debajo de la tabla. Todos los destinos se
   mantienen en la misma matriz, sin crear otra fila por cada embarque.
   La producción mantiene su tabla por material y turno, totales y cuadre contra
   patio utilizado. El PDF excluye las condiciones y observaciones completas,
   incluidas las explicaciones automáticas de sugerencias; estas siguen en la app.
   Los faltantes de producción conservan sus alertas por fecha, material y destino.
   El encabezado identifica la versión exportada y las continuaciones se numeran.
   El botón confirma la ruta guardada y muestra cancelaciones o errores junto
   a la acción; el refresco automático conserva ese resultado.
8. Abrir Producción real vs programada para comparar fecha, turno y material.

## Reglas del cálculo

- El patio se asigna primero por material y por fecha/prioridad del embarque.
- La producción cubre únicamente la demanda neta restante; el historial no crea
  demanda ni cantidades adicionales.
- El turno día puede cubrir su fecha; la noche solo fechas posteriores. Nunca
  se borra un faltante anterior porque haya producción posterior.
- La capacidad diaria se comparte entre los tres materiales. Día y noche tienen
  cupos según el porcentaje configurado. Un turno bloqueado pierde su cupo;
  no lo transfiere automáticamente al otro.
- La proporción inicial Día/Noche usa el histórico real de los tres materiales
  (50/50 si falta historial, con aviso explícito). Puede ir de 0% a 100%.
- Se asume capacidad nominal de C1 50% y C2 50%, indicado en la pantalla.
  Las pérdidas activas por máquina se suman con tope de 100%; la pérdida diaria
  total es el promedio de ambas, redondeado hacia arriba. Cambios de maquinaria
  se incorporan al volver a generar y se verifican en la base antes de aprobar.
- Se asigna la máxima cantidad factible según fechas, respetando prioridades en
  empates. Una búsqueda de factibilidad minimiza la mayor carga diaria relativa
  al ritmo histórico de cada día, considerando turnos utilizables y maquinaria.
  Sin datos históricos se conserva el equilibrio de cantidades entre días.
- Con los totales diarios equilibrados, un flujo de costo mínimo asigna conjuntamente
  materiales a turnos según sus frecuencias históricas. Así, el orden de captura
  de los embarques no acapara los turnos habituales de otro material. Los límites
  por turno son compartidos y ningún material puede usar producción posterior a
  su fecha de salida. La preferencia combina 80% del promedio del mismo día/turno
  y 20% del promedio de ese turno del material entre los cinco días, para moderar
  concentraciones en una sola celda histórica. El costo aumenta con cada paca
  asignada a una celda y a un turno, evitando concentraciones cuando las
  preferencias históricas empatan. Esto orienta el reparto, no crea demanda.
- Se conservan faltantes por embarque/destino/material/fecha y se distinguen
  falta de capacidad y producción no asignada a tiempo, con restricciones
  relevantes de patio, días, turnos y maquinaria.
- El saldo diario muestra patio más producción menos demanda acumulada; los
  faltantes siguen identificados en la fecha original aunque cambie el saldo.

## Integración con Producción de Operación

- Fuente actual: las salidas de `material_transformation_runs_v2` y
  `material_transformation_run_outputs_v2`, las mismas capturadas en Producción
  de Operación. Se leen pacas reales, fecha operativa, turno y material comercial.
- Ventana: seis semanas completas anteriores al lunes del programa. Se excluyen
  la semana programada, fechas futuras, sábados, domingos, kg y otros materiales.
  No se convierten turnos desconocidos en turno día; se informa su exclusión.
- Se usa `production_runs` solo para semanas sin registros de pacas en la fuente
  actual. No se suman ambas fuentes para la misma semana y los registros a granel
  no ocultan las semanas anteriores de pacas. Las consultas están paginadas con
  orden estable y filtran las fechas desde la relación con la corrida.
- Los promedios se dividen entre las semanas con registros utilizables. Se muestra
  cuántas de las seis aportan datos. Dentro de esas semanas, un día sin captura
  aporta cero; una semana completa sin registros no se interpreta como producción cero.
- Un material sin historial usa el patrón general con aviso. Un día sin historial
  usa la referencia diaria general, también con aviso. Superar el promedio observado
  de un turno ajustado por maquinaria genera una advertencia; el promedio no es una
  capacidad física rígida ni puede sustituir la demanda de embarques menos patio.
- El histórico agregado se guarda en `conditions.production_history` junto con
  cada versión. Al generar se toma el histórico actualizado; las versiones anteriores
  y aprobadas conservan su referencia. Los cambios de Operación provocan recarga
  silenciosa del origen, sin regenerar ni modificar versiones guardadas.
- Las versiones antiguas siguen abriendo. Para incorporar la referencia se debe
  generar un nuevo borrador. El PDF identifica el periodo y cobertura de la referencia.

## Persistencia y despliegue

La migración `supabase/migrations/20260915100000_create_direction_operating_programs.sql`
está aplicada al proyecto Supabase `pjxncveymixxdntplchb` y registrada con la
versión `20260915100000` en `supabase_migrations.schema_migrations`.
Se verificaron las dos tablas con RLS, las seis funciones, sus permisos y el
índice de versión operativa única. Los 17 embarques existentes se conservaron;
el despliegue no creó programas ni líneas de prueba. También se validó previamente
en PostgreSQL aislado (PGlite).

La vinculación histórica usa el campo JSON `conditions` existente y no requiere
otra migración. Se probó que guardar y aprobar conserva la referencia histórica.

Tablas nuevas:

- `direction_operating_programs`: semana, número de versión, estado, marca de
  versión operativa, condiciones, copia de embarques y auditoría de creación,
  aprobación e inicio de ejecución.
- `direction_operating_program_lines`: 30 celdas de fecha relativa/turno/material
  con cantidad, relacionadas con una versión.

Todas las cantidades/condiciones se guardan como versiones nuevas mediante RPC
atómico. No hay escritura directa de líneas para usuarios autenticados.
La aprobación valida límites por turno, bloqueos y demanda acumulada hasta el
turno día de cada fecha. Se rechazan embarques o afectaciones que cambiaron desde
el borrador. Un bloqueo transaccional por semana y un número esperado de versión
protegen contra guardados concurrentes. Solo hay una versión vigente aprobada o
en ejecución; las anteriores permanecen en el historial.

Los perfiles activos `direccion`, `admin` y `ops_manager` pueden gestionar el
programa. Las tablas tienen RLS y las funciones validan estos permisos.

La producción real se lee de las mismas fuentes, con selección por semana del
histórico anterior de `production_runs` cuando no hay pacas en la fuente actual.
Las referencias aprobadas no se recalculan a partir de la producción real.

## Metas automáticas de Gerencia

La migración `20260921200000_sync_operating_program_gerencia_goals.sql` conecta
la aprobación del programa con el plan semanal de Gerencia en la misma
transacción. Si la sincronización falla, tampoco se cambia la versión operativa.
Aplicada al proyecto Supabase vinculado el 21 de septiembre de 2026.

- Guardar o generar un borrador no modifica metas. Al aprobarlo, se crea la semana
  en Gerencia si falta y se reemplazan las metas de los tres materiales de cartón.
- Meta de embarque: suma de los embarques confirmados incluidos en la copia
  aprobada, de lunes a viernes. No incluye planeados, kilos ni el sábado.
- Meta de producción: suma de las cantidades programadas en ambos turnos de
  lunes a viernes. El patio puede hacer que esta meta sea menor que los embarques;
  la producción adicional programada también queda incluida.
- Nacional corresponde a `revuelto` en Gerencia; Limpio a `limpio` y Americano a
  `americano`. Un material retirado de una nueva versión queda con meta cero.
- Una nueva aprobación sustituye las metas de esa misma semana y conserva los
  identificadores, notas, estado y datos reales. Iniciar ejecución no vuelve a sumarlas.
- Gerencia muestra la versión de origen. Las cantidades vinculadas se ajustan
  mediante otra aprobación en Dirección; las notas siguen siendo editables.
- La aplicación invalida la caché y avisa a las vistas de Gerencia al aprobar.
  Los cambios en las líneas también se publican por Realtime para otros equipos,
  con la recarga periódica existente como respaldo. Un diálogo abierto difiere
  el refresco y la base impide que una edición anterior sobrescriba metas vinculadas.
- Las semanas cerradas o canceladas no se sobrescriben: aprobar otra versión de
  esas semanas devuelve un conflicto y conserva el programa anterior.
- El despliegue vincula las versiones operativas ya aprobadas de la semana
  actual y futuras, salvo semanas cerradas o canceladas. No altera metas históricas.

La prueba SQL `tool/test_direction_gerencia_goals_sql.mjs` ejecuta las migraciones
reales en PostgreSQL temporal y verifica creación, sustitución, turnos, materiales,
patio, exclusiones, permisos y reversión de ambas partes ante conflictos.
`test/direction/operating_program_gerencia_test.dart` comprueba la recarga inmediata
de la caché, la notificación a las vistas y la edición de notas sin reenviar metas.

## Validación

```sh
flutter test --no-pub test/direction
dart analyze lib/app/direction/operating_program lib/app/direction/direction_shipments_page.dart lib/app/direction/direction_shipments_store.dart test/direction
DICSA_PGLITE_MODULE=/ruta/a/pglite/dist/index.js node tool/test_direction_operating_program_sql.mjs
DICSA_PGLITE_MODULE=/ruta/a/pglite/dist/index.js node tool/test_direction_gerencia_goals_sql.mjs
```

Las pruebas cubren patio por material, turno nocturno, plazos, equilibrio diario,
festivos, turnos bloqueados, maquinaria, ajustes, filtrado de demanda, versiones,
aprobación, permisos, conflictos, pantalla compacta y exportación. Se incluyen 250
combinaciones deterministas de condiciones para comprobar la factibilidad.
La integración histórica añade otras 150 combinaciones de historial y restricciones,
pruebas de reparto por día/material/turno, lectura de más de 1,000 registros,
separación de fuentes y unidades, referencias persistentes y pantalla compacta.
