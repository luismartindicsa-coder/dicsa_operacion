# Contrato del Reporte: Operaciones - OTs Diarias Nuevas

Fecha de diseno: 2026-08-13

## Fecha de referencia

La fecha actual del sistema es:

- `Thursday, August 13, 2026`

Por lo tanto, el primer corte diario de arranque para este reporte corresponde a:

- `Thursday, August 13, 2026`

## Nombre oficial

- `Operaciones - OTs diarias nuevas`

## Frecuencia

- `Diario`

## Ubicacion en la app

- `Dashboard Operacion -> Reportes de supervision -> Generar diario`
- `Supervision -> Operaciones -> Generar diario`

## Objetivo gerencial

Este reporte existe para que Gerencia y el encargado de Operaciones entiendan, en el mismo dia:

- que trabajo nuevo aparecio
- que parte si es urgencia real
- que parte revela prevencion deficiente
- que responsable debe atenderlo hoy

No es un listado administrativo.

Es un corte para coordinar accion del dia.

## Usuario principal

- `Gerencia`
- `Encargado de Operaciones`

## Preguntas que debe responder

1. Cuantas OTs nuevas nacieron hoy.
2. Cuales son `alta prioridad`.
3. Cuales traen `paro_total` o `paro_parcial`.
4. En que areas se estan concentrando.
5. Cuales siguen sin responsable o sin mecanico asignado.
6. Que patrones ya sugieren problema repetitivo.

## Fuente exacta

Fuente base:

- `public.maintenance_orders`

Campos minimos a consultar:

- `id`
- `ot_folio`
- `status`
- `priority`
- `type`
- `category`
- `impact`
- `requested_at`
- `area_label`
- `equipment_label`
- `requester_name`
- `assigned_to_name`
- `mechanic_name`
- `problem_description`
- `cost_estimated_total`

Nota:

- `problem_description` debe entrar en el query del reporte aunque no siempre aparezca en la lectura corta del dashboard actual

## Regla de corte

Para el corte diario:

- incluir OTs cuyo `requested_at` caiga dentro del dia seleccionado

Para el primer arranque:

- desde `2026-08-13 00:00:00`
- hasta `2026-08-13 23:59:59`

Zona operativa:

- usar la zona local del sistema del negocio

## Que se considera OT nueva

Una OT cuenta como `nueva del dia` si:

- su `requested_at` pertenece al dia del corte

No importa si durante ese mismo dia ya cambio de estatus.

Sigue siendo nueva.

## Que NO entra

- OTs creadas antes del dia del corte
- OTs eliminadas
- OTs de otros dias aunque hoy sigan abiertas

Eso ultimo debe verse en otro reporte:

- `Seguimiento de OTs`

## KPIs superiores del PDF

El encabezado debe traer estos KPIs:

1. `OTs nuevas`
2. `OTs altas`
3. `OTs con paro`
4. `OTs sin responsable claro`
5. `Areas con mas carga`
6. `Costo estimado visible`

Reglas:

- `OTs nuevas`: total de filas del dia
- `OTs altas`: `priority = alta`
- `OTs con paro`: `impact in (paro_total, paro_parcial)`
- `OTs sin responsable claro`: sin `assigned_to_name` y sin `mechanic_name`
- `Areas con mas carga`: top 1 o top 2 por conteo
- `Costo estimado visible`: suma de `cost_estimated_total` solo cuando exista

## Secciones del PDF

## 1. Encabezado

Debe mostrar:

- nombre del reporte
- fecha del corte
- hora de generacion
- usuario que lo genero
- responsable del area

## 2. Resumen ejecutivo

Debe tener 3 a 5 frases automaticas de alto valor.

Ejemplos del tipo de lectura:

- cuantas OTs nuevas aparecieron hoy
- si se concentraron en una misma area
- si hubo demasiadas de prioridad alta
- si nacieron varias sin responsable

