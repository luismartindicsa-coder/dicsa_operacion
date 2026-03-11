# Dashboard Archetype

Arquetipo base para vistas de resumen ejecutivo u operativo.

Referencia funcional homologada: `Dashboard`.

## Uso minimo

- `DashboardShell`
- `DashboardWidgetCard`
- `DashboardRefreshController`

## Contrato minimo

- no debe existir overflow horizontal global
- widgets deben responder a cambios de ancho
- hover/lift debe ser consistente
- overlays o detalles deben sentirse de la misma familia visual
- refresh debe ser silencioso
