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
import 'human_resources_employee_status.dart';
import 'human_resources_event_period_impacts.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_period_context.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

const String _kHrProfilesTable = 'hr_employee_profiles';
const String _kHrImportLotsTable = 'hr_attendance_import_lots';
const String _kHrAttendanceDailyRecordsTable = 'hr_attendance_daily_records';
const String _kHrAttendanceOperationalPeriodsTable =
    'hr_attendance_operational_periods';
const String _kHrVacationEventsTable = 'hr_employee_vacation_events';
const String _kHrPermissionEventsTable = 'hr_employee_permission_events';
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

enum _HrAttendanceViewMode { diario, semanal }

class _HumanResourcesAttendancePageState
    extends State<HumanResourcesAttendancePage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _loading = true;
  _HrAttendanceViewMode _viewMode = _HrAttendanceViewMode.diario;
  String _activePeriodLabel = '';
  String _selectedPeriodLabel = '';
  List<String> _periodOptions = const <String>[];
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
  final List<_HrAttendanceOperationalPeriod> _operationalPeriods =
      <_HrAttendanceOperationalPeriod>[];
  DateTime? _selectedDailyDate;
  int _dailyRefreshRevision = 0;
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
      final selectedPeriodLabel =
          await HumanResourcesPeriodContext.readSelectedLabel();
      final client = Supabase.instance.client;
      final employeesResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrProfilesTable)
            .select(
              'id,nombre,empresa,horario,dias_labora,labor_schedules,fecha_ingreso,salario',
            )
            .neq('employment_status', kHrEmployeeStatusTerminated)
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
      List<dynamic> operationalPeriodsResult = const <dynamic>[];
      try {
        operationalPeriodsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrAttendanceOperationalPeriodsTable)
              .select()
              .order('start_date', ascending: false)
              .range(from, to),
        );
      } catch (_) {
        // The operational-period migration can be deployed independently.
        operationalPeriodsResult = const <dynamic>[];
      }
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
      final operationalPeriods = operationalPeriodsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrAttendanceOperationalPeriod.fromRow)
          .toList(growable: false);

      var records = recordsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrAttendanceStoredRecord.fromRow)
          .toList(growable: false);

      final periodOptions = _attendancePeriodOptions(
        lots: lots,
        records: records,
        operationalPeriodLabels: operationalPeriods.map(
          (period) => period.periodLabel,
        ),
      );
      final activePeriodLabel = HumanResourcesPeriodContext.resolveSelected(
        selectedLabel: selectedPeriodLabel,
        availableLabels: periodOptions,
      );
      final isOperationalDailyPeriod = operationalPeriods.any(
        (period) => period.periodLabel == activePeriodLabel,
      );
      if (activePeriodLabel.isNotEmpty && !isOperationalDailyPeriod) {
        records = await _synchronizeNgtecoAttendanceBaselines(
          client: client,
          employees: employees,
          lots: lots,
          storedRecords: records,
          periodLabel: activePeriodLabel,
        );
      }

      if (!mounted) return;
      _employees = employees;
      _importLots
        ..clear()
        ..addAll(lots);
      _storedRecords
        ..clear()
        ..addAll(records);
      _operationalPeriods
        ..clear()
        ..addAll(operationalPeriods);
      _selectedPeriodLabel = selectedPeriodLabel;
      _periodOptions = _attendancePeriodOptions(
        lots: lots,
        records: records,
        operationalPeriodLabels: operationalPeriods.map(
          (period) => period.periodLabel,
        ),
      );
      _selectedDailyDate = _resolveDailyDateForPeriod(
        periodLabel: activePeriodLabel,
        current: _selectedDailyDate,
      );
      _rebuildRows();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Persists the NGTeco baseline so Dashboard and Prenomina consume the same
  /// reliable daily rows as Attendance. User-owned records are represented by
  /// the summary builder as `manual` or `ajuste` and are never included here.
  Future<List<_HrAttendanceStoredRecord>>
  _synchronizeNgtecoAttendanceBaselines({
    required SupabaseClient client,
    required List<_HrAttendanceEmployeeMaster> employees,
    required List<_HrAttendanceImportLotLite> lots,
    required List<_HrAttendanceStoredRecord> storedRecords,
    required String periodLabel,
  }) async {
    final ngtecoLot = _attendanceLotForPeriod(
      lots,
      _HrAttendanceImportSource.ngteco,
      periodLabel,
    );
    if (ngtecoLot == null) return storedRecords;

    try {
      final contpaqLot = _attendanceLotForPeriod(
        lots,
        _HrAttendanceImportSource.contpaq,
        periodLabel,
      );
      final summaryRows = _buildAttendanceSummaryRows(
        employees: employees,
        ngtecoLot: ngtecoLot,
        contpaqLot: contpaqLot,
        storedRecords: storedRecords,
        periodLabel: periodLabel,
      );
      final periodRange = _resolveAttendanceActiveRange(
        ngtecoLot: ngtecoLot,
        contpaqLot: contpaqLot,
        activePeriodLabel: periodLabel,
      );
      final existingByDay = <String, List<_HrAttendanceStoredRecord>>{};
      for (final record in storedRecords.where(
        (item) => item.periodLabel == periodLabel,
      )) {
        for (final key in _attendanceStoredRecordKeys(
          record,
          periodRange: periodRange,
        )) {
          existingByDay
              .putIfAbsent(key, () => <_HrAttendanceStoredRecord>[])
              .add(record);
        }
      }

      final repairs = <_HrAttendanceStoredRecord>[];
      for (final row in summaryRows) {
        for (final day in row.days.where(
          (item) => item.sourceMode == 'importado',
        )) {
          final key = _attendanceEmployeeDateKey(
            row.employeeId,
            day.sourceDate,
          );
          final existing =
              existingByDay[key] ?? const <_HrAttendanceStoredRecord>[];
          if (existing.isEmpty) {
            repairs.add(
              _attendanceStoredRecordFromDay(
                employeeId: row.employeeId,
                employeeName: row.displayName,
                periodLabel: periodLabel,
                day: day,
              ),
            );
            continue;
          }
          // Manual capture and explicit RH adjustments are authoritative.
          // NGTeco may refresh its own baseline, but it can never replace a
          // human correction recorded for the same employee and day.
          if (existing.any((record) => record.sourceMode != 'importado')) {
            continue;
          }
          for (final record in existing) {
            if (_attendanceStoredRecordMatchesDay(record, day)) continue;
            repairs.add(
              _attendanceStoredRecordFromDay(
                employeeId: row.employeeId,
                employeeName: row.displayName,
                periodLabel: periodLabel,
                sourceDate: record.sourceDate,
                day: day,
              ),
            );
          }
        }
      }
      if (repairs.isEmpty) return storedRecords;

      await client
          .from(_kHrAttendanceDailyRecordsTable)
          .upsert(
            repairs.map((item) => item.toRow()).toList(growable: false),
            onConflict: 'period_label,employee_id,source_date',
          );
      final refreshedResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrAttendanceDailyRecordsTable)
            .select()
            .eq('period_label', periodLabel)
            .order('source_date')
            .order('created_at')
            .range(from, to),
      );
      final refreshed = refreshedResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrAttendanceStoredRecord.fromRow)
          .toList(growable: false);
      return <_HrAttendanceStoredRecord>[
        ...storedRecords.where((item) => item.periodLabel != periodLabel),
        ...refreshed,
      ];
    } catch (error, stackTrace) {
      // Rendering from the saved NGTeco lot remains available if an older
      // deployment has not yet created the daily-records table. Keep the
      // failure visible in development instead of silently losing the sync.
      debugPrint('No se pudo sincronizar NGTeco en Asistencia: $error');
      debugPrintStack(stackTrace: stackTrace);
      return storedRecords;
    }
  }

  void _rebuildRows() {
    final periodLabel = HumanResourcesPeriodContext.resolveSelected(
      selectedLabel: _selectedPeriodLabel,
      availableLabels: _periodOptions,
    );
    final ngtecoLot = _attendanceLotForPeriod(
      _importLots,
      _HrAttendanceImportSource.ngteco,
      periodLabel,
    );
    final contpaqLot = _attendanceLotForPeriod(
      _importLots,
      _HrAttendanceImportSource.contpaq,
      periodLabel,
    );
    final usesDailyOperationalTruth = _operationalPeriods.any(
      (period) => period.periodLabel == periodLabel,
    );
    final rows = _buildAttendanceSummaryRows(
      employees: _employees,
      ngtecoLot: usesDailyOperationalTruth ? null : ngtecoLot,
      contpaqLot: contpaqLot,
      storedRecords: _storedRecords,
      periodLabel: periodLabel,
      includeImportedStoredRows: !usesDailyOperationalTruth,
      defaultSchedulePending: usesDailyOperationalTruth,
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

  Future<void> _selectPeriod(String periodLabel) async {
    await HumanResourcesPeriodContext.select(periodLabel);
    if (!mounted) return;
    _selectedPeriodLabel = periodLabel;
    _currentPage = 0;
    _selectedDailyDate = _resolveDailyDateForPeriod(
      periodLabel: periodLabel,
      current: _selectedDailyDate,
    );
    _rebuildRows();
  }

  DateTime? _resolveDailyDateForPeriod({
    required String periodLabel,
    required DateTime? current,
  }) {
    final range = _extractDateRangeFromPeriodLabel(periodLabel);
    if (range == null) return current;
    if (current != null &&
        !current.isBefore(range.start) &&
        !current.isAfter(range.end)) {
      return current;
    }
    return range.start;
  }

  bool get _usesDailyOperationalTruth => _operationalPeriods.any(
    (period) => period.periodLabel == _activePeriodLabel,
  );

  Future<void> _selectDailyDate(DateTime date) async {
    final range = _extractDateRangeFromPeriodLabel(_activePeriodLabel);
    if (range == null ||
        date.isBefore(range.start) ||
        date.isAfter(range.end)) {
      _showSnack('La fecha debe pertenecer al periodo activo.');
      return;
    }
    setState(() => _selectedDailyDate = date);
  }

  Future<void> _createOperationalPeriod() async {
    final created = await showDialog<_HrAttendanceOperationalPeriodDraft>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _HrAttendanceCreatePeriodDialog(),
    );
    if (created == null) return;

    try {
      final client = Supabase.instance.client;
      final inserted = await client
          .from(_kHrAttendanceOperationalPeriodsTable)
          .insert(created.toRow())
          .select()
          .single();
      final period = _HrAttendanceOperationalPeriod.fromRow(
        Map<String, dynamic>.from(inserted),
      );
      _operationalPeriods.removeWhere(
        (item) => item.periodLabel == period.periodLabel,
      );
      _operationalPeriods.add(period);
      await _projectPendingHrEventsIntoOperationalPeriod(
        client: client,
        period: period,
      );
      await HumanResourcesPeriodContext.select(period.periodLabel);
      if (!mounted) return;
      setState(() {
        _selectedPeriodLabel = period.periodLabel;
        _selectedDailyDate = period.startDate;
        _viewMode = _HrAttendanceViewMode.diario;
        _currentPage = 0;
      });
      await _loadData();
      if (!mounted) return;
      _showSnack(
        'Periodo operativo creado. Se aplicaron los permisos y vacaciones que correspondan.',
      );
    } on PostgrestException catch (error) {
      _showSnack('No se pudo crear el periodo: ${error.message}');
    }
  }

  /// Makes date-based HR events visible once their operational week exists.
  /// Events are always captured independently from attendance; the period only
  /// determines when their daily impact can be materialized.
  Future<void> _projectPendingHrEventsIntoOperationalPeriod({
    required SupabaseClient client,
    required _HrAttendanceOperationalPeriod period,
  }) async {
    final startDate = _formatAttendanceDatabaseDate(period.startDate);
    final endDate = _formatAttendanceDatabaseDate(period.endDate);

    Future<List<Map<String, dynamic>>> loadEvents(String table) async {
      try {
        final raw = await client
            .from(table)
            .select()
            .lte('start_date', endDate)
            .gte('end_date', startDate);
        return (raw as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(growable: false);
      } catch (error) {
        // Event modules can be deployed separately. Attendance creation must
        // stay available even while one administrative module is unavailable.
        debugPrint('No se pudieron leer eventos de $table: $error');
        return const <Map<String, dynamic>>[];
      }
    }

    final vacationEvents = await loadEvents(_kHrVacationEventsTable);
    final permissionEvents = await loadEvents(_kHrPermissionEventsTable);
    final knownPeriodLabels = _operationalPeriods
        .map((item) => item.periodLabel)
        .toList(growable: false);

    Future<void> syncImpacts({
      required String eventKind,
      required List<Map<String, dynamic>> events,
      required bool vacation,
    }) async {
      final sources = <HrEventPeriodImpactSource>[];
      for (final event in events) {
        final start = _parseAttendanceDateLabel(
          (event['start_date'] ?? '').toString(),
        );
        final end = _parseAttendanceDateLabel(
          (event['end_date'] ?? '').toString(),
        );
        if (start == null || end == null || end.isBefore(start)) continue;
        sources.add(
          HrEventPeriodImpactSource(
            eventId: (event['id'] ?? '').toString(),
            employeeId: (event['employee_id'] ?? '').toString(),
            startDate: start,
            endDate: end,
            daysApplied: _asAttendanceDouble(
              event[vacation ? 'days_applied' : 'quantity_days'],
            ),
            additionalPaidDays: vacation
                ? _asAttendanceDouble(event['additional_paid_days'])
                : 0,
            quantityHours: vacation
                ? 0
                : _asAttendanceDouble(event['quantity_hours']),
            impactAttendance: vacation
                ? event['impact_attendance'] != false
                : event['impact_attendance'] == true,
            impactPrenomina: event['impact_prenomina'] == true,
            isCancelled: (event['status'] ?? '').toString() == 'cancelado',
          ),
        );
      }
      if (sources.isEmpty) return;
      try {
        await syncHrEventPeriodImpacts(
          client: client,
          eventKind: eventKind,
          sources: sources,
          knownPeriodLabels: knownPeriodLabels,
          activePeriodLabel: '',
        );
      } catch (error) {
        debugPrint('No se pudieron sincronizar impactos de $eventKind: $error');
      }
    }

    await syncImpacts(
      eventKind: 'vacacion',
      events: vacationEvents,
      vacation: true,
    );
    await syncImpacts(
      eventKind: 'permiso',
      events: permissionEvents,
      vacation: false,
    );

    final rawAttendance = await client
        .from(_kHrAttendanceDailyRecordsTable)
        .select()
        .eq('period_label', period.periodLabel);
    final existingByEmployeeDay = <String, _HrAttendanceStoredRecord>{};
    for (final raw in rawAttendance as List) {
      final record = _HrAttendanceStoredRecord.fromRow(
        Map<String, dynamic>.from(raw as Map),
      );
      final date = _parseAttendanceDateLabel(record.sourceDate);
      if (date == null) continue;
      existingByEmployeeDay[_attendanceEmployeeDayKey(
            record.employeeId,
            date,
          )] =
          record;
    }
    final employeesById = <String, _HrAttendanceEmployeeMaster>{
      for (final employee in _employees)
        _normalizeAttendanceEmployeeId(employee.employeeId): employee,
    };

    Future<void> projectAttendanceEvents({
      required String table,
      required List<Map<String, dynamic>> events,
      required bool vacation,
    }) async {
      final syncUpdates = <Map<String, dynamic>>[];
      final eventPeriodLabels = <String, String>{};
      for (final event in events) {
        final eventId = (event['id'] ?? '').toString().trim();
        final employeeId = (event['employee_id'] ?? '').toString().trim();
        final start = _parseAttendanceDateLabel(
          (event['start_date'] ?? '').toString(),
        );
        final end = _parseAttendanceDateLabel(
          (event['end_date'] ?? '').toString(),
        );
        if (start == null || end == null || end.isBefore(start)) continue;
        final isApplicable =
            eventId.isNotEmpty &&
            employeeId.isNotEmpty &&
            (event['status'] ?? '').toString() == 'aplicado' &&
            (vacation
                ? event['impact_attendance'] != false
                : event['impact_attendance'] == true) &&
            (vacation || (event['request_unit'] ?? '').toString() == 'dia');
        if (!isApplicable) continue;

        final employee =
            employeesById[_normalizeAttendanceEmployeeId(employeeId)];
        if (employee == null) continue;
        final prefix = vacation
            ? _kHrAttendanceVacationSyncPrefix
            : _kHrAttendancePermissionSyncPrefix;
        final eventLabel = vacation
            ? (event['event_type'] ?? 'vacaciones').toString()
            : (event['permission_type'] ?? 'permiso').toString();
        final note =
            '$prefix $eventLabel · '
            '${_fmtAttendanceDateLabel(start)} - ${_fmtAttendanceDateLabel(end)}';
        final firstDate = start.isBefore(period.startDate)
            ? period.startDate
            : start;
        final lastDate = end.isAfter(period.endDate) ? period.endDate : end;
        var appliedAny = false;

        for (
          var date = DateTime(firstDate.year, firstDate.month, firstDate.day);
          !date.isAfter(lastDate);
          date = date.add(const Duration(days: 1))
        ) {
          final weekdayLabel = _hrWeekdayLabel(date.weekday);
          final schedule = _resolveAttendanceScheduleForPunchlessDay(
            schedules: employee.workSchedules,
            weekdayLabel: weekdayLabel,
          );
          if (schedule == null) continue;

          final key = _attendanceEmployeeDayKey(employeeId, date);
          final existing = existingByEmployeeDay[key];
          if (existing != null &&
              _attendanceRecordIsProtectedFromEventProjection(existing)) {
            continue;
          }
          if (!vacation &&
              existing?.notes.contains(_kHrAttendanceVacationSyncPrefix) ==
                  true) {
            // Vacation has precedence over a day-level permission.
            continue;
          }

          final projected = _HrAttendanceStoredRecord(
            id: existing?.id ?? '',
            periodLabel: period.periodLabel,
            employeeId: employee.employeeId,
            employeeName: employee.displayName,
            sourceDate: _fmtAttendanceDateLabel(date),
            weekdayLabel: weekdayLabel,
            status: _HrAttendanceStatus.noAplica,
            sourceMode: 'ajuste',
            captureOrigin: existing?.captureOrigin ?? 'weekly',
            selectedSchedule: existing?.selectedSchedule ?? '',
            firstPunch: '',
            lastPunch: '',
            punchTimeline: const <String>[],
            lateMinutes: 0,
            overtimeMinutes: 0,
            notes: _mergeAttendanceEventProjectionNote(
              existing?.notes ?? '',
              prefix: prefix,
              note: note,
            ),
          );
          syncUpdates.add(projected.toRow());
          existingByEmployeeDay[key] = projected;
          appliedAny = true;
        }

        if (appliedAny) {
          eventPeriodLabels[eventId] = _appendAttendanceEventPeriodLabel(
            (event['attendance_period_label'] ?? '').toString(),
            period.periodLabel,
          );
        }
      }

      if (syncUpdates.isNotEmpty) {
        await client
            .from(_kHrAttendanceDailyRecordsTable)
            .upsert(
              syncUpdates,
              onConflict: 'period_label,employee_id,source_date',
            );
      }
      for (final entry in eventPeriodLabels.entries) {
        await client
            .from(table)
            .update(<String, dynamic>{
              'attendance_period_label': entry.value,
              'payroll_period_label': entry.value,
              'attendance_sync_status': 'aplicado',
            })
            .eq('id', entry.key);
      }
    }

    await projectAttendanceEvents(
      table: _kHrVacationEventsTable,
      events: vacationEvents,
      vacation: true,
    );
    await projectAttendanceEvents(
      table: _kHrPermissionEventsTable,
      events: permissionEvents,
      vacation: false,
    );
  }

  Future<void> _persistDailyAttendanceRecord(
    _HrAttendanceDailyDraft draft,
  ) async {
    if (!_requireActivePeriod()) return;
    final record = _HrAttendanceStoredRecord(
      id: '',
      periodLabel: _activePeriodLabel,
      employeeId: draft.employee.employeeId,
      employeeName: draft.employee.displayName,
      sourceDate: _fmtAttendanceDateLabel(draft.date),
      weekdayLabel: _hrWeekdayLabel(draft.date.weekday),
      status: draft.status,
      sourceMode: 'manual',
      captureOrigin: 'daily',
      selectedSchedule: draft.selectedSchedule,
      firstPunch: draft.entry,
      lastPunch: draft.exit,
      punchTimeline: draft.manualTimeline,
      lateMinutes: draft.lateMinutes,
      overtimeMinutes: draft.overtimeMinutes,
      notes: draft.notes,
    );
    final client = Supabase.instance.client;
    final saved = await client
        .from(_kHrAttendanceDailyRecordsTable)
        .upsert(
          record.toRow(),
          onConflict: 'period_label,employee_id,source_date',
        )
        .select()
        .single();
    final persisted = _HrAttendanceStoredRecord.fromRow(
      Map<String, dynamic>.from(saved),
    );
    _storedRecords.removeWhere(
      (item) =>
          item.periodLabel == persisted.periodLabel &&
          item.employeeId == persisted.employeeId &&
          _normalizeAttendanceStoredDateLabel(item.sourceDate) ==
              persisted.sourceDate,
    );
    _storedRecords.add(persisted);
    _rebuildRows();
  }

  bool _requireActivePeriod() {
    if (_activePeriodLabel.isNotEmpty) return true;
    _showSnack('Selecciona un periodo operativo antes de editar asistencia.');
    return false;
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
    if (!_requireActivePeriod()) return;
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
    if (!_requireActivePeriod()) return;
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
            captureOrigin: day.captureOrigin,
            selectedSchedule: day.selectedSchedule,
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
    _dailyRefreshRevision += 1;
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
                      : _HrAttendanceTabbedWorkspace(
                          viewMode: _viewMode,
                          onViewModeChanged: (mode) =>
                              setState(() => _viewMode = mode),
                          weeklyChild: _HrAttendanceWorkspace(
                            allRows: _allRows,
                            rows: _visibleRows,
                            totalRows: _allRows.length,
                            selectedCount:
                                _selectionController.selectedIds.length,
                            activePeriodLabel: _activePeriodLabel,
                            periodOptions: _periodOptions,
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
                            onSelectPeriod: _selectPeriod,
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
                          dailyChild: _HrAttendanceDailyGrid(
                            key: ValueKey<String>(
                              '$_activePeriodLabel-${_selectedDailyDate?.toIso8601String()}-$_dailyRefreshRevision',
                            ),
                            activePeriodLabel: _activePeriodLabel,
                            periodOptions: _periodOptions,
                            selectedDate: _selectedDailyDate,
                            employees: _employees,
                            storedRecords: _storedRecords,
                            importLots: _importLots,
                            usesOperationalTruth: _usesDailyOperationalTruth,
                            onSelectPeriod: _selectPeriod,
                            onSelectDate: _selectDailyDate,
                            onCreatePeriod: _createOperationalPeriod,
                            onPersist: _persistDailyAttendanceRecord,
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

class _HrAttendanceTabbedWorkspace extends StatelessWidget {
  final _HrAttendanceViewMode viewMode;
  final ValueChanged<_HrAttendanceViewMode> onViewModeChanged;
  final Widget weeklyChild;
  final Widget dailyChild;

  const _HrAttendanceTabbedWorkspace({
    required this.viewMode,
    required this.onViewModeChanged,
    required this.weeklyChild,
    required this.dailyChild,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Wrap(
            spacing: 8,
            children: [
              _HrAttendanceModeTab(
                label: 'Diario',
                icon: Icons.edit_calendar_rounded,
                selected: viewMode == _HrAttendanceViewMode.diario,
                onTap: () => onViewModeChanged(_HrAttendanceViewMode.diario),
              ),
              _HrAttendanceModeTab(
                label: 'Semanal',
                icon: Icons.calendar_view_week_rounded,
                selected: viewMode == _HrAttendanceViewMode.semanal,
                onTap: () => onViewModeChanged(_HrAttendanceViewMode.semanal),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: viewMode.index,
            children: [dailyChild, weeklyChild],
          ),
        ),
      ],
    );
  }
}

class _HrAttendanceModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _HrAttendanceModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEFE3FF)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF9F6BFF)
                : Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? const Color(0xFF4A207D) : Colors.white,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? const Color(0xFF2B1946) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceDailyGrid extends StatefulWidget {
  final String activePeriodLabel;
  final List<String> periodOptions;
  final DateTime? selectedDate;
  final List<_HrAttendanceEmployeeMaster> employees;
  final List<_HrAttendanceStoredRecord> storedRecords;
  final List<_HrAttendanceImportLotLite> importLots;
  final bool usesOperationalTruth;
  final ValueChanged<String> onSelectPeriod;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function() onCreatePeriod;
  final Future<void> Function(_HrAttendanceDailyDraft draft) onPersist;

  const _HrAttendanceDailyGrid({
    super.key,
    required this.activePeriodLabel,
    required this.periodOptions,
    required this.selectedDate,
    required this.employees,
    required this.storedRecords,
    required this.importLots,
    required this.usesOperationalTruth,
    required this.onSelectPeriod,
    required this.onSelectDate,
    required this.onCreatePeriod,
    required this.onPersist,
  });

  @override
  State<_HrAttendanceDailyGrid> createState() => _HrAttendanceDailyGridState();
}

class _HrAttendanceDailyGridState extends State<_HrAttendanceDailyGrid> {
  static const int _columnCount = 11;
  final FocusNode _gridFocusNode = FocusNode(debugLabel: 'hrAttendanceDaily');
  final GridNavigationController _navigation = GridNavigationController();
  final GridScrollVisibilityCoordinator _visibility =
      GridScrollVisibilityCoordinator();
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  final Map<String, _HrAttendanceDailyDraft> _drafts =
      <String, _HrAttendanceDailyDraft>{};
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _cellFocusNodes = <String, FocusNode>{};
  final Map<String, Timer> _saveTimers = <String, Timer>{};
  final Set<String> _savingDrafts = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _navigation.addListener(_handleGridNavigationChanged);
    _hydrateDrafts();
  }

  @override
  void didUpdateWidget(covariant _HrAttendanceDailyGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePeriodLabel != widget.activePeriodLabel ||
        oldWidget.selectedDate != widget.selectedDate) {
      _disposeEditors();
      _drafts.clear();
      _hydrateDrafts();
    }
  }

  @override
  void dispose() {
    _gridFocusNode.dispose();
    _navigation
      ..removeListener(_handleGridNavigationChanged)
      ..dispose();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    _disposeEditors();
    super.dispose();
  }

  void _handleGridNavigationChanged() {
    if (mounted) setState(() {});
  }

  void _disposeEditors() {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final node in _cellFocusNodes.values) {
      node.dispose();
    }
    _cellFocusNodes.clear();
  }

  DateTimeRange? get _range =>
      _extractDateRangeFromPeriodLabel(widget.activePeriodLabel);

  List<_HrAttendanceDailyDraft> get _rows {
    final rows = _drafts.values.toList(growable: false)
      ..sort((left, right) {
        final leftId = int.tryParse(left.employee.employeeId);
        final rightId = int.tryParse(right.employee.employeeId);
        if (leftId != null && rightId != null) return leftId.compareTo(rightId);
        return left.employee.employeeId.compareTo(right.employee.employeeId);
      });
    return rows;
  }

  void _hydrateDrafts() {
    final date = widget.selectedDate;
    if (date == null || widget.activePeriodLabel.isEmpty) {
      _navigation.configure(
        insertColumnCount: 0,
        gridColumnCount: _columnCount,
        rowCount: 0,
      );
      return;
    }
    final dateLabel = _fmtAttendanceDateLabel(date);
    final weekdayLabel = _hrWeekdayLabel(date.weekday);
    final ngtecoLot = _attendanceLotForPeriod(
      widget.importLots,
      _HrAttendanceImportSource.ngteco,
      widget.activePeriodLabel,
    );
    final entries = ngtecoLot == null
        ? const <_HrAttendanceImportedEntry>[]
        : _filterAttendanceEntriesToRange(
            ngtecoLot.entries,
            DateTimeRange(start: date, end: date),
          );
    final importsByEmployee = _groupAttendanceEntriesByEmployeeDay(entries);
    for (final employee in widget.employees) {
      final resolvedSchedule = _resolveAttendanceScheduleForPunchlessDay(
        schedules: employee.workSchedules,
        weekdayLabel: weekdayLabel,
      );
      final stored = _dailyStoredRecordFor(
        records: widget.storedRecords,
        periodLabel: widget.activePeriodLabel,
        employeeId: employee.employeeId,
        dateLabel: dateLabel,
      );
      // Daily capture is the operational sheet. Keep every active employee
      // visible, even when Personal still lacks a schedule, so RH can resolve
      // that case without waiting for NGTeco or a later configuration change.
      final importKey = _attendanceEmployeeDayKey(
        _normalizeAttendanceEmployeeId(employee.employeeId),
        date,
      );
      final importedTimes =
          (importsByEmployee[importKey] ?? const <_HrAttendanceImportedEntry>[])
              .map(_parseAttendanceImportedDateTime)
              .whereType<DateTime>()
              .toList(growable: false)
            ..sort();
      // Semanal y Diario son dos vistas del mismo registro. Los datos ya
      // capturados en Semanal se muestran como transición en Diario; desde
      // aquí, cualquier ajuste de RH se guarda con origen Diario.
      final storedDraft = stored;
      final scheduleOptions = employee.workSchedules
          .where((item) => _parseAttendanceSchedule(item.horario) != null)
          .toList(growable: false);
      final storedSchedule = storedDraft?.selectedSchedule.trim() ?? '';
      final selectedOption =
          _attendanceWorkScheduleForValue(scheduleOptions, storedSchedule) ??
          _attendanceWorkScheduleMatching(
            scheduleOptions,
            resolvedSchedule?.schedule,
          );
      final activeSchedule = selectedOption == null
          ? (_parseAttendanceSchedule(storedSchedule) ??
                resolvedSchedule?.schedule)
          : _parseAttendanceSchedule(selectedOption.horario);
      final expectedTimes = _attendanceExpectedTimes(activeSchedule);
      _drafts[employee.employeeId] = _HrAttendanceDailyDraft(
        employee: employee,
        date: date,
        schedule: activeSchedule,
        scheduleOptions: scheduleOptions,
        selectedSchedule: selectedOption?.horario ?? storedSchedule,
        status: storedDraft?.status ?? _HrAttendanceStatus.pendiente,
        // The new daily sheet starts from Personal's expected schedule. A
        // stored RH capture always wins, including intentionally blank cells.
        entry: storedDraft?.firstPunch ?? expectedTimes[0],
        lunchExit: storedDraft == null
            ? expectedTimes[1]
            : _manualPunchTimelineValue(
                storedDraft.punchTimeline,
                'Salida comida',
              ),
        lunchEntry: storedDraft == null
            ? expectedTimes[2]
            : _manualPunchTimelineValue(
                storedDraft.punchTimeline,
                'Entrada comida',
              ),
        exit: storedDraft?.lastPunch ?? expectedTimes[3],
        notes: storedDraft?.notes ?? '',
        ngtecoTimes: importedTimes
            .map(_fmtAttendanceTime)
            .toList(growable: false),
      )..recalculate();
    }
    _navigation.configure(
      insertColumnCount: 0,
      gridColumnCount: _columnCount,
      rowCount: _drafts.length,
    );
    if (_drafts.isNotEmpty) {
      _navigation.focusGridCell(rowIndex: 0, columnIndex: 4);
    }
  }

  TextEditingController _controllerFor(
    _HrAttendanceDailyDraft draft,
    String field,
  ) {
    final key = '${draft.id}:$field';
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: draft.valueFor(field)),
    );
  }

  FocusNode _focusFor(_HrAttendanceDailyDraft draft, int columnIndex) {
    final key = '${draft.id}:$columnIndex';
    return _cellFocusNodes.putIfAbsent(
      key,
      () => FocusNode(
        debugLabel: 'hrAttendanceDaily:${draft.id}:$columnIndex',
        onKeyEvent: (_, event) => _handleTimeCellKey(
          draftId: draft.id,
          columnIndex: columnIndex,
          event: event,
        ),
      ),
    );
  }

  KeyEventResult _handleTimeCellKey({
    required String draftId,
    required int columnIndex,
    required KeyEvent event,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final field = _dailyTimeFieldForColumn(columnIndex);
    final controller = field == null ? null : _controllers['$draftId:$field'];
    final rowIndex = _rows.indexWhere((draft) => draft.id == draftId);
    if (controller == null || rowIndex < 0) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final selection = controller.selection;
    final hasSelection = !selection.isCollapsed;
    final caretOffset = selection.extentOffset;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (rowIndex == 0) return KeyEventResult.ignored;
      _moveToCell(rowIndex - 1, columnIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (rowIndex == _rows.length - 1) return KeyEventResult.ignored;
      _moveToCell(rowIndex + 1, columnIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft &&
        !hasSelection &&
        caretOffset <= 0) {
      _moveToCell(rowIndex, columnIndex - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        !hasSelection &&
        caretOffset >= controller.text.length) {
      _moveToCell(rowIndex, columnIndex + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _updateTime(_HrAttendanceDailyDraft draft, String field, String raw) {
    draft.setValue(field, raw);
    if (draft.entry.trim().isNotEmpty || draft.exit.trim().isNotEmpty) {
      draft.status = _HrAttendanceStatus.laboro;
    } else if (draft.status == _HrAttendanceStatus.laboro) {
      draft.status = _HrAttendanceStatus.pendiente;
    }
    draft.recalculate();
    setState(() {});
    _schedulePersist(draft);
  }

  void _updateStatus(_HrAttendanceDailyDraft draft, _HrAttendanceStatus value) {
    draft.status = value;
    draft.recalculate();
    setState(() {});
    _schedulePersist(draft, immediate: true);
  }

  void _selectSchedule(_HrAttendanceDailyDraft draft, int index) {
    if (!draft.selectScheduleAt(index)) return;
    for (final field in const <String>[
      'entry',
      'lunchExit',
      'lunchEntry',
      'exit',
    ]) {
      final controller = _controllers['${draft.id}:$field'];
      if (controller == null) continue;
      final value = draft.valueFor(field);
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {});
    _schedulePersist(draft, immediate: true);
  }

  void _schedulePersist(
    _HrAttendanceDailyDraft draft, {
    bool immediate = false,
  }) {
    final previous = _saveTimers.remove(draft.id);
    previous?.cancel();
    if (!_isDraftReadyToPersist(draft)) return;
    if (immediate) {
      unawaited(_persist(draft));
      return;
    }
    _saveTimers[draft.id] = Timer(
      const Duration(milliseconds: 550),
      () => unawaited(_persist(draft)),
    );
  }

  bool _isDraftReadyToPersist(_HrAttendanceDailyDraft draft) =>
      _isValidAttendanceTimeOrEmpty(draft.entry) &&
      _isValidAttendanceTimeOrEmpty(draft.lunchExit) &&
      _isValidAttendanceTimeOrEmpty(draft.lunchEntry) &&
      _isValidAttendanceTimeOrEmpty(draft.exit);

  Future<void> _persist(_HrAttendanceDailyDraft draft) async {
    if (!_isDraftReadyToPersist(draft)) return;
    setState(() {
      _savingDrafts.add(draft.id);
      _error = null;
    });
    try {
      draft.normalizeTimes();
      for (final field in const <String>[
        'entry',
        'lunchExit',
        'lunchEntry',
        'exit',
      ]) {
        final controller = _controllers['${draft.id}:$field'];
        final normalized = draft.valueFor(field);
        if (controller != null && controller.text != normalized) {
          controller.value = TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
          );
        }
      }
      draft.recalculate();
      await widget.onPersist(draft);
    } catch (_) {
      _error =
          'No se pudo guardar una celda. Verifica tu conexión e inténtalo de nuevo.';
    } finally {
      if (mounted) setState(() => _savingDrafts.remove(draft.id));
    }
  }

  void _moveToCell(int rowIndex, int columnIndex) {
    final rows = _rows;
    if (rows.isEmpty) return;
    final nextRow = rowIndex.clamp(0, rows.length - 1);
    final nextColumn = columnIndex.clamp(0, _columnCount - 1);
    _navigation.focusGridCell(rowIndex: nextRow, columnIndex: nextColumn);
    unawaited(_visibility.ensureGridRowVisible(nextRow, alignment: 0.35));
    final editableColumns = <int>{4, 5, 6, 7};
    if (editableColumns.contains(nextColumn)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final field = _dailyTimeFieldForColumn(nextColumn);
        if (field == null) return;
        _focusFor(rows[nextRow], nextColumn).requestFocus();
        final controller = _controllerFor(rows[nextRow], field);
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
      });
    } else {
      _gridFocusNode.requestFocus();
    }
  }

  Future<void> _pickDate() async {
    final range = _range;
    if (range == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate ?? range.start,
      firstDate: range.start,
      lastDate: range.end,
    );
    if (picked != null) widget.onSelectDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.selectedDate;
    final rows = _rows;
    return ContractGlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Asistencia diaria',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Captura RH es la verdad operativa. NGTeco sólo se muestra para validar diferencias y nunca sobreescribe esta hoja.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD7C6F5),
              ),
            ),
            const SizedBox(height: 12),
            AppGlassToolbarPanel(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  HumanResourcesPeriodSelector(
                    selectedLabel: widget.activePeriodLabel,
                    options: widget.periodOptions,
                    onSelected: widget.onSelectPeriod,
                  ),
                  FilledButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: widget.onCreatePeriod,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Crear periodo'),
                  ),
                  OutlinedButton.icon(
                    style: contractSecondaryButtonStyle(context),
                    onPressed: date == null ? null : _pickDate,
                    icon: const Icon(Icons.today_rounded),
                    label: Text(
                      date == null
                          ? 'Elige un periodo'
                          : _fmtAttendanceDateLabel(date),
                    ),
                  ),
                  if (date != null)
                    _HrAttendanceDailySaveState(
                      saving: _savingDrafts.isNotEmpty,
                      operational: widget.usesOperationalTruth,
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFFCCCB),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: date == null
                  ? const _HrAttendanceDailyEmptyState()
                  : GridKeyboardShell(
                      navigationController: _navigation,
                      focusNode: _gridFocusNode,
                      isEditingText: () =>
                          _cellFocusNodes.values.any((node) => node.hasFocus),
                      onNavigated: (position) =>
                          _moveToCell(position.rowIndex, position.columnIndex),
                      child: _HrAttendanceDailySheet(
                        rows: rows,
                        navigation: _navigation,
                        visibility: _visibility,
                        verticalScroll: _verticalScroll,
                        horizontalScroll: _horizontalScroll,
                        controllerFor: _controllerFor,
                        focusFor: _focusFor,
                        onUpdateTime: _updateTime,
                        onUpdateStatus: _updateStatus,
                        onSelectSchedule: _selectSchedule,
                        onMoveToCell: _moveToCell,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _dailyTimeFieldForColumn(int columnIndex) => switch (columnIndex) {
  4 => 'entry',
  5 => 'lunchExit',
  6 => 'lunchEntry',
  7 => 'exit',
  _ => null,
};

class _HrAttendanceDailySaveState extends StatelessWidget {
  final bool saving;
  final bool operational;
  const _HrAttendanceDailySaveState({
    required this.saving,
    required this.operational,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFEFE3FF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFB794FF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          saving ? Icons.sync_rounded : Icons.cloud_done_rounded,
          size: 17,
          color: const Color(0xFF5B3291),
        ),
        const SizedBox(width: 7),
        Text(
          saving
              ? 'Guardando...'
              : operational
              ? 'Captura RH activa'
              : 'Autoguardado activo',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2B1946),
          ),
        ),
      ],
    ),
  );
}

