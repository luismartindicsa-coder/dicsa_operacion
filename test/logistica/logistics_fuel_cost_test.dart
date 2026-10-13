import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dicsa_operacion/app/logistica/logistics_fuel_cost.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_store.dart';
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
  final picker = _FuelImportPicker();
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
        final data = tables.putIfAbsent(table, () => []);
        if (r.method == 'POST') {
          expectSync(table, 'logistics_vehicle_mileage');
          expectSync(
            r.url.queryParameters['on_conflict'],
            'entry_date,vehicle_key',
          );
          final decoded = jsonDecode(r.body);
          for (final row in (decoded is List ? decoded : [decoded])) {
            final patch = Map<String, dynamic>.from(row as Map);
            writes.add(patch);
            final existing = data
                .where(
                  (d) =>
                      d['entry_date'] == patch['entry_date'] &&
                      d['vehicle_key'] == patch['vehicle_key'],
                )
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
    FilePicker.platform = picker;
    picker.bytes = _mileageWorkbook();
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
    tables['logistics_vehicle_mileage'] = [];
    tables['logistics_diesel_consumption'] = [
      {
        'id': 'd1',
        'entry_date': _date(1),
        'vehicle_id': 'v1',
        'vehicle_label': 'T-01',
        'liters_requested': 100,
        'liters_purchased': 5000,
      },
    ];
  });

  test(
    'price parsing, mixed fuel, rounding, missing prices and changing prices',
    () {
      expect(parseLogisticsFuelPrice('25,50'), 25.5);
      expect(parseLogisticsFuelPrice(' 24.10 '), 24.1);
      expect(parseLogisticsFuelPrice(''), isNull);
      for (final value in [
        '0',
        '-1',
        'NaN',
        'Infinity',
        '1e3',
        '20.123',
        '1000000',
      ]) {
        expect(() => parseLogisticsFuelPrice(value), throwsFormatException);
      }
      final first = LogisticsFuelCost.calculate(
        dieselLiters: 100,
        gasolineLiters: 10,
        dieselPrice: 25.50,
        gasolinePrice: 24.10,
      );
      expect(first.label, r'$2,791.00');
      final second = LogisticsFuelCost.calculate(
        dieselLiters: 2.5,
        gasolineLiters: 0,
        dieselPrice: 26.35,
        gasolinePrice: null,
      );
      expect(second.knownCents, 6588);
      expect((first + second).label, r'$2,856.88');
      final missing = LogisticsFuelCost.calculate(
        dieselLiters: 100,
        gasolineLiters: 10,
        dieselPrice: 25.50,
        gasolinePrice: null,
      );
      expect(missing.isComplete, false);
      expect(missing.label, r'$2,550.00 (parcial)');
      expect(
        LogisticsFuelCost.calculate(
          dieselLiters: 100,
          gasolineLiters: 0,
          dieselPrice: null,
          gasolinePrice: null,
        ).label,
        'Pendiente de precio',
      );
      expect(
        LogisticsFuelCost.calculate(
          dieselLiters: 0,
          gasolineLiters: 0,
          dieselPrice: null,
          gasolinePrice: null,
        ).label,
        r'$0.00',
      );
    },
  );

  test('remote prices round-trip and absent inputs omit price keys', () {
    final record = LogisticsVehicleMileageRecord.fromRemoteRow({
      'entry_date': _date(1),
      'vehicle_label': 'T-01',
      'vehicle_key': 'T1',
      'kilometers': 300,
      'diesel_price_per_liter': '25.50',
      'gasoline_price_per_liter': 24.10,
    });
    expect(record.dieselPricePerLiter, 25.5);
    expect(record.toUpsertJson()['gasoline_price_per_liter'], 24.1);
    final legacy = LogisticsVehicleMileageRecord.fromRemoteRow({
      'entry_date': _date(1),
    });
    expect(legacy.dieselPricePerLiter, isNull);
    expect(legacy.toUpsertJson().containsKey('diesel_price_per_liter'), false);
    expect(
      legacy.toUpsertJson().containsKey('gasoline_price_per_liter'),
      false,
    );
  });

  test(
    'mileage totals read every page, including prices beyond 1000 rows',
    () async {
      tables['logistics_vehicle_mileage'] = List.generate(
        1001,
        (i) => {
          'entry_date': _date(1),
          'vehicle_label': 'T-$i',
          'vehicle_key': 'T$i',
          'kilometers': 300,
          'diesel_price_per_liter': 25.50,
        },
      );
      final rows = await LogisticsVehicleMileageStore.loadEntries();
      expect(rows.length, 1001);
      expect(rows.last.dieselPricePerLiter, 25.5);
    },
  );

  testWidgets(
    'XLSX import captures separate prices, shows amount and preserves blank price on reimport',
    (tester) async {
      tables['logistics_gasoline_control'] = [
        {
          'entry_date': _date(1),
          'vehicle_id': 'v1',
          'vehicle_label': 'T-01',
          'liters_loaded': 10,
        },
      ];
      await _openPage(tester);
      await _openImport(tester);
      final fields = find.byType(TextFormField);
      final focused = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(focused.focusNode.hasFocus, true);
      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Captura al menos un precio de combustible.'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(0), '-1');
      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Captura un precio mayor a 0 con hasta 2 decimales.'),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      await tester.enterText(fields.at(0), '25,50');
      await tester.enterText(fields.at(1), '24.10');
      await tester.pumpAndSettle();
      await _screenshot(tester, 'fuel-price-dialog');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes.single['diesel_price_per_liter'], 25.5);
      expect(writes.single['gasoline_price_per_liter'], 24.1);
      expect(find.text(r'$2,791.00'), findsNWidgets(2));
      expect(find.text(r'$25.50'), findsOneWidget);
      expect(find.text(r'$24.10'), findsOneWidget);
      // 400 L tank and 5000 L diesel purchase must not affect charged volume.
      expect(find.text('400 L'), findsOneWidget);
      expect(find.text('2.73 km/L'), findsWidgets);
      expect(tester.takeException(), isNull);
      await _screenshot(tester, 'fuel-performance');
      await _openImport(tester);
      await tester.enterText(fields.first, '26');
      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();
      expect(tables['logistics_vehicle_mileage'], hasLength(1));
      expect(writes.last.containsKey('gasoline_price_per_liter'), false);
      expect(
        tables['logistics_vehicle_mileage']!.single['gasoline_price_per_liter'],
        24.1,
      );
      expect(find.text(r'$2,841.00'), findsNWidgets(2));
      // Cancel leaves the successful import intact.
      await _openImport(tester);
      await tester.enterText(fields.first, '99');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(writes, hasLength(2));
      expect(find.text('Precios de combustible'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(home: LogisticsPerformancePage()),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$2,841.00'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('legacy rows remain pending and mixed rows show partial totals', (
    tester,
  ) async {
    tables['logistics_vehicle_mileage'] = [
      {
        'entry_date': _date(1),
        'vehicle_label': 'T-01',
        'vehicle_key': 'T1',
        'vehicle_id': 'v1',
        'kilometers': 300,
      },
    ];
    await _openPage(tester, width: 1100);
    expect(find.text('Pendiente de precio'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await _openImport(tester);
    await tester.enterText(find.byType(TextFormField).first, '25.50');
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text(r'$2,550.00'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    tables['logistics_gasoline_control'] = [
      {
        'entry_date': _date(1),
        'vehicle_id': 'v1',
        'vehicle_label': 'T-01',
        'liters_loaded': 10,
      },
    ];
    await tester.pumpWidget(
      const MaterialApp(home: LogisticsPerformancePage()),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$2,550.00 (parcial)'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PDF totals use each day price, and honor unit filters', (
    tester,
  ) async {
    tables['vehicles']!.add({'id': 'v2', 'code': 'T-02'});
    tables['logistics_vehicle_mileage'] = [
      {
        'entry_date': _date(1),
        'vehicle_label': 'T-01',
        'vehicle_key': 'T1',
        'vehicle_id': 'v1',
        'kilometers': 300,
        'diesel_price_per_liter': 25.50,
      },
      {
        'entry_date': _date(2),
        'vehicle_label': 'T-01',
        'vehicle_key': 'T1',
        'vehicle_id': 'v1',
        'kilometers': 300,
        'diesel_price_per_liter': 26.50,
      },
      {
        'entry_date': _date(2),
        'vehicle_label': 'T-02',
        'vehicle_key': 'T2',
        'vehicle_id': 'v2',
        'kilometers': 200,
        'gasoline_price_per_liter': 24.10,
      },
    ];
    tables['logistics_diesel_consumption']!.add({
      'entry_date': _date(2),
      'vehicle_id': 'v1',
      'vehicle_label': 'T-01',
      'liters_requested': 100,
    });
    tables['logistics_gasoline_control'] = [
      {
        'entry_date': _date(2),
        'vehicle_id': 'v2',
        'vehicle_label': 'T-02',
        'liters_loaded': 10,
      },
    ];
    await _openPage(tester);
    expect(find.text(r'$5,441.00'), findsOneWidget);
    await tester.tap(find.text('Todas las unidades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T-01').last);
    await tester.pumpAndSettle();
    expect(find.text(r'$5,200.00'), findsOneWidget);
    expect(find.text('T-02'), findsNothing);
    final dir = Platform.environment['DICSA_LOGISTICS_QA_DIR'];
    if (dir != null) {
      picker.savePath = '$dir/fuel-report.pdf';
      await tester.runAsync(() async {
        final file = File(picker.savePath!);
        if (await file.exists()) await file.delete();
      });
      await tester.tap(find.text('Generar reporte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mensual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar PDF'));
      await tester.pumpAndSettle();
      var saved = false;
      for (var i = 0; i < 100 && !saved; i++) {
        saved =
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              final file = File(picker.savePath!);
              return await file.exists() && await file.length() > 500;
            }) ??
            false;
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(saved, true);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

String _date(int day) =>
    '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

Future<void> _openPage(WidgetTester tester, {double width = 1440}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: LogisticsPerformancePage()));
  await tester.pumpAndSettle();
}

Future<void> _openImport(WidgetTester tester) async {
  await tester.tap(find.text('Importar kilometraje'));
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(DatePickerDialog));
  await tester.tap(find.text(MaterialLocalizations.of(context).okButtonLabel));
  await tester.pumpAndSettle();
  expect(find.text('Precios de combustible'), findsOneWidget);
}

Future<void> _screenshot(WidgetTester tester, String name) async {
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

class _FuelImportPicker extends FilePicker {
  late Uint8List bytes;
  String? savePath;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'viajes.xlsx', size: bytes.length, bytes: bytes),
  ]);

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => savePath;
}

Uint8List _mileageWorkbook() {
  const main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  final files = {
    'xl/workbook.xml':
        '<workbook xmlns="$main" xmlns:r="$rel"><sheets><sheet name="VIAJES" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml" Type="$rel/worksheet"/></Relationships>',
    'xl/sharedStrings.xml':
        '<sst xmlns="$main"><si><t>Unidad</t></si><si><t>T-01</t></si><si><t>Día 1</t></si></sst>',
    'xl/worksheets/sheet1.xml':
        '<worksheet xmlns="$main"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c></row><row r="2"><c r="A2" t="s"><v>1</v></c></row><row r="3"><c r="A3" t="s"><v>2</v></c><c r="B3"><v>300</v></c></row></sheetData></worksheet>',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
