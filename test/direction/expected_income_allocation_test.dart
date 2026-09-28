import 'dart:io';

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_view.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as ui;
import 'expected_income_pdf_test.dart' as pdf;
import 'weekly_projection_view_test.dart' as flow_ui;

const mixed = IncomeClientRule(
  key: 'RICARDO MENDIETA',
  name: 'RICARDO MENDIETA',
  paymentType: 'MIXTO',
  termUnit: 'INMEDIATO',
);
ExpectedIncomeData data({
  IncomeAllocation? allocation,
  List<IncomeSale> sales = const [],
  List<IncomeClientRule> clients = const [mixed],
}) => ExpectedIncomeData(
  materials: f.incomeMaterials,
  clients: clients,
  sales: sales,
  allocations: allocation == null ? {} : {allocation.shipmentId: allocation},
);
IncomeAllocation split() => f
    .forecast(data: data())
    .rows
    .single
    .distribute(cashCents: 2345678, fiscalCents: 5004322);
WeeklyExpensePlan plan() => WeeklyExpensePlan(
  week: f.incomeWeek,
  openingCash: 10000,
  openingFiscal: 20000,
  generated: true,
);

class MixedRepository extends ExpectedIncomeRepository {
  IncomeAllocation? allocation;
  bool failSave = false;
  int reads = 0, writes = 0;
  @override
  Future<ExpectedIncomeData> load(
    DirectionShipmentPlanningBundle bundle, {
    DateTime? now,
  }) async {
    reads++;
    return data(allocation: allocation);
  }

