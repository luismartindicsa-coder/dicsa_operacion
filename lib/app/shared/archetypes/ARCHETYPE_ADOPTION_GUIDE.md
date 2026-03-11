# Archetype Adoption Guide

Guia minima para arrancar una pagina nueva sobre la infraestructura reusable.

## Regla base

1. declarar arquetipo
2. importar `ui_contract_core`
3. importar el arquetipo correspondiente
4. adaptar solo datos, validaciones y persistencia del modulo

## Import base

```dart
import 'package:dicsa_operacion/app/shared/ui_contract_core/ui_contract_core.dart';
```

## Grid Editable

```dart
import 'package:dicsa_operacion/app/shared/archetypes/grid_editable/grid_editable.dart';
```

Uso minimo:

- `GridKeyboardShell`
- `GridEditableShell`
- insert row wrappers
- row/context/filter wrappers

## Grid Editable Tabulado

```dart
import 'package:dicsa_operacion/app/shared/archetypes/grid_editable_tabbed/grid_editable_tabbed.dart';
```

Uso minimo:

- `GridTabbedController`
- `GridTabbedShell`
- `GridTabbedActionsBar`
- `GridTabbedMetricHeader`

## Workflow Master-Detail

```dart
import 'package:dicsa_operacion/app/shared/archetypes/workflow_master_detail/workflow_master_detail.dart';
```

Uso minimo:

- `WorkflowMasterDetailController`
- `WorkflowMasterDetailShell`
- `WorkflowStatusSummaryCard`
- `WorkflowItemActionsBar`

## Operacion Hibrida Tabs

```dart
import 'package:dicsa_operacion/app/shared/archetypes/operacion_hibrida_tabs/operacion_hibrida_tabs.dart';
```

Uso minimo:

- `OperacionHibridaTabsController`
- `OperacionHibridaTabsShell`
- `OperacionTabSummaryStrip`
- `OperacionTabActionsBar`

## Dashboard

```dart
import 'package:dicsa_operacion/app/shared/archetypes/dashboard/dashboard.dart';
```

Uso minimo:

- `DashboardShell`
- `DashboardWidgetCard`

## Auxiliary Surfaces

```dart
import 'package:dicsa_operacion/app/shared/archetypes/auxiliary_surfaces/auxiliary_surfaces.dart';
```

Uso minimo:

- `showSearchablePickerDialog`
- `showContractDatePickerSurface`
- `showContractConfirmationDialog`

## Verificacion minima

- `dart format`
- `dart analyze`
- validar foco al primer click
- validar `Esc`, `Enter`, `Delete` y flechas
- validar refresh sin robo de foco
