import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_engine.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:dicsa_operacion/app/shared/utils/manual_yard_count_time.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_shipment_suggestions_test.dart' as f;

void main() {
  for (final day in [-1, 0, 2, 6, 7]) {
    for (final current in [0, 22]) {
      test(
        'program uses current yard only within its week: day $day, stock $current',
        () {
          final report = DirectionShipmentSuggestionReport(
            weekStart: f.week,
            generatedAt: f.week.add(Duration(days: day)),
            suggestions: [],
            coverage: [],
            observations: [],
            intakeFactor: 1,
            operationHistoryCount: 0,
            directionHistoryCount: 0,
            productionRecordCount: 0,
            sourceKey: 'current-yard',
            dailyCapacity: 80,
            openingFloorByMaterial: {f.national: 35},
            currentFloorByMaterial: {f.national: current},
            fridayOpeningMaterials: {f.national},
          );
          final bundle = DirectionShipmentPlanningBundle(
            weekStartDate: f.week,
            weekEndDate: f.week.add(const Duration(days: 5)),
            shipments: [
              f.shipment(
                'pending',
                f.week.add(const Duration(days: 4)),
                50,
                status: 'confirmado',
              ),
              f.shipment('already-shipped', f.week, 12),
            ],
            projections: [],
            suggestedShipments: [],
            floorCountByMaterial: {},
            floorCountUpdatedAt: report.generatedAt,
            expectedDays: [],
            activeCapacityImpacts: [],
            impactSummaries: [],
            maintenanceAlerts: [],
            suggestionReport: report,
            savedProgramConditions: {
              'yard': {f.national: 999},
            },
          );
          final expected = day >= 0 && day < 7 ? current : 35;
          final conditions = ProgramConditions.fromReference(bundle);
          expect(conditions.yard[f.national], expected);
          final demands = ProgramDemand.fromShipments(f.week, bundle.shipments);
          expect(demands.single.id, 'pending');
          final lines = generateOperatingProgram(f.week, conditions, demands);
          expect(programQuantity(lines), 50 - expected);
        },
      );
    }
  }
  final fridayClosingTime = DateTime.parse('2026-09-18T23:01:00Z');
  final weeklyOpening = {
    f.national: DirectionWeeklyYardOpening(
      quantity: 35,
      countedAt: fridayClosingTime,
    ),
  };

  test(
    'Friday close is exact Monday floor in advance, without prior-week reservations',
    () {
      final report = f.propose(
        asOf: fridayClosingTime.add(const Duration(minutes: 1)),
        floor: 35,
        stamps: {f.national: fridayClosingTime},
        weeklyOpeningCounts: weeklyOpening,
        production: [],
        movements: [],
        shipments: [
          f.shipment('history', f.week.subtract(const Duration(days: 7)), 30),
          f.shipment(
            'previous',
            f.week.subtract(const Duration(days: 1)),
            60,
            status: 'confirmado',
            client: 'SEMANA ANTERIOR',
          ),
        ],
        conditions: {
          'yard': {f.national: 999},
        },
      );
      expect(report.openingFloorByMaterial[f.national], 35);
      expect(report.currentFloorByMaterial[f.national], 35);
      expect(report.fridayOpeningMaterials, {f.national});
      expect(report.estimatedFloorMaterials, isNot(contains(f.national)));
      expect(report.suggestions.single.suggestedDate, f.week);
      expect(report.suggestions.single.suggestedQuantity, 30);
      final accepted = [
        f.shipment('accepted', f.week, 30, status: 'confirmado'),
      ];
      final projection = DirectionShipmentsStore.buildProjections(
        shipments: accepted,
        floorCounts: report.currentFloorByMaterial,
        expectedDays: [],
        suggestionReport: report,
        asOf: fridayClosingTime,
      );
      expect(projection.single.projectedRemainingAfterQuantity, 5);
      final conditions = ProgramConditions.fromReference(
        DirectionShipmentPlanningBundle(
          weekStartDate: f.week,
          weekEndDate: f.week.add(const Duration(days: 5)),
          shipments: accepted,
          projections: projection,
          suggestedShipments: [],
          floorCountByMaterial: {},
          floorCountUpdatedAt: fridayClosingTime,
          expectedDays: [],
          activeCapacityImpacts: [],
          impactSummaries: [],
          maintenanceAlerts: [],
          suggestionReport: report,
        ),
      );
      expect(conditions.yard[f.national], 35);
      final demands = ProgramDemand.fromShipments(f.week, accepted);
      final lines = generateOperatingProgram(f.week, conditions, demands);
      expect(programQuantity(lines), 0);
      expect(
        evaluateOperatingProgram(f.week, conditions, demands, lines).valid,
        isTrue,
      );
    },
  );

  test(
    'weekend movements do not alter Monday close; Monday movements apply once',
    () {
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: f.week.add(const Duration(hours: 12)),
        counts: {f.national: 35},
        countedAt: {f.national: fridayClosingTime},
        weeklyOpeningCounts: weeklyOpening,
        savedProgramConditions: {
          'yard': {f.national: 999},
        },
        production: [
          for (final offset in [-2, 0])
            DirectionProductionHistoryRecord(
              date: f.week.add(Duration(days: offset)),
              materialCode: f.national,
              quantity: 10,
              shiftKey: 'DAY',
            ),
        ],
        movements: [
          for (final offset in [-2, 0])
            DirectionShipmentMovement(
              date: f.week.add(Duration(days: offset)),
              flow: 'OUT',
              level: 'COMMERCIAL',
              material: f.national,
              bales: 7,
              client: 'CLIENTE NUEVO',
            ),
          DirectionShipmentMovement(
            date: f.week,
            flow: 'IN',
            level: 'COMMERCIAL',
            origin: 'TRANSFORMATION',
            material: f.national,
            bales: 10,
          ),
        ],
        shipments: [f.shipment('same-output', f.week, 7)],
      );
      expect(result.opening[f.national], 35);
      expect(result.current[f.national], 38);
    },
  );

  test(
    'later physical count updates current stock and preserves Friday opening',
    () {
      final tuesday = f.week.add(const Duration(days: 1));
      final stamp = tuesday.add(const Duration(hours: 10));
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: stamp.add(const Duration(hours: 2)),
        counts: {f.national: 20},
        countedAt: {f.national: stamp},
        weeklyOpeningCounts: weeklyOpening,
        production: [
          DirectionProductionHistoryRecord(
            date: tuesday,
            recordedAt: stamp.add(const Duration(hours: 1)),
            materialCode: f.national,
            quantity: 2,
            shiftKey: 'DAY',
          ),
        ],
        movements: [],
        shipments: [],
      );
      expect(result.opening[f.national], 35);
      expect(result.current[f.national], 22);
      final empty = f.propose(
        asOf: f.now,
        weeklyOpeningCounts: {
          f.national: DirectionWeeklyYardOpening(
            quantity: 0,
            countedAt: fridayClosingTime,
          ),
        },
        floor: 100,
        stamps: {f.national: fridayClosingTime},
        production: [],
        movements: [],
      );
      expect(empty.currentFloorByMaterial[f.national], 0);
      expect(empty.openingFloorByMaterial[f.national], 0);
      expect(empty.missingFloorMaterials, isNot(contains(f.national)));
      expect(empty.suggestions, isEmpty);
    },
  );

  test(
    'late Sunday UTC count is still Sunday in Celaya, not a Monday recount',
    () {
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: f.week.add(const Duration(hours: 12)),
        counts: {f.national: 999},
        countedAt: {f.national: DateTime.parse('2026-09-21T04:30:00Z')},
        countedOn: {f.national: DateTime(2026, 9, 20)},
        weeklyOpeningCounts: weeklyOpening,
        production: [],
        movements: [],
        shipments: [],
      );
      expect(result.opening[f.national], 35);
      expect(result.current[f.national], 35);
    },
  );

  test(
    'manual counts use the server save instant, including legacy offsetless captures',
    () {
      final server = DateTime.parse('2026-09-22T14:57:00Z');
      expect(
        manualYardCountTime({
          'counted_at': '2026-09-22T08:57:00Z',
          'updated_at': server.toIso8601String(),
        }),
        server,
      );
      expect(
        manualYardCountTime({'counted_at': server.toIso8601String()}),
        server,
      );
      expect(
        manualYardCountTime({'counted_at': server, 'updated_at': 'invalid'}),
        server,
      );
      expect(manualYardCountTime({}), isNull);
    },
  );

  test(
    'a current physical count survives an inconsistent reconstruction of Monday stock',
    () {
      final countTime = f.week.add(const Duration(days: 1, hours: 9));
      final inventory = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: countTime.add(const Duration(hours: 3)),
        counts: {f.national: 30, 'PACA_AMERICANA': 2, 'PACA_LIMPIA': 14},
        countedAt: {
          for (final m in [f.national, 'PACA_AMERICANA', 'PACA_LIMPIA'])
            m: countTime,
        },
        production: [
          DirectionProductionHistoryRecord(
            date: f.week,
            materialCode: f.national,
            quantity: 100,
            shiftKey: 'DAY',
          ),
        ],
        movements: [],
        shipments: [],
      );
      expect(inventory.opening[f.national], 0);
      expect(inventory.current, {
        f.national: 30,
        'PACA_AMERICANA': 2,
        'PACA_LIMPIA': 14,
      });
      expect(inventory.estimatedMaterials, isEmpty);
      expect(inventory.missingMaterials, isEmpty);
      expect(
        inventory.observations.join(' '),
        contains('revisar la conciliación'),
      );
    },
  );

  test(
    'only movements after the corrected count affect current stock; raw kg and transformation do not double count',
    () {
      final stamp = manualYardCountTime({
        'counted_at': '2026-09-22T08:57:00Z',
        'updated_at': '2026-09-22T14:57:00Z',
      })!;
      final day = DateTime(2026, 9, 22);
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: stamp.add(const Duration(hours: 2)).toLocal(),
        counts: {f.national: 30},
        countedAt: {f.national: stamp},
        production: [
          for (final hour in [-1, 1])
            DirectionProductionHistoryRecord(
              date: day,
              recordedAt: stamp.add(Duration(hours: hour)),
              materialCode: f.national,
              quantity: 10,
              shiftKey: 'DAY',
            ),
        ],
        movements: [
          for (final hour in [-1, 1])
            DirectionShipmentMovement(
              date: day,
              recordedAt: stamp.add(Duration(hours: hour)),
              flow: 'OUT',
              level: 'COMMERCIAL',
              material: f.national,
              bales: 2,
            ),
          DirectionShipmentMovement(
            date: day,
            recordedAt: stamp.add(const Duration(hours: 1)),
            flow: 'IN',
            level: 'COMMERCIAL',
            material: f.national,
            bales: 10,
            origin: 'TRANSFORMATION',
          ),
          DirectionShipmentMovement(
            date: day,
            flow: 'IN',
            level: 'GENERAL',
            material: 'CARTON',
            kilograms: 30000,
          ),
        ],
        shipments: [],
      );
      expect(result.current[f.national], 38); // 30 physical + 10 new - 2 out
      expect(result.estimatedMaterials.contains(f.national), false);
    },
  );

  test(
    'planned shipment feasibility combines the count, production history, intake and earlier commitments',
    () {
      final now = f.week.add(const Duration(days: 1, hours: 12));
      final plans = [
        f.shipment('shipped', f.week, 100),
        f.shipment(
          'today',
          f.week.add(const Duration(days: 1)),
          40,
          status: 'confirmado',
        ),
        f.shipment(
          'tomorrow',
          f.week.add(const Duration(days: 2)),
          70,
          status: 'confirmado',
        ),
      ];
      List<DirectionShipmentPlanProjection> project({double incoming = 6000}) {
        final report = f.propose(
          floor: 30,
          asOf: now,
          stamps: {f.national: now},
          shipments: plans,
          movements: f.supply(recent: incoming),
        );
        return DirectionShipmentsStore.buildProjections(
          shipments: plans,
          floorCounts: report.currentFloorByMaterial,
          expectedDays: [],
          suggestionReport: report,
          asOf: now,
        );
      }

      final normal = project();
      expect(normal[0].risk, DirectionShipmentRisk.shipped);
      expect(normal[1].currentFloorQuantity, 30);
      expect(normal[1].expectedFutureQuantity, 30);
      expect(normal[1].priorCommittedQuantity, 0);
      expect(normal[1].projectedRemainingAfterQuantity, 20);
      expect(normal[1].risk, DirectionShipmentRisk.good);
      expect(normal[2].expectedFutureQuantity, 60);
      expect(normal[2].priorCommittedQuantity, 40);
      expect(normal[2].projectedRemainingAfterQuantity, -20);
      expect(normal[2].risk, DirectionShipmentRisk.atRisk);
      final low = project(incoming: 0);
      expect(low[1].expectedFutureQuantity, 0);
      expect(low[1].risk, DirectionShipmentRisk.atRisk);
    },
  );

  test(
    'missing floor, uncertain movements and a known empty floor have distinct risk states',
    () {
      final plans = [f.shipment('plan', f.week, 20, status: 'confirmado')];
      DirectionShipmentRisk risk(DirectionShipmentSuggestionReport report) =>
          DirectionShipmentsStore.buildProjections(
            shipments: plans,
            floorCounts: report.currentFloorByMaterial,
            expectedDays: [],
            suggestionReport: report,
            asOf: f.now,
          ).single.risk;
      final missing = f.propose(stamps: {}, production: [], shipments: plans);
      expect(risk(missing), DirectionShipmentRisk.unknown);
      final uncertain = f.propose(
        floor: 30,
        asOf: f.now.add(const Duration(hours: 2)),
        production: [
          DirectionProductionHistoryRecord(
            date: f.week,
            materialCode: f.national,
            quantity: 5,
            shiftKey: 'DAY',
          ),
        ],
        shipments: plans,
      );
      expect(uncertain.currentFloorByMaterial[f.national], 30);
      expect(uncertain.missingFloorMaterials.contains(f.national), false);
      expect(risk(uncertain), DirectionShipmentRisk.estimated);
      expect(
        risk(f.propose(floor: 0, production: [], shipments: plans)),
        DirectionShipmentRisk.atRisk,
      );
    },
  );

  test('raw carton consumed in transformation never cancels arrivals', () {
    final normal = f.propose(floor: 5);
    final result = f.propose(
      floor: 5,
      movements: [
        ...f.supply(),
        for (final receipt in f.supply())
          DirectionShipmentMovement(
            date: receipt.date,
            flow: 'OUT',
            level: 'GENERAL',
            material: 'CARTON',
            origin: 'TRANSFORMATION',
            kilograms: receipt.kilograms * 3,
          ),
      ],
    );
    expect(result.intakeFactor, 1);
    expect(result.incomingRecordCount, 7);
    expect(result.sourceKey, normal.sourceKey);
    expect(f.propose(floor: 5, movements: []).suggestions, isNotEmpty);
  });

  test(
    'old floor rolls forward; production is counted once and duplicate departures are reconciled',
    () {
      final mondayNoon = f.week.add(const Duration(hours: 12));
      final tuesday = f.week.add(const Duration(days: 1));
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: tuesday.add(const Duration(hours: 10)),
        counts: {f.national: 20},
        countedAt: {f.national: f.week.subtract(const Duration(hours: 12))},
        production: [
          DirectionProductionHistoryRecord(
            date: f.week,
            recordedAt: mondayNoon,
            materialCode: f.national,
            quantity: 30,
            shiftKey: 'DAY',
          ),
        ],
        movements: [
          DirectionShipmentMovement(
            date: f.week,
            recordedAt: mondayNoon,
            flow: 'IN',
            level: 'COMMERCIAL',
            material: f.national,
            bales: 30,
            origin: 'TRANSFORMATION',
          ),
          DirectionShipmentMovement(
            date: f.week,
            recordedAt: mondayNoon,
            flow: 'IN',
            level: 'COMMERCIAL',
            material: f.national,
            bales: 10,
            origin: 'DIRECT_PURCHASE',
          ),
          DirectionShipmentMovement(
            date: f.week,
            recordedAt: mondayNoon,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: f.national,
            bales: 15,
            client: 'CLIENTE NUEVO',
          ),
        ],
        shipments: [f.shipment('done', f.week, 15)],
      );
      expect(result.opening[f.national], 20);
      expect(result.current[f.national], 45);
    },
  );

  test(
    'later count reconstructs Monday opening without moving the count backwards unchanged',
    () {
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: f.week.add(const Duration(days: 2, hours: 10)),
        counts: {f.national: 45},
        countedAt: {f.national: f.week.add(const Duration(days: 1))},
        production: [
          DirectionProductionHistoryRecord(
            date: f.week,
            materialCode: f.national,
            quantity: 30,
            shiftKey: 'DAY',
          ),
        ],
        movements: [],
        shipments: [f.shipment('done', f.week, 5)],
      );
      expect(result.opening[f.national], 20);
      expect(result.current[f.national], 45);
    },
  );

  test(
    'saved initial yard is a fallback when no fresh manual count exists',
    () {
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: f.week.add(const Duration(days: 2)),
        counts: {},
        countedAt: {},
        production: [],
        movements: [],
        shipments: [f.shipment('done', f.week, 10)],
        savedProgramConditions: {
          'yard': {f.national: 50},
        },
      );
      expect(result.opening[f.national], 50);
      expect(result.current[f.national], 40);
    },
  );

  test(
    'night production supplies the next day; a disabled shift creates no capacity',
    () {
      final history = [
        for (final r in f.productionHistory())
          DirectionProductionHistoryRecord(
            date: r.date,
            materialCode: r.materialCode,
            quantity: r.quantity,
            shiftKey: 'NIGHT',
          ),
      ];
      final result = f.propose(floor: 5, production: history);
      expect(
        result.suggestions.single.suggestedDate,
        f.week.add(const Duration(days: 1)),
      );
      expect(
        f
            .propose(
              floor: 5,
              production: history,
              conditions: {
                'days': List.generate(5, (_) => {'night_available': false}),
              },
            )
            .suggestions,
        isEmpty,
      );
    },
  );

  test('actual production today is not forecast a second time', () {
    final result = f.propose(
      floor: 5,
      production: [
        ...f.productionHistory(),
        DirectionProductionHistoryRecord(
          date: f.week,
          recordedAt: f.now.subtract(const Duration(hours: 1)),
          materialCode: f.national,
          quantity: 30,
          shiftKey: 'DAY',
        ),
      ],
    );
    expect(
      result.suggestions.single.suggestedDate,
      f.week.add(const Duration(days: 1)),
    );
    expect(result.suggestions.single.currentFloorQuantity, 5);
  });

  test(
    'one capacity is shared across materials and respects saved working days',
    () {
      final result = buildDirectionShipmentSuggestions(
        weekStart: f.week,
        asOf: f.now,
        shipments: [
          for (final m in programMaterials)
            f.shipment(
              m,
              f.week.subtract(const Duration(days: 7)),
              30,
              material: m,
            ),
        ],
        floorCounts: {for (final m in programMaterials) m: 5},
        floorCountedAt: {for (final m in programMaterials) m: f.now},
        production: [
          for (final m in programMaterials)
            for (final r in f.productionHistory())
              DirectionProductionHistoryRecord(
                date: r.date,
                materialCode: m,
                quantity: 30,
                shiftKey: 'DAY',
              ),
        ],
        movements: f.supply(),
        impacts: [],
        savedProgramConditions: {
          'daily_capacity': 30,
          'day_share': 100,
          'days': List.generate(5, (d) => {'working': d != 1}),
        },
      );
      expect(result.suggestions, hasLength(3));
      expect(
        result.suggestions.every(
          (s) => !s.suggestedDate.isBefore(f.week.add(const Duration(days: 3))),
        ),
        isTrue,
      );
      expect(result.dailyCapacity, 30);
    },
  );

  test(
    'suggestions feed automatic opening yard and observed capacity into a feasible program',
    () {
      final report = f.propose(floor: 5, targets: []);
      final bundle = DirectionShipmentPlanningBundle(
        weekStartDate: f.week,
        weekEndDate: f.week.add(const Duration(days: 5)),
        shipments: [
          for (final s in report.suggestions)
            f.shipment(
              'accepted',
              s.suggestedDate,
              s.suggestedQuantity,
              client: s.clientName,
              status: 'confirmado',
            ),
        ],
        projections: [],
        suggestedShipments: report.suggestions,
        floorCountByMaterial: {},
        floorCountUpdatedAt: f.now,
        expectedDays: [],
        activeCapacityImpacts: [],
        impactSummaries: [],
        maintenanceAlerts: [],
        productionHistory: f.productionHistory(),
        suggestionReport: report,
      );
      final conditions = ProgramConditions.fromReference(bundle);
      expect(conditions.yard[f.national], 5);
      expect(conditions.dailyCapacity, 30);
      final demands = ProgramDemand.fromShipments(f.week, bundle.shipments);
      final lines = generateOperatingProgram(f.week, conditions, demands);
      final evaluation = evaluateOperatingProgram(
        f.week,
        conditions,
        demands,
        lines,
      );
      expect(evaluation.valid, isTrue);
      expect(programQuantity(lines), report.coverage.first.productionGoal(30));
    },
  );
}
