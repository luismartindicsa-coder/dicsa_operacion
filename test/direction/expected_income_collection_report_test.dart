import 'dart:io';

import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_pdf.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_collections_test.dart' as c;
import 'expected_income_pdf_test.dart' as pdf;
import 'expected_income_test.dart' as f;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'linked invoice retains its document and net amount exactly once, with overdue status inside the week',
    () {
      final accounts = mayoreoExpectedCollections(
        [
          c.account(
            id: 'r1',
            client: 'RICARDO MENDIETA',
            saleDate: '2026-09-21',
          ),
          c.account(id: 'prior', due: '2026-09-20'),
          c.account(id: 'future', due: '2026-09-28'),
          c.account(id: 'paid', status: 'pagada'),
          c.account(id: 'cancel', status: 'cancelada'),
          c.account(id: 'undated', due: null),
          c.account(id: 'palomar', client: 'EL PALOMAR'),
        ],
        {'r1': 4000},
      );
      final data = ExpectedIncomePrintData(
        bundle: f.incomeBundle(),
        data: ExpectedIncomeData(
          materials: f.incomeMaterials,
          clients: f.incomeClients,
          collections: accounts,
          sales: [
            f.incomeSale(
              amount: 1000000,
              paid: 400000,
              status: 'pagoParcial',
              due: DateTime(2026, 9, 23),
            ),
          ],
        ),
        generatedAt: DateTime(2026, 9, 24, 11),
      );
      final report = data.collectionReport;
      expect(report.rows, hasLength(1));
      expect(report.rows.single.document, 'F-18');
      expect(report.rows.single.pendingCents, 600000);
      expect(report.rows.single.status, 'Vencido');
      expect(report.rows.single.date, DateTime(2026, 9, 23));
      expect(report.expected, isEmpty);
      report.validate(data.projection);
    },
  );

  test(
    'includes all materials and Sunday, marks today, and separates unshipped income',
    () {
      final data = ExpectedIncomePrintData(
        bundle: f.incomeBundle(),
        data: ExpectedIncomeData(
          materials: f.incomeMaterials,
          clients: f.incomeClients,
          collections: mayoreoExpectedCollections([
            c.account(
              id: 'monday',
              material: 'PESADO',
              client: 'CLIENTE ACERO',
              due: '2026-09-21',
            ),
            c.account(
              id: 'sunday',
              material: 'REBABA',
              client: 'CLIENTE REBABA',
              due: '2026-09-27',
            ),
          ], {}),
        ),
        generatedAt: f.incomeWeek,
      );
      final report = data.collectionReport;
      expect(report.receivables, hasLength(2));
      expect(report.receivables.first.material, 'PESADO');
      expect(report.receivables.first.status, 'Cobrar hoy');
      expect(report.receivables.last.date, DateTime(2026, 9, 27));
      expect(report.expected.single.status, 'Por embarcar');
      expect(report.total, data.projection.current.salesTotal);
    },
  );

  test(
    'PDF refuses a collection breakdown that no longer matches its summary',
    () async {
      final data = pdf.reportFixture();
      data.projection.current.add('FISCAL', 1);
      await expectLater(buildExpectedIncomePdf(data), throwsStateError);
    },
  );

  test(
    'many invoices and long names paginate without dropping the last document or balances',
    () async {
      final data = ExpectedIncomePrintData(
        bundle: f.incomeBundle(shipments: []),
        data: ExpectedIncomeData(
          collections: [
            for (var i = 0; i < 210; i++)
              MayoreoExpectedCollection(
                accountId: 'a-$i',
                client: i == 0
                    ? '${List.filled(60, 'CLIENTE CON RAZÓN SOCIAL EXTENSA').join(' ')} FIN_CLIENTE'
                    : 'CLIENTE $i',
                document: i == 0
                    ? '${List.filled(50, 'FACTURA REFERENCIA').join(' ')} FIN_DOCUMENTO'
                    : 'FACT-${i.toString().padLeft(4, '0')}',
                material: i == 0
                    ? '${List.filled(20, 'MATERIAL DE PRUEBA').join(' ')} FIN_MATERIAL'
                    : 'PESADO',
                saleDate: f.incomeWeek.subtract(const Duration(days: 7)),
                dueDate: f.incomeWeek.add(Duration(days: i % 7)),
                pendingCents: 100001 + i,
              ),
          ],
        ),
        generatedAt: f.incomeWeek.add(const Duration(days: 3)),
      );
      expect(data.collectionReport.receivables, hasLength(210));
      expect(data.collectionReport.total, 21022155);
      final bytes = await buildExpectedIncomePdf(data);
      expect(pdf.pages(bytes), greaterThan(4));
      if (Platform.environment['DICSA_INCOME_PDF_QA'] == '1') {
        await File(
          '/private/tmp/dicsa-income-collection-stress.pdf',
        ).writeAsBytes(bytes);
      }
    },
  );
}
