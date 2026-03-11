# Workflow Master-Detail Archetype

Arquetipo base para flujos tipo lista + detalle + acciones de proceso.

Referencia funcional homologada: `Mantenimiento`.

## Uso minimo

- `WorkflowMasterDetailController`
- `WorkflowMasterDetailShell`
- `WorkflowStatusSummaryCard`
- `WorkflowItemActionsBar`
- `showWorkflowItemContextMenu`
- `WorkflowRefreshController`

## Contrato minimo

- lista y detalle viven en una sola superficie
- `Esc` debe cerrar menus/dialogos del flujo cuando aplique
- `Enter` confirma accion primaria visible
- refresh no debe romper captura en detalle
- click derecho y acciones visibles deben compartir la misma logica
