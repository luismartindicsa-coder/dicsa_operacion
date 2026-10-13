import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/auth/auth_access.dart';
import 'package:dicsa_operacion/app/maintenance/maintenance_page.dart';
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
  final reads = <http.Request>[], writes = <http.Request>[];
  var rejectInsert = false, role = 'operacion';
  var created = 0;
  setUpAll(() async {
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
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://ot-simplified.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        final table = r.url.pathSegments.last;
        final params = r.url.queryParameters;
        final rows = db.putIfAbsent(table, () => []);
        if (r.method == 'GET') {
          reads.add(r);
        } else {
          writes.add(r);
        }
        http.Response respond(Object? result, {int status = 200}) =>
            http.Response(
              jsonEncode(result),
              status,
              request: r,
              headers: {'content-type': 'application/json'},
            );
        if (table == 'profiles') {
          return respond({'role': role, 'is_active': true});
        }
        if (r.url.path.contains('/rpc/')) {
          final result = <Map<String, dynamic>>[];
          for (final op in jsonDecode(r.body)['p_operations']) {
            final records = db.putIfAbsent(op['table'], () => []);
            final index = records.indexWhere((row) => row['id'] == op['id']);
            final row = <String, dynamic>{
              if (index >= 0) ...records[index],
              ...?op['values'],
            };
            if (index >= 0) records.removeAt(index);
            if (op['action'] != 'delete') records.add(row);
            result.add({
              'table': op['table'],
              'action': op['action'],
              'row': row,
            });
          }
          return respond(result);
        }
        bool matches(Map<String, dynamic> row) => params.entries.every(
          (p) =>
              !p.value.startsWith('eq.') ||
              row[p.key]?.toString() == p.value.substring(3),
        );
        var result = <Map<String, dynamic>>[];
        if (r.method == 'GET') {
          result = rows
              .where(matches)
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          final select = params['select'];
          if (select != null && select != '*') {
            result = result
                .map((r) => {for (final f in select.split(',')) f: r[f]})
                .toList();
          }
        } else if (r.method == 'POST') {
          if (rejectInsert) {
            return respond({
              'code': '42501',
              'message': 'Insert denied',
            }, status: 403);
          }
          if (table == 'maintenance_status_log') {
            final row = Map<String, dynamic>.from(jsonDecode(r.body));
            rows.add(row);
            return respond([row]);
          }
          expect(table, 'maintenance_orders');
          final row = Map<String, dynamic>.from(jsonDecode(r.body));
          expect(
            row.containsKey('serial_number'),
            isFalse,
            reason: 'OT serial field is equipment_serial',
          );
          row['id'] = 'new-${++created}';
          rows.add(row);
          result = [row];
        } else if (r.method == 'PATCH' && table == 'maintenance_orders') {
          final patch = Map<String, dynamic>.from(jsonDecode(r.body));
          expect(patch.keys, ['status']);
          result = rows.where(matches).toList();
          for (final row in result) {
            row.addAll(patch);
          }
        } else {
          fail('Unexpected sequential write ${r.method} $table');
        }
        final single =
            r.headers['accept']?.contains('vnd.pgrst.object') ?? false;
        return respond(single ? result.firstOrNull : result);
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  Map<String, dynamic> order(String id, String status) => {
    'id': id,
    'ot_folio': id == 'open' ? 'OT-2026-000001' : 'OT-2026-000002',
    'status': status,
    'priority': 'alta',
    'type': 'correctivo',
    'category': 'mecanica',
    'impact': 'paro_parcial',
    'area_label': 'CARTON',
    'equipment_label': 'PRENSA 01',
    'equipment_serial': 'SERIE-01',
    'requested_at': '2026-10-01T12:00:00Z',
    'problem_description': 'Fuga hidráulica',
    'diagnosis': 'Diagnóstico original',
    'work_summary': 'Trabajo original',
    'requester_name': 'SOLICITANTE ORIGINAL',
    'mechanic_name': 'MECÁNICO ORIGINAL',
    'mechanic_contact': 'CONTACTO ORIGINAL',
    'category_snapshot': 'Mecanica',
    'assigned_to_name': 'JUAN',
    'cost_estimated_total': 300,
    'cost_actual_total': 250,
  };
  setUp(() async {
    db.clear();
    reads.clear();
    writes.clear();
    rejectInsert = false;
    role = 'operacion';
    created = 0;
    db.addAll({
      'maintenance_orders': [
        order('closed', 'cerrado'),
        order('open', 'aviso_falla'),
      ],
      'maintenance_tasks': [
        {
          'id': 'task1',
          'ot_id': 'open',
          'description': 'Cambiar manguera',
          'qty': 1,
          'unit': 'SERV',
          'line_no': 1,
          'is_done': false,
        },
      ],
      'maintenance_materials': [
        {
          'id': 'mat1',
          'ot_id': 'open',
          'name': 'Manguera',
          'purchase_order_id': 'purchase-original',
          'notes': 'Nota original',
          'qty': 1,
          'source': 'almacen',
          'cost_estimated': 300,
          'cost_actual': 250,
          'line_no': 1,
        },
      ],
      'maintenance_time_logs': [
        {
          'id': 'time1',
          'ot_id': 'open',
          'start_at': '2026-10-01T10:00:00Z',
          'end_at': '2026-10-01T11:00:00Z',
          'minutes': 60,
          'tech_name': 'JUAN',
        },
      ],
      'vehicles': [
        {
          'id': 'vehicle1',
          'code': 'C-01',
          'status': 'activo',
          'serial_number': 'SERIE-C01',
        },
      ],
    });
    AuthAccess.invalidateResolvedProfileCache();
    final expiry =
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
        1000;
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': 'user-ot', 'exp': expiry})}.signature';
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'test',
        'token_type': 'bearer',
        'expires_in': 86400,
        'user': {
          'id': 'user-ot',
          'aud': 'authenticated',
          'email': 'pruebas@example.invalid',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  Future<void> open(
    WidgetTester tester, {
    bool viewer = false,
    String? initial,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: MaintenancePage(viewerMode: viewer, initialOrderId: initial),
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
  Future<void> newOrder(WidgetTester tester) async {
    await tester.tap(find.text('Nueva OT'));
    await tester.pumpAndSettle();
    await tester.enterText(field('¿Qué necesita atención?'), 'Revisar bomba');
    final dropdown = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButtonFormField<String>),
        )
        .first;
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CARTON').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pending-first layout keeps details and avoids loading report data on entry',
    (tester) async {
      await open(tester);
      expect(find.text('OT-2026-000002'), findsNothing);
      expect(find.text('OT-2026-000001'), findsOneWidget);
      expect(find.text('Cambiar estado'), findsOneWidget);
      expect(find.text('Trabajo realizado'), findsOneWidget);
      expect(find.text('Agregar actividad'), findsNothing);
      expect(writes, isEmpty);
      expect(
        reads.where(
          (r) =>
              r.url.pathSegments.last == 'maintenance_time_logs' &&
              (r.url.queryParameters['ot_id'] ?? '').startsWith('in.'),
        ),
        isEmpty,
      );
      await close(tester);
    },
  );
  testWidgets(
    'quick create validates required fields and cancel does not create a blank order',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Nueva OT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear OT'));
      await tester.pumpAndSettle();
      expect(
        find.text('Describe el problema o trabajo a realizar'),
        findsOneWidget,
      );
      expect(find.text('Selecciona el área'), findsOneWidget);
      expect(writes, isEmpty);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(db['maintenance_orders'], hasLength(2));
      await close(tester);
    },
  );
  testWidgets(
    'quick create inserts the completed draft once and selects its order',
    (tester) async {
      await open(tester);
      await newOrder(tester);
      await tester.enterText(
        field('Equipo o ubicación (opcional)'),
        'BOMBA 02',
      );
      await tester.enterText(field('Responsable (opcional)'), 'MARIA');
      await tester.tap(find.text('Crear OT'));
      await tester.tap(find.text('Crear OT'), warnIfMissed: false);
      await tester.pumpAndSettle();
      final row = db['maintenance_orders']!.last;
      expect(row['problem_description'], 'Revisar bomba');
      expect(row['area_label'], 'CARTON');
      expect(row['assigned_to_name'], 'MARIA');
      expect(row['equipment_label'], 'BOMBA 02');
      expect(row['status'], 'aviso_falla');
      expect(
        writes.where(
          (w) => w.method == 'POST' && !w.url.path.contains('/rpc/'),
        ),
        hasLength(1),
      );
      expect(find.text('Orden ${row['ot_folio']}'), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets('create failure preserves typed data and permits retry', (
    tester,
  ) async {
    await open(tester);
    await newOrder(tester);
    rejectInsert = true;
    await tester.tap(find.text('Crear OT'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No se pudo crear la OT. Conservamos los datos para que intentes de nuevo.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(field('¿Qué necesita atención?'))
          .controller!
          .text,
      'Revisar bomba',
    );
    rejectInsert = false;
    await tester.tap(find.text('Crear OT'));
    await tester.pumpAndSettle();
    expect(db['maintenance_orders'], hasLength(3));
    await close(tester);
  });
  testWidgets(
    'collapsing sections and saving a description preserves all existing details',
    (tester) async {
      await open(tester);
      final originalOrder = Map<String, dynamic>.from(
        db['maintenance_orders']!.singleWhere((o) => o['id'] == 'open'),
      );
      final originals = {
        for (final t in [
          'maintenance_tasks',
          'maintenance_materials',
          'maintenance_time_logs',
        ])
          t: jsonDecode(jsonEncode(db[t])) as List,
      };
      await tester.tap(find.text('Trabajo realizado'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar actividad'), findsOneWidget);
      await tester.tap(find.text('Trabajo realizado'));
      await tester.pumpAndSettle();
      await tester.enterText(
        field('Descripción del problema'),
        'Descripción corregida',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        db['maintenance_orders']!.singleWhere(
          (o) => o['id'] == 'open',
        )['problem_description'],
        'Descripción corregida',
      );
      final savedOrder = db['maintenance_orders']!.singleWhere(
        (o) => o['id'] == 'open',
      );
      for (final key in [
        'requester_name',
        'equipment_serial',
        'mechanic_name',
        'mechanic_contact',
        'work_summary',
        'diagnosis',
        'priority',
        'type',
        'impact',
        'category',
        'category_snapshot',
      ]) {
        expect(
          savedOrder[key],
          originalOrder[key],
          reason: '$key must survive folded controls',
        );
      }
      for (final entry in originals.entries) {
        expect(db[entry.key]!.length, entry.value.length);
        for (final original in entry.value) {
          final saved = db[entry.key]!.singleWhere(
            (row) => row['id'] == original['id'],
          );
          for (final field in (original as Map).entries) {
            expect(saved[field.key], field.value);
          }
        }
      }
      await close(tester);
    },
  );
  testWidgets(
    'closed orders remain available through filters and direct links',
    (tester) async {
      await open(tester, initial: 'closed');
      expect(find.text('Orden OT-2026-000002'), findsOneWidget);
      expect(find.text('OT-2026-000002'), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets('viewer cannot edit, save, create or change workflow state', (
    tester,
  ) async {
    await open(tester, viewer: true);
    expect(find.text('Guardar'), findsNothing);
    expect(find.text('Cambiar estado'), findsNothing);
    expect(
      tester.widget<TextField>(field('Descripción del problema')).readOnly,
      isTrue,
    );
    expect(find.text('Modo visualizador'), findsOneWidget);
    expect(writes, isEmpty);
    await close(tester);
  });
  testWidgets(
    'accounting keeps material-only editing and no workflow actions',
    (tester) async {
      role = 'contabilidad';
      AuthAccess.invalidateResolvedProfileCache();
      await open(tester);
      expect(find.text('Guardar materiales'), findsOneWidget);
      expect(find.text('Cambiar estado'), findsNothing);
      expect(
        tester.widget<TextField>(field('Descripción del problema')).readOnly,
        isTrue,
      );
      expect(find.text('Agregar material'), findsOneWidget);
      expect(find.text('Fotos (0)'), findsNothing);
      expect(writes, isEmpty);
      await close(tester);
    },
  );
  testWidgets('compact window and quick create do not overflow', (
    tester,
  ) async {
    await open(tester, size: const Size(1000, 800));
    await tester.tap(find.text('Nueva OT'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await close(tester);
  });
  for (final step in {
    'supervision': 'cerrado',
    'autorizacion_finanzas': 'supervision',
  }.entries) {
    testWidgets(
      '${step.value} permits missing diagnosis, activities and evidence',
      (tester) async {
        role = 'admin';
        AuthAccess.invalidateResolvedProfileCache();
        final order = db['maintenance_orders']!.singleWhere(
          (o) => o['id'] == 'open',
        );
        order['status'] = step.key;
        order['diagnosis'] = null;
        order['work_summary'] = null;
        db['maintenance_tasks'] = [];
        db['maintenance_evidence'] = [];
        await open(tester);
        await tester.tap(find.text('Cambiar estado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        expect(order['status'], step.value);
        expect(order['diagnosis'], isNull);
        expect(db['maintenance_tasks'], isEmpty);
        expect(db['maintenance_evidence'], isEmpty);
        expect(db['maintenance_status_log']!.single['to_status'], step.value);
        expect(find.text('Estado actualizado'), findsOneWidget);
        await close(tester);
      },
    );
  }
  testWidgets('closing still checks the existing role restriction', (
    tester,
  ) async {
    db['maintenance_orders']!.singleWhere((o) => o['id'] == 'open')['status'] =
        'supervision';
    await open(tester);
    await tester.tap(find.text('Cambiar estado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Solo Jefe Operativo o Admin puede cerrar'),
      findsOneWidget,
    );
    expect(writes, isEmpty);
    expect(
      db['maintenance_orders']!.singleWhere((o) => o['id'] == 'open')['status'],
      'supervision',
    );
    await close(tester);
  });
  testWidgets('reports fetch their detail only when opened', (tester) async {
    await open(tester);
    reads.clear();
    await tester.tap(find.text('Reportes'));
    await tester.pumpAndSettle();
    for (final table in [
      'maintenance_time_logs',
      'maintenance_tasks',
      'maintenance_materials',
    ]) {
      expect(
        reads.where(
          (r) =>
              r.url.pathSegments.last == table &&
              (r.url.queryParameters['ot_id'] ?? '').startsWith('in.'),
        ),
        hasLength(1),
      );
    }
    expect(writes, isEmpty);
    await close(tester);
  });
  testWidgets('equipment captured manually can be corrected in order details', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Datos de la orden'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('Equipo o ubicación'));
    await tester.enterText(field('Equipo o ubicación'), 'PRENSA 02');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final row = db['maintenance_orders']!.singleWhere((o) => o['id'] == 'open');
    expect(row['equipment_label'], 'PRENSA 02');
    expect(row['equipment_serial'], 'SERIE-01');
    await close(tester);
  });
  testWidgets(
    'new order can select a vehicle and keeps its identity and serial',
    (tester) async {
      await open(tester);
      await newOrder(tester);
      await tester.tap(find.byTooltip('Seleccionar unidad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C-01').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear OT'));
      await tester.pumpAndSettle();
      final row = db['maintenance_orders']!.last;
      expect(row['equipment_id'], 'vehicle1');
      expect(row['equipment_label'], 'C-01');
      expect(row['equipment_serial'], 'SERIE-C01');
      await close(tester);
    },
  );
  testWidgets(
    'secondary details are available on demand and pending approvals remain visible',
    (tester) async {
      db['maintenance_approvals'] = [
        {
          'id': 'approval1',
          'ot_id': 'open',
          'step': 'operador',
          'status': 'pendiente',
        },
      ];
      await open(tester);
      expect(find.text('Aprobaciones pendientes'), findsOneWidget);
      expect(find.text('Registro de tiempo'), findsOneWidget); // summary only
      expect(find.text('Agregar tiempo'), findsNothing);
      await tester.tap(find.text('Datos de la orden'));
      await tester.pumpAndSettle();
      expect(field('Mecánico'), findsOneWidget);
      expect(field('Serie'), findsNothing);
      expect(find.text('Equipo (unidades)'), findsNothing);
      expect(find.text('Contacto registrado'), findsNothing);
      await tester.ensureVisible(find.text('Más datos de la orden'));
      await tester.tap(find.text('Más datos de la orden'));
      await tester.pumpAndSettle();
      expect(field('Serie'), findsOneWidget);
      expect(field('Solicitante'), findsOneWidget);
      expect(writes, isEmpty);
      await close(tester);
    },
  );
  testWidgets(
    'editing an activity keeps quantity, unit and notes while folded',
    (tester) async {
      db['maintenance_tasks']!.first['notes'] = 'Nota de actividad';
      await open(tester);
      await tester.tap(find.text('Trabajo realizado'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Editar actividad'));
      await tester.tap(find.byTooltip('Editar actividad'));
      await tester.pumpAndSettle();
      expect(field('Unidad'), findsNothing);
      await tester.enterText(field('Actividad'), 'Revisar manguera');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Guardar'),
        ),
      );
      await tester.pumpAndSettle();
      final row = db['maintenance_tasks']!.single;
      expect(row['id'], 'task1');
      expect(row['description'], 'Revisar manguera');
      expect(row['qty'], 1);
      expect(row['unit'], 'SERV');
      expect(row['notes'], 'Nota de actividad');
      await close(tester);
    },
  );
}
