import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/hr/human_resources_personnel_page.dart';
import 'package:dicsa_operacion/app/maintenance/maintenance_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final database = <String, List<Map<String, dynamic>>>{};
  final writes = <http.Request>[];
  String? errorCode;
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final root = config.absolute.uri.resolve(
      '${packages.singleWhere((p) => p['name'] == 'flutter')['rootUri']}/',
    );
    final font = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://preservation-ui.invalid',
      anonKey: 'synthetic',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        expectSync(r.url.host, 'preservation-ui.invalid');
        final table = r.url.pathSegments.last;
        if (r.method != 'GET') writes.add(r);
        if (r.url.path.contains('/rpc/')) {
          expectSync(table, 'app_commit_preserving_data');
          if (errorCode != null) {
            return http.Response(
              jsonEncode({'code': errorCode, 'message': 'Concurrent update'}),
              409,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          final result = <Map<String, dynamic>>[];
          for (final op in jsonDecode(r.body)['p_operations']) {
            final rows = database.putIfAbsent(op['table'], () => []);
            final index = rows.indexWhere((x) => x['id'] == op['id']);
            final row = <String, dynamic>{
              if (index >= 0) ...rows[index],
              ...?op['values'],
            };
            if (index >= 0) rows.removeAt(index);
            if (op['action'] != 'delete') rows.add(row);
            result.add({
              'table': op['table'],
              'action': op['action'],
              'row': row,
            });
          }
          return http.Response(
            jsonEncode(result),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.method != 'GET') throw StateError('Unexpected sequential write');
        final rows = database[table] ?? [];
        final result =
            (r.headers['Accept'] ?? r.headers['accept'] ?? '').contains(
              'vnd.pgrst.object',
            )
            ? rows.single
            : rows;
        return http.Response(
          jsonEncode(result),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    database.clear();
    writes.clear();
    errorCode = null;
  });
  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'RH failed save retains entered values and cannot close while saving',
    (tester) async {
      size(tester);
      var pending = Completer<bool>();
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await hrPersonnelCompensationEditorForTesting(
                    context,
                    employee: {'salario': 2000, 'salario_flujo': 1000},
                    persist: (_) => pending.future,
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('personalSalaryFlow'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '1234.56');
      await tester.tap(find.text('Guardar expediente'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Guardar expediente'), findsOneWidget);
      expect(saved, isNull);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Guardar expediente'), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, '1234.56');
      pending = Completer<bool>()..complete(true);
      await tester.tap(find.text('Guardar expediente'));
      await tester.pumpAndSettle();
      expect(saved!['salario_flujo'], 1234.56);
      expect(tester.takeException(), isNull);
    },
  );
  Future<State> openMaintenance(WidgetTester tester) async {
    size(tester);
    database.addAll({
      'maintenance_orders': [
        {
          'id': '00000000-0000-4000-8000-000000000001',
          'ot_folio': 'OT-TEST',
          'status': 'aviso_falla',
          'priority': 'media',
          'type': 'correctivo',
          'category': 'otros',
          'impact': 'sin_impacto',
          'requested_at': '2026-10-01T12:00:00Z',
          'problem_description': 'Original',
        },
      ],
      'maintenance_tasks': [
        {
          'id': '00000000-0000-4000-8000-000000000002',
          'ot_id': '00000000-0000-4000-8000-000000000001',
          'description': 'Original',
          'line_no': 1,
          'is_done': false,
          'created_at': '2026-10-01T12:00:00Z',
        },
      ],
      'maintenance_materials': [],
      'maintenance_time_logs': [],
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const MaintenancePage(),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(MaintenancePage));
  }

  testWidgets(
    'maintenance real page saves twice without replacing task identity',
    (tester) async {
      final state = await openMaintenance(tester);
      final originalId = database['maintenance_tasks']!.single['id'];
      var saved = maintenancePreservingSaveForTesting(state, 'First edit');
      await tester.pumpAndSettle();
      expect(
        await saved,
        isTrue,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where(
              (s) =>
                  s?.contains('guardar') == true ||
                  s?.contains('pendiente') == true,
            )
            .join(' | '),
      );
      saved = maintenancePreservingSaveForTesting(state, 'Second edit');
      await tester.pumpAndSettle();
      expect(
        await saved,
        isTrue,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where(
              (s) =>
                  s?.contains('guardar') == true ||
                  s?.contains('pendiente') == true,
            )
            .join(' | '),
      );
      expect(database['maintenance_tasks']!.single['id'], originalId);
      expect(
        database['maintenance_tasks']!.single['description'],
        'Second edit',
      );
      expect(writes, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'maintenance conflict keeps the draft and stops repeating destructive saves',
    (tester) async {
      final state = await openMaintenance(tester);
      errorCode = '40001';
      final saved = maintenancePreservingSaveForTesting(state, 'Local draft');
      await tester.pumpAndSettle();
      expect(await saved, isFalse);
      expect(database['maintenance_tasks']!.single['description'], 'Original');
      final snapshot = maintenancePreservationStateForTesting(state);
      expect(
        snapshot['conflict'],
        isTrue,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where(
              (s) =>
                  s?.contains('guardar') == true ||
                  s?.contains('pendiente') == true,
            )
            .join(' | '),
      );
      expect((snapshot['tasks'] as List).single['description'], 'Local draft');
      await tester.pump(const Duration(seconds: 4));
      expect(writes, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'maintenance validation rejection stops retries and permits a corrected save',
    (tester) async {
      final state = await openMaintenance(tester);
      errorCode = '23514';
      final rejected = maintenancePreservingSaveForTesting(
        state,
        'Rejected draft',
      );
      await tester.pumpAndSettle();
      expect(await rejected, isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(writes, hasLength(1));
      expect(database['maintenance_tasks']!.single['description'], 'Original');
      errorCode = null;
      final corrected = maintenancePreservingSaveForTesting(
        state,
        'Corrected draft',
      );
      await tester.pumpAndSettle();
      expect(await corrected, isTrue);
      expect(
        database['maintenance_tasks']!.single['description'],
        'Corrected draft',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
