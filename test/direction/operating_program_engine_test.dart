import 'dart:io';
import 'dart:math';

import 'package:dicsa_operacion/app/direction/operating_program/operating_program_engine.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_pdf.dart';
import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:flutter_test/flutter_test.dart';

final week = DateTime(2026, 9, 14);
ProgramConditions conditions({
  int capacity = 100,
  int share = 50,
  List<int> yard = const [0, 0, 0],
  List<ProgramDayCondition>? days,
}) => ProgramConditions(
  dailyCapacity: capacity,
  dayShare: share,
  yard: {for (var i = 0; i < 3; i++) programMaterials[i]: yard[i]},
  days: days ?? List.filled(5, const ProgramDayCondition()),
);
ProgramDemand demand(int day, int quantity, {int material = 0, String? id}) =>
    ProgramDemand(
      id: id ?? '$day-$material',
      destination: 'CLIENTE ${id ?? '$day-$material'}',
      material: programMaterials[material],
      date: week.add(Duration(days: day)),
      quantity: quantity,
    );
List<ProgramLine> withQuantity(
  int day,
  int shift,
  int material,
  int quantity,
) => [
  for (final l in emptyProgramLines())
    l.day == day && l.shift == shift && l.material == programMaterials[material]
        ? ProgramLine(day, shift, l.material, quantity)
        : l,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'takes only confirmed carton bales Monday to Friday without changing source records',
    () {
      final records = [
        for (final (day, material, status, unit) in [
          (14, 'PACA_NACIONAL', 'confirmado', 'PACAS'),
          (15, 'PACA_LIMPIA', 'planeado', 'PACAS'),
          (16, 'PACA_AMERICANA', 'embarcado', 'PACAS'),
          (17, 'CHATARRA', 'confirmado', 'KG'),
          (18, 'CAPLE', 'confirmado', 'PACAS'),
          (19, 'PACA_NACIONAL', 'confirmado', 'PACAS'),
        ])
          DirectionShipmentPlanRecord.fromRow({
            'id': '$day',
            'ship_date': '2026-09-$day',
            'planning_material_code': material,
            'status': status,
            'quantity_unit': unit,
            'planned_units': 50,
            'client_name': 'Destino $day',
          }),
      ];
      final demands = ProgramDemand.fromShipments(week, records);
      expect(demands, hasLength(1));
      expect(demands.single.quantity, 50);
      expect(records.map((r) => r.status), [
        'confirmado',
        'planeado',
        'embarcado',
        'confirmado',
        'confirmado',
        'confirmado',
      ]);
    },
  );
  test(
    'empty week requires no production and a Friday night block does not explain a Friday deadline',
    () {
      final c = conditions(
        days: List.generate(
          5,
          (i) => ProgramDayCondition(nightAvailable: i != 4),
        ),
      );
      expect(programQuantity(generateOperatingProgram(week, c, [])), 0);
      final demands = [demand(4, 600)];
      final result = evaluateOperatingProgram(
        week,
        c,
        demands,
        generateOperatingProgram(week, c, demands),
      );
      expect(
        result.shortfalls.single.causes,
        isNot(contains('Turno no disponible')),
      );
      expect(
        result.shortfalls.single.causes.any(
          (s) => s.startsWith('Falta de capacidad'),
        ),
        isTrue,
      );
    },
  );
  test(
    'uses yard first by material and never makes unnecessary production',
    () {
      final c = conditions(yard: [100, 0, 0]);
      final demands = [
        demand(0, 40),
        demand(1, 30),
        demand(2, 30, material: 1),
      ];
      final lines = generateOperatingProgram(week, c, demands);
      final result = evaluateOperatingProgram(week, c, demands, lines);
      expect(result.valid, isTrue);
      expect(programQuantity(lines, material: programMaterials[0]), 0);
      expect(programQuantity(lines, material: programMaterials[1]), 30);
      expect(result.yardApplied[0][programMaterials[0]], 40);
      expect(result.closingBalances.last[programMaterials[0]], 30);
    },
  );
  test('Monday shipment cannot use Monday night or future production', () {
    final c = conditions();
    final demands = [demand(0, 80)];
    final lines = generateOperatingProgram(week, c, demands);
    final result = evaluateOperatingProgram(week, c, demands, lines);
    expect(programQuantity(lines), 50);
    expect(result.missingTotal, 30);
    expect(result.shortfalls.single.shipment.date, week);
    for (final slot in [(0, 1), (1, 0), (4, 1)]) {
      expect(
        evaluateOperatingProgram(
          week,
          c,
          demands,
          withQuantity(slot.$1, slot.$2, 0, 80),
        ).missingTotal,
        80,
      );
    }
  });
  test('night can cover following day and not own day', () {
    final c = conditions();
    final lines = withQuantity(0, 1, 0, 40);
    expect(
      evaluateOperatingProgram(week, c, [demand(1, 40)], lines).valid,
      isTrue,
    );
    expect(
      evaluateOperatingProgram(week, c, [demand(0, 40)], lines).missingTotal,
      40,
    );
  });
  test(
    'shares daily capacity across materials and balances the minimum daily peak',
    () {
      final c = conditions();
      final demands = [for (var m = 0; m < 3; m++) demand(4, 60, material: m)];
      final lines = generateOperatingProgram(week, c, demands);
      expect(evaluateOperatingProgram(week, c, demands, lines).valid, isTrue);
      expect(
        [for (var d = 0; d < 5; d++) programQuantity(lines, day: d)],
        [36, 36, 36, 36, 36],
      );
      expect(programQuantity(lines, day: 4, shift: 1), 0);
    },
  );
  test('honors holidays, blocked shifts and machinery capacity', () {
    final c = conditions(
      days: [
        const ProgramDayCondition(working: false),
        const ProgramDayCondition(nightAvailable: false),
        const ProgramDayCondition(lossPercent: 50),
        const ProgramDayCondition(lossPercent: 100),
        const ProgramDayCondition(nightAvailable: false),
      ],
    );
    final demands = [demand(0, 10), demand(4, 200)];
    final lines = generateOperatingProgram(week, c, demands);
    final result = evaluateOperatingProgram(week, c, demands, lines);
    expect(programQuantity(lines, day: 0), 0);
    expect(programQuantity(lines, day: 1, shift: 1), 0);
    expect(programQuantity(lines, day: 2), lessThanOrEqualTo(50));
    expect(programQuantity(lines, day: 3), 0);
    expect(programQuantity(lines, day: 4, shift: 1), 0);
    expect(result.missingTotal, 60);
    expect(result.violations, isEmpty);
    expect(result.shortfalls.first.causes, contains('Día no laborable'));
  });
  test(
    'manual move preserves material and total but revalidates deadlines',
    () {
      final c = conditions();
      final original = withQuantity(0, 0, 0, 40);
      final moved = moveProgramProduction(
        original,
        fromDay: 0,
        fromShift: 0,
        toDay: 1,
        toShift: 1,
        material: programMaterials[0],
        quantity: 20,
      );
      expect(programQuantity(moved), 40);
      expect(
        evaluateOperatingProgram(week, c, [demand(0, 40)], moved).missingTotal,
        20,
      );
      expect(
        () => moveProgramProduction(
          original,
          fromDay: 0,
          fromShift: 0,
          toDay: 1,
          toShift: 1,
          material: programMaterials[0],
          quantity: 41,
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'manual excess, blocked shift and wrong material cannot pass validation',
    () {
      final c = conditions(
        days: List.filled(5, const ProgramDayCondition(nightAvailable: false)),
      );
      expect(
        evaluateOperatingProgram(
          week,
          c,
          [],
          withQuantity(0, 0, 0, 101),
        ).violations,
        isNotEmpty,
      );
      expect(
        evaluateOperatingProgram(
          week,
          c,
          [],
          withQuantity(1, 1, 1, 1),
        ).violations,
        isNotEmpty,
      );
      expect(
        evaluateOperatingProgram(week, c, [
          demand(1, 40, material: 1),
        ], withQuantity(0, 0, 0, 40)).missingTotal,
        40,
      );
    },
  );
  test(
    'randomized schedules cover exactly feasible demand and never exceed a slot',
    () {
      final random = Random(89);
      for (var run = 0; run < 250; run++) {
        final c = conditions(
          capacity: 10 + random.nextInt(91),
          share: random.nextInt(101),
          yard: List.generate(3, (_) => random.nextInt(40)),
          days: List.generate(
            5,
            (_) => ProgramDayCondition(
              working: random.nextInt(5) != 0,
              dayAvailable: random.nextInt(4) != 0,
              nightAvailable: random.nextInt(4) != 0,
              lossPercent: random.nextInt(3) * 25,
            ),
          ),
        );
        final demands = [
          for (var d = 0; d < 5; d++)
            for (var m = 0; m < 3; m++)
              demand(d, 1 + random.nextInt(45), material: m),
        ];
        final lines = generateOperatingProgram(week, c, demands);
        final result = evaluateOperatingProgram(week, c, demands, lines);
        expect(result.violations, isEmpty, reason: 'run $run');
        expect(
          programQuantity(lines) + result.missingTotal,
          result.requiredTotal,
          reason: 'run $run',
        );
        for (var d = 0; d < 5; d++) {
          for (var s = 0; s < 2; s++) {
            expect(
              programQuantity(lines, day: d, shift: s),
              lessThanOrEqualTo(c.slotCapacity(d, s)),
            );
          }
        }
      }
    },
  );
  test(
    'conditions and version snapshots round trip without sharing shipment records',
    () {
      final c = conditions(yard: [10, 20, 30]);
      expect(ProgramConditions.fromJson(c.toJson()).toJson(), c.toJson());
      final s = demand(1, 50);
      expect(ProgramDemand.fromJson(s.toJson()).toJson(), s.toJson());
      expect(
        programDemandFingerprint([demand(1, 20), demand(0, 10)]),
        programDemandFingerprint([demand(0, 10), demand(1, 20)]),
      );
    },
  );
  test(
    'exports the full operator week including destinations and balances',
    () async {
      final c = conditions(
        yard: [20, 10, 0],
        days: List.generate(
          5,
          (d) => ProgramDayCondition(nightAvailable: d != 4),
        ),
      );
      final demands = [
        demand(0, 30),
        demand(1, 50, material: 1),
        demand(2, 90, material: 2),
        demand(3, 70),
        demand(4, 80, material: 1),
      ];
      final p = OperatingProgram(
        id: 'qa',
        week: week,
        version: 1,
        status: 'draft',
        conditions: c,
        demands: demands,
        lines: generateOperatingProgram(week, c, demands),
      );
      final bytes = await buildOperatingProgramPdf(p);
      expect(bytes.length, greaterThan(1000));
      final output = Platform.environment['DICSA_PROGRAM_QA_PDF'];
      if (output != null) await File(output).writeAsBytes(bytes);
    },
  );
}
