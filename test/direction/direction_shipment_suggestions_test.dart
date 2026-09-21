import 'dart:math';

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:flutter_test/flutter_test.dart';

final week = DateTime(2026, 9, 21);
final now = week.add(const Duration(hours: 10));
const national = 'PACA_NACIONAL';

DirectionShipmentTarget target({
  int shipping = 90,
  int production = 200,
  String notes = '',
}) => DirectionShipmentTarget(
  baleTypeKey: 'revuelto',
  sortOrder: 1,
  shipmentTargetBales: shipping,
  productionTargetBales: production,
  notes: notes,
);

DirectionShipmentPlanRecord shipment(
  String id,
  DateTime date,
  int quantity, {
  String client = 'CLIENTE NUEVO',
  String status = 'embarcado',
  String material = national,
}) => DirectionShipmentPlanRecord(
  id: id,
  shipDate: date,
  clientName: client,
  materialCode: material,
  materialScope: DirectionShipmentMaterialScope.commercial,
  quantityUnit: DirectionShipmentQuantityUnit.bales,
  plannedQuantity: quantity,
  priority: 'normal',
  status: status,
  notes: '',
  createdAt: date,
  updatedAt: date,
);

List<DirectionShipmentMovement> supply({double recent = 6000}) => [
  for (var w = 1; w <= 7; w++)
    DirectionShipmentMovement(
      date: week.subtract(Duration(days: w * 7 - 1)),
      flow: 'IN',
      level: 'GENERAL',
      material: 'CARTON',
      kilograms: w == 1 ? recent : 6000,
    ),
];

List<DirectionProductionHistoryRecord> productionHistory() => [
  for (var w = 1; w <= 6; w++)
    for (var d = 0; d < 5; d++)
      DirectionProductionHistoryRecord(
        date: week.subtract(Duration(days: 7 * w)).add(Duration(days: d)),
        materialCode: national,
        quantity: 30,
        shiftKey: 'DAY',
        compactadoraKey: 'c1',
      ),
];

DirectionShipmentSuggestionReport propose({
  int floor = 100,
  int shipping = 90,
  int productionTarget = 200,
  List<DirectionShipmentPlanRecord>? shipments,
  List<DirectionShipmentMovement>? movements,
  List<DirectionProductionHistoryRecord>? production,
  List<DirectionProductionCapacityImpactRecord> impacts = const [],
  Map<String, DateTime>? stamps,
  DateTime? asOf,
  DateTime? start,
  List<DirectionShipmentTarget>? targets,
  Map<String, dynamic>? conditions,
}) => buildDirectionShipmentSuggestions(
  weekStart: start ?? week,
  asOf: asOf ?? now,
  shipments:
      shipments ??
      [shipment('history', week.subtract(const Duration(days: 7)), 30)],
  floorCounts: {national: floor},
  floorCountedAt: stamps ?? {national: now},
  production: production ?? productionHistory(),
  impacts: impacts,
  targets:
      targets ?? [target(shipping: shipping, production: productionTarget)],
  savedProgramConditions: conditions,
  movements: movements ?? supply(),
);

