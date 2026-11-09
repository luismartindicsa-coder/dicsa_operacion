# Integración EPCOM GPS para DICSA

Estado: integración continua activada el 4 de noviembre de 2026. Las 15 unidades
visibles en EPCOM quedaron vinculadas al catálogo de DICSA y con posición recibida.
Se verificaron ejecuciones automáticas correctas a las 17:31 y 17:32
(America/Mexico_City). La pantalla está en **Logística → Ubicación GPS**.
Tras reiniciar DICSA se comprobó la carga inicial de la cartografía sin mover el
mapa, con las 15 unidades y la consulta automática de las 17:39 del mismo día.

## Operación continua

- El servidor consulta EPCOM cada minuto mediante `logistics-gps-sync`. La app
  consulta el último resultado cada 30 segundos mientras la ventana está visible;
  conserva búsqueda, selección y encuadre durante las actualizaciones.
- Cada posición muestra su propia fecha. Se considera reciente hasta 15 minutos;
  un reloj adelantado más de un minuto requiere revisión. La consulta reciente del
  servidor no convierte una posición antigua en ubicación actual.
- Una conexión sin éxito durante más de tres minutos muestra aviso. Ante un error
  de EPCOM se conserva el último resultado con advertencia. Si una unidad deja de
  ser visible o su posición se vuelve privada, sus coordenadas se eliminan.
- Acceso de lectura restringido por RLS a perfiles activos de Logística/Servicios
  y Dirección, conforme a los roles existentes; Báscula queda excluida. La app no
  puede modificar posiciones ni ejecutar el sincronizador.
- La autorización de EPCOM es de sólo consulta (`access_type=256`) por un año,
  con vencimiento registrado conservadoramente el 4 de noviembre de 2027.
  Flutter muestra un aviso durante los siete días previos al vencimiento.
- El token vive en secretos de Supabase, fuera de Flutter y del repositorio. El
  cron obtiene su clave de invocación dedicada desde Vault. El endpoint exige
  esa clave aunque `verify_jwt=false`; las solicitudes sin ella reciben 401.
- No se guarda historial de trayectos. Sólo se conserva la última posición
  disponible por unidad. El mapa usa la misma cartografía de Catálogos Operativos.

Vínculos explícitos: C-001–C-005 → C1–C5; F-001–F-003 → F1–F3;
G-001/G-003/G-004/G-005 → G1/G3/G4/G5; T-001/T-003/T-004 → T1/T3/T4.
La relación permanente usa ID de EPCOM y UUID del vehículo. No se reasignan
vehículos por semejanza de nombre. Una unidad nueva queda sin vínculo hasta
validar su correspondencia. Los otros vehículos del catálogo no reciben una
posición inventada.

### Componentes y renovación

- Esquema y permisos: `supabase/migrations/20261104235900_add_logistics_gps.sql`.
- Consulta de Wialon: `supabase/functions/logistics-gps-sync/wialon.ts`.
- Función de servidor: `supabase/functions/logistics-gps-sync/index.ts`.
- Configuración/renovación: `tool/configure_logistics_gps.py`.
- Interfaz y lectura: `lib/app/logistica/logistics_gps_{page,store}.dart`.
- Programación: cron `dicsa-logistics-gps`, expresión `* * * * *`.

Para renovar, desde la raíz de esta app, con Supabase CLI autenticado y
`psycopg[binary]` instalado en el Python elegido:

```sh
python3 tool/configure_logistics_gps.py
```

El usuario autoriza directamente en EPCOM «DICSA GPS - Logistica». La herramienta
comprueba las unidades, actualiza los secretos, conserva la clave de invocación,
asegura la programación y ejecuta una primera consulta. No pegar tokens en el
chat ni pasarlos como argumentos. Requiere migración y función ya desplegadas.
La migración de GPS se desplegó de forma aislada, sin aplicar migraciones ajenas
pendientes del repositorio.

## Geocercas y empresas

Activadas el 4 de noviembre de 2026: **26 geocercas de EPCOM**, vinculadas a
**24 empresas y dos bases DICSA**, sin pendientes. Se consultan en
**Logística → Ubicación GPS → Geocercas**. El mapa conserva los límites definidos
en EPCOM y permite buscar por geocerca o empresa, filtrar y editar el vínculo.
Los puntos del catálogo de empresas se conservan sin cambios.

- `logistics-geofences-sync` consulta cada diez minutos, con la misma autorización
  de lectura ya guardada en el servidor. La consulta de unidades sigue cada minuto.
- Las 26 geocercas iniciales son círculos: Avon tiene radio de 250 m; las demás,
  100 m. También se admiten polígonos y corredores del proveedor.
- Las bases son Dicsa Apaseo y Dicsa Celaya. Archroma corresponde a ACROMA y
  Monroe Norte a MONROE, con coincidencia de coordenadas. El usuario confirmó
  expresamente BOSCH → BOCHS, LicBox → LICBOX y Monroe Sur → MONROE SUR.
  En LICBOX y MONROE SUR se usan los límites de EPCOM a pesar de las diferencias
  de 2.7 km y 17.5 km respecto al punto anterior del catálogo.
