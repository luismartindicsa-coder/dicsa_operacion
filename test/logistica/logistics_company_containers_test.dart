import 'dart:convert';

import 'package:dicsa_operacion/app/logistica/logistics_catalog_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = <String, List<Map<String, dynamic>>>{};
  final writes = <String>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://company-containers-test.invalid',
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
        Map<String, dynamic>? saved;
        if (request.method == 'POST') {
          writes.add(table);
          final body = jsonDecode(request.body);
          for (final raw in body is List ? body : [body]) {
            final patch = Map<String, dynamic>.from(raw as Map);
            final idKey = table == 'logistics_company_profiles'
                ? 'site_id'
                : 'id';
            final existing = data
                .where((row) => row[idKey] == patch[idKey])
                .firstOrNull;
            if (existing == null) {
              data.add(patch);
              saved = patch;
            } else {
              existing.addAll(patch);
              saved = existing;
            }
          }
        }
        final rows = data
            .where(
              (row) => request.url.queryParameters.entries.every(
                (entry) =>
                    !entry.value.startsWith('eq.') ||
                    '${row[entry.key]}' == entry.value.substring(3),
              ),
            )
            .toList();
        return http.Response(
          jsonEncode(
            request.headers['accept'] == 'application/vnd.pgrst.object+json'
                ? saved
                : rows,
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    tables.clear();
    writes.clear();
    tables['sites'] = [
      {
        'id': 's1',
        'name': 'EMPRESA ALFA',
        'type': 'cliente',
        'is_active': true,
      },
      {
        'id': 's2',
        'name': 'EMPRESA BETA',
        'type': 'cliente',
        'is_active': true,
      },
    ];
    tables['logistics_company_profiles'] = [
      {
        'site_id': 's1',
        'site_name': 'EMPRESA ALFA',
        'has_containers': false,
        'container_count': 0,
      },
      {
        'site_id': 's2',
        'site_name': 'EMPRESA BETA',
        'has_containers': true,
        'container_count': 99,
      },
    ];
    tables['logistics_containers'] = [
      for (final label in ['C-02', 'C-01', 'INACTIVO', 'SIN ASIGNAR'])
        {
          'id': label, 'container_label': label, 'entry_date': '2026-11-03',
          'site_id': label == 'SIN ASIGNAR' ? null : 's1',
          // Deliberately stale text: the relation must use the company ID.
          'site_name': 'EMPRESA BETA', 'location_label': 'Patio norte',
          'is_active': label != 'INACTIVO',
          'notes': 'Conservar comentario', 'tare_weight_kg': 1200,
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
  }

  Future<void> companySearch(WidgetTester tester, String value) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar empresa'),
      value,
    );
    await tester.pumpAndSettle();
  }

  Future<void> editContainer(WidgetTester tester) async {
    await tester.tap(find.text('Contenedores').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar contenedor'),
      'C-01',
    );
    await tester.pumpAndSettle();
    final edit = find.text('Editar contenedor');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
  }

  Future<void> saveContainer(WidgetTester tester) async {
    final save = find.text('Actualizar contenedor');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Empresas').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'existing links show automatically by ID, with active count and searchable labels',
    (tester) async {
      await open(tester);
      expect(find.text('2 contenedores · C-01, C-02'), findsOneWidget);
      expect(find.text('Sin contenedores activos asignados.'), findsOneWidget);
      expect(writes, isEmpty);
      await companySearch(tester, 'C-02');
      expect(find.text('EMPRESA ALFA'), findsOneWidget);
      expect(find.text('EMPRESA BETA'), findsNothing);
      await companySearch(tester, 'INACTIVO');
      expect(find.text('EMPRESA ALFA'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('moving and unlinking a container refreshes both company cards', (
    tester,
  ) async {
    await open(tester);
    await editContainer(tester);
    final companyPicker = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Empresa vinculada',
    );
    await tester.ensureVisible(companyPicker);
    await tester.tap(companyPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('EMPRESA BETA').last);
    await tester.pumpAndSettle();
    await saveContainer(tester);
    expect(find.text('1 contenedor · C-02'), findsOneWidget);
    expect(find.text('1 contenedor · C-01'), findsOneWidget);
    final saved = tables['logistics_containers']!.firstWhere(
      (row) => row['id'] == 'C-01',
    );
    expect(saved['site_id'], 's2');
    expect(saved['tare_weight_kg'], 1200);
    expect(saved['notes'], 'Conservar comentario');
    await editContainer(tester);
    await tester.ensureVisible(companyPicker);
    await tester.tap(companyPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sin empresa vinculada').last);
    await tester.pumpAndSettle();
    await saveContainer(tester);
    expect(saved['site_id'], isNull);
    expect(find.text('1 contenedor · C-02'), findsOneWidget);
    expect(find.text('Sin contenedores activos asignados.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'company profile shows derived containers and saving contact preserves their assignments',
    (tester) async {
      await open(tester);
      await companySearch(tester, 'ALFA');
      await tester.ensureVisible(find.text('Editar perfil'));
      await tester.tap(find.text('Editar perfil'));
      await tester.pumpAndSettle();
      final assigned = find.byKey(
        const ValueKey('logistics-company-assigned-containers'),
      );
      await tester.ensureVisible(assigned);
      expect(
        find.descendant(
          of: assigned,
          matching: find.text('2 contenedores · C-01, C-02'),
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Cantidad de contenedores'),
        findsNothing,
      );
      expect(find.text('Tiene contenedores'), findsNothing);
      final contact = find.widgetWithText(TextField, 'Contacto operativo');
      await tester.ensureVisible(contact);
      await tester.enterText(contact, 'ANA');
      final save = find.text('Guardar perfil');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(writes, ['logistics_company_profiles']);
      expect(tables['logistics_company_profiles']!.first['container_count'], 2);
      expect(
        tables['logistics_company_profiles']!.first['operational_contact'],
        'ANA',
      );
      expect(find.text('2 contenedores · C-01, C-02'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
