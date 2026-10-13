import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_payment_schedule.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as b;
import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as ui_fixtures;
import 'weekly_projection_view_test.dart' as fixtures;

DateTime day(int offset) => f.incomeWeek.add(Duration(days: offset));
FinanceWeeklyBudgetAnalysis analysis(List<(String, double, int)> invoices) =>
    FinanceWeeklyBudgetAnalysis(
      b.budgetSource(
        invoices: [
          for (final (id, amount, due) in invoices)
            b.invoice(id, amount, day(due).toIso8601String(), provider: id),
        ],
      ),
      day(0),
      targetWeek: day(0),
    );

ExpectedIncomeProjection income(
  Map<int, int> amounts, {
  String type = 'FISCAL',
  int financing = 0,
  int undated = 0,
}) {
  final timeline = {
    for (final e in amounts.entries)
      day(e.key): IncomeTotals()..add(type, e.value),
  };
  return ExpectedIncomeProjection(
    rows: const [],
    current: IncomeTotals()
      ..add(type, amounts.values.fold<int>(0, (a, b) => a + b))
      ..addFinancing('FISCAL', financing),
    next: IncomeTotals(),
    later: IncomeTotals(),
    overdue: IncomeTotals(),
    undated: IncomeTotals()..add(type, undated),
    timeline: timeline,
    palomar: const PalomarIncomeProjection(
      opening: 0,
      charges: 0,
      credits: 0,
      plannedShipments: 0,
      closing: 0,
      availableDraw: 0,
      cash: 0,
      fiscal: 0,
      configured: true,
      complete: true,
    ),
    warnings: const [],
  );
}

IncomePaymentSchedule distribute(
  FinanceWeeklyBudgetAnalysis a,
  ExpectedIncomeProjection i, {
  WeeklyExpensePlan? plan,
  int now = 0,
}) => distributePaymentsByIncome(
  analysis: a,
  income: i,
  now: day(now),
  allowLatePayments: true,
  plan:
      plan ??
      WeeklyExpensePlan(
        week: day(0),
        openingCash: 0,
        openingFiscal: 0,
        payments: paymentProposal(a),
      ),
);

