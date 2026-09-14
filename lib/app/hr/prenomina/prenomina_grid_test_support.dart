part of '../human_resources_prenomina_page.dart';

/// Offline fixture host. Inherits the actual page, filters, pagination, selection
/// and detail navigation; only external reads/writes are replaced for tests.
@visibleForTesting
Widget hrPrenominaGridForTesting({
  required String period,
  required List<Map<String, dynamic>> employees,
  required List<Map<String, dynamic>> drafts,
  List<Map<String, dynamic>> attendance = const [],
  List<Map<String, dynamic>> vacations = const [],
  List<Map<String, dynamic>> permissions = const [],
  required ValueChanged<Map<String, dynamic>> onSnapshot,
  required ValueChanged<String> onAction,
  ValueChanged<Uint8List>? onExportBytes,
  HrLoanFundState? loanFund,
  String? loanLoadError,
  bool useClosureReview = false,
  bool useStatusActions = false,
  bool periodClosed = false,
  Future<void> Function(Map<String, dynamic>)? onPersistDraft,
  Future<void> Function(Map<String, dynamic>)? onAfterPersistDraft,
}) => _PrenominaGridFixture(
  period: period,
  employees: employees,
  drafts: drafts,
  attendance: attendance,
  vacations: vacations,
  permissions: permissions,
  onSnapshot: onSnapshot,
  onAction: onAction,
  onExportBytes: onExportBytes,
  loanFund: loanFund,
  loanLoadError: loanLoadError,
  useClosureReview: useClosureReview,
  useStatusActions: useStatusActions,
  periodClosed: periodClosed,
  onPersistDraft: onPersistDraft,
  onAfterPersistDraft: onAfterPersistDraft,
);

class _PrenominaGridFixture extends HumanResourcesPrenominaPage {
  final String period;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> drafts;
  final List<Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> vacations;
  final List<Map<String, dynamic>> permissions;
  final ValueChanged<Map<String, dynamic>> onSnapshot;
  final ValueChanged<String> onAction;
  final ValueChanged<Uint8List>? onExportBytes;
  final HrLoanFundState? loanFund;
  final String? loanLoadError;
  final bool useClosureReview;
  final bool useStatusActions;
  final bool periodClosed;
  final Future<void> Function(Map<String, dynamic>)? onPersistDraft;
  final Future<void> Function(Map<String, dynamic>)? onAfterPersistDraft;
  const _PrenominaGridFixture({
    required this.period,
    required this.employees,
    required this.drafts,
    required this.attendance,
    required this.vacations,
    required this.permissions,
    required this.onSnapshot,
    required this.onAction,
    this.onExportBytes,
    this.loanFund,
    this.loanLoadError,
    this.useClosureReview = false,
    this.useStatusActions = false,
    this.periodClosed = false,
    this.onPersistDraft,
    this.onAfterPersistDraft,
  });
  @override
  State<HumanResourcesPrenominaPage> createState() =>
      _PrenominaGridFixtureState();
}

class _PrenominaGridFixtureState extends _HumanResourcesPrenominaPageState {
  List<Map<String, dynamic>>? _savedDrafts;
  _PrenominaGridFixture get fixture => widget as _PrenominaGridFixture;
  @override
  Future<void> _resolveNavigationAccess() async {}
  @override
  Future<void> _loadData() async {
    _periodClosures = [
      if (fixture.periodClosed)
        _HrPrenominaPeriodClosure.fromRow({
          'period_label': fixture.period,
          'status': 'cerrado',
        }),
    ];
    _loanFund = fixture.loanFund;
    _loanLoadError = fixture.loanLoadError;
    _employees = fixture.employees
        .map(_HrPrenominaEmployeeMaster.fromRow)
        .toList();
    _draftRows = (_savedDrafts ?? fixture.drafts)
        .map(_HrPrenominaDraftRowRecord.fromRow)
        .toList();
    _attendanceRecords = fixture.attendance
        .where(isHrOperationalAttendanceRow)
        .map(_HrPrenominaAttendanceRecord.fromRow)
        .toList();
    _vacationEvents = fixture.vacations
        .map(_HrPrenominaVacationEventRecord.fromRow)
        .toList();
    _permissionEvents = fixture.permissions
        .map(_HrPrenominaPermissionEventRecord.fromRow)
        .toList();
    _periodOptions = [fixture.period];
    _selectedPeriodLabel = fixture.period;
    _rebuildRows();
  }

