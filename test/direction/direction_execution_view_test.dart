import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/direction/execution/direction_execution_repository.dart';
import 'package:dicsa_operacion/app/direction/execution/direction_execution_view.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_shipment_suggestions_test.dart' as f;
import 'operating_program_view_test.dart' as p;

class ActualRepo extends DirectionExecutionRepository {
  final saved = <DirectionExecutionActual>[];
  bool fail = false;
  @override
  Future<DirectionExecutionActual> save({
    required DirectionExecutionRow row,
    required int quantity,
    required List<int> loads,
    required String notes,
    String? programId,
    bool clear = false,
  }) async {
    if (fail) throw StateError('Conflicto de revisión');
    final a = DirectionExecutionActual(
      kind: row.kind,
      date: row.date,
      material: row.material,
      client: row.client,
      shift: row.shift,
      quantity: quantity,
      loads: loads,
      notes: notes,
      plannedQuantity: row.confirmation?.plannedQuantity ?? row.planned,
      observedQuantity: row.observed,
      revision: (row.confirmation?.revision ?? 0) + 1,
      agendaSyncedRevision: row.kind == 'shipment'
          ? (row.confirmation?.revision ?? 0) + 1
          : 0,
      active: !clear,
      programId: programId,
    );
    saved.add(a);
    return a;
  }
}

DirectionShipmentPlanningBundle bundle({int observed = 35}) =>
    DirectionShipmentPlanningBundle(
      weekStartDate: f.week,
      weekEndDate: f.week.add(const Duration(days: 5)),
      shipments: [
        f.shipment('s', f.week, 40, client: 'MENDIETA', status: 'confirmado'),
      ],
      projections: [],
      suggestedShipments: [],
      floorCountByMaterial: {},
      floorCountUpdatedAt: null,
      expectedDays: [],
      activeCapacityImpacts: [],
      impactSummaries: [],
      maintenanceAlerts: [],
      shipmentMovements: [
        DirectionShipmentMovement(
          date: f.week,
          flow: 'OUT',
          level: 'COMMERCIAL',
          material: f.national,
          client: 'MENDIETA',
          bales: observed,
        ),
      ],
    );

Widget harness(
  ActualRepo repo, {
  DirectionShipmentPlanningBundle? data,
  GlobalKey? capture,
  VoidCallback? changed,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: kDirectionBg,
    body: RepaintBoundary(
      key: capture,
      child: ColoredBox(
        color: kDirectionBg,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DirectionExecutionView(
            kind: 'shipment',
            bundle: data ?? bundle(),
            repository: repo,
            asOf: DateTime(2026, 9, 23),
            onWeekChanged: (_) async {},
            onChanged: () async {
              changed?.call();
            },
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    final path = Platform.environment['DICSA_PROGRAM_QA_FONTS'];
    if (path == null) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('Ahem', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(await File('$path/$file').readAsBytes()),
          ),
        );
      await loader.load();
    }
  });
  Future<void> screen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Operation prefill supports correction, Enter save, preserved plan and restoring source',
    (tester) async {
      await screen(tester);
      final repo = ActualRepo();
      var refreshes = 0;
      await tester.pumpWidget(harness(repo, changed: () => refreshes++));
      await tester.pumpAndSettle();
      expect(find.text('Planeado: 40 pacas'), findsOneWidget);
      expect(find.text('Real: 35 pacas'), findsOneWidget);
      await tester.tap(find.text('Confirmar o corregir'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '35',
      );
      await tester.enterText(find.byType(TextField).first, '25, 10');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.saved.single.loads, [25, 10]);
      expect(refreshes, 1);
      expect(find.text('Confirmado · revisión 1'), findsOneWidget);
      expect(
        find.text('Agenda actualizada · 2 cargas embarcadas'),
        findsOneWidget,
      );
      await tester.tap(find.text('Usar dato de Operación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restablecer'));
      await tester.pumpAndSettle();
      expect(repo.saved.last.active, false);
      expect(refreshes, 2);
      expect(find.text('Planeado: 40 pacas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed save keeps input, silent refresh does not reset editing and zero can be confirmed',
    (tester) async {
      await screen(tester);
      final repo = ActualRepo()..fail = true;
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar o corregir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.pumpWidget(harness(repo, data: bundle(observed: 36)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '0',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Conflicto de revisión'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.quantity, 0);
      expect(find.text('Real: 0 pacas'), findsOneWidget);
      expect(find.text('Diferencia: -40 pacas'), findsOneWidget);
      expect(
        find.text('Agenda actualizada · embarques cancelados'),
        findsOneWidget,
      );
      expect(
        find.textContaining('El registro de origen cambió'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Escape cancels and adding a real unplanned shipment does not create a plan',
    (tester) async {
      await screen(tester);
      final repo = ActualRepo();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar o corregir'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      await tester.tap(find.text('Registrar embarque real'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Cliente adicional');
      await tester.enterText(fields.at(1), '38');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.client, 'CLIENTE ADICIONAL');
      expect(repo.saved.single.plannedQuantity, isNull);
      expect(find.text('Planeado: 40 pacas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Program has Planeado and Real tabs, missing production is not zero',
    (tester) async {
      await screen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: OperatingProgramView(
              bundle: p.fixture(),
              repository: p.TestPrograms(),
              executionRepository: ActualRepo(),
              onWeekChanged: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Planeado'), findsOneWidget);
      expect(find.text('Real'), findsOneWidget);
      await tester.tap(find.text('Real'));
      await tester.pumpAndSettle();
      expect(find.text('PRODUCCIÓN REAL'), findsOneWidget);
      expect(find.text('Real: — pacas'), findsWidgets);
      expect(find.text('Real: 0 pacas'), findsNothing);
      await tester.tap(find.text('Capturar real').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planeado'));
      await tester.pumpAndSettle();
      expect(find.text('PRODUCCIÓN REAL'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('actual cards visual review', (tester) async {
    await screen(tester);
    final capture = GlobalKey();
    await tester.pumpWidget(harness(ActualRepo(), capture: capture));
    await tester.pumpAndSettle();
    if (Platform.environment['DICSA_EXECUTION_QA'] case final String path) {
      final boundary =
          capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('future production cannot be confirmed and compact cards fit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: DirectionExecutionView(
            kind: 'production',
            bundle: bundle(),
            repository: ActualRepo(),
            asOf: DateTime(2026, 9, 23),
            onWeekChanged: (_) async {},
            onChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Capturar real').first;
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.text('Pendiente de ejecución'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
