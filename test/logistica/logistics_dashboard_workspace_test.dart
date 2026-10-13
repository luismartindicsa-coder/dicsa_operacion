import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/logistica/logistics_area_chrome.dart';
import 'package:dicsa_operacion/app/logistica/logistics_dashboard_summary.dart';
import 'package:dicsa_operacion/app/logistica/logistics_dashboard_missing_cards.dart';
import 'package:dicsa_operacion/app/logistica/logistics_theme.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'logistics_dashboard_summary_test.dart' as f;

const missingModules = [
  LogisticsDashboardModule.units,
  LogisticsDashboardModule.incidents,
  LogisticsDashboardModule.performance,
  LogisticsDashboardModule.savings,
  LogisticsDashboardModule.catalogs,
];

Widget harness({
  required Future<LogisticsDashboardSnapshot> Function() load,
  Map<LogisticsDashboardModule, Future<void> Function()>? actions,
  double scale = 1,
}) => MaterialApp(
  theme: ThemeData.light(),
  debugShowCheckedModeBanner: false,
  home: AreaThemeScope(
    tokens: logisticsAreaTokens,
    child: Scaffold(
      backgroundColor: kLogisticsSilverBackgroundTop,
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LogisticsDashboardMissingCards(
            load: load,
            onOpen: actions ?? {for (final m in missingModules) m: () async {}},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    final root = Platform.environment['DICSA_LOGISTICS_QA_FONTS'];
    if (root == null) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(
            File('$root/$file').readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });

  for (final (width, scale) in [
    (1440.0, 1.0),
    (1100.0, 1.0),
    (900.0, 1.0),
    (390.0, 1.3),
  ]) {
    testWidgets('only missing summaries fit at $width, scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 1440 ? 900 : 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        harness(load: () async => f.fixtureSnapshot(), scale: scale),
      );
      await tester.pumpAndSettle();
      for (final module in missingModules) {
        final card = find.byKey(ValueKey('logistics-summary-${module.name}'));
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final output = Platform.environment['DICSA_LOGISTICS_QA_DIR'];
      if (output != null) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('logistics-summary-units')),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final layer =
              tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            Offset.zero & tester.view.physicalSize,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/dashboard-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('each module opens with one click and refreshes on return', (
    tester,
  ) async {
    var loads = 0;
    final opens = <LogisticsDashboardModule>[];
    await tester.pumpWidget(
      harness(
        load: () async {
          loads++;
          return f.fixtureSnapshot();
        },
        actions: {
          for (final m in missingModules)
            m: () async {
              opens.add(m);
            },
        },
      ),
    );
    await tester.pumpAndSettle();
    for (final module in missingModules) {
      final title = find.descendant(
        of: find.byKey(ValueKey('logistics-summary-${module.name}')),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
    }
    expect(opens, missingModules);
    expect(loads, 6);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'loading, isolated errors and silent recovery keep navigation available',
    (tester) async {
      final first = Completer<LogisticsDashboardSnapshot>();
      var calls = 0;
      await tester.pumpWidget(
        harness(
          load: () {
            calls++;
            return calls == 1
                ? first.future
                : Future.value(f.fixtureSnapshot());
          },
        ),
      );
      await tester.pump();
      expect(find.text('Cargando…'), findsNWidgets(5));
      first.complete(
        LogisticsDashboardSnapshot.fromRows(
          now: f.dashboardDate,
          rows: f.dashboardFixture(),
          failedSources: {'logistics_unit_states'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Datos no disponibles'), findsOneWidget);
      expect(find.text('1,190 km'), findsOneWidget);
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(find.text('Datos no disponibles'), findsNothing);
      expect(find.text('unidades disponibles'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'second click while a page is opening does not duplicate navigation',
    (tester) async {
      final opening = Completer<void>();
      var count = 0;
      await tester.pumpWidget(
        harness(
          load: () async => f.fixtureSnapshot(),
          actions: {
            LogisticsDashboardModule.units: () {
              count++;
              return opening.future;
            },
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estado de Unidades'));
      await tester.tap(find.text('Estado de Unidades'));
      expect(count, 1);
      opening.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'area menu preserves permitted destinations and one-click navigation',
    (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AreaThemeScope(
              tokens: logisticsAreaTokens,
              child: LogisticsAreaSidePanel(
                currentLabel: kLogisticsNavDashboardLabel,
                canReturnToDirection: false,
                onNavigate: opened.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(kLogisticsNavDirectionDashboardLabel), findsNothing);
      await tester.ensureVisible(find.text(kLogisticsNavPerformanceLabel));
      await tester.tap(find.text(kLogisticsNavPerformanceLabel));
      expect(opened, [kLogisticsNavPerformanceLabel]);
      expect(tester.takeException(), isNull);
    },
  );
}
