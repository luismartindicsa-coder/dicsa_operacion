import 'dart:convert';

import 'package:dicsa_operacion/app/logistica/logistics_catalog_page.dart';
import 'package:dicsa_operacion/app/shared/archetypes/grid_editable/filters/grid_filter_dialog.dart';
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
  const original = '  MONROE SUR, ROCIO\nCARVAJAL, BASURERO  ';
  final tables = <String, List<Map<String, dynamic>>>{};
  final writes = <Map<String, dynamic>>[];
  var failSave = false;
  var failRead = false;
  Map<String, dynamic> profile() => tables['logistics_driver_profiles']!.single;
  Map<String, dynamic> link(String id) => {
    'site_id': id,
    'sites': {
      'name': tables['sites']!.firstWhere((r) => r['id'] == id)['name'],
      'is_active': id != 's4',
    },
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://driver-companies-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        http.Response response(Object? body, [int status = 200]) =>
            http.Response(
              jsonEncode(body),
              status,
              headers: {'content-type': 'application/json'},
              request: request,
            );
        if (table == 'save_logistics_driver_with_companies') {
          final body = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          writes.add(body);
          if (failSave) {
            return response({
              'message': 'No se pudo guardar',
              'code': '42501',
            }, 403);
          }
          profile().addAll(Map<String, dynamic>.from(body['p_profile'] as Map));
          profile()['logistics_driver_companies'] = (body['p_site_ids'] as List)
              .cast<String>()
              .map(link)
              .toList();
          return response(null);
        }
        if (failRead && table == 'logistics_driver_profiles') {
          return response({
            'message': 'Lectura no disponible',
            'code': '42501',
          }, 403);
        }
        final data = tables.putIfAbsent(table, () => []);
        if (request.method == 'POST') {
          for (final raw in jsonDecode(request.body) as List) {
            final patch = Map<String, dynamic>.from(raw as Map);
            if (table == 'logistics_driver_profiles') {
              writes.add(patch);
              profile().addAll(patch);
            } else if (table == 'logistics_company_profiles') {
              data.add(patch);
            }
          }
        }
        return response(
          data
              .where(
                (row) => request.url.queryParameters.entries.every(
                  (e) =>
                      !e.value.startsWith('eq.') ||
                      '${row[e.key]}' == e.value.substring(3),
                ),
              )
              .toList(),
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    tables.clear();
    writes.clear();
    failSave = false;
    failRead = false;
    tables['sites'] = [
      {'id': 's1', 'name': 'MONROE SUR', 'type': 'cliente', 'is_active': true},
      {
        'id': 's2',
        'name': 'ROCIO CARVAJAL',
        'type': 'cliente',
        'is_active': true,
      },
      {'id': 's3', 'name': 'AVON', 'type': 'cliente', 'is_active': true},
      {
        'id': 's4',
        'name': 'EMPRESA INACTIVA',
        'type': 'cliente',
        'is_active': false,
      },
    ];
    tables['logistics_company_profiles'] = [
      for (final site in tables['sites']!)
        {'site_id': site['id'], 'site_name': site['name']},
    ];
    tables['employees'] = [
      {
        'id': 'e1',
        'full_name': 'RENE JIMENEZ',
        'is_driver': true,
        'is_active': true,
      },
    ];
    tables['logistics_driver_profiles'] = [
      {
        'employee_id': 'e1',
        'driver_name': 'RENE JIMENEZ',
        'compatible_unit_types': ['GRUA'],
        'coverage_note': original,
        'notes': 'NOTA INTACTA',
        'planning_status': 'ACTIVO',
        'coverage_import_pending': ['BASURERO'],
        'logistics_driver_companies': [link('s1'), link('s2')],
      },
    ];
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LogisticsCatalogPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choferes').last);
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester) async {
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
  }

  Future<void> picker(WidgetTester tester) async {
    final button = find.byKey(
      const ValueKey('logistics-driver-companies-picker'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, 'Buscar');
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guardar perfil'));
    await tester.tap(find.text('Guardar perfil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'multi-select, save, reload and clear preserve original coverage and show reverse links',
    (tester) async {
      await open(tester);
      expect(find.text('MONROE SUR, ROCIO CARVAJAL'), findsOneWidget);
      expect(
        find.text('Sin coincidencia automática: BASURERO'),
        findsOneWidget,
      );
      await edit(tester);
      await picker(tester);
      expect(find.text('EMPRESA INACTIVA'), findsNothing);
      expect(
        tester.getTopLeft(find.text('AVON')).dy,
        lessThan(tester.getTopLeft(find.text('MONROE SUR')).dy),
      );
      await tester.tap(
        find.text('AVON'),
      ); // add one while preserving imported assignments
      await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'ROCIO');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await save(tester);
      expect(writes.single['p_expected_site_ids'], ['s1', 's2']);
      expect(writes.single['p_site_ids'], ['s3', 's1']);
      expect(profile()['coverage_note'], original);
      expect(profile()['notes'], 'NOTA INTACTA');
      expect(find.text('AVON, MONROE SUR'), findsOneWidget);
      await tester.tap(find.text('Empresas').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar empresa'),
        'AVON',
      );
      await tester.pumpAndSettle();
      expect(find.text('RENE JIMENEZ'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.text('AVON, MONROE SUR'), findsOneWidget);
      await edit(tester);
      await picker(tester);
      await tester.tap(find.text('Limpiar'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(find.text('Sin empresas asignadas.'), findsOneWidget);
      expect(profile()['coverage_note'], original);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cancel picker and editor, then failed save leave assignments intact',
    (tester) async {
      await open(tester);
      await edit(tester);
      await picker(tester);
      await tester.tap(find.text('AVON'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Seleccionar empresas (2)'), findsOneWidget);
      await picker(tester);
      await tester.tap(find.text('AVON'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await edit(tester);
      await picker(tester);
      await tester.tap(find.text('AVON'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      failSave = true;
      await save(tester);
      expect(find.text('MONROE SUR, ROCIO CARVAJAL'), findsOneWidget);
      expect(profile()['coverage_note'], original);
      expect(
        find.textContaining('No se pudo guardar el perfil del chofer:'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'master name sync preserves manual text and links, and load failures surface',
    () async {
      tables['employees']!.single['full_name'] = 'RENE ACTUALIZADO';
      final drivers = await LogisticsDriverProfileStore.loadProfiles();
      expect(writes.single, {
        'employee_id': 'e1',
        'driver_name': 'RENE ACTUALIZADO',
      });
      expect(drivers.single.assignedCompanies.map((c) => c.siteId), [
        's1',
        's2',
      ]);
      expect(profile()['coverage_note'], original);
      failRead = true;
      await expectLater(
        LogisticsDriverProfileStore.loadProfiles(),
        throwsA(isA<PostgrestException>()),
      );
      expect(writes, hasLength(1));
    },
  );

  testWidgets(
    'an existing inactive company remains selected when saving other profile fields',
    (tester) async {
      profile()['logistics_driver_companies'] = [link('s4')];
      await open(tester);
      await edit(tester);
      await picker(tester);
      expect(
        find.descendant(
          of: find.byType(GridFilterDialog),
          matching: find.text('EMPRESA INACTIVA (inactiva)'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(writes.single['p_site_ids'], ['s4']);
      expect(profile()['coverage_note'], original);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
