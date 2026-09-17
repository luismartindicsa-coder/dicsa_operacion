# Seguros · implementación funcional

Continúa la [entrega de Contratos](ENTREGA_CONTRATOS_2026-09-14.md). La novena categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914235930_enable_documental_insurance.sql` está aplicada y registrada; su contenido remoto coincide exactamente con el archivo local.

## Recorrido y campos

Gestión Documental → Seguros → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados: Cobertura, Endoso, Póliza y Renovación. Conserva responsable interno, área, estado, prioridad, avance de 0 a 100, próxima acción y observaciones.

- **Aseguradora:** nombre requerido, reutiliza el campo documental `authority` con la etiqueta propia de Seguros.
- **Número de póliza:** reutiliza `reference`. Puede completarse posteriormente cuando la emisión esté pendiente.
- **Bien, persona o unidad asegurada:** descripción requerida del alcance asegurado. Permite identificar instalaciones, bienes, personas, unidades o grupos dentro del expediente; no crea ni modifica catálogos de RH o vehículos.
- **Cobertura:** descripción documental opcional, con varias líneas y búsqueda por contenido.
- **Inicio y vencimiento:** fechas compartidas de vigencia. El vencimiento no puede preceder al inicio; se permite registrar un expediente mientras se completan sus fechas. Se conserva también la fecha opcional de emisión.
- **Renovación:** picker opcional con Automática, No aplica y Por acuerdo, fecha independiente del vencimiento y condiciones. No aplica retira la fecha de renovación y oculta su control; el servidor rechaza una fecha incompatible. La modalidad describe el expediente y no ejecuta renovaciones ni desplaza su vencimiento.
- **Póliza (principal):** archivo privado con sustitución e historial de versiones. Endosos y otros documentos pueden adjuntarse como complementarios. Es posible guardar un expediente pendiente de documentación.

La prima queda para la etapa posterior prevista en el planteamiento original.

La lista muestra Póliza, Aseguradora, Responsable, Vencimiento, Días, Prioridad, Estado/Semáforo y Avance. La búsqueda incluye número de póliza, aseguradora, asegurado, cobertura y condiciones de renovación. Mantiene filtros, paginación de 50 registros, orden por creación descendente y referencia ascendente, y acción rápida de seguimiento.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, mediante workspace y captura compartidos. Conserva navegación de referencia Finanzas, tokens rosas, controles y teclado homologados, refresh automático diferido durante la edición y tarjetas desplazables en ventanas compactas.

El modelo incorpora `insured_subject` y `coverage_description`; comparte las fechas y los campos de renovación introducidos por Contratos. `documental_save_record` habilita Seguros, valida aseguradora, asegurado, tipo, avance y coherencia de fechas, y conserva la operación atómica con archivos e historial. Los campos exclusivos de otras categorías se descartan. `documental_query_records` devuelve los datos propios y permite buscarlos dentro de Seguros.

Se conservan enlaces firmados, almacenamiento privado, snapshots históricos, reintento idempotente y conflicto `PT409`. Los cambios de asegurado, cobertura y renovación no modifican las versiones anteriores ni retiran sus archivos.

## Verificación

- 23 pruebas Flutter aprobadas. El nuevo recorrido comprueba campos obligatorios, fechas mediante calendario y teclado, renovación independiente, búsqueda por asegurado/cobertura/póliza, seguimiento, refresh diferido, sustitución del archivo, datos y archivos históricos, y limpieza de renovación al elegir No aplica sin modificar vencimiento.
- Capturas revisadas de datos generales, vigencia, vista previa, lista e historial. Lista comprobada en 1440×1000, 800×900 y 390×844 sin overflow. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con once migraciones: tipos, normalización, búsqueda, separación por categoría, aseguradora y asegurado requeridos, fechas independientes, historial, campos aún pendientes, rechazo de datos inválidos y denegación a perfiles inactivos y sin acceso. Mantiene las pruebas de archivos, RLS, idempotencia, conflictos y guardado atómico de las categorías anteriores.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: contexto, alta, lectura, búsqueda y persistencia de fechas comprobados en una transacción con rollback.

- Nueve recorridos reales aprobados con el repositorio de producción y dos clientes: Legal, Trámites, Seguridad, Medio Ambiente, Vehículos, Personal, Protección Civil, Contratos y Seguros. Comprueban alta, reapertura, reintento idempotente, descarga con comparación de bytes, sustitución conservando el archivo anterior, conflicto, filtros y realtime. Seguros comprueba además asegurado, cobertura y renovación actuales e históricos. La auditoría final confirmó cero expedientes de prueba, metadatos, entradas históricas y objetos del bucket documental.
- El primer intento de la prueba real se detuvo al quedar menos de un minuto de vigencia en la sesión local. La app renovó su sesión automáticamente y el recorrido completo pasó al repetirse. Se envió la recarga a la instancia macOS en ejecución.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Mantenimiento.

Continuación: [Mantenimiento implementado](ENTREGA_MANTENIMIENTO_2026-09-14.md).
