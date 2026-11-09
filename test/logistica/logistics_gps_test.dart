import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/logistica/logistics_gps_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_geofence_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_visit_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_stop_store.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  var allowed = true, fail = false;
  var status = 'ok';
  var reads = 0;
  var linkFail = false;
  Map<String, dynamic>? savedLink;
  late List<Map<String, dynamic>> fences;
  late List<Map<String, dynamic>> stops;
  bool reviewFail = false;
  Map<String, dynamic>? savedReview;
  final now = DateTime.now().toUtc();
  List<Map<String, dynamic>> visitRows() => [
    {
      'id': 'visit1',
      'provider_unit_id': '1',
      'unit_label': 'C1',
      'place_label': 'AVON',
      'geofence_name': 'Avon',
      'classification': 'company',
      'status': 'open',
      'arrival_kind': 'first_seen',
      'has_gap': false,
      'started_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
      'last_inside_at': now
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    },
    {
      'id': 'visit2',
      'provider_unit_id': '2',
      'unit_label': 'T3',
      'place_label': 'SETEX',
      'geofence_name': 'Setex',
      'classification': 'company',
      'status': 'closed',
      'arrival_kind': 'arrival',
      'has_gap': false,
      'started_at': now.subtract(const Duration(minutes: 40)).toIso8601String(),
      'last_inside_at': now
          .subtract(const Duration(minutes: 21))
          .toIso8601String(),
      'ended_at': now.subtract(const Duration(minutes: 20)).toIso8601String(),
    },
  ];
  List<Map<String, dynamic>> presence() => [
    {
      'provider_unit_id': '1',
      'resource_id': '9',
      'geofence_id': '1',
      'mode': 'inside',
      'last_position_at': now
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      'active_visit_id': 'visit1',
      'continuity_lost': false,
    },
  ];
  List<Map<String, dynamic>> rows() => [
    {
      'provider_unit_id': '1',
      'provider_name': 'C-001',
      'vehicle_id': 'v1',
      'vehicles': {'code': 'C1'},
      'latitude': 20.52,
      'longitude': -100.81,
      'position_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      'observed_at': now.toIso8601String(),
      'provider_visible': true,
    },
    {
      'provider_unit_id': '2',
      'provider_name': 'T-003',
      'vehicle_id': 'v2',
      'vehicles': {'code': 'T3'},
      'latitude': 20.65,
      'longitude': -100.7,
      'position_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'observed_at': now.toIso8601String(),
      'provider_visible': true,
    },
    {
      'provider_unit_id': '3',
      'provider_name': 'NUEVA',
      'vehicle_id': null,
      'vehicles': null,
      'latitude': null,
      'longitude': null,
      'position_at': null,
      'observed_at': now.toIso8601String(),
      'provider_visible': true,
    },
  ];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final root = config.absolute.uri.resolve(
      '${packages.singleWhere((p) => p['name'] == 'flutter')['rootUri']}/',
    );
    for (final font in ['Roboto', 'MaterialIcons']) {
      final file = File.fromUri(
        root.resolve(
          '../../bin/cache/artifacts/material_fonts/${font == 'Roboto' ? 'Roboto-Regular.ttf' : 'MaterialIcons-Regular.otf'}',
        ),
      );
      await (FontLoader(
        font,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
    await Supabase.initialize(
      url: 'https://gps-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        reads++;
        final table = request.url.pathSegments.last;
        if (fail) {
          return http.Response(
            '{"message":"offline","code":"503"}',
            503,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (table == 'link_logistics_geofence') {
          if (linkFail) {
            return http.Response(
              '{"message":"offline","code":"503"}',
              503,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          savedLink = jsonDecode(request.body) as Map<String, dynamic>;
          final row = fences.singleWhere(
            (f) => f['geofence_id'] == savedLink!['p_geofence_id'],
          );
          row['site_id'] = savedLink!['p_site_id'];
          row['classification'] = savedLink!['p_classification'];
          row['link_version'] = (row['link_version'] as int) + 1;
          row['sites'] = {'name': 'SETEX', 'is_active': true};
          return http.Response(
            '1',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (table == 'review_logistics_gps_stop') {
          if (reviewFail) {
            return http.Response(
              '{"message":"offline","code":"503"}',
              503,
              request: request,
            );
          }
          savedReview = jsonDecode(request.body) as Map<String, dynamic>;
          final row = stops.singleWhere((s) => s['id'] == savedReview!['p_id']);
          expect(savedReview!['p_expected_version'], row['review_version']);
          row['review_note'] = savedReview!['p_note'];
          row['reviewed_at'] = now.toIso8601String();
          row['review_version'] = (row['review_version'] as int) + 1;
          return http.Response('1', 200, request: request);
        }
        final dynamic data = switch (table) {
          'can_view_logistics_gps' => allowed,
          'logistics_gps_units' => rows(),
          'logistics_geofences' => fences,
          'logistics_gps_visits' => visitRows(),
          'logistics_gps_stops' => stops,
          'logistics_gps_stop_monitor' => [
            {
              'status': 'ok',
              'last_run_at': now.toIso8601String(),
              'enabled_at': now
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
            },
          ],
          'logistics_gps_presence' => presence(),
          'logistics_gps_visit_monitor' => [
            {
              'status': 'ok',
              'last_run_at': now.toIso8601String(),
              'enabled_at': now
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
            },
          ],
          'logistics_geofence_sync_state' => [
            {'status': 'ok', 'last_success_at': now.toIso8601String()},
          ],
          'sites' => [
            {'id': 'site1', 'name': 'AVON'},
            {'id': 'site2', 'name': 'SETEX'},
          ],
          'logistics_gps_sync_state' => [
            {
              'status': status,
              'last_success_at': now.toIso8601String(),
              'error_code': status == 'error' ? 'authorization' : null,
            },
          ],
          _ => [],
        };
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    allowed = true;
    fail = false;
    status = 'ok';
    reads = 0;
    linkFail = false;
    savedLink = null;
    reviewFail = false;
    savedReview = null;
    stops = [
      {
        'id': 'stop1',
        'provider_unit_id': '1',
        'unit_label': 'C1',
        'status': 'open',
        'latitude': 20.53,
        'longitude': -100.82,
        'review_version': 0,
        'started_at': now
            .subtract(const Duration(minutes: 12))
            .toIso8601String(),
        'last_stationary_at': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      },
      {
        'id': 'stop2',
        'provider_unit_id': '2',
        'unit_label': 'T3',
        'status': 'interrupted',
        'latitude': 20.54,
        'longitude': -100.83,
        'review_version': 0,
        'end_reason': 'signal_gap',
        'started_at': now
            .subtract(const Duration(minutes: 40))
            .toIso8601String(),
        'last_stationary_at': now
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
      },
    ];
    fences = [
      {
        'resource_id': '9',
        'geofence_id': '1',
        'provider_name': 'Avon',
        'shape_type': 3,
        'width_m': 100,
        'points': [
          {'lat': 20.52, 'lng': -100.81},
        ],
        'provider_visible': true,
        'site_id': 'site1',
        'sites': {'name': 'AVON', 'is_active': true},
        'classification': 'company',
        'link_version': 0,
      },
      {
        'resource_id': '9',
        'geofence_id': '2',
        'provider_name': 'Base DICSA',
        'shape_type': 2,
        'width_m': 0,
        'points': [
          {'lat': 20.51, 'lng': -100.81},
          {'lat': 20.52, 'lng': -100.81},
          {'lat': 20.52, 'lng': -100.80},
        ],
        'provider_visible': true,
        'classification': 'base',
        'link_version': 0,
      },
    ];
  });

  test(
    'GPS freshness uses position time; missing/revoked coordinates never make a point',
    () {
      final data = rows();
      expect(
        LogisticsGpsUnit.fromRow(data[0]).status(now),
        LogisticsGpsPositionStatus.recent,
      );
      expect(
        LogisticsGpsUnit.fromRow(data[1]).status(now),
        LogisticsGpsPositionStatus.delayed,
      );
      expect(LogisticsGpsUnit.fromRow(data[2]).hasPosition, false);
      expect(
        LogisticsGpsUnit.fromRow({
          ...data[0],
          'provider_visible': false,
        }).hasPosition,
        false,
      );
      expect(
        LogisticsGpsUnit.fromRow({
          ...data[0],
          'latitude': double.nan,
        }).hasPosition,
        false,
      );
      expect(
        LogisticsGpsUnit.fromRow({
          ...data[0],
          'position_at': now.add(const Duration(minutes: 2)).toIso8601String(),
        }).status(now),
        LogisticsGpsPositionStatus.future,
      );
      final bundle = LogisticsGpsBundle(
        units: [],
        state: 'ok',
        lastSuccessAt: now.subtract(const Duration(minutes: 4)),
      );
      expect(bundle.connectionNotice(now), contains('sin actualizar'));
    },
  );
  test('denied access does not load locations', () async {
    allowed = false;
    await expectLater(
      LogisticsGpsStore.load(),
      throwsA(isA<LogisticsGpsAccessDenied>()),
    );
    expect(reads, 1);
  });
  test(
    'stop duration freezes at last observation and interrupted stops never infer a departure',
    () {
      final stop = LogisticsGpsStop.fromRow(stops.last);
      expect(stop.durationLabel, 'Al menos 10 min observados');
      expect(stop.endedAt, isNull);
      expect(stop.statusLabel, 'Seguimiento interrumpido');
      expect(stop.endLabel, 'Faltan posiciones recientes');
      final bundle = LogisticsGpsStopBundle(
        status: 'ok',
        lastRunAt: now,
        stops: [stop],
      );
      expect(bundle.isLive(now), true);
      expect(bundle.isLive(now.add(const Duration(minutes: 4))), false);
      expect(stop.durationLabel, 'Al menos 10 min observados');
    },
  );
  for (final width in [1440.0, 800.0]) {
    testWidgets('unknown stops, map, review and refresh work at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LogisticsGpsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paradas'));
      await tester.pumpAndSettle();
      expect(find.text('2 paradas'), findsOneWidget);
      expect(find.text('Al menos 11 min observados'), findsOneWidget);
      final output = Platform.environment['DICSA_GPS_QA_DIR'];
      if (output != null) {
        await tester.runAsync(() async {
          final layer =
              tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            Offset.zero & tester.view.physicalSize,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/stops-$width.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const ValueKey('stop-stop1')));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Al menos 10 min observados'), findsOneWidget);
      expect(
        find.textContaining('No se conoce el tiempo total'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const ValueKey('stops-search')), 'C1');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('1 parada'), findsOneWidget);
      final mapButton = find.text('Ver en mapa');
      await tester.ensureVisible(mapButton);
      await tester.tap(mapButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Punto observado; las geocercas del mapa son las actuales.',
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revisar parada'));
      await tester.tap(find.text('Revisar parada'));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('stop-review-note'));
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        true,
      );
      await tester.tap(find.text('Guardar revisión'));
      await tester.pumpAndSettle();
      expect(
        find.text('Escribe el motivo o una nota de revisión.'),
        findsOneWidget,
      );
      await tester.enterText(
        input,
        'Cambio de llanta, confirmado con operador',
      );
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      reviewFail = true;
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.textContaining('Tu nota se conserva'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(input).controller!.text,
        contains('Cambio de llanta'),
      );
      reviewFail = false;
      await tester.tap(find.text('Guardar revisión'));
      await tester.pumpAndSettle();
      expect(savedReview!['p_note'], contains('Cambio de llanta'));
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('0 paradas'), findsOneWidget);
      // A reviewed stop remains in history and becomes visible under Revisadas.
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Pendientes'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisadas').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Cambio de llanta, confirmado con operador'),
        findsOneWidget,
      );
      expect(find.text('1 parada'), findsOneWidget);
      await tester.ensureVisible(find.text('Editar revisión'));
      await tester.tap(find.text('Editar revisión'));
      await tester.pumpAndSettle();
      await tester.enterText(input, 'No guardar');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(stops.first['review_note'], contains('Cambio de llanta'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('GPS list, map, filter and navigation fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LogisticsGpsPage()));
      await tester.pumpAndSettle();
      expect(find.text('3 unidades · 1 recientes'), findsOneWidget);
      expect(find.text('Posición atrasada'), findsOneWidget);
      expect(find.text('Sin vínculo en el catálogo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['DICSA_GPS_QA_DIR'];
      if (output != null) {
        await tester.runAsync(() async {
          final layer =
              tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            Offset.zero & tester.view.physicalSize,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/gps-$width.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.byKey(const ValueKey('gps-unit-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gps-unit-2')));
      await tester.pumpAndSettle();
      expect(find.text('T3 · Posición atrasada'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('gps-search')), 'T3');
      await tester.pump();
      expect(find.byKey(const ValueKey('gps-unit-1')), findsNothing);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('T3 · Posición atrasada'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('gps-search')))
            .controller!
            .text,
        'T3',
      );
      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Navegación Logística'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Navegación Logística').hitTestable(), findsNothing);
      await tester.tap(find.text('Geocercas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('geofence-9/1')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Base DICSA · Base DICSA'), findsOneWidget);
      await tester.tap(find.text('Vincular'));
      await tester.pumpAndSettle();
      expect(find.text('Vincular Base DICSA'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Vincular Base DICSA'), findsNothing);
      await tester.tap(find.text('Visitas'));
      await tester.pumpAndSettle();
      expect(find.text('2 visitas'), findsOneWidget);
      expect(find.text('Detectada dentro'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('visit-visit1')));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Aprox. 20 min'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('visits-search')),
        'SETEX',
      );
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('visit-visit1')), findsNothing);
      expect(find.text('Aprox. 20 min'), findsOneWidget);
      await tester.tap(find.text('Unidades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visitas'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('visits-search')))
            .controller!
            .text,
        'SETEX',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'geofences preserve search and draft through refresh, retry and save the reviewed link',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LogisticsGpsPage()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CircleLayer>(find.byType(CircleLayer)).circles,
        hasLength(1),
      );
      await tester.tap(find.text('Geocercas'));
      await tester.pumpAndSettle();
      expect(find.text('2 geocercas · 0 pendientes'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('geofence-search')),
        'Avon',
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('geofence-9/1')), findsOneWidget);
      expect(find.byKey(const ValueKey('geofence-9/2')), findsNothing);
      await tester.tap(find.text('Vincular'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'AVON'));
      await tester.pumpAndSettle();
      final input = find.byType(TextField).last;
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await tester.enterText(input, 'SETEX');
      await tester.pumpAndSettle();
      await tester.tap(find.text('SETEX').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'SETEX'), findsOneWidget);
      linkFail = true;
      await tester.tap(find.text('Guardar vínculo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tu selección se conserva'), findsOneWidget);
      linkFail = false;
      await tester.tap(find.text('Guardar vínculo'));
      await tester.pumpAndSettle();
      expect(savedLink!['p_site_id'], 'site2');
      expect(savedLink!['p_expected_version'], 0);
      expect(find.text('Avon · SETEX'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'unavailable geofence geometry is hidden and circles fit their full radius',
    () {
      final fence = LogisticsGeofence.fromRow(fences.first);
      expect(fence.fitPoints, hasLength(4));
      expect(
        fence.fitPoints.first.latitude,
        greaterThan(fence.points.first.latitude),
      );
      expect(
        LogisticsGeofence.fromRow({
          ...fences.first,
          'provider_visible': false,
          'points': null,
        }).showOnMap,
        false,
      );
      expect(
        LogisticsGeofence.fromRow({
          ...fences.first,
          'classification': 'company',
          'site_id': null,
          'sites': null,
        }).needsReview,
        true,
      );
    },
  );
  test(
    'visits freeze observed dwell and distinguish uncertainty from current location',
    () {
      final rows = visitRows();
      final open = LogisticsGpsVisit.fromRow(rows.first);
      expect(open.durationLabel, 'Al menos 9 min');
      expect(
        LogisticsGpsVisit.fromRow({
          ...rows.first,
          'has_gap': true,
        }).durationLabel,
        contains('No determinable'),
      );
      final bundle = LogisticsGpsVisitBundle(
        visits: rows.map(LogisticsGpsVisit.fromRow).toList(),
        presence: presence(),
        status: 'ok',
        lastRunAt: now,
      );
      expect(bundle.location('1', now, sourceFresh: true), 'En AVON');
      final stationary = LogisticsGpsVisitBundle(
        visits: bundle.visits,
        presence: [
          {
            ...presence().first,
            'last_position_at': now
                .subtract(const Duration(minutes: 10))
                .toIso8601String(),
          },
        ],
        status: 'ok',
        lastRunAt: now,
      );
      expect(stationary.location('1', now, sourceFresh: true), 'En AVON');
      expect(
        bundle.location('1', now, sourceFresh: false),
        contains('sin confirmar'),
      );
      expect(
        bundle.location(
          '1',
          now.add(const Duration(minutes: 6)),
          sourceFresh: true,
        ),
        contains('sin confirmar'),
      );
      final pending = LogisticsGpsVisitBundle(
        visits: bundle.visits,
        presence: [
          {...presence().first, 'candidate_mode': 'outside'},
        ],
        status: 'ok',
        lastRunAt: now,
      );
      expect(
        pending.location('1', now, sourceFresh: true),
        contains('salida por confirmar'),
      );
      final outside = LogisticsGpsVisitBundle(
        presence: [
          {...presence().first, 'mode': 'outside', 'active_visit_id': null},
        ],
        status: 'ok',
        lastRunAt: now,
      );
      expect(
        outside.location('1', now, sourceFresh: true),
        startsWith('Fuera'),
      );
    },
  );
  testWidgets('visible desktop window refreshes without keyboard focus', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LogisticsGpsPage()));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    final before = reads;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(reads, greaterThan(before));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    final hiddenReads = reads;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(reads, hiddenReads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reads, greaterThan(hiddenReads));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'network failure preserves snapshot with warning; revoked permission clears it',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LogisticsGpsPage()));
      await tester.pumpAndSettle();
      fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gps-unit-1')), findsOneWidget);
      expect(
        find.textContaining('Se reintentará automáticamente'),
        findsOneWidget,
      );
      fail = false;
      allowed = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gps-unit-1')), findsNothing);
      expect(find.textContaining('no tiene acceso'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
