import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_engine.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_shipment_suggestions_test.dart' as f;

void main() {
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
