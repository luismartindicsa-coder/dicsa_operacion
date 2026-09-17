# Personal · implementación funcional

Continuación: [Protección Civil](ENTREGA_PROTECCION_CIVIL_2026-09-14.md).

Continúa la [entrega de Vehículos](ENTREGA_VEHICULOS_2026-09-14.md). La sexta categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914235000_enable_documental_personnel.sql` está aplicada y registrada; su contenido remoto coincide con el archivo local.

## Recorrido y campos propios

Gestión Documental → Personal → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados: Certificación, Constancia, Contrato laboral, Documento laboral, Identificación y Licencia. Se conservan responsable interno, área/departamento, estado, prioridad, avance entero de 0 a 100, próxima acción y observaciones. Los campos específicos son:

- **Trabajador relacionado:** picker del catálogo existente de RH, ordenado por nombre y con búsqueda enfocada al abrir. Incluye trabajadores activos e inactivos; estos últimos se distinguen mediante «(inactivo)» en las opciones. El nombre guardado no incluye esa anotación.
- **Emisor / institución:** etiqueta apropiada para el campo de autoridad compartido.
- **Folio / referencia:** identificador documental independiente del trabajador.

La relación es opcional mediante «Sin trabajador específico», para documentos generales de un área. El catálogo remoto cuenta con 18 trabajadores al verificar esta entrega: 16 activos y 2 inactivos. Personal permite integrar documentos de trabajadores de baja; la regla previa de Seguridad e Higiene se conserva: nuevas relaciones con trabajadores activos y posibilidad de mantener al trabajador ya asociado.

No se crea un catálogo paralelo ni se modifican fichas de RH. El contexto de Personal expone únicamente identificador, nombre y estado activo del trabajador. Se mantienen las fechas opcionales y la posibilidad de registrar documentos sin vencimiento; el avance sigue siendo independiente del estatus.

La lista muestra Documento laboral, Trabajador/área, Responsable, Vencimiento, Días, Prioridad, Estado/Semáforo y Avance. La acción rápida abre Seguimiento con foco en Avance. Se puede buscar por nombre guardado del trabajador, documento, folio, emisor y área, además de utilizar los filtros compartidos. Los resultados se aíslan por categoría, se paginan a 50 registros y se ordenan inicialmente por creación descendente y referencia ascendente.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, mediante el workspace y la captura documental compartidos. Conserva navegación de referencia Finanzas, tokens rosas, selección y teclado homologados, refresh automático diferido durante la captura y tarjetas desplazables en ventanas compactas.

Se reutilizan `related_employee_id` y `related_employee_name` de `documental_records`. La FK apunta a `employees` y el servidor obtiene el nombre desde RH, ignorando nombres enviados por el cliente. Una actualización del nombre en RH se incorpora al guardar de nuevo el expediente; los snapshots previos conservan la identidad de su versión. Eliminar un trabajador del catálogo deja nula la relación actual y preserva su identidad histórica; guardar sin trabajador limpia el nombre actual.

`documental_personnel_context` devuelve responsables, fecha civil del servidor y trabajadores. `documental_save_record` habilita Personal, valida tipo, trabajador existente y avance, y conserva el guardado atómico con archivos e historial. `documental_query_records` habilita la categoría sin cambiar su firma. Los contextos de las otras categorías siguen disponibles.

Se reutilizan archivos privados, enlaces firmados, sustitución del principal sin borrar anteriores, historial inmutable, reintentos idempotentes, conflicto `PT409` y semáforo por fecha civil del servidor.

## Verificación

- 20 pruebas Flutter aprobadas. El nuevo recorrido cubre captura de trabajador activo, selección de inactivo, búsqueda por trabajador/folio/emisor, cambio de relación y avance, identidad histórica, documento sin trabajador, aislamiento frente a Seguridad e Higiene y conservación de cambios ante refresh.
- Capturas revisadas de lista, captura, picker, vista previa e historial, con ventanas de 1440×1000, 800×900 y 390×844 sin overflow de layout. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con ocho migraciones: creación para trabajadores inactivos, nombre calculado por el servidor, cambios de nombre conservando historia, relación opcional, eliminación de trabajador conservando snapshots, campos ajenos descartados, validación de tipo/trabajador/avance, aislamiento de categorías, conflicto y denegación a perfiles inactivos y sin acceso. Se mantienen las comprobaciones previas de archivos, RLS, versiones y guardado atómico.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: contexto, alta, lectura y búsqueda verificados con un trabajador inactivo dentro de una transacción con rollback.

- Seis recorridos reales aprobados con el repositorio de producción y dos clientes: Legal, Trámites, Seguridad, Medio Ambiente, Vehículos y Personal. Comprueban alta, reapertura, reintento, descarga con comparación de bytes, sustitución conservando el archivo histórico, conflicto, filtros y realtime. Personal comprueba además alta para un trabajador inactivo, búsqueda por nombre y cambio de trabajador conservando la identidad anterior. Todos los expedientes, versiones y objetos de prueba fueron retirados.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Protección Civil.
