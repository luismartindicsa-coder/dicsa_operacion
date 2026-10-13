import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_engine.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_forms.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_pdf.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_view.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_payment_schedule.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as b;
import 'expected_income_test.dart' as f;
import 'expected_income_pdf_test.dart' as p;
import 'expected_income_view_test.dart' as v;

DateTime day(int n) => f.incomeWeek.add(Duration(days: n));
PalomarReceiptSchedule schedule({int? cash = 3, int? fiscal = 1}) =>
    PalomarReceiptSchedule(
      week: day(0),
      cashDate: cash == null ? null : day(cash),
      fiscalDate: fiscal == null ? null : day(fiscal),
    );
ExpectedIncomeData data(
  PalomarReceiptSchedule? dates, {
  bool blocked = false,
}) => ExpectedIncomeData(
  palomarConfig: const PalomarIncomeConfig(
    creditLimit: 400000,
    drawAmount: 400000,
    cashCheck1: 99000,
    cashCheck2: 99000,
  ),
  palomarSchedule: dates,
  palomarMovements: [
    if (blocked)
      PalomarIncomeMovement(
        id: 'actual',
        date: day(0),
        signedCents: 50000000,
        concept: 'CHEQUE',
      ),
  ],
);
ExpectedIncomeProjection forecast(
  PalomarReceiptSchedule? dates, {
  bool blocked = false,
}) => projectExpectedIncome(
  bundle: f.incomeBundle(shipments: []),
  data: data(dates, blocked: blocked),
  now: day(0),
);
WeeklyExpensePlan plan() => WeeklyExpensePlan(
  week: day(0),
  generated: true,
  openingCash: 0,
  openingFiscal: 0,
);

class ScheduleRepository extends ExpectedIncomeRepository {
  final schedules = <DateTime, PalomarReceiptSchedule>{};
  int reads = 0;
  bool failSave = false;
  @override
  Future<ExpectedIncomeData> load(
    DirectionShipmentPlanningBundle bundle, {
    DateTime? now,
  }) async {
    reads++;
    return data(schedules[bundle.weekStartDate]);
  }

