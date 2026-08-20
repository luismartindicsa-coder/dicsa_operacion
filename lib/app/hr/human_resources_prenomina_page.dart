import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_dialog.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_state.dart';
import '../shared/archetypes/grid_editable/grid_editable_shell.dart';
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
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

const String _kHrPrenominaProfilesTable = 'hr_employee_profiles';
const String _kHrPrenominaImportLotsTable = 'hr_attendance_import_lots';
const String _kHrPrenominaAttendanceDailyRecordsTable =
    'hr_attendance_daily_records';
const String _kHrPrenominaVacationEventsTable = 'hr_employee_vacation_events';
const String _kHrPrenominaPermissionEventsTable =
    'hr_employee_permission_events';
const String _kHrPrenominaDraftRowsTable = 'hr_prenomina_draft_rows';

const String _kHrPrenominaVacationSyncPrefix = 'Vacaciones RH:';
const String _kHrPrenominaPermissionSyncPrefix = 'Permisos RH:';
const String _kHrPrenominaContpaqReceiptPrefix = 'contpaq:';

const double _kHrPrenominaIdW = 84;
const double _kHrPrenominaSalaryW = 154;
const double _kHrPrenominaAttendanceW = 170;
const double _kHrPrenominaVacationW = 170;
const double _kHrPrenominaPermissionW = 170;
const double _kHrPrenominaStatusW = 150;
const double _kHrPrenominaActionsW = 118;

class HumanResourcesPrenominaPage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesPrenominaPage({super.key, this.instantOpen = false});

  @override
  State<HumanResourcesPrenominaPage> createState() =>
      _HumanResourcesPrenominaPageState();
}

enum _HrPrenominaRowAction { open }