  @override
  Future<void> saveAllocation(IncomeAllocation value) async {
    if (failSave) throw StateError('No se pudo guardar la distribución');
    writes++;
    allocation = IncomeAllocation(
      shipmentId: value.shipmentId,
      sourceKey: value.sourceKey,
      totalCents: value.totalCents,
      cashCents: value.cashCents,
      fiscalCents: value.fiscalCents,
      revision: value.revision + 1,
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
    'allocation preserves total and updates forecast, timeline and final balances',
    () {
      final before = f.forecast(data: data());
      final p = f.forecast(data: data(allocation: split()));
      expect(before.current.byType['MIXTO'], 7350000);
      expect(p.current.total, before.current.total);
      expect(p.current.byType, {
        'EFECTIVO': 2345678,
        'FISCAL': 5004322,
        'MIXTO': 0,
      });
      expect(p.timeline[f.incomeWeek]!.byType, p.current.byType);
      final flow = WeeklyCashFlow(p.current, plan());
      expect(flow.classified, true);
      expect(flow.closingFor('EFECTIVO'), 2355678);
      expect(flow.closingFor('FISCAL'), 5024322);
      expect(flow.closing, 7380000);
      expect(p.generated, before.generated);
    },
  );
  test(
    'zero on one side is valid; negative or incomplete distributions are rejected',
    () {
      final r = f.forecast(data: data()).rows.single;
      for (final cash in [0, r.pendingCents]) {
        final allocation = r.distribute(
          cashCents: cash,
          fiscalCents: r.pendingCents - cash,
        );
        expect(
          f
              .forecast(data: data(allocation: allocation))
              .current
              .byType['MIXTO'],
          0,
        );
      }
      for (final amounts in [(1, 1), (-1, 7350001), (7350001, -1)]) {
        expect(
          () => r.distribute(cashCents: amounts.$1, fiscalCents: amounts.$2),
          throwsArgumentError,
        );
      }
    },
  );
  test(
    'changed value or linked sale leaves outstanding mixed and requires review',
    () {
      final allocated = split();
      final changed = f.forecast(
        data: data(allocation: allocated),
        bundle: f.incomeBundle(shipments: [f.incomeShipment(bales: 40)]),
      );
      expect(changed.current.byType['MIXTO'], 7000000);
      expect(changed.current.byType['EFECTIVO'], 0);
      expect(changed.rows.single.allocationStale, true);
      expect(
        changed.rows.single.risks.join(),
        contains('revisa la distribución'),
      );
      final sale = IncomeSale(
        id: 'real',
        client: mixed.name,
        material: 'PACA_NACIONAL',
        ticket: 'R-1',
        date: f.incomeWeek,
        approvedCents: 7350000,
        paidCents: 10000,
      );
      final actual = f.forecast(
        data: data(allocation: allocated, sales: [sale]),
      );
      expect(actual.current.byType['MIXTO'], 7340000);
      expect(actual.rows.single.allocationStale, true);
    },
  );
  test(
    'subsequent partial payment invalidates a distribution of the old balance',
    () {
      IncomeSale sale(int paid) => IncomeSale(
        id: 'real',
        client: mixed.name,
        material: 'PACA_NACIONAL',
        ticket: 'R-1',
        date: f.incomeWeek,
        approvedCents: 100000,
        paidCents: paid,
      );
      final r = f.forecast(data: data(sales: [sale(10000)])).rows.single;
      final saved = r.distribute(cashCents: 40000, fiscalCents: 50000);
      final p = f.forecast(
        data: data(sales: [sale(20000)], allocation: saved),
      );
      expect(p.current.byType['MIXTO'], 80000);
      expect(p.rows.single.allocationStale, true);
    },
  );
  test(
    'date changes move the same split to next week; another shipment cannot reuse it',
    () {
      final allocated = split();
      final next = f.forecast(
        data: data(
          allocation: allocated,
          clients: [
            const IncomeClientRule(
              key: 'RICARDO MENDIETA',
              name: 'RICARDO MENDIETA',
              paymentType: 'MIXTO',
              term: 7,
            ),
          ],
        ),
      );
      expect(next.current.total, 0);
      expect(next.next.byType['EFECTIVO'], 2345678);
      expect(next.next.byType['FISCAL'], 5004322);
      final other = f.forecast(
        data: data(allocation: allocated),
        bundle: f.incomeBundle(shipments: [f.incomeShipment(id: 'other')]),
      );
      expect(other.current.byType['MIXTO'], 7350000);
    },
  );
  test(
    'Fiscal sale, cancelled and revolving shipments never reuse an ordinary split',
    () {
      final allocated = split();
      final fiscal = f.forecast(
        data: data(
          allocation: allocated,
          sales: [
            IncomeSale(
              id: 'invoice',
              client: mixed.name,
              material: 'PACA_NACIONAL',
              ticket: 'F-1',
              date: f.incomeWeek,
              approvedCents: 7350000,
              paymentType: 'FISCAL',
            ),
          ],
        ),
      );
      expect(fiscal.current.byType['FISCAL'], 7350000);
      expect(fiscal.rows.single.canAllocate, false);
      final cancelled = f.forecast(
        data: data(allocation: allocated),
        bundle: f.incomeBundle(
          shipments: [f.incomeShipment(status: 'cancelado')],
        ),
      );
      expect(cancelled.current.total, 0);
      final revolving = f.forecast(
        data: data(
          allocation: allocated,
          clients: [
            const IncomeClientRule(
              key: 'RICARDO MENDIETA',
              name: 'RICARDO MENDIETA',
              paymentType: 'MIXTO',
              revolving: true,
            ),
          ],
        ),
      );
      expect(revolving.current.total, 0);
      expect(revolving.rows.single.canAllocate, false);
    },
  );
  test('repository adapter reads persisted split and revision', () {
    final a = split();
    final tables = List.generate(16, (_) => <Map<String, dynamic>>[]);
    tables[0] = f.incomeMaterials.map((r) => r.toJson()).toList();
    tables[1] = [mixed.toJson()];
    tables[15] = [
      {
        'shipment_id': a.shipmentId,
        'source_key': a.sourceKey,
        'total_cents': a.totalCents,
        'cash_cents': a.cashCents,
        'fiscal_cents': a.fiscalCents,
        'revision': 3,
      },
    ];
    final restored = assembleExpectedIncomeData(
      bundle: f.incomeBundle(),
      today: f.incomeWeek,
      tables: tables,
    );
    final row = f.forecast(data: restored).rows.single;
    expect(row.allocationApplied, true);
    expect(row.distribute(cashCents: 0, fiscalCents: 7350000).revision, 3);
  });
  test(
    'both PDFs use the split and flow detail reconciles without duplicate income',
    () async {
      final d = data(allocation: split());
      final p = f.forecast(data: d);
      final report = WeeklyCashFlowReport(p, plan());
      expect(report.incomes, hasLength(2));
      expect(
        {for (final row in report.incomes) row.type: row.amount},
        {'EFECTIVO': 2345678, 'FISCAL': 5004322},
      );
      expect(report.incomes.fold<int>(0, (sum, r) => sum + r.amount), 7350000);
      final flowBytes = await buildWeeklyCashFlowPdf(
        p,
        plan(),
        generatedAt: f.incomeWeek,
      );
      final incomeBytes = await buildExpectedIncomePdf(
        ExpectedIncomePrintData(
          bundle: f.incomeBundle(),
          data: d,
          generatedAt: f.incomeWeek,
        ),
      );
      expect(pdf.pages(flowBytes), greaterThan(1));
      expect(pdf.pages(incomeBytes), 1);
      if (Platform.environment['DICSA_ALLOCATION_QA'] == '1') {
        await File(
          '/private/tmp/dicsa-allocated-flow.pdf',
        ).writeAsBytes(flowBytes);
        await File(
          '/private/tmp/dicsa-allocated-income.pdf',
        ).writeAsBytes(incomeBytes);
      }
    },
  );

  testWidgets(
    'edit, validate, preserve failure draft, save and reload split in flow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = MixedRepository();
      final expenseRepo = flow_ui.MemoryProjectionRepository()
        ..saved[f.incomeWeek] = plan();
      final bundle = f.incomeBundle();
      var flow = false;
      await tester.pumpWidget(
        ui.app(
          StatefulBuilder(
            builder: (context, setLocal) => Column(
              children: [
                TextButton(
                  onPressed: () => setLocal(() => flow = !flow),
                  child: const Text('Cambiar tab'),
                ),
                Expanded(
                  child: IndexedStack(
                    index: flow ? 1 : 0,
                    children: [
                      ExpectedIncomeView(
                        bundle: bundle,
                        repository: repo,
                        clock: () => f.incomeWeek,
                        active: !flow,
                        onWeekChanged: (_) async {},
                      ),
                      WeeklyProjectionView(
                        bundle: bundle,
                        repository: expenseRepo,
                        incomeRepository: repo,
                        clock: () => f.incomeWeek,
                        active: flow,
                        flow: true,
                        onWeekChanged: (_) async {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar tab'));
      await tester.pumpAndSettle();
      expect(find.text('Por distribuir'), findsNWidgets(2));
      await tester.tap(find.text('Cambiar tab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Distribuir ingresos mixtos'));
      await tester.pumpAndSettle();
      final cash = find.byKey(const ValueKey('allocationCash'));
      final fiscal = find.byKey(const ValueKey('allocationFiscal'));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: cash, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        true,
      );
      await tester.enterText(cash, '23456.78');
      await tester.enterText(fiscal, '1');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('deben sumar exactamente'), findsOneWidget);
      expect(repo.writes, 0);
      await tester.enterText(fiscal, '50043.22');
      repo.failSave = true;
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(find.text('23456.78'), findsOneWidget);
      final reads = repo.reads;
      await tester.pump(const Duration(seconds: 31));
      expect(repo.reads, reads, reason: 'refresh deferred while editing');
      repo.failSave = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.allocation!.cashCents, 2345678);
      final bucket = find.byKey(const ValueKey('income-bucket-Esta semana'));
      expect(
        find.descendant(
          of: bucket,
          matching: find.text(r'Por distribuir: $0.00'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cambiar tab'));
      await tester.pumpAndSettle();
      expect(find.text('Por distribuir'), findsNothing);
      expect(find.text(r'$23,556.78'), findsOneWidget);
      expect(find.text(r'$50,243.22'), findsOneWidget);
      await tester.tap(find.text('Cambiar tab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Distribuir ingresos mixtos'));
      await tester.pumpAndSettle();
      expect(find.text('23456.78'), findsOneWidget);
      await tester.enterText(cash, '0');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.allocation!.cashCents, 2345678);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
