# Restore 2026-08-03

## Estado preparado

- Backup físico disponible en Supabase: `2026-08-01T04:15:45.729Z`
- PITR: `desactivado`
- Snapshot amplio pre-restore exportado a:
  - `backups/restore_20260803_pre_restore/full_public_snapshot/`
- Snapshots críticos separados:
  - `backups/restore_20260803_pre_restore/mayoreo_accounts.json`
  - `backups/restore_20260803_pre_restore/mayoreo_sales_reports.json`
  - `backups/restore_20260803_pre_restore/finanzas_bank_movements.json`

## Blindaje aplicado en código

- `lib/app/mayoreo/mayoreo_accounts_page.dart`
  - Ya no persiste automáticamente toda `mayoreo_accounts` al cargar y reconciliar con movimientos bancarios.
  - La normalización financiera ya no degrada automáticamente cuentas con pago real a `pendienteFactura` o `pendienteCheque` sólo porque falte capturar toda la metadata documental.

## Hallazgo clave del backup

- El backup físico `2026-08-01T04:15:45.729Z` ya contiene la anomalía de Mayoreo Ventas.
- No sirve por sí solo para recuperar `pagada`, `facturadaPendientePago` o `chequeCanjeado`.
- La recuperación de Mayoreo debe apoyarse en evidencia cruzada:
  - `finanzas_bank_movements`
  - `mayoreo_palomar_movements`
  - `sale_notes` / observaciones en ventas

## Recuperación candidata ya preparada

Generar propuesta local de recuperación:

```sh
cd /Users/martinvelzat/DICSA/apps/dicsa_operacion

dart run tool/generate_mayoreo_accounts_recovery.dart
```

Esto produce:

- `backups/mayoreo_accounts_recovery_20260803/summary.json`
- `backups/mayoreo_accounts_recovery_20260803/report.json`
- `backups/mayoreo_accounts_recovery_20260803/report.csv`
- `backups/mayoreo_accounts_recovery_20260803/upserts/mayoreo_accounts.json`

La propuesta separa:

- alta confianza:
  - facturas pagadas ligadas a `VENTA_FACTURA` en bancos
  - cheques aplicados de `EL PALOMAR`
- confianza media:
  - facturas con folio visible en `sale_notes` / observaciones

## Paso manual en Supabase

1. Abrir el proyecto `pjxncveymixxdntplchb`.
2. Ir a `Database > Backups`.
3. Restaurar el backup físico `2026-08-01T04:15:45.729Z`.

Nota:
- Ese timestamp está en UTC.
- La app tendrá downtime mientras corre la restauración.

## Export post-restore

Después del restore, exportar nuevamente las mismas tablas:

```sh
cd /Users/martinvelzat/DICSA/apps/dicsa_operacion

TABLES=$(find backups/restore_20260803_pre_restore/full_public_snapshot -type f -name '*.json' -exec basename {} .json \; | sort)

SUPABASE_URL='https://pjxncveymixxdntplchb.supabase.co' \
SUPABASE_SERVICE_ROLE_KEY='<SERVICE_ROLE_KEY>' \
./tool/export_supabase_tables.sh \
  backups/restore_20260803_post_restore/full_public_snapshot \
  ${=TABLES}
```

## Generar diff para replay

```sh
cd /Users/martinvelzat/DICSA/apps/dicsa_operacion

dart run tool/diff_supabase_snapshot.dart \
  --baseline backups/restore_20260803_post_restore/full_public_snapshot \
  --current backups/restore_20260803_pre_restore/full_public_snapshot \
  --out backups/restore_20260803_replay_diff
```

Esto genera:

- `backups/restore_20260803_replay_diff/summary.json`
- `backups/restore_20260803_replay_diff/upserts/*.json`
- `backups/restore_20260803_replay_diff/deletes/*.json`

## Regla de replay

- No reaplicar automáticamente `mayoreo_accounts`.
- Sí usar el diff como base para reinyectar tablas fuente y capturas válidas del día.
- Empezar por mayoreo y finanzas:
  - `mayoreo_sales_reports`
  - `mayoreo_palomar_movements`
  - `mayoreo_pending_items`
  - `mayoreo_price_adjustment_history`
  - `finanzas_bank_movements`

## Aplicar upserts por lote

```sh
cd /Users/martinvelzat/DICSA/apps/dicsa_operacion

SUPABASE_URL='https://pjxncveymixxdntplchb.supabase.co' \
SUPABASE_SERVICE_ROLE_KEY='<SERVICE_ROLE_KEY>' \
./tool/apply_supabase_upserts.sh \
  backups/restore_20260803_replay_diff/upserts \
  mayoreo_sales_reports \
  mayoreo_palomar_movements \
  mayoreo_pending_items \
  mayoreo_price_adjustment_history \
  finanzas_bank_movements
```

## Validación mínima posterior

- Revisar `mayoreo_accounts` y confirmar que regresaron `pagada`, `pagoParcial`, `chequeCanjeado`.
- Revisar `Dashboard Mayoreo`.
- Revisar `Finanzas > Cuentas bancarias`.
- Comparar contra `summary.json` para decidir si se reinyectan otras tablas del `3 de agosto de 2026`.
