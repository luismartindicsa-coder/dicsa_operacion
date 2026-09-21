import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'expected_income_test.dart' as f;

Map<String, dynamic> account({
  String id = 'prior',
  String status = 'pagoParcial',
  String operation = 'factura',
  Object? due = '2026-09-23T00:00:00+00:00',
  double paid = 1000,
  String saleDate = '2026-09-15',
  String client = 'SAN LUIS',
  String material = 'CARTON NACIONAL',
}) => {
  'id': id,
  'approved_amount': 10000,
  'paid_amount': paid,
  'operation_type': operation,
  'estimated_payment_date': due,
  'status': status,
  'client_name_snapshot': client,
  'material_name_snapshot': material,
  'document_number': 'F-18',
  'sale_date': saleDate,
};

void main() {
  test(
    'Mayoreo uses remaining bank-linked balance instead of adding both payment sources',
    () {
      final result = mayoreoExpectedCollections([account()], {'prior': 4000});
      expect(result.single.pendingCents, 600000);
      expect(result.single.dueDate, DateTime(2026, 9, 23));
    },
  );
  test(
    'native collection eligibility excludes cheques, paid, cancelled, missing dates and zero balances',
    () {
      final rows = [
        account(status: 'pagada'),
        account(status: 'chequeCanjeado'),
        account(status: 'cancelada'),
        account(operation: 'cheque'),
        account(due: null),
        account(paid: 10000),
      ];
      expect(mayoreoExpectedCollections(rows, {}), isEmpty);
    },
  );
  test(
    'previous-week sale due this week adds to current cash, fiscal, committed and client totals',
    () {
      final collections = mayoreoExpectedCollections([account()], {});
      final p = f.forecast(
        data: ExpectedIncomeData(
          materials: f.incomeMaterials,
          clients: f.incomeClients,
          collections: collections,
        ),
      );
      expect(p.current.byType['FISCAL'], 900000);
      expect(p.current.byType['EFECTIVO'], 7350000);
      expect(p.current.total, 8250000);
      expect(p.committed, 900000);
      expect(p.byClient['SAN LUIS'], 900000);
      expect(p.generated, 7350000); // Still only selected-week shipments.
    },
  );
  test(
    'all Mayoreo collection materials are included, even without carton shipment history',
    () {
      final p = f.forecast(
        bundle: f.incomeBundle(shipments: []),
        data: ExpectedIncomeData(
          collections: mayoreoExpectedCollections([
            account(client: 'CLIENTE ACERO', material: 'PESADO'),
          ], {}),
        ),
      );
      expect(p.current.total, 900000);
      expect(p.byMaterial['PESADO'], 900000);
    },
  );
  test(
    'a linked invoice is represented exactly once in the combined forecast',
    () {
      final p = f.forecast(
        data: ExpectedIncomeData(
          materials: f.incomeMaterials,
          clients: f.incomeClients,
          sales: [f.incomeSale(status: 'pagoParcial', paid: 1000000)],
          collections: mayoreoExpectedCollections([
            account(
              id: 'r1',
              client: 'RICARDO MENDIETA',
              saleDate: '2026-09-21',
            ),
          ], {}),
        ),
      );
      expect(p.collections, isEmpty);
      expect(p.current.total, 7400000);
    },
  );
  test(
    'an ambiguous old invoice suppresses overlapping estimates until matched',
    () {
      final p = f.forecast(
        bundle: f.incomeBundle(
          shipments: [
            f.incomeShipment(id: 'a'),
            f.incomeShipment(id: 'b'),
          ],
        ),
        data: ExpectedIncomeData(
          materials: f.incomeMaterials,
          clients: f.incomeClients,
          sales: [f.incomeSale()],
          collections: mayoreoExpectedCollections([
            account(
              id: 'r1',
              client: 'RICARDO MENDIETA',
              saleDate: '2026-09-21',
            ),
          ], {}),
        ),
      );
      expect(p.current.total, 900000);
      expect(p.rows.every((r) => r.cashExcluded), isTrue);
    },
  );
  test(
    'Palomar collection is held in revolving account and not ordinary cash',
    () {
      final p = f.forecast(
        bundle: f.incomeBundle(shipments: []),
        data: ExpectedIncomeData(
          clients: f.incomeClients,
          collections: mayoreoExpectedCollections([
            account(client: 'EL PALOMAR'),
          ], {}),
        ),
      );
      expect(p.current.total, 0);
    },
  );
  test(
    'a previous sale due next week goes to next, overdue is not silently promised for today',
    () {
      final p = f.forecast(
        bundle: f.incomeBundle(shipments: []),
        data: ExpectedIncomeData(
          collections: mayoreoExpectedCollections([
            account(id: 'next', due: '2026-09-29'),
            account(id: 'past', due: '2026-09-20'),
          ], {}),
        ),
      );
      expect(p.current.total, 0);
      expect(p.next.total, 900000);
      expect(p.overdue.total, 900000);
    },
  );
  test(
    'repository adapter includes collection with no associated sales report and linked bank credits',
    () {
      final tables = List.generate(15, (_) => <Map<String, dynamic>>[]);
      tables[8] = [account()];
      tables[14] = [
        {
          'id': 'bank1',
          'source_type': 'VENTA_FACTURA',
          'linked_external_ref': 'prior',
          'credit_amount': 2000,
        },
        {
          'id': 'bank2',
          'source_type': 'VENTA_FACTURA',
          'linked_external_ref': 'prior',
          'credit_amount': 1500,
        },
      ];
      final data = assembleExpectedIncomeData(
        bundle: f.incomeBundle(),
        today: f.incomeWeek,
        tables: tables,
      );
      expect(data.collections.single.pendingCents, 650000);
    },
  );
}
