# Importación de permisos y disfrutes de vacaciones

El historial anterior al periodo 37 se carga como eventos normales editables. Los pagos de vacaciones siguen siendo eventos independientes; importar disfrutes no crea pagos ni recibos.

## Reglas de la carga

- Ejercicio 2026 y fechas anteriores al 4 de septiembre de 2026.
- Identidad exacta o alias inequívoco contra Personal; no crear perfiles con datos faltantes.
- Sin goce cuando no está indicado, salvo un motivo explícito de compensación de tiempo.
- Conservar horas decimales documentadas sin inventar horarios.
- Separar fechas no consecutivas y permisos que cruzan periodos; conservar cantidades de vacaciones capturadas.
- Deduplicar filas repetidas manteniendo todas las referencias de origen.
- Conservar datos pendientes y fechas futuras fuera del lote aplicado.
- Mantener los pagos y cálculos existentes. Recalcular únicamente los contadores de saldo a partir de los eventos.
- Los eventos históricos nuevos llevan impacto de asistencia y prenómina desactivado para no reescribir semanas capturadas. Los disfrutes aplicados sí consumen saldo anual.

La procedencia queda en `import_source` para vacaciones y `source_snapshot` para permisos: archivo, huella SHA-256, hoja, fila, registro de origen y decisiones confirmadas. Los guardados normales del editor no reemplazan esa procedencia.

## Corrección del editor de permisos

Los permisos importados con duración pero sin hora inicial/final conservan sus horas al abrir, normalizar y guardar. En ese caso el campo Horas admite captura decimal directa. Al existir horas inicial/final válidas, la duración vuelve a calcularse desde el horario. Los eventos manuales mantienen su comportamiento anterior.

## Validación

Se ensayó la transacción con reversión antes de aplicarla. La verificación compara saldos/eventos contra el plan y confirma que Personal, asistencia, borradores de prenómina, cierres, impactos por periodo y cálculos de vacaciones permanecen intactos. Las claves de origen e identificadores son deterministas para impedir una segunda carga del mismo lote.

Las pruebas cubren duración importada, edición sin horario, preservación de procedencia, compatibilidad de tipos con la base, separación de pago/disfrute y reglas de vacaciones pagadas previamente. También se validó el lote con los modelos reales de Flutter.

El resultado detallado con datos de colaboradores se mantiene únicamente en la carpeta local privada `.local/hr_events_history_2026_import/RESULTADO.md`, fuera del repositorio de la app.
