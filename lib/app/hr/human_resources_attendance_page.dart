import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/archetypes/grid_editable/grid_editable_shell.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_dialog.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_state.dart';
import '../shared/archetypes/grid_editable/grid_keyboard_shell.dart';
import '../shared/archetypes/grid_editable/grid_navigation_controller.dart';
import '../shared/archetypes/grid_editable/grid_scroll_visibility_coordinator.dart';
import '../shared/archetypes/grid_editable/grid_selection_controller.dart';
import '../shared/archetypes/grid_editable/row/editable_row_actions_button.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

const String _kHrProfilesTable = 'hr_employee_profiles';
const String _kHrImportLotsTable = 'hr_attendance_import_lots';
const String _kHrAttendanceDailyRecordsTable = 'hr_attendance_daily_records';
const String _kHrAttendanceVacationSyncPrefix = 'Vacaciones RH:';
const String _kHrAttendancePermissionSyncPrefix = 'Permisos RH:';

const double _kHrAttendanceIdW = 84;
const double _kHrAttendanceNameW = 360;
const double _kHrAttendanceWorkedW = 132;
const double _kHrAttendanceAbsentW = 132;
const double _kHrAttendanceLateW = 168;
const double _kHrAttendanceExtraW = 168;
const double _kHrAttendanceActionsW = 118;

class HumanResourcesAttendancePage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesAttendancePage({super.key, this.instantOpen = false});

  @override
  State<HumanResourcesAttendancePage> createState() =>
      _HumanResourcesAttendancePageState();
}

enum _HrAttendanceSummaryRowAction { open }

