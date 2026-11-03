import 'package:dicsa_operacion/app/direction/expected_income/expected_income_collection_report.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_test.dart' as f;

void main() {
  test(
    'next week estimates shipped bales at 750 kg and client material price',
    () {
      final projection = f.forecast(
        bundle: f.incomeBundle(
          shipments: [
            f.incomeShipment(
              client: 'SAN LUIS',
              bales: 40,
              status: 'embarcado',
            ),
          ],
        ),
        data: f.incomeData(prices: {'SAN LUIS|PACA_NACIONAL': 2.8}),
      );
      final row = projection.rows.single;
      expect(row.kilograms, 30000); // Ignores the configured 700 kg average.
      expect(row.valueCents, 8400000);
      expect(row.estimatedFromBales, isTrue);
      expect(row.state, IncomeState.shipped);
      expect(row.collectionDate, DateTime(2026, 9, 28));
      expect(projection.next.byType['FISCAL'], 8400000);
      expect(projection.current.total, 0);
      expect(projection.collected, 0);
    },
  );

  test(
    'an unapproved linked sale uses bales instead of exit weight, minus advances',
    () {
      final projection = f.forecast(
        bundle: f.incomeBundle(
          shipments: [f.incomeShipment(client: 'SAN LUIS', bales: 40)],
        ),
        data: f.incomeData(
          prices: {'SAN LUIS|PACA_NACIONAL': 2.8},
          sales: [
            f.incomeSale(
              client: 'SAN LUIS',
              weight: 28000,
              price: 3,
              amount: null,
              paid: 1000000,
              status: 'pagoParcial',
            ),
          ],
        ),
      );
      final row = projection.rows.single;
      expect(row.kilograms, 30000);
      expect(
        row.price,
        3,
      ); // Price already recorded for this sale takes priority.
      expect(row.valueCents, 9000000);
      expect(row.pendingCents, 8000000);
      expect(projection.next.total, 8000000);
      expect(projection.collected, 1000000);
    },
  );

  test(
    'estimates retain client terms and Mayoreo dates, including overdue dates',
    () {
      final bundle = f.incomeBundle(
        shipments: [f.incomeShipment(client: 'SAN LUIS', status: 'embarcado')],
      );
      for (final due in [DateTime(2026, 9, 23), DateTime(2026, 9, 20)]) {
        final projection = f.forecast(
          bundle: bundle,
          data: f.incomeData(
            sales: [f.incomeSale(client: 'SAN LUIS', amount: null, due: due)],
          ),
        );
        expect(projection.rows.single.collectionDate, due);
        expect(projection.next.total, 0);
        expect(
          due.isBefore(f.incomeWeek)
              ? projection.overdue.total
              : projection.current.total,
          9450000,
        );
      }
      final immediate = f.forecast(
        bundle: f.incomeBundle(
          shipments: [f.incomeShipment(status: 'embarcado')],
        ),
      );
      expect(immediate.current.total, 7875000);
      expect(immediate.next.total, 0);
    },
  );

  test(
    'approval replaces the estimate, preserves partial payments and deduplicates the account',
    () {
      final bundle = f.incomeBundle(
        shipments: [
          f.incomeShipment(client: 'SAN LUIS', bales: 40, status: 'embarcado'),
        ],
      );
      final tables = _tables();
      tables[7].single.addAll({
        'approved_weight': 28000,
        'approved_price': 3,
        'approved_amount': 84000,
      });
      tables[8].single.addAll({
        'approved_weight': 28000,
        'approved_price': 3,
        'approved_amount': 84000,
        'estimated_payment_date': '2026-09-28',
      });
      final data = assembleExpectedIncomeData(
        bundle: bundle,
        today: f.incomeWeek,
        tables: tables,
      );
      expect(data.collections, hasLength(1));
      final projection = f.forecast(bundle: bundle, data: data);
      expect(projection.rows.single.estimatedFromBales, isFalse);
      expect(projection.rows.single.kilograms, 28000);
      expect(projection.generated, 8400000);
      expect(projection.next.total, 7400000);
      expect(projection.collections, isEmpty);
    },
  );

  test(
    'unapproved default zero retains bank advances instead of erasing or doubling them',
    () {
      final bundle = f.incomeBundle(
        shipments: [
          f.incomeShipment(client: 'SAN LUIS', bales: 40, status: 'embarcado'),
        ],
      );
      final tables = _tables();
      final data = assembleExpectedIncomeData(
        bundle: bundle,
        today: f.incomeWeek,
        tables: tables,
      );
      expect(data.sales.single.approvedCents, isNull);
      expect(
        data.sales.single.paidCents,
        1000000,
      ); // Bank replaces manual 2,000.
      final projection = f.forecast(bundle: bundle, data: data);
      expect(projection.rows.single.kilograms, 30000);
      expect(projection.next.total, 8000000);
      expect(projection.collections, isEmpty);

      tables[14].clear();
      final manual = assembleExpectedIncomeData(
        bundle: bundle,
        today: f.incomeWeek,
        tables: tables,
      );
      expect(f.forecast(bundle: bundle, data: manual).next.total, 8800000);
    },
  );

  test(
    'paid, cancelled and explicitly zero-approved sales never create estimated cash',
    () {
      for (final status in ['pagada', 'chequeCanjeado', 'cancelada']) {
        final projection = f.forecast(
          bundle: f.incomeBundle(
            shipments: [
              f.incomeShipment(client: 'SAN LUIS', status: 'embarcado'),
            ],
          ),
          data: f.incomeData(
            sales: [
              f.incomeSale(client: 'SAN LUIS', amount: null, status: status),
            ],
            links: {'s1': 'r1'},
          ),
        );
        expect(projection.next.total, 0);
        expect(projection.rows.single.estimatedFromBales, isFalse);
      }
      final zero = f.forecast(
        data: f.incomeData(sales: [f.incomeSale(amount: 0, price: 0)]),
      );
      expect(zero.rows.single.valueCents, 0);
      expect(zero.rows.single.estimatedFromBales, isFalse);
      expect(zero.current.total, 0);
    },
  );

  test(
    'missing prices stay unvalued; shipped estimates do not require configured bale weight',
    () {
      final bundle = f.incomeBundle(
        shipments: [
          f.incomeShipment(client: 'SAN LUIS', bales: 40, status: 'embarcado'),
        ],
      );
      final missing = f.forecast(
        bundle: bundle,
        data: f.incomeData(materials: []),
      );
      expect(missing.rows.single.valueCents, isNull);
      expect(missing.rows.single.risks, contains('Precio sin definir.'));
      expect(missing.next.total, 0);
      final priced = f.forecast(
        bundle: bundle,
        data: f.incomeData(
          materials: [],
          prices: {'SAN LUIS|PACA_NACIONAL': 2.5},
        ),
      );
      expect(priced.next.total, 7500000);
    },
  );

  test(
    'unshipped plans retain configurable weights and Palomar stays outside ordinary cash',
    () {
      final planned = f.forecast(
        bundle: f.incomeBundle(
          shipments: [f.incomeShipment(client: 'SAN LUIS', bales: 40)],
        ),
      );
      expect(planned.rows.single.kilograms, 28000);
      expect(planned.rows.single.estimatedFromBales, isFalse);
      expect(planned.next.total, 7000000);
      final revolving = f.forecast(
        bundle: f.incomeBundle(
          shipments: [
            f.incomeShipment(
              client: 'EL PALOMAR',
              bales: 40,
              status: 'embarcado',
            ),
          ],
        ),
      );
      expect(revolving.palomar.closing, -7500000);
      expect(revolving.current.total + revolving.next.total, 0);
    },
  );

  test(
    'collection and cash flow details identify estimates and reconcile totals',
    () {
      final projection = f.forecast(
        bundle: f.incomeBundle(
          shipments: [f.incomeShipment(status: 'embarcado')],
        ),
      );
      final report = ExpectedIncomeCollectionReport(
        projection: projection,
        sourceCollections: [],
        week: f.incomeWeek,
        generatedAt: f.incomeWeek,
      );
      expect(report.rows.single.status, 'Estimado · pendiente de Mayoreo');
      report.validate(projection);
      final flow = WeeklyCashFlowReport(
        projection,
        WeeklyExpensePlan(week: f.incomeWeek),
      );
      expect(flow.incomes.single.reference, contains('Importe estimado'));
      expect(flow.incomes.single.amount, 7875000);
    },
  );
}

