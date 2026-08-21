import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_employee_status.dart';
import 'human_resources_event_period_impacts.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_period_context.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';

const String _kHrProfilesTable = 'hr_employee_profiles';
const String _kHrImportLotsTable = 'hr_attendance_import_lots';
const String _kHrAttendanceDailyRecordsTable = 'hr_attendance_daily_records';
const String _kHrVacationRulesTable = 'hr_vacation_entitlement_rules';
const String _kHrVacationBalancesTable = 'hr_employee_vacation_balances';
const String _kHrVacationEventsTable = 'hr_employee_vacation_events';
const String _kHrVacationCalculationsTable =
    'hr_employee_vacation_calculations';

const String _kHrVacationAttendanceSyncPrefix = 'Vacaciones RH:';
const String _kHrVacationContpaqReceiptPrefix = 'contpaq:';

const double _kHrVacationIdW = 84;
const double _kHrVacationNameW = 224;
const double _kHrVacationIngresoW = 124;
const double _kHrVacationAltaW = 124;
const double _kHrVacationEntitledW = 120;
const double _kHrVacationAppliedW = 120;
const double _kHrVacationAvailableW = 120;
const double _kHrVacationStatusW = 136;
const double _kHrVacationActionsW = 108;

class HumanResourcesVacationsPage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesVacationsPage({super.key, this.instantOpen = false});

  @override
  State<HumanResourcesVacationsPage> createState() =>
      _HumanResourcesVacationsPageState();
}

enum _HrVacationRowAction { open }

class _HumanResourcesVacationsPageState
    extends State<HumanResourcesVacationsPage> {
  final int _exerciseYear = DateTime.now().year;
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _loading = true;
  String _activePeriodLabel = '';
  String _selectedPeriodLabel = '';
  List<String> _periodOptions = const <String>[];
  String? _selectedRowId;
  String? _hoveredRowId;
  int _currentPage = 0;
  int _pageSize = 40;
  final Map<String, Set<String>> _columnFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};
  bool _dragSelectionActive = false;
  bool _dragSelectionAdditive = false;
  bool _dragSelectionMoved = false;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  Set<String> _dragSelectionBaseIds = <String>{};
  List<String> _dragSelectionIds = const <String>[];
  String? _dragSelectionAnchorId;

  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'hrVacationRows');
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

  List<_HrVacationEmployeeMaster> _employees =
      const <_HrVacationEmployeeMaster>[];
  List<_HrVacationAttendanceLotLite> _attendanceImportLots =
      const <_HrVacationAttendanceLotLite>[];
  List<_HrVacationRule> _rules = const <_HrVacationRule>[];
  List<_HrVacationBalanceRecord> _balances = const <_HrVacationBalanceRecord>[];
  List<_HrVacationEventRecord> _events = const <_HrVacationEventRecord>[];
  List<_HrVacationCalculationRecord> _calculations =
      const <_HrVacationCalculationRecord>[];
  List<_HrVacationSummaryRow> _allRows = const <_HrVacationSummaryRow>[];
  List<_HrVacationSummaryRow> _visibleRows = const <_HrVacationSummaryRow>[];

  @override
  void initState() {
    super.initState();
    _navigationController.addListener(_handleNavigationChanged);
    _selectionController.addListener(_handleSelectionChanged);
    _configureGrid();
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
              'id,nombre,empresa,horario,dias_labora,labor_schedules,fecha_ingreso,fecha_alta,salario,salario_real_percibido',
            )
            .neq('employment_status', kHrEmployeeStatusTerminated)
            .order('id')
            .range(from, to),
      );
      final importLotsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrImportLotsTable)
            .select('id,source,file_name,imported_at,period_label,entries')
            .order('imported_at', ascending: false)
            .range(from, to),
      );
      final rulesResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrVacationRulesTable)
            .select()
            .eq('active', true)
            .order('sort_order')
            .range(from, to),
      );
      final balancesResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrVacationBalancesTable)
            .select()
            .eq('exercise_year', _exerciseYear)
            .order('employee_id')
            .range(from, to),
      );
      final eventsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrVacationEventsTable)
            .select()
            .eq('exercise_year', _exerciseYear)
            .order('start_date')
            .range(from, to),
      );
      final calculationsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrVacationCalculationsTable)
            .select()
            .eq('exercise_year', _exerciseYear)
            .order('vacation_event_id')
            .order('sequence_no')
            .range(from, to),
      );

      final employees =
          employeesResult
              .map((raw) => Map<String, dynamic>.from(raw))
              .map(_HrVacationEmployeeMaster.fromRow)
              .where((row) => row.employeeId.trim().isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) {
              final aInt = int.tryParse(a.employeeId);
              final bInt = int.tryParse(b.employeeId);
              if (aInt != null && bInt != null) return aInt.compareTo(bInt);
              return a.employeeId.compareTo(b.employeeId);
            });
      final attendanceLots = importLotsResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrVacationAttendanceLotLite.fromRow)
          .toList(growable: false);

      final rules = rulesResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrVacationRule.fromRow)
          .toList(growable: false);
      final balances = balancesResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrVacationBalanceRecord.fromRow)
          .toList(growable: false);
      var events = eventsResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrVacationEventRecord.fromRow)
          .toList(growable: false);
      var calculations = calculationsResult
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrVacationCalculationRecord.fromRow)
          .toList(growable: false);

      final periodOptions = _vacationPeriodOptions(
        lots: attendanceLots,
        events: events,
      );
      final activePeriodLabel = HumanResourcesPeriodContext.resolveSelected(
        selectedLabel: selectedPeriodLabel,
        availableLabels: periodOptions,
      );

      final contpaqSyncChanged = activePeriodLabel.isEmpty
          ? false
          : await _syncVacationPaidEventsFromContpaq(
              client: client,
              employees: employees,
              balances: balances,
              attendanceLots: attendanceLots,
              events: events,
              calculations: calculations,
              exerciseYear: _exerciseYear,
              activePeriodLabel: activePeriodLabel,
            );
      if (contpaqSyncChanged) {
        final refreshedEventsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrVacationEventsTable)
              .select()
              .eq('exercise_year', _exerciseYear)
              .order('start_date')
              .range(from, to),
        );
        final refreshedCalculationsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrVacationCalculationsTable)
              .select()
              .eq('exercise_year', _exerciseYear)
              .order('vacation_event_id')
              .order('sequence_no')
              .range(from, to),
        );
        events = refreshedEventsResult
            .map((raw) => Map<String, dynamic>.from(raw))
            .map(_HrVacationEventRecord.fromRow)
            .toList(growable: false);
        calculations = refreshedCalculationsResult
            .map((raw) => Map<String, dynamic>.from(raw))
            .map(_HrVacationCalculationRecord.fromRow)
            .toList(growable: false);
      }

      if (!mounted) return;
      _employees = employees;
      _attendanceImportLots = attendanceLots;
      _rules = rules;
      _balances = balances;
      _events = events;
      _calculations = calculations;
      _selectedPeriodLabel = selectedPeriodLabel;
      _periodOptions = _vacationPeriodOptions(
        lots: attendanceLots,
        events: events,
      );
      _rebuildRows();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _rebuildRows() {
    _activePeriodLabel = HumanResourcesPeriodContext.resolveSelected(
      selectedLabel: _selectedPeriodLabel,
      availableLabels: _periodOptions,
    );
    final balanceByEmployee = {
      for (final item in _balances) item.employeeId: item,
    };
    final eventsByEmployee = <String, List<_HrVacationEventRecord>>{};
    for (final item in _events) {
      eventsByEmployee.putIfAbsent(item.employeeId, () => []).add(item);
    }
    final rows = _employees
        .map(
          (employee) => _buildVacationSummaryRow(
            employee: employee,
            balance: balanceByEmployee[employee.employeeId],
            events: eventsByEmployee[employee.employeeId] ?? const [],
            rules: _rules,
            exerciseYear: _exerciseYear,
          ),
        )
        .toList(growable: false);
    final filteredRows = _applyVacationFilters(rows);
    final pageCount = filteredRows.isEmpty
        ? 1
        : ((filteredRows.length - 1) ~/ _pageSize) + 1;
    if (_currentPage >= pageCount) {
      _currentPage = pageCount - 1;
    }
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, filteredRows.length);
    _allRows = filteredRows;
    _visibleRows = filteredRows.sublist(
      start.clamp(0, filteredRows.length),
      end,
    );
    if (_selectedRowId != null &&
        !_allRows.any((row) => row.employeeId == _selectedRowId)) {
      _selectedRowId = null;
      _selectionController.clear();
    }
    _configureGrid();
    setState(() => _loading = false);
  }

  Future<void> _selectPeriod(String periodLabel) async {
    await HumanResourcesPeriodContext.select(periodLabel);
    if (!mounted) return;
    _selectedPeriodLabel = periodLabel;
    _currentPage = 0;
    _rebuildRows();
  }

  bool _requireActivePeriod() {
    if (_activePeriodLabel.isNotEmpty) return true;
    _showSnack('Selecciona un periodo operativo antes de editar vacaciones.');
    return false;
  }

  List<_HrVacationSummaryRow> _applyVacationFilters(
    List<_HrVacationSummaryRow> rows,
  ) {
    if (_columnFilters.isEmpty && _columnDateRangeFilters.isEmpty) return rows;
    return rows
        .where((row) {
          for (final entry in _columnDateRangeFilters.entries) {
            final date = _vacationDateValueForColumn(row, entry.key);
            if (date == null) return false;
            final dateOnly = DateUtils.dateOnly(date);
            final rangeStart = DateUtils.dateOnly(entry.value.start);
            final rangeEnd = DateUtils.dateOnly(entry.value.end);
            if (dateOnly.isBefore(rangeStart) || dateOnly.isAfter(rangeEnd)) {
              return false;
            }
          }
          for (final entry in _columnFilters.entries) {
            if (entry.value.isEmpty) continue;
            final value = _vacationCellValueForColumn(row, entry.key);
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

  Future<void> _openPermissions() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesPermissionsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openImportConciliation() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesAttendanceIncidentsPage(instantOpen: true),
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

  Future<void> _openSummaryRow(_HrVacationSummaryRow row) async {
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
      final result = await showDialog<_HrVacationEditResult>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _HrVacationEditDialog(
          row: row,
          rules: _rules,
          calculations: _calculations
              .where((item) => item.employeeId == row.employeeId)
              .toList(growable: false),
          canGoPrevious: currentIndex > 0,
          canGoNext: currentIndex < _allRows.length - 1,
        ),
      );
      if (result == null) return;
      await _saveVacationEdits(row: row, result: result);
      switch (result.action) {
        case _HrVacationEditAction.save:
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrVacationEditAction.previous:
          if (currentIndex > 0) {
            currentIndex -= 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
        case _HrVacationEditAction.next:
          if (currentIndex < _allRows.length - 1) {
            currentIndex += 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
      }
    }
  }

  Future<void> _saveVacationEdits({
    required _HrVacationSummaryRow row,
    required _HrVacationEditResult result,
  }) async {
    if (!_requireActivePeriod()) return;
    final client = Supabase.instance.client;
    final preparedEvents = await _prepareVacationEventsForPersistence(
      row: row,
      events: result.events,
    );

    final balancePayload = result.balance.toRow(
      employeeId: row.employeeId,
      employeeName: row.displayName,
      empresa: row.empresa,
      exerciseYear: _exerciseYear,
      existingId: row.balanceId,
    );
    await client
        .from(_kHrVacationBalancesTable)
        .upsert(balancePayload, onConflict: 'employee_id,exercise_year');

    final refreshedBalanceResult = await client
        .from(_kHrVacationBalancesTable)
        .select()
        .eq('employee_id', row.employeeId)
        .eq('exercise_year', _exerciseYear)
        .limit(1)
        .maybeSingle();
    final refreshedBalance = refreshedBalanceResult == null
        ? null
        : _HrVacationBalanceRecord.fromRow(
            Map<String, dynamic>.from(refreshedBalanceResult as Map),
          );

    final lockedEventIds = row.events
        .where(
          (event) =>
              event.prenominaSyncStatus == _HrVacationSyncStatus.aplicado,
        )
        .map((event) => event.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    final nextEventIds = preparedEvents
        .map((event) => event.localId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final existing in row.events) {
      if (existing.id.isEmpty ||
          lockedEventIds.contains(existing.id) ||
          nextEventIds.contains(existing.id)) {
        continue;
      }
      await client.from(_kHrVacationEventsTable).delete().eq('id', existing.id);
    }

    final existingDrafts = preparedEvents
        .where(
          (event) =>
              event.hasPersistedId && !lockedEventIds.contains(event.localId),
        )
        .toList(growable: false);
    if (existingDrafts.isNotEmpty) {
      await client
          .from(_kHrVacationEventsTable)
          .upsert(
            existingDrafts
                .map(
                  (event) => event.toRow(
                    balanceId: refreshedBalance?.id,
                    employeeId: row.employeeId,
                    employeeName: row.displayName,
                    exerciseYear: _exerciseYear,
                  ),
                )
                .toList(growable: false),
            onConflict: 'id',
          );
    }
    for (final event in preparedEvents.where(
      (event) => !event.hasPersistedId,
    )) {
      final inserted = await client
          .from(_kHrVacationEventsTable)
          .insert(
            event.toRow(
              balanceId: refreshedBalance?.id,
              employeeId: row.employeeId,
              employeeName: row.displayName,
              exerciseYear: _exerciseYear,
            ),
          )
          .select('id')
          .single();
      event.localId = (inserted['id'] ?? '').toString();
    }

    await syncHrEventPeriodImpacts(
      client: client,
      eventKind: 'vacacion',
      sources: preparedEvents
          .map(
            (event) => HrEventPeriodImpactSource(
              eventId: event.localId,
              employeeId: row.employeeId,
              startDate: event.startDate,
              endDate: event.endDate,
              daysApplied: event.daysApplied,
              additionalPaidDays: event.additionalPaidDays,
              quantityHours: 0,
              impactAttendance: event.impactAttendance,
              impactPrenomina: event.impactPrenomina,
              isCancelled: event.status == _HrVacationEventStatus.cancelado,
            ),
          )
          .toList(growable: false),
      knownPeriodLabels: [
        for (final lot in _attendanceImportLots)
          _describeVacationAttendancePeriod(lot),
      ],
      activePeriodLabel: _activePeriodLabel,
    );

    final mutableEvents = preparedEvents
        .where((event) => !lockedEventIds.contains(event.localId))
        .toList(growable: false);
    final mutableExistingIds = mutableEvents
        .map((event) => event.localId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (mutableExistingIds.isNotEmpty) {
      await client
          .from(_kHrVacationCalculationsTable)
          .delete()
          .inFilter('vacation_event_id', mutableExistingIds);
    }

    final calculationPayloads = <Map<String, dynamic>>[];
    for (final event in mutableEvents) {
      final eventId = event.localId;
      if (eventId.isEmpty) continue;
      final components = _buildVacationCalculationPayloads(
        eventId: eventId,
        employeeId: row.employeeId,
        exerciseYear: _exerciseYear,
        event: event,
        balance: result.balance,
      );
      calculationPayloads.addAll(components);
    }
    if (calculationPayloads.isNotEmpty) {
      await client
          .from(_kHrVacationCalculationsTable)
          .insert(calculationPayloads);
    }

    await _loadData();
    _showSnack(
      'Vacaciones de ${row.displayName} actualizadas. '
      'El recibo no se genera desde el expediente; se controla después del cierre de Prenómina.',
    );
  }

  // ignore: unused_element
  Future<int> _generateVacationReceipts({
    required _HrVacationSummaryRow row,
    required _HrVacationBalanceDraft balance,
    required List<_HrVacationEventDraft> events,
  }) async {
    final receiptEvents = events
        .where(
          (event) =>
              event.generateReceipt &&
              event.status == _HrVacationEventStatus.aplicado &&
              _vacationEventHasPayrollFootprint(event),
        )
        .toList(growable: false);
    if (receiptEvents.isEmpty) return 0;

    final contpaqLot = _vacationLotForPeriod(
      _attendanceImportLots,
      _HrVacationAttendanceImportSource.contpaq,
      _activePeriodLabel,
    );
    final contpaqEntry = contpaqLot?.entries
        .cast<_HrVacationAttendanceImportedEntry?>()
        .firstWhere(
          (entry) => entry?.employeeId == row.employeeId,
          orElse: () => null,
        );
    var generated = 0;
    for (final event in receiptEvents) {
      final bytes = await _buildVacationReceiptPdfBytes(
        row: row,
        balance: balance,
        event: event,
        contpaqEntry: contpaqEntry,
        contpaqPeriodLabel: contpaqLot?.periodLabel ?? '',
      );
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${Directory.systemTemp.path}/recibo_vacaciones_${_vacationFileSlug(row.displayName)}_${event.startDate.year}${event.startDate.month.toString().padLeft(2, '0')}${event.startDate.day.toString().padLeft(2, '0')}_$stamp.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await _openVacationReceiptPdf(file.path);
      generated += 1;
    }
    return generated;
  }

  Future<void> _openVacationReceiptPdf(String path) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', <String>[path]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', <String>['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', <String>[path]);
    } else {
      throw UnsupportedError('Plataforma no soportada para abrir PDF');
    }
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
  }

  Future<List<_HrVacationEventDraft>> _prepareVacationEventsForPersistence({
    required _HrVacationSummaryRow row,
    required List<_HrVacationEventDraft> events,
  }) async {
    final client = Supabase.instance.client;
    final employee = _findVacationEmployeeById(row.employeeId, _employees);
    final ngtecoLot = _vacationLotForPeriod(
      _attendanceImportLots,
      _HrVacationAttendanceImportSource.ngteco,
      _activePeriodLabel,
    );
    final contpaqLot = _vacationLotForPeriod(
      _attendanceImportLots,
      _HrVacationAttendanceImportSource.contpaq,
      _activePeriodLabel,
    );
    final activeAttendancePeriodLabel = _activePeriodLabel;
    final activeAttendanceRange = _resolveVacationAttendanceActiveRange(
      ngtecoLot: ngtecoLot,
      contpaqLot: contpaqLot,
      activePeriodLabel: activeAttendancePeriodLabel,
    );
    final rawRows = await fetchAllSupabaseRows(
      (from, to) => client
          .from(_kHrAttendanceDailyRecordsTable)
          .select()
          .eq('employee_id', row.employeeId)
          .order('source_date')
          .order('created_at')
          .range(from, to),
    );
    final attendanceRows = ((rawRows as List?) ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: true);

    final previousSyncedDates = _collectVacationAppliedDateLabels(row.events);
    final revertUpdates = <Map<String, dynamic>>[];
    for (final attendanceRow in attendanceRows) {
      final sourceDate = (attendanceRow['source_date'] ?? '').toString();
      if (!previousSyncedDates.contains(sourceDate)) continue;
      if (_attendanceRowHasPunches(attendanceRow)) continue;
      final notes = (attendanceRow['notes'] ?? '').toString();
      if (!notes.contains(_kHrVacationAttendanceSyncPrefix)) continue;
      final nextNotes = _removeVacationAttendanceNotes(notes);
      final reverted = _copyAttendanceRowForUpdate(
        attendanceRow,
        status: 'falto',
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
        ..['status'] = 'falto'
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
          .from(_kHrAttendanceDailyRecordsTable)
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
      _normalizeVacationEventDraft(event, forceDays: !event.daysManuallyEdited);
      event.attendancePeriodLabel = '';
      event.attendanceSyncStatus =
          !event.impactAttendance ||
              event.status == _HrVacationEventStatus.cancelado
          ? _HrVacationSyncStatus.omitido
          : _HrVacationSyncStatus.pendiente;
      event.prenominaSyncStatus =
          !event.impactPrenomina ||
              event.status == _HrVacationEventStatus.cancelado
          ? _HrVacationSyncStatus.omitido
          : _HrVacationSyncStatus.pendiente;

      if (!event.impactAttendance ||
          event.status != _HrVacationEventStatus.aplicado) {
        continue;
      }

      final sourceDates = _vacationDateRangeLabels(
        event.startDate,
        event.endDate,
      );
      if (activeAttendancePeriodLabel.isEmpty ||
          activeAttendanceRange == null) {
        event.attendanceSyncStatus = _HrVacationSyncStatus.pendiente;
        continue;
      }

      final note = _buildVacationAttendanceSyncNote(event);
      final syncUpdates = <Map<String, dynamic>>[];
      var appliedAny = false;
      var skippedByPunch = false;
      final touchedPeriods = <String>{};
      for (final sourceDate in sourceDates) {
        if (!_isVacationAttendanceDateWithinRange(
          sourceDate,
          activeAttendanceRange,
        )) {
          continue;
        }
        final key = '$activeAttendancePeriodLabel|$sourceDate';
        final attendanceRow = attendanceByPeriodDate[key];
        if (attendanceRow == null) {
          if (employee == null ||
              !_shouldCreateVacationAttendanceRow(
                employee: employee,
                sourceDate: sourceDate,
              )) {
            continue;
          }
          final created = _buildVacationAttendanceRow(
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
        if (_attendanceRowHasPunches(attendanceRow)) {
          skippedByPunch = true;
          continue;
        }
        final mergedNotes = _mergeVacationAttendanceNotes(
          (attendanceRow['notes'] ?? '').toString(),
          note,
        );
        final updated = _copyAttendanceRowForUpdate(
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
            .from(_kHrAttendanceDailyRecordsTable)
            .upsert(
              syncUpdates,
              onConflict: 'period_label,employee_id,source_date',
            );
      }
      event.attendanceSyncStatus = appliedAny
          ? _HrVacationSyncStatus.aplicado
          : skippedByPunch
          ? _HrVacationSyncStatus.omitido
          : _HrVacationSyncStatus.pendiente;
    }

    return events;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleTapRow(_HrVacationSummaryRow row, int rowIndex) {
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
      _ensureSelectedRowVisible(row.employeeId);
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
    );
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    setState(() => _dragSelectionMoved = false);
    _ensureSelectedRowVisible(row.employeeId);
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
    _ensureSelectedRowVisible(rowId);
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
    _ensureSelectedRowVisible(rowId);
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
    _ensureSelectedRowVisible(rowId);
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
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      _dragSelectionBaseIds = <String>{};
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
    _HrVacationSummaryRow row,
    int rowIndex,
  ) async {
    _prepareRowSelectionForActions(rowId: row.employeeId, rowIndex: rowIndex);
    final selected = await showContractContextMenu<_HrVacationRowAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      entries: const [
        ContractMenuEntry(
          value: _HrVacationRowAction.open,
          label: 'Editar vacaciones',
          icon: Icons.beach_access_rounded,
        ),
      ],
    );
    if (selected != null && mounted) {
      await _openSummaryRow(row);
    }
  }

  bool _hasActiveFilter(String columnId) =>
      (_columnFilters[columnId] ?? const <String>{}).isNotEmpty ||
      _columnDateRangeFilters.containsKey(columnId);

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (_isDateFilterColumn(columnId)) {
      final result = await _showHrDateRangeFilterDialog(
        context,
        label: label,
        bounds: _dateBoundsForColumn(columnId),
        initialRange: _columnDateRangeFilters[columnId],
      );
      if (!mounted || result == null) return;
      setState(() {
        if (result.clear) {
          _columnDateRangeFilters.remove(columnId);
        } else if (result.range != null) {
          _columnDateRangeFilters[columnId] = DateTimeRange(
            start: DateUtils.dateOnly(result.range!.start),
            end: DateUtils.dateOnly(result.range!.end),
          );
        }
        _columnFilters.remove(columnId);
        _currentPage = 0;
      });
      _rebuildRows();
      return;
    }

    final options =
        _allRows
            .map((row) => _vacationCellValueForColumn(row, columnId))
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
      _columnDateRangeFilters.remove(columnId);
      _currentPage = 0;
    });
    _rebuildRows();
  }

  bool _isDateFilterColumn(String columnId) =>
      columnId == 'fecha_ingreso' || columnId == 'fecha_alta';

  DateTimeRange _dateBoundsForColumn(String columnId) {
    DateTime? minDate;
    DateTime? maxDate;
    for (final row in _allRows) {
      final date = _vacationDateValueForColumn(row, columnId);
      if (date == null) continue;
      final dateOnly = DateUtils.dateOnly(date);
      if (minDate == null || dateOnly.isBefore(minDate)) minDate = dateOnly;
      if (maxDate == null || dateOnly.isAfter(maxDate)) maxDate = dateOnly;
    }
    if (minDate == null || maxDate == null) {
      for (final employee in _employees) {
        final date = switch (columnId) {
          'fecha_ingreso' => employee.fechaIngreso,
          'fecha_alta' => employee.fechaAlta,
          _ => null,
        };
        if (date == null) continue;
        final dateOnly = DateUtils.dateOnly(date);
        if (minDate == null || dateOnly.isBefore(minDate)) minDate = dateOnly;
        if (maxDate == null || dateOnly.isAfter(maxDate)) maxDate = dateOnly;
      }
    }
    final now = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: minDate ?? DateTime(now.year - 3, 1, 1),
      end: maxDate ?? DateTime(now.year + 3, 12, 31),
    );
  }

  void _focusEmployeeRow(String employeeId) {
    final globalIndex = _allRows.indexWhere(
      (row) => row.employeeId == employeeId,
    );
    if (globalIndex < 0) return;
    _selectedRowId = employeeId;
    _currentPage = globalIndex ~/ _pageSize;
    _rebuildRows();
    final pageIndex = _visibleRows.indexWhere(
      (row) => row.employeeId == employeeId,
    );
    if (pageIndex >= 0) {
      _navigationController.focusGridCell(rowIndex: pageIndex, columnIndex: 0);
      unawaited(_gridVisibilityCoordinator.ensureGridRowVisible(pageIndex));
    }
    _rowsFocusNode.requestFocus();
  }

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

  void _configureGrid() {
    _navigationController.configure(
      insertColumnCount: 0,
      gridColumnCount: _kVacationGridColumns.length,
      rowCount: _visibleRows.length,
    );
  }

  GlobalKey _rowKeyForId(String rowId) =>
      _rowKeys.putIfAbsent(rowId, () => GlobalKey());

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
        centerBuilder: (_, _) => const _HrVacationHeaderBrand(),
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
                      : _HrVacationWorkspace(
                          allRows: _allRows,
                          rows: _visibleRows,
                          totalRows: _allRows.length,
                          selectedCount:
                              _selectionController.selectedIds.length,
                          activePeriodLabel: _activePeriodLabel,
                          periodOptions: _periodOptions,
                          exerciseYear: _exerciseYear,
                          navigationController: _navigationController,
                          selectionController: _selectionController,
                          rowsScrollController: _rowsScrollController,
                          visibilityCoordinator: _gridVisibilityCoordinator,
                          rowsViewportKey: _rowsViewportKey,
                          rowsFocusNode: _rowsFocusNode,
                          selectedRowId: _selectedRowId,
                          rowKeyForId: _rowKeyForId,
                          onRowsPointerMove: _handleRowsPointerMove,
                          hoveredRowId: _hoveredRowId,
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
                          onPreviousPage: _currentPage > 0
                              ? _previousPage
                              : null,
                          onNextPage:
                              ((_currentPage + 1) * _pageSize) < _allRows.length
                              ? _nextPage
                              : null,
                          onPageSizeChanged: _changePageSize,
                          onOpenSelectedRow: () async {
                            final row = _activeRow();
                            if (row != null) await _openSummaryRow(row);
                          },
                          onSelectPeriod: _selectPeriod,
                          onEscape: _handleEscape,
                          onOpenActiveCell: _openActiveRecord,
                          hasActiveFilter: _hasActiveFilter,
                          onOpenFilter: _openColumnFilter,
                          onHoverRowChanged: (value) =>
                              setState(() => _hoveredRowId = value),
                        ),
                ),
              ),
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.vacations,
                openPersonnel: _openPersonnel,
                openAttendance: _openAttendance,
                openImportConciliation: _openImportConciliation,
                openVacations: () async {},
                openPermissions: _openPermissions,
                openPrenomina: _openPrenomina,
                openNomina: _openNomina,
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.vacations,
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
    _HrVacationSummaryRow row,
    int rowIndex,
  ) {
    _prepareRowSelectionForActions(rowId: row.employeeId, rowIndex: rowIndex);
  }

  _HrVacationSummaryRow? _activeRow() {
    if (_selectedRowId == null) return null;
    for (final row in _allRows) {
      if (row.employeeId == _selectedRowId) return row;
    }
    return null;
  }
}