class _HrAttendanceDailyEmptyState extends StatelessWidget {
  const _HrAttendanceDailyEmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Crea o selecciona un periodo para abrir la captura diaria.',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );
}

class _HrAttendanceDailySheet extends StatelessWidget {
  final List<_HrAttendanceDailyDraft> rows;
  final GridNavigationController navigation;
  final GridScrollVisibilityCoordinator visibility;
  final ScrollController verticalScroll;
  final ScrollController horizontalScroll;
  final TextEditingController Function(_HrAttendanceDailyDraft, String)
  controllerFor;
  final FocusNode Function(_HrAttendanceDailyDraft, int) focusFor;
  final void Function(_HrAttendanceDailyDraft, String, String) onUpdateTime;
  final void Function(_HrAttendanceDailyDraft, _HrAttendanceStatus)
  onUpdateStatus;
  final void Function(_HrAttendanceDailyDraft, int) onSelectSchedule;
  final void Function(int, int) onMoveToCell;

  const _HrAttendanceDailySheet({
    required this.rows,
    required this.navigation,
    required this.visibility,
    required this.verticalScroll,
    required this.horizontalScroll,
    required this.controllerFor,
    required this.focusFor,
    required this.onUpdateTime,
    required this.onUpdateStatus,
    required this.onSelectSchedule,
    required this.onMoveToCell,
  });