List<List<Map<String, dynamic>>> _tables() {
  final tables = List.generate(15, (_) => <Map<String, dynamic>>[]);
  tables[0] = f.incomeMaterials.map((r) => r.toJson()).toList();
  tables[1] = f.incomeClients.map((r) => r.toJson()).toList();
  tables[4] = [
    {'id': 'national', 'code': 'PACA_NACIONAL', 'name': 'CARTON NACIONAL'},
  ];
  tables[7] = [
    {
      'id': 'r1',
      'client_name_snapshot': 'SAN LUIS',
      'material_id': 'national',
      'ticket': '123',
      'sale_date': '2026-09-21',
      'exit_weight': 28000,
      'price_snapshot': 3,
      'approved_amount': 0,
    },
  ];
  tables[8] = [
    {
      'id': 'r1',
      'client_name_snapshot': 'SAN LUIS',
      'material_name_snapshot': 'CARTON NACIONAL',
      'sale_date': '2026-09-21',
      'approved_amount': 0,
      'paid_amount': 2000,
      'status': 'pagoParcial',
      'operation_type': 'factura',
    },
  ];
  tables[14] = [
    {
      'id': 'advance',
      'source_type': 'VENTA_FACTURA',
      'linked_external_ref': 'r1',
      'credit_amount': 10000,
    },
  ];
  return tables;
}
