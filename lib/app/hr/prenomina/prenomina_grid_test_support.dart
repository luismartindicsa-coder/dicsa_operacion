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
}) => _PrenominaGridFixture(
  period: period,
  employees: employees,
  drafts: drafts,
  attendance: attendance,
  vacations: vacations,
  permissions: permissions,
  onSnapshot: onSnapshot,
  onAction: onAction,
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
  const _PrenominaGridFixture({
    required this.period,
    required this.employees,
    required this.drafts,
    required this.attendance,
    required this.vacations,
    required this.permissions,
    required this.onSnapshot,
    required this.onAction,
  });
  @override
  State<HumanResourcesPrenominaPage> createState() =>
      _PrenominaGridFixtureState();
}

class _PrenominaGridFixtureState extends _HumanResourcesPrenominaPageState {
  _PrenominaGridFixture get fixture => widget as _PrenominaGridFixture;
  @override
  Future<void> _resolveNavigationAccess() async {}
  @override
  Future<void> _loadData() async {
    _employees = fixture.employees
        .map(_HrPrenominaEmployeeMaster.fromRow)
        .toList();
    _draftRows = fixture.drafts
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
        (sum, row) =>
            sum + row.weeklyPaymentVisibleAmount - row.fiscalTotalAmount,
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
    fixture.onAction('save:${row.employeeId}:${result.action.name}');
  }

  @override
  Future<void> _closeActivePeriod() async {
    fixture.onAction('close');
  }

  @override
  Future<void> _exportCashEnvelopeXlsx() async {
    fixture.onAction('export');
  }
}
