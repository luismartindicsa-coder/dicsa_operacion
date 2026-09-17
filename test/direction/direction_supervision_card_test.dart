import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_supervision_dashboard_card.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_history_store.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:dicsa_operacion/app/shared/app_error_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ManagementReportRunRecord record(ManagementAreaKey area) =>
    ManagementReportRunRecord(
      areaKey: area,
      frequency: ManagementReportFrequency.weeklyFriday,
      generatedAt: DateTime(2026, 9, 18),
      generatedBy: 'Prueba',
      fileName: 'supervision_${area.name}_viernes.pdf',
    );

Widget harness({
  required DirectionSupervisionExporter exporter,
  Future<void> Function()? onOpen,
  double width = 420,
  double textScale = 1,
  GlobalKey? captureKey,
}) => MaterialApp(
  scaffoldMessengerKey: appScaffoldMessengerKey,
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
                child: DirectionSupervisionDashboardCard(
                  exportReport: exporter,
                  onOpenSupervision: onOpen ?? () async {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder generate(ManagementAreaKey area) =>
    find.byKey(ValueKey('direction-supervision-generate-${area.name}'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final path = Platform.environment['DICSA_SUPERVISION_QA_FONTS'];
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

  for (final width in [420.0, 320.0]) {
    testWidgets('normal card fits at width $width with internal scrolling', (
      tester,
    ) async {
      final capture = GlobalKey();
      await tester.pumpWidget(
        harness(
          width: width,
          textScale: width == 320 ? 1.3 : 1,
          captureKey: capture,
          exporter: ({required area, required frequency}) async => null,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Supervisión'), findsOneWidget);
      expect(find.text('13 áreas · Reporte semanal en PDF'), findsOneWidget);
      expect(find.text('Generar diario'), findsNothing);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['DICSA_SUPERVISION_QA_PNG'];
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
      await tester.scrollUntilVisible(
        generate(ManagementAreaKey.ventas),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(generate(ManagementAreaKey.ventas).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'every area generates its Friday report and hub remains accessible',
    (tester) async {
      final calls = <(ManagementAreaKey, ManagementReportFrequency)>[];
      var opens = 0;
      await tester.pumpWidget(
        harness(
          exporter: ({required area, required frequency}) async {
            calls.add((area.key, frequency));
            return record(area.key);
          },
          onOpen: () async => opens++,
        ),
      );
      await tester.pumpAndSettle();
      final areas = [
        ...managementAreaCatalog,
      ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      for (final area in areas) {
        await tester.scrollUntilVisible(
          generate(area.key),
          80,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(generate(area.key));
        await tester.pumpAndSettle();
        expect(calls.last, (area.key, ManagementReportFrequency.weeklyFriday));
        expect(
          find.textContaining('PDF guardado · ${area.title}:'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      expect(calls.length, managementAreaCatalog.length);
      await tester.tap(find.byTooltip('Abrir Supervisión'));
      await tester.pumpAndSettle();
      expect(opens, 1);
    },
  );

  testWidgets(
    'pending export prevents duplicate saves and reports cancellation',
    (tester) async {
      final pending = Completer<ManagementReportRunRecord?>();
      var calls = 0;
      await tester.pumpWidget(
        harness(
          exporter: ({required area, required frequency}) {
            calls++;
            return pending.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(generate(ManagementAreaKey.bascula));
      await tester.pump();
      expect(find.text('Generando viernes · Báscula…'), findsOneWidget);
      await tester.tap(generate(ManagementAreaKey.bascula));
      await tester.tap(generate(ManagementAreaKey.contabilidad));
      expect(calls, 1);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Guardado cancelado · Báscula.'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(generate(ManagementAreaKey.bascula))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('export error stays visible and permits a successful retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      harness(
        exporter: ({required area, required frequency}) async {
          if (calls++ == 0) throw const SocketException('Prueba sin conexión');
          return record(area.key);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(generate(ManagementAreaKey.bascula));
    await tester.pumpAndSettle();
    final message = find.byKey(const ValueKey('direction-supervision-message'));
    expect(
      tester.widget<Text>(message).data,
      contains('No se pudo generar el PDF de Báscula'),
    );
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(message).data, contains('Intenta de nuevo'));
    await tester.tap(generate(ManagementAreaKey.bascula));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(message).data,
      contains('PDF guardado · Báscula:'),
    );
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving dashboard during export does not update disposed state',
    (tester) async {
      final pending = Completer<ManagementReportRunRecord?>();
      await tester.pumpWidget(
        harness(
          exporter: ({required area, required frequency}) => pending.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(generate(ManagementAreaKey.bascula));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(record(ManagementAreaKey.bascula));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
