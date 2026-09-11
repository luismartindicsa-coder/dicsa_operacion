# Gestión Documental: análisis y alcance inicial

Fecha: 11 de septiembre de 2026.
Estado: análisis del prompt y del repositorio; sin implementación funcional.

## 1. Alcance acordado para avanzar

La instrucción de esta conversación divide el trabajo en entregas pequeñas:

1. **Esta pasada:** analizar el requerimiento completo y su integración con DICSA.
2. **Siguiente pasada:** dashboard “de chocolate”, identidad rosa y navegación hacia las pantallas base.
3. **Entregas posteriores:** conectar progresivamente registros, responsables, archivos, seguimiento, vencimientos, historial y calendario.

La Fase 1 funcional descrita en el prompt es el objetivo acumulado de esas entregas. El dashboard inicial no equivale a completar todos sus criterios de aceptación.

**Decisión explícita del usuario:** Gestión Documental será rosa en todo su contrato visual. Esta indicación sustituye la antigua sugerencia de gris azulado de `AREA_PALETTES_CONTRACT.md`. En la siguiente implementación habrá que actualizar esa sección y la nota final que sugería reciclar el azul de Administración.

## 2. Qué existe hoy y cómo aprovecharlo

La revisión comprende código Flutter, contratos locales y migraciones SQL versionadas. No se consultó el esquema desplegado ni se inspeccionó el Excel real `Gestor_Tramites_CELAYA 2026.xlsx`; sus campos se conocen por el prompt.

| Frente | Hallazgo en el repositorio | Aplicación al área |
| --- | --- | --- |
| Arquitectura | Flutter/Dart; páginas agrupadas por área, archivos de tema, navegación y stores; Supabase para autenticación, datos y archivos. | Crear `lib/app/gestion_documental/` siguiendo esta organización. No incorporar otro framework ni otra infraestructura de persistencia. |
| Dashboard de área | `EmptyAreaDashboardPage` permite configurar tokens, fondo, acciones, menú y contenido mediante `workspaceBuilder`. Contabilidad lo utiliza. | Base concreta para el dashboard inicial; conservar geometría, header, glass, movimientos y navegación homologados. |
| Navegación | `GeneralDashboardPage` abre áreas con `Navigator` y `appPageRoute`. `MaterialApp` usa `home`; no registra las URLs del prompt. | Agregar entrada en Dirección y navegación interna con el patrón actual. Las rutas del prompt son por ahora destinos conceptuales; no prometer enlaces web directos sin implementar su resolución. |
| Permisos | `AuthAccess` resuelve `profiles` por `user_id`, rol y actividad; `RoleRouter` decide el destino de sesión. Existe `ActionPermission` para acciones. | Incorporar permisos documentales específicos cuando haya operación real; no inventar un usuario o correo de área. |
| Grid | `InventoryPage` / `InventoryMovementsGrid` implementan Entradas y Salidas. Hay wrappers en `shared/archetypes/grid_editable`. | Replicar su interacción de foco, selección, edición, teclado, menús y refresh; adaptar campos y paleta. |
| Detalle | Mantenimiento es la referencia contractual de workflow; existen piezas `workflow_master_detail`, diálogos y superficies compartidas. | Detalle documental organizado por secciones, con navegación propia y adaptación de ancho. |
| Formularios y filtros | Existen `GridFilterDialog`, celdas de captura/edición, `showSearchablePickerDialog`, botones y diálogos contractuales. | Reusar los componentes compatibles, con búsquedas enfocadas y tokens rosas dentro de overlays. |
| Calendarios | Hay date pickers contractuales y una agenda comercial de registros independientes. No se identificó un calendario transversal de obligaciones documentales. | Reusar pickers y lenguaje visual; construir la vista de eventos a partir de documentos, sin duplicarlos en la agenda comercial. |
| Archivos | `file_picker` y Supabase Storage ya se usan en Finanzas, RH y Mantenimiento. Nómina tiene bucket privado, metadatos y versiones de recibos. | Mantener Storage y el patrón de descarga existente; tomar el precedente privado/versionado para documentos del área. |
| Personal | RH usa `hr_employee_profiles` con ID `text`; Logística usa `employees` con ID `uuid`, además de `logistics_driver_profiles`. | Los IDs no son intercambiables. La categoría Personal debe relacionarse con RH; un responsable de aplicación es otra relación. |
| Vehículos | Catálogo `vehicles` y extensión `logistics_vehicle_profiles`. | Referenciar la unidad existente mediante `vehicle_id`. |
| Alertas | Finanzas tiene cálculos de vencimiento y un límite de presentación por sesión, visibles también en Dirección. | Reusar su experiencia visual cuando corresponda. Falta una política documental persistente de destinatarios y deduplicación. |
| Badges | Hay badges y tarjetas de estado, pero algunos están acoplados a Operación o contienen colores fijos. | Reusar el lenguaje visual, con estados documentales y tokens semánticos propios; no reutilizar enums de transporte. |

