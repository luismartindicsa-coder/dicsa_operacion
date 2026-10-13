import 'dart:math' as math;

import '../../management_reports/finance_weekly_budget_analysis.dart';
import '../expected_income/expected_income_models.dart';
import 'weekly_projection_models.dart';

const _channels = ['EFECTIVO', 'FISCAL'];

Map<String, DateTime> paymentDueDates(FinanceWeeklyBudgetAnalysis analysis) => {
  for (final row in analysis.invoices)
    if (row.invoice.dueDate != null)
      'invoice:${row.invoice.id}': incomeDay(row.invoice.dueDate!),
  for (final row in analysis.commitments)
    if (row.dueDate != null)
      '${row.fixed ? 'fixed' : 'agreement'}:${row.id}': incomeDay(row.dueDate!),
};

class PaymentPressureDay {
  final DateTime date;
  final bool elapsed;
  final Map<String, int> income, expenses, closing;
  const PaymentPressureDay({
    required this.date,
    required this.elapsed,
    required this.income,
    required this.expenses,
    required this.closing,
  });
  int get receipts => income.values.fold(0, (a, b) => a + b);
  int get payments => expenses.values.fold(0, (a, b) => a + b);
  int get shortfall => closing.values.fold(0, (s, v) => s + math.max(0, -v));
  double get peakUsage => _channels.fold<double>(0, (peak, type) {
    final paid = expenses[type] ?? 0;
    if (paid == 0) return peak;
    return math.max(peak, paid / math.max(1, (closing[type] ?? 0) + paid));
  });
}

class WeeklyPaymentPressure {
  final List<PaymentPressureDay> days;
  final List<String> warnings;
  final bool openingComplete, classified;
  const WeeklyPaymentPressure({
    required this.days,
    required this.warnings,
    required this.openingComplete,
    required this.classified,
  });
}

/// All money is in cents. Only dated, classified pending income can fund a day.
/// The opening balance is the available balance at the consultation cutoff.
class _LiquidityCalendar {
  final WeeklyExpensePlan plan;
  final ExpectedIncomeProjection income;
  final DateTime start;
  final int firstDay;
  final receipts = {
    for (final type in [..._channels, 'MIXTO']) type: List<int>.filled(7, 0),
  };
  final expenses = {
    for (final type in [..._channels, 'SIN_CLASIFICAR'])
      type: List<int>.filled(7, 0),
  };
  int earlierPendingIncome = 0;

  _LiquidityCalendar(this.plan, this.income, DateTime now)
    : start = incomeDay(plan.week),
      firstDay = incomeDay(
        now,
      ).difference(incomeDay(plan.week)).inDays.clamp(0, 7) {
    for (final entry in income.timeline.entries) {
      final offset = incomeDay(entry.key).difference(start).inDays;
      if (offset < 0 || offset > 6) continue;
      if (offset < firstDay) {
        earlierPendingIncome += entry.value.total;
        continue;
      }
      for (final type in receipts.keys) {
        receipts[type]![offset] += entry.value.byType[type] ?? 0;
      }
    }
  }

  void reserve(ProjectedPayment payment) {
    if (payment.total <= 0 || firstDay == 7) return;
    final offset = incomeDay(payment.date).difference(start).inDays;
    if (offset < 0 || offset > 6) {
      throw StateError('El pago ${payment.reference} está fuera de la semana.');
    }
    // These are still unpaid obligations, even if a saved date has elapsed.
    expenses[payment.paymentType]![math.max(firstDay, offset)] += payment.total;
  }

  List<int> balances(String type, {bool reserveUnclassified = false}) {
    var balance =
        (type == 'EFECTIVO' ? plan.openingCash : plan.openingFiscal) ?? 0;
    return [
      for (var d = 0; d < 7; d++)
        if (d < firstDay)
          0
        else
          balance +=
              receipts[type]![d] -
              expenses[type]![d] -
              (reserveUnclassified ? expenses['SIN_CLASIFICAR']![d] : 0),
    ];
  }

  WeeklyPaymentPressure report(FinanceWeeklyBudgetAnalysis? analysis) {
    final closing = {for (final type in _channels) type: balances(type)};
    final openingComplete =
        plan.openingCash != null && plan.openingFiscal != null;
    final mixed = receipts['MIXTO']!.fold<int>(0, (a, b) => a + b);
    final unclassified = expenses['SIN_CLASIFICAR']!.fold<int>(
      0,
      (a, b) => a + b,
    );
    final due = analysis == null
        ? <String, DateTime>{}
        : paymentDueDates(analysis);
    final late = plan.scheduledPayments
        .where(
          (p) => due.containsKey(p.id) && incomeDay(p.date).isAfter(due[p.id]!),
        )
        .length;
    return WeeklyPaymentPressure(
      openingComplete: openingComplete,
      classified: mixed == 0 && unclassified == 0,
      days: [
        for (var d = 0; d < 7; d++)
          PaymentPressureDay(
            date: start.add(Duration(days: d)),
            elapsed: d < firstDay,
            income: {for (final t in receipts.keys) t: receipts[t]![d]},
            expenses: {for (final t in expenses.keys) t: expenses[t]![d]},
            closing: {for (final t in _channels) t: closing[t]![d]},
          ),
      ],
      warnings: [
        if (!openingComplete)
          'Falta capturar el saldo inicial de Efectivo o Fiscal. La distribución usa solo el saldo conocido y los ingresos fechados; la presión queda por validar.',
        if (income.current.financingByType.entries.any(
          (part) => part.value > 0 && income.palomar.dateFor(part.key) == null,
        ))
          'Parte de la disposición de El Palomar sigue sin fecha de recepción: aparece en el flujo semanal, pero solo los importes con fecha financian un día específico.',
        if (income.undated.total > 0)
          'Hay ingresos sin fecha de cobro; no se usan para asignar los pagos a un día.',
        if (earlierPendingIncome > 0)
          'Hay cobros pendientes con fecha anterior a hoy. Reprograma su cobro en Ingresos para usarlos en la distribución diaria.',
        if (mixed > 0)
          'Los ingresos mixtos sin distribuir no financian Efectivo ni Fiscal hasta asignar sus importes.',
        if (unclassified > 0)
          'Hay egresos sin clasificar. Se reserva su importe de forma conservadora al distribuir; los saldos por canal quedan por validar.',
        if (late > 0)
          '$late pagos tienen fecha posterior a su vencimiento original; incluyen compromisos ya atrasados y ajustes manuales.',
        if (firstDay == 7)
          'La semana ya terminó; sus fechas no se redistribuyen automáticamente.',
        if (income.warnings.isNotEmpty)
          'Revisa los avisos de Ingresos: la distribución depende de sus fechas e importes previstos.',
      ],
    );
  }
}

