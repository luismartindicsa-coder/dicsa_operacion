import 'dart:io';

import 'package:dicsa_operacion/app/direction/expected_income/expected_income_engine.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_pdf_test.dart' as pdf;
import 'expected_income_test.dart' as f;
import 'weekly_cash_flow_report_test.dart' as r;

DateTime day(int offset) => f.incomeWeek.add(Duration(days: offset));

ExpectedIncomeProjection receipts(List<(String, int, int)> values) =>
    projectExpectedIncome(
      bundle: f.incomeBundle(
        shipments: [
          for (var i = 0; i < values.length; i++)
            f.incomeShipment(id: '$i', day: values[i].$2, status: 'embarcado'),
        ],
      ),
      data: ExpectedIncomeData(
        materials: f.incomeMaterials,
        clients: f.incomeClients,
        links: {for (var i = 0; i < values.length; i++) '$i': 'sale-$i'},
        sales: [
          for (var i = 0; i < values.length; i++)
            IncomeSale(
              id: 'sale-$i',
              client: 'RICARDO MENDIETA',
              material: 'PACA_NACIONAL',
              ticket: 'REM-$i',
              date: day(values[i].$2),
              dueDate: day(values[i].$2),
              approvedCents: values[i].$3,
              paidCents: 0,
              paymentType: values[i].$1,
            ),
        ],
      ),
      now: day(0),
    );