### Referencias principales verificadas

- `AGENTS.md` y `lib/app/shared/app_ui/DICSA_APP_UI_STANDARD.md`.
- `lib/app/shared/app_ui/AREA_PALETTES_CONTRACT.md`.
- `lib/app/shared/archetypes/dashboard/empty_area_dashboard.dart`.
- `lib/app/contabilidad/contabilidad_dashboard_page.dart` y `contabilidad_area_chrome.dart`.
- `lib/app/shared/ui_contract_core/theme/{contract_tokens,area_theme_scope,glass_styles,contract_buttons}.dart`.
- `lib/app/shared/page_routes.dart`, `lib/app/dashboard/general_dashboard_page.dart`, `lib/app/auth/{auth_access,role_router}.dart`.
- `lib/app/services/{inventory_page,inventory_movements_grid}.dart`.
- `lib/app/shared/archetypes/auxiliary_surfaces/{date_picker_surface,searchable_picker}.dart`.
- `lib/app/finanzas/finanzas_due_alerts_store.dart` y `finanzas_evidence_store.dart`.
- `lib/app/hr/human_resources_personnel_page.dart` y `human_resources_nomina_page.dart`.
- `lib/app/logistica/logistics_resource_profile_store.dart`.
- `lib/app/shared/utils/file_download_save.dart`.
- Migraciones `20260629150000_create_hr_employee_files_foundation.sql`, `20260806190000_create_logistics_driver_vehicle_profiles.sql` y `20260820213000_add_hr_payroll_closure_and_receipt_archive.sql`.

## 3. Contrato visual rosa

La identidad debe entrar por `ContractAreaTokens` y `AreaThemeScope`, más el tema Material del área cuando el componente lo requiera. No basta con cambiar el fondo y el botón principal.

Cobertura obligatoria:

- Fondo, gradientes y masas decorativas homologadas.
- Header, navegación overlay, cards y listas.
- Botones principales/secundarios, iconos, links y acciones de fila.
- Grid: encabezados, separadores, captura, hover de celda, selección y edición.
- Campos, cursor, foco, selección de texto y validaciones.
- Filtros, dropdowns, pickers, calendarios y rangos de fechas.
- Menús contextuales, modales, confirmaciones, estados vacíos y cargas.

Dirección visual propuesta para la maqueta: glass en rosa profundo, superficies de la misma familia y acentos rosa claro, manteniendo legibilidad. El matiz y los tokens exactos se afinarán al verlo en pantalla; evitar que termine pareciendo el morado de RH o el vino de Gerencia.

Interpretación propuesta del prompt: el **semáforo temporal conserva verde/amarillo/rojo en un indicador discreto**, con texto e icono, dentro de una interfaz rosa. Esos colores comunican urgencia y no recolorean cards, filas ni calendarios completos. Los badges de categoría y controles permanecen en la familia rosa.

Riesgos concretos de implementación detectados:

- El tema Material raíz es verde y el fallback de `AreaThemeScope` es azul. Un diálogo abierto fuera del scope puede heredar esos colores; transmitir los tokens al builder como ya hacen los pickers compartidos.
- `DashboardWidgetCard` y `WorkflowDetailPanel` conservan texto de color fijo. No asumir que toda pieza compartida ya funciona sobre rosa oscuro: verificar y adaptar solo lo necesario con compatibilidad para sus consumidores.
- `GridFilterDialog` no declara actualmente autofocus en su buscador. Su integración debe cumplir el contrato de foco inicial.
- El selector nativo de archivos pertenece al sistema operativo; el picker, la lista de adjuntos y los diálogos construidos dentro de DICSA sí recibirán el contrato rosa.

