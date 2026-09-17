import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_engine.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

import 'operating_program_engine_test.dart' as f;

OperatingProgram program({
  ProgramConditions? conditions,
  List<ProgramDemand>? demands,
  List<ProgramLine>? lines,
}) {
  final c = conditions ?? f.conditions();
  final d = demands ?? [f.demand(4, 40)];
  return OperatingProgram(
    id: 'pdf',
    week: f.week,
    version: 2,
    status: 'draft',
    conditions: c,
    demands: d,
    lines: lines ?? generateOperatingProgram(f.week, c, d),
  );
}

void expectOneA4Page(List<int> bytes) {
  final pdf = latin1.decode(bytes);
  expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf), hasLength(1));
  expect(
    pdf,
    matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+841\.\d+\s+595\.\d+\s*\]')),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reference shipments reconcile exactly and print one A4 landscape page',
    () async {
      final c = f.conditions(
        share: 60,
        yard: [21, 22, 32],
        days: [
          const ProgramDayCondition(),
          const ProgramDayCondition(),
          const ProgramDayCondition(working: false),
          const ProgramDayCondition(),
          const ProgramDayCondition(nightAvailable: false),
        ],
      );
      final demands = [
        for (final (day, name, material, quantity) in [
          (0, 'Mendieta', 0, 40),
          (0, 'Toluca', 2, 40),
          (1, 'Mendieta', 0, 40),
          (1, 'Ecofibras', 0, 40),
          (3, 'Mendieta', 0, 40),
          (3, 'San Luis', 0, 65),
          (3, 'El Palomar', 1, 70),
          (4, 'Mendieta', 0, 40),
          (4, 'Toluca', 2, 40),
        ])
          ProgramDemand(
            id: '$day-$name',
            destination: name,
            material: programMaterials[material],
            date: f.week.add(Duration(days: day)),
            quantity: quantity,
          ),
      ];
      final p = program(conditions: c, demands: demands);
      final data = OperatingProgramPrintData(p);
      expect(data.shipmentTotals, [265, 70, 80]);
      expect(data.yardUsed, [21, 22, 32]);
      expect(data.productionTotals, [244, 48, 48]);
      expect(data.evaluation.requiredTotal, 340);
      expect(data.alerts, isEmpty);
      expect(programQuantity(p.lines, day: 2), 0);
      expect(programQuantity(p.lines, day: 4, shift: 1), 0);
      expect(
        data.destinations(3),
        'Mendieta: 40 Nacional; San Luis: 65 Nacional; El Palomar: 70 Limpio',
      );
      final bytes = await buildOperatingProgramPdf(
        p,
        operationalNotes: ['El Palomar: 70 Limpio pasa al jueves'],
      );
      expectOneA4Page(bytes);
      final path = Platform.environment['DICSA_OPERATOR_QA_PDF'];
      if (path != null) await File(path).writeAsBytes(bytes);
    },
  );

  test(
    'subtracts only yard used, keeps materials and destinations separate',
    () {
      final p = program(
        conditions: f.conditions(yard: [100, 5, 0]),
        demands: [
          f.demand(0, 20),
          f.demand(1, 12, material: 1),
          f.demand(2, 8, material: 2),
        ],
      );
      final data = OperatingProgramPrintData(p);
      expect(data.yardUsed, [20, 5, 0]);
      expect(data.productionTotals, [0, 7, 8]);
      expect(
        data.reconciliation,
        'Nacional 20 - 20 = 0  |  Limpio 12 - 5 = 7  |  Americano 8 - 0 = 8',
      );
    },
  );

  test('same-day night does not conceal a dated material shortfall', () async {
    final p = program(
      demands: [f.demand(0, 10)],
      lines: f.withQuantity(0, 1, 0, 10),
    );
    final data = OperatingProgramPrintData(p);
    expect(data.alerts.single, contains('14/09/2026: faltan 10 Nacional'));
    final bytes = await buildOperatingProgramPdf(p);
    expectOneA4Page(bytes);
    final path = Platform.environment['DICSA_OPERATOR_ALERT_QA_PDF'];
    if (path != null) await File(path).writeAsBytes(bytes);
  });

  test('rejects surplus production even if all shipments are covered', () {
    expect(
      () => OperatingProgramPrintData(
        program(demands: [f.demand(4, 10)], lines: f.withQuantity(0, 0, 0, 11)),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          contains('excede las 10 pacas requeridas'),
        ),
      ),
    );
  });

  test('rejects overcapacity and production on unavailable days or shifts', () {
    for (final (c, lines) in [
      (f.conditions(), f.withQuantity(0, 0, 0, 101)),
      (
        f.conditions(
          days: List.filled(5, const ProgramDayCondition(working: false)),
        ),
        f.withQuantity(0, 0, 0, 10),
      ),
      (
        f.conditions(
          days: List.filled(
            5,
            const ProgramDayCondition(nightAvailable: false),
          ),
        ),
        f.withQuantity(4, 1, 0, 10),
      ),
    ]) {
      expect(
        () => OperatingProgramPrintData(
          program(conditions: c, demands: [f.demand(4, 150)], lines: lines),
        ),
        throwsStateError,
      );
    }
  });

  test(
    'keeps movement and cancellation notices without mutating saved totals',
    () {
      final p = program(
        demands: [
          f.demand(1, 20, id: 'moved'),
          f.demand(2, 5, id: 'cancelled'),
        ],
      );
      final notes = programPdfShipmentNotes(p, [
        DirectionShipmentPlanRecord.fromRow({
          'id': 'moved',
          'ship_date': '2026-09-17',
          'planning_material_code': 'PACA_NACIONAL',
          'quantity_unit': 'PACAS',
          'planned_units': 20,
          'client_name': 'CLIENTE moved',
          'status': 'confirmado',
          'notes': 'Pasa al jueves',
        }),
        DirectionShipmentPlanRecord.fromRow({
          'id': 'cancelled',
          'ship_date': '2026-09-16',
          'planning_material_code': 'PACA_NACIONAL',
          'quantity_unit': 'PACAS',
          'planned_units': 5,
          'client_name': 'CLIENTE cancelled',
          'status': 'cancelado',
        }),
        DirectionShipmentPlanRecord.fromRow({
          'id': 'kg',
          'ship_date': '2026-09-16',
          'planning_material_code': 'CHATARRA',
          'quantity_unit': 'KG',
          'planned_units': 500,
          'client_name': 'METAL',
          'status': 'cancelado',
        }),
      ]);
      expect(notes.join(' '), contains('Cambio posterior al programa'));
      expect(
        notes.join(' '),
        contains('Cancelado: CLIENTE cancelled: 5 Nacional'),
      );
      expect(notes.join(' '), isNot(contains('METAL')));
      expect(
        OperatingProgramPrintData(p, operationalNotes: notes).shipmentTotals,
        [25, 0, 0],
      );
      expect(p.demands.first.date, DateTime(2026, 9, 15));
    },
  );

  test('does not silently discard unsupported units or weekend shipments', () {
    expect(
      () => OperatingProgramPrintData(
        program(demands: [f.demand(5, 10)], lines: emptyProgramLines()),
      ),
      throwsStateError,
    );
  });

  test(
    'refuses an unreadable one-page export instead of clipping destinations',
    () async {
      final demands = [
        for (var i = 0; i < 75; i++)
          ProgramDemand(
            id: '$i',
            destination:
                'DESTINO COMPLETO $i CON DETALLE QUE NO SE DEBE RECORTAR',
            material: programMaterials[0],
            date: f.week.add(const Duration(days: 4)),
            quantity: 1,
          ),
      ];
      await expectLater(
        buildOperatingProgramPdf(program(demands: demands)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('no cabe legible'),
          ),
        ),
      );
    },
  );
}
