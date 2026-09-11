part of '../human_resources_prenomina_page.dart';

/// Offline adapter for exercising the production projection, editor and payload.
/// Does not instantiate Supabase or execute save/publication requests.
@visibleForTesting
({
  Map<String, double> totals,
  Future<Map<String, dynamic>?> Function(BuildContext) open,
})
hrPrenominaEditorForTesting({
  HrLoanFundState? loanFund,
  bool freezeLoanPlans = false,
  required String period,
  required Map<String, dynamic> employee,
  Map<String, dynamic>? storedDraft,
  List<Map<String, dynamic>> attendanceRows = const [],
  List<Map<String, dynamic>> vacationRows = const [],
  List<Map<String, dynamic>> permissionRows = const [],
}) {
  final master = _HrPrenominaEmployeeMaster.fromRow(employee);
  final attendance = attendanceRows
      .map(_HrPrenominaAttendanceRecord.fromRow)
      .toList();
  _HrPrenominaSummaryRow project(Map<String, dynamic>? draft) =>
      _buildPrenominaSummaryRows(
        loanFund: loanFund,
        freezeLoanPlans: freezeLoanPlans,
        employees: [master],
        contpaqLot: null,
        attendanceRecords: attendance,
        vacationEvents: vacationRows
            .map(_HrPrenominaVacationEventRecord.fromRow)
            .toList(),
        permissionEvents: permissionRows
            .map(_HrPrenominaPermissionEventRecord.fromRow)
            .toList(),
        eventPeriodImpacts: [],
        draftRows: draft == null
            ? []
            : [_HrPrenominaDraftRowRecord.fromRow(draft)],
        activePeriodLabel: period,
        activeContpaqRawPeriodLabel: '',
      ).single;
  Map<String, dynamic> payload(_HrPrenominaDraftDraft draft) => draft.toRow(
    periodLabel: period,
    employeeId: master.employeeId,
    employeeName: master.displayName,
    empresa: master.empresa,
    existingId: storedDraft?['id']?.toString() ?? '',
  );
  final row = project(storedDraft);
  return (
    totals: {
      'fiscal': row.fiscalTotalAmount,
      'flow': row.weeklyPaymentVisibleAmount - row.fiscalTotalAmount,
      'total': row.weeklyPaymentVisibleAmount,
      'flow_deductions': row.operationalCashDeductionsTotalAmount,
      'fiscal_deductions': _prenominaFiscalDeductions(row),
      'vacation_days': row.vacationTotalDays,
      'without_pay_days': row.permissionWithoutPayDays,
      'late_minutes': row.lateMinutesSum.toDouble(),
      'extra_minutes': row.overtimeMinutesSum.toDouble(),
    },
    open: (context) async {
      final result = await showDialog<_HrPrenominaEditResult>(
        context: context,
        builder: (_) => _HrPrenominaEditDialog(
          row: row,
          periodLabel: period,
          attendance: attendance,
          preview: (draft) => project(payload(draft)),
          canGoPrevious: true,
          canGoNext: true,
        ),
      );
      if (result == null) return null;
      return {'action': result.action.name, 'payload': payload(result.draft)};
    },
  );
}

@visibleForTesting
Map<String, dynamic> hrPrenominaPrepaidProjectionForTesting({
  HrLoanFundState? loanFund,
  bool freezeLoanPlans = false,
  required String period,
  required Map<String, dynamic> employee,
  required List<Map<String, dynamic>> vacations,
  List<Map<String, dynamic>> attendance = const [],
  List<Map<String, dynamic>> permissions = const [],
  List<Map<String, dynamic>> impacts = const [],
  Map<String, dynamic>? contpaq,
  Map<String, dynamic>? draft,
}) {
  return hrPrenominaPeriodProjectionForTesting(
    loanFund: loanFund,
    freezeLoanPlans: freezeLoanPlans,
    period: period,
    employees: [employee],
    vacations: vacations,
    attendance: attendance,
    permissions: permissions,
    impacts: impacts,
    contpaq: contpaq == null ? [] : [contpaq],
    drafts: draft == null ? [] : [draft],
  ).single;
}

@visibleForTesting
List<Map<String, dynamic>> hrPrenominaPeriodProjectionForTesting({
  HrLoanFundState? loanFund,
  bool freezeLoanPlans = false,
  required String period,
  required List<Map<String, dynamic>> employees,
  List<Map<String, dynamic>> vacations = const [],
  List<Map<String, dynamic>> attendance = const [],
  List<Map<String, dynamic>> permissions = const [],
  List<Map<String, dynamic>> impacts = const [],
  List<Map<String, dynamic>> contpaq = const [],
  List<Map<String, dynamic>> drafts = const [],
}) {
  final rows = _buildPrenominaSummaryRows(
    loanFund: loanFund,
    freezeLoanPlans: freezeLoanPlans,
    employees: employees.map(_HrPrenominaEmployeeMaster.fromRow).toList(),
    contpaqLot: contpaq.isEmpty
        ? null
        : _HrPrenominaImportLotLite.fromRow({
            'source': 'contpaq',
            'period_label': period,
            'entries': contpaq,
          }),
    attendanceRecords: attendance
        .map(_HrPrenominaAttendanceRecord.fromRow)
        .toList(),
    vacationEvents: vacations
        .map(_HrPrenominaVacationEventRecord.fromRow)
        .toList(),
    permissionEvents: permissions
        .map(_HrPrenominaPermissionEventRecord.fromRow)
        .toList(),
    eventPeriodImpacts: impacts.map(HrEventPeriodImpactRecord.fromRow).toList(),
    draftRows: drafts.map(_HrPrenominaDraftRowRecord.fromRow).toList(),
    activePeriodLabel: period,
    activeContpaqRawPeriodLabel: '',
  );
  return rows
      .map(
        (row) => <String, dynamic>{
          'id': row.employeeId,
          'name': row.displayName,
          'fiscal_cash': row.fiscalCashAmount,
          'fiscal_deposit': row.fiscalDepositedAmount,
          'flow_delivery': row.flowDeliveryAmount,
          'envelope': row.cashEnvelopeAmount,
          'channel': row.paymentChannel.name,
          'extra_minutes': row.overtimeMinutesSum,
          'extra_amount': row.overtimeMonetizedAmount,
          'days': row.prepaidVacation.days,
          'enjoyed_days': row.vacationEnjoyedDays,
          'deduction': row.prepaidVacation.total,
          'vacation': row.vacationCalculatedAmount,
          'fiscal': row.fiscalTotalAmount,
          'cash_salary': row.cashSalaryAmount,
          'total': row.weeklyPaymentVisibleAmount,
          'payload': _HrPrenominaDraftDraft.fromSummaryRow(row).toRow(
            periodLabel: period,
            employeeId: row.employeeId,
            employeeName: row.displayName,
            empresa: row.empresa,
            existingId: row.draftId,
          ),
        },
      )
      .toList();
}
