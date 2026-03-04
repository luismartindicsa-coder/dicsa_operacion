import 'package:flutter/material.dart';

enum OperationalModuleLayout { singleGrid, tabbedGrid, cardsAndGrid }

enum OperationalMetricKind { kg, count, custom }

@immutable
class OperationalMetricSpec {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final OperationalMetricKind kind;

  const OperationalMetricSpec({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.kind = OperationalMetricKind.custom,
  });
}

@immutable
class OperationalToolbarSpec {
  final bool showExportCsv;
  final bool showGridEditToggle;
  final bool showDeleteSelected;
  final bool showSelectionCount;
  final bool showActiveCellHint;

  const OperationalToolbarSpec({
    this.showExportCsv = true,
    this.showGridEditToggle = true,
    this.showDeleteSelected = true,
    this.showSelectionCount = true,
    this.showActiveCellHint = true,
  });
}

@immutable
class OperationalTabSpec {
  final String id;
  final String label;
  final IconData icon;

  const OperationalTabSpec({
    required this.id,
    required this.label,
    required this.icon,
  });
}

@immutable
class OperationalPageBlueprint {
  final String pageName;
  final String headerTitle;
  final OperationalModuleLayout layout;
  final List<OperationalTabSpec> tabs;
  final bool externalActionToolbar;
  final bool metricCardInsideBody;
  final bool autoFocusInsertDate;
  final bool silentAutoRefresh;
  final bool keyboardGridNavigation;
  final bool keyboardInsertNavigation;
  final bool multiSelectCtrlCmd;
  final bool deleteWithKeyboard;
  final bool escapeClearsSelection;
  final bool enterSubmitsInsert;
  final bool headerFiltersEnabled;
  final bool dateRangeFiltersEnabled;
  final bool csvExportEnabled;
  final bool gridEditEnabled;

  const OperationalPageBlueprint({
    required this.pageName,
    required this.headerTitle,
    required this.layout,
    this.tabs = const [],
    this.externalActionToolbar = true,
    this.metricCardInsideBody = true,
    this.autoFocusInsertDate = true,
    this.silentAutoRefresh = true,
    this.keyboardGridNavigation = true,
    this.keyboardInsertNavigation = true,
    this.multiSelectCtrlCmd = true,
    this.deleteWithKeyboard = true,
    this.escapeClearsSelection = true,
    this.enterSubmitsInsert = true,
    this.headerFiltersEnabled = true,
    this.dateRangeFiltersEnabled = true,
    this.csvExportEnabled = true,
    this.gridEditEnabled = true,
  });

  factory OperationalPageBlueprint.singleGrid({
    required String pageName,
    required String headerTitle,
    bool metricCardInsideBody = true,
  }) {
    return OperationalPageBlueprint(
      pageName: pageName,
      headerTitle: headerTitle,
      layout: OperationalModuleLayout.singleGrid,
      metricCardInsideBody: metricCardInsideBody,
    );
  }

  factory OperationalPageBlueprint.tabbedGrid({
    required String pageName,
    required String headerTitle,
    required List<OperationalTabSpec> tabs,
    bool metricCardInsideBody = true,
  }) {
    return OperationalPageBlueprint(
      pageName: pageName,
      headerTitle: headerTitle,
      layout: OperationalModuleLayout.tabbedGrid,
      tabs: tabs,
      metricCardInsideBody: metricCardInsideBody,
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (layout == OperationalModuleLayout.tabbedGrid && tabs.isEmpty) {
      errors.add('`tabs` is required when layout is `tabbedGrid`.');
    }
    if (tabs.map((t) => t.id).toSet().length != tabs.length) {
      errors.add('Tab ids must be unique.');
    }
    return errors;
  }
}

@immutable
class OperationalInteractionContract {
  final bool arrowsNavigateInsertRow;
  final bool arrowsNavigateGrid;
  final bool spaceOpensDropdownOrDate;
  final bool enterConfirmsPrimaryAction;
  final bool escCancelsOrClears;
  final bool deleteDeletesSelection;
  final bool ctrlCmdExtendsSelection;
  final bool preventArrowUpPastTableBoundary;

  const OperationalInteractionContract({
    this.arrowsNavigateInsertRow = true,
    this.arrowsNavigateGrid = true,
    this.spaceOpensDropdownOrDate = true,
    this.enterConfirmsPrimaryAction = true,
    this.escCancelsOrClears = true,
    this.deleteDeletesSelection = true,
    this.ctrlCmdExtendsSelection = true,
    this.preventArrowUpPastTableBoundary = true,
  });
}

class OperationalStandards {
  static const OperationalInteractionContract interaction =
      OperationalInteractionContract();

  static const OperationalToolbarSpec toolbar = OperationalToolbarSpec();

  static const List<int> defaultPageSizes = <int>[40, 80, 120];

  static const double folderTabsHeight = 64;
  static const double metricCardHeight = 64;

  const OperationalStandards._();
}
