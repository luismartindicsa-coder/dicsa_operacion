import 'dart:convert';

import 'package:dicsa_operacion/app/logistica/logistics_catalog_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_resource_profile_store.dart';
import 'package:flutter/material.dart';
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
  var failRead = false;
  var failSave = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://vehicle-driver-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final data = tables.putIfAbsent(table, () => []);
        if (table == 'logistics_vehicle_profiles' &&
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
          final idKey = table == 'logistics_driver_profiles'
              ? 'employee_id'
              : 'vehicle_id';
          for (final raw in jsonDecode(request.body) as List) {
            final patch = Map<String, dynamic>.from(raw as Map);
            if (table == 'logistics_vehicle_profiles') writes.add(patch);
            final existing = data
                .where((row) => row[idKey] == patch[idKey])
                .firstOrNull;
            if (existing == null) {
              data.add(patch);
            } else {
              existing.addAll(patch);
            }
          }
        } else {
          expectSync(request.method, 'GET');
        }
        final query = request.url.queryParameters;
        final rows = data
            .where(
              (row) => query.entries.every(
                (entry) =>
                    !entry.value.startsWith('eq.') ||
                    '${row[entry.key]}' == entry.value.substring(3),
              ),
            )
            .toList();
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    failRead = false;
    failSave = false;
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
        'compatible_load_types': ['CARGA_GENERAL'],
        'planning_status': 'ACTIVO',
        'tank_capacity_liters': 400,
        'notes': 'Conservar nota',
        'assigned_driver_employee_id': null,
      },
    ];
    tables['employees'] = [
      {
        'id': 'e2',
        'full_name': 'ZULIO PEREZ',
        'is_active': true,
        'is_driver': true,
      },
      {
        'id': 'e1',
        'full_name': 'ANA LOPEZ',
        'is_active': true,
        'is_driver': true,
      },
      {
        'id': 'e3',
        'full_name': 'INACTIVO',
        'is_active': false,
        'is_driver': true,
      },
      {
        'id': 'e4',
        'full_name': 'ADMINISTRACION',
        'is_active': true,
        'is_driver': false,
      },
    ];
  });

  Map<String, dynamic> profile() =>
      tables['logistics_vehicle_profiles']!.single;
  final picker = find.byKey(const ValueKey('logistics-assigned-driver-picker'));

  Future<void> openUnits(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LogisticsCatalogPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidades').last);
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester) async {
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) async {
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, 'Buscar');
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
    expect(find.text('INACTIVO'), findsNothing);
    expect(find.text('ADMINISTRACION'), findsNothing);
    await tester.enterText(search, name);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('Guardar perfil');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  test(
    'assignment can be replaced or cleared without changing the other fields',
    () {
      final original = LogisticsVehicleProfileRecord.fromRemoteRow(profile());
      expect(original.assignedDriverEmployeeId, isNull);
      final assigned = original.copyWith(assignedDriverEmployeeId: 'e1');
      expect(assigned.copyWith(notes: 'Cambio').assignedDriverEmployeeId, 'e1');
      expect(
        assigned
            .copyWith(assignedDriverEmployeeId: 'e2')
            .toUpsertJson()['assigned_driver_employee_id'],
        'e2',
      );
      final cleared = assigned.copyWith(assignedDriverEmployeeId: null);
      expect(cleared.toUpsertJson()['assigned_driver_employee_id'], isNull);
      expect(cleared.tankCapacityLiters, 400);
      expect(cleared.notes, 'Conservar nota');
    },
  );

  test(
    'fleet resync preserves assignment after a profile read error',
    () async {
      profile()['assigned_driver_employee_id'] = 'e1';
      failRead = true;
      await expectLater(
        LogisticsVehicleProfileStore.loadProfiles(),
        throwsA(isA<PostgrestException>()),
      );
      expect(writes, isEmpty);
      expect(profile()['assigned_driver_employee_id'], 'e1');
    },
  );

  testWidgets('assign, reload, search by driver, replace and clear', (
    tester,
  ) async {
    await openUnits(tester);
    expect(find.text('Sin chofer asignado'), findsOneWidget);
    await edit(tester);
    await choose(tester, 'ANA');
    expect(writes, isEmpty);
    await save(tester);
    expect(profile()['assigned_driver_employee_id'], 'e1');
    expect(profile()['tank_capacity_liters'], 400);
    expect(profile()['notes'], 'Conservar nota');
    expect(find.text('ANA LOPEZ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await openUnits(tester);
    expect(find.text('ANA LOPEZ'), findsOneWidget);
    final search = find.widgetWithText(TextField, 'Buscar unidad o chofer');
    await tester.enterText(search, 'ANA');
    await tester.pumpAndSettle();
    expect(find.text('T-01'), findsOneWidget);
    await tester.enterText(search, 'ZULIO');
    await tester.pumpAndSettle();
    expect(find.text('Sin unidades visibles'), findsOneWidget);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    await edit(tester);
    expect(
      find.descendant(of: picker, matching: find.text('ANA LOPEZ')),
      findsOneWidget,
    );
    await choose(tester, 'ZULIO');
    await save(tester);
    expect(profile()['assigned_driver_employee_id'], 'e2');
    expect(find.text('ZULIO PEREZ'), findsOneWidget);
    await edit(tester);
    await choose(tester, 'Sin chofer');
    await save(tester);
    expect(profile()['assigned_driver_employee_id'], isNull);
    expect(find.text('Sin chofer asignado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('canceling the picker or editor does not save an assignment', (
    tester,
  ) async {
    profile()['assigned_driver_employee_id'] = 'e1';
    await openUnits(tester);
    await edit(tester);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('ANA LOPEZ').last).dy,
      lessThan(tester.getTopLeft(find.text('ZULIO PEREZ')).dy),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: picker, matching: find.text('ANA LOPEZ')),
      findsOneWidget,
    );
    await choose(tester, 'ZULIO');
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(profile()['assigned_driver_employee_id'], 'e1');
    expect(find.text('ANA LOPEZ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'an unavailable assigned driver is preserved when editing another field',
    (tester) async {
      profile()['assigned_driver_employee_id'] = 'e3';
      await openUnits(tester);
      expect(find.text('Chofer no disponible'), findsOneWidget);
      await edit(tester);
      await tester.enterText(
        find.byKey(const ValueKey('logistics-tank-capacity-input')),
        '450',
      );
      await save(tester);
      expect(profile()['assigned_driver_employee_id'], 'e3');
      expect(profile()['tank_capacity_liters'], 450);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed save leaves the previous assignment visible', (
    tester,
  ) async {
    await openUnits(tester);
    await edit(tester);
    await choose(tester, 'ANA');
    failSave = true;
    await save(tester);
    expect(profile()['assigned_driver_employee_id'], isNull);
    expect(find.text('Sin chofer asignado'), findsOneWidget);
    expect(
      find.textContaining('No se pudo guardar el perfil de la unidad'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
