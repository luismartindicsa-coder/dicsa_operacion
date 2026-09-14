# Documentación Legal · implementación funcional

Continuación: [Permisos y Trámites funcional](ENTREGA_PERMISOS_TRAMITES_2026-09-14.md). Esa entrega habilita la segunda categoría y promueve los componentes `legal_draft`, `legal_capture` y `legal_workspace` a componentes compartidos; los nombres de archivos aquí describen esta primera entrega.

Continúa la [entrega visual de Legal](ENTREGA_PANTALLAS_LEGAL_2026-09-11.md). El alcance de esta etapa es completar el expediente legal antes de conectar las demás categorías.

**Estado:** Documentación Legal está activada en el proyecto Supabase enlazado `dicsa_operacion`. Se renovó la autorización de la CLI, se inspeccionó el esquema real y se aplicaron las dos migraciones documentales con sus versiones registradas. El recorrido del repositorio pasó contra los servicios reales usando la sesión vigente de la app y dos clientes independientes. Los expedientes y archivos temporales de verificación se retiraron al terminar.

## Recorrido implementado

Gestión Documental → Documentación Legal → Nuevo → captura por secciones → Vista previa → Guardar documento → detalle guardado → Cerrar → lista → Abrir expediente → Editar expediente.

- Nombre, tipo documental, responsable interno existente, folio, autoridad y área.
- Emisión e inicio opcionales. Vencimiento opcional con validación de fechas; un documento sin vencimiento es válido.
- Estatus y prioridad controlados, próxima acción y observaciones.
- Selección de archivo principal y complementarios. Carga a Storage al guardar, límite de 50 MiB por archivo y hasta 30 archivos nuevos por operación.
- Consulta y descarga de archivos guardados mediante enlaces temporales del bucket privado. El detalle muestra usuario de carga, fecha y versión.
- Sustitución del principal sin sobrescribir el anterior. Retiro de complementarios de la versión vigente sin borrar su archivo histórico.
- Historial por versión con autor, fecha y copia de campos/archivos de ese momento.
- Búsqueda por nombre, folio, autoridad y área; filtros por tipo, estatus, responsable y vigencia. Paginación de 50 registros. Orden inicial por fecha de creación descendente y folio ascendente; opciones por nombre y vencimiento.
- Semáforo derivado, sin guardar colores: Completado tiene precedencia; sin fecha es neutral; vencido antes de hoy; crítico de 0 a 5 días; atención de 6 a 15; en tiempo después de 15. Fecha civil de referencia del servidor en `America/Mexico_City`.

El guardado solo anuncia éxito cuando confirma la transacción. Si se pierde la respuesta, conserva la identidad de la solicitud y los archivos subidos; Reintentar verifica esa misma operación. Mientras el resultado sea incierto, la captura permanece bloqueada para evitar cambiar los datos de la solicitud. Una edición de una versión antigua se rechaza con instrucciones para volver a abrir el expediente.

