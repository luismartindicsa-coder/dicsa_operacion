import 'statement_automatic_rules.dart';
import 'statement_models.dart';

/// Known remuneration only. CONTPAQ's stored net does not contain a complete
/// gross-pay breakdown or employer contributions, so this is always a partial
/// basis, never a certified employer cost. Cheques are delivery, not earnings.
double? statementPayrollRemuneration(StatementRow r) {
  const fields = [
    'fiscal_net_amount',
    'fiscal_imss_amount',
    'fiscal_infonavit_amount',
    'fiscal_fonacot_amount',
    'fiscal_late_deduction_amount',
    'fiscal_vacation_amount',
    'fiscal_manual_deduction_amount',
    'cash_salary_amount',
    'cash_vacation_amount',
    'transport_support_amount',
    'holiday_amount',
    'overtime_monetized_amount',
    'manual_bonus_amount',
    'manual_adjustment_amount',
    'payment_outside_amount',
    'cash_absence_deduction_amount',
  ];
  if (r['fiscal_net_amount'] == null && r['cash_salary_amount'] == null) {
    return null;
  }
  for (final field in fields) {
    if (r[field] == null) continue;
    final value = statementValidNumber(r[field]);
    if (value == null || (value < 0 && field != 'manual_adjustment_amount')) {
      return null;
    }
  }
  double n(String k) => stNumber(r[k]);
  if (r['source_snapshot'] != null && r['source_snapshot'] is! Map) return null;
  final snapshot = r['source_snapshot'] as Map? ?? const {};
  if (snapshot['contpaq_official_net'] != null &&
      statementValidNumber(snapshot['contpaq_official_net']) == null) {
    return null;
  }
  if (snapshot['prepaid_vacation'] != null &&
      snapshot['prepaid_vacation'] is! Map) {
    return null;
  }
  final prepaid = snapshot['prepaid_vacation'] as Map? ?? const {};
  if (['days', 'fiscal', 'flow'].any(
    (k) => prepaid[k] != null && statementValidNumber(prepaid[k]) == null,
  )) {
    return null;
  }
  // These need the original accrual/advance to determine the earned amount.
  if (n('fiscal_manual_deduction_amount') != 0 ||
      ['days', 'fiscal', 'flow'].any((k) => stNumber(prepaid[k]) != 0)) {
    return null;
  }
  final informational =
      snapshot['incidences_informational'] == true ||
      r['incidences_informational'] == true;
  final fiscal =
      (n('fiscal_net_amount') -
              (informational ? 0 : n('fiscal_late_deduction_amount')))
          .clamp(0, double.infinity) +
      n('fiscal_imss_amount') +
      n('fiscal_infonavit_amount') +
      n('fiscal_fonacot_amount') +
      (snapshot['contpaq_official_net'] != null
          ? 0
          : n('fiscal_vacation_amount'));
  final complements = [
    'cash_salary_amount',
    'cash_vacation_amount',
    'transport_support_amount',
    'holiday_amount',
    'overtime_monetized_amount',
    'manual_bonus_amount',
    'manual_adjustment_amount',
    'payment_outside_amount',
  ].fold<double>(0, (sum, field) => sum + n(field));
  // ISR, INFONAVIT, FONACOT and loan repayments withheld from this compensation
  // settle liabilities/receivables; they do not reduce the remuneration earned.
  final amount =
      fiscal +
      complements -
      (informational ? 0 : n('cash_absence_deduction_amount'));
  return amount.isFinite && amount >= 0 ? amount : null;
}

(DateTime, DateTime)? statementPayrollDates(String label) {
  final m = RegExp(
    r'(\d{2})/(\d{2})/(\d{4})\s*-\s*(\d{2})/(\d{2})/(\d{4})',
  ).firstMatch(label);
  if (m == null) return null;
  final start = stDate('${m[3]}-${m[2]}-${m[1]}');
  final end = stDate('${m[6]}-${m[5]}-${m[4]}');
  return start == null ||
          end == null ||
          end.isBefore(start) ||
          end.difference(start).inDays > 31
      ? null
      : (start, end);
}
