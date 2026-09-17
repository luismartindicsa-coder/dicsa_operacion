# Dashboard y Calendario · datos reales

Continúa la [entrega de Auditorías](ENTREGA_AUDITORIAS_2026-09-14.md). Dashboard y Calendario consultan los expedientes reales de las once categorías. Conservan la navegación homologada con Finanzas y los tokens rosas del área. Elegir una fecha de la agenda abre el expediente original, con sus campos específicos, documentos, seguimiento e historial.

## Indicadores

Los conteos se calculan sobre todos los registros en Supabase, independientemente de las páginas cargadas en las listas. Para los indicadores de atención se consideran activos los estados **Pendiente** y **En proceso**. Completado, Cancelado y No aplica quedan fuera de esos indicadores.

| Indicador | Regla |
|---|---|
| Documentos activos | Pendiente o En proceso, con o sin vencimiento |
| Próximos a vencer | Activos con vencimiento desde hoy hasta dentro de 15 días, inclusive |
| Documentos críticos | Activos con vencimiento desde hoy hasta dentro de 5 días, inclusive; es un subconjunto de Próximos a vencer |
| Documentos vencidos | Activos con vencimiento anterior a hoy |
| Trámites pendientes | Permisos y Trámites con estado Pendiente |
| Trámites en proceso | Permisos y Trámites con estado En proceso |

Las tarjetas de categoría muestran el total de sus registros de cualquier estado, los próximos a vencer y los vencidos activos. El indicador de atención señala cuántos expedientes permanecen pendientes o en proceso.

**Próximas fechas** presenta hasta 12 fechas de expedientes activos, ordenadas por fecha ascendente, título, referencia, ID y tipo de fecha. El periodo empieza hoy e incluye los 29 días siguientes. Muestra el total del periodo y un acceso al calendario para consultar las restantes. Incluye vencimientos, inicios de vigencia, renovaciones y programaciones; excluye fechas de realización.

## Calendario derivado

No se crea otra tabla de eventos. Las fechas se obtienen del registro vigente:

| Fecha | Fuente |
|---|---|
| Vencimiento | `expiration_date`, en cualquier categoría |
| Inicio de vigencia | `start_date`, en cualquier categoría |
| Renovación | `renewal_date` en Contratos y Seguros, cuando el tipo de renovación no es No aplica |
| Programación | `scheduled_date` en Mantenimiento y Auditorías |
| Realización | `performed_date` en Mantenimiento y Auditorías |

Un expediente puede aparecer varias veces si tiene distintas clases de fecha, incluso el mismo día. La periodicidad no genera ocurrencias futuras automáticamente. Cambiar o quitar una fecha actualiza la agenda y conserva los valores anteriores en el historial del expediente.

El calendario incluye todos los estados inicialmente, también expedientes completados. Ofrece filtros combinables por categoría, tipo de fecha, responsable y estado. Los contadores mensual y diario cubren todos los resultados; la agenda pagina de 50 en 50. Si un cambio deja vacía la última página, vuelve a la última página válida.

Navegación: mes anterior/siguiente, selección de día, flechas del teclado (un día horizontal, una semana vertical), Ir a fecha y Hoy. Las flechas cruzan el límite de mes y mantienen el foco en el día seleccionado. Pickers y buscadores mantienen el contrato compartido de foco y teclado. En ventanas angostas, la agenda se coloca debajo del mes.

## Actualización y consistencia

La fecha de referencia procede de `documental_context`, con la zona America/Mexico_City. Ambos RPC devuelven ese contexto junto con sus resultados. La aplicación programa una actualización al siguiente cambio de día; Hoy sigue esa fecha del servidor, mientras una selección explícita conserva el día elegido.

Se reutiliza el coordinador compartido de refresh y su protección de edición: realtime y reanudación de la app recargan automáticamente; los cambios recibidos durante una captura se aplican al cerrarla. Las respuestas atrasadas no pueden aparecer bajo un mes o filtro recién elegido. Al salir de la pantalla se cancelan suscripciones y temporizadores.

Una consulta fallida muestra un error y datos no disponibles, en lugar de presentar ceros o una agenda vacía falsos. Hay reintento automático; las capturas conservan sus propias reglas de validación, conflicto e idempotencia.

## Base de datos y acceso

Migración `20260914235955_enable_documental_overview.sql`: aplicada y registrada en Supabase; el contenido registrado coincide exactamente con el archivo local. Agrega los RPC `documental_dashboard` y `documental_calendar` y la función interna `documental_event_dates`.

Los dos RPC requieren usuario autenticado y el acceso documental existente. La función interna no es invocable directamente por authenticated ni anon. No se modifica el guardado, la identidad del usuario documental ni los archivos existentes.

## Verificación

- 30 pruebas Flutter aprobadas: regresión de las once categorías, ingreso y navegación; indicadores, filtros combinados, más de 50 registros, edición desde ambas vistas, reprogramación, foco y flechas entre meses, pantallas compactas, fallos de conexión, medianoche del servidor, respuestas atrasadas y descarte tras salir de la pantalla.
- PostgreSQL aislado con catorce migraciones: conteos completos, límites del semáforo, estados cerrados, las once categorías, cinco tipos de fecha, paginación, filtros, febrero bisiesto, reprogramación, retiro de renovaciones, validaciones y rechazo de accesos no permitidos. Conserva las comprobaciones de guardado, versiones, idempotencia, conflicto y archivos privados.
- Análisis Dart sin incidencias. Capturas revisadas del Dashboard y la agenda con registros; disposición compacta comprobada en 800×900 y 390×844.
- Once recorridos reales en Supabase aprobados, uno por categoría, con el repositorio de producción y dos clientes. Verifican incremento y actualización de indicadores, fechas derivadas, lectura de expedientes completados, retiro de la fecha anterior al reprogramar y eliminación de renovaciones que dejan de aplicar. También comprueban guardado, reintento idempotente, descarga y sustitución de archivos, historial, conflicto, filtros y realtime.
- Acceso a ambos RPC verificado bajo `authenticated` con el UUID de `gestion@dicsamx.com`; Dashboard y Hoy devolvieron la misma fecha del servidor. Auditoría final: cero expedientes de prueba, metadatos de archivos, entradas históricas y objetos del bucket documental.
- Compilación macOS aprobada y señal de recarga enviada a la instancia en ejecución.

Para reproducir la validación local:

```sh
flutter test --no-pub test/gestion_documental
dart analyze lib/app/gestion_documental test/gestion_documental
flutter build macos --debug --no-pub
DOCUMENTAL_PGLITE_MODULE=file:///ruta/temporal/node_modules/@electric-sql/pglite/dist/index.js node tool/test_documental_sql.mjs
```
