import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as ui;
import 'weekly_payment_schedule_test.dart' as schedule;
import 'weekly_projection_view_test.dart' as fixtures;

void main() {
  test(
    'weekly payroll has the three requested amounts, channels and weekdays across year boundaries',
    () {
      for (final week in [
        f.incomeWeek,
        DateTime(2026, 10, 26),
        DateTime(2026, 12, 28),
      ]) {
        final payroll = includeWeeklyPayroll([], week);
        expect(payroll, hasLength(3));
        final plan = WeeklyExpensePlan(week: week, payments: payroll);
        expect(plan.total, 20500000);
        expect(plan.totalForType('FISCAL'), 12000000);
        expect(plan.totalForType('EFECTIVO'), 8500000);
        expect(
          {for (final r in payroll) r.payee: (r.amount, r.paymentType, r.date)},
          {
            'NOMINA DICSA FISCAL': (
              12000000,
              'FISCAL',
              week.add(const Duration(days: 3)),
            ),
            'NOMINA DICSA EFECTIVO': (
              5500000,
              'EFECTIVO',
              week.add(const Duration(days: 4)),
            ),
            'NOMINA EMPRESAS EFECTIVO': (
              3000000,
              'EFECTIVO',
              week.add(const Duration(days: 3)),
            ),
          },
        );
      }
    },
  );

  test(
    'saved payroll survives round trip, regeneration, silent refresh and Finance reset once per week',
    () {
      final defaults = weeklyPayrollPayments(f.incomeWeek);
      final saved = [
        defaults[0].copyWith(amount: 11000000, notes: 'Ajuste de esta semana'),
        defaults[1].copyWith(included: false),
        defaults[2].copyWith(removed: true, included: false),
      ].map((r) => ProjectedPayment.fromJson(r.toJson())).toList();
      var result = saved;
      for (var n = 0; n < 3; n++) {
        result = includeWeeklyPayroll(
          incorporateFinanceProposal(result, []),
          f.incomeWeek,
        );
        result = reconcilePayments(result, []);
        result = includeWeeklyPayroll(
          resetFinanceProposal(result, []),
          f.incomeWeek,
        );
        expect(result.map((r) => r.toJson()), saved.map((r) => r.toJson()));
      }
      final next = includeWeeklyPayroll(
        [],
        f.incomeWeek.add(const Duration(days: 7)),
      );
      expect(next.every((r) => r.included && !r.removed), isTrue);
      expect(next.first.amount, 12000000);
    },
  );

  test(
    'fixed payroll reserves funds before Finance payments and never moves with income timing',
    () {
      final analysis = schedule.analysis([('tax', 1000, 1)]);
      final payroll = weeklyPayrollPayments(f.incomeWeek);
      final plan = WeeklyExpensePlan(
        week: f.incomeWeek,
        openingFiscal: 12000000,
        openingCash: 8500000,
        payments: includeWeeklyPayroll(paymentProposal(analysis), f.incomeWeek),
      );
      final result = schedule.distribute(
        analysis,
        schedule.income({4: 100000}),
        plan: plan,
      );
      for (final row in payroll) {
        expect(
          result.payments.singleWhere((r) => r.id == row.id).toJson(),
          row.toJson(),
        );
      }
      expect(
        result.payments.singleWhere((r) => r.id == 'invoice:tax').date,
        schedule.day(4),
      );
    },
  );

  test(
    'payroll contributes to cash flow and report totals without expense ticket exclusion',
    () {
      final report = WeeklyCashFlowReport(
        f.forecast(bundle: f.incomeBundle(shipments: [])),
        WeeklyExpensePlan(
          week: f.incomeWeek,
          generated: true,
          openingCash: 8500000,
          openingFiscal: 12000000,
          payments: weeklyPayrollPayments(f.incomeWeek),
        ),
      );
      expect(report.flow.expenses, 20500000);
      expect(report.flow.closing, 0);
      expect(report.flow.plan.scheduledPayments, hasLength(3));
      final days = WeeklyCashFlowCalendar(report, f.incomeWeek).pressure.days;
      expect(days[3].payments, 15000000);
      expect(days[4].payments, 5500000);
    },
  );

  testWidgets(
    'Generate adds payroll only on demand, persists once and keeps it after silent refresh',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = fixtures.MemoryProjectionRepository();
      await tester.pumpWidget(
        ui.app(
          WeeklyProjectionView(
            bundle: f.incomeBundle(shipments: []),
            onWeekChanged: (_) async {},
            active: true,
            flow: false,
            repository: repo,
            incomeRepository: ui.MemoryIncomeRepository(),
            clock: () => f.incomeWeek,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      final generate = find.byKey(
        const ValueKey('generate-projected-payments'),
      );
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(generate);
        await tester.tap(generate);
        await tester.pumpAndSettle();
        final saved = repo.saved[f.incomeWeek]!.payments
            .where((r) => r.isWeeklyPayroll)
            .toList();
        expect(saved, hasLength(3));
        expect(saved.fold<int>(0, (sum, r) => sum + r.total), 20500000);
        expect(saved.first.date, f.incomeWeek.add(const Duration(days: 3)));
      }
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('NOMINA DICSA FISCAL'), findsOneWidget);
      expect(find.textContaining('NOMINA DICSA EFECTIVO'), findsOneWidget);
      expect(find.textContaining('NOMINA EMPRESAS EFECTIVO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
