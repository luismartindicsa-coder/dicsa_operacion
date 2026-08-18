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
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

const String _kHrPermissionProfilesTable = 'hr_employee_profiles';
const String _kHrPermissionImportLotsTable = 'hr_attendance_import_lots';
const String _kHrPermissionAttendanceDailyRecordsTable =
    'hr_attendance_daily_records';
const String _kHrPermissionEventsTable = 'hr_employee_permission_events';
const String _kHrPermissionAttendanceSyncPrefix = 'Permisos RH:';
const String _kHrPermissionVacationAttendanceSyncPrefix = 'Vacaciones RH:';

const double _kHrPermissionIdW = 84;
const double _kHrPermissionGoceW = 160;
const double _kHrPermissionSinGoceW = 160;
const double _kHrPermissionIncapacidadW = 160;
const double _kHrPermissionStatusW = 150;
const double _kHrPermissionActionsW = 118;

class HumanResourcesPermissionsPage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesPermissionsPage({super.key, this.instantOpen = false});

  @override
  State<HumanResourcesPermissionsPage> createState() =>
      _HumanResourcesPermissionsPageState();
}

enum _HrPermissionRowAction { open }

class _HumanResourcesPermissionsPageState
    extends State<HumanResourcesPermissionsPage> {
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

  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'hrPermissionRows');
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

  List<_HrPermissionEmployeeMaster> _employees =
      const <_HrPermissionEmployeeMaster>[];
  List<_HrPermissionImportLotLite> _importLots =
      const <_HrPermissionImportLotLite>[];
  List<_HrPermissionEventRecord> _events = const <_HrPermissionEventRecord>[];
  List<_HrPermissionSummaryRow> _allRows = const <_HrPermissionSummaryRow>[];
  List<_HrPermissionSummaryRow> _visibleRows =
      const <_HrPermissionSummaryRow>[];

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
            .from(_kHrPermissionProfilesTable)
            .select(
              'id,nombre,empresa,horario,dias_labora,labor_schedules,fecha_ingreso,fecha_alta,salario,salario_real_percibido',
            )
            .order('id')
            .range(from, to),
      );
      final importLotsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrPermissionImportLotsTable)
            .select('id,source,file_name,imported_at,period_label')
            .order('imported_at', ascending: false)
            .range(from, to),
      );
      List<dynamic> eventsResult = const <dynamic>[];
      try {
        eventsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrPermissionEventsTable)
              .select()
              .order('start_date')
              .order('created_at')
              .range(from, to),
        );
      } catch (_) {
        eventsResult = const <dynamic>[];
      }

      final employees =
          employeesResult
              .map((raw) => Map<String, dynamic>.from(raw))
              .map(_HrPermissionEmployeeMaster.fromRow)
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
          .map(_HrPermissionImportLotLite.fromRow)
          .toList(growable: false);

      final events = eventsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPermissionEventRecord.fromRow)
          .toList(growable: false);

      if (!mounted) return;
      _employees = employees;
      _importLots = importLots;
      _events = events;
      _rebuildRows();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _rebuildRows() {
    final ngtecoLot = _latestLotBySource(
      _importLots,
      _HrPermissionImportSource.ngteco,
    );
    final contpaqLot = _latestLotBySource(
      _importLots,
      _HrPermissionImportSource.contpaq,
    );
    final periodLabel = _resolveActivePermissionPeriodLabel(
      ngtecoLot: ngtecoLot,
      contpaqLot: contpaqLot,
    );
    final periodEvents = _events
        .where((event) => event.attendancePeriodLabel == periodLabel)
        .toList(growable: false);
    final rows = _buildPermissionSummaryRows(
      employees: _employees,
      events: periodEvents,
    );
    final filteredRows = _applyPermissionFilters(rows);
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
      gridColumnCount: _kPermissionGridColumns.length,
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

  List<_HrPermissionSummaryRow> _applyPermissionFilters(
    List<_HrPermissionSummaryRow> rows,
  ) {
    if (_columnFilters.isEmpty) return rows;
    return rows
        .where((row) {
          for (final entry in _columnFilters.entries) {
            if (entry.value.isEmpty) continue;
            final value = _permissionCellValueForColumn(row, entry.key);
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

  Future<void> _openSummaryRow(_HrPermissionSummaryRow row) async {
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
      final result = await showDialog<_HrPermissionEditResult>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _HrPermissionEditDialog(
          row: row,
          periodLabel: _activePeriodLabel,
          canGoPrevious: currentIndex > 0,
          canGoNext: currentIndex < _allRows.length - 1,
        ),
      );
      if (result == null) return;
      await _savePermissionEdits(row: row, result: result);
      switch (result.action) {
        case _HrPermissionEditAction.save:
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrPermissionEditAction.previous:
          if (currentIndex > 0) {
            currentIndex -= 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrPermissionEditAction.next:
          if (currentIndex < _allRows.length - 1) {
            currentIndex += 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
      }
    }
  }

  Future<void> _savePermissionEdits({
    required _HrPermissionSummaryRow row,
    required _HrPermissionEditResult result,
  }) async {
    final client = Supabase.instance.client;
    final existing = _events
        .where(
          (item) =>
              item.employeeId == row.employeeId &&
              item.attendancePeriodLabel == _activePeriodLabel,
        )
        .toList(growable: false);

    final preparedEvents = await _preparePermissionEventsForPersistence(
      row: row,
      events: result.events,
    );

    final nextRecords = preparedEvents
        .where((event) => event.startDate != null && event.endDate != null)
        .map(
          (event) => _HrPermissionEventRecord(
            id: event.id,
            employeeId: row.employeeId,
            employeeName: row.displayName,
            empresa: row.empresa,
            attendancePeriodLabel: event.attendancePeriodLabel.isEmpty
                ? _activePeriodLabel
                : event.attendancePeriodLabel,
            permissionType: event.permissionType,
            requestUnit: event.requestUnit,
            startDate: event.startDate!,
            endDate: event.endDate!,
            startTime: event.startTime,
            endTime: event.endTime,
            quantityDays: event.quantityDays,
            quantityHours: event.quantityHours,
            attendanceSyncStatus: event.attendanceSyncStatus,
            prenominaSyncStatus: event.prenominaSyncStatus,
            impactAttendance: event.impactAttendance,
            impactPrenomina: event.impactPrenomina,
            sourceMode: event.sourceMode,
            status: event.status,
            notes: event.notes,
          ),
        )
        .toList(growable: false);

    final nextIds = nextRecords
        .map((item) => item.id)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final previous in existing.where(
      (item) => !nextIds.contains(item.id),
    )) {
      if (previous.id.isEmpty) continue;
      await client
          .from(_kHrPermissionEventsTable)
          .delete()
          .eq('id', previous.id);
    }

    final inserts = nextRecords.where((item) => item.id.isEmpty).toList();
    if (inserts.isNotEmpty) {
      await client
          .from(_kHrPermissionEventsTable)
          .insert(
            inserts.map((item) => item.toInsertRow()).toList(growable: false),
          );
    }

    final updates = nextRecords.where((item) => item.id.isNotEmpty).toList();
    if (updates.isNotEmpty) {
      await client
          .from(_kHrPermissionEventsTable)
          .upsert(
            updates.map((item) => item.toRow()).toList(growable: false),
            onConflict: 'id',
          );
    }

    final refreshedResult = await client
        .from(_kHrPermissionEventsTable)
        .select()
        .eq('employee_id', row.employeeId)
        .eq('attendance_period_label', _activePeriodLabel)
        .order('start_date')
        .order('created_at');
    final refreshed = (refreshedResult as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .map(_HrPermissionEventRecord.fromRow)
        .toList(growable: false);

    _events = [
      for (final event in _events)
        if (!(event.employeeId == row.employeeId &&
            event.attendancePeriodLabel == _activePeriodLabel))
          event,
      ...refreshed,
    ];
    _rebuildRows();
    _showSnack('Permisos de ${row.displayName} actualizados.');
  }

  Future<List<_HrPermissionEventDraft>> _preparePermissionEventsForPersistence({
    required _HrPermissionSummaryRow row,
    required List<_HrPermissionEventDraft> events,
  }) async {
    final client = Supabase.instance.client;
    final employee = _findPermissionEmployeeById(row.employeeId, _employees);
    final ngtecoLot = _latestLotBySource(
      _importLots,
      _HrPermissionImportSource.ngteco,
    );
    final contpaqLot = _latestLotBySource(
      _importLots,
      _HrPermissionImportSource.contpaq,
    );
    final activeAttendancePeriodLabel = _resolveActivePermissionPeriodLabel(
      ngtecoLot: ngtecoLot,
      contpaqLot: contpaqLot,
    );
    final activeAttendanceRange = _resolvePermissionAttendanceActiveRange(
      ngtecoLot: ngtecoLot,
      contpaqLot: contpaqLot,
      activePeriodLabel: activeAttendancePeriodLabel,
    );
    final rawRows = await fetchAllSupabaseRows(
      (from, to) => client
          .from(_kHrPermissionAttendanceDailyRecordsTable)
          .select()
          .eq('employee_id', row.employeeId)
          .order('source_date')
          .order('created_at')
          .range(from, to),
    );
    final attendanceRows = ((rawRows as List?) ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: true);

    final previousSyncedDates = _collectPermissionAppliedDateLabels(row.events);
    final revertUpdates = <Map<String, dynamic>>[];
    for (final attendanceRow in attendanceRows) {
      final sourceDate = (attendanceRow['source_date'] ?? '').toString();
      if (!previousSyncedDates.contains(sourceDate)) continue;
      if (_permissionAttendanceRowHasPunches(attendanceRow)) continue;
      final notes = (attendanceRow['notes'] ?? '').toString();
      if (!notes.contains(_kHrPermissionAttendanceSyncPrefix)) continue;
      final nextNotes = _removePermissionAttendanceNotes(notes);
      final keepsVacation = nextNotes.contains(
        _kHrPermissionVacationAttendanceSyncPrefix,
      );
      final reverted = _copyPermissionAttendanceRowForUpdate(
        attendanceRow,
        status: keepsVacation ? 'no_aplica' : 'falto',
        sourceMode: 'ajuste',
        firstPunch: '',
        lastPunch: '',
        punchTimeline: const <String>[],
        lateMinutes: 0,
        overtimeMinutes: 0,
        notes: nextNotes,
      );
      revertUpdates.add(reverted);
      attendanceRow
        ..['status'] = keepsVacation ? 'no_aplica' : 'falto'
        ..['source_mode'] = 'ajuste'
        ..['first_punch'] = ''
        ..['last_punch'] = ''
        ..['punch_timeline'] = const <String>[]
        ..['late_minutes'] = 0
        ..['overtime_minutes'] = 0
        ..['notes'] = nextNotes;
    }
    if (revertUpdates.isNotEmpty) {
      await client
          .from(_kHrPermissionAttendanceDailyRecordsTable)
          .upsert(
            revertUpdates,
            onConflict: 'period_label,employee_id,source_date',
          );
    }

    final attendanceByPeriodDate = <String, Map<String, dynamic>>{};
    for (final rowMap in attendanceRows) {
      final periodLabel = (rowMap['period_label'] ?? '').toString().trim();
      final sourceDate = (rowMap['source_date'] ?? '').toString();
      if (periodLabel.isEmpty || sourceDate.isEmpty) continue;
      attendanceByPeriodDate['$periodLabel|$sourceDate'] = rowMap;
    }

    for (final event in events) {
      _normalizePermissionEventDraft(event);
      event.attendanceSyncStatus =
          !event.impactAttendance ||
              event.status == _HrPermissionEventStatus.cancelado
          ? _HrPermissionSyncStatus.omitido
          : _HrPermissionSyncStatus.pendiente;
      event.prenominaSyncStatus =
          !event.impactPrenomina ||
              event.status == _HrPermissionEventStatus.cancelado
          ? _HrPermissionSyncStatus.omitido
          : _HrPermissionSyncStatus.pendiente;

      if (!event.impactAttendance ||
          event.status != _HrPermissionEventStatus.aplicado ||
          event.requestUnit != _HrPermissionUnit.dia) {
        continue;
      }

      final sourceDates = _permissionDateRangeLabels(
        event.startDate!,
        event.endDate!,
      );
      if (activeAttendancePeriodLabel.isEmpty ||
          activeAttendanceRange == null) {
        event.attendanceSyncStatus = _HrPermissionSyncStatus.pendiente;
        continue;
      }

      final note = _buildPermissionAttendanceSyncNote(event);
      final syncUpdates = <Map<String, dynamic>>[];
      var appliedAny = false;
      var skippedByPunch = false;
      var blockedByVacation = false;
      final touchedPeriods = <String>{};
      for (final sourceDate in sourceDates) {
        if (!_isPermissionAttendanceDateWithinRange(
          sourceDate,
          activeAttendanceRange,
        )) {
          continue;
        }
        final key = '$activeAttendancePeriodLabel|$sourceDate';
        final attendanceRow = attendanceByPeriodDate[key];
        if (attendanceRow == null) {
          if (employee == null ||
              !_shouldCreatePermissionAttendanceRow(
                employee: employee,
                sourceDate: sourceDate,
              )) {
            continue;
          }
          final created = _buildPermissionAttendanceRow(
            periodLabel: activeAttendancePeriodLabel,
            employeeId: row.employeeId,
            employeeName: row.displayName,
            sourceDate: sourceDate,
            notes: note,
          );
          syncUpdates.add(created);
          attendanceRows.add(created);
          attendanceByPeriodDate[key] = created;
          appliedAny = true;
          touchedPeriods.add(activeAttendancePeriodLabel);
          continue;
        }
        if (_permissionAttendanceRowHasPunches(attendanceRow)) {
          skippedByPunch = true;
          continue;
        }
        final existingNotes = (attendanceRow['notes'] ?? '').toString();
        if (existingNotes.contains(
          _kHrPermissionVacationAttendanceSyncPrefix,
        )) {
          blockedByVacation = true;
          continue;
        }
        final mergedNotes = _mergePermissionAttendanceNotes(
          existingNotes,
          note,
        );
        final updated = _copyPermissionAttendanceRowForUpdate(
          attendanceRow,
          status: 'no_aplica',
          sourceMode: 'ajuste',
          firstPunch: '',
          lastPunch: '',
          punchTimeline: const <String>[],
          lateMinutes: 0,
          overtimeMinutes: 0,
          notes: mergedNotes,
        );
        syncUpdates.add(updated);
        attendanceRow
          ..['status'] = 'no_aplica'
          ..['source_mode'] = 'ajuste'
          ..['first_punch'] = ''
          ..['last_punch'] = ''
          ..['punch_timeline'] = const <String>[]
          ..['late_minutes'] = 0
          ..['overtime_minutes'] = 0
          ..['notes'] = mergedNotes;
        appliedAny = true;
        touchedPeriods.add(
          (attendanceRow['period_label'] ?? '').toString().trim(),
        );
      }
      final touchedPeriodLabels = touchedPeriods.toList(growable: false)
        ..sort();
      event.attendancePeriodLabel = touchedPeriodLabels.join(' · ');
      if (syncUpdates.isNotEmpty) {
        await client
            .from(_kHrPermissionAttendanceDailyRecordsTable)
            .upsert(
              syncUpdates,
              onConflict: 'period_label,employee_id,source_date',
            );
      }
      event.attendanceSyncStatus = appliedAny
          ? _HrPermissionSyncStatus.aplicado
          : skippedByPunch || blockedByVacation
          ? _HrPermissionSyncStatus.omitido
          : _HrPermissionSyncStatus.pendiente;
    }

    return events;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  _HrPermissionSummaryRow? _activeRow() {
    if (_selectedRowId == null) return null;
    for (final row in _allRows) {
      if (row.employeeId == _selectedRowId) return row;
    }
    return null;
  }

  void _handleTapRow(_HrPermissionSummaryRow row, int rowIndex) {
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
    _HrPermissionSummaryRow row,
    int rowIndex,
  ) async {
    _prepareRowSelectionForActions(rowId: row.employeeId, rowIndex: rowIndex);
    final selected = await showContractContextMenu<_HrPermissionRowAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      entries: const [
        ContractMenuEntry(
          value: _HrPermissionRowAction.open,
          label: 'Editar permisos',
          icon: Icons.assignment_turned_in_outlined,
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
            .map((row) => _permissionCellValueForColumn(row, columnId))
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
        centerBuilder: (_, _) => const _HrPermissionHeaderBrand(),
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
                      : _HrPermissionWorkspace(
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
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_menuOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _menuOpen ? 1 : 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _menuOpen = false),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.permissions,
                openPersonnel: _openPersonnel,
                openAttendance: _openAttendance,
                openImportConciliation: _openImportConciliation,
                openVacations: _openVacations,
                openPermissions: () async {},
                openPrenomina: _openPrenomina,
                openNomina: _openNomina,
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.permissions,
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
    _HrPermissionSummaryRow row,
    int rowIndex,
  ) {
    _prepareRowSelectionForActions(rowId: row.employeeId, rowIndex: rowIndex);
  }
}

class _HrPermissionWorkspace extends StatelessWidget {
  final List<_HrPermissionSummaryRow> allRows;
  final List<_HrPermissionSummaryRow> rows;
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
  final void Function(_HrPermissionSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrPermissionSummaryRow row, int rowIndex)
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
    _HrPermissionSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final Future<void> Function(_HrPermissionSummaryRow row) onOpenRow;
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

  const _HrPermissionWorkspace({
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
        ? _kPermissionGridColumns[active.columnIndex.clamp(
                0,
                _kPermissionGridColumns.length - 1,
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
            topBar: _HrPermissionModuleTopBar(
              totalRows: totalRows,
              rows: allRows,
              selectedCount: selectedCount,
              activeCellLabel: activeLabel == null
                  ? null
                  : 'Celda: $activeLabel',
              activePeriodLabel: activePeriodLabel,
              onOpenSelectedRow: () => unawaited(onOpenSelectedRow()),
            ),
            body: _HrPermissionGrid(
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
            footer: _HrPermissionGridFooter(
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

class _HrPermissionGrid extends StatelessWidget {
  final List<_HrPermissionSummaryRow> rows;
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
  final void Function(_HrPermissionSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrPermissionSummaryRow row, int rowIndex)
  onPrepareRowActions;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(_HrPermissionSummaryRow row) onOpenRow;
  final Future<void> Function(
    TapDownDetails details,
    _HrPermissionSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final ValueChanged<String?> onHoverRowChanged;

  const _HrPermissionGrid({
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
                  _HrPermissionGridHeader(
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
                                  const _HrPermissionEmptyState()
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
                                        child: _HrPermissionGridRow(
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

class _HrPermissionEmptyState extends StatelessWidget {
  const _HrPermissionEmptyState();

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
              Icons.assignment_turned_in_outlined,
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
              'Ajusta filtros o registra permisos en el periodo activo para comenzar a operar RH.',
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

class _HrPermissionGridHeader extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;

  const _HrPermissionGridHeader({
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
              width: _kHrPermissionIdW,
              child: _HrPermissionHeaderText(
                'ID',
                style: style,
                active: hasActiveFilter('id'),
                onFilter: () => onOpenFilter('id', 'ID'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HrPermissionHeaderText(
                'NOMBRE',
                style: style,
                active: hasActiveFilter('nombre'),
                onFilter: () => onOpenFilter('nombre', 'Nombre'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPermissionGoceW,
              child: _HrPermissionHeaderText(
                'CON GOCE',
                style: style,
                centered: true,
                active: hasActiveFilter('con_goce'),
                onFilter: () => onOpenFilter('con_goce', 'Con goce'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPermissionSinGoceW,
              child: _HrPermissionHeaderText(
                'SIN GOCE',
                style: style,
                centered: true,
                active: hasActiveFilter('sin_goce'),
                onFilter: () => onOpenFilter('sin_goce', 'Sin goce'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPermissionIncapacidadW,
              child: _HrPermissionHeaderText(
                'INCAPACIDAD',
                style: style,
                centered: true,
                active: hasActiveFilter('incapacidad'),
                onFilter: () => onOpenFilter('incapacidad', 'Incapacidad'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPermissionStatusW,
              child: _HrPermissionHeaderText(
                'ESTADO',
                style: style,
                centered: true,
                active: hasActiveFilter('estado'),
                onFilter: () => onOpenFilter('estado', 'Estado'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrPermissionActionsW,
              child: const _HrPermissionHeaderText(
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

class _HrPermissionHeaderText extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool centered;
  final bool active;
  final VoidCallback? onFilter;

  const _HrPermissionHeaderText(
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

class _HrPermissionGridRow extends StatelessWidget {
  final _HrPermissionSummaryRow row;
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

  const _HrPermissionGridRow({
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
                        width: _kHrPermissionIdW,
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
                        child: Text(
                          row.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPermissionGoceW,
                        child: Text(
                          row.withPaySummary,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPermissionSinGoceW,
                        child: Text(
                          row.withoutPaySummary,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPermissionIncapacidadW,
                        child: Text(
                          row.disabilitySummary,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPermissionStatusW,
                        child: Text(
                          row.statusLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: _permissionStatusColor(row.statusLabel),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _kHrPermissionActionsW,
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
                                EditableRowActionsButton<
                                  _HrPermissionRowAction
                                >(
                                  tooltip: 'Acciones de permisos',
                                  iconColor: hasSelection
                                      ? Colors.white
                                      : const Color(0xFF6E47A8),
                                  onBeforeOpen: onPrepareActionsMenu,
                                  entries: const [
                                    ContractMenuEntry(
                                      value: _HrPermissionRowAction.open,
                                      label: 'Editar permisos',
                                      icon: Icons.assignment_turned_in_outlined,
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

class _HrPermissionModuleTopBar extends StatelessWidget {
  final int totalRows;
  final List<_HrPermissionSummaryRow> rows;
  final int selectedCount;
  final String? activeCellLabel;
  final String activePeriodLabel;
  final VoidCallback onOpenSelectedRow;

  const _HrPermissionModuleTopBar({
    required this.totalRows,
    required this.rows,
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
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Permisos',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: const Color(0xFFF0E6FF).withValues(alpha: 0.56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB794FF),
                    foregroundColor: const Color(0xFF24103D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onPressed: totalRows == 0 ? null : onOpenSelectedRow,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Editar permisos'),
                ),
                const SizedBox(width: 12),
                _HrPermissionSoftPill(label: '$totalRows colaboradores'),
                const Spacer(),
                Text(
                  [
                    'Selección: $selectedCount',
                    activeCellLabel,
                    if (activePeriodLabel.isNotEmpty)
                      'Periodo: $activePeriodLabel',
                  ].whereType<String>().join(' · '),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 520,
            child: _HrPermissionMetricCard(totalRows: totalRows, rows: rows),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HrPermissionMetricCard extends StatelessWidget {
  final int totalRows;
  final List<_HrPermissionSummaryRow> rows;

  const _HrPermissionMetricCard({required this.totalRows, required this.rows});

  @override
  Widget build(BuildContext context) {
    final allEvents = rows.expand((row) => row.events).toList(growable: false);
    final attendanceReady = allEvents
        .where(_permissionEventCountsAsAttendanceApplied)
        .length;
    final attendanceReview = allEvents
        .where(_permissionEventCountsAsAttendanceReview)
        .length;
    final prenominaPending = allEvents
        .where(_permissionEventCountsAsPrenominaPending)
        .length;
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
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
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
                'PERMISOS RH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6E47A8),
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                '$totalRows',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24103D),
                  height: 1,
                ),
              ),
              Text(
                'Filtrado ($totalRows registros)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6E47A8).withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                _HrPermissionMetricPill(
                  label: 'Asistencia lista: $attendanceReady',
                ),
                _HrPermissionMetricPill(
                  label: 'Revisión RH: $attendanceReview',
                ),
                _HrPermissionMetricPill(
                  label: 'Prenómina pendiente: $prenominaPending',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HrPermissionSoftPill extends StatelessWidget {
  final String label;

  const _HrPermissionSoftPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HrPermissionMetricPill extends StatelessWidget {
  final String label;

  const _HrPermissionMetricPill({required this.label});

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

class _HrPermissionGridFooter extends StatelessWidget {
  final int rows;
  final int totalRows;
  final int selectedCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HrPermissionGridFooter({
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
                style: _hrPermissionActionOutlinedButtonStyle(),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${_fmtPermissionInt(currentPage + 1)} de ${_fmtPermissionInt(totalPages)}',
              ),
              OutlinedButton.icon(
                style: _hrPermissionActionOutlinedButtonStyle(),
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
                  decoration: _hrPermissionFieldDecoration(),
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
              Text('Mostrando: ${_fmtPermissionInt(rows)}'),
              Text('Total: ${_fmtPermissionInt(totalRows)}'),
              Text('Selección: ${_fmtPermissionInt(selectedCount)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrPermissionHeaderBrand extends StatelessWidget {
  const _HrPermissionHeaderBrand();

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
              'Permisos',
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

enum _HrPermissionEditAction { save, previous, next }

class _HrPermissionEditResult {
  final _HrPermissionEditAction action;
  final List<_HrPermissionEventDraft> events;

  const _HrPermissionEditResult({required this.action, required this.events});
}

class _HrPermissionEditDialog extends StatefulWidget {
  final _HrPermissionSummaryRow row;
  final String periodLabel;
  final bool canGoPrevious;
  final bool canGoNext;

  const _HrPermissionEditDialog({
    required this.row,
    required this.periodLabel,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  State<_HrPermissionEditDialog> createState() =>
      _HrPermissionEditDialogState();
}

class _HrPermissionEditDialogState extends State<_HrPermissionEditDialog> {
  final FocusNode _dialogFocusNode = FocusNode(
    debugLabel: 'hrPermissionDialog',
  );
  late final List<_HrPermissionEventDraft> _events = widget.row.events
      .map((event) => event.toDraft())
      .toList(growable: true);

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

  void _save([_HrPermissionEditAction action = _HrPermissionEditAction.save]) {
    Navigator.of(context).pop(
      _HrPermissionEditResult(
        action: action,
        events: _events
            .where((event) => event.startDate != null && event.endDate != null)
            .toList(growable: false),
      ),
    );
  }

  void _addEvent() {
    setState(() {
      _events.add(
        _HrPermissionEventDraft(
          localId: 'manual_${DateTime.now().microsecondsSinceEpoch}',
          permissionType: _HrPermissionType.permisoConGoce,
          requestUnit: _HrPermissionUnit.dia,
          startDate: _resolveInitialDialogDate(widget.periodLabel),
          endDate: _resolveInitialDialogDate(widget.periodLabel),
          quantityDays: 1,
          quantityHours: 0,
          attendanceSyncStatus: _HrPermissionSyncStatus.pendiente,
          prenominaSyncStatus: _HrPermissionSyncStatus.pendiente,
          impactAttendance: true,
          impactPrenomina: false,
          sourceMode: 'manual',
          status: _HrPermissionEventStatus.pendiente,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final withPayCount = _events
        .where(
          (event) => event.permissionType == _HrPermissionType.permisoConGoce,
        )
        .length;
    final withoutPayCount = _events
        .where(
          (event) => event.permissionType == _HrPermissionType.permisoSinGoce,
        )
        .length;
    final disabilityCount = _events
        .where((event) => event.permissionType == _HrPermissionType.incapacidad)
        .length;
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
          _save(_HrPermissionEditAction.previous);
          return KeyEventResult.handled;
        }
        if (!_hasEditableTextFocus() &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.canGoNext) {
          _save(_HrPermissionEditAction.next);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ContractDialogShell(
        insetPadding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Container(
            width: 1060,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9DAFF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x66B084FF),
                              ),
                            ),
                            child: const Text(
                              'LEDGER DE PERMISOS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6E47A8),
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Permisos del colaborador',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF24103D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Captura operativa de permisos administrativos antes de asistencia, prenómina y nómina.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6E47A8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HrPermissionStatusChip(
                                label: '#${widget.row.employeeId}',
                                complete: true,
                              ),
                              _HrPermissionStatusChip(
                                label: widget.row.empresa.isEmpty
                                    ? 'Empresa pendiente'
                                    : widget.row.empresa,
                                complete: widget.row.empresa.isNotEmpty,
                              ),
                              _HrPermissionStatusChip(
                                label: widget.periodLabel.isEmpty
                                    ? 'Sin periodo activo'
                                    : widget.periodLabel,
                                complete: widget.periodLabel.isNotEmpty,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFF1E6FF,
                        ).withValues(alpha: 0.92),
                        foregroundColor: const Color(0xFF6E47A8),
                        side: const BorderSide(color: Color(0x66B084FF)),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
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
                                _HrPermissionInfoLine(
                                  label: 'Periodo',
                                  value: widget.periodLabel.isEmpty
                                      ? 'Sin periodo activo'
                                      : widget.periodLabel,
                                ),
                                _HrPermissionInfoLine(
                                  label: 'Fecha de ingreso',
                                  value: _formatPermissionDate(
                                    widget.row.fechaIngreso,
                                  ),
                                ),
                                _HrPermissionInfoLine(
                                  label: 'Fecha de alta',
                                  value: _formatPermissionDate(
                                    widget.row.fechaAlta,
                                  ),
                                ),
                                _HrPermissionInfoLine(
                                  label: 'Salario',
                                  value: widget.row.salario.isEmpty
                                      ? 'Pendiente'
                                      : widget.row.salario,
                                ),
                                _HrPermissionInfoLine(
                                  label: 'Salario percibido',
                                  value: widget.row.salarioPercibido.isEmpty
                                      ? 'Pendiente'
                                      : widget.row.salarioPercibido,
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
                                for (
                                  var i = 0;
                                  i < widget.row.workSchedules.length;
                                  i++
                                )
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          i ==
                                              widget.row.workSchedules.length -
                                                  1
                                          ? 0
                                          : 8,
                                    ),
                                    child: _HrPermissionScheduleTile(
                                      title: 'Jornada ${i + 1}',
                                      subtitle: _formatPermissionScheduleOption(
                                        widget.row.workSchedules[i],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _HrPermissionSectionCard(
                              title: 'Resumen del periodo',
                              subtitle:
                                  'Conteos operativos de permisos capturados para la semana activa.',
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _HrPermissionMetricMiniCard(
                                    label: 'CON GOCE',
                                    value: '$withPayCount',
                                  ),
                                  _HrPermissionMetricMiniCard(
                                    label: 'SIN GOCE',
                                    value: '$withoutPayCount',
                                  ),
                                  _HrPermissionMetricMiniCard(
                                    label: 'INCAPACIDAD',
                                    value: '$disabilityCount',
                                  ),
                                  _HrPermissionMetricMiniCard(
                                    label: 'EVENTOS',
                                    value: '${_events.length}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _HrPermissionSectionCard(
                                  title: 'Eventos del colaborador',
                                  subtitle:
                                      'Permisos por día u hora dentro del periodo operativo activo.',
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
                                    onPressed: _addEvent,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Evento'),
                                  ),
                                  child: _events.isEmpty
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
                                            'Todavía no hay permisos capturados. Puedes agregar uno manualmente.',
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
                                              index < _events.length;
                                              index += 1
                                            ) ...[
                                              _HrPermissionEventCard(
                                                draft: _events[index],
                                                onChanged: () =>
                                                    setState(() {}),
                                                onRemove: () => setState(
                                                  () => _events.removeAt(index),
                                                ),
                                              ),
                                              if (index != _events.length - 1)
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
                        child: _HrPermissionInlineNote(
                          icon: Icons.info_outline_rounded,
                          message:
                              'Verifica el tipo de permiso y su rango antes de guardar. El periodo seguirá editable después.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.canGoPrevious) ...[
                        OutlinedButton.icon(
                          style: _hrPermissionActionOutlinedButtonStyle(),
                          onPressed: () =>
                              _save(_HrPermissionEditAction.previous),
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Anterior'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.canGoNext) ...[
                        OutlinedButton.icon(
                          style: _hrPermissionActionOutlinedButtonStyle(),
                          onPressed: () => _save(_HrPermissionEditAction.next),
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Siguiente'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton(
                        style: _hrPermissionActionOutlinedButtonStyle(),
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
                        child: const Text('Guardar permisos'),
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

class _HrPermissionStatusChip extends StatelessWidget {
  final String label;
  final bool complete;

  const _HrPermissionStatusChip({required this.label, required this.complete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: complete ? const Color(0xFFDCC5FF) : const Color(0xFFF7F0FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: complete ? const Color(0xFF9F6BFF) : const Color(0x44B084FF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: complete ? const Color(0xFF24103D) : const Color(0xFF6E47A8),
        ),
      ),
    );
  }
}

class _HrPermissionSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _HrPermissionSectionCard({
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

class _HrPermissionMetricMiniCard extends StatelessWidget {
  final String label;
  final String value;

  const _HrPermissionMetricMiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6E47A8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF24103D),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrPermissionInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _HrPermissionInfoLine({required this.label, required this.value});

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

class _HrPermissionScheduleTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HrPermissionScheduleTile({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Ink(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44B084FF)),
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
    );
  }
}

class _HrPermissionEventCard extends StatelessWidget {
  final _HrPermissionEventDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _HrPermissionEventCard({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    _normalizePermissionEventDraft(draft);
    void commitDraftChange() {
      _normalizePermissionEventDraft(draft);
      onChanged();
    }

    final attendanceLabel = _permissionAttendanceSyncLabel(draft);
    final prenominaLabel = _permissionPrenominaSyncLabel(draft);
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
                      draft.headerLabel,
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
                        _HrPermissionDialogPill(
                          label: draft.sourceMode == 'importado'
                              ? 'Importado'
                              : draft.sourceMode == 'ajuste'
                              ? 'Ajuste'
                              : 'Manual',
                        ),
                        _HrPermissionDialogPill(label: draft.status.label),
                        _HrPermissionSyncPill(
                          label: attendanceLabel,
                          color: _permissionAttendanceSyncColor(draft),
                        ),
                        _HrPermissionSyncPill(
                          label: prenominaLabel,
                          color: _permissionPrenominaSyncColor(draft),
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 210,
                child: _HrPermissionLabeledField(
                  label: 'Tipo',
                  child: _HrPermissionPickerField(
                    value: draft.permissionType.label,
                    onTap: () async {
                      final value =
                          await showSearchablePickerDialog<_HrPermissionType>(
                            context,
                            title: 'Tipo de permiso',
                            initialValue: draft.permissionType,
                            options: _HrPermissionType.values
                                .map(
                                  (item) => SearchablePickerOption(
                                    value: item,
                                    label: item.label,
                                  ),
                                )
                                .toList(growable: false),
                          );
                      if (value == null) return;
                      draft.permissionType = value;
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: _HrPermissionLabeledField(
                  label: 'Estatus',
                  child: _HrPermissionPickerField(
                    value: draft.status.label,
                    onTap: () async {
                      final value =
                          await showSearchablePickerDialog<
                            _HrPermissionEventStatus
                          >(
                            context,
                            title: 'Estatus',
                            initialValue: draft.status,
                            options: _HrPermissionEventStatus.values
                                .map(
                                  (item) => SearchablePickerOption(
                                    value: item,
                                    label: item.label,
                                  ),
                                )
                                .toList(growable: false),
                          );
                      if (value == null) return;
                      draft.status = value;
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: _HrPermissionLabeledField(
                  label: 'Unidad',
                  child: _HrPermissionPickerField(
                    value: draft.requestUnit.label,
                    onTap: () async {
                      final value =
                          await showSearchablePickerDialog<_HrPermissionUnit>(
                            context,
                            title: 'Unidad',
                            initialValue: draft.requestUnit,
                            options: _HrPermissionUnit.values
                                .map(
                                  (item) => SearchablePickerOption(
                                    value: item,
                                    label: item.label,
                                  ),
                                )
                                .toList(growable: false),
                          );
                      if (value == null) return;
                      draft.requestUnit = value;
                      _recalculatePermissionDraft(draft);
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: _HrPermissionLabeledField(
                  label: 'Fecha inicio',
                  child: _HrPermissionDatePickerField(
                    value: _formatPermissionDate(draft.startDate),
                    onTap: () async {
                      final picked = await _pickPermissionDate(
                        context,
                        initialDate:
                            draft.startDate ?? draft.endDate ?? DateTime.now(),
                      );
                      if (picked == null) return;
                      draft.startDate = picked;
                      if (draft.endDate == null ||
                          draft.endDate!.isBefore(picked)) {
                        draft.endDate = picked;
                      }
                      _recalculatePermissionDraft(draft);
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: _HrPermissionLabeledField(
                  label: 'Fecha fin',
                  child: _HrPermissionDatePickerField(
                    value: _formatPermissionDate(draft.endDate),
                    onTap: () async {
                      final picked = await _pickPermissionDate(
                        context,
                        initialDate:
                            draft.endDate ?? draft.startDate ?? DateTime.now(),
                      );
                      if (picked == null) return;
                      draft.endDate = picked;
                      if (draft.startDate == null ||
                          draft.startDate!.isAfter(picked)) {
                        draft.startDate = picked;
                      }
                      _recalculatePermissionDraft(draft);
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: _HrPermissionLabeledField(
                  label: 'Hora inicio',
                  child: TextFormField(
                    initialValue: draft.startTime,
                    decoration: _hrPermissionFieldDecoration(hintText: '08:00'),
                    onChanged: (value) {
                      draft.startTime = value;
                      _recalculatePermissionDraft(draft);
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: _HrPermissionLabeledField(
                  label: 'Hora fin',
                  child: TextFormField(
                    initialValue: draft.endTime,
                    decoration: _hrPermissionFieldDecoration(hintText: '13:00'),
                    onChanged: (value) {
                      draft.endTime = value;
                      _recalculatePermissionDraft(draft);
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: _HrPermissionLabeledField(
                  label: 'Días',
                  child: _HrPermissionComputedField(
                    value: _formatPermissionDays(draft.quantityDays),
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: _HrPermissionLabeledField(
                  label: 'Horas',
                  child: _HrPermissionComputedField(
                    value: _formatPermissionHours(draft.quantityHours),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: _HrPermissionLabeledField(
                  label: 'Asistencia',
                  child: _HrPermissionToggleField(
                    value: draft.impactAttendance,
                    trueLabel: 'Impacta asistencia',
                    falseLabel: 'No impacta asistencia',
                    onChanged: (value) {
                      draft.impactAttendance = value;
                      commitDraftChange();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: _HrPermissionLabeledField(
                  label: 'Prenómina',
                  child: _HrPermissionToggleField(
                    value: draft.impactPrenomina,
                    trueLabel: 'Impacta prenómina',
                    falseLabel: 'No impacta prenómina',
                    onChanged: (value) {
                      draft.impactPrenomina = value;
                      commitDraftChange();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_permissionAttendanceNeedsOperationalNote(draft)) ...[
            _HrPermissionInlineNote(
              icon: Icons.info_outline_rounded,
              message: _permissionAttendanceOperationalNote(draft),
            ),
            const SizedBox(height: 12),
          ],
          _HrPermissionLabeledField(
            label: 'Notas RH',
            child: TextFormField(
              initialValue: draft.notes,
              decoration: _hrPermissionFieldDecoration(),
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

class _HrPermissionDialogPill extends StatelessWidget {
  final String label;

  const _HrPermissionDialogPill({required this.label});

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

class _HrPermissionSyncPill extends StatelessWidget {
  final String label;
  final Color color;

  const _HrPermissionSyncPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _HrPermissionLabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _HrPermissionLabeledField({required this.label, required this.child});

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

class _HrPermissionPickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _HrPermissionPickerField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: _hrPermissionFieldDecoration(),
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

class _HrPermissionDatePickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _HrPermissionDatePickerField({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: _hrPermissionFieldDecoration(),
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
              Icons.calendar_month_rounded,
              size: 18,
              color: Color(0xFF6E47A8),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrPermissionComputedField extends StatelessWidget {
  final String value;

  const _HrPermissionComputedField({required this.value});

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

class _HrPermissionToggleField extends StatelessWidget {
  final bool value;
  final String trueLabel;
  final String falseLabel;
  final ValueChanged<bool> onChanged;

  const _HrPermissionToggleField({
    required this.value,
    required this.trueLabel,
    required this.falseLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFE4D0FF) : const Color(0xFFF8F2FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? const Color(0xFF9F6BFF) : const Color(0x44B084FF),
          ),
        ),
        child: Text(
          value ? trueLabel : falseLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF24103D),
          ),
        ),
      ),
    );
  }
}

class _HrPermissionInlineNote extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HrPermissionInlineNote({required this.icon, required this.message});

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

enum _HrPermissionType {
  permisoConGoce('Permiso con goce'),
  permisoSinGoce('Permiso sin goce'),
  incapacidad('Incapacidad'),
  ajusteRh('Ajuste RH');

  final String label;
  const _HrPermissionType(this.label);
}

enum _HrPermissionUnit {
  dia('Día'),
  hora('Hora');

  final String label;
  const _HrPermissionUnit(this.label);
}

enum _HrPermissionEventStatus {
  pendiente('Pendiente'),
  aprobado('Aprobado'),
  aplicado('Aplicado'),
  cancelado('Cancelado');

  final String label;
  const _HrPermissionEventStatus(this.label);
}

enum _HrPermissionSyncStatus {
  pendiente('Pendiente'),
  aplicado('Aplicado'),
  omitido('Omitido');

  final String label;
  const _HrPermissionSyncStatus(this.label);
}

class _HrPermissionWorkSchedule {
  final String horario;
  final List<String> diasLabora;

  const _HrPermissionWorkSchedule({
    required this.horario,
    required this.diasLabora,
  });
}

class _HrPermissionEmployeeMaster {
  final String employeeId;
  final String displayName;
  final String empresa;
  final List<_HrPermissionWorkSchedule> workSchedules;
  final DateTime? fechaIngreso;
  final DateTime? fechaAlta;
  final String salario;
  final String salarioPercibido;

  const _HrPermissionEmployeeMaster({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.workSchedules,
    required this.fechaIngreso,
    required this.fechaAlta,
    required this.salario,
    required this.salarioPercibido,
  });

  factory _HrPermissionEmployeeMaster.fromRow(Map<String, dynamic> row) {
    return _HrPermissionEmployeeMaster(
      employeeId: (row['id'] ?? '').toString(),
      displayName: (row['nombre'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      workSchedules: _parsePermissionWorkSchedules(
        row['labor_schedules'],
        fallbackHorario: (row['horario'] ?? '').toString(),
        fallbackDiasLabora: _parsePermissionWeekdays(row['dias_labora']),
      ),
      fechaIngreso: _parsePermissionDbDate(row['fecha_ingreso']),
      fechaAlta: _parsePermissionDbDate(row['fecha_alta']),
      salario: _permissionDbNumericToText(row['salario']),
      salarioPercibido: _permissionDbNumericToText(
        row['salario_real_percibido'],
      ),
    );
  }
}

enum _HrPermissionImportSource { ngteco, contpaq }

class _HrPermissionImportLotLite {
  final String id;
  final _HrPermissionImportSource source;
  final String fileName;
  final DateTime importedAt;
  final String periodLabel;

  const _HrPermissionImportLotLite({
    required this.id,
    required this.source,
    required this.fileName,
    required this.importedAt,
    required this.periodLabel,
  });

  factory _HrPermissionImportLotLite.fromRow(Map<String, dynamic> row) {
    final source = _HrPermissionImportSource.values.firstWhere(
      (item) => item.name == (row['source'] ?? '').toString(),
      orElse: () => _HrPermissionImportSource.ngteco,
    );
    return _HrPermissionImportLotLite(
      id: (row['id'] ?? '').toString(),
      source: source,
      fileName: (row['file_name'] ?? '').toString(),
      importedAt:
          DateTime.tryParse((row['imported_at'] ?? '').toString()) ??
          DateTime.now(),
      periodLabel: (row['period_label'] ?? '').toString(),
    );
  }
}

class _HrPermissionEventRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String empresa;
  final String attendancePeriodLabel;
  final _HrPermissionType permissionType;
  final _HrPermissionUnit requestUnit;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final double quantityDays;
  final double quantityHours;
  final _HrPermissionSyncStatus attendanceSyncStatus;
  final _HrPermissionSyncStatus prenominaSyncStatus;
  final bool impactAttendance;
  final bool impactPrenomina;
  final String sourceMode;
  final _HrPermissionEventStatus status;
  final String notes;

  const _HrPermissionEventRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.attendancePeriodLabel,
    required this.permissionType,
    required this.requestUnit,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.quantityDays,
    required this.quantityHours,
    required this.attendanceSyncStatus,
    required this.prenominaSyncStatus,
    required this.impactAttendance,
    required this.impactPrenomina,
    required this.sourceMode,
    required this.status,
    required this.notes,
  });

  factory _HrPermissionEventRecord.fromRow(Map<String, dynamic> row) {
    return _HrPermissionEventRecord(
      id: (row['id'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      attendancePeriodLabel: (row['attendance_period_label'] ?? '').toString(),
      permissionType: _permissionTypeFromDb(row['permission_type']),
      requestUnit: _permissionUnitFromDb(row['request_unit']),
      startDate: _parsePermissionDbDate(row['start_date']) ?? DateTime.now(),
      endDate: _parsePermissionDbDate(row['end_date']) ?? DateTime.now(),
      startTime: (row['start_time'] ?? '').toString(),
      endTime: (row['end_time'] ?? '').toString(),
      quantityDays: _parsePermissionNumber(row['quantity_days']),
      quantityHours: _parsePermissionNumber(row['quantity_hours']),
      attendanceSyncStatus: _permissionSyncStatusFromDb(
        row['attendance_sync_status'],
      ),
      prenominaSyncStatus: _permissionSyncStatusFromDb(
        row['prenomina_sync_status'],
      ),
      impactAttendance: row['impact_attendance'] == true,
      impactPrenomina: row['impact_prenomina'] == true,
      sourceMode: (row['source_mode'] ?? 'manual').toString(),
      status: _permissionEventStatusFromDb(row['status']),
      notes: (row['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toInsertRow() {
    final row = toRow();
    row.remove('id');
    return row;
  }

  Map<String, dynamic> toRow() {
    return {
      if (id.isNotEmpty) 'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'empresa': empresa,
      'attendance_period_label': attendancePeriodLabel,
      'permission_type': permissionType.name,
      'request_unit': requestUnit.name,
      'start_date': _permissionDbDate(startDate),
      'end_date': _permissionDbDate(endDate),
      'start_time': startTime,
      'end_time': endTime,
      'quantity_days': quantityDays,
      'quantity_hours': quantityHours,
      'attendance_sync_status': attendanceSyncStatus.name,
      'prenomina_sync_status': prenominaSyncStatus.name,
      'impact_attendance': impactAttendance,
      'impact_prenomina': impactPrenomina,
      'source_mode': sourceMode,
      'status': status.name,
      'notes': notes,
      'source_snapshot': <String, dynamic>{},
    };
  }

  _HrPermissionEventDraft toDraft() {
    return _HrPermissionEventDraft(
      id: id,
      localId: id.isEmpty
          ? 'draft_${DateTime.now().microsecondsSinceEpoch}'
          : id,
      attendancePeriodLabel: attendancePeriodLabel,
      permissionType: permissionType,
      requestUnit: requestUnit,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      quantityDays: quantityDays,
      quantityHours: quantityHours,
      attendanceSyncStatus: attendanceSyncStatus,
      prenominaSyncStatus: prenominaSyncStatus,
      impactAttendance: impactAttendance,
      impactPrenomina: impactPrenomina,
      sourceMode: sourceMode,
      status: status,
      notes: notes,
    );
  }
}

class _HrPermissionSummaryRow {
  final String employeeId;
  final String displayName;
  final String empresa;
  final DateTime? fechaIngreso;
  final DateTime? fechaAlta;
  final String salario;
  final String salarioPercibido;
  final List<_HrPermissionWorkSchedule> workSchedules;
  final List<_HrPermissionEventRecord> events;
  final String withPaySummary;
  final String withoutPaySummary;
  final String disabilitySummary;
  final String statusLabel;

  const _HrPermissionSummaryRow({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.fechaIngreso,
    required this.fechaAlta,
    required this.salario,
    required this.salarioPercibido,
    required this.workSchedules,
    required this.events,
    required this.withPaySummary,
    required this.withoutPaySummary,
    required this.disabilitySummary,
    required this.statusLabel,
  });
}

class _HrPermissionEventDraft {
  final String id;
  final String localId;
  String attendancePeriodLabel;
  _HrPermissionType permissionType;
  _HrPermissionUnit requestUnit;
  DateTime? startDate;
  DateTime? endDate;
  String startTime;
  String endTime;
  double quantityDays;
  double quantityHours;
  _HrPermissionSyncStatus attendanceSyncStatus;
  _HrPermissionSyncStatus prenominaSyncStatus;
  bool impactAttendance;
  bool impactPrenomina;
  String sourceMode;
  _HrPermissionEventStatus status;
  String notes;

  _HrPermissionEventDraft({
    this.id = '',
    required this.localId,
    this.attendancePeriodLabel = '',
    required this.permissionType,
    required this.requestUnit,
    this.startDate,
    this.endDate,
    this.startTime = '',
    this.endTime = '',
    this.quantityDays = 0,
    this.quantityHours = 0,
    this.attendanceSyncStatus = _HrPermissionSyncStatus.pendiente,
    this.prenominaSyncStatus = _HrPermissionSyncStatus.pendiente,
    this.impactAttendance = true,
    this.impactPrenomina = false,
    this.sourceMode = 'manual',
    this.status = _HrPermissionEventStatus.pendiente,
    this.notes = '',
  });

  String get headerLabel {
    final dateLabel = startDate == null
        ? 'Sin fecha'
        : _formatPermissionDate(startDate);
    return '${permissionType.label} · $dateLabel';
  }
}

const List<_HrPermissionGridColumn> _kPermissionGridColumns = [
  _HrPermissionGridColumn(id: 'id', label: 'ID'),
  _HrPermissionGridColumn(id: 'nombre', label: 'Nombre'),
  _HrPermissionGridColumn(id: 'con_goce', label: 'Con goce'),
  _HrPermissionGridColumn(id: 'sin_goce', label: 'Sin goce'),
  _HrPermissionGridColumn(id: 'incapacidad', label: 'Incapacidad'),
  _HrPermissionGridColumn(id: 'estado', label: 'Estado'),
  _HrPermissionGridColumn(id: 'acciones', label: 'Acciones'),
];

class _HrPermissionGridColumn {
  final String id;
  final String label;

  const _HrPermissionGridColumn({required this.id, required this.label});
}

List<_HrPermissionSummaryRow> _buildPermissionSummaryRows({
  required List<_HrPermissionEmployeeMaster> employees,
  required List<_HrPermissionEventRecord> events,
}) {
  final eventsByEmployee = <String, List<_HrPermissionEventRecord>>{};
  for (final event in events) {
    eventsByEmployee
        .putIfAbsent(event.employeeId, () => <_HrPermissionEventRecord>[])
        .add(event);
  }

  return employees
      .map((employee) {
        final employeeEvents = List<_HrPermissionEventRecord>.from(
          eventsByEmployee[employee.employeeId] ?? const [],
        )..sort((a, b) => a.startDate.compareTo(b.startDate));
        final withPay = employeeEvents
            .where(
              (event) =>
                  event.permissionType == _HrPermissionType.permisoConGoce,
            )
            .toList(growable: false);
        final withoutPay = employeeEvents
            .where(
              (event) =>
                  event.permissionType == _HrPermissionType.permisoSinGoce,
            )
            .toList(growable: false);
        final disability = employeeEvents
            .where(
              (event) => event.permissionType == _HrPermissionType.incapacidad,
            )
            .toList(growable: false);

        return _HrPermissionSummaryRow(
          employeeId: employee.employeeId,
          displayName: employee.displayName,
          empresa: employee.empresa,
          fechaIngreso: employee.fechaIngreso,
          fechaAlta: employee.fechaAlta,
          salario: employee.salario,
          salarioPercibido: employee.salarioPercibido,
          workSchedules: employee.workSchedules,
          events: employeeEvents,
          withPaySummary: _summarizePermissionBucket(withPay),
          withoutPaySummary: _summarizePermissionBucket(withoutPay),
          disabilitySummary: _summarizePermissionBucket(disability),
          statusLabel: _resolvePermissionSummaryStatus(employeeEvents),
        );
      })
      .toList(growable: false);
}

String _summarizePermissionBucket(List<_HrPermissionEventRecord> events) {
  if (events.isEmpty) return '--';
  final days = events.fold<double>(0, (sum, event) => sum + event.quantityDays);
  final hours = events.fold<double>(
    0,
    (sum, event) => sum + event.quantityHours,
  );
  final parts = <String>[];
  if (days > 0) parts.add('${_trimPermissionNumber(days)} d');
  if (hours > 0) parts.add('${_trimPermissionNumber(hours)} h');
  if (parts.isEmpty) parts.add('${events.length} ev');
  return parts.join(' · ');
}

String _resolvePermissionSummaryStatus(List<_HrPermissionEventRecord> events) {
  if (events.isEmpty) return 'Sin captura';
  if (events.any(_permissionEventCountsAsAttendanceReview)) {
    return 'Revisión RH';
  }
  if (events.any(
    (event) => event.status == _HrPermissionEventStatus.pendiente,
  )) {
    return 'Pendiente';
  }
  if (events.any(
    (event) => event.status == _HrPermissionEventStatus.aprobado,
  )) {
    return 'Aprobado';
  }
  if (events.any(_permissionEventCountsAsAttendancePending)) {
    return 'Pendiente asistencia';
  }
  if (events.any(_permissionEventCountsAsPrenominaPending)) {
    return 'Pendiente prenómina';
  }
  if (events.any(
    (event) => event.status == _HrPermissionEventStatus.aplicado,
  )) {
    return 'Aplicado';
  }
  return 'Cancelado';
}

String _permissionCellValueForColumn(
  _HrPermissionSummaryRow row,
  String columnId,
) {
  switch (columnId) {
    case 'id':
      return row.employeeId;
    case 'nombre':
      return row.displayName;
    case 'con_goce':
      return row.withPaySummary;
    case 'sin_goce':
      return row.withoutPaySummary;
    case 'incapacidad':
      return row.disabilitySummary;
    case 'estado':
      return row.statusLabel;
    default:
      return '';
  }
}

_HrPermissionImportLotLite? _latestLotBySource(
  List<_HrPermissionImportLotLite> lots,
  _HrPermissionImportSource source,
) {
  for (final lot in lots) {
    if (lot.source == source) return lot;
  }
  return null;
}

String _resolveActivePermissionPeriodLabel({
  _HrPermissionImportLotLite? ngtecoLot,
  _HrPermissionImportLotLite? contpaqLot,
}) {
  if (contpaqLot != null && contpaqLot.periodLabel.trim().isNotEmpty) {
    return _describePermissionImportPeriod(contpaqLot);
  }
  if (ngtecoLot != null && ngtecoLot.periodLabel.trim().isNotEmpty) {
    return _describePermissionImportPeriod(ngtecoLot);
  }
  return '';
}

List<_HrPermissionWorkSchedule> _parsePermissionWorkSchedules(
  Object? raw, {
  required String fallbackHorario,
  required List<String> fallbackDiasLabora,
}) {
  final output = <_HrPermissionWorkSchedule>[];
  if (raw is List) {
    for (final item in raw) {
      final map = _asMap(item);
      final horario = (map['horario'] ?? '').toString().trim();
      final dias = _parsePermissionWeekdays(map['dias_labora']);
      if (horario.isEmpty && dias.isEmpty) continue;
      output.add(_HrPermissionWorkSchedule(horario: horario, diasLabora: dias));
    }
  }
  if (output.isEmpty &&
      (fallbackHorario.trim().isNotEmpty || fallbackDiasLabora.isNotEmpty)) {
    output.add(
      _HrPermissionWorkSchedule(
        horario: fallbackHorario.trim(),
        diasLabora: fallbackDiasLabora,
      ),
    );
  }
  return output;
}

List<String> _parsePermissionWeekdays(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return const <String>[];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _formatPermissionScheduleOption(_HrPermissionWorkSchedule schedule) {
  final horario = schedule.horario.trim().isEmpty
      ? 'Horario pendiente'
      : schedule.horario.trim();
  final dias = schedule.diasLabora.isEmpty
      ? 'Días pendientes'
      : schedule.diasLabora.join(', ');
  return '$horario · $dias';
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

DateTime? _parsePermissionDbDate(Object? raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String? _permissionDbDate(DateTime? value) {
  if (value == null) return null;
  return value.toIso8601String().split('T').first;
}

double _parsePermissionNumber(Object? raw) {
  if (raw is num) return raw.toDouble();
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return 0;
  return double.tryParse(text) ?? 0;
}

String _permissionDbNumericToText(Object? raw) {
  if (raw == null) return '';
  if (raw is num) return _trimPermissionNumber(raw.toDouble());
  return raw.toString();
}

String _trimPermissionNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  if (fixed.endsWith('0')) return fixed.substring(0, fixed.length - 1);
  return fixed;
}

String _formatPermissionDate(DateTime? date) {
  if (date == null) return 'Pendiente';
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatPermissionDays(double value) =>
    value <= 0 ? '--' : '${_trimPermissionNumber(value)} d';

String _formatPermissionHours(double value) =>
    value <= 0 ? '--' : '${_trimPermissionNumber(value)} h';

bool _permissionEventHasAttendanceSyncTarget(_HrPermissionEventRecord event) {
  return event.impactAttendance &&
      event.status == _HrPermissionEventStatus.aplicado &&
      event.requestUnit == _HrPermissionUnit.dia;
}

bool _permissionEventCountsAsAttendanceApplied(_HrPermissionEventRecord event) {
  return _permissionEventHasAttendanceSyncTarget(event) &&
      event.attendanceSyncStatus == _HrPermissionSyncStatus.aplicado;
}

bool _permissionEventCountsAsAttendancePending(_HrPermissionEventRecord event) {
  return _permissionEventHasAttendanceSyncTarget(event) &&
      event.attendanceSyncStatus == _HrPermissionSyncStatus.pendiente;
}

bool _permissionEventCountsAsAttendanceReview(_HrPermissionEventRecord event) {
  return _permissionEventHasAttendanceSyncTarget(event) &&
      event.attendanceSyncStatus == _HrPermissionSyncStatus.omitido;
}

bool _permissionEventCountsAsPrenominaPending(_HrPermissionEventRecord event) {
  return event.impactPrenomina &&
      event.status != _HrPermissionEventStatus.cancelado &&
      event.prenominaSyncStatus == _HrPermissionSyncStatus.pendiente;
}

String _permissionAttendanceSyncLabel(_HrPermissionEventDraft draft) {
  if (!draft.impactAttendance) return 'Asistencia: Sin impacto';
  if (draft.status == _HrPermissionEventStatus.cancelado) {
    return 'Asistencia: Omitido';
  }
  if (draft.status != _HrPermissionEventStatus.aplicado) {
    return 'Asistencia: Pendiente';
  }
  if (draft.requestUnit != _HrPermissionUnit.dia) {
    return 'Asistencia: Manual';
  }
  return 'Asistencia: ${draft.attendanceSyncStatus.label}';
}

String _permissionPrenominaSyncLabel(_HrPermissionEventDraft draft) {
  if (!draft.impactPrenomina) return 'Prenómina: Sin impacto';
  if (draft.status == _HrPermissionEventStatus.cancelado) {
    return 'Prenómina: Omitido';
  }
  return 'Prenómina: ${draft.prenominaSyncStatus.label}';
}

Color _permissionAttendanceSyncColor(_HrPermissionEventDraft draft) {
  if (!draft.impactAttendance) return const Color(0xFF6E47A8);
  if (draft.status == _HrPermissionEventStatus.cancelado) {
    return const Color(0xFF9B1C31);
  }
  if (draft.status != _HrPermissionEventStatus.aplicado) {
    return const Color(0xFF9A5B00);
  }
  if (draft.requestUnit != _HrPermissionUnit.dia) {
    return const Color(0xFF6E47A8);
  }
  switch (draft.attendanceSyncStatus) {
    case _HrPermissionSyncStatus.pendiente:
      return const Color(0xFF9A5B00);
    case _HrPermissionSyncStatus.aplicado:
      return const Color(0xFF13795B);
    case _HrPermissionSyncStatus.omitido:
      return const Color(0xFF9B1C31);
  }
}

Color _permissionPrenominaSyncColor(_HrPermissionEventDraft draft) {
  if (!draft.impactPrenomina) return const Color(0xFF6E47A8);
  if (draft.status == _HrPermissionEventStatus.cancelado) {
    return const Color(0xFF9B1C31);
  }
  switch (draft.prenominaSyncStatus) {
    case _HrPermissionSyncStatus.pendiente:
      return const Color(0xFF6E47A8);
    case _HrPermissionSyncStatus.aplicado:
      return const Color(0xFF13795B);
    case _HrPermissionSyncStatus.omitido:
      return const Color(0xFF9B1C31);
  }
}

bool _permissionAttendanceNeedsOperationalNote(_HrPermissionEventDraft draft) {
  return (draft.impactAttendance &&
          draft.requestUnit == _HrPermissionUnit.hora) ||
      (draft.impactAttendance &&
          draft.status == _HrPermissionEventStatus.aplicado &&
          draft.requestUnit == _HrPermissionUnit.dia &&
          draft.attendanceSyncStatus == _HrPermissionSyncStatus.omitido);
}

String _permissionAttendanceOperationalNote(_HrPermissionEventDraft draft) {
  if (draft.impactAttendance && draft.requestUnit == _HrPermissionUnit.hora) {
    return 'Los permisos por hora quedan trazados para RH y prenómina, pero no cierran automáticamente el día en Asistencia.';
  }
  return 'Este permiso aplicado requiere revisión RH en Asistencia porque no se pudo sincronizar automáticamente sobre el día correspondiente.';
}

Color _permissionStatusColor(String label) {
  switch (label) {
    case 'Pendiente':
      return const Color(0xFF9A5B00);
    case 'Aprobado':
      return const Color(0xFF6E47A8);
    case 'Pendiente asistencia':
      return const Color(0xFF8A4B00);
    case 'Pendiente prenómina':
      return const Color(0xFF6E47A8);
    case 'Aplicado':
      return const Color(0xFF13795B);
    case 'Revisión RH':
      return const Color(0xFF9B1C31);
    case 'Cancelado':
      return const Color(0xFF9B1C31);
    default:
      return const Color(0xFF6E47A8);
  }
}

int _fmtPermissionInt(int value) => value;

InputDecoration _hrPermissionFieldDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
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

ButtonStyle _hrPermissionActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF24103D),
    side: const BorderSide(color: Color(0x66B084FF)),
    backgroundColor: Colors.white.withValues(alpha: 0.76),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

_HrPermissionType _permissionTypeFromDb(Object? raw) {
  final key = (raw ?? '').toString();
  return _HrPermissionType.values.firstWhere(
    (item) => item.name == key,
    orElse: () => _HrPermissionType.permisoConGoce,
  );
}

_HrPermissionUnit _permissionUnitFromDb(Object? raw) {
  final key = (raw ?? '').toString();
  return _HrPermissionUnit.values.firstWhere(
    (item) => item.name == key,
    orElse: () => _HrPermissionUnit.dia,
  );
}

_HrPermissionEventStatus _permissionEventStatusFromDb(Object? raw) {
  final key = (raw ?? '').toString();
  return _HrPermissionEventStatus.values.firstWhere(
    (item) => item.name == key,
    orElse: () => _HrPermissionEventStatus.pendiente,
  );
}

_HrPermissionSyncStatus _permissionSyncStatusFromDb(Object? raw) {
  final key = (raw ?? '').toString();
  return _HrPermissionSyncStatus.values.firstWhere(
    (item) => item.name == key,
    orElse: () => _HrPermissionSyncStatus.pendiente,
  );
}

Future<DateTime?> _pickPermissionDate(
  BuildContext context, {
  required DateTime initialDate,
}) {
  final safeInitial = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );
  return showDatePicker(
    context: context,
    initialDate: safeInitial,
    firstDate: DateTime(2000, 1, 1),
    lastDate: DateTime(2035, 12, 31),
  );
}

DateTime _resolveInitialDialogDate(String periodLabel) {
  final range = RegExp(
    r'(\d{2})\/(\d{2})\/(\d{4})',
  ).allMatches(periodLabel).toList();
  if (range.isNotEmpty) {
    final last = range.last;
    final day = int.tryParse(last.group(1) ?? '') ?? DateTime.now().day;
    final month = int.tryParse(last.group(2) ?? '') ?? DateTime.now().month;
    final year = int.tryParse(last.group(3) ?? '') ?? DateTime.now().year;
    return DateTime(year, month, day);
  }
  return DateTime.now();
}

void _recalculatePermissionDraft(_HrPermissionEventDraft draft) {
  if (draft.requestUnit == _HrPermissionUnit.dia) {
    if (draft.startDate != null && draft.endDate != null) {
      final difference = draft.endDate!.difference(draft.startDate!).inDays;
      draft.quantityDays = difference >= 0 ? difference + 1 : 0;
    } else {
      draft.quantityDays = 0;
    }
    draft.quantityHours = 0;
    return;
  }
  draft.quantityDays = 0;
  final start = _parsePermissionTime(draft.startTime);
  final end = _parsePermissionTime(draft.endTime);
  if (start == null || end == null) {
    draft.quantityHours = 0;
    return;
  }
  var minutes = (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
  if (minutes < 0) minutes += 24 * 60;
  draft.quantityHours = minutes / 60;
}

TimeOfDay? _parsePermissionTime(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

void _normalizePermissionEventDraft(_HrPermissionEventDraft draft) {
  if (draft.startDate != null &&
      draft.endDate != null &&
      draft.endDate!.isBefore(draft.startDate!)) {
    draft.endDate = draft.startDate;
  }
  _recalculatePermissionDraft(draft);
  draft.attendanceSyncStatus =
      !draft.impactAttendance ||
          draft.status == _HrPermissionEventStatus.cancelado
      ? _HrPermissionSyncStatus.omitido
      : _HrPermissionSyncStatus.pendiente;
  draft.prenominaSyncStatus =
      !draft.impactPrenomina ||
          draft.status == _HrPermissionEventStatus.cancelado
      ? _HrPermissionSyncStatus.omitido
      : _HrPermissionSyncStatus.pendiente;
}

_HrPermissionEmployeeMaster? _findPermissionEmployeeById(
  String employeeId,
  List<_HrPermissionEmployeeMaster> employees,
) {
  for (final employee in employees) {
    if (employee.employeeId == employeeId) return employee;
  }
  return null;
}

DateTimeRange? _resolvePermissionAttendanceActiveRange({
  required _HrPermissionImportLotLite? ngtecoLot,
  required _HrPermissionImportLotLite? contpaqLot,
  required String activePeriodLabel,
}) {
  return _extractPermissionAttendanceDateRangeFromPeriodLabel(
        activePeriodLabel,
      ) ??
      _extractPermissionAttendanceDateRangeFromPeriodLabel(
        contpaqLot?.periodLabel ?? '',
      ) ??
      _extractPermissionAttendanceDateRangeFromPeriodLabel(
        ngtecoLot?.periodLabel ?? '',
      );
}

DateTimeRange? _extractPermissionAttendanceDateRangeFromPeriodLabel(
  String raw,
) {
  final match = RegExp(
    r'(?:del\s+)?(\d{2}/\d{2}/\d{4})\s+(?:al|-)\s+(\d{2}/\d{2}/\d{4})',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final start = _parsePermissionAttendanceDateLabel(match.group(1)!);
  final end = _parsePermissionAttendanceDateLabel(match.group(2)!);
  if (start == null || end == null) return null;
  return DateTimeRange(start: start, end: end);
}

String _describePermissionImportPeriod(_HrPermissionImportLotLite lot) {
  final raw = lot.periodLabel.trim();
  if (raw.isEmpty) return 'Periodo no detectado';
  if (lot.source == _HrPermissionImportSource.ngteco) {
    final segments = raw.split('→').map((part) => part.trim()).toList();
    if (segments.length == 2) {
      final first = _parsePermissionUsImportDate(segments[0]);
      final second = _parsePermissionUsImportDate(segments[1]);
      if (first != null && second != null) {
        final ordered = [first, second]..sort();
        return '${_formatPermissionAttendanceDateLabel(ordered.first)} - ${_formatPermissionAttendanceDateLabel(ordered.last)}';
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

Set<String> _collectPermissionAppliedDateLabels(
  List<_HrPermissionEventRecord> events,
) {
  final labels = <String>{};
  for (final event in events) {
    if (!event.impactAttendance ||
        event.status != _HrPermissionEventStatus.aplicado ||
        event.requestUnit != _HrPermissionUnit.dia) {
      continue;
    }
    labels.addAll(_permissionDateRangeLabels(event.startDate, event.endDate));
  }
  return labels;
}

List<String> _permissionDateRangeLabels(DateTime start, DateTime end) {
  final orderedStart = DateTime(start.year, start.month, start.day);
  final orderedEnd = end.isBefore(start)
      ? orderedStart
      : DateTime(end.year, end.month, end.day);
  final labels = <String>[];
  var cursor = orderedStart;
  while (!cursor.isAfter(orderedEnd)) {
    labels.add(_formatPermissionAttendanceDateLabel(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return labels;
}

bool _isPermissionAttendanceDateWithinRange(
  String sourceDate,
  DateTimeRange? range,
) {
  if (range == null) return true;
  final parsed = _parsePermissionAttendanceDateLabel(sourceDate);
  if (parsed == null) return false;
  return !parsed.isBefore(range.start) && !parsed.isAfter(range.end);
}

bool _shouldCreatePermissionAttendanceRow({
  required _HrPermissionEmployeeMaster employee,
  required String sourceDate,
}) {
  final parsedDate = _parsePermissionAttendanceDateLabel(sourceDate);
  if (parsedDate == null) return false;
  final weekdayLabel = _permissionWeekdayLabel(parsedDate.weekday);
  return _resolvePermissionScheduleForPunchlessDay(
        schedules: employee.workSchedules,
        weekdayLabel: weekdayLabel,
      ) !=
      null;
}

Map<String, dynamic> _buildPermissionAttendanceRow({
  required String periodLabel,
  required String employeeId,
  required String employeeName,
  required String sourceDate,
  required String notes,
}) {
  final parsedDate = _parsePermissionAttendanceDateLabel(sourceDate);
  return {
    'period_label': periodLabel,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'source_date': sourceDate,
    'weekday_label': parsedDate == null
        ? ''
        : _permissionWeekdayLabel(parsedDate.weekday),
    'status': 'no_aplica',
    'source_mode': 'ajuste',
    'first_punch': '',
    'last_punch': '',
    'punch_timeline': const <String>[],
    'late_minutes': 0,
    'overtime_minutes': 0,
    'notes': notes,
  };
}

bool _permissionAttendanceRowHasPunches(Map<String, dynamic> row) {
  final punchTimeline = ((row['punch_timeline'] as List?) ?? const <dynamic>[])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return (row['first_punch'] ?? '').toString().trim().isNotEmpty ||
      (row['last_punch'] ?? '').toString().trim().isNotEmpty ||
      punchTimeline.isNotEmpty;
}

Map<String, dynamic> _copyPermissionAttendanceRowForUpdate(
  Map<String, dynamic> row, {
  required String status,
  required String sourceMode,
  required String firstPunch,
  required String lastPunch,
  required List<String> punchTimeline,
  required int lateMinutes,
  required int overtimeMinutes,
  required String notes,
}) {
  return {
    'id': (row['id'] ?? '').toString(),
    'period_label': (row['period_label'] ?? '').toString(),
    'employee_id': (row['employee_id'] ?? '').toString(),
    'employee_name': (row['employee_name'] ?? '').toString(),
    'source_date': (row['source_date'] ?? '').toString(),
    'weekday_label': (row['weekday_label'] ?? '').toString(),
    'status': status,
    'source_mode': sourceMode,
    'first_punch': firstPunch,
    'last_punch': lastPunch,
    'punch_timeline': punchTimeline,
    'late_minutes': lateMinutes,
    'overtime_minutes': overtimeMinutes,
    'notes': notes,
  };
}

String _buildPermissionAttendanceSyncNote(_HrPermissionEventDraft event) {
  final rangeLabel =
      '${_formatPermissionDate(event.startDate)} → ${_formatPermissionDate(event.endDate)}';
  final quantityLabel = event.requestUnit == _HrPermissionUnit.dia
      ? _formatPermissionDays(event.quantityDays)
      : _formatPermissionHours(event.quantityHours);
  return '$_kHrPermissionAttendanceSyncPrefix ${event.permissionType.label} $rangeLabel ($quantityLabel)';
}

String _mergePermissionAttendanceNotes(String existing, String note) {
  final lines = existing
      .split('\n')
      .map((item) => item.trim())
      .where(
        (item) =>
            item.isNotEmpty &&
            !item.startsWith(_kHrPermissionAttendanceSyncPrefix),
      )
      .toList(growable: true);
  lines.add(note);
  return lines.join('\n');
}

String _removePermissionAttendanceNotes(String existing) {
  return existing
      .split('\n')
      .map((item) => item.trim())
      .where(
        (item) =>
            item.isNotEmpty &&
            !item.startsWith(_kHrPermissionAttendanceSyncPrefix),
      )
      .join('\n');
}

String _permissionWeekdayLabel(int weekday) {
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

class _HrPermissionScheduleDraft {
  final TimeOfDay start;
  final TimeOfDay end;

  const _HrPermissionScheduleDraft({required this.start, required this.end});
}

_HrPermissionScheduleDraft? _parsePermissionSchedule(String? raw) {
  final normalized = (raw ?? '').trim();
  final pattern = RegExp(
    r'^(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})(?:\s*\|\s*comida\s*(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}))?$',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(normalized);
  if (match == null) return null;
  final start = _parsePermissionTime(match.group(1) ?? '');
  final end = _parsePermissionTime(match.group(2) ?? '');
  if (start == null || end == null) return null;
  return _HrPermissionScheduleDraft(start: start, end: end);
}

_HrPermissionScheduleDraft? _resolvePermissionScheduleForPunchlessDay({
  required List<_HrPermissionWorkSchedule> schedules,
  required String weekdayLabel,
}) {
  if (schedules.isEmpty) return null;
  for (final item in schedules) {
    final parsed = _parsePermissionSchedule(item.horario);
    if (parsed == null) continue;
    if (!item.diasLabora.contains(weekdayLabel)) continue;
    return parsed;
  }
  return null;
}

DateTime? _parsePermissionAttendanceDateLabel(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatPermissionAttendanceDateLabel(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}

DateTime? _parsePermissionUsImportDate(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}