- La asociación usa el recurso e ID de geocerca de EPCOM y el UUID de la empresa.
  Cambios de nombre o geometría conservan el vínculo. Una geocerca nueva o un ID
  reutilizado por el proveedor queda pendiente de revisión.
- Un error de consulta conserva la última geometría con aviso. Si una geocerca
  deja de ser visible en una consulta completa, se retira del mapa y se elimina
  su geometría almacenada. El catálogo permite identificarla como no disponible.
- RLS limita la consulta a los mismos perfiles de GPS. El RPC de vinculación
  valida el permiso, la empresa activa y la versión del vínculo, para impedir
  que una edición antigua sobrescriba otra más reciente. La app no modifica EPCOM.
- El editor conserva su selección durante las actualizaciones y ante un error de
  guardado. Las geocercas también aparecen como referencia en el mapa de unidades.

La vinculación sirve de base para la bitácora de visitas y para la comparación
de consulta con Control Diario descrita al final. No modifica los servicios.

Componentes: migración `20261105001000_add_logistics_geofences.sql`, función
`supabase/functions/logistics-geofences-sync`, y
`lib/app/logistica/logistics_geofence_{store,widgets}.dart`.
La programación `dicsa-logistics-geofences` usa `*/10 * * * *` y se configura
con `python3 tool/configure_logistics_geofences.py` después del despliegue,
reutilizando la clave dedicada de Vault. La migración se desplegó de forma aislada.
Una segunda consulta real a las 17:56:01 confirmó las 26 geocercas y conservó
todos los vínculos. Tras compilar y reiniciar macOS, se verificaron el contador
sin pendientes, los perímetros de Avon y MONROE SUR y el editor de vínculos.
Pasaron las 28 pruebas de GPS, dashboard y operación, las pruebas del servidor
y el análisis de los archivos Flutter modificados.

## Bitácora automática de visitas

Activada el **4 de noviembre de 2026 a las 18:02 (America/Mexico_City)**.
La nueva pestaña **Logística → Ubicación GPS → Visitas** muestra unidad,
empresa/base, llegada o primera detección dentro, salida y estancia observada.
Incluye búsqueda, filtros de estado y periodos Hoy / 7 días / 30 días; las visitas
abiertas se incluyen aunque hayan empezado antes del periodo. El mapa de unidades
muestra el lugar confirmado o la falta de posiciones recientes para confirmarlo.

- El cron `dicsa-logistics-gps-visits` ejecuta `process_logistics_gps_visits()` cada
  minuto sobre las últimas posiciones ya sincronizadas, sin nuevas llamadas a
  EPCOM. La función es independiente de la carga GPS y solo puede ejecutarse
  desde el servidor. No modifica servicios, rutas ni Control Diario.
- Solo participan unidades vinculadas y geocercas de empresas activas o bases.
  Se exigen dos posiciones distintas y crecientes, separadas por al menos 60
  segundos y sin saltos superiores a quince minutos. Releer el mismo punto no
  cuenta como una confirmación. Posiciones anteriores a la activación, futuras,
  ausentes o con más de quince minutos de antigüedad no producen eventos.
- Una franja neutral de 20 m a cada lado del perímetro evita cambios por ruido
  del GPS. La confirmación empieza dentro de la zona interior o fuera de la zona
  exterior. Los círculos usan distancia esférica; polígonos y corredores usan
  proyección métrica local, adecuada para estas geocercas operativas, no deslindes.
- Si la unidad ya aparece dentro al comenzar o retomar el seguimiento, se registra
  **Detectada dentro**, no una llegada observada. Las horas de llegada y salida
  son aproximadas, usando la primera posición de la secuencia confirmada. No se
  reconstruye historial anterior ni se garantizan visitas más breves que el
  intervalo de muestreo y confirmación.
- Una pérdida de señal no registra una salida. Se conserva la visita abierta y
  se marca la interrupción. La duración deja de avanzar con el reloj: usa la
  última posición dentro. Cuando hubo un hueco, el total se muestra como no
  determinable, aunque después se confirme que la unidad salió.
- Un cambio de vínculo, geometría, vehículo o disponibilidad interrumpe el
  seguimiento sin inventar una salida. Los nombres y asociaciones históricos
  quedan como se registraron. Geocercas superpuestas pueden producir varias
  visitas simultáneas; no se escoge una empresa arbitrariamente.
- Si falla la fuente GPS, la consulta de geocercas o el detector, la pantalla
  avisa que la detección está en pausa. El historial permanece disponible. RLS
  restringe las tres tablas a los mismos perfiles autorizados para GPS; los
  clientes no pueden editar la bitácora ni ejecutar el detector.

Esquema: `20261105003000_add_logistics_gps_visits.sql` y ajuste
`20261105004000_adjust_gps_visit_fix_window.sql` para equipos detenidos que
renuevan posición aproximadamente cada diez minutos. Programación:
`python3 tool/configure_logistics_gps_visits.py`, después de desplegar la migración.
Interfaz: `logistics_gps_visit_store.dart` y `logistics_gps_visits_panel.dart`.
La prueba SQL reproduce entradas/salidas, inicio dentro, pérdida y recuperación
de señal, posiciones repetidas/futuras/fuera de orden, ruido en bordes, cambios
de geocerca y aislamiento de permisos. No se insertaron visitas ficticias en
producción para comprobar la pantalla.

