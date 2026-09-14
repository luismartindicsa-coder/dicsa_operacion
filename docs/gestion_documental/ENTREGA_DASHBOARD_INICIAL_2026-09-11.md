# Gestión Documental · dashboard inicial

Entrega del 11 de septiembre de 2026. Implementa la etapa visual y navegable acordada en `ANALISIS_Y_ALCANCE_INICIAL_2026-09-11.md`.

Continuación: el alta y detalle visual se describen en [ENTREGA_PANTALLAS_LEGAL_2026-09-11.md](ENTREGA_PANTALLAS_LEGAL_2026-09-11.md). La [entrega funcional del 14 de septiembre](ENTREGA_LEGAL_FUNCIONAL_2026-09-14.md) incorpora guardado, archivos e historial de Legal, ya activados y verificados en Supabase.

## Disponible

- Entrada desde el menú de áreas de Dirección y una card en su dashboard.
- Dashboard con seis indicadores vacíos, once categorías y bloque de próximos vencimientos.
- Pantallas base de categoría con descripción, tipos documentales, encabezados propios, búsqueda y selectores de estatus/vencimiento.
- Calendario mensual navegable, selección de día, regreso a Hoy, selector de fecha y filtro de categoría; agenda vacía.
- Navegación compartida homologada con Finanzas: Seguimiento (Calendario), Expedientes (once categorías) y Accesos (Dashboard Gestión Documental y Dashboard Dirección, según el perfil actual).
- Tema rosa centralizado en fondos, glass, navegación, botones, cards, campos, filtros y pickers. El acento de confirmación es rosa profundo para conservar contraste con texto claro.

## Archivos

Dentro de `lib/app/gestion_documental/`:

| Archivo | Función |
| --- | --- |
| `gestion_documental_catalog.dart` | Registro central de categorías, iconos, descripciones, tipos documentales y columnas. |
| `gestion_documental_theme.dart` | Tokens rosas, configuración del shell y tema Material del área. |
| `gestion_documental_area_chrome.dart` | Menú y navegación común; mantiene el dashboard original al cambiar entre categorías. |
| `gestion_documental_dashboard_page.dart` | Dashboard, indicadores y cards navegables. |
| `gestion_documental_category_page.dart` | Vista inicial parametrizada por categoría. |
| `gestion_documental_calendar_page.dart` | Mes, selección de fecha y agenda inicial. |
| `gestion_documental_widgets.dart` | Cards, iconos, badges, encabezados y estados vacíos del área. |

Cambios de integración:

- `lib/app/dashboard/general_dashboard_page.dart`: entrada y navegación al área.
- `lib/app/shared/archetypes/dashboard/empty_area_dashboard.dart`: opción de encabezado/overlay adaptable, activada para Gestión Documental; foco del menú cerrado excluido y tooltips en botones compactos. Las otras áreas conservan su layout por defecto.
- `lib/app/shared/app_ui/AREA_PALETTES_CONTRACT.md`: sustituye la propuesta gris/azul por rosa.
- `test/gestion_documental/gestion_documental_navigation_test.dart`: navegación, selectores y tamaños de ventana.

## Decisiones y límites de esta entrega

La navegación utiliza `Navigator` y `appPageRoute` existentes. Los destinos funcionan dentro de la app; no se añadieron endpoints ni resolución de URLs web. Las categorías hermanas reemplazan la ruta de detalle para que Atrás regrese al Dashboard sin acumular pantallas.

Se reutilizan `EmptyAreaDashboardPage`, `AppShell`, `ContractGlassCard`, estilos de botones y selectores contractuales. El menú toma como referencia `FinanzasAreaSidePanel`: ancho de 320 px, bloques de radio 20 px, botones de radio 18 px con padding de 12 px, títulos de 14 px, subtítulos de 12 px y separación de 8 px. Conserva sus estados de hover y selección, con tokens rosas. Los módulos aparecen primero y los dashboards al final, en Accesos.

Los indicadores muestran `—` y las pantallas se identifican como “Vista inicial”. No hay documentos ficticios ni envíos simulados. Los filtros permiten revisar su interacción visual; todavía no consultan registros documentales. El botón Nuevo está deshabilitado y explica su disponibilidad futura.

No hay modelos de persistencia, migraciones, buckets, cambios de roles ni escrituras de negocio. La siguiente entrega funcional conectará Documentación Legal, carga/consulta de archivos, responsables y detalle. Quedan pendientes después Permisos y Trámites, semáforo, versiones, calendario derivado de registros y alertas.

El grid de esta etapa es una superficie vacía con encabezados: la edición, selección de filas y refresh se incorporarán sobre el contrato de Entradas y Salidas cuando existan registros.

## Validación

- `dart format` en archivos modificados.
- `dart analyze` del área, integración con Dirección, shell y pruebas: sin incidencias.
- Cuatro pruebas de widgets: cambio entre categorías y retorno sin duplicar dashboard; cierre con Escape; selección en calendario; tema rosa y foco del buscador en pickers; ausencia de overflow en 390×844, 800×900 y escritorio 1440×1000.
- Capturas renderizadas revisadas de Dashboard, menú (módulos y accesos), categoría legal, Calendario, date picker y ventanas compactas. Las capturas se regeneran opcionalmente con `DOCUMENTAL_PREVIEW=1 flutter test --no-pub test/gestion_documental/gestion_documental_navigation_test.dart` y se guardan en `/private/tmp/documental_*.png`.
- Recarga de la sesión local de Flutter; la nueva entrada de Gestión Documental aparece en el árbol de accesibilidad de Dirección. La automatización de clics de la ventana nativa presentó `noWindowsAvailable`, por lo que la navegación completa se verificó en las pruebas de widgets.

Se conservaron los cambios de trabajo preexistentes en Gerencia y reportes.
