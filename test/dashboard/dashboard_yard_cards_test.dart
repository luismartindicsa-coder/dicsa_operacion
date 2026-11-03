import 'dart:convert';

import 'package:dicsa_operacion/app/dashboard/dashboard_page.dart';
import 'package:dicsa_operacion/app/services/inventory_page.dart';
import 'package:dicsa_operacion/app/shared/utils/number_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NavigationObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }
}

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final firstCut = today.subtract(const Duration(days: 5));
  final entryDate = today.subtract(const Duration(days: 1));
  var latestExit = firstCut;
  var heavyEntryKg = 11420;
  String date(DateTime value) => value.toIso8601String().substring(0, 10);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://yard-cards.invalid',
      anonKey: 'key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final incoming = request.url.queryParameters['flow'] == 'eq.IN';
        final rows = switch (table) {
          'sites' => [
            {'id': 'public', 'name': 'PUBLICO'},
          ],
          'material_commercial_catalog_v2' => [
            {
              'id': 'heavy',
              'code': 'PESADO',
              'name': 'PESADO',
              'general_material': {'code': 'CHATARRA'},
            },
            {
              'id': 'mixed',
              'code': 'MIXTO',
              'name': 'MIXTO',
              'general_material': {'code': 'CHATARRA'},
            },
            {
              'id': 'generic',
              'code': 'CHATARRA',
              'name': 'CHATARRA',
              'general_material': {'code': 'CHATARRA'},
            },
          ],
          'dashboard_yard_manual_counts' => [
            {
              'widget_key': 'default_1_bales_total_total',
              'source_kind': 'bales_total',
              'count_units': 50,
              'weight_kg': 0,
              'counted_at': today.toUtc().toIso8601String(),
            },
            {
              'widget_key': 'default_8_commercial_material_total',
              'source_kind': 'commercial_material',
              'commercial_material_code': 'PESADO',
              'weight_kg': 99999,
              'counted_at': today.toUtc().toIso8601String(),
            },
          ],
          'inventory_movements_v2' => [
            if (incoming)
              {
                'id': 'in',
                'flow': 'IN',
                'inventory_level': 'GENERAL',
                'source_commercial_material_id': 'heavy',
                'op_date': date(entryDate),
                'net_kg': heavyEntryKg,
                'site': 'DICSA_CELAYA',
                'general_material': {'code': 'CHATARRA'},
                'source_commercial': {'code': 'PESADO', 'name': 'PESADO'},
              }
            else
              {
                'id': 'out',
                'flow': 'OUT',
                'inventory_level': 'COMMERCIAL',
                'commercial_material_id': 'heavy',
                'op_date': date(latestExit),
                'weight_kg': 100,
                'site': 'DICSA_CELAYA',
              },
            if (incoming)
              {
                'id': 'public-in',
                'flow': 'IN',
                'inventory_level': 'GENERAL',
                'source_commercial_material_id': 'generic',
                'counterparty_site_id': 'public',
                'op_date': date(entryDate),
                'net_kg': 4127,
                'site': 'DICSA_CELAYA',
                'general_material': {'code': 'CHATARRA'},
                'source_commercial': {'code': 'CHATARRA', 'name': 'CHATARRA'},
              }
            else
              {
                'id': 'mixed-out',
                'flow': 'OUT',
                'inventory_level': 'COMMERCIAL',
                'commercial_material_id': 'mixed',
                'op_date': date(firstCut),
                'weight_kg': 100,
                'site': 'DICSA_CELAYA',
              },
          ],
          'material_transformation_runs_v2' => [
            {
              'id': 'transformation',
              'op_date': date(entryDate),
              'source_general_material': {'code': 'CHATARRA'},
            },
          ],
          'material_transformation_run_outputs_v2' => [
            {
              'run_id': 'transformation',
              'output_weight_kg': 99999,
              'commercial_material': {
                'code': 'PESADO',
                'name': 'PESADO',
                'general_material': {'code': 'CHATARRA'},
              },
            },
            {
              'run_id': 'transformation',
              'output_weight_kg': 1600,
              'output_unit_count': 2,
              'commercial_material': {
                'code': 'PACA_NACIONAL',
                'name': 'PACA NACIONAL',
                'general_material': {'code': 'CARTON'},
              },
            },
          ],
          _ => <Map<String, dynamic>>[],
        };
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets(
    'scrap cards use movements, bales remain manual, and refresh resets stock',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _NavigationObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const DashboardPage(instantOpen: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('${formatDecimal(11420, decimals: 1)} kg'),
        findsOneWidget,
      );
      expect(
        find.text('${formatDecimal(99999, decimals: 1)} kg'),
        findsNothing,
      );
      expect(find.text('50 pacas'), findsOneWidget);
      expect(
        find.text('${formatDecimal(4127, decimals: 1)} kg'),
        findsOneWidget,
      );
      expect(find.text('Sin salida registrada'), findsNWidgets(5));
      expect(tester.takeException(), isNull);

      Map<String, Map<DateTime, double>> chartValues(String title) {
        final chart = find.ancestor(
          of: find.text(title),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_ChartCard',
          ),
        );
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: chart,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter.runtimeType.toString() ==
                      '_ProductionBarChartPainter',
            ),
          ),
        );
        final Iterable<dynamic> series = (paint.painter as dynamic).seriesList;
        return {
          for (final s in series)
            s.label as String: {
              for (final p in s.points) p.day as DateTime: p.value as double,
            },
        };
      }

      final daily = chartValues('Entradas diarias de chatarra');
      expect(daily.keys, unorderedEquals(['Pesado', 'Mixto']));
      expect(daily['Pesado']![entryDate], 11420);
      expect(daily['Mixto']![entryDate], 4127);
      expect(daily['Pesado']![today], 0);
      expect(daily['Pesado'], hasLength(90));
      expect(
        chartValues('Transformación diaria de cartón').values.single[entryDate],
        2,
      );
      expect(find.text('Transformación diaria de patio'), findsNothing);

      await tester.ensureVisible(find.text('Pesado').first);
      await tester.tap(find.text('Pesado').first);
      final route = observer.lastPushed! as PageRouteBuilder<dynamic>;
      expect(
        route.pageBuilder(
          tester.element(find.byType(DashboardPage)),
          const AlwaysStoppedAnimation(1),
          const AlwaysStoppedAnimation(0),
        ),
        isA<InventoryPage>(),
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Entradas diarias de chatarra'));
      await tester.tap(find.text('Entradas diarias de chatarra'));
      final chartRoute = observer.lastPushed! as PageRouteBuilder<dynamic>;
      expect(
        chartRoute.pageBuilder(
          tester.element(find.byType(DashboardPage)),
          const AlwaysStoppedAnimation(1),
          const AlwaysStoppedAnimation(0),
        ),
        isA<InventoryPage>(),
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Pacas en patio'));
      await tester.tap(find.text('Pacas en patio'));
      await tester.pumpAndSettle();
      expect(find.text('Pacas contadas'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Manual bale count layout',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      latestExit = today;
      heavyEntryKg = 12000;
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      final heavyCard = find.ancestor(
        of: find.text('Pesado').first,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_SquareTile',
        ),
      );
      expect(
        find.descendant(
          of: heavyCard,
          matching: find.text('${formatDecimal(0, decimals: 1)} kg'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('${formatDecimal(11420, decimals: 1)} kg'),
        findsNothing,
      );
      expect(find.text('50 pacas'), findsOneWidget);
      expect(
        find.text('${formatDecimal(4127, decimals: 1)} kg'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(
        chartValues('Entradas diarias de chatarra')['Pesado']![entryDate],
        12000,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
