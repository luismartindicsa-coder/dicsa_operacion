import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/logistica/logistics_catalog_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_catalog_pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final picker = _CatalogPdfPicker();
  final qaDir = Platform.environment['DICSA_LOGISTICS_QA_DIR'];
  late Directory output;
  late BuiltInMapCachingProvider mapCache;
  var writes = 0;
  var failLoad = false;
  final tables = <String, List<Map<String, dynamic>>>{
    'sites': [
      {
        'id': 's1',
        'name': 'EMPRESA PRUEBA',
        'type': 'cliente',
        'is_active': true,
      },
    ],
    'logistics_company_profiles': [
      {
        'site_id': 's1',
        'site_name': 'EMPRESA PRUEBA',
        'zone_id': 'z1',
        'address_line': 'Avenida México 123',
        'operational_contact': 'José Pérez',
        'contact_phone': '555 123 4567',
        'pickup_window': '08:00 a 16:00',
        'has_containers': true,
        'container_count': 2,
      },
    ],
    'logistics_zones': [
      {
        'id': 'z1',
        'code': 'NORTE',
        'name': 'Zona Norte',
        'city': 'Celaya',
        'state': 'Guanajuato',
        'coverage_hint': 'Parque industrial',
        'is_active': true,
      },
    ],
    'employees': [
      {
        'id': 'e1',
        'full_name': 'ANA LÓPEZ',
        'is_driver': true,
        'is_active': true,
      },
      {
        'id': 'e2',
        'full_name': 'JOSÉ PÉREZ',
        'is_driver': true,
        'is_active': true,
      },
    ],
    'logistics_driver_profiles': [
      {
        'employee_id': 'e1',
        'driver_name': 'ANA LÓPEZ',
        'compatible_unit_types': ['CAMION'],
        'coverage_note': 'EMPRESA PRUEBA, BASURERO',
        'coverage_import_pending': ['BASURERO'],
        'logistics_driver_companies': [
          {
            'site_id': 's1',
            'sites': {'name': 'EMPRESA PRUEBA', 'is_active': true},
          },
        ],
      },
      {
        'employee_id': 'e2',
        'driver_name': 'JOSÉ PÉREZ',
        'compatible_unit_types': ['TRAILER'],
      },
    ],
    'vehicles': [
      {
        'id': 'v1',
        'code': 'T-01',
        'status': 'activo',
        'type': 'camion',
        'serial_number': 'SERIE-01',
      },
      {
        'id': 'v2',
        'code': 'T-02',
        'status': 'activo',
        'type': 'trailer',
        'serial_number': 'SERIE-02',
      },
    ],
    'logistics_vehicle_profiles': [
      for (var i = 1; i <= 2; i++)
        {
          'vehicle_id': 'v$i',
          'vehicle_code': 'T-0$i',
          'source_status': 'activo',
          'source_vehicle_type': i == 1 ? 'camion' : 'trailer',
          'serial_number': 'SERIE-0$i',
          'model_year': i == 1 ? 2020 : null,
          'model_name': i == 1 ? 'Kenworth T680' : null,
          'logistics_unit_type': i == 1 ? 'CAMION' : 'TRAILER',
          'assigned_driver_employee_id': 'e$i',
          'tank_capacity_liters': 400.5,
          'compatible_load_types': ['CARGA_GENERAL'],
          'notes': 'Nota de unidad $i',
        },
    ],
    'logistics_containers': [
      {
        'id': 'c1',
        'container_label': 'C-01',
        'legacy_code': 'ANT-01',
        'entry_date': '2026-11-03',
        'operator_employee_id': 'e1',
        'operator_name': 'ANA LÓPEZ',
        'site_id': 's1',
        'site_name': 'EMPRESA PRUEBA',
        'location_label': 'Patio norte',
        'material_name': 'CARTÓN',
        'tare_weight_kg': 1250,
        'capacity_m3': 15.75,
        'width_m': 2.5,
        'height_m': 2.1,
        'length_m': 3,
        'compatible_unit_types': ['CAMION'],
        'is_active': true,
        'notes': 'Revisar compuerta antes de salir.',
      },
    ],
  };

  setUpAll(() async {
    output = qaDir == null
        ? await Directory.systemTemp.createTemp('catalog-pdf-')
        : Directory(qaDir);
    await output.create(recursive: true);
    mapCache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: '${output.path}/map-cache',
      readOnly: true,
    );
    FilePicker.platform = picker;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://catalog-pdf-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        if (failLoad && table == 'sites') {
          return http.Response(
            jsonEncode({'message': 'No disponible', 'code': '42501'}),
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method != 'GET') writes++;
        final query = request.url.queryParameters;
        final rows = (tables[table] ?? [])
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
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await mapCache.destroy(deleteCache: true);
    if (qaDir == null) await output.delete(recursive: true);
  });
  setUp(() {
    writes = 0;
    failLoad = false;
    picker.reset();
  });

  Future<void> open(WidgetTester tester, {double width = 1440}) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LogisticsCatalogPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> export(WidgetTester tester, String choice) async {
    await tester.tap(
      find.byKey(const ValueKey('logistics-catalog-download-pdf')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Generando PDF...').evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(find.text('Generando PDF...'), findsNothing);
    expect(tester.takeException(), isNull);
  }

  testWidgets('every catalog tab exports its own PDF', (tester) async {
    await open(tester);
    for (final kind in LogisticsCatalogKind.values) {
      final tabLabel = kind == LogisticsCatalogKind.zones
          ? 'Zonas y mapa'
          : kind.label;
      await tester.tap(find.text(tabLabel).last);
      await tester.pumpAndSettle();
      picker.path = '${output.path}/${kind.fileKey}.pdf';
      await export(tester, 'Catálogo actual: ${kind.label}');
      expect(
        picker.suggestedName,
        startsWith('catalogos_operativos_${kind.fileKey}_'),
      );
      expect(
        await tester.runAsync(() => File(picker.path!).length()),
        greaterThan(5000),
      );
    }
    expect(picker.calls, 5);
    expect(writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('current PDF uses the selected tab and visible search results', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Unidades').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar unidad o chofer'),
      'ANA',
    );
    await tester.pumpAndSettle();
    picker.path = '${output.path}/unidades-filtradas';
    await export(tester, 'Catálogo actual: Unidades');
    expect(picker.suggestedName, startsWith('catalogos_operativos_unidades_'));
    expect(find.textContaining('Reporte PDF guardado:'), findsOneWidget);
    final bytes = await tester.runAsync(
      () => File('${picker.path}.pdf').readAsBytes(),
    );
    expect(ascii.decode(bytes!.take(4).toList()), '%PDF');
    expect(writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'complete PDF includes all five catalogs despite a screen filter',
    (tester) async {
      await open(tester, width: 1024);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar empresa'),
        'SIN COINCIDENCIA',
      );
      await tester.pumpAndSettle();
      picker.path = '${output.path}/catalogos-completos.pdf';
      await export(tester, 'PDF general: todos los catálogos');
      expect(
        picker.suggestedName,
        startsWith('catalogos_operativos_completos_'),
      );
      expect(
        await tester.runAsync(() => File(picker.path!).length()),
        greaterThan(5000),
      );
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cancel and save errors restore the download button', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Descargar PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(picker.calls, 0);
    await export(tester, 'Catálogo actual: Empresas');
    expect(picker.calls, 1);
    expect(find.textContaining('Reporte PDF guardado:'), findsNothing);
    picker.fail = true;
    await export(tester, 'Catálogo actual: Empresas');
    expect(find.textContaining('No se pudo descargar el PDF:'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('logistics-catalog-download-pdf')),
    );
    expect(button.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed catalog loading disables export', (tester) async {
    failLoad = true;
    await open(tester);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('logistics-catalog-download-pdf')),
    );
    expect(button.onPressed, isNull);
    expect(picker.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'large catalog paginates long notes and includes an empty section',
    () async {
      final sections = [
        LogisticsCatalogPdfSection(
          kind: LogisticsCatalogKind.containers,
          totalCount: 120,
          records: [
            for (var i = 1; i <= 120; i++)
              LogisticsCatalogPdfRecord(
                id: 'c$i',
                title: 'C-${i.toString().padLeft(3, '0')}',
                fields: [
                  LogisticsCatalogPdfField(
                    'Observaciones',
                    i == 1
                        ? '${List.filled(500, 'Información extensa de la operación.').join(' ')} FINAL_NOTA_LARGA'
                        : 'NOTA_$i',
                  ),
                ],
              ),
          ],
        ),
        const LogisticsCatalogPdfSection(
          kind: LogisticsCatalogKind.zones,
          totalCount: 0,
          records: [],
          search: 'Sin coincidencia',
        ),
      ];
      final bytes = await buildLogisticsCatalogPdf(
        sections: sections,
        generatedAt: DateTime(2026, 11, 3, 10, 30),
      );
      await File('${output.path}/catalogo-extenso.pdf').writeAsBytes(bytes);
      expect(bytes.length, greaterThan(5000));
    },
  );
}

class _CatalogPdfPicker extends FilePicker {
  String? path;
  String? suggestedName;
  bool fail = false;
  int calls = 0;
  void reset() {
    path = null;
    suggestedName = null;
    fail = false;
    calls = 0;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    calls++;
    suggestedName = fileName;
    if (fail) throw PlatformException(code: 'save_failed');
    return path;
  }
}