class _HumanResourcesPrenominaPageState
    extends State<HumanResourcesPrenominaPage> {
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

  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'hrPrenominaRows');
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

  List<_HrPrenominaEmployeeMaster> _employees =
      const <_HrPrenominaEmployeeMaster>[];
  List<_HrPrenominaImportLotLite> _importLots =
      const <_HrPrenominaImportLotLite>[];
  List<_HrPrenominaAttendanceRecord> _attendanceRecords =
      const <_HrPrenominaAttendanceRecord>[];
  List<_HrPrenominaVacationEventRecord> _vacationEvents =
      const <_HrPrenominaVacationEventRecord>[];
  List<_HrPrenominaPermissionEventRecord> _permissionEvents =
      const <_HrPrenominaPermissionEventRecord>[];
  List<_HrPrenominaDraftRowRecord> _draftRows =
      const <_HrPrenominaDraftRowRecord>[];
  List<_HrPrenominaSummaryRow> _allRows = const <_HrPrenominaSummaryRow>[];
  List<_HrPrenominaSummaryRow> _visibleRows = const <_HrPrenominaSummaryRow>[];

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
            .from(_kHrPrenominaProfilesTable)
            .select(
              'id,nombre,empresa,fecha_ingreso,fecha_alta,salario,salario_real_percibido',
            )
            .order('id')
            .range(from, to),
      );
      final importLotsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrPrenominaImportLotsTable)
            .select('id,source,file_name,imported_at,period_label,entries')
            .order('imported_at', ascending: false)
            .range(from, to),
      );
      List<dynamic> attendanceResult = const <dynamic>[];
      List<dynamic> vacationEventsResult = const <dynamic>[];
      List<dynamic> permissionEventsResult = const <dynamic>[];
      List<dynamic> draftRowsResult = const <dynamic>[];
      try {
        attendanceResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrPrenominaAttendanceDailyRecordsTable)
              .select()
              .order('source_date')
              .range(from, to),
        );
      } catch (_) {}
      try {
        vacationEventsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrPrenominaVacationEventsTable)
              .select()
              .order('start_date')
              .range(from, to),
        );
      } catch (_) {}
      try {
        permissionEventsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrPrenominaPermissionEventsTable)
              .select()
              .order('start_date')
              .range(from, to),
        );
      } catch (_) {}
      try {
        draftRowsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrPrenominaDraftRowsTable)
              .select()
              .order('employee_name')
              .range(from, to),
        );
      } catch (_) {}

      final employees =
          employeesResult
              .map((raw) => Map<String, dynamic>.from(raw))
              .map(_HrPrenominaEmployeeMaster.fromRow)
              .where((row) => row.employeeId.trim().isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) {
              final aInt = int.tryParse(a.employeeId);
              final bInt = int.tryParse(b.employeeId);
              if (aInt != null && bInt != null) return aInt.compareTo(bInt);
              return a.employeeId.compareTo(b.employeeId);
            });

      final importLots = importLotsResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrPrenominaImportLotLite.fromRow)
          .toList(growable: false);

      if (!mounted) return;
      _employees = employees;
      _importLots = importLots;
      _attendanceRecords = attendanceResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaAttendanceRecord.fromRow)
          .toList(growable: false);
      _vacationEvents = vacationEventsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaVacationEventRecord.fromRow)
          .toList(growable: false);
      _permissionEvents = permissionEventsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaPermissionEventRecord.fromRow)
          .toList(growable: false);
      _draftRows = draftRowsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaDraftRowRecord.fromRow)
          .toList(growable: false);
      _rebuildRows();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _rebuildRows() {
    final ngtecoLot = _latestPrenominaLotBySource(
      _importLots,
      _HrPrenominaImportSource.ngteco,
    );
    final contpaqLot = _latestPrenominaLotBySource(
      _importLots,
      _HrPrenominaImportSource.contpaq,
    );
    final periodLabel = _resolveActivePrenominaPeriodLabel(
      ngtecoLot: ngtecoLot,
      contpaqLot: contpaqLot,
    );
    final rows = _buildPrenominaSummaryRows(
      employees: _employees,
      contpaqLot: contpaqLot,
      attendanceRecords: _attendanceRecords,
      vacationEvents: _vacationEvents,
      permissionEvents: _permissionEvents,
      draftRows: _draftRows,
      activePeriodLabel: periodLabel,
      activeContpaqRawPeriodLabel: contpaqLot?.periodLabel.trim() ?? '',
    );
    final filteredRows = _applyFilters(rows);
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
      gridColumnCount: _kPrenominaGridColumns.length,
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

  List<_HrPrenominaSummaryRow> _applyFilters(
    List<_HrPrenominaSummaryRow> rows,
  ) {
    if (_columnFilters.isEmpty) return rows;
    return rows
        .where((row) {
          for (final entry in _columnFilters.entries) {
            if (entry.value.isEmpty) continue;
            final value = _prenominaCellValueForColumn(row, entry.key);
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

  Future<void> _openAttendance() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesAttendancePage(instantOpen: true)),
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

  Future<void> _openDirectionDashboard() async {
    await Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const GeneralDashboardPage()));
  }

  Future<void> _openNomina() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesNominaPage(instantOpen: true)),
    );
  }

  Future<void> _logout() async => signOutAndRouteToLogin(context);

  Future<void> _openSummaryRow(_HrPrenominaSummaryRow row) async {
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
      final result = await showDialog<_HrPrenominaEditResult>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _HrPrenominaEditDialog(
          row: row,
          periodLabel: _activePeriodLabel,
          canGoPrevious: currentIndex > 0,
          canGoNext: currentIndex < _allRows.length - 1,
        ),
      );
      if (result == null) return;
      await _saveDraftRow(row: row, result: result);
      switch (result.action) {
        case _HrPrenominaEditAction.save:
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrPrenominaEditAction.previous:
          if (currentIndex > 0) {
            currentIndex -= 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrPrenominaEditAction.next:
          if (currentIndex < _allRows.length - 1) {
            currentIndex += 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
      }
    }
  }

  Future<void> _saveDraftRow({
    required _HrPrenominaSummaryRow row,
    required _HrPrenominaEditResult result,
  }) async {
    final client = Supabase.instance.client;
    final payload = result.draft.toRow(
      periodLabel: _activePeriodLabel,
      employeeId: row.employeeId,
      employeeName: row.displayName,
      empresa: row.empresa,
      existingId: row.draftId,
    );
    await client
        .from(_kHrPrenominaDraftRowsTable)
        .upsert(payload, onConflict: 'period_label,employee_id');

    final refreshedResult = await client
        .from(_kHrPrenominaDraftRowsTable)
        .select()
        .eq('period_label', _activePeriodLabel)
        .eq('employee_id', row.employeeId)
        .limit(1);
    final refreshed = (refreshedResult as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .map(_HrPrenominaDraftRowRecord.fromRow)
        .toList(growable: false);
    _draftRows = [
      for (final item in _draftRows)
        if (!(item.periodLabel == _activePeriodLabel &&
            item.employeeId == row.employeeId))
          item,
      ...refreshed,
    ];
    _rebuildRows();
    _showSnack('Borrador de prenómina de ${row.displayName} actualizado.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  _HrPrenominaSummaryRow? _activeRow() {
    if (_selectedRowId == null) return null;
    for (final row in _allRows) {
      if (row.employeeId == _selectedRowId) return row;
    }
    return null;
  }

  void _handleTapRow(_HrPrenominaSummaryRow row, int rowIndex) {
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
    _HrPrenominaSummaryRow row,
    int rowIndex,
  ) async {
    _prepareRowSelectionForActions(rowId: row.employeeId, rowIndex: rowIndex);
    final selected = await showContractContextMenu<_HrPrenominaRowAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      entries: const [
        ContractMenuEntry(
          value: _HrPrenominaRowAction.open,
          label: 'Editar borrador',
          icon: Icons.payments_outlined,
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
            .map((row) => _prenominaCellValueForColumn(row, columnId))
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
        centerBuilder: (_, _) => const _HrPrenominaHeaderBrand(),
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
                      : _HrPrenominaWorkspace(
                          allRows: _allRows,
                          rows: _visibleRows,
                          totalRows: _allRows.length,
                          selectedCount:
                              _selectionController.selectedIds.length,
                          activePeriodLabel: _activePeriodLabel,
                          hoveredRowId: _hoveredRowId,
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
                              _prepareRowSelectionForActionsFromRow,
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
                activeScreen: HumanResourcesAreaScreen.prenomina,
                openPersonnel: _openPersonnel,
                openAttendance: _openAttendance,
                openImportConciliation: _openImportConciliation,
                openVacations: _openVacations,
                openPermissions: _openPermissions,
                openPrenomina: () async {},
                openNomina: _openNomina,
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.prenomina,
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

  void _prepareRowSelectionForActionsFromRow(
    _HrPrenominaSummaryRow row,
    int rowIndex,
  ) {
    _prepareRowSelectionForActions(rowId: row.employeeId, rowIndex: rowIndex);
  }
}

class _HrPrenominaWorkspace extends StatelessWidget {
  final List<_HrPrenominaSummaryRow> allRows;
  final List<_HrPrenominaSummaryRow> rows;
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
  final void Function(_HrPrenominaSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrPrenominaSummaryRow row, int rowIndex)
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
    _HrPrenominaSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final Future<void> Function(_HrPrenominaSummaryRow row) onOpenRow;
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

  const _HrPrenominaWorkspace({
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
        ? _kPrenominaGridColumns[active.columnIndex.clamp(
                0,
                _kPrenominaGridColumns.length - 1,
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
            topBar: _HrPrenominaModuleTopBar(
              rows: allRows,
              totalRows: totalRows,
              selectedCount: selectedCount,
              activeCellLabel: activeLabel == null
                  ? null
                  : 'Celda: $activeLabel',
              activePeriodLabel: activePeriodLabel,
              onOpenSelectedRow: () => unawaited(onOpenSelectedRow()),
            ),
            body: _HrPrenominaGrid(
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
            footer: _HrPrenominaGridFooter(
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

class _HrPrenominaGrid extends StatelessWidget {
  final List<_HrPrenominaSummaryRow> rows;
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
  final void Function(_HrPrenominaSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrPrenominaSummaryRow row, int rowIndex)
  onPrepareRowActions;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(_HrPrenominaSummaryRow row) onOpenRow;
  final Future<void> Function(
    TapDownDetails details,
    _HrPrenominaSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final ValueChanged<String?> onHoverRowChanged;

  const _HrPrenominaGrid({
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
    required this.onPrepareRowActions,
    required this.onBeginDragSelection,
    required this.onUpdateDragSelection,
    required this.onEndDragSelection,
    required this.onOpenRow,
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
                  _HrPrenominaGridHeader(
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
                                  const _HrPrenominaEmptyState()
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
                                        child: _HrPrenominaGridRow(
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

class _HrPrenominaEmptyState extends StatelessWidget {
  const _HrPrenominaEmptyState();

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
          border: Border.all(color: const Color(0x66B68CFF)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.payments_outlined,
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
              'Ajusta filtros o consolida fuentes RH para comenzar el borrador semanal de prenómina.',
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

class _HrPrenominaGridHeader extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;

  const _HrPrenominaGridHeader({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: _kHrPrenominaIdW,
              child: _HrPrenominaHeaderText(
                'ID',
                style: style,
                active: hasActiveFilter('id'),
                onFilter: () => onOpenFilter('id', 'ID'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HrPrenominaHeaderText(
                'NOMBRE',
                style: style,
                active: hasActiveFilter('nombre'),
                onFilter: () => onOpenFilter('nombre', 'Nombre'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPrenominaSalaryW,
              child: _HrPrenominaHeaderText(
                'SUELDO',
                style: style,
                centered: true,
                active: hasActiveFilter('sueldo'),
                onFilter: () => onOpenFilter('sueldo', 'Sueldo'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPrenominaAttendanceW,
              child: _HrPrenominaHeaderText(
                'ASISTENCIA',
                style: style,
                centered: true,
                active: hasActiveFilter('asistencia'),
                onFilter: () => onOpenFilter('asistencia', 'Asistencia'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPrenominaVacationW,
              child: _HrPrenominaHeaderText(
                'VACACIONES',
                style: style,
                centered: true,
                active: hasActiveFilter('vacaciones'),
                onFilter: () => onOpenFilter('vacaciones', 'Vacaciones'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPrenominaPermissionW,
              child: _HrPrenominaHeaderText(
                'PERMISOS',
                style: style,
                centered: true,
                active: hasActiveFilter('permisos'),
                onFilter: () => onOpenFilter('permisos', 'Permisos'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPrenominaStatusW,
              child: _HrPrenominaHeaderText(
                'ESTADO',
                style: style,
                centered: true,
                active: hasActiveFilter('estado'),
                onFilter: () => onOpenFilter('estado', 'Estado'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPrenominaActionsW,
              child: const _HrPrenominaHeaderText(
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

class _HrPrenominaHeaderText extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool centered;
  final bool active;
  final VoidCallback? onFilter;

  const _HrPrenominaHeaderText(
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

class _HrPrenominaCellSummary extends StatelessWidget {
  final String primary;
  final String secondary;
  final TextAlign align;

  const _HrPrenominaCellSummary({
    required this.primary,
    required this.secondary,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.8,
            fontWeight: FontWeight.w900,
            color: Color(0xFF24103D),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          secondary,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9.9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6E47A8),
          ),
        ),
      ],
    );
  }
}

class _HrPrenominaGridRow extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
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

  const _HrPrenominaGridRow({
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
                        width: _kHrPrenominaIdW,
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
                              row.empresa.isEmpty
                                  ? 'Empresa pendiente'
                                  : row.empresa,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6E47A8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPrenominaSalaryW,
                        child: _HrPrenominaCellSummary(
                          primary: _formatPrenominaMoney(row.salaryWeekly),
                          secondary: row.weeklyPaymentVisibleAmount > 0
                              ? 'Semana ${_formatPrenominaMoneyZero(row.weeklyPaymentVisibleAmount)}'
                              : 'Borrador ${_formatPrenominaMoneyZero(row.preliminarySubtotalAmount)}',
                          align: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPrenominaAttendanceW,
                        child: _HrPrenominaCellSummary(
                          primary: row.attendanceSummaryPrimary,
                          secondary: row.attendanceSummarySecondary,
                          align: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPrenominaVacationW,
                        child: _HrPrenominaCellSummary(
                          primary: row.vacationSummaryPrimary,
                          secondary: row.vacationSummarySecondary,
                          align: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPrenominaPermissionW,
                        child: _HrPrenominaCellSummary(
                          primary: row.permissionSummaryPrimary,
                          secondary: row.permissionSummarySecondary,
                          align: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPrenominaStatusW,
                        child: Center(
                          child: _HrPrenominaStatusBadge(
                            label: row.statusLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPrenominaActionsW,
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
                            ),
                            child:
                                EditableRowActionsButton<_HrPrenominaRowAction>(
                                  tooltip: 'Acciones de prenómina',
                                  iconColor: hasSelection
                                      ? Colors.white
                                      : const Color(0xFF6E47A8),
                                  onBeforeOpen: onPrepareActionsMenu,
                                  entries: const [
                                    ContractMenuEntry(
                                      value: _HrPrenominaRowAction.open,
                                      label: 'Editar borrador',
                                      icon: Icons.payments_outlined,
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

class _HrPrenominaModuleTopBar extends StatelessWidget {
  final List<_HrPrenominaSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final String? activeCellLabel;
  final String activePeriodLabel;
  final VoidCallback onOpenSelectedRow;

  const _HrPrenominaModuleTopBar({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activeCellLabel,
    required this.activePeriodLabel,
    required this.onOpenSelectedRow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prenómina',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Consolidado semanal previo a nómina final y validación RH.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xD9D9C7FF),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB794FF),
                foregroundColor: const Color(0xFF24103D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: totalRows == 0 ? null : onOpenSelectedRow,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Editar borrador'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF4ECFF).withValues(alpha: 0.60),
                const Color(0xFFE8D8FF).withValues(alpha: 0.42),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x44C7A7FF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF130B22).withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activePeriodLabel.isEmpty
                    ? 'Sin periodo operativo activo'
                    : activePeriodLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24103D),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _HrPrenominaTopMetaPill(
                    label: 'Colaboradores',
                    value: '$totalRows',
                  ),
                  _HrPrenominaTopMetaPill(
                    label: 'Selección',
                    value: '$selectedCount',
                  ),
                  if (activeCellLabel != null)
                    _HrPrenominaTopMetaPill(
                      label: 'Celda',
                      value: activeCellLabel!.replaceFirst('Celda: ', ''),
                    ),
                  const _HrPrenominaTopMetaPill(
                    label: 'Estado',
                    value: 'Borrador semanal',
                  ),
                  const _HrPrenominaSoftPill(label: 'Fuente: RH'),
                ],
              ),
              const SizedBox(height: 8),
              _HrPrenominaMetricCard(totalRows: totalRows, rows: rows),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HrPrenominaMetricCard extends StatelessWidget {
  final int totalRows;
  final List<_HrPrenominaSummaryRow> rows;

  const _HrPrenominaMetricCard({required this.totalRows, required this.rows});

  @override
  Widget build(BuildContext context) {
    final readyRows = rows.where((row) => row.statusLabel == 'Listo').length;
    final reviewRows = rows
        .where((row) => row.statusLabel == 'Revisión RH')
        .length;
    final lateMinutes = rows.fold<int>(
      0,
      (sum, row) => sum + row.lateMinutesSum,
    );
    final overtimeMinutes = rows.fold<int>(
      0,
      (sum, row) => sum + row.overtimeMinutesSum,
    );
    final vacationDays = rows.fold<double>(
      0,
      (sum, row) => sum + row.vacationTotalDays,
    );
    final permissionDays = rows.fold<double>(
      0,
      (sum, row) => sum + row.permissionImpactDays,
    );
    final preliminarySubtotal = rows.fold<double>(
      0,
      (sum, row) => sum + row.preliminarySubtotalAmount,
    );
    final weeklyVisibleTotal = rows.fold<double>(
      0,
      (sum, row) => sum + row.weeklyPaymentVisibleAmount,
    );
    final fiscalNetTotal = rows.fold<double>(
      0,
      (sum, row) => sum + row.fiscalNetAmount,
    );
    final fiscalCashTotal = rows.fold<double>(
      0,
      (sum, row) => sum + row.fiscalCashAmount,
    );
    final fiscalDepositedTotal = rows.fold<double>(
      0,
      (sum, row) => sum + row.fiscalDepositedAmount,
    );
    final operationalCashTotal = rows.fold<double>(
      0,
      (sum, row) => sum + row.operationalCashTotalAmount,
    );
    final fiscalRows = rows
        .where((row) => row.hasFiscalVacationFootprint)
        .length;
    final permissionPendingRows = rows
        .where((row) => row.permissionPendingPrenominaCount > 0)
        .length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _HrPrenominaMetricPill(label: 'Listo: $readyRows'),
        _HrPrenominaMetricPill(label: 'Revisión RH: $reviewRows'),
        _HrPrenominaMetricPill(
          label: 'Retardo: ${_formatPrenominaMinutesAsHourRatio(lateMinutes)}',
        ),
        _HrPrenominaMetricPill(
          label:
              'Horas extra: ${_formatPrenominaMinutesAsHourRatio(overtimeMinutes)}',
        ),
        _HrPrenominaMetricPill(
          label: 'Vacaciones: ${_formatPrenominaDays(vacationDays)} d',
        ),
        _HrPrenominaMetricPill(
          label: 'Permisos: ${_formatPrenominaDays(permissionDays)} d',
        ),
        _HrPrenominaMetricPill(
          label:
              'Preliminar: ${_formatPrenominaMoneyZero(preliminarySubtotal)}',
          emphasized: true,
        ),
        _HrPrenominaMetricPill(
          label: 'Fiscal: ${_formatPrenominaMoneyZero(fiscalNetTotal)}',
        ),
        _HrPrenominaMetricPill(
          label:
              'Fiscal depositado: ${_formatPrenominaMoneyZero(fiscalDepositedTotal)}',
        ),
        _HrPrenominaMetricPill(
          label:
              'Fiscal en efectivo: ${_formatPrenominaMoneyZero(fiscalCashTotal)}',
        ),
        _HrPrenominaMetricPill(
          label:
              'Efectivo RH: ${_formatPrenominaMoneyZero(operationalCashTotal)}',
        ),
        _HrPrenominaMetricPill(
          label: 'Semana: ${_formatPrenominaMoneyZero(weeklyVisibleTotal)}',
          emphasized: true,
        ),
        _HrPrenominaMetricPill(label: 'Fiscal CONTPAQ: $fiscalRows'),
        _HrPrenominaMetricPill(
          label: 'Permisos pendientes: $permissionPendingRows',
        ),
      ],
    );
  }
}

class _HrPrenominaMetricPill extends StatelessWidget {
  final String label;
  final bool emphasized;

  const _HrPrenominaMetricPill({required this.label, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xFFDBC2FF) : const Color(0xFFE9DAFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized ? const Color(0xAA9F6BFF) : const Color(0x55B084FF),
        ),
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

class _HrPrenominaTopMetaPill extends StatelessWidget {
  final String label;
  final String value;

  const _HrPrenominaTopMetaPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE1FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55B084FF)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF24103D),
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF6E47A8)),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _HrPrenominaSoftPill extends StatelessWidget {
  final String label;

  const _HrPrenominaSoftPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF6E47A8),
        ),
      ),
    );
  }
}

class _HrPrenominaGridFooter extends StatelessWidget {
  final int rows;
  final int totalRows;
  final int selectedCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HrPrenominaGridFooter({
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
                style: _hrPrenominaActionOutlinedButtonStyle(),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${_fmtPrenominaInt(currentPage + 1)} de ${_fmtPrenominaInt(totalPages)}',
              ),
              OutlinedButton.icon(
                style: _hrPrenominaActionOutlinedButtonStyle(),
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
                  decoration: _hrPrenominaFieldDecoration(),
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
              Text('Mostrando: ${_fmtPrenominaInt(rows)}'),
              Text('Total: ${_fmtPrenominaInt(totalRows)}'),
              Text('Selección: ${_fmtPrenominaInt(selectedCount)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrPrenominaHeaderBrand extends StatelessWidget {
  const _HrPrenominaHeaderBrand();

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
              'Prenómina',
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

enum _HrPrenominaEditAction { save, previous, next }

class _HrPrenominaEditResult {
  final _HrPrenominaEditAction action;
  final _HrPrenominaDraftDraft draft;

  const _HrPrenominaEditResult({required this.action, required this.draft});
}

class _HrPrenominaEditDialog extends StatefulWidget {
  final _HrPrenominaSummaryRow row;
  final String periodLabel;
  final bool canGoPrevious;
  final bool canGoNext;

  const _HrPrenominaEditDialog({
    required this.row,
    required this.periodLabel,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  State<_HrPrenominaEditDialog> createState() => _HrPrenominaEditDialogState();
}

class _HrPrenominaEditDialogState extends State<_HrPrenominaEditDialog> {
  final FocusNode _dialogFocusNode = FocusNode(debugLabel: 'hrPrenominaDialog');
  late final _HrPrenominaDraftDraft _draft =
      _HrPrenominaDraftDraft.fromSummaryRow(widget.row);
  String? _moneyValidationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    super.dispose();
  }

  bool _hasEditableTextFocus() {
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  void _save([_HrPrenominaEditAction action = _HrPrenominaEditAction.save]) {
    final invalidField = _draft.firstInvalidMoneyFieldLabel;
    if (invalidField != null) {
      setState(() {
        _moneyValidationMessage =
            'Revisa "$invalidField". Captura un monto válido, por ejemplo 1250.50.';
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(_HrPrenominaEditResult(action: action, draft: _draft));
  }

  @override
  Widget build(BuildContext context) {
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
          _save(_HrPrenominaEditAction.previous);
          return KeyEventResult.handled;
        }
        if (!_hasEditableTextFocus() &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.canGoNext) {
          _save(_HrPrenominaEditAction.next);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ContractDialogShell(
        insetPadding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Container(
            width: 1080,
            constraints: BoxConstraints(
              maxWidth: 1080,
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
                  title: 'Prenómina',
                  contextLabel: widget.periodLabel.isEmpty
                      ? 'Borrador semanal por colaborador'
                      : widget.periodLabel,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                if (_moneyValidationMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5A1B5)),
                    ),
                    child: Text(
                      _moneyValidationMessage!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8B2D50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 250,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF3E9FF,
                            ).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x55B084FF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.row.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF24103D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ID #${widget.row.employeeId}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6E47A8),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.row.empresa.isEmpty
                                    ? 'Empresa pendiente'
                                    : widget.row.empresa,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6E47A8),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Divider(
                                color: Color(0x44B084FF),
                                height: 1,
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaInfoLine(
                                label: 'Periodo',
                                value: widget.periodLabel.isEmpty
                                    ? 'Sin periodo activo'
                                    : widget.periodLabel,
                              ),
                              _HrPrenominaInfoLine(
                                label: 'Estado',
                                value: widget.row.statusLabel,
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HrPrenominaCompactInfoTile(
                                    label: 'Salario',
                                    value: _formatPrenominaMoney(
                                      widget.row.salaryWeekly,
                                    ),
                                  ),
                                  _HrPrenominaCompactInfoTile(
                                    label: 'Percibido',
                                    value: _formatPrenominaMoney(
                                      widget.row.salaryPerceivedWeekly,
                                    ),
                                  ),
                                  _HrPrenominaCompactInfoTile(
                                    label: 'Base',
                                    value: _formatPrenominaMoneyZero(
                                      widget.row.visibleDraftBaseAmount,
                                    ),
                                  ),
                                  _HrPrenominaCompactInfoTile(
                                    label: 'Prev',
                                    value: _formatPrenominaMoneyZero(
                                      widget.row.preliminarySubtotalAmount,
                                    ),
                                  ),
                                  _HrPrenominaCompactInfoTile(
                                    label: 'Fiscal',
                                    value: _formatPrenominaMoneyZero(
                                      widget.row.fiscalNetAmount,
                                    ),
                                  ),
                                  _HrPrenominaCompactInfoTile(
                                    label: 'Semana',
                                    value: _formatPrenominaMoneyZero(
                                      widget.row.weeklyPaymentVisibleAmount,
                                    ),
                                    emphasized: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaMiniLedgerLine(
                                label: 'Asistencia',
                                value: widget.row.attendanceSummary,
                              ),
                              const SizedBox(height: 8),
                              _HrPrenominaMiniLedgerLine(
                                label: 'Vacaciones',
                                value: widget.row.vacationSummary,
                              ),
                              const SizedBox(height: 8),
                              _HrPrenominaMiniLedgerLine(
                                label: 'Permisos',
                                value: widget.row.permissionSummary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HrPrenominaSectionCard(
                                title: 'Resumen fuente',
                                subtitle:
                                    'Consolidado semanal aprobado desde asistencia, vacaciones y permisos.',
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _HrPrenominaMetricMiniCard(
                                      label: 'ASISTENCIA LISTA',
                                      value:
                                          '${widget.row.attendanceReadyDays}',
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'REVISION RH',
                                      value:
                                          '${widget.row.attendanceReviewDays}',
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'RETARDO',
                                      value: _formatPrenominaMinutesAsHourRatio(
                                        widget.row.lateMinutesSum,
                                      ),
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'HORAS EXTRA',
                                      value: _formatPrenominaMinutesAsHourRatio(
                                        widget.row.overtimeMinutesSum,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaSectionCard(
                                title: 'Lectura base RH',
                                subtitle:
                                    'Base visible del borrador semanal antes de fórmulas finales de nómina.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _HrPrenominaMetricMiniCard(
                                          label: 'SUELDO SEMANAL',
                                          value: _formatPrenominaMoneyZero(
                                            widget.row.salaryWeekly,
                                          ),
                                        ),
                                        _HrPrenominaMetricMiniCard(
                                          label: 'PERCIBIDO SEMANAL',
                                          value: _formatPrenominaMoneyZero(
                                            widget.row.salaryPerceivedWeekly,
                                          ),
                                        ),
                                        _HrPrenominaMetricMiniCard(
                                          label: 'AJUSTE RH',
                                          value: _formatPrenominaSignedMoney(
                                            widget.row.manualAdjustmentAmount,
                                          ),
                                        ),
                                        _HrPrenominaMetricMiniCard(
                                          label: 'BASE VISIBLE',
                                          value: _formatPrenominaMoneyZero(
                                            widget.row.visibleDraftBaseAmount,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const _HrPrenominaInlineNote(
                                      icon: Icons.calculate_outlined,
                                      message:
                                          'Base visible = salario percibido semanal + ajuste manual RH. Todavía no representa el neto final de nómina.',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaSectionCard(
                                title: 'Corrida preliminar RH',
                                subtitle:
                                    'Valoración transparente previa a nómina final, usando solo supuestos visibles.',
                                child: Column(
                                  children: [
                                    _HrPrenominaConceptLine(
                                      concept: 'Salario diario fiscal',
                                      detail:
                                          'Referencia semanal fiscal dividida entre 7 días.',
                                      value: _formatPrenominaMoneyZero(
                                        widget.row.fiscalDailyRate,
                                      ),
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Salario diario percibido',
                                      detail:
                                          'Referencia semanal percibida dividida entre 7 días.',
                                      value: _formatPrenominaMoneyZero(
                                        widget.row.perceivedDailyRate,
                                      ),
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Vacaciones estimadas',
                                      detail:
                                          'Días pagados del periodo por salario percibido diario.',
                                      value: _formatPrenominaMoneyZero(
                                        widget.row.preliminaryVacationPayAmount,
                                      ),
                                      emphasized:
                                          widget
                                              .row
                                              .preliminaryVacationPayAmount !=
                                          0,
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Descuento preliminar sin goce',
                                      detail:
                                          widget.row.permissionWithoutPayHours >
                                              0
                                          ? 'Incluye días y horas sin goce con supuesto operativo de 8 h por día.'
                                          : 'Calculado solo sobre días sin goce capturados.',
                                      value: _formatPrenominaSignedMoney(
                                        -widget
                                            .row
                                            .preliminaryWithoutPayDeductionAmount,
                                      ),
                                      emphasized:
                                          widget
                                              .row
                                              .preliminaryWithoutPayDeductionAmount !=
                                          0,
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept:
                                          'Permisos con goce de referencia',
                                      detail:
                                          widget.row.permissionWithPayHours > 0
                                          ? 'Valor visible de días y horas con goce; no suma extra sobre la base semanal.'
                                          : 'Referencia visible de días con goce dentro del periodo.',
                                      value: _formatPrenominaMoneyZero(
                                        widget
                                            .row
                                            .preliminaryWithPayReferenceAmount,
                                      ),
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Retardo pendiente de fórmula',
                                      detail:
                                          'Todavía no se monetiza automáticamente dentro de prenómina.',
                                      value: _formatPrenominaMinutesAsHourRatio(
                                        widget.row.lateMinutesSum,
                                      ),
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept:
                                          'Horas extra pendientes de fórmula',
                                      detail:
                                          'Se mantienen visibles, pero sin valoración automática final todavía.',
                                      value: _formatPrenominaMinutesAsHourRatio(
                                        widget.row.overtimeMinutesSum,
                                      ),
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Subtotal preliminar RH',
                                      detail:
                                          'Base visible + vacaciones estimadas - descuentos preliminares sin goce.',
                                      value: _formatPrenominaMoneyZero(
                                        widget.row.preliminarySubtotalAmount,
                                      ),
                                      emphasized: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaSectionCard(
                                title: 'Conceptos del borrador',
                                subtitle:
                                    'Lectura operativa por concepto antes de construir el cálculo final de nómina.',
                                child: Column(
                                  children: [
                                    _HrPrenominaConceptLine(
                                      concept: 'Asistencia consolidada',
                                      detail:
                                          '${widget.row.attendanceReadyDays} día(s) listos · ${widget.row.attendanceReviewDays} en revisión',
                                      value:
                                          widget.row.attendanceOperationalLabel,
                                      emphasized:
                                          widget.row.attendanceReviewDays == 0,
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Retardo acumulado',
                                      detail:
                                          'Lectura operativa importada y cerrada desde asistencia',
                                      value: _formatPrenominaMinutesAsHourRatio(
                                        widget.row.lateMinutesSum,
                                      ),
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Horas extra acumuladas',
                                      detail:
                                          'Huella semanal validada en el cierre editable de asistencia',
                                      value: _formatPrenominaMinutesAsHourRatio(
                                        widget.row.overtimeMinutesSum,
                                      ),
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Vacaciones pagadas',
                                      detail:
                                          widget.row.hasFiscalVacationFootprint
                                          ? 'Con huella fiscal visible de CONTPAQ'
                                          : 'Sin huella fiscal registrada en el periodo',
                                      value:
                                          '${_formatPrenominaDays(widget.row.vacationPaidDays)} d',
                                      emphasized:
                                          widget.row.hasFiscalVacationFootprint,
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Vacaciones disfrutadas',
                                      detail:
                                          'Consumen disponibilidad operativa del ejercicio',
                                      value:
                                          '${_formatPrenominaDays(widget.row.vacationEnjoyedDays)} d',
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Vacaciones reservadas',
                                      detail:
                                          'Compromiso RH todavía visible para periodos posteriores',
                                      value:
                                          '${_formatPrenominaDays(widget.row.vacationReservedDays)} d',
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Permisos con goce',
                                      detail:
                                          'Eventos administrativos con impacto nominal positivo',
                                      value:
                                          '${_formatPrenominaDays(widget.row.permissionWithPayDays)} d',
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Permisos sin goce',
                                      detail:
                                          'Eventos administrativos que RH debe descontar después',
                                      value:
                                          '${_formatPrenominaDays(widget.row.permissionWithoutPayDays)} d',
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Incapacidades',
                                      detail:
                                          'Días trazados por incapacidad dentro del periodo activo',
                                      value:
                                          '${_formatPrenominaDays(widget.row.disabilityDays)} d',
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Ajuste manual RH',
                                      detail:
                                          'Corrección nominal capturada manualmente por RH',
                                      value: _formatPrenominaSignedMoney(
                                        widget.row.manualAdjustmentAmount,
                                      ),
                                      emphasized:
                                          widget.row.manualAdjustmentAmount !=
                                          0,
                                    ),
                                    _HrPrenominaConceptLine(
                                      concept: 'Base visible semanal',
                                      detail:
                                          'Salario percibido semanal más ajuste RH visible',
                                      value: _formatPrenominaMoneyZero(
                                        widget.row.visibleDraftBaseAmount,
                                      ),
                                      emphasized: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaSectionCard(
                                title: 'Vacaciones y permisos',
                                subtitle:
                                    'Trazabilidad de eventos que ya dejan huella en el borrador semanal.',
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _HrPrenominaMetricMiniCard(
                                      label: 'VAC PAGADAS',
                                      value: _formatPrenominaDays(
                                        widget.row.vacationPaidDays,
                                      ),
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'VAC DISFRUTADAS',
                                      value: _formatPrenominaDays(
                                        widget.row.vacationEnjoyedDays,
                                      ),
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'VAC RESERVADAS',
                                      value: _formatPrenominaDays(
                                        widget.row.vacationReservedDays,
                                      ),
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'PERM GOCE',
                                      value: _formatPrenominaDays(
                                        widget.row.permissionWithPayDays,
                                      ),
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'PERM SIN GOCE',
                                      value: _formatPrenominaDays(
                                        widget.row.permissionWithoutPayDays,
                                      ),
                                    ),
                                    _HrPrenominaMetricMiniCard(
                                      label: 'INCAPACIDAD',
                                      value: _formatPrenominaDays(
                                        widget.row.disabilityDays,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaSectionCard(
                                title: 'Huella fiscal CONTPAQ',
                                subtitle:
                                    'Referencias fiscales del periodo. Si el lote no las trajo, RH puede capturarlas manualmente.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Neto fiscal',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.fiscalNetAmountText,
                                              onChanged: (value) =>
                                                  _draft.fiscalNetAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'IMSS fiscal',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.fiscalImssAmountText,
                                              onChanged: (value) =>
                                                  _draft.fiscalImssAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'INFONAVIT fiscal',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .fiscalInfonavitAmountText,
                                              onChanged: (value) =>
                                                  _draft.fiscalInfonavitAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'FONACOT fiscal',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .fiscalFonacotAmountText,
                                              onChanged: (value) =>
                                                  _draft.fiscalFonacotAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Faltas fiscales',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .fiscalAbsenceAmountText,
                                              onChanged: (value) =>
                                                  _draft.fiscalAbsenceAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Vacaciones fiscales',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .fiscalVacationAmountText,
                                              onChanged: (value) =>
                                                  _draft.fiscalVacationAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _HrPrenominaInlineNote(
                                      icon: Icons.account_balance_outlined,
                                      message:
                                          'Referencia automática actual: neto ${_formatPrenominaMoney(widget.row.contpaqNetAmount)}, IMSS ${_formatPrenominaMoney(widget.row.contpaqImssAmount)}, INFONAVIT ${_formatPrenominaMoney(widget.row.contpaqInfonavitAmount)} y FONACOT ${_formatPrenominaMoney(widget.row.contpaqFonacotAmount)}.',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaSectionCard(
                                title: 'Bolsa operativa RH',
                                subtitle:
                                    'Aquí se consolida el efectivo, bonos y descuentos que no viven dentro del neto fiscal.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Sueldo en efectivo',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.cashSalaryAmountText,
                                              onChanged: (value) =>
                                                  _draft.cashSalaryAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Vacaciones en efectivo',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.cashVacationAmountText,
                                              onChanged: (value) =>
                                                  _draft.cashVacationAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'ISR operativo',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.cashIsrAmountText,
                                              onChanged: (value) =>
                                                  _draft.cashIsrAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Apoyo transporte',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .transportSupportAmountText,
                                              onChanged: (value) =>
                                                  _draft.transportSupportAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Día festivo',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.holidayAmountText,
                                              onChanged: (value) =>
                                                  _draft.holidayAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Horas extra monetizadas',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .overtimeMonetizedAmountText,
                                              onChanged: (value) =>
                                                  _draft.overtimeMonetizedAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Bono manual',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.manualBonusAmountText,
                                              onChanged: (value) =>
                                                  _draft.manualBonusAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Descuento faltas',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .cashAbsenceDeductionAmountText,
                                              onChanged: (value) =>
                                                  _draft.cashAbsenceDeductionAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Descuento INFONAVIT',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .cashInfonavitDeductionAmountText,
                                              onChanged: (value) =>
                                                  _draft.cashInfonavitDeductionAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Descuento FONACOT',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .cashFonacotDeductionAmountText,
                                              onChanged: (value) =>
                                                  _draft.cashFonacotDeductionAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Descuento préstamo',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .loanDeductionAmountText,
                                              onChanged: (value) =>
                                                  _draft.loanDeductionAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Fiscal en efectivo',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue:
                                                  _draft.checkAmountText,
                                              onChanged: (value) =>
                                                  _draft.checkAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 210,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Pago por fuera',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .paymentOutsideAmountText,
                                              onChanged: (value) =>
                                                  _draft.paymentOutsideAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Column(
                                      children: [
                                        _HrPrenominaConceptLine(
                                          concept: 'Bolsa operativa RH',
                                          detail:
                                              'Suma de sueldo en efectivo, vacaciones, transporte, festivo y bonos.',
                                          value: _formatPrenominaMoneyZero(
                                            widget
                                                .row
                                                .operationalCashSubtotalAmount,
                                          ),
                                        ),
                                        _HrPrenominaConceptLine(
                                          concept: 'Descuentos operativos RH',
                                          detail:
                                              'ISR, faltas, INFONAVIT, FONACOT y préstamo fuera del neto fiscal.',
                                          value: _formatPrenominaSignedMoney(
                                            -widget
                                                .row
                                                .operationalCashDeductionsTotalAmount,
                                          ),
                                          emphasized:
                                              widget
                                                  .row
                                                  .operationalCashDeductionsTotalAmount !=
                                              0,
                                        ),
                                        _HrPrenominaConceptLine(
                                          concept: 'Operativo neto RH',
                                          detail:
                                              'Resultado operativo visible antes de sumarse al depósito fiscal.',
                                          value: _formatPrenominaMoneyZero(
                                            widget
                                                .row
                                                .operationalCashTotalAmount,
                                          ),
                                          emphasized: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HrPrenominaSectionCard(
                                title: 'Borrador RH',
                                subtitle:
                                    'Control semanal de estatus, canal de pago y observaciones antes de publicar la corrida.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: 220,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Estatus RH',
                                            child: _HrPrenominaPickerField(
                                              value: _draft.draftStatus.label,
                                              onTap: () async {
                                                final value =
                                                    await showSearchablePickerDialog<
                                                      _HrPrenominaDraftStatus
                                                    >(
                                                      context,
                                                      title: 'Estatus RH',
                                                      initialValue:
                                                          _draft.draftStatus,
                                                      options: _HrPrenominaDraftStatus
                                                          .values
                                                          .map(
                                                            (item) =>
                                                                SearchablePickerOption(
                                                                  value: item,
                                                                  label: item
                                                                      .label,
                                                                ),
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                    );
                                                if (value == null) return;
                                                setState(
                                                  () => _draft.draftStatus =
                                                      value,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 220,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Ajuste nominal RH',
                                            child: _HrPrenominaMoneyTextField(
                                              initialValue: _draft
                                                  .manualAdjustmentAmountText,
                                              onChanged: (value) =>
                                                  _draft.manualAdjustmentAmountText =
                                                      value,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 220,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Canal de pago',
                                            child: _HrPrenominaPickerField(
                                              value:
                                                  _draft.paymentChannel.label,
                                              onTap: () async {
                                                final value =
                                                    await showSearchablePickerDialog<
                                                      _HrPrenominaPaymentChannel
                                                    >(
                                                      context,
                                                      title: 'Canal de pago',
                                                      initialValue:
                                                          _draft.paymentChannel,
                                                      options: _HrPrenominaPaymentChannel
                                                          .values
                                                          .map(
                                                            (item) =>
                                                                SearchablePickerOption(
                                                                  value: item,
                                                                  label: item
                                                                      .label,
                                                                ),
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                    );
                                                if (value == null) return;
                                                setState(
                                                  () => _draft.paymentChannel =
                                                      value,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 300,
                                          child: _HrPrenominaLabeledField(
                                            label: 'Referencia de pago',
                                            child: TextFormField(
                                              initialValue:
                                                  _draft.paymentReference,
                                              decoration:
                                                  _hrPrenominaFieldDecoration(),
                                              onChanged: (value) =>
                                                  _draft.paymentReference =
                                                      value,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Column(
                                      children: [
                                        _HrPrenominaConceptLine(
                                          concept: 'Fiscal total',
                                          detail:
                                              'Huella semanal tomada de CONTPAQ y validada por RH.',
                                          value: _formatPrenominaMoneyZero(
                                            widget.row.fiscalNetAmount,
                                          ),
                                        ),
                                        _HrPrenominaConceptLine(
                                          concept: 'Fiscal depositado',
                                          detail:
                                              'Parte fiscal que sí se deposita a colaboradores con cuenta.',
                                          value: _formatPrenominaMoneyZero(
                                            widget.row.fiscalDepositedAmount,
                                          ),
                                        ),
                                        _HrPrenominaConceptLine(
                                          concept: 'Fiscal en efectivo',
                                          detail:
                                              'Parte fiscal que no se deposita y se entrega en efectivo.',
                                          value: _formatPrenominaMoneyZero(
                                            widget.row.fiscalCashAmount,
                                          ),
                                          emphasized:
                                              widget.row.fiscalCashAmount != 0,
                                        ),
                                        _HrPrenominaConceptLine(
                                          concept: 'Pago por fuera',
                                          detail:
                                              'Monto fuera del fiscal y fuera del operativo visible.',
                                          value: _formatPrenominaMoneyZero(
                                            widget.row.paymentOutsideAmount,
                                          ),
                                          emphasized:
                                              widget.row.paymentOutsideAmount !=
                                              0,
                                        ),
                                        _HrPrenominaConceptLine(
                                          concept: 'Total semanal visible',
                                          detail:
                                              'Fiscal total + operativo RH + pago por fuera, sin duplicar el fiscal en efectivo.',
                                          value: _formatPrenominaMoneyZero(
                                            widget
                                                .row
                                                .weeklyPaymentVisibleAmount,
                                          ),
                                          emphasized: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (_draftNeedsOperationalNote(
                                      widget.row,
                                    )) ...[
                                      _HrPrenominaInlineNote(
                                        icon: Icons.info_outline_rounded,
                                        message: _draftOperationalNote(
                                          widget.row,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    _HrPrenominaLabeledField(
                                      label: 'Notas RH',
                                      child: TextFormField(
                                        initialValue: _draft.notes,
                                        decoration:
                                            _hrPrenominaFieldDecoration(),
                                        minLines: 3,
                                        maxLines: 5,
                                        onChanged: (value) =>
                                            _draft.notes = value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                        child: _HrPrenominaInlineNote(
                          icon: Icons.info_outline_rounded,
                          message:
                              'Esta primera versión consolida fuentes reales y ajustes RH. La fórmula final de nómina vendrá después sobre este borrador ya limpio.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.canGoPrevious) ...[
                        OutlinedButton.icon(
                          style: _hrPrenominaActionOutlinedButtonStyle(),
                          onPressed: () =>
                              _save(_HrPrenominaEditAction.previous),
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Anterior'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.canGoNext) ...[
                        OutlinedButton.icon(
                          style: _hrPrenominaActionOutlinedButtonStyle(),
                          onPressed: () => _save(_HrPrenominaEditAction.next),
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Siguiente'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton(
                        style: _hrPrenominaActionOutlinedButtonStyle(),
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
                        child: const Text('Guardar borrador'),
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

class _HrPrenominaSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _HrPrenominaSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HrPrenominaMetricMiniCard extends StatelessWidget {
  final String label;
  final String value;

  const _HrPrenominaMetricMiniCard({required this.label, required this.value});

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

class _HrPrenominaCompactInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _HrPrenominaCompactInfoTile({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xFFE9DAFF) : const Color(0xFFFFFBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasized ? const Color(0x669F6BFF) : const Color(0x44B084FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF24103D),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrPrenominaConceptLine extends StatelessWidget {
  final String concept;
  final String detail;
  final String value;
  final bool emphasized;

  const _HrPrenominaConceptLine({
    required this.concept,
    required this.detail,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xFFF8F2FF) : const Color(0xFFFFFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasized ? const Color(0x669F6BFF) : const Color(0x44B084FF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF24103D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6E47A8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: emphasized
                  ? const Color(0xFFE6D5FF)
                  : const Color(0xFFF1E6FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: emphasized
                    ? const Color(0xFF9F6BFF)
                    : const Color(0x55B084FF),
              ),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF24103D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrPrenominaMiniLedgerLine extends StatelessWidget {
  final String label;
  final String value;

  const _HrPrenominaMiniLedgerLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6E47A8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24103D),
            ),
          ),
        ),
      ],
    );
  }
}

class _HrPrenominaInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _HrPrenominaInfoLine({required this.label, required this.value});

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

class _HrPrenominaStatusBadge extends StatelessWidget {
  final String label;

  const _HrPrenominaStatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorSet = _prenominaStatusBadgeColorSet(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorSet.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorSet.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: colorSet.foreground,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HrPrenominaLabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _HrPrenominaLabeledField({required this.label, required this.child});

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

class _HrPrenominaPickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _HrPrenominaPickerField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: _hrPrenominaFieldDecoration(),
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

class _HrPrenominaMoneyTextField extends StatelessWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _HrPrenominaMoneyTextField({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      decoration: _hrPrenominaFieldDecoration(),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _HrPrenominaInlineNote extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HrPrenominaInlineNote({required this.icon, required this.message});

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

class _HrPrenominaEmployeeMaster {
  final String employeeId;
  final String displayName;
  final String empresa;
  final double salaryWeekly;
  final double salaryPerceivedWeekly;
  final DateTime? fechaIngreso;
  final DateTime? fechaAlta;

  const _HrPrenominaEmployeeMaster({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.salaryWeekly,
    required this.salaryPerceivedWeekly,
    required this.fechaIngreso,
    required this.fechaAlta,
  });

  factory _HrPrenominaEmployeeMaster.fromRow(Map<String, dynamic> row) {
    return _HrPrenominaEmployeeMaster(
      employeeId: (row['id'] ?? '').toString(),
      displayName: (row['nombre'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      salaryWeekly: _parsePrenominaNumber(row['salario']),
      salaryPerceivedWeekly: _parsePrenominaNumber(
        row['salario_real_percibido'],
      ),
      fechaIngreso: _parsePrenominaDbDate(row['fecha_ingreso']),
      fechaAlta: _parsePrenominaDbDate(row['fecha_alta']),
    );
  }
}

enum _HrPrenominaImportSource { ngteco, contpaq }

class _HrPrenominaImportLotLite {
  final String id;
  final _HrPrenominaImportSource source;
  final String fileName;
  final DateTime importedAt;
  final String periodLabel;
  final List<_HrPrenominaImportedEntry> entries;

  const _HrPrenominaImportLotLite({
    required this.id,
    required this.source,
    required this.fileName,
    required this.importedAt,
    required this.periodLabel,
    this.entries = const <_HrPrenominaImportedEntry>[],
  });

  factory _HrPrenominaImportLotLite.fromRow(Map<String, dynamic> row) {
    final source = _HrPrenominaImportSource.values.firstWhere(
      (item) => item.name == (row['source'] ?? '').toString(),
      orElse: () => _HrPrenominaImportSource.ngteco,
    );
    return _HrPrenominaImportLotLite(
      id: (row['id'] ?? '').toString(),
      source: source,
      fileName: (row['file_name'] ?? '').toString(),
      importedAt:
          DateTime.tryParse((row['imported_at'] ?? '').toString()) ??
          DateTime.now(),
      periodLabel: (row['period_label'] ?? '').toString(),
      entries: (row['entries'] as List? ?? const [])
          .map(
            (item) => _HrPrenominaImportedEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _HrPrenominaImportedEntry {
  final String employeeId;
  final String sourceName;
  final String detail;
  final String salary;
  final String net;
  final String overtime;
  final String vacations;
  final String absenceDeduction;
  final String imss;
  final String infonavit;
  final String fonacot;

  const _HrPrenominaImportedEntry({
    required this.employeeId,
    required this.sourceName,
    required this.detail,
    this.salary = '',
    this.net = '',
    this.overtime = '',
    this.vacations = '',
    this.absenceDeduction = '',
    this.imss = '',
    this.infonavit = '',
    this.fonacot = '',
  });

  factory _HrPrenominaImportedEntry.fromJson(Map<String, dynamic> json) {
    return _HrPrenominaImportedEntry(
      employeeId: (json['employee_id'] ?? '').toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      salary: (json['salary'] ?? '').toString(),
      net: (json['net'] ?? '').toString(),
      overtime: (json['overtime'] ?? '').toString(),
      vacations: (json['vacations'] ?? '').toString(),
      absenceDeduction: (json['absence_deduction'] ?? '').toString(),
      imss: (json['imss'] ?? '').toString(),
      infonavit: (json['infonavit'] ?? '').toString(),
      fonacot: (json['fonacot'] ?? '').toString(),
    );
  }
}

enum _HrPrenominaAttendanceStatus { laboro, falto, noAplica }

class _HrPrenominaAttendanceRecord {
  final String periodLabel;
  final String employeeId;
  final String sourceDate;
  final _HrPrenominaAttendanceStatus status;
  final String sourceMode;
  final int lateMinutes;
  final int overtimeMinutes;
  final String notes;

  const _HrPrenominaAttendanceRecord({
    required this.periodLabel,
    required this.employeeId,
    required this.sourceDate,
    required this.status,
    required this.sourceMode,
    required this.lateMinutes,
    required this.overtimeMinutes,
    required this.notes,
  });

  factory _HrPrenominaAttendanceRecord.fromRow(Map<String, dynamic> row) {
    return _HrPrenominaAttendanceRecord(
      periodLabel: (row['period_label'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      sourceDate: (row['source_date'] ?? '').toString(),
      status: _HrPrenominaAttendanceStatus.values.firstWhere(
        (item) => item.name == (row['status'] ?? '').toString(),
        orElse: () => _HrPrenominaAttendanceStatus.noAplica,
      ),
      sourceMode: (row['source_mode'] ?? 'manual').toString(),
      lateMinutes: _asPrenominaInt(row['late_minutes']),
      overtimeMinutes: _asPrenominaInt(row['overtime_minutes']),
      notes: (row['notes'] ?? '').toString(),
    );
  }
}

enum _HrPrenominaVacationEventType {
  vacacionesDisfrutadas,
  vacacionesPagadas,
  vacacionesPendientes,
  ajusteRh,
}

enum _HrPrenominaSyncStatus { pendiente, aplicado, omitido }

enum _HrPrenominaEventStatus { pendiente, aprobado, aplicado, cancelado }

class _HrPrenominaVacationEventRecord {
  final String employeeId;
  final String attendancePeriodLabel;
  final String receiptGroupKey;
  final _HrPrenominaVacationEventType eventType;
  final _HrPrenominaEventStatus status;
  final double daysApplied;
  final bool impactPrenomina;
  final _HrPrenominaSyncStatus prenominaSyncStatus;

  const _HrPrenominaVacationEventRecord({
    required this.employeeId,
    required this.attendancePeriodLabel,
    required this.receiptGroupKey,
    required this.eventType,
    required this.status,
    required this.daysApplied,
    required this.impactPrenomina,
    required this.prenominaSyncStatus,
  });

  factory _HrPrenominaVacationEventRecord.fromRow(Map<String, dynamic> row) {
    return _HrPrenominaVacationEventRecord(
      employeeId: (row['employee_id'] ?? '').toString(),
      attendancePeriodLabel: (row['attendance_period_label'] ?? '').toString(),
      receiptGroupKey: (row['receipt_group_key'] ?? '').toString(),
      eventType: _HrPrenominaVacationEventType.values.firstWhere(
        (item) =>
            item.name ==
            _snakeToLowerCamel((row['event_type'] ?? '').toString()),
        orElse: () => _HrPrenominaVacationEventType.vacacionesDisfrutadas,
      ),
      status: _HrPrenominaEventStatus.values.firstWhere(
        (item) => item.name == (row['status'] ?? '').toString(),
        orElse: () => _HrPrenominaEventStatus.pendiente,
      ),
      daysApplied: _parsePrenominaNumber(row['days_applied']),
      impactPrenomina: row['impact_prenomina'] == true,
      prenominaSyncStatus: _HrPrenominaSyncStatus.values.firstWhere(
        (item) => item.name == (row['prenomina_sync_status'] ?? '').toString(),
        orElse: () => _HrPrenominaSyncStatus.pendiente,
      ),
    );
  }

  bool get isContpaqImported =>
      receiptGroupKey.startsWith(_kHrPrenominaContpaqReceiptPrefix);
}

enum _HrPrenominaPermissionType {
  permisoConGoce,
  permisoSinGoce,
  incapacidad,
  ajusteRh,
}

enum _HrPrenominaPermissionUnit { dia, hora }

class _HrPrenominaPermissionEventRecord {
  final String employeeId;
  final String attendancePeriodLabel;
  final _HrPrenominaPermissionType permissionType;
  final _HrPrenominaPermissionUnit requestUnit;
  final _HrPrenominaEventStatus status;
  final double quantityDays;
  final double quantityHours;
  final bool impactPrenomina;
  final _HrPrenominaSyncStatus prenominaSyncStatus;

  const _HrPrenominaPermissionEventRecord({
    required this.employeeId,
    required this.attendancePeriodLabel,
    required this.permissionType,
    required this.requestUnit,
    required this.status,
    required this.quantityDays,
    required this.quantityHours,
    required this.impactPrenomina,
    required this.prenominaSyncStatus,
  });

  factory _HrPrenominaPermissionEventRecord.fromRow(Map<String, dynamic> row) {
    return _HrPrenominaPermissionEventRecord(
      employeeId: (row['employee_id'] ?? '').toString(),
      attendancePeriodLabel: (row['attendance_period_label'] ?? '').toString(),
      permissionType: _HrPrenominaPermissionType.values.firstWhere(
        (item) =>
            item.name ==
            _snakeToLowerCamel((row['permission_type'] ?? '').toString()),
        orElse: () => _HrPrenominaPermissionType.permisoConGoce,
      ),
      requestUnit: _HrPrenominaPermissionUnit.values.firstWhere(
        (item) => item.name == (row['request_unit'] ?? '').toString(),
        orElse: () => _HrPrenominaPermissionUnit.dia,
      ),
      status: _HrPrenominaEventStatus.values.firstWhere(
        (item) => item.name == (row['status'] ?? '').toString(),
        orElse: () => _HrPrenominaEventStatus.pendiente,
      ),
      quantityDays: _parsePrenominaNumber(row['quantity_days']),
      quantityHours: _parsePrenominaNumber(row['quantity_hours']),
      impactPrenomina: row['impact_prenomina'] == true,
      prenominaSyncStatus: _HrPrenominaSyncStatus.values.firstWhere(
        (item) => item.name == (row['prenomina_sync_status'] ?? '').toString(),
        orElse: () => _HrPrenominaSyncStatus.pendiente,
      ),
    );
  }
}

enum _HrPrenominaDraftStatus {
  borrador('Borrador'),
  revisionRh('Revisión RH'),
  listo('Listo'),
  publicado('Publicado');

  final String label;
  const _HrPrenominaDraftStatus(this.label);
}

enum _HrPrenominaPaymentChannel {
  pendiente('Pendiente'),
  deposito('Depósito fiscal'),
  cheque('Fiscal en efectivo'),
  mixto('Mixto'),
  efectivo('Efectivo'),
  pagoFuera('Pago por fuera');

  final String label;
  const _HrPrenominaPaymentChannel(this.label);
}

class _HrPrenominaDraftRowRecord {
  final String id;
  final String periodLabel;
  final String employeeId;
  final String employeeName;
  final String empresa;
  final _HrPrenominaDraftStatus draftStatus;
  final double manualAdjustmentAmount;
  final double? fiscalNetAmount;
  final double? fiscalImssAmount;
  final double? fiscalInfonavitAmount;
  final double? fiscalFonacotAmount;
  final double? fiscalAbsenceAmount;
  final double? fiscalVacationAmount;
  final double? cashSalaryAmount;
  final double? cashVacationAmount;
  final double? cashIsrAmount;
  final double? transportSupportAmount;
  final double? holidayAmount;
  final double? overtimeMonetizedAmount;
  final double? manualBonusAmount;
  final double? cashAbsenceDeductionAmount;
  final double? cashInfonavitDeductionAmount;
  final double? cashFonacotDeductionAmount;
  final double? loanDeductionAmount;
  final double? checkAmount;
  final double? paymentOutsideAmount;
  final String paymentChannel;
  final String paymentReference;
  final String notes;

  const _HrPrenominaDraftRowRecord({
    required this.id,
    required this.periodLabel,
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.draftStatus,
    required this.manualAdjustmentAmount,
    required this.fiscalNetAmount,
    required this.fiscalImssAmount,
    required this.fiscalInfonavitAmount,
    required this.fiscalFonacotAmount,
    required this.fiscalAbsenceAmount,
    required this.fiscalVacationAmount,
    required this.cashSalaryAmount,
    required this.cashVacationAmount,
    required this.cashIsrAmount,
    required this.transportSupportAmount,
    required this.holidayAmount,
    required this.overtimeMonetizedAmount,
    required this.manualBonusAmount,
    required this.cashAbsenceDeductionAmount,
    required this.cashInfonavitDeductionAmount,
    required this.cashFonacotDeductionAmount,
    required this.loanDeductionAmount,
    required this.checkAmount,
    required this.paymentOutsideAmount,
    required this.paymentChannel,
    required this.paymentReference,
    required this.notes,
  });

  factory _HrPrenominaDraftRowRecord.fromRow(Map<String, dynamic> row) {
    return _HrPrenominaDraftRowRecord(
      id: (row['id'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      draftStatus: _draftStatusFromDb((row['draft_status'] ?? '').toString()),
      manualAdjustmentAmount: _parsePrenominaNumber(
        row['manual_adjustment_amount'],
      ),
      fiscalNetAmount: _parsePrenominaNullableNumber(row['fiscal_net_amount']),
      fiscalImssAmount: _parsePrenominaNullableNumber(
        row['fiscal_imss_amount'],
      ),
      fiscalInfonavitAmount: _parsePrenominaNullableNumber(
        row['fiscal_infonavit_amount'],
      ),
      fiscalFonacotAmount: _parsePrenominaNullableNumber(
        row['fiscal_fonacot_amount'],
      ),
      fiscalAbsenceAmount: _parsePrenominaNullableNumber(
        row['fiscal_absence_amount'],
      ),
      fiscalVacationAmount: _parsePrenominaNullableNumber(
        row['fiscal_vacation_amount'],
      ),
      cashSalaryAmount: _parsePrenominaNullableNumber(
        row['cash_salary_amount'],
      ),
      cashVacationAmount: _parsePrenominaNullableNumber(
        row['cash_vacation_amount'],
      ),
      cashIsrAmount: _parsePrenominaNullableNumber(row['cash_isr_amount']),
      transportSupportAmount: _parsePrenominaNullableNumber(
        row['transport_support_amount'],
      ),
      holidayAmount: _parsePrenominaNullableNumber(row['holiday_amount']),
      overtimeMonetizedAmount: _parsePrenominaNullableNumber(
        row['overtime_monetized_amount'],
      ),
      manualBonusAmount: _parsePrenominaNullableNumber(
        row['manual_bonus_amount'],
      ),
      cashAbsenceDeductionAmount: _parsePrenominaNullableNumber(
        row['cash_absence_deduction_amount'],
      ),
      cashInfonavitDeductionAmount: _parsePrenominaNullableNumber(
        row['cash_infonavit_deduction_amount'],
      ),
      cashFonacotDeductionAmount: _parsePrenominaNullableNumber(
        row['cash_fonacot_deduction_amount'],
      ),
      loanDeductionAmount: _parsePrenominaNullableNumber(
        row['loan_deduction_amount'],
      ),
      checkAmount: _parsePrenominaNullableNumber(row['check_amount']),
      paymentOutsideAmount: _parsePrenominaNullableNumber(
        row['payment_outside_amount'],
      ),
      paymentChannel: (row['payment_channel'] ?? '').toString(),
      paymentReference: (row['payment_reference'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
    );
  }
}

class _HrPrenominaSummaryRow {
  final String draftId;
  final String employeeId;
  final String displayName;
  final String empresa;
  final double salaryWeekly;
  final double salaryPerceivedWeekly;
  final DateTime? fechaIngreso;
  final DateTime? fechaAlta;
  final int attendanceReadyDays;
  final int attendanceReviewDays;
  final int lateMinutesSum;
  final int overtimeMinutesSum;
  final double vacationPaidDays;
  final double vacationEnjoyedDays;
  final double vacationReservedDays;
  final double permissionWithPayDays;
  final double permissionWithoutPayDays;
  final double disabilityDays;
  final double permissionWithPayHours;
  final double permissionWithoutPayHours;
  final double disabilityHours;
  final int permissionPendingPrenominaCount;
  final bool hasFiscalVacationFootprint;
  final _HrPrenominaDraftStatus draftStatus;
  final double manualAdjustmentAmount;
  final double contpaqSalaryAmount;
  final double contpaqNetAmount;
  final double contpaqOvertimeAmount;
  final double contpaqVacationAmount;
  final double contpaqAbsenceAmount;
  final double contpaqImssAmount;
  final double contpaqInfonavitAmount;
  final double contpaqFonacotAmount;
  final double fiscalNetAmount;
  final double fiscalImssAmount;
  final double fiscalInfonavitAmount;
  final double fiscalFonacotAmount;
  final double fiscalAbsenceAmount;
  final double fiscalVacationAmount;
  final double cashSalaryAmount;
  final double cashVacationAmount;
  final double cashIsrAmount;
  final double transportSupportAmount;
  final double holidayAmount;
  final double overtimeMonetizedAmount;
  final double manualBonusAmount;
  final double cashAbsenceDeductionAmount;
  final double cashInfonavitDeductionAmount;
  final double cashFonacotDeductionAmount;
  final double loanDeductionAmount;
  final double checkAmount;
  final double paymentOutsideAmount;
  final _HrPrenominaPaymentChannel paymentChannel;
  final String paymentReference;
  final String notes;

  const _HrPrenominaSummaryRow({
    required this.draftId,
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.salaryWeekly,
    required this.salaryPerceivedWeekly,
    required this.fechaIngreso,
    required this.fechaAlta,
    required this.attendanceReadyDays,
    required this.attendanceReviewDays,
    required this.lateMinutesSum,
    required this.overtimeMinutesSum,
    required this.vacationPaidDays,
    required this.vacationEnjoyedDays,
    required this.vacationReservedDays,
    required this.permissionWithPayDays,
    required this.permissionWithoutPayDays,
    required this.disabilityDays,
    required this.permissionWithPayHours,
    required this.permissionWithoutPayHours,
    required this.disabilityHours,
    required this.permissionPendingPrenominaCount,
    required this.hasFiscalVacationFootprint,
    required this.draftStatus,
    required this.manualAdjustmentAmount,
    required this.contpaqSalaryAmount,
    required this.contpaqNetAmount,
    required this.contpaqOvertimeAmount,
    required this.contpaqVacationAmount,
    required this.contpaqAbsenceAmount,
    required this.contpaqImssAmount,
    required this.contpaqInfonavitAmount,
    required this.contpaqFonacotAmount,
    required this.fiscalNetAmount,
    required this.fiscalImssAmount,
    required this.fiscalInfonavitAmount,
    required this.fiscalFonacotAmount,
    required this.fiscalAbsenceAmount,
    required this.fiscalVacationAmount,
    required this.cashSalaryAmount,
    required this.cashVacationAmount,
    required this.cashIsrAmount,
    required this.transportSupportAmount,
    required this.holidayAmount,
    required this.overtimeMonetizedAmount,
    required this.manualBonusAmount,
    required this.cashAbsenceDeductionAmount,
    required this.cashInfonavitDeductionAmount,
    required this.cashFonacotDeductionAmount,
    required this.loanDeductionAmount,
    required this.checkAmount,
    required this.paymentOutsideAmount,
    required this.paymentChannel,
    required this.paymentReference,
    required this.notes,
  });

  String get attendanceSummary =>
      '$attendanceReadyDays listo · $attendanceReviewDays rev · ${_formatPrenominaMinutesAsHourRatio(lateMinutesSum)} tard';
  String get attendanceSummaryPrimary =>
      '$attendanceReadyDays listo · $attendanceReviewDays rev';
  String get attendanceSummarySecondary =>
      '${_formatPrenominaMinutesAsHourRatio(lateMinutesSum)} retardo';
  String get vacationSummary =>
      '${_formatPrenominaDays(vacationPaidDays)} pag · ${_formatPrenominaDays(vacationEnjoyedDays)} disfr · ${_formatPrenominaDays(vacationReservedDays)} res';
  String get vacationSummaryPrimary =>
      '${_formatPrenominaDays(vacationPaidDays)} pagadas · ${_formatPrenominaDays(vacationEnjoyedDays)} goce';
  String get vacationSummarySecondary =>
      '${_formatPrenominaDays(vacationReservedDays)} reserva';
  String get permissionSummary =>
      '${_formatPrenominaDays(permissionWithPayDays)} goce · ${_formatPrenominaDays(permissionWithoutPayDays)} sin · ${_formatPrenominaDays(disabilityDays)} inc';
  String get permissionSummaryPrimary =>
      '${_formatPrenominaDays(permissionWithPayDays)} goce · ${_formatPrenominaDays(permissionWithoutPayDays)} sin goce';
  String get permissionSummarySecondary =>
      '${_formatPrenominaDays(disabilityDays)} incapacidad';
  double get vacationTotalDays =>
      vacationPaidDays + vacationEnjoyedDays + vacationReservedDays;
  double get permissionImpactDays =>
      permissionWithPayDays + permissionWithoutPayDays + disabilityDays;
  double get fiscalDailyRate => salaryWeekly == 0 ? 0 : salaryWeekly / 7;
  double get perceivedDailyRate =>
      salaryPerceivedWeekly == 0 ? 0 : salaryPerceivedWeekly / 7;
  double get perceivedHourlyRate =>
      perceivedDailyRate == 0 ? 0 : perceivedDailyRate / 8;
  double get visibleDraftBaseAmount =>
      salaryPerceivedWeekly + manualAdjustmentAmount;
  double get preliminaryVacationPayAmount =>
      vacationPaidDays * perceivedDailyRate;
  double get preliminaryWithoutPayDeductionAmount =>
      (permissionWithoutPayDays * perceivedDailyRate) +
      (permissionWithoutPayHours * perceivedHourlyRate);
  double get preliminaryWithPayReferenceAmount =>
      (permissionWithPayDays * perceivedDailyRate) +
      (permissionWithPayHours * perceivedHourlyRate);
  double get preliminarySubtotalAmount =>
      visibleDraftBaseAmount +
      preliminaryVacationPayAmount -
      preliminaryWithoutPayDeductionAmount;
  double get operationalBonusTotalAmount =>
      overtimeMonetizedAmount + manualBonusAmount;
  double get operationalCashSubtotalAmount =>
      cashSalaryAmount +
      cashVacationAmount +
      transportSupportAmount +
      holidayAmount +
      operationalBonusTotalAmount;
  double get operationalCashDeductionsTotalAmount =>
      cashIsrAmount +
      cashAbsenceDeductionAmount +
      cashInfonavitDeductionAmount +
      cashFonacotDeductionAmount +
      loanDeductionAmount;
  double get operationalCashTotalAmount =>
      operationalCashSubtotalAmount - operationalCashDeductionsTotalAmount;
  double get fiscalCashAmount => checkAmount;
  double get fiscalDepositedAmount {
    final amount = fiscalNetAmount - fiscalCashAmount;
    return amount < 0 ? 0 : amount;
  }

  double get weeklyPaymentVisibleAmount =>
      fiscalNetAmount + paymentOutsideAmount + operationalCashTotalAmount;
  String get attendanceOperationalLabel =>
      attendanceReviewDays > 0 ? 'Pendiente RH' : 'Lista';
  String get statusLabel => _resolveSummaryStatus(this).label;
}

class _HrPrenominaDraftDraft {
  final String id;
  _HrPrenominaDraftStatus draftStatus;
  String manualAdjustmentAmountText;
  String fiscalNetAmountText;
  String fiscalImssAmountText;
  String fiscalInfonavitAmountText;
  String fiscalFonacotAmountText;
  String fiscalAbsenceAmountText;
  String fiscalVacationAmountText;
  String cashSalaryAmountText;
  String cashVacationAmountText;
  String cashIsrAmountText;
  String transportSupportAmountText;
  String holidayAmountText;
  String overtimeMonetizedAmountText;
  String manualBonusAmountText;
  String cashAbsenceDeductionAmountText;
  String cashInfonavitDeductionAmountText;
  String cashFonacotDeductionAmountText;
  String loanDeductionAmountText;
  String checkAmountText;
  String paymentOutsideAmountText;
  _HrPrenominaPaymentChannel paymentChannel;
  String paymentReference;
  String notes;

  _HrPrenominaDraftDraft({
    required this.id,
    required this.draftStatus,
    required this.manualAdjustmentAmountText,
    required this.fiscalNetAmountText,
    required this.fiscalImssAmountText,
    required this.fiscalInfonavitAmountText,
    required this.fiscalFonacotAmountText,
    required this.fiscalAbsenceAmountText,
    required this.fiscalVacationAmountText,
    required this.cashSalaryAmountText,
    required this.cashVacationAmountText,
    required this.cashIsrAmountText,
    required this.transportSupportAmountText,
    required this.holidayAmountText,
    required this.overtimeMonetizedAmountText,
    required this.manualBonusAmountText,
    required this.cashAbsenceDeductionAmountText,
    required this.cashInfonavitDeductionAmountText,
    required this.cashFonacotDeductionAmountText,
    required this.loanDeductionAmountText,
    required this.checkAmountText,
    required this.paymentOutsideAmountText,
    required this.paymentChannel,
    required this.paymentReference,
    required this.notes,
  });

  factory _HrPrenominaDraftDraft.fromSummaryRow(_HrPrenominaSummaryRow row) {
    return _HrPrenominaDraftDraft(
      id: row.draftId,
      draftStatus: row.draftStatus,
      manualAdjustmentAmountText: row.manualAdjustmentAmount == 0
          ? ''
          : row.manualAdjustmentAmount.toStringAsFixed(2),
      fiscalNetAmountText: _draftMoneyText(row.fiscalNetAmount),
      fiscalImssAmountText: _draftMoneyText(row.fiscalImssAmount),
      fiscalInfonavitAmountText: _draftMoneyText(row.fiscalInfonavitAmount),
      fiscalFonacotAmountText: _draftMoneyText(row.fiscalFonacotAmount),
      fiscalAbsenceAmountText: _draftMoneyText(row.fiscalAbsenceAmount),
      fiscalVacationAmountText: _draftMoneyText(row.fiscalVacationAmount),
      cashSalaryAmountText: _draftMoneyText(row.cashSalaryAmount),
      cashVacationAmountText: _draftMoneyText(row.cashVacationAmount),
      cashIsrAmountText: _draftMoneyText(row.cashIsrAmount),
      transportSupportAmountText: _draftMoneyText(row.transportSupportAmount),
      holidayAmountText: _draftMoneyText(row.holidayAmount),
      overtimeMonetizedAmountText: _draftMoneyText(row.overtimeMonetizedAmount),
      manualBonusAmountText: _draftMoneyText(row.manualBonusAmount),
      cashAbsenceDeductionAmountText: _draftMoneyText(
        row.cashAbsenceDeductionAmount,
      ),
      cashInfonavitDeductionAmountText: _draftMoneyText(
        row.cashInfonavitDeductionAmount,
      ),
      cashFonacotDeductionAmountText: _draftMoneyText(
        row.cashFonacotDeductionAmount,
      ),
      loanDeductionAmountText: _draftMoneyText(row.loanDeductionAmount),
      checkAmountText: _draftMoneyText(row.checkAmount),
      paymentOutsideAmountText: _draftMoneyText(row.paymentOutsideAmount),
      paymentChannel: row.paymentChannel,
      paymentReference: row.paymentReference,
      notes: row.notes,
    );
  }

  String? get firstInvalidMoneyFieldLabel {
    final fields = <(String, String)>[
      ('Neto fiscal', fiscalNetAmountText),
      ('IMSS fiscal', fiscalImssAmountText),
      ('INFONAVIT fiscal', fiscalInfonavitAmountText),
      ('FONACOT fiscal', fiscalFonacotAmountText),
      ('Faltas fiscales', fiscalAbsenceAmountText),
      ('Vacaciones fiscales', fiscalVacationAmountText),
      ('Sueldo en efectivo', cashSalaryAmountText),
      ('Vacaciones en efectivo', cashVacationAmountText),
      ('ISR operativo', cashIsrAmountText),
      ('Apoyo transporte', transportSupportAmountText),
      ('Día festivo', holidayAmountText),
      ('Horas extra monetizadas', overtimeMonetizedAmountText),
      ('Bono manual', manualBonusAmountText),
      ('Descuento faltas', cashAbsenceDeductionAmountText),
      ('Descuento INFONAVIT', cashInfonavitDeductionAmountText),
      ('Descuento FONACOT', cashFonacotDeductionAmountText),
      ('Descuento préstamo', loanDeductionAmountText),
      ('Fiscal en efectivo', checkAmountText),
      ('Pago por fuera', paymentOutsideAmountText),
      ('Ajuste nominal RH', manualAdjustmentAmountText),
    ];
    for (final field in fields) {
      if (!_isPrenominaMoneyInputValid(field.$2)) return field.$1;
    }
    return null;
  }

  Map<String, dynamic> toRow({
    required String periodLabel,
    required String employeeId,
    required String employeeName,
    required String empresa,
    required String existingId,
  }) {
    return {
      if (existingId.trim().isNotEmpty) 'id': existingId,
      'period_label': periodLabel,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'empresa': empresa,
      'draft_status': _draftStatusToDb(draftStatus),
      'manual_adjustment_amount':
          _parsePrenominaDraftText(manualAdjustmentAmountText) ?? 0.0,
      'fiscal_net_amount': _parsePrenominaDraftText(fiscalNetAmountText),
      'fiscal_imss_amount': _parsePrenominaDraftText(fiscalImssAmountText),
      'fiscal_infonavit_amount': _parsePrenominaDraftText(
        fiscalInfonavitAmountText,
      ),
      'fiscal_fonacot_amount': _parsePrenominaDraftText(
        fiscalFonacotAmountText,
      ),
      'fiscal_absence_amount': _parsePrenominaDraftText(
        fiscalAbsenceAmountText,
      ),
      'fiscal_vacation_amount': _parsePrenominaDraftText(
        fiscalVacationAmountText,
      ),
      'cash_salary_amount': _parsePrenominaDraftText(cashSalaryAmountText),
      'cash_vacation_amount': _parsePrenominaDraftText(cashVacationAmountText),
      'cash_isr_amount': _parsePrenominaDraftText(cashIsrAmountText),
      'transport_support_amount': _parsePrenominaDraftText(
        transportSupportAmountText,
      ),
      'holiday_amount': _parsePrenominaDraftText(holidayAmountText),
      'overtime_monetized_amount': _parsePrenominaDraftText(
        overtimeMonetizedAmountText,
      ),
      'manual_bonus_amount': _parsePrenominaDraftText(manualBonusAmountText),
      'cash_absence_deduction_amount': _parsePrenominaDraftText(
        cashAbsenceDeductionAmountText,
      ),
      'cash_infonavit_deduction_amount': _parsePrenominaDraftText(
        cashInfonavitDeductionAmountText,
      ),
      'cash_fonacot_deduction_amount': _parsePrenominaDraftText(
        cashFonacotDeductionAmountText,
      ),
      'loan_deduction_amount': _parsePrenominaDraftText(
        loanDeductionAmountText,
      ),
      'check_amount': _parsePrenominaDraftText(checkAmountText),
      'payment_outside_amount': _parsePrenominaDraftText(
        paymentOutsideAmountText,
      ),
      'payment_channel': paymentChannel.name,
      'payment_reference': paymentReference.trim(),
      'notes': notes.trim(),
      'source_snapshot': <String, dynamic>{},
    };
  }
}

const List<_HrPrenominaGridColumn> _kPrenominaGridColumns =
    <_HrPrenominaGridColumn>[
      _HrPrenominaGridColumn(id: 'id', label: 'ID'),
      _HrPrenominaGridColumn(id: 'nombre', label: 'Nombre'),
      _HrPrenominaGridColumn(id: 'sueldo', label: 'Sueldo'),
      _HrPrenominaGridColumn(id: 'asistencia', label: 'Asistencia'),
      _HrPrenominaGridColumn(id: 'vacaciones', label: 'Vacaciones'),
      _HrPrenominaGridColumn(id: 'permisos', label: 'Permisos'),
      _HrPrenominaGridColumn(id: 'estado', label: 'Estado'),
      _HrPrenominaGridColumn(id: 'acciones', label: 'Acciones'),
    ];

class _HrPrenominaGridColumn {
  final String id;
  final String label;

  const _HrPrenominaGridColumn({required this.id, required this.label});
}

_HrPrenominaImportLotLite? _latestPrenominaLotBySource(
  List<_HrPrenominaImportLotLite> lots,
  _HrPrenominaImportSource source,
) {
  for (final lot in lots) {
    if (lot.source == source) return lot;
  }
  return null;
}

String _resolveActivePrenominaPeriodLabel({
  required _HrPrenominaImportLotLite? ngtecoLot,
  required _HrPrenominaImportLotLite? contpaqLot,
}) {
  if (contpaqLot != null && contpaqLot.periodLabel.trim().isNotEmpty) {
    return _describePrenominaImportPeriod(contpaqLot);
  }
  if (ngtecoLot != null && ngtecoLot.periodLabel.trim().isNotEmpty) {
    return _describePrenominaImportPeriod(ngtecoLot);
  }
  return '';
}

List<_HrPrenominaSummaryRow> _buildPrenominaSummaryRows({
  required List<_HrPrenominaEmployeeMaster> employees,
  required _HrPrenominaImportLotLite? contpaqLot,
  required List<_HrPrenominaAttendanceRecord> attendanceRecords,
  required List<_HrPrenominaVacationEventRecord> vacationEvents,
  required List<_HrPrenominaPermissionEventRecord> permissionEvents,
  required List<_HrPrenominaDraftRowRecord> draftRows,
  required String activePeriodLabel,
  required String activeContpaqRawPeriodLabel,
}) {
  final draftByEmployee = {
    for (final draft in draftRows.where(
      (item) => item.periodLabel == activePeriodLabel,
    ))
      draft.employeeId: draft,
  };

  final attendanceByEmployee = <String, List<_HrPrenominaAttendanceRecord>>{};
  for (final item in attendanceRecords.where(
    (record) => record.periodLabel == activePeriodLabel,
  )) {
    attendanceByEmployee
        .putIfAbsent(item.employeeId, () => <_HrPrenominaAttendanceRecord>[])
        .add(item);
  }

  final vacationsByEmployee = <String, List<_HrPrenominaVacationEventRecord>>{};
  for (final event in vacationEvents.where(
    (item) =>
        item.impactPrenomina &&
        item.status != _HrPrenominaEventStatus.cancelado &&
        (item.attendancePeriodLabel == activePeriodLabel ||
            (activeContpaqRawPeriodLabel.isNotEmpty &&
                item.receiptGroupKey.contains(activeContpaqRawPeriodLabel))),
  )) {
    vacationsByEmployee
        .putIfAbsent(
          event.employeeId,
          () => <_HrPrenominaVacationEventRecord>[],
        )
        .add(event);
  }

  final permissionsByEmployee =
      <String, List<_HrPrenominaPermissionEventRecord>>{};
  for (final event in permissionEvents.where(
    (item) =>
        item.impactPrenomina &&
        item.status != _HrPrenominaEventStatus.cancelado &&
        item.attendancePeriodLabel == activePeriodLabel,
  )) {
    permissionsByEmployee
        .putIfAbsent(
          event.employeeId,
          () => <_HrPrenominaPermissionEventRecord>[],
        )
        .add(event);
  }

  final contpaqByEmployee = {
    for (final entry
        in contpaqLot?.entries ?? const <_HrPrenominaImportedEntry>[])
      entry.employeeId: entry,
  };

  return employees
      .map((employee) {
        final attendance =
            attendanceByEmployee[employee.employeeId] ?? const [];
        final vacations = vacationsByEmployee[employee.employeeId] ?? const [];
        final permissions =
            permissionsByEmployee[employee.employeeId] ?? const [];
        final draft = draftByEmployee[employee.employeeId];
        final contpaq = contpaqByEmployee[employee.employeeId];

        final attendanceReadyDays = attendance
            .where(_attendanceRecordIsReadyForPrenomina)
            .length;
        final attendanceReviewDays = attendance
            .where(_attendanceRecordNeedsReview)
            .length;
        final lateMinutesSum = attendance.fold<int>(
          0,
          (sum, item) => sum + item.lateMinutes,
        );
        final overtimeMinutesSum = attendance.fold<int>(
          0,
          (sum, item) => sum + item.overtimeMinutes,
        );

        double vacationPaidDays = 0;
        double vacationEnjoyedDays = 0;
        double vacationReservedDays = 0;
        var hasFiscalVacationFootprint = false;
        for (final event in vacations) {
          if (event.isContpaqImported) hasFiscalVacationFootprint = true;
          switch (event.eventType) {
            case _HrPrenominaVacationEventType.vacacionesPagadas:
              vacationPaidDays += event.daysApplied;
            case _HrPrenominaVacationEventType.vacacionesDisfrutadas:
              vacationEnjoyedDays += event.daysApplied;
            case _HrPrenominaVacationEventType.vacacionesPendientes:
              vacationReservedDays += event.daysApplied;
            case _HrPrenominaVacationEventType.ajusteRh:
              vacationReservedDays += event.daysApplied;
          }
        }

        double permissionWithPayDays = 0;
        double permissionWithoutPayDays = 0;
        double disabilityDays = 0;
        double permissionWithPayHours = 0;
        double permissionWithoutPayHours = 0;
        double disabilityHours = 0;
        var permissionPendingPrenominaCount = 0;
        for (final event in permissions) {
          if (event.prenominaSyncStatus == _HrPrenominaSyncStatus.pendiente) {
            permissionPendingPrenominaCount += 1;
          }
          if (event.requestUnit == _HrPrenominaPermissionUnit.hora) {
            switch (event.permissionType) {
              case _HrPrenominaPermissionType.permisoConGoce:
                permissionWithPayHours += event.quantityHours;
              case _HrPrenominaPermissionType.permisoSinGoce:
                permissionWithoutPayHours += event.quantityHours;
              case _HrPrenominaPermissionType.incapacidad:
                disabilityHours += event.quantityHours;
              case _HrPrenominaPermissionType.ajusteRh:
                permissionWithPayHours += event.quantityHours;
            }
            continue;
          }
          switch (event.permissionType) {
            case _HrPrenominaPermissionType.permisoConGoce:
              permissionWithPayDays += event.quantityDays;
            case _HrPrenominaPermissionType.permisoSinGoce:
              permissionWithoutPayDays += event.quantityDays;
            case _HrPrenominaPermissionType.incapacidad:
              disabilityDays += event.quantityDays;
            case _HrPrenominaPermissionType.ajusteRh:
              permissionWithPayDays += event.quantityDays;
          }
        }

        final derivedStatus = attendanceReviewDays > 0
            ? _HrPrenominaDraftStatus.revisionRh
            : permissionPendingPrenominaCount > 0
            ? _HrPrenominaDraftStatus.borrador
            : _HrPrenominaDraftStatus.listo;

        final contpaqSalaryAmount = _parsePrenominaImportedAmount(
          contpaq?.salary,
        );
        final contpaqNetAmount = _parsePrenominaImportedAmount(contpaq?.net);
        final contpaqOvertimeAmount = _parsePrenominaImportedAmount(
          contpaq?.overtime,
        );
        final contpaqVacationAmount = _parsePrenominaImportedAmount(
          contpaq?.vacations,
        );
        final contpaqAbsenceAmount = _parsePrenominaImportedAmount(
          contpaq?.absenceDeduction,
        );
        final contpaqImssAmount = _parsePrenominaImportedAmount(contpaq?.imss);
        final contpaqInfonavitAmount = _parsePrenominaImportedAmount(
          contpaq?.infonavit,
        );
        final contpaqFonacotAmount = _parsePrenominaImportedAmount(
          contpaq?.fonacot,
        );
        final fiscalNetAmount = draft?.fiscalNetAmount ?? contpaqNetAmount;
        final fiscalImssAmount = draft?.fiscalImssAmount ?? contpaqImssAmount;
        final fiscalInfonavitAmount =
            draft?.fiscalInfonavitAmount ?? contpaqInfonavitAmount;
        final fiscalFonacotAmount =
            draft?.fiscalFonacotAmount ?? contpaqFonacotAmount;
        final fiscalAbsenceAmount =
            draft?.fiscalAbsenceAmount ?? contpaqAbsenceAmount;
        final fiscalVacationAmount =
            draft?.fiscalVacationAmount ?? contpaqVacationAmount;
        final suggestedCashSalaryAmount = _suggestPrenominaCashSalaryAmount(
          salaryPerceivedWeekly: employee.salaryPerceivedWeekly,
          contpaqSalaryAmount: contpaqSalaryAmount,
        );
        final suggestedCashVacationAmount = _suggestPrenominaCashVacationAmount(
          vacationPaidDays: vacationPaidDays,
          perceivedDailyRate: employee.salaryPerceivedWeekly == 0
              ? 0
              : employee.salaryPerceivedWeekly / 7,
          fiscalVacationAmount: fiscalVacationAmount,
        );
        final suggestedCashAbsenceDeductionAmount =
            _suggestPrenominaCashAbsenceDeductionAmount(
              permissionWithoutPayDays: permissionWithoutPayDays,
              permissionWithoutPayHours: permissionWithoutPayHours,
              perceivedDailyRate: employee.salaryPerceivedWeekly == 0
                  ? 0
                  : employee.salaryPerceivedWeekly / 7,
              fiscalAbsenceAmount: fiscalAbsenceAmount,
            );
        final suggestedOvertimeMonetizedAmount =
            _suggestPrenominaOvertimeMonetizedAmount(
              contpaqOvertimeAmount: contpaqOvertimeAmount,
            );
        final cashSalaryAmount =
            draft?.cashSalaryAmount ?? suggestedCashSalaryAmount;
        final cashVacationAmount =
            draft?.cashVacationAmount ?? suggestedCashVacationAmount;
        final cashIsrAmount = draft?.cashIsrAmount ?? 0;
        final transportSupportAmount = draft?.transportSupportAmount ?? 0;
        final holidayAmount = draft?.holidayAmount ?? 0;
        final overtimeMonetizedAmount =
            draft?.overtimeMonetizedAmount ?? suggestedOvertimeMonetizedAmount;
        final manualBonusAmount = draft?.manualBonusAmount ?? 0;
        final cashAbsenceDeductionAmount =
            draft?.cashAbsenceDeductionAmount ??
            suggestedCashAbsenceDeductionAmount;
        final cashInfonavitDeductionAmount =
            draft?.cashInfonavitDeductionAmount ?? 0;
        final cashFonacotDeductionAmount =
            draft?.cashFonacotDeductionAmount ?? 0;
        final loanDeductionAmount = draft?.loanDeductionAmount ?? 0;
        final checkAmount = draft?.checkAmount ?? 0;
        final paymentOutsideAmount = draft?.paymentOutsideAmount ?? 0;
        final paymentChannel = draft?.paymentChannel.trim().isNotEmpty == true
            ? _paymentChannelFromDb(draft!.paymentChannel)
            : _suggestPrenominaPaymentChannel(
                fiscalNetAmount: fiscalNetAmount,
                cashSalaryAmount: cashSalaryAmount,
                cashVacationAmount: cashVacationAmount,
                cashIsrAmount: cashIsrAmount,
                transportSupportAmount: transportSupportAmount,
                holidayAmount: holidayAmount,
                overtimeMonetizedAmount: overtimeMonetizedAmount,
                manualBonusAmount: manualBonusAmount,
                cashAbsenceDeductionAmount: cashAbsenceDeductionAmount,
                cashInfonavitDeductionAmount: cashInfonavitDeductionAmount,
                cashFonacotDeductionAmount: cashFonacotDeductionAmount,
                loanDeductionAmount: loanDeductionAmount,
                checkAmount: checkAmount,
                paymentOutsideAmount: paymentOutsideAmount,
              );

        return _HrPrenominaSummaryRow(
          draftId: draft?.id ?? '',
          employeeId: employee.employeeId,
          displayName: employee.displayName,
          empresa: employee.empresa,
          salaryWeekly: employee.salaryWeekly,
          salaryPerceivedWeekly: employee.salaryPerceivedWeekly,
          fechaIngreso: employee.fechaIngreso,
          fechaAlta: employee.fechaAlta,
          attendanceReadyDays: attendanceReadyDays,
          attendanceReviewDays: attendanceReviewDays,
          lateMinutesSum: lateMinutesSum,
          overtimeMinutesSum: overtimeMinutesSum,
          vacationPaidDays: vacationPaidDays,
          vacationEnjoyedDays: vacationEnjoyedDays,
          vacationReservedDays: vacationReservedDays,
          permissionWithPayDays: permissionWithPayDays,
          permissionWithoutPayDays: permissionWithoutPayDays,
          disabilityDays: disabilityDays,
          permissionWithPayHours: permissionWithPayHours,
          permissionWithoutPayHours: permissionWithoutPayHours,
          disabilityHours: disabilityHours,
          permissionPendingPrenominaCount: permissionPendingPrenominaCount,
          hasFiscalVacationFootprint: hasFiscalVacationFootprint,
          draftStatus: draft?.draftStatus ?? derivedStatus,
          manualAdjustmentAmount: draft?.manualAdjustmentAmount ?? 0,
          contpaqSalaryAmount: contpaqSalaryAmount,
          contpaqNetAmount: contpaqNetAmount,
          contpaqOvertimeAmount: contpaqOvertimeAmount,
          contpaqVacationAmount: contpaqVacationAmount,
          contpaqAbsenceAmount: contpaqAbsenceAmount,
          contpaqImssAmount: contpaqImssAmount,
          contpaqInfonavitAmount: contpaqInfonavitAmount,
          contpaqFonacotAmount: contpaqFonacotAmount,
          fiscalNetAmount: fiscalNetAmount,
          fiscalImssAmount: fiscalImssAmount,
          fiscalInfonavitAmount: fiscalInfonavitAmount,
          fiscalFonacotAmount: fiscalFonacotAmount,
          fiscalAbsenceAmount: fiscalAbsenceAmount,
          fiscalVacationAmount: fiscalVacationAmount,
          cashSalaryAmount: cashSalaryAmount,
          cashVacationAmount: cashVacationAmount,
          cashIsrAmount: cashIsrAmount,
          transportSupportAmount: transportSupportAmount,
          holidayAmount: holidayAmount,
          overtimeMonetizedAmount: overtimeMonetizedAmount,
          manualBonusAmount: manualBonusAmount,
          cashAbsenceDeductionAmount: cashAbsenceDeductionAmount,
          cashInfonavitDeductionAmount: cashInfonavitDeductionAmount,
          cashFonacotDeductionAmount: cashFonacotDeductionAmount,
          loanDeductionAmount: loanDeductionAmount,
          checkAmount: checkAmount,
          paymentOutsideAmount: paymentOutsideAmount,
          paymentChannel: paymentChannel,
          paymentReference: draft?.paymentReference ?? '',
          notes: draft?.notes ?? '',
        );
      })
      .toList(growable: false);
}

double _suggestPrenominaCashSalaryAmount({
  required double salaryPerceivedWeekly,
  required double contpaqSalaryAmount,
}) {
  if (salaryPerceivedWeekly <= 0) return 0;
  final amount = salaryPerceivedWeekly - contpaqSalaryAmount;
  return amount > 0 ? amount : 0;
}

double _suggestPrenominaCashVacationAmount({
  required double vacationPaidDays,
  required double perceivedDailyRate,
  required double fiscalVacationAmount,
}) {
  if (vacationPaidDays <= 0 || perceivedDailyRate <= 0) return 0;
  final operationalVacation = vacationPaidDays * perceivedDailyRate;
  final amount = operationalVacation - fiscalVacationAmount;
  return amount > 0 ? amount : 0;
}

double _suggestPrenominaCashAbsenceDeductionAmount({
  required double permissionWithoutPayDays,
  required double permissionWithoutPayHours,
  required double perceivedDailyRate,
  required double fiscalAbsenceAmount,
}) {
  if (perceivedDailyRate <= 0) return 0;
  final perceivedHourlyRate = perceivedDailyRate / 8;
  final operationalAbsence =
      (permissionWithoutPayDays * perceivedDailyRate) +
      (permissionWithoutPayHours * perceivedHourlyRate);
  final amount = operationalAbsence - fiscalAbsenceAmount;
  return amount > 0 ? amount : 0;
}

double _suggestPrenominaOvertimeMonetizedAmount({
  required double contpaqOvertimeAmount,
}) {
  return contpaqOvertimeAmount > 0 ? contpaqOvertimeAmount : 0;
}

_HrPrenominaPaymentChannel _suggestPrenominaPaymentChannel({
  required double fiscalNetAmount,
  required double cashSalaryAmount,
  required double cashVacationAmount,
  required double cashIsrAmount,
  required double transportSupportAmount,
  required double holidayAmount,
  required double overtimeMonetizedAmount,
  required double manualBonusAmount,
  required double cashAbsenceDeductionAmount,
  required double cashInfonavitDeductionAmount,
  required double cashFonacotDeductionAmount,
  required double loanDeductionAmount,
  required double checkAmount,
  required double paymentOutsideAmount,
}) {
  final operationalSubtotal =
      cashSalaryAmount +
      cashVacationAmount +
      transportSupportAmount +
      holidayAmount +
      overtimeMonetizedAmount +
      manualBonusAmount;
  final operationalDeductions =
      cashIsrAmount +
      cashAbsenceDeductionAmount +
      cashInfonavitDeductionAmount +
      cashFonacotDeductionAmount +
      loanDeductionAmount;
  final operationalCashTotal = operationalSubtotal - operationalDeductions;
  final hasFiscal = fiscalNetAmount > 0;
  final hasCash = operationalCashTotal > 0;
  final hasCheck = checkAmount > 0;
  final hasOutside = paymentOutsideAmount > 0;
  if (hasCheck && !hasFiscal && !hasCash && !hasOutside) {
    return _HrPrenominaPaymentChannel.cheque;
  }
  if (hasOutside && !hasFiscal && !hasCash && !hasCheck) {
    return _HrPrenominaPaymentChannel.pagoFuera;
  }
  if (hasFiscal && (hasCash || hasCheck || hasOutside)) {
    return _HrPrenominaPaymentChannel.mixto;
  }
  if (hasFiscal) return _HrPrenominaPaymentChannel.deposito;
  if (hasCash) return _HrPrenominaPaymentChannel.efectivo;
  return _HrPrenominaPaymentChannel.pendiente;
}

String _prenominaCellValueForColumn(
  _HrPrenominaSummaryRow row,
  String columnId,
) {
  switch (columnId) {
    case 'id':
      return row.employeeId;
    case 'nombre':
      return row.displayName;
    case 'sueldo':
      return _formatPrenominaMoney(row.salaryWeekly);
    case 'asistencia':
      return row.attendanceSummary;
    case 'vacaciones':
      return row.vacationSummary;
    case 'permisos':
      return row.permissionSummary;
    case 'estado':
      return row.statusLabel;
    default:
      return '';
  }
}

bool _attendanceRecordHasVacationSync(_HrPrenominaAttendanceRecord record) =>
    record.notes.contains(_kHrPrenominaVacationSyncPrefix);

bool _attendanceRecordHasPermissionSync(_HrPrenominaAttendanceRecord record) =>
    record.notes.contains(_kHrPrenominaPermissionSyncPrefix);

bool _attendanceRecordNeedsReview(_HrPrenominaAttendanceRecord record) {
  if (_attendanceRecordHasVacationSync(record) ||
      _attendanceRecordHasPermissionSync(record)) {
    return false;
  }
  if (record.status == _HrPrenominaAttendanceStatus.falto) return true;
  if (record.status == _HrPrenominaAttendanceStatus.noAplica &&
      record.notes.trim().isEmpty) {
    return true;
  }
  return false;
}

bool _attendanceRecordIsReadyForPrenomina(
  _HrPrenominaAttendanceRecord record,
) => !_attendanceRecordNeedsReview(record);

_HrPrenominaDraftStatus _resolveSummaryStatus(_HrPrenominaSummaryRow row) {
  if (row.draftStatus == _HrPrenominaDraftStatus.publicado) {
    return _HrPrenominaDraftStatus.publicado;
  }
  if (row.draftStatus == _HrPrenominaDraftStatus.revisionRh ||
      row.attendanceReviewDays > 0) {
    return _HrPrenominaDraftStatus.revisionRh;
  }
  if (row.draftStatus == _HrPrenominaDraftStatus.listo &&
      row.permissionPendingPrenominaCount == 0) {
    return _HrPrenominaDraftStatus.listo;
  }
  return row.draftStatus;
}

bool _draftNeedsOperationalNote(_HrPrenominaSummaryRow row) {
  return row.attendanceReviewDays > 0 ||
      row.permissionPendingPrenominaCount > 0 ||
      row.hasFiscalVacationFootprint;
}

String _draftOperationalNote(_HrPrenominaSummaryRow row) {
  if (row.attendanceReviewDays > 0) {
    return 'Todavía existen días de asistencia en revisión RH. Esta corrida no debe publicarse como lista hasta cerrar esas incidencias.';
  }
  if (row.permissionPendingPrenominaCount > 0) {
    return 'Existen permisos con huella pendiente hacia prenómina. RH debe validar su estatus antes de cerrar la corrida.';
  }
  return 'La huella fiscal de vacaciones sembrada desde CONTPAQ ya está visible para este colaborador dentro del borrador semanal.';
}

_HrPrenominaDraftStatus _draftStatusFromDb(String value) {
  switch (value) {
    case 'revision_rh':
      return _HrPrenominaDraftStatus.revisionRh;
    case 'listo':
      return _HrPrenominaDraftStatus.listo;
    case 'publicado':
      return _HrPrenominaDraftStatus.publicado;
    case 'borrador':
    default:
      return _HrPrenominaDraftStatus.borrador;
  }
}

String _draftStatusToDb(_HrPrenominaDraftStatus value) {
  switch (value) {
    case _HrPrenominaDraftStatus.revisionRh:
      return 'revision_rh';
    case _HrPrenominaDraftStatus.listo:
      return 'listo';
    case _HrPrenominaDraftStatus.publicado:
      return 'publicado';
    case _HrPrenominaDraftStatus.borrador:
      return 'borrador';
  }
}

_HrPrenominaPaymentChannel _paymentChannelFromDb(String value) {
  return _HrPrenominaPaymentChannel.values.firstWhere(
    (item) => item.name == value,
    orElse: () => _HrPrenominaPaymentChannel.pendiente,
  );
}

String _draftMoneyText(double value) {
  if (value == 0) return '';
  return value.toStringAsFixed(2);
}

double? _parsePrenominaNullableNumber(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

double _parsePrenominaImportedAmount(String? raw) {
  final text = (raw ?? '').trim().replaceAll(',', '');
  if (text.isEmpty) return 0;
  return double.tryParse(text) ?? 0;
}

double? _parsePrenominaDraftText(String value) {
  final normalized = value.trim().replaceAll(r'$', '').replaceAll(',', '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

bool _isPrenominaMoneyInputValid(String value) {
  return value.trim().isEmpty || _parsePrenominaDraftText(value) != null;
}

DateTime? _parsePrenominaDbDate(Object? raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

double _parsePrenominaNumber(Object? raw) {
  if (raw is num) return raw.toDouble();
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return 0;
  return double.tryParse(text) ?? 0;
}

int _asPrenominaInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString().trim()) ?? 0;
}

String _describePrenominaImportPeriod(_HrPrenominaImportLotLite lot) {
  final raw = lot.periodLabel.trim();
  if (raw.isEmpty) return 'Periodo no detectado';
  if (lot.source == _HrPrenominaImportSource.ngteco) {
    final segments = raw.split('→').map((part) => part.trim()).toList();
    if (segments.length == 2) {
      final first = _parsePrenominaUsImportDate(segments[0]);
      final second = _parsePrenominaUsImportDate(segments[1]);
      if (first != null && second != null) {
        final ordered = [first, second]..sort();
        return '${_formatPrenominaDateLabel(ordered.first)} - ${_formatPrenominaDateLabel(ordered.last)}';
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

DateTime? _parsePrenominaUsImportDate(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (month == null || day == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatPrenominaDateLabel(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}

String _formatPrenominaMoney(double value) {
  if (value == 0) return '--';
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final decimals = parts[1];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final reverseIndex = whole.length - i;
    buffer.write(whole[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(',');
  }
  return '\$${buffer.toString()}.$decimals';
}

String _formatPrenominaMoneyZero(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final decimals = parts[1];
  final negative = whole.startsWith('-');
  final digits = negative ? whole.substring(1) : whole;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final reverseIndex = digits.length - i;
    buffer.write(digits[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(',');
  }
  final prefix = negative ? '-\$' : '\$';
  return '$prefix${buffer.toString()}.$decimals';
}

String _formatPrenominaSignedMoney(double value) {
  if (value == 0) return '\$0.00';
  final absValue = _formatPrenominaMoneyZero(value.abs());
  return value > 0 ? '+$absValue' : absValue.replaceFirst('\$', '-\$');
}

String _formatPrenominaDays(double value) {
  if (value == 0) return '--';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _formatPrenominaMinutesAsHourRatio(int minutes) =>
    '${(minutes / 60).toStringAsFixed(2)} h';

String _snakeToLowerCamel(String value) {
  final parts = value.split('_').where((item) => item.isNotEmpty).toList();
  if (parts.isEmpty) return value;
  return parts.first +
      parts.skip(1).map((part) {
        if (part.isEmpty) return part;
        return part[0].toUpperCase() + part.substring(1);
      }).join();
}

ButtonStyle _hrPrenominaActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF24103D),
    side: const BorderSide(color: Color(0x66B084FF)),
    backgroundColor: Colors.white.withValues(alpha: 0.76),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

InputDecoration _hrPrenominaFieldDecoration() {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.92),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x55B084FF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF9F6BFF), width: 1.2),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x55B084FF)),
    ),
  );
}

String _fmtPrenominaInt(int value) => value.toString();

class _HrPrenominaPillColorSet {
  final Color background;
  final Color border;
  final Color foreground;

  const _HrPrenominaPillColorSet({
    required this.background,
    required this.border,
    required this.foreground,
  });
}

_HrPrenominaPillColorSet _prenominaStatusBadgeColorSet(String label) {
  switch (label) {
    case 'Revisión RH':
      return const _HrPrenominaPillColorSet(
        background: Color(0xFFF4E3EA),
        border: Color(0xFFD69BB3),
        foreground: Color(0xFF7A284C),
      );
    case 'Publicado':
      return const _HrPrenominaPillColorSet(
        background: Color(0xFFDCC5FF),
        border: Color(0xFF8B5CF6),
        foreground: Color(0xFF24103D),
      );
    case 'Listo':
      return const _HrPrenominaPillColorSet(
        background: Color(0xFFEFE4FF),
        border: Color(0xFFB084FF),
        foreground: Color(0xFF6E47A8),
      );
    case 'Borrador':
    default:
      return const _HrPrenominaPillColorSet(
        background: Color(0xFFE8D9FF),
        border: Color(0x66B084FF),
        foreground: Color(0xFF24103D),
      );
  }
}
