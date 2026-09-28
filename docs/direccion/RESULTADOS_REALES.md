# Resultados reales de Embarques y Programa operativo

Cada sección tiene subtabs **Planeado** y **Real**. Real precarga Operación y permite confirmar o corregir en Dirección. En Embarques, confirmar también actualiza la agenda de Planeado con lo ejecutado. Las capturas originales de Operación y las versiones del Programa operativo se conservan.

- Embarques: un renglón por fecha, destino normalizado y material, de lunes a sábado. Se pueden registrar salidas no planeadas. Las cantidades por carga se separan con comas para conservar el tamaño habitual de los embarques.
- Producción: un renglón por fecha, turno y material de cartón, de lunes a viernes. Las 30 combinaciones aparecen aunque no exista captura.
- `Sin captura` no equivale a cero. Cero requiere confirmación explícita. No se permite confirmar fechas futuras.
- La primera confirmación guarda el total y detalle planeado como referencia. En producción usa la versión guardada seleccionada, no los cambios sin guardar del borrador. Correcciones posteriores conservan esa referencia.
- Si Operación cambia después de confirmar, se muestra una advertencia. **Usar dato de Operación** desactiva la corrección y conserva su historial. En Embarques también restaura las cantidades y estados anteriores; las cargas nuevas quedan canceladas. Si hubo cambios manuales posteriores en la agenda, se pide volver a confirmar antes de restablecer para no sobrescribirlos.

## Efecto en la planeación

Los totales confirmados sustituyen los registros equivalentes; no se suman a ellos. Los días terminados ajustan el historial por turno y material, la distribución del Programa operativo y las estimaciones de producción. Los embarques confirmados ajustan frecuencia, volumen y tamaño habitual de carga. Las ventanas históricas y los límites de capacidad y abastecimiento siguen vigentes: registrar un resultado no modifica automáticamente un programa ya guardado.

## Agenda de embarques desde Real

- Cada carga positiva confirmada queda como `embarcado`, con su cantidad real. Se reutilizan primero los renglones del mismo día, destino normalizado y material; se prefieren cantidades coincidentes para conservar sus identificadores y referencias de ingresos.
- Las cargas previstas que no se realizaron quedan como `cancelado`. Confirmar `0` cancela el grupo de ese día, destino y material. Sus cantidades anteriores siguen visibles como referencia, pero ya no reservan inventario ni generan ingreso previsto.
- Si sobran cargas reales, se agregan renglones nuevos como `embarcado`. Una confirmación de cero sin plan previo no crea un renglón vacío.
- Corregir o confirmar nuevamente actualiza los mismos renglones, sin duplicarlos. Las cancelaciones manuales anteriores no se reactivan; las hechas por Real sí pueden reutilizarse al corregir.
- El detalle original permanece en la primera referencia guardada y cada revisión conserva la agenda antes/después. El Programa operativo ya guardado no cambia.
- La actualización inicial aplica confirmaciones existentes únicamente si la agenda todavía coincide con su referencia. Si hubo ediciones posteriores, Real indica **Agenda pendiente de actualizar** y ofrece **Actualizar agenda**.

Los renglones creados o modificados automáticamente no se consideran capturas nuevas de Operación. Se conserva el origen anterior para evitar que Real se retroalimente, marque falsas diferencias o duplique salidas en el piso y el historial. Los compromisos activos restantes se calculan sobre la agenda actual.

El conteo físico de piso sigue siendo la referencia. Confirmar sin cambiar cantidades conserva horas y maquinaria de los registros originales. Una corrección diaria sin hora comparable puede dejar el piso como estimado. La producción del día en curso conserva la lectura de Operación; las correcciones de producción entran al cálculo histórico al día siguiente.

## Persistencia y validación

Migraciones: `20260923190000_direction_execution_actuals.sql` y `20260925180000_sync_real_shipments_agenda.sql`.

`direction_execution_actuals` guarda el resultado vigente y su revisión; `direction_execution_actual_revisions` conserva cada cambio con usuario, fecha y referencia original. El RPC `direction_save_execution_actual` valida permisos de Dirección, cantidades, fechas, materiales, desglose por carga y concurrencia. La confirmación y su efecto en la agenda se guardan en una sola transacción; si falla cualquiera, se revierte todo. Los auxiliares internos de sincronización no se exponen al cliente.

Pruebas: `direction_execution_test.dart`, `direction_execution_view_test.dart` y `tool/test_direction_execution_sql.mjs` y `tool/test_direction_execution_agenda_sql.mjs`, además de regresiones de inventario, sugerencias y programa. Cubren precarga, deduplicación, cero, restauración, referencia inmutable, cambio de fuente, Enter/Esc, persistencia de la captura durante refresh, revisiones y permisos.

Validación del 23/09/2026: 100 pruebas Flutter aprobadas, pruebas SQL locales aprobadas, análisis estático sin incidencias, captura visual revisada y compilación macOS debug correcta. Migración aplicada en el proyecto vinculado. Se envió la recarga a la sesión Flutter del proyecto; la comprobación nativa mostró Dirección operativa, pero el control de navegación nativa no permitió verificar los subtabs en esa sesión.

Actualización del 25/09/2026: sincronización de Real con la agenda implementada y migración aplicada en el proyecto vinculado. Pruebas SQL de estados, cargas adicionales, reversión, correcciones, concurrencia y aplicación de confirmaciones previas aprobadas; 90 pruebas Flutter aprobadas, análisis estático sin incidencias y compilación macOS debug correcta.