  @override
  void _rebuildRows() {
    super._rebuildRows();
    fixture.onSnapshot({
      'count': _allRows.length,
      'statuses': {
        for (final row in _periodRows) row.employeeId: row.statusLabel,
      },
      'page': _currentPage,
      'page_size': _pageSize,
      'visible_ids': _visibleRows.map((row) => row.employeeId).toList(),
      'fiscal': _allRows.fold<double>(
        0,
        (sum, row) => sum + row.fiscalTotalAmount,
      ),
      'deposit': _allRows.fold<double>(
        0,
        (sum, row) => sum + row.fiscalDepositedAmount,
      ),
      'cheque': _allRows.fold<double>(
        0,
        (sum, row) => sum + row.fiscalCashAmount,
      ),
      'flow': _allRows.fold<double>(
        0,
        (sum, row) => sum + row.flowDeliveryAmount,
      ),
      'total': _allRows.fold<double>(
        0,
        (sum, row) => sum + row.weeklyPaymentVisibleAmount,
      ),
      'ready': _allRows.where((row) => row.statusLabel == 'Listo').length,
      'review': _allRows
          .where((row) => row.statusLabel == 'Revisión RH')
          .length,
      'extra': _allRows.fold<int>(
        0,
        (sum, row) => sum + row.overtimeMinutesSum,
      ),
    });
  }

  @override
  Future<void> _saveDraftRow({
    required _HrPrenominaSummaryRow row,
    required _HrPrenominaEditResult result,
  }) async {
    if (fixture.useStatusActions) {
      await super._saveDraftRow(row: row, result: result);
      return;
    }
    fixture.onAction('save:${row.employeeId}:${result.action.name}');
    if (fixture.useClosureReview) {
      final payload = result.draft.toRow(
        periodLabel: _activePeriodLabel,
        employeeId: row.employeeId,
        employeeName: row.displayName,
        empresa: row.empresa,
        existingId: row.draftId,
      );
      _savedDrafts = [
        for (final draft in _savedDrafts ?? fixture.drafts)
          if (draft['employee_id'] != row.employeeId ||
              draft['period_label'] != _activePeriodLabel)
            draft,
        payload,
      ];
      await _loadData();
    }
  }

  @override
  Future<void> _persistDraftRow(Map<String, dynamic> payload) async {
    await fixture.onPersistDraft?.call(payload);
    fixture.onAction(
      'persist:${payload['employee_id']}:${payload['draft_status']}',
    );
    _savedDrafts = [
      for (final draft in _savedDrafts ?? fixture.drafts)
        if (draft['employee_id'] != payload['employee_id'] ||
            draft['period_label'] != payload['period_label'])
          draft,
      {
        ...payload,
        'id': payload['id'] ?? 'fixture-draft-${payload['employee_id']}',
      },
    ];
    await fixture.onAfterPersistDraft?.call(payload);
  }

  @override
  Future<void> _closeActivePeriod() async {
    fixture.onAction('close');
    if (fixture.useClosureReview) await super._closeActivePeriod();
  }

  @override
  Future<void> _exportCashEnvelopeXlsx() async {
    fixture.onAction('export');
    if (fixture.onExportBytes != null) await super._exportCashEnvelopeXlsx();
  }

  @override
  Future<String?> _saveCashEnvelopeXlsx(Uint8List bytes) async {
    fixture.onExportBytes!(bytes);
    return 'sobres_prueba.xlsx';
  }
}
