import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_engine.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:flutter_test/flutter_test.dart';

final incomeWeek = DateTime(2026, 9, 21);
const incomeMaterials = [
  IncomeMaterialRule('PACA_NACIONAL', 700, 2.50),
  IncomeMaterialRule('PACA_LIMPIA', 700, 2.70),
  IncomeMaterialRule('PACA_AMERICANA', 700, 3.80),
];
const incomeClients = [
  IncomeClientRule(
    key: 'RICARDO MENDIETA',
    name: 'RICARDO MENDIETA',
    paymentType: 'EFECTIVO',
    termUnit: 'INMEDIATO',
  ),
  IncomeClientRule(
    key: 'NEVADO',
    name: 'NEVADO',
    aliases: ['PAPELERA DEL NEVADO'],
    paymentType: 'FISCAL',
    term: 2,
  ),
  IncomeClientRule(
    key: 'SAN LUIS',
    name: 'SAN LUIS',
    paymentType: 'FISCAL',
    termUnit: 'SEMANAS',
    term: 1,
  ),
  IncomeClientRule(
    key: 'EL PALOMAR',
    name: 'EL PALOMAR',
    paymentType: 'MIXTO',
    revolving: true,
  ),
];

DirectionShipmentPlanRecord incomeShipment({
  String id = 's1',
  int day = 0,
  String client = 'RICARDO MENDIETA',
  String material = 'PACA_NACIONAL',
  int bales = 42,
  String status = 'confirmado',
}) => DirectionShipmentPlanRecord.fromRow({
  'id': id,
  'ship_date': programDate(incomeWeek.add(Duration(days: day))),
  'client_name': client,
  'planning_material_code': material,
  'quantity_unit': 'PACAS',
  'planned_units': bales,
  'status': status,
});

DirectionShipmentPlanningBundle incomeBundle({
  List<DirectionShipmentPlanRecord>? shipments,
  Map<String, int> stock = const {},
  bool estimated = false,
}) => DirectionShipmentPlanningBundle(
  weekStartDate: incomeWeek,
  weekEndDate: incomeWeek.add(const Duration(days: 6)),
  shipments: shipments ?? [incomeShipment()],
  projections: [],
  suggestedShipments: [],
  floorCountByMaterial: stock,
  floorCountUpdatedAt: incomeWeek,
  expectedDays: [],
  activeCapacityImpacts: [],
  impactSummaries: [],
  maintenanceAlerts: [],
  suggestionReport: DirectionShipmentSuggestionReport(
    weekStart: incomeWeek,
    generatedAt: incomeWeek,
    suggestions: [],
    coverage: [],
    observations: [],
    intakeFactor: 1,
    operationHistoryCount: 0,
    directionHistoryCount: 0,
    productionRecordCount: 0,
    sourceKey: 'test',
    currentFloorByMaterial: stock,
    openingFloorByMaterial: stock,
    estimatedFloorMaterials: estimated ? stock.keys.toSet() : {},
  ),
);

ExpectedIncomeData incomeData({
  List<IncomeClientRule> clients = incomeClients,
  List<IncomeMaterialRule> materials = incomeMaterials,
  Map<String, double> prices = const {},
  List<IncomeSupply> supplies = const [],
  List<IncomeSale> sales = const [],
  Map<String, String> links = const {},
  Set<String> external = const {},
  PalomarIncomeConfig config = const PalomarIncomeConfig(),
  List<PalomarIncomeMovement> movements = const [],
}) => ExpectedIncomeData(
  materials: materials,
  clients: clients,
  supplies: supplies,
  clientMaterialPrices: prices,
  sales: sales,
  links: links,
  externallyLinkedSales: external,
  palomarConfig: config,
  palomarMovements: movements,
);

ExpectedIncomeProjection forecast({
  DirectionShipmentPlanningBundle? bundle,
  ExpectedIncomeData? data,
  DateTime? now,
}) => projectExpectedIncome(
  bundle: bundle ?? incomeBundle(),
  data: data ?? incomeData(),
  now: now ?? incomeWeek,
);

IncomeSale incomeSale({
  String id = 'r1',
  String client = 'RICARDO MENDIETA',
  int day = 0,
  double? weight = 28000,
  double? price = 3,
  int? amount = 8400000,
  int paid = 0,
  String? status,
  DateTime? due,
}) => IncomeSale(
  id: id,
  ticket: id,
  client: client,
  material: 'PACA_NACIONAL',
  date: incomeWeek.add(Duration(days: day)),
  weight: weight,
  price: price,
  approvedCents: amount,
  paidCents: paid,
  accountStatus: status,
  dueDate: due,
);

