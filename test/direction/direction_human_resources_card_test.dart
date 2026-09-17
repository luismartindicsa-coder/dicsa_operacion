import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_human_resources_dashboard_card.dart';
import 'package:dicsa_operacion/app/direction/direction_human_resources_summary.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/hr/human_resources_period_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'direction_human_resources_summary_test.dart' as f;

DirectionHumanResourcesSummary fixture({String selected = f.period}) =>
    f.summary(
      selected: selected,
      drafts: [
        f.draft('1', fiscal: 45200, cash: 7250, status: 'publicado'),
        f.draft('2', fiscal: 12800, cash: 4500, status: 'listo'),
      ],
      vacations: [
        f.event('v1', '2026-09-17', end: '2026-09-20'),
        f.event('v2', '2026-09-23', employee: '2', end: '2026-09-26'),
      ],
      permissions: [
        f.event('p1', '2026-09-15', permission: 'permiso_con_goce'),
        f.event(
          'p2',
          '2026-09-16',
          employee: '2',
          permission: 'permiso_sin_goce',
          status: 'aplicado',
        ),
      ],
      attendance: [
        f.absence('2026-09-14'),
        f.absence('2026-09-15'),
        f.absence('2026-09-15', employee: '2'),
      ],
    );

Widget harness({
  required Future<DirectionHumanResourcesSummary> Function() loader,
  Future<void> Function()? onOpen,
  GlobalKey? captureKey,
  double textScale = 1,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: kDirectionBg,
    body: SingleChildScrollView(
      child: Center(
        child: RepaintBoundary(
          key: captureKey,
          child: ColoredBox(
            color: kDirectionBg,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1288),
                  child: DirectionHumanResourcesDashboardCard(
                    loadSummary: loader,
                    onOpenHumanResources: onOpen ?? () async {},
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final path = Platform.environment['DICSA_HR_QA_FONTS'];
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

  for (final width in [1360.0, 740.0, 390.0]) {
    testWidgets(
      'large HR card shows period totals and all sections at width $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 950));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final capture = GlobalKey();
        await tester.pumpWidget(
          harness(
            loader: () async => fixture(),
            captureKey: capture,
            textScale: width == 390 ? 1.2 : 1,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Recursos Humanos'), findsOneWidget);
        expect(find.text('Total fiscal'), findsOneWidget);
        expect(find.text('Total flujo'), findsOneWidget);
        expect(find.text('\$58,000.00'), findsOneWidget);
        expect(find.text('\$24,550.00'), findsOneWidget);
        expect(find.text('Vacaciones próximas'), findsOneWidget);
        expect(find.text('Permisos'), findsOneWidget);
        expect(find.text('Faltas'), findsOneWidget);
        expect(find.text('ANA MARTÍNEZ'), findsWidgets);
        expect(find.textContaining('Permiso sin goce'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['DICSA_HR_QA_PNG'];
        if (output != null && width == 1360) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1.25);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(output).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'period selection is persisted for RH and opens its existing dashboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1360, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opens = 0;
      await tester.pumpWidget(
        harness(
          loader: () async => fixture(
            selected: await HumanResourcesPeriodContext.readSelectedLabel(),
          ),
          onOpen: () async {
            opens++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seleccionar periodo'), findsOneWidget);
      expect(find.text('\$0.00'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('direction-rh-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(f.period));
      await tester.pumpAndSettle();
      expect(await HumanResourcesPeriodContext.readSelectedLabel(), f.period);
      expect(find.text('\$58,000.00'), findsOneWidget);
      await tester.tap(find.byTooltip('Abrir Recursos Humanos'));
      await tester.pumpAndSettle();
      expect(opens, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'refresh failures preserve amounts with a stale-data notice then recover',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1360, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fail = false;
      var calls = 0;
      await tester.pumpWidget(
        harness(
          loader: () async {
            calls++;
            if (fail) throw StateError('offline');
            return fixture();
          },
        ),
      );
      await tester.pumpAndSettle();
      fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('últimos datos consultados'), findsOneWidget);
      expect(find.text('\$58,000.00'), findsOneWidget);
      fail = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.textContaining('últimos datos consultados'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an initial failure displays an unavailable state without zero amounts',
    (tester) async {
      await tester.pumpWidget(
        harness(loader: () async => throw StateError('offline')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudo consultar el resumen de RH.'),
        findsOneWidget,
      );
      expect(find.text('\$0.00'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a pending refresh cannot replace a newly selected period', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1360, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await HumanResourcesPeriodContext.select(f.period);
    final pending = Completer<DirectionHumanResourcesSummary>();
    var calls = 0;
    await tester.pumpWidget(
      harness(
        loader: () async {
          calls++;
          if (calls == 2) return pending.future;
          return fixture(
            selected: await HumanResourcesPeriodContext.readSelectedLabel(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('direction-rh-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(f.previous));
    await tester.pump();
    pending.complete(fixture());
    await tester.pumpAndSettle();
    expect(find.text(f.previous), findsOneWidget);
    expect(find.text('\$58,000.00'), findsNothing);
    expect(find.text('Sin prenómina guardada'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
