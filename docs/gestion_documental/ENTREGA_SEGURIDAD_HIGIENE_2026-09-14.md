# Seguridad e Higiene · implementación funcional

Continuación: [Medio Ambiente funcional](ENTREGA_MEDIO_AMBIENTE_2026-09-14.md), con autoridad ambiental, autorización e instalación conservadas por versión.

Continúa la [entrega de Permisos y Trámites](ENTREGA_PERMISOS_TRAMITES_2026-09-14.md). La tercera categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`, mediante los permisos existentes. La migración `20260914230000_enable_documental_safety.sql` está aplicada y registrada; el contenido remoto coincide con el archivo local.

## Recorrido

Gestión Documental → Seguridad e Higiene → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados: Capacitación, DC3, Dictamen, Documentación STPS, Equipo, Estudio, Inspección, Obligación y Programa. La captura incluye nombre de documento o actividad, autoridad/entidad, área/departamento, responsable interno existente y folio.

Campos propios de esta categoría:

- **Trabajador relacionado:** vínculo opcional por UUID con `employees`. El picker consulta únicamente identificador y nombre de trabajadores activos. Permite quitar la relación para un registro de área o de alcance general. Si el trabajador de un documento existente queda inactivo, conserva esa relación y puede seguir editándose; no se permite asignar un inactivo a un documento nuevo.
- **Tipo de estudio:** selección opcional entre Condiciones térmicas, Ergonomía, Iluminación, Otro, Ruido, Sustancias químicas y Vibraciones. Es una clasificación documental; no calcula obligaciones ni determina qué estudio corresponde.
- **Proveedor / capacitador:** nombre descriptivo opcional de quien emite o realiza la actividad. No crea proveedores en los catálogos comerciales.
- **Periodicidad:** opcional, con catálogo Anual, Bimestral, Mensual, Por evento, Semestral, Sin periodicidad, Trimestral y Única. No calcula ni cambia fechas automáticamente.

Vigencia mantiene emisión e inicio opcionales y admite documentos sin vencimiento. Seguimiento incluye estatus, prioridad, avance entero de 0 a 100, próxima acción y observaciones. El avance se captura explícitamente y es independiente del estatus.

La lista muestra Documento/actividad, Trabajador/área, Responsable, Vencimiento, Días, Prioridad, Estado/Semáforo, Avance y acciones. La acción rápida abre Seguimiento con foco en Avance. Los datos específicos completos aparecen en el detalle y en cada versión del historial.

La búsqueda incluye nombre, folio, autoridad, área, nombre asociado del trabajador, proveedor, estudio y periodicidad. Se mantienen filtros por tipo, estatus, responsable, vigencia y prioridad, paginación de 50 y orden inicial por creación descendente y folio ascendente. Las tres categorías consultan exclusivamente sus registros.

## Contrato y conservación de datos

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, reutilizando la infraestructura homologada de Legal y Trámites y los controladores compartidos de selección, foco y teclado de Entradas y Salidas. Se conserva la navegación homologada con Finanzas y la paleta rosa en todas las superficies y controles. En tamaños compactos los registros usan tarjetas desplazables.

El guardado, los adjuntos privados, la sustitución del principal sin borrar versiones anteriores, las descargas firmadas, la auditoría, el reintento idempotente y el conflicto `PT409` se reutilizan. El refresh se difiere mientras el expediente está abierto. Los días restantes y el semáforo continúan usando la fecha civil del servidor en America/Mexico_City.

El nombre asociado del trabajador se obtiene del catálogo en el servidor durante cada guardado; no se acepta un nombre enviado por el cliente como fuente de verdad. Cada snapshot conserva el nombre y los campos de esa versión. Cambiar el nombre o estado del trabajador no reescribe el historial documental.

## Modelo desplegado

- Columnas nuevas en `documental_records`: `related_employee_id`, `related_employee_name`, `study_type`, `provider_name`, `periodicity`. El identificador tiene FK a `employees`, con relación nullable y `on delete set null`; los snapshots históricos permanecen intactos.
- `documental_save_record` habilita Seguridad e Higiene, valida su catálogo y avance, verifica la relación con el trabajador y guarda los campos específicos dentro de la misma transacción y versión que los archivos.
- `documental_query_records` admite la tercera categoría y devuelve/busca sus campos específicos. Conserva la firma anterior y el aislamiento de categorías.
- `documental_safety_context` devuelve el contexto documental y las opciones de trabajadores activos, protegido por `documental_can_manage`. Solo Seguridad e Higiene solicita este contexto; Legal y Trámites conservan su RPC de contexto original.
- No cambia la autorización: el rol activo `gestion_documental`, Dirección y administración conservan sus accesos existentes. No se modifican usuarios, roles ni tablas de RH.

Archivos modificados: `gestion_documental_records.dart`, `gestion_documental_record_draft.dart`, `gestion_documental_record_capture.dart`, `gestion_documental_records_workspace.dart` y `gestion_documental_store.dart`, dentro de `lib/app/gestion_documental/`. La categoría existente se activa mediante el registro de tipos compartido.

## Verificación completada

- 17 pruebas Flutter aprobadas, incluidas las regresiones de acceso, Legal y Trámites. El nuevo recorrido cubre alta, campos propios, pickers con foco, vínculo con trabajador, retiro del vínculo, avance 40→80, periodicidad Anual→Semestral, historial, filtros y refresh diferido.
- Capturas revisadas a 1440×1000, 800×900 y 390×844; sin overflow de layout. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con las cinco migraciones documentales: datos específicos, catálogo de trabajadores, nombre obtenido del servidor, conservación del nombre histórico, trabajador inactivo preservado pero no asignable a nuevos registros, campos opcionales vacíos, avance, validaciones, aislamiento de categorías y denegación con perfil desactivado. Se mantienen los escenarios previos de archivos, RLS, historial, idempotencia y conflictos.
- Verificación en Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: acceso al contexto de trabajadores y guardado/consulta de Seguridad e Higiene; toda la transacción de prueba se deshizo con rollback.
- Tres recorridos reales usando el repositorio de producción y dos clientes: Legal, Trámites y Seguridad. Comprobaron alta, reapertura, reintento, descarga de bytes, sustitución conservando archivo histórico, conflicto, filtros y realtime. Seguridad comprobó relación/nombre del trabajador, proveedor y cambio de periodicidad conservando el valor anterior en el historial. Los registros, versiones y objetos temporales se retiraron al terminar.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Medio Ambiente.
