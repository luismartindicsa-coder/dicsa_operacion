# Protección Civil · implementación funcional

Continuación: [Contratos](ENTREGA_CONTRATOS_2026-09-14.md).

Continúa la [entrega de Personal](ENTREGA_PERSONAL_2026-09-14.md). La séptima categoría queda conectada a Supabase y disponible para el rol documental, incluido `gestion@dicsamx.com`. La migración `20260914235500_enable_documental_civil_protection.sql` está aplicada y registrada; su contenido remoto coincide con el archivo local.

## Recorrido y captura

Gestión Documental → Protección Civil → Nuevo → Datos generales / Vigencia / Documentación / Seguimiento → Vista previa → Guardar documento.

Tipos controlados, ordenados alfabéticamente: Brigada, Capacitación, Dictamen, Plan de respuesta, Programa interno, Simulacro y Visto bueno.

La captura utiliza Documento/actividad, Folio/referencia, Autoridad/entidad, Área/departamento y Responsable interno. Conserva las fechas de emisión e inicio opcionales y admite documentos sin vencimiento. Seguimiento incluye estado, prioridad, avance entero de 0 a 100, próxima acción y observaciones. El avance es independiente del estado y de las fechas.

La lista muestra Documento/actividad, Autoridad/área, Responsable, Vencimiento, Días, Prioridad, Estado/Semáforo y Avance. La acción rápida abre Seguimiento con foco en Avance. La búsqueda incluye documento, folio, autoridad y área; se conservan filtros por tipo, estatus, responsable, vigencia y prioridad, paginación a 50 registros y orden inicial por creación descendente y referencia ascendente.

Se trata de expedientes documentales de las actividades indicadas. Los registros de capacitación y dictamen en esta categoría permanecen separados de Seguridad e Higiene aunque compartan nombre de tipo.

## Contrato y persistencia

Arquetipo **Workflow Master-Detail**, referencia Mantenimiento, mediante la captura y el workspace documental compartidos. Conserva navegación de referencia Finanzas, tokens rosas, selección y teclado homologados, refresh automático diferido durante captura y tarjetas desplazables en ventanas compactas.

Se utiliza el modelo documental existente sin columnas ni catálogos adicionales. `documental_save_record` habilita `proteccion-civil`, valida sus siete tipos y el avance y guarda los campos comunes dentro de la transacción versionada. `documental_query_records` admite la categoría sin cambiar su firma; el contexto compartido proporciona responsables y fecha civil del servidor. Los contextos específicos de trabajadores y vehículos permanecen disponibles para sus categorías.

Se reutilizan archivos privados, enlaces firmados, sustitución del documento principal conservando anteriores, historial inmutable, reintentos idempotentes, conflicto `PT409` y semáforo por fecha civil del servidor. Cada versión conserva el tipo, autoridad, área, folio y avance registrados en ese momento.

## Verificación

- 21 pruebas Flutter aprobadas. El nuevo recorrido cubre las siete opciones de tipo, captura, búsqueda por folio/autoridad/área, filtro por tipo, actualización de avance, cambio de tipo/autoridad/área conservando historial, aislamiento frente a Seguridad e Higiene y conservación de cambios ante refresh.
- Capturas revisadas de lista, captura, picker, vista previa e historial, con ventanas de 1440×1000, 800×900 y 390×844 sin overflow de layout. Análisis Dart sin incidencias y compilación macOS aprobada.
- PostgreSQL aislado con nueve migraciones: los siete tipos admitidos, campos comunes, búsqueda y filtros, identidad de categoría, versiones históricas, rechazo de tipos y avances inválidos, fechas contradictorias, conflicto, campos ajenos descartados y denegación de perfiles inactivos y sin acceso. Se conservan las comprobaciones previas de RLS, archivos privados, idempotencia y guardado atómico.
- Supabase bajo `authenticated` con el UUID de `gestion@dicsamx.com`: contexto, alta, lectura y búsqueda verificados dentro de una transacción con rollback.

- Siete recorridos reales aprobados con el repositorio de producción y dos clientes: Legal, Trámites, Seguridad, Medio Ambiente, Vehículos, Personal y Protección Civil. Comprueban alta, reapertura, reintento, descarga con comparación de bytes, sustitución conservando el archivo histórico, conflicto, filtros y realtime. Protección Civil verifica además cambios de tipo, autoridad y área conservando los valores anteriores. Todos los expedientes, versiones y objetos de prueba fueron retirados.

Para reproducir:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```

Dashboard y calendario global mantienen su etapa visual. La siguiente categoría en el orden existente es Contratos.