Verificación real: las ejecuciones automáticas de las 18:09 y 18:10 terminaron
correctamente. La primera visita fue **G1 en Dicsa Celaya**, detectada dentro desde
las 18:07 y confirmada con una posición posterior; se verificó abierta en la app,
sin una llegada o salida inventada. Pasaron las pruebas SQL del detector, nueve
pruebas de GPS/geocercas/visitas y veinte de dashboard/operación, junto con análisis
Flutter y compilación macOS. Se comprobó la interfaz en 800 y 1440 píxeles, búsqueda
y selección persistentes durante actualizaciones, teclado y duración ante huecos.

## Rendimiento con kilometraje histórico de EPCOM

Conectado el **5 de noviembre de 2026** en **Logística → Rendimiento**.
EPCOM aporta kilómetros de los recorridos detectados por unidad y día terminado;
DICSA los cruza con los litros despachados de diésel o cargados de gasolina y los
servicios completados. Los km/L siguen siendo una **estimación por cargas del
periodo**, no una medición del combustible consumido ni un indicador individual
del chofer. Los precios faltantes permanecen pendientes, sin inventar importes.

- Se recuperó el periodo **1–4 de noviembre** para las 15 unidades vinculadas.
  El 4 de noviembre, 14 unidades tienen datos; F3 no tiene mensajes disponibles.
  Las 297 lecturas Excel previas se conservaron sin cambios.
- La primera comprobación de contadores acumulados encontró cálculo automático
  solo en F1 y T4. Por eso esta integración usa `messages/load_interval` y
  `unit/get_trips`, con el detector histórico de EPCOM, no diferencias entre los
  últimos puntos del mapa ni esos contadores desactivados.
- **El acceso existente funcionó en pruebas reales del historial**, sin renovar
  token ni ampliar permisos. La suposición inicial de necesitar otra autorización
  quedó descartada por la respuesta real del servidor. No se modificaron equipos,
  geocercas, contadores ni permisos en EPCOM.
- Solo se consultan días terminados, de 00:00:00 a 23:59:59 en
  `America/Mexico_City` para el comparativo cerrado. El recorrido provisional de
  hoy se consulta por separado en «Desde última carga», como se describe abajo.
  La API devuelve metros por recorrido; se convierten una vez a kilómetros.
- Se cargan en la sesión del proveedor mensajes con ubicación (flags 1, máscara
  65281). No se descargan ni almacenan trayectorias completas. Menos de dos
  posiciones significa datos insuficientes, no cero kilómetros. Cero significa
  que EPCOM no detectó recorridos entre los mensajes consultados.
- `logistics-mileage-sync` atiende una unidad/día por ejecución, con lease y
  sesión independiente, autenticada con la clave de servidor existente. El cron
  `dicsa-logistics-mileage` corre cada minuto; sin días pendientes atiende las
  ventanas de última carga descritas abajo.
  Revisa los últimos tres días cada 12 horas por mensajes que lleguen tarde.
- Los resultados se guardan en `logistics_gps_daily_mileage`. Un error conserva
  el dato anterior para revisión, pero no lo presenta como lectura actual válida.
  Reintenta después de una hora; los errores de autorización frenan nuevas
  solicitudes durante ese intervalo.
- Rendimiento usa el vínculo explícito de vehículo y fecha. Un Excel importado
  tiene prioridad sobre EPCOM para ese mismo día: nunca suma ambas lecturas. Se
  muestra el origen en el detalle. Días pendientes o sin datos bloquean el km/L
  del periodo; se conserva la navegación, filtros y actualización silenciosa.
- RLS limita lectura al mismo grupo de GPS. El cliente puede corregir únicamente
  los precios por litro de las lecturas EPCOM; kilómetros, resultados y cola solo
  pueden escribirse desde el servidor. Los precios se conservan al recalcular.

Componentes: migraciones `20261105160000_add_epcom_daily_mileage.sql` y
`20261105161000_require_gps_positions_for_daily_mileage.sql`, función
`supabase/functions/logistics-mileage-sync`, herramienta
`tool/configure_logistics_mileage.py`, y archivos existentes
`logistics_performance_{store,data,page}.dart`. Las migraciones se desplegaron
aisladas, sin aplicar cambios pendientes ajenos al GPS.

Validación: pruebas del worker para fechas, unidades, errores, metros/km y ausencia
de datos; prueba SQL para cola, reintentos, fechas de México, permisos y edición
exclusiva de precios; pruebas Flutter para prioridad del Excel, no duplicación,
precios en la fuente correcta, datos incompletos y refresh. Análisis Flutter y
compilación macOS correctos. La verificación real del 4 de noviembre obtuvo, por
ejemplo, C1 90.509 km, C4 120.856 km y F1 212.759 km. La carga inicial terminó con
53 lecturas y siete días/unidad sin posiciones, sin errores ni pendientes. Se
reinició la app y se verificó el detalle real de C4 con kilometraje EPCOM,
cargas de combustible y servicios del periodo.

