import 'human_resources_fiscal_payment.dart';
import 'human_resources_fiscal_payment_card.dart';
import 'human_resources_compensation.dart';
import 'human_resources_lateness.dart';
import 'human_resources_overtime.dart';
import 'human_resources_prepaid_vacation.dart';
import 'human_resources_vacation_pay.dart';
import 'dart:async';
import 'dart:convert';
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
import '../shared/utils/file_download_save.dart';
import '../shared/utils/simple_xlsx_builder.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_terminations_page.dart';
import 'human_resources_loans_page.dart';
import 'human_resources_loans.dart';
import 'loans/loan_repository.dart';
import 'human_resources_attendance_source.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_employee_status.dart';
import 'human_resources_event_period_impacts.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_period_context.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

part 'prenomina/prenomina_editor_test_support.dart';
part 'prenomina/prenomina_employee_editor.dart';
part 'prenomina/prenomina_grid.dart';
part 'prenomina/prenomina_grid_test_support.dart';
part 'prenomina/prenomina_dashboard.dart';
part 'prenomina/prenomina_employee_sidebar.dart';
part 'prenomina/prenomina_editor_sections.dart';
part 'prenomina/prenomina_editor_widgets.dart';
part 'prenomina/prenomina_closure_review.dart';
part 'prenomina/prenomina_publication_dialog.dart';

const String _kHrPrenominaProfilesTable = 'hr_employee_profiles';
const String _kHrPrenominaImportLotsTable = 'hr_attendance_import_lots';
const String _kHrPrenominaAttendanceDailyRecordsTable =
    'hr_attendance_daily_records';
const String _kHrPrenominaVacationEventsTable = 'hr_employee_vacation_events';
const String _kHrPrenominaPermissionEventsTable =
    'hr_employee_permission_events';
const String _kHrPrenominaDraftRowsTable = 'hr_prenomina_draft_rows';
const String _kHrPrenominaPeriodClosuresTable = 'hr_payroll_period_closures';

const String _kHrPrenominaVacationSyncPrefix = 'Vacaciones RH:';
const String _kHrPrenominaPermissionSyncPrefix = 'Permisos RH:';
const String _kHrPrenominaContpaqReceiptPrefix = 'contpaq:';