  @override
  Future<void> savePalomarSchedule(PalomarReceiptSchedule s) async {
    if (failSave) throw StateError('No se pudo guardar la fecha');
    schedules[s.week] = PalomarReceiptSchedule(
      week: s.week,
      cashDate: s.cashDate,
      fiscalDate: s.fiscalDate,
      revision: s.revision + 1,
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

  test('weekly dates fund each channel once and preserve weekly totals', () {
    final income = forecast(schedule());
    expect(income.current.total, 40000000);
    expect(income.current.salesTotal, 0);
    expect(income.timeline.keys.toSet(), {day(1), day(3)});
    expect(income.timeline[day(1)]!.financingByType['FISCAL'], 20200000);
    expect(income.timeline[day(3)]!.financingByType['EFECTIVO'], 19800000);
    final report = WeeklyCashFlowReport(income, plan());
    expect(report.incomes, hasLength(2));
    expect(
      report.incomes.singleWhere((r) => r.type == 'EFECTIVO').date,
      day(3),
    );
    final calendar = WeeklyCashFlowCalendar(report, day(0));
    expect(calendar.undated.total, 0);
    expect(calendar.closingFor(calendar.pressure.days[0], 'FISCAL'), 0);
    expect(calendar.closingFor(calendar.pressure.days[1], 'FISCAL'), 20200000);
    expect(calendar.closingFor(calendar.pressure.days[2], 'EFECTIVO'), 0);
    expect(
      calendar.closingFor(calendar.pressure.days[3], 'EFECTIVO'),
      19800000,
    );
    expect(
      calendar.pressure.warnings.any(
        (w) => w.contains('sin fecha de recepción'),
      ),
      false,
    );
    expect(income.next.total + income.later.total, 0);
  });

  test(
    'moving, partial dates, same-day dates and clearing never duplicate financing',
    () {
      for (final s in [
        schedule(cash: 1, fiscal: 1),
        schedule(cash: 6, fiscal: 0),
        schedule(cash: null),
        schedule(cash: null, fiscal: null),
      ]) {
        final income = forecast(s);
        final calendar = WeeklyCashFlowCalendar(
          WeeklyCashFlowReport(income, plan()),
          day(0),
        );
        expect(income.current.total, 40000000);
        expect(
          income.timeline.values.fold<int>(0, (s, d) => s + d.total) +
              calendar.undated.total,
          40000000,
        );
      }
      final partial = forecast(schedule(cash: null));
      expect(partial.palomar.undatedDraw, 19800000);
      expect(partial.timeline[day(1)]!.total, 20200000);
      final legacy = forecast(null);
      expect(legacy.timeline, isEmpty);
      expect(legacy.current.total, 40000000);
    },
  );

  test('dates do not override eligibility or leak into other weeks', () {
    final blocked = forecast(schedule(), blocked: true);
    expect(blocked.current.total, 0);
    expect(blocked.timeline, isEmpty);
    expect(
      forecast(PalomarReceiptSchedule(week: day(7), cashDate: day(8))).timeline,
      isEmpty,
    );
    expect(schedule(cash: -1).valid, false);
    expect(schedule(fiscal: 7).valid, false);
    expect(schedule(cash: null, fiscal: 6).valid, true);
  });

  test(
    'old expected receipts stay outside current daily funds until reprogrammed',
    () {
      final calendar = WeeklyCashFlowCalendar(
        WeeklyCashFlowReport(forecast(schedule()), plan()),
        day(2),
      );
      expect(calendar.earlier.total, 20200000);
      expect(calendar.closingFor(calendar.pressure.days[2], 'FISCAL'), 0);
      expect(
        calendar.closingFor(calendar.pressure.days[3], 'EFECTIVO'),
        19800000,
      );
    },
  );

  test(
    'payment proposal uses Palomar on its date separately for cash and fiscal',
    () {
      final analysis = FinanceWeeklyBudgetAnalysis(
        b.budgetSource(
          invoices: [b.invoice('invoice', 100000, day(0).toIso8601String())],
          fixedPayments: [
            b.fixed(
              'cash',
              100000,
              day(0).toIso8601String(),
              method: 'EFECTIVO',
            ),
          ],
        ),
        day(0),
        targetWeek: day(0),
      );
      final original = plan().copyWith(payments: paymentProposal(analysis));
      final income = forecast(schedule());
      final distributed = distributePaymentsByIncome(
        plan: original,
        income: income,
        analysis: analysis,
        now: day(0),
        allowLatePayments: true,
      );
      expect(
        distributed.payments.singleWhere((r) => r.id == 'invoice:invoice').date,
        day(1),
      );
      expect(
        distributed.payments.singleWhere((r) => r.id == 'fixed:cash').date,
        day(3),
      );
      final calendar = WeeklyCashFlowCalendar(
        WeeklyCashFlowReport(
          income,
          original.copyWith(payments: distributed.payments),
        ),
        day(0),
      );
      expect(calendar.pressure.days.every((d) => d.shortfall == 0), true);
    },
  );

  test('repository adapter restores independent weekly dates and revision', () {
    final tables = List.generate(17, (_) => <Map<String, dynamic>>[]);
    tables[16] = [
      {
        'week_start': '2026-09-21',
        'cash_date': '2026-09-24',
        'fiscal_date': null,
        'revision': 4,
      },
    ];
    final restored = assembleExpectedIncomeData(
      bundle: f.incomeBundle(shipments: []),
      today: day(0),
      tables: tables,
    ).palomarSchedule!;
    expect(restored.cashDate, day(3));
    expect(restored.fiscalDate, isNull);
    expect(restored.revision, 4);
    expect(restored.valid, true);
  });

  test(
    'both PDFs preserve dated Palomar receipts and reconciled totals',
    () async {
      final snapshot = ExpectedIncomePrintData(
        bundle: f.incomeBundle(shipments: []),
        data: data(schedule()),
        generatedAt: day(0),
      );
      final incomePdf = await buildExpectedIncomePdf(snapshot);
      final flowPdf = await buildWeeklyCashFlowPdf(
        snapshot.projection,
        plan(),
        generatedAt: day(0),
      );
      expect(p.pages(incomePdf), 1);
      if (Platform.environment['DICSA_PALOMAR_QA'] == '1') {
        await File(
          '/private/tmp/dicsa-palomar-dated-income.pdf',
        ).writeAsBytes(incomePdf);
        await File(
          '/private/tmp/dicsa-palomar-dated-flow.pdf',
        ).writeAsBytes(flowPdf);
      }
    },
  );

  testWidgets(
    'date picker saves, refreshes calendar and preserves edits on failed save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = ScheduleRepository();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: v.app(
            ExpectedIncomeView(
              bundle: f.incomeBundle(shipments: []),
              repository: repo,
              clock: () => day(0),
              onWeekChanged: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fecha de recepción'));
      await tester.tap(find.text('Fecha de recepción'));
      await tester.pumpAndSettle();
      Future<void> choose(String field, String value) async {
        await tester.tap(find.widgetWithText(OutlinedButton, field));
        await tester.pumpAndSettle();
        final search = find.byType(TextField);
        expect(tester.widget<TextField>(search).focusNode!.hasFocus, true);
        await tester.enterText(search, value);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining(value).last);
        await tester.pumpAndSettle();
      }

      await choose('Recepción Efectivo: Sin fecha', '2026-09-24');
      await choose('Recepción Fiscal: Sin fecha', '2026-09-22');
      final reads = repo.reads;
      await tester.pump(const Duration(seconds: 31));
      expect(repo.reads, reads);
      if (Platform.environment['DICSA_PALOMAR_QA'] == '1') {
        await tester.runAsync(() async {
          final picture =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '/private/tmp/dicsa-palomar-date-dialog.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      repo.failSave = true;
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(IncomeFormDialog), findsOneWidget);
      expect(repo.schedules, isEmpty);
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      repo.failSave = false;
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.schedules[day(0)]!.cashDate, day(3));
      expect(repo.schedules[day(0)]!.fiscalDate, day(1));
      expect(find.text('Recepción EFECTIVO: 2026-09-24'), findsOneWidget);
      expect(find.text('Recepción FISCAL: 2026-09-22'), findsOneWidget);
      expect(find.text('Sin fecha · El Palomar'), findsNothing);
      await tester.ensureVisible(find.text('Fecha de recepción'));
      await tester.tap(find.text('Fecha de recepción'));
      await tester.pumpAndSettle();
      await choose('Recepción Efectivo: 2026-09-24 · Jueves', 'Sin fecha');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.schedules[day(0)]!.cashDate, day(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