Documentación de referencia:
- [Recorridos y distancia histórica](https://help.wialon.com/en/api/user-guide/api-reference/unit/get_trips).
- [Mensajes de un intervalo](https://help.wialon.com/en/api/user-guide/api-reference/messages/load_interval).
- [Selección de mensajes con ubicación](https://help.wialon.com/en/api/user-guide/api-reference/messages/message-request-examples).

## Corte cerrado y seguimiento desde última carga

Activado el **5 de noviembre de 2026**. El usuario confirmó que los litros de
«Solicitados» ya fueron entregados y que las cargas son parciales o de cantidad
fija. Una carga no equivale al consumo del intervalo ni al nivel del tanque.

- El comparativo usa **Últimos 7 días / Últimos 30 días completos**, siempre
  hasta ayer en el horario operativo de México. Kilómetros, servicios y cargas
  comparten el corte; la selección personalizada tampoco incluye hoy. La tarjeta
  de Rendimiento del dashboard usa los últimos 30 días y combina Excel/EPCOM con la
  misma prioridad por unidad/día. Los faltantes siguen identificados, sin ceros
  inventados; el km/L disponible se marca parcial si el recorrido está incompleto. La cola histórica
  comenzó el 1 de noviembre y se recuperó además el hueco del 26 al 31 de
  octubre: 81 lecturas válidas y nueve días/unidad sin mensajes suficientes.
  Las 297 lecturas Excel anteriores permanecen; otros huecos del periodo elegido
  se muestran explícitamente.
- **Desde última carga** muestra fecha, litros entregados, recorrido consultado
  y hora del último punto GPS incluido. Por indicación del usuario, **no se solicita
  hora de carga**: no hay campo, botón ni aviso de hora pendiente. Para una carga
  de hoy se muestra el recorrido completo de hoy y se aclara que puede incluir
  kilómetros anteriores a cargar. Para una carga anterior, el recorrido comienza
  a medianoche del día siguiente y se declara que excluye el día de carga.
- La columna **KM/L · 7 DÍAS** muestra el mismo rendimiento del comparativo cerrado:
  suma de kilómetros ÷ litros entregados del periodo. El detalle abre con el km/L,
  fechas y cifras utilizadas. Se conservan las indicaciones de datos incompletos,
  falta de litros o combustibles mezclados; no se inventa un resultado. Los km de
  hoy no se dividen por una carga de hoy para evitar mezclar intervalos distintos.
- El detalle permite abrir el registro original y revisar los días incluidos.
  No se toma la hora de creación del registro como hora de entrega. Se conservan
  los campos opcionales y la compatibilidad con datos previos en el servidor;
  la interfaz no captura ni modifica horas de carga.
- Las cargas de una misma fecha se suman sin inventar su orden. Una firma de IDs,
  litros y datos originales invalida resultados ante cargas nuevas, correcciones
  o eliminaciones, incluso si el proveedor estaba consultando.
- El mismo worker y cron atienden hasta tres ventanas en sesiones independientes
  cuando no hay días cerrados pendientes. Rotación objetivo de cinco minutos
  para las quince unidades; el cierre diario conserva prioridad. Se consultan
  cargas de los últimos treinta días, hasta el último punto GPS observado, nunca
  hasta una hora futura. Requiere sincronización GPS reciente y posiciones de
  menos de quince minutos. Los errores conservan datos con aviso; menos de dos
  mensajes es información insuficiente, no cero kilómetros.
- Se usan el acceso de lectura y la clave de servidor existentes. La tabla de
  seguimiento solo permite lectura a los perfiles GPS y escritura del servidor.
  El cálculo funciona con los kilómetros y litros ya registrados. Por indicación
  del usuario, no se solicita nivel del tanque, recorrido pendiente ni mediciones
  adicionales de combustible; se retiraron la lista de verificaciones y sus avisos.

Componentes: migración `20261105210000_add_fuel_load_followup.sql`, tabla
`logistics_gps_load_mileage`, vista de servidor `logistics_latest_fuel_loads`, RPC
`set_logistics_fuel_load_time` y archivos `logistics_fuel_followup_{store,widgets}.dart`.
La migración se aplicó de forma aislada y se desplegó `logistics-mileage-sync`,
sin cambiar cron, permisos EPCOM, geocercas ni visitas.

Validación: pruebas SQL de hora real, límites de fecha, permisos, concurrencia,
invalidación durante consulta y ausencia de ceros ficticios; seis pruebas del
worker incluidas ventanas parciales; 43 pruebas Flutter de corte, firma de carga,
seguimiento por fecha sin solicitud de hora, cierre con Esc, fuentes, costos,
filtros y dashboard. Análisis Flutter
sin incidencias, compilación macOS y reinicio verificados. Se comprobó con datos reales: C1 cargó 150 L el 5 de noviembre; el primer resultado
fue **151.680 km de hoy hasta las 14:32**, correctamente marcado como recorrido
que incluye antes de cargar, porque no se conoce la hora. C2 mostró 47.053 km
desde el día siguiente a su carga del 4 de noviembre. No se capturaron horas
ficticias para probar producción. Los 196 registros de diésel (27,324.81 L) y 39
de gasolina (3,695.90 L) conservaron sus cantidades durante el despliegue.
La revisión final dejó 14 ventanas de carga con recorrido y una pendiente de
posición reciente; la cola de días cerrados quedó sin pendientes ni errores.

Ajuste posterior solicitado por el usuario: se retiró la captura de hora y sus
avisos. Pasaron las 18 pruebas de seguimiento y Rendimiento y el análisis de
los cinco archivos afectados; el seguimiento funciona con la fecha registrada.

## Prueba inicial

Estado: acceso real comprobado el 4 de noviembre de 2026 a las 17:19:51
(America/Mexico_City). La autorización temporal permitió consultar 15 unidades,
todas con posición: 11 recientes (hasta 15 minutos) y 4 atrasadas según el umbral
de la prueba. El cierre de sesión terminó sin advertencias. Estas cantidades son
una fotografía de esa consulta, no un monitoreo continuo.

El token de la prueba no se guardó; la integración continua usa una autorización
posterior e independiente. El acceso técnico satisfactorio no confirma
si el proveedor aplica cargos adicionales por API.

El portal confirmado por el usuario es https://gps.epcom.net. El portal y el servidor
de API pueden tener direcciones diferentes. No usar la API comercial de
developers.epcom.net: corresponde al catálogo de productos, no a la flota.

## Prueba con inicio de sesión

Requiere Python 3.9 o posterior, sin paquetes adicionales. Desde la raíz de la app:

```sh
python3 tool/epcom_gps_probe.py --authorize
```

Abrir el enlace emitido en el navegador de esta computadora. El usuario inicia
sesión directamente en EPCOM y autoriza la consulta de seguimiento. La solicitud
usa `access_type=256` y una duración de una hora. El token se recibe mediante un
callback aleatorio en `127.0.0.1`, se mantiene solo en memoria y no se imprime.
El receptor espera hasta 20 minutos. Si expira, ejecutar de nuevo.

El servidor de API se obtiene de `wialon_sdk_url` en la respuesta de autorización.
Solo se aceptan los servidores documentados de Wialon o el portal confirmado.
Si el proveedor no lo devuelve, confirmar su servidor y repetir con `--api-url`.
También se admite `--api-url` con `--token-file` para un token ya autorizado,
guardado en un archivo privado fuera del repositorio. Nunca incluir un token en
Flutter, assets, commits, parámetros de línea de comandos o mensajes del chat.

La prueba inicia sesión, pagina las unidades visibles, obtiene la última ubicación
y cierra su propia sesión. Solo invoca `token/login`, `core/search_items` y
`core/logout`. No modifica unidades, activa servicios, envía comandos ni toca Supabase.

La salida normal contiene cantidades y advertencias, sin ubicaciones ni secretos.
`--output /ruta/privada/nombre-nuevo.json` permite guardar detalles en un archivo
nuevo con permisos 0600. El reporte contiene ubicaciones y debe permanecer fuera
del repositorio. El cierre de sesión no revoca el token: este vence al cumplirse
la hora solicitada.

## Criterios de la prueba

- Autenticación válida, al menos una unidad visible y posición con fecha verificable.
- Confirmar qué ID de EPCOM corresponde a cada vehículo de DICSA; no vincular por
  nombre automáticamente ni tratar el ID de EPCOM como el UUID de `vehicles`.
- Separar posiciones recientes (hasta 15 minutos, umbral de esta prueba), atrasadas,
  ausentes/privadas y con reloj adelantado. Última posición no significa ubicación en vivo.
- Una cuenta vacía o un error 7 requiere revisar permisos/servicios con el proveedor;
  no demuestra por sí solo que sea necesario contratar un complemento.
- El resultado técnico no confirma la tarifa de API. Los cargos deben verificarse
  con el proveedor antes de habilitar un servicio facturable.

## Verificación local

```sh
python3 -m unittest discover -s tool -p 'test_epcom_gps_probe.py' -v
node --test tool/test_logistics_gps_worker.mjs
node --test tool/test_logistics_geofences_worker.mjs
DICSA_PGLITE_MODULE=/ruta/a/@electric-sql/pglite/dist/index.js node tool/test_logistics_gps_sql.mjs
DICSA_PGLITE_MODULE=/ruta/a/@electric-sql/pglite/dist/index.js node tool/test_logistics_geofences_sql.mjs
DICSA_PGLITE_MODULE=/ruta/a/@electric-sql/pglite/dist/index.js node tool/test_logistics_gps_visits_sql.mjs
flutter test test/logistica/logistics_gps_test.dart test/logistica/logistics_dashboard_page_test.dart test/logistica/logistics_operations_test.dart
```

La suite SQL cubre aislamiento por rol, ausencia de escritura desde clientes,
vínculos explícitos, exclusión mutua, actualizaciones atómicas y eliminación de
posiciones revocadas. La suite del worker cubre paginación completa, errores HTTP
200, validación de origen y rechazo de invocaciones sin autorización. La interfaz
prueba búsqueda/selección durante refresh, tamaños de ventana, permisos revocados
y errores sin pérdida del último resultado. La compilación macOS se verificó.
Las pruebas de geocercas cubren lotes completos, conversión de pies a metros,
validación de geometría, RLS, concurrencia de vínculos y reutilización de IDs.
La interfaz prueba edición y reintento, foco del buscador, navegación con flechas,
cierre con Esc y tamaños de ventana de 800 y 1440 píxeles.

Documentación oficial consultada:
- [Autorización](https://help.wialon.com/en/api/user-guide/getting-an-access-token)
- [Permisos de tokens](https://help.wialon.com/en/api/user-guide/api-reference/token/update)
- [Consulta y paginación](https://help.wialon.com/en/api/user-guide/api-reference/core/search_items)
- [Ubicaciones de unidades](https://help.wialon.com/en/api/user-guide/data-format/units)
- [Errores de API](https://help.wialon.com/en/api/user-guide/error-codes)
- [Recursos y geocercas](https://help.wialon.com/en/api/user-guide/data-format/resources)
- [Geometría de geocercas](https://help.wialon.com/en/api/user-guide/api-reference/resource/get_zone_data)

Ajuste de lectura directa (5 de noviembre): el seguimiento muestra el km/L de
los siete días cerrados sin solicitar datos adicionales. Pasaron 26 pruebas de
Rendimiento, seguimiento y costos, incluidas la exclusión de hoy, litros del mismo
periodo, independencia del nivel del tanque y los casos con datos incompletos.
Verificación en DICSA reiniciado: F1 muestra 8.07 km/L para el 29 de octubre al
4 de noviembre (764.8 km y 94.8 L). El detalle abre con ese resultado y sus
cifras; no aparecen solicitudes de nivel, ruta ni combustible adicional.

## Corrección del promedio alto con cargas parciales

El 5 de noviembre se detectó que el corte de siete días daba una referencia
engañosa para cargas parciales: F2 sumaba 518.137 km y solo 55.44 L en el corte,
dejando fuera los 78.57 L del 27 de octubre. G3 dejaba fuera 116.39 L del 28 de
octubre y mostraba 6.88 km/L. El cociente era aritméticamente correcto, pero no
representaba consumo medido. No se aplicaron topes ni factores para bajar cifras.

- Rendimiento abre en **Últimos 30 días**; el seguimiento de última carga y la
  tarjeta del dashboard usan ese mismo corte, siempre hasta ayer.
- La columna se denomina **KM/L CARGADO**. Pantalla, detalle y PDF aclaran que
  los litros entregados pueden diferir de los consumidos. Los cortes cortos
  conservan su información y explican la variación por cargas fuera del corte.
- Se recuperaron 154 días/unidad faltantes del 6 al 25 de octubre: 132 lecturas
  válidas y 22 sin posiciones suficientes. No se modificaron cargas ni Excel.
  La cola terminó sin pendientes ni errores. Los faltantes impiden publicar
  un promedio como completo, aunque ocurran antes de los últimos siete días.
- Referencias verificadas del 6 de octubre al 4 de noviembre: F2,
  2689.392 km / 806.38 L = **3.34 km/L**; G3, 2105.008 km / 958.21 L =
  **2.20 km/L**. F1 queda sin estimación por historial GPS incompleto.
- Pasaron 45 pruebas de Rendimiento, seguimiento, costos y dashboard; análisis
  sin incidencias y compilación macOS. La regresión reproduce la diferencia de
  F2 entre siete y treinta días, los límites de fechas y la exclusión de hoy.
  Se mantienen los flujos sin pedir hora, nivel, ruta ni combustible adicional.
- DICSA se reinició y se verificaron el dashboard, el comparativo abierto por
  defecto en 30 días y el seguimiento. El detalle de F2 muestra 3.34 km/L,
  2689.4 km / 806.4 L y las fechas 06/10–04/11; la carga y el recorrido del
  5 de noviembre permanecen separados. El detalle cierra con Esc.

## Referencias parciales cuando faltan días de kilometraje

El usuario reportó que demasiadas unidades seguían sin estimación. La auditoría
del 5 de noviembre confirmó que C1 tenía cinco días sin posiciones, C2 seis y C3
dos; todos coincidían con fines de semana sin servicios ni cargas registrados.
La ausencia de actividad registrada no prueba que la unidad estuviera inmóvil.
La regla anterior ocultaba la referencia de todo el mes por cualquier día faltante.

- Se conserva el corte de 30 días hasta ayer y **todos** los litros cargados del
  periodo, incluso los de días sin kilometraje. No se cambian lecturas faltantes
  a cero, se extrapolan recorridos ni se quitan cargas del denominador.
- Si hay kilometraje y litros del mismo combustible, la tabla, detalle y PDF
  muestran el cociente disponible con **(parcial)** cuando falta algún día.
  El seguimiento informa los días con km y sin km. El detalle explica que el
  valor puede aumentar al recuperar historial y no confirma un rendimiento bajo.
- El valor completo `performance` permanece nulo mientras existan faltantes;
  `recordedPerformance` representa exclusivamente la referencia disponible.
  Ninguna lectura, ausencia de cargas o mezcla de combustibles sigue impidiendo
  el cálculo. Un cero medido se distingue de una lectura ausente.
- Referencias parciales con los registros actuales: C1 **1.46 km/L** (25 días
  con km, cinco faltantes), C2 **2.11** (24 y seis), C3 **4.02** (28 y dos).
  F1, F3, T1 y T4 también muestran su referencia parcial, sin esconder avisos.
  F3 no ha comunicado posición desde el 26 de octubre.
- Pasaron 28 pruebas de Rendimiento, seguimiento y costos y el análisis de seis
  archivos. Las pruebas cubren cargas en días sin lectura, huecos sin actividad,
  cero medido, ninguna lectura, mezcla de combustibles y transición automática
  de parcial a completo al llegar la lectura faltante, sin escrituras de datos.
- Compilación macOS y verificación tras reiniciar DICSA: en 30 días aparecen
  referencias para las 15 unidades con kilometraje y cargas, siete parciales.
  Permanecen sin cálculo siete filas sin kilometraje (incluidas las cargas sin
  unidad). Se verificaron visualmente las etiquetas parciales en 30 y siete días.

## Precios de combustible sin importación

- Rendimiento incorpora **Precios de combustible** en todas sus vistas,
  incluido Desde última carga. Reutiliza el diálogo existente: diésel y gasolina
  por litro, con una fecha de vigencia que inicia en hoy y permite elegir fechas
  anteriores. No requiere importar Excel ni tener kilometraje para calcular gasto.
- `logistics_fuel_prices` conserva cambios por fecha. Cada combustible utiliza su
  último precio vigente; dejar un campo vacío conserva el anterior. El selector
  de fechas guardadas permite corregir una vigencia. Los precios individuales
  existentes conservan prioridad sobre el general. No se altera el cálculo km/L.
- Las lecturas usan RLS y el guardado usa una función que valida fecha, precio y
  permisos de Logística/Dirección. La migración se desplegó aisladamente, sin
  aplicar otras migraciones locales pendientes ni introducir precios de prueba.
- Pasaron 31 pruebas de costos, Rendimiento y seguimiento, además de las pruebas
  SQL de permisos y validación. Se comprobó el costo sin kilometraje, la vigencia
  independiente por combustible, la prioridad de precios individuales, el guardado
  sin importar, la conservación de campos vacíos y la recuperación ante errores.
  Enter guarda y Esc cancela; durante el guardado se impide cerrar o duplicar la
  operación. Análisis de cuatro archivos sin incidencias.
- Compilación macOS correcta. Se reinició DICSA y se verificaron el nuevo botón,
  los dos campos, el calendario y la selección de una fecha anterior; se cerró
  con Cancelar sin guardar precios. La tabla general permanece vacía hasta la
  primera captura real del usuario.

## Visitas de cinco minutos y paradas fuera de geocercas

- Activado el 5 de noviembre de 2026 a las **16:20, hora de México**. La
  sincronización confirmó 26 geocercas visibles y vinculadas: 24 empresas y dos
  bases. Las nuevas visitas requieren posiciones distintas que acrediten al
  menos cinco minutos dentro. Se conserva la confirmación de salida de un minuto
  y la banda de incertidumbre del borde de 20 m. Los registros anteriores
  conservan su regla de un minuto, visible en el detalle; no se reescribe historia.
- **Ubicación GPS → Paradas** registra detenciones fuera de todas las geocercas
  visibles de EPCOM, también si alguna aún no está vinculada. Requiere velocidad
  conocida de hasta 3 km/h y posiciones durante cinco minutos dentro de 50 m del
  punto inicial; el centro no se desplaza con la unidad. La velocidad proviene de
  `pos.s` de la [respuesta de unidades de Wialon](https://help.wialon.com/en/api/user-guide/data-format/units).
  Una velocidad ausente permanece desconocida, nunca se sustituye por cero.
- El proceso corre cada minuto en el servidor. Repetir una posición antigua no
  acumula tiempo; si el equipo reporta cada diez minutos, la confirmación espera
  al siguiente envío. Se toleran intervalos de hasta 15 minutos entre posiciones,
  por lo que son observaciones aproximadas, no una trayectoria continua. Una
  interrupción de señal, pérdida de acceso o cambio de límites interrumpe el
  seguimiento sin inventar salida ni duración. El registro empieza desde la
  activación, sin reconstruir paradas anteriores.
- La pestaña permite buscar unidad, coordenadas y nota; filtrar por periodo y
  revisión; abrir el mapa con el punto observado, su radio y las geocercas
  actuales; y copiar coordenadas para crear una geocerca en EPCOM. El tiempo
  muestra **al menos los minutos observados**, sin sumarle el reloj actual ni el
  intervalo hasta una salida posterior. Las paradas abiertas permanecen visibles
  aunque hayan comenzado antes del periodo seleccionado.
- **Revisar parada** guarda una explicación manual, usuario y fecha. El GPS no
  determina el motivo. Enter guarda, Esc cancela y los errores conservan el texto.
  Las notas tienen control de versión para evitar sobrescribir otra revisión;
  los datos GPS no son editables desde este diálogo. Las revisadas permanecen en
  el historial y salen del filtro inicial de pendientes. Se mantienen los
  permisos existentes de Logística/Dirección y el acceso de EPCOM de solo consulta.
- Cinco minutos reducen visitas por paso, pero no resuelven geocercas realmente
  superpuestas: el detalle advierte cuando una unidad coincide con varias. No se
  asigna arbitrariamente una empresa ni se crean geocercas automáticamente.
- Validación: pruebas SQL de temporización, movimiento, bordes, velocidad ausente,
  posiciones repetidas, pausas, cambios de geometría, permisos y revisiones
  simultáneas; siete pruebas del conector y doce pruebas Flutter. Se verificaron
  búsqueda, mapa, notas, recuperación de errores y vistas de 1440/800 px. Análisis
  de siete archivos sin incidencias y compilación macOS correcta.
- Migración aplicada de forma aislada, conector desplegado y cron activo. El
  servidor confirmó velocidad disponible en las 15 unidades, monitores correctos
  y una candidata aún sin cumplir cinco minutos. DICSA se reinició y se verificó
  la regla nueva en Visitas, la etiqueta histórica de un minuto, el aviso de
  geocercas superpuestas y la pestaña Paradas con su fecha de inicio, sin errores.
  No se introdujeron paradas ni notas ficticias en producción.


## Asignación de visitas y papelera reversible (implementación local)

`Ubicación GPS → Asignación` presenta servicios de Control Diario en tabla y
visitas disponibles en una bandeja. Seleccionar un servicio muestra sus visitas
compatibles; se asignan con botón o arrastrándolas a la fila. La tabla conserva
hora programada, empresa, tipo de servicio, unidad, estado y visita asignada.
Hay búsqueda, navegación Hoy/Ayer/día y filtros Todos/Sin asignar/Asignados.
La bandeja pasa debajo de la tabla en ventanas pequeñas.

Reglas de relación:
- Una visita por servicio y un servicio por visita. Las sugerencias por fecha,
  unidad y empresa nunca se convierten en asignaciones sin intervención.
- Usa identificadores de unidad y empresa y la fecha prevista (`due_date`, o
  `service_date` si está vacía), en hora de Celaya. No relaciona por nombres.
- Visitas de al menos cinco minutos, excluyendo DICSA Celaya. No permite nuevas
  asignaciones a servicios cancelados. Si un servicio asignado se cancela o se
  modifica, conserva su fila para revisar y quitar la relación.
- Interrupciones GPS requieren una nota. La asignación marca el servicio como completado en la misma transacción.
  Conserva los datos originales del GPS.
- Quitar la asignación libera la visita. Reasignar crea un registro nuevo y conserva
  la relación anterior, autor, fecha, nota y las instantáneas revisadas.

`A papelera` está disponible en Visitas, Paradas y la bandeja de Asignación.
Pide un motivo, oculta el evento del trabajo y permite recuperarlo desde la
pestaña `Papelera`. La papelera incluye búsqueda, filtro Visitas/Paradas y
Restaurar. Los datos originales y el detector permanecen intactos: si el evento
sigue abierto, continúa recibiendo observaciones aunque esté oculto. Restaurar
lo devuelve sujeto al período y filtros habituales.

Una visita asignada no puede descartarse hasta quitar su relación. El servidor
valida esta regla, los permisos de GPS, la compatibilidad y la exclusividad, con
bloqueos y comprobación de la asignación esperada para evitar sobrescrituras.
Cada envío y restauración conserva quién lo hizo y cuándo.

Archivos de datos: `logistics_gps_curation_store.dart` y migración
`20261106001000_add_gps_assignments_and_trash.sql`. Migración aplicada al servidor vinculado el 5 de noviembre de 2026. Se verificaron
ambas tablas con RLS y las tres funciones con acceso autenticado, sin acceso anónimo.
Evidencia: `work/gps_assignment_enable_20261105/enabled.json` en la raíz del workspace.
La sesión macOS abierta ya contiene la interfaz de Asignación y Papelera; no se
ha publicado un instalador nuevo para otros equipos.

Validación: `logistics_gps_assignment_workflow_test.dart`,
`logistics_gps_reconciliation_test.dart`, `logistics_gps_test.dart` y
`tool/test_logistics_gps_curation_sql.mjs`. Incluyen arrastre y botón,
asignación/quitar, errores, papelera/restaurar para ambos eventos, filtros,
ventanas de 800/1440 px, restricciones de datos y permisos.


### Completar Control Diario al asignar (6 de noviembre de 2026)

Migración `20261106010000_complete_gps_assigned_services.sql` aplicada y verificada
contra el servidor vinculado. Una asignación válida completa el servicio en la
misma transacción; un error no modifica su estado. Quitar la relación no reabre
el servicio. La tabla Asignación excluye todos los servicios completados,
incluso los completados manualmente sin visita GPS. Después de asignar se
recarga Control Diario para retirar inmediatamente la fila.

La actualización histórica sólo afecta asignaciones activas de Logística y
conserva cancelaciones. En esta activación no había servicios asignados pendientes
de completar. Evidencia: `work/gps_completion_20261106/deployed.json`.
