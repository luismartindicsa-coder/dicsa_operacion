import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_logistics_dashboard_card.dart';
import 'package:dicsa_operacion/app/direction/direction_logistics_summary.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_logistics_summary_test.dart' as f;

Widget harness({
  required Future<DirectionLogisticsWeeklySummary> Function(DateTime) loader,
  Future<void> Function(DirectionFuelType, DateTime)? onOpen,
  Future<void> Function()? onOpenLogistics,
  DateTime Function()? now,
  double width = 420,
  double textScale = 1,
  GlobalKey? captureKey,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: kDirectionBg,
    body: Center(
      child: RepaintBoundary(
        key: captureKey,
        child: ColoredBox(
          color: kDirectionBg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: SizedBox(
                width: width,
                height: 428,
                child: DirectionLogisticsDashboardCard(
                  loadSummary: loader,
                  now: now ?? () => DateTime(2026, 9, 15),
                  onOpenControl: onOpen ?? (_, _) async {},
                  onOpenLogistics: onOpenLogistics ?? () async {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final path = Platform.environment['DICSA_LOGISTICS_QA_FONTS'];
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

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  for (final width in [420.0, 320.0]) {
    testWidgets(
      'both fuel controls fit at width $width with separate driver lists',
      (tester) async {
        final capture = GlobalKey();
        await tester.pumpWidget(
          harness(
            loader: (date) async => f.fixture(date),
            width: width,
            textScale: width == 320 ? 1.3 : 1,
            captureKey: capture,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('870.50 L'), findsOneWidget);
        expect(find.text('123.50 L'), findsOneWidget);
        expect(find.text('Comprados: 1,500 L'), findsOneWidget);
        expect(find.text('LUIS GARCÍA'), findsOneWidget);
        expect(find.text('PEDRO RAMÍREZ'), findsNothing);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['DICSA_LOGISTICS_QA_PNG'];
        if (output != null && width == 420) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(output).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(
          find.byKey(const ValueKey('direction-logistics-gasoline')),
        );
        await tester.pumpAndSettle();
        expect(find.text('LUIS GARCÍA'), findsNothing);
        expect(find.text('PEDRO RAMÍREZ'), findsOneWidget);
        expect(find.text('2 registros de carga'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      },
    );
  }

  testWidgets(
    'drill-through sends fuel and chosen week and refreshes on return',
    (tester) async {
      final opens = <(DirectionFuelType, DateTime)>[];
      final loads = <DateTime>[];
      var hubOpens = 0;
      await tester.pumpWidget(
        harness(
          loader: (week) async {
            loads.add(week);
            return f.fixture(week);
          },
          onOpen: (fuel, week) async => opens.add((fuel, week)),
          onOpenLogistics: () async => hubOpens++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      expect(find.text('07/09 – 13/09 · 2026'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('direction-logistics-gasoline')),
      );
      await tester.tap(
        find.byKey(const ValueKey('direction-logistics-open-control')),
      );
      await tester.pumpAndSettle();
      expect(opens.single, (DirectionFuelType.gasoline, DateTime(2026, 9, 7)));
      expect(loads, [f.week, DateTime(2026, 9, 7), DateTime(2026, 9, 7)]);
      await tester.tap(find.byTooltip('Semana actual'));
      await tester.pumpAndSettle();
      final next = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Semana siguiente',
      );
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tester.tap(find.byTooltip('Abrir Logística'));
      await tester.pumpAndSettle();
      expect(hubOpens, 1);
      await dispose(tester);
    },
  );

  testWidgets('an in-flight refresh cannot put totals under a different week', (
    tester,
  ) async {
    final pending = Completer<DirectionLogisticsWeeklySummary>();
    var calls = 0;
    await tester.pumpWidget(
      harness(
        loader: (week) async {
          if (++calls == 2) return pending.future;
          return calls == 1 ? f.fixture(week) : f.summary(date: week);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pump();
    expect(find.text('870.50 L'), findsNothing);
    pending.complete(f.fixture());
    await tester.pumpAndSettle();
    expect(find.text('07/09 – 13/09 · 2026'), findsOneWidget);
    expect(find.text('870.50 L'), findsNothing);
    expect(find.text('Sin litros solicitados en esta semana.'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets(
    'background errors keep known data with a notice and recover automatically',
    (tester) async {
      var fail = false;
      await tester.pumpWidget(
        harness(
          loader: (week) async {
            if (fail) throw StateError('offline');
            return f.fixture(week);
          },
        ),
      );
      await tester.pumpAndSettle();
      fail = true;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('870.50 L'), findsOneWidget);
      expect(
        find.textContaining('Se conservan los últimos datos'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      fail = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Se conservan los últimos datos'),
        findsNothing,
      );
      await dispose(tester);
    },
  );

  testWidgets(
    'initial failure differs from an empty week without false zero liters',
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        harness(
          loader: (week) async {
            if (fail) throw StateError('offline');
            return f.summary(date: week);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron cargar los controles de combustible.'),
        findsOneWidget,
      );
      expect(find.text('0 L'), findsNothing);
      fail = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('0 L'), findsNWidgets(2));
      expect(
        find.text('Sin litros solicitados en esta semana.'),
        findsOneWidget,
      );
      await dispose(tester);
    },
  );

  testWidgets(
    'current week rolls over while a historical selection stays fixed',
    (tester) async {
      var now = DateTime(2026, 9, 20);
      await tester.pumpWidget(
        harness(now: () => now, loader: (week) async => f.fixture(week)),
      );
      await tester.pumpAndSettle();
      now = DateTime(2026, 9, 21);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('21/09 – 27/09 · 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      now = DateTime(2026, 9, 28);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('14/09 – 20/09 · 2026'), findsOneWidget);
      await dispose(tester);
    },
  );
}