const double _kHrPrenominaHoursPerDay = 8;

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
  String _employeeSearch = '';
  String? _companyFilter;
  bool _incidencesOnly = false;
  List<_HrPrenominaSummaryRow> _periodRows = const [];
  Map<String, _PrenominaAttendanceDiagnostic> _attendanceDiagnostics = const {};
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
  List<HrEventPeriodImpactRecord> _eventPeriodImpacts =
      const <HrEventPeriodImpactRecord>[];
  List<_HrPrenominaDraftRowRecord> _draftRows =
      const <_HrPrenominaDraftRowRecord>[];
  HrLoanFundState? _loanFund;
  String? _loanLoadError;
  String? _changingStatusEmployeeId;
  bool _publishingAll = false;
  final _publicationRetries = <String, Set<String>>{};
  bool get _updatingStatuses =>
      _publishingAll || _changingStatusEmployeeId != null;
  final _statusMenuKeys =
      <String, GlobalKey<PopupMenuButtonState<_HrPrenominaDraftStatus>>>{};

  GlobalKey<PopupMenuButtonState<_HrPrenominaDraftStatus>> _statusMenuKey(
    String employeeId,
  ) => _statusMenuKeys.putIfAbsent(employeeId, () => GlobalKey());
  List<_HrPrenominaPeriodClosure> _periodClosures =
      const <_HrPrenominaPeriodClosure>[];
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
      final selectedPeriodLabel =
          await HumanResourcesPeriodContext.readSelectedLabel();
      final client = Supabase.instance.client;
      final employeesResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrPrenominaProfilesTable)
            .select(
              'id,nombre,empresa,fecha_ingreso,fecha_alta,salario,salario_real_percibido,salario_flujo,fiscal_payment_mode,overtime_hourly_rate,employment_status,termination_date',
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
      List<dynamic> eventPeriodImpactsResult = const <dynamic>[];
      List<dynamic> draftRowsResult = const <dynamic>[];
      List<dynamic> periodClosuresResult = const <dynamic>[];
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
        eventPeriodImpactsResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(hrEventPeriodImpactsTable)
              .select()
              .order('period_start_date')
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
      try {
        periodClosuresResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrPrenominaPeriodClosuresTable)
              .select()
              .order('created_at', ascending: false)
              .range(from, to),
        );
      } catch (_) {}

      try {
        _loanFund = await HrLoanRepository(client).load();
        _loanLoadError = null;
      } catch (_) {
        _loanFund = null;
        _loanLoadError =
            'No se pudieron consultar los préstamos. Vuelve a abrir Prenómina antes de guardar o cerrar.';
      }

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
      final attendanceRecords = attendanceResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .where(isHrOperationalAttendanceRow)
          .map(_HrPrenominaAttendanceRecord.fromRow)
          .toList(growable: false);
      final vacationEvents = vacationEventsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaVacationEventRecord.fromRow)
          .toList(growable: false);
      final permissionEvents = permissionEventsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaPermissionEventRecord.fromRow)
          .toList(growable: false);
      final draftRows = draftRowsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaDraftRowRecord.fromRow)
          .toList(growable: false);
      final periodClosures = periodClosuresResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrPrenominaPeriodClosure.fromRow)
          .toList(growable: false);
      final initialImpacts = eventPeriodImpactsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(HrEventPeriodImpactRecord.fromRow)
          .toList(growable: false);
      final availablePeriods = _prenominaPeriodOptions(
        lots: importLots,
        attendanceRecords: attendanceRecords,
        vacationEvents: vacationEvents,
        permissionEvents: permissionEvents,
        eventPeriodImpacts: initialImpacts,
        drafts: draftRows,
        closures: periodClosures,
      );
      final activePeriod = HumanResourcesPeriodContext.resolveSelected(
        selectedLabel: selectedPeriodLabel,
        availableLabels: availablePeriods,
      );
      if (activePeriod.isNotEmpty) {
        try {
          await _syncPrenominaPendingEventImpacts(
            client: client,
            vacationEvents: vacationEvents,
            permissionEvents: permissionEvents,
            knownPeriodLabels: availablePeriods,
            activePeriodLabel: activePeriod,
          );
          eventPeriodImpactsResult = await fetchAllSupabaseRows(
            (from, to) => client
                .from(hrEventPeriodImpactsTable)
                .select()
                .order('period_start_date')
                .range(from, to),
          );
        } catch (_) {
          // The migration may not yet be installed during a staged rollout.
          // Prenomina retains the legacy event reading until it is available.
        }
      }

      if (!mounted) return;
      _employees = employees;
      _importLots = importLots;
      _attendanceRecords = attendanceRecords;
      _vacationEvents = vacationEvents;
      _permissionEvents = permissionEvents;
      _eventPeriodImpacts = eventPeriodImpactsResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(HrEventPeriodImpactRecord.fromRow)
          .toList(growable: false);
      _draftRows = draftRows;
      _periodClosures = periodClosures;
      _selectedPeriodLabel = selectedPeriodLabel;
      _periodOptions = _prenominaPeriodOptions(
        lots: importLots,
        attendanceRecords: _attendanceRecords,
        vacationEvents: _vacationEvents,
        permissionEvents: _permissionEvents,
        eventPeriodImpacts: _eventPeriodImpacts,
        drafts: _draftRows,
        closures: _periodClosures,
      );
      _rebuildRows();
      if (_loanLoadError != null) _showSnack(_loanLoadError!);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  _HrPrenominaPeriodClosure? get _activePeriodClosure {
    for (final closure in _periodClosures) {
      if (closure.periodLabel == _activePeriodLabel) return closure;
    }
    return null;
  }

  bool get _isActivePeriodClosed => _activePeriodClosure?.isClosed ?? false;

  int get _activePublishedDraftCount => _draftRows
      .where(
        (row) =>
            row.periodLabel == _activePeriodLabel &&
            row.draftStatus == _HrPrenominaDraftStatus.publicado,
      )
      .map((row) => row.employeeId)
      .toSet()
      .length;

  int get _activePendingDraftCount => _activePeriodLabel.isEmpty
      ? 0
      : math.max(0, _periodRows.length - _activePublishedDraftCount);

  void _rebuildRows() {
    final periodLabel = HumanResourcesPeriodContext.resolveSelected(
      selectedLabel: _selectedPeriodLabel,
      availableLabels: _periodOptions,
    );
    final contpaqLot = _prenominaLotForPeriod(
      _importLots,
      _HrPrenominaImportSource.contpaq,
      periodLabel,
    );
    final rows = periodLabel.isEmpty
        ? const <_HrPrenominaSummaryRow>[]
        : _buildPrenominaSummaryRows(
            loanFund: _loanFund,
            freezeLoanPlans: _isActivePeriodClosed,
            employees: _employees,
            contpaqLot: contpaqLot,
            attendanceRecords: _attendanceRecords,
            vacationEvents: _vacationEvents,
            permissionEvents: _permissionEvents,
            eventPeriodImpacts: _eventPeriodImpacts,
            draftRows: _draftRows,
            activePeriodLabel: periodLabel,
            activeContpaqRawPeriodLabel: contpaqLot?.periodLabel.trim() ?? '',
          );
    _periodRows = rows;
    _attendanceDiagnostics = _prenominaAttendanceDiagnostics(
      _attendanceRecords,
      periodLabel,
    );
    final filteredRows = _applyFilters(rows)
        .where(
          (row) => _prenominaMatchesDashboardFilters(
            row,
            _attendanceDiagnostics[row.employeeId],
            query: _employeeSearch,
            company: _companyFilter,
            incidencesOnly: _incidencesOnly,
          ),
        )
        .toList(growable: false);
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

  Future<void> _selectPeriod(String periodLabel) async {
    if (_updatingStatuses) return;
    await HumanResourcesPeriodContext.select(periodLabel);
    if (!mounted) return;
    _selectedPeriodLabel = periodLabel;
    _currentPage = 0;
    _rebuildRows();
  }

  bool _requireActivePeriod() {
    if (_activePeriodLabel.isNotEmpty) return true;
    _showSnack('Selecciona un periodo operativo antes de editar prenómina.');
    return false;
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

  Future<void> _openTerminations() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesTerminationsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openLoans() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesLoansPage(instantOpen: true)),
    );
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
    if (!_requireActivePeriod()) return;
    final initialIndex = _allRows.indexWhere(
      (candidate) => candidate.employeeId == row.employeeId,
    );
    if (initialIndex < 0) return;
    await _openSummaryRowAtIndex(initialIndex);
  }

  Future<void> _openSummaryRowAtIndex(
    int index, {
    bool entirePeriod = false,
    _PrenominaSection initialSection = _PrenominaSection.resumen,
  }) async {
    if (_updatingStatuses) return;
    List<_HrPrenominaSummaryRow> editRows() =>
        entirePeriod ? _periodRows : _allRows;
    var currentIndex = index;
    while (currentIndex >= 0 && currentIndex < editRows().length) {
      final row = editRows()[currentIndex];
      _focusEmployeeRow(row.employeeId);
      if (!mounted) return;
      final result = await showDialog<_HrPrenominaEditResult>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _HrPrenominaEditDialog(
          initialSection: initialSection,
          row: row,
          attendance: _attendanceRecords
              .where(
                (item) =>
                    item.employeeId == row.employeeId &&
                    item.periodLabel == _activePeriodLabel,
              )
              .toList(growable: false),
          preview: (draft) {
            final lot = _prenominaLotForPeriod(
              _importLots,
              _HrPrenominaImportSource.contpaq,
              _activePeriodLabel,
            );
            return _buildPrenominaSummaryRows(
              loanFund: _loanFund,
              freezeLoanPlans: _isActivePeriodClosed,
              employees: _employees
                  .where((item) => item.employeeId == row.employeeId)
                  .toList(growable: false),
              contpaqLot: lot,
              attendanceRecords: _attendanceRecords,
              vacationEvents: _vacationEvents,
              permissionEvents: _permissionEvents,
              eventPeriodImpacts: _eventPeriodImpacts,
              draftRows: [
                _HrPrenominaDraftRowRecord.fromRow(
                  draft.toRow(
                    periodLabel: _activePeriodLabel,
                    employeeId: row.employeeId,
                    employeeName: row.displayName,
                    empresa: row.empresa,
                    existingId: row.draftId,
                  ),
                ),
              ],
              activePeriodLabel: _activePeriodLabel,
              activeContpaqRawPeriodLabel: lot?.periodLabel.trim() ?? '',
            ).single;
          },
          periodLabel: _activePeriodLabel,
          canGoPrevious: currentIndex > 0,
          canGoNext: currentIndex < editRows().length - 1,
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
          if (currentIndex < editRows().length - 1) {
            currentIndex += 1;
            continue;
          }
          _focusEmployeeRow(row.employeeId);
          return;
      }
    }
  }

  Future<void> _changeRowStatus(
    _HrPrenominaSummaryRow row,
    _HrPrenominaDraftStatus status,
  ) async {
    if (_updatingStatuses || _isActivePeriodClosed) return;
    if (status == row.draftStatus && row.draftId.isNotEmpty) {
      if (row.statusLabel != status.label) {
        _showSnack(
          'El estado guardado es ${status.label}; la tabla muestra '
          '${row.statusLabel} porque hay asistencia pendiente de revisión.',
        );
      }
      return;
    }
    final draft = _HrPrenominaDraftDraft.fromSummaryRow(row)
      ..draftStatus = status;
    final validation = draft.validationMessage(
      fiscalAvailable: row.fiscalBeforeManualDeductionAmount,
    );
    if (validation != null) {
      _showSnack('$validation Abre el detalle para corregirlo.');
      return;
    }
    setState(() => _changingStatusEmployeeId = row.employeeId);
    try {
      await _saveDraftRow(
        row: row,
        result: _HrPrenominaEditResult(
          action: _HrPrenominaEditAction.save,
          draft: draft,
        ),
      );
    } catch (_) {
      if (mounted) {
        _showSnack(
          'No se pudo completar el cambio de estado de ${row.displayName}. '
          'Revisa tu conexión e intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _changingStatusEmployeeId = null);
    }
  }

  Future<void> _saveDraftRow({
    required _HrPrenominaSummaryRow row,
    required _HrPrenominaEditResult result,
  }) async {
    if (!_requireActivePeriod()) return;
    if (_loanLoadError != null) {
      _showSnack(_loanLoadError!);
      return;
    }
    if (_isActivePeriodClosed) {
      _showSnack(
        'El periodo ya está cerrado. Registra cualquier diferencia como ajuste RH.',
      );
      return;
    }
    final isFirstPublication =
        result.draft.draftStatus == _HrPrenominaDraftStatus.publicado &&
        row.draftStatus != _HrPrenominaDraftStatus.publicado;
    if (isFirstPublication) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publicar cierre semanal'),
          content: Text(
            'Se liquidarán los eventos de vacaciones y permisos de '
            '${row.displayName} para este periodo. Las correcciones posteriores '
            'deberán registrarse como ajuste, sin reabrir esta corrida.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Publicar cierre'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final payload = result.draft.toRow(
      periodLabel: _activePeriodLabel,
      employeeId: row.employeeId,
      employeeName: row.displayName,
      empresa: row.empresa,
      existingId: row.draftId,
    );
    await _persistDraftRow(payload);
    _publicationRetries[_activePeriodLabel]?.remove(row.employeeId);
    await _loadData();
    if (!mounted) return;
    final reviewNote =
        result.draft.draftStatus == _HrPrenominaDraftStatus.listo &&
            row.attendanceReviewDays > 0
        ? ' La tabla sigue en Revisión RH por asistencia pendiente.'
        : '';
    _showSnack(
      'Prenómina de ${row.displayName} guardada: ${result.draft.draftStatus.label}.$reviewNote',
    );
  }

  Future<void> _persistDraftRow(Map<String, dynamic> payload) async {
    final client = Supabase.instance.client;
    final employeeId = payload['employee_id'] as String;
    final periodLabel = payload['period_label'] as String;
    await client
        .from(_kHrPrenominaDraftRowsTable)
        .upsert(payload, onConflict: 'period_label,employee_id');

    if (payload['draft_status'] == 'publicado') {
      await _settleOperationalEventsForPublishedDraft(
        client: client,
        employeeId: employeeId,
      );
    }

    final refreshedResult = await client
        .from(_kHrPrenominaDraftRowsTable)
        .select()
        .eq('period_label', periodLabel)
        .eq('employee_id', employeeId)
        .limit(1);
    final refreshed = (refreshedResult as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .map(_HrPrenominaDraftRowRecord.fromRow)
        .toList(growable: false);
    _draftRows = [
      for (final item in _draftRows)
        if (!(item.periodLabel == periodLabel && item.employeeId == employeeId))
          item,
      ...refreshed,
    ];
  }

  Future<void> _publishAll() async {
    if (_updatingStatuses || _isActivePeriodClosed || !_requireActivePeriod()) {
      return;
    }
    final period = _activePeriodLabel;
    final retries = _publicationRetries.putIfAbsent(period, () => <String>{});
    final candidates = _periodRows
        .where(
          (row) =>
              row.draftId.isEmpty ||
              row.draftStatus != _HrPrenominaDraftStatus.publicado ||
              retries.contains(row.employeeId),
        )
        .toList(growable: false);
    setState(() => _publishingAll = true);
    try {
      if (_loanLoadError != null) {
        await _showPublicationMessage(
          'No se puede publicar todavía',
          _loanLoadError!,
        );
        return;
      }
      if (candidates.isEmpty) {
        await _showPublicationMessage(
          'Publicar todo',
          _periodRows.isEmpty
              ? 'No hay colaboradores en este periodo.'
              : 'Todos los colaboradores del periodo ya están publicados.',
        );
        return;
      }
      final payloads = <Map<String, dynamic>>[];
      final invalid = <String>[];
      for (final row in candidates) {
        final draft = _HrPrenominaDraftDraft.fromSummaryRow(row)
          ..draftStatus = _HrPrenominaDraftStatus.publicado;
        final validation = draft.validationMessage(
          fiscalAvailable: row.fiscalBeforeManualDeductionAmount,
        );
        if (validation != null) {
          invalid.add(
            '${row.displayName} · ID ${row.employeeId} · ${row.empresa}\n$validation',
          );
        } else {
          payloads.add(
            draft.toRow(
              periodLabel: period,
              employeeId: row.employeeId,
              employeeName: row.displayName,
              empresa: row.empresa,
              existingId: row.draftId,
            ),
          );
        }
      }
      if (invalid.isNotEmpty) {
        await _showPublicationMessage(
          'Revisa estos colaboradores',
          'Corrige los siguientes datos en el detalle antes de publicar todo. No se guardó ningún cambio.',
          details: invalid,
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _PrenominaPublicationDialog(
          title: 'Publicar todo el periodo',
          period: period,
          message:
              'Se publicarán ${candidates.length} colaboradores de este periodo, incluidos los ocultos por filtros y otras páginas. '
              '${_periodRows.length - candidates.length} ya publicados se conservarán.\n\n'
              'Se guardarán los importes y notas actuales y se liquidarán los eventos de vacaciones y permisos, igual que al publicar cada detalle. '
              'Las correcciones posteriores deberán registrarse como ajustes RH.',
          confirmLabel: 'Publicar todo',
        ),
      );
      if (confirmed != true || !mounted) return;
      final progress = ValueNotifier<(int, String)>((
        0,
        'Preparando publicación…',
      ));
      final progressDialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: ValueListenableBuilder<(int, String)>(
            valueListenable: progress,
            builder: (_, value, _) => _PrenominaPublicationDialog(
              title: 'Publicando prenómina',
              period: period,
              message:
                  '${value.$1} de ${payloads.length} procesados\n${value.$2}',
              progress: value.$1 / payloads.length,
            ),
          ),
        ),
      );
      final failures = <String>[];
      var published = 0;
      try {
        for (var index = 0; index < payloads.length; index++) {
          if (!mounted) break;
          final payload = payloads[index];
          final employeeId = payload['employee_id'] as String;
          progress.value = (index, payload['employee_name'] as String);
          try {
            // Use the same persistence and event settlement as individual publication.
            await _persistDraftRow(payload);
            retries.remove(employeeId);
            published++;
          } catch (_) {
            // An upsert may succeed before an event settlement or read fails.
            // Keep that employee eligible for retry even if its state is already Publicado.
            retries.add(employeeId);
            failures.add(
              '${payload['employee_name']} · ID $employeeId · ${payload['empresa']}',
            );
          }
          progress.value = (index + 1, payload['employee_name'] as String);
        }
        if (mounted) await _loadData();
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        await progressDialog;
        progress.dispose();
      }
      if (!mounted) return;
      await _showPublicationMessage(
        failures.isEmpty
            ? 'Publicación completada'
            : 'Publicación con pendientes',
        failures.isEmpty
            ? '$published colaboradores publicados. El periodo sigue abierto; puedes cerrarlo cuando termines la revisión.'
            : '$published colaboradores publicados. No se pudo confirmar la publicación completa de ${failures.length}. '
                  'Revisa tu conexión y vuelve a pulsar Publicar todo para reintentar los pendientes.',
        details: failures,
      );
    } finally {
      if (mounted) setState(() => _publishingAll = false);
    }
  }

  Future<void> _showPublicationMessage(
    String title,
    String message, {
    List<String> details = const [],
  }) => showDialog<void>(
    context: context,
    builder: (_) => _PrenominaPublicationDialog(
      title: title,
      period: _activePeriodLabel,
      message: message,
      details: details,
    ),
  );

  Future<void> _closeActivePeriod() async {
    if (_updatingStatuses) return;
    if (_publicationRetries[_activePeriodLabel]?.isNotEmpty == true) {
      await _showPublicationMessage(
        'Publicación con pendientes',
        'Vuelve a pulsar Publicar todo para completar las publicaciones pendientes antes de cerrar el periodo.',
      );
      return;
    }
    if (_activePeriodLabel.trim().isEmpty) {
      await _showClosureMessage(
        'Selecciona un periodo en Prenómina antes de iniciar el cierre.',
      );
      return;
    }
    if (_isActivePeriodClosed) {
      await _showClosureMessage(
        'Este periodo ya está cerrado. Puedes consultar sus pagos y recibos en Nómina.',
      );
      return;
    }
    if (_periodRows.isEmpty) {
      await _showClosureMessage(
        'No hay colaboradores en este periodo. Revisa el periodo seleccionado y sus registros antes de cerrar.',
      );
      return;
    }
    if (!await _reviewClosureRequirements() || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar periodo de nómina'),
        content: Text(
          'Se congelará $_activePeriodLabel con $_activePublishedDraftCount '
          'colaborador(es) publicados. A partir de este momento solo se '
          'podrán registrar ajustes RH; Nómina podrá emitir los recibos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar periodo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final now = DateTime.now();
    final client = Supabase.instance.client;
    await client.from(_kHrPrenominaPeriodClosuresTable).upsert(
      <String, dynamic>{
        'period_label': _activePeriodLabel,
        'status': 'cerrado',
        'closed_at': now.toIso8601String(),
        'closed_by': client.auth.currentUser?.id,
        'notes': 'Cierre global confirmado desde Prenómina.',
        'summary_snapshot': <String, dynamic>{
          'period_label': _activePeriodLabel,
          'published_rows': _activePublishedDraftCount,
          'employees_expected': _periodRows.length,
          'closed_at': now.toIso8601String(),
        },
      },
      onConflict: 'period_label',
    );
    await _loadData();
    if (!mounted) return;
    _showSnack(
      'Periodo cerrado. Ya puedes continuar a Nómina y emitir recibos.',
    );
  }

  Future<void> _showClosureMessage(String message) => showDialog<void>(
    context: context,
    builder: (_) => _PrenominaClosureReviewDialog(
      period: _activePeriodLabel,
      issues: const [],
      message: message,
    ),
  );

  Future<bool> _reviewClosureRequirements() async {
    while (mounted) {
      final issues = _buildPrenominaClosureIssues(
        rows: _periodRows,
        drafts: _draftRows,
        period: _activePeriodLabel,
        checkLoans: _loanLoadError == null,
      );
      if (issues.isEmpty && _loanLoadError == null) return true;
      if (!mounted) return false;
      final selected = await showDialog<_PrenominaClosureIssue>(
        context: context,
        builder: (_) => _PrenominaClosureReviewDialog(
          period: _activePeriodLabel,
          issues: issues,
          message: _loanLoadError,
        ),
      );
      if (!mounted || selected == null) return false;
      final index = _periodRows.indexWhere(
        (row) => row.employeeId == selected.row.employeeId,
      );
      if (index < 0) continue;
      await _openSummaryRowAtIndex(
        index,
        entirePeriod: true,
        initialSection: selected.section,
      );
    }
    return false;
  }

  Future<void> _exportCashEnvelopeXlsx() async {
    if (_activePeriodLabel.trim().isEmpty) {
      _showSnack('Selecciona un periodo antes de exportar los sobres.');
      return;
    }
    final cashRows =
        _allRows
            .where((row) => row.cashEnvelopeAmount > 0)
            .toList(growable: false)
          ..sort((a, b) {
            final aInt = int.tryParse(a.employeeId);
            final bInt = int.tryParse(b.employeeId);
            if (aInt != null && bInt != null) return aInt.compareTo(bInt);
            return a.employeeId.compareTo(b.employeeId);
          });
    if (cashRows.isEmpty) {
      _showSnack(
        'No hay efectivo de sobre para exportar con los filtros actuales.',
      );
      return;
    }

    final bytes = buildSimpleXlsx(
      sheetName: 'Sobres efectivo',
      headers: const <String>['NO.', 'NOMBRE', 'TOTAL'],
      rows: cashRows
          .map(
            (row) => <String>[
              row.employeeId,
              row.displayName,
              row.cashEnvelopeAmount.toStringAsFixed(2),
            ],
          )
          .toList(growable: false),
    );
    final path = await _saveCashEnvelopeXlsx(bytes);
    if (!mounted || path == null) return;
    _showSnack('${cashRows.length} sobre(s) de efectivo exportados.');
  }

  Future<String?> _saveCashEnvelopeXlsx(Uint8List bytes) => saveBytesAs(
    bytes: bytes,
    suggestedFileName:
        'sobres_efectivo_${_prenominaFileSafeLabel(_activePeriodLabel)}.xlsx',
    dialogTitle: 'Guardar Excel de sobres de efectivo',
  );

  Future<void> _settleOperationalEventsForPublishedDraft({
    required SupabaseClient client,
    required String employeeId,
  }) async {
    if (_activePeriodLabel.trim().isEmpty) return;
    final settledAt = DateTime.now().toIso8601String();
    final impactSettlement = <String, dynamic>{
      'payroll_settlement_status': 'liquidado',
      'payroll_settled_at': settledAt,
      'prenomina_sync_status': 'aplicado',
    };
    final activeImpacts = _eventPeriodImpacts
        .where(
          (impact) =>
              impact.employeeId == employeeId &&
              impact.impactPrenomina &&
              !impact.isLiquidated &&
              impact.prenominaSyncStatus != 'omitido' &&
              impact.matchesPeriod(_activePeriodLabel),
        )
        .toList(growable: false);
    if (activeImpacts.isNotEmpty) {
      await client
          .from(hrEventPeriodImpactsTable)
          .update(impactSettlement)
          .inFilter('id', activeImpacts.map((impact) => impact.id).toList());
    }

    // Supports legacy events created before weekly impacts existed. New events
    // are settled above by their individual period impact only.
    final impactVacationIds = activeImpacts
        .where((impact) => impact.eventKind == 'vacacion')
        .map((impact) => impact.parentEventId)
        .toSet();
    final impactPermissionIds = activeImpacts
        .where((impact) => impact.eventKind == 'permiso')
        .map((impact) => impact.parentEventId)
        .toSet();
    final legacyVacationIds = _vacationEvents
        .where(
          (event) =>
              event.employeeId == employeeId &&
              event.impactPrenomina &&
              event.attendancePeriodLabel == _activePeriodLabel &&
              event.status != _HrPrenominaEventStatus.cancelado &&
              event.prenominaSyncStatus != _HrPrenominaSyncStatus.aplicado &&
              !impactVacationIds.contains(event.id),
        )
        .map((event) => event.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final legacyPermissionIds = _permissionEvents
        .where(
          (event) =>
              event.employeeId == employeeId &&
              event.impactPrenomina &&
              event.attendancePeriodLabel == _activePeriodLabel &&
              event.status != _HrPrenominaEventStatus.cancelado &&
              event.prenominaSyncStatus != _HrPrenominaSyncStatus.aplicado &&
              !impactPermissionIds.contains(event.id),
        )
        .map((event) => event.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final legacySettlement = <String, dynamic>{
      'payroll_period_label': _activePeriodLabel,
      'payroll_settlement_status': 'liquidado',
      'payroll_settled_at': settledAt,
      'prenomina_sync_status': 'aplicado',
    };

    if (legacyVacationIds.isNotEmpty) {
      await client
          .from(_kHrPrenominaVacationEventsTable)
          .update(legacySettlement)
          .inFilter('id', legacyVacationIds);
    }
    if (legacyPermissionIds.isNotEmpty) {
      await client
          .from(_kHrPrenominaPermissionEventsTable)
          .update(legacySettlement)
          .inFilter('id', legacyPermissionIds);
    }
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
    if (_navigationController.active.columnIndex ==
        _kPrenominaGridColumns.indexWhere((column) => column.id == 'estado')) {
      if (!_isActivePeriodClosed && !_updatingStatuses) {
        _statusMenuKey(
          _visibleRows[index].employeeId,
        ).currentState?.showButtonMenu();
      }
      return;
    }
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : _HrPrenominaWorkspace(
                          periodRows: _periodRows,
                          diagnostics: _attendanceDiagnostics,
                          search: _employeeSearch,
                          company: _companyFilter,
                          incidencesOnly: _incidencesOnly,
                          selectedStatuses:
                              _columnFilters['estado'] ?? const {},
                          hasFilters:
                              _columnFilters.isNotEmpty ||
                              _employeeSearch.isNotEmpty ||
                              _companyFilter != null ||
                              _incidencesOnly,
                          onSearch: (value) {
                            _employeeSearch = value;
                            _currentPage = 0;
                            _rebuildRows();
                          },
                          onCompany: (value) {
                            _companyFilter = value;
                            _currentPage = 0;
                            _rebuildRows();
                          },
                          onIncidences: (value) {
                            _incidencesOnly = value;
                            _currentPage = 0;
                            _rebuildRows();
                          },
                          onStatuses: (value) {
                            if (value.isEmpty) {
                              _columnFilters.remove('estado');
                            } else {
                              _columnFilters['estado'] = value;
                            }
                            _currentPage = 0;
                            _rebuildRows();
                          },
                          onClearFilters: () {
                            _columnFilters.clear();
                            _employeeSearch = '';
                            _companyFilter = null;
                            _incidencesOnly = false;
                            _currentPage = 0;
                            _rebuildRows();
                          },
                          allRows: _allRows,
                          rows: _visibleRows,
                          totalRows: _allRows.length,
                          selectedCount:
                              _selectionController.selectedIds.length,
                          activePeriodLabel: _activePeriodLabel,
                          periodOptions: _periodOptions,
                          isPeriodClosed: _isActivePeriodClosed,
                          publishedDraftCount: _activePublishedDraftCount,
                          pendingDraftCount: _activePendingDraftCount,
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
                          onChangeStatus: _changeRowStatus,
                          changingStatusEmployeeId: _changingStatusEmployeeId,
                          statusMenuKey: _statusMenuKey,
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
                          onClosePeriod: _closeActivePeriod,
                          onPublishAll: _updatingStatuses ? null : _publishAll,
                          onExportCashEnvelopes: _exportCashEnvelopeXlsx,
                          onSelectPeriod: _selectPeriod,
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
                openTerminations: _openTerminations,
                openLoans: _openLoans,
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

class _HrPrenominaHeaderBrand extends StatelessWidget {
  const _HrPrenominaHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}

enum _HrPrenominaEditAction { save, previous, next }

class _HrPrenominaEditResult {
  final _HrPrenominaEditAction action;
  final _HrPrenominaDraftDraft draft;

  const _HrPrenominaEditResult({required this.action, required this.draft});
}

class _HrPrenominaStatusBadge extends StatelessWidget {
  final String label;
  final bool interactive;
  final bool saving;

  const _HrPrenominaStatusBadge({
    required this.label,
    this.interactive = false,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorSet = _prenominaStatusBadgeColorSet(label);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: interactive ? 6 : 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colorSet.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorSet.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              saving ? 'Guardando' : label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: colorSet.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (interactive) ...[
            const SizedBox(width: 2),
            Icon(
              saving ? Icons.hourglass_top_rounded : Icons.expand_more_rounded,
              size: 16,
              color: colorSet.foreground,
            ),
          ],
        ],
      ),
    );
  }
}

class _HrPrenominaEmployeeMaster {
  final HrEmployeeCompensation compensation;
  final String employeeId;
  final String displayName;
  final String empresa;
  final double salaryWeekly;
  final double salaryPerceivedWeekly;
  final DateTime? fechaIngreso;
  final DateTime? fechaAlta;
  final String employmentStatus;
  final DateTime? terminationDate;

  const _HrPrenominaEmployeeMaster({
    required this.compensation,
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.salaryWeekly,
    required this.salaryPerceivedWeekly,
    required this.fechaIngreso,
    required this.fechaAlta,
    required this.employmentStatus,
    required this.terminationDate,
  });

  factory _HrPrenominaEmployeeMaster.fromRow(Map<String, dynamic> row) {
    final compensation = HrEmployeeCompensation.fromRow(row);
    return _HrPrenominaEmployeeMaster(
      compensation: compensation,
      employeeId: (row['id'] ?? '').toString(),
      displayName: (row['nombre'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      salaryWeekly: _parsePrenominaNumber(row['salario']),
      salaryPerceivedWeekly: row['salario_flujo'] != null
          ? compensation.total
          : _parsePrenominaNumber(row['salario_real_percibido']),
      fechaIngreso: _parsePrenominaDbDate(row['fecha_ingreso']),
      fechaAlta: _parsePrenominaDbDate(row['fecha_alta']),
      employmentStatus: (row['employment_status'] ?? kHrEmployeeStatusActive)
          .toString(),
      terminationDate: _parsePrenominaDbDate(row['termination_date']),
    );
  }

  bool belongsToPeriod(
    HumanResourcesPeriodRange? period, {
    required bool hasDraft,
  }) {
    // A later termination must not erase an earlier payroll. Saved period
    // records remain visible even when Personal no longer marks them active.
    if (hasDraft || employmentStatus != kHrEmployeeStatusTerminated) {
      return true;
    }
    if (period == null || terminationDate == null) return false;
    final start = fechaIngreso ?? fechaAlta;
    if (start != null && start.isAfter(period.end)) return false;
    // Preserve the existing exclusion for the termination period and later;
    // this change only restores complete periods preceding the effective baja.
    return terminationDate!.isAfter(period.end);
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
      lateMinutes: hrEligibleLateMinutes(_asPrenominaInt(row['late_minutes'])),
      overtimeMinutes: hrEligibleOvertimeMinutes(
        _asPrenominaInt(row['overtime_minutes']),
      ),
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
  final int exerciseYear;
  final String id;
  final String employeeId;
  final String attendancePeriodLabel;
  final String receiptGroupKey;
  final DateTime startDate;
  final DateTime endDate;
  final _HrPrenominaVacationEventType eventType;
  final _HrPrenominaEventStatus status;
  final double daysApplied;
  final double additionalPaidDays;
  final bool impactPrenomina;
  final _HrPrenominaSyncStatus prenominaSyncStatus;

  const _HrPrenominaVacationEventRecord({
    this.exerciseYear = 0,
    required this.id,
    required this.employeeId,
    required this.attendancePeriodLabel,
    required this.receiptGroupKey,
    required this.startDate,
    required this.endDate,
    required this.eventType,
    required this.status,
    required this.daysApplied,
    required this.additionalPaidDays,
    required this.impactPrenomina,
    required this.prenominaSyncStatus,
  });

  factory _HrPrenominaVacationEventRecord.fromRow(Map<String, dynamic> row) {
    return _HrPrenominaVacationEventRecord(
      exerciseYear:
          int.tryParse('${row['exercise_year']}') ??
          DateTime.tryParse('${row['start_date']}')?.year ??
          0,
      id: (row['id'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      attendancePeriodLabel: (row['attendance_period_label'] ?? '').toString(),
      receiptGroupKey: (row['receipt_group_key'] ?? '').toString(),
      startDate:
          DateTime.tryParse((row['start_date'] ?? '').toString()) ??
          DateTime(1970),
      endDate:
          DateTime.tryParse((row['end_date'] ?? '').toString()) ??
          DateTime(1970),
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
      additionalPaidDays: _parsePrenominaNumber(row['additional_paid_days']),
      impactPrenomina: row['impact_prenomina'] == true,
      prenominaSyncStatus: _HrPrenominaSyncStatus.values.firstWhere(
        (item) => item.name == (row['prenomina_sync_status'] ?? '').toString(),
        orElse: () => _HrPrenominaSyncStatus.pendiente,
      ),
    );
  }

  _HrPrenominaVacationEventRecord withDays(double days) =>
      _HrPrenominaVacationEventRecord(
        exerciseYear: exerciseYear,
        id: id,
        employeeId: employeeId,
        attendancePeriodLabel: attendancePeriodLabel,
        receiptGroupKey: receiptGroupKey,
        startDate: startDate,
        endDate: endDate,
        eventType: eventType,
        status: status,
        daysApplied: days,
        additionalPaidDays: additionalPaidDays,
        impactPrenomina: impactPrenomina,
        prenominaSyncStatus: prenominaSyncStatus,
      );

  bool get isContpaqImported =>
      receiptGroupKey.startsWith(_kHrPrenominaContpaqReceiptPrefix);

  _HrPrenominaVacationEventRecord forPeriodImpact(
    HrEventPeriodImpactRecord impact,
  ) {
    return _HrPrenominaVacationEventRecord(
      exerciseYear: exerciseYear,
      id: id,
      employeeId: employeeId,
      attendancePeriodLabel: impact.periodLabel,
      receiptGroupKey: receiptGroupKey,
      startDate: impact.periodStartDate,
      endDate: impact.periodEndDate,
      eventType: eventType,
      status: status,
      daysApplied: impact.daysApplied,
      additionalPaidDays: impact.additionalPaidDays,
      impactPrenomina: impactPrenomina,
      prenominaSyncStatus: _HrPrenominaSyncStatus.pendiente,
    );
  }
}

enum _HrPrenominaPermissionType {
  permisoConGoce,
  permisoSinGoce,
  incapacidad,
  ajusteRh,
}

enum _HrPrenominaPermissionUnit { dia, hora }

class _HrPrenominaPermissionEventRecord {
  final String id;
  final String employeeId;
  final String attendancePeriodLabel;
  final DateTime startDate;
  final DateTime endDate;
  final _HrPrenominaPermissionType permissionType;
  final _HrPrenominaPermissionUnit requestUnit;
  final _HrPrenominaEventStatus status;
  final double quantityDays;
  final double quantityHours;
  final bool impactPrenomina;
  final _HrPrenominaSyncStatus prenominaSyncStatus;

  const _HrPrenominaPermissionEventRecord({
    required this.id,
    required this.employeeId,
    required this.attendancePeriodLabel,
    required this.startDate,
    required this.endDate,
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
      id: (row['id'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      attendancePeriodLabel: (row['attendance_period_label'] ?? '').toString(),
      startDate:
          DateTime.tryParse((row['start_date'] ?? '').toString()) ??
          DateTime(1970),
      endDate:
          DateTime.tryParse((row['end_date'] ?? '').toString()) ??
          DateTime(1970),
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

  _HrPrenominaPermissionEventRecord forPeriodImpact(
    HrEventPeriodImpactRecord impact,
  ) {
    return _HrPrenominaPermissionEventRecord(
      id: id,
      employeeId: employeeId,
      attendancePeriodLabel: impact.periodLabel,
      startDate: impact.periodStartDate,
      endDate: impact.periodEndDate,
      permissionType: permissionType,
      requestUnit: requestUnit,
      status: status,
      quantityDays: impact.daysApplied,
      quantityHours: impact.quantityHours,
      impactPrenomina: impactPrenomina,
      prenominaSyncStatus: _HrPrenominaSyncStatus.pendiente,
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
  final Map<String, dynamic> sourceSnapshot;
  final String id;
  final String periodLabel;
  final String employeeId;
  final String employeeName;
  final String empresa;
  final _HrPrenominaDraftStatus draftStatus;
  final double manualAdjustmentAmount;
  final double? fiscalNetAmount;
  final double fiscalManualDeductionAmount;
  final String fiscalManualDeductionReason;
  final double? fiscalImssAmount;
  final double? fiscalInfonavitAmount;
  final double? fiscalFonacotAmount;
  final double? fiscalAbsenceAmount;
  final double? fiscalLateDeductionAmount;
  final double? fiscalVacationAmount;
  final double? cashSalaryAmount;
  final bool cashSalaryIsManual;
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
    this.sourceSnapshot = const {},
    required this.id,
    required this.periodLabel,
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.draftStatus,
    required this.manualAdjustmentAmount,
    required this.fiscalNetAmount,
    this.fiscalManualDeductionAmount = 0,
    this.fiscalManualDeductionReason = '',
    required this.fiscalImssAmount,
    required this.fiscalInfonavitAmount,
    required this.fiscalFonacotAmount,
    required this.fiscalAbsenceAmount,
    required this.fiscalLateDeductionAmount,
    required this.fiscalVacationAmount,
    required this.cashSalaryAmount,
    required this.cashSalaryIsManual,
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
    final snapshot = row['source_snapshot'] is Map
        ? Map<String, dynamic>.from(row['source_snapshot'] as Map)
        : <String, dynamic>{};
    final prepaid = HrPrepaidVacationDeduction.fromSnapshot(snapshot);
    return _HrPrenominaDraftRowRecord(
      sourceSnapshot: snapshot,
      id: (row['id'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      draftStatus: _draftStatusFromDb((row['draft_status'] ?? '').toString()),
      manualAdjustmentAmount: _parsePrenominaNumber(
        row['manual_adjustment_amount'],
      ),
      fiscalManualDeductionAmount: _parsePrenominaNumber(
        row['fiscal_manual_deduction_amount'],
      ),
      fiscalManualDeductionReason: (row['fiscal_manual_deduction_reason'] ?? '')
          .toString(),
      fiscalNetAmount: row['fiscal_net_amount'] == null
          ? null
          : _parsePrenominaNumber(row['fiscal_net_amount']) + prepaid.fiscal,
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
      fiscalLateDeductionAmount: _parsePrenominaNullableNumber(
        row['fiscal_late_deduction_amount'],
      ),
      fiscalVacationAmount: _parsePrenominaNullableNumber(
        row['fiscal_vacation_amount'],
      ),
      cashSalaryAmount: row['cash_salary_amount'] == null
          ? null
          : _parsePrenominaNumber(row['cash_salary_amount']) + prepaid.flow,
      cashSalaryIsManual: _parsePrenominaBoolean(row['cash_salary_is_manual']),
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

class _HrPrenominaPeriodClosure {
  final String id;
  final String periodLabel;
  final String status;
  final DateTime? closedAt;

  const _HrPrenominaPeriodClosure({
    required this.id,
    required this.periodLabel,
    required this.status,
    required this.closedAt,
  });

  bool get isClosed => status == 'cerrado';

  factory _HrPrenominaPeriodClosure.fromRow(Map<String, dynamic> row) {
    return _HrPrenominaPeriodClosure(
      id: (row['id'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      status: (row['status'] ?? '').toString(),
      closedAt: _parsePrenominaDbDate(row['closed_at']),
    );
  }
}

class _HrPrenominaSummaryRow {
  final HrPrepaidVacationDeduction prepaidVacation;
  final Map<String, dynamic> sourceSnapshot;
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
  final double vacationCalculatedAmount;
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
  final double fiscalManualDeductionAmount;
  final String fiscalManualDeductionReason;
  final double fiscalImssAmount;
  final double fiscalInfonavitAmount;
  final double fiscalFonacotAmount;
  final double fiscalAbsenceAmount;
  final double fiscalLateDeductionAmount;
  final double fiscalVacationAmount;
  final double cashSalaryAmount;
  final bool cashSalaryIsManual;
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
    this.prepaidVacation = const HrPrepaidVacationDeduction(),
    this.sourceSnapshot = const {},
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
    required this.vacationCalculatedAmount,
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
    this.fiscalManualDeductionAmount = 0,
    this.fiscalManualDeductionReason = '',
    required this.fiscalImssAmount,
    required this.fiscalInfonavitAmount,
    required this.fiscalFonacotAmount,
    required this.fiscalAbsenceAmount,
    required this.fiscalLateDeductionAmount,
    required this.fiscalVacationAmount,
    required this.cashSalaryAmount,
    required this.cashSalaryIsManual,
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
  double get fiscalHourlyRate => fiscalDailyRate / _kHrPrenominaHoursPerDay;
  double get calculatedCashSalaryAmount =>
      _parsePrenominaNumber(sourceSnapshot['personal_flow']);
  double get overtimeHourlyRate =>
      _parsePrenominaNumber(sourceSnapshot['personal_overtime_hourly_rate']);
  String get fiscalDeliveryLabel => fiscalCashAmount > 0
      ? (fiscalDepositedAmount > 0 ? 'Depósito + cheque' : 'Cheque · efectivo')
      : (sourceSnapshot['personal_fiscal_payment_mode'] == 'cheque' &&
                fiscalTotalAmount == 0
            ? 'Cheque · sin pago'
            : 'Depósito');
  double get perceivedDailyRate =>
      salaryPerceivedWeekly == 0 ? 0 : salaryPerceivedWeekly / 7;
  double get perceivedHourlyRate =>
      perceivedDailyRate == 0 ? 0 : perceivedDailyRate / 8;
  double get visibleDraftBaseAmount =>
      salaryPerceivedWeekly + manualAdjustmentAmount;
  double get preliminaryVacationPayAmount => vacationCalculatedAmount;
  double get preliminaryWithoutPayDeductionAmount =>
      (permissionWithoutPayDays * perceivedDailyRate) +
      (permissionWithoutPayHours * perceivedHourlyRate);
  double get preliminaryWithPayReferenceAmount =>
      (permissionWithPayDays * perceivedDailyRate) +
      (permissionWithPayHours * perceivedHourlyRate);
  double get preliminarySubtotalAmount =>
      visibleDraftBaseAmount +
      preliminaryVacationPayAmount -
      preliminaryWithoutPayDeductionAmount -
      prepaidVacation.total;
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
      (sourceSnapshot['incidences_informational'] == true
          ? 0
          : cashAbsenceDeductionAmount) +
      cashInfonavitDeductionAmount +
      cashFonacotDeductionAmount +
      loanDeductionAmount +
      prepaidVacation.flow;
  double get operationalCashTotalAmount =>
      operationalCashSubtotalAmount - operationalCashDeductionsTotalAmount;
  double get fiscalNetAfterLateDeductionAmount {
    final amount =
        fiscalNetAmount -
        (sourceSnapshot['incidences_informational'] == true
            ? 0
            : fiscalLateDeductionAmount) -
        prepaidVacation.fiscal;
    return amount < 0 ? 0 : amount;
  }

  double get fiscalBeforeManualDeductionAmount =>
      fiscalNetAfterLateDeductionAmount +
      (sourceSnapshot['contpaq_official_net'] != null
          ? 0
          : fiscalVacationAmount);
  double get fiscalTotalAmount =>
      (fiscalBeforeManualDeductionAmount - fiscalManualDeductionAmount)
          .clamp(0, double.infinity)
          .toDouble();
  double get fiscalCashAmount => checkAmount.clamp(0, fiscalTotalAmount);
  double get fiscalDepositedAmount {
    final amount = fiscalTotalAmount - fiscalCashAmount;
    return amount < 0 ? 0 : amount;
  }

  // Delivery includes fiscal paid by cheque; it does not change the salary
  // complement or the fiscal origin used by payroll, receipts and loans.
  double get flowDeliveryAmount =>
      weeklyPaymentVisibleAmount - fiscalDepositedAmount;

  // Export the same payable cash as the screen, including payment outside.
  // Use the displayed cents; zero or negative balances need no envelope.
  double get cashEnvelopeAmount =>
      math.max(0.0, double.parse(flowDeliveryAmount.toStringAsFixed(2)));

  double get weeklyPaymentVisibleAmount =>
      fiscalTotalAmount +
      paymentOutsideAmount +
      operationalCashTotalAmount +
      manualAdjustmentAmount;
  String get attendanceOperationalLabel =>
      attendanceReviewDays > 0 ? 'Pendiente RH' : 'Lista';
  String get statusLabel => _resolveSummaryStatus(this).label;
}

class _HrPrenominaDraftDraft {
  final HrPrepaidVacationDeduction prepaidVacation;
  final double perceivedWeekly;
  final Map<String, dynamic> sourceSnapshot;
  final String id;
  _HrPrenominaDraftStatus draftStatus;
  String manualAdjustmentAmountText;
  String fiscalNetAmountText;
  String fiscalManualDeductionAmountText;
  String fiscalManualDeductionReason;
  String fiscalImssAmountText;
  String fiscalInfonavitAmountText;
  String fiscalFonacotAmountText;
  String fiscalAbsenceAmountText;
  String fiscalLateDeductionAmountText;
  String fiscalVacationAmountText;
  String cashSalaryAmountText;
  bool cashSalaryIsManual;
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
    this.prepaidVacation = const HrPrepaidVacationDeduction(),
    this.perceivedWeekly = 0,
    this.sourceSnapshot = const {},
    required this.id,
    required this.draftStatus,
    required this.manualAdjustmentAmountText,
    required this.fiscalNetAmountText,
    this.fiscalManualDeductionAmountText = '',
    this.fiscalManualDeductionReason = '',
    required this.fiscalImssAmountText,
    required this.fiscalInfonavitAmountText,
    required this.fiscalFonacotAmountText,
    required this.fiscalAbsenceAmountText,
    required this.fiscalLateDeductionAmountText,
    required this.fiscalVacationAmountText,
    required this.cashSalaryAmountText,
    required this.cashSalaryIsManual,
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
      prepaidVacation: row.prepaidVacation,
      perceivedWeekly: row.salaryPerceivedWeekly,
      sourceSnapshot: Map<String, dynamic>.of(row.sourceSnapshot),
      id: row.draftId,
      draftStatus: row.draftStatus,
      manualAdjustmentAmountText: row.manualAdjustmentAmount == 0
          ? ''
          : row.manualAdjustmentAmount.toStringAsFixed(2),
      fiscalNetAmountText: _draftMoneyText(row.fiscalNetAmount),
      fiscalManualDeductionAmountText: _draftMoneyText(
        row.fiscalManualDeductionAmount,
      ),
      fiscalManualDeductionReason: row.fiscalManualDeductionReason,
      fiscalImssAmountText: _draftMoneyText(row.fiscalImssAmount),
      fiscalInfonavitAmountText: _draftMoneyText(row.fiscalInfonavitAmount),
      fiscalFonacotAmountText: _draftMoneyText(row.fiscalFonacotAmount),
      fiscalAbsenceAmountText: _draftMoneyText(row.fiscalAbsenceAmount),
      fiscalLateDeductionAmountText: _draftMoneyText(
        row.fiscalLateDeductionAmount,
      ),
      fiscalVacationAmountText: _draftMoneyText(row.fiscalVacationAmount),
      cashSalaryAmountText: row.cashSalaryAmount.toStringAsFixed(2),
      cashSalaryIsManual: row.cashSalaryIsManual,
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
      loanDeductionAmountText: _draftMoneyText(
        row.loanDeductionAmount -
            HrLoanPayrollPlan.fromSnapshot(row.sourceSnapshot).cents / 100,
      ),
      checkAmountText: row.checkAmount.toStringAsFixed(2),
      paymentOutsideAmountText: _draftMoneyText(row.paymentOutsideAmount),
      paymentChannel: row.paymentChannel,
      paymentReference: row.paymentReference,
      notes: row.notes,
    );
  }

  String? get firstInvalidMoneyFieldLabel {
    if (fiscalManualDeductionAmountText.trim().isNotEmpty) {
      final amount = _parsePrenominaDraftText(fiscalManualDeductionAmountText);
      if (amount == null ||
          !amount.isFinite ||
          ((amount * 100).roundToDouble() - amount * 100).abs() > .000001) {
        return 'Descuento fiscal manual';
      }
    }
    final fields = <(String, String)>[
      ('Neto fiscal', fiscalNetAmountText),
      ('Descuento fiscal manual', fiscalManualDeductionAmountText),
      ('IMSS fiscal', fiscalImssAmountText),
      ('INFONAVIT fiscal', fiscalInfonavitAmountText),
      ('FONACOT fiscal', fiscalFonacotAmountText),
      ('Faltas fiscales', fiscalAbsenceAmountText),
      ('Retardos fiscales', fiscalLateDeductionAmountText),
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

  String? validationMessage({required double fiscalAvailable}) {
    final invalidField = firstInvalidMoneyFieldLabel;
    if (invalidField != null) {
      return 'Revisa "$invalidField". Captura un monto válido, por ejemplo 1250.50.';
    }
    final manual =
        _parsePrenominaDraftText(fiscalManualDeductionAmountText) ?? 0;
    if (manual < 0 || manual > fiscalAvailable + .001) {
      return 'El descuento fiscal manual debe estar entre cero y el fiscal disponible (${_formatPrenominaMoneyZero(fiscalAvailable)}).';
    }
    if (manual > 0 && fiscalManualDeductionReason.trim().isEmpty) {
      return 'Indica el motivo del descuento fiscal manual.';
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
    final fiscal = sourceSnapshot['contpaq_official_net'] != null
        ? _parsePrenominaNumber(sourceSnapshot['contpaq_official_net'])
        : _parsePrenominaDraftText(fiscalNetAmountText);
    final flow = _parsePrenominaDraftText(cashSalaryAmountText) ?? 0.0;
    final calculatedSettlement = HrPrepaidVacationDeduction.calculate(
      days: prepaidVacation.days,
      perceivedWeekly: perceivedWeekly,
      fiscalAvailable: (fiscal ?? 0).clamp(0, double.infinity).toDouble(),
      flowAvailable: flow,
    );
    // Prepaid vacation settles salary already paid, independently of the
    // informational attendance deductions included in CONTPAQ's net.
    final settlement = calculatedSettlement;
    final fiscalManual =
        _parsePrenominaDraftText(fiscalManualDeductionAmountText) ?? 0;
    final fiscalBeforeManual =
        ((fiscal ?? 0) - settlement.fiscal).clamp(0, double.infinity) +
        (sourceSnapshot['contpaq_official_net'] != null
            ? 0
            : (_parsePrenominaDraftText(fiscalVacationAmountText) ?? 0));
    final payableFiscal = (fiscalBeforeManual - fiscalManual).clamp(
      0,
      double.infinity,
    );
    final fiscalInCash = sourceSnapshot['fiscal_payment_is_manual'] == false
        ? (sourceSnapshot['personal_fiscal_payment_mode'] == 'cheque'
              ? payableFiscal
              : 0.0)
        : (_parsePrenominaDraftText(checkAmountText) ?? 0).clamp(
            0,
            payableFiscal,
          );
    final manualLoan = _parsePrenominaDraftText(loanDeductionAmountText) ?? 0;
    final availableForLoan =
        flow -
        settlement.flow +
        (_parsePrenominaDraftText(cashVacationAmountText) ?? 0) +
        (_parsePrenominaDraftText(transportSupportAmountText) ?? 0) +
        (_parsePrenominaDraftText(holidayAmountText) ?? 0) +
        (_parsePrenominaDraftText(overtimeMonetizedAmountText) ?? 0) +
        (_parsePrenominaDraftText(manualBonusAmountText) ?? 0) +
        (_parsePrenominaDraftText(manualAdjustmentAmountText) ?? 0) -
        (_parsePrenominaDraftText(cashIsrAmountText) ?? 0) -
        (_parsePrenominaDraftText(cashInfonavitDeductionAmountText) ?? 0) -
        (_parsePrenominaDraftText(cashFonacotDeductionAmountText) ?? 0) -
        (sourceSnapshot['incidences_informational'] == true
            ? 0
            : (_parsePrenominaDraftText(cashAbsenceDeductionAmountText) ?? 0)) -
        manualLoan;
    final loanPlan = HrLoanPayrollPlan.fromSnapshot(
      sourceSnapshot,
    ).limitedTo(hrLoanCents(availableForLoan));
    return {
      if (existingId.trim().isNotEmpty) 'id': existingId,
      'period_label': periodLabel,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'empresa': empresa,
      'draft_status': _draftStatusToDb(draftStatus),
      'manual_adjustment_amount':
          _parsePrenominaDraftText(manualAdjustmentAmountText) ?? 0.0,
      'fiscal_net_amount': fiscal == null ? null : fiscal - settlement.fiscal,
      'fiscal_manual_deduction_amount': fiscalManual,
      'fiscal_manual_deduction_reason': fiscalManualDeductionReason.trim(),
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
      'fiscal_late_deduction_amount': _parsePrenominaDraftText(
        fiscalLateDeductionAmountText,
      ),
      'fiscal_vacation_amount': _parsePrenominaDraftText(
        fiscalVacationAmountText,
      ),
      'cash_salary_amount': flow - settlement.flow,
      'cash_salary_is_manual': cashSalaryIsManual,
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
      'loan_deduction_amount': manualLoan + loanPlan.cents / 100,
      'check_amount': fiscalInCash,
      'payment_outside_amount': _parsePrenominaDraftText(
        paymentOutsideAmountText,
      ),
      'payment_channel': paymentChannel.name,
      'payment_reference': paymentReference.trim(),
      'notes': notes.trim(),
      'source_snapshot': <String, dynamic>{
        ...sourceSnapshot,
        if (loanPlan.end != null) 'loan_fund': loanPlan.toJson(),
        if (settlement.days > 0 ||
            sourceSnapshot.containsKey('prepaid_vacation'))
          'prepaid_vacation': settlement.toJson(),
      },
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
      _HrPrenominaGridColumn(id: 'fiscal', label: 'Depósito fiscal'),
      _HrPrenominaGridColumn(id: 'flujo', label: 'Flujo a entregar'),
      _HrPrenominaGridColumn(id: 'total', label: 'Total'),
      _HrPrenominaGridColumn(id: 'estado', label: 'Estado'),
      _HrPrenominaGridColumn(id: 'acciones', label: 'Acciones'),
    ];

class _HrPrenominaGridColumn {
  final String id;
  final String label;

  const _HrPrenominaGridColumn({required this.id, required this.label});
}

/// Backfills weekly impacts for pending events created before this model was
/// introduced. Applied legacy events are deliberately left untouched.
Future<void> _syncPrenominaPendingEventImpacts({
  required SupabaseClient client,
  required List<_HrPrenominaVacationEventRecord> vacationEvents,
  required List<_HrPrenominaPermissionEventRecord> permissionEvents,
  required Iterable<String> knownPeriodLabels,
  required String activePeriodLabel,
}) async {
  await syncHrEventPeriodImpacts(
    client: client,
    eventKind: 'vacacion',
    sources: vacationEvents
        .where(
          (event) =>
              event.id.isNotEmpty &&
              event.startDate.year > 1970 &&
              event.prenominaSyncStatus != _HrPrenominaSyncStatus.aplicado,
        )
        .map(
          (event) => HrEventPeriodImpactSource(
            eventId: event.id,
            employeeId: event.employeeId,
            startDate:
                event.eventType ==
                    _HrPrenominaVacationEventType.vacacionesPagadas
                ? (HumanResourcesPeriodRange.tryParse(
                        event.attendancePeriodLabel,
                      )?.start ??
                      event.startDate)
                : event.startDate,
            endDate:
                event.eventType ==
                    _HrPrenominaVacationEventType.vacacionesPagadas
                ? (HumanResourcesPeriodRange.tryParse(
                        event.attendancePeriodLabel,
                      )?.start ??
                      event.startDate)
                : event.endDate,
            daysApplied: event.daysApplied,
            additionalPaidDays: event.additionalPaidDays,
            quantityHours: 0,
            impactAttendance: false,
            impactPrenomina: event.impactPrenomina,
            isCancelled: event.status == _HrPrenominaEventStatus.cancelado,
          ),
        )
        .toList(growable: false),
    knownPeriodLabels: knownPeriodLabels,
    activePeriodLabel: activePeriodLabel,
  );
  await syncHrEventPeriodImpacts(
    client: client,
    eventKind: 'permiso',
    sources: permissionEvents
        .where(
          (event) =>
              event.id.isNotEmpty &&
              event.startDate.year > 1970 &&
              event.prenominaSyncStatus != _HrPrenominaSyncStatus.aplicado,
        )
        .map(
          (event) => HrEventPeriodImpactSource(
            eventId: event.id,
            employeeId: event.employeeId,
            startDate: event.startDate,
            endDate: event.endDate,
            daysApplied: event.quantityDays,
            additionalPaidDays: 0,
            quantityHours: event.quantityHours,
            impactAttendance: false,
            impactPrenomina: event.impactPrenomina,
            isCancelled: event.status == _HrPrenominaEventStatus.cancelado,
          ),
        )
        .toList(growable: false),
    knownPeriodLabels: knownPeriodLabels,
    activePeriodLabel: activePeriodLabel,
  );
}

List<String> _prenominaPeriodOptions({
  required List<_HrPrenominaImportLotLite> lots,
  required List<_HrPrenominaAttendanceRecord> attendanceRecords,
  required List<_HrPrenominaVacationEventRecord> vacationEvents,
  required List<_HrPrenominaPermissionEventRecord> permissionEvents,
  required List<HrEventPeriodImpactRecord> eventPeriodImpacts,
  required List<_HrPrenominaDraftRowRecord> drafts,
  required List<_HrPrenominaPeriodClosure> closures,
}) {
  return HumanResourcesPeriodContext.normalizedOptions([
    for (final record in attendanceRecords) record.periodLabel,
    for (final event in vacationEvents) event.attendancePeriodLabel,
    for (final event in permissionEvents) event.attendancePeriodLabel,
    for (final impact in eventPeriodImpacts) impact.periodLabel,
    for (final draft in drafts) draft.periodLabel,
    for (final closure in closures) closure.periodLabel,
  ]);
}

_HrPrenominaImportLotLite? _prenominaLotForPeriod(
  List<_HrPrenominaImportLotLite> lots,
  _HrPrenominaImportSource source,
  String selectedPeriodLabel,
) {
  if (selectedPeriodLabel.trim().isEmpty) return null;
  for (final lot in lots) {
    if (lot.source != source) continue;
    if (_prenominaLotMatchesPeriod(lot, selectedPeriodLabel)) return lot;
  }
  return null;
}

bool _prenominaLotMatchesPeriod(
  _HrPrenominaImportLotLite lot,
  String selectedPeriodLabel,
) {
  final described = _describePrenominaImportPeriod(lot);
  if (described == selectedPeriodLabel) return true;
  final selectedRange = _extractPrenominaDateRangeFromPeriodLabel(
    selectedPeriodLabel,
  );
  final lotRange = _extractPrenominaDateRangeFromPeriodLabel(described);
  return selectedRange != null &&
      lotRange != null &&
      selectedRange.start == lotRange.start &&
      selectedRange.end == lotRange.end;
}

List<_HrPrenominaSummaryRow> _buildPrenominaSummaryRows({
  HrLoanFundState? loanFund,
  bool freezeLoanPlans = false,
  required List<_HrPrenominaEmployeeMaster> employees,
  required _HrPrenominaImportLotLite? contpaqLot,
  required List<_HrPrenominaAttendanceRecord> attendanceRecords,
  required List<_HrPrenominaVacationEventRecord> vacationEvents,
  required List<_HrPrenominaPermissionEventRecord> permissionEvents,
  required List<HrEventPeriodImpactRecord> eventPeriodImpacts,
  required List<_HrPrenominaDraftRowRecord> draftRows,
  required String activePeriodLabel,
  required String activeContpaqRawPeriodLabel,
}) {
  final activeRange = HumanResourcesPeriodRange.tryParse(activePeriodLabel);
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

  final activeImpacts = eventPeriodImpacts
      .where(
        (impact) =>
            impact.impactPrenomina &&
            !impact.isLiquidated &&
            impact.prenominaSyncStatus != 'aplicado' &&
            impact.matchesPeriod(activePeriodLabel),
      )
      .toList(growable: false);
  final vacationImpactsByEvent = <String, List<HrEventPeriodImpactRecord>>{};
  final permissionImpactsByEvent = <String, List<HrEventPeriodImpactRecord>>{};
  for (final impact in activeImpacts) {
    final target = impact.eventKind == 'vacacion'
        ? vacationImpactsByEvent
        : permissionImpactsByEvent;
    target.putIfAbsent(impact.parentEventId, () => []).add(impact);
  }

  // The same period allocation drives visible enjoyment and salary settlement.
  // Applied sync status does not erase enjoyment from its original period.
  final enjoymentDaysByEvent = <String, double>{};
  final vacationsByEmployee = <String, List<_HrPrenominaVacationEventRecord>>{};
  for (final event in vacationEvents.where(
    (item) =>
        item.impactPrenomina &&
        item.status != _HrPrenominaEventStatus.cancelado,
  )) {
    if (event.eventType ==
        _HrPrenominaVacationEventType.vacacionesDisfrutadas) {
      if (activeRange == null ||
          event.endDate.isBefore(activeRange.start) ||
          event.startDate.isAfter(activeRange.end)) {
        continue;
      }
      final allocations = eventPeriodImpacts.where(
        (impact) =>
            impact.eventKind == 'vacacion' && impact.parentEventId == event.id,
      );
      if (allocations.isNotEmpty) {
        if (!allocations.any(
          (impact) =>
              impact.impactPrenomina &&
              impact.matchesPeriod(activePeriodLabel) &&
              impact.daysApplied > 0,
        )) {
          continue;
        }
      } else {
        final assigned = HumanResourcesPeriodRange.tryParse(
          event.attendancePeriodLabel,
        );
        final matches =
            event.attendancePeriodLabel.isEmpty ||
            event.attendancePeriodLabel == activePeriodLabel ||
            (assigned?.start == activeRange.start &&
                assigned?.end == activeRange.end);
        if (!matches) continue;
      }
      final start = event.startDate.isBefore(activeRange.start)
          ? activeRange.start
          : event.startDate;
      final end = event.endDate.isAfter(activeRange.end)
          ? activeRange.end
          : event.endDate;
      // Period allocations identify membership; their historical proportional
      // bank-day amounts are not salary days. Use the actual absence dates.
      final days = event.daysApplied > 0
          ? (end.difference(start).inDays + 1).toDouble()
          : 0.0;
      if (days <= 0) continue;
      if (event.status == _HrPrenominaEventStatus.aplicado) {
        enjoymentDaysByEvent[event.id] = days;
      }
      vacationsByEmployee
          .putIfAbsent(event.employeeId, () => [])
          .add(event.withDays(days));
      continue;
    }
    final impacts = vacationImpactsByEvent[event.id];
    if (impacts != null) {
      for (final impact in impacts) {
        vacationsByEmployee
            .putIfAbsent(
              event.employeeId,
              () => <_HrPrenominaVacationEventRecord>[],
            )
            .add(event.forPeriodImpact(impact));
      }
      continue;
    }
    if (event.prenominaSyncStatus != _HrPrenominaSyncStatus.aplicado &&
        (event.attendancePeriodLabel == activePeriodLabel ||
            (activeContpaqRawPeriodLabel.isNotEmpty &&
                event.receiptGroupKey.contains(activeContpaqRawPeriodLabel)))) {
      vacationsByEmployee
          .putIfAbsent(
            event.employeeId,
            () => <_HrPrenominaVacationEventRecord>[],
          )
          .add(event);
    }
  }

  final prepaidByEvent = activeRange == null
      ? <String, double>{}
      : hrPrepaidVacationDays(
          eligibleDaysByEvent: enjoymentDaysByEvent,
          periodStart: activeRange.start,
          periodEnd: activeRange.end,
          events: [
            for (final e in vacationEvents)
              {
                'id': e.id,
                'employee_id': e.employeeId,
                'exercise_year': e.exerciseYear,
                'event_type': switch (e.eventType) {
                  _HrPrenominaVacationEventType.vacacionesPagadas =>
                    'vacaciones_pagadas',
                  _HrPrenominaVacationEventType.vacacionesDisfrutadas =>
                    'vacaciones_disfrutadas',
                  _ => '',
                },
                'status': e.status.name,
                'days_applied': e.daysApplied,
                'start_date': e.startDate.toIso8601String(),
                'end_date': e.endDate.toIso8601String(),
              },
          ],
        );

  final permissionsByEmployee =
      <String, List<_HrPrenominaPermissionEventRecord>>{};
  for (final event in permissionEvents.where(
    (item) =>
        item.impactPrenomina &&
        item.status != _HrPrenominaEventStatus.cancelado,
  )) {
    final impacts = permissionImpactsByEvent[event.id];
    if (impacts != null) {
      for (final impact in impacts) {
        permissionsByEmployee
            .putIfAbsent(
              event.employeeId,
              () => <_HrPrenominaPermissionEventRecord>[],
            )
            .add(event.forPeriodImpact(impact));
      }
      continue;
    }
    if (event.prenominaSyncStatus != _HrPrenominaSyncStatus.aplicado &&
        event.attendancePeriodLabel == activePeriodLabel) {
      permissionsByEmployee
          .putIfAbsent(
            event.employeeId,
            () => <_HrPrenominaPermissionEventRecord>[],
          )
          .add(event);
    }
  }

  final contpaqByEmployee = {
    for (final entry
        in contpaqLot?.entries ?? const <_HrPrenominaImportedEntry>[])
      entry.employeeId: entry,
  };

  return employees
      .where(
        (employee) => employee.belongsToPeriod(
          activeRange,
          hasDraft: draftByEmployee.containsKey(employee.employeeId),
        ),
      )
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
          (sum, item) => sum + hrEligibleLateMinutes(item.lateMinutes),
        );
        final overtimeMinutesSum = attendance.fold<int>(
          0,
          (sum, item) => sum + hrEligibleOvertimeMinutes(item.overtimeMinutes),
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
        final vacationCalculatedAmount = vacations
            .where(
              (event) =>
                  event.status == _HrPrenominaEventStatus.aplicado &&
                  event.eventType ==
                      _HrPrenominaVacationEventType.vacacionesPagadas,
            )
            .fold<double>(
              0,
              (sum, event) =>
                  sum +
                  _calculatePrenominaVacationAmount(
                    event: event,
                    prepaidDays: prepaidByEvent[event.id] ?? 0,
                    perceivedDailyRate: employee.salaryPerceivedWeekly > 0
                        ? employee.salaryPerceivedWeekly / 7
                        : 0,
                  ),
            );

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
        final isPublished =
            draft?.draftStatus == _HrPrenominaDraftStatus.publicado;
        final officialNet = isPublished
            ? null
            : contpaq != null
            ? contpaqNetAmount
            : draft?.sourceSnapshot['contpaq_official_net'];
        final fiscalNetAmount = officialNet != null
            ? _parsePrenominaNumber(officialNet)
            : draft?.fiscalNetAmount ?? contpaqNetAmount;
        final fiscalImssAmount = draft?.fiscalImssAmount ?? contpaqImssAmount;
        final fiscalInfonavitAmount =
            draft?.fiscalInfonavitAmount ?? contpaqInfonavitAmount;
        final fiscalFonacotAmount =
            draft?.fiscalFonacotAmount ?? contpaqFonacotAmount;
        final fiscalAbsenceAmount =
            draft?.fiscalAbsenceAmount ?? contpaqAbsenceAmount;
        final fiscalLateDeductionAmount =
            draft?.fiscalLateDeductionAmount ??
            _calculatePrenominaFiscalLateDeduction(
              salaryWeekly: employee.salaryWeekly,
              lateMinutes: lateMinutesSum,
            );
        final prepaidDays =
            draft?.draftStatus == _HrPrenominaDraftStatus.publicado
            ? 0.0
            : vacationEvents
                  .where((e) => e.employeeId == employee.employeeId)
                  .fold<double>(
                    0,
                    (sum, e) => sum + (prepaidByEvent[e.id] ?? 0),
                  );
        final fiscalVacationAmount =
            prepaidDays > 0 && contpaqVacationAmount <= 0
            ? _suggestPrenominaFiscalVacationAmount(
                vacationCalculatedAmount: vacationCalculatedAmount,
                fiscalWeeklyAmount: employee.salaryWeekly,
                perceivedWeeklyAmount: employee.salaryPerceivedWeekly,
              )
            : draft?.fiscalVacationAmount ??
                  (contpaqVacationAmount > 0
                      ? contpaqVacationAmount
                      : _suggestPrenominaFiscalVacationAmount(
                          vacationCalculatedAmount: vacationCalculatedAmount,
                          fiscalWeeklyAmount: contpaqSalaryAmount > 0
                              ? contpaqSalaryAmount
                              : employee.salaryWeekly,
                          perceivedWeeklyAmount: employee.salaryPerceivedWeekly,
                        ));
        final suggestedCashSalaryAmount = employee.compensation.flow;
        final suggestedCashVacationAmount = _suggestPrenominaCashVacationAmount(
          vacationCalculatedAmount: vacationCalculatedAmount,
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
              overtimeMinutes: overtimeMinutesSum,
              hourlyRate: employee.compensation.overtimeHourlyRate,
            );
        final cashSalaryIsManual = draft?.cashSalaryIsManual ?? false;
        final cashSalaryAmount =
            (cashSalaryIsManual ||
                draft?.draftStatus == _HrPrenominaDraftStatus.publicado)
            ? (draft?.cashSalaryAmount ??
                  (cashSalaryIsManual ? 0 : suggestedCashSalaryAmount))
            : suggestedCashSalaryAmount;
        final calculatedPrepaidVacation =
            draft?.draftStatus == _HrPrenominaDraftStatus.publicado
            ? HrPrepaidVacationDeduction.fromSnapshot(draft!.sourceSnapshot)
            : HrPrepaidVacationDeduction.calculate(
                days: prepaidDays,
                perceivedWeekly: employee.salaryPerceivedWeekly,
                fiscalAvailable: fiscalNetAmount
                    .clamp(0, double.infinity)
                    .toDouble(),
                flowAvailable: cashSalaryAmount,
              );
        final prepaidVacation = calculatedPrepaidVacation;
        final cashVacationAmount = prepaidDays > 0
            ? suggestedCashVacationAmount
            : draft?.cashVacationAmount ?? suggestedCashVacationAmount;
        final cashIsrAmount = draft?.cashIsrAmount ?? 0;
        final transportSupportAmount = draft?.transportSupportAmount ?? 0;
        final holidayAmount = draft?.holidayAmount ?? 0;
        final overtimeIsManual =
            draft?.sourceSnapshot['overtime_is_manual'] == true ||
            (draft != null &&
                !draft.sourceSnapshot.containsKey('overtime_is_manual') &&
                draft.overtimeMonetizedAmount != null);
        final overtimeMonetizedAmount = (isPublished || overtimeIsManual)
            ? (draft?.overtimeMonetizedAmount ?? 0)
            : suggestedOvertimeMonetizedAmount;
        final manualBonusAmount = draft?.manualBonusAmount ?? 0;
        final cashAbsenceDeductionAmount =
            draft?.cashAbsenceDeductionAmount ??
            suggestedCashAbsenceDeductionAmount;
        final cashInfonavitDeductionAmount =
            draft?.cashInfonavitDeductionAmount ?? 0;
        final cashFonacotDeductionAmount =
            draft?.cashFonacotDeductionAmount ?? 0;
        final savedLoanPlan = HrLoanPayrollPlan.fromSnapshot(
          draft?.sourceSnapshot ?? const {},
        );
        final manualLoan = math.max(
          0.0,
          (draft?.loanDeductionAmount ?? 0) - savedLoanPlan.cents / 100,
        );
        final loanCapacity =
            cashSalaryAmount -
            prepaidVacation.flow +
            cashVacationAmount +
            transportSupportAmount +
            holidayAmount +
            overtimeMonetizedAmount +
            manualBonusAmount +
            (draft?.manualAdjustmentAmount ?? 0) -
            cashIsrAmount -
            cashInfonavitDeductionAmount -
            cashFonacotDeductionAmount -
            manualLoan -
            (isPublished &&
                    draft?.sourceSnapshot['incidences_informational'] != true
                ? cashAbsenceDeductionAmount
                : 0);
        final loanPlan =
            !freezeLoanPlans && loanFund != null && activeRange != null
            ? loanFund.payrollPlan(
                employee.employeeId,
                activeRange.end,
                flowAvailableCents: hrLoanCents(loanCapacity),
                fiscalReady:
                    officialNet != null ||
                    draft?.sourceSnapshot['contpaq_official_net'] != null,
              )
            : savedLoanPlan;
        final loanDeductionAmount = manualLoan + loanPlan.cents / 100;
        final fiscalPaymentIsManual = HrFiscalPayment.isManual(
          draft?.sourceSnapshot ?? const {},
          draft?.checkAmount,
        );
        final fiscalManualDeductionAmount =
            draft?.fiscalManualDeductionAmount ?? 0;
        final fiscalBeforeManual =
            (fiscalNetAmount - (isPublished ? 0 : prepaidVacation.fiscal))
                .clamp(0, double.infinity) +
            (officialNet != null ||
                    draft?.sourceSnapshot['contpaq_official_net'] != null
                ? 0
                : fiscalVacationAmount);
        final payableFiscal = (fiscalBeforeManual - fiscalManualDeductionAmount)
            .clamp(0, double.infinity);
        final checkAmount = HrFiscalPayment.resolve(
          total: payableFiscal.toDouble(),
          storedCheque: draft?.checkAmount,
          snapshot: draft?.sourceSnapshot ?? const {},
          personalMode: employee.compensation.fiscalByCheck
              ? 'cheque'
              : 'deposito',
          frozen: isPublished,
        ).cheque;
        final paymentOutsideAmount = draft?.paymentOutsideAmount ?? 0;
        final paymentChannel =
            (isPublished || fiscalPaymentIsManual) &&
                draft?.paymentChannel.trim().isNotEmpty == true
            ? _paymentChannelFromDb(draft!.paymentChannel)
            : _suggestPrenominaPaymentChannel(
                fiscalNetAmount: payableFiscal.toDouble(),
                cashSalaryAmount:
                    (cashSalaryAmount -
                            (isPublished ? 0 : prepaidVacation.flow))
                        .clamp(0, double.infinity)
                        .toDouble(),
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
          vacationCalculatedAmount: vacationCalculatedAmount,
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
          prepaidVacation: prepaidVacation,
          sourceSnapshot: {
            ...?draft?.sourceSnapshot,
            if (loanPlan.end != null) 'loan_fund': loanPlan.toJson(),
            if (!isPublished) ...{
              'incidences_informational': true,
              'personal_flow': employee.compensation.flow,
              'personal_overtime_hourly_rate':
                  employee.compensation.overtimeHourlyRate,
              'personal_fiscal_payment_mode':
                  employee.compensation.fiscalByCheck ? 'cheque' : 'deposito',
              'overtime_is_manual': overtimeIsManual,
              'fiscal_payment_is_manual': fiscalPaymentIsManual,
            },
            'contpaq_official_net': ?officialNet,
            'attendance_absence_reference': _roundPrenominaMoney(
              attendance
                      .where(
                        (r) => r.status == _HrPrenominaAttendanceStatus.falto,
                      )
                      .length *
                  employee.salaryWeekly /
                  7,
            ),
            'attendance_late_reference': _calculatePrenominaFiscalLateDeduction(
              salaryWeekly: employee.salaryWeekly,
              lateMinutes: lateMinutesSum,
            ),
            'permission_reference': _roundPrenominaMoney(
              employee.salaryWeekly /
                  7 *
                  (permissionWithoutPayDays +
                      permissionWithoutPayHours / _kHrPrenominaHoursPerDay),
            ),
          },
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
          fiscalManualDeductionAmount: fiscalManualDeductionAmount,
          fiscalManualDeductionReason: draft?.fiscalManualDeductionReason ?? '',
          fiscalImssAmount: fiscalImssAmount,
          fiscalInfonavitAmount: fiscalInfonavitAmount,
          fiscalFonacotAmount: fiscalFonacotAmount,
          fiscalAbsenceAmount: fiscalAbsenceAmount,
          fiscalLateDeductionAmount: fiscalLateDeductionAmount,
          fiscalVacationAmount: fiscalVacationAmount,
          cashSalaryAmount: cashSalaryAmount,
          cashSalaryIsManual: cashSalaryIsManual,
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

double _suggestPrenominaCashVacationAmount({
  required double vacationCalculatedAmount,
  required double fiscalVacationAmount,
}) {
  if (vacationCalculatedAmount <= 0) return 0;
  final amount = vacationCalculatedAmount - fiscalVacationAmount;
  return amount > 0 ? amount : 0;
}

double _suggestPrenominaFiscalVacationAmount({
  required double vacationCalculatedAmount,
  required double fiscalWeeklyAmount,
  required double perceivedWeeklyAmount,
}) {
  if (vacationCalculatedAmount <= 0) return 0;
  if (perceivedWeeklyAmount <= 0 || fiscalWeeklyAmount <= 0) {
    return vacationCalculatedAmount;
  }
  final fiscalShare = (fiscalWeeklyAmount / perceivedWeeklyAmount)
      .clamp(0, 1)
      .toDouble();
  return vacationCalculatedAmount * fiscalShare;
}

double _calculatePrenominaVacationAmount({
  required _HrPrenominaVacationEventRecord event,
  required double perceivedDailyRate,
  double prepaidDays = 0,
}) {
  if (perceivedDailyRate <= 0 || event.daysApplied <= 0) return 0;
  return HrVacationPay(
    perceivedWeekly: perceivedDailyRate * 7,
    fiscalWeekly: 0,
    vacationDays: (event.daysApplied - prepaidDays)
        .clamp(0, event.daysApplied)
        .toDouble(),
    additionalPaidDays: prepaidDays >= event.daysApplied
        ? 0
        : event.additionalPaidDays,
  ).total;
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
  required int overtimeMinutes,
  required double hourlyRate,
}) {
  if (overtimeMinutes <= 0) return 0;
  return _roundPrenominaMoney((overtimeMinutes / 60) * hourlyRate);
}

double _calculatePrenominaFiscalLateDeduction({
  required double salaryWeekly,
  required int lateMinutes,
}) {
  if (salaryWeekly <= 0 || lateMinutes <= 0) return 0;
  final baseHourlyRate = salaryWeekly / 7 / _kHrPrenominaHoursPerDay;
  return _roundPrenominaMoney(baseHourlyRate * (lateMinutes / 60));
}

double _roundPrenominaMoney(double value) =>
    double.parse(value.toStringAsFixed(2));

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
  final hasFiscal =
      fiscalNetAmount -
          checkAmount.clamp(0, fiscalNetAmount.clamp(0, double.infinity)) >
      0;
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
  if (hasCheck) {
    return hasCash || hasOutside
        ? _HrPrenominaPaymentChannel.mixto
        : _HrPrenominaPaymentChannel.cheque;
  }
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

bool _parsePrenominaBoolean(Object? raw) {
  if (raw is bool) return raw;
  return raw?.toString().trim().toLowerCase() == 'true';
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

String _prenominaFileSafeLabel(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'periodo' : normalized;
}

String _describePrenominaImportPeriod(_HrPrenominaImportLotLite lot) {
  final raw = lot.periodLabel.trim();
  if (RegExp(r'^Periodo\s+\d+\s+semanal\s+·').hasMatch(raw)) return raw;
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
    return 'Periodo $week semanal · $start - $end';
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

DateTimeRange? _extractPrenominaDateRangeFromPeriodLabel(String raw) {
  final match = RegExp(
    r'(?:del\s+)?(\d{2}/\d{2}/\d{4})\s+(?:al|-)\s+(\d{2}/\d{2}/\d{4})',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final start = _parsePrenominaDayFirstDate(match.group(1)!);
  final end = _parsePrenominaDayFirstDate(match.group(2)!);
  if (start == null || end == null) return null;
  return DateTimeRange(start: start, end: end);
}

DateTime? _parsePrenominaDayFirstDate(String raw) {
  final parts = raw.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
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
  final colors = humanResourcesPayrollStatusColors(label);
  return _HrPrenominaPillColorSet(
    background: colors.background,
    border: colors.border,
    foreground: colors.foreground,
  );
}