void main() {
  test('uses completed Dirección history outside former fixed client list', () {
    final result = propose();
    expect(result.suggestions, hasLength(1));
    final row = result.suggestions.single;
    expect(row.clientName, 'CLIENTE NUEVO');
    expect(row.suggestedQuantity, 30);
    expect(result.coverage.first.shortfall, 0);
    expect(row.projectedRemainingAfterQuantity, greaterThanOrEqualTo(5));
  });

  test(
    'ignores planned, cancelled, kg and future history for client evidence',
    () {
      final rows = [
        shipment(
          'planned',
          week.subtract(const Duration(days: 7)),
          30,
          status: 'planeado',
        ),
        shipment(
          'cancelled',
          week.subtract(const Duration(days: 14)),
          30,
          status: 'cancelado',
        ),
        shipment('future', week.add(const Duration(days: 3)), 30),
      ];
      expect(propose(shipments: rows).suggestions, isEmpty);
    },
  );

  test(
    'reconciles duplicate OUT and Dirección actual totals, including all clients',
    () {
      final date = week.subtract(const Duration(days: 7));
      final rows = [
        shipment('history', date, 30),
        shipment('actual', week, 20),
      ];
      final result = propose(
        shipments: rows,
        movements: [
          ...supply(),
          DirectionShipmentMovement(
            date: date,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: national,
            client: 'cliente nuevo',
            bales: 30,
          ),
          DirectionShipmentMovement(
            date: week,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: national,
            client: 'cliente nuevo',
            bales: 20,
          ),
        ],
      );
      expect(result.coverage.first.actual, 20);
      // The client already took 20 of its habitual 30, so do not invent another load.
      expect(result.suggestions, isEmpty);
    },
  );

  test(
    'protects Friday and Saturday stock from an earlier proposed shipment',
    () {
      final result = propose(
        floor: 40,
        production: [],
        shipments: [
          shipment('history', week.subtract(const Duration(days: 7)), 30),
          shipment(
            'reserved',
            week.add(const Duration(days: 5)),
            35,
            client: 'CONFIRMADO',
            status: 'confirmado',
          ),
        ],
      );
      expect(result.suggestions, isEmpty);
      expect(result.coverage.first.committed, 35);
    },
  );

  test('day production can supply the same day within shared capacity', () {
    final result = propose(floor: 5);
    final row = result.suggestions.single;
    expect(row.suggestedDate, week);
    expect(row.expectedFutureQuantity, 30);
    expect(row.risk, DirectionShipmentRisk.tight);
  });

  test('low raw intake reduces forecast; kg never become bales', () {
    final normal = propose(floor: 5);
    final low = propose(floor: 5, movements: supply(recent: 3000));
    expect(normal.intakeFactor, 1);
    expect(low.intakeFactor, .5);
    expect(
      low.suggestions.single.suggestedDate,
      normal.suggestions.single.suggestedDate.add(const Duration(days: 1)),
    );
    expect(
      propose(floor: 5, movements: supply(recent: 0)).suggestions,
      isEmpty,
    );
    expect(
      propose(floor: 35, movements: []).suggestions.single.suggestedQuantity,
      30,
    );
  });

  test(
    'goals are outputs and never gate or inflate the historical proposal',
    () {
      final without = propose(floor: 5, targets: []);
      expect(without.suggestions.single.suggestedQuantity, 30);
      for (final goal in [0, 20, 9999]) {
        final result = propose(
          floor: 5,
          shipping: goal,
          productionTarget: goal,
        );
        expect(result.sourceKey, without.sourceKey);
        expect(result.coverage.first.shipmentGoal(30), 30);
        expect(result.coverage.first.productionGoal(30), 25);
      }
      expect(
        propose(floor: 5, production: [], productionTarget: 9999).suggestions,
        isEmpty,
      );
    },
  );

  test(
    'machine shutdown also constrains production without machine attribution',
    () {
      final result = propose(
        floor: 5,
        production: productionHistory()
            .map(
              (p) => DirectionProductionHistoryRecord(
                date: p.date,
                materialCode: p.materialCode,
                quantity: p.quantity,
                shiftKey: p.shiftKey,
              ),
            )
            .toList(),
        impacts: [
          DirectionProductionCapacityImpactRecord(
            id: 'stop',
            machineKey: 'ambas',
            startDate: week,
            endDate: week.add(const Duration(days: 5)),
            impactPercent: 100,
            notes: '',
            source: 'manual',
            linkedMaintenanceOrderId: null,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      expect(result.suggestions, isEmpty);
    },
  );

  test(
    'dated counts older than twelve hours are usable; missing/future counts add no stock',
    () {
      expect(
        propose(
          stamps: {national: now.subtract(const Duration(hours: 13))},
          production: [],
        ).suggestions,
        isNotEmpty,
      );
      for (final stamps in <Map<String, DateTime>>[
        {},
        {national: now.add(const Duration(hours: 1))},
      ]) {
        expect(propose(stamps: stamps, production: []).suggestions, isEmpty);
        // Known capacity can still build a load even when opening stock is unknown.
        expect(propose(stamps: stamps).suggestions, isNotEmpty);
      }
    },
  );

  test('small management goals do not truncate historical loads', () {
    for (final goal in [0, 20, 25]) {
      final result = propose(shipping: goal);
      expect(result.suggestions.single.suggestedQuantity, 30);
      expect(result.coverage.first.shortfall, 0);
    }
  });

  test(
    'past weeks and weekend have no proposals; all suggestions fit program scope',
    () {
      expect(
        propose(start: week.subtract(const Duration(days: 7))).suggestions,
        isEmpty,
      );
      expect(
        propose(asOf: week.add(const Duration(days: 5))).suggestions,
        isEmpty,
      );
      final demands = ProgramDemand.fromShipments(week, [
        for (final s in propose().suggestions)
          shipment(
            'accepted',
            s.suggestedDate,
            s.suggestedQuantity,
            client: s.clientName,
            material: s.materialCode,
            status: 'confirmado',
          ),
      ]);
      expect(demands.single.quantity, 30);
    },
  );

  test(
    'reopening after accepting a proposal reserves it and prevents duplication',
    () {
      final first = propose();
      final row = first.suggestions.single;
      final second = propose(
        shipments: [
          shipment('history', week.subtract(const Duration(days: 7)), 30),
          shipment(
            'accepted',
            row.suggestedDate,
            row.suggestedQuantity,
            status: 'confirmado',
          ),
        ],
      );
      expect(second.suggestions, isEmpty);
      expect(second.sourceKey, isNot(first.sourceKey));
      expect(
        propose(asOf: now.add(const Duration(minutes: 1))).sourceKey,
        first.sourceKey,
      );
    },
  );

  test(
    'acceptance payload saves the complete selection with stable separate IDs',
    () {
      final report = propose(
        shipping: 90,
        shipments: [
          for (var i = 0; i < 3; i++)
            shipment('h$i', week.subtract(const Duration(days: 7)), 30),
        ],
      );
      List<Map<String, dynamic>> payload(bool confirm) =>
          DirectionShipmentsStore.prepareSuggestedShipmentRows(
            reviewed: report,
            fresh: report,
            selected: report.suggestions,
            confirmForProgram: confirm,
          );
      final confirmed = payload(true);
      expect(confirmed, hasLength(3));
      expect(confirmed.map((r) => r['id']).toSet(), hasLength(3));
      expect(payload(true), confirmed);
      expect(payload(false).every((r) => r['status'] == 'planeado'), isTrue);
      expect(
        ProgramDemand.fromShipments(
          week,
          confirmed.map(DirectionShipmentPlanRecord.fromRow),
        ),
        hasLength(3),
      );
      expect(
        confirmed.every(
          (r) => r['notes'].toString().contains('Propuesta semanal'),
        ),
        isTrue,
      );
    },
  );

  test(
    'stale or foreign selections are rejected before preparing any writes',
    () {
      final report = propose();
      expect(
        () => DirectionShipmentsStore.prepareSuggestedShipmentRows(
          reviewed: report,
          fresh: propose(floor: 0, production: []),
          selected: report.suggestions,
          confirmForProgram: true,
        ),
        throwsStateError,
      );
      expect(
        () => DirectionShipmentsStore.prepareSuggestedShipmentRows(
          reviewed: report,
          fresh: report,
          selected: propose(floor: 30, production: []).suggestions,
          confirmForProgram: true,
        ),
        throwsStateError,
      );
    },
  );

  test('several loads for the same client remain separately identifiable', () {
    final result = propose(
      shipping: 90,
      shipments: [
        for (var i = 0; i < 3; i++)
          shipment('h$i', week.subtract(const Duration(days: 7)), 30),
      ],
    );
    expect(result.suggestions, hasLength(3));
    expect(
      result.suggestions.map(directionSuggestionKey).toSet(),
      hasLength(3),
    );
    expect(result.suggestions.every((s) => s.suggestedQuantity == 30), isTrue);
  });

  test(
    'departures after the count reduce stock without subtracting earlier history',
    () {
      final result = propose(
        floor: 40,
        production: [],
        movements: [
          ...supply(),
          DirectionShipmentMovement(
            date: week,
            recordedAt: now.add(const Duration(minutes: 5)),
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: national,
            client: 'OTRO CLIENTE',
            bales: 20,
          ),
        ],
        asOf: now.add(const Duration(minutes: 10)),
      );
      expect(result.suggestions, isEmpty);
      expect(
        result.observations.any((s) => s.contains('piso calculado 20')),
        isTrue,
      );
    },
  );

  test(
    'many clients share a single stock budget and preserve every later commitment',
    () {
      final rng = Random(21);
      for (var trial = 0; trial < 80; trial++) {
        final floor = rng.nextInt(250);
        final reserved = rng.nextInt(80);
        final result = propose(
          floor: floor,
          shipping: 1000,
          production: [],
          shipments: [
            for (var c = 0; c < 10; c++)
              shipment(
                'h$c',
                week.subtract(const Duration(days: 7)),
                20 + rng.nextInt(25),
                client: 'CLIENTE $c',
              ),
            shipment(
              'reserved',
              week.add(const Duration(days: 4)),
              reserved,
              client: 'RESERVADO',
              status: 'confirmado',
            ),
          ],
        );
        final total = result.suggestions.fold(
          0,
          (n, s) => n + s.suggestedQuantity,
        );
        expect(total + reserved, lessThanOrEqualTo(max(reserved, floor - 5)));
        expect(
          result.suggestions.every((s) => s.suggestedQuantity >= 8),
          isTrue,
        );
      }
    },
  );
}
