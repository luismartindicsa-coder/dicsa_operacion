# Inventario previo: grid de Prenómina

A. Empleado: ID, nombre, empresa, salario semanal/percibido, fechas de ingreso/alta, asistencia, vacaciones/permisos, referencias fiscales, borrador e importes. No se cargan puesto, área ni sucursal.
B. KPIs existentes: colaboradores, listos/revisión, minutos de extra/retardo, vacaciones/permisos y montos del resumen. Fechas del periodo parseables con el helper existente.
C. Estados: Borrador, Revisión RH, Listo, Publicado, resueltos con `_resolveSummaryStatus`. Incidencias será sólo una agrupación visual de datos disponibles, nunca un estado persistido.
D. Filtros locales: mapa `_columnFilters`, coincidencia exacta sobre ID, nombre, sueldo, asistencia, vacaciones, permisos y estado; diálogo compartido `GridFilterDialog`. Sin query params. Búsqueda/empresa/incidencias se añaden como filtros visuales sobre el mismo conjunto cargado.
E. Empleado: click selecciona; doble click, Enter y menú abren el mismo diálogo de borrador; click derecho conserva menú y selección.
F. Selección múltiple existente por Cmd/Ctrl, Shift y arrastre; no hay publicación/revisión/exportación por lote seleccionable. No se agregan operaciones masivas.
G. Paginación local sobre filas filtradas: 40/80/120; anterior/siguiente y reconstrucción de selección. Se conserva.
H. Orden de la proyección existente; no existe sorting de columnas. No se dibujan flechas de sorting ficticias.
I. El detalle abre con `showDialog`, `_openSummaryRow` y `_openSummaryRowAtIndex`, sin URL; rutas generales, roles y cierre de sesión conservados.
J. Fiscal: getter `fiscalTotalAmount` (neto tras retardo más vacaciones).
K. Flujo: presentación ya adoptada en el detalle, `weeklyPaymentVisibleAmount - fiscalTotalAmount`; incluye neto operativo, pago por fuera y ajuste RH, sin duplicar distribución fiscal.
L. Total: `weeklyPaymentVisibleAmount`, sin alterar fórmula ni redondeos. Los KPIs mantienen el alcance de las filas filtradas, igual que antes, con etiqueta explícita; no sólo la página visible.
M. Fuentes: perfiles RH, asistencia diaria operacional, vacaciones, permisos, impactos por periodo, lotes CONTPAQ, borradores y cierres. Mismos loaders, consultas y cruces. El nuevo resumen de trabajados/faltas se deriva de registros ya cargados, sin consulta adicional.

Se toma como base la implementación después del refactor del editor individual. La referencia visual del usuario autoriza la reorganización y superficies lavanda de este grid; se mantiene el arquetipo de interacción de AGENTS.md. No se cambia el editor individual.

## Implementación final

- Modificado `lib/app/hr/human_resources_prenomina_page.dart`: conserva contenedor, fuentes y acciones. Guarda el conjunto antes de filtros para contadores del lateral y deriva diagnósticos desde asistencia ya cargada. Añade búsqueda/empresa/incidencias localmente, después de aplicar los filtros exactos existentes. Ajuste mínimo del branding local: escala hacia abajo cuando su espacio no alcanza, sin cambiar el header global.
- Creado `lib/app/hr/prenomina/prenomina_dashboard.dart`: header de acciones existentes, ocho KPIs, lateral con búsqueda/estado/empresa/incidencias, acceso a filtros por columna, contador de selección y paginación.
- Creado `lib/app/hr/prenomina/prenomina_grid.dart`: workspace, tabla, filas, cabecera y celdas compactas. Cabecera y filas comparten anchos; scroll horizontal conserva Fiscal/Flujo/Total y acciones. Nombre completo en tooltip, empresa debajo. Estados mantienen los badges existentes y las incidencias tienen indicador informativo separado.
- Creado `lib/app/hr/prenomina/prenomina_grid_test_support.dart`: anfitrión offline que hereda la página real; sustituye sólo lecturas/escrituras externas para pruebas. No se utiliza en rutas de producción.
- Creado `test/hr/human_resources_prenomina_grid_test.dart`: seis pruebas del nuevo grid.

