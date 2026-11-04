import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/logistica/logistics_catalog_page.dart';
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
  late Map<String, dynamic> profile;
  late Map<String, dynamic> vehicle;
  final writes = <Map<String, dynamic>>[];
  var failRead = false;
  var failSave = false;
  final qaDir = Platform.environment['DICSA_LOGISTICS_QA_DIR'];

  setUpAll(() async {
    if (qaDir != null) {
      await Directory(qaDir).create(recursive: true);
      for (final (family, asset) in [
        ('Roboto', 'assets/fonts/Roboto-Regular.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://vehicle-model-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final profiles = table == 'logistics_vehicle_profiles';
        if (profiles &&
            ((failRead && request.method == 'GET') ||
                (failSave && request.method == 'POST'))) {
          return http.Response(
            jsonEncode({'message': 'No disponible', 'code': '42501'}),
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST') {
          expectSync(profiles, isTrue);
          for (final row in jsonDecode(request.body) as List) {
            final patch = Map<String, dynamic>.from(row as Map);
            writes.add(patch);
            profile.addAll(patch);
          }
        } else {
          expectSync(request.method, 'GET');
        }
        return http.Response(
          jsonEncode(
            profiles
                ? [profile]
                : table == 'vehicles'
                ? [vehicle]
                : [],
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    writes.clear();
    failRead = false;
    failSave = false;
    vehicle = {
      'id': 'v1',
      'code': 'T-01',
      'serial_number': 'SERIE',
      'type': 'camion',
      'status': 'activo',
    };
    profile = {
      'vehicle_id': 'v1',
      'vehicle_code': 'T-01',
      'serial_number': 'SERIE',
      'source_vehicle_type': 'camion',
      'source_status': 'activo',
      'model_year': 2019,
      'model_name': 'Kenworth T800',
      'logistics_unit_type': 'CAMION',
      'planning_status': 'ACTIVO',
      'compatible_load_types': ['CARGA_GENERAL'],
      'tank_capacity_liters': 400,
      'assigned_driver_employee_id': 'e1',
      'notes': 'Conservar nota',
    };
  });

  final yearInput = find.byKey(const ValueKey('logistics-vehicle-year-input'));
  final modelInput = find.byKey(
    const ValueKey('logistics-vehicle-model-input'),
  );
  Future<void> screenshot(WidgetTester tester, String name) async {
    if (qaDir == null) return;
    await tester.runAsync(() async {
      final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
      final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$qaDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LogisticsCatalogPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidades').last);
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester) async {
    final button = find.text('Editar perfil');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.text('Guardar perfil');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  test(
    'year/model round trip, optional clearing and year validation',
    () async {
      final record = LogisticsVehicleProfileRecord.fromRemoteRow(profile);
      expect(record.copyWith(notes: 'Otra nota').modelYear, 2019);
      expect(record.copyWith(notes: 'Otra nota').modelName, 'Kenworth T800');
      final cleared = record
          .copyWith(modelYear: null, modelName: '  ')
          .toUpsertJson();
      expect(cleared['model_year'], isNull);
      expect(cleared['model_name'], isNull);
      expect(
        record.copyWith(modelName: ' T680 ').toUpsertJson()['model_name'],
        'T680',
      );
      expect(parseLogisticsModelYear(''), isNull);
      expect(parseLogisticsModelYear(' 2020 '), 2020);
      for (final input in [
        '1899',
        '2101',
        '-1',
        '20',
        '20.20',
        '2e3',
        'abcd',
        '02020',
      ]) {
        expect(() => parseLogisticsModelYear(input), throwsFormatException);
      }
      await expectLater(
        LogisticsVehicleProfileStore.saveProfileRow(
          record.copyWith(modelYear: 2101),
        ),
        throwsFormatException,
      );
      await expectLater(
        LogisticsVehicleProfileStore.saveProfileRows([
          record,
          record.copyWith(modelYear: 0),
        ]),
        throwsFormatException,
      );
      expect(writes, isEmpty);
    },
  );

  test(
    'fleet changes retain model and omit captured values from sync writes',
    () async {
      vehicle['code'] = 'T-01 NUEVA';
      final rows = await LogisticsVehicleProfileStore.loadProfiles();
      expect(rows.single.modelYear, 2019);
      expect(rows.single.modelName, 'Kenworth T800');
      expect(writes, hasLength(1));
      expect(writes.single.containsKey('model_year'), isFalse);
      expect(writes.single.containsKey('model_name'), isFalse);
      expect(profile['model_year'], 2019);
      expect(profile['model_name'], 'Kenworth T800');
    },
  );

  testWidgets(
    'capture, reload, search by year/model and clear without losing other fields',
    (tester) async {
      await open(tester);
      expect(find.text('2019'), findsOneWidget);
      expect(find.text('Kenworth T800'), findsOneWidget);
      await edit(tester);
      await tester.enterText(yearInput, '2020');
      await tester.enterText(modelInput, 'Kenworth T680');
      await tester.pumpAndSettle();
      await screenshot(tester, 'year-model-editor');
      await submit(tester);
      expect(profile['model_year'], 2020);
      expect(profile['model_name'], 'Kenworth T680');
      expect(profile['tank_capacity_liters'], 400);
      expect(profile['assigned_driver_employee_id'], 'e1');
      expect(profile['notes'], 'Conservar nota');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await open(tester);
      await screenshot(tester, 'year-model-card');
      final search = find.widgetWithText(TextField, 'Buscar unidad o chofer');
      for (final term in ['2020', 'T680']) {
        await tester.enterText(search, term);
        await tester.pumpAndSettle();
        expect(find.text('T-01'), findsOneWidget);
      }
      await tester.enterText(search, '2019');
      await tester.pumpAndSettle();
      expect(find.text('Sin unidades visibles'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      await edit(tester);
      expect(tester.widget<TextField>(yearInput).controller!.text, '2020');
      expect(
        tester.widget<TextField>(modelInput).controller!.text,
        'Kenworth T680',
      );
      await tester.enterText(yearInput, '');
      await tester.enterText(modelInput, '');
      await submit(tester);
      expect(profile['model_year'], isNull);
      expect(profile['model_name'], isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('invalid year and cancellation do not save', (tester) async {
    await open(tester);
    await edit(tester);
    await tester.enterText(yearInput, '2200');
    await submit(tester);
    expect(
      find.text('Captura un año de 4 dígitos entre 1900 y 2100.'),
      findsOneWidget,
    );
    expect(writes, isEmpty);
    await tester.ensureVisible(yearInput);
    await tester.enterText(yearInput, '2021');
    final cancel = find.text('Cancelar');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(profile['model_year'], 2019);
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed save keeps captured data and failed reads block editing',
    (tester) async {
      await open(tester);
      await edit(tester);
      await tester.enterText(modelInput, 'NO GUARDADO');
      failSave = true;
      await submit(tester);
      expect(profile['model_name'], 'Kenworth T800');
      expect(find.text('Kenworth T800'), findsOneWidget);
      expect(find.text('NO GUARDADO'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      failRead = true;
      await open(tester);
      expect(find.text('Editar perfil'), findsNothing);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
