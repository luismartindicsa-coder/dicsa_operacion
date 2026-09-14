# Permisos y Trámites · implementación funcional

Acceso posterior: [usuario gestion@dicsamx.com y rol documental](ACCESO_USUARIO_GESTION_2026-09-14.md), con entrada directa al dashboard y permisos para trabajar en las categorías habilitadas.

Continúa la [entrega funcional de Documentación Legal](ENTREGA_LEGAL_FUNCIONAL_2026-09-14.md). Permisos y Trámites queda conectado al proyecto Supabase enlazado de DICSA, con captura, consulta, edición, archivos e historial. La migración `20260914210000_enable_documental_procedures.sql` está aplicada y registrada; su contenido remoto coincide exactamente con el archivo local.

## Recorrido y campos

Gestión Documental → Permisos y Trámites → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar trámite.

- Nombre del trámite o expediente, tipo de gestión controlado, dependencia, responsable interno existente, área y folio/referencia.
- Tipos: Expediente, Licencia, Permiso, Renovación y Trámite; picker ordenado alfabéticamente con foco inicial en búsqueda.
- Fechas de emisión e inicio opcionales. Vencimiento opcional, con validación contra el inicio cuando ambos existen.
- Estatus y prioridad controlados, avance entero obligatorio de 0 a 100, próxima acción y observaciones.
- El avance expresa lo capturado por el responsable y es independiente del estatus. Marcar Completado no inventa un porcentaje ni altera automáticamente lo capturado.
- Documento principal y complementarios privados. Conserva sustitución del principal, descarga mediante enlaces temporales e historial de versiones, incluidos archivos anteriores.

La lista muestra Trámite, Dependencia, Responsable, Vencimiento, Días restantes, Prioridad, Estado/Semáforo, Avance y acciones. La acción **Actualizar seguimiento** abre directamente Seguimiento con foco en Avance; conserva todos los demás datos y guarda una versión completa. También está disponible desde el menú contextual de un expediente.

La búsqueda consulta nombre, folio, dependencia y área. Los filtros incluyen tipo, estatus, responsable, vigencia y prioridad. La consulta está paginada a 50 registros y empieza por creación descendente, con folio ascendente para desempatar. Legal y Trámites consultan exclusivamente su categoría.

Los días y el semáforo se calculan con la fecha civil del servidor en America/Mexico_City. Se conservan los límites definidos en Legal y en el prompt: Completado tiene precedencia, sin vencimiento es neutral, fechas pasadas son Vencido, 0–5 días Crítico, 6–15 Atención y más de 15 En tiempo.

## Contrato de interfaz

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento: lista de consulta y detalle con guardado atómico. Reutiliza la captura y el repositorio de Legal, así como los controladores compartidos de selección y teclado de Entradas y Salidas. No se introduce edición parcial de celdas.

Mantiene la navegación homologada con Finanzas, botones contractuales y tokens rosas del área en shell, filtros, pickers, calendario, listas, diálogo y barra de avance. El Estado combina texto del proceso y semáforo, evitando una columna adicional. En ventanas pequeñas la fila se presenta como tarjeta con la misma información operativa.

El refresh sigue siendo automático y se difiere durante la captura para preservar cambios locales. Se conserva el guardado idempotente, el reintento tras respuesta incierta y el rechazo `PT409` de revisiones antiguas. La corrección de un campo inválido retira su error sin perder el foco.

## Modelo y compatibilidad

- `documental_records.progress_percentage`: smallint, no nulo, valor inicial 0 y restricción 0–100.
- `documental_save_record`: admite Legal y Permisos y Trámites; valida tipos por categoría y exige el avance de Trámites. Impide cambiar de categoría un expediente existente.
- `documental_query_records`: nueva consulta por categoría con filtro de prioridad y campos de seguimiento incluidos en la respuesta.
- `documental_list_records`: conserva su firma y comportamiento exclusivo de Legal para clientes anteriores.
- Historial: cada versión incluye categoría, avance, próxima acción y el resto de los metadatos. La primera versión de un trámite se identifica como Trámite registrado.

Se reutilizan el bucket privado, las políticas RLS, los permisos de Dirección/administración y la auditoría existentes. La migración no modifica usuarios ni roles. Solo se desplegó esta migración documental; las migraciones pendientes de otras áreas no forman parte de esta entrega.

## Archivos principales

Los tres componentes que antes tenían nombre Legal ahora son compartidos por categoría:

| Archivo actual | Responsabilidad |
| --- | --- |
| `lib/app/gestion_documental/gestion_documental_record_draft.dart` | Antes `gestion_documental_legal_draft.dart`; borrador, categoría, catálogos y validación de avance. |
| `lib/app/gestion_documental/gestion_documental_record_capture.dart` | Antes `gestion_documental_legal_capture.dart`; captura, detalle, archivos, seguimiento e historial. |
| `lib/app/gestion_documental/gestion_documental_records_workspace.dart` | Antes `gestion_documental_legal_workspace.dart`; lista y acciones por categoría. |
| `lib/app/gestion_documental/gestion_documental_records.dart` | Tipo de categoría, avance, dependencia y filtros de consulta. |
| `lib/app/gestion_documental/gestion_documental_store.dart` | Consulta real por categoría y creación del borrador correspondiente. |
| `lib/app/gestion_documental/gestion_documental_category_page.dart` | Conecta las dos categorías habilitadas al workspace compartido. |
| `lib/app/gestion_documental/gestion_documental_widgets.dart` | Barra rosa de avance con porcentaje y semántica accesible. |
| `supabase/migrations/20260914210000_enable_documental_procedures.sql` | Columna, validaciones y consulta por categoría. |
| `test/gestion_documental/` y `tool/test_documental_sql.mjs` | Cobertura funcional y regresión de Legal. |

## Verificación completada

- 12 pruebas Flutter aprobadas: nueve de widgets, una de dominio y dos del repositorio HTTP. El nuevo recorrido valida campos, avance vacío y 101 rechazados, corrección a 35, prioridad, separación de categorías, actualización rápida a 68, historial y refresh diferido. Incluye tamaños 1440×1000, 800×900 y 390×844.
- Capturas renderizadas revisadas de lista, captura, detalle e historial, además de tarjetas compactas; no se observaron desbordamientos.
- Análisis Dart sin incidencias y compilación `flutter build macos --debug --no-pub` aprobada.
- PostgreSQL aislado con PGlite: tres migraciones, avance 35→85 e historial, límites inválidos, aislamiento y bloqueo de cambios de categoría, paginación 50+1, filtros, compatibilidad de consulta Legal, guardado atómico, idempotencia, conflicto, archivos y RLS.
- Dos recorridos contra Supabase real con el repositorio de producción, uno Legal y otro Trámites: alta sin vencimiento, reapertura desde otro cliente, reintento idempotente, subida/descarga con comparación de bytes, sustitución de principal conservando descarga histórica, conflicto de revisión, prioridad, categorías separadas y realtime. En Trámites se comprobó el avance 35→68 conservando el 35 histórico.
- Los dos expedientes de verificación, sus versiones y sus archivos se retiraron al finalizar. Las pruebas remotas usan la sesión vigente de la app sin registrar credenciales en el repositorio.

Comandos de reproducción local:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

La importación del Excel queda para su etapa posterior. El dashboard y calendario global continúan en su etapa visual; las demás categorías conservan sus pantallas iniciales. La siguiente categoría en el orden existente es Seguridad e Higiene.