class _HrVacationWorkspace extends StatelessWidget {
  final List<_HrVacationSummaryRow> allRows;
  final List<_HrVacationSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final int exerciseYear;
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
  final void Function(_HrVacationSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrVacationSummaryRow row, int rowIndex)
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
    _HrVacationSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final Future<void> Function(_HrVacationSummaryRow row) onOpenRow;
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

  const _HrVacationWorkspace({
    required this.allRows,
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.exerciseYear,
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
        ? _kVacationGridColumns[active.columnIndex.clamp(
                0,
                _kVacationGridColumns.length - 1,
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
            topBar: _HrVacationModuleTopBar(
              totalRows: totalRows,
              rows: allRows,
              selectedCount: selectedCount,
              activeCellLabel: activeLabel == null
                  ? null
                  : 'Celda: $activeLabel',
              exerciseYear: exerciseYear,
              activePeriodLabel: activePeriodLabel,
              periodOptions: periodOptions,
              onSelectPeriod: onSelectPeriod,
              onOpenSelectedRow: () => unawaited(onOpenSelectedRow()),
            ),
            body: _HrVacationGrid(
              rows: rows,
              hoveredRowId: hoveredRowId,
              selectedRowId: selectedRowId,
              navigationController: navigationController,
              selectionController: selectionController,
              rowsScrollController: rowsScrollController,
              visibilityCoordinator: visibilityCoordinator,
              rowsViewportKey: rowsViewportKey,
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
              rowKeyForId: rowKeyForId,
              onRowsPointerMove: onRowsPointerMove,
            ),
            footer: _HrVacationGridFooter(
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

class _HrVacationGrid extends StatelessWidget {
  final List<_HrVacationSummaryRow> rows;
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
  final void Function(_HrVacationSummaryRow row, int rowIndex) onTapRow;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(_HrVacationSummaryRow row) onOpenRow;
  final void Function(_HrVacationSummaryRow row, int rowIndex)
  onPrepareRowActions;
  final Future<void> Function(
    TapDownDetails details,
    _HrVacationSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final ValueChanged<String?> onHoverRowChanged;

  const _HrVacationGrid({
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
                  _HrVacationGridHeader(
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
                                  const _HrVacationEmptyState()
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
                                        child: _HrVacationGridRow(
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
                                          visibilityCoordinator:
                                              visibilityCoordinator,
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

class _HrVacationEmptyState extends StatelessWidget {
  const _HrVacationEmptyState();

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
              Icons.beach_access_rounded,
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
              'Ajusta filtros o completa Personal RH para comenzar a tabular vacaciones por ejercicio.',
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

class _HrVacationGridHeader extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;

  const _HrVacationGridHeader({
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
              width: _kHrVacationIdW,
              child: _HrVacationHeaderText(
                'ID',
                style: style,
                active: hasActiveFilter('id'),
                onFilter: () => onOpenFilter('id', 'ID'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationNameW,
              child: _HrVacationHeaderText(
                'NOMBRE',
                style: style,
                active: hasActiveFilter('nombre'),
                onFilter: () => onOpenFilter('nombre', 'Nombre'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationIngresoW,
              child: _HrVacationHeaderText(
                'FECHA INGRESO',
                style: style,
                centered: true,
                active: hasActiveFilter('fecha_ingreso'),
                onFilter: () => onOpenFilter('fecha_ingreso', 'Fecha ingreso'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationAltaW,
              child: _HrVacationHeaderText(
                'FECHA ALTA',
                style: style,
                centered: true,
                active: hasActiveFilter('fecha_alta'),
                onFilter: () => onOpenFilter('fecha_alta', 'Fecha alta'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationEntitledW,
              child: _HrVacationHeaderText(
                'DÍAS CORRESPONDEN',
                style: style,
                centered: true,
                active: hasActiveFilter('dias_corresponden'),
                onFilter: () =>
                    onOpenFilter('dias_corresponden', 'Días corresponden'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationAppliedW,
              child: _HrVacationHeaderText(
                'DÍAS APLICADOS',
                style: style,
                centered: true,
                active: hasActiveFilter('dias_aplicados'),
                onFilter: () =>
                    onOpenFilter('dias_aplicados', 'Días aplicados'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationAvailableW,
              child: _HrVacationHeaderText(
                'DÍAS DISPONIBLES',
                style: style,
                centered: true,
                active: hasActiveFilter('dias_disponibles'),
                onFilter: () =>
                    onOpenFilter('dias_disponibles', 'Días disponibles'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationStatusW,
              child: _HrVacationHeaderText(
                'ESTADO',
                style: style,
                centered: true,
                active: hasActiveFilter('estatus'),
                onFilter: () => onOpenFilter('estatus', 'Estado'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _kHrVacationActionsW,
              child: _HrVacationHeaderText(
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

class _HrVacationHeaderText extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool centered;
  final bool active;
  final VoidCallback? onFilter;

  const _HrVacationHeaderText(
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

class _HrVacationGridRow extends StatelessWidget {
  final _HrVacationSummaryRow row;
  final int rowIndex;
  final bool hovered;
  final bool active;
  final bool selected;
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final VoidCallback onTap;
  final Future<void> Function() onOpen;
  final VoidCallback onPrepareActionsMenu;
  final ValueChanged<bool>? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final GestureTapDownCallback? onSecondaryTapDown;
  final ValueChanged<String?> onHoverChanged;

  const _HrVacationGridRow({
    required this.row,
    required this.rowIndex,
    required this.hovered,
    required this.active,
    required this.selected,
    required this.visibilityCoordinator,
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
        child: GestureDetector(
          key: visibilityCoordinator.keyForCell(
            zone: GridNavigationZone.grid,
            rowIndex: rowIndex,
            columnIndex: 0,
          ),
          behavior: HitTestBehavior.translucent,
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
                      width: _kHrVacationIdW,
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
                    SizedBox(
                      width: _kHrVacationNameW,
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
                      width: _kHrVacationIngresoW,
                      child: Text(
                        row.fechaIngresoLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF24103D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: _kHrVacationAltaW,
                      child: Text(
                        row.fechaAltaLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF24103D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: _kHrVacationEntitledW,
                      child: Text(
                        _formatVacationDays(row.daysEntitled),
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
                      width: _kHrVacationAppliedW,
                      child: Text(
                        _formatVacationDays(row.daysApplied),
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
                      width: _kHrVacationAvailableW,
                      child: Text(
                        _formatVacationDays(row.daysAvailable),
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
                      width: _kHrVacationStatusW,
                      child: Center(
                        child: _HrVacationStatusBadge(label: row.statusLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: _kHrVacationActionsW,
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
                          child: EditableRowActionsButton<_HrVacationRowAction>(
                            tooltip: 'Acciones de vacaciones',
                            iconColor: hasSelection
                                ? Colors.white
                                : const Color(0xFF6E47A8),
                            onBeforeOpen: onPrepareActionsMenu,
                            entries: const [
                              ContractMenuEntry(
                                value: _HrVacationRowAction.open,
                                label: 'Editar vacaciones',
                                icon: Icons.beach_access_rounded,
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
    );
  }
}

class _HrVacationModuleTopBar extends StatelessWidget {
  final int totalRows;
  final List<_HrVacationSummaryRow> rows;
  final int selectedCount;
  final String? activeCellLabel;
  final int exerciseYear;
  final String activePeriodLabel;
  final List<String> periodOptions;
  final ValueChanged<String> onSelectPeriod;
  final VoidCallback onOpenSelectedRow;

  const _HrVacationModuleTopBar({
    required this.totalRows,
    required this.rows,
    required this.selectedCount,
    required this.activeCellLabel,
    required this.exerciseYear,
    required this.activePeriodLabel,
    required this.periodOptions,
    required this.onSelectPeriod,
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
            'Vacaciones',
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
              final info = _HrVacationSelectionInfo(
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
                    icon: const Icon(Icons.beach_access_rounded),
                    label: const Text('Editar vacaciones'),
                  ),
                  _HrVacationExercisePill(year: exerciseYear),
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
          child: _HrVacationMetricCard(totalRows: totalRows, rows: rows),
        ),
      ],
    );
  }
}

class _HrVacationSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final String? activeCellLabel;

  const _HrVacationSelectionInfo({
    required this.selectedCount,
    required this.activeCellLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          selectedCount == 1
              ? '1 registro seleccionado'
              : '${_fmtVacationInt(selectedCount)} registros seleccionados',
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

class _HrVacationExercisePill extends StatelessWidget {
  final int year;

  const _HrVacationExercisePill({required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EAFF).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x66B084FF)),
      ),
      child: Text(
        'Ejercicio $year',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF6E47A8),
        ),
      ),
    );
  }
}

class _HrVacationMetricCard extends StatelessWidget {
  final int totalRows;
  final List<_HrVacationSummaryRow> rows;

  const _HrVacationMetricCard({required this.totalRows, required this.rows});

  @override
  Widget build(BuildContext context) {
    final allEvents = rows.expand((row) => row.events).toList(growable: false);
    final attendanceReady = allEvents
        .where(_vacationEventCountsAsAttendanceApplied)
        .length;
    final attendanceReview = allEvents
        .where(_vacationEventCountsAsAttendanceReview)
        .length;
    final fiscalSeeded = allEvents
        .where(_vacationRecordIsContpaqImported)
        .length;
    final committedDays = rows.fold<double>(
      0,
      (sum, row) => sum + row.daysApplied,
    );
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
              Icons.beach_access_rounded,
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
                'VACACIONES RH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6E47A8),
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                _fmtVacationInt(totalRows),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24103D),
                  height: 1,
                ),
              ),
              Text(
                'Filtrado (${_fmtVacationInt(totalRows)} registros)',
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
                  _HrVacationMetricPill(
                    label: 'Asistencia lista: $attendanceReady',
                  ),
                  _HrVacationMetricPill(
                    label: 'Revisión RH: $attendanceReview',
                  ),
                  _HrVacationMetricPill(label: 'Fiscal CONTPAQ: $fiscalSeeded'),
                  _HrVacationMetricPill(
                    label:
                        'Días comprometidos: ${_formatVacationDays(committedDays)}',
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

class _HrVacationMetricPill extends StatelessWidget {
  final String label;

  const _HrVacationMetricPill({required this.label});

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

class _HrDateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;

  const _HrDateFilterDialogResult({this.range, this.clear = false});
}

Future<_HrDateFilterDialogResult?> _showHrDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_HrDateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? bounds.start).year,
        (initialRange?.start ?? bounds.start).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
      bool withinBounds(DateTime day) {
        final d = dateOnly(day);
        return !d.isBefore(dateOnly(bounds.start)) &&
            !d.isAfter(dateOnly(bounds.end));
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
          final leading = (monthFirst.weekday + 6) % 7;
          final gridStart = monthFirst.subtract(Duration(days: leading));
          final rangePreviewEnd = end ?? hover;

          bool inPreviewRange(DateTime day) {
            if (start == null || rangePreviewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(rangePreviewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
          }

          _HrDateFilterDialogResult? buildApplyResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _HrDateFilterDialogResult(
              range: DateTimeRange(start: from, end: to),
            );
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(dialogContext);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                final applyResult = buildApplyResult();
                if (applyResult != null) {
                  Navigator.pop(dialogContext, applyResult);
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _hrFilterDialogDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setLocalState(
                                  () => displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month - 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _hrDateFilterMonthLabel(displayMonth),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setLocalState(
                                  () => displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month + 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: const [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'L',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'J',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'V',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'S',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'D',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 6 * 42,
                            child: Column(
                              children: List.generate(6, (week) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(7, (weekday) {
                                      final day = gridStart.add(
                                        Duration(days: week * 7 + weekday),
                                      );
                                      final inMonth =
                                          day.month == displayMonth.month;
                                      final enabled = withinBounds(day);
                                      final selectedStart =
                                          start != null &&
                                          isSameDay(day, start!);
                                      final selectedEnd =
                                          end != null && isSameDay(day, end!);
                                      final inRange = inPreviewRange(day);
                                      return Expanded(
                                        child: MouseRegion(
                                          onEnter: enabled
                                              ? (_) => setLocalState(
                                                  () => hover = day,
                                                )
                                              : null,
                                          child: GestureDetector(
                                            onTap: !enabled
                                                ? null
                                                : () => setLocalState(() {
                                                    final tapped = dateOnly(
                                                      day,
                                                    );
                                                    if (start == null ||
                                                        (start != null &&
                                                            end != null)) {
                                                      start = tapped;
                                                      end = null;
                                                    } else {
                                                      end = tapped;
                                                    }
                                                  }),
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    selectedStart || selectedEnd
                                                    ? humanResourcesAreaTokens
                                                          .primary
                                                    : inRange
                                                    ? Colors.white.withValues(
                                                        alpha: 0.16,
                                                      )
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color:
                                                      selectedStart ||
                                                          selectedEnd
                                                      ? Colors.white
                                                      : Colors.white.withValues(
                                                          alpha: inRange
                                                              ? 0.28
                                                              : 0.06,
                                                        ),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  fontWeight:
                                                      selectedStart ||
                                                          selectedEnd
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: !enabled
                                                      ? Colors.white24
                                                      : inMonth
                                                      ? Colors.white
                                                      : Colors.white54,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            start == null
                                ? 'Selecciona el rango de fechas.'
                                : end == null
                                ? 'Inicio: ${_formatHrDateFilter(start!)}'
                                : 'Rango: ${_formatHrDateFilter(start!)} - ${_formatHrDateFilter(end!)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _hrInvFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _hrInvFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _HrDateFilterDialogResult(clear: true),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: _hrInvFilterFilledButtonStyle(),
                                onPressed: () {
                                  final applyResult = buildApplyResult();
                                  if (applyResult == null) return;
                                  Navigator.pop(dialogContext, applyResult);
                                },
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
        },
      );
    },
  );
}

BoxDecoration _hrFilterDialogDecoration() {
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

ButtonStyle _hrInvFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFF1E7FF),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    backgroundColor: const Color(0xFF34204E).withValues(alpha: 0.72),
  );
}

ButtonStyle _hrInvFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: humanResourcesAreaTokens.primary,
    foregroundColor: Colors.white,
  );
}

String _hrDateFilterMonthLabel(DateTime month) {
  const months = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return '${months[month.month - 1]} ${month.year}';
}

String _formatHrDateFilter(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}

class _HrVacationGridFooter extends StatelessWidget {
  final int rows;
  final int totalRows;
  final int selectedCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HrVacationGridFooter({
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
                style: _hrVacationActionOutlinedButtonStyle(),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${_fmtVacationInt(currentPage + 1)} de ${_fmtVacationInt(totalPages)}',
              ),
              OutlinedButton.icon(
                style: _hrVacationActionOutlinedButtonStyle(),
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
                  decoration: _hrVacationFieldDecoration(),
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
              Text('Mostrando: ${_fmtVacationInt(rows)}'),
              Text('Total: ${_fmtVacationInt(totalRows)}'),
              Text('Selección: ${_fmtVacationInt(selectedCount)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrVacationHeaderBrand extends StatelessWidget {
  const _HrVacationHeaderBrand();

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
              'Vacaciones',
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

enum _HrVacationEditAction { save, previous, next }

class _HrVacationEditResult {
  final _HrVacationEditAction action;
  final _HrVacationBalanceDraft balance;
  final List<_HrVacationEventDraft> events;

  const _HrVacationEditResult({
    required this.action,
    required this.balance,
    required this.events,
  });
}

class _HrVacationEditDialog extends StatefulWidget {
  final _HrVacationSummaryRow row;
  final List<_HrVacationRule> rules;
  final List<_HrVacationCalculationRecord> calculations;
  final bool canGoPrevious;
  final bool canGoNext;

  const _HrVacationEditDialog({
    required this.row,
    required this.rules,
    required this.calculations,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  State<_HrVacationEditDialog> createState() => _HrVacationEditDialogState();
}

class _HrVacationEditDialogState extends State<_HrVacationEditDialog> {
  final FocusNode _dialogFocusNode = FocusNode(debugLabel: 'hrVacationDialog');
  late final _HrVacationBalanceDraft _balance =
      _HrVacationBalanceDraft.fromSummaryRow(widget.row);
  late final List<_HrVacationEventDraft> _events = widget.row.events
      .map(_HrVacationEventDraft.fromRecord)
      .toList(growable: true);

  @override
  void initState() {
    super.initState();
    for (final event in _events) {
      _refreshVacationEventDraft(event, forceDays: !event.daysManuallyEdited);
    }
    _syncDerivedTotals();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    super.dispose();
  }

  void _syncDerivedTotals() {
    final totals = _summarizeVacationDraftEvents(_events);
    _balance.daysPaid = totals.daysPaid;
    _balance.daysEnjoyed = totals.daysEnjoyed;
    _balance.daysReserved = totals.daysReserved;
    _balance.daysTaken = totals.daysCommitted;
    _balance.daysAvailable = (_balance.daysEntitled - totals.daysCommitted)
        .clamp(0, 9999)
        .toDouble();
  }

  void _refreshVacationEventDraft(
    _HrVacationEventDraft draft, {
    bool forceDays = false,
  }) => _normalizeVacationEventDraft(draft, forceDays: forceDays);

  Future<void> _addEvent() async {
    final now = DateTime.now();
    setState(() {
      final draft = _HrVacationEventDraft(
        localId: 'event_${now.microsecondsSinceEpoch}',
        eventType: _HrVacationEventType.vacacionesDisfrutadas,
        status: _HrVacationEventStatus.pendiente,
        startDate: DateTime(now.year, now.month, now.day),
        endDate: DateTime(now.year, now.month, now.day),
        daysApplied: 1.0,
        additionalPaidDays: 0,
        attendancePeriodLabel: '',
        attendanceSyncStatus: _HrVacationSyncStatus.pendiente,
        prenominaSyncStatus: _HrVacationSyncStatus.pendiente,
        impactAttendance: true,
        impactPrenomina: false,
        generateReceipt: false,
        isrMethod: _HrVacationIsrMethod.tarifaSemanal,
        isrOrdinaryMonthlyIncomeOverrideText: '',
        isrRetentionOverrideText: '',
        receiptGroupKey: '',
        notes: '',
      );
      _refreshVacationEventDraft(draft, forceDays: true);
      _events.add(draft);
      _syncDerivedTotals();
    });
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final fallbackInitial =
        initial ??
        widget.row.fechaIngreso ??
        widget.row.fechaAlta ??
        DateTime(widget.row.exerciseYear, 1, 1);
    final initialDate = DateUtils.dateOnly(fallbackInitial);
    final lowerCandidates = <DateTime>[
      DateTime(widget.row.exerciseYear - 2, 1, 1),
      initialDate,
      if (widget.row.fechaIngreso != null)
        DateUtils.dateOnly(widget.row.fechaIngreso!),
      if (widget.row.fechaAlta != null)
        DateUtils.dateOnly(widget.row.fechaAlta!),
    ]..sort();
    final upperCandidates = <DateTime>[
      DateTime(widget.row.exerciseYear + 2, 12, 31),
      initialDate,
      if (widget.row.fechaIngreso != null)
        DateUtils.dateOnly(widget.row.fechaIngreso!),
      if (widget.row.fechaAlta != null)
        DateUtils.dateOnly(widget.row.fechaAlta!),
    ]..sort();
    final firstDate = lowerCandidates.first;
    final lastDate = upperCandidates.last;
    final safeInitial = initialDate.isBefore(firstDate)
        ? firstDate
        : initialDate.isAfter(lastDate)
        ? lastDate
        : initialDate;
    return showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  bool _hasEditableTextFocus() {
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  void _showDialogSnack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateBeforeSave() {
    if (_balance.baseDatePolicy == _HrVacationBaseDatePolicy.manualRh) {
      if (_balance.baseManualDate == null) {
        _showDialogSnack('Selecciona una fecha manual RH antes de guardar.');
        return false;
      }
      if (_balance.manualOverrideReason.trim().isEmpty) {
        _showDialogSnack('Captura la justificación RH del criterio manual.');
        return false;
      }
    }
    return true;
  }

  void _save([_HrVacationEditAction action = _HrVacationEditAction.save]) {
    _syncDerivedTotals();
    _balance.manualOverride =
        _balance.baseDatePolicy == _HrVacationBaseDatePolicy.manualRh;
    _balance.manualOverrideReason = _balance.manualOverrideReason.trim();
    if (!_validateBeforeSave()) return;
    Navigator.of(context).pop(
      _HrVacationEditResult(
        action: action,
        balance: _balance,
        events: List<_HrVacationEventDraft>.of(_events),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncDerivedTotals();
    final attendanceReadyCount = _events
        .where(
          (event) =>
              event.impactAttendance &&
              event.status == _HrVacationEventStatus.aplicado &&
              event.attendanceSyncStatus == _HrVacationSyncStatus.aplicado,
        )
        .length;
    final attendanceReviewCount = _events
        .where(
          (event) =>
              event.impactAttendance &&
              event.status == _HrVacationEventStatus.aplicado &&
              event.attendanceSyncStatus == _HrVacationSyncStatus.omitido,
        )
        .length;
    final fiscalImportedCount = _events
        .where((event) => event.isContpaqImported)
        .length;
    final prenominaPendingCount = _events
        .where(
          (event) =>
              event.impactPrenomina &&
              event.status != _HrVacationEventStatus.cancelado &&
              event.prenominaSyncStatus == _HrVacationSyncStatus.pendiente,
        )
        .length;
    final selectedRule = _resolveVacationRuleByYears(
      rules: widget.rules,
      years: _balance.antiguedadYears,
    );
    final salaryWeekly = _parseVacationMoney(widget.row.salario);
    final salaryPerceivedWeekly = _parseVacationMoney(
      widget.row.salarioPercibido,
    );
    final salaryDaily = salaryWeekly > 0 ? salaryWeekly / 7 : 0.0;
    final salaryPerceivedDaily = salaryPerceivedWeekly > 0
        ? salaryPerceivedWeekly / 7
        : 0.0;
    final additionalPaidDays = _events
        .where(_vacationEventHasPayrollFootprint)
        .fold<double>(0, (sum, event) => sum + event.additionalPaidDays);
    final payableSalaryDays = _balance.daysPaid + additionalPaidDays;
    final vacationPay = salaryDaily * payableSalaryDays;
    final vacationPayPerceived = salaryPerceivedDaily * payableSalaryDays;
    final bonusPay = salaryDaily * _balance.daysPaid * 0.25;
    final bonusPayPerceived = salaryPerceivedDaily * _balance.daysPaid * 0.25;
    final salaryDelta = salaryPerceivedWeekly - salaryWeekly;
    final vacationDelta = vacationPayPerceived - vacationPay;
    final bonusDelta = bonusPayPerceived - bonusPay;

    return Focus(
      focusNode: _dialogFocusNode,
      autofocus: true,
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
          _save(_HrVacationEditAction.previous);
          return KeyEventResult.handled;
        }
        if (!_hasEditableTextFocus() &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.canGoNext) {
          _save(_HrVacationEditAction.next);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ContractDialogShell(
        child: Container(
          width: 1320,
          constraints: BoxConstraints(
            maxWidth: 1320,
            maxHeight: MediaQuery.sizeOf(context).height - 48,
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F3FF).withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x66B084FF)),
          ),
          child: Column(
            children: [
              HumanResourcesCompactDialogHeader(
                title: 'Vacaciones',
                contextLabel:
                    'Ejercicio ${widget.row.exerciseYear} · Control y aplicación vacacional',
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
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.64),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0x44B084FF),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFB891FF),
                                                Color(0xFF8B5CF6),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.beach_access_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'EXPEDIENTE VACACIONAL',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF6E47A8),
                                                  letterSpacing: 0.7,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                widget.row.displayName,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF24103D),
                                                  height: 1.12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _HrVacationStatusBadge(
                                          label: 'ID #${widget.row.employeeId}',
                                        ),
                                        _HrVacationStatusBadge(
                                          label: widget.row.empresa.isEmpty
                                              ? 'Empresa pendiente'
                                              : widget.row.empresa,
                                        ),
                                        _HrVacationStatusBadge(
                                          label: _balance.status.label,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(
                                color: Color(0x44B084FF),
                                height: 1,
                              ),
                              const SizedBox(height: 12),
                              _HrVacationInfoLine(
                                label: 'Fecha ingreso',
                                value: widget.row.fechaIngresoLabel,
                              ),
                              _HrVacationInfoLine(
                                label: 'Fecha alta',
                                value: widget.row.fechaAltaLabel,
                              ),
                              _HrVacationInfoLine(
                                label: 'Salario',
                                value: _formatVacationMoney(salaryWeekly),
                              ),
                              _HrVacationInfoLine(
                                label: 'Salario percibido',
                                value: _formatVacationMoney(
                                  salaryPerceivedWeekly,
                                ),
                              ),
                              _HrVacationInfoLine(
                                label: 'Diferencia semanal',
                                value: _formatVacationMoney(salaryDelta),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Base de cálculo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF6E47A8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final policy
                                  in _HrVacationBaseDatePolicy.values)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _HrVacationSelectorTile(
                                    title: policy.label,
                                    subtitle: policy.description,
                                    selected: _balance.baseDatePolicy == policy,
                                    onTap: () {
                                      setState(() {
                                        _balance.baseDatePolicy = policy;
                                        if (policy ==
                                                _HrVacationBaseDatePolicy
                                                    .manualRh &&
                                            _balance.baseManualDate == null) {
                                          _balance.baseManualDate =
                                              widget.row.fechaIngreso ??
                                              widget.row.fechaAlta ??
                                              DateTime(
                                                widget.row.exerciseYear,
                                                1,
                                                1,
                                              );
                                        }
                                        _recomputeBalanceFromPolicy(
                                          widget.row,
                                          _balance,
                                          widget.rules,
                                        );
                                        _balance.manualOverride =
                                            policy ==
                                            _HrVacationBaseDatePolicy.manualRh;
                                      });
                                    },
                                  ),
                                ),
                              if (_balance.baseDatePolicy ==
                                  _HrVacationBaseDatePolicy.manualRh) ...[
                                const SizedBox(height: 4),
                                _HrVacationLabeledField(
                                  label: 'Fecha manual RH',
                                  child: _HrVacationDateField(
                                    value: _formatVacationDate(
                                      _balance.baseManualDate,
                                    ),
                                    onTap: () async {
                                      final picked = await _pickDate(
                                        _balance.baseManualDate,
                                      );
                                      if (picked == null) return;
                                      setState(() {
                                        _balance.baseManualDate = picked;
                                        _balance.manualOverride = true;
                                        _recomputeBalanceFromPolicy(
                                          widget.row,
                                          _balance,
                                          widget.rules,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _HrVacationLabeledField(
                                  label: 'Justificación RH',
                                  child: TextFormField(
                                    initialValue: _balance.manualOverrideReason,
                                    decoration: _hrVacationFieldDecoration()
                                        .copyWith(
                                          hintText:
                                              'Explica por qué RH usa criterio manual.',
                                        ),
                                    minLines: 2,
                                    maxLines: 4,
                                    onChanged: (value) {
                                      _balance.manualOverrideReason = value;
                                      _balance.manualOverride =
                                          value.trim().isNotEmpty ||
                                          _balance.baseDatePolicy ==
                                              _HrVacationBaseDatePolicy
                                                  .manualRh;
                                    },
                                  ),
                                ),
                              ],
                              _HrVacationInfoLine(
                                label: 'Antigüedad calculada',
                                value: '${_balance.antiguedadYears} año(s)',
                              ),
                              _HrVacationInfoLine(
                                label: 'Días corresponden',
                                value: _formatVacationDays(
                                  _balance.daysEntitled,
                                ),
                              ),
                              _HrVacationInfoLine(
                                label: 'Días aplicados',
                                value: _formatVacationDays(_balance.daysTaken),
                              ),
                              _HrVacationInfoLine(
                                label: 'Días pagados',
                                value: _formatVacationDays(_balance.daysPaid),
                              ),
                              _HrVacationInfoLine(
                                label: 'Días disfrutados',
                                value: _formatVacationDays(
                                  _balance.daysEnjoyed,
                                ),
                              ),
                              _HrVacationInfoLine(
                                label: 'Días reservados',
                                value: _formatVacationDays(
                                  _balance.daysReserved,
                                ),
                              ),
                              _HrVacationInfoLine(
                                label: 'Días disponibles',
                                value: _formatVacationDays(
                                  _balance.daysAvailable,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _HrVacationLabeledField(
                                label: 'Estado',
                                child: _HrVacationPickerField(
                                  value: _balance.status.label,
                                  onTap: () async {
                                    final value =
                                        await showSearchablePickerDialog<
                                          _HrVacationBalanceStatus
                                        >(
                                          context,
                                          title: 'Estado',
                                          initialValue: _balance.status,
                                          options: _HrVacationBalanceStatus
                                              .values
                                              .map(
                                                (status) =>
                                                    SearchablePickerOption(
                                                      value: status,
                                                      label: status.label,
                                                    ),
                                              )
                                              .toList(growable: false),
                                        );
                                    if (value == null) return;
                                    setState(() => _balance.status = value);
                                  },
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
                          _HrVacationSectionCard(
                            title: 'Resumen',
                            subtitle:
                                'Saldo, derecho y pago resumido del ejercicio activo.',
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _HrVacationMetricMiniCard(
                                  label: 'DIAS CORRESPONDEN',
                                  value: _formatVacationDays(
                                    _balance.daysEntitled,
                                  ),
                                  helper:
                                      'Tabla legal activa para este ejercicio',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'DIAS APLICADOS',
                                  value: _formatVacationDays(
                                    _balance.daysTaken,
                                  ),
                                  helper: 'Suma viva de eventos capturados',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'DIAS PAGADOS',
                                  value: _formatVacationDays(_balance.daysPaid),
                                  helper: 'Ya con huella fiscal o de recibo',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'DIAS DISFRUTADOS',
                                  value: _formatVacationDays(
                                    _balance.daysEnjoyed,
                                  ),
                                  helper: 'Ya tomados por el colaborador',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'DIAS RESERVADOS',
                                  value: _formatVacationDays(
                                    _balance.daysReserved,
                                  ),
                                  helper: 'Apartados para uso posterior',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'DIAS DISPONIBLES',
                                  value: _formatVacationDays(
                                    _balance.daysAvailable,
                                  ),
                                  helper: 'Saldo listo para RH',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'VACACIONES',
                                  value: _formatVacationMoney(vacationPay),
                                  helper: 'Base salario',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'PRIMA VACACIONAL',
                                  value: _formatVacationMoney(bonusPay),
                                  helper: '25% sobre vacaciones',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'ASISTENCIA LISTA',
                                  value: '$attendanceReadyCount',
                                  helper:
                                      'Eventos ya reflejables en asistencia',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'REVISION RH',
                                  value: '$attendanceReviewCount',
                                  helper:
                                      'Eventos que RH debe revisar manualmente',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'FISCAL CONTPAQ',
                                  value: '$fiscalImportedCount',
                                  helper: 'Eventos sembrados desde CONTPAQ',
                                ),
                                _HrVacationMetricMiniCard(
                                  label: 'PRENOMINA',
                                  value: '$prenominaPendingCount',
                                  helper:
                                      'Eventos con huella pendiente de cierre',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _HrVacationSectionCard(
                                    title: 'Reglas de cálculo',
                                    subtitle:
                                        'Base de fecha, tramo legal y soporte del derecho anual.',
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _HrVacationRuleCard(
                                          title: 'Base activa',
                                          value: _balance.baseDatePolicy.label,
                                          emphasis:
                                              _balance.baseDatePolicy ==
                                              _HrVacationBaseDatePolicy
                                                  .manualRh,
                                        ),
                                        _HrVacationRuleCard(
                                          title: 'Fecha base usada',
                                          value: _formatVacationDate(
                                            switch (_balance.baseDatePolicy) {
                                              _HrVacationBaseDatePolicy
                                                  .fechaIngreso =>
                                                widget.row.fechaIngreso,
                                              _HrVacationBaseDatePolicy
                                                  .fechaAlta =>
                                                widget.row.fechaAlta,
                                              _HrVacationBaseDatePolicy
                                                  .manualRh =>
                                                _balance.baseManualDate,
                                            },
                                          ),
                                        ),
                                        _HrVacationRuleCard(
                                          title: 'Antigüedad',
                                          value:
                                              '${_balance.antiguedadYears} año(s)',
                                        ),
                                        _HrVacationRuleCard(
                                          title: 'Tramo legal',
                                          value:
                                              selectedRule?.rangeLabel ??
                                              'Sin tramo',
                                          emphasis: selectedRule == null,
                                        ),
                                        _HrVacationRuleCard(
                                          title: 'Días que corresponden',
                                          value: _formatVacationDays(
                                            _balance.daysEntitled,
                                          ),
                                        ),
                                        _HrVacationRuleCard(
                                          title: 'Override RH',
                                          value: _balance.manualOverride
                                              ? (_balance.manualOverrideReason
                                                        .trim()
                                                        .isEmpty
                                                    ? 'Manual RH'
                                                    : _balance
                                                          .manualOverrideReason)
                                              : 'Sin override',
                                          emphasis: _balance.manualOverride,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _HrVacationSectionCard(
                                    title: 'Eventos de vacaciones',
                                    subtitle:
                                        'Rangos, días y trazabilidad de impacto en asistencia y prenómina.',
                                    trailing: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF8B5CF6,
                                        ),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: _addEvent,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Evento'),
                                    ),
                                    child: _events.isEmpty
                                        ? const _HrVacationEmptyBlock(
                                            message:
                                                'Todavía no hay eventos capturados. Agrega un rango para comenzar a tabular vacaciones.',
                                          )
                                        : Column(
                                            children: [
                                              for (
                                                var index = 0;
                                                index < _events.length;
                                                index += 1
                                              ) ...[
                                                _HrVacationEventCard(
                                                  draft: _events[index],
                                                  balance: _balance,
                                                  onChanged: () => setState(() {
                                                    _refreshVacationEventDraft(
                                                      _events[index],
                                                      forceDays: !_events[index]
                                                          .daysManuallyEdited,
                                                    );
                                                    _syncDerivedTotals();
                                                  }),
                                                  onPickDate: _pickDate,
                                                  onRemove: () => setState(() {
                                                    _events.removeAt(index);
                                                    _syncDerivedTotals();
                                                  }),
                                                ),
                                                if (index != _events.length - 1)
                                                  const SizedBox(height: 10),
                                              ],
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  _HrVacationSectionCard(
                                    title: 'Componentes de pago',
                                    subtitle:
                                        'Comparativo entre salario y salario percibido para dejar prenómina preparada.',
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _HrVacationPaymentCard(
                                          title: 'Base salario',
                                          dailyLabel:
                                              'Diario ${_formatVacationMoney(salaryDaily)}',
                                          payLabel:
                                              'Vacaciones ${_formatVacationMoney(vacationPay)}',
                                          bonusLabel:
                                              'Prima ${_formatVacationMoney(bonusPay)}',
                                          accentLabel: 'Base administrativa',
                                        ),
                                        _HrVacationPaymentCard(
                                          title: 'Base salario percibido',
                                          dailyLabel:
                                              'Diario ${_formatVacationMoney(salaryPerceivedDaily)}',
                                          payLabel:
                                              'Vacaciones ${_formatVacationMoney(vacationPayPerceived)}',
                                          bonusLabel:
                                              'Prima ${_formatVacationMoney(bonusPayPerceived)}',
                                          accentLabel: 'Base percibida',
                                        ),
                                        _HrVacationPaymentCard(
                                          title: 'Diferencia entre bases',
                                          dailyLabel:
                                              'Semanal ${_formatVacationMoney(salaryDelta)}',
                                          payLabel:
                                              'Vacaciones ${_formatVacationMoney(vacationDelta)}',
                                          bonusLabel:
                                              'Prima ${_formatVacationMoney(bonusDelta)}',
                                          accentLabel: 'Brecha RH',
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
                      child: _HrVacationInlineNote(
                        icon: Icons.info_outline_rounded,
                        message:
                            'Verifica saldo, rangos y componentes de pago antes de guardar. Los eventos aplicados ya pueden justificar asistencia y dejar trazabilidad para prenómina.',
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.canGoPrevious) ...[
                      OutlinedButton.icon(
                        style: _hrVacationActionOutlinedButtonStyle(),
                        onPressed: () => _save(_HrVacationEditAction.previous),
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Anterior'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.canGoNext) ...[
                      OutlinedButton.icon(
                        style: _hrVacationActionOutlinedButtonStyle(),
                        onPressed: () => _save(_HrVacationEditAction.next),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Siguiente'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton(
                      style: _hrVacationActionOutlinedButtonStyle(),
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
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: _save,
                      child: const Text('Guardar vacaciones'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrVacationSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _HrVacationSectionCard({
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

class _HrVacationMetricMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;

  const _HrVacationMetricMiniCard({
    required this.label,
    required this.value,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final detail = helper?.trim();
    return Tooltip(
      message: detail == null || detail.isEmpty ? label : '$label\n$detail',
      child: Container(
        width: 144,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x44B084FF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6E47A8),
                  letterSpacing: 0.35,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
      ),
    );
  }
}

class _HrVacationRuleCard extends StatelessWidget {
  final String title;
  final String value;
  final bool emphasis;

  const _HrVacationRuleCard({
    required this.title,
    required this.value,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: emphasis ? const Color(0xFFF4E9FF) : const Color(0xFFFFFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasis ? const Color(0x889F6BFF) : const Color(0x44B084FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: emphasis
                  ? const Color(0xFF4E2B7A)
                  : const Color(0xFF24103D),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrVacationPaymentCard extends StatelessWidget {
  final String title;
  final String dailyLabel;
  final String payLabel;
  final String bonusLabel;
  final String? accentLabel;

  const _HrVacationPaymentCard({
    required this.title,
    required this.dailyLabel,
    required this.payLabel,
    required this.bonusLabel,
    this.accentLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF24103D),
                  ),
                ),
              ),
              if (accentLabel != null && accentLabel!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBDDFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x44B084FF)),
                  ),
                  child: Text(
                    accentLabel!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6E47A8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dailyLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4E2B7A),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            payLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0x22B084FF), height: 1),
          const SizedBox(height: 4),
          Text(
            bonusLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E47A8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrVacationEmptyBlock extends StatelessWidget {
  final String message;

  const _HrVacationEmptyBlock({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2FF).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7D62A8),
        ),
      ),
    );
  }
}

class _HrVacationInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _HrVacationInfoLine({required this.label, required this.value});

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

class _HrVacationLabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _HrVacationLabeledField({required this.label, required this.child});

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

class _HrVacationPickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _HrVacationPickerField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: _hrVacationFieldDecoration(),
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

class _HrVacationReadOnlyField extends StatelessWidget {
  final String value;

  const _HrVacationReadOnlyField({required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _hrVacationFieldDecoration(),
      child: Text(
        value.isEmpty ? 'Sin periodo fiscal' : value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF24103D),
        ),
      ),
    );
  }
}

class _HrVacationSelectorTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _HrVacationSelectorTile({
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

class _HrVacationStatusBadge extends StatelessWidget {
  final String label;

  const _HrVacationStatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorSet = _vacationStatusBadgeColorSet(label);
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

class _HrVacationEventPill extends StatelessWidget {
  final String label;
  final _HrVacationPillColorSet colorSet;

  const _HrVacationEventPill({required this.label, required this.colorSet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorSet.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorSet.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: colorSet.foreground,
        ),
      ),
    );
  }
}

class _HrVacationEventCard extends StatelessWidget {
  final _HrVacationEventDraft draft;
  final _HrVacationBalanceDraft balance;
  final VoidCallback onChanged;
  final Future<DateTime?> Function(DateTime? initial) onPickDate;
  final VoidCallback onRemove;

  const _HrVacationEventCard({
    required this.draft,
    required this.balance,
    required this.onChanged,
    required this.onPickDate,
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
                    const Text(
                      'RANGO CAPTURADO',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6E47A8),
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatVacationDate(draft.startDate)} → ${_formatVacationDate(draft.endDate)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF24103D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatVacationDays(draft.daysApplied)} · ${draft.eventType.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6E47A8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5ECFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x44B084FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ESTADO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6E47A8),
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.status.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF24103D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x22B084FF)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (draft.isContpaqImported)
                  const _HrVacationEventPill(
                    label: 'Detectado desde CONTPAQ',
                    colorSet: _HrVacationPillColorSet(
                      background: Color(0xFFEADFFF),
                      border: Color(0xFFB084FF),
                      foreground: Color(0xFF4E2B7A),
                    ),
                  ),
                _HrVacationEventPill(
                  label: draft.eventType.label,
                  colorSet: _eventTypeColorSet(draft.eventType),
                ),
                _HrVacationEventPill(
                  label: draft.status.label,
                  colorSet: _eventStatusColorSet(draft.status),
                ),
                _HrVacationEventPill(
                  label: 'Asistencia ${draft.attendanceSyncStatus.label}',
                  colorSet: _syncStatusColorSet(draft.attendanceSyncStatus),
                ),
                _HrVacationEventPill(
                  label: 'Prenómina ${draft.prenominaSyncStatus.label}',
                  colorSet: _syncStatusColorSet(draft.prenominaSyncStatus),
                ),
                if (draft.attendancePeriodLabel.trim().isNotEmpty)
                  _HrVacationEventPill(
                    label: draft.attendancePeriodLabel,
                    colorSet: const _HrVacationPillColorSet(
                      background: Color(0xFFF2E8FF),
                      border: Color(0x55B084FF),
                      foreground: Color(0xFF6E47A8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (draft.isContpaqImported) ...[
            const _HrVacationInlineNote(
              icon: Icons.receipt_long_rounded,
              message:
                  'Este evento fue sembrado desde CONTPAQ por vacaciones pagadas del periodo. RH puede revisarlo y complementarlo sin perder la huella fiscal.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 340,
              child: _HrVacationLabeledField(
                label: 'Periodo fiscal origen',
                child: _HrVacationReadOnlyField(
                  value: draft.contpaqFiscalPeriodLabel,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_vacationEventNeedsOperationalNote(draft)) ...[
            _HrVacationInlineNote(
              icon: Icons.info_outline_rounded,
              message: _vacationEventOperationalNote(draft),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: _HrVacationLabeledField(
                  label: 'Tipo',
                  child: _HrVacationPickerField(
                    value: draft.eventType.label,
                    onTap: () async {
                      final value =
                          await showSearchablePickerDialog<
                            _HrVacationEventType
                          >(
                            context,
                            title: 'Tipo',
                            initialValue: draft.eventType,
                            options: _HrVacationEventType.values
                                .map(
                                  (item) => SearchablePickerOption(
                                    value: item,
                                    label: item.label,
                                  ),
                                )
                                .toList(growable: false),
                          );
                      if (value == null) return;
                      draft.eventType = value;
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: _HrVacationLabeledField(
                  label: 'Fecha inicio',
                  child: _HrVacationDateField(
                    value: _formatVacationDate(draft.startDate),
                    onTap: () async {
                      final value = await onPickDate(draft.startDate);
                      if (value == null) return;
                      draft.startDate = value;
                      if (draft.endDate.isBefore(value)) {
                        draft.endDate = value;
                      }
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: _HrVacationLabeledField(
                  label: 'Fecha fin',
                  child: _HrVacationDateField(
                    value: _formatVacationDate(draft.endDate),
                    onTap: () async {
                      final value = await onPickDate(draft.endDate);
                      if (value == null) return;
                      draft.endDate = value.isBefore(draft.startDate)
                          ? draft.startDate
                          : value;
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: _HrVacationLabeledField(
                  label: 'Días',
                  child: TextFormField(
                    initialValue: _formatVacationDays(draft.daysApplied),
                    decoration: _hrVacationFieldDecoration(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      draft.daysManuallyEdited = trimmed.isNotEmpty;
                      draft.daysApplied = trimmed.isEmpty
                          ? 0.0
                          : _parseVacationNumber(
                              trimmed,
                            ).clamp(0, 9999).toDouble();
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: _HrVacationLabeledField(
                  label: 'Domingos / festivos pagados',
                  child: TextFormField(
                    initialValue: _formatVacationDays(draft.additionalPaidDays),
                    decoration: _hrVacationFieldDecoration(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      draft.additionalPaidDaysManuallyEdited =
                          trimmed.isNotEmpty;
                      draft.additionalPaidDays = trimmed.isEmpty
                          ? 0.0
                          : _parseVacationNumber(
                              trimmed,
                            ).clamp(0, 9999).toDouble();
                      onChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: _HrVacationLabeledField(
                  label: 'Estado',
                  child: _HrVacationPickerField(
                    value: draft.status.label,
                    onTap: () async {
                      final value =
                          await showSearchablePickerDialog<
                            _HrVacationEventStatus
                          >(
                            context,
                            title: 'Estado',
                            initialValue: draft.status,
                            options: _HrVacationEventStatus.values
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
                      onChanged();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _HrVacationBooleanField(
                label: 'Impacta asistencia',
                value: draft.impactAttendance,
                onChanged: (value) {
                  draft.impactAttendance = value;
                  onChanged();
                },
              ),
              _HrVacationBooleanField(
                label: 'Impacta prenómina',
                value: draft.impactPrenomina,
                onChanged: (value) {
                  draft.impactPrenomina = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _HrVacationInlineNote(
            icon: Icons.lock_clock_outlined,
            message:
                'El evento queda pendiente de cierre. La emisión del recibo se controla desde Nómina después de publicar la prenómina del periodo.',
          ),
          if (draft.impactPrenomina) ...[
            const SizedBox(height: 12),
            _HrVacationIsrEditor(
              draft: draft,
              balance: balance,
              onChanged: onChanged,
            ),
          ],
          const SizedBox(height: 12),
          _HrVacationLabeledField(
            label: 'Observación RH',
            child: TextFormField(
              initialValue: draft.notes,
              decoration: _hrVacationFieldDecoration(),
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

class _HrVacationIsrEditor extends StatelessWidget {
  final _HrVacationEventDraft draft;
  final _HrVacationBalanceDraft balance;
  final VoidCallback onChanged;

  const _HrVacationIsrEditor({
    required this.draft,
    required this.balance,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final daily = balance.salarySnapshot / 7;
    final fiscalVacation =
        daily * (draft.daysApplied + draft.additionalPaidDays) +
        (daily * draft.daysApplied * 0.25);
    final isr = _calculateVacationIsr(
      balance: balance,
      event: draft,
      fiscalVacationAmount: fiscalVacation,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x445C2D91)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RETENCIÓN ISR DEL RECIBO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              color: Color(0xFF5C2D91),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Salario base + vacaciones gravadas + prima gravada - subsidio al empleo. RH puede sustituir el importe por el CFDI.',
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 210,
                child: _HrVacationLabeledField(
                  label: 'ISR retenido (override CFDI)',
                  child: TextFormField(
                    initialValue: draft.isrRetentionOverrideText,
                    decoration: _hrVacationFieldDecoration().copyWith(
                      hintText: _formatVacationMoney(isr.retentionAmount),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      draft.isrRetentionOverrideText = value;
                      onChanged();
                    },
                  ),
                ),
              ),
              _HrVacationEventPill(
                label: 'Base gravable ${_formatVacationMoney(isr.taxableBase)}',
                colorSet: const _HrVacationPillColorSet(
                  background: Color(0xFFEADFFF),
                  border: Color(0xFFB084FF),
                  foreground: Color(0xFF4E2B7A),
                ),
              ),
              _HrVacationEventPill(
                label: 'Exento ${_formatVacationMoney(isr.exemptAmount)}',
                colorSet: const _HrVacationPillColorSet(
                  background: Color(0xFFEADFFF),
                  border: Color(0xFFB084FF),
                  foreground: Color(0xFF4E2B7A),
                ),
              ),
              _HrVacationEventPill(
                label: 'Subsidio ${_formatVacationMoney(isr.subsidyAmount)}',
                colorSet: const _HrVacationPillColorSet(
                  background: Color(0xFFEADFFF),
                  border: Color(0xFFB084FF),
                  foreground: Color(0xFF4E2B7A),
                ),
              ),
              _HrVacationEventPill(
                label: 'ISR ${_formatVacationMoney(isr.retentionAmount)}',
                colorSet: const _HrVacationPillColorSet(
                  background: Color(0xFFFDEBEE),
                  border: Color(0xFFE5A1AF),
                  foreground: Color(0xFF9A2947),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HrVacationDateField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _HrVacationDateField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: _hrVacationFieldDecoration(),
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
              Icons.calendar_month_outlined,
              size: 18,
              color: Color(0xFF6E47A8),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrVacationBooleanField extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HrVacationBooleanField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch.adaptive(
          value: value,
          activeTrackColor: const Color(0xFF8B5CF6),
          activeThumbColor: Colors.white,
          onChanged: onChanged,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF24103D),
          ),
        ),
      ],
    );
  }
}

class _HrVacationInlineNote extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HrVacationInlineNote({required this.icon, required this.message});

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

class _HrVacationColumnFilterDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const _HrVacationColumnFilterDialog({
    required this.title,
    required this.initialValue,
  });

  @override
  State<_HrVacationColumnFilterDialog> createState() =>
      _HrVacationColumnFilterDialogState();
}

class _HrVacationColumnFilterDialogState
    extends State<_HrVacationColumnFilterDialog> {
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
                decoration: _hrVacationFilterDialogDecoration(),
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
                      'Escribe un valor para filtrar esta columna dentro del grid de vacaciones.',
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
                      decoration: _hrVacationFieldDecoration().copyWith(
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
                          style: _hrVacationFilterOutlinedButtonStyle(),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: _hrVacationFilterOutlinedButtonStyle(),
                          onPressed: () => Navigator.of(context).pop(''),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: _hrVacationFilterFilledButtonStyle(),
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

BoxDecoration _hrVacationFilterDialogDecoration() {
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

ButtonStyle _hrVacationFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFF1E7FF),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    backgroundColor: const Color(0xFF34204E).withValues(alpha: 0.72),
  );
}

ButtonStyle _hrVacationFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: humanResourcesAreaTokens.primary,
    foregroundColor: Colors.white,
  );
}

ButtonStyle _hrVacationActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF24103D),
    side: BorderSide(color: const Color(0xFFB68CFF).withValues(alpha: 0.42)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

InputDecoration _hrVacationFieldDecoration() {
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

enum _HrVacationBaseDatePolicy {
  fechaIngreso('Fecha de ingreso', 'Usa la fecha de ingreso como base legal.'),
  fechaAlta('Fecha de alta', 'Usa la fecha de alta como base administrativa.'),
  manualRh('Manual RH', 'Permite criterio manual con justificación RH.');

  final String label;
  final String description;
  const _HrVacationBaseDatePolicy(this.label, this.description);
}

enum _HrVacationBalanceStatus {
  pendiente('Pendiente'),
  calculado('Calculado'),
  aplicado('Aplicado'),
  conAjusteRh('Con ajuste RH'),
  listoPrenomina('Listo para prenómina');

  final String label;
  const _HrVacationBalanceStatus(this.label);
}

enum _HrVacationEventType {
  vacacionesDisfrutadas('Vacaciones disfrutadas'),
  vacacionesPagadas('Vacaciones pagadas'),
  vacacionesPendientes('Vacaciones pendientes'),
  ajusteRh('Ajuste RH');

  final String label;
  const _HrVacationEventType(this.label);
}

enum _HrVacationEventStatus {
  pendiente('Pendiente'),
  aprobado('Aprobado'),
  aplicado('Aplicado'),
  cancelado('Cancelado');

  final String label;
  const _HrVacationEventStatus(this.label);
}

enum _HrVacationSyncStatus {
  pendiente('Pendiente'),
  aplicado('Aplicado'),
  omitido('Omitido');

  final String label;
  const _HrVacationSyncStatus(this.label);
}

enum _HrVacationIsrMethod {
  articulo174(
    'Regla DICSA 2026',
    'Tarifa semanal sobre la base gravable total.',
  ),
  tarifaSemanal(
    'Regla DICSA 2026',
    'Tarifa semanal sobre la base gravable total.',
  ),
  manualRh('Manual RH', 'RH captura la retención confirmada por CFDI.');

  final String label;
  final String description;
  const _HrVacationIsrMethod(this.label, this.description);
}

class _HrVacationWorkSchedule {
  final String horario;
  final List<String> diasLabora;

  const _HrVacationWorkSchedule({
    required this.horario,
    required this.diasLabora,
  });
}

enum _HrVacationAttendanceImportSource { ngteco, contpaq }

class _HrVacationAttendanceImportedEntry {
  final String employeeId;
  final String sourceName;
  final String detail;
  final String salary;
  final String net;
  final String overtime;
  final String vacations;
  final String absenceDeduction;

  const _HrVacationAttendanceImportedEntry({
    required this.employeeId,
    required this.sourceName,
    required this.detail,
    this.salary = '',
    this.net = '',
    this.overtime = '',
    this.vacations = '',
    this.absenceDeduction = '',
  });

  factory _HrVacationAttendanceImportedEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    return _HrVacationAttendanceImportedEntry(
      employeeId: (json['employee_id'] ?? '').toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      salary: (json['salary'] ?? '').toString(),
      net: (json['net'] ?? '').toString(),
      overtime: (json['overtime'] ?? '').toString(),
      vacations: (json['vacations'] ?? '').toString(),
      absenceDeduction: (json['absence_deduction'] ?? '').toString(),
    );
  }
}

class _HrVacationAttendanceLotLite {
  final String id;
  final _HrVacationAttendanceImportSource source;
  final String fileName;
  final DateTime importedAt;
  final String periodLabel;
  final List<_HrVacationAttendanceImportedEntry> entries;

  const _HrVacationAttendanceLotLite({
    required this.id,
    required this.source,
    required this.fileName,
    required this.importedAt,
    required this.periodLabel,
    required this.entries,
  });

  factory _HrVacationAttendanceLotLite.fromRow(Map<String, dynamic> row) {
    final source = _HrVacationAttendanceImportSource.values.firstWhere(
      (item) => item.name == (row['source'] ?? '').toString(),
      orElse: () => _HrVacationAttendanceImportSource.ngteco,
    );
    return _HrVacationAttendanceLotLite(
      id: (row['id'] ?? '').toString(),
      source: source,
      fileName: (row['file_name'] ?? '').toString(),
      importedAt:
          DateTime.tryParse((row['imported_at'] ?? '').toString()) ??
          DateTime.now(),
      periodLabel: (row['period_label'] ?? '').toString(),
      entries: ((row['entries'] as List?) ?? const <dynamic>[])
          .map(
            (item) => _HrVacationAttendanceImportedEntry.fromJson(_asMap(item)),
          )
          .toList(growable: false),
    );
  }
}

class _HrVacationEmployeeMaster {
  final String employeeId;
  final String displayName;
  final String empresa;
  final List<_HrVacationWorkSchedule> workSchedules;
  final DateTime? fechaIngreso;
  final DateTime? fechaAlta;
  final String salario;
  final String salarioPercibido;

  const _HrVacationEmployeeMaster({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.workSchedules,
    required this.fechaIngreso,
    required this.fechaAlta,
    required this.salario,
    required this.salarioPercibido,
  });

  factory _HrVacationEmployeeMaster.fromRow(Map<String, dynamic> row) {
    return _HrVacationEmployeeMaster(
      employeeId: (row['id'] ?? '').toString(),
      displayName: (row['nombre'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      workSchedules: _parseVacationWorkSchedules(
        row['labor_schedules'],
        fallbackHorario: (row['horario'] ?? '').toString(),
        fallbackDiasLabora: _parseVacationWeekdays(row['dias_labora']),
      ),
      fechaIngreso: _parseVacationDbDate(row['fecha_ingreso']),
      fechaAlta: _parseVacationDbDate(row['fecha_alta']),
      salario: _vacationDbNumericToText(row['salario']),
      salarioPercibido: _vacationDbNumericToText(row['salario_real_percibido']),
    );
  }
}

class _HrVacationRule {
  final String ruleKey;
  final int sortOrder;
  final int minYears;
  final int? maxYears;
  final int daysEntitled;

  const _HrVacationRule({
    required this.ruleKey,
    required this.sortOrder,
    required this.minYears,
    required this.maxYears,
    required this.daysEntitled,
  });

  String get rangeLabel {
    if (maxYears == null || maxYears == minYears) return '$minYears año(s)';
    return '$minYears-$maxYears años';
  }

  factory _HrVacationRule.fromRow(Map<String, dynamic> row) {
    return _HrVacationRule(
      ruleKey: (row['rule_key'] ?? '').toString(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      minYears: (row['min_years'] as num?)?.toInt() ?? 0,
      maxYears: (row['max_years'] as num?)?.toInt(),
      daysEntitled: (row['days_entitled'] as num?)?.toInt() ?? 0,
    );
  }
}

class _HrVacationBalanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String empresa;
  final int exerciseYear;
  final _HrVacationBaseDatePolicy baseDatePolicy;
  final DateTime? baseFechaIngreso;
  final DateTime? baseFechaAlta;
  final DateTime? baseManualDate;
  final int antiguedadYears;
  final String entitlementRuleKey;
  final double daysEntitled;
  final double daysPaid;
  final double daysEnjoyed;
  final double daysReserved;
  final double daysTaken;
  final double daysAvailable;
  final double salarySnapshot;
  final double salaryPerceivedSnapshot;
  final _HrVacationBalanceStatus status;
  final bool manualOverride;
  final String manualOverrideReason;
  final String notes;

  const _HrVacationBalanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.exerciseYear,
    required this.baseDatePolicy,
    required this.baseFechaIngreso,
    required this.baseFechaAlta,
    required this.baseManualDate,
    required this.antiguedadYears,
    required this.entitlementRuleKey,
    required this.daysEntitled,
    required this.daysPaid,
    required this.daysEnjoyed,
    required this.daysReserved,
    required this.daysTaken,
    required this.daysAvailable,
    required this.salarySnapshot,
    required this.salaryPerceivedSnapshot,
    required this.status,
    required this.manualOverride,
    required this.manualOverrideReason,
    required this.notes,
  });

  factory _HrVacationBalanceRecord.fromRow(Map<String, dynamic> row) {
    return _HrVacationBalanceRecord(
      id: (row['id'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      exerciseYear: (row['exercise_year'] as num?)?.toInt() ?? 0,
      baseDatePolicy: _baseDatePolicyFromText(
        (row['base_date_policy'] ?? '').toString(),
      ),
      baseFechaIngreso: _parseVacationDbDate(row['base_fecha_ingreso']),
      baseFechaAlta: _parseVacationDbDate(row['base_fecha_alta']),
      baseManualDate: _parseVacationDbDate(row['base_manual_date']),
      antiguedadYears: (row['antiguedad_years'] as num?)?.toInt() ?? 0,
      entitlementRuleKey: (row['entitlement_rule_key'] ?? '').toString(),
      daysEntitled: _parseVacationNumber(row['days_entitled']),
      daysPaid: _parseVacationNumber(row['days_paid']),
      daysEnjoyed: _parseVacationNumber(row['days_enjoyed']),
      daysReserved: _parseVacationNumber(row['days_reserved']),
      daysTaken: _parseVacationNumber(row['days_taken']),
      daysAvailable: _parseVacationNumber(row['days_available']),
      salarySnapshot: _parseVacationNumber(row['salary_snapshot']),
      salaryPerceivedSnapshot: _parseVacationNumber(
        row['salary_perceived_snapshot'],
      ),
      status: _balanceStatusFromText((row['status'] ?? '').toString()),
      manualOverride: row['manual_override'] == true,
      manualOverrideReason: (row['manual_override_reason'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
    );
  }
}

class _HrVacationEventRecord {
  final String id;
  final String balanceId;
  final String employeeId;
  final String employeeName;
  final int exerciseYear;
  final _HrVacationEventType eventType;
  final DateTime startDate;
  final DateTime endDate;
  final double daysApplied;
  final double additionalPaidDays;
  final String attendancePeriodLabel;
  final _HrVacationSyncStatus attendanceSyncStatus;
  final _HrVacationSyncStatus prenominaSyncStatus;
  final bool impactAttendance;
  final bool impactPrenomina;
  final bool generateReceipt;
  final _HrVacationIsrMethod isrMethod;
  final double? isrOrdinaryMonthlyIncomeOverride;
  final double? isrRetentionOverride;
  final String receiptGroupKey;
  final _HrVacationEventStatus status;
  final String notes;

  const _HrVacationEventRecord({
    required this.id,
    required this.balanceId,
    required this.employeeId,
    required this.employeeName,
    required this.exerciseYear,
    required this.eventType,
    required this.startDate,
    required this.endDate,
    required this.daysApplied,
    required this.additionalPaidDays,
    required this.attendancePeriodLabel,
    required this.attendanceSyncStatus,
    required this.prenominaSyncStatus,
    required this.impactAttendance,
    required this.impactPrenomina,
    required this.generateReceipt,
    required this.isrMethod,
    required this.isrOrdinaryMonthlyIncomeOverride,
    required this.isrRetentionOverride,
    required this.receiptGroupKey,
    required this.status,
    required this.notes,
  });

  factory _HrVacationEventRecord.fromRow(Map<String, dynamic> row) {
    return _HrVacationEventRecord(
      id: (row['id'] ?? '').toString(),
      balanceId: (row['balance_id'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      exerciseYear: (row['exercise_year'] as num?)?.toInt() ?? 0,
      eventType: _eventTypeFromText((row['event_type'] ?? '').toString()),
      startDate: _parseVacationDbDate(row['start_date']) ?? DateTime.now(),
      endDate: _parseVacationDbDate(row['end_date']) ?? DateTime.now(),
      daysApplied: _parseVacationNumber(row['days_applied']),
      additionalPaidDays: _parseVacationNumber(row['additional_paid_days']),
      attendancePeriodLabel: (row['attendance_period_label'] ?? '').toString(),
      attendanceSyncStatus: _syncStatusFromText(
        (row['attendance_sync_status'] ?? '').toString(),
      ),
      prenominaSyncStatus: _syncStatusFromText(
        (row['prenomina_sync_status'] ?? '').toString(),
      ),
      impactAttendance: row['impact_attendance'] != false,
      impactPrenomina: row['impact_prenomina'] == true,
      generateReceipt: row['generate_receipt'] == true,
      isrMethod: _vacationIsrMethodFromText(
        (row['isr_method'] ?? '').toString(),
      ),
      isrOrdinaryMonthlyIncomeOverride: _parseVacationNullableNumber(
        row['isr_ordinary_monthly_income_override'],
      ),
      isrRetentionOverride: _parseVacationNullableNumber(
        row['isr_retention_override'],
      ),
      receiptGroupKey: (row['receipt_group_key'] ?? '').toString(),
      status: _eventStatusFromText((row['status'] ?? '').toString()),
      notes: (row['notes'] ?? '').toString(),
    );
  }
}

class _HrVacationCalculationRecord {
  final String id;
  final String vacationEventId;
  final String employeeId;
  final int exerciseYear;
  final int sequenceNo;
  final String componentLabel;
  final String calculationMode;
  final _HrVacationBaseDatePolicy baseDatePolicy;
  final double daysPaid;
  final double dailySalaryUsed;
  final double dailySalaryPerceivedUsed;
  final double vacationPay;
  final double vacationBonusRate;
  final double vacationBonusPay;
  final double transferComponent;
  final double cashComponent;
  final double differenceComponent;
  final double isrTaxableBase;
  final double isrExemptAmount;
  final double isrRetentionAmount;
  final _HrVacationIsrMethod isrMethod;
  final int? isrTariffYear;
  final bool isFinal;

  const _HrVacationCalculationRecord({
    required this.id,
    required this.vacationEventId,
    required this.employeeId,
    required this.exerciseYear,
    required this.sequenceNo,
    required this.componentLabel,
    required this.calculationMode,
    required this.baseDatePolicy,
    required this.daysPaid,
    required this.dailySalaryUsed,
    required this.dailySalaryPerceivedUsed,
    required this.vacationPay,
    required this.vacationBonusRate,
    required this.vacationBonusPay,
    required this.transferComponent,
    required this.cashComponent,
    required this.differenceComponent,
    required this.isrTaxableBase,
    required this.isrExemptAmount,
    required this.isrRetentionAmount,
    required this.isrMethod,
    required this.isrTariffYear,
    required this.isFinal,
  });

  factory _HrVacationCalculationRecord.fromRow(Map<String, dynamic> row) {
    return _HrVacationCalculationRecord(
      id: (row['id'] ?? '').toString(),
      vacationEventId: (row['vacation_event_id'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      exerciseYear: (row['exercise_year'] as num?)?.toInt() ?? 0,
      sequenceNo: (row['sequence_no'] as num?)?.toInt() ?? 1,
      componentLabel: (row['component_label'] ?? '').toString(),
      calculationMode: (row['calculation_mode'] ?? '').toString(),
      baseDatePolicy: _baseDatePolicyFromText(
        (row['base_date_policy'] ?? '').toString(),
      ),
      daysPaid: _parseVacationNumber(row['days_paid']),
      dailySalaryUsed: _parseVacationNumber(row['daily_salary_used']),
      dailySalaryPerceivedUsed: _parseVacationNumber(
        row['daily_salary_perceived_used'],
      ),
      vacationPay: _parseVacationNumber(row['vacation_pay']),
      vacationBonusRate: _parseVacationNumber(row['vacation_bonus_rate']),
      vacationBonusPay: _parseVacationNumber(row['vacation_bonus_pay']),
      transferComponent: _parseVacationNumber(row['transfer_component']),
      cashComponent: _parseVacationNumber(row['cash_component']),
      differenceComponent: _parseVacationNumber(row['difference_component']),
      isrTaxableBase: _parseVacationNumber(row['isr_taxable_base']),
      isrExemptAmount: _parseVacationNumber(row['isr_exempt_amount']),
      isrRetentionAmount: _parseVacationNumber(row['isr_retention_amount']),
      isrMethod: _vacationIsrMethodFromText(
        (row['isr_method'] ?? '').toString(),
      ),
      isrTariffYear: (row['isr_tariff_year'] as num?)?.toInt(),
      isFinal: row['is_final'] == true,
    );
  }
}

class _HrVacationSummaryRow {
  final String employeeId;
  final String displayName;
  final String empresa;
  final int exerciseYear;
  final String balanceId;
  final DateTime? fechaIngreso;
  final DateTime? fechaAlta;
  final String salario;
  final String salarioPercibido;
  final _HrVacationBaseDatePolicy baseDatePolicy;
  final int antiguedadYears;
  final double daysEntitled;
  final double daysPaid;
  final double daysEnjoyed;
  final double daysReserved;
  final double daysApplied;
  final double daysAvailable;
  final _HrVacationBalanceStatus status;
  final bool manualOverride;
  final String manualOverrideReason;
  final List<_HrVacationEventRecord> events;

  const _HrVacationSummaryRow({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.exerciseYear,
    required this.balanceId,
    required this.fechaIngreso,
    required this.fechaAlta,
    required this.salario,
    required this.salarioPercibido,
    required this.baseDatePolicy,
    required this.antiguedadYears,
    required this.daysEntitled,
    required this.daysPaid,
    required this.daysEnjoyed,
    required this.daysReserved,
    required this.daysApplied,
    required this.daysAvailable,
    required this.status,
    required this.manualOverride,
    required this.manualOverrideReason,
    required this.events,
  });

  String get fechaIngresoLabel => _formatVacationDate(fechaIngreso);
  String get fechaAltaLabel => _formatVacationDate(fechaAlta);
  String get statusLabel => _resolveVacationSummaryStatus(this);
}

class _HrVacationBalanceDraft {
  String id;
  _HrVacationBaseDatePolicy baseDatePolicy;
  DateTime? baseFechaIngreso;
  DateTime? baseFechaAlta;
  DateTime? baseManualDate;
  int antiguedadYears;
  String entitlementRuleKey;
  double daysEntitled;
  double daysPaid;
  double daysEnjoyed;
  double daysReserved;
  double daysTaken;
  double daysAvailable;
  double salarySnapshot;
  double salaryPerceivedSnapshot;
  _HrVacationBalanceStatus status;
  bool manualOverride;
  String manualOverrideReason;
  String notes;

  _HrVacationBalanceDraft({
    required this.id,
    required this.baseDatePolicy,
    required this.baseFechaIngreso,
    required this.baseFechaAlta,
    required this.baseManualDate,
    required this.antiguedadYears,
    required this.entitlementRuleKey,
    required this.daysEntitled,
    required this.daysPaid,
    required this.daysEnjoyed,
    required this.daysReserved,
    required this.daysTaken,
    required this.daysAvailable,
    required this.salarySnapshot,
    required this.salaryPerceivedSnapshot,
    required this.status,
    required this.manualOverride,
    required this.manualOverrideReason,
    required this.notes,
  });

  factory _HrVacationBalanceDraft.fromSummaryRow(_HrVacationSummaryRow row) {
    return _HrVacationBalanceDraft(
      id: row.balanceId,
      baseDatePolicy: row.baseDatePolicy,
      baseFechaIngreso: row.fechaIngreso,
      baseFechaAlta: row.fechaAlta,
      baseManualDate: null,
      antiguedadYears: row.antiguedadYears,
      entitlementRuleKey: '',
      daysEntitled: row.daysEntitled,
      daysPaid: row.daysPaid,
      daysEnjoyed: row.daysEnjoyed,
      daysReserved: row.daysReserved,
      daysTaken: row.daysApplied,
      daysAvailable: row.daysAvailable,
      salarySnapshot: _parseVacationMoney(row.salario),
      salaryPerceivedSnapshot: _parseVacationMoney(row.salarioPercibido),
      status: row.status,
      manualOverride: row.manualOverride,
      manualOverrideReason: row.manualOverrideReason,
      notes: '',
    );
  }

  Map<String, dynamic> toRow({
    required String employeeId,
    required String employeeName,
    required String empresa,
    required int exerciseYear,
    String? existingId,
  }) {
    return {
      if ((existingId ?? '').trim().isNotEmpty) 'id': existingId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'empresa': empresa,
      'exercise_year': exerciseYear,
      'base_date_policy': _baseDatePolicyToText(baseDatePolicy),
      'base_fecha_ingreso': _vacationDbDate(baseFechaIngreso),
      'base_fecha_alta': _vacationDbDate(baseFechaAlta),
      'base_manual_date': _vacationDbDate(baseManualDate),
      'antiguedad_years': antiguedadYears,
      'entitlement_rule_key': entitlementRuleKey.isEmpty
          ? null
          : entitlementRuleKey,
      // El derecho legal se persiste como entero; los demás saldos admiten decimales.
      'days_entitled': daysEntitled.round(),
      'days_paid': daysPaid,
      'days_enjoyed': daysEnjoyed,
      'days_reserved': daysReserved,
      'days_taken': daysTaken,
      'days_available': daysAvailable,
      'salary_snapshot': salarySnapshot,
      'salary_perceived_snapshot': salaryPerceivedSnapshot,
      'status': _balanceStatusToText(status),
      'manual_override': manualOverride,
      'manual_override_reason': manualOverrideReason,
      'notes': notes,
    };
  }
}

class _HrVacationEventDraft {
  String localId;
  _HrVacationEventType eventType;
  _HrVacationEventStatus status;
  DateTime startDate;
  DateTime endDate;
  double daysApplied;
  double additionalPaidDays;
  bool daysManuallyEdited;
  bool additionalPaidDaysManuallyEdited = false;
  String attendancePeriodLabel;
  _HrVacationSyncStatus attendanceSyncStatus;
  _HrVacationSyncStatus prenominaSyncStatus;
  bool impactAttendance;
  bool impactPrenomina;
  bool generateReceipt;
  _HrVacationIsrMethod isrMethod;
  String isrOrdinaryMonthlyIncomeOverrideText;
  String isrRetentionOverrideText;
  String receiptGroupKey;
  String notes;

  _HrVacationEventDraft({
    required this.localId,
    required this.eventType,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.daysApplied,
    required this.additionalPaidDays,
    this.daysManuallyEdited = false,
    required this.attendancePeriodLabel,
    required this.attendanceSyncStatus,
    required this.prenominaSyncStatus,
    required this.impactAttendance,
    required this.impactPrenomina,
    required this.generateReceipt,
    required this.isrMethod,
    required this.isrOrdinaryMonthlyIncomeOverrideText,
    required this.isrRetentionOverrideText,
    required this.receiptGroupKey,
    required this.notes,
  });

  factory _HrVacationEventDraft.fromRecord(_HrVacationEventRecord record) {
    return _HrVacationEventDraft(
      localId: record.id,
      eventType: record.eventType,
      status: record.status,
      startDate: record.startDate,
      endDate: record.endDate,
      daysApplied: record.daysApplied,
      additionalPaidDays: record.additionalPaidDays,
      daysManuallyEdited: false,
      attendancePeriodLabel: record.attendancePeriodLabel,
      attendanceSyncStatus: record.attendanceSyncStatus,
      prenominaSyncStatus: record.prenominaSyncStatus,
      impactAttendance: record.impactAttendance,
      impactPrenomina: record.impactPrenomina,
      generateReceipt: record.generateReceipt,
      isrMethod: record.isrMethod,
      isrOrdinaryMonthlyIncomeOverrideText: _formatVacationNullableMoney(
        record.isrOrdinaryMonthlyIncomeOverride,
      ),
      isrRetentionOverrideText: _formatVacationNullableMoney(
        record.isrRetentionOverride,
      ),
      receiptGroupKey: record.receiptGroupKey,
      notes: record.notes,
    );
  }

  Map<String, dynamic> toRow({
    required String? balanceId,
    required String employeeId,
    required String employeeName,
    required int exerciseYear,
  }) {
    return {
      if (hasPersistedId) 'id': localId,
      'balance_id': balanceId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'exercise_year': exerciseYear,
      'event_type': _eventTypeToText(eventType),
      'start_date': _vacationDbDate(startDate),
      'end_date': _vacationDbDate(endDate),
      'days_applied': daysApplied,
      'additional_paid_days': additionalPaidDays,
      'attendance_period_label': attendancePeriodLabel,
      'payroll_period_label': attendancePeriodLabel,
      'attendance_sync_status': _syncStatusToText(attendanceSyncStatus),
      'prenomina_sync_status': _syncStatusToText(prenominaSyncStatus),
      'impact_attendance': impactAttendance,
      'impact_prenomina': impactPrenomina,
      'generate_receipt': generateReceipt,
      'isr_method': _vacationIsrMethodToText(isrMethod),
      'isr_ordinary_monthly_income_override': _parseVacationNullableNumber(
        isrOrdinaryMonthlyIncomeOverrideText,
      ),
      'isr_retention_override': _parseVacationNullableNumber(
        isrRetentionOverrideText,
      ),
      'receipt_group_key': receiptGroupKey,
      'status': _eventStatusToText(status),
      'notes': notes,
    };
  }

  bool get hasPersistedId =>
      localId.isNotEmpty && !localId.startsWith('event_');

  bool get isContpaqImported =>
      receiptGroupKey.startsWith(_kHrVacationContpaqReceiptPrefix);

  String get contpaqFiscalPeriodLabel {
    if (!isContpaqImported) return '';
    final raw = receiptGroupKey.substring(
      _kHrVacationContpaqReceiptPrefix.length,
    );
    final separatorIndex = raw.lastIndexOf('|');
    if (separatorIndex <= 0) return raw;
    return raw.substring(0, separatorIndex).trim();
  }
}

class _VacationGridColumn {
  final String id;
  final String label;

  const _VacationGridColumn(this.id, this.label);
}

const List<_VacationGridColumn> _kVacationGridColumns = <_VacationGridColumn>[
  _VacationGridColumn('id', 'ID'),
  _VacationGridColumn('nombre', 'Nombre'),
  _VacationGridColumn('fecha_ingreso', 'Fecha ingreso'),
  _VacationGridColumn('fecha_alta', 'Fecha alta'),
  _VacationGridColumn('dias_corresponden', 'Días corresponden'),
  _VacationGridColumn('dias_aplicados', 'Días aplicados'),
  _VacationGridColumn('dias_disponibles', 'Días disponibles'),
  _VacationGridColumn('estatus', 'Estado'),
];

String _vacationCellValueForColumn(_HrVacationSummaryRow row, String columnId) {
  switch (columnId) {
    case 'id':
      return row.employeeId;
    case 'nombre':
      return row.displayName;
    case 'fecha_ingreso':
      return row.fechaIngresoLabel;
    case 'fecha_alta':
      return row.fechaAltaLabel;
    case 'dias_corresponden':
      return _formatVacationDays(row.daysEntitled);
    case 'dias_aplicados':
      return _formatVacationDays(row.daysApplied);
    case 'dias_disponibles':
      return _formatVacationDays(row.daysAvailable);
    case 'estatus':
      return row.statusLabel;
    default:
      return '';
  }
}

DateTime? _vacationDateValueForColumn(
  _HrVacationSummaryRow row,
  String columnId,
) {
  switch (columnId) {
    case 'fecha_ingreso':
      return row.fechaIngreso;
    case 'fecha_alta':
      return row.fechaAlta;
    default:
      return null;
  }
}

class _HrVacationEventTotals {
  final double daysPaid;
  final double daysEnjoyed;
  final double daysReserved;

  const _HrVacationEventTotals({
    required this.daysPaid,
    required this.daysEnjoyed,
    required this.daysReserved,
  });

  double get daysCommitted => daysEnjoyed + daysReserved;
}

_HrVacationEventTotals _summarizeVacationRecordEvents(
  Iterable<_HrVacationEventRecord> events,
) {
  var daysPaid = 0.0;
  var daysEnjoyed = 0.0;
  var daysReserved = 0.0;
  for (final event in events) {
    final next = _classifyVacationEventBuckets(
      eventType: event.eventType,
      status: event.status,
      daysApplied: event.daysApplied,
      impactAttendance: event.impactAttendance,
      impactPrenomina: event.impactPrenomina,
      generateReceipt: event.generateReceipt,
    );
    daysPaid += next.daysPaid;
    daysEnjoyed += next.daysEnjoyed;
    daysReserved += next.daysReserved;
  }
  return _HrVacationEventTotals(
    daysPaid: daysPaid,
    daysEnjoyed: daysEnjoyed,
    daysReserved: daysReserved,
  );
}

_HrVacationEventTotals _summarizeVacationDraftEvents(
  Iterable<_HrVacationEventDraft> events,
) {
  var daysPaid = 0.0;
  var daysEnjoyed = 0.0;
  var daysReserved = 0.0;
  for (final event in events) {
    final next = _classifyVacationEventBuckets(
      eventType: event.eventType,
      status: event.status,
      daysApplied: event.daysApplied,
      impactAttendance: event.impactAttendance,
      impactPrenomina: event.impactPrenomina,
      generateReceipt: event.generateReceipt,
    );
    daysPaid += next.daysPaid;
    daysEnjoyed += next.daysEnjoyed;
    daysReserved += next.daysReserved;
  }
  return _HrVacationEventTotals(
    daysPaid: daysPaid,
    daysEnjoyed: daysEnjoyed,
    daysReserved: daysReserved,
  );
}

_HrVacationEventTotals _classifyVacationEventBuckets({
  required _HrVacationEventType eventType,
  required _HrVacationEventStatus status,
  required double daysApplied,
  required bool impactAttendance,
  required bool impactPrenomina,
  required bool generateReceipt,
}) {
  if (status == _HrVacationEventStatus.cancelado || daysApplied <= 0) {
    return const _HrVacationEventTotals(
      daysPaid: 0.0,
      daysEnjoyed: 0,
      daysReserved: 0,
    );
  }

  final isApplied = status == _HrVacationEventStatus.aplicado;
  final carriesPayrollFootprint =
      eventType == _HrVacationEventType.vacacionesPagadas ||
      impactPrenomina ||
      generateReceipt;
  final canConsumeAttendance =
      eventType == _HrVacationEventType.vacacionesDisfrutadas ||
      impactAttendance;

  final daysPaid = isApplied && carriesPayrollFootprint ? daysApplied : 0.0;
  final daysEnjoyed = isApplied && canConsumeAttendance ? daysApplied : 0.0;
  final daysReserved =
      !isApplied &&
          (eventType == _HrVacationEventType.vacacionesPendientes ||
              canConsumeAttendance ||
              eventType == _HrVacationEventType.ajusteRh)
      ? daysApplied
      : 0.0;

  return _HrVacationEventTotals(
    daysPaid: daysPaid,
    daysEnjoyed: daysEnjoyed,
    daysReserved: daysReserved,
  );
}

_HrVacationSummaryRow _buildVacationSummaryRow({
  required _HrVacationEmployeeMaster employee,
  required _HrVacationBalanceRecord? balance,
  required List<_HrVacationEventRecord> events,
  required List<_HrVacationRule> rules,
  required int exerciseYear,
}) {
  final policy =
      balance?.baseDatePolicy ??
      (employee.fechaIngreso != null
          ? _HrVacationBaseDatePolicy.fechaIngreso
          : _HrVacationBaseDatePolicy.fechaAlta);
  final baseDate = switch (policy) {
    _HrVacationBaseDatePolicy.fechaIngreso => employee.fechaIngreso,
    _HrVacationBaseDatePolicy.fechaAlta => employee.fechaAlta,
    _HrVacationBaseDatePolicy.manualRh => balance?.baseManualDate,
  };
  final years = baseDate == null
      ? 0
      : _completedYearsOn(baseDate, DateTime(exerciseYear, 12, 31));
  final rule = _resolveVacationRuleByYears(rules: rules, years: years);
  final daysEntitled =
      balance?.daysEntitled ??
      (rule == null ? 0 : rule.daysEntitled.toDouble());
  final eventTotals = _summarizeVacationRecordEvents(events);
  final legacyDaysTaken = balance?.daysTaken ?? 0;
  final persistedDaysPaid = balance?.daysPaid ?? 0;
  final persistedDaysEnjoyed = balance?.daysEnjoyed ?? 0;
  final persistedDaysReserved = balance?.daysReserved ?? 0;
  final hasSeparatedPersistedTotals =
      persistedDaysPaid > 0 ||
      persistedDaysEnjoyed > 0 ||
      persistedDaysReserved > 0;
  final daysPaid =
      (events.isNotEmpty
              ? eventTotals.daysPaid
              : (hasSeparatedPersistedTotals ? persistedDaysPaid : 0))
          .toDouble();
  final daysEnjoyed =
      (events.isNotEmpty
              ? eventTotals.daysEnjoyed
              : (hasSeparatedPersistedTotals
                    ? persistedDaysEnjoyed
                    : legacyDaysTaken))
          .toDouble();
  final daysReserved =
      (events.isNotEmpty
              ? eventTotals.daysReserved
              : (hasSeparatedPersistedTotals ? persistedDaysReserved : 0))
          .toDouble();
  final daysApplied = (daysEnjoyed + daysReserved).toDouble();
  final daysAvailable = (daysEntitled - daysApplied).clamp(0, 9999).toDouble();

  return _HrVacationSummaryRow(
    employeeId: employee.employeeId,
    displayName: employee.displayName,
    empresa: balance?.empresa.isNotEmpty == true
        ? balance!.empresa
        : employee.empresa,
    exerciseYear: exerciseYear,
    balanceId: balance?.id ?? '',
    fechaIngreso: employee.fechaIngreso,
    fechaAlta: employee.fechaAlta,
    salario: employee.salario,
    salarioPercibido: employee.salarioPercibido,
    baseDatePolicy: policy,
    antiguedadYears: balance?.antiguedadYears ?? years,
    daysEntitled: daysEntitled,
    daysPaid: daysPaid,
    daysEnjoyed: daysEnjoyed,
    daysReserved: daysReserved,
    daysApplied: daysApplied,
    daysAvailable: daysAvailable,
    status: balance?.status ?? _HrVacationBalanceStatus.pendiente,
    manualOverride: balance?.manualOverride ?? false,
    manualOverrideReason: balance?.manualOverrideReason ?? '',
    events: events,
  );
}

void _recomputeBalanceFromPolicy(
  _HrVacationSummaryRow row,
  _HrVacationBalanceDraft balance,
  List<_HrVacationRule> rules,
) {
  final baseDate = switch (balance.baseDatePolicy) {
    _HrVacationBaseDatePolicy.fechaIngreso => row.fechaIngreso,
    _HrVacationBaseDatePolicy.fechaAlta => row.fechaAlta,
    _HrVacationBaseDatePolicy.manualRh => balance.baseManualDate,
  };
  final years = baseDate == null
      ? 0
      : _completedYearsOn(baseDate, DateTime(row.exerciseYear, 12, 31));
  final rule = _resolveVacationRuleByYears(rules: rules, years: years);
  balance.antiguedadYears = years;
  balance.entitlementRuleKey = rule?.ruleKey ?? '';
  balance.daysEntitled = (rule?.daysEntitled ?? 0).toDouble();
  balance.daysTaken = balance.daysEnjoyed + balance.daysReserved;
  balance.daysAvailable = (balance.daysEntitled - balance.daysTaken)
      .clamp(0, 9999)
      .toDouble();
}

class _HrVacationContpaqPaidSignal {
  final String receiptGroupKey;
  final String employeeId;
  final String employeeName;
  final String fileName;
  final String periodLabel;
  final DateTime periodAnchorDate;
  final double daysPaid;
  final double vacationAmount;
  final double netAmount;
  final double salaryAmount;
  final String notes;

  const _HrVacationContpaqPaidSignal({
    required this.receiptGroupKey,
    required this.employeeId,
    required this.employeeName,
    required this.fileName,
    required this.periodLabel,
    required this.periodAnchorDate,
    required this.daysPaid,
    required this.vacationAmount,
    required this.netAmount,
    required this.salaryAmount,
    required this.notes,
  });
}

Future<bool> _syncVacationPaidEventsFromContpaq({
  required SupabaseClient client,
  required List<_HrVacationEmployeeMaster> employees,
  required List<_HrVacationBalanceRecord> balances,
  required List<_HrVacationAttendanceLotLite> attendanceLots,
  required List<_HrVacationEventRecord> events,
  required List<_HrVacationCalculationRecord> calculations,
  required int exerciseYear,
  required String activePeriodLabel,
}) async {
  final contpaqLots = attendanceLots
      .where(
        (lot) =>
            lot.source == _HrVacationAttendanceImportSource.contpaq &&
            _lotBelongsToVacationExercise(lot, exerciseYear) &&
            _vacationLotMatchesPeriod(lot, activePeriodLabel),
      )
      .toList(growable: false);
  if (contpaqLots.isEmpty) return false;

  final employeesById = {
    for (final employee in employees) employee.employeeId: employee,
  };
  final balancesByEmployeeId = {
    for (final balance in balances) balance.employeeId: balance,
  };
  final desiredSignals = <String, _HrVacationContpaqPaidSignal>{};
  for (final lot in contpaqLots) {
    for (final entry in lot.entries) {
      final signal = _buildVacationContpaqPaidSignal(
        lot: lot,
        entry: entry,
        employee: employeesById[entry.employeeId],
      );
      if (signal == null) continue;
      desiredSignals[signal.receiptGroupKey] = signal;
    }
  }

  final existingAutoEvents = {
    for (final event in events)
      if (event.receiptGroupKey.startsWith(_kHrVacationContpaqReceiptPrefix))
        event.receiptGroupKey: event,
  };
  final calculationsByEventId = <String, List<_HrVacationCalculationRecord>>{};
  for (final calculation in calculations) {
    calculationsByEventId
        .putIfAbsent(
          calculation.vacationEventId,
          () => <_HrVacationCalculationRecord>[],
        )
        .add(calculation);
  }

  var changed = false;

  for (final entry in existingAutoEvents.entries) {
    if (entry.value.prenominaSyncStatus == _HrVacationSyncStatus.aplicado) {
      continue;
    }
    if (desiredSignals.containsKey(entry.key)) continue;
    await client
        .from(_kHrVacationEventsTable)
        .delete()
        .eq('id', entry.value.id);
    changed = true;
  }

  for (final signal in desiredSignals.values) {
    final existingEvent = existingAutoEvents[signal.receiptGroupKey];
    if (existingEvent?.prenominaSyncStatus == _HrVacationSyncStatus.aplicado) {
      continue;
    }
    final balance = balancesByEmployeeId[signal.employeeId];
    final desiredEventRow = _buildVacationContpaqEventRow(
      signal: signal,
      exerciseYear: exerciseYear,
      balanceId: balance?.id,
    );

    String eventId;
    if (existingEvent == null) {
      final inserted = await client
          .from(_kHrVacationEventsTable)
          .insert(desiredEventRow)
          .select()
          .single();
      eventId = (inserted['id'] ?? '').toString();
      changed = true;
    } else {
      eventId = existingEvent.id;
      final needsEventUpdate = _vacationContpaqEventNeedsUpdate(
        existing: existingEvent,
        desired: signal,
      );
      if (needsEventUpdate) {
        await client
            .from(_kHrVacationEventsTable)
            .update(desiredEventRow)
            .eq('id', existingEvent.id);
        changed = true;
      }
    }

    final desiredCalculationRows = _buildVacationContpaqCalculationPayloads(
      eventId: eventId,
      signal: signal,
      exerciseYear: exerciseYear,
      baseDatePolicy:
          balance?.baseDatePolicy ?? _HrVacationBaseDatePolicy.fechaIngreso,
    );
    final existingRows =
        calculationsByEventId[eventId] ??
        const <_HrVacationCalculationRecord>[];
    final needsCalculationUpdate = _vacationContpaqCalculationsNeedUpdate(
      existingRows: existingRows,
      desiredRows: desiredCalculationRows,
    );
    if (needsCalculationUpdate) {
      await client
          .from(_kHrVacationCalculationsTable)
          .delete()
          .eq('vacation_event_id', eventId);
      if (desiredCalculationRows.isNotEmpty) {
        await client
            .from(_kHrVacationCalculationsTable)
            .insert(desiredCalculationRows);
      }
      changed = true;
    }
  }

  return changed;
}

List<Map<String, dynamic>> _buildVacationCalculationPayloads({
  required String eventId,
  required String employeeId,
  required int exerciseYear,
  required _HrVacationEventDraft event,
  required _HrVacationBalanceDraft balance,
}) {
  if (!_vacationEventHasPayrollFootprint(event)) {
    return const <Map<String, dynamic>>[];
  }
  final payloads = <Map<String, dynamic>>[];
  final salaryDaily = balance.salarySnapshot > 0
      ? balance.salarySnapshot / 7
      : 0.0;
  final salaryPerceivedDaily = balance.salaryPerceivedSnapshot > 0
      ? balance.salaryPerceivedSnapshot / 7
      : 0.0;
  final grossDaily = salaryPerceivedDaily > 0
      ? salaryPerceivedDaily
      : salaryDaily;
  final paidSalaryDays = event.daysApplied + event.additionalPaidDays;
  final vacationPay = grossDaily * paidSalaryDays;
  final vacationBonus = grossDaily * event.daysApplied * 0.25;
  final totalVacationAmount = vacationPay + vacationBonus;
  final fiscalShare = salaryPerceivedDaily > 0 && salaryDaily > 0
      ? (salaryDaily / salaryPerceivedDaily).clamp(0, 1).toDouble()
      : 1.0;
  final transferComponent = totalVacationAmount * fiscalShare;
  final cashComponent = totalVacationAmount - transferComponent;
  final isr = _calculateVacationIsr(
    balance: balance,
    event: event,
    fiscalVacationAmount: transferComponent,
  );
  payloads.add({
    'vacation_event_id': eventId,
    'employee_id': employeeId,
    'exercise_year': exerciseYear,
    'sequence_no': 1,
    'component_label': 'Pago vacacional',
    'calculation_mode': 'mixto',
    'base_date_policy': _baseDatePolicyToText(balance.baseDatePolicy),
    'days_paid': paidSalaryDays,
    'daily_salary_used': salaryDaily,
    'daily_salary_perceived_used': salaryPerceivedDaily,
    'vacation_pay': vacationPay,
    'vacation_bonus_rate': 0.25,
    'vacation_bonus_pay': vacationBonus,
    'transfer_component': transferComponent,
    'cash_component': cashComponent,
    'difference_component': cashComponent,
    'isr_taxable_base': isr.taxableBase,
    'isr_exempt_amount': isr.exemptAmount,
    'isr_retention_amount': isr.retentionAmount,
    'isr_method': _vacationIsrMethodToText(event.isrMethod),
    'isr_tariff_year': isr.tariffYear,
    'status': 'vigente',
    'is_final': false,
    'notes': event.notes,
  });
  return payloads;
}

class _HrVacationIsrBreakdown {
  final double taxableBase;
  final double exemptAmount;
  final double subsidyAmount;
  final double retentionAmount;
  final int? tariffYear;

  const _HrVacationIsrBreakdown({
    required this.taxableBase,
    required this.exemptAmount,
    required this.subsidyAmount,
    required this.retentionAmount,
    required this.tariffYear,
  });
}

class _HrVacationIsrBracket {
  final double lower;
  final double? upper;
  final double fixedQuota;
  final double marginalRate;

  const _HrVacationIsrBracket(
    this.lower,
    this.upper,
    this.fixedQuota,
    this.marginalRate,
  );
}

class _HrVacationSubsidyBracket {
  final double lower;
  final double? upper;
  final double subsidy;

  const _HrVacationSubsidyBracket(this.lower, this.upper, this.subsidy);
}

const List<_HrVacationIsrBracket> _kHrVacationWeeklyIsr2026 =
    <_HrVacationIsrBracket>[
      _HrVacationIsrBracket(0.01, 194.46, 0, 0.0192),
      _HrVacationIsrBracket(194.47, 1650.67, 3.71, 0.0640),
      _HrVacationIsrBracket(1650.68, 2900.87, 96.95, 0.1088),
      _HrVacationIsrBracket(2900.88, 3372.11, 232.96, 0.1600),
      _HrVacationIsrBracket(3372.12, 4037.32, 308.35, 0.1792),
      _HrVacationIsrBracket(4037.33, 8142.75, 427.56, 0.2136),
      _HrVacationIsrBracket(8142.76, 12834.08, 1304.45, 0.2352),
      _HrVacationIsrBracket(12834.09, 24502.45, 2407.86, 0.3000),
      _HrVacationIsrBracket(24502.46, 32669.91, 5908.35, 0.3200),
      _HrVacationIsrBracket(32669.92, 98009.66, 8521.94, 0.3400),
      _HrVacationIsrBracket(98009.67, null, 30737.49, 0.3500),
    ];

const List<_HrVacationSubsidyBracket> _kHrVacationWeeklySubsidy2026 =
    <_HrVacationSubsidyBracket>[
      _HrVacationSubsidyBracket(0.01, 407.33, 93.73),
      _HrVacationSubsidyBracket(407.34, 610.96, 93.66),
      _HrVacationSubsidyBracket(610.97, 799.68, 93.66),
      _HrVacationSubsidyBracket(799.69, 814.66, 90.44),
      _HrVacationSubsidyBracket(814.67, 1023.75, 88.06),
      _HrVacationSubsidyBracket(1023.76, 1086.19, 81.55),
      _HrVacationSubsidyBracket(1086.20, 1228.57, 74.83),
      _HrVacationSubsidyBracket(1228.58, 1433.32, 67.83),
      _HrVacationSubsidyBracket(1433.33, 1638.07, 58.38),
      _HrVacationSubsidyBracket(1638.08, 1699.88, 50.12),
      _HrVacationSubsidyBracket(1699.89, null, 0),
    ];

const double _kHrVacationUmaDaily2026 = 117.31;
const double _kHrVacationBonusExemptUmaDays = 15;

_HrVacationIsrBreakdown _calculateVacationIsr({
  required _HrVacationBalanceDraft balance,
  required _HrVacationEventDraft event,
  required double fiscalVacationAmount,
}) {
  final year = event.startDate.year;
  if (year != 2026 || fiscalVacationAmount <= 0) {
    return const _HrVacationIsrBreakdown(
      taxableBase: 0,
      exemptAmount: 0,
      subsidyAmount: 0,
      retentionAmount: 0,
      tariffYear: null,
    );
  }
  final fiscalWeekly = balance.salarySnapshot.clamp(0, 9999999).toDouble();
  final fiscalDaily = fiscalWeekly / 7;
  final fiscalVacationPay =
      fiscalDaily * (event.daysApplied + event.additionalPaidDays);
  final fiscalBonus = fiscalDaily * event.daysApplied * 0.25;
  final exemptAmount = fiscalBonus
      .clamp(0, _kHrVacationUmaDaily2026 * _kHrVacationBonusExemptUmaDays)
      .toDouble();
  final taxableBonus = (fiscalBonus - exemptAmount)
      .clamp(0, 9999999)
      .toDouble();
  final taxableBase = fiscalWeekly + fiscalVacationPay + taxableBonus;
  final subsidy = _calculateVacationWeeklySubsidy(taxableBase);

  double calculatedRetention;
  if (event.isrMethod == _HrVacationIsrMethod.manualRh) {
    calculatedRetention = 0;
  } else {
    calculatedRetention =
        _calculateVacationTariffTax(taxableBase, _kHrVacationWeeklyIsr2026) -
        subsidy;
  }
  final override = _parseVacationNullableNumber(event.isrRetentionOverrideText);
  return _HrVacationIsrBreakdown(
    taxableBase: taxableBase,
    exemptAmount: exemptAmount,
    subsidyAmount: subsidy,
    retentionAmount: ((override ?? calculatedRetention).clamp(
      0,
      fiscalVacationAmount,
    )).toDouble(),
    tariffYear: 2026,
  );
}

double _calculateVacationWeeklySubsidy(double taxableBase) {
  if (taxableBase <= 0) return 0;
  final bracket = _kHrVacationWeeklySubsidy2026.firstWhere(
    (item) => item.upper == null || taxableBase <= item.upper!,
    orElse: () => _kHrVacationWeeklySubsidy2026.last,
  );
  return bracket.subsidy;
}

double _calculateVacationTariffTax(
  double base,
  List<_HrVacationIsrBracket> brackets,
) {
  if (base <= 0) return 0;
  final bracket = brackets.firstWhere(
    (item) => item.upper == null || base <= item.upper!,
    orElse: () => brackets.last,
  );
  return (bracket.fixedQuota +
          ((base - bracket.lower).clamp(0, 999999999) * bracket.marginalRate))
      .clamp(0, 999999999)
      .toDouble();
}

bool _vacationEventHasPayrollFootprint(_HrVacationEventDraft event) {
  if (event.status != _HrVacationEventStatus.aplicado) return false;
  return event.eventType == _HrVacationEventType.vacacionesPagadas ||
      event.impactPrenomina ||
      event.generateReceipt;
}

bool _lotBelongsToVacationExercise(
  _HrVacationAttendanceLotLite lot,
  int exerciseYear,
) {
  final range = _extractVacationAttendanceDateRangeFromPeriodLabel(
    lot.periodLabel,
  );
  if (range != null) {
    return range.start.year == exerciseYear || range.end.year == exerciseYear;
  }
  return lot.importedAt.year == exerciseYear;
}

_HrVacationContpaqPaidSignal? _buildVacationContpaqPaidSignal({
  required _HrVacationAttendanceLotLite lot,
  required _HrVacationAttendanceImportedEntry entry,
  required _HrVacationEmployeeMaster? employee,
}) {
  final vacationsAmount = _parseVacationNumber(entry.vacations);
  if (vacationsAmount <= 0) return null;
  final employeeId = entry.employeeId.trim();
  if (employeeId.isEmpty) return null;
  final periodLabel = lot.periodLabel.trim().isEmpty
      ? 'CONTPAQ ${lot.importedAt.toIso8601String()}'
      : lot.periodLabel.trim();
  final periodRange = _extractVacationAttendanceDateRangeFromPeriodLabel(
    lot.periodLabel,
  );
  final periodAnchorDate =
      periodRange?.end ?? DateUtils.dateOnly(lot.importedAt);
  final salaryAmount = _parseVacationNumber(entry.salary);
  final employeeSalaryAmount = employee == null
      ? 0.0
      : _parseVacationMoney(employee.salario);
  final employeePerceivedAmount = employee == null
      ? 0.0
      : _parseVacationMoney(employee.salarioPercibido);
  final dailyBase = _resolveVacationContpaqDailyBase(
    entrySalaryAmount: salaryAmount,
    employeeSalaryAmount: employeeSalaryAmount,
    employeePerceivedAmount: employeePerceivedAmount,
  );
  final derivedDays = dailyBase > 0
      ? (vacationsAmount / dailyBase).clamp(0, 9999).toDouble()
      : 0.0;
  final employeeName = employee?.displayName.trim().isNotEmpty == true
      ? employee!.displayName
      : entry.sourceName;
  final netAmount = _parseVacationNumber(entry.net);
  final receiptGroupKey =
      '$_kHrVacationContpaqReceiptPrefix$periodLabel|$employeeId';
  final notes = _buildVacationContpaqNotes(
    fileName: lot.fileName,
    periodLabel: periodLabel,
    vacationsAmount: vacationsAmount,
    netAmount: netAmount,
    derivedDays: derivedDays,
  );
  return _HrVacationContpaqPaidSignal(
    receiptGroupKey: receiptGroupKey,
    employeeId: employeeId,
    employeeName: employeeName,
    fileName: lot.fileName,
    periodLabel: periodLabel,
    periodAnchorDate: periodAnchorDate,
    daysPaid: derivedDays,
    vacationAmount: vacationsAmount,
    netAmount: netAmount,
    salaryAmount: salaryAmount,
    notes: notes,
  );
}

double _resolveVacationContpaqDailyBase({
  required double entrySalaryAmount,
  required double employeeSalaryAmount,
  required double employeePerceivedAmount,
}) {
  if (entrySalaryAmount > 0) return entrySalaryAmount / 7;
  if (employeeSalaryAmount > 0) return employeeSalaryAmount / 7;
  if (employeePerceivedAmount > 0) return employeePerceivedAmount / 7;
  return 0;
}

String _buildVacationContpaqNotes({
  required String fileName,
  required String periodLabel,
  required double vacationsAmount,
  required double netAmount,
  required double derivedDays,
}) {
  final parts = <String>[
    'CONTPAQ $fileName',
    periodLabel,
    'Vacaciones ${_formatVacationMoney(vacationsAmount)}',
  ];
  if (netAmount > 0) {
    parts.add('Neto ${_formatVacationMoney(netAmount)}');
  }
  if (derivedDays > 0) {
    parts.add('Días estimados ${_formatVacationDays(derivedDays)}');
  } else {
    parts.add('Sin base para estimar días');
  }
  return parts.join(' · ');
}

Map<String, dynamic> _buildVacationContpaqEventRow({
  required _HrVacationContpaqPaidSignal signal,
  required int exerciseYear,
  required String? balanceId,
}) {
  return {
    'balance_id': balanceId,
    'employee_id': signal.employeeId,
    'employee_name': signal.employeeName,
    'exercise_year': exerciseYear,
    'event_type': 'vacaciones_pagadas',
    'start_date': _vacationDbDate(signal.periodAnchorDate),
    'end_date': _vacationDbDate(signal.periodAnchorDate),
    'days_applied': signal.daysPaid,
    'attendance_period_label': '',
    'attendance_sync_status': 'omitido',
    'prenomina_sync_status': 'aplicado',
    'impact_attendance': false,
    'impact_prenomina': true,
    'generate_receipt': true,
    'receipt_group_key': signal.receiptGroupKey,
    'status': 'aplicado',
    'notes': signal.notes,
  };
}

bool _vacationContpaqEventNeedsUpdate({
  required _HrVacationEventRecord existing,
  required _HrVacationContpaqPaidSignal desired,
}) {
  final desiredDate = DateUtils.dateOnly(desired.periodAnchorDate);
  return existing.eventType != _HrVacationEventType.vacacionesPagadas ||
      existing.status != _HrVacationEventStatus.aplicado ||
      existing.impactAttendance != false ||
      existing.impactPrenomina != true ||
      existing.generateReceipt != true ||
      existing.attendanceSyncStatus != _HrVacationSyncStatus.omitido ||
      existing.prenominaSyncStatus != _HrVacationSyncStatus.aplicado ||
      DateUtils.dateOnly(existing.startDate) != desiredDate ||
      DateUtils.dateOnly(existing.endDate) != desiredDate ||
      (existing.daysApplied - desired.daysPaid).abs() > 0.01 ||
      existing.notes.trim() != desired.notes.trim();
}

List<Map<String, dynamic>> _buildVacationContpaqCalculationPayloads({
  required String eventId,
  required _HrVacationContpaqPaidSignal signal,
  required int exerciseYear,
  required _HrVacationBaseDatePolicy baseDatePolicy,
}) {
  return <Map<String, dynamic>>[
    {
      'vacation_event_id': eventId,
      'employee_id': signal.employeeId,
      'exercise_year': exerciseYear,
      'sequence_no': 1,
      'component_label': 'CONTPAQ vacaciones',
      'calculation_mode': 'manual_rh',
      'base_date_policy': _baseDatePolicyToText(baseDatePolicy),
      'days_paid': signal.daysPaid,
      'daily_salary_used': signal.daysPaid > 0
          ? signal.vacationAmount / signal.daysPaid
          : 0,
      'daily_salary_perceived_used': 0,
      'vacation_pay': signal.vacationAmount,
      'vacation_bonus_rate': 0,
      'vacation_bonus_pay': 0,
      'transfer_component': signal.vacationAmount,
      'cash_component': 0,
      'difference_component': 0,
      'status': 'vigente',
      'is_final': true,
      'notes': signal.notes,
    },
  ];
}

bool _vacationContpaqCalculationsNeedUpdate({
  required List<_HrVacationCalculationRecord> existingRows,
  required List<Map<String, dynamic>> desiredRows,
}) {
  if (existingRows.length != desiredRows.length) return true;
  if (desiredRows.isEmpty) return false;
  final existing = existingRows.first;
  final desired = desiredRows.first;
  return existing.componentLabel !=
          (desired['component_label'] ?? '').toString() ||
      existing.calculationMode !=
          (desired['calculation_mode'] ?? '').toString() ||
      existing.baseDatePolicy !=
          _baseDatePolicyFromText(
            (desired['base_date_policy'] ?? '').toString(),
          ) ||
      (existing.daysPaid - _parseVacationNumber(desired['days_paid'])).abs() >
          0.01 ||
      (existing.dailySalaryUsed -
                  _parseVacationNumber(desired['daily_salary_used']))
              .abs() >
          0.01 ||
      (existing.vacationPay - _parseVacationNumber(desired['vacation_pay']))
              .abs() >
          0.01 ||
      (existing.vacationBonusRate -
                  _parseVacationNumber(desired['vacation_bonus_rate']))
              .abs() >
          0.0001 ||
      (existing.vacationBonusPay -
                  _parseVacationNumber(desired['vacation_bonus_pay']))
              .abs() >
          0.01 ||
      (existing.transferComponent -
                  _parseVacationNumber(desired['transfer_component']))
              .abs() >
          0.01 ||
      (existing.cashComponent - _parseVacationNumber(desired['cash_component']))
              .abs() >
          0.01 ||
      (existing.differenceComponent -
                  _parseVacationNumber(desired['difference_component']))
              .abs() >
          0.01 ||
      (existing.isrTaxableBase -
                  _parseVacationNumber(desired['isr_taxable_base']))
              .abs() >
          0.01 ||
      (existing.isrExemptAmount -
                  _parseVacationNumber(desired['isr_exempt_amount']))
              .abs() >
          0.01 ||
      (existing.isrRetentionAmount -
                  _parseVacationNumber(desired['isr_retention_amount']))
              .abs() >
          0.01 ||
      existing.isrMethod !=
          _vacationIsrMethodFromText(
            (desired['isr_method'] ?? '').toString(),
          ) ||
      existing.isFinal != (desired['is_final'] == true);
}

void _normalizeVacationEventDraft(
  _HrVacationEventDraft draft, {
  bool forceDays = false,
}) {
  if (draft.isrMethod != _HrVacationIsrMethod.manualRh) {
    draft.isrMethod = _HrVacationIsrMethod.tarifaSemanal;
  }
  if (draft.endDate.isBefore(draft.startDate)) {
    draft.endDate = draft.startDate;
  }
  if (forceDays || !draft.daysManuallyEdited) {
    draft.daysApplied = _suggestVacationDays(draft.startDate, draft.endDate);
  }
  if (!draft.additionalPaidDaysManuallyEdited) {
    draft.additionalPaidDays = _suggestVacationAdditionalPaidDays(
      draft.startDate,
      draft.endDate,
    );
  }
  if (draft.daysApplied < 0) {
    draft.daysApplied = 0.0;
  }
  if (!draft.impactAttendance ||
      draft.status == _HrVacationEventStatus.cancelado) {
    draft.attendanceSyncStatus = _HrVacationSyncStatus.omitido;
    draft.attendancePeriodLabel = '';
  } else {
    draft.attendanceSyncStatus = _HrVacationSyncStatus.pendiente;
  }
  draft.prenominaSyncStatus =
      !draft.impactPrenomina || draft.status == _HrVacationEventStatus.cancelado
      ? _HrVacationSyncStatus.omitido
      : _HrVacationSyncStatus.pendiente;
  // La emisión queda exclusivamente en Nómina, tras publicar el cierre.
  draft.generateReceipt = false;
}

class _HrVacationPillColorSet {
  final Color background;
  final Color border;
  final Color foreground;

  const _HrVacationPillColorSet({
    required this.background,
    required this.border,
    required this.foreground,
  });
}

_HrVacationPillColorSet _eventTypeColorSet(_HrVacationEventType value) {
  return switch (value) {
    _HrVacationEventType.vacacionesDisfrutadas => const _HrVacationPillColorSet(
      background: Color(0xFFE8D9FF),
      border: Color(0xFFB084FF),
      foreground: Color(0xFF24103D),
    ),
    _HrVacationEventType.vacacionesPagadas => const _HrVacationPillColorSet(
      background: Color(0xFFF4E7FF),
      border: Color(0xFFB084FF),
      foreground: Color(0xFF6E47A8),
    ),
    _HrVacationEventType.vacacionesPendientes => const _HrVacationPillColorSet(
      background: Color(0xFFF7F0FF),
      border: Color(0x66B084FF),
      foreground: Color(0xFF6E47A8),
    ),
    _HrVacationEventType.ajusteRh => const _HrVacationPillColorSet(
      background: Color(0xFFF3E9FF),
      border: Color(0xFFB084FF),
      foreground: Color(0xFF24103D),
    ),
  };
}

_HrVacationPillColorSet _eventStatusColorSet(_HrVacationEventStatus value) {
  return switch (value) {
    _HrVacationEventStatus.pendiente => const _HrVacationPillColorSet(
      background: Color(0xFFF7F0FF),
      border: Color(0x66B084FF),
      foreground: Color(0xFF6E47A8),
    ),
    _HrVacationEventStatus.aprobado => const _HrVacationPillColorSet(
      background: Color(0xFFEFE4FF),
      border: Color(0xFFB084FF),
      foreground: Color(0xFF6E47A8),
    ),
    _HrVacationEventStatus.aplicado => const _HrVacationPillColorSet(
      background: Color(0xFFDCC5FF),
      border: Color(0xFF8B5CF6),
      foreground: Color(0xFF24103D),
    ),
    _HrVacationEventStatus.cancelado => const _HrVacationPillColorSet(
      background: Color(0xFFF4E3EA),
      border: Color(0xFFD69BB3),
      foreground: Color(0xFF7A284C),
    ),
  };
}

_HrVacationPillColorSet _syncStatusColorSet(_HrVacationSyncStatus value) {
  return switch (value) {
    _HrVacationSyncStatus.pendiente => const _HrVacationPillColorSet(
      background: Color(0xFFF7F0FF),
      border: Color(0x66B084FF),
      foreground: Color(0xFF6E47A8),
    ),
    _HrVacationSyncStatus.aplicado => const _HrVacationPillColorSet(
      background: Color(0xFFDCC5FF),
      border: Color(0xFF8B5CF6),
      foreground: Color(0xFF24103D),
    ),
    _HrVacationSyncStatus.omitido => const _HrVacationPillColorSet(
      background: Color(0xFFEFE4FF),
      border: Color(0x55B084FF),
      foreground: Color(0xFF7D62A8),
    ),
  };
}

_HrVacationPillColorSet _vacationStatusBadgeColorSet(String label) {
  switch (label) {
    case 'Revisión RH':
      return const _HrVacationPillColorSet(
        background: Color(0xFFF4E3EA),
        border: Color(0xFFD69BB3),
        foreground: Color(0xFF7A284C),
      );
    case 'Pendiente asistencia':
      return const _HrVacationPillColorSet(
        background: Color(0xFFFFF0DD),
        border: Color(0xFFE0BE83),
        foreground: Color(0xFF8A4B00),
      );
    case 'Pendiente prenómina':
      return const _HrVacationPillColorSet(
        background: Color(0xFFF4E7FF),
        border: Color(0xFFB084FF),
        foreground: Color(0xFF6E47A8),
      );
    case 'Aplicado':
    case 'Listo para prenómina':
      return const _HrVacationPillColorSet(
        background: Color(0xFFDCC5FF),
        border: Color(0xFF8B5CF6),
        foreground: Color(0xFF24103D),
      );
    case 'Con ajuste RH':
      return const _HrVacationPillColorSet(
        background: Color(0xFFEFE4FF),
        border: Color(0xFFB084FF),
        foreground: Color(0xFF6E47A8),
      );
    case 'Calculado':
      return const _HrVacationPillColorSet(
        background: Color(0xFFF7F0FF),
        border: Color(0x66B084FF),
        foreground: Color(0xFF6E47A8),
      );
    case 'Pendiente':
    default:
      return const _HrVacationPillColorSet(
        background: Color(0xFFE8D9FF),
        border: Color(0x66B084FF),
        foreground: Color(0xFF24103D),
      );
  }
}

bool _vacationEventHasAttendanceSyncTarget(_HrVacationEventRecord event) {
  return event.impactAttendance &&
      event.status == _HrVacationEventStatus.aplicado;
}

bool _vacationRecordIsContpaqImported(_HrVacationEventRecord event) {
  return event.receiptGroupKey.startsWith(_kHrVacationContpaqReceiptPrefix);
}

bool _vacationEventCountsAsAttendanceApplied(_HrVacationEventRecord event) {
  return _vacationEventHasAttendanceSyncTarget(event) &&
      event.attendanceSyncStatus == _HrVacationSyncStatus.aplicado;
}

bool _vacationEventCountsAsAttendancePending(_HrVacationEventRecord event) {
  return _vacationEventHasAttendanceSyncTarget(event) &&
      event.attendanceSyncStatus == _HrVacationSyncStatus.pendiente;
}

bool _vacationEventCountsAsAttendanceReview(_HrVacationEventRecord event) {
  return _vacationEventHasAttendanceSyncTarget(event) &&
      event.attendanceSyncStatus == _HrVacationSyncStatus.omitido;
}

bool _vacationEventCountsAsPrenominaPending(_HrVacationEventRecord event) {
  return event.impactPrenomina &&
      event.status != _HrVacationEventStatus.cancelado &&
      event.prenominaSyncStatus == _HrVacationSyncStatus.pendiente;
}

bool _vacationEventNeedsOperationalNote(_HrVacationEventDraft draft) {
  return draft.isContpaqImported ||
      (draft.impactAttendance &&
          draft.status == _HrVacationEventStatus.aplicado &&
          draft.attendanceSyncStatus == _HrVacationSyncStatus.omitido) ||
      (draft.impactPrenomina &&
          draft.status != _HrVacationEventStatus.cancelado &&
          draft.prenominaSyncStatus == _HrVacationSyncStatus.pendiente);
}

String _vacationEventOperationalNote(_HrVacationEventDraft draft) {
  if (draft.isContpaqImported) {
    return 'El pago fiscal ya quedó sembrado desde CONTPAQ. RH todavía puede decidir si también corresponde disfrute, reserva o ajuste operativo dentro del ejercicio.';
  }
  if (draft.impactAttendance &&
      draft.status == _HrVacationEventStatus.aplicado &&
      draft.attendanceSyncStatus == _HrVacationSyncStatus.omitido) {
    return 'Este evento aplicado no pudo sembrarse automáticamente en Asistencia. RH debe revisar fichajes, rango o conflicto operativo antes del cierre.';
  }
  return 'Este evento ya tiene huella para prenómina, pero todavía requiere cierre operativo o validación RH antes de consolidar el ejercicio.';
}

String _resolveVacationSummaryStatus(_HrVacationSummaryRow row) {
  if (row.events.any(_vacationEventCountsAsAttendanceReview)) {
    return 'Revisión RH';
  }
  if (row.events.any(_vacationEventCountsAsAttendancePending)) {
    return 'Pendiente asistencia';
  }
  if (row.events.any(_vacationEventCountsAsPrenominaPending)) {
    return 'Pendiente prenómina';
  }
  if (row.manualOverride) {
    return 'Con ajuste RH';
  }
  return row.status.label;
}

_HrVacationRule? _resolveVacationRuleByYears({
  required List<_HrVacationRule> rules,
  required int years,
}) {
  if (years <= 0) return null;
  for (final rule in rules) {
    final max = rule.maxYears;
    if (years >= rule.minYears && (max == null || years <= max)) return rule;
  }
  return rules.isEmpty ? null : rules.last;
}

int _completedYearsOn(DateTime baseDate, DateTime asOf) {
  var years = asOf.year - baseDate.year;
  if (asOf.month < baseDate.month ||
      (asOf.month == baseDate.month && asOf.day < baseDate.day)) {
    years -= 1;
  }
  return years < 0 ? 0 : years;
}

double _suggestVacationDays(DateTime start, DateTime end) =>
    end.difference(start).inDays + 1.0;

double _suggestVacationAdditionalPaidDays(DateTime start, DateTime end) {
  var count = 0;
  var cursor = DateUtils.dateOnly(start);
  final last = DateUtils.dateOnly(end.isBefore(start) ? start : end);
  while (!cursor.isAfter(last)) {
    if (cursor.weekday == DateTime.sunday) count += 1;
    cursor = cursor.add(const Duration(days: 1));
  }
  return count.toDouble();
}

Set<String> _collectVacationAppliedDateLabels(
  List<_HrVacationEventRecord> events,
) {
  final labels = <String>{};
  for (final event in events) {
    if (!event.impactAttendance ||
        event.status != _HrVacationEventStatus.aplicado) {
      continue;
    }
    labels.addAll(_vacationDateRangeLabels(event.startDate, event.endDate));
  }
  return labels;
}

List<String> _vacationDateRangeLabels(DateTime start, DateTime end) {
  final orderedStart = DateTime(start.year, start.month, start.day);
  final orderedEnd = end.isBefore(start)
      ? orderedStart
      : DateTime(end.year, end.month, end.day);
  final labels = <String>[];
  var cursor = orderedStart;
  while (!cursor.isAfter(orderedEnd)) {
    labels.add(_formatVacationAttendanceDateLabel(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return labels;
}

_HrVacationEmployeeMaster? _findVacationEmployeeById(
  String employeeId,
  List<_HrVacationEmployeeMaster> employees,
) {
  for (final employee in employees) {
    if (employee.employeeId == employeeId) return employee;
  }
  return null;
}

List<String> _vacationPeriodOptions({
  required List<_HrVacationAttendanceLotLite> lots,
  required List<_HrVacationEventRecord> events,
}) {
  return HumanResourcesPeriodContext.normalizedOptions([
    for (final lot in lots) _describeVacationAttendancePeriod(lot),
    for (final event in events) event.attendancePeriodLabel,
  ]);
}

_HrVacationAttendanceLotLite? _vacationLotForPeriod(
  List<_HrVacationAttendanceLotLite> lots,
  _HrVacationAttendanceImportSource source,
  String selectedPeriodLabel,
) {
  if (selectedPeriodLabel.trim().isEmpty) return null;
  for (final lot in lots) {
    if (lot.source != source) continue;
    if (_vacationLotMatchesPeriod(lot, selectedPeriodLabel)) return lot;
  }
  return null;
}

bool _vacationLotMatchesPeriod(
  _HrVacationAttendanceLotLite lot,
  String selectedPeriodLabel,
) {
  final described = _describeVacationAttendancePeriod(lot);
  if (described == selectedPeriodLabel) return true;
  final selectedRange = _extractVacationAttendanceDateRangeFromPeriodLabel(
    selectedPeriodLabel,
  );
  final lotRange = _extractVacationAttendanceDateRangeFromPeriodLabel(
    described,
  );
  return selectedRange != null &&
      lotRange != null &&
      selectedRange.start == lotRange.start &&
      selectedRange.end == lotRange.end;
}

DateTimeRange? _resolveVacationAttendanceActiveRange({
  required _HrVacationAttendanceLotLite? ngtecoLot,
  required _HrVacationAttendanceLotLite? contpaqLot,
  required String activePeriodLabel,
}) {
  return _extractVacationAttendanceDateRangeFromPeriodLabel(activePeriodLabel);
}

DateTimeRange? _extractVacationAttendanceDateRangeFromPeriodLabel(String raw) {
  final match = RegExp(
    r'(?:del\s+)?(\d{2}/\d{2}/\d{4})\s+(?:al|-)\s+(\d{2}/\d{2}/\d{4})',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final start = _parseVacationAttendanceDateLabel(match.group(1)!);
  final end = _parseVacationAttendanceDateLabel(match.group(2)!);
  if (start == null || end == null) return null;
  return DateTimeRange(start: start, end: end);
}

bool _isVacationAttendanceDateWithinRange(
  String sourceDate,
  DateTimeRange? range,
) {
  if (range == null) return true;
  final parsed = _parseVacationAttendanceDateLabel(sourceDate);
  if (parsed == null) return false;
  return !parsed.isBefore(range.start) && !parsed.isAfter(range.end);
}

String _describeVacationAttendancePeriod(_HrVacationAttendanceLotLite lot) {
  final raw = lot.periodLabel.trim();
  if (raw.isEmpty) return 'Periodo no detectado';
  if (lot.source == _HrVacationAttendanceImportSource.ngteco) {
    final segments = raw.split('→').map((part) => part.trim()).toList();
    if (segments.length == 2) {
      final first = _parseVacationUsImportDate(segments[0]);
      final second = _parseVacationUsImportDate(segments[1]);
      if (first != null && second != null) {
        final ordered = [first, second]..sort();
        return '${_formatVacationAttendanceDateLabel(ordered.first)} - ${_formatVacationAttendanceDateLabel(ordered.last)}';
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

bool _shouldCreateVacationAttendanceRow({
  required _HrVacationEmployeeMaster employee,
  required String sourceDate,
}) {
  final parsedDate = _parseVacationAttendanceDateLabel(sourceDate);
  if (parsedDate == null) return false;
  final weekdayLabel = _vacationWeekdayLabel(parsedDate.weekday);
  return _resolveVacationScheduleForPunchlessDay(
        schedules: employee.workSchedules,
        weekdayLabel: weekdayLabel,
      ) !=
      null;
}

Map<String, dynamic> _buildVacationAttendanceRow({
  required String periodLabel,
  required String employeeId,
  required String employeeName,
  required String sourceDate,
  required String notes,
}) {
  final parsedDate = _parseVacationAttendanceDateLabel(sourceDate);
  return {
    'period_label': periodLabel,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'source_date': sourceDate,
    'weekday_label': parsedDate == null
        ? ''
        : _vacationWeekdayLabel(parsedDate.weekday),
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

String _vacationWeekdayLabel(int weekday) {
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

List<String> _parseVacationWeekdays(Object? value) {
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

List<_HrVacationWorkSchedule> _parseVacationWorkSchedules(
  Object? value, {
  required String fallbackHorario,
  required List<String> fallbackDiasLabora,
}) {
  final parsed = <_HrVacationWorkSchedule>[];
  if (value is List) {
    for (final item in value) {
      final map = _asMap(item);
      final horario = (map['horario'] ?? '').toString().trim();
      final dias = _parseVacationWeekdays(map['dias_labora']);
      if (horario.isEmpty && dias.isEmpty) continue;
      parsed.add(_HrVacationWorkSchedule(horario: horario, diasLabora: dias));
    }
  }
  if (parsed.isEmpty && fallbackHorario.trim().isNotEmpty) {
    parsed.add(
      _HrVacationWorkSchedule(
        horario: fallbackHorario.trim(),
        diasLabora: fallbackDiasLabora,
      ),
    );
  }
  return parsed;
}

class _HrVacationScheduleDraft {
  final TimeOfDay start;
  final TimeOfDay end;
  final TimeOfDay? lunchStart;
  final TimeOfDay? lunchEnd;

  const _HrVacationScheduleDraft({
    required this.start,
    required this.end,
    this.lunchStart,
    this.lunchEnd,
  });
}

_HrVacationScheduleDraft? _parseVacationSchedule(String? raw) {
  final normalized = (raw ?? '').trim();
  final pattern = RegExp(
    r'^(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})(?:\s*\|\s*comida\s*(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}))?$',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(normalized);
  if (match == null) return null;
  final start = _parseVacationTimeOfDay(match.group(1));
  final end = _parseVacationTimeOfDay(match.group(2));
  if (start == null || end == null) return null;
  return _HrVacationScheduleDraft(
    start: start,
    end: end,
    lunchStart: _parseVacationTimeOfDay(match.group(3)),
    lunchEnd: _parseVacationTimeOfDay(match.group(4)),
  );
}

_HrVacationScheduleDraft? _resolveVacationScheduleForPunchlessDay({
  required List<_HrVacationWorkSchedule> schedules,
  required String weekdayLabel,
}) {
  if (schedules.isEmpty) return null;
  for (final item in schedules) {
    final parsed = _parseVacationSchedule(item.horario);
    if (parsed == null) continue;
    if (!item.diasLabora.contains(weekdayLabel)) continue;
    return parsed;
  }
  return null;
}

TimeOfDay? _parseVacationTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

DateTime? _parseVacationAttendanceDateLabel(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatVacationAttendanceDateLabel(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}

DateTime? _parseVacationUsImportDate(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

bool _attendanceRowHasPunches(Map<String, dynamic> row) {
  final punchTimeline = ((row['punch_timeline'] as List?) ?? const <dynamic>[])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return (row['first_punch'] ?? '').toString().trim().isNotEmpty ||
      (row['last_punch'] ?? '').toString().trim().isNotEmpty ||
      punchTimeline.isNotEmpty;
}

Map<String, dynamic> _copyAttendanceRowForUpdate(
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

String _buildVacationAttendanceSyncNote(_HrVacationEventDraft event) {
  return '$_kHrVacationAttendanceSyncPrefix ${event.eventType.label} ${_formatVacationDate(event.startDate)} → ${_formatVacationDate(event.endDate)} (${_formatVacationDays(event.daysApplied)} día(s))';
}

String _mergeVacationAttendanceNotes(String existing, String note) {
  final lines = existing
      .split('\n')
      .map((item) => item.trim())
      .where(
        (item) =>
            item.isNotEmpty &&
            !item.startsWith(_kHrVacationAttendanceSyncPrefix),
      )
      .toList(growable: true);
  lines.add(note);
  return lines.join('\n');
}

String _removeVacationAttendanceNotes(String existing) {
  return existing
      .split('\n')
      .map((item) => item.trim())
      .where(
        (item) =>
            item.isNotEmpty &&
            !item.startsWith(_kHrVacationAttendanceSyncPrefix),
      )
      .join('\n');
}

String _fmtVacationInt(int value) {
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

String _formatVacationDays(double value) {
  if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

Future<Uint8List> _buildVacationReceiptPdfBytes({
  required _HrVacationSummaryRow row,
  required _HrVacationBalanceDraft balance,
  required _HrVacationEventDraft event,
  required _HrVacationAttendanceImportedEntry? contpaqEntry,
  required String contpaqPeriodLabel,
}) async {
  const companyName = 'DESPERDICIOS INDUSTRIALES CELAYA, S.A. DE C.V.';
  final purple = PdfColor.fromHex('#3B1F5C');
  final violet = PdfColor.fromHex('#7C4DFF');
  final lavender = PdfColor.fromHex('#F3EDFF');
  final softLavender = PdfColor.fromHex('#FBF9FF');
  final ink = PdfColor.fromHex('#24143D');
  final muted = PdfColor.fromHex('#6E5A8B');
  final border = PdfColor.fromHex('#D9C8F8');
  final receiptDate = DateTime.now();
  final perceivedWeekly = balance.salaryPerceivedSnapshot > 0
      ? balance.salaryPerceivedSnapshot
      : balance.salarySnapshot;
  final fiscalWeeklyImported = _parseVacationNumber(contpaqEntry?.net);
  final fiscalWeekly = fiscalWeeklyImported > 0
      ? fiscalWeeklyImported
      : balance.salarySnapshot;
  final dailySalary = perceivedWeekly > 0 ? perceivedWeekly / 7 : 0.0;
  final paidSalaryDays = event.daysApplied + event.additionalPaidDays;
  final vacationBase = paidSalaryDays * dailySalary;
  final vacationBonus = event.daysApplied * dailySalary * 0.25;
  final vacationTotal = vacationBase + vacationBonus;
  final importedFiscalVacation = _parseVacationNumber(contpaqEntry?.vacations);
  final fiscalVacation = importedFiscalVacation > 0
      ? importedFiscalVacation
      : _suggestVacationReceiptFiscalVacation(
          vacationTotal: vacationTotal,
          fiscalWeekly: fiscalWeekly,
          perceivedWeekly: perceivedWeekly,
        );
  final cashVacation = (vacationTotal - fiscalVacation)
      .clamp(0, 9999999)
      .toDouble();
  final cashWeekly = (perceivedWeekly - fiscalWeekly)
      .clamp(0, 9999999)
      .toDouble();
  final isr = _calculateVacationIsr(
    balance: balance,
    event: event,
    fiscalVacationAmount: fiscalVacation,
  );
  final transferTotal = (fiscalVacation + fiscalWeekly - isr.retentionAmount)
      .clamp(0, 9999999)
      .toDouble();
  final cashTotal = cashVacation + cashWeekly;
  final totalPayment = transferTotal + cashTotal;
  pw.MemoryImage? logo;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
    logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {
    // El recibo conserva su estructura si el recurso visual no está disponible.
  }

  final document = pw.Document(
    title: 'Recibo de vacaciones ${row.displayName}',
    author: 'DICSA - Recursos Humanos',
  );
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: purple,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              children: [
                if (logo != null)
                  pw.Container(
                    width: 48,
                    height: 48,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(9),
                    ),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                if (logo != null) pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'RECIBO DE VACACIONES',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Recursos Humanos',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#DCC7FF'),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _vacationReceiptLabel(
                      'FECHA DE EMISIÓN',
                      _formatVacationPdfDate(receiptDate),
                      PdfColors.white,
                    ),
                    pw.SizedBox(height: 5),
                    _vacationReceiptLabel(
                      'HORA',
                      _formatVacationPdfTime(receiptDate),
                      PdfColors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _vacationReceiptSection(
            title: 'Datos del colaborador',
            color: violet,
            child: pw.Column(
              children: [
                _vacationReceiptDataRow(
                  'Nombre del trabajador',
                  row.displayName,
                ),
                _vacationReceiptDataRow(
                  'ID / Empresa',
                  '#${row.employeeId}  -  ${row.empresa}',
                ),
                _vacationReceiptDataRow(
                  'Fecha de ingreso',
                  _formatVacationPdfDate(row.fechaIngreso),
                ),
                _vacationReceiptDataRow(
                  'Antigüedad / derecho',
                  '${balance.antiguedadYears} año(s)  -  ${_formatVacationDays(balance.daysEntitled)} día(s)',
                ),
                _vacationReceiptDataRow(
                  'Periodo de vacaciones',
                  '${_formatVacationPdfDate(event.startDate)} al ${_formatVacationPdfDate(event.endDate)}',
                ),
                if (contpaqPeriodLabel.trim().isNotEmpty)
                  _vacationReceiptDataRow(
                    'Periodo fiscal CONTPAQ',
                    contpaqPeriodLabel,
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _vacationReceiptSection(
            title: 'Cálculo vacacional',
            color: violet,
            child: pw.Table(
              border: pw.TableBorder.all(color: border, width: 0.7),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.1),
                1: pw.FlexColumnWidth(),
                2: pw.FlexColumnWidth(),
                3: pw.FlexColumnWidth(1.15),
              },
              children: [
                _vacationReceiptTableRow(
                  const ['Concepto', 'Días', 'Sueldo diario', 'Importe'],
                  background: lavender,
                  textColor: purple,
                  bold: true,
                ),
                _vacationReceiptTableRow([
                  'Vacaciones',
                  _formatVacationDays(paidSalaryDays),
                  _formatVacationMoney(dailySalary),
                  _formatVacationMoney(vacationBase),
                ]),
                _vacationReceiptTableRow([
                  'Prima vacacional (25%)',
                  _formatVacationDays(event.daysApplied),
                  _formatVacationMoney(dailySalary),
                  _formatVacationMoney(vacationBonus),
                ]),
                _vacationReceiptTableRow(
                  [
                    'TOTAL VACACIONES',
                    '',
                    '',
                    _formatVacationMoney(vacationTotal),
                  ],
                  background: PdfColor.fromHex('#E6DAFF'),
                  textColor: purple,
                  bold: true,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _vacationReceiptSection(
                  title: 'Desglose transferencia',
                  color: violet,
                  child: _vacationReceiptTotals(
                    rows: [
                      ('Vacaciones fiscales', fiscalVacation),
                      ('Nómina fiscal', fiscalWeekly),
                      ('Retención ISR', -isr.retentionAmount),
                    ],
                    totalLabel: 'TOTAL TRANSFERENCIA',
                    total: transferTotal,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _vacationReceiptSection(
                  title: 'Desglose efectivo',
                  color: violet,
                  child: _vacationReceiptTotals(
                    rows: [
                      ('Vacaciones en efectivo', cashVacation),
                      ('Sueldo en efectivo', cashWeekly),
                    ],
                    totalLabel: 'TOTAL EFECTIVO',
                    total: cashTotal,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: pw.BoxDecoration(
              color: purple,
              borderRadius: pw.BorderRadius.circular(9),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL DE PAGO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                pw.Text(
                  _formatVacationMoney(totalPayment),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: softLavender,
              border: pw.Border.all(color: border),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'El presente recibo detalla el convenio y pago vacacional registrado por Recursos Humanos. '
              'ISR: base gravable ${_formatVacationMoney(isr.taxableBase)}, prima exenta ${_formatVacationMoney(isr.exemptAmount)}, subsidio ${_formatVacationMoney(isr.subsidyAmount)} y retención ${_formatVacationMoney(isr.retentionAmount)}. '
              'RH debe confirmar el importe contra el CFDI cuando exista.',
              style: pw.TextStyle(color: muted, fontSize: 8.6, lineSpacing: 2),
            ),
          ),
          pw.Spacer(),
          pw.Row(
            children: [
              _vacationReceiptSignature(
                'Nombre y firma del trabajador',
                row.displayName,
                ink,
              ),
              pw.SizedBox(width: 34),
              _vacationReceiptSignature('Recursos Humanos', 'DICSA', ink),
            ],
          ),
        ],
      ),
    ),
  );
  return document.save();
}

double _suggestVacationReceiptFiscalVacation({
  required double vacationTotal,
  required double fiscalWeekly,
  required double perceivedWeekly,
}) {
  if (vacationTotal <= 0) return 0;
  if (fiscalWeekly <= 0 || perceivedWeekly <= 0) return vacationTotal;
  return vacationTotal * (fiscalWeekly / perceivedWeekly).clamp(0, 1);
}

pw.Widget _vacationReceiptSection({
  required String title,
  required PdfColor color,
  required pw.Widget child,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColor.fromHex('#D9C8F8')),
      borderRadius: pw.BorderRadius.circular(9),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        child,
      ],
    ),
  );
}

pw.Widget _vacationReceiptDataRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 132,
        child: pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#6E5A8B'),
            fontSize: 8.5,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#24143D'),
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
);

pw.TableRow _vacationReceiptTableRow(
  List<String> values, {
  PdfColor? background,
  PdfColor? textColor,
  bool bold = false,
}) => pw.TableRow(
  decoration: pw.BoxDecoration(color: background),
  children: values
      .map(
        (value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              color: textColor ?? PdfColor.fromHex('#24143D'),
              fontSize: 8.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      )
      .toList(growable: false),
);

pw.Widget _vacationReceiptTotals({
  required List<(String, double)> rows,
  required String totalLabel,
  required double total,
}) => pw.Column(
  children: [
    for (final row in rows)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              row.$1,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#6E5A8B'),
                fontSize: 8.5,
              ),
            ),
            pw.Text(
              _formatVacationMoney(row.$2),
              style: pw.TextStyle(
                color: PdfColor.fromHex('#24143D'),
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    pw.Divider(color: PdfColor.fromHex('#D9C8F8')),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          totalLabel,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#3B1F5C'),
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          _formatVacationMoney(total),
          style: pw.TextStyle(
            color: PdfColor.fromHex('#3B1F5C'),
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  ],
);

pw.Widget _vacationReceiptSignature(String label, String name, PdfColor ink) =>
    pw.Expanded(
      child: pw.Column(
        children: [
          pw.SizedBox(height: 30),
          pw.Container(height: 0.8, color: ink),
          pw.SizedBox(height: 5),
          pw.Text(
            name,
            style: pw.TextStyle(
              color: ink,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#6E5A8B'),
              fontSize: 7.5,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

pw.Widget _vacationReceiptLabel(String label, String value, PdfColor color) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFFDCC7FF),
            fontSize: 6.5,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: color,
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );

String _formatVacationPdfDate(DateTime? value) {
  if (value == null) return 'Pendiente';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatVacationPdfTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _vacationFileSlug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _formatVacationMoney(double value) {
  final sign = value < 0 ? '-' : '';
  final absolute = value.abs().toStringAsFixed(2);
  final parts = absolute.split('.');
  final integer = parts.first;
  final decimal = parts.last;
  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    final reverseIndex = integer.length - i;
    buffer.write(integer[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '$sign\$$buffer.$decimal';
}

double _parseVacationMoney(String value) => _parseVacationNumber(value);

double? _parseVacationNullableNumber(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return _parseVacationNumber(raw);
}

String _formatVacationNullableMoney(double? value) {
  if (value == null || value == 0) return '';
  return value.toStringAsFixed(2);
}

double _parseVacationNumber(Object? raw) {
  if (raw == null) return 0;
  if (raw is num) return raw.toDouble();
  final normalized = raw
      .toString()
      .replaceAll('\$', '')
      .replaceAll(',', '')
      .trim();
  return double.tryParse(normalized) ?? 0;
}

String _vacationDbNumericToText(Object? raw) {
  if (raw == null) return '';
  if (raw is int) return raw.toString();
  if (raw is double) {
    final fixed = raw.toStringAsFixed(2);
    if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
    return fixed;
  }
  return raw.toString();
}

DateTime? _parseVacationDbDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String _formatVacationDate(DateTime? value) {
  if (value == null) return 'Pendiente';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String? _vacationDbDate(DateTime? value) =>
    value?.toIso8601String().split('T').first;

_HrVacationBaseDatePolicy _baseDatePolicyFromText(String value) {
  return switch (value) {
    'fecha_alta' => _HrVacationBaseDatePolicy.fechaAlta,
    'manual_rh' => _HrVacationBaseDatePolicy.manualRh,
    _ => _HrVacationBaseDatePolicy.fechaIngreso,
  };
}

String _baseDatePolicyToText(_HrVacationBaseDatePolicy value) {
  return switch (value) {
    _HrVacationBaseDatePolicy.fechaIngreso => 'fecha_ingreso',
    _HrVacationBaseDatePolicy.fechaAlta => 'fecha_alta',
    _HrVacationBaseDatePolicy.manualRh => 'manual_rh',
  };
}

_HrVacationBalanceStatus _balanceStatusFromText(String value) {
  return switch (value) {
    'calculado' => _HrVacationBalanceStatus.calculado,
    'aplicado' => _HrVacationBalanceStatus.aplicado,
    'con_ajuste_rh' => _HrVacationBalanceStatus.conAjusteRh,
    'listo_prenomina' => _HrVacationBalanceStatus.listoPrenomina,
    _ => _HrVacationBalanceStatus.pendiente,
  };
}

String _balanceStatusToText(_HrVacationBalanceStatus value) {
  return switch (value) {
    _HrVacationBalanceStatus.pendiente => 'pendiente',
    _HrVacationBalanceStatus.calculado => 'calculado',
    _HrVacationBalanceStatus.aplicado => 'aplicado',
    _HrVacationBalanceStatus.conAjusteRh => 'con_ajuste_rh',
    _HrVacationBalanceStatus.listoPrenomina => 'listo_prenomina',
  };
}

_HrVacationEventType _eventTypeFromText(String value) {
  return switch (value) {
    'vacaciones_pagadas' => _HrVacationEventType.vacacionesPagadas,
    'vacaciones_pendientes' => _HrVacationEventType.vacacionesPendientes,
    'ajuste_rh' => _HrVacationEventType.ajusteRh,
    _ => _HrVacationEventType.vacacionesDisfrutadas,
  };
}

String _eventTypeToText(_HrVacationEventType value) {
  return switch (value) {
    _HrVacationEventType.vacacionesDisfrutadas => 'vacaciones_disfrutadas',
    _HrVacationEventType.vacacionesPagadas => 'vacaciones_pagadas',
    _HrVacationEventType.vacacionesPendientes => 'vacaciones_pendientes',
    _HrVacationEventType.ajusteRh => 'ajuste_rh',
  };
}

_HrVacationEventStatus _eventStatusFromText(String value) {
  return switch (value) {
    'aprobado' => _HrVacationEventStatus.aprobado,
    'aplicado' => _HrVacationEventStatus.aplicado,
    'cancelado' => _HrVacationEventStatus.cancelado,
    _ => _HrVacationEventStatus.pendiente,
  };
}

String _eventStatusToText(_HrVacationEventStatus value) {
  return switch (value) {
    _HrVacationEventStatus.pendiente => 'pendiente',
    _HrVacationEventStatus.aprobado => 'aprobado',
    _HrVacationEventStatus.aplicado => 'aplicado',
    _HrVacationEventStatus.cancelado => 'cancelado',
  };
}

_HrVacationSyncStatus _syncStatusFromText(String value) {
  return switch (value) {
    'aplicado' => _HrVacationSyncStatus.aplicado,
    'omitido' => _HrVacationSyncStatus.omitido,
    _ => _HrVacationSyncStatus.pendiente,
  };
}

_HrVacationIsrMethod _vacationIsrMethodFromText(String value) {
  return switch (value) {
    'tarifa_semanal' => _HrVacationIsrMethod.tarifaSemanal,
    'manual_rh' => _HrVacationIsrMethod.manualRh,
    _ => _HrVacationIsrMethod.articulo174,
  };
}

String _vacationIsrMethodToText(_HrVacationIsrMethod value) {
  return switch (value) {
    _HrVacationIsrMethod.articulo174 => 'articulo_174',
    _HrVacationIsrMethod.tarifaSemanal => 'tarifa_semanal',
    _HrVacationIsrMethod.manualRh => 'manual_rh',
  };
}

String _syncStatusToText(_HrVacationSyncStatus value) {
  return switch (value) {
    _HrVacationSyncStatus.pendiente => 'pendiente',
    _HrVacationSyncStatus.aplicado => 'aplicado',
    _HrVacationSyncStatus.omitido => 'omitido',
  };
}
