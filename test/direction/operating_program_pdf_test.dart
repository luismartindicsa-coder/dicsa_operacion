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
    'one destination column consolidates daily loads and preserves each material',
    () {
      final data = OperatingProgramPrintData(
        program(
          demands: [
            for (final (id, day, destination, material, quantity) in [
              ('n1', 0, 'DESTINO A', 0, 20),
              ('n2', 0, 'DESTINO A', 0, 5),
              ('l1', 0, 'DESTINO A', 1, 7),
              ('a1', 1, 'DESTINO B', 2, 11),
            ])
              ProgramDemand(
                id: id,
                date: f.week.add(Duration(days: day)),
                destination: destination,
                material: programMaterials[material],
                quantity: quantity,
              ),
          ],
        ),
      );
      expect(data.destinationColumns, ['DESTINO A', 'DESTINO B']);
      expect(
        data.destinationQuantities(0, 'DESTINO A'),
        '25 Nacional\n7 Limpio',
      );
      expect(data.destinationQuantities(1, 'DESTINO B'), '11 Americano');
      expect(data.destinationQuantities(1, 'DESTINO A'), '0');
      expect(data.destinationQuantities(2, 'DESTINO B'), '0');
      expect(data.shipmentTotals, [25, 7, 11]);
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
    'nine destinations share one matrix without repeating weekday rows',
    () async {
      final demands = [
        for (var i = 0; i < 9; i++)
          ProgramDemand(
            id: '$i',
            destination:
                'DESTINO COMPLETO $i CON DETALLE QUE NO SE DEBE RECORTAR',
            material: programMaterials[0],
            date: f.week.add(const Duration(days: 4)),
            quantity: 1,
          ),
      ];
      final p = program(demands: demands);
      final before = OperatingProgramPrintData(p);
      final bytes = await buildOperatingProgramPdf(p);
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)),
        hasLength(2),
      );
      expect(before.shipmentTotals, [9, 0, 0]);
      expect(before.productionTotals, [9, 0, 0]);
      final path = Platform.environment['DICSA_OPERATOR_DETAIL_QA_PDF'];
      if (path != null) await File(path).writeAsBytes(bytes);
    },
  );
  test('long automatic explanations and observations do not add PDF pages', () async {
    final notes = [
      for (var i = 0; i < 12; i++)
        'CLIENTE $i: Propuesta semanal. Demanda histórica 42 pacas aún por cubrir. '
            'Carga habitual 42 pacas; 12 días con embarque realizado. Piso 6, '
            'producción disponible antes de la carga 110. Depende de producir según historial, '
            'entradas y turnos. Reserva mínima 5 pacas; compromisos posteriores protegidos.',
      'INICIO NOTA EXTENSA ${List.filled(120, 'Se conserva la observación operativa completa.').join(' ')} FIN NOTA EXTENSA',
    ];
    final bytes = await buildOperatingProgramPdf(
      program(),
      operationalNotes: notes,
    );
    expectOneA4Page(bytes);
    final path = Platform.environment['DICSA_OPERATOR_NOTES_QA_PDF'];
    if (path != null) await File(path).writeAsBytes(bytes);
  });
}
