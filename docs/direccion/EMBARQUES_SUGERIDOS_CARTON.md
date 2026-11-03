# Embarques sugeridos de cartón

Dirección → Embarques calcula la propuesta con inventario e historial operativo.
Las metas son **resultados** de los embarques factibles y su producción requerida;
no se consultan ni se exigen metas de Gerencia para generar sugerencias.
El PDF proporcionado por el usuario es referencia informativa y no se modifica.

El subtab **Real** precarga las salidas de Operación y permite confirmar o corregir
las cantidades ejecutadas. Las próximas sugerencias usan ese historial confirmado,
sin duplicarlo. Confirmar también actualiza la agenda con embarcados, cancelados y
cargas adicionales; la referencia original se conserva para comparar. Ver [Resultados reales](RESULTADOS_REALES.md).

## Flujo

1. **Embarques sugeridos** abre **Empresas de la semana**, con búsqueda y casillas
   para elegir los clientes con historial a los que sí se venderá. Una semana nueva
   empieza sin empresas marcadas. **Generar sugeridos** guarda esa elección para
   esa semana y presenta fechas, cantidades, disponibilidad, reservas y condiciones.
   **Cambiar empresas** permite ajustar la elección y recalcular la propuesta.
2. La selección muestra las metas resultantes por material: embarques realizados
   + compromisos + selección, y producción ya realizada + producción adicional
   necesaria para cubrir compromisos y selección con el piso disponible.
3. **Guardar selección** guarda como `planeado`. **Aceptar embarques** guarda
   como `confirmado` y mantiene la lista disponible para editar fecha, destino,
   material, cantidad y prioridad con la interacción habitual de Embarques.
4. **Generar programa semanal** vuelve a leer la lista final guardada. Usa los
   confirmados dentro de su alcance, precarga patio inicial y capacidad observada
   y calcula la producción requerida. Se conservan los ajustes manuales de las
   condiciones. Si falla la lectura, no guarda con una referencia anterior.
5. Las versiones aprobadas permanecen inmutables. Para incorporar ediciones se
   crea otro borrador y se genera de nuevo. Una versión con embarques modificados
   no puede aprobarse ni iniciar ejecución con esa copia anterior.

Cerrar o Escape no guarda embarques. La elección de empresas se guarda al pulsar
**Generar sugeridos**, aunque después se cierre la revisión. No se publican ni
sobrescriben automáticamente las metas de Gerencia.

## Fuentes y reglas

| Fuente | Uso |
| --- | --- |
| Entradas y Salidas de Operación | Recepciones de cartón en kg como señal de abastecimiento; salidas comerciales en pacas para demanda histórica e inventario. |
| Producción de Operación | Seis semanas completas para ritmo por material, día y turno; hasta dieciséis semanas de eventos para conciliar conteos fechados. |
| Embarques de Dirección | Dieciséis semanas de realizados para clientes, cargas y frecuencia; compromisos activos de la semana hasta sábado. |
| Conteo de piso | Conteo fechado conciliado con producción, entradas comerciales externas y salidas posteriores. |
| Programa Operativo guardado | Patio inicial, capacidad, días laborables y disponibilidad de turnos de la semana. |
| Afectaciones de maquinaria | Reducción de capacidad por compactadora. |

- Alcance: nacional, limpia y americana, días restantes de lunes a viernes de la
  semana actual o lunes a viernes de una semana futura. Materiales fuera del
  Programa Operativo no consumen esta demanda.
- Los clientes proceden de salidas o embarques realizados; no se inventan pedidos.
  Solo las empresas marcadas participan en el cálculo de demanda y en el reparto
  del material, normalizando nombres y alias. Las empresas desmarcadas no reciben
  nuevas sugerencias; sus compromisos existentes siguen reservando inventario.
  La carga habitual es la mediana inferior de las cargas conciliadas. La demanda
  semanal por cliente/material usa el mayor entre esa carga y el promedio semanal
  desde el primer registro dentro de la ventana de dieciséis semanas. Se descuentan
  realizados y compromisos de esta semana del mismo cliente/material, sin descontar
  ventas a otras empresas de su demanda. Una selección sin historial reciente se
  señala para captura manual, sin inventar cantidades.
- **Cierre del viernes:** el último conteo de pacas por material guardado desde
  las 17:00 del viernes, hora `America/Mexico_City` (Celaya), se conserva como
  piso inicial exacto del lunes siguiente. Está disponible desde el viernes para
  planear Embarques y Programa operativo. Incluye conteos explícitos de cero.
  Las salidas, producción y compromisos anteriores al lunes no vuelven a ajustar
  ese cierre. Desde el lunes, producción y salidas modifican el saldo disponible
  normalmente; un conteo físico posterior actualiza el saldo actual pero conserva
  el cierre semanal. Cada material y semana se guardan por separado.
- Al planear una semana futura se usa el historial disponible hoy. Para materiales
  **sin cierre del viernes**, se descuenta
  del piso actual el material comprometido antes del lunes elegido y solo se
  anticipa producción de la semana elegida. Si el piso no cubre compromisos previos
  de un material, se avisa y no se proponen nuevas cargas de ese material hasta
  resolverlo. El patio resultante se marca estimado y debe revisarse al iniciar
  la semana. No se atribuye producción aún no realizada a las semanas intermedias.
