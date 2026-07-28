# Auditoría: Análisis de Flujo

Fecha de corte: 2026-07-16

## Objetivo

Validar si la pantalla `Contabilidad > Análisis de Flujo` expone una lectura confiable frente a sus fuentes reales y dejar documentado qué riesgos quedaron resueltos tras la migración transaccional de Bóveda aplicada el jueves 16 de julio de 2026.

## Fuentes auditadas

- `finanzas_bank_movements`
- `direction_vault_vouchers`
- `direction_vault_voucher_lines`
- `vw_men_cash_vouchers_grid`
- `men_cash_voucher_lines`
- `vw_men_cash_cuts_grid`

## Cambio estructural aplicado

El jueves 16 de julio de 2026 se dejó de usar `cash_taxonomy_configs.area = direccion_boveda_vouchers` como fuente operativa del análisis de flujo.

Desde esa fecha:

- Bóveda guarda en `direction_vault_vouchers`
- el detalle por renglón guarda en `direction_vault_voucher_lines`
- la pantalla de Bóveda en Dirección lee y escribe sobre esa fuente
- Contabilidad consume Bóveda desde `DirectionVaultRepository`

También se migró el historial previamente almacenado en `cash_taxonomy_configs.payload.rows` hacia las nuevas tablas transaccionales.

## Reconstrucción viva de fuentes

Conteos observables con la misma sesión autenticada local de la app:

- Bancos: movimientos en `finanzas_bank_movements`
- Bóveda: movimientos en `direction_vault_vouchers`
- Líneas Bóveda: renglones en `direction_vault_voucher_lines`
- Menudeo: vouchers en `vw_men_cash_vouchers_grid`
- Líneas de vouchers menudeo: `men_cash_voucher_lines`
- Cortes de menudeo: `vw_men_cash_cuts_grid`

## Hallazgos resueltos

### 1. La pantalla ya no tolera faltantes silenciosos de bancos o bóveda

Estado: resuelto.

Antes, `FinanzasBankAccountsStore.loadMovements()` y la carga de Bóveda podían regresar vacío ante error y permitir una lectura parcial sin avisar.

Ahora:

- Contabilidad usa `FinanzasBankAccountsStore.loadMovementsStrict()`
- Bóveda ya no se consume desde un loader tolerante de snapshot
- la página muestra error en lugar de construir un resultado parcial silencioso

Referencias:

- `lib/app/finanzas/finanzas_bank_accounts_store.dart`
- `lib/app/contabilidad/contabilidad_flow_analysis_store.dart`
- `lib/app/contabilidad/contabilidad_flow_analysis_page.dart`

### 2. Bóveda ya no depende de un blob JSON editable

Estado: resuelto.

Antes, la fuente de Bóveda era `cash_taxonomy_configs.payload.rows`, lo que significaba que una edición del payload podía reescribir la historia que Contabilidad consumía.

Ahora, Bóveda vive en tablas transaccionales propias:

- `direction_vault_vouchers`
- `direction_vault_voucher_lines`

Eso vuelve audit-able el origen de los importes por voucher y por renglón.

Referencias:

- `supabase/migrations/20260716123000_create_direction_vault_vouchers.sql`
- `lib/app/shared/direction_vault/direction_vault_repository.dart`
- `lib/app/direction/direction_cash_entries_exits_page.dart`
- `lib/app/contabilidad/contabilidad_flow_analysis_store.dart`

### 3. La tarjeta "A dónde se fue el dinero" ya no mezcla depósitos de menudeo con egresos

Estado: resuelto.

Antes, `cashRubricRows` podía incluir rubros de depósito y presentarlos como si fueran salidas.

Ahora, Contabilidad toma de Menudeo solo `expenseRubricRows` para ese detalle.

Referencias:

- `lib/app/direction/analysis/menudeo/menudeo_analysis_models.dart`
- `lib/app/direction/analysis/menudeo/menudeo_analysis_repository.dart`
- `lib/app/contabilidad/contabilidad_flow_analysis_store.dart`

## Riesgos que siguen vigentes

### 1. La exclusión de movimientos internos todavía depende de reglas de interpretación

Riesgo: medio.

En bancos, la clasificación de internos ya es más conservadora, pero todavía depende de contexto capturado en categoría, comentario, referencia o contraparte.

En Bóveda, la detección de internos se apoya en rubro y en valores como `Bóveda`, `Caja Grande`, `Transferencia` o `Interno` dentro de los renglones.

Eso es mejor que antes porque ya se hace sobre fuente transaccional, pero sigue sin ser un flag persistido de negocio.

Referencia:

- `lib/app/contabilidad/contabilidad_flow_analysis_store.dart`

### 2. El análisis sigue siendo de flujo, no de utilidad

Riesgo: conceptual, no técnico.

La pantalla ya es mucho más confiable para leer entradas, salidas, internos y tensión de liquidez.

Pero sigue siendo incorrecto usar este análisis por sí solo como utilidad bruta o utilidad neta.

Referencia:

- `lib/app/contabilidad/contabilidad_flow_analysis_page.dart`

## Conclusión actualizada

La lectura principal de `Contabilidad > Análisis de Flujo` subió de nivel de forma importante el jueves 16 de julio de 2026.

Después de la migración de Bóveda:

- bancos ya se cargan en modo estricto
- bóveda ya sale de una fuente transaccional propia
- el detalle de egresos ya no infla salidas con depósitos de menudeo
- la pantalla ya expone una capa visible de confiabilidad para Dirección

La pantalla todavía no equivale a un estado financiero ni a una utilidad, pero sí puede considerarse una lectura ejecutiva de flujo mucho más defendible y audit-able que la versión anterior.

## Nivel de confianza recomendado

- Flujo neto consolidado: confianza alta operativa
- Desglose de "a dónde se fue el dinero": confianza media-alta
- Bóveda como fuente audit-able: confianza alta
- Clasificación automática de internos: confianza media

## Siguiente paso recomendado

1. Persistir un flag explícito de movimiento interno en origen para bancos y bóveda, en lugar de depender de heurísticas.
2. Abrir `Análisis de Gastos` ya sobre estas fuentes transaccionales.
3. Construir después `Estado de Resultados` y `Utilidad` como pantallas distintas, no derivadas solo del flujo.