WeeklyExpensePlan dailyPlan() => WeeklyExpensePlan(
  week: day(0),
  generated: true,
  openingCash: 1000000,
  openingFiscal: 0,
  payments: [
    r.expense('cash-mon', 'manual', 600000),
    r.expense('cash-tue', 'manual', 600000).copyWith(date: day(1)),
    r
        .expense('fiscal-tue', 'invoice', 100000, type: 'FISCAL')
        .copyWith(date: day(1)),
    r
        .expense('fiscal-wed', 'invoice', 200000, type: 'FISCAL')
        .copyWith(date: day(2)),
    r.expense('ticket', 'ticket', 99999999),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('same-day receipts, carry-over and independent channel shortfalls', () {
    final report = WeeklyCashFlowReport(
      receipts([('EFECTIVO', 2, 500000), ('FISCAL', 1, 1000000)]),
      dailyPlan(),
    );
    final calendar = WeeklyCashFlowCalendar(report, day(0));
    final days = calendar.pressure.days;
    // A negative daily net still leaves funds from the opening balance.
    expect(days[0].income['EFECTIVO'], 0);
    expect(days[0].expenses['EFECTIVO'], 600000);
    expect(calendar.closingFor(days[0], 'EFECTIVO'), 400000);
    expect(calendar.statusFor(days[0], 'EFECTIVO'), DailyFlowStatus.sufficient);
    // Fiscal surplus cannot cover an Efectivo shortfall.
    expect(calendar.closingFor(days[1], 'EFECTIVO'), -200000);
    expect(calendar.statusFor(days[1], 'EFECTIVO'), DailyFlowStatus.shortfall);
    expect(calendar.closingFor(days[1], 'FISCAL'), 900000);
    expect(calendar.statusFor(days[1], 'FISCAL'), DailyFlowStatus.sufficient);
    expect(calendar.closingFor(days[2], 'EFECTIVO'), 300000);
    expect(calendar.closingFor(days[6], 'FISCAL'), 700000);
    for (final type in ['EFECTIVO', 'FISCAL']) {
      expect(calendar.closingFor(days[6], type), report.flow.closingFor(type));
    }
    expect(days.fold<int>(0, (s, d) => s + d.payments), report.flow.expenses);
    expect(
      days.fold<int>(0, (s, d) => s + d.receipts),
      report.flow.income.total,
    );
    expect(dailyPlan().payments, hasLength(5));
  });

  test('Palomar reconciles weekly without inventing a daily draw date', () {
    final report = WeeklyCashFlowReport(
      pdf.reportFixture().projection,
      r.plan(),
    );
    final calendar = WeeklyCashFlowCalendar(report, day(0));
    expect(calendar.undated.total, 40000000);
    expect(calendar.undated.byType['EFECTIVO'], 19800000);
    expect(calendar.undated.byType['FISCAL'], 20200000);
    for (final type in ['EFECTIVO', 'FISCAL']) {
      expect(
        calendar.closingFor(calendar.pressure.days.last, type)! +
            calendar.undated.byType[type]!,
        report.flow.closingFor(type),
      );
    }
  });

  test('current week reserves old payments and flags old receipts', () {
    final report = WeeklyCashFlowReport(
      receipts([('EFECTIVO', 0, 500000), ('FISCAL', 3, 1000000)]),
      dailyPlan(),
    );
    final calendar = WeeklyCashFlowCalendar(report, day(2));
    expect(calendar.earlier.total, 500000);
    expect(calendar.earlierPayments, 1300000);
    expect(calendar.pressure.days.take(2).every((d) => d.elapsed), true);
    expect(calendar.pressure.days[2].expenses['EFECTIVO'], 1200000);
    expect(calendar.closingFor(calendar.pressure.days[2], 'EFECTIVO'), -200000);
    expect(calendar.closingFor(calendar.pressure.days[2], 'FISCAL'), -300000);
    expect(
      calendar.pressure.days.fold<int>(0, (s, d) => s + d.payments),
      report.flow.expenses,
    );
  });

  test(
    'missing balance, classification or proposal never claims sufficiency',
    () {
      final income = receipts([]);
      final missing = WeeklyCashFlowCalendar(
        WeeklyCashFlowReport(
          income,
          WeeklyExpensePlan(week: day(0), generated: true, openingFiscal: 0),
        ),
        day(0),
      );
      expect(missing.closingFor(missing.pressure.days[0], 'EFECTIVO'), isNull);
      expect(
        missing.statusFor(missing.pressure.days[0], 'EFECTIVO'),
        DailyFlowStatus.missingOpening,
      );
      expect(
        missing.statusFor(missing.pressure.days[0], 'FISCAL'),
        DailyFlowStatus.sufficient,
      );
      for (final mixedIncome in [false, true]) {
        final calendar = WeeklyCashFlowCalendar(
          WeeklyCashFlowReport(
            receipts(mixedIncome ? [('MIXTO', 0, 100000)] : []),
            dailyPlan().copyWith(
              payments: mixedIncome
                  ? []
                  : [
                      r.expense(
                        'unclassified',
                        'manual',
                        100000,
                        type: 'SIN_CLASIFICAR',
                      ),
                    ],
            ),
          ),
          day(0),
        );
        expect(
          calendar.closingFor(calendar.pressure.days[0], 'FISCAL'),
          isNull,
        );
        expect(
          calendar.statusFor(calendar.pressure.days[0], 'FISCAL'),
          DailyFlowStatus.unclassified,
        );
      }
      final incomplete = WeeklyCashFlowCalendar(
        WeeklyCashFlowReport(income, dailyPlan().copyWith(generated: false)),
        day(0),
      );
      expect(
        incomplete.statusFor(incomplete.pressure.days[0], 'EFECTIVO'),
        DailyFlowStatus.incomplete,
      );
    },
  );

  test('completed week has no fabricated historical closing balances', () {
    final calendar = WeeklyCashFlowCalendar(
      WeeklyCashFlowReport(receipts([]), dailyPlan()),
      day(8),
    );
    expect(calendar.pressure.days.every((d) => d.elapsed), true);
    for (final d in calendar.pressure.days) {
      expect(calendar.closingFor(d, 'EFECTIVO'), isNull);
      expect(calendar.statusFor(d, 'FISCAL'), DailyFlowStatus.elapsed);
    }
  });

  for (final scenario in [
    'shortfall',
    'midweek',
    'missing',
    'unknown',
    'past',
  ]) {
    test('daily comparison PDF renders $scenario', () async {
      var income = receipts([('EFECTIVO', 2, 500000), ('FISCAL', 1, 1000000)]);
      var plan = dailyPlan();
      if (scenario == 'missing') {
        plan = WeeklyExpensePlan(
          week: day(0),
          generated: true,
          openingFiscal: 0,
        );
      } else if (scenario == 'unknown') {
        income = receipts([('MIXTO', 0, 100000)]);
        plan = plan.copyWith(
          payments: [
            r.expense('unknown', 'manual', 50000, type: 'SIN_CLASIFICAR'),
          ],
        );
      }
      final bytes = await buildWeeklyCashFlowPdf(
        income,
        plan,
        generatedAt: day(
          scenario == 'midweek'
              ? 2
              : scenario == 'past'
              ? 8
              : 0,
        ),
      );
      expect(pdf.pages(bytes), greaterThanOrEqualTo(3));
      if (Platform.environment['DICSA_FLOW_QA'] == '1') {
        await File(
          '/private/tmp/dicsa-flow-daily-$scenario.pdf',
        ).writeAsBytes(bytes);
      }
    });
  }
}