La confirmación de la RPC tiene un límite de 45 segundos; agotarlo conserva la solicitud para un reintento seguro. El conflicto de revisión devuelve `PT409`/HTTP 409. Se evita usar el error de serialización `40001` para una validación de negocio, porque PostgREST puede reintentar esa transacción indefinidamente, como documenta [Supabase](https://supabase.com/docs/guides/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b).

## Contrato de interfaz y arquitectura

Arquetipo `Workflow Master-Detail`: lista de consulta y detalle editable, con referencia funcional de Mantenimiento. Los cambios se guardan como una versión completa del expediente; esta superficie no implementa edición inline ni multiedición de celdas. Reutiliza los controladores de selección y navegación de Entradas y Salidas: selección simple, Cmd/Ctrl, Shift, flechas, Enter para abrir y Escape para salir del detalle guardado o limpiar selección. Click derecho ofrece Abrir expediente respetando la selección.

Se conservan el menú homologado con Finanzas, `ContractDialogShell`, confirmaciones, pickers buscables, calendario y botones contractuales. Los tokens rosas se aplican al shell, filtros, listas, controles y superficies. El semáforo añade color semántico solo al icono, manteniendo texto e iconografía para no depender únicamente del color.

El repositorio obtiene datos mediante RPC y escucha cambios de `documental_records`. Reutiliza `WorkflowRefreshController` y `LifecycleRefreshScope`: refresca al regresar a la app, ante cambios remotos, después del detalle y al cambiar el día operativo. Difiere la recarga mientras el detalle está abierto, conservando los campos en edición.

Sin acceso o sin la migración, la página muestra el error y deshabilita Nuevo. El repositorio en memoria existe exclusivamente en las pruebas; no hay datos ficticios ni fallback local en producción.

## Base de datos desplegada

Migraciones aplicadas: `supabase/migrations/20260914120000_create_documental_legal_foundation.sql` y `supabase/migrations/20260914121000_fix_documental_revision_conflict.sql`. Se preservó la primera versión y se registró la corrección del conflicto en una migración posterior.

| Objeto | Responsabilidad |
| --- | --- |
| `documental_records` | Metadatos vigentes, responsable por UUID, fechas civiles, revisión y auditoría. |
| `documental_files` | Rutas de Storage, rol principal/complementario, versión, usuario/fecha y vigencia. |
| `documental_history` | Historial inmutable por versión, solicitud idempotente y snapshot de datos/archivos. |
| `documental_can_manage()` | Autorización a perfiles activos de Dirección y administración según roles existentes. |
| `documental_context()` | Responsables activos existentes y reloj civil del servidor. |
| `documental_list_records(...)` | Consulta filtrada, ordenada y paginada de Legal. |
| `documental_get_record(uuid)` | Expediente completo con archivos e historial. |
| `documental_save_record(...)` | Guardado atómico, revisión esperada, idempotencia y sustitución versionada. |
| Bucket privado `documental` | Bytes de archivos, con rutas nuevas por carga y enlaces firmados de 120 segundos. |

No se crean usuarios ni se modifican sus roles. El responsable debe corresponder a un perfil activo; la autorización inicial de lectura/escritura se limita a Dirección/administración. Asignar un responsable no le concede por sí solo acceso al área.

Las tablas tienen RLS y permisos de lectura; las escrituras del cliente pasan por la RPC. Las políticas de Storage incluyen restricciones específicas del bucket para que una política permisiva anterior no exponga documentos, permita sobrescribirlos o borrar archivos referenciados. Solo se permite limpiar cargas propias todavía no asociadas a un expediente.

La subida precede a la transacción SQL. Si se confirma que esta falló, se limpian las cargas de esa operación. Si una subida o su limpieza pierde conexión, puede quedar un objeto privado sin referencia; no se borra ningún archivo vinculado al historial. La limpieza programada de esos objetos no forma parte de esta etapa.

## Archivos principales

| Archivo | Cambio |
| --- | --- |
| `lib/app/gestion_documental/gestion_documental_records.dart` | Entidades, consulta, reloj civil y reglas de vigencia. |
| `lib/app/gestion_documental/gestion_documental_store.dart` | Repositorio Supabase, RPC, Storage, realtime y reintentos. |
| `lib/app/gestion_documental/gestion_documental_legal_draft.dart` | Edición local desde una versión guardada y payload de captura. |
| `lib/app/gestion_documental/gestion_documental_legal_capture.dart` | Alta, edición, responsable, archivos, detalle e historial. |
| `lib/app/gestion_documental/gestion_documental_legal_workspace.dart` | Lista funcional, filtros, orden, paginación y refresh diferido. |
| `lib/app/gestion_documental/gestion_documental_category_page.dart` | Integra el workspace en la categoría Legal. |
| `lib/app/gestion_documental/gestion_documental_theme.dart` y `gestion_documental_widgets.dart` | Indicadores de vigencia por tokens semánticos. |
| `pubspec.yaml` y `pubspec.lock` | Declaran `uuid` directamente, manteniendo la versión ya resuelta. |
| `test/gestion_documental/` | Pruebas de navegación, captura, repositorio y vigencia; fixtures aislados. |
| `tool/test_documental_sql.mjs` | Prueba ejecutable de migración, RPC, concurrencia, historial y permisos en PostgreSQL aislado. |

## Verificación

- Ocho pruebas de widgets: navegación y tema, captura y descarte, archivos seleccionados, vencimiento opcional, guardado y edición con historial, fallo de guardado, actualización diferida, filtros, teclado y ventanas de 1440×1000, 800×900 y 390×844.
- Una prueba de dominio con los límites del semáforo y serialización de fechas civiles.
- Dos pruebas del repositorio HTTP: respuesta perdida con reintento sin duplicar subidas y fallo SQL confirmado con limpieza acotada.
- Script SQL aprobado con PGlite 0.5.8: creación de esquema, guardado atómico, idempotencia, conflicto de revisión, sustitución conservando el archivo anterior, rollback, filtros y RLS de tablas/Storage incluso con una política permisiva preexistente.
- Análisis Dart y revisión de formato/diff. Compilación `flutter build macos --debug --no-pub` aprobada.
- Capturas renderizadas revisadas de lista, detalle e historial, además de los tamaños compactos. Son datos de prueba, no registros del proyecto remoto.
- Verificación real aprobada con el repositorio de producción: alta sin vencimiento, reapertura desde otro cliente, reintento idempotente, subida/descarga con comprobación de bytes, sustitución de principal, descarga de la versión histórica, rechazo inmediato de una edición desactualizada, filtros y recepción de realtime. Los datos y archivos temporales fueron eliminados.
- El esquema remoto coincide con `profiles.user_id`, `role` e `is_active`. Se comprobaron RLS en las tres tablas, bucket privado de 50 MiB, publicación realtime e historial de las dos migraciones. La activación no modifica perfiles ni políticas de otros buckets.

Comandos de reproducción desde la raíz de la app:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
```

Para SQL, instalar `@electric-sql/pglite@0.5.8` en un directorio temporal y ejecutar el script con Node, indicando la ruta al módulo si no está en el árbol de dependencias:

```sh
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

No se añade Node ni PGlite como dependencia de la app. La prueba prepara tablas equivalentes de `profiles`, `auth` y `storage`; no sustituye la inspección y prueba del servicio Supabase desplegado.

## Activación y siguiente alcance

La autorización se completó mediante el flujo oficial de Supabase con la sesión existente del navegador. No fue necesario usar la contraseña compartida. La inspección inicial confirmó que no existían tablas, funciones ni bucket documentales. Se validó primero el esquema y las RPC dentro de una transacción con rollback; después se aplicaron únicamente las migraciones documentales y se registraron en `supabase_migrations.schema_migrations`, sin desplegar otras migraciones pendientes.

El perfil activo de Dirección puede ingresar a Gestión Documental → Documentación Legal y utilizar Nuevo. El área obtiene responsables y expedientes del servicio real.

El dashboard y calendario global continúan en su etapa visual. Quedan para sus entregas la conexión de indicadores y eventos a datos, notificaciones, permisos por otras áreas y las demás categorías, comenzando por Permisos y Trámites.