## 4. Próxima entrega: dashboard “de chocolate”

### Pantalla principal

1. Header DICSA / Gestión Documental, navegación y cierre de sesión conforme al shell existente.
2. Seis indicadores compactos: documentos activos, próximos a vencer, críticos, vencidos, trámites pendientes y trámites en proceso.
3. Once cards de categoría, en el orden del prompt, con icono, nombre y espacio para total / por vencer / vencidos / atención.
4. Bloque breve de próximos vencimientos y acceso a Calendario.

Conservar una jerarquía limpia y un layout adaptable; no meter el grid de expedientes completo dentro del dashboard.

### Navegación y destinos

| Destino conceptual | Pantalla |
| --- | --- |
| `/gestion-documental` | Resumen |
| `/gestion-documental/calendario` | Calendario |
| `/gestion-documental/:category` | Grid de categoría |
| `/gestion-documental/:category/:id` | Detalle de registro, para la entrega funcional |

Menú del área: Resumen, Calendario y las once categorías. Sin Proveedores / Clientes como categoría principal.

Las cards deben abrir una pantalla base de su categoría; el calendario debe tener destino propio. Cada pantalla debe conservar el menú rosa, identificar la ubicación actual y permitir volver al Resumen. El panel abre sobre el contenido, empieza cerrado y se cierra con `Esc` o al navegar.

En esta entrega visual las cifras todavía no representan consultas documentales reales: usar `—` o un estado vacío explícito, sin presentar datos inventados como información de DICSA. No mostrar acciones que aparenten haber guardado o subido archivos. La estructura visual inicial se convertirá en las pantallas reales en las siguientes entregas.

El acceso inicial puede incorporarse desde Dirección siguiendo el punto de entrada existente. No requiere crear cuentas, cambiar roles de usuarios ni mover datos.

### Criterios de cierre de la entrega visual

- Entrada visible a Gestión Documental desde Dirección.
- Identidad rosa consistente en todas las superficies construidas.
- Once categorías y Calendario accesibles; retorno y ubicación actual correctos.
- Menú overlay, hover, foco y teclado acordes con DICSA.
- Sin overflow global ni títulos truncados de forma inutilizable en los anchos de trabajo revisados.
- Estados vacíos honestos; sin persistencia documental ni notificaciones simuladas.
- Revisión visual en la app, formato y análisis de los archivos Dart modificados.

## 5. Base documental propuesta para las entregas funcionales

Una infraestructura común y un registro de categorías evitarán once implementaciones independientes. La configuración de categoría define nombre, icono, orden, subcategorías, columnas y campos específicos. Las diferencias de negocio pueden tener secciones propias sin duplicar navegación, archivos ni cálculos.

Modelo conceptual, sujeto a validar contra el esquema desplegado antes de crear migraciones:

| Entidad | Responsabilidad |
| --- | --- |
| `DocumentCategory` | Categorías estables y extensibles; clave técnica separada del nombre visible. En la maqueta basta un registro central en Dart. |
| `DocumentRecord` | Identidad del expediente, categoría/subcategoría, tipo de registro, título, descripción, responsable, área, prioridad, estatus de proceso, autoridad/entidad, folio, observaciones, próxima acción, avance y auditoría. |
| `DocumentVersion` | Edición vigente o histórica: fechas de emisión/inicio/vencimiento/renovación, datos específicos relevantes y archivos correspondientes a esa vigencia. El registro expone los datos de su versión actual. |
| `DocumentAttachment` | Versión, función principal/complementaria, nombre original, MIME, tamaño, bucket/path, fecha y usuario de carga. |
| `DocumentHistoryEntry` | Cambios de estatus, seguimiento, renovaciones y sustituciones, con actor y fecha. |
| Hitos del expediente, cuando se necesiten | Inspección, pago, auditoría u otra obligación que no pueda representarse mediante las fechas base; pertenecen al registro y alimentan el calendario. |

