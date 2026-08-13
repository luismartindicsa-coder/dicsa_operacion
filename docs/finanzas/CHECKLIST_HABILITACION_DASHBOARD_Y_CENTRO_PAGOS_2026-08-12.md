# Checklist de habilitación para Dashboard Finanzas y Centro de pagos

Fecha del corte leído: 11 de agosto de 2026.

Objetivo: documentar qué falta llenar para que `Dashboard Finanzas` y `Centro de pagos` lean mejor la operación sin mover datos ni ejecutar cambios sobre la base.

## Faltantes críticos detectados

- `84` facturas abiertas siguen sin `due_date`.
- `34` proveedores con saldo operativo abierto siguen con huecos en el directorio financiero.
- `14` pagos fijos pendientes todavía no apuntan a un movimiento bancario real.
- `35` incidencias de identidad siguen partiendo la lectura por empresa entre compras, directo, facturas o banco.

## Qué llenar primero

- En facturas abiertas: completar `due_date`.
- En `finanzas_company_directory`: completar `operational_contact`, `phone`, `location`, `credit_days`, `payment_stage` y `manual_priority` donde falten.
- En pagos fijos pendientes: revisar `linked_bank_movement_id`.
- En identidades de empresa: normalizar alias y cruces entre fuentes antes de confiar en agregados automáticos.

## Proveedores de impacto visible en el corte

- `TENNECO`: sigue con campos críticos faltantes y además concentra muchos pendientes sin vencimiento.
- `MONROE`: aparece sin fila de directorio financiero en el corte leído.
- `AVON`: mantiene huecos operativos y sigue visible entre pendientes.
- `KS`: conserva metadatos comerciales prácticamente vacíos.

## Referencias

- Ruta en app: `Docs Finanzas`.
- Documento base: `apps/dicsa_operacion/docs/finanzas/CHECKLIST_HABILITACION_DASHBOARD_Y_CENTRO_PAGOS_2026-08-12.md`
- Paquete temporal sólo lectura: `/private/tmp/finanzas_readonly_checklists_2026-08-11`
- Auditoría de identidades: `apps/dicsa_operacion/docs/migrations/finanzas_company_identity_audit.json`

## Nota operativa

Esta documentación resume una revisión de sólo lectura. No implica migraciones, `upserts`, ni reconciliaciones automáticas.
