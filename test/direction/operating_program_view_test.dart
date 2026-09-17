import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_engine.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_repository.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final week = DateTime(2026, 9, 14);
DirectionShipmentPlanningBundle fixture({
  List<DirectionProductionHistoryRecord> productionHistory = const [],
}) => DirectionShipmentPlanningBundle(
  weekStartDate: week,
  weekEndDate: week.add(const Duration(days: 5)),
  shipments: [
    for (var d = 0; d < 5; d++)
      DirectionShipmentPlanRecord.fromRow({
        'id': 's$d',
        'ship_date': programDate(week.add(Duration(days: d))),
        'client_name': [
          'SAN PABLO',
          'EL PALOMAR',
          'BIO PAPEL',
          'SAN LUIS',
          'QUERETANA',
        ][d],
        'planning_material_code': programMaterials[d % 3],
        'quantity_unit': 'PACAS',
        'planned_units': 30,
        'priority': 'normal',
        'status': 'confirmado',
      }),
  ],
  projections: [],
  suggestedShipments: [],
  floorCountByMaterial: {},
  floorCountUpdatedAt: null,
  expectedDays: [],
  activeCapacityImpacts: [],
  impactSummaries: [],
  maintenanceAlerts: [],
  productionHistory: productionHistory,
);

class TestPrograms extends OperatingProgramRepository {
  List<OperatingProgram> saved = [];
  bool fail = false;
  @override
  Future<List<OperatingProgram>> loadVersions(DateTime week) async {
    if (fail) throw StateError('unavailable');
    return [...saved];
  }

  @override
  Future<List<ProgramLine>> loadActual(DateTime week) async =>
      emptyProgramLines();
  @override
  Future<OperatingProgram> saveDraft({
    required DateTime week,
    required int expectedVersion,
    required ProgramConditions conditions,
    required List<ProgramDemand> demands,
    required List<ProgramLine> lines,
  }) async {
    final p = OperatingProgram(
      id: 'v${saved.length + 1}',
      week: week,
      version: saved.length + 1,
      status: 'draft',
      conditions: conditions,
      demands: [...demands],
      lines: [...lines],
    );
    saved.insert(0, p);
    return p;
  }

  @override
  Future<OperatingProgram> approve(String id, {bool execute = false}) async {
    final old = saved.firstWhere((p) => p.id == id);
    final p = OperatingProgram(
      id: id,
      week: old.week,
      version: old.version,
      status: execute ? 'executing' : 'approved',
      conditions: old.conditions,
      demands: old.demands,
      lines: old.lines,
      operational: true,
    );
    saved[saved.indexOf(old)] = p;
    return p;
  }
}

Widget harness(
  TestPrograms repo, {
  GlobalKey? capture,
  DirectionShipmentPlanningBundle? bundle,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: kDirectionBg,
    body: RepaintBoundary(
      key: capture,
      child: ColoredBox(
        color: kDirectionBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OperatingProgramView(
            bundle: bundle ?? fixture(),
            repository: repo,
            onWeekChanged: (_) async {},
          ),
        ),
      ),
    ),
  ),
);