  static const List<double> _widths = <double>[
    110,
    72,
    280,
    220,
    114,
    126,
    130,
    114,
    108,
    108,
    138,
  ];
  static const List<String> _headers = <String>[
    'FECHA',
    'ID',
    'NOMBRE',
    'JORNADA',
    'ENTRADA',
    'SALIDA COMIDA',
    'ENTRADA COMIDA',
    'SALIDA',
    'RETARDO',
    'EXTRA',
    'ESTATUS',
  ];

  @override
  Widget build(BuildContext context) {
    final minWidth = _widths.fold<double>(0, (sum, width) => sum + width) + 72;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDDF0E7FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x66B084FF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Scrollbar(
          controller: horizontalScroll,
          child: SingleChildScrollView(
            controller: horizontalScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(minWidth, MediaQuery.sizeOf(context).width - 130),
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: Scrollbar(
                      controller: verticalScroll,
                      child: ListView.builder(
                        controller: verticalScroll,
                        itemCount: rows.length,
                        itemBuilder: (context, index) =>
                            _row(context, rows[index], index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    color: const Color(0xFFF1E9FF),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    child: Row(
      children: [
        for (var index = 0; index < _headers.length; index++)
          SizedBox(
            width: _widths[index],
            child: Text(
              _headers[index],
              textAlign: index < 4 ? TextAlign.left : TextAlign.center,
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

  Widget _row(BuildContext context, _HrAttendanceDailyDraft draft, int index) {
    final activeRow =
        navigation.active.zone == GridNavigationZone.grid &&
        navigation.active.rowIndex == index;
    return Container(
      decoration: BoxDecoration(
        color: activeRow
            ? const Color(0xFF9F6BFF).withValues(alpha: 0.17)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFB68CFF).withValues(alpha: 0.25),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          _readonly(
            _fmtAttendanceDateLabel(draft.date),
            0,
            draft,
            index,
            centered: true,
          ),
          _readonly(draft.employee.employeeId, 1, draft, index, centered: true),
          _readonly(draft.employee.displayName, 2, draft, index),
          _scheduleCell(draft, index),
          _timeCell(context, draft, index, 'entry', 4),
          _timeCell(context, draft, index, 'lunchExit', 5),
          _timeCell(context, draft, index, 'lunchEntry', 6),
          _timeCell(context, draft, index, 'exit', 7),
          _readonly(
            _formatAttendanceMinutesAsHourRatio(draft.lateMinutes),
            8,
            draft,
            index,
            centered: true,
            accent: draft.lateMinutes > 0,
          ),
          _readonly(
            _formatAttendanceMinutesAsHourRatio(draft.overtimeMinutes),
            9,
            draft,
            index,
            centered: true,
            accent: draft.overtimeMinutes > 0,
          ),
          SizedBox(width: _widths[10], child: _statusCell(draft, index)),
        ],
      ),
    );
  }

  Widget _readonly(
    String value,
    int column,
    _HrAttendanceDailyDraft draft,
    int row, {
    bool centered = false,
    bool accent = false,
  }) => SizedBox(
    width: _widths[column],
    child: InkWell(
      key: visibility.keyForCell(
        zone: GridNavigationZone.grid,
        rowIndex: row,
        columnIndex: column,
      ),
      onTap: () => onMoveToCell(row, column),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
        child: Text(
          value.isEmpty ? '—' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: 12.3,
            fontWeight: FontWeight.w800,
            color: accent ? const Color(0xFF7340B3) : const Color(0xFF24103D),
          ),
        ),
      ),
    ),
  );

  Widget _scheduleCell(_HrAttendanceDailyDraft draft, int row) => SizedBox(
    key: visibility.keyForCell(
      zone: GridNavigationZone.grid,
      rowIndex: row,
      columnIndex: 3,
    ),
    width: _widths[3],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft.scheduleOptions.length > 1)
            DropdownButtonFormField<int>(
              key: ValueKey('${draft.id}:${draft.selectedSchedule}'),
              initialValue: draft.selectedScheduleIndex,
              isExpanded: true,
              onChanged: (value) {
                if (value != null) onSelectSchedule(draft, value);
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                filled: true,
                fillColor: const Color(0xFFFBF8FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD7C3FF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD7C3FF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF8B59E7),
                    width: 1.6,
                  ),
                ),
              ),
              hint: Text(
                draft.scheduleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24103D),
                ),
              ),
              items: [
                for (
                  var index = 0;
                  index < draft.scheduleOptions.length;
                  index += 1
                )
                  DropdownMenuItem<int>(
                    value: index,
                    child: Text(
                      'Jornada ${index + 1} · '
                      '${draft.scheduleOptions[index].horario}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF24103D),
              ),
            )
          else
            InkWell(
              onTap: () => onMoveToCell(row, 3),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(
                  draft.scheduleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.3,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24103D),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            draft.ngtecoTimes.isEmpty
                ? 'NGTeco: sin lectura'
                : 'NGTeco: ${draft.ngtecoTimes.join(' · ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF765AA8),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _timeCell(
    BuildContext context,
    _HrAttendanceDailyDraft draft,
    int row,
    String field,
    int column,
  ) {
    final controller = controllerFor(draft, field);
    final focus = focusFor(draft, column);
    return SizedBox(
      width: _widths[column],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Shortcuts(
          // GridKeyboardShell owns these keys outside an editor. Override the
          // editing keys locally so a desktop TextField keeps native cursor
          // movement and deletion while the user captures a punch.
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.backspace):
                DeleteCharacterIntent(forward: false),
            SingleActivator(LogicalKeyboardKey.delete): DeleteCharacterIntent(
              forward: true,
            ),
            SingleActivator(
              LogicalKeyboardKey.arrowLeft,
            ): ExtendSelectionByCharacterIntent(
              forward: false,
              collapseSelection: true,
            ),
            SingleActivator(
              LogicalKeyboardKey.arrowRight,
            ): ExtendSelectionByCharacterIntent(
              forward: true,
              collapseSelection: true,
            ),
          },
          child: TextField(
            key: visibility.keyForCell(
              zone: GridNavigationZone.grid,
              rowIndex: row,
              columnIndex: column,
            ),
            controller: controller,
            focusNode: focus,
            // macOS selects all text in a single-line input by default. A
            // time cell behaves more like a spreadsheet: enter at the end,
            // then let RH move through the digits with the arrow keys.
            selectAllOnFocus: false,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
            onTap: () => onMoveToCell(row, column),
            onChanged: (value) => onUpdateTime(draft, field, value),
            onSubmitted: (_) =>
                onMoveToCell(row, column == 7 ? 10 : column + 1),
            decoration: InputDecoration(
              hintText: 'HH:MM',
              hintStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9D84BB),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              filled: true,
              fillColor: const Color(0xFFFBF8FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD7C3FF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD7C3FF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF8B59E7),
                  width: 1.6,
                ),
              ),
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24103D),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCell(_HrAttendanceDailyDraft draft, int row) => InkWell(
    key: visibility.keyForCell(
      zone: GridNavigationZone.grid,
      rowIndex: row,
      columnIndex: 10,
    ),
    onTap: () => onMoveToCell(row, 10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: DropdownButtonFormField<_HrAttendanceStatus>(
        initialValue: draft.status,
        isExpanded: true,
        onChanged: (value) {
          if (value != null) onUpdateStatus(draft, value);
        },
        items: _HrAttendanceStatus.values
            .map(
              (status) => DropdownMenuItem(
                value: status,
                child: Text(status.label, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 9,
          ),
          filled: true,
          fillColor: _dailyStatusColor(draft.status),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD7C3FF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD7C3FF)),
          ),
        ),
        style: const TextStyle(
          fontSize: 12.2,
          fontWeight: FontWeight.w900,
          color: Color(0xFF24103D),
        ),
      ),
    ),
  );
}

class _HrAttendanceWorkspace extends StatelessWidget {
  final List<_HrAttendanceSummaryRow> allRows;
  final List<_HrAttendanceSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final String activePeriodLabel;
  final List<String> periodOptions;
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
  final ValueChanged<String> onSelectPeriod;
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
    required this.periodOptions,
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
    required this.onSelectPeriod,
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
              activePeriodLabel: activePeriodLabel,
              periodOptions: periodOptions,
              onOpenSelectedRow: () => unawaited(onOpenSelectedRow()),
              onSelectPeriod: onSelectPeriod,
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
  final String activePeriodLabel;
  final List<String> periodOptions;
  final VoidCallback onOpenSelectedRow;
  final ValueChanged<String> onSelectPeriod;

