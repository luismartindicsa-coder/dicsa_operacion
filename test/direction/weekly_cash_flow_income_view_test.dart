import 'dart:io';

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_collections_test.dart' as c;
import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as v;
import 'expected_income_pdf_test.dart' as pdf;
import 'weekly_projection_view_test.dart' as p;
import 'weekly_cash_flow_income_test.dart' as flow;

class ReceiptRepository extends ExpectedIncomeRepository {
  int cashDay = 6;
  double paid = 4000;
  @override
  Future<ExpectedIncomeData> load(
    DirectionShipmentPlanningBundle bundle, {
    DateTime? now,
  }) async => ExpectedIncomeData(
    collections: mayoreoExpectedCollections(
      [c.account(id: 'bio', client: 'BIO PAPEL', due: '2026-09-18')],
      {'bio': paid},
    ),
    palomarConfig: const PalomarIncomeConfig(
      creditLimit: 400000,
      drawAmount: 400000,
      cashCheck1: 99000,
      cashCheck2: 99000,
    ),
    palomarSchedule: PalomarReceiptSchedule(
      week: f.incomeWeek,
      cashDate: flow.day(cashDay),
      fiscalDate: flow.day(1),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final name in ['Roboto', 'Ahem']) {
      await (FontLoader(name)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  testWidgets(
    'flow shows overdue detail in one click and refreshes payments and Sunday dates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final receipts = ReceiptRepository();
      final repo = p.MemoryProjectionRepository()
        ..saved[f.incomeWeek] = flow.plan();
      await tester.pumpWidget(
        v.app(
          WeeklyProjectionView(
            bundle: f.incomeBundle(shipments: []),
            onWeekChanged: (_) async {},
            active: true,
            flow: true,
            repository: repo,
            incomeRepository: receipts,
            clock: () => f.incomeWeek,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$208,000.00'), findsWidgets);
      final overdue = find.byKey(const ValueKey('flow-overdue-receipts'));
      await tester.ensureVisible(overdue);
      await tester.tap(find.text(r'Cobros vencidos incluidos · $6,000.00'));
      await tester.pumpAndSettle();
      expect(find.textContaining('BIO PAPEL'), findsOneWidget);
      expect(find.textContaining('2026-09-18'), findsOneWidget);
      expect(
        find.textContaining(r'$198,000.00 programados para el domingo'),
        findsOneWidget,
      );
      await tester.binding.setSurfaceSize(const Size(780, 1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      receipts.paid = 10000;
      receipts.cashDay = 5;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-overdue-receipts')), findsNothing);
      expect(find.text(r'$208,000.00'), findsNothing);
      expect(find.text(r'$400,000.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'PDF exports reconciled Sunday exclusion and prior overdue balance',
    () async {
      final source = flow.projection(
        collections: mayoreoExpectedCollections(
          [c.account(id: 'bio', client: 'BIO PAPEL', due: '2026-09-18')],
          {'bio': 4000},
        ),
      );
      final bytes = await buildWeeklyCashFlowPdf(
        source,
        flow.plan(),
        generatedAt: f.incomeWeek,
      );
      expect(pdf.pages(bytes), greaterThan(1));
    },
  );
}
