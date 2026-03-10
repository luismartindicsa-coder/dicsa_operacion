import 'package:flutter/material.dart';

enum AppModuleLayout { singleGrid, tabbedGrid, cardsAndGrid }

enum AppMetricKind { kg, count, custom }

@immutable
class AppMetricSpec {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final AppMetricKind kind;

  const AppMetricSpec({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.kind = AppMetricKind.custom,
  });
}

@immutable
class AppToolbarSpec {
  final bool showExportCsv;
  final bool showGridEditToggle;
  final bool showDeleteSelected;
  final bool showSelectionCount;
  final bool showActiveCellHint;

  const AppToolbarSpec({
    this.showExportCsv = true,
    this.showGridEditToggle = true,
    this.showDeleteSelected = true,
    this.showSelectionCount = true,
    this.showActiveCellHint = true,
  });
}

@immutable
class AppTabSpec {
  final String id;
  final String label;
  final IconData icon;

  const AppTabSpec({required this.id, required this.label, required this.icon});
}

@immutable
class AppPageBlueprint {
  final String pageName;
  final String headerTitle;
  final AppModuleLayout layout;
  final List<AppTabSpec> tabs;
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

  const AppPageBlueprint({
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

  factory AppPageBlueprint.singleGrid({
    required String pageName,
    required String headerTitle,
    bool metricCardInsideBody = true,
  }) {
    return AppPageBlueprint(
      pageName: pageName,
      headerTitle: headerTitle,
      layout: AppModuleLayout.singleGrid,
      metricCardInsideBody: metricCardInsideBody,
    );
  }

  factory AppPageBlueprint.tabbedGrid({
    required String pageName,
    required String headerTitle,
    required List<AppTabSpec> tabs,
    bool metricCardInsideBody = true,
  }) {
    return AppPageBlueprint(
      pageName: pageName,
      headerTitle: headerTitle,
      layout: AppModuleLayout.tabbedGrid,
      tabs: tabs,
      metricCardInsideBody: metricCardInsideBody,
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (layout == AppModuleLayout.tabbedGrid && tabs.isEmpty) {
      errors.add('`tabs` is required when layout is `tabbedGrid`.');
    }
    if (tabs.map((t) => t.id).toSet().length != tabs.length) {
      errors.add('Tab ids must be unique.');
    }
    return errors;
  }
}

@immutable
class AppInteractionContract {
  final bool arrowsNavigateInsertRow;
  final bool arrowsNavigateGrid;
  final bool spaceOpensDropdownOrDate;
  final bool enterConfirmsPrimaryAction;
  final bool escCancelsOrClears;
  final bool deleteDeletesSelection;
  final bool ctrlCmdExtendsSelection;
  final bool preventArrowUpPastTableBoundary;

  const AppInteractionContract({
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

class AppUiStandards {
  static const AppInteractionContract interaction = AppInteractionContract();

  static const AppToolbarSpec toolbar = AppToolbarSpec();

  static const List<int> defaultPageSizes = <int>[40, 80, 120];

  static const double folderTabsHeight = 64;
  static const double metricCardHeight = 64;

  const AppUiStandards._();
}

typedef OperationalMetricSpec = AppMetricSpec;
typedef OperationalToolbarSpec = AppToolbarSpec;
typedef OperationalTabSpec = AppTabSpec;
typedef OperationalPageBlueprint = AppPageBlueprint;
typedef OperationalInteractionContract = AppInteractionContract;
typedef OperationalStandards = AppUiStandards;
