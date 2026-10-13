import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/logistica/logistics_catalog_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_resource_profile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = <String, List<Map<String, dynamic>>>{};
  final writes = <Map<String, dynamic>>[];
  var failProfiles = false;
  setUpAll(() async {
    final fontDir = Platform.environment['DICSA_LOGISTICS_QA_FONTS'];
    if (fontDir != null) {
      for (final (family, file) in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(
              File('$fontDir/$file').readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://tank-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        final table = r.url.pathSegments.last;
        if (r.method == 'GET' &&
            failProfiles &&
            table == 'logistics_vehicle_profiles') {
          return http.Response(
            jsonEncode({'message': 'Unavailable', 'code': '503'}),
            503,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        final data = tables.putIfAbsent(table, () => []);
        if (r.method == 'POST') {
          expectSync(table, 'logistics_vehicle_profiles');
          final decoded = jsonDecode(r.body);
          for (final row in (decoded is List ? decoded : [decoded])) {
            final patch = Map<String, dynamic>.from(row as Map);
            writes.add(patch);
            final existing = data
                .where((d) => d['vehicle_id'] == patch['vehicle_id'])
                .firstOrNull;
            if (existing == null) {
              data.add(patch);
            } else {
              existing.addAll(patch);
            }
          }
        } else {
          expectSync(r.method, 'GET');
        }
        final p = r.url.queryParameters;
        var rows = data
            .where(
              (row) => p.entries.every(
                (e) =>
                    !e.value.startsWith('eq.') ||
                    row[e.key].toString() == e.value.substring(3),
              ),
            )
            .skip(int.tryParse(p['offset'] ?? '') ?? 0)
            .take(int.tryParse(p['limit'] ?? '') ?? 1000)
            .toList();
        final select = p['select'];
        if (select != null && select != '*') {
          rows = rows
              .map(
                (row) => {for (final col in select.split(',')) col: row[col]},
              )
              .toList();
        }
        return http.Response(
          jsonEncode(rows),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    failProfiles = false;
    writes.clear();
    tables.clear();
    tables['vehicles'] = [
      {
        'id': 'v1',
        'code': 'T-01',
        'serial_number': 'SERIE',
        'type': 'camion',
        'status': 'activo',
      },
    ];
    tables['logistics_vehicle_profiles'] = [
      {
        'vehicle_id': 'v1',
        'vehicle_code': 'T-01',
        'serial_number': 'SERIE',
        'source_vehicle_type': 'camion',
        'source_status': 'activo',
        'logistics_unit_type': 'CAMION',
        'planning_status': 'ACTIVO',
        'compatible_load_types': <String>[],
        'tank_capacity_liters': 400.0,
      },
    ];
    tables['logistics_vehicle_mileage'] = [
      {
        'id': 'm1',
        'entry_date': '2026-10-13',
        'vehicle_id': 'v1',
        'vehicle_key': 'T1',
        'vehicle_label': 'T-01',
        'kilometers': 300,
      },
    ];
    tables['logistics_diesel_consumption'] = [
      {
        'id': 'd1',
        'entry_date': '2026-10-13',
        'vehicle_id': 'v1',
        'vehicle_label': 'T-01',
        'liters_requested': 100,
      },
    ];
  });
  test(
    'capacity supports decimals and clearing while preserving other profile fields',
    () {
      final row = LogisticsVehicleProfileRecord.fromRemoteRow(
        tables['logistics_vehicle_profiles']!.single,
      );
      expect(row.copyWith(notes: 'Nota').tankCapacityLiters, 400);
      expect(
        row
            .copyWith(tankCapacityLiters: null)
            .toUpsertJson()['tank_capacity_liters'],
        isNull,
      );
      expect(
        row
            .copyWith(tankCapacityLiters: 450.75)
            .toUpsertJson()['tank_capacity_liters'],
        450.75,
      );
      expect(parseLogisticsTankCapacity('450,75'), 450.75);
      expect(parseLogisticsTankCapacity(''), isNull);
      for (final input in [
        '0',
        '-10',
        'NaN',
        '1e3',
        '1.234',
        '1000000',
        'abc',
      ]) {
        expect(() => parseLogisticsTankCapacity(input), throwsFormatException);
      }
      expect(logisticsTankCapacityInput(400), '400');
      expect(logisticsTankCapacityInput(450.5), '450.5');
      expect(logisticsTankCapacityLabel(null), 'Sin capturar');
    },
  );
  test(
    'master-data resync cannot clear capacity when the profile read fails',
    () async {
      failProfiles = true;
      await LogisticsVehicleProfileStore.loadProfiles();
      expect(writes, hasLength(1));
      expect(writes.single.containsKey('tank_capacity_liters'), isFalse);
      expect(
        tables['logistics_vehicle_profiles']!.single['tank_capacity_liters'],
        400,
      );
    },
  );
  test('read-only capacity loading paginates and writes nothing', () async {
    tables['logistics_vehicle_profiles'] = List.generate(
      1001,
      (i) => {
        'vehicle_id': 'v$i',
        'tank_capacity_liters': i == 1000 ? 450.75 : null,
      },
    );
    final tanks = await LogisticsVehicleProfileStore.loadTankCapacities();
    expect(tanks.length, 1001);
    expect(tanks['v1000'], 450.75);
    expect(writes, isEmpty);
  });
  Future<void> screenshot(WidgetTester tester, String name) async {
    final dir = Platform.environment['DICSA_LOGISTICS_QA_DIR'];
    if (dir == null) return;
    await tester.runAsync(() async {
      final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
      final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'capture validates, persists, reopens and is shared with Performance',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LogisticsCatalogPage()));
      await tester.pumpAndSettle();
      final tab = find.text('Unidades').last;
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.text('400 L'), findsOneWidget);
      await tester.tap(find.text('Editar perfil'));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('logistics-tank-capacity-input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, '-5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text('Captura litros mayores a 0, con máximo 2 decimales.'),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      await tester.enterText(input, '450,75');
      await tester.pumpAndSettle();
      await screenshot(tester, 'tank-editor');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tables['logistics_vehicle_profiles']!.single['tank_capacity_liters'],
        450.75,
      );
      expect(find.text('450.75 L'), findsOneWidget);
      await tester.tap(find.text('Editar perfil'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '450.75');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(home: LogisticsPerformancePage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('TANQUE (L)'), findsOneWidget);
      expect(find.text('450.75 L'), findsOneWidget);
      // Tank size is descriptive; it must not replace actual liters in km/L.
      expect(find.text('3.00 km/L'), findsWidgets);
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'tank-performance');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('an uncaptured tank stays unspecified in Performance', (
    tester,
  ) async {
    tables['logistics_vehicle_profiles']!.single['tank_capacity_liters'] = null;
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: LogisticsPerformancePage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin capturar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
