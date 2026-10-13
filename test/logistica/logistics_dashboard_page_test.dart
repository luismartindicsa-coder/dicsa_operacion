import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/logistica/logistics_dashboard_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_dashboard_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logistics_dashboard_summary_test.dart' as f;

void main() {
  setUpAll(() async {
    final root = Platform.environment['DICSA_LOGISTICS_QA_FONTS'];
    if (root != null) {
      for (final (family, file) in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(
              File('$root/$file').readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://dashboard-page.invalid',
      anonKey: 'key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        final table = r.url.pathSegments.last;
        final key =
            table == 'logistics_diesel_consumption' &&
                r.url.queryParameters['limit'] == '1'
            ? 'diesel_latest'
            : table;
        final rows = f.dashboardFixture()[key] ?? [];
        final today = DateUtils.dateOnly(DateTime.now());
        final difference = today.difference(
          DateUtils.dateOnly(f.dashboardDate),
        );
        final current = rows
            .map(
              (row) => {
                for (final entry in row.entries)
                  entry.key:
                      [
                        'entry_date',
                        'due_date',
                        'service_date',
                      ].contains(entry.key)
                      ? DateTime.parse(
                          entry.value.toString(),
                        ).add(difference).toIso8601String().substring(0, 10)
                      : entry.value,
              },
            )
            .toList();
        return http.Response(
          jsonEncode(current),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  for (final width in [1440.0]) {
    testWidgets('complete dashboard shell and menu fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: LogisticsDashboardPage(instantOpen: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Datos no disponibles'), findsNothing);
      expect(find.text('Saldo actual de diesel'), findsOneWidget);
      expect(find.text('Resumen de Viajes y Servicios'), findsOneWidget);
      expect(find.text('Accesos del área'), findsNothing);
      expect(find.text('Hub'), findsNothing);
      expect(find.text('Encargado de Logística'), findsNothing);
      expect(
        find.byKey(const ValueKey('logistics-summary-daily')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('logistics-summary-diesel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('logistics-summary-gasoline')),
        findsNothing,
      );
      for (final module in [
        LogisticsDashboardModule.units,
        LogisticsDashboardModule.incidents,
        LogisticsDashboardModule.performance,
        LogisticsDashboardModule.savings,
        LogisticsDashboardModule.catalogs,
      ]) {
        expect(
          find.byKey(ValueKey('logistics-summary-${module.name}')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      final output = Platform.environment['DICSA_LOGISTICS_QA_DIR'];
      Future<void> capture(String name) async {
        if (output == null) return;
        await tester.runAsync(() async {
          final layer =
              tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            Offset.zero & tester.view.physicalSize,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/$name-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('restored-page');
      await tester.ensureVisible(
        find.byKey(const ValueKey('logistics-summary-units')),
      );
      await tester.pumpAndSettle();
      await capture('added-cards');
      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Navegación Logística'), findsOneWidget);
      expect(find.text('Dashboard Dirección'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture('navigation');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Navegación Logística').hitTestable(), findsNothing);
      expect(find.byIcon(Icons.menu_rounded).hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // The fake host cannot accept the original dashboard's subscriptions.
      Supabase.instance.client.realtime.reconnectTimer.reset();
    });
  }
}
