import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_documental_dashboard_card.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_documental_summary_test.dart' as f;

Widget harness(
  f.DirectionDocumentalTestRepository repository, {
  double width = 420,
  double scale = 1,
  Future<void> Function()? onOpen,
  GlobalKey? captureKey,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: kDirectionBg,
    body: DocumentalRepositoryScope(
      repository: repository,
      child: Center(
        child: RepaintBoundary(
          key: captureKey,
          child: ColoredBox(
            color: kDirectionBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: width,
                  height: 428,
                  child: DirectionDocumentalDashboardCard(
                    onOpenManagement: onOpen ?? () async {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder entry(String id) =>
    find.byKey(ValueKey('direction-documental-record-$id'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final path = Platform.environment['DICSA_DOCUMENTAL_QA_FONTS'];
    if (path == null) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
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

  Future<void> dispose(
    WidgetTester tester,
    f.DirectionDocumentalTestRepository repository,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await repository.events.close();
  }

  for (final width in [420.0, 320.0]) {
    testWidgets(
      'documental card fits at $width and keeps expirations and procedures separate',
      (tester) async {
        final repository = f.fixture();
        final capture = GlobalKey();
        await tester.pumpWidget(
          harness(
            repository,
            width: width,
            scale: width == 320 ? 1.3 : 1,
            captureKey: capture,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Gestión Documental'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Vence hoy'), findsOneWidget);
        expect(find.text('Resp. Responsable de prueba'), findsWidgets);
        expect(entry('p1'), findsNothing);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['DICSA_DOCUMENTAL_QA_PNG'];
        if (output != null && width == 420) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(output).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(
          find.byKey(const ValueKey('direction-documental-procedures')),
        );
        await tester.pumpAndSettle();
        expect(entry('d1'), findsNothing);
        expect(entry('p1'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
        await tester.scrollUntilVisible(
          entry('p2'),
          70,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sin vencimiento'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await dispose(tester, repository);
      },
    );
  }

  testWidgets(
    'rows open the existing saved record preview and defer refresh until it closes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = f.fixture();
      var hubOpens = 0;
      await tester.pumpWidget(
        harness(repository, onOpen: () async => hubOpens++),
      );
      await tester.pumpAndSettle();
      await tester.tap(entry('d1'));
      await tester.pumpAndSettle();
      expect(repository.opened, ['d1']);
      expect(find.text('Expediente guardado · Versión 1'), findsOneWidget);
      expect(find.text('Editar expediente'), findsOneWidget);
      final loads = repository.dashboardLoads;
      repository.add(f.record('d1', status: 'Completado'));
      repository.events.add(null);
      await tester.pumpAndSettle();
      expect(repository.dashboardLoads, loads);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(repository.dashboardLoads, greaterThan(loads));
      expect(entry('d1'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('direction-documental-procedures')),
      );
      await tester.pumpAndSettle();
      await tester.tap(entry('p1'));
      await tester.pumpAndSettle();
      expect(repository.opened, ['d1', 'p1']);
      expect(find.text('Expediente guardado · Versión 1'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Abrir Gestión Documental'));
      await tester.pumpAndSettle();
      expect(hubOpens, 1);
      expect(repository.saves, 0);
      expect(tester.takeException(), isNull);
      await dispose(tester, repository);
    },
  );

  testWidgets('realtime updates and server midnight recalculate the lists', (
    tester,
  ) async {
    final repository = f.fixture()
      ..overviewMidnight = const Duration(seconds: 20);
    await tester.pumpWidget(harness(repository));
    await tester.pumpAndSettle();
    repository.add(
      f.record(
        'p1',
        kind: DocumentalRecordKind.procedures,
        status: 'Completado',
      ),
    );
    repository.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    repository.todayOverride = DateTime(2026, 9, 16);
    repository.overviewMidnight = const Duration(days: 1);
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(entry('d1'), findsNothing);
    expect(find.text('Al 16/09/2026'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await dispose(tester, repository);
  });

  testWidgets(
    'failed queries show unavailable data and retry without false zeros',
    (tester) async {
      final repository = f.fixture()..failPages = true;
      await tester.pumpWidget(harness(repository));
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron consultar los expedientes.'),
        findsOneWidget,
      );
      expect(find.text('0'), findsNothing);
      expect(entry('d1'), findsNothing);
      repository.failPages = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(entry('d1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await dispose(tester, repository);
    },
  );

  testWidgets('empty lists show true zero counts and explicit messages', (
    tester,
  ) async {
    final repository = f.DirectionDocumentalTestRepository()
      ..todayOverride = DateTime(2026, 9, 15);
    await tester.pumpWidget(harness(repository));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(2));
    expect(
      find.text('No hay documentos por vencer en los próximos 15 días.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('direction-documental-procedures')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay trámites en proceso.'), findsOneWidget);
    await dispose(tester, repository);
  });
}
