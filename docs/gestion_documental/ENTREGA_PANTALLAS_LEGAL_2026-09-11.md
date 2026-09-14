# Documentación Legal · captura y detalle visual

Estado posterior: la [implementación funcional del 14 de septiembre](ENTREGA_LEGAL_FUNCIONAL_2026-09-14.md) añade persistencia, archivos e historial y ya está activada y verificada en Supabase. Este documento conserva el alcance histórico de la entrega visual.

Continuación del dashboard inicial, manteniendo el avance por etapas. Esta entrega permite recorrer las pantallas de alta y detalle antes de habilitar persistencia documental.

## Recorrido disponible

Gestión Documental → Documentación Legal → Nuevo → Vista previa → Volver a captura.

- **Datos generales:** nombre, tipo documental controlado, folio/escritura, notaría/autoridad y área.
- **Vigencia:** emisión e inicio opcionales; vencimiento activable. Desactivarlo limpia la fecha y muestra “Sin vencimiento”. Las fechas incluyen año.
- **Documentación:** selección local del documento principal y complementarios mediante el `FilePicker` existente; cambio de selección, eliminación de la selección y manejo de cancelación/error. Los archivos se identifican como seleccionados, sin subir.
- **Seguimiento:** estatus de proceso, prioridad, próxima acción y observaciones.
- **Detalle:** lectura de la captura por secciones, archivos seleccionados e historial vacío. Se conserva la captura al volver a editar.
- **Salida:** Escape vuelve del detalle a captura; cancelar/cerrar una captura modificada permite conservarla o descartarla.

El formulario valida nombre y tipo antes de la vista previa. Si se activa vencimiento, exige fecha y comprueba que no sea anterior al inicio. No precarga catálogos ni fechas.

## Arquitectura y referencias

- Arquetipo: superficie auxiliar de captura y revisión; referencia de secciones y subflujos de Mantenimiento. Esta entrega no activa un grid editable alternativo.
- Reutiliza `ContractDialogShell`, botones contractuales, `showSearchablePickerDialog`, date picker y confirmación compartidos, `AreaThemeScope` y tokens rosas.
- La navegación del área y su menú de Finanzas se conservan. El alta/detalle vive en un diálogo sobre la categoría; no añade URLs ni cambia el stack de categorías.
- `DocumentalLegalDraft` es una captura transitoria, no una entidad persistida. Se libera al cerrar y no modifica los indicadores del dashboard.
- No hay refresh remoto en la captura visual. Ninguna consulta ni temporizador reemplaza campos mientras se editan.

## Archivos de esta entrega

| Archivo | Cambio |
| --- | --- |
| `lib/app/gestion_documental/gestion_documental_legal_capture.dart` | Captura por secciones, detalle visual, pickers, selección local de archivos y salida. |
| `lib/app/gestion_documental/gestion_documental_legal_draft.dart` | Estado transitorio, tipos documentales, estatus, prioridades y validación de vigencia. |
| `lib/app/gestion_documental/gestion_documental_category_page.dart` | Habilita Nuevo en Legal y explica el recorrido disponible. |
| `lib/app/gestion_documental/gestion_documental_catalog.dart` | Encabezados propios de Legal: documento, tipo, emisión, vencimiento, responsable y folio. |
| `lib/app/gestion_documental/gestion_documental_theme.dart` | Scrollbars y bordes deshabilitados con los tokens rosas del área. |
| `test/gestion_documental/gestion_documental_navigation_test.dart` | Cobertura de captura, revisión, cancelación, archivos y tamaños de ventana, además de navegación existente. |

## Pendiente para la etapa funcional

- Persistencia y modelo documental/versiones; permisos/RLS y relación con usuarios existentes.
- Asignación de responsable: el control está visible y deshabilitado; no se inventó un catálogo ni se sustituyó la identidad por texto libre.
- Guardado y carga a Storage: Guardar documento permanece deshabilitado. Seleccionar un archivo no lo sube ni lo copia a otro repositorio.
- Consulta/descarga de archivos guardados, historial real, renovación y sustitución versionada.
- Grid editable contractual con registros, semáforo, indicadores y calendario derivados de la misma fuente.
- Pantallas funcionales de Permisos y Trámites y ampliación de las restantes categorías.

No se crean migraciones, buckets, permisos, catálogos de personal ni registros de negocio en esta entrega. No se presenta la captura visual como un guardado exitoso.

## Validación

Seis pruebas de widgets aprobadas: foco inicial y búsqueda, validación, conservación de datos entre secciones/detalle, Escape y descarte, vencimiento opcional, selección/cancelación/error de archivos y ausencia de overflow en escritorio, 800×900 y 390×844. Análisis Dart sin incidencias. Las capturas opcionales se regeneran con `DOCUMENTAL_PREVIEW=1 flutter test --no-pub test/gestion_documental/gestion_documental_navigation_test.dart` y se guardan en `/private/tmp/documental_legal_*.png`.