class ScheduleIncomeRepository extends ExpectedIncomeRepository {
  int receiptDay = 2, reads = 0;
  bool fail = false;
  @override
  Future<ExpectedIncomeData> load(
    DirectionShipmentPlanningBundle bundle, {
    DateTime? now,
  }) async {
    reads++;
    if (fail) throw StateError('No se pudieron leer los ingresos');
    return ExpectedIncomeData(
      collections: [
        MayoreoExpectedCollection(
          accountId: 'collection',
          client: 'Cliente',
          material: 'Cartón',
          document: 'R-1',
          saleDate: day(-7),
          dueDate: day(receiptDay),
          pendingCents: 20000,
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });

  test(
    'balances load over receipt days without changing selection or cents',
    () {
      final a = analysis([('a', 50, 4), ('b', 50, 4)]);
      final result = distribute(a, income({1: 10000, 3: 10000}));
      // Thursday's receipt also leaves carryover for a less loaded Friday.
      expect(result.payments.map((p) => p.date).toSet(), {day(3), day(4)});
      expect(
        result.payments.fold<int>(0, (s, p) => s + p.total),
        a.proposedTotal,
      );
      expect(
        result.payments.every((p) => p.selectionAutomatic && p.included),
        true,
      );
      final again = distribute(
        a,
        income({1: 10000, 3: 10000}),
        plan: WeeklyExpensePlan(
          week: day(0),
          payments: result.payments.reversed.toList(),
          openingCash: 0,
          openingFiscal: 0,
        ),
      );
      expect(
        {for (final p in again.payments) p.id: p.date},
        {for (final p in result.payments) p.id: p.date},
      );
    },
  );
  test('late is a fallback when incoming funds arrive after the due date', () {
    final a = analysis([('a', 100, 1)]);
    final result = distribute(a, income({2: 20000}));
    expect(result.payments.single.date, day(2));
    final plan = WeeklyExpensePlan(
      week: day(0),
      payments: result.payments,
      openingCash: 0,
      openingFiscal: 0,
    );
    final report = weeklyPaymentPressure(
      plan: plan,
      income: income({2: 20000}),
      now: day(0),
      analysis: a,
    );
    expect(
      report.warnings.any((w) => w.contains('1 pagos tienen fecha posterior')),
      true,
    );
    expect(report.days[2].closing['FISCAL'], 10000);
    expect(report.days.every((d) => d.shortfall == 0), true);
    // Later abundant income must not postpone an affordable on-time payment.
    expect(
      distribute(a, income({0: 10000, 4: 100000})).payments.single.date,
      day(0),
    );
  });
  test(
    'cash cannot fund Fiscal, unclassified or undated income cannot create liquidity',
    () {
      final a = analysis([('a', 100, 1)]);
      for (final i in [
        income({0: 100000}, type: 'EFECTIVO'),
        income({0: 100000}, type: 'MIXTO'),
        income({}, financing: 100000, undated: 100000),
      ]) {
        final result = distribute(a, i);
        expect(result.payments.single.date, day(1));
        final report = weeklyPaymentPressure(
          plan: WeeklyExpensePlan(
            week: day(0),
            payments: result.payments,
            openingCash: 0,
            openingFiscal: 0,
          ),
          income: i,
          now: day(0),
        );
        expect(report.days[1].closing['FISCAL'], -10000);
      }
    },
  );
  test(
    'reserves manual commitments and Menudeo before choosing an affordable day',
    () {
      final a = analysis([('a', 60, 1)]);
      final row = paymentProposal(a).single.copyWith(paymentType: 'EFECTIVO');
      final locked = ProjectedPayment(
        id: 'manual',
        source: 'manual',
        payee: 'Manual',
        reference: 'Reserva',
        account: '',
        date: day(2),
        amount: 8000,
        available: 8000,
        paymentType: 'EFECTIVO',
      );
      for (final menudeo in [false, true]) {
        final plan = WeeklyExpensePlan(
          week: day(0),
          openingCash: 10000,
          openingFiscal: 0,
          payments: [row, if (!menudeo) locked],
          menudeoPayments: [if (menudeo) locked],
        );
        final result = distribute(
          a,
          income({4: 5000}, type: 'EFECTIVO'),
          plan: plan,
        );
        expect(result.payments.first.date, day(4));
        expect(result.payments.first.amount, 6000);
        if (!menudeo) expect(result.payments.last.toJson(), locked.toJson());
      }
    },
  );
  test(
    'manual edits, exclusions, removals and unclassified payments are preserved',
    () {
      final a = analysis([
        ('a', 50, 1),
        ('b', 60, 1),
        ('c', 70, 1),
        ('d', 80, 1),
      ]);
      final rows = paymentProposal(a);
      final protected = [
        rows[0].copyWith(
          selectionAutomatic: false,
          notes: 'Mantener',
          date: day(1),
        ),
        rows[1].copyWith(included: false),
        rows[2].copyWith(removed: true),
        rows[3].copyWith(paymentType: 'SIN_CLASIFICAR'),
      ];
      final result = distribute(
        a,
        income({4: 500000}),
        plan: WeeklyExpensePlan(week: day(0), payments: protected),
      );
      expect(
        result.payments.map((p) => p.toJson()),
        protected.map((p) => p.toJson()),
      );
    },
  );
  test(
    'current week never assigns past dates or spends overdue receipts as if already collected',
    () {
      final a = analysis([('a', 100, 0)]);
      final i = income({0: 100000, 4: 15000});
      final result = distribute(a, i, now: 2);
      expect(result.payments.single.date, day(4));
      final plan = WeeklyExpensePlan(
        week: day(0),
        openingCash: 0,
        openingFiscal: 0,
        payments: result.payments,
      );
      final report = weeklyPaymentPressure(plan: plan, income: i, now: day(2));
      expect(report.days.take(2).every((d) => d.elapsed), true);
      expect(report.warnings.any((w) => w.contains('anterior a hoy')), true);
      expect(report.days.last.closing['FISCAL'], 5000);
      final past = distribute(a, i, now: 8);
      expect(past.payments.single.date, paymentProposal(a).single.date);
      expect(past.moved, 0);
    },
  );
  test(
    'missing opening is reported, and a weekly shortfall does not silently exclude or split debt',
    () {
      final a = analysis([('a', 300, 1)]);
      final original = WeeklyExpensePlan(
        week: day(0),
        payments: paymentProposal(a),
      );
      final i = income({3: 10000});
      final result = distribute(a, i, plan: original);
      expect(result.payments.single.amount, 30000);
      expect(result.payments.single.included, true);
      final report = weeklyPaymentPressure(
        plan: original.copyWith(payments: result.payments),
        income: i,
        now: day(0),
      );
      expect(report.openingComplete, false);
      expect(report.warnings.any((w) => w.contains('saldo inicial')), true);
      expect(report.days.last.closing['FISCAL'], -20000);
    },
  );
  test(
    'automatic fixed payments also move when their channel receives funds',
    () {
      final a = FinanceWeeklyBudgetAnalysis(
        b.budgetSource(
          fixedPayments: [
            b.fixed('fixed', 100, day(1).toIso8601String(), method: 'EFECTIVO'),
          ],
        ),
        day(0),
        targetWeek: day(0),
      );
      expect(
        distribute(
          a,
          income({4: 10000}, type: 'EFECTIVO'),
        ).payments.single.date,
        day(4),
      );
    },
  );

  Future<void> size(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget harness(
    fixtures.MemoryProjectionRepository repo,
    ScheduleIncomeRepository incomes, {
    GlobalKey? boundary,
  }) => ui_fixtures.app(
    RepaintBoundary(
      key: boundary,
      child: WeeklyProjectionView(
        bundle: f.incomeBundle(shipments: []),
        repository: repo,
        incomeRepository: incomes,
        flow: false,
        active: true,
        clock: () => day(0),
        onWeekChanged: (_) async {},
      ),
    ),
  );
  testWidgets(
    'generate refreshes receipts, saves the chosen day, flags lateness and preserves dates on silent refresh',
    (tester) async {
      await size(tester);
      final repo = fixtures.MemoryProjectionRepository()
        ..sourceOverride = b.budgetSource(
          invoices: [b.invoice('i', 100, day(1).toIso8601String())],
        );
      repo.saved[day(0)] = WeeklyExpensePlan(
        week: day(0),
        openingCash: 0,
        openingFiscal: 0,
      );
      final incomes = ScheduleIncomeRepository();
      final boundary = GlobalKey();
      await tester.pumpWidget(harness(repo, incomes, boundary: boundary));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('projection-opening')), findsOneWidget);
      incomes.receiptDay =
          4; // Generate must re-read, not reuse the tab's snapshot.
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      expect(repo.saved[day(0)]!.payments.single.date, day(4));
      expect(incomes.reads, greaterThanOrEqualTo(2));
      expect(find.text('Pago tardío · vencimiento 2026-09-22'), findsOneWidget);
      await tester.tap(find.text('Distribución diaria de pagos'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresos previstos'), findsOneWidget);
      expect(find.text('Vie 2026-09-25'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['DICSA_SCHEDULE_QA'] == '1') {
        await tester.runAsync(() async {
          final picture =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '/private/tmp/dicsa-payment-pressure.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      incomes.receiptDay = 3;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(repo.saved[day(0)]!.payments.single.date, day(4));
      expect(repo.writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed income read during generation saves no new dates or payments',
    (tester) async {
      await size(tester);
      final repo = fixtures.MemoryProjectionRepository();
      final incomes = ScheduleIncomeRepository();
      await tester.pumpWidget(harness(repo, incomes));
      await tester.pumpAndSettle();
      incomes.fail = true;
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      expect(
        find.textContaining('No se pudieron leer los ingresos'),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
