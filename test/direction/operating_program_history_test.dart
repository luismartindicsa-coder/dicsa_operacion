import 'dart:math';
import 'dart:io';

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_engine.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

import 'operating_program_engine_test.dart' as fixtures;

ProgramProductionHistory history(int Function(int, int, int) quantity) =>
    ProgramProductionHistory.fromRecords(fixtures.week, [
      for (var w = 1; w <= 6; w++)
        for (var d = 0; d < 5; d++)
          for (var s = 0; s < 2; s++)
            for (var m = 0; m < 3; m++)
              DirectionProductionHistoryRecord(
                date: fixtures.week.subtract(Duration(days: 7 * w - d)),
                materialCode: programMaterials[m],
                shiftKey: programShifts[s],
                quantity: quantity(d, s, m),
              ),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'exports an operator program with its saved historical reference',
    () async {
      final c = fixtures.conditions().copyWith(
        history: history((d, s, m) => 10 + m * 5),
      );
      final demands = [
        for (var m = 0; m < 3; m++) fixtures.demand(4, 40, material: m),
      ];
      final p = OperatingProgram(
        id: 'history-pdf',
        week: fixtures.week,
        version: 1,
        status: 'draft',
        conditions: c,
        demands: demands,
        lines: generateOperatingProgram(fixtures.week, c, demands),
      );
      final bytes = await buildOperatingProgramPdf(p);
      expect(bytes.length, greaterThan(1000));
      final path = Platform.environment['DICSA_HISTORY_QA_PDF'];
      if (path != null) await File(path).writeAsBytes(bytes);
    },
  );
  test(
    'reference excludes current/future weeks, weekends, kg and unknown shifts',
    () {
      final week = fixtures.week;
      DirectionProductionHistoryRecord record(
        DateTime date, {
        String material = 'PACA_NACIONAL',
        String shift = 'DAY',
        int quantity = 10,
      }) => DirectionProductionHistoryRecord(
        date: date,
        materialCode: material,
        shiftKey: shift,
        quantity: quantity,
      );
      final h = ProgramProductionHistory.fromRecords(week, [
        record(week.subtract(const Duration(days: 7)), quantity: 20),
        record(week.subtract(const Duration(days: 14)), quantity: 40),
        record(week),
        record(week.add(const Duration(days: 1))),
        record(week.subtract(const Duration(days: 49))),
        record(week.subtract(const Duration(days: 2))),
        record(week.subtract(const Duration(days: 7)), material: 'PAPEL'),
        record(week.subtract(const Duration(days: 7)), shift: ''),
      ]);
      expect(h.recordCount, 2);
      expect(h.observedWeeks.length, 2);
      expect(h.average(day: 0), 30);
      expect(h.unknownShiftCount, 1);
      expect(h.dayShare, 100);
      expect(
        ProgramProductionHistory.fromJson(h.toJson()).toJson(),
        h.toJson(),
      );
      final c = fixtures.conditions().copyWith(history: h);
      expect(
        ProgramConditions.fromJson(c.toJson()).history!.toJson(),
        h.toJson(),
      );
      expect(
        ProgramConditions.fromJson(fixtures.conditions().toJson()).history,
        isNull,
      );
    },
  );

  test(
    'daily load follows actual weekday output rather than an equal invented pattern',
    () {
      final h = history(
        (d, s, m) => s == 0 && m == 0 ? [80, 40, 20, 40, 20][d] : 0,
      );
      final c = fixtures.conditions(share: 100).copyWith(history: h);
      final demands = [fixtures.demand(4, 100)];
      final lines = generateOperatingProgram(fixtures.week, c, demands);
      expect(
        [for (var d = 0; d < 5; d++) programQuantity(lines, day: d)],
        [40, 20, 10, 20, 10],
      );
      expect(
        evaluateOperatingProgram(fixtures.week, c, demands, lines).valid,
        isTrue,
      );
      expect(programQuantity(lines), 100);
    },
  );
  test(
    'equal observations spread each material between comparable days and shifts',
    () {
      final c = fixtures.conditions().copyWith(
        history: history((d, s, m) => 10),
      );
      final demands = [
        for (var m = 0; m < 3; m++) fixtures.demand(4, 30, material: m),
      ];
      final lines = generateOperatingProgram(fixtures.week, c, demands);
      expect(
        evaluateOperatingProgram(fixtures.week, c, demands, lines).valid,
        isTrue,
      );
      expect(programQuantity(lines), 90);
      expect(programQuantity(lines, shift: 1), inInclusiveRange(38, 42));
      for (final m in programMaterials) {
        for (var d = 0; d < 4; d++) {
          expect(
            programQuantity(lines, material: m, day: d),
            inInclusiveRange(5, 8),
          );
          expect(
            (programQuantity(lines, material: m, day: d, shift: 0) -
                    programQuantity(lines, material: m, day: d, shift: 1))
                .abs(),
            lessThanOrEqualTo(1),
          );
        }
      }
    },
  );

  test(
    'assigns national to its observed night shift and clean to day regardless of shipment order',
    () {
      final h = history(
        (d, s, m) => (m == 0 && s == 1) || (m == 1 && s == 0) ? 40 : 0,
      );
      final c = fixtures.conditions().copyWith(history: h);
      for (final reverse in [false, true]) {
        final demands = [
          fixtures.demand(4, 60, id: reverse ? 'z' : 'a'),
          fixtures.demand(4, 60, material: 1, id: reverse ? 'a' : 'z'),
        ];
        final lines = generateOperatingProgram(fixtures.week, c, demands);
        expect(
          programQuantity(lines, material: programMaterials[0], shift: 1),
          60,
        );
        expect(
          programQuantity(lines, material: programMaterials[1], shift: 0),
          60,
        );
        expect(programQuantity(lines, day: 4, shift: 1), 0);
        expect(
          evaluateOperatingProgram(fixtures.week, c, demands, lines).valid,
          isTrue,
        );
      }
    },
  );

  test(
    'historical preferences cannot postpone Monday demand or exceed configured capacity',
    () {
      final h = history((d, s, m) => s == 1 && m == 0 ? 40 : 0);
      final c = fixtures.conditions().copyWith(history: h);
      final demands = [fixtures.demand(0, 80)];
      final lines = generateOperatingProgram(fixtures.week, c, demands);
      final result = evaluateOperatingProgram(fixtures.week, c, demands, lines);
      expect(programQuantity(lines, day: 0, shift: 0), 50);
      expect(programQuantity(lines), 50);
      expect(result.missingTotal, 30);
      expect(result.violations, isEmpty);
      expect(
        result.historicalWarnings.any((w) => w.contains('mayor ritmo')),
        isTrue,
      );
    },
  );

  test(
    'missing material history is explicit and never adds production beyond demand net of yard',
    () {
      final h = history((d, s, m) => m == 0 ? 40 : 0);
      final c = fixtures.conditions(yard: [0, 10, 0]).copyWith(history: h);
      final demands = [fixtures.demand(4, 30, material: 1)];
      final lines = generateOperatingProgram(fixtures.week, c, demands);
      final result = evaluateOperatingProgram(fixtures.week, c, demands, lines);
      expect(programQuantity(lines), 20);
      expect(programQuantity(lines, material: programMaterials[0]), 0);
      expect(
        result.historicalWarnings.any(
          (w) => w.contains('Limpio: sin historial propio'),
        ),
        isTrue,
      );
    },
  );

  test(
    'varied histories preserve maximal feasible coverage across closures, materials and deadlines',
    () {
      final random = Random(208);
      for (var run = 0; run < 150; run++) {
        final samples = List.generate(30, (_) => random.nextInt(50));
        final h = history((d, s, m) => samples[d * 6 + s * 3 + m]);
        final c = fixtures
            .conditions(
              capacity: 20 + random.nextInt(81),
              share: random.nextInt(101),
              yard: List.generate(3, (_) => random.nextInt(30)),
              days: List.generate(
                5,
                (_) => ProgramDayCondition(
                  working: random.nextInt(5) != 0,
                  dayAvailable: random.nextInt(5) != 0,
                  nightAvailable: random.nextInt(5) != 0,
                  lossPercent: random.nextInt(3) * 25,
                ),
              ),
            )
            .copyWith(history: h);
        final demands = [
          for (var d = 0; d < 5; d++)
            for (var m = 0; m < 3; m++)
              fixtures.demand(d, random.nextInt(50) + 1, material: m),
        ];
        final lines = generateOperatingProgram(fixtures.week, c, demands);
        final result = evaluateOperatingProgram(
          fixtures.week,
          c,
          demands,
          lines,
        );
        expect(result.violations, isEmpty, reason: 'run $run');
        expect(
          programQuantity(lines) + result.missingTotal,
          result.requiredTotal,
          reason: 'run $run',
        );
        for (final m in programMaterials) {
          expect(
            programQuantity(lines, material: m),
            lessThanOrEqualTo(result.requiredByMaterial[m]!),
          );
        }
      }
    },
  );
}