## 3. KPIs

Tarjetas o tabla corta con los KPIs definidos arriba.

## 4. Foco del dia

Bloque especial con:

- OTs de `priority = alta`
- OTs con `impact = paro_total`
- OTs sin responsable claro

Esta es la parte que debe leerse primero en junta.

## 5. Resumen por area

Tabla corta:

- `Area`
- `OTs nuevas`
- `Altas`
- `Con paro`
- `Sin responsable`

Objetivo:

- ver en que frente se esta rompiendo mas el dia

## 6. Listado completo del dia

Tabla detalle con columnas sugeridas:

- `OT`
- `Hora`
- `Area`
- `Equipo`
- `Estatus actual`
- `Prioridad`
- `Impacto`
- `Solicitante`
- `Responsable`
- `Mecanico`
- `Descripcion corta`

Regla:

- la descripcion debe ir resumida para no romper el layout

## 7. Pendientes y responsables

Bloque de cierre con preguntas ejecutivas:

- cual OT se toma hoy
- quien responde
- que necesita autorizacion
- que debio prevenirse

## Reglas de lectura gerencial

Este reporte no debe usarse para preguntar:

- que paso con OTs viejas

Eso pertenece a:

- `Seguimiento de OTs`

Este reporte si debe usarse para preguntar:

- por que nacieron estas OTs hoy
- cuales si eran inevitables
- cuales revelan falta de rutina, mantenimiento o control

## Clasificaciones clave

## Estatus

La lectura debe homologar:

- `aviso_falla`
- `cotizacion`
- `autorizacion_finanzas`
- `supervision`
- `cerrado`
- `rechazado`

## Prioridad

La lectura debe mostrar:

- `alta`
- `media`
- `baja`

## Impacto

La lectura debe mostrar:

- `paro_total`
- `paro_parcial`
- `sin_impacto`

## Alertas automaticas recomendadas

El PDF debe marcar alerta cuando ocurra cualquiera de estas:

- 3 o mas OTs nuevas en la misma area el mismo dia
- 2 o mas OTs de `priority = alta`
- cualquier OT con `impact = paro_total`
- cualquier OT nueva sin responsable claro
- costo estimado alto en OT nueva el mismo dia

Nota:

- el umbral de `costo estimado alto` debe definirse contigo cuando revisemos montos reales

## Frases de resumen sugeridas

El generador debe producir frases del tipo:

- `Hoy nacieron X OTs nuevas en Operaciones.`
- `El area con mayor carga nueva fue Y con Z OTs.`
- `Se detectaron N OTs de prioridad alta.`
- `Hay M OTs nuevas sin responsable claro.`
- `La lectura de hoy sugiere urgencia real / carga concentrada / desorden preventivo.`

## Preguntas obligatorias para la junta

El encargado de Operaciones debe llegar listo para responder:

1. Cuales OTs de hoy no debieron nacer.
2. Cuales si requieren atencion inmediata.
3. Que area esta repitiendo fallas.
4. Cuales siguen sin responsable y por que.
5. Que accion concreta se tomara hoy.

## Riesgos que debemos evitar

- convertir el reporte en solo lista de filas
- confundir OTs nuevas con OTs abiertas historicas
- meter costos reales inexistentes
- ocultar OTs sin responsable
- inflar el PDF con detalle tecnico que no sirve en junta diaria

## Definicion de terminado para este reporte

Este reporte estara bien construido cuando:

1. Lea `maintenance_orders` del dia seleccionado.
2. Calcule bien KPIs diarios.
3. Muestre foco del dia y resumen por area.
4. Liste todas las OTs nuevas del corte.
5. Genere un PDF entendible para junta diaria.
6. Permita que Gerencia pregunte accion y no solo datos.

## Siguiente reporte despues de este

Una vez validado este reporte, el siguiente de `Operaciones` debe ser:

- `Seguimiento de OTs` del viernes