  const _HrAttendanceModuleTopBar({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activeCellLabel,
    required this.activePeriodLabel,
    required this.periodOptions,
    required this.onOpenSelectedRow,
    required this.onSelectPeriod,
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
                  HumanResourcesPeriodSelector(
                    selectedLabel: activePeriodLabel,
                    options: periodOptions,
                    onSelected: onSelectPeriod,
                  ),
                  FilledButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: activePeriodLabel.isEmpty
                        ? null
                        : onOpenSelectedRow,
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
  final TextEditingController _weeklyLateHoursController =
      TextEditingController();
  final TextEditingController _weeklyOvertimeHoursController =
      TextEditingController();
  final TextEditingController _weeklyWorkedDaysController =
      TextEditingController();
  final TextEditingController _weeklyAbsentDaysController =
      TextEditingController();
  int? _selectedWorkScheduleIndex;
  String? _quickAdjustmentFeedback;
  late final List<_HrAttendanceDayDraft> _days = widget.row.days
      .map((day) => day.toDraft())
      .toList(growable: true);

  @override
  void initState() {
    super.initState();
    _applySelectedScheduleToDays();
    _syncWeeklyAdjustmentInputs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    _weeklyLateHoursController.dispose();
    _weeklyOvertimeHoursController.dispose();
    _weeklyWorkedDaysController.dispose();
    _weeklyAbsentDaysController.dispose();
    super.dispose();
  }

  void _syncWeeklyAdjustmentInputs() {
    final lateMinutes = _days.fold<int>(0, (sum, day) => sum + day.lateMinutes);
    final overtimeMinutes = _days.fold<int>(
      0,
      (sum, day) => sum + day.overtimeMinutes,
    );
    _weeklyLateHoursController.text = _formatAttendanceHoursInput(lateMinutes);
    _weeklyOvertimeHoursController.text = _formatAttendanceHoursInput(
      overtimeMinutes,
    );
    _weeklyWorkedDaysController.text = _days
        .where((day) => day.status == _HrAttendanceStatus.laboro)
        .length
        .toString();
    _weeklyAbsentDaysController.text = _days
        .where((day) => day.status == _HrAttendanceStatus.falto)
        .length
        .toString();
  }

  void _applyWeeklyWorkedDaysTotal() {
    _applyWeeklyAttendanceDaysTotal(
      controller: _weeklyWorkedDaysController,
      targetStatus: _HrAttendanceStatus.laboro,
      label: 'Laboró',
    );
  }

  void _applyWeeklyAbsentDaysTotal() {
    _applyWeeklyAttendanceDaysTotal(
      controller: _weeklyAbsentDaysController,
      targetStatus: _HrAttendanceStatus.falto,
      label: 'Faltó',
    );
  }

  void _applyWeeklyAttendanceDaysTotal({
    required TextEditingController controller,
    required _HrAttendanceStatus targetStatus,
    required String label,
  }) {
    final targetCount = int.tryParse(controller.text.trim());
    if (targetCount == null || targetCount < 0) {
      setState(() {
        _quickAdjustmentFeedback =
            'Captura una cantidad válida de días para $label.';
      });
      return;
    }
    final candidates = _days
        .where(
          (day) =>
              day.scheduledStart.trim().isNotEmpty &&
              day.scheduledEnd.trim().isNotEmpty &&
              !_attendanceDraftHasVacationSync(day) &&
              !_attendanceDraftHasPermissionSync(day),
        )
        .toList(growable: false);
    final candidateIds = candidates.map((day) => day.localId).toSet();
    final lockedTargetDays = _days
        .where(
          (day) =>
              !candidateIds.contains(day.localId) && day.status == targetStatus,
        )
        .length;
    final targetCandidatesCount = targetCount - lockedTargetDays;
    if (targetCandidatesCount < 0 ||
        targetCandidatesCount > candidates.length) {
      setState(() {
        _quickAdjustmentFeedback =
            'Este ajuste permite entre $lockedTargetDays y ${lockedTargetDays + candidates.length} día(s) como $label.';
      });
      return;
    }
    final ranked = List<_HrAttendanceDayDraft>.of(candidates)
      ..sort((left, right) {
        final priorityDifference = _attendanceMassStatusPriority(
          left,
          targetStatus,
        ).compareTo(_attendanceMassStatusPriority(right, targetStatus));
        if (priorityDifference != 0) return priorityDifference;
        return left.sourceDate.compareTo(right.sourceDate);
      });
    final selectedIds = ranked
        .take(targetCandidatesCount)
        .map((day) => day.localId)
        .toSet();
    final oppositeStatus = targetStatus == _HrAttendanceStatus.laboro
        ? _HrAttendanceStatus.falto
        : _HrAttendanceStatus.laboro;
    setState(() {
      for (final day in candidates) {
        final nextStatus = selectedIds.contains(day.localId)
            ? targetStatus
            : oppositeStatus;
        if (day.status == nextStatus) continue;
        day.status = nextStatus;
        day.sourceMode = 'ajuste';
        day.captureOrigin = 'weekly';
        if (nextStatus == _HrAttendanceStatus.laboro) {
          if (day.firstPunch.trim().isEmpty) {
            day.firstPunch = day.scheduledStart;
          }
          if (day.lastPunch.trim().isEmpty) {
            day.lastPunch = day.scheduledEnd;
          }
        }
        _recalculateAttendanceDraftMetrics(day);
      }
      _syncWeeklyAdjustmentInputs();
      _quickAdjustmentFeedback =
          '$targetCount día(s) marcado(s) como $label. Vacaciones y permisos se conservaron sin cambios.';
    });
  }

  int _attendanceMassStatusPriority(
    _HrAttendanceDayDraft day,
    _HrAttendanceStatus targetStatus,
  ) {
    if (day.status == targetStatus) return 0;
    final hasImportedPunches =
        _attendanceDraftIsImported(day) &&
        (day.firstPunch.trim().isNotEmpty || day.lastPunch.trim().isNotEmpty);
    if (targetStatus == _HrAttendanceStatus.laboro && hasImportedPunches) {
      return 1;
    }
    final hasNoPunches =
        day.firstPunch.trim().isEmpty && day.lastPunch.trim().isEmpty;
    if (targetStatus == _HrAttendanceStatus.falto && hasNoPunches) return 1;
    return 2;
  }

  void _applyWeeklyLateTotal() {
    _applyWeeklyTotal(
      controller: _weeklyLateHoursController,
      isOvertime: false,
      label: 'retardo',
    );
  }

  void _applyWeeklyOvertimeTotal() {
    _applyWeeklyTotal(
      controller: _weeklyOvertimeHoursController,
      isOvertime: true,
      label: 'horas extra',
    );
  }

  void _applyWeeklyTotal({
    required TextEditingController controller,
    required bool isOvertime,
    required String label,
  }) {
    final totalMinutes = _parseAttendanceHoursInput(controller.text);
    if (totalMinutes == null) {
      setState(() {
        _quickAdjustmentFeedback =
            'Captura un total válido en horas, por ejemplo 6 o 6.50.';
      });
      return;
    }
    final targetDays = _days
        .where(
          (day) =>
              day.status == _HrAttendanceStatus.laboro &&
              day.scheduledStart.trim().isNotEmpty &&
              day.scheduledEnd.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (targetDays.isEmpty) {
      setState(() {
        _quickAdjustmentFeedback =
            'No hay jornadas con estatus Laboró para distribuir el $label.';
      });
      return;
    }
    final allocations = _distributeAttendanceMinutes(
      totalMinutes,
      targetDays.length,
    );
    setState(() {
      for (var index = 0; index < targetDays.length; index += 1) {
        final day = targetDays[index];
        final allocatedMinutes = allocations[index];
        if (isOvertime) {
          day.lastPunch = _attendanceTimePlusMinutes(
            day.scheduledEnd,
            allocatedMinutes,
          );
          if (day.firstPunch.trim().isEmpty) {
            day.firstPunch = day.scheduledStart;
          }
        } else {
          day.firstPunch = _attendanceTimePlusMinutes(
            day.scheduledStart,
            allocatedMinutes,
          );
          if (day.lastPunch.trim().isEmpty) {
            day.lastPunch = day.scheduledEnd;
          }
        }
        day.sourceMode = 'ajuste';
        day.captureOrigin = 'weekly';
        _recalculateAttendanceDraftMetrics(day);
      }
      controller.text = _formatAttendanceHoursInput(totalMinutes);
      _quickAdjustmentFeedback =
          '${_formatAttendanceMinutesAsHourRatio(totalMinutes)} de $label distribuido entre ${targetDays.length} jornada(s).';
    });
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
          status: punchlessSchedule == null
              ? _HrAttendanceStatus.noAplica
              : _HrAttendanceStatus.laboro,
          sourceMode: punchlessSchedule == null ? 'manual' : 'jornada',
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
          firstPunch: punchlessSchedule == null
              ? ''
              : _fmtTimeOfDay(punchlessSchedule.schedule.start),
          lastPunch: punchlessSchedule == null
              ? ''
              : _fmtTimeOfDay(punchlessSchedule.schedule.end),
        ),
      );
      _applySelectedScheduleToDays();
      _days.sort((a, b) {
        final aDate = _parseAttendanceDateLabel(a.sourceDate);
        final bDate = _parseAttendanceDateLabel(b.sourceDate);
        if (aDate != null && bDate != null) return aDate.compareTo(bDate);
        return a.sourceDate.compareTo(b.sourceDate);
      });
      _syncWeeklyAdjustmentInputs();
    });
  }