- No se sugieren cargas menores a ocho pacas ni al 80% de la carga habitual.
  Se conservan cinco pacas por material y se protegen todos los compromisos
  posteriores hasta sábado. El inventario se comparte entre clientes.
- Operación y Dirección del mismo día, cliente y material se concilian por el
  mayor total, pues no existe un identificador común. Un compromiso todavía
  activo mantiene su reserva hasta actualizar su estado, aunque coincida con una salida.
- El consumo `GENERAL OUT / TRANSFORMATION` **no se resta de las recepciones**.
  Las entradas `GENERAL IN` de los siete días completos recientes se comparan
  con el promedio semanal de las seis semanas previas. La caída reduce la
  proyección; un aumento no la eleva. Sin base comparable se conserva el ritmo
  observado y se señala la incertidumbre de abastecimiento. Los kg no se convierten en pacas.
- El conteo no caduca automáticamente a las doce horas. Dentro de la ventana de
  eventos se calcula el saldo actual y se reconstruye el saldo inicial del lunes.
  Un patio inicial guardado sirve como respaldo. Sin conteo utilizable se parte
  de cero más los movimientos netos observados de la semana y se marca estimado.
- Operación y Embarques usan el instante de guardado del conteo registrado por
  el servidor (`updated_at`; respaldo `counted_at`). Este formulario captura el
  conteo al guardar y no permite fecharlo hacia atrás. Así se corrigen también
  las lecturas de clientes anteriores que enviaban la hora local sin zona.
  Las nuevas capturas escriben `counted_at` en UTC y Operación muestra la hora local.
- Una reconstrucción incierta o negativa del patio del lunes se advierte por
  separado; no invalida el conteo físico actual. “Sin conteo” identifica falta de
  una referencia utilizable, mientras “Piso estimado” señala incertidumbre en
  los movimientos posteriores. Cada embarque muestra el piso disponible, la
  producción esperada, los compromisos previos y el saldo antes/después.
- La producción se suma una sola vez: se excluyen entradas comerciales de origen
  `TRANSFORMATION`, ya representadas por los registros de Producción. Fechas de
  captura comparables permiten separar movimientos anteriores y posteriores al
  conteo. Si falta la hora se usa una asignación conservadora y se señala el saldo estimado.
- La capacidad diaria parte del percentil 75 de los totales diarios registrados
  en las seis semanas previas, o de la capacidad guardada. La proyección por
  material/día/turno usa el promedio desde la primera semana observada de esa
  ventana; los huecos intermedios aportan cero. No se genera capacidad sin producción histórica.
- La capacidad y los turnos se comparten entre materiales. Se respetan días y
  turnos bloqueados. La producción del turno día puede cubrir la salida de ese
  día; la nocturna queda disponible al siguiente. Lo ya producido hoy no se
  proyecta nuevamente. Los registros sin turno conocido no anticipan producción.
- Entre fechas factibles se priorizan cantidad cubierta, día habitual del cliente,
  menor concentración y fecha temprana. Es una heurística explicable; transporte,
  citas y pedidos no registrados siguen requiriendo revisión comercial.
- Las proyecciones de los embarques capturados usan el mismo saldo y pronóstico
  para estos tres materiales. El histórico desplegable conserva su carácter de referencia.

## Guardado y verificación

Antes de aceptar se releen las fuentes. Cambios de inventario, calendario,
compromisos, empresas elegidas o propuesta invalidan la selección anterior. Se guarda el lote en
una operación con identificadores estables por revisión/carga; cargas iguales
conservan identificadores distintos y reintentos idénticos no duplican registros.
La comprobación previa no bloquea capturas concurrentes de otros usuarios.

Se reutilizan `direction_shipment_plans` y `direction_operating_programs.conditions`.
La migración `20261016160000_create_direction_shipment_week_clients.sql` agrega
`direction_shipment_week_clients` para recordar las empresas por lunes de semana.
Aplicada al proyecto Supabase vinculado el 16 de octubre de 2026.
Reutiliza los permisos de Programa Operativo (perfiles activos `direccion`, `admin`
y `ops_manager`). Las pruebas cubren selección y persistencia por semana, reservas
de empresas excluidas, planeación futura, metas ausentes o arbitrarias, consumo
por transformación, conteos anteriores, conciliación sin duplicados, reservas,
turnos, maquinaria, capacidad compartida, generación con patio automático y
conservación de ajustes manuales. El diálogo se verifica a 1440 y 390 px, además
del flujo de aceptar, editar y generar con la versión final de los embarques.

`20261016170000_capture_friday_yard_openings.sql` agrega el cierre persistente
`dashboard_yard_week_openings`, capturado por trigger al guardar el conteo de
Operación, y la fecha de captura en Celaya (`counted_on`). Aplicada al proyecto
Supabase vinculado el 16 de octubre de 2026. El corte se calcula en
el servidor; no depende de la zona horaria del dispositivo. Reutiliza el último
conteo existente si cumple el horario. Cambiar el conteo durante la semana no
sobrescribe cierres anteriores. Borrar el conteo retira solo su cierre coincidente,
si todavía corresponde al mismo instante de captura. La tabla solo admite lectura
directa; las escrituras pasan por el guardado habitual de Operación.
