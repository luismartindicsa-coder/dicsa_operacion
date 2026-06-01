# Contrato Estándar de Egress y Refresh

Este documento fija el estándar que debe seguir toda página nueva de `DICSA Operación` para mantener la app funcional, reducir egress innecesario y evitar que cada módulo invente su propia estrategia de refresh.

La intención no es refactorizar toda la app hoy.

La intención es:

- congelar una regla clara para páginas nuevas
- evitar que el problema crezca mientras se termina la app
- dejar una ruta de homologación posterior para páginas existentes

## Regla madre

Toda pantalla nueva debe diseñarse bajo la idea:

`la consistencia operativa importa, pero no se paga con polling agresivo ni recargas completas innecesarias`

La jerarquía correcta es:

1. datos mínimos
2. refresh silencioso
3. resiliencia ante reconexión o background
4. costo de red controlado

## Qué sí se busca

- que la pantalla se mantenga actualizada
- que no se rompa la captura por refresh
- que el usuario no tenga que recargar manualmente cada rato
- que el tráfico mensual sea predecible

## Qué se quiere evitar

- `timer + realtime` por costumbre
- intervalos de `12s`, `15s`, `18s` o `30s` sin justificación fuerte
- `select(*)` en rutas de auto refresh
- recargar tablas completas cuando solo cambió una fila
- traer catálogos o historiales completos en cada refresco
- usar dashboards como si fueran streams permanentes de datos sin costo

## Contrato de refresh por defecto

Para toda pantalla nueva, el orden por defecto es este:

### 1. Primera opción: `realtime + resume`

Usar cuando:

- la vista depende de cambios vivos
- el volumen de datos visible es moderado
- la pantalla puede reconstruirse con consultas acotadas

Comportamiento esperado:

- suscripción `Realtime`
- refresh al volver de background
- refresh al entrar por primera vez
- sin timer periódico por defecto

### 2. Segunda opción: `realtime + timer de respaldo`

Usar solo cuando:

- la reconexión pueda dejar huecos operativos
- la pantalla dependa de varias tablas o agregados derivados
- exista riesgo real de desincronización silenciosa

Reglas:

- el timer es respaldo, no fuente primaria
- el intervalo mínimo recomendado es `60s`
- para dashboards o agregados pesados, preferir `120s` a `300s`
- usar menos de `60s` requiere justificación documentada en la propia pantalla o en su contrato

### 3. Tercera opción: `manual + resume`

Usar cuando:

- la vista sea pesada
- el dato no cambie cada minuto
- la consistencia absoluta en vivo no sea necesaria

Comportamiento esperado:

- carga inicial
- recarga al volver a foreground
- recarga después de acciones del propio usuario
- botón manual si de verdad hace falta

## Contrato por tipo de página

### Dashboard operativo

- puede usar `Realtime`
- puede usar timer de respaldo
- no debe usar timer agresivo por defecto
- debe traer métricas compactas y no datasets completos si solo muestra resumen

Estándar recomendado:

- `realtime + timer de 120s a 300s`

### Grid editable operativo

- `Realtime` si el módulo lo necesita
- refresh diferido durante edición
- preferir `resume + eventos locales + realtime`
- timer solo como respaldo y normalmente de `180s` o más

Estándar recomendado:

- `realtime + resume`
- si el riesgo operativo lo exige: `realtime + timer de 180s`

### Catálogos

- evitar polling continuo
- refrescar tras inserción, edición o eliminación
- refrescar al volver de background si aplica

Estándar recomendado:

- `manual + resume` o `realtime + resume`

### Evidencias, imágenes y archivos

- no recargar listados de archivos en loop
- no descargar previews pesados sin necesidad
- mostrar primero metadata o thumbnail si existe

## Contrato de consultas

Toda ruta que participe en auto refresh debe cumplir:

- no usar `select(*)` si la vista no necesita todas las columnas
- pedir solo columnas visibles o funcionales
- limitar resultados
- paginar cuando el dataset crece
- separar métricas de detalle cuando no se necesitan juntas
- evitar traer catálogos completos una y otra vez si casi no cambian

Regla explícita:

- si una página se refresca sola, su query debe ser más estricta que una query manual o administrativa

## Contrato de actualización incremental

Cuando el evento `Realtime` permita identificar el cambio, se debe preferir:

- actualizar una fila
- insertar una fila
- eliminar una fila
- recalcular una métrica puntual

Antes de:

- volver a pedir toda la tabla
- volver a pedir todo el dashboard
- volver a pedir varios catálogos completos

Si no existe todavía infraestructura local para actualización incremental, se permite refresh completo pero con query acotada y timer no agresivo.

## Contrato de resiliencia

La pantalla debe seguir funcionando aunque `Realtime` falle o se reconecte tarde.

Mínimos obligatorios:

- refresh al entrar
- refresh al volver de background
- diferir refresh si hay edición o captura
- procesar un pending refresh cuando termine la edición

## Umbrales guía para páginas nuevas

Estas reglas no son matemáticas, pero sí normativas:

- menos de `60s`:
  - evitar
  - solo con justificación fuerte
- `60s` a `180s`:
  - aceptable para dashboards operativos
- `180s` a `300s`:
  - preferido para respaldo silencioso en grids o agregados pesados
- sin timer:
  - preferido en catálogos, formularios, flujos con edición y vistas de detalle

## Plan por fases

### Fase 1. Desde ahora: páginas nuevas

Toda página nueva debe cumplir este contrato.

Eso incluye:

- estrategia de refresh declarada
- sin polling agresivo por default
- sin `select(*)` en auto refresh
- queries acotadas
- refresh diferido si hay edición

### Fase 2. Antes de cierre funcional de la app

No rehacer todo todavía.

Solo identificar páginas candidatas de alto impacto:

- dashboards globales
- grids grandes con `timer + realtime`
- módulos con `select(*)` recurrente

### Fase 3. Homologación posterior

Cuando la app base ya esté terminada:

- revisar páginas existentes
- migrarlas al contrato estándar
- medir antes/después en egress
- eliminar excepciones viejas que ya no se justifiquen

## Checklist obligatorio para nuevas pantallas

Antes de dar por buena una pantalla nueva, validar:

- [ ] La estrategia de refresh quedó declarada
- [ ] No existe `timer` agresivo sin justificación
- [ ] No hay `select(*)` en rutas de refresh automático
- [ ] La consulta está limitada o paginada si el dataset puede crecer
- [ ] El refresh no rompe foco ni edición
- [ ] Existe refresh por `resume`
- [ ] Si usa `Realtime`, el comportamiento degradado sigue siendo funcional
- [ ] Si usa archivos o evidencias, no se fuerzan descargas pesadas sin necesidad

## Regla de decisión rápida

Si una página nueva duda entre meter timer o no, usar esta pregunta:

`si realtime se pierde por unos minutos, el usuario queda bloqueado o solo ve datos un poco viejos?`

Si solo ve datos un poco viejos:

- no meter timer agresivo

Si sí queda bloqueado:

- usar timer de respaldo, pero lento y documentado

## Cierre operativo

Mientras la app sigue en construcción:

- subir a `Pro` da aire operativo
- este contrato evita que el consumo escale sin control
- la homologación completa de páginas viejas se mueve al final, no se cancela

La meta no es perseguir egress cero.

La meta es que DICSA crezca con un costo entendible, estable y compatible con operación real.
