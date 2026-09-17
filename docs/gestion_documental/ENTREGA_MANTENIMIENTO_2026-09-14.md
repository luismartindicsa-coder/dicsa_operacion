# Mantenimiento · implementación funcional

Continúa la [entrega de Seguros](ENTREGA_SEGUROS_2026-09-14.md). La décima categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914235945_enable_documental_maintenance.sql` está aplicada y registrada; su contenido remoto coincide exactamente con el archivo local.

## Recorrido y campos

Gestión Documental → Mantenimiento → Nuevo → Datos generales / Programación y vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados: Certificado, Contrato, Evidencia, Inspección periódica, Mantenimiento obligatorio y Programa. Conserva folio, emisor/certificador, área, responsable interno, estado, prioridad, avance entero de 0 a 100, próxima acción y observaciones.

- **Equipo / instalación / alcance:** descripción requerida de lo que cubre el documento. Permite registrar equipos, instalaciones o programas que abarcan varias áreas sin crear catálogos operativos.
- **Proveedor / servicio:** nombre opcional del proveedor asociado al expediente.
- **Periodicidad:** picker opcional que reutiliza el catálogo documental: Anual, Bimestral, Mensual, Por evento, Semestral, Sin periodicidad, Trimestral y Única.
- **Fecha programada:** fecha opcional de la actividad o inspección; visible en una columna propia de la lista y en las tarjetas compactas.
- **Fecha realizada:** fecha opcional independiente, que puede ser anterior o posterior a la programada. Capturar una fecha realizada no cambia automáticamente el estado del expediente.
- **Emisión, inicio y vencimiento:** vigencia del documento, separada de su programación y realización. Se permite guardar documentos sin vencimiento; si se especifica, no puede ser anterior al inicio.
- **Documento principal y complementarios:** contratos, certificados y evidencias privados, con sustitución y acceso a versiones históricas.

La periodicidad describe el expediente. Reprogramar conserva las fechas anteriores en el historial; no genera recurrencias automáticamente. Esta entrega sigue el alcance documental y de calendarización del planteamiento original, sin sustituir el mantenimiento operativo.

La lista muestra Documento/actividad, Equipo/instalación, Responsable, Programada, Vencimiento, Días, Prioridad, Estado/Semáforo y Avance. Busca por título, folio, alcance, proveedor, periodicidad, emisor y área. Mantiene filtros compartidos, paginación de 50 registros y orden inicial por creación descendente y referencia ascendente. El orden adicional **Fecha programada** muestra las fechas más próximas primero y deja los registros sin programar al final.

El semáforo y los días restantes siguen usando el vencimiento documental. La columna Programada identifica por separado la agenda de la actividad.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, mediante workspace y captura compartidos. Conserva navegación de referencia Finanzas, tokens rosas, controles y teclado homologados, refresh automático diferido durante la edición y tarjetas desplazables en ventanas compactas. Encabezados y filas obtienen sus columnas de la misma definición, incluida Programada.

El modelo incorpora `maintenance_subject`, `scheduled_date` y `performed_date`, y reutiliza `provider_name` y `periodicity`. `documental_save_record` habilita Mantenimiento, valida alcance, tipo, periodicidad y avance, y mantiene el guardado atómico de registro, archivos e historial. Los campos exclusivos de otras categorías se descartan. `documental_query_records` devuelve los datos propios y admite búsqueda y orden por programación.

Se conservan enlaces firmados, almacenamiento privado, snapshots históricos, reintento idempotente y conflicto `PT409`. Actualizar alcance, proveedor, periodicidad, programación o realización conserva los valores y archivos anteriores.

## Verificación

- 24 pruebas Flutter aprobadas: 23 recorridos previos y el nuevo recorrido de Mantenimiento. Este último verifica alcance requerido, selección de periodicidad, fechas por calendario y teclado, búsqueda, orden por fecha programada, seguimiento, refresh diferido, reprogramación, sustitución de evidencia e historial. El ajuste de su prueba de navegación desplaza el dashboard hasta la tarjeta Mantenimiento antes de abrirla.
- Capturas revisadas de datos generales, programación, vista previa, lista e historial. Lista comprobada en 1440×1000, 800×900 y 390×844 sin overflow. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con doce migraciones: tipos, normalización, programación y realización independientes, orden cronológico con fechas vacías al final, periodicidad controlada, historial, búsqueda, separación por categoría, alcance requerido, rechazo de datos inválidos y denegación a perfiles inactivos y sin acceso. Mantiene las verificaciones previas de RLS, archivos, idempotencia, conflictos y guardado atómico.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: contexto, alta, lectura, búsqueda y persistencia de programación comprobados en una transacción con rollback.

- Diez recorridos reales aprobados con el repositorio de producción y dos clientes: Legal, Trámites, Seguridad, Medio Ambiente, Vehículos, Personal, Protección Civil, Contratos, Seguros y Mantenimiento. Comprueban alta, reapertura, reintento idempotente, descarga con comparación de bytes, sustitución conservando el archivo anterior, conflicto, filtros y realtime. Mantenimiento verifica además alcance, proveedor, periodicidad y fechas actuales e históricas. Todos los registros y archivos temporales fueron retirados; la auditoría final confirmó cero expedientes de prueba, metadatos, entradas históricas y objetos del bucket documental. Se envió la recarga a la instancia macOS en ejecución.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Auditorías.

Continuación: [Auditorías implementadas](ENTREGA_AUDITORIAS_2026-09-14.md).
