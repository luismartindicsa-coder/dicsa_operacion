# Plan Maestro: Mantenimiento OT (Hoja Digital)

## Objetivo
Implementar un MVP de ordenes de trabajo de mantenimiento en formato hoja digital, con flujo manual por estado, evidencia fotografica y trazabilidad por usuario/fecha, alineado al contrato UI operativo de DICSA.

## Alcance MVP
- Tabla principal de OTs con filtros y columna `📷 Evidencias`.
- Alta y edicion de OT en hoja digital unica (sin tabs).
- Secciones: datos, clasificacion, descripcion, diagnostico, actividades, materiales, tiempos, evidencias y aprobaciones.
- Intervinientes multiples (proveedor, mecanico, electricista, tecnico externo) capturados por renglon en `Materiales / Refacciones / Mano de obra`.
- Flujo manual de estados (sin automatizacion).
- Validaciones minimas para cierre.

## Fuera de alcance MVP
- Notificaciones automaticas.
- Alertas avanzadas.
- Kanban.
- Firma biometrica/PIN.

## Flujo oficial
`AVISO_FALLA -> REVISION_AREA -> REPORTE_MANTENIMIENTO -> COTIZACION -> AUTORIZACION_FINANZAS -> MATERIAL_RECOLECTADO -> PROGRAMADO -> MANTENIMIENTO_REALIZADO -> SUPERVISION -> CERRADO`

Estado alterno: `RECHAZADO` (comentario obligatorio).

## Arquitectura tecnica
- Flutter:
  - `lib/app/maintenance/maintenance_page.dart`
  - Navegacion desde Dashboard y menu overlay operativo.
- Supabase:
  - Tablas: `maintenance_orders`, `maintenance_tasks`, `maintenance_materials`, `maintenance_time_logs`, `maintenance_evidence`, `maintenance_approvals`, `maintenance_status_log`.
  - Bucket de storage: `maintenance_evidence`.

## Fases
1. Base de datos y RLS.
2. Listado OT y filtros.
3. Hoja digital.
4. Workflow + validaciones.
5. QA de paridad e2e.

## Riesgos y mitigacion
- Riesgo: desalineacion UX con Entradas/Salidas.
  - Mitigacion: validar foco, teclado, seleccion y refresh contra contrato operativo.
- Riesgo: evidencia sin bucket/politicas.
  - Mitigacion: migracion con creacion idempotente de bucket + policies.
- Riesgo: roles reales heterogeneos.
  - Mitigacion: mapeo tolerante de roles y matriz centralizada.
