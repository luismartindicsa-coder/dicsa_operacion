# Vehículos · implementación funcional

Continuación: [Personal](ENTREGA_PERSONAL_2026-09-14.md).

Continúa la [entrega de Medio Ambiente](ENTREGA_MEDIO_AMBIENTE_2026-09-14.md). La quinta categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914234500_enable_documental_vehicles.sql` está aplicada y registrada; su contenido remoto coincide con el archivo local.

## Recorrido y campos propios

Gestión Documental → Vehículos → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados: Licencia relacionada, Mantenimiento documental, Permiso, Seguro, Tarjeta de circulación, Tenencia y Verificación. Se mantienen responsable interno, área/departamento, estado, prioridad, avance de 0 a 100, próxima acción y observaciones. La captura incorpora:

- **Unidad relacionada:** picker del catálogo existente `vehicles`, identificado por código, nombre y placas, evitando repetir código y nombre iguales. La relación es opcional mediante «Sin unidad específica», para documentos aplicables a toda la flotilla.
- **Emisor / aseguradora:** etiqueta del campo de autoridad compartido.
- **Folio / póliza / referencia:** identificador independiente del vehículo.

El catálogo remoto tiene 32 unidades al momento de la verificación. Se incluyen todos sus estados operativos, porque mantenimiento o fuera de servicio no impiden documentar una unidad. El picker expone únicamente identificador y etiqueta; esta pantalla no crea ni modifica vehículos.

La vigencia admite fechas de emisión e inicio opcionales y documentos sin vencimiento. El avance es independiente del estatus. La lista muestra Documento vehicular, Unidad, Responsable, Vencimiento, Días, Prioridad, Estado/Semáforo y Avance. La acción rápida abre Seguimiento con foco en Avance.

La búsqueda incluye el código, nombre y placas guardados en la versión actual del expediente, además de documento, póliza/referencia, emisor y área. Los cambios posteriores en el catálogo se reflejan en la etiqueta documental al guardar de nuevo el expediente; las versiones anteriores conservan su identidad original. Se mantienen filtros, paginación a 50 registros, orden por creación descendente y referencia ascendente y aislamiento por categoría.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, con los componentes documentales compartidos. Mantiene navegación de referencia Finanzas, tokens rosas, selección y teclado homologados, refresh automático diferido durante la captura y tarjetas desplazables en ventanas compactas.

El modelo agrega `vehicle_id` como FK al catálogo existente, con `ON DELETE SET NULL`, y `vehicle_label` como identidad guardada por versión. El servidor calcula la etiqueta desde el catálogo, ignorando cualquier etiqueta enviada por el cliente. Si se elimina una unidad del catálogo, la relación actual queda nula y el historial conserva su identidad; el siguiente guardado sin unidad limpia la etiqueta actual.

`documental_vehicle_context` entrega responsables, fecha civil del servidor y unidades ordenadas por etiqueta. `documental_save_record` habilita Vehículos y valida tipo, unidad existente y avance. `documental_query_records` incorpora la relación y la búsqueda. Se conservan las firmas de las funciones compartidas y los contextos de las otras categorías.

Se reutilizan los archivos privados, sustitución del principal conservando anteriores, enlaces firmados, historial inmutable, guardado atómico, reintento idempotente, conflicto `PT409` y semáforo por fecha civil del servidor.

## Verificación

- 19 pruebas Flutter aprobadas, incluyendo selección de unidad, búsqueda por código/placas/póliza, actualización de avance, cambio de unidad con historial, captura aplicable a la flotilla, foco del picker y conservación de cambios durante refresh.
- Capturas revisadas de lista, captura, picker, vista previa e historial en escritorio y ventanas de 800×900 y 390×844, sin overflow de layout. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con siete migraciones: identidad calculada por el servidor, cambio de placas conservando historia, unidades en mantenimiento/fuera de servicio, relación opcional, eliminación de unidad conservando snapshots, validación de unidad/tipo/avance, aislamiento, conflictos y denegación de perfiles inactivos y sin acceso. Se mantienen las comprobaciones de archivos, RLS, versiones y guardado atómico.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: contexto, alta, lectura y búsqueda verificados dentro de una transacción con rollback.

- Cinco recorridos reales aprobados con el repositorio de producción y dos clientes: Legal, Trámites, Seguridad, Medio Ambiente y Vehículos. Comprueban alta, reapertura, reintento, descarga con comparación de bytes, sustitución conservando el archivo histórico, conflicto, filtros y realtime. Vehículos comprueba además selección del catálogo, búsqueda de unidad y cambio de relación conservando la identidad anterior. Los expedientes, versiones y objetos de prueba fueron retirados.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Personal.