Future<void> generate(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Generar programa semanal'));
  await tester.tap(find.text('Generar programa semanal'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final path = Platform.environment['DICSA_PROGRAM_QA_FONTS'];
    if (path == null) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('Ahem', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family);
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$path/$file').readAsBytes()),
        ),
      );
      await loader.load();
    }
  });
  testWidgets(
    'generates a persisted draft, restores it and fixes an approved version',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = TestPrograms();
      final capture = GlobalKey();
      await tester.pumpWidget(harness(repo, capture: capture));
      await tester.pumpAndSettle();
      await generate(tester);
      expect(repo.saved, hasLength(1));
      expect(programQuantity(repo.saved.single.lines), 150);
      expect(
        evaluateOperatingProgram(
          week,
          repo.saved.single.conditions,
          repo.saved.single.demands,
          repo.saved.single.lines,
        ).valid,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      final output = Platform.environment['DICSA_PROGRAM_QA_PNG'];
      if (output != null) {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(output).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('v1 · Borrador'), findsWidgets);
      await tester.ensureVisible(find.text('Aprobar programa'));
      await tester.tap(find.text('Aprobar programa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.status, 'approved');
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('generate-operating-program')),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Crear nuevo borrador'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar nueva versión'));
      await tester.pumpAndSettle();
      expect(repo.saved, hasLength(2));
      expect(repo.saved.last.status, 'approved');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'single click edits, instant validation, escape reverts and blocked data cannot save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = TestPrograms();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await generate(tester);
      final cell = find.byKey(const ValueKey('v1:0:0:PACA_NACIONAL'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      final input = find.descendant(of: cell, matching: find.byType(TextField));
      expect(input, findsOneWidget);
      await tester.enterText(input, '90');
      await tester.pump();
      expect(find.textContaining('exceden'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.textContaining('exceden'), findsNothing);
      final capacity = find.widgetWithText(
        TextFormField,
        'Capacidad máxima diaria',
      );
      await tester.ensureVisible(capacity);
      await tester.enterText(capacity, '0');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('generate-operating-program')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'compact width stays within the viewport and load errors are explicit',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = TestPrograms()..fail = true;
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudo leer el historial'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('generate-operating-program')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final action in ['Mover', 'Cancelar', 'Escape', 'Barrera']) {
    testWidgets('move dialog closes safely with $action and can reopen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = TestPrograms();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await generate(tester);
      final original = repo.saved.single.lines;
      final moveButton = find.widgetWithText(
        OutlinedButton,
        'Mover producción',
      );
      await tester.ensureVisible(moveButton);
      await tester.tap(moveButton);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final quantity = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      await tester.enterText(quantity, '9999');
      await tester.tap(find.widgetWithText(FilledButton, 'Mover'));
      await tester.pumpAndSettle();
      expect(
        find.text('Revisa la cantidad disponible en el origen.'),
        findsOneWidget,
      );
      await tester.enterText(quantity, '5');
      switch (action) {
        case 'Escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'Barrera':
          await tester.tapAt(const Offset(10, 10));
        default:
          await tester.tap(
            find.descendant(of: dialog, matching: find.text(action)),
          );
      }
      // The route is still mounted during the reverse transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(tester.takeException(), isNull);
      if (action == 'Mover') {
        await tester.ensureVisible(find.text('Guardar nueva versión'));
        await tester.tap(find.text('Guardar nueva versión'));
        await tester.pumpAndSettle();
        expect(repo.saved, hasLength(2));
        final moved = repo.saved.first.lines;
        expect(programQuantity(moved), programQuantity(original));
        for (final before in original) {
          final after = moved.singleWhere((line) => line.key == before.key);
          final delta =
              before.material == programMaterials.first && before.shift == 0
              ? (before.day == 0
                    ? -5
                    : before.day == 1
                    ? 5
                    : 0)
              : 0;
          expect(after.quantity, before.quantity + delta);
        }
      } else {
        expect(repo.saved, hasLength(1));
        expect(find.textContaining('Sin guardar'), findsNothing);
      }
      await tester.ensureVisible(moveButton);
      await tester.tap(moveButton);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(quantity).controller!.text, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final width in [1440.0, 420.0]) {
    testWidgets(
      'shows production history at width $width and saves a frozen reference',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1050));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        List<DirectionProductionHistoryRecord> records(int national) => [
          for (var w = 1; w <= 6; w++)
            for (var d = 0; d < 5; d++)
              for (var m = 0; m < 3; m++)
                DirectionProductionHistoryRecord(
                  date: week.subtract(Duration(days: w * 7 - d)),
                  materialCode: programMaterials[m],
                  shiftKey: m == 0 ? 'NIGHT' : 'DAY',
                  quantity: m == 0 ? national : 10,
                ),
        ];
        final repo = TestPrograms();
        final capture = GlobalKey();
        await tester.pumpWidget(
          harness(
            repo,
            capture: capture,
            bundle: fixture(productionHistory: records(30)),
          ),
        );
        await tester.pumpAndSettle();
        final reference = find.text('Histórico de Producción · 6/6 semanas');
        await tester.ensureVisible(reference);
        await tester.tap(reference);
        await tester.pumpAndSettle();
        expect(find.textContaining('250.0 pacas/semana'), findsOneWidget);
        final share = find.widgetWithText(
          TextFormField,
          'Capacidad turno día (%)',
        );
        await tester.ensureVisible(share);
        await tester.enterText(share, '90');
        final apply = find.text(
          'Aplicar proporción histórica: 40% Día / 60% Noche',
        );
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: share, matching: find.byType(TextField)),
              )
              .controller!
              .text,
          '40',
        );
        expect(tester.takeException(), isNull);
        final output = Platform.environment['DICSA_HISTORY_QA_PNG'];
        if (output != null && width == 1440) {
          await tester.ensureVisible(reference);
          await tester.pumpAndSettle();
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(output).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await generate(tester);
        expect(repo.saved.first.conditions.dayShare, 40);
        final original = repo.saved.first.conditions.history!.toJson();
        await tester.pumpWidget(
          harness(
            repo,
            capture: capture,
            bundle: fixture(productionHistory: records(60)),
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.saved.single.conditions.history!.toJson(), original);
        await tester.ensureVisible(find.text('Generar programa semanal'));
        await tester.tap(find.text('Generar programa semanal'));
        await tester.pumpAndSettle();
        expect(repo.saved.length, 2);
        expect(repo.saved.first.conditions.history!.average(), 400);
        expect(repo.saved.last.conditions.history!.toJson(), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