void main() {
  test('35 American bales generate 93,100, due two calendar days later', () {
    final p = forecast(
      bundle: incomeBundle(
        shipments: [
          incomeShipment(
            client: 'PAPELERA DEL NEVADO',
            material: 'PACA_AMERICANA',
            bales: 35,
          ),
        ],
      ),
    );
    expect(p.rows.single.valueCents, 9310000);
    expect(p.current.byType['FISCAL'], 9310000);
    expect(p.rows.single.collectionDate, DateTime(2026, 9, 23));
  });
  test('production and stock without shipments never generate revenue', () {
    final p = forecast(
      bundle: incomeBundle(shipments: [], stock: {'PACA_NACIONAL': 1000}),
      data: incomeData(
        supplies: [IncomeSupply(incomeWeek, 'PACA_NACIONAL', 1000)],
      ),
    );
    expect(p.current.total, 0);
    expect(p.generated, 0);
  });
  test(
    'moving a shipment recomputes its calendar bucket, including weekends',
    () {
      final p = forecast(
        bundle: incomeBundle(
          shipments: [incomeShipment(day: 5, client: 'NEVADO')],
        ),
      );
      expect(p.current.total, 0);
      expect(p.next.total, 7350000);
      expect(p.rows.single.collectionDate, DateTime(2026, 9, 28));
      final weekend = forecast(
        bundle: incomeBundle(
          shipments: [incomeShipment(day: 4, client: 'NEVADO')],
        ),
      );
      expect(weekend.timeline[DateTime(2026, 9, 27)]!.total, 7350000);
    },
  );
  test('week and 30-day terms produce next and later buckets', () {
    final p = forecast(
      bundle: incomeBundle(
        shipments: [
          incomeShipment(id: 'a', client: 'SAN LUIS'),
          incomeShipment(id: 'b', client: 'LONG'),
        ],
      ),
      data: incomeData(
        clients: [
          ...incomeClients,
          const IncomeClientRule(
            key: 'LONG',
            name: 'LONG',
            paymentType: 'MIXTO',
            term: 30,
          ),
        ],
      ),
    );
    expect(p.next.byType['FISCAL'], 7350000);
    expect(p.later.byType['MIXTO'], 7350000);
  });
  test(
    'client-material price wins, then client, then material; zero is valid',
    () {
      const client = IncomeClientRule(
        key: 'RICARDO MENDIETA',
        name: 'RICARDO MENDIETA',
        paymentType: 'EFECTIVO',
        price: 3,
      );
      expect(forecast(data: incomeData(clients: [client])).generated, 8820000);
      expect(
        forecast(
          data: incomeData(
            clients: [client],
            prices: {'RICARDO MENDIETA|PACA_NACIONAL': 4},
          ),
        ).generated,
        11760000,
      );
      expect(
        forecast(
          data: incomeData(prices: {'RICARDO MENDIETA|PACA_NACIONAL': 0}),
        ).generated,
        0,
      );
    },
  );
  test('unknown terms and price do not invent money or payment dates', () {
    final unknown = forecast(data: incomeData(clients: []));
    expect(unknown.current.total, 0);
    expect(unknown.undated.total, 7350000);
    final missing = forecast(data: incomeData(materials: []));
    expect(missing.rows.single.valueCents, isNull);
    expect(missing.rows.single.risks, contains('Precio sin definir.'));
  });
  test('the same floor stock cannot make two clients ready', () {
    final p = forecast(
      bundle: incomeBundle(
        stock: {'PACA_NACIONAL': 50},
        shipments: [
          incomeShipment(id: 'a'),
          incomeShipment(id: 'b', client: 'SAN LUIS'),
        ],
      ),
    );
    expect(p.rows.first.state, IncomeState.ready);
    expect(p.rows.last.state, IncomeState.projected);
    expect(p.rows.last.stockBales, 8);
    expect(p.rows.last.missingBales, 34);
  });
  test(
    'same-day night supply cannot cover a day shipment and deficits carry',
    () {
      final p = forecast(
        bundle: incomeBundle(
          shipments: [
            incomeShipment(id: 'a'),
            incomeShipment(id: 'b', day: 1),
          ],
        ),
        data: incomeData(
          supplies: [
            IncomeSupply(
              incomeWeek.add(const Duration(days: 1)),
              'PACA_NACIONAL',
              50,
            ),
          ],
        ),
      );
      expect(p.rows.first.missingBales, 42);
      expect(p.rows.last.missingBales, 34);
    },
  );
  test('estimated floor cannot be classified as physically ready', () {
    final p = forecast(
      bundle: incomeBundle(stock: {'PACA_NACIONAL': 100}, estimated: true),
    );
    expect(p.rows.single.state, IncomeState.projected);
    expect(p.rows.single.missingBales, 0);
  });
  test(
    'real linked sale replaces kg, price, date, and partial collections',
    () {
      final p = forecast(
        data: incomeData(
          sales: [incomeSale(day: 1, paid: 1000000, status: 'pendientePago')],
          links: {'s1': 'r1'},
        ),
      );
      expect(p.rows.single.kilograms, 28000);
      expect(p.rows.single.price, 3);
      expect(p.generated, 8400000);
      expect(p.current.total, 7400000);
      expect(p.collected, 1000000);
      expect(p.rows.single.collectionDate, DateTime(2026, 9, 22));
      expect(p.rows.single.state, IncomeState.receivable);
    },
  );
  test('settled and cancelled receivables are excluded from pending cash', () {
    final settled = forecast(
      data: incomeData(sales: [incomeSale(status: 'pagada')]),
    );
    expect(settled.current.total, 0);
    expect(settled.collected, 8400000);
    final cancelled = forecast(
      data: incomeData(
        sales: [incomeSale(status: 'cancelada')],
        links: {'s1': 'r1'},
      ),
    );
    expect(cancelled.current.total, 0);
    expect(cancelled.generated, 0);
  });
  test('shipped without an account stays shipped, not collected', () {
    final p = forecast(
      bundle: incomeBundle(shipments: [incomeShipment(status: 'embarcado')]),
    );
    expect(p.rows.single.state, IncomeState.shipped);
    expect(p.collected, 0);
  });
  test(
    'ambiguous sales cannot be automatically counted against multiple shipments',
    () {
      final p = forecast(
        bundle: incomeBundle(
          shipments: [
            incomeShipment(id: 'a'),
            incomeShipment(id: 'b'),
          ],
        ),
        data: incomeData(sales: [incomeSale()]),
      );
      expect(p.rows.every((r) => r.sale == null), isTrue);
      final external = forecast(
        data: incomeData(sales: [incomeSale()], external: {'r1'}),
      );
      expect(external.rows.single.sale, isNull);
    },
  );
  test('changing client invalidates an old explicit sale link', () {
    final p = forecast(
      bundle: incomeBundle(shipments: [incomeShipment(client: 'SAN LUIS')]),
      data: incomeData(sales: [incomeSale()], links: {'s1': 'r1'}),
    );
    expect(p.rows.single.sale, isNull);
    expect(p.rows.single.risks.first, contains('Revisar vínculo'));
  });
  test('overdue collections do not roll forward into another week', () {
    final p = forecast(
      data: incomeData(
        sales: [
          incomeSale(status: 'pendientePago', due: DateTime(2026, 9, 20)),
        ],
      ),
    );
    expect(p.current.total, 0);
    expect(p.overdue.total, 8400000);
    expect(p.rows.single.risks, contains('Pago vencido.'));
  });
  test(
    'Palomar remissions reduce balance once; cuts do not add a second opening',
    () {
      final movements = [
        PalomarIncomeMovement.fromLedger({
          'id': 'a',
          'date': '2026-09-01',
          'type': 'chequeLiberado',
          'amount': 100000,
        }),
        PalomarIncomeMovement.fromLedger({
          'id': 'b',
          'date': '2026-09-21',
          'type': 'remisionAplicada',
          'amount': 84000,
          'source_report_id': 'r1',
        }),
        PalomarIncomeMovement.fromLedger({
          'id': 'c',
          'date': '2026-09-21',
          'type': 'corteInterno',
          'amount': 999999,
        }),
      ];
      final p = forecast(
        bundle: incomeBundle(shipments: [incomeShipment(client: 'EL PALOMAR')]),
        data: incomeData(
          sales: [incomeSale(client: 'EL PALOMAR')],
          movements: movements,
          config: const PalomarIncomeConfig(
            creditLimit: 500000,
            drawAmount: 400000,
            cashCheck1: 99000,
            cashCheck2: 99000,
          ),
        ),
      );
      expect(p.palomar.opening, 10000000);
      expect(p.palomar.credits, 8400000);
      expect(p.palomar.closing, 1600000);
      expect(p.palomar.plannedShipments, 0);
      expect(p.palomar.availableDraw, 0);
      expect(p.current.total, 0);
    },
  );
  test(
    'Palomar configuration limits draw and its cash/fiscal split, never sales',
    () {
      final p = forecast(
        bundle: incomeBundle(shipments: [incomeShipment(client: 'EL PALOMAR')]),
        data: incomeData(
          config: const PalomarIncomeConfig(
            creditLimit: 500000,
            drawAmount: 400000,
            cashCheck1: 99000,
            cashCheck2: 99000,
          ),
        ),
      );
      expect(p.palomar.closing, -7350000);
      expect(p.palomar.availableDraw, 40000000);
      expect(p.palomar.cash, 19800000);
      expect(p.palomar.fiscal, 20200000);
      expect(p.current.total, 40000000);
      expect(p.current.byType['EFECTIVO'], 19800000);
      expect(p.current.byType['FISCAL'], 20200000);
      expect(p.current.financingTotal, 40000000);
      expect(p.current.salesTotal, 0);
      expect(p.next.total + p.later.total, 0);
      expect(p.timeline, isEmpty); // Closing-week forecast, not an agreed day.
      expect(p.projected + p.committed + p.collected, 0);
      expect(p.byClient['El Palomar · disposición'], 40000000);
      expect(p.generated, 7350000);
      expect(forecast(data: incomeData()).palomar.availableDraw, 0);
    },
  );
  test(
    'changing Palomar configuration recomputes cash without accumulating earlier draws',
    () {
      final bundle = incomeBundle(
        shipments: [
          incomeShipment(),
          incomeShipment(id: 'palomar', client: 'EL PALOMAR'),
        ],
      );
      final first = forecast(
        bundle: bundle,
        data: incomeData(
          config: const PalomarIncomeConfig(
            creditLimit: 500000,
            drawAmount: 400000,
            cashCheck1: 99000,
            cashCheck2: 99000,
          ),
        ),
      );
      final updated = forecast(
        bundle: bundle,
        data: incomeData(
          config: const PalomarIncomeConfig(
            creditLimit: 500000,
            drawAmount: 200000,
            cashCheck1: 50000,
            cashCheck2: 50000,
          ),
        ),
      );
      expect(first.current.total, 47350000);
      expect(updated.current.total, 27350000);
      expect(updated.current.salesTotal, 7350000);
      expect(updated.current.byType['EFECTIVO'], 17350000);
      expect(updated.current.byType['FISCAL'], 10000000);
      expect(updated.byMaterial['Nacional'], 7350000);
      expect(updated.palomar.closing, -7350000);
    },
  );
  test(
    'configuring a draw does not add cash when the account is still uncovered or the limit is zero',
    () {
      final bundle = incomeBundle(shipments: []);
      final p = forecast(
        bundle: bundle,
        data: incomeData(
          config: const PalomarIncomeConfig(
            creditLimit: 500000,
            drawAmount: 400000,
            cashCheck1: 99000,
            cashCheck2: 99000,
          ),
          movements: [
            PalomarIncomeMovement(
              id: 'check',
              date: incomeWeek,
              signedCents: 50000000,
              concept: 'Cheque',
            ),
          ],
        ),
      );
      expect(p.current.total, 0);
      expect(p.current.financingTotal, 0);
      final zero = forecast(
        bundle: bundle,
        data: incomeData(
          config: const PalomarIncomeConfig(creditLimit: 0, drawAmount: 400000),
        ),
      );
      expect(zero.current.total, 0);
    },
  );
  test(
    'an unvalued Palomar shipment blocks disposition even with zero known balance',
    () {
      final p = forecast(
        bundle: incomeBundle(shipments: [incomeShipment(client: 'EL PALOMAR')]),
        data: incomeData(
          materials: [],
          config: const PalomarIncomeConfig(
            creditLimit: 500000,
            drawAmount: 100000,
          ),
        ),
      );
      expect(p.palomar.complete, isFalse);
      expect(p.palomar.availableDraw, 0);
    },
  );
  test(
    'adapter uses schedule day/night and subtracts actual production already in floor',
    () {
      final bundle = incomeBundle();
      final tables = List.generate(14, (_) => <Map<String, dynamic>>[]);
      tables[12] = [
        {
          'id': 'program',
          'week_start': '2026-09-21',
          'version': 1,
          'status': 'approved',
          'is_operational': true,
          'conditions': ProgramConditions.fromReference(bundle).toJson(),
          'shipments': ProgramDemand.fromShipments(
            incomeWeek,
            bundle.shipments,
          ).map((d) => d.toJson()).toList(),
          'lines': [
            const ProgramLine(0, 0, 'PACA_NACIONAL', 30).toJson(),
            const ProgramLine(0, 1, 'PACA_NACIONAL', 20).toJson(),
          ],
        },
      ];
      tables[13] = [
        {
          'date': '2026-09-21',
          'shift': 'DAY',
          'material': 'PACA_NACIONAL',
          'quantity': 10,
        },
      ];
      final data = assembleExpectedIncomeData(
        bundle: bundle,
        today: incomeWeek,
        tables: tables,
      );
      expect(data.supplies.first.bales, 20);
      expect(data.supplies.last.availableDate, DateTime(2026, 9, 22));
      expect(data.productionSource, contains('v1'));
      final changed = assembleExpectedIncomeData(
        bundle: incomeBundle(shipments: [incomeShipment(bales: 99)]),
        today: incomeWeek,
        tables: tables,
      );
      expect(changed.warnings, contains(contains('regenerar')));
      expect(changed.supplies, isEmpty);
    },
  );
}
