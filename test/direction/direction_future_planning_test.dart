import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/direction/direction_shipments_page.dart';
import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String planningTitle(DateTime week) =>
    'Planeación semanal · ${shortDate(week)} - ${shortDate(week.add(const Duration(days: 5)))}';
String programTitle(DateTime week) =>
    'Programa operativo de cartón\n${programDate(week)} al ${programDate(week.add(const Duration(days: 4)))}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shipments = <Map<String, dynamic>>[];
  final programs = <Map<String, dynamic>>[];
  final savedRequests = <Map<String, dynamic>>[];
  final weekClients = <String, List<String>>{};
  final floorCounts = <Map<String, dynamic>>[];
  final weeklyOpenings = <Map<String, dynamic>>[];
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://future-planning-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final resource = request.url.pathSegments.last;
        final params = request.url.queryParameters;
        dynamic result = [];
        if (resource == 'direction_shipment_plans') {
          if (request.method == 'POST') {
            final body = jsonDecode(request.body);
            for (final row in body is List ? body : [body]) {
              shipments.add({
                'id': 'shipment-${shipments.length + 1}',
                ...row as Map<String, dynamic>,
              });
            }
          } else if (request.method == 'PATCH') {
            shipments
                .singleWhere((r) => 'eq.${r['id']}' == params['id'])
                .addAll(jsonDecode(request.body) as Map<String, dynamic>);
          } else {
            final filters = request.url.queryParametersAll['ship_date']!;
            final from = filters
                .firstWhere((v) => v.startsWith('gte.'))
                .substring(4);
            final to = filters
                .firstWhere((v) => v.startsWith('lte.'))
                .substring(4);
            result = shipments
                .where(
                  (r) =>
                      (r['ship_date'] as String).compareTo(from) >= 0 &&
                      (r['ship_date'] as String).compareTo(to) <= 0,
                )
                .toList();
          }
        } else if (resource == 'direction_shipment_week_clients') {
          if (request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            weekClients[body['week_start'] as String] = List<String>.from(
              body['client_names'] as List,
            );
          } else {
            final week = params['week_start']!.substring(3);
            result = weekClients.containsKey(week)
                ? [
                    {'client_names': weekClients[week]},
                  ]
                : [];
          }
        } else if (resource == 'dashboard_yard_week_openings') {
          result = weeklyOpenings
              .where((r) => 'eq.${r['week_start']}' == params['week_start'])
              .toList();
        } else if (resource == 'dashboard_yard_manual_counts') {
          result = floorCounts;
        } else if (resource == 'direction_operating_programs') {
          result = programs
              .where((r) => 'eq.${r['week_start']}' == params['week_start'])
              .toList();
        } else if (resource == 'direction_save_operating_program') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          savedRequests.add(body);
          final saved = <String, dynamic>{
            'id': body['p_id'],
            'week_start': body['p_week'],
            'version': (body['p_expected_version'] as int) + 1,
            'status': 'draft',
            'conditions': body['p_conditions'],
            'shipments': body['p_shipments'],
            'lines': body['p_lines'],
          };
          programs.insert(0, saved);
          result = saved;
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: request,
          headers: {'content-type': 'application/json', 'content-range': '*/0'},
        );
      }),
    );
  });
  setUp(() {
    shipments.clear();
    programs.clear();
    savedRequests.clear();
    weekClients.clear();
    floorCounts.clear();
    weeklyOpenings.clear();
  });
  tearDownAll(() => Supabase.instance.dispose());

  Future<void> open(WidgetTester tester, {DateTime? week}) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: DirectionShipmentsPage(
          instantOpen: true,
          initialWeekStartDate: week,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  void seedCustomerHistory() {
    final current = DirectionShipmentsStore.currentWeekStartDate();
    for (final client in ['EL PALOMAR', 'CLIENTE ACTUAL']) {
      shipments.add({
        'id': client,
        'ship_date': programDate(current.subtract(const Duration(days: 7))),
        'client_name': client,
        'commercial_material_code': 'PACA_NACIONAL',
        'planning_material_code': 'PACA_NACIONAL',
        'material_scope': 'commercial',
        'quantity_unit': 'PACAS',
        'planned_units': 30,
        'status': 'embarcado',
        'priority': 'normal',
      });
    }
    floorCounts.add({
      'source_kind': 'commercial_material',
      'commercial_material_code': 'PACA_NACIONAL',
      'count_units': 100,
      'counted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  test(
    'store reads the Friday opening for its own Monday without replacing later physical stock',
    () async {
      seedCustomerHistory();
      final current = DirectionShipmentsStore.currentWeekStartDate();
      weeklyOpenings.add({
        'week_start': programDate(current),
        'commercial_material_code': 'PACA_NACIONAL',
        'count_units': 35,
        'counted_at': current
            .subtract(const Duration(days: 3))
            .add(const Duration(hours: 23))
            .toUtc()
            .toIso8601String(),
      });
      final bundle = await DirectionShipmentsStore.loadWeek(current);
      expect(
        bundle.suggestionReport!.openingFloorByMaterial['PACA_NACIONAL'],
        35,
      );
      expect(
        bundle.suggestionReport!.currentFloorByMaterial['PACA_NACIONAL'],
        100,
      );
      // The weekly opening remains frozen, but a new current-week program
      // consumes the available stock for shipments still awaiting dispatch.
      expect(ProgramConditions.fromReference(bundle).yard['PACA_NACIONAL'], 100);
      final next = await DirectionShipmentsStore.loadWeek(
        current.add(const Duration(days: 7)),
      );
      expect(next.suggestionReport!.fridayOpeningMaterials, isEmpty);
    },
  );

  testWidgets(
    'selects next-week companies before generating and remembers only that week',
    (tester) async {
      seedCustomerHistory();
      final next = DirectionShipmentsStore.currentWeekStartDate().add(
        const Duration(days: 7),
      );
      await open(tester, week: next);
      await tap(tester, find.text('Embarques sugeridos'));
      expect(find.byType(DirectionShipmentClientsDialog), findsOneWidget);
      expect(find.byType(DirectionSuggestedShipmentsDialog), findsNothing);
      await tap(tester, find.text('CLIENTE ACTUAL'));
      await tap(tester, find.text('Generar sugeridos'));
      expect(weekClients[programDate(next)], ['CLIENTE ACTUAL']);
      expect(find.byType(DirectionSuggestedShipmentsDialog), findsOneWidget);
      expect(find.text('EL PALOMAR'), findsNothing);
      await tap(tester, find.text('Cambiar empresas'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('shipment-client-CLIENTE ACTUAL')),
            )
            .value,
        isTrue,
      );
      await tap(tester, find.text('Generar sugeridos'));
      await tap(tester, find.text('Aceptar embarques'));
      final accepted = shipments
          .where((r) => r['status'] == 'confirmado')
          .toList();
      expect(accepted, hasLength(1));
      expect(accepted.single['client_name'], 'CLIENTE ACTUAL');
      expect(accepted.single['ship_date'], programDate(next));
      await tap(tester, find.text('Embarques sugeridos'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('shipment-client-CLIENTE ACTUAL')),
            )
            .value,
        isTrue,
      );
      await tap(tester, find.text('Cancelar'));
      await tap(tester, find.byTooltip('Semana siguiente'));
      await tap(tester, find.text('Embarques sugeridos'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('shipment-client-CLIENTE ACTUAL')),
            )
            .value,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(weekClients.keys, [programDate(next)]);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'acceptance reloads weekly company choice and rejects a changed selection',
    () async {
      seedCustomerHistory();
      final next = DirectionShipmentsStore.currentWeekStartDate().add(
        const Duration(days: 7),
      );
      await DirectionShipmentsStore.saveSuggestionClients(next, [
        'cliente actual',
      ]);
      final report = (await DirectionShipmentsStore.loadWeek(
        next,
      )).suggestionReport!;
      expect(report.suggestions.single.clientName, 'CLIENTE ACTUAL');
      await DirectionShipmentsStore.saveSuggestionClients(next, ['EL PALOMAR']);
      await expectLater(
        DirectionShipmentsStore.acceptSuggestedShipments(
          reviewed: report,
          selected: report.suggestions,
          confirmForProgram: true,
        ),
        throwsStateError,
      );
      expect(shipments.where((r) => r['status'] == 'confirmado'), isEmpty);
    },
  );

  testWidgets(
    'next-week shipment can be saved, edited and used by its own operating program today',
    (tester) async {
      final current = DirectionShipmentsStore.currentWeekStartDate();
      final next = current.add(const Duration(days: 7));
      await open(tester);
      expect(find.text(planningTitle(current)), findsOneWidget);
      await tap(tester, find.byTooltip('Semana siguiente'));
      expect(find.text(planningTitle(next)), findsOneWidget);
      await tap(tester, find.text('Nuevo embarque'));
      await tester.enterText(
        field('Nombre corto del cliente'),
        'CLIENTE PROXIMA SEMANA',
      );
      await tester.enterText(field('Cantidad en pacas'), '30');
      await tap(
        tester,
        find.text('Martes · ${shortDate(next.add(const Duration(days: 1)))}'),
      );
      await tap(tester, find.text('Confirmado'));
      await tap(tester, find.text('Guardar embarque'));
      expect(
        shipments.single['ship_date'],
        programDate(next.add(const Duration(days: 1))),
      );
      expect(shipments.single['status'], 'confirmado');
      expect(shipments.single['planned_units'], 30);

      await tap(tester, find.text('Editar'));
      await tester.enterText(field('Cantidad en pacas'), '42');
      await tap(tester, find.text('Guardar embarque'));
      expect(shipments.single['planned_units'], 42);

      await tap(tester, find.text('Ir a actual'));
      expect(find.text(planningTitle(current)), findsOneWidget);
      expect(find.text('CLIENTE PROXIMA SEMANA'), findsNothing);
      await tap(tester, find.byTooltip('Semana siguiente'));
      expect(find.text('CLIENTE PROXIMA SEMANA'), findsOneWidget);
      await tap(tester, find.text('Programa operativo'));
      expect(find.text(programTitle(next)), findsOneWidget);
      await tap(
        tester,
        find.byKey(const ValueKey('generate-operating-program')),
      );
      expect(savedRequests, hasLength(1));
      expect(savedRequests.single['p_week'], programDate(next));
      final demands = savedRequests.single['p_shipments'] as List;
      expect(
        demands.single['date'],
        programDate(next.add(const Duration(days: 1))),
      );
      expect(demands.single['quantity'], 42);
      expect(programs.single['status'], 'draft');

      await tap(tester, find.text('Semana actual'));
      expect(find.text(programTitle(current)), findsOneWidget);
      expect(find.text('v1 · Borrador'), findsNothing);
      await tap(tester, find.byTooltip('Semana siguiente del programa'));
      expect(find.text(programTitle(next)), findsOneWidget);
      expect(find.text('v1 · Borrador'), findsWidgets);
      expect(
        savedRequests,
        hasLength(1),
        reason: 'Changing weeks does not create another version',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'both tabs navigate across year boundaries and keep the selected week',
    (tester) async {
      final week = DateTime(2026, 12, 28);
      final next = DateTime(2027, 1, 4);
      final later = DateTime(2027, 1, 11);
      await open(tester, week: week);
      await tap(tester, find.byTooltip('Semana siguiente'));
      expect(find.text(planningTitle(next)), findsOneWidget);
      await tap(tester, find.text('Programa operativo'));
      expect(find.text(programTitle(next)), findsOneWidget);
      await tap(tester, find.byTooltip('Semana siguiente del programa'));
      expect(find.text(programTitle(later)), findsOneWidget);
      await tap(
        tester,
        find.descendant(
          of: find.byType(SegmentedButton<int>).first,
          matching: find.text('Embarques'),
        ),
      );
      expect(find.text(planningTitle(later)), findsOneWidget);
      await tap(tester, find.byTooltip('Semana anterior'));
      expect(find.text(planningTitle(next)), findsOneWidget);
      expect(shipments, isEmpty);
      expect(savedRequests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
