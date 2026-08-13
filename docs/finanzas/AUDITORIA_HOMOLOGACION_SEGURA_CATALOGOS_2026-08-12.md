# Auditoria de homologacion segura de catalogos

Fecha del corte autenticado: 12 de agosto de 2026.

Objetivo: dejar documentado el estado actual entre `Compras`, `Ventas Mayoreo` y `Finanzas` sin mover datos ni correr homologaciones masivas.

## Regla operativa

- No correr resincronizaciones completas de catalogo para corregir un caso puntual.
- No tocar `compras_counterparties`, `mayoreo_counterparties` ni `finanzas_catalog_companies` de forma masiva.
- Cualquier ajuste futuro debe ser `app-side`, de lectura, o puntual por empresa aprobada caso por caso.
- El flujo de convenios debe mantenerse defensivo y no depender de una resincronizacion global del catalogo.

## Corte rapido

- `finanzas_company_directory` activas: `45`
- `finanzas_catalog_companies` activas/visibles en el corte: `177`
- `compras_counterparties` activas: `46`
- `mayoreo_counterparties` activas: `33`

## Riesgo masivo hoy

- Empresas activas en `finanzas_company_directory` que no existan en `finanzas_catalog_companies`: `0`
- Empresas activas de `Compras` ausentes por nombre en `Finanzas`: `0`
- Empresas activas de `Ventas Mayoreo` ausentes por nombre en `Finanzas`: `1`

Conclusion operativa: al corte del 12 de agosto de 2026 no se observa una ruptura masiva del catalogo activo de Finanzas. El riesgo actual es de homologacion puntual de `id`, no de desaparicion general de empresas.

## Caso Avon

- `AVON` existe en `finanzas_company_directory` con `company_id = compras_co_1779230989617207`
- `AVON` existe en `finanzas_catalog_companies` con `id = compras_co_1779230989617207`
- `AVON` tiene `12` facturas abiertas por `607,533.50`
- `AVON` tiene `0` convenios registrados al corte

Conclusion: `AVON` no aparece hoy como empresa faltante en el catalogo activo de Finanzas. Si vuelve a fallar el guardado de convenio, debe revisarse como caso de flujo, validacion o captura, no como caida general del catalogo.

## Desfaces puntuales detectados

### Compras vs Finanzas

Estos nombres existen en Finanzas, pero no con el `id` esperado por el patron `compras_{id_de_compras}`:

- `AVON`: `cp_import_avon` en Compras vs `compras_co_1779230989617207` en Finanzas
- `FERNANDO RUBIO`: `cp_import_fernando_rubio` en Compras vs `ventas_co_seed_fernando_rubio` en Finanzas
- `PLASTICOS DE INGENIERIA MEXICANOS`: `co_1782160320540728` en Compras vs `fc_import_plasticos_de_ingenieria_mexicanos` en Finanzas
- `RICARDO GARCIA MENDIETA`: `cp_import_ricardo_garcia_mendieta` en Compras vs `ventas_co_seed_ricardo_garcia_mendieta` en Finanzas
- `TRUPER`: `co_1785183511873247` en Compras vs `fc_1784306801560010` en Finanzas
- `KS`: `cp_import_ks` en Compras vs `ventas_co_seed_ks` en Finanzas
- `YOROZU`: `cp_import_yorozu` en Compras vs `ventas_co_seed_yorozu` en Finanzas

Lectura correcta de este hallazgo:

- No significa que la empresa falte en Finanzas.
- Significa que la identidad canonica en Finanzas no siempre coincide con el origen actual de Compras.
- Esto exige revision puntual si algun flujo depende de `id` exacto y no de nombre homologado.

### Ventas Mayoreo vs Finanzas

- `QUERETANA CARRILLO` existe en `mayoreo_counterparties` pero no se encontro por nombre en `finanzas_catalog_companies`
- `DESPERDICIOS QUERETANA PATIO-MICHEL` existe por nombre en Finanzas, pero no con el `id` esperado por el patron `ventas_{id_de_mayoreo}`

## Casos con impacto operativo visible hoy

Dentro de los desfaces puntuales, estos nombres si aparecen activos en `finanzas_company_directory` y por lo tanto merecen cuidado adicional si algun flujo usa `id` exacto:

- `AVON`
- `FERNANDO RUBIO`
- `RICARDO GARCIA MENDIETA`
- `TRUPER`
- `KS`
- `YOROZU`

Estos nombres salieron en el cruce de identidades pero no aparecen activos en el directorio financiero actual:

- `PLASTICOS DE INGENIERIA MEXICANOS`
- `QUERETANA CARRILLO`

## Decision segura recomendada

- Mantener cualquier correccion futura en modo puntual por empresa.
- Evitar homologar ids en lote hasta revisar el impacto por modulo.
- No usar `saveCatalogSnapshot` ni procesos equivalentes como correccion rapida para un solo proveedor.
- Si algun flujo vuelve a fallar en un proveedor puntual, primero auditar `directory`, `catalog`, facturas y convenios de esa sola empresa.

## Nota de alcance

Esta auditoria fue de solo lectura. No implica `upserts`, migraciones, borrados ni remapeos de ids.
