# Contratos · implementación funcional

Continúa la [entrega de Protección Civil](ENTREGA_PROTECCION_CIVIL_2026-09-14.md). La octava categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914235900_enable_documental_contracts.sql` está aplicada y registrada; su contenido remoto coincide con el archivo local.

## Recorrido y campos

Gestión Documental → Contratos → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados: Anexo, Contrato, Convenio y Renovación. La captura mantiene folio/referencia, notaría/entidad, área, responsable interno, estado, prioridad, avance entero de 0 a 100, próxima acción y observaciones.

- **Contraparte:** nombre requerido dentro del expediente, guardado por versión. Es una descripción documental; no crea una entidad en los catálogos comerciales.
- **Fecha de firma:** fecha opcional independiente de la emisión y del inicio contractual.
- **Fecha inicial y fecha final:** usan las fechas de vigencia compartidas. La fecha final no puede preceder a la inicial. Se permiten contratos sin vencimiento y expedientes pendientes de firma.
- **Renovación:** modalidad opcional mediante picker: Automática, No aplica o Por acuerdo. Si aún no se conoce puede quedar sin especificar.
- **Fecha de renovación:** fecha opcional independiente del vencimiento. Elegir No aplica retira esta fecha y oculta el control; el servidor rechaza una fecha enviada junto con No aplica.
- **Condiciones de renovación:** texto libre opcional, conservado en cada versión.
- **Archivo firmado (principal):** carga privada del contrato; se puede sustituir conservando todas sus versiones. Los anexos pueden incorporarse como archivos complementarios.

La modalidad Automática describe lo pactado; guardar este dato no modifica fechas ni genera renovaciones. El semáforo de vigencia sigue calculándose sobre la fecha final y el estado del proceso. Los campos de firma y archivo firmado pueden completarse posteriormente. El monto opcional del planteamiento general queda fuera de esta entrega documental.

La lista muestra Contrato, Contraparte, Responsable, Vencimiento, Días, Prioridad, Estado/Semáforo y Avance. Se busca por nombre, contraparte, folio, autoridad, área y condiciones de renovación. Se mantienen filtros compartidos, paginación a 50 registros, orden inicial por creación descendente y referencia ascendente, y acción rápida de seguimiento.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, mediante captura y workspace compartidos. Conserva navegación de referencia Finanzas, tokens rosas, selección y teclado homologados, refresh automático diferido durante la edición y tarjetas desplazables en ventanas compactas.

El modelo agrega `counterparty_name`, `signature_date`, `renewal_type`, `renewal_date` y `renewal_notes`. `documental_save_record` habilita Contratos, valida sus tipos, contraparte, avance y coherencia de renovación, normaliza espacios exteriores y conserva el guardado atómico con historial y archivos. `documental_query_records` devuelve los campos propios y permite buscar por contraparte y condiciones. El contexto común y las firmas de las funciones existentes se conservan.

Se reutilizan enlaces firmados, archivos privados, snapshots inmutables, reintento idempotente y conflicto `PT409`. Cambiar contraparte, firma o renovación conserva los valores anteriores en el historial; sustituir el archivo firmado conserva la descarga de su versión anterior.

## Verificación

- 22 pruebas Flutter aprobadas. El recorrido nuevo comprueba contraparte obligatoria, selección de firma/inicio/fin/renovación mediante calendario y teclado, búsqueda por contraparte, actualización de avance, sustitución del archivo firmado, conservación de datos y archivos históricos, y limpieza de la fecha al elegir No aplica sin alterar la fecha final.
- Capturas revisadas de datos generales, vigencia, vista previa, lista e historial, en ventanas de 1440×1000, 800×900 y 390×844 sin overflow de layout. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con diez migraciones: tipos de contrato, contraparte requerida, firma independiente de emisión, renovación independiente de vencimiento, condiciones y normalización, búsqueda, aislamiento, versiones históricas, contratos sin firma ni fecha final, rechazo de datos inválidos y denegación a perfiles inactivos y sin acceso. Se mantienen las comprobaciones previas de RLS, archivos, idempotencia, conflictos y guardado atómico.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: contexto, alta, lectura, búsqueda por contraparte y persistencia de fechas comprobados dentro de una transacción con rollback.

- Ocho recorridos reales aprobados con el repositorio de producción y dos clientes: Legal, Trámites, Seguridad, Medio Ambiente, Vehículos, Personal, Protección Civil y Contratos. Comprueban alta, reapertura, reintento, descarga con comparación de bytes, sustitución conservando el archivo histórico, conflicto, filtros y realtime. Contratos verifica además contraparte, firma y renovación actuales e históricas, sin alterar la fecha final. Todos los expedientes, versiones y objetos de prueba fueron retirados.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Seguros.

Continuación: [Seguros implementado](ENTREGA_SEGUROS_2026-09-14.md).