class _HumanResourcesAttendancePageState
    extends State<HumanResourcesAttendancePage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _loading = true;
  String _activePeriodLabel = '';
  String? _selectedRowId;
  String? _hoveredRowId;
  int _currentPage = 0;
  int _pageSize = 40;
  final Map<String, Set<String>> _columnFilters = <String, Set<String>>{};
  bool _dragSelectionActive = false;
  bool _dragSelectionAdditive = false;
  bool _dragSelectionMoved = false;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  Set<String> _dragSelectionBaseIds = <String>{};
  List<String> _dragSelectionIds = const <String>[];
  String? _dragSelectionAnchorId;

  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'hrAttendanceRows');
  final GridNavigationController _navigationController =
      GridNavigationController();
  final GridSelectionController _selectionController =
      GridSelectionController();
  final ScrollController _rowsScrollController = ScrollController();
  final GridScrollVisibilityCoordinator _gridVisibilityCoordinator =
      GridScrollVisibilityCoordinator();
  final GlobalKey _rowsViewportKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  List<_HrAttendanceEmployeeMaster> _employees =
      const <_HrAttendanceEmployeeMaster>[];
  final List<_HrAttendanceImportLotLite> _importLots =
      <_HrAttendanceImportLotLite>[];
  final List<_HrAttendanceStoredRecord> _storedRecords =
      <_HrAttendanceStoredRecord>[];
  List<_HrAttendanceSummaryRow> _allRows = const <_HrAttendanceSummaryRow>[];
  List<_HrAttendanceSummaryRow> _visibleRows =
      const <_HrAttendanceSummaryRow>[];

  @override
  void initState() {
    super.initState();
    _navigationController.addListener(_handleNavigationChanged);
    _selectionController.addListener(_handleSelectionChanged);
    unawaited(_resolveNavigationAccess());
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _rowsFocusNode.dispose();
    _navigationController
      ..removeListener(_handleNavigationChanged)
      ..dispose();
    _selectionController
      ..removeListener(_handleSelectionChanged)
      ..dispose();
    _rowsScrollController.dispose();
    _dragAutoScrollTimer?.cancel();
    super.dispose();
  }

  void _handleNavigationChanged() {
    final position = _navigationController.active;
    if (position.zone == GridNavigationZone.grid &&
        position.rowIndex >= 0 &&
        position.rowIndex < _visibleRows.length) {
      final row = _visibleRows[position.rowIndex];
      if (!_selectionController.isSelected(row.employeeId) ||
          _selectionController.selectedIds.length != 1) {
        _selectionController.selectSingle(
          row.employeeId,
          rowIndex: position.rowIndex,
        );
      }
      unawaited(
        _gridVisibilityCoordinator.ensureGridRowVisible(position.rowIndex),
      );
      if (!mounted) return;
      setState(() => _selectedRowId = row.employeeId);
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  void _handleSelectionChanged() {
    if (!mounted) return;
    final visibleIds = _visibleRows.map((row) => row.employeeId).toSet();
    final selectedIds = _selectionController.selectedIds.intersection(
      visibleIds,
    );
    String? nextSelectedRowId;
    if (_selectedRowId != null && selectedIds.contains(_selectedRowId)) {
      nextSelectedRowId = _selectedRowId;
    } else if (selectedIds.isNotEmpty) {
      nextSelectedRowId = _visibleRows
          .firstWhere((row) => selectedIds.contains(row.employeeId))
          .employeeId;
    }
    setState(() => _selectedRowId = nextSelectedRowId);
    _ensureSelectedRowVisible(nextSelectedRowId);
  }

  void _ensureSelectedRowVisible(String? rowId) {
    if (rowId == null) return;
    final rowIndex = _visibleRows.indexWhere((row) => row.employeeId == rowId);
    if (rowIndex < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_gridVisibilityCoordinator.ensureGridRowVisible(rowIndex));
    });
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(
      () =>
          _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile),
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final employeesResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrProfilesTable)
            .select(
              'id,nombre,empresa,horario,dias_labora,labor_schedules,fecha_ingreso,salario',
            )
            .order('id')
            .range(from, to),
      );
      final importLotsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrImportLotsTable)
            .select()
            .order('imported_at', ascending: false)
            .range(from, to),
      );
      List<dynamic> recordsResult = const <dynamic>[];
      try {
        recordsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrAttendanceDailyRecordsTable)
              .select()
              .order('source_date')
              .order('created_at')
              .range(from, to),
        );
      } catch (_) {
        recordsResult = const <dynamic>[];
      }

      final employees =
          employeesResult
              .map((raw) => Map<String, dynamic>.from(raw))
              .map(
                (row) => _HrAttendanceEmployeeMaster(
                  employeeId: (row['id'] ?? '').toString(),
                  displayName: (row['nombre'] ?? '').toString(),
                  empresa: (row['empresa'] ?? '').toString(),
                  horario: (row['horario'] ?? '').toString(),
                  diasLabora: _parseAttendanceWeekdays(row['dias_labora']),
                  workSchedules: _parseAttendanceWorkSchedules(
                    row['labor_schedules'],
                    fallbackHorario: (row['horario'] ?? '').toString(),
                    fallbackDiasLabora: _parseAttendanceWeekdays(
                      row['dias_labora'],
                    ),
                  ),
                  fechaIngreso: (row['fecha_ingreso'] ?? '').toString(),
                  salario: (row['salario'] ?? '').toString(),
                ),
              )
              .where((row) => row.employeeId.trim().isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) {
              final aInt = int.tryParse(a.employeeId);
              final bInt = int.tryParse(b.employeeId);
              if (aInt != null && bInt != null) return aInt.compareTo(bInt);
              return a.employeeId.compareTo(b.employeeId);
            });

      final lots = importLotsResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrAttendanceImportLotLite.fromRow)
          .toList(growable: false);

      final records = recordsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrAttendanceStoredRecord.fromRow)
          .toList(growable: false);

      if (!mounted) return;
      _employees = employees;
      _importLots
        ..clear()
        ..addAll(lots);
      _storedRecords
        ..clear()
        ..addAll(records);
      _rebuildRows();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _rebuildRows() {
    final ngtecoLot = _latestLotBySource(
      _importLots,
      _HrAttendanceImportSource.ngteco,
    );
    final contpaqLot = _latestLotBySource(
      _importLots,
      _HrAttendanceImportSource.contpaq,
    );
    final periodLabel = _resolveActiveAttendancePeriodLabel(
      ngtecoLot: ngtecoLot,
      contpaqLot: contpaqLot,
    );
    final rows = _buildAttendanceSummaryRows(
      employees: _employees,
      ngtecoLot: ngtecoLot,
      contpaqLot: contpaqLot,
      storedRecords: _storedRecords,
      periodLabel: periodLabel,
    );
    final filteredRows = _applyAttendanceFilters(rows);
    final pageCount = filteredRows.isEmpty
        ? 1
        : ((filteredRows.length - 1) ~/ _pageSize) + 1;
    _currentPage = _currentPage.clamp(0, pageCount - 1);
    final start = (_currentPage * _pageSize).clamp(0, filteredRows.length);
    final end = (start + _pageSize).clamp(0, filteredRows.length);
    _allRows = filteredRows;
    _visibleRows = filteredRows.sublist(start, end);
    _activePeriodLabel = periodLabel;
    _navigationController.configure(
      insertColumnCount: 0,
      gridColumnCount: _kAttendanceGridColumns.length,
      rowCount: _visibleRows.length,
    );
    if (_visibleRows.isNotEmpty) {
      final selected =
          _visibleRows.any((row) => row.employeeId == _selectedRowId)
          ? _selectedRowId
          : _visibleRows.first.employeeId;
      _selectedRowId = selected;
      _selectionController.selectSingle(
        selected!,
        rowIndex: _visibleRows.indexWhere((row) => row.employeeId == selected),
      );
      _navigationController.focusGridCell(
        rowIndex: _visibleRows.indexWhere((row) => row.employeeId == selected),
        columnIndex: 0,
      );
    } else {
      _selectedRowId = null;
      _selectionController.clear();
      _navigationController.focusInsertColumn(0);
    }
    setState(() => _loading = false);
  }

  List<_HrAttendanceSummaryRow> _applyAttendanceFilters(
    List<_HrAttendanceSummaryRow> rows,
  ) {
    if (_columnFilters.isEmpty) return rows;
    return rows
        .where((row) {
          for (final entry in _columnFilters.entries) {
            if (entry.value.isEmpty) continue;
            final value = _attendanceCellValueForColumn(row, entry.key);
            if (!entry.value.contains(value)) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _openDashboard() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openPersonnel() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesPersonnelPage(instantOpen: true)),
    );
  }

  Future<void> _openImportConciliation() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesAttendanceIncidentsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openVacations() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesVacationsPage(instantOpen: true)),
    );
  }

  Future<void> _openPermissions() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesPermissionsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openPrenomina() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesPrenominaPage(instantOpen: true)),
    );
  }

  Future<void> _openNomina() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesNominaPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    await Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const GeneralDashboardPage()));
  }

  Future<void> _logout() async => signOutAndRouteToLogin(context);

  Future<void> _openSummaryRow(_HrAttendanceSummaryRow row) async {
    final initialIndex = _allRows.indexWhere(
      (candidate) => candidate.employeeId == row.employeeId,
    );
    if (initialIndex < 0) return;
    await _openSummaryRowAtIndex(initialIndex);
  }

  Future<void> _openSummaryRowAtIndex(int index) async {
    var currentIndex = index;
    while (currentIndex >= 0 && currentIndex < _allRows.length) {
      final row = _allRows[currentIndex];
      _focusEmployeeRow(row.employeeId);
      if (!mounted) return;
      final result = await showDialog<_HrAttendanceEditResult>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _HrAttendanceEditDialog(
          row: row,
          periodLabel: _activePeriodLabel,
          canGoPrevious: currentIndex > 0,
          canGoNext: currentIndex < _allRows.length - 1,
        ),
      );
      if (result == null) return;
      await _saveAttendanceEdits(row: row, result: result);
      switch (result.action) {
        case _HrAttendanceEditAction.save:
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrAttendanceEditAction.previous:
          if (currentIndex > 0) {
            currentIndex -= 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrAttendanceEditAction.next:
          if (currentIndex < _allRows.length - 1) {
            currentIndex += 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
      }
    }
  }

  Future<void> _saveAttendanceEdits({
    required _HrAttendanceSummaryRow row,
    required _HrAttendanceEditResult result,
  }) async {
    final client = Supabase.instance.client;
    final existing = _storedRecords
        .where(
          (item) =>
              item.periodLabel == _activePeriodLabel &&
              item.employeeId == row.employeeId,
        )
        .toList(growable: false);

    final nextRecords = result.days
        .map(
          (day) => _HrAttendanceStoredRecord(
            id: '',
            periodLabel: _activePeriodLabel,
            employeeId: row.employeeId,
            employeeName: row.displayName,
            sourceDate: day.sourceDate,
            weekdayLabel: day.weekdayLabel,
            status: day.status,
            sourceMode: day.sourceMode,
            firstPunch: day.firstPunch,
            lastPunch: day.lastPunch,
            punchTimeline: day.punchTimeline,
            lateMinutes: day.lateMinutes,
            overtimeMinutes: day.overtimeMinutes,
            notes: day.notes,
          ),
        )
        .toList(growable: false);

    final nextDates = nextRecords.map((item) => item.sourceDate).toSet();
    for (final previous in existing.where(
      (item) => !nextDates.contains(item.sourceDate),
    )) {
      if (previous.id.isEmpty) continue;
      await client
          .from(_kHrAttendanceDailyRecordsTable)
          .delete()
          .eq('id', previous.id);
    }

    if (nextRecords.isNotEmpty) {
      await client
          .from(_kHrAttendanceDailyRecordsTable)
          .upsert(
            nextRecords.map((item) => item.toRow()).toList(growable: false),
            onConflict: 'period_label,employee_id,source_date',
          );
    }

    final refreshedResult = await client
        .from(_kHrAttendanceDailyRecordsTable)
        .select()
        .eq('period_label', _activePeriodLabel)
        .eq('employee_id', row.employeeId)
        .order('source_date');
    final refreshed = (refreshedResult as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .map(_HrAttendanceStoredRecord.fromRow)
        .toList(growable: false);

    _storedRecords.removeWhere(
      (item) =>
          item.periodLabel == _activePeriodLabel &&
          item.employeeId == row.employeeId,
    );
    _storedRecords.addAll(refreshed);
    _rebuildRows();
    _showSnack('Asistencia de ${row.displayName} actualizada.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  _HrAttendanceSummaryRow? _activeRow() {
    if (_selectedRowId == null) return null;
    for (final row in _allRows) {
      if (row.employeeId == _selectedRowId) return row;
    }
    return null;
  }

  void _handleTapRow(_HrAttendanceSummaryRow row, int rowIndex) {
    if (_suppressNextRowTap) {
      setState(() {
        _suppressNextRowTap = false;
        _dragSelectionMoved = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    if (_pointerDownAdditiveSelection) {
      _selectionController.toggle(row.employeeId, rowIndex: rowIndex);
      _selectedRowId = row.employeeId;
      _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
      setState(() {
        _pointerDownAdditiveSelection = false;
        _dragSelectionMoved = false;
      });
      _rowsFocusNode.requestFocus();
      return;
    }
    _selectedRowId = row.employeeId;
    _selectionController.handlePointerSelection(
      id: row.employeeId,
      rowIndex: rowIndex,
      resolveRangeIds: (start, end) => _visibleRows
          .sublist(start, end + 1)
          .map((row) => row.employeeId)
          .toList(growable: false),
      visibilityCoordinator: _gridVisibilityCoordinator,
    );
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    setState(() => _dragSelectionMoved = false);
    _rowsFocusNode.requestFocus();
  }

  void _prepareRowSelectionForActions({
    required String rowId,
    required int rowIndex,
  }) {
    final preserveMultiSelection =
        _selectionController.selectedIds.length > 1 &&
        _selectionController.selectedIds.contains(rowId);
    if (!preserveMultiSelection) {
      _selectionController.selectSingle(rowId, rowIndex: rowIndex);
      setState(() => _selectedRowId = rowId);
    } else {
      _selectionController.anchorIndex = rowIndex;
      setState(() => _selectedRowId = rowId);
    }
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    _rowsFocusNode.requestFocus();
  }

  void _beginDragSelection(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  }) {
    _rowsFocusNode.requestFocus();
    final rowIndex = visibleIds.indexOf(rowId);
    if (rowIndex < 0) return;
    final baseIds = additive
        ? {..._selectionController.selectedIds}
        : <String>{};
    final nextIds = additive ? baseIds : <String>{rowId};
    setState(() {
      _dragSelectionActive = true;
      _dragSelectionAdditive = additive;
      _dragSelectionMoved = false;
      _suppressNextRowTap = false;
      _pointerDownAdditiveSelection = additive;
      _dragSelectionBaseIds = baseIds;
      _dragSelectionIds = visibleIds;
      _dragSelectionAnchorId = rowId;
      _selectedRowId = rowId;
      _dragPointerGlobal = null;
    });
    _selectionController.selectRange(nextIds, anchorRowIndex: rowIndex);
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
  }

  void _updateDragSelection(String rowId) {
    if (!_dragSelectionActive || _dragSelectionAnchorId == null) return;
    final visibleIds = _dragSelectionIds;
    final start = visibleIds.indexOf(_dragSelectionAnchorId!);
    final end = visibleIds.indexOf(rowId);
    if (start == -1 || end == -1) return;
    final range = visibleIds.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    final nextIds = _dragSelectionAdditive
        ? {..._dragSelectionBaseIds, ...range}
        : range.toSet();
    _selectionController.selectRange(nextIds, anchorRowIndex: start);
    _navigationController.focusGridCell(rowIndex: end, columnIndex: 0);
    setState(() {
      _selectedRowId = rowId;
      _dragSelectionMoved = end != start || nextIds.length > 1;
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive) return;
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAdditive = false;
      _suppressNextRowTap = _dragSelectionMoved;
      if (_dragSelectionMoved) {
        _pointerDownAdditiveSelection = false;
      }
      _dragSelectionIds = const <String>[];
      _dragSelectionAnchorId = null;
      _dragSelectionBaseIds = <String>{};
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<String> visibleIds,
  ) {
    for (var i = 0; i < visibleIds.length; i++) {
      final box =
          _rowKeys[visibleIds[i]]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(List<String> visibleIds, {required bool last}) {
    final indexes = <int>[];
    for (var i = 0; i < visibleIds.length; i++) {
      final box =
          _rowKeys[visibleIds[i]]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(PointerMoveEvent event, List<String> visibleIds) {
    if (!_dragSelectionActive) return;
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(visibleIds);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(
      event.position,
      visibleIds,
    );
    if (visibleIndex == null) return;
    _updateDragSelection(visibleIds[visibleIndex]);
  }

  void _updateDragAutoScroll(List<String> visibleIds) {
    if (!_dragSelectionActive || _dragPointerGlobal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final local = box.globalToLocal(_dragPointerGlobal!);
    final y = local.dy;
    if (y < edge) {
      _dragAutoScrollVelocity = -((edge - y) / edge).clamp(0.0, 1.0) * maxStep;
    } else if (y > box.size.height - edge) {
      _dragAutoScrollVelocity =
          ((y - (box.size.height - edge)) / edge).clamp(0.0, 1.0) * maxStep;
    } else {
      _dragAutoScrollVelocity = 0;
    }
    if (_dragAutoScrollVelocity == 0) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    _dragAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performDragAutoScroll(visibleIds),
    );
  }

  void _performDragAutoScroll(List<String> visibleIds) {
    if (!_dragSelectionActive ||
        _dragAutoScrollVelocity == 0 ||
        !_rowsScrollController.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _rowsScrollController.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    _rowsScrollController.jumpTo(next);
    final pointer = _dragPointerGlobal;
    final viewportBox =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || viewportBox == null || !viewportBox.hasSize) return;
    final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, visibleIds);
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy < 0) {
        targetIndex = _mountedEdgeRowIndex(visibleIds, last: false);
      } else if (local.dy > viewportBox.size.height) {
        targetIndex = _mountedEdgeRowIndex(visibleIds, last: true);
      }
    }
    if (targetIndex == null) return;
    _updateDragSelection(visibleIds[targetIndex]);
  }

  Future<void> _openRowMenu(
    TapDownDetails details,
    _HrAttendanceSummaryRow row,
    int rowIndex,
  ) async {
    _prepareRowSelectionForActions(rowId: row.employeeId, rowIndex: rowIndex);
    final selected =
        await showContractContextMenu<_HrAttendanceSummaryRowAction>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          entries: const [
            ContractMenuEntry(
              value: _HrAttendanceSummaryRowAction.open,
              label: 'Editar asistencia',
              icon: Icons.edit_calendar_rounded,
            ),
          ],
        );
    if (selected != null && mounted) {
      await _openSummaryRow(row);
    }
  }

  bool _hasActiveFilter(String columnId) =>
      (_columnFilters[columnId] ?? const <String>{}).isNotEmpty;

  Future<void> _openColumnFilter(String columnId, String label) async {
    final options =
        _allRows
            .map((row) => _attendanceCellValueForColumn(row, columnId))
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final current = _columnFilters[columnId] ?? const <String>{};
    final result = await showDialog<GridFilterState>(
      context: context,
      builder: (context) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: GridFilterDialog(
          title: label,
          initialState: GridFilterState(
            options: options
                .map(
                  (value) => GridFilterOption(
                    value: value,
                    label: value,
                    selected: current.contains(value),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final selected = result.selectedValues;
      if (selected.isEmpty) {
        _columnFilters.remove(columnId);
      } else {
        _columnFilters[columnId] = selected;
      }
      _currentPage = 0;
    });
    _rebuildRows();
  }

  void _focusEmployeeRow(String employeeId) {
    final globalIndex = _allRows.indexWhere(
      (row) => row.employeeId == employeeId,
    );
    if (globalIndex < 0) return;
    _selectedRowId = employeeId;
    _currentPage = globalIndex ~/ _pageSize;
    _rebuildRows();
    _rowsFocusNode.requestFocus();
  }

  GlobalKey _rowKeyForId(String rowId) =>
      _rowKeys.putIfAbsent(rowId, () => GlobalKey());

  void _handleEscape() {
    if (_menuOpen) {
      setState(() => _menuOpen = false);
      return;
    }
    if (_selectedRowId != null) {
      _selectionController.clear();
      setState(() => _selectedRowId = null);
      return;
    }
    if (_visibleRows.isNotEmpty) {
      _selectedRowId = _visibleRows.first.employeeId;
      _selectionController.selectSingle(_selectedRowId!, rowIndex: 0);
      _navigationController.focusGridCell(rowIndex: 0, columnIndex: 0);
      _rowsFocusNode.requestFocus();
      setState(() {});
    }
  }

  void _openActiveRecord() {
    if (_visibleRows.isEmpty) return;
    final index = _navigationController.active.rowIndex;
    if (index < 0 || index >= _visibleRows.length) return;
    unawaited(_openSummaryRow(_visibleRows[index]));
  }

  void _changePageSize(int value) {
    _pageSize = value;
    _currentPage = 0;
    _rebuildRows();
  }

  void _previousPage() {
    if (_currentPage <= 0) return;
    _currentPage -= 1;
    _rebuildRows();
  }

  void _nextPage() {
    final totalPages = _allRows.isEmpty
        ? 1
        : ((_allRows.length - 1) ~/ _pageSize) + 1;
    if (_currentPage >= totalPages - 1) return;
    _currentPage += 1;
    _rebuildRows();
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: humanResourcesAreaTokens,
      child: AppShell(
        background: const HumanResourcesAreaBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 8,
        padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
        leadingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: _menuOpen ? 'Cerrar panel' : 'Navegación',
          icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
          onTapSync: () => setState(() => _menuOpen = !_menuOpen),
        ),
        centerBuilder: (_, _) => const _HrAttendanceHeaderBrand(),
        trailingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: _logout,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 4, 8, 0),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : _HrAttendanceWorkspace(
                          allRows: _allRows,
                          rows: _visibleRows,
                          totalRows: _allRows.length,
                          selectedCount:
                              _selectionController.selectedIds.length,
                          activePeriodLabel: _activePeriodLabel,
                          navigationController: _navigationController,
                          selectionController: _selectionController,
                          rowsScrollController: _rowsScrollController,
                          visibilityCoordinator: _gridVisibilityCoordinator,
                          rowsViewportKey: _rowsViewportKey,
                          rowsFocusNode: _rowsFocusNode,
                          selectedRowId: _selectedRowId,
                          rowKeyForId: _rowKeyForId,
                          onRowsPointerMove: _handleRowsPointerMove,
                          onTapRow: _handleTapRow,
                          onPrepareRowActions:
                              (_HrAttendanceSummaryRow row, int rowIndex) =>
                                  _prepareRowSelectionForActions(
                                    rowId: row.employeeId,
                                    rowIndex: rowIndex,
                                  ),
                          onBeginDragSelection: _beginDragSelection,
                          onUpdateDragSelection: _updateDragSelection,
                          onEndDragSelection: _endDragSelection,
                          onRowContextMenu: _openRowMenu,
                          onOpenRow: _openSummaryRow,
                          currentPage: _currentPage,
                          totalPages: _allRows.isEmpty
                              ? 1
                              : ((_allRows.length - 1) ~/ _pageSize) + 1,
                          pageSize: _pageSize,
                          onPreviousPage: _currentPage == 0
                              ? null
                              : _previousPage,
                          onNextPage:
                              (((_allRows.isEmpty
                                          ? 1
                                          : ((_allRows.length - 1) ~/
                                                    _pageSize) +
                                                1) -
                                      1) <=
                                  _currentPage)
                              ? null
                              : _nextPage,
                          onPageSizeChanged: _changePageSize,
                          onOpenSelectedRow: () async {
                            final row = _activeRow();
                            if (row != null) await _openSummaryRow(row);
                          },
                          onEscape: _handleEscape,
                          onOpenActiveCell: _openActiveRecord,
                          hoveredRowId: _hoveredRowId,
                          hasActiveFilter: _hasActiveFilter,
                          onOpenFilter: _openColumnFilter,
                          onHoverRowChanged: (value) {
                            if (_hoveredRowId == value) return;
                            setState(() => _hoveredRowId = value);
                          },
                        ),
                ),
              ),
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.attendance,
                openPersonnel: _openPersonnel,
                openAttendance: () async {},
                openImportConciliation: _openImportConciliation,
                openVacations: _openVacations,
                openPermissions: _openPermissions,
                openPrenomina: _openPrenomina,
                openNomina: _openNomina,
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.attendance,
                openDashboard: _openDashboard,
                canReturnToDirection: _canReturnToDirection,
                openDirectionDashboard: _openDirectionDashboard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceWorkspace extends StatelessWidget {
  final List<_HrAttendanceSummaryRow> allRows;
  final List<_HrAttendanceSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final String activePeriodLabel;
  final String? hoveredRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final ScrollController rowsScrollController;
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final GlobalKey rowsViewportKey;
  final FocusNode rowsFocusNode;
  final String? selectedRowId;
  final GlobalKey Function(String rowId) rowKeyForId;
  final void Function(PointerMoveEvent event, List<String> visibleIds)
  onRowsPointerMove;
  final void Function(_HrAttendanceSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrAttendanceSummaryRow row, int rowIndex)
  onPrepareRowActions;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(
    TapDownDetails details,
    _HrAttendanceSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final Future<void> Function(_HrAttendanceSummaryRow row) onOpenRow;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;
  final Future<void> Function() onOpenSelectedRow;
  final VoidCallback onEscape;
  final VoidCallback onOpenActiveCell;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final ValueChanged<String?> onHoverRowChanged;

  const _HrAttendanceWorkspace({
    required this.allRows,
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activePeriodLabel,
    required this.hoveredRowId,
    required this.navigationController,
    required this.selectionController,
    required this.rowsScrollController,
    required this.visibilityCoordinator,
    required this.rowsViewportKey,
    required this.rowsFocusNode,
    required this.selectedRowId,
    required this.rowKeyForId,
    required this.onRowsPointerMove,
    required this.onTapRow,
    required this.onPrepareRowActions,
    required this.onBeginDragSelection,
    required this.onUpdateDragSelection,
    required this.onEndDragSelection,
    required this.onRowContextMenu,
    required this.onOpenRow,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
    required this.onOpenSelectedRow,
    required this.onEscape,
    required this.onOpenActiveCell,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onHoverRowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = navigationController.active;
    final activeLabel = active.zone == GridNavigationZone.grid
        ? _kAttendanceGridColumns[active.columnIndex.clamp(
                0,
                _kAttendanceGridColumns.length - 1,
              )]
              .label
        : null;
    return ContractGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: GridKeyboardShell(
          navigationController: navigationController,
          focusNode: rowsFocusNode,
          onEscape: onEscape,
          onConfirm: () => unawaited(onOpenSelectedRow()),
          onOpenActiveCell: onOpenActiveCell,
          onNavigated: (position) {
            if (position.zone != GridNavigationZone.grid) return;
            unawaited(
              visibilityCoordinator.ensureGridRowVisible(
                position.rowIndex,
                alignment: 0.5,
                allowSkipIfFullyVisible: false,
              ),
            );
          },
          child: GridEditableShell(
            topBar: _HrAttendanceModuleTopBar(
              rows: allRows,
              totalRows: totalRows,
              selectedCount: selectedCount,
              activeCellLabel: activeLabel == null
                  ? null
                  : 'Celda: $activeLabel',
              onOpenSelectedRow: () => unawaited(onOpenSelectedRow()),
            ),
            body: _HrAttendanceGrid(
              rows: rows,
              hoveredRowId: hoveredRowId,
              selectedRowId: selectedRowId,
              navigationController: navigationController,
              selectionController: selectionController,
              rowsScrollController: rowsScrollController,
              visibilityCoordinator: visibilityCoordinator,
              rowsViewportKey: rowsViewportKey,
              rowKeyForId: rowKeyForId,
              onRowsPointerMove: onRowsPointerMove,
              onTapRow: onTapRow,
              onPrepareRowActions: onPrepareRowActions,
              onBeginDragSelection: onBeginDragSelection,
              onUpdateDragSelection: onUpdateDragSelection,
              onEndDragSelection: onEndDragSelection,
              onRowContextMenu: onRowContextMenu,
              onOpenRow: onOpenRow,
              hasActiveFilter: hasActiveFilter,
              onOpenFilter: onOpenFilter,
              onHoverRowChanged: onHoverRowChanged,
            ),
            footer: _HrAttendanceGridFooter(
              rows: rows.length,
              totalRows: totalRows,
              selectedCount: selectedCount,
              currentPage: currentPage,
              totalPages: totalPages,
              pageSize: pageSize,
              onPreviousPage: onPreviousPage,
              onNextPage: onNextPage,
              onPageSizeChanged: onPageSizeChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _HrAttendanceGrid extends StatelessWidget {
  final List<_HrAttendanceSummaryRow> rows;
  final String? hoveredRowId;
  final String? selectedRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final ScrollController rowsScrollController;
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final GlobalKey rowsViewportKey;
  final GlobalKey Function(String rowId) rowKeyForId;
  final void Function(PointerMoveEvent event, List<String> visibleIds)
  onRowsPointerMove;
  final void Function(_HrAttendanceSummaryRow row, int rowIndex) onTapRow;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(_HrAttendanceSummaryRow row) onOpenRow;
  final void Function(_HrAttendanceSummaryRow row, int rowIndex)
  onPrepareRowActions;
  final Future<void> Function(
    TapDownDetails details,
    _HrAttendanceSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final ValueChanged<String?> onHoverRowChanged;

  const _HrAttendanceGrid({
    required this.rows,
    required this.hoveredRowId,
    required this.selectedRowId,
    required this.navigationController,
    required this.selectionController,
    required this.rowsScrollController,
    required this.visibilityCoordinator,
    required this.rowsViewportKey,
    required this.rowKeyForId,
    required this.onRowsPointerMove,
    required this.onTapRow,
    required this.onBeginDragSelection,
    required this.onUpdateDragSelection,
    required this.onEndDragSelection,
    required this.onOpenRow,
    required this.onPrepareRowActions,
    required this.onRowContextMenu,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onHoverRowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xDDF0E7FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x66B084FF)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                children: [
                  _HrAttendanceGridHeader(
                    hasActiveFilter: hasActiveFilter,
                    onOpenFilter: onOpenFilter,
                  ),
                  Expanded(
                    child: Listener(
                      onPointerMove: (event) => onRowsPointerMove(
                        event,
                        rows
                            .map((row) => row.employeeId)
                            .toList(growable: false),
                      ),
                      onPointerUp: (_) => onEndDragSelection(),
                      onPointerCancel: (_) => onEndDragSelection(),
                      child: Container(
                        key: rowsViewportKey,
                        child: SingleChildScrollView(
                          controller: rowsScrollController,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                0,
                                constraints.maxHeight - 68,
                              ),
                            ),
                            child: Column(
                              children: [
                                if (rows.isEmpty)
                                  const _HrAttendanceEmptyState()
                                else
                                  for (
                                    var index = 0;
                                    index < rows.length;
                                    index++
                                  )
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        6,
                                        index == 0 ? 8 : 2,
                                        6,
                                        index == rows.length - 1 ? 8 : 2,
                                      ),
                                      child: KeyedSubtree(
                                        key: rowKeyForId(
                                          rows[index].employeeId,
                                        ),
                                        child: _HrAttendanceGridRow(
                                          key: visibilityCoordinator.keyForCell(
                                            zone: GridNavigationZone.grid,
                                            rowIndex: index,
                                            columnIndex: 0,
                                          ),
                                          row: rows[index],
                                          rowIndex: index,
                                          hovered:
                                              hoveredRowId ==
                                              rows[index].employeeId,
                                          active:
                                              navigationController
                                                      .active
                                                      .zone ==
                                                  GridNavigationZone.grid &&
                                              navigationController
                                                      .active
                                                      .rowIndex ==
                                                  index,
                                          selected:
                                              selectedRowId ==
                                                  rows[index].employeeId ||
                                              selectionController.isSelected(
                                                rows[index].employeeId,
                                              ),
                                          onTap: () =>
                                              onTapRow(rows[index], index),
                                          onOpen: () => onOpenRow(rows[index]),
                                          onPrepareActionsMenu: () =>
                                              onPrepareRowActions(
                                                rows[index],
                                                index,
                                              ),
                                          onPrimaryPointerDown: (additive) =>
                                              onBeginDragSelection(
                                                rows[index].employeeId,
                                                rows
                                                    .map(
                                                      (item) => item.employeeId,
                                                    )
                                                    .toList(growable: false),
                                                additive: additive,
                                              ),
                                          onDragEnter: () =>
                                              onUpdateDragSelection(
                                                rows[index].employeeId,
                                              ),
                                          onPointerEnd: onEndDragSelection,
                                          onSecondaryTapDown: (details) =>
                                              onRowContextMenu(
                                                details,
                                                rows[index],
                                                index,
                                              ),
                                          onHoverChanged: onHoverRowChanged,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HrAttendanceEmptyState extends StatelessWidget {
  const _HrAttendanceEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: const BoxDecoration(color: Color(0xDDF0E7FF)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F3FF).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0x66B68CFF),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 34,
              color: Color(0xFFB68CFF),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin coincidencias',
              style: TextStyle(
                color: Color(0xFF24103D),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Carga importaciones o ajusta el periodo para volver a mostrar el cierre editable de asistencia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF6E47A8).withValues(alpha: 0.92),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceGridHeader extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;

  const _HrAttendanceGridHeader({
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: Color(0xFF24103D),
      letterSpacing: 0.3,
    );
    return Card(
      elevation: 0,
      color: const Color(0xFFF4EEFF).withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: _kHrAttendanceIdW,
              child: _HrAttendanceHeaderText(
                'ID',
                style: style,
                active: hasActiveFilter('id'),
                onFilter: () => onOpenFilter('id', 'ID'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _HrAttendanceHeaderText(
                'NOMBRE',
                style: style,
                active: hasActiveFilter('nombre'),
                onFilter: () => onOpenFilter('nombre', 'Nombre'),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: _kHrAttendanceWorkedW,
              child: _HrAttendanceHeaderText(
                'DÍAS LABORÓ',
                style: style,
                centered: true,
                active: hasActiveFilter('dias_laboro'),
                onFilter: () => onOpenFilter('dias_laboro', 'Días laboró'),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: _kHrAttendanceAbsentW,
              child: _HrAttendanceHeaderText(
                'DÍAS FALTÓ',
                style: style,
                centered: true,
                active: hasActiveFilter('dias_falto'),
                onFilter: () => onOpenFilter('dias_falto', 'Días faltó'),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: _kHrAttendanceLateW,
              child: _HrAttendanceHeaderText(
                'RETARDO',
                style: style,
                centered: true,
                active: hasActiveFilter('retardo'),
                onFilter: () => onOpenFilter('retardo', 'Retardo'),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: _kHrAttendanceExtraW,
              child: _HrAttendanceHeaderText(
                'HORAS EXTRA',
                style: style,
                centered: true,
                active: hasActiveFilter('extra'),
                onFilter: () => onOpenFilter('extra', 'Horas extra'),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: _kHrAttendanceActionsW,
              child: _HrAttendanceHeaderText(
                'ACCIONES',
                style: style,
                centered: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceHeaderText extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool centered;
  final bool active;
  final VoidCallback? onFilter;

  const _HrAttendanceHeaderText(
    this.label, {
    required this.style,
    this.centered = false,
    this.active = false,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final filterIcon = onFilter == null
        ? const SizedBox(width: 21, height: 21)
        : InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onFilter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: active
                    ? humanResourcesAreaTokens.primary
                    : const Color(0xFFE7D8FF).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? humanResourcesAreaTokens.primary
                      : const Color(0xFF6E47A8).withValues(alpha: 0.26),
                ),
              ),
              child: Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 15,
                color: active ? Colors.white : const Color(0xFF6E47A8),
              ),
            ),
          );
    return Row(
      children: [
        filterIcon,
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            textAlign: centered ? TextAlign.center : TextAlign.left,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _HrAttendanceGridRow extends StatelessWidget {
  final _HrAttendanceSummaryRow row;
  final int rowIndex;
  final bool hovered;
  final bool active;
  final bool selected;
  final VoidCallback onTap;
  final Future<void> Function() onOpen;
  final VoidCallback onPrepareActionsMenu;
  final ValueChanged<bool>? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final GestureTapDownCallback? onSecondaryTapDown;
  final ValueChanged<String?> onHoverChanged;

  const _HrAttendanceGridRow({
    super.key,
    required this.row,
    required this.rowIndex,
    required this.hovered,
    required this.active,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onPrepareActionsMenu,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    this.onSecondaryTapDown,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = active || selected;
    final hoverOnly = hovered && !hasSelection;
    final rowBg = hasSelection
        ? const Color(0xFF9F6BFF).withValues(alpha: 0.18)
        : hoverOnly
        ? const Color(0xFFF6F0FF)
        : Colors.white;
    final hoverLift = hasSelection
        ? -1.4
        : hovered
        ? -1.15
        : 0.0;
    final hoverElevation = hasSelection
        ? 3.2
        : hovered
        ? 2.7
        : 0.5;

    return MouseRegion(
      onEnter: (_) {
        onHoverChanged(row.employeeId);
        onDragEnter?.call();
      },
      onExit: (_) => onHoverChanged(null),
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            final pressed = HardwareKeyboard.instance.logicalKeysPressed;
            final additive =
                pressed.contains(LogicalKeyboardKey.controlLeft) ||
                pressed.contains(LogicalKeyboardKey.controlRight) ||
                pressed.contains(LogicalKeyboardKey.metaLeft) ||
                pressed.contains(LogicalKeyboardKey.metaRight);
            onPrimaryPointerDown?.call(additive);
          }
        },
        onPointerUp: (_) => onPointerEnd?.call(),
        onPointerCancel: (_) => onPointerEnd?.call(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onDoubleTap: () async => onOpen(),
            onSecondaryTapDown: onSecondaryTapDown,
            child: AnimatedContainer(
              duration: Duration.zero,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, hoverLift, 0),
              child: Card(
                elevation: hoverElevation,
                color: rowBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: hasSelection
                        ? const Color(0xFF9F6BFF).withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _kHrAttendanceIdW,
                        child: Text(
                          row.employeeId,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF24103D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _attendanceRowOperationalSubtitle(row),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _attendanceRowOperationalColor(row),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrAttendanceWorkedW,
                        child: Text(
                          row.daysWorkedCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrAttendanceAbsentW,
                        child: Text(
                          row.daysAbsentCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrAttendanceLateW,
                        child: Text(
                          _formatAttendanceMinutesAsHourRatio(
                            row.lateMinutesSum,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrAttendanceExtraW,
                        child: Text(
                          _formatAttendanceMinutesAsHourRatio(
                            row.overtimeMinutesSum,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrAttendanceActionsW,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 36,
                            decoration: BoxDecoration(
                              color: hasSelection
                                  ? const Color(0xFF6E47A8)
                                  : const Color(0xFFF3EBFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasSelection
                                    ? const Color(
                                        0xFF9F6BFF,
                                      ).withValues(alpha: 0.86)
                                    : const Color(
                                        0xFFB68CFF,
                                      ).withValues(alpha: 0.38),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: hasSelection ? 0.12 : 0.06,
                                  ),
                                  blurRadius: hasSelection ? 12 : 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child:
                                EditableRowActionsButton<
                                  _HrAttendanceSummaryRowAction
                                >(
                                  tooltip: 'Acciones de asistencia',
                                  iconColor: hasSelection
                                      ? Colors.white
                                      : const Color(0xFF6E47A8),
                                  onBeforeOpen: onPrepareActionsMenu,
                                  entries: const [
                                    ContractMenuEntry(
                                      value: _HrAttendanceSummaryRowAction.open,
                                      label: 'Editar asistencia',
                                      icon: Icons.edit_calendar_rounded,
                                    ),
                                  ],
                                  onSelected: (_) async => onOpen(),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HrAttendanceModuleTopBar extends StatelessWidget {
  final List<_HrAttendanceSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final String? activeCellLabel;
  final VoidCallback onOpenSelectedRow;

  const _HrAttendanceModuleTopBar({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activeCellLabel,
    required this.onOpenSelectedRow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Asistencia',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        AppGlassToolbarPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = _HrAttendanceSelectionInfo(
                selectedCount: selectedCount,
                activeCellLabel: activeCellLabel,
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: onOpenSelectedRow,
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Editar asistencia'),
                  ),
                ],
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actions,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: 10),
                  info,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _HrAttendanceMetricCard(totalRows: totalRows, rows: rows),
        ),
      ],
    );
  }
}

class _HrAttendanceSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final String? activeCellLabel;

  const _HrAttendanceSelectionInfo({
    required this.selectedCount,
    required this.activeCellLabel,
  });

  @override
  Widget build(BuildContext context) {
    final summary = selectedCount == 1
        ? '1 registro seleccionado'
        : '${_fmtAttendanceInt(selectedCount)} registros seleccionados';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          summary,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF24103D),
          ),
          textAlign: TextAlign.right,
        ),
        if (selectedCount > 1)
          const Text(
            'Shift/Ctrl amplian la selección activa',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E47A8),
            ),
            textAlign: TextAlign.right,
          ),
        if (activeCellLabel != null)
          Text(
            activeCellLabel!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E47A8),
            ),
            textAlign: TextAlign.right,
          ),
      ],
    );
  }
}

String _fmtAttendanceInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final reverseIndex = text.length - i;
    buffer.write(text[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

class _HrAttendanceMetricCard extends StatelessWidget {
  final int totalRows;
  final List<_HrAttendanceSummaryRow> rows;

  const _HrAttendanceMetricCard({required this.totalRows, required this.rows});

  @override
  Widget build(BuildContext context) {
    final allDays = rows.expand((row) => row.days).toList(growable: false);
    final importedDays = allDays.where(_attendanceDayIsImported).length;
    final manualDays = allDays.where(_attendanceDayIsManual).length;
    final adjustedDays = allDays.where(_attendanceDayIsAdjusted).length;
    final justifiedDays = allDays.where(_attendanceDayIsJustified).length;
    final readyDays = allDays.where(_attendanceDayIsReadyForPrenomina).length;
    final reviewDays = allDays.where(_attendanceDayNeedsReview).length;
    return Container(
      constraints: const BoxConstraints(minWidth: 278),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EAFF).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66B084FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF130B22).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFF6E47A8),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ASISTENCIA RH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6E47A8),
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                _fmtAttendanceInt(totalRows),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24103D),
                  height: 1,
                ),
              ),
              Text(
                'Filtrado (${_fmtAttendanceInt(totalRows)} registros)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6E47A8).withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HrAttendanceMetricPill(
                    label: 'Importado: ${_fmtAttendanceInt(importedDays)}',
                  ),
                  _HrAttendanceMetricPill(
                    label:
                        'Manual/Ajuste: ${_fmtAttendanceInt(manualDays + adjustedDays)}',
                  ),
                  _HrAttendanceMetricPill(
                    label: 'Justificado: ${_fmtAttendanceInt(justifiedDays)}',
                  ),
                  _HrAttendanceMetricPill(
                    label: 'Listo prenómina: ${_fmtAttendanceInt(readyDays)}',
                  ),
                  _HrAttendanceMetricPill(
                    label: 'Revisión RH: ${_fmtAttendanceInt(reviewDays)}',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceMetricPill extends StatelessWidget {
  final String label;

  const _HrAttendanceMetricPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE9DAFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55B084FF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF24103D),
        ),
      ),
    );
  }
}

class _HrAttendanceGridFooter extends StatelessWidget {
  final int rows;
  final int totalRows;
  final int selectedCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HrAttendanceGridFooter({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        elevation: 0,
        color: const Color(0xFFF0E6FF).withValues(alpha: 0.56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: _hrAttendanceActionOutlinedButtonStyle(),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${_fmtAttendanceInt(currentPage + 1)} de ${_fmtAttendanceInt(totalPages)}',
              ),
              OutlinedButton.icon(
                style: _hrAttendanceActionOutlinedButtonStyle(),
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Siguiente'),
              ),
              const Text('Filas/pág:'),
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<int>(
                  initialValue: pageSize,
                  isDense: true,
                  decoration: _hrAttendanceFieldDecoration(),
                  items: const [40, 80, 120]
                      .map(
                        (e) =>
                            DropdownMenuItem<int>(value: e, child: Text('$e')),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onPageSizeChanged(value);
                  },
                ),
              ),
              Text('Mostrando: ${_fmtAttendanceInt(rows)}'),
              Text('Total: ${_fmtAttendanceInt(totalRows)}'),
              Text('Selección: ${_fmtAttendanceInt(selectedCount)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrAttendanceHeaderBrand extends StatelessWidget {
  const _HrAttendanceHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: const DicsaLogoD(size: 36, progress: 1),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recursos Humanos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Asistencia',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFCFAEFF),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HrAttendanceEditDialog extends StatefulWidget {
  final _HrAttendanceSummaryRow row;
  final String periodLabel;
  final bool canGoPrevious;
  final bool canGoNext;

  const _HrAttendanceEditDialog({
    required this.row,
    required this.periodLabel,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  State<_HrAttendanceEditDialog> createState() =>
      _HrAttendanceEditDialogState();
}

class _HrAttendanceEditDialogState extends State<_HrAttendanceEditDialog> {
  final FocusNode _dialogFocusNode = FocusNode(
    debugLabel: 'hrAttendanceDialog',
  );
  int? _selectedWorkScheduleIndex;
  late final List<_HrAttendanceDayDraft> _days = widget.row.days
      .map((day) => day.toDraft())
      .toList(growable: true);

  @override
  void initState() {
    super.initState();
    _applySelectedScheduleToDays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addManualDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _parseAttendanceDateLabel(
            _days.isEmpty
                ? _fmtAttendanceDateLabel(DateTime.now())
                : _days.last.sourceDate,
          ) ??
          DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (picked == null || !mounted) return;
    final sourceDate = _fmtAttendanceDateLabel(picked);
    if (_days.any((day) => day.sourceDate == sourceDate)) return;
    final weekdayLabel = _hrWeekdayLabel(picked.weekday);
    final punchlessSchedule = _resolveAttendanceScheduleForPunchlessDay(
      schedules: widget.row.workSchedules,
      weekdayLabel: weekdayLabel,
    );
    setState(() {
      _days.add(
        _HrAttendanceDayDraft(
          localId: 'manual_${picked.microsecondsSinceEpoch}',
          sourceDate: sourceDate,
          weekdayLabel: weekdayLabel,
          status: _HrAttendanceStatus.noAplica,
          sourceMode: 'manual',
          scheduledStart: punchlessSchedule == null
              ? ''
              : _fmtTimeOfDay(punchlessSchedule.schedule.start),
          scheduledEnd: punchlessSchedule == null
              ? ''
              : _fmtTimeOfDay(punchlessSchedule.schedule.end),
          effectiveWorkMinutes: punchlessSchedule == null
              ? 0
              : _resolveAttendanceEffectiveWorkMinutes(
                  punchlessSchedule.schedule,
                ),
        ),
      );
      _applySelectedScheduleToDays();
      _days.sort((a, b) {
        final aDate = _parseAttendanceDateLabel(a.sourceDate);
        final bDate = _parseAttendanceDateLabel(b.sourceDate);
        if (aDate != null && bDate != null) return aDate.compareTo(bDate);
        return a.sourceDate.compareTo(b.sourceDate);
      });
    });
  }

  bool _hasEditableTextFocus() {
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  void _applySelectedScheduleToDays() {
    final overrideSchedule =
        _selectedWorkScheduleIndex != null &&
            _selectedWorkScheduleIndex! >= 0 &&
            _selectedWorkScheduleIndex! < widget.row.workSchedules.length
        ? widget.row.workSchedules[_selectedWorkScheduleIndex!]
        : null;
    final parsedOverride = overrideSchedule == null
        ? null
        : _parseAttendanceSchedule(overrideSchedule.horario);
    for (final day in _days) {
      if (parsedOverride != null) {
        day.scheduledStart = _fmtTimeOfDay(parsedOverride.start);
        day.scheduledEnd = _fmtTimeOfDay(parsedOverride.end);
        day.effectiveWorkMinutes = _resolveAttendanceEffectiveWorkMinutes(
          parsedOverride,
        );
      } else {
        day.scheduledStart = day.originalScheduledStart;
        day.scheduledEnd = day.originalScheduledEnd;
        day.effectiveWorkMinutes = day.originalEffectiveWorkMinutes;
      }
      _recalculateAttendanceDraftMetrics(day);
    }
  }

  void _save([_HrAttendanceEditAction action = _HrAttendanceEditAction.save]) {
    Navigator.of(context).pop(
      _HrAttendanceEditResult(
        action: action,
        days: _days
            .where((day) => day.sourceDate.trim().isNotEmpty)
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workedCount = _days
        .where((day) => day.status == _HrAttendanceStatus.laboro)
        .length;
    final absentCount = _days
        .where((day) => day.status == _HrAttendanceStatus.falto)
        .length;
    final totalLateMinutes = _days.fold<int>(
      0,
      (sum, day) => sum + day.lateMinutes,
    );
    final totalExtraMinutes = _days.fold<int>(
      0,
      (sum, day) => sum + day.overtimeMinutes,
    );
    final importedDays = _days.where(_attendanceDraftIsImported).length;
    final manualDays = _days.where(_attendanceDraftIsManual).length;
    final adjustedDays = _days.where(_attendanceDraftIsAdjusted).length;
    final vacationDays = _days.where(_attendanceDraftHasVacationSync).length;
    final permissionDays = _days
        .where(_attendanceDraftHasPermissionSync)
        .length;
    final readyDays = _days.where(_attendanceDraftIsReadyForPrenomina).length;
    final reviewDays = _days.where(_attendanceDraftNeedsReview).length;
    return Focus(
      autofocus: true,
      focusNode: _dialogFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        if (!_hasEditableTextFocus() &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _save();
          return KeyEventResult.handled;
        }
        if (!_hasEditableTextFocus() &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.canGoPrevious) {
          _save(_HrAttendanceEditAction.previous);
          return KeyEventResult.handled;
        }
        if (!_hasEditableTextFocus() &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.canGoNext) {
          _save(_HrAttendanceEditAction.next);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ContractDialogShell(
        insetPadding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Container(
            width: 1028,
            constraints: BoxConstraints(
              maxWidth: 1028,
              maxHeight: MediaQuery.sizeOf(context).height - 48,
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F0FF).withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x66B084FF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HumanResourcesCompactDialogHeader(
                  title: 'Asistencia',
                  contextLabel: widget.periodLabel.isEmpty
                      ? 'Cierre editable por colaborador'
                      : widget.periodLabel,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 250,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF3E9FF,
                            ).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x55B084FF)),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.row.displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF24103D),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ID #${widget.row.employeeId}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6E47A8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.row.empresa.isEmpty
                                      ? 'Empresa pendiente'
                                      : widget.row.empresa,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6E47A8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(
                                  color: Color(0x44B084FF),
                                  height: 1,
                                ),
                                const SizedBox(height: 12),
                                _HrAttendanceInfoLine(
                                  label: 'Periodo',
                                  value: widget.periodLabel.isEmpty
                                      ? 'Sin periodo activo'
                                      : widget.periodLabel,
                                ),
                                _HrAttendanceInfoLine(
                                  label: 'Dias laboró',
                                  value: workedCount.toString(),
                                ),
                                _HrAttendanceInfoLine(
                                  label: 'Dias faltó',
                                  value: absentCount.toString(),
                                ),
                                _HrAttendanceInfoLine(
                                  label: 'Retardo',
                                  value: _formatAttendanceMinutesAsHourRatio(
                                    totalLateMinutes,
                                  ),
                                ),
                                _HrAttendanceInfoLine(
                                  label: 'Horas extra',
                                  value: _formatAttendanceMinutesAsHourRatio(
                                    totalExtraMinutes,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Jornadas',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF6E47A8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (widget.row.workSchedules.isEmpty)
                                  const Text(
                                    'No hay jornadas capturadas en Personal.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6E47A8),
                                    ),
                                  ),
                                if (widget.row.workSchedules.length > 1)
                                  _HrAttendanceScheduleSelectorTile(
                                    title: 'Automática',
                                    subtitle:
                                        'Usa la jornada detectada originalmente para cada día.',
                                    selected:
                                        _selectedWorkScheduleIndex == null,
                                    onTap: () => setState(() {
                                      _selectedWorkScheduleIndex = null;
                                      _applySelectedScheduleToDays();
                                    }),
                                  ),
                                if (widget.row.workSchedules.length > 1)
                                  const SizedBox(height: 8),
                                for (
                                  var scheduleIndex = 0;
                                  scheduleIndex <
                                      widget.row.workSchedules.length;
                                  scheduleIndex += 1
                                ) ...[
                                  _HrAttendanceScheduleSelectorTile(
                                    title: 'Jornada ${scheduleIndex + 1}',
                                    subtitle: _formatAttendanceScheduleOption(
                                      widget.row.workSchedules[scheduleIndex],
                                    ),
                                    selected:
                                        _selectedWorkScheduleIndex ==
                                        scheduleIndex,
                                    onTap: () => setState(() {
                                      _selectedWorkScheduleIndex =
                                          scheduleIndex;
                                      _applySelectedScheduleToDays();
                                    }),
                                  ),
                                  if (scheduleIndex !=
                                      widget.row.workSchedules.length - 1)
                                    const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _HrAttendanceSectionCard(
                              title: 'Resumen semanal',
                              subtitle:
                                  'Conteos y acumulados editables del cierre actual.',
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _HrAttendanceMetricMiniCard(
                                    label: 'DIAS LABORÓ',
                                    value: workedCount.toString(),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'DIAS FALTÓ',
                                    value: absentCount.toString(),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'RETARDO',
                                    value: _formatAttendanceMinutesAsHourRatio(
                                      totalLateMinutes,
                                    ),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'HORAS EXTRA',
                                    value: _formatAttendanceMinutesAsHourRatio(
                                      totalExtraMinutes,
                                    ),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'IMPORTADO',
                                    value: importedDays.toString(),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'MANUAL/AJUSTE',
                                    value: (manualDays + adjustedDays)
                                        .toString(),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'VACACIONES',
                                    value: vacationDays.toString(),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'PERMISOS',
                                    value: permissionDays.toString(),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'LISTO PRENÓMINA',
                                    value: readyDays.toString(),
                                  ),
                                  _HrAttendanceMetricMiniCard(
                                    label: 'REVISIÓN RH',
                                    value: reviewDays.toString(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _HrAttendanceSectionCard(
                                  title: 'Dias del periodo',
                                  subtitle:
                                      'Importaciones leidas por día con opcion de ajuste manual.',
                                  trailing: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _addManualDay,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Día'),
                                  ),
                                  child: _days.isEmpty
                                      ? Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            16,
                                            14,
                                            16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFF8F2FF,
                                            ).withValues(alpha: 0.92),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x44B084FF),
                                            ),
                                          ),
                                          child: const Text(
                                            'Todavía no hay días cargados. Puedes agregar uno manualmente.',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF7D62A8),
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            for (
                                              var index = 0;
                                              index < _days.length;
                                              index += 1
                                            ) ...[
                                              _HrAttendanceDayCard(
                                                draft: _days[index],
                                                onChanged: () =>
                                                    setState(() {}),
                                                onRemove: () => setState(
                                                  () => _days.removeAt(index),
                                                ),
                                              ),
                                              if (index != _days.length - 1)
                                                const SizedBox(height: 10),
                                            ],
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE4FF).withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x55B084FF)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _HrAttendanceInlineNote(
                          icon: Icons.info_outline_rounded,
                          message:
                              'Verifica la asistencia antes de guardar. Podras seguir ajustando el cierre despues.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.canGoPrevious) ...[
                        OutlinedButton.icon(
                          style: _hrAttendanceActionOutlinedButtonStyle(),
                          onPressed: () =>
                              _save(_HrAttendanceEditAction.previous),
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Anterior'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.canGoNext) ...[
                        OutlinedButton.icon(
                          style: _hrAttendanceActionOutlinedButtonStyle(),
                          onPressed: () => _save(_HrAttendanceEditAction.next),
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Siguiente'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton(
                        style: _hrAttendanceActionOutlinedButtonStyle(),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: _save,
                        child: const Text('Guardar asistencia'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HrAttendanceSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _HrAttendanceSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E9FF).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF24103D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6E47A8),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HrAttendanceMetricMiniCard extends StatelessWidget {
  final String label;
  final String value;

  const _HrAttendanceMetricMiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 144,
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x44B084FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6E47A8),
                letterSpacing: 0.35,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF24103D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _HrAttendanceInfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF24103D),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceDayCard extends StatelessWidget {
  final _HrAttendanceDayDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _HrAttendanceDayCard({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${draft.sourceDate} · ${draft.weekdayLabel}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF24103D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HrAttendanceDialogPill(
                          label: draft.sourceMode == 'importado'
                              ? 'Importado'
                              : draft.sourceMode == 'ajuste'
                              ? 'Ajuste'
                              : 'Manual',
                        ),
                        if (_attendanceDraftHasVacationSync(draft))
                          const _HrAttendanceDialogPill(label: 'Vacaciones RH'),
                        if (_attendanceDraftHasPermissionSync(draft))
                          const _HrAttendanceDialogPill(label: 'Permisos RH'),
                        _HrAttendanceDialogPill(
                          label: _attendanceDraftNeedsReview(draft)
                              ? 'Revisión RH'
                              : 'Listo prenómina',
                        ),
                        if (draft.punchTimeline.isNotEmpty)
                          _HrAttendanceDialogPill(
                            label: draft.punchTimeline.join(' · '),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (draft.sourceMode != 'importado')
                IconButton(
                  onPressed: onRemove,
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF6E47A8),
                    backgroundColor: const Color(0xFFF1E6FF),
                    side: const BorderSide(color: Color(0x44B084FF)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_attendanceDraftNeedsOperationalNote(draft)) ...[
            _HrAttendanceInlineNote(
              icon: Icons.info_outline_rounded,
              message: _attendanceDraftOperationalNote(draft),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: _HrAttendanceLabeledField(
                  label: 'Estatus',
                  child: _HrAttendancePickerField(
                    value: draft.status.label,
                    onTap: () async {
                      final value =
                          await showSearchablePickerDialog<_HrAttendanceStatus>(
                            context,
                            title: 'Estatus',
                            initialValue: draft.status,
                            options: _HrAttendanceStatus.values
                                .map(
                                  (status) => SearchablePickerOption(
                                    value: status,
                                    label: status.label,
                                  ),
                                )
                                .toList(growable: false),
                          );
                      if (value == null) return;
                      draft.status = value;
                      _recalculateAttendanceDraftMetrics(draft);
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: _HrAttendanceLabeledField(
                  label: 'Primer fichaje',
                  child: TextFormField(
                    initialValue: draft.firstPunch,
                    decoration: _hrAttendanceFieldDecoration(),
                    onChanged: (value) {
                      draft.firstPunch = value;
                      _recalculateAttendanceDraftMetrics(draft);
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: _HrAttendanceLabeledField(
                  label: 'Último fichaje',
                  child: TextFormField(
                    initialValue: draft.lastPunch,
                    decoration: _hrAttendanceFieldDecoration(),
                    onChanged: (value) {
                      draft.lastPunch = value;
                      _recalculateAttendanceDraftMetrics(draft);
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: _HrAttendanceLabeledField(
                  label: 'Retardo (hora)',
                  child: _HrAttendanceComputedField(
                    value: _formatAttendanceMinutesAsHourRatio(
                      draft.lateMinutes,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: _HrAttendanceLabeledField(
                  label: 'Horas extra (hora)',
                  child: _HrAttendanceComputedField(
                    value: _formatAttendanceMinutesAsHourRatio(
                      draft.overtimeMinutes,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HrAttendanceLabeledField(
            label: 'Notas RH',
            child: TextFormField(
              initialValue: draft.notes,
              decoration: _hrAttendanceFieldDecoration(),
              minLines: 2,
              maxLines: 4,
              onChanged: (value) => draft.notes = value,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceDialogPill extends StatelessWidget {
  final String label;

  const _HrAttendanceDialogPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8D9FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x66B084FF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF24103D),
        ),
      ),
    );
  }
}

class _HrAttendanceLabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _HrAttendanceLabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF6E47A8),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _HrAttendancePickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _HrAttendancePickerField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: _hrAttendanceFieldDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF24103D),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF6E47A8),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceComputedField extends StatelessWidget {
  final String value;

  const _HrAttendanceComputedField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55B084FF)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF24103D),
        ),
      ),
    );
  }
}

class _HrAttendanceScheduleSelectorTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _HrAttendanceScheduleSelectorTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE4D0FF) : const Color(0xFFF8F2FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF9F6BFF) : const Color(0x44B084FF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF24103D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6E47A8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceInlineNote extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HrAttendanceInlineNote({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6E47A8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E47A8),
            ),
          ),
        ),
      ],
    );
  }
}

class _HrAttendanceColumnFilterDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const _HrAttendanceColumnFilterDialog({
    required this.title,
    required this.initialValue,
  });

  @override
  State<_HrAttendanceColumnFilterDialog> createState() =>
      _HrAttendanceColumnFilterDialogState();
}

class _HrAttendanceColumnFilterDialogState
    extends State<_HrAttendanceColumnFilterDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          Navigator.of(context).pop(_controller.text);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: _hrAttendanceFilterDialogDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtro: ${widget.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Escribe un valor para filtrar esta columna dentro del grid de asistencia.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: _hrAttendanceFieldDecoration().copyWith(
                        hintText: 'Valor a buscar',
                      ),
                      onSubmitted: (_) =>
                          Navigator.of(context).pop(_controller.text),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: _hrAttendanceFilterOutlinedButtonStyle(),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: _hrAttendanceFilterOutlinedButtonStyle(),
                          onPressed: () => Navigator.of(context).pop(''),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: _hrAttendanceFilterFilledButtonStyle(),
                          onPressed: () =>
                              Navigator.of(context).pop(_controller.text),
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _hrAttendanceFilterDialogDecoration() {
  return BoxDecoration(
    color: const Color(0xEE1D112F),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.26),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

ButtonStyle _hrAttendanceFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFF1E7FF),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    backgroundColor: const Color(0xFF34204E).withValues(alpha: 0.72),
  );
}

ButtonStyle _hrAttendanceFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: humanResourcesAreaTokens.primary,
    foregroundColor: Colors.white,
  );
}

ButtonStyle _hrAttendanceActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF24103D),
    side: BorderSide(color: const Color(0xFFB68CFF).withValues(alpha: 0.42)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

InputDecoration _hrAttendanceFieldDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: const Color(0xFFB68CFF).withValues(alpha: 0.38),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: const Color(0xFFB68CFF).withValues(alpha: 0.38),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF9F6BFF)),
    ),
  );
}

enum _HrAttendanceImportSource {
  ngteco('NGTeco'),
  contpaq('CONTPAQ');

  final String label;
  const _HrAttendanceImportSource(this.label);
}

enum _HrAttendanceStatus {
  laboro('Laboró'),
  falto('Faltó'),
  noAplica('No aplica');

  final String label;
  const _HrAttendanceStatus(this.label);
}

class _HrAttendanceEmployeeMaster {
  final String employeeId;
  final String displayName;
  final String empresa;
  final String horario;
  final List<String> diasLabora;
  final List<_HrAttendanceWorkSchedule> workSchedules;
  final String fechaIngreso;
  final String salario;

  const _HrAttendanceEmployeeMaster({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.horario,
    required this.diasLabora,
    required this.workSchedules,
    required this.fechaIngreso,
    required this.salario,
  });
}

class _HrAttendanceWorkSchedule {
  final String horario;
  final List<String> diasLabora;

  const _HrAttendanceWorkSchedule({
    required this.horario,
    required this.diasLabora,
  });
}

class _HrAttendanceImportLotLite {
  final String id;
  final _HrAttendanceImportSource source;
  final String fileName;
  final DateTime importedAt;
  final String periodLabel;
  final List<_HrAttendanceImportedEntry> entries;

  const _HrAttendanceImportLotLite({
    required this.id,
    required this.source,
    required this.fileName,
    required this.importedAt,
    required this.periodLabel,
    required this.entries,
  });

  static _HrAttendanceImportLotLite fromRow(Map<String, dynamic> row) {
    final source = _HrAttendanceImportSource.values.firstWhere(
      (item) => item.name == (row['source'] ?? '').toString(),
      orElse: () => _HrAttendanceImportSource.ngteco,
    );
    return _HrAttendanceImportLotLite(
      id: (row['id'] ?? '').toString(),
      source: source,
      fileName: (row['file_name'] ?? '').toString(),
      importedAt:
          DateTime.tryParse((row['imported_at'] ?? '').toString()) ??
          DateTime.now(),
      periodLabel: (row['period_label'] ?? '').toString(),
      entries: ((row['entries'] as List?) ?? const <dynamic>[])
          .map((item) => _HrAttendanceImportedEntry.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class _HrAttendanceImportedEntry {
  final String employeeId;
  final String sourceName;
  final String detail;
  final String sourceDate;
  final String sourceTime;
  final String salary;
  final String net;

  const _HrAttendanceImportedEntry({
    required this.employeeId,
    required this.sourceName,
    this.detail = '',
    this.sourceDate = '',
    this.sourceTime = '',
    this.salary = '',
    this.net = '',
  });

  static _HrAttendanceImportedEntry fromJson(Map<String, dynamic> json) {
    return _HrAttendanceImportedEntry(
      employeeId: (json['employee_id'] ?? '').toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      sourceDate: (json['source_date'] ?? '').toString(),
      sourceTime: (json['source_time'] ?? '').toString(),
      salary: (json['salary'] ?? '').toString(),
      net: (json['net'] ?? '').toString(),
    );
  }
}

class _HrAttendanceStoredRecord {
  final String id;
  final String periodLabel;
  final String employeeId;
  final String employeeName;
  final String sourceDate;
  final String weekdayLabel;
  final _HrAttendanceStatus status;
  final String sourceMode;
  final String firstPunch;
  final String lastPunch;
  final List<String> punchTimeline;
  final int lateMinutes;
  final int overtimeMinutes;
  final String notes;

  const _HrAttendanceStoredRecord({
    required this.id,
    required this.periodLabel,
    required this.employeeId,
    required this.employeeName,
    required this.sourceDate,
    required this.weekdayLabel,
    required this.status,
    required this.sourceMode,
    required this.firstPunch,
    required this.lastPunch,
    required this.punchTimeline,
    required this.lateMinutes,
    required this.overtimeMinutes,
    required this.notes,
  });

  Map<String, dynamic> toRow() => {
    'period_label': periodLabel,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'source_date': sourceDate,
    'weekday_label': weekdayLabel,
    'status': status.name,
    'source_mode': sourceMode,
    'first_punch': firstPunch,
    'last_punch': lastPunch,
    'punch_timeline': punchTimeline,
    'late_minutes': lateMinutes,
    'overtime_minutes': overtimeMinutes,
    'notes': notes,
  };

  static _HrAttendanceStoredRecord fromRow(Map<String, dynamic> row) {
    return _HrAttendanceStoredRecord(
      id: (row['id'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      sourceDate: (row['source_date'] ?? '').toString(),
      weekdayLabel: (row['weekday_label'] ?? '').toString(),
      status: _HrAttendanceStatus.values.firstWhere(
        (item) => item.name == (row['status'] ?? '').toString(),
        orElse: () => _HrAttendanceStatus.noAplica,
      ),
      sourceMode: (row['source_mode'] ?? 'manual').toString(),
      firstPunch: (row['first_punch'] ?? '').toString(),
      lastPunch: (row['last_punch'] ?? '').toString(),
      punchTimeline: ((row['punch_timeline'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
      lateMinutes: _asInt(row['late_minutes']),
      overtimeMinutes: _asInt(row['overtime_minutes']),
      notes: (row['notes'] ?? '').toString(),
    );
  }
}

class _HrAttendanceDayRecord {
  final String sourceDate;
  final String weekdayLabel;
  final _HrAttendanceStatus status;
  final String sourceMode;
  final String scheduledStart;
  final String scheduledEnd;
  final int effectiveWorkMinutes;
  final String firstPunch;
  final String lastPunch;
  final List<String> punchTimeline;
  final int lateMinutes;
  final int overtimeMinutes;
  final String notes;

  const _HrAttendanceDayRecord({
    required this.sourceDate,
    required this.weekdayLabel,
    required this.status,
    required this.sourceMode,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.effectiveWorkMinutes,
    required this.firstPunch,
    required this.lastPunch,
    required this.punchTimeline,
    required this.lateMinutes,
    required this.overtimeMinutes,
    required this.notes,
  });

  _HrAttendanceDayDraft toDraft() {
    return _HrAttendanceDayDraft(
      localId: '${sourceDate}_$weekdayLabel',
      sourceDate: sourceDate,
      weekdayLabel: weekdayLabel,
      status: status,
      sourceMode: sourceMode,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      effectiveWorkMinutes: effectiveWorkMinutes,
      firstPunch: firstPunch,
      lastPunch: lastPunch,
      punchTimeline: List<String>.from(punchTimeline),
      lateMinutes: lateMinutes,
      overtimeMinutes: overtimeMinutes,
      notes: notes,
    );
  }
}

class _HrAttendanceSummaryRow {
  final String employeeId;
  final String displayName;
  final String empresa;
  final List<_HrAttendanceWorkSchedule> workSchedules;
  final int daysWorkedCount;
  final int daysAbsentCount;
  final int lateMinutesSum;
  final int overtimeMinutesSum;
  final List<_HrAttendanceDayRecord> days;

  const _HrAttendanceSummaryRow({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.workSchedules,
    required this.daysWorkedCount,
    required this.daysAbsentCount,
    required this.lateMinutesSum,
    required this.overtimeMinutesSum,
    required this.days,
  });
}

class _HrAttendanceDayDraft {
  final String localId;
  final String originalScheduledStart;
  final String originalScheduledEnd;
  final int originalEffectiveWorkMinutes;
  String sourceDate;
  String weekdayLabel;
  _HrAttendanceStatus status;
  String sourceMode;
  String scheduledStart;
  String scheduledEnd;
  int effectiveWorkMinutes;
  String firstPunch;
  String lastPunch;
  List<String> punchTimeline;
  int lateMinutes;
  int overtimeMinutes;
  String notes;

  _HrAttendanceDayDraft({
    required this.localId,
    String? originalScheduledStart,
    String? originalScheduledEnd,
    int? originalEffectiveWorkMinutes,
    required this.sourceDate,
    required this.weekdayLabel,
    required this.status,
    required this.sourceMode,
    this.scheduledStart = '',
    this.scheduledEnd = '',
    this.effectiveWorkMinutes = 0,
    this.firstPunch = '',
    this.lastPunch = '',
    this.punchTimeline = const <String>[],
    this.lateMinutes = 0,
    this.overtimeMinutes = 0,
    this.notes = '',
  }) : originalScheduledStart = originalScheduledStart ?? scheduledStart,
       originalScheduledEnd = originalScheduledEnd ?? scheduledEnd,
       originalEffectiveWorkMinutes =
           originalEffectiveWorkMinutes ?? effectiveWorkMinutes;
}

enum _HrAttendanceEditAction { save, previous, next }

class _HrAttendanceEditResult {
  final _HrAttendanceEditAction action;
  final List<_HrAttendanceDayDraft> days;

  const _HrAttendanceEditResult({required this.action, required this.days});
}

const List<_HrAttendanceGridColumn> _kAttendanceGridColumns =
    <_HrAttendanceGridColumn>[
      _HrAttendanceGridColumn(
        id: 'id',
        label: 'ID',
        width: _kHrAttendanceIdW,
        centered: true,
      ),
      _HrAttendanceGridColumn(
        id: 'nombre',
        label: 'Nombre',
        width: _kHrAttendanceNameW,
      ),
      _HrAttendanceGridColumn(
        id: 'dias_laboro',
        label: 'Días laboró',
        width: _kHrAttendanceWorkedW,
        centered: true,
      ),
      _HrAttendanceGridColumn(
        id: 'dias_falto',
        label: 'Días faltó',
        width: _kHrAttendanceAbsentW,
        centered: true,
      ),
      _HrAttendanceGridColumn(
        id: 'retardo',
        label: 'Retardo',
        width: _kHrAttendanceLateW,
        centered: true,
      ),
      _HrAttendanceGridColumn(
        id: 'extra',
        label: 'Horas extra',
        width: _kHrAttendanceExtraW,
        centered: true,
      ),
      _HrAttendanceGridColumn(
        id: 'acciones',
        label: 'Acciones',
        width: _kHrAttendanceActionsW,
        centered: true,
      ),
    ];

class _HrAttendanceGridColumn {
  final String id;
  final String label;
  final double width;
  final bool centered;

  const _HrAttendanceGridColumn({
    required this.id,
    required this.label,
    required this.width,
    this.centered = false,
  });
}

String _attendanceCellValueForColumn(
  _HrAttendanceSummaryRow row,
  String columnId,
) {
  switch (columnId) {
    case 'id':
      return row.employeeId;
    case 'nombre':
      return row.displayName;
    case 'dias_laboro':
      return row.daysWorkedCount.toString();
    case 'dias_falto':
      return row.daysAbsentCount.toString();
    case 'retardo':
      return _formatAttendanceMinutesAsHourRatio(row.lateMinutesSum);
    case 'extra':
      return _formatAttendanceMinutesAsHourRatio(row.overtimeMinutesSum);
    default:
      return '';
  }
}

_HrAttendanceImportLotLite? _latestLotBySource(
  List<_HrAttendanceImportLotLite> lots,
  _HrAttendanceImportSource source,
) {
  for (final lot in lots) {
    if (lot.source == source) return lot;
  }
  return null;
}

List<_HrAttendanceSummaryRow> _buildAttendanceSummaryRows({
  required List<_HrAttendanceEmployeeMaster> employees,
  required _HrAttendanceImportLotLite? ngtecoLot,
  required _HrAttendanceImportLotLite? contpaqLot,
  required List<_HrAttendanceStoredRecord> storedRecords,
  required String periodLabel,
}) {
  final periodRange = _resolveAttendanceActiveRange(
    ngtecoLot: ngtecoLot,
    contpaqLot: contpaqLot,
    activePeriodLabel: periodLabel,
  );
  final groupedPunches = ngtecoLot == null
      ? const <String, List<_HrAttendanceImportedEntry>>{}
      : _groupAttendanceEntriesByEmployeeDay(
          _filterAttendanceEntriesToRange(ngtecoLot.entries, periodRange),
        );
  final periodDates = _resolveAttendancePeriodDates(
    ngtecoLot: ngtecoLot,
    contpaqLot: contpaqLot,
    activePeriodLabel: periodLabel,
  );
  final storedByEmployeeDate = {
    for (final record in storedRecords.where(
      (item) =>
          item.periodLabel == periodLabel &&
          _isAttendanceDateWithinRange(item.sourceDate, periodRange),
    ))
      '${_normalizeAttendanceEmployeeId(record.employeeId)}|${record.sourceDate}':
          record,
  };

  final rows = <_HrAttendanceSummaryRow>[];
  for (final employee in employees) {
    final normalizedEmployeeId = _normalizeAttendanceEmployeeId(
      employee.employeeId,
    );
    final recordMap = <String, _HrAttendanceDayRecord>{};

    for (final date in periodDates) {
      final sourceDate = _fmtAttendanceDateLabel(date);
      final weekdayLabel = _hrWeekdayLabel(date.weekday);
      final groupedKey = _attendanceEmployeeDayKey(normalizedEmployeeId, date);
      final punches =
          groupedPunches[groupedKey] ?? const <_HrAttendanceImportedEntry>[];
      final importedDateTimes =
          punches
              .map(_parseAttendanceImportedDateTime)
              .whereType<DateTime>()
              .toList(growable: false)
            ..sort();
      final hasPunches = importedDateTimes.isNotEmpty;
      final resolvedSchedule = hasPunches
          ? _resolveAttendanceScheduleForPunch(
              schedules: employee.workSchedules,
              weekdayLabel: weekdayLabel,
              punchAt: importedDateTimes.first,
            )
          : _resolveAttendanceScheduleForPunchlessDay(
              schedules: employee.workSchedules,
              weekdayLabel: weekdayLabel,
            );
      final worksThatDay = resolvedSchedule?.worksThatDay ?? false;
      if (!hasPunches && !worksThatDay) continue;

      var lateMinutes = 0;
      var overtimeMinutes = 0;
      var firstPunch = '';
      var lastPunch = '';
      final punchTimeline = importedDateTimes
          .map(_fmtAttendanceTime)
          .toList(growable: false);
      if (hasPunches) {
        firstPunch = _fmtAttendanceTime(importedDateTimes.first);
        lastPunch = _fmtAttendanceTime(importedDateTimes.last);
        final schedule = resolvedSchedule?.schedule;
        if (schedule != null) {
          final scheduledStartAt = DateTime(
            importedDateTimes.first.year,
            importedDateTimes.first.month,
            importedDateTimes.first.day,
            schedule.start.hour,
            schedule.start.minute,
          );
          final scheduledEndAt = DateTime(
            importedDateTimes.last.year,
            importedDateTimes.last.month,
            importedDateTimes.last.day,
            schedule.end.hour,
            schedule.end.minute,
          );
          lateMinutes = importedDateTimes.first
              .difference(scheduledStartAt)
              .inMinutes;
          if (lateMinutes < 0) lateMinutes = 0;
          overtimeMinutes = _resolveOvertimeMinutes(
            scheduledEndAt: scheduledEndAt,
            lastPunchAt: importedDateTimes.last,
          );
        }
      }

      recordMap[sourceDate] = _HrAttendanceDayRecord(
        sourceDate: sourceDate,
        weekdayLabel: weekdayLabel,
        status: hasPunches
            ? _HrAttendanceStatus.laboro
            : _HrAttendanceStatus.falto,
        sourceMode: 'importado',
        scheduledStart: resolvedSchedule == null
            ? ''
            : _fmtTimeOfDay(resolvedSchedule.schedule.start),
        scheduledEnd: resolvedSchedule == null
            ? ''
            : _fmtTimeOfDay(resolvedSchedule.schedule.end),
        effectiveWorkMinutes: resolvedSchedule == null
            ? 0
            : _resolveAttendanceEffectiveWorkMinutes(resolvedSchedule.schedule),
        firstPunch: firstPunch,
        lastPunch: lastPunch,
        punchTimeline: punchTimeline,
        lateMinutes: lateMinutes,
        overtimeMinutes: overtimeMinutes,
        notes: '',
      );
    }

    for (final stored in storedByEmployeeDate.values.where(
      (item) =>
          _normalizeAttendanceEmployeeId(item.employeeId) ==
          normalizedEmployeeId,
    )) {
      final storedDate = _parseAttendanceDateLabel(stored.sourceDate);
      final storedWeekdayLabel = storedDate == null
          ? stored.weekdayLabel
          : _hrWeekdayLabel(storedDate.weekday);
      final storedPunchAt = _resolveAttendancePunchDateTime(
        sourceDate: stored.sourceDate,
        sourceTime: stored.firstPunch,
      );
      final storedSchedule = storedPunchAt != null
          ? _resolveAttendanceScheduleForPunch(
              schedules: employee.workSchedules,
              weekdayLabel: storedWeekdayLabel,
              punchAt: storedPunchAt,
            )
          : _resolveAttendanceScheduleForPunchlessDay(
              schedules: employee.workSchedules,
              weekdayLabel: storedWeekdayLabel,
            );
      recordMap[stored.sourceDate] = _HrAttendanceDayRecord(
        sourceDate: stored.sourceDate,
        weekdayLabel: stored.weekdayLabel,
        status: stored.status,
        sourceMode: stored.sourceMode,
        scheduledStart: storedSchedule == null
            ? ''
            : _fmtTimeOfDay(storedSchedule.schedule.start),
        scheduledEnd: storedSchedule == null
            ? ''
            : _fmtTimeOfDay(storedSchedule.schedule.end),
        effectiveWorkMinutes: storedSchedule == null
            ? 0
            : _resolveAttendanceEffectiveWorkMinutes(storedSchedule.schedule),
        firstPunch: stored.firstPunch,
        lastPunch: stored.lastPunch,
        punchTimeline: stored.punchTimeline,
        lateMinutes: stored.lateMinutes,
        overtimeMinutes: stored.overtimeMinutes,
        notes: stored.notes,
      );
    }

    final days = recordMap.values.toList(growable: false)
      ..sort((a, b) {
        final aDate = _parseAttendanceDateLabel(a.sourceDate);
        final bDate = _parseAttendanceDateLabel(b.sourceDate);
        if (aDate != null && bDate != null) return aDate.compareTo(bDate);
        return a.sourceDate.compareTo(b.sourceDate);
      });

    rows.add(
      _HrAttendanceSummaryRow(
        employeeId: employee.employeeId,
        displayName: employee.displayName,
        empresa: employee.empresa,
        workSchedules: employee.workSchedules,
        daysWorkedCount: days
            .where((day) => day.status == _HrAttendanceStatus.laboro)
            .length,
        daysAbsentCount: days
            .where((day) => day.status == _HrAttendanceStatus.falto)
            .length,
        lateMinutesSum: days.fold<int>(0, (sum, day) => sum + day.lateMinutes),
        overtimeMinutesSum: days.fold<int>(
          0,
          (sum, day) => sum + day.overtimeMinutes,
        ),
        days: days,
      ),
    );
  }

  rows.sort((a, b) {
    final aInt = int.tryParse(a.employeeId);
    final bInt = int.tryParse(b.employeeId);
    if (aInt != null && bInt != null) return aInt.compareTo(bInt);
    return a.employeeId.compareTo(b.employeeId);
  });
  return rows;
}

String _resolveActiveAttendancePeriodLabel({
  required _HrAttendanceImportLotLite? ngtecoLot,
  required _HrAttendanceImportLotLite? contpaqLot,
}) {
  if (contpaqLot != null && contpaqLot.periodLabel.trim().isNotEmpty) {
    return _describeImportPeriod(contpaqLot);
  }
  if (ngtecoLot != null && ngtecoLot.periodLabel.trim().isNotEmpty) {
    return _describeImportPeriod(ngtecoLot);
  }
  return '';
}

List<DateTime> _resolveAttendancePeriodDates({
  required _HrAttendanceImportLotLite? ngtecoLot,
  required _HrAttendanceImportLotLite? contpaqLot,
  required String activePeriodLabel,
}) {
  final activeRange = _resolveAttendanceActiveRange(
    ngtecoLot: ngtecoLot,
    contpaqLot: contpaqLot,
    activePeriodLabel: activePeriodLabel,
  );
  if (activeRange != null) {
    final dates = <DateTime>[];
    var cursor = DateTime(
      activeRange.start.year,
      activeRange.start.month,
      activeRange.start.day,
    );
    while (!cursor.isAfter(activeRange.end)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  final dates = <DateTime>{};
  if (ngtecoLot != null) {
    for (final entry in ngtecoLot.entries) {
      final parsed = _parseAttendanceImportedDateTime(entry);
      if (parsed != null) {
        dates.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }
  }
  final contpaqRange = _extractDateRangeFromPeriodLabel(
    contpaqLot?.periodLabel ?? '',
  );
  if (contpaqRange != null) {
    var cursor = DateTime(
      contpaqRange.start.year,
      contpaqRange.start.month,
      contpaqRange.start.day,
    );
    while (!cursor.isAfter(contpaqRange.end)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
  }
  final sorted = dates.toList(growable: false)..sort();
  return sorted;
}

DateTimeRange? _extractDateRangeFromPeriodLabel(String raw) {
  final match = RegExp(
    r'(?:del\s+)?(\d{2}/\d{2}/\d{4})\s+(?:al|-)\s+(\d{2}/\d{2}/\d{4})',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final start = _parseAttendanceDateLabel(match.group(1)!);
  final end = _parseAttendanceDateLabel(match.group(2)!);
  if (start == null || end == null) return null;
  return DateTimeRange(start: start, end: end);
}

DateTimeRange? _resolveAttendanceActiveRange({
  required _HrAttendanceImportLotLite? ngtecoLot,
  required _HrAttendanceImportLotLite? contpaqLot,
  required String activePeriodLabel,
}) {
  return _extractDateRangeFromPeriodLabel(activePeriodLabel) ??
      _extractDateRangeFromPeriodLabel(contpaqLot?.periodLabel ?? '') ??
      _extractDateRangeFromPeriodLabel(ngtecoLot?.periodLabel ?? '');
}

List<_HrAttendanceImportedEntry> _filterAttendanceEntriesToRange(
  List<_HrAttendanceImportedEntry> entries,
  DateTimeRange? range,
) {
  if (range == null) return entries;
  return entries
      .where((entry) {
        final parsed = _parseAttendanceImportedDateTime(entry);
        if (parsed == null) return false;
        final day = DateTime(parsed.year, parsed.month, parsed.day);
        return !day.isBefore(range.start) && !day.isAfter(range.end);
      })
      .toList(growable: false);
}

bool _isAttendanceDateWithinRange(String sourceDate, DateTimeRange? range) {
  if (range == null) return true;
  final parsed = _parseAttendanceDateLabel(sourceDate);
  if (parsed == null) return false;
  return !parsed.isBefore(range.start) && !parsed.isAfter(range.end);
}

List<String> _parseAttendanceWeekdays(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) return const <String>[];
  return raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<_HrAttendanceWorkSchedule> _parseAttendanceWorkSchedules(
  Object? value, {
  required String fallbackHorario,
  required List<String> fallbackDiasLabora,
}) {
  final parsed = <_HrAttendanceWorkSchedule>[];
  if (value is List) {
    for (final item in value) {
      final map = _asMap(item);
      final horario = (map['horario'] ?? '').toString().trim();
      final dias = _parseAttendanceWeekdays(map['dias_labora']);
      if (horario.isEmpty && dias.isEmpty) continue;
      parsed.add(_HrAttendanceWorkSchedule(horario: horario, diasLabora: dias));
    }
  }
  if (parsed.isNotEmpty) return parsed;
  if (fallbackHorario.trim().isEmpty && fallbackDiasLabora.isEmpty) {
    return const <_HrAttendanceWorkSchedule>[];
  }
  return <_HrAttendanceWorkSchedule>[
    _HrAttendanceWorkSchedule(
      horario: fallbackHorario,
      diasLabora: fallbackDiasLabora,
    ),
  ];
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

String _normalizeAttendanceEmployeeId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;
  final normalized = trimmed.replaceFirst(RegExp(r'^0+'), '');
  return normalized.isEmpty ? '0' : normalized;
}

DateTime? _parseAttendanceImportedDateTime(_HrAttendanceImportedEntry entry) {
  final date = entry.sourceDate.trim();
  final time = entry.sourceTime.trim();
  if (date.isEmpty || time.isEmpty) return null;
  final dateMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(date);
  final timeMatch = RegExp(
    r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(time);
  if (dateMatch == null || timeMatch == null) return null;
  final month = int.tryParse(dateMatch.group(1)!);
  final day = int.tryParse(dateMatch.group(2)!);
  final year = int.tryParse(dateMatch.group(3)!);
  final hour = int.tryParse(timeMatch.group(1)!);
  final minute = int.tryParse(timeMatch.group(2)!);
  final second = int.tryParse(timeMatch.group(3) ?? '0');
  if (month == null ||
      day == null ||
      year == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
}

Map<String, List<_HrAttendanceImportedEntry>>
_groupAttendanceEntriesByEmployeeDay(List<_HrAttendanceImportedEntry> entries) {
  final grouped = <String, List<_HrAttendanceImportedEntry>>{};
  for (final entry in entries) {
    final parsedDate = _parseAttendanceImportedDateTime(entry);
    if (parsedDate == null) continue;
    final key = _attendanceEmployeeDayKey(entry.employeeId, parsedDate);
    grouped.putIfAbsent(key, () => <_HrAttendanceImportedEntry>[]).add(entry);
  }
  return grouped;
}

String _attendanceEmployeeDayKey(String employeeId, DateTime date) {
  final normalizedEmployeeId = _normalizeAttendanceEmployeeId(employeeId);
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$normalizedEmployeeId|$year-$month-$day';
}

String _fmtAttendanceDateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

DateTime? _parseAttendanceDateLabel(String raw) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

DateTime? _parseUsImportDate(String raw) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
  if (match == null) return null;
  final month = int.tryParse(match.group(1)!);
  final day = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _fmtAttendanceTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime? _resolveAttendancePunchDateTime({
  required String sourceDate,
  required String sourceTime,
}) {
  final date = _parseAttendanceDateLabel(sourceDate);
  final time = _parseAttendanceTimeOfDay(sourceTime);
  if (date == null || time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _hrWeekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Lun';
    case DateTime.tuesday:
      return 'Mar';
    case DateTime.wednesday:
      return 'Mie';
    case DateTime.thursday:
      return 'Jue';
    case DateTime.friday:
      return 'Vie';
    case DateTime.saturday:
      return 'Sab';
    case DateTime.sunday:
      return 'Dom';
    default:
      return '';
  }
}

TimeOfDay? _parseAttendanceTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatAttendanceMinutesAsHourRatio(int minutes) {
  return '${(minutes / 60).toStringAsFixed(2)} h';
}

bool _attendanceNotesHaveVacationSync(String notes) {
  return notes.contains(_kHrAttendanceVacationSyncPrefix);
}

bool _attendanceNotesHavePermissionSync(String notes) {
  return notes.contains(_kHrAttendancePermissionSyncPrefix);
}

bool _attendanceDayIsImported(_HrAttendanceDayRecord day) =>
    day.sourceMode == 'importado';

bool _attendanceDayIsManual(_HrAttendanceDayRecord day) =>
    day.sourceMode == 'manual';

bool _attendanceDayIsAdjusted(_HrAttendanceDayRecord day) =>
    day.sourceMode == 'ajuste';

bool _attendanceDayHasVacationSync(_HrAttendanceDayRecord day) =>
    _attendanceNotesHaveVacationSync(day.notes);

bool _attendanceDayHasPermissionSync(_HrAttendanceDayRecord day) =>
    _attendanceNotesHavePermissionSync(day.notes);

bool _attendanceDayIsJustified(_HrAttendanceDayRecord day) =>
    _attendanceDayHasVacationSync(day) || _attendanceDayHasPermissionSync(day);

bool _attendanceDayNeedsReview(_HrAttendanceDayRecord day) {
  if (_attendanceDayIsJustified(day)) return false;
  if (day.status == _HrAttendanceStatus.falto) return true;
  if (day.status == _HrAttendanceStatus.noAplica &&
      day.firstPunch.trim().isEmpty &&
      day.lastPunch.trim().isEmpty &&
      day.notes.trim().isEmpty) {
    return true;
  }
  return false;
}

bool _attendanceDayIsReadyForPrenomina(_HrAttendanceDayRecord day) =>
    !_attendanceDayNeedsReview(day);

bool _attendanceDraftIsImported(_HrAttendanceDayDraft day) =>
    day.sourceMode == 'importado';

bool _attendanceDraftIsManual(_HrAttendanceDayDraft day) =>
    day.sourceMode == 'manual';

bool _attendanceDraftIsAdjusted(_HrAttendanceDayDraft day) =>
    day.sourceMode == 'ajuste';

bool _attendanceDraftHasVacationSync(_HrAttendanceDayDraft day) =>
    _attendanceNotesHaveVacationSync(day.notes);

bool _attendanceDraftHasPermissionSync(_HrAttendanceDayDraft day) =>
    _attendanceNotesHavePermissionSync(day.notes);

bool _attendanceDraftIsJustified(_HrAttendanceDayDraft day) =>
    _attendanceDraftHasVacationSync(day) ||
    _attendanceDraftHasPermissionSync(day);

bool _attendanceDraftNeedsReview(_HrAttendanceDayDraft day) {
  if (_attendanceDraftIsJustified(day)) return false;
  if (day.status == _HrAttendanceStatus.falto) return true;
  if (day.status == _HrAttendanceStatus.noAplica &&
      day.firstPunch.trim().isEmpty &&
      day.lastPunch.trim().isEmpty &&
      day.notes.trim().isEmpty) {
    return true;
  }
  return false;
}

bool _attendanceDraftIsReadyForPrenomina(_HrAttendanceDayDraft day) =>
    !_attendanceDraftNeedsReview(day);

bool _attendanceDraftNeedsOperationalNote(_HrAttendanceDayDraft day) =>
    _attendanceDraftHasVacationSync(day) ||
    _attendanceDraftHasPermissionSync(day) ||
    _attendanceDraftNeedsReview(day);

String _attendanceDraftOperationalNote(_HrAttendanceDayDraft day) {
  if (_attendanceDraftHasVacationSync(day)) {
    return 'Este día quedó justificado desde Vacaciones RH y ya puede considerarse dentro del cierre operativo semanal.';
  }
  if (_attendanceDraftHasPermissionSync(day)) {
    return 'Este día quedó justificado desde Permisos RH y mantiene trazabilidad administrativa para el cierre semanal.';
  }
  return 'Este día todavía requiere revisión RH antes de considerarse listo para prenómina.';
}

String _attendanceRowOperationalSubtitle(_HrAttendanceSummaryRow row) {
  final imported = row.days.where(_attendanceDayIsImported).length;
  final edited =
      row.days.where(_attendanceDayIsManual).length +
      row.days.where(_attendanceDayIsAdjusted).length;
  final vacations = row.days.where(_attendanceDayHasVacationSync).length;
  final permissions = row.days.where(_attendanceDayHasPermissionSync).length;
  final review = row.days.where(_attendanceDayNeedsReview).length;
  final parts = <String>[];
  if (imported > 0) parts.add('Imp $imported');
  if (edited > 0) parts.add('Ed $edited');
  if (vacations > 0) parts.add('Vac $vacations');
  if (permissions > 0) parts.add('Perm $permissions');
  parts.add(review > 0 ? 'Rev $review' : 'Listo prenómina');
  return parts.join(' · ');
}

Color _attendanceRowOperationalColor(_HrAttendanceSummaryRow row) {
  final review = row.days.where(_attendanceDayNeedsReview).length;
  if (review > 0) return const Color(0xFF8A4B00);
  if (row.days.any(_attendanceDayIsJustified)) {
    return const Color(0xFF6E47A8);
  }
  return const Color(0xFF6E47A8);
}

String _formatAttendanceScheduleOption(_HrAttendanceWorkSchedule schedule) {
  final dias = schedule.diasLabora.isEmpty
      ? 'Días por definir'
      : schedule.diasLabora.join(', ');
  final horario = schedule.horario.trim().isEmpty
      ? 'Horario por definir'
      : schedule.horario.trim();
  return '$dias · $horario';
}

void _recalculateAttendanceDraftMetrics(_HrAttendanceDayDraft draft) {
  if (draft.status != _HrAttendanceStatus.laboro ||
      draft.scheduledStart.trim().isEmpty ||
      draft.scheduledEnd.trim().isEmpty) {
    draft.lateMinutes = 0;
    draft.overtimeMinutes = 0;
    return;
  }
  final firstPunchAt = _resolveAttendancePunchDateTime(
    sourceDate: draft.sourceDate,
    sourceTime: draft.firstPunch,
  );
  final lastPunchAt = _resolveAttendancePunchDateTime(
    sourceDate: draft.sourceDate,
    sourceTime: draft.lastPunch,
  );
  final scheduledStartAt = _resolveAttendancePunchDateTime(
    sourceDate: draft.sourceDate,
    sourceTime: draft.scheduledStart,
  );
  final scheduledEndAt = _resolveAttendancePunchDateTime(
    sourceDate: draft.sourceDate,
    sourceTime: draft.scheduledEnd,
  );
  if (firstPunchAt == null ||
      lastPunchAt == null ||
      scheduledStartAt == null ||
      scheduledEndAt == null) {
    draft.lateMinutes = 0;
    draft.overtimeMinutes = 0;
    return;
  }
  final lateMinutes = firstPunchAt.difference(scheduledStartAt).inMinutes;
  draft.lateMinutes = lateMinutes > 0 ? lateMinutes : 0;
  draft.overtimeMinutes = _resolveOvertimeMinutes(
    scheduledEndAt: scheduledEndAt,
    lastPunchAt: lastPunchAt,
  );
}

String _fmtTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _HrAttendanceScheduleDraft {
  final TimeOfDay start;
  final TimeOfDay end;
  final TimeOfDay? lunchStart;
  final TimeOfDay? lunchEnd;

  const _HrAttendanceScheduleDraft({
    required this.start,
    required this.end,
    this.lunchStart,
    this.lunchEnd,
  });
}

_HrAttendanceScheduleDraft? _parseAttendanceSchedule(String? raw) {
  final normalized = (raw ?? '').trim();
  final pattern = RegExp(
    r'^(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})(?:\s*\|\s*comida\s*(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}))?$',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(normalized);
  if (match == null) return null;
  final start = _parseAttendanceTimeOfDay(match.group(1));
  final end = _parseAttendanceTimeOfDay(match.group(2));
  if (start == null || end == null) return null;
  return _HrAttendanceScheduleDraft(
    start: start,
    end: end,
    lunchStart: _parseAttendanceTimeOfDay(match.group(3)),
    lunchEnd: _parseAttendanceTimeOfDay(match.group(4)),
  );
}

class _HrResolvedAttendanceSchedule {
  final _HrAttendanceScheduleDraft schedule;
  final bool worksThatDay;

  const _HrResolvedAttendanceSchedule({
    required this.schedule,
    required this.worksThatDay,
  });
}

_HrResolvedAttendanceSchedule? _resolveAttendanceScheduleForPunch({
  required List<_HrAttendanceWorkSchedule> schedules,
  required String weekdayLabel,
  required DateTime punchAt,
}) {
  if (schedules.isEmpty) return null;
  final candidates = <Map<String, Object?>>[];
  for (final item in schedules) {
    final parsed = _parseAttendanceSchedule(item.horario);
    if (parsed == null) continue;
    final startAt = DateTime(
      punchAt.year,
      punchAt.month,
      punchAt.day,
      parsed.start.hour,
      parsed.start.minute,
    );
    final diffMinutes = punchAt.difference(startAt).inMinutes.abs();
    final worksThatDay = item.diasLabora.contains(weekdayLabel);
    final hasWorkdays = item.diasLabora.isNotEmpty;
    final score = worksThatDay
        ? diffMinutes
        : hasWorkdays
        ? 10000 + diffMinutes
        : 5000 + diffMinutes;
    candidates.add({'score': score, 'schedule': parsed, 'works': worksThatDay});
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => (a['score'] as int).compareTo(b['score'] as int));
  return _HrResolvedAttendanceSchedule(
    schedule: candidates.first['schedule'] as _HrAttendanceScheduleDraft,
    worksThatDay: (candidates.first['works'] as bool?) ?? false,
  );
}

_HrResolvedAttendanceSchedule? _resolveAttendanceScheduleForPunchlessDay({
  required List<_HrAttendanceWorkSchedule> schedules,
  required String weekdayLabel,
}) {
  if (schedules.isEmpty) return null;
  for (final item in schedules) {
    final parsed = _parseAttendanceSchedule(item.horario);
    if (parsed == null) continue;
    final worksThatDay = item.diasLabora.contains(weekdayLabel);
    if (!worksThatDay) continue;
    return _HrResolvedAttendanceSchedule(schedule: parsed, worksThatDay: true);
  }
  return null;
}

int _resolveOvertimeMinutes({
  required DateTime scheduledEndAt,
  required DateTime lastPunchAt,
}) {
  final diff = lastPunchAt.difference(scheduledEndAt).inMinutes;
  return diff > 0 ? diff : 0;
}

int _resolveAttendanceEffectiveWorkMinutes(
  _HrAttendanceScheduleDraft schedule,
) {
  final startMinutes = schedule.start.hour * 60 + schedule.start.minute;
  final endMinutes = schedule.end.hour * 60 + schedule.end.minute;
  var totalMinutes = endMinutes - startMinutes;
  if (schedule.lunchStart != null && schedule.lunchEnd != null) {
    final lunchStartMinutes =
        schedule.lunchStart!.hour * 60 + schedule.lunchStart!.minute;
    final lunchEndMinutes =
        schedule.lunchEnd!.hour * 60 + schedule.lunchEnd!.minute;
    totalMinutes -= lunchEndMinutes - lunchStartMinutes;
  }
  return totalMinutes > 0 ? totalMinutes : 0;
}

String _describeImportPeriod(_HrAttendanceImportLotLite lot) {
  final raw = lot.periodLabel.trim();
  if (raw.isEmpty) return 'Periodo no detectado';
  if (lot.source == _HrAttendanceImportSource.ngteco) {
    final segments = raw.split('→').map((part) => part.trim()).toList();
    if (segments.length == 2) {
      final first = _parseUsImportDate(segments[0]);
      final second = _parseUsImportDate(segments[1]);
      if (first != null && second != null) {
        final ordered = [first, second]..sort();
        return '${_fmtAttendanceDateLabel(ordered.first)} - ${_fmtAttendanceDateLabel(ordered.last)}';
      }
    }
    return raw;
  }

  final periodMatch = RegExp(
    r'Periodo\s+(\d+)\s+al\s+\d+\s+Semanal\s+del\s+(\d{2}/\d{2}/\d{4})\s+al\s+(\d{2}/\d{2}/\d{4})(?:\s+·\s+Hora:\s+(\d{2}:\d{2}:\d{2}))?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (periodMatch != null) {
    final week = periodMatch.group(1)!;
    final start = periodMatch.group(2)!;
    final end = periodMatch.group(3)!;
    final time = periodMatch.group(4);
    return time == null
        ? 'Periodo $week semanal · $start - $end'
        : 'Periodo $week semanal · $start - $end · Archivo $time';
  }
  return raw;
}
