import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/execution/direction_execution_repository.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_shipment_suggestions_test.dart' as f;

DirectionExecutionActual actual({
  String kind = 'shipment',
  DateTime? date,
  int quantity = 25,
  List<int> loads = const [25],
  String client = 'MENDIETA',
  String shift = '',
  bool active = true,
  int? observed = 30,
  int? planned = 40,
  List<DirectionExecutionAgendaChange> agendaChanges = const [],
}) => DirectionExecutionActual(
  kind: kind,
  date: date ?? f.week,
  material: f.national,
  quantity: quantity,
  loads: loads,
  client: client,
  shift: shift,
  active: active,
  observedQuantity: observed,
  plannedQuantity: planned,
  revision: 1,
  agendaSyncedRevision: agendaChanges.isEmpty ? 0 : 1,
  agendaChanges: agendaChanges,
);

void main() {
  test(
    'agenda reconciliation does not become its own source or change the original comparison',
    () {
      final before = f.shipment(
        's',
        f.week,
        40,
        client: 'MENDIETA',
        status: 'confirmado',
      );
      final after = f.shipment('s', f.week, 30, client: 'MENDIETA');
      final a = actual(
        quantity: 30,
        loads: [30],
        observed: 35,
        agendaChanges: [
          DirectionExecutionAgendaChange(before: before, after: after),
        ],
      );
      final rows = buildDirectionExecutionRows(
        kind: 'shipment',
        week: f.week,
        shipments: [after],
        movements: [
          DirectionShipmentMovement(
            date: f.week,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: f.national,
            client: 'MENDIETA',
            bales: 35,
          ),
        ],
        production: [],
        confirmations: [a],
      );
      expect(rows.single.planned, 30);
      expect(rows.single.baseline, 40);
      expect(rows.single.observed, 35);
      expect(rows.single.actual, 30);
      expect(rows.single.sourceChanged, false);
      expect(directionShipmentSourcePlans([after], [a]).single, same(before));
      final inventory = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: f.week.add(const Duration(days: 1)),
        counts: {f.national: 100},
        countedAt: {f.national: f.week},
        production: [],
        shipments: [after],
        movements: [
          DirectionShipmentMovement(
            date: f.week,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: f.national,
            client: 'MENDIETA',
            bales: 35,
          ),
        ],
        executionActuals: [a],
      );
      expect(inventory.current[f.national], 70);
    },
  );

  test(
    'unplanned actual added to agenda stays absent from raw sources, including after undo',
    () {
      final after = f.shipment('added', f.week, 25, client: 'MENDIETA');
      final a = actual(
        observed: null,
        planned: null,
        agendaChanges: [DirectionExecutionAgendaChange(after: after)],
      );
      final row = buildDirectionExecutionRows(
        kind: 'shipment',
        week: f.week,
        shipments: [after],
        movements: [],
        production: [],
        confirmations: [a],
      ).single;
      expect(row.observed, isNull);
      expect(row.baseline, isNull);
      expect(row.sourceChanged, false);
      final cancelled = f.shipment(
        'added',
        f.week,
        25,
        client: 'MENDIETA',
        status: 'cancelado',
      );
      final cleared = actual(
        active: false,
        agendaChanges: [DirectionExecutionAgendaChange(after: cancelled)],
      );
      expect(directionShipmentSourcePlans([cancelled], [cleared]), isEmpty);
      final manual = f.shipment('added', f.week, 30, client: 'MENDIETA');
      expect(
        directionShipmentSourcePlans([manual], [a]).single,
        same(manual),
        reason: 'later manual edits are new source observations',
      );
    },
  );

  test(
    'zero cancellation remains comparable and does not create a legacy shipped source',
    () {
      final before = f.shipment(
        's',
        f.week,
        40,
        client: 'MENDIETA',
        status: 'confirmado',
      );
      final after = f.shipment(
        's',
        f.week,
        40,
        client: 'MENDIETA',
        status: 'cancelado',
      );
      final a = actual(
        quantity: 0,
        loads: [],
        observed: null,
        agendaChanges: [
          DirectionExecutionAgendaChange(before: before, after: after),
        ],
      );
      final row = buildDirectionExecutionRows(
        kind: 'shipment',
        week: f.week,
        shipments: [after],
        movements: [],
        production: [],
        confirmations: [a],
      ).single;
      expect(row.actual, 0);
      expect(row.baseline, 40);
      expect(row.difference, -40);
      expect(row.observed, isNull);
      expect(row.sourceChanged, false);
      expect(
        DirectionShipmentsStore.buildProjections(
          shipments: [after],
          floorCounts: {f.national: 50},
          expectedDays: [],
          executionActuals: [a],
          asOf: f.week,
        ).single.risk,
        DirectionShipmentRisk.cancelled,
      );
    },
  );

  test(
    'confirming unchanged totals preserves floor timestamps and machine attribution',
    () {
      final time = f.week.add(const Duration(hours: 8));
      final countTime = f.week.add(const Duration(hours: 10));
      final record = DirectionProductionHistoryRecord(
        date: f.week,
        materialCode: f.national,
        quantity: 20,
        shiftKey: 'DAY',
        compactadoraKey: 'c1',
        recordedAt: time,
      );
      final learned = directionProductionWithActuals(
        [record],
        [
          actual(
            kind: 'production',
            quantity: 20,
            shift: 'DAY',
            client: '',
            loads: [],
          ),
        ],
        before: f.week.add(const Duration(days: 1)),
      );
      expect(learned.single, same(record));
      final inventory = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: f.week.add(const Duration(days: 1)),
        counts: {f.national: 70},
        countedAt: {f.national: countTime},
        production: learned,
        shipments: [],
        movements: [
          DirectionShipmentMovement(
            date: f.week,
            recordedAt: time,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: f.national,
            client: 'MENDIETA',
            bales: 30,
          ),
        ],
        executionActuals: [
          actual(quantity: 30, loads: [30]),
        ],
      );
      expect(inventory.current[f.national], 70);
      expect(inventory.estimatedMaterials.contains(f.national), false);
    },
  );

  test(
    'preloads shipments by date, canonical client and material without double counting',
    () {
      final rows = buildDirectionExecutionRows(
        kind: 'shipment',
        week: f.week,
        shipments: [
          f.shipment('a', f.week, 40, client: 'MENDIETA'),
          f.shipment(
            'b',
            f.week,
            20,
            client: 'RICARDO MENDIETA',
            status: 'confirmado',
          ),
        ],
        movements: [
          DirectionShipmentMovement(
            date: f.week,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: f.national,
            client: 'Ricardo Mendieta',
            bales: 40,
          ),
        ],
        production: [],
        confirmations: [actual()],
      );
      expect(rows, hasLength(1));
      expect(rows.single.planned, 60);
      expect(rows.single.observed, 40);
      expect(rows.single.actual, 25);
      expect(
        rows.single.baseline,
        40,
        reason: 'the baseline saved at confirmation survives edits to the plan',
      );
      expect(rows.single.difference, -15);
      expect(rows.single.sourceChanged, true);
    },
  );

  test(
    'zero is confirmed execution; missing and future production cells remain unobserved',
    () {
      final rows = buildDirectionExecutionRows(
        kind: 'production',
        week: f.week,
        shipments: [],
        movements: [],
        production: [],
        confirmations: [
          actual(
            kind: 'production',
            quantity: 0,
            loads: [],
            client: '',
            shift: 'DAY',
          ),
        ],
      );
      expect(rows, hasLength(30));
      expect(rows.where((r) => r.actual != null), hasLength(1));
      expect(rows.firstWhere((r) => r.confirmed).difference, -40);
      expect(
        rows.where((r) => !r.confirmed).every((r) => r.difference == null),
        true,
      );
    },
  );

  test(
    'production correction replaces matching runs, learns zeros and keeps current-day raw events',
    () {
      final monday = f.week.subtract(const Duration(days: 7));
      final raw = [
        for (final q in [15, 25])
          DirectionProductionHistoryRecord(
            date: monday,
            materialCode: f.national,
            quantity: q,
            shiftKey: 'DAY',
          ),
      ];
      final corrections = [
        actual(
          kind: 'production',
          date: monday,
          quantity: 0,
          loads: [],
          client: '',
          shift: 'DAY',
        ),
      ];
      final learned = directionProductionWithActuals(
        raw,
        corrections,
        before: f.week,
      );
      expect(learned, hasLength(1));
      expect(learned.single.quantity, 0);
      final history = ProgramProductionHistory.fromRecords(f.week, learned);
      expect(history.observedWeeks, hasLength(1));
      expect(history.dayShare, 50);
      expect(
        directionProductionWithActuals(raw, corrections, before: monday),
        raw,
      );
      expect(
        directionProductionWithActuals(raw, [
          actual(kind: 'production', date: monday, active: false, shift: 'DAY'),
        ], before: f.week),
        raw,
      );
      expect(directionHistoricalDailyCapacity(f.week, learned), 0);
    },
  );

  test(
    'actual shipment credits only the outstanding portion, preserving all planned source quantities',
    () {
      final plans = [
        f.shipment('a', f.week, 40, client: 'MENDIETA'),
        f.shipment('b', f.week, 30, client: 'MENDIETA', status: 'confirmado'),
        f.shipment('c', f.week, 30, client: 'MENDIETA', status: 'confirmado'),
      ];
      final confirmed = [
        actual(quantity: 80, loads: [40, 40]),
      ];
      final remaining = directionOutstandingShipmentPlans(
        plans,
        confirmed,
        f.week,
      );
      expect(remaining.map((p) => p.id), ['a', 'c']);
      expect(remaining.last.plannedQuantity, 20);
      expect(plans.map((p) => p.plannedQuantity), [40, 30, 30]);
      final projections = DirectionShipmentsStore.buildProjections(
        shipments: plans,
        floorCounts: {f.national: 50},
        expectedDays: [],
        executionActuals: confirmed,
        asOf: f.week,
      );
      expect(
        projections.firstWhere((p) => p.plan.id == 'b').risk,
        DirectionShipmentRisk.shipped,
      );
      expect(
        projections
            .firstWhere((p) => p.plan.id == 'c')
            .projectedRemainingAfterQuantity,
        30,
      );
    },
  );

  test(
    'confirmed shipment replaces Operation and legacy outputs in physical inventory',
    () {
      final result = reconcileDirectionShipmentInventory(
        weekStart: f.week,
        asOf: f.week.add(const Duration(days: 1)),
        counts: {f.national: 100},
        countedAt: {f.national: f.week},
        production: [],
        shipments: [f.shipment('a', f.week, 40, client: 'MENDIETA')],
        movements: [
          DirectionShipmentMovement(
            date: f.week,
            flow: 'OUT',
            level: 'COMMERCIAL',
            material: f.national,
            client: 'MENDIETA',
            bales: 40,
          ),
        ],
        executionActuals: [
          actual(quantity: 30, loads: [30]),
        ],
      );
      expect(result.current[f.national], 70);
    },
  );

  test(
    'confirmed load sizes and corrected production change the next suggestions',
    () {
      final past = f.week.subtract(const Duration(days: 7));
      DirectionShipmentSuggestionReport propose(
        List<DirectionExecutionActual> actuals,
      ) => buildDirectionShipmentSuggestions(
        weekStart: f.week,
        asOf: f.now,
        shipments: [f.shipment('a', past, 60, client: 'MENDIETA')],
        floorCounts: {f.national: 100},
        floorCountedAt: {f.national: f.now},
        production: [
          DirectionProductionHistoryRecord(
            date: past,
            materialCode: f.national,
            quantity: 60,
            shiftKey: 'DAY',
          ),
        ],
        impacts: [],
        movements: f.supply(),
        executionActuals: actuals,
      );
      final baseline = propose([]);
      final corrected = propose([
        actual(date: past, quantity: 50, loads: [25, 25]),
        actual(
          kind: 'production',
          date: past,
          quantity: 20,
          loads: [],
          client: '',
          shift: 'DAY',
        ),
      ]);
      expect(baseline.suggestions.first.suggestedQuantity, 60);
      expect(
        corrected.suggestions.every((s) => s.suggestedQuantity == 25),
        true,
      );
      expect(corrected.suggestions, isNotEmpty);
      expect(
        corrected.productionThrough(f.national, f.week),
        lessThan(baseline.productionThrough(f.national, f.week)),
      );
      expect(
        corrected.observations.join(' '),
        contains('resultados confirmados'),
      );
    },
  );

  test(
    'per-load parsing accepts explicit zero and rejects invalid or ambiguous amounts',
    () {
      expect(parseDirectionActualLoads('42, 38'), [42, 38]);
      expect(parseDirectionActualLoads('0'), isEmpty);
      for (final text in ['', '2.5', '-1', '1,', '0,4', '10000001', 'text']) {
        expect(() => parseDirectionActualLoads(text), throwsFormatException);
      }
    },
  );
}
