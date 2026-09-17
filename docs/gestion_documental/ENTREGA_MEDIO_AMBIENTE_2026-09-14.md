# Medio Ambiente · implementación funcional

Continuación: [Vehículos](ENTREGA_VEHICULOS_2026-09-14.md).

Continúa la [entrega de Seguridad e Higiene](ENTREGA_SEGURIDAD_HIGIENE_2026-09-14.md). La cuarta categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914233000_enable_documental_environment.sql` está aplicada y registrada; su contenido remoto coincide con el archivo local.

## Recorrido y campos propios

Gestión Documental → Medio Ambiente → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados: Agua, Autorización, Emisiones, Estudio, Licencia, Manifiesto, Permiso y Residuos. La captura conserva responsable interno existente, área/departamento y folio/referencia, con campos propios de esta categoría:

- **Autoridad ambiental:** utiliza el campo de autoridad compartido con etiqueta apropiada al documento.
- **Número de autorización:** dato independiente del folio/referencia; cambiar uno no sustituye al otro.
- **Instalación relacionada:** referencia descriptiva opcional, guardada en cada versión. La inspección de `sites` encontró únicamente ubicaciones de clientes, sin un catálogo de instalaciones propias de DICSA; esta entrega no vincula ni crea ubicaciones en ese catálogo.

La autorización y la instalación son opcionales, porque un estudio o manifiesto puede no tener esos datos. La vigencia mantiene fechas de emisión e inicio opcionales y admite registros sin vencimiento. Seguimiento conserva estatus, prioridad, avance entero de 0 a 100, próxima acción y observaciones. El avance no se deduce del estatus ni modifica fechas.

La lista muestra Documento ambiental, Instalación/autoridad, Responsable, Vencimiento, Días, Prioridad, Estado/Semáforo, Avance y acciones. Bajo el título aparece el número de autorización cuando existe; el folio completo sigue disponible en el detalle. La acción rápida abre Seguimiento con foco en Avance.

La búsqueda incluye autorización e instalación además de nombre, autoridad, folio y área. Se mantienen los filtros compartidos, la paginación a 50 registros, el orden inicial por creación descendente y folio ascendente y el aislamiento por categoría.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, mediante los componentes documentales ya homologados. Mantiene navegación de referencia Finanzas, tokens rosas, selección y teclado compartidos con Entradas y Salidas, refresh automático diferido durante la captura y tarjetas desplazables en ventanas compactas.

El modelo agrega `authorization_number` e `installation_name` como columnas de texto independientes en `documental_records`. `documental_save_record` habilita Medio Ambiente, valida sus tipos y el avance, normaliza espacios exteriores y guarda los campos dentro de la transacción versionada. `documental_query_records` incorpora ambos campos a la respuesta y la búsqueda, conservando su firma. No se cambia el contexto de responsables ni el contexto específico de trabajadores de Seguridad e Higiene.

Cada snapshot conserva autoridad, autorización, instalación, folio y los demás campos de esa versión. Se reutilizan los archivos privados, sustitución del principal sin borrar anteriores, enlaces de descarga firmados, auditoría, reintento idempotente, conflicto `PT409` y semáforo por fecha civil del servidor. No se modifican usuarios ni permisos de otras áreas.

Archivos principales: `gestion_documental_records.dart`, `gestion_documental_record_draft.dart`, `gestion_documental_record_capture.dart` y `gestion_documental_records_workspace.dart`, dentro de `lib/app/gestion_documental/`, más la migración y las pruebas documentales.

## Verificación

- 18 pruebas Flutter aprobadas. El nuevo recorrido comprueba captura de autoridad/autorización/instalación, folio independiente, búsqueda por autorización, actualización 25→75, historial de autorización e instalación y conservación de cambios durante refresh remoto.
- Capturas revisadas de lista, captura, detalle e historial y tamaños 1440×1000, 800×900 y 390×844, sin overflow de layout. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con seis migraciones: campos ambientales, normalización, búsqueda por autorización/instalación/autoridad, aislamiento frente a las otras tres categorías, renovación conservando valores anteriores, campos opcionales vacíos, tipos inválidos, avance fuera de rango, conflicto de revisión y denegación de perfiles inactivos. Se conservan las comprobaciones previas de archivos, RLS y guardado atómico.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: guardado, consulta y búsqueda ambiental confirmados dentro de una transacción con rollback.
- Recorridos reales con el repositorio de producción y dos clientes para Legal, Trámites, Seguridad y Medio Ambiente: alta, reapertura, reintento, descarga con comparación de bytes, sustitución manteniendo el archivo histórico, conflicto, filtros y realtime. Medio Ambiente verifica además autorización e instalación actuales e históricas y preservación del folio. Los expedientes, versiones y objetos de prueba se retiran al finalizar.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Vehículos.