Decisiones recomendadas:

- Distinguir el tipo de registro —documento, trámite o expediente— de la categoría. Un trámite no debe contarse como múltiples documentos por tener varios adjuntos.
- Campos comunes con tipos y validaciones explícitos. Los datos particulares pueden comenzar como metadatos validados por categoría; claves foráneas, fechas consultables y campos necesarios para filtros no deben quedar escondidos en JSON libre.
- Relaciones a `vehicles` y `hr_employee_profiles` usando sus tipos reales. Responsable de aplicación mediante usuario/perfil existente; si corresponde permitir responsables de RH, modelar esa relación explícitamente. No mezclar ambos IDs en un campo ambiguo.
- Nombres descriptivos de responsable solo como apoyo para externos o migración; no como identidad principal. Verificar qué campos de nombre expone `profiles` antes de construir el picker.
- Vigencia opcional. No derivar “sin vencimiento” de una fecha ficticia.
- `progress_percentage` limitado a 0–100; separar archivo completo, avance del trámite y vigencia.
- Estatus: Pendiente, En proceso, Completado, Cancelado, No aplica. Prioridad: Urgente, Alta, Media, Baja.
- Diferenciar registro vigente/archivado de estatus de proceso. Las versiones históricas no deben inflar los indicadores activos.

### Diferencias previstas por categoría

| Categoría | Especialización inicial prevista |
| --- | --- |
| Documentación Legal | Tipo documental, notaría/autoridad y escritura/folio; vencimiento opcional. |
| Permisos y Trámites | Dependencia, responsable, fechas, prioridad, proceso, avance y próxima acción; primera categoría de seguimiento operativo. |
| Seguridad e Higiene | Estudio/capacitación/DC3, trabajador o área, proveedor y periodicidad. |
| Medio Ambiente | Autorización, autoridad e instalación relacionada. |
| Vehículos | Unidad existente, tipo documental y vigencia. |
| Personal | Trabajador de RH y tipo documental; enlazar documentación existente cuando corresponda en vez de copiar archivos de RH automáticamente. |
| Protección Civil | Programa, dictamen, brigada, simulacro o capacitación. |
| Contratos | Contraparte, firma, inicio/fin, renovación y archivo firmado; monto opcional posterior. |
| Seguros | Aseguradora, póliza, cobertura y entidad asegurada. |
| Mantenimiento | Obligación, periodicidad, certificados y evidencia; vínculo operativo posterior sin sustituir las OT. |
| Auditorías | Organismo, programación/realización, resultado, hallazgos y acciones. |

## 6. Vencimientos, indicadores y calendario

Una función de dominio central debe recibir el registro y la fecha de referencia, sin depender de colores ni de llamadas independientes a `DateTime.now()` en cada widget.

| Orden de evaluación | Condición | Semáforo |
| --- | --- | --- |
| 1 | Estatus Completado | Completado |
| 2 | Sin fecha de vencimiento | Sin vencimiento |
| 3 | Días restantes < 0 | Vencido |
| 4 | Días restantes entre 0 y 5 | Crítico |
| 5 | Días restantes entre 6 y 15 | Atención |
| 6 | Días restantes > 15 | En tiempo |

Hoy equivale a cero días: es crítico, todavía no vencido. Días restantes se calcula y nunca se captura ni importa como dato fijo.

Usar fechas civiles para vigencias y timestamps para auditoría. Propuesta: fecha operativa común de `America/Mexico_City`, con referencia del servidor al cargar/refrescar y renovación al cambio de día o regreso a la app. Ya hay precedentes de esa zona en SQL de RH; no se identificó un reloj transversal listo para reutilizar. Evitar diferencias de horas del dispositivo o días de 23/25 horas en el cálculo.

Definiciones propuestas para cerrar al conectar el dashboard:

- Documentos activos: registros documentales actuales no archivados, cancelados ni marcados No aplica; no cantidad de PDFs ni versiones.
- Próximos a vencer: ventana de 0–30 días; críticos es su subconjunto de 0–5. Rotular la ventana y no sumar ambos como grupos excluyentes.
- Vencidos: fechas anteriores al día operativo; separados de críticos.
- Trámites pendientes/en proceso: conteo por tipo de registro y estatus correspondiente.
- Completados fuera de alertas temporales conforme al prompt. Cancelados, No aplica y versiones históricas fuera de pendientes/alertas, sin borrar su historial.