  bool _hasEditableTextFocus() {
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  void _applySelectedScheduleToDays({bool markAsWeeklyEdit = false}) {
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
      if (markAsWeeklyEdit) day.captureOrigin = 'weekly';
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
    final scheduleDays = _days.where(_attendanceDraftIsScheduleFilled).length;
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
                                      _applySelectedScheduleToDays(
                                        markAsWeeklyEdit: true,
                                      );
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
                                      _applySelectedScheduleToDays(
                                        markAsWeeklyEdit: true,
                                      );
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
                                  'Los totales se calculan por día. Edita Retardo u Horas extra y distribuye desde su card.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _HrAttendanceEditableMetricMiniCard(
                                        label: 'DIAS LABORÓ',
                                        controller: _weeklyWorkedDaysController,
                                        tooltip:
                                            'Captura el total de días laborados y aplícalo en masa. Vacaciones y permisos no se modifican.',
                                        onApply: _applyWeeklyWorkedDaysTotal,
                                        icon: Icons.event_available_rounded,
                                        integerOnly: true,
                                      ),
                                      _HrAttendanceEditableMetricMiniCard(
                                        label: 'DIAS FALTÓ',
                                        controller: _weeklyAbsentDaysController,
                                        tooltip:
                                            'Captura el total de faltas y aplícalo en masa. Vacaciones y permisos no se modifican.',
                                        onApply: _applyWeeklyAbsentDaysTotal,
                                        icon: Icons.event_busy_rounded,
                                        integerOnly: true,
                                      ),
                                      _HrAttendanceEditableMetricMiniCard(
                                        label: 'RETARDO (h)',
                                        controller: _weeklyLateHoursController,
                                        tooltip:
                                            'Captura el total semanal y presiona Enter o aplicar para distribuirlo entre los días laborados.',
                                        onApply: _applyWeeklyLateTotal,
                                        icon: Icons.schedule_rounded,
                                      ),
                                      _HrAttendanceEditableMetricMiniCard(
                                        label: 'HORAS EXTRA (h)',
                                        controller:
                                            _weeklyOvertimeHoursController,
                                        tooltip:
                                            'Captura el total semanal y presiona Enter o aplicar para distribuirlo entre los días laborados.',
                                        onApply: _applyWeeklyOvertimeTotal,
                                        icon: Icons.add_alarm_rounded,
                                      ),
                                      _HrAttendanceMetricMiniCard(
                                        label: 'IMPORTADO',
                                        value: importedDays.toString(),
                                      ),
                                      _HrAttendanceMetricMiniCard(
                                        label: 'JORNADA',
                                        value: scheduleDays.toString(),
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
                                  if (_quickAdjustmentFeedback != null) ...[
                                    const SizedBox(height: 10),
                                    _HrAttendanceInlineNote(
                                      icon: Icons.auto_awesome_rounded,
                                      message:
                                          '${_quickAdjustmentFeedback!} El reparto conserva los fichajes importados y marca los días como Ajuste RH.',
                                    ),
                                  ],
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
                                                onChanged: () => setState(
                                                  _syncWeeklyAdjustmentInputs,
                                                ),
                                                onRemove: () => setState(() {
                                                  _days.removeAt(index);
                                                  _syncWeeklyAdjustmentInputs();
                                                }),
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

class _HrAttendanceEditableMetricMiniCard extends StatelessWidget {
  final String label;
  final String tooltip;
  final TextEditingController controller;
  final VoidCallback onApply;
  final IconData icon;
  final bool integerOnly;

  const _HrAttendanceEditableMetricMiniCard({
    required this.label,
    required this.tooltip,
    required this.controller,
    required this.onApply,
    required this.icon,
    this.integerOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 144,
        height: 58,
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8B5CF6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: integerOnly
                          ? TextInputType.number
                          : const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                      inputFormatters: [
                        integerOnly
                            ? FilteringTextInputFormatter.digitsOnly
                            : FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                      ],
                      onFieldSubmitted: (_) => onApply(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF24103D),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Distribuir total semanal',
                    onPressed: onApply,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(icon, size: 17),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF7C4DCC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ],
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
                              ? 'NGTeco'
                              : draft.sourceMode == 'jornada'
                              ? 'Jornada'
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
                            label: draft.sourceMode == 'importado'
                                ? draft.punchTimeline.join(' · ')
                                : 'RH: ${draft.punchTimeline.join(' · ')}',
                          ),
                        if (draft.ngtecoReferenceTimeline.isNotEmpty &&
                            !_listEquals(
                              draft.punchTimeline,
                              draft.ngtecoReferenceTimeline,
                            ))
                          _HrAttendanceDialogPill(
                            label:
                                'NGTeco: ${draft.ngtecoReferenceTimeline.join(' · ')}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (draft.sourceMode == 'manual' || draft.sourceMode == 'ajuste')
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
                      if (draft.status == value) return;
                      draft.status = value;
                      _markAttendanceDraftAsUserAdjustment(draft);
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
                      if (draft.firstPunch == value) return;
                      draft.firstPunch = value;
                      _markAttendanceDraftAsUserAdjustment(draft);
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
                      if (draft.lastPunch == value) return;
                      draft.lastPunch = value;
                      _markAttendanceDraftAsUserAdjustment(draft);
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
              onChanged: (value) {
                if (draft.notes == value) return;
                draft.notes = value;
                _markAttendanceDraftAsUserAdjustment(draft);
                onChanged();
              },
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
  pendiente('Pendiente'),
  laboro('Laboró'),
  falto('Faltó'),
  noAplica('No aplica');

  final String label;
  const _HrAttendanceStatus(this.label);

  String get databaseValue => switch (this) {
    _HrAttendanceStatus.pendiente => 'pendiente',
    _HrAttendanceStatus.laboro => 'laboro',
    _HrAttendanceStatus.falto => 'falto',
    _HrAttendanceStatus.noAplica => 'no_aplica',
  };

  static _HrAttendanceStatus fromDatabaseValue(String raw) {
    return switch (raw.trim()) {
      'pendiente' => _HrAttendanceStatus.pendiente,
      'laboro' => _HrAttendanceStatus.laboro,
      'falto' => _HrAttendanceStatus.falto,
      'no_aplica' || 'noAplica' => _HrAttendanceStatus.noAplica,
      _ => _HrAttendanceStatus.pendiente,
    };
  }
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

class _HrAttendanceOperationalPeriod {
  final String periodLabel;
  final int? periodNumber;
  final DateTime startDate;
  final DateTime endDate;

  const _HrAttendanceOperationalPeriod({
    required this.periodLabel,
    required this.periodNumber,
    required this.startDate,
    required this.endDate,
  });

  static _HrAttendanceOperationalPeriod fromRow(Map<String, dynamic> row) {
    final start =
        _parseAttendanceDateLabel((row['start_date'] ?? '').toString()) ??
        DateTime.now();
    final end =
        _parseAttendanceDateLabel((row['end_date'] ?? '').toString()) ??
        start.add(const Duration(days: 6));
    return _HrAttendanceOperationalPeriod(
      periodLabel: (row['period_label'] ?? '').toString(),
      periodNumber: _asNullableInt(row['period_number']),
      startDate: start,
      endDate: end,
    );
  }
}

class _HrAttendanceOperationalPeriodDraft {
  final int periodNumber;
  final DateTime startDate;
  final DateTime endDate;

  const _HrAttendanceOperationalPeriodDraft({
    required this.periodNumber,
    required this.startDate,
    required this.endDate,
  });

  String get periodLabel => _formatOperationalAttendancePeriodLabel(
    periodNumber: periodNumber,
    startDate: startDate,
    endDate: endDate,
  );

  Map<String, dynamic> toRow() => <String, dynamic>{
    'period_label': periodLabel,
    'period_number': periodNumber,
    'start_date': _formatAttendanceDatabaseDate(startDate),
    'end_date': _formatAttendanceDatabaseDate(endDate),
  };
}

class _HrAttendanceCreatePeriodDialog extends StatefulWidget {
  const _HrAttendanceCreatePeriodDialog();

  @override
  State<_HrAttendanceCreatePeriodDialog> createState() =>
      _HrAttendanceCreatePeriodDialogState();
}

class _HrAttendanceCreatePeriodDialogState
    extends State<_HrAttendanceCreatePeriodDialog> {
  late final TextEditingController _periodController;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _periodController = TextEditingController();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() => _startDate = selected);
  }

  void _submit() {
    final periodNumber = int.tryParse(_periodController.text.trim());
    if (periodNumber == null || periodNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un número de periodo válido.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _HrAttendanceOperationalPeriodDraft(
        periodNumber: periodNumber,
        startDate: _startDate,
        endDate: _startDate.add(const Duration(days: 6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final endDate = _startDate.add(const Duration(days: 6));
    return ContractDialogShell(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCEB3FF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HumanResourcesCompactDialogHeader(
              title: 'Crear periodo diario',
              contextLabel:
                  'La captura diaria funciona antes de importar NGTeco o CONTPAQ.',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 18),
            const Text(
              'Periodo semanal',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5F3AA2),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _periodController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onSubmitted: (_) => _submit(),
              decoration: _hrAttendanceFieldDecoration().copyWith(
                hintText: 'Ej. 35',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Inicio de semana',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5F3AA2),
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _pickStartDate,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(_fmtAttendanceDateLabel(_startDate)),
            ),
            const SizedBox(height: 8),
            Text(
              'El periodo cerrará el ${_fmtAttendanceDateLabel(endDate)}.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7454A6),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: _submit,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear periodo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceDailyDraft {
  final _HrAttendanceEmployeeMaster employee;
  final DateTime date;
  final List<_HrAttendanceWorkSchedule> scheduleOptions;
  _HrAttendanceScheduleDraft? schedule;
  String selectedSchedule;
  String entry;
  String lunchExit;
  String lunchEntry;
  String exit;
  String notes;
  final List<String> ngtecoTimes;
  _HrAttendanceStatus status;
  int lateMinutes = 0;
  int overtimeMinutes = 0;

  _HrAttendanceDailyDraft({
    required this.employee,
    required this.date,
    required this.schedule,
    required this.scheduleOptions,
    this.selectedSchedule = '',
    required this.status,
    required this.entry,
    required this.lunchExit,
    required this.lunchEntry,
    required this.exit,
    required this.notes,
    required this.ngtecoTimes,
  });

  String get id => '${employee.employeeId}|${_fmtAttendanceDateLabel(date)}';

  int? get selectedScheduleIndex {
    final index = scheduleOptions.indexWhere(
      (item) => item.horario == selectedSchedule,
    );
    return index < 0 ? null : index;
  }

  String get scheduleLabel {
    final value = schedule;
    if (value == null) return 'Jornada pendiente';
    final lunch = value.lunchStart == null || value.lunchEnd == null
        ? ''
        : ' | comida ${_fmtTimeOfDay(value.lunchStart!)} - ${_fmtTimeOfDay(value.lunchEnd!)}';
    return '${_fmtTimeOfDay(value.start)} - ${_fmtTimeOfDay(value.end)}$lunch';
  }

  List<String> get manualTimeline => <String>[
    if (entry.trim().isNotEmpty) 'Entrada ${entry.trim()}',
    if (lunchExit.trim().isNotEmpty) 'Salida comida ${lunchExit.trim()}',
    if (lunchEntry.trim().isNotEmpty) 'Entrada comida ${lunchEntry.trim()}',
    if (exit.trim().isNotEmpty) 'Salida ${exit.trim()}',
  ];

  String valueFor(String field) => switch (field) {
    'entry' => entry,
    'lunchExit' => lunchExit,
    'lunchEntry' => lunchEntry,
    'exit' => exit,
    _ => '',
  };

  void setValue(String field, String value) {
    switch (field) {
      case 'entry':
        entry = value;
      case 'lunchExit':
        lunchExit = value;
      case 'lunchEntry':
        lunchEntry = value;
      case 'exit':
        exit = value;
    }
  }

  bool selectScheduleAt(int index) {
    if (index < 0 || index >= scheduleOptions.length) return false;
    final selected = scheduleOptions[index];
    final nextSchedule = _parseAttendanceSchedule(selected.horario);
    if (nextSchedule == null) return false;
    final previousExpected = _attendanceExpectedTimes(schedule);
    final nextExpected = _attendanceExpectedTimes(nextSchedule);
    schedule = nextSchedule;
    selectedSchedule = selected.horario;

    if (_attendanceTimeIsDerived(entry, previousExpected[0])) {
      entry = nextExpected[0];
    }
    if (_attendanceTimeIsDerived(lunchExit, previousExpected[1])) {
      lunchExit = nextExpected[1];
    }
    if (_attendanceTimeIsDerived(lunchEntry, previousExpected[2])) {
      lunchEntry = nextExpected[2];
    }
    if (_attendanceTimeIsDerived(exit, previousExpected[3])) {
      exit = nextExpected[3];
    }
    recalculate();
    return true;
  }

  void normalizeTimes() {
    entry = _normalizeAttendanceTimeInput(entry);
    lunchExit = _normalizeAttendanceTimeInput(lunchExit);
    lunchEntry = _normalizeAttendanceTimeInput(lunchEntry);
    exit = _normalizeAttendanceTimeInput(exit);
  }

  void recalculate() {
    final activeSchedule = schedule;
    if (status != _HrAttendanceStatus.laboro || activeSchedule == null) {
      lateMinutes = 0;
      overtimeMinutes = 0;
      return;
    }
    final firstPunchAt = _resolveAttendancePunchDateTime(
      sourceDate: _fmtAttendanceDateLabel(date),
      sourceTime: _normalizeAttendanceTimeInput(entry),
    );
    var lastPunchAt = _resolveAttendancePunchDateTime(
      sourceDate: _fmtAttendanceDateLabel(date),
      sourceTime: _normalizeAttendanceTimeInput(exit),
    );
    final scheduledStartAt = DateTime(
      date.year,
      date.month,
      date.day,
      activeSchedule.start.hour,
      activeSchedule.start.minute,
    );
    final scheduledEndAtSameDate = DateTime(
      date.year,
      date.month,
      date.day,
      activeSchedule.end.hour,
      activeSchedule.end.minute,
    );
    if (firstPunchAt == null || lastPunchAt == null) {
      lateMinutes = 0;
      overtimeMinutes = 0;
      return;
    }
    final overnightSchedule = !scheduledEndAtSameDate.isAfter(scheduledStartAt);
    final scheduledEndAt = overnightSchedule
        ? scheduledEndAtSameDate.add(const Duration(days: 1))
        : scheduledEndAtSameDate;
    if (overnightSchedule && lastPunchAt.isBefore(scheduledStartAt)) {
      lastPunchAt = lastPunchAt.add(const Duration(days: 1));
    }
    lateMinutes = math.max(
      0,
      firstPunchAt.difference(scheduledStartAt).inMinutes,
    );
    overtimeMinutes = _resolveOvertimeMinutes(
      scheduledEndAt: scheduledEndAt,
      lastPunchAt: lastPunchAt,
    );
  }
}

List<String> _attendanceExpectedTimes(_HrAttendanceScheduleDraft? schedule) {
  if (schedule == null) return const <String>['', '', '', ''];
  return <String>[
    _fmtTimeOfDay(schedule.start),
    schedule.lunchStart == null ? '' : _fmtTimeOfDay(schedule.lunchStart!),
    schedule.lunchEnd == null ? '' : _fmtTimeOfDay(schedule.lunchEnd!),
    _fmtTimeOfDay(schedule.end),
  ];
}

bool _attendanceTimeIsDerived(String value, String expected) {
  if (value.trim().isEmpty) return true;
  return _normalizeAttendanceTimeInput(value) ==
      _normalizeAttendanceTimeInput(expected);
}

_HrAttendanceWorkSchedule? _attendanceWorkScheduleForValue(
  List<_HrAttendanceWorkSchedule> schedules,
  String value,
) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  for (final schedule in schedules) {
    if (schedule.horario == normalized) return schedule;
  }
  return null;
}

_HrAttendanceWorkSchedule? _attendanceWorkScheduleMatching(
  List<_HrAttendanceWorkSchedule> schedules,
  _HrAttendanceScheduleDraft? target,
) {
  if (target == null) return null;
  final targetTimes = _attendanceExpectedTimes(target);
  for (final schedule in schedules) {
    final parsed = _parseAttendanceSchedule(schedule.horario);
    if (parsed == null) continue;
    if (_listEquals(_attendanceExpectedTimes(parsed), targetTimes)) {
      return schedule;
    }
  }
  return null;
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
  final String captureOrigin;
  final String selectedSchedule;
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
    this.captureOrigin = 'weekly',
    this.selectedSchedule = '',
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
    'status': status.databaseValue,
    'source_mode': sourceMode,
    'capture_origin': captureOrigin,
    'selected_schedule': selectedSchedule,
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
      status: _HrAttendanceStatus.fromDatabaseValue(
        (row['status'] ?? '').toString(),
      ),
      sourceMode: (row['source_mode'] ?? 'manual').toString(),
      captureOrigin: (row['capture_origin'] ?? 'weekly').toString(),
      selectedSchedule: (row['selected_schedule'] ?? '').toString(),
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
  final String captureOrigin;
  final String selectedSchedule;
  final String scheduledStart;
  final String scheduledEnd;
  final int effectiveWorkMinutes;
  final String firstPunch;
  final String lastPunch;
  final List<String> punchTimeline;
  final List<String> ngtecoReferenceTimeline;
  final int lateMinutes;
  final int overtimeMinutes;
  final String notes;

  const _HrAttendanceDayRecord({
    required this.sourceDate,
    required this.weekdayLabel,
    required this.status,
    required this.sourceMode,
    this.captureOrigin = 'weekly',
    this.selectedSchedule = '',
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.effectiveWorkMinutes,
    required this.firstPunch,
    required this.lastPunch,
    required this.punchTimeline,
    this.ngtecoReferenceTimeline = const <String>[],
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
      captureOrigin: captureOrigin,
      selectedSchedule: selectedSchedule,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      effectiveWorkMinutes: effectiveWorkMinutes,
      firstPunch: firstPunch,
      lastPunch: lastPunch,
      punchTimeline: List<String>.from(punchTimeline),
      ngtecoReferenceTimeline: List<String>.from(ngtecoReferenceTimeline),
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
  String captureOrigin;
  String selectedSchedule;
  String scheduledStart;
  String scheduledEnd;
  int effectiveWorkMinutes;
  String firstPunch;
  String lastPunch;
  List<String> punchTimeline;
  List<String> ngtecoReferenceTimeline;
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
    this.captureOrigin = 'weekly',
    this.selectedSchedule = '',
    this.scheduledStart = '',
    this.scheduledEnd = '',
    this.effectiveWorkMinutes = 0,
    this.firstPunch = '',
    this.lastPunch = '',
    this.punchTimeline = const <String>[],
    this.ngtecoReferenceTimeline = const <String>[],
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

List<_HrAttendanceSummaryRow> _buildAttendanceSummaryRows({
  required List<_HrAttendanceEmployeeMaster> employees,
  required _HrAttendanceImportLotLite? ngtecoLot,
  required _HrAttendanceImportLotLite? contpaqLot,
  required List<_HrAttendanceStoredRecord> storedRecords,
  required String periodLabel,
  bool includeImportedStoredRows = true,
  bool defaultSchedulePending = false,
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
  final storedByEmployeeDate = <String, _HrAttendanceStoredRecord>{};
  for (final record in storedRecords.where(
    (item) => item.periodLabel == periodLabel,
  )) {
    for (final key in _attendanceStoredRecordKeys(
      record,
      periodRange: periodRange,
    )) {
      storedByEmployeeDate[key] = record;
    }
  }

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
          final scheduledEndAtSameDate = DateTime(
            importedDateTimes.first.year,
            importedDateTimes.first.month,
            importedDateTimes.first.day,
            schedule.end.hour,
            schedule.end.minute,
          );
          final overnightSchedule = !scheduledEndAtSameDate.isAfter(
            scheduledStartAt,
          );
          final scheduledEndAt = overnightSchedule
              ? scheduledEndAtSameDate.add(const Duration(days: 1))
              : scheduledEndAtSameDate;
          var lastPunchAt = importedDateTimes.last;
          if (overnightSchedule && lastPunchAt.isBefore(scheduledStartAt)) {
            lastPunchAt = lastPunchAt.add(const Duration(days: 1));
          }
          lateMinutes = importedDateTimes.first
              .difference(scheduledStartAt)
              .inMinutes;
          if (lateMinutes < 0) lateMinutes = 0;
          overtimeMinutes = _resolveOvertimeMinutes(
            scheduledEndAt: scheduledEndAt,
            lastPunchAt: lastPunchAt,
          );
        }
      }

      recordMap[sourceDate] = _HrAttendanceDayRecord(
        sourceDate: sourceDate,
        weekdayLabel: weekdayLabel,
        status: hasPunches || !defaultSchedulePending
            ? _HrAttendanceStatus.laboro
            : _HrAttendanceStatus.pendiente,
        sourceMode: hasPunches ? 'importado' : 'jornada',
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
        ngtecoReferenceTimeline: punchTimeline,
        lateMinutes: lateMinutes,
        overtimeMinutes: overtimeMinutes,
        notes: '',
      );
    }

    final employeeStoredRecords = <String, _HrAttendanceStoredRecord>{};
    for (final entry in storedByEmployeeDate.entries) {
      final stored = entry.value;
      if (_normalizeAttendanceEmployeeId(stored.employeeId) !=
          normalizedEmployeeId) {
        continue;
      }
      // The same legacy record can expose both date orders while it is being
      // normalized. Process it once, preferring the date that has NGTeco data.
      employeeStoredRecords.putIfAbsent(stored.id, () => stored);
    }
    for (final stored in employeeStoredRecords.values) {
      if (!includeImportedStoredRows &&
          stored.sourceMode == 'importado' &&
          stored.captureOrigin != 'weekly') {
        continue;
      }
      final storedSourceDate = _resolveAttendanceStoredDateForRecord(
        stored: stored,
        recordMap: recordMap,
        periodRange: periodRange,
      );
      if (storedSourceDate == null) continue;
      final storedDate = _parseAttendanceDateLabel(storedSourceDate);
      final storedWeekdayLabel = storedDate == null
          ? stored.weekdayLabel
          : _hrWeekdayLabel(storedDate.weekday);
      final storedPunchAt = _resolveAttendancePunchDateTime(
        sourceDate: storedSourceDate,
        sourceTime: stored.firstPunch,
      );
      final storedSchedule =
          _resolveAttendanceSelectedSchedule(stored.selectedSchedule) ??
          (storedPunchAt != null
              ? _resolveAttendanceScheduleForPunch(
                  schedules: employee.workSchedules,
                  weekdayLabel: storedWeekdayLabel,
                  punchAt: storedPunchAt,
                )
              : _resolveAttendanceScheduleForPunchlessDay(
                  schedules: employee.workSchedules,
                  weekdayLabel: storedWeekdayLabel,
                ));
      final importedRecord = recordMap[storedSourceDate];
      final importedPunchesAreAvailable =
          importedRecord?.sourceMode == 'importado' &&
          (importedRecord!.firstPunch.trim().isNotEmpty ||
              importedRecord.punchTimeline.isNotEmpty);
      final isUserOwnedRecord =
          stored.sourceMode == 'manual' ||
          stored.sourceMode == 'ajuste' ||
          _isLegacyAttendanceUserOverride(
            stored: stored,
            imported: importedRecord,
          );
      if (importedPunchesAreAvailable && !isUserOwnedRecord) {
        // An imported row is always a refreshable NGTeco baseline. Only a
        // manual/adjusted row, including a detectable legacy user edit, is
        // allowed to supersede the current source import.
        continue;
      }
      recordMap[storedSourceDate] = _HrAttendanceDayRecord(
        sourceDate: storedSourceDate,
        weekdayLabel: storedWeekdayLabel,
        status: stored.status,
        sourceMode: stored.sourceMode,
        captureOrigin: stored.captureOrigin,
        selectedSchedule: stored.selectedSchedule,
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
        ngtecoReferenceTimeline:
            importedRecord?.punchTimeline ?? const <String>[],
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

bool _isLegacyAttendanceUserOverride({
  required _HrAttendanceStoredRecord stored,
  required _HrAttendanceDayRecord? imported,
}) {
  if (stored.sourceMode != 'importado' || imported == null) return false;
  if (stored.notes.trim().isNotEmpty) return true;

  // Earlier versions persisted direct edits with sourceMode "importado".
  // A legacy override is only credible when it still has a complete pair of
  // RH-entered punches. Old import templates can contain an empty or partial
  // timeline; those rows must be refreshed from the current NGTeco lot.
  final storedFirst = stored.firstPunch.trim();
  final storedLast = stored.lastPunch.trim();
  if (storedFirst.isEmpty || storedLast.isEmpty) return false;

  final importedFirst = imported.firstPunch.trim();
  final importedLast = imported.lastPunch.trim();
  if (importedFirst.isEmpty || importedLast.isEmpty) return false;

  return stored.status != imported.status ||
      storedFirst != importedFirst ||
      storedLast != importedLast;
}

Iterable<String> _attendanceStoredRecordKeys(
  _HrAttendanceStoredRecord record, {
  DateTimeRange? periodRange,
}) sync* {
  for (final dateLabel in _attendanceCandidateStoredDateLabels(record)) {
    final date = _parseAttendanceDateLabel(dateLabel);
    if (date == null ||
        (periodRange != null &&
            (date.isBefore(periodRange.start) ||
                date.isAfter(periodRange.end)))) {
      continue;
    }
    yield _attendanceEmployeeDateKey(record.employeeId, dateLabel);
  }
}

List<String> _attendanceCandidateStoredDateLabels(
  _HrAttendanceStoredRecord record,
) {
  final labels = <String>{};
  final canonical = _normalizeAttendanceStoredDateLabel(record.sourceDate);
  if (canonical.isNotEmpty) labels.add(canonical);
  if (record.sourceMode == 'importado') {
    final sourceAsUsDate = _parseUsImportDate(record.sourceDate);
    if (sourceAsUsDate != null) {
      labels.add(_fmtAttendanceDateLabel(sourceAsUsDate));
    }
  }
  return labels.toList(growable: false);
}

String? _resolveAttendanceStoredDateForRecord({
  required _HrAttendanceStoredRecord stored,
  required Map<String, _HrAttendanceDayRecord> recordMap,
  required DateTimeRange? periodRange,
}) {
  final dateLabels = _attendanceCandidateStoredDateLabels(stored)
      .where((label) {
        final date = _parseAttendanceDateLabel(label);
        return date != null &&
            (periodRange == null ||
                (!date.isBefore(periodRange.start) &&
                    !date.isAfter(periodRange.end)));
      })
      .toList(growable: false);
  for (final label in dateLabels) {
    if (recordMap.containsKey(label)) return label;
  }
  return dateLabels.isEmpty ? null : dateLabels.first;
}

String _attendanceEmployeeDateKey(String employeeId, String sourceDate) {
  return '${_normalizeAttendanceEmployeeId(employeeId)}|'
      '${_normalizeAttendanceStoredDateLabel(sourceDate)}';
}

_HrAttendanceStoredRecord _attendanceStoredRecordFromDay({
  required String employeeId,
  required String employeeName,
  required String periodLabel,
  required _HrAttendanceDayRecord day,
  String? sourceDate,
}) {
  return _HrAttendanceStoredRecord(
    id: '',
    periodLabel: periodLabel,
    employeeId: employeeId,
    employeeName: employeeName,
    sourceDate: sourceDate ?? day.sourceDate,
    weekdayLabel: day.weekdayLabel,
    status: day.status,
    sourceMode: day.sourceMode,
    captureOrigin: day.captureOrigin,
    selectedSchedule: day.selectedSchedule,
    firstPunch: day.firstPunch,
    lastPunch: day.lastPunch,
    punchTimeline: day.punchTimeline,
    lateMinutes: day.lateMinutes,
    overtimeMinutes: day.overtimeMinutes,
    notes: day.notes,
  );
}

bool _attendanceStoredRecordMatchesDay(
  _HrAttendanceStoredRecord record,
  _HrAttendanceDayRecord day,
) {
  return record.weekdayLabel == day.weekdayLabel &&
      record.status == day.status &&
      record.sourceMode == day.sourceMode &&
      record.captureOrigin == day.captureOrigin &&
      record.selectedSchedule == day.selectedSchedule &&
      record.firstPunch == day.firstPunch &&
      record.lastPunch == day.lastPunch &&
      _listEquals(record.punchTimeline, day.punchTimeline) &&
      record.lateMinutes == day.lateMinutes &&
      record.overtimeMinutes == day.overtimeMinutes &&
      record.notes == day.notes;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<String> _attendancePeriodOptions({
  required List<_HrAttendanceImportLotLite> lots,
  required List<_HrAttendanceStoredRecord> records,
  Iterable<String> operationalPeriodLabels = const <String>[],
}) {
  return HumanResourcesPeriodContext.normalizedOptions([
    ...operationalPeriodLabels,
    for (final lot in lots) _describeImportPeriod(lot),
    for (final record in records) record.periodLabel,
  ]);
}

_HrAttendanceImportLotLite? _attendanceLotForPeriod(
  List<_HrAttendanceImportLotLite> lots,
  _HrAttendanceImportSource source,
  String selectedPeriodLabel,
) {
  if (selectedPeriodLabel.trim().isEmpty) return null;
  final selectedRange = _extractDateRangeFromPeriodLabel(selectedPeriodLabel);
  _HrAttendanceImportLotLite? bestEntryMatch;
  var bestEntryMatchCount = 0;
  for (final lot in lots) {
    if (lot.source != source) continue;
    final described = _describeImportPeriod(lot);
    if (described == selectedPeriodLabel) return lot;
    final lotRange = _attendanceImportLotDateRange(lot);
    if (selectedRange != null &&
        lotRange != null &&
        selectedRange.start == lotRange.start &&
        selectedRange.end == lotRange.end) {
      return lot;
    }
    if (selectedRange == null || source != _HrAttendanceImportSource.ngteco) {
      continue;
    }
    final entriesInRange = lot.entries.where((entry) {
      final parsed = _parseAttendanceImportedDateTime(entry);
      if (parsed == null) return false;
      final date = DateTime(parsed.year, parsed.month, parsed.day);
      return !date.isBefore(selectedRange.start) &&
          !date.isAfter(selectedRange.end);
    }).length;
    // The source dates are authoritative. Imported labels can be generated by
    // older app versions and use a different date order.
    if (entriesInRange > bestEntryMatchCount) {
      bestEntryMatch = lot;
      bestEntryMatchCount = entriesInRange;
    }
  }
  return bestEntryMatch;
}

DateTimeRange? _attendanceImportLotDateRange(_HrAttendanceImportLotLite lot) {
  if (lot.source == _HrAttendanceImportSource.ngteco) {
    final entryRange = _attendanceImportedEntriesRange(lot.entries);
    if (entryRange != null) return entryRange;
  }
  return _extractDateRangeFromPeriodLabel(_describeImportPeriod(lot));
}

DateTimeRange? _attendanceImportedEntriesRange(
  Iterable<_HrAttendanceImportedEntry> entries,
) {
  final dates = entries
      .map(_parseAttendanceImportedDateTime)
      .whereType<DateTime>()
      .map((value) => DateTime(value.year, value.month, value.day))
      .toList(growable: false);
  if (dates.isEmpty) return null;
  dates.sort();
  return DateTimeRange(start: dates.first, end: dates.last);
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
  return _extractDateRangeFromPeriodLabel(activePeriodLabel);
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

double _asAttendanceDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(
        (value ?? '').toString().trim().replaceAll(',', '.'),
      ) ??
      0;
}

bool _attendanceRecordIsProtectedFromEventProjection(
  _HrAttendanceStoredRecord record,
) {
  final hasFichajes =
      record.firstPunch.trim().isNotEmpty ||
      record.lastPunch.trim().isNotEmpty ||
      record.punchTimeline.any((item) => item.trim().isNotEmpty);
  if (hasFichajes ||
      record.sourceMode == 'manual' ||
      record.captureOrigin == 'daily') {
    return true;
  }

  // A weekly adjustment without an administrative-event trace belongs to RH
  // and must not be overwritten when a period is created later.
  final isAdministrativeProjection =
      record.notes.contains(_kHrAttendanceVacationSyncPrefix) ||
      record.notes.contains(_kHrAttendancePermissionSyncPrefix);
  return record.sourceMode == 'ajuste' && !isAdministrativeProjection;
}

String _mergeAttendanceEventProjectionNote(
  String current, {
  required String prefix,
  required String note,
}) {
  final remaining = current
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith(prefix))
      .toList(growable: false);
  return <String>[...remaining, note].join('\n');
}

String _appendAttendanceEventPeriodLabel(String current, String periodLabel) {
  final labels = current
      .split(' · ')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
  labels.add(periodLabel);
  final ordered = labels.toList(growable: false)..sort();
  return ordered.join(' · ');
}

String _normalizeAttendanceEmployeeId(String raw) {
  final compact = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) return '';
  final numeric = RegExp(r'^(\d+)(?:\.0+)?$').firstMatch(compact);
  if (numeric == null) return compact;
  final normalized = numeric.group(1)!.replaceFirst(RegExp(r'^0+'), '');
  return normalized.isEmpty ? '0' : normalized;
}

DateTime? _parseAttendanceImportedDateTime(_HrAttendanceImportedEntry entry) {
  var date = entry.sourceDate.trim();
  var time = entry.sourceTime.trim();
  if (date.isEmpty || time.isEmpty) {
    final detailMatch = RegExp(
      r'(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}/\d{1,2}/\d{4})[ T]+(\d{1,2}:\d{2}(?::\d{2}(?:\.\d+)?)?)',
    ).firstMatch(entry.detail);
    if (detailMatch != null) {
      date = detailMatch.group(1)!;
      time = detailMatch.group(2)!;
    }
  }
  if (date.isEmpty || time.isEmpty) return null;

  var year = 0;
  var month = 0;
  var day = 0;
  final isoDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(date);
  if (isoDate != null) {
    year = int.tryParse(isoDate.group(1)!) ?? 0;
    month = int.tryParse(isoDate.group(2)!) ?? 0;
    day = int.tryParse(isoDate.group(3)!) ?? 0;
  } else {
    final slashDate = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(date);
    if (slashDate == null) return null;
    final first = int.tryParse(slashDate.group(1)!);
    final second = int.tryParse(slashDate.group(2)!);
    year = int.tryParse(slashDate.group(3)!) ?? 0;
    if (first == null || second == null) return null;
    // NGTeco normally exports MM/DD/YYYY. If only one order is valid, use it.
    if (first > 12 && second <= 12) {
      day = first;
      month = second;
    } else {
      month = first;
      day = second;
    }
  }
  final timeMatch = RegExp(
    r'^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$',
  ).firstMatch(time);
  if (timeMatch == null) return null;
  final hour = int.tryParse(timeMatch.group(1)!);
  final minute = int.tryParse(timeMatch.group(2)!);
  final second = int.tryParse(timeMatch.group(3) ?? '0');
  if (year < 2000 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour == null ||
      hour > 23 ||
      minute == null ||
      minute > 59 ||
      second == null ||
      second > 59) {
    return null;
  }
  final parsed = DateTime(year, month, day, hour, minute, second);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? parsed
      : null;
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

String _formatAttendanceDatabaseDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatOperationalAttendancePeriodLabel({
  required int periodNumber,
  required DateTime startDate,
  required DateTime endDate,
}) {
  return 'Periodo $periodNumber semanal · '
      '${_fmtAttendanceDateLabel(startDate)} - ${_fmtAttendanceDateLabel(endDate)}';
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  final raw = value.toString().trim();
  final direct = int.tryParse(raw);
  if (direct != null) return direct;
  final decimal = double.tryParse(raw);
  if (decimal != null &&
      decimal.isFinite &&
      decimal == decimal.roundToDouble()) {
    return decimal.toInt();
  }
  return null;
}

String _normalizeAttendanceStoredDateLabel(String raw) {
  final parsed = _parseAttendanceDateLabel(raw);
  return parsed == null ? raw.trim() : _fmtAttendanceDateLabel(parsed);
}

DateTime? _parseAttendanceDateLabel(String raw) {
  final normalized = raw.trim();
  final iso = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T].*)?$',
  ).firstMatch(normalized);
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(normalized);
  final year = int.tryParse(iso?.group(1) ?? slash?.group(3) ?? '');
  final month = int.tryParse(iso?.group(2) ?? slash?.group(2) ?? '');
  final day = int.tryParse(iso?.group(3) ?? slash?.group(1) ?? '');
  if (day == null || month == null || year == null) return null;
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? parsed
      : null;
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
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

TimeOfDay? _parseFlexibleAttendanceTime(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) return null;
  final separated = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(normalized);
  final compact = RegExp(r'^(\d{1,2})(\d{2})$').firstMatch(normalized);
  final hour = int.tryParse(separated?.group(1) ?? compact?.group(1) ?? '');
  final minute = int.tryParse(separated?.group(2) ?? compact?.group(2) ?? '');
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

bool _isValidAttendanceTimeOrEmpty(String raw) =>
    raw.trim().isEmpty || _parseFlexibleAttendanceTime(raw) != null;

String _normalizeAttendanceTimeInput(String raw) {
  final time = _parseFlexibleAttendanceTime(raw);
  return time == null ? raw.trim() : _fmtTimeOfDay(time);
}

_HrAttendanceStoredRecord? _dailyStoredRecordFor({
  required List<_HrAttendanceStoredRecord> records,
  required String periodLabel,
  required String employeeId,
  required String dateLabel,
}) {
  for (final record in records.reversed) {
    if (record.periodLabel != periodLabel ||
        _normalizeAttendanceEmployeeId(record.employeeId) !=
            _normalizeAttendanceEmployeeId(employeeId) ||
        _normalizeAttendanceStoredDateLabel(record.sourceDate) != dateLabel) {
      continue;
    }
    return record;
  }
  return null;
}

String _manualPunchTimelineValue(List<String> timeline, String prefix) {
  for (final item in timeline) {
    final normalized = item.trim();
    if (!normalized.toLowerCase().startsWith(prefix.toLowerCase())) continue;
    return normalized.substring(prefix.length).trim();
  }
  return '';
}

Color _dailyStatusColor(_HrAttendanceStatus status) => switch (status) {
  _HrAttendanceStatus.pendiente => const Color(0xFFFFF8E8),
  _HrAttendanceStatus.laboro => const Color(0xFFE9F8ED),
  _HrAttendanceStatus.falto => const Color(0xFFFFEBEE),
  _HrAttendanceStatus.noAplica => const Color(0xFFF0ECF7),
};

String _formatAttendanceMinutesAsHourRatio(int minutes) {
  return '${(minutes / 60).toStringAsFixed(2)} h';
}

String _formatAttendanceHoursInput(int minutes) =>
    (minutes / 60).toStringAsFixed(2);

int? _parseAttendanceHoursInput(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final hours = double.tryParse(normalized);
  if (hours == null || hours < 0) return null;
  return (hours * 60).round();
}

List<int> _distributeAttendanceMinutes(int totalMinutes, int count) {
  if (count <= 0) return const <int>[];
  final base = totalMinutes ~/ count;
  final remainder = totalMinutes % count;
  return List<int>.generate(
    count,
    (index) => base + (index < remainder ? 1 : 0),
    growable: false,
  );
}

String _attendanceTimePlusMinutes(String sourceTime, int extraMinutes) {
  final time = _parseAttendanceTimeOfDay(sourceTime);
  if (time == null) return sourceTime;
  final total = (time.hour * 60 + time.minute + extraMinutes) % (24 * 60);
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
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
  if (day.status == _HrAttendanceStatus.pendiente) return true;
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

bool _attendanceDraftIsScheduleFilled(_HrAttendanceDayDraft day) =>
    day.sourceMode == 'jornada';

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
  if (day.status == _HrAttendanceStatus.pendiente) return true;
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

void _markAttendanceDraftAsUserAdjustment(_HrAttendanceDayDraft draft) {
  // Keep explicitly captured manual records manual, but protect edits to
  // imported or schedule-generated rows from a later NGTeco refresh.
  if (draft.sourceMode != 'manual') {
    draft.sourceMode = 'ajuste';
  }
  draft.captureOrigin = 'weekly';
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
  var lastPunchAt = _resolveAttendancePunchDateTime(
    sourceDate: draft.sourceDate,
    sourceTime: draft.lastPunch,
  );
  final scheduledStartAt = _resolveAttendancePunchDateTime(
    sourceDate: draft.sourceDate,
    sourceTime: draft.scheduledStart,
  );
  final scheduledEndAtSameDate = _resolveAttendancePunchDateTime(
    sourceDate: draft.sourceDate,
    sourceTime: draft.scheduledEnd,
  );
  if (firstPunchAt == null ||
      lastPunchAt == null ||
      scheduledStartAt == null ||
      scheduledEndAtSameDate == null) {
    draft.lateMinutes = 0;
    draft.overtimeMinutes = 0;
    return;
  }
  final overnightSchedule = !scheduledEndAtSameDate.isAfter(scheduledStartAt);
  final scheduledEndAt = overnightSchedule
      ? scheduledEndAtSameDate.add(const Duration(days: 1))
      : scheduledEndAtSameDate;
  if (overnightSchedule && lastPunchAt.isBefore(scheduledStartAt)) {
    lastPunchAt = lastPunchAt.add(const Duration(days: 1));
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

_HrResolvedAttendanceSchedule? _resolveAttendanceSelectedSchedule(
  String rawSchedule,
) {
  final schedule = _parseAttendanceSchedule(rawSchedule);
  if (schedule == null) return null;
  // The daily sheet explicitly records this as the worked shift, even when
  // its normal workday pattern differs because the employee rotated shifts.
  return _HrResolvedAttendanceSchedule(schedule: schedule, worksThatDay: true);
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
  if (lot.source == _HrAttendanceImportSource.ngteco) {
    final entryRange = _attendanceImportedEntriesRange(lot.entries);
    if (entryRange != null) {
      return '${_fmtAttendanceDateLabel(entryRange.start)} - ${_fmtAttendanceDateLabel(entryRange.end)}';
    }
    if (raw.isEmpty) return 'Periodo no detectado';
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
  if (raw.isEmpty) return 'Periodo no detectado';

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
