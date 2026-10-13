import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/logistica/logistics_operations_pages.dart';
import 'package:dicsa_operacion/app/logistica/logistics_operations_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = <String, List<Map<String, dynamic>>>{};
  final writes = <http.Request>[];
  final reads = <http.Request>[];
  var failRead = false;
  var failWrite = false;
  final failedTables = <String, Map<String, dynamic>>{};
  var revision = 0;
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final root = config.absolute.uri.resolve(
      '${packages.singleWhere((r) => r['name'] == 'flutter')['rootUri']}/',
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
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://logistics-test.invalid',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final rows = db.putIfAbsent(table, () => []);
        final params = request.url.queryParameters;
        bool matches(Map<String, dynamic> row) => params.entries.every(
          (p) =>
              !p.value.startsWith('eq.') ||
              row[p.key]?.toString() == p.value.substring(3),
        );
        var response = <Map<String, dynamic>>[];
        if (request.method == 'GET' && failedTables.containsKey(table)) {
          reads.add(request);
          return http.Response(
            jsonEncode(failedTables[table]),
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if ((failRead && request.method == 'GET') ||
            (failWrite && request.method != 'GET')) {
          return http.Response(
            jsonEncode({'message': 'Unavailable', 'code': '503'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET') {
          reads.add(request);
          response = rows
              .where(matches)
              .skip(int.tryParse(params['offset'] ?? '') ?? 0)
              .take(int.tryParse(params['limit'] ?? '') ?? 1000)
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          final select = params['select'];
          if (select != null && select != '*') {
            response = response
                .map(
                  (r) => {
                    for (final field in select.split(',')) field: r[field],
                  },
                )
                .toList();
          }
        } else {
          writes.add(request);
          expect(
            ['logistics_trip_incidents', 'logistics_unit_states'],
            contains(table),
            reason:
                'Incidents must never modify services, vehicles or maintenance',
          );
          final data = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          data['updated_at'] = DateTime.utc(
            2026,
            10,
            12,
            12,
            0,
            ++revision,
          ).toIso8601String();
          if (data['resolution_status'] == 'RESUELTA') {
            data['resolved_at'] = data['updated_at'];
          }
          if (request.method == 'POST') {
            data['id'] = 'incident-$revision';
            rows.add(data);
            response = [data];
          } else if (request.method == 'PATCH') {
            for (final row in rows.where(matches)) {
              row.addAll(data);
              response.add(row);
            }
          } else {
            fail('Unexpected write: ${request.method}');
          }
        }
        final single =
            request.headers['accept']?.contains('vnd.pgrst.object') ?? false;
        return http.Response(
          jsonEncode(single ? response.firstOrNull : response),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  Map<String, dynamic> incident(
    String id, {
    String status = 'ABIERTA',
    String vehicle = 'v1',
  }) => {
    'id': id,
    'vehicle_id': vehicle,
    'vehicle_code': 'C-01',
    'service_id': 's1',
    'service_label': 'SERVICIO ORIGINAL',
    'driver_employee_id': 'd1',
    'driver_name': 'CHOFER ORIGINAL',
    'incident_type': 'FALLA_MECANICA',
    'impact_level': 'ALTA',
    'resolution_status': status,
    'summary': 'Falla de frenos $id',
    'action_taken': status == 'RESUELTA' ? 'Reparada' : '',
    'responsible_name': 'OPERACIONES',
    'notes': 'Revisión requerida',
    'reported_at': DateTime.now().toUtc().toIso8601String(),
    'updated_at': '2026-10-12T10:00:00.123456Z',
    if (status == 'RESUELTA') 'resolved_at': '2026-10-12T11:00:00Z',
  };
  setUp(() {
    db.clear();
    writes.clear();
    reads.clear();
    revision = 0;
    failedTables.clear();
    failRead = false;
    failWrite = false;
    final today = DateUtils.dateOnly(DateTime.now());
    db.addAll({
      'vehicles': [
        {'id': 'v1', 'code': 'C-01', 'status': 'activo', 'type': 'Camion'},
        {'id': 'v2', 'code': 'C-02', 'status': 'activo', 'type': 'Camioneta'},
        {'id': 'v3', 'code': 'C-03', 'status': 'inactivo', 'type': 'Trailer'},
      ],
      'logistics_unit_states': [
        {
          'vehicle_id': 'v1',
          'operational_status': 'EN_REVISION',
          'notes': 'Revisar frenos',
          'updated_at': '2026-10-12T10:00:00.123456Z',
        },
      ],
      'logistics_vehicle_profiles': [
        {
          'vehicle_id': 'v1',
          'vehicle_code': 'C-01',
          'planning_status': 'RESTRINGIDO',
          'compatible_load_types': ['CARGA_GENERAL'],
        },
      ],
      'employees': [
        {'id': 'd1', 'full_name': 'JUAN PEREZ'},
      ],
      'services': [
        {
          'id': 's1',
          'vehicle_id': 'v1',
          'driver_employee_id': 'd1',
          'client_name': 'ACEROS DEL NORTE',
          'service_date': today.toIso8601String(),
          'scheduled_time': '11:00:00',
          'status': 'en_ruta',
        },
        {
          'id': 's2',
          'vehicle_id': 'v1',
          'driver_employee_id': 'd1',
          'client_name': 'PAPELERA',
          'due_date': today.add(const Duration(days: 1)).toIso8601String(),
          'status': 'programado',
        },
        {
          'id': 's3',
          'vehicle_id': 'v2',
          'client_name': 'SERVICIO TERMINADO',
          'service_date': today.toIso8601String(),
          'status': 'completado',
        },
      ],
      'maintenance_orders': [
        {
          'id': 'ot1',
          'ot_folio': 'OT-001',
          'area_label': 'FLOTILLA',
          'equipment_id': 'v1',
          'status': 'aviso_falla',
          'problem_description': 'Revisar frenos',
        },
        {
          'id': 'ot2',
          'area_label': 'MAQUINARIA',
          'equipment_id': 'v2',
          'status': 'aviso_falla',
        },
        {
          'id': 'ot3',
          'area_label': 'FLOTILLA',
          'equipment_id': 'v2',
          'status': 'cerrado',
        },
      ],
      'logistics_trip_incidents': [
        incident('i1'),
        incident('i2', status: 'RESUELTA', vehicle: 'v2'),
      ],
    });
  });
  Future<void> open(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1280, 800),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  test(
    'manual fleet state never queries services, maintenance, profiles or incidents',
    () async {
      final data = await LogisticsOperationsStore.load(fleet: true);
      expect(data.unitStates['v1']!.status, 'EN_REVISION');
      expect(data.unitStates['v1']!.notes, 'Revisar frenos');
      expect(data.unitStates.containsKey('v2'), isFalse);
      expect(reads.map((r) => r.url.pathSegments.last).toSet(), {
        'vehicles',
        'logistics_unit_states',
      });
      expect(writes, isEmpty);
    },
  );
  test(
    'incident history loads independently of catalogs and all other modules',
    () async {
      for (final table in [
        'vehicles',
        'services',
        'maintenance_orders',
        'employees',
        'logistics_unit_states',
      ]) {
        failedTables[table] = {'code': '42501', 'message': 'Denied'};
      }
      final data = await LogisticsOperationsStore.load(fleet: false);
      expect(data.incidents, hasLength(2));
      expect(data.issues, isEmpty);
      expect(reads.map((r) => r.url.pathSegments.last).toSet(), {
        'logistics_trip_incidents',
      });
    },
  );
  test(
    'missing incident table is identified precisely and does not break manual states',
    () async {
      failedTables['logistics_trip_incidents'] = {
        'code': 'PGRST205',
        'message': 'Missing table',
      };
      final incidents = await LogisticsOperationsStore.load(fleet: false);
      expect(
        incidents.issues['logistics_trip_incidents']!.missingTable,
        isTrue,
        reason: incidents.issues['logistics_trip_incidents']!.cause.toString(),
      );
      final fleet = await LogisticsOperationsStore.load(fleet: true);
      expect(fleet.issues, isEmpty);
      expect(fleet.unitStates['v1']!.status, 'EN_REVISION');
    },
  );
  test('all incidents are loaded across the Supabase row limit', () async {
    db['logistics_trip_incidents'] = [
      for (var i = 0; i < 1002; i++) incident('i$i'),
    ];
    final bundle = await LogisticsOperationsStore.load(fleet: false);
    expect(bundle.incidents, hasLength(1002));
    expect(
      reads.where((r) => r.url.pathSegments.last == 'logistics_trip_incidents'),
      hasLength(2),
    );
    expect(writes, isEmpty);
  });
  test(
    'resolution requires an action and stale changes cannot overwrite newer follow-up',
    () async {
      final original = LogisticsIncident.fromRow(
        db['logistics_trip_incidents']!.first,
      );
      final draft = {
        ...db['logistics_trip_incidents']!.first,
        'resolution_status': 'RESUELTA',
      };
      await expectLater(
        LogisticsOperationsStore.saveIncident(draft, original: original),
        throwsArgumentError,
      );
      expect(writes, isEmpty);
      draft['action_taken'] = 'Frenos reparados';
      await LogisticsOperationsStore.saveIncident(draft, original: original);
      await expectLater(
        LogisticsOperationsStore.saveIncident({
          ...draft,
          'notes': 'Stale edit',
        }, original: original),
        throwsStateError,
      );
      expect(
        db['logistics_trip_incidents']!.first['notes'],
        'Revisión requerida',
      );
      expect(
        writes.last.url.queryParameters['updated_at'],
        'eq.${original.updatedAt}',
      );
    },
  );
  testWidgets(
    'manual fleet warnings and incident report leave assignments unchanged',
    (tester) async {
      await open(tester, const LogisticsUnitsPage());
      expect(find.text('En revisión'), findsOneWidget);
      expect(
        find.text('Advertencia informativa para la programación.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reportar incidencia').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'C-01'), findsOneWidget);
      await tester.enterText(field('Descripción'), 'Llanta dañada');
      await tester.tap(find.text('Guardar incidencia'));
      await tester.pumpAndSettle();
      expect(db['logistics_trip_incidents']!.last['vehicle_id'], 'v1');
      expect(db['logistics_trip_incidents']!.last['summary'], 'Llanta dañada');
      expect(writes, hasLength(1));
      await close(tester);
    },
  );
  testWidgets(
    'resolve validates action, removes from open view and retains history',
    (tester) async {
      await open(tester, const LogisticsIncidentsPage());
      await tester.tap(find.text('Resolver incidencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar incidencia'));
      await tester.pumpAndSettle();
      expect(find.text('Indica cómo se resolvió'), findsOneWidget);
      expect(writes, isEmpty);
      await tester.enterText(
        field('Acción realizada'),
        'Se cambiaron los frenos',
      );
      await tester.tap(find.text('Guardar incidencia'));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay incidencias con estos filtros.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resueltas').last);
      await tester.pumpAndSettle();
      expect(find.text('Se cambiaron los frenos'), findsOneWidget);
      expect(
        db['logistics_trip_incidents']!.first['service_label'],
        'SERVICIO ORIGINAL',
      );
      expect(
        db['logistics_trip_incidents']!.first['driver_name'],
        'CHOFER ORIGINAL',
      );
      await close(tester);
    },
  );
  testWidgets('save errors keep the form and draft open; retry succeeds once', (
    tester,
  ) async {
    await open(tester, const LogisticsIncidentsPage());
    await tester.tap(find.text('Nueva incidencia'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Descripción'), 'Material pendiente');
    failWrite = true;
    await tester.tap(find.text('Guardar incidencia'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo guardar la incidencia. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Material pendiente'), findsOneWidget);
    failWrite = false;
    await tester.tap(find.text('Guardar incidencia'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    await close(tester);
  });
  testWidgets(
    'navigation reaches incidents with one click and hides direction for non-directors',
    (tester) async {
      await open(tester, const LogisticsUnitsPage());
      await tester.tap(find.text('Navegación'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard Dirección'), findsNothing);
      await tester.tap(find.text('Incidencias').last);
      await tester.pumpAndSettle();
      expect(find.text('Nueva incidencia'), findsOneWidget);
      expect(find.byType(LogisticsIncidentsPage), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets('unavailable source data never appears as an available fleet', (
    tester,
  ) async {
    failRead = true;
    await open(tester, const LogisticsUnitsPage());
    expect(
      find.textContaining('No se pudieron cargar el catálogo de unidades.'),
      findsOneWidget,
    );
    expect(find.text('Disponible'), findsNothing);
    failRead = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('C-01'), findsOneWidget);
    await close(tester);
  });
  testWidgets('compact incident dialog remains usable at increased text size', (
    tester,
  ) async {
    await open(
      tester,
      const LogisticsIncidentsPage(),
      size: const Size(1000, 800),
      scale: 1.5,
    );
    await tester.tap(find.text('Nueva incidencia'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await close(tester);
  });
  testWidgets(
    'editing history keeps snapshots after a linked source was removed',
    (tester) async {
      db['logistics_trip_incidents']!.first.addAll({
        'service_id': null,
        'vehicle_id': null,
        'driver_employee_id': null,
      });
      await open(tester, const LogisticsIncidentsPage());
      await tester.tap(find.text('Editar seguimiento'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Notas'), 'Nota histórica corregida');
      await tester.tap(find.text('Guardar incidencia'));
      await tester.pumpAndSettle();
      final row = db['logistics_trip_incidents']!.first;
      expect(row['service_label'], 'SERVICIO ORIGINAL');
      expect(row['vehicle_code'], 'C-01');
      expect(row['driver_name'], 'CHOFER ORIGINAL');
      expect(row['notes'], 'Nota histórica corregida');
      await close(tester);
    },
  );
  testWidgets(
    'clearing a service link clears its label and typing begins on the first click',
    (tester) async {
      await open(tester, const LogisticsIncidentsPage());
      await tester.tap(find.text('Editar seguimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.route).last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.text('General / sin servicio'));
      await tester.pumpAndSettle();
      await tester.tap(field('Responsable de seguimiento'));
      await tester.pump();
      tester.testTextInput.enterText('ANA');
      await tester.pump();
      await tester.tap(find.text('Guardar incidencia'));
      await tester.pumpAndSettle();
      final row = db['logistics_trip_incidents']!.first;
      expect(row['service_id'], isNull);
      expect(row['service_label'], '');
      expect(row['responsible_name'], 'ANA');
      await close(tester);
    },
  );
  testWidgets('arrow keys select incidents and scroll them into view', (
    tester,
  ) async {
    db['logistics_trip_incidents'] = [
      for (var i = 0; i < 12; i++)
        incident('i$i')
          ..['reported_at'] =
              '2026-10-12T12:${i.toString().padLeft(2, '0')}:00Z',
    ];
    await open(tester, const LogisticsIncidentsPage());
    await tester.tap(find.text('Falla de frenos i11').first);
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(find.text('Falla de frenos i3'), findsNWidgets(2));
    expect(find.text('Falla de frenos i3').first.hitTestable(), findsOneWidget);
    await close(tester);
  });
  testWidgets(
    'missing states table still shows roster with no guessed availability',
    (tester) async {
      failedTables['logistics_unit_states'] = {
        'code': 'PGRST205',
        'message': 'Missing table',
      };
      await open(tester, const LogisticsUnitsPage());
      expect(find.text('C-01'), findsOneWidget);
      expect(find.text('Sin datos'), findsWidgets);
      expect(
        find.textContaining('Los estados manuales aún no están habilitados'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(
                    of: find.text('Actualizar estado').first,
                    matching: find.byWidgetPredicate((w) => w is FilledButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Disponible'), findsNothing);
      await close(tester);
    },
  );
  testWidgets(
    'missing incidents table shows specific activation message, not an empty history',
    (tester) async {
      failedTables['logistics_trip_incidents'] = {
        'code': 'PGRST205',
        'message': 'Missing table',
      };
      await open(tester, const LogisticsIncidentsPage());
      expect(
        find.textContaining('Incidencias aún no está habilitado'),
        findsOneWidget,
      );
      expect(find.text('No hay incidencias con estos filtros.'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(
                    of: find.text('Nueva incidencia'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await close(tester);
    },
  );
  testWidgets(
    'manual status is saved, survives reopening and never changes operational data',
    (tester) async {
      await open(tester, const LogisticsUnitsPage());
      expect(find.text('Sin capturar'), findsWidgets);
      await tester.tap(find.text('Actualizar estado').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fuera de servicio').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Observaciones',
        ),
        'Esperando refacción',
      );
      await tester.tap(find.text('Guardar estado'));
      await tester.pumpAndSettle();
      expect(find.text('Fuera de servicio'), findsOneWidget);
      expect(find.text('Esperando refacción'), findsOneWidget);
      expect(writes.single.url.pathSegments.last, 'logistics_unit_states');
      expect(db['services']!.first['status'], 'en_ruta');
      expect(db['vehicles']!.first['status'], 'activo');
      await close(tester);
      await open(tester, const LogisticsUnitsPage());
      expect(find.text('Fuera de servicio'), findsOneWidget);
      expect(find.text('Esperando refacción'), findsOneWidget);
      await close(tester);
    },
  );
  test(
    'concurrent manual status edits cannot overwrite a newer state',
    () async {
      final before = (await LogisticsOperationsStore.load(
        fleet: true,
      )).unitStates['v1']!;
      await LogisticsOperationsStore.saveUnitState(
        vehicleId: 'v1',
        status: 'DISPONIBLE',
        notes: 'Reparada',
        original: before,
      );
      await expectLater(
        LogisticsOperationsStore.saveUnitState(
          vehicleId: 'v1',
          status: 'EN_REVISION',
          notes: 'Obsoleto',
          original: before,
        ),
        throwsStateError,
      );
      expect(
        db['logistics_unit_states']!.first['operational_status'],
        'DISPONIBLE',
      );
    },
  );
  testWidgets(
    'unavailable optional service catalog still permits general incident capture',
    (tester) async {
      failedTables['services'] = {'code': '42501', 'message': 'Denied'};
      await open(tester, const LogisticsIncidentsPage());
      await tester.tap(find.text('Nueva incidencia'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No tienes acceso a los servicios para vincular'),
        findsOneWidget,
      );
      await tester.enterText(
        field('Descripción'),
        'Incidencia general independiente',
      );
      await tester.tap(find.text('Guardar incidencia'));
      await tester.pumpAndSettle();
      expect(
        db['logistics_trip_incidents']!.last['summary'],
        'Incidencia general independiente',
      );
      expect(writes, hasLength(1));
      await close(tester);
    },
  );
}
