# Auditorías · implementación funcional

Continúa la [entrega de Mantenimiento](ENTREGA_MANTENIMIENTO_2026-09-14.md). La undécima categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914235950_enable_documental_audits.sql` está aplicada y registrada; su contenido remoto coincide exactamente con el archivo local.

## Recorrido y campos

Gestión Documental → Auditorías → Nuevo → Datos generales / Programación y vigencia / Documentación / Resultados y seguimiento → Vista previa → Guardar documento.

Tipos controlados: Certificación, Externa, Interna, Regulatoria y Seguimiento. Conserva folio, área, responsable interno, estado, prioridad, avance entero de 0 a 100 y observaciones.

- **Organismo / auditor:** nombre requerido de quien lleva a cabo la revisión. Permite identificar tanto organismos externos como responsables de auditorías internas.
- **Fecha programada y fecha realizada:** fechas opcionales e independientes. La realización puede ser anterior o posterior a lo programado. Se conservan también emisión, inicio y vencimiento documental, sin mezclarlos con estas fechas.
- **Resultado:** picker opcional con Con observaciones, Conforme, No aplica y No conforme. Puede quedar sin registrar mientras se recibe el informe. El resultado no cambia automáticamente el estado ni el avance del expediente; ambos representan su seguimiento operativo.
- **Hallazgos:** texto de varias líneas, conservado por versión.
- **Acciones pendientes:** texto de varias líneas separado de los hallazgos y las observaciones, reutiliza `next_action` con la etiqueta propia de Auditorías.
- **Observaciones:** notas generales del expediente, independientes del resultado, hallazgos y acciones pendientes.
- **Evidencia / documento final (principal):** informe privado con sustitución e historial; admite anexos complementarios y expedientes aún pendientes de documentación.

La lista muestra Auditoría, Organismo, Responsable, Programada, Vencimiento, Resultado, Prioridad, Estado/Semáforo y Avance. La búsqueda incluye organismo, folio, resultado, hallazgos y acciones pendientes, además de los datos comunes. Mantiene filtros compartidos, paginación de 50 registros y orden inicial por creación descendente y referencia ascendente. El orden adicional **Fecha programada** coloca las fechas más próximas primero y los expedientes sin programar al final.

El semáforo conserva el criterio documental compartido de estado y vencimiento. El resultado de la auditoría se presenta en una columna o badge independiente.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, mediante workspace y captura compartidos. Conserva navegación de referencia Finanzas, tokens rosas, controles y teclado homologados, refresh automático diferido durante la edición y tarjetas desplazables en ventanas compactas. Encabezados y filas usan la misma definición de columnas.

El modelo incorpora `audit_result` y `audit_findings`, y reutiliza `authority`, `scheduled_date`, `performed_date`, `next_action` y `observations`. `documental_save_record` habilita Auditorías y valida tipo, organismo, resultado y avance. Conserva el guardado atómico del registro, archivos e historial y descarta campos exclusivos de otras categorías. `documental_query_records` devuelve los nuevos datos; permite buscar hallazgos y acciones pendientes dentro de Auditorías y ordenar por programación.

Se conservan enlaces firmados, almacenamiento privado, snapshots históricos, reintento idempotente y conflicto `PT409`. Cambiar organismo, resultado, hallazgos, acciones o fechas conserva los valores y archivos anteriores.

## Verificación

- 25 pruebas Flutter aprobadas. El nuevo recorrido comprueba organismo requerido, tipo y resultado mediante pickers, fechas por calendario y teclado, búsqueda por hallazgos y acciones, filtro de tipo, orden por programación, seguimiento, refresh diferido, reprogramación, sustitución de informe e historial. Verifica que cambiar el resultado a Conforme no modifica el estado Pendiente ni el vencimiento.
- Capturas revisadas de datos generales, programación, resultados, vista previa, lista e historial. Lista comprobada en 1440×1000, 800×900 y 390×844 sin overflow. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con trece migraciones: tipos y resultados controlados, normalización, organismo requerido, fechas independientes, historial de resultado/hallazgos/acciones, búsquedas, programación, registros aún sin resultado ni fechas, separación por categoría y rechazo de datos inválidos. Comprueba que el proceso puede marcarse Completado aun cuando su resultado sea No conforme. Mantiene las verificaciones previas de RLS, archivos, idempotencia, conflictos y guardado atómico.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: contexto, alta, lectura, búsqueda de acciones, resultado y fechas comprobados en una transacción con rollback.

- Once recorridos reales aprobados con el repositorio de producción y dos clientes: Legal, Trámites, Seguridad, Medio Ambiente, Vehículos, Personal, Protección Civil, Contratos, Seguros, Mantenimiento y Auditorías. Comprueban alta, reapertura, reintento idempotente, descarga con comparación de bytes, sustitución conservando el archivo anterior, conflicto, filtros y realtime. Auditorías verifica además organismo, resultado, hallazgos, acciones y fechas actuales e históricas. La auditoría final confirmó cero expedientes de prueba, metadatos, entradas históricas y objetos del bucket documental. Se envió la recarga a la instancia macOS en ejecución.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Con esta entrega quedan habilitadas las once categorías documentales. La conexión posterior del Dashboard y Calendario se documenta en la [entrega de Dashboard y Calendario](ENTREGA_DASHBOARD_CALENDARIO_2026-09-14.md).
