import 'dart:io';

import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as f;
import 'expected_income_pdf_test.dart' as pdf;

final week = DateTime(2026, 9, 21);
ProjectedPayment payment(
  String id,
  int amount, {
  String type = 'EFECTIVO',
  bool included = true,
}) => ProjectedPayment(
  id: id,
  source: 'manual',
  payee: 'PROVEEDOR',
  reference: 'Factura',
  account: 'DICSA|CELAYA',
  date: week,
  amount: amount,
  available: 100000000,
  paymentType: type,
  included: included,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Friday unchanged by default; explicit week anchors due dates without moving actual cutoff',
    () {
      final source = f.budgetSource(
        invoices: [
          f.invoice('this', 100, '2026-09-24'),
          f.invoice('next', 200, '2026-10-01', provider: 'B'),
        ],
      );
      final friday = FinanceWeeklyBudgetAnalysis(source, week);
      final current = FinanceWeeklyBudgetAnalysis(
        source,
        week,
        targetWeek: week,
      );
      expect(friday.period.start, week.add(const Duration(days: 7)));
      expect(friday.proposedTotal, 30000);
      expect(current.period.start, week);
      expect(current.period.asOf, week);
      expect(current.proposedTotal, 10000);
      expect(
        paymentProposal(current).fold<int>(0, (s, r) => s + r.total),
        current.proposedTotal,
      );
    },
  );
  test(
    'invoice documents are fiscal and fixed payments retain their Finance method',
    () {
      final proposal = paymentProposal(
        FinanceWeeklyBudgetAnalysis(
          f.budgetSource(
            invoices: [f.invoice('i', 100, '2026-09-24')],
            fixedPayments: [
              f.fixed('cash', 100, '2026-09-23', method: 'EFECTIVO'),
              f.fixed('bank', 100, '2026-09-23', method: 'BANCO'),
              f.fixed('unknown', 100, '2026-09-23'),
            ],
          ),
          week,
          targetWeek: week,
        ),
      );
      expect(
        {for (final r in proposal) r.id: r.paymentType},
        {
          'fixed:cash': 'EFECTIVO',
          'fixed:bank': 'FISCAL',
          'fixed:unknown': 'SIN_CLASIFICAR',
          'invoice:i': 'FISCAL',
        },
      );
    },
  );
  test(
    'refresh retains edits and excludes paid obligations without inserting new ones',
    () {
      FinanceWeeklyBudgetAnalysis analysis(double balance) =>
          FinanceWeeklyBudgetAnalysis(
            f.budgetSource(
              invoices: [
                f.invoice('i', 1000, '2026-09-24', balance: balance),
                f.invoice('new', 900, '2026-09-24', provider: 'B'),
              ],
            ),
            week,
            targetWeek: week,
          );
      final original = paymentProposal(
        analysis(1000),
      ).firstWhere((r) => r.id == 'invoice:i');
      final saved = original.copyWith(
        amount: 50000,
        paymentType: 'EFECTIVO',
        paymentTypeAutomatic: false,
        date: week.add(const Duration(days: 4)),
        notes: 'Conservar',
      );
      var result = reconcilePayments([
        saved,
      ], paymentProposal(analysis(800))).single;
      expect(result.amount, 50000);
      expect(result.date.weekday, 5);
      expect(result.paymentType, 'EFECTIVO');
      expect(result.notes, 'Conservar');
      result = reconcilePayments([
        saved,
      ], paymentProposal(analysis(200))).single;
      expect(result.amount, 20000);
      expect(result.warning, contains('ajustado'));
      result = reconcilePayments([saved], paymentProposal(analysis(0))).single;
      expect(result.total, 0);
      expect(result.included, false);
    },
  );
  test(
    'agreement-linked invoice cannot be scheduled twice through the invoice',
    () {
      final result = paymentProposal(
        FinanceWeeklyBudgetAnalysis(
          f.budgetSource(
            invoices: [
              f.invoice('agreement', 1000, '2026-09-24', status: 'CONVENIO'),
            ],
          ),
          week,
          targetWeek: week,
        ),
      ).single;
      expect(result.available, 0);
      expect(result.included, false);
    },
  );
  test(
    'flow uses collectible income once, excludes omitted payments, preserves negative balances',
    () {
      final income = IncomeTotals()
        ..add('EFECTIVO', 10000)
        ..add('FISCAL', 20000)
        ..addFinancing('EFECTIVO', 5000);
      final flow = WeeklyCashFlow(
        income,
        WeeklyExpensePlan(
          week: week,
          openingCash: 1000,
          openingFiscal: 2000,
          payments: [
            payment('cash', 25000),
            payment('fiscal', 1000, type: 'FISCAL'),
            payment('excluded', 999999, included: false),
          ],
        ),
      );
      expect(flow.income.salesTotal, 30000);
      expect(flow.income.total, 35000);
      expect(flow.expenses, 26000);
      expect(flow.net, 9000);
      expect(flow.closing, 12000);
      expect(flow.closingFor('EFECTIVO'), -9000);
      expect(flow.closingFor('FISCAL'), 21000);
    },
  );
  test(
    'unclassified cash is included in total but never fabricates a channel balance',
    () {
      final income = IncomeTotals()..add('MIXTO', 1000);
      final flow = WeeklyCashFlow(
        income,
        WeeklyExpensePlan(
          week: week,
          openingCash: 0,
          openingFiscal: 0,
          payments: [payment('unknown', 500, type: 'SIN_CLASIFICAR')],
        ),
      );
      expect(flow.closing, 500);
      expect(flow.classified, false);
      expect(flow.closingFor('EFECTIVO'), isNull);
      expect(
        WeeklyCashFlow(income, WeeklyExpensePlan(week: week)).closing,
        isNull,
      );
    },
  );
  test('saved plan round trips cents, exclusions and selected week', () {
    final plan = WeeklyExpensePlan.fromJson({
      'week_start': '2026-09-21',
      'revision': 3,
      'opening_cash': 123456,
      'opening_fiscal': 0,
      'generated': true,
      'payments': [payment('a', 12345, included: false).toJson()],
    });
    expect(plan.revision, 3);
    expect(plan.openingCash, 123456);
    expect(plan.payments.single.total, 0);
  });
  for (final scenario in ['normal', 'large', 'incomplete', 'deficit']) {
    test('itemized flow PDF: $scenario', () async {
      final plan = WeeklyExpensePlan(
        week: week,
        revision: 3,
        generated: scenario != 'incomplete',
        openingCash: scenario == 'incomplete' ? null : 1000000,
        openingFiscal: scenario == 'incomplete' ? null : 2000000,
        payments: [
          payment('cash', scenario == 'deficit' ? 100000000 : 20000000),
          payment('fiscal', 15000000, type: 'FISCAL'),
          if (scenario == 'incomplete')
            payment('unclassified', 5000000, type: 'SIN_CLASIFICAR'),
          if (scenario == 'large')
            for (var i = 0; i < 1000; i++) payment('$i', 123),
        ],
      );
      final bytes = await buildWeeklyCashFlowPdf(
        pdf.reportFixture().projection,
        plan,
        generatedAt: week,
      );
      expect(pdf.pages(bytes), greaterThan(1));
      if (Platform.environment['DICSA_FLOW_QA'] == '1') {
        await File('/private/tmp/dicsa-flow-$scenario.pdf').writeAsBytes(bytes);
      }
    });
  }
}