Una tarea completada y una póliza vigente son conceptos distintos: evitar marcar una póliza “Completada” solo por subirla, porque el requerimiento excluye ese estado de las alertas. Si hay un trámite de renovación terminado, puede vincularse al documento que conserva su vigencia.

El calendario será una proyección de fechas de la versión actual y, posteriormente, hitos/obligaciones del registro. Cada evento tendrá identidad estable (registro + versión/hito + tipo de fecha), categoría e ingreso al detalle. La categoría se reconoce por icono y etiqueta; no requiere once colores distintos. Las recurrencias deben proceder de una obligación configurada, no de eventos manuales duplicados.

## 7. Archivos, versiones, permisos y alertas

**Archivos e historial.** Mantener Supabase Storage. Para el área, proponer un bucket privado con el patrón ya utilizado por Nómina; es una separación de documentos dentro del mecanismo actual. Algunas implementaciones antiguas de RH/Finanzas usan URLs públicas y permisos amplios: no copiarlos para expedientes legales/personales. Aplicar permisos tanto a metadatos como a objetos.

La renovación debe crear otra versión con su archivo y fechas, dejando accesible la anterior. El cambio de versión vigente y su historial deben publicarse de forma atómica en base de datos. Storage y SQL requieren manejo explícito de fallos: subir a una ruta nueva, registrar la versión y conservar la vigente anterior si falla. No sobrescribir bytes del archivo histórico ni anunciar éxito antes de completar el registro.

**Permisos.** Antes de habilitar datos reales, definir lectura, alta/edición, renovación, descarga y administración por rol/categoría. Reutilizar autenticación existente y políticas RLS; ocultar un botón no sustituye el permiso de servidor. La matriz de usuarios responsables y acceso a expedientes de Personal se concreta en esa entrega, sin bloquear la maqueta.

**Alertas.** Preparar umbrales 30, 15, 7, 5, 1 y vencido en una política central. El límite por sesión existente en Finanzas no resuelve deduplicación duradera ni destinatarios. Al implementar envíos, registrar entrega por registro/versión, vencimiento, umbral, destinatario y canal; agrupar avisos y evitar disparar de golpe todos los umbrales pasados. El canal y la frecuencia se definirán después. En el dashboard inicial no habrá envíos automáticos.

## 8. Secuencia posterior al dashboard

1. **Documentación Legal:** base persistente, permisos, responsable, detalle, documentos sin vencimiento y carga/consulta con historial.
2. **Permisos y Trámites:** grid contractual, filtros, seguimiento, prioridades, estatus y semáforo central.
3. **Resumen y Calendario reales:** agregados de las mismas fuentes, navegación al detalle y fechas consolidadas.
4. **Resto de categorías:** activar campos específicos sobre la infraestructura común, en entregas separadas.
5. **Alertas e importación:** política de avisos y mapeo del Excel real, conservando folio/referencia de origen y resolviendo responsables. No importar colores, días restantes ni fórmulas como valores definitivos.

Validación funcional futura concentrada en casos reales: sin vencimiento; límites −1/0/5/6/15/16; Completado con fecha vencida; cambio de día; renovación que conserva archivo anterior; fallo de carga; acceso no autorizado; filtros y navegación; foco/teclado y refresh durante edición. No se ejecutaron pruebas de app en esta pasada de análisis.

## 9. Archivos previstos y resultado de esta pasada

Para la siguiente entrega visual se prevén tema, navegación, registro de categorías, dashboard, pantalla base de categoría y calendario base dentro de `lib/app/gestion_documental/`, más la entrada en `GeneralDashboardPage` y la actualización del contrato cromático. Los nombres finales pueden ajustarse al implementar.

Esta pasada solo crea este documento. No agrega rutas ejecutables, modelos Dart, migraciones, buckets ni cambios en pantallas existentes. No se modificaron los cambios de trabajo que ya estaban presentes en Gerencia y reportes.