Los siete IDs de filtros existentes (`id`, `nombre`, `sueldo`, `asistencia`, `vacaciones`, `permisos`, `estado`) mantienen sus valores y diálogo. Las tres nuevas columnas de presentación amplían la lista local de columnas de navegación; no agregan campos persistidos ni ordenamiento. La búsqueda añade coincidencia por ID/nombre/empresa; las selecciones de estado reutilizan `_columnFilters['estado']`.

Se retiraron del encabezado las colecciones de chips técnicos y los importes redundantes. Sueldos de referencia, desglose fiscal, depósito/distribución, ajustes y conceptos siguen en el modelo y en el detalle individual. Publicación/cierre siguen sus mismas validaciones. El grid mantiene selección y menú existentes; no agrega checkboxes que prometan operaciones masivas inexistentes ni botones de sorting sin soporte.

Fiscal usa `fiscalTotalAmount`. Flujo agrupa visualmente `weeklyPaymentVisibleAmount - fiscalTotalAmount`. Total usa `weeklyPaymentVisibleAmount`. El KPI Permisos conserva `permissionImpactDays`, que ya incluye incapacidad, y muestra además horas. Ceros de vacaciones/permisos se muestran como `0`; periodo sin fechas parseables se muestra como no disponible.

## Validación

28 pruebas de RH aprobadas, incluidas seis del grid y nueve del editor individual. Análisis estático sin incidencias en los archivos del refactor.

Caso de prueba: 45 colaboradores, 44 listos, 1 en revisión; 2 horas extra, 1 día de vacaciones y 1.5 días de permisos/incapacidad. Fiscal 99,000.00 + Flujo 14,850.00 = Total 113,850.00. Al pasar a la segunda página permanecen los totales del conjunto; buscar un empleado produce 2,200.00 + 330.00 = 2,530.00. Se verifican paginación 40/80, opciones existentes, búsqueda, estados, incidencias, empresa, limpiar, apertura/cancelación/guardado del detalle y despacho de cierre/exportación.

Se comparó el código previo y final ignorando espacios: sin cambios en loaders/roles, ciclo de vida/foco/selección, filtros originales/rutas/detalle/guardar/cerrar/exportar/paginación y modelos/payloads/fórmulas/helpers. Sólo se añadieron IDs locales de las tres columnas monetarias. El detalle individual no se modificó.

Se revisó captura con tipografía e iconos reales y se probaron 1555×1012 y 1000×760. No se cerró ni publicó un periodo real: las acciones externas se verifican por comparación de código y despacho a sustitutos offline. Requiere recompilar la instalación para mostrarlo.

## Inconsistencias y límites anteriores, separados del refactor

1. **Selección múltiple:** `_handleNavigationChanged` llama a `selectSingle` cuando la selección no tiene exactamente una fila. Los handlers de Ctrl/Shift/arrastre llaman a `focusGridCell`, que notifica ese listener y reduce la selección. Una prueba temporal contra la copia anterior confirmó el mismo resultado con Ctrl y Shift. Los handlers permanecen intactos por la instrucción de no mezclar correcciones históricas; se documenta como pendiente. La prueba de paridad registra esta limitación, no afirma que la selección múltiple funcione correctamente.
2. **Alcance de exportación:** `Exportar sobres` usa `_allRows` (conjunto filtrado, no la página ni la selección). Se conserva. El cierre sigue siendo global y valida empleados/borradores del periodo mediante los contadores originales, sin sustituirlos por los KPIs filtrados.
3. **Campos ausentes:** no se inventaron área/puesto/sucursal. No hay sorting ni acciones masivas de marcar listo/revisión/exportar selección. La información de asistencia procede del mismo modelo existente y se presenta sin equiparar días listos con días trabajados.
