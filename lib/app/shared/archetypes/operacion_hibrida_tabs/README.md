# Operacion Hibrida Tabs Archetype

Arquetipo base para modulos tipo resumen + tabs + superficies distintas dentro del mismo modulo.

Referencia funcional homologada: `Almacen`.

## Uso minimo

- `OperacionHibridaTabsController`
- `OperacionHibridaTabsShell`
- `OperacionTabSummaryStrip`
- `OperacionTabActionsBar`
- `OperacionTabViewHost`
- `OperacionTabWorkspacePanel`
- `OperacionRefreshController`

## Contrato minimo

- cambio de tab no debe sentirse como subapp separada
- resumen, acciones y body deben convivir como una sola superficie
- refresh debe respetar el tab activo
- el tab activo puede guardar contexto reusable
