import '../expected_income/expected_income_models.dart';
import 'weekly_cash_flow_income.dart';
import 'weekly_projection_models.dart';
import 'weekly_payment_schedule.dart';

export 'weekly_cash_flow_income.dart' show FlowIncomeDetail;

/// The PDF scope deliberately excludes expense tickets, including from totals.
WeeklyExpensePlan expenseReportPlan(WeeklyExpensePlan plan) => plan.copyWith(
  payments: plan.payments.where((r) => r.source != 'ticket').toList(),
);

/// Uses the already reconciled income projection, including Mayoreo collections
/// only once. Palomar is one possible draw, with optional weekly dates per channel.
class WeeklyCashFlowReport {
  final ExpectedIncomeProjection projection;
  final WeeklyCashFlowIncome income;
  final WeeklyCashFlow flow;
  final List<FlowIncomeDetail> incomes;

  factory WeeklyCashFlowReport(
    ExpectedIncomeProjection projection,
    WeeklyExpensePlan plan,
  ) {
    final income = WeeklyCashFlowIncome(projection, plan.week);
    final incomes = income.incomes;
    final totals = IncomeTotals();
    for (final r in incomes) {
      if (r.financing) {
        totals.addFinancing(r.type, r.amount);
      } else {
        totals.add(r.type, r.amount);
      }
    }
    for (final type in {...totals.byType.keys, ...income.totals.byType.keys}) {
      if ((totals.byType[type] ?? 0) != (income.totals.byType[type] ?? 0) ||
          (totals.financingByType[type] ?? 0) !=
              (income.totals.financingByType[type] ?? 0)) {
        throw StateError(
          'El desglose de ingresos no coincide con los totales de la semana. Actualiza la proyección antes de exportar.',
        );
      }
    }
    return WeeklyCashFlowReport._(
      projection,
      income,
      WeeklyCashFlow(income.totals, expenseReportPlan(plan)),
      incomes,
    );
  }
  const WeeklyCashFlowReport._(
    this.projection,
    this.income,
    this.flow,
    this.incomes,
  );
}

enum DailyFlowStatus {
  elapsed,
  missingOpening,
  unclassified,
  incomplete,
  shortfall,
  sufficient,
}

/// Shares the payment allocator's liquidity rules, using the PDF's ticket-free
/// scope. Undated financing and overdue receipts never create daily liquidity.
class WeeklyCashFlowCalendar {
  final WeeklyCashFlowReport report;
  final WeeklyPaymentPressure pressure;
  final IncomeTotals undated = IncomeTotals(), earlier = IncomeTotals();
  final DateTime cutoff;
  int earlierPayments = 0;

  WeeklyCashFlowCalendar(this.report, DateTime now)
    : cutoff = incomeDay(now),
      pressure = weeklyPaymentPressure(
        plan: report.flow.plan,
        income: report.projection,
        now: now,
      ) {
    for (final row in report.incomes) {
      if (row.date == null) {
        undated.add(row.type, row.amount);
      } else if (incomeDay(row.date!).isBefore(cutoff)) {
        earlier.add(row.type, row.amount);
      }
    }
    earlierPayments = report.flow.plan.scheduledPayments
        .where((p) => incomeDay(p.date).isBefore(cutoff))
        .fold(0, (s, p) => s + p.total);
  }

  int? openingFor(String type) => type == 'EFECTIVO'
      ? report.flow.plan.openingCash
      : report.flow.plan.openingFiscal;

  int? closingFor(PaymentPressureDay day, String type) =>
      day.elapsed || openingFor(type) == null || !pressure.classified
      ? null
      : day.closing[type];

  DailyFlowStatus statusFor(PaymentPressureDay day, String type) {
    if (day.elapsed) return DailyFlowStatus.elapsed;
    if (openingFor(type) == null) return DailyFlowStatus.missingOpening;
    if (!pressure.classified) return DailyFlowStatus.unclassified;
    if (!report.flow.plan.generated) return DailyFlowStatus.incomplete;
    return closingFor(day, type)! < 0
        ? DailyFlowStatus.shortfall
        : DailyFlowStatus.sufficient;
  }
}
