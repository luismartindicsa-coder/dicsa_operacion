import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/direction/expected_income/expected_income_engine.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_pdf_test.dart' as pdf;
import 'expected_income_test.dart' as f;

ProjectedPayment expense(
  String id,
  String source,
  int amount, {
  String type = 'EFECTIVO',
  bool included = true,
  bool removed = false,
}) => ProjectedPayment(
  id: id,
  source: source,
  payee: 'BENEFICIARIO $id',
  reference: 'REF-PAGO-$id',
  account: 'DICSA|CELAYA',
  date: f.incomeWeek,
  amount: amount,
  available: amount,
  paymentType: type,
  included: included,
  removed: removed,
);

WeeklyExpensePlan plan() => WeeklyExpensePlan(
  week: f.incomeWeek,
  revision: 5,
  generated: true,
  openingCash: 1000000,
  openingFiscal: 2000000,
  payments: [
    expense('FACTURA', 'invoice', 1250000, type: 'FISCAL'),
    expense('MANUAL', 'manual', 250000),
    expense('TICKET-EXCLUIDO', 'ticket', 999999, type: 'SIN_CLASIFICAR'),
    expense('NO-INCLUIDO', 'manual', 777777, included: false),
    expense('BORRADO', 'invoice', 888888, removed: true),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'income detail reconciles partial collections, Mayoreo and one Palomar draw',
    () {
      final report = WeeklyCashFlowReport(
        pdf.reportFixture().projection,
        plan(),
      );
      expect(report.incomes, hasLength(7));
      expect(report.flow.income.total, 62685000);
      expect(report.incomes.fold<int>(0, (s, r) => s + r.amount), 62685000);
      expect(
        report.incomes.singleWhere((r) => r.id == 'shipment:real').amount,
        2500000,
      );
      expect(
        report.incomes.singleWhere((r) => r.id == 'collection:prior').amount,
        900000,
      );
      expect(
        report.incomes.any(
          (r) =>
              r.id == 'collection:next' ||
              r.id == 'shipment:sanluis' ||
              r.id == 'shipment:cancel' ||
              r.id == 'shipment:unknown',
        ),
        false,
      );
      final financing = report.incomes.where((r) => r.financing).toList();
      expect(financing, hasLength(2));
      expect(financing.every((r) => r.date == null), true);
      expect(financing.fold<int>(0, (s, r) => s + r.amount), 40000000);
      expect(report.incomes.any((r) => r.id == 'shipment:palomar'), false);
    },
  );

  test(
    'expense tickets, exclusions and removals never affect printed flow or channel balances',
    () {
      final original = plan();
      final report = WeeklyCashFlowReport(
        pdf.reportFixture().projection,
        original,
      );
      expect(report.flow.expenses, 1500000);
      expect(report.flow.net, 61185000);
      expect(report.flow.closing, 64185000);
      expect(report.flow.classified, true);
      expect(report.flow.closingFor('EFECTIVO'), 33025000);
      expect(report.flow.closingFor('FISCAL'), 31160000);
      expect(report.flow.plan.scheduledPayments.length, 2);
      expect(
        original.total,
        2499999,
        reason: 'Export does not modify the saved plan',
      );
    },
  );

  test(
    'inconsistent income detail blocks export instead of inventing a balancing amount',
    () {
      final base = pdf.reportFixture().projection;
      final inconsistent = ExpectedIncomeProjection(
        rows: base.rows,
        collections: base.collections,
        current: IncomeTotals()..add('FISCAL', 1),
        next: base.next,
        later: base.later,
        overdue: base.overdue,
        undated: base.undated,
        timeline: base.timeline,
        palomar: base.palomar,
        warnings: base.warnings,
      );
      expect(
        () => WeeklyCashFlowReport(inconsistent, plan()),
        throwsStateError,
      );
    },
  );

  test(
    'a shipment already linked to Mayoreo appears only once in the printed detail',
    () {
      final week = f.incomeWeek;
      final projection = projectExpectedIncome(
        bundle: f.incomeBundle(
          shipments: [f.incomeShipment(id: 'linked', status: 'embarcado')],
        ),
        data: ExpectedIncomeData(
          materials: f.incomeMaterials,
          clients: f.incomeClients,
          links: const {'linked': 'sale-linked'},
          sales: [
            IncomeSale(
              id: 'sale-linked',
              client: 'RICARDO MENDIETA',
              material: 'PACA_NACIONAL',
              ticket: 'REM-UNICA',
              date: week,
              dueDate: week,
              approvedCents: 100000,
              paidCents: 25000,
              paymentType: 'EFECTIVO',
            ),
          ],
          collections: [
            MayoreoExpectedCollection(
              accountId: 'sale-linked',
              client: 'RICARDO MENDIETA',
              material: 'PACA_NACIONAL',
              document: 'REM-UNICA',
              saleDate: week,
              dueDate: week,
              pendingCents: 75000,
            ),
          ],
        ),
        now: week,
      );
      final report = WeeklyCashFlowReport(projection, plan());
      expect(report.incomes, hasLength(1));
      expect(report.incomes.single.amount, 75000);
      expect(report.flow.income.total, 75000);
    },
  );

  for (final scenario in ['normal', 'long', 'empty', 'mixed']) {
    test(
      'detailed flow PDF preserves references and classifications: $scenario',
      () async {
        var projection = pdf.reportFixture().projection;
        var expenses = plan();
        if (scenario == 'empty') {
          projection = f.forecast(bundle: f.incomeBundle(shipments: []));
          expenses = WeeklyExpensePlan(
            week: f.incomeWeek,
            generated: true,
            openingCash: 0,
            openingFiscal: 0,
          );
        } else if (scenario == 'mixed') {
          projection = f.forecast(
            data: f.incomeData(
              clients: const [
                IncomeClientRule(
                  key: 'RICARDO MENDIETA',
                  name: 'RICARDO MENDIETA',
                  paymentType: 'MIXTO',
                  termUnit: 'INMEDIATO',
                ),
              ],
            ),
          );
        } else if (scenario == 'long') {
          projection = projectExpectedIncome(
            bundle: f.incomeBundle(shipments: []),
            data: ExpectedIncomeData(
              collections: [
                MayoreoExpectedCollection(
                  accountId: 'long',
                  client:
                      'INICIO CLIENTE ${List.filled(40, 'NOMBRE COMERCIAL COMPLETO').join(' ')} FIN CLIENTE',
                  material: 'PACA_NACIONAL',
                  document:
                      'INICIO DOCUMENTO ${List.filled(40, 'FACTURA CON REFERENCIA EXTENSA').join(' ')} FIN DOCUMENTO',
                  saleDate: f.incomeWeek.subtract(const Duration(days: 7)),
                  dueDate: f.incomeWeek,
                  pendingCents: 123456,
                ),
              ],
            ),
            now: f.incomeWeek,
          );
        }
        final report = WeeklyCashFlowReport(projection, expenses);
        if (scenario == 'mixed') {
          expect(report.flow.classified, false);
          expect(report.flow.closingFor('EFECTIVO'), isNull);
        }
        final bytes = await buildWeeklyCashFlowPdf(
          projection,
          expenses,
          generatedAt: f.incomeWeek,
        );
        expect(pdf.pages(bytes), greaterThan(1));
        if (Platform.environment['DICSA_FLOW_QA'] == '1') {
          await File(
            '/private/tmp/dicsa-flow-detail-$scenario.pdf',
          ).writeAsBytes(bytes);
          await File(
            '/private/tmp/dicsa-flow-detail-$scenario.json',
          ).writeAsString(
            jsonEncode({
              'income': report.flow.income.total,
              'expenses': report.flow.expenses,
              'net': report.flow.net,
              'closing': report.flow.closing,
              'incomes': [
                for (final r in report.incomes)
                  {
                    'client': r.client,
                    'reference': r.reference,
                    'amount': r.amount,
                    'financing': r.financing,
                  },
              ],
              'payments': report.flow.plan.scheduledPayments
                  .map((p) => p.toJson())
                  .toList(),
            }),
          );
        }
      },
    );
  }
}