WeeklyPaymentPressure weeklyPaymentPressure({
  required WeeklyExpensePlan plan,
  required ExpectedIncomeProjection income,
  required DateTime now,
  FinanceWeeklyBudgetAnalysis? analysis,
}) {
  final calendar = _LiquidityCalendar(plan, income, now);
  for (final row in plan.scheduledPayments) {
    calendar.reserve(row);
  }
  return calendar.report(analysis);
}

class IncomePaymentSchedule {
  final List<ProjectedPayment> payments;
  final int moved;
  const IncomePaymentSchedule(this.payments, this.moved);
}

/// Deterministic deadline-first allocation of the selected Finance proposal.
/// It does not change amounts, selection or manually edited rows. Manual payments
/// and Menudeo reserve liquidity first. Among days with sufficient cash for all
/// subsequent commitments, prefer the lowest payments / available-funds ratio.
/// If no day is funded, keep the due-date fallback and disclose the shortfall.
IncomePaymentSchedule distributePaymentsByIncome({
  required WeeklyExpensePlan plan,
  required ExpectedIncomeProjection income,
  required FinanceWeeklyBudgetAnalysis analysis,
  required DateTime now,
  bool allowLatePayments = false,
}) {
  final calendar = _LiquidityCalendar(plan, income, now);
  if (calendar.firstDay == 7) return IncomePaymentSchedule(plan.payments, 0);
  final dueDates = paymentDueDates(analysis);
  bool movable(ProjectedPayment row) =>
      row.total > 0 &&
      row.selectionAutomatic &&
      const ['invoice', 'agreement', 'fixed'].contains(row.source) &&
      _channels.contains(row.paymentType);
  for (final row in plan.scheduledPayments.where((r) => !movable(r))) {
    calendar.reserve(row);
  }
  final candidates = plan.payments.where(movable).toList()
    ..sort((a, b) {
      final due = (dueDates[a.id] ?? a.date).compareTo(
        dueDates[b.id] ?? b.date,
      );
      if (due != 0) return due;
      final amount = b.amount.compareTo(a.amount);
      return amount != 0 ? amount : a.id.compareTo(b.id);
    });
  final assigned = <String, ProjectedPayment>{};
  var moved = 0;
  for (final row in candidates) {
    final first = calendar.firstDay;
    final due = dueDates[row.id];
    final dueOffset = due?.difference(calendar.start).inDays;
    // Already overdue obligations may be paid later, throughout this week.
    final last = dueOffset == null || dueOffset < first
        ? 6
        : dueOffset.clamp(first, 6);
    final balances = calendar.balances(
      row.paymentType,
      reserveUnclassified: true,
    );
    final headroom = List<int>.filled(7, 0);
    for (var d = 6; d >= first; d--) {
      headroom[d] = d == 6
          ? balances[d]
          : math.min(balances[d], headroom[d + 1]);
    }
    int? best;
    var bestPressure = double.infinity;
    void consider(int d) {
      if (headroom[d] < row.amount) return;
      final existing =
          calendar.expenses[row.paymentType]![d] +
          calendar.expenses['SIN_CLASIFICAR']![d];
      final funds = balances[d] + existing;
      final pressure = (existing + row.amount) / funds;
      if (pressure < bestPressure) {
        best = d;
        bestPressure = pressure;
      }
    }

    for (var d = first; d <= last; d++) {
      consider(d);
    }
    // Being allowed to pay late is a fallback, never a reason to miss a
    // deadline that can be met with the known funds.
    if (best == null && allowLatePayments) {
      for (var d = last + 1; d < 7; d++) {
        consider(d);
      }
    }
    final day =
        best ??
        (dueOffset ?? row.date.difference(calendar.start).inDays).clamp(
          first,
          last,
        );
    final updated = row.copyWith(date: calendar.start.add(Duration(days: day)));
    assigned[row.id] = updated;
    calendar.reserve(updated);
    if (updated.date != row.date) moved++;
  }
  return IncomePaymentSchedule([
    for (final row in plan.payments) assigned[row.id] ?? row,
  ], moved);
}
