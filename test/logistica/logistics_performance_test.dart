import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/logistica/logistics_performance_data.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_diesel_page.dart';
import 'package:dicsa_operacion/app/gerencia/gerencia_operational_viewer_side_menu.dart';
import 'package:dicsa_operacion/app/maintenance/maintenance_page.dart';
import 'package:dicsa_operacion/app/services/services_shell.dart';
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
  final requests = <Uri>[];
  final today = DateUtils.dateOnly(DateTime.now());
  final periodStart = today.subtract(const Duration(days: 7));
  String date(int day) =>
      periodStart.add(Duration(days: day)).toIso8601String().substring(0, 10);
  Map<String, dynamic> reading(
    int day,
    double km, {
    String unit = 'v1',
    double? price = 25,
  }) => {
    'id': 'm$day$unit',
    'entry_date': date(day),
    'vehicle_id': unit,
    'vehicle_label': unit == 'v1' ? 'T-01' : 'C-02',
    'vehicle_key': unit == 'v1' ? 'T1' : 'C2',
    'kilometers': km,
    'diesel_price_per_liter': price,
    'source_file_name': 'Lecturas.xlsx',
  };
  Map<String, dynamic> service(
    String id,
    int day, {
    String status = 'completado',
    String unit = 'v1',
  }) => {
    'id': id,
    'area': 'LOGISTICA',
    'status': status,
    'service_date': date(day),
    'due_date': date(day),
    'vehicle_id': unit,
    'client_id': 'c1',
    'driver_employee_id': 'e1',
    'direction': 'recoleccion',
  };

  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    final fonts = Platform.environment['DICSA_LOGISTICS_QA_FONTS'];
    if (fonts != null) {
      for (final (name, file) in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(name)..addFont(
              File('$fonts/$file').readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://performance-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        requests.add(r.url);
        final table = r.url.pathSegments.last;
        final p = r.url.queryParameters;
        final source = tables[table] ?? [];
        var rows = source
            .where(
              (row) => p.entries.every(
                (e) =>
                    !e.value.startsWith('eq.') ||
                    row[e.key].toString() == e.value.substring(3),
              ),
            )
            .toList();
        if (r.method == 'PATCH') {
          expectSync(
            table,
            anyOf('logistics_vehicle_mileage', 'logistics_gps_daily_mileage'),
          );
          final patch = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          writes.add(patch);
          for (final row in rows) {
            row.addAll(patch);
          }
        } else {
          expectSync(r.method, 'GET');
        }
        rows = rows
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
    tables.clear();
    writes.clear();
    requests.clear();
    tables['vehicles'] = [
      {'id': 'v1', 'code': 'T-01', 'status': 'activo'},
      {'id': 'v2', 'code': 'C-02', 'status': 'activo'},
    ];
    tables['employees'] = [
      {
        'id': 'e1',
        'full_name': 'CHOFER HISTÓRICO',
        'is_active': false,
        'is_driver': true,
      },
    ];
    tables['sites'] = [
      {'id': 'c1', 'name': 'EMPRESA UNO'},
    ];
    tables['logistics_vehicle_profiles'] = [
      {'vehicle_id': 'v1', 'tank_capacity_liters': 400},
    ];
    tables['logistics_vehicle_mileage'] = [
      reading(0, 0),
      reading(1, 300),
      reading(2, 200),
    ];
    tables['logistics_diesel_consumption'] = [
      {
        'id': 'purchase',
        'entry_date': date(0),
        'liters_purchased': 5000,
        'liters_requested': 0,
      },
      {
        'id': 'load1',
        'entry_date': date(0),
        'vehicle_id': 'v1',
        'vehicle_label': 'T-01',
        'liters_requested': 100,
        'operator_employee_id': 'e1',
      },
    ];
    tables['services'] = [
      service('s1', 1),
      service('s2', 2),
      service('planned', 2, status: 'programado'),
      service('cancelled', 2, status: 'cancelado'),
    ];
  });

  test(
    'period combines driving on days without fuel, only completed services, historical driver',
    () async {
      final days = await LogisticsPerformanceData.load();
      final unit = groupPerformanceUnits(days).single;
      expect(unit.kilometers, 500);
      expect(unit.fuel.total, 100);
      expect(unit.performance, 5);
      expect(unit.trips, 2);
      expect(unit.cost.knownCents, 250000);
      expect(unit.warnings, isEmpty);
      expect(unit.days.first.services.single.driver, 'CHOFER HISTÓRICO');
      expect(unit.destinations, {'EMPRESA UNO'});
      expect(writes, isEmpty);
    },
  );

  test(
    'missing km retain every delivery and show a partial reference without claiming a complete ratio or cost',
    () async {
      tables['logistics_diesel_consumption']!.add({
        'id': 'orphan',
        'entry_date': date(3),
        'vehicle_id': 'v1',
        'vehicle_label': 'T-01',
        'liters_requested': 50,
      });
      tables['services']!.add(service('other', 1, unit: 'v2'));
      final units = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      );
      expect(units.map((u) => u.vehicleLabel), ['C-02', 'T-01']);
      final t = units.last;
      expect(t.fuel.total, 150);
      expect(t.kilometerLabel, '500.0 km (parcial)');
      expect(t.performance, isNull);
      expect(t.recordedPerformance, closeTo(500 / 150, .000001));
      expect(t.hasPartialPerformance, isTrue);
      expect(t.performanceLabel, '3.33 km/L (parcial)');
      expect(t.mileageCoverageLabel, '3 días con km · 1 sin km');
      expect(t.days.first.mileage, isNull);
      expect(t.cost.label, r'$2,500.00 (parcial)');
      expect(
        t.warnings,
        containsAll(['Falta kilometraje (1 día)', 'Falta precio']),
      );
      expect(units.first.mileageDays, 0);
      expect(units.first.performanceLabel, 'Sin estimación');
      expect(units.first.trips, 1);
      expect(units.first.warnings, contains('Sin carga registrada'));
    },
  );

  test(
    'zero is a reading, mixed fuels are not compared, aliases match by ID',
    () async {
      tables['logistics_vehicle_mileage'] = [reading(0, 0)];
      tables['services'] = [];
      final zero = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(zero.performance, 0);
      expect(zero.hasPartialPerformance, isFalse);
      expect(zero.performanceLabel, '0.00 km/L');
      expect(zero.missingMileageDays, 0);
      tables['logistics_gasoline_control'] = [
        {
          'entry_date': date(0),
          'vehicle_id': 'v1',
          'vehicle_label': 'OLD ALIAS',
          'liters_loaded': 20,
        },
      ];
      final mixed = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(mixed.fuel.total, 120);
      expect(mixed.performance, isNull);
      expect(mixed.recordedPerformance, isNull);
      expect(mixed.hasPartialPerformance, isFalse);
      expect(mixed.performanceLabel, 'Sin estimación');
      expect(mixed.warnings, contains('Combustibles mezclados'));
    },
  );

  test(
    'pagination includes completed services beyond 1000 and no writes on load',
    () async {
      tables['services'] = List.generate(1002, (i) => service('s$i', 1));
      final units = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      );
      expect(units.single.trips, 1002);
      expect(
        requests.any(
          (u) =>
              u.path.endsWith('/services') &&
              u.queryParameters['offset'] == '1000',
        ),
        true,
      );
      expect(writes, isEmpty);
    },
  );

  test(
    'price-only correction preserves mileage and other fuel price; missing reading is not inserted',
    () async {
      final row = tables['logistics_vehicle_mileage']!.first;
      row['gasoline_price_per_liter'] = 24;
      final record = LogisticsVehicleMileageRecord.fromRemoteRow(row);
      await LogisticsVehicleMileageStore.updatePrices(record, diesel: 26);
      expect(row['kilometers'], 0);
      expect(row['gasoline_price_per_liter'], 24);
      expect(writes.single, {'diesel_price_per_liter': 26});
      tables['logistics_vehicle_mileage']!.clear();
      await expectLater(
        LogisticsVehicleMileageStore.updatePrices(record, diesel: 27),
        throwsStateError,
      );
      expect(tables['logistics_vehicle_mileage'], isEmpty);
    },
  );

  Map<String, dynamic> gpsReading(
    int day,
    double? km, {
    String status = 'ok',
  }) => {
    'entry_date': date(day),
    'vehicle_id': 'v1',
    'vehicle_label': 'OLD GPS LABEL',
    'status': status,
    'kilometers': km,
    'diesel_price_per_liter': 26,
  };

  test(
    'EPCOM fills missing daily km, never adds to imported mileage and routes price edits to its source',
    () async {
      tables['logistics_vehicle_mileage']!.removeLast();
      tables['logistics_gps_daily_mileage'] = [
        gpsReading(1, 999),
        gpsReading(2, 250),
      ];
      var unit = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(unit.kilometers, 550);
      expect(unit.performance, 5.5);
      final automatic = unit.days.first;
      expect(automatic.mileage!.fromEpcom, true);
      expect(automatic.mileageSourceLabel, 'EPCOM · recorridos del día');
      expect(unit.days[1].mileage!.fromEpcom, false);
      expect(unit.days[1].mileageSourceLabel, 'Lecturas.xlsx');
      await LogisticsVehicleMileageStore.updatePrices(
        automatic.mileage!,
        diesel: 28,
      );
      expect(requests.last.path, endsWith('/logistics_gps_daily_mileage'));
      expect(requests.last.queryParameters['vehicle_id'], 'eq.v1');
      expect(writes.single, {'diesel_price_per_liter': 28.0});
      unit = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(unit.days.first.dieselPrice, 28);
      expect(
        tables['logistics_vehicle_mileage']![1]['diesel_price_per_liter'],
        25,
      );
    },
  );

  test(
    'GPS gaps and access failures keep partial labels and source warnings; measured zero completes the period',
    () async {
      tables['logistics_vehicle_mileage']!.removeLast();
      tables['logistics_gps_daily_mileage'] = [
        gpsReading(2, null, status: 'no_data'),
      ];
      var unit = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(unit.performance, isNull);
      expect(unit.performanceLabel, '3.00 km/L (parcial)');
      expect(unit.warnings, contains('Hay días sin mensajes GPS'));
      tables['logistics_gps_daily_mileage'] = [
        {...gpsReading(2, 250, status: 'error'), 'error_code': 'authorization'},
      ];
      unit = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(unit.kilometers, 300);
      expect(unit.performance, isNull);
      expect(unit.performanceLabel, '3.00 km/L (parcial)');
      expect(unit.warnings, contains('Falta autorizar historial EPCOM'));
      tables['logistics_gps_daily_mileage'] = [gpsReading(2, 0)];
      unit = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(unit.performance, 3);
      expect(unit.performanceLabel, '3.00 km/L');
      expect(unit.hasPartialPerformance, isFalse);
      tables['logistics_gps_daily_mileage']!.add({
        ...gpsReading(3, 999),
        'vehicle_id': 'deleted-vehicle',
        'vehicle_label': 'T-01',
      });
      unit = groupPerformanceUnits(
        await LogisticsPerformanceData.load(),
      ).single;
      expect(
        unit.kilometers,
        300,
        reason: 'GPS must never fuzzy-link a missing vehicle',
      );
    },
  );

  Future<void> open(
    WidgetTester tester, {
    double width = 1440,
    bool viewerMode = false,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: LogisticsPerformancePage(viewerMode: viewerMode),
      ),
    );
    await tester.pumpAndSettle();
  }

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
    'Gerencia can consult performance without editing or leaving its viewer routes',
    (tester) async {
      tables['logistics_vehicle_mileage']!.removeAt(0);
      await open(tester, viewerMode: true);
      expect(
        find.text('Rendimiento de Unidades · Solo consulta'),
        findsOneWidget,
      );
      expect(find.text('Importar kilometraje'), findsNothing);
      expect(find.text('Precios de combustible'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Descargar PDF'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is FilledButton,
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Últimos 7 días'));
      await tester.pumpAndSettle();
      expect(find.text('5.00 km/L (parcial)'), findsOneWidget);
      await screenshot(tester, 'gerencia-performance');
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      expect(find.text('Cargas registradas'), findsOneWidget);
      expect(find.text('Importar kilometraje faltante'), findsNothing);
      expect(find.text('Capturar precio'), findsNothing);
      expect(find.text('Editar precios'), findsNothing);
      expect(find.text('Revisar cargas'), findsNothing);
      expect(find.byTooltip('Abrir carga'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desde última carga'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      expect(find.text('T-01 · Desde última carga'), findsOneWidget);
      expect(find.text('Abrir carga'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar detalle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      final menu = tester.widget<GerenciaOperationalViewerSideMenu>(
        find.byType(GerenciaOperationalViewerSideMenu),
      );
      expect(
        menu.currentDestination,
        GerenciaOperationalViewerMenuDestination.logisticsPerformance,
      );
      expect(menu.onGoToGerenciaDashboard, isNotNull);
      expect(find.text('Dashboard Gerencia'), findsOneWidget);
      expect(find.text('GPS'), findsNothing);
      await screenshot(tester, 'gerencia-performance-menu');
      await tester.tap(find.text('Ordenes de trabajo'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaintenancePage>(find.byType(MaintenancePage)).viewerMode,
        isTrue,
      );
      final shell = tester.widget<ServicesShell>(find.byType(ServicesShell));
      final maintenanceMenu =
          shell.customSideMenuBuilder!(
                tester.element(find.byType(ServicesShell)),
                () {},
              )
              as GerenciaOperationalViewerSideMenu;
      maintenanceMenu.onGoToLogisticsPerformance!();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LogisticsPerformancePage>(
              find.byType(LogisticsPerformancePage),
            )
            .viewerMode,
        isTrue,
      );
      expect(find.text('Importar kilometraje'), findsNothing);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'default and load followup use 30 days while short cuts explain partial-load distortion',
    (tester) async {
      tables['services'] = [];
      tables['logistics_vehicle_mileage'] = [
        reading(-2, 2171.255),
        reading(5, 518.137),
      ];
      tables['logistics_diesel_consumption'] = [
        {
          'id': 'earlier-load',
          'entry_date': date(-2),
          'vehicle_id': 'v1',
          'vehicle_label': 'T-01',
          'liters_requested': 750.94,
        },
        {
          'id': 'recent-load',
          'entry_date': date(5),
          'vehicle_id': 'v1',
          'vehicle_label': 'T-01',
          'liters_requested': 55.44,
        },
      ];
      await open(tester, width: 1100);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Últimos 30 días'),
            )
            .selected,
        isTrue,
      );
      expect(find.text('3.34 km/L'), findsOneWidget);
      expect(find.text('9.35 km/L'), findsNothing);
      expect(find.textContaining('no consumo medido'), findsOneWidget);
      await tester.tap(find.text('Desde última carga'));
      await tester.pumpAndSettle();
      expect(find.text('3.34 km/L'), findsOneWidget);
      expect(find.text('KM/L CARGADO · 30 DÍAS'), findsOneWidget);
      await tester.tap(find.text('Últimos 7 días'));
      await tester.pumpAndSettle();
      expect(find.text('9.35 km/L'), findsOneWidget);
      expect(find.textContaining('cargas fuera del corte'), findsOneWidget);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'date-only loads stay usable without time capture in the followup',
    (tester) async {
      tables['logistics_diesel_consumption']!.add({
        'id': 'today-load',
        'entry_date': today.toIso8601String().substring(0, 10),
        'vehicle_id': 'v1',
        'vehicle_label': 'T-01',
        'liters_requested': 150,
        'operator_employee_id': 'e1',
      });
      await open(tester, width: 1100);
      expect(find.text('5.00 km/L'), findsOneWidget);
      expect(find.textContaining('Corte común hasta'), findsOneWidget);
      await tester.tap(find.text('Desde última carga'));
      await tester.pumpAndSettle();
      expect(find.text('150.0 L'), findsOneWidget);
      expect(find.text('5.00 km/L'), findsOneWidget);
      expect(find.text('KM/L CARGADO · 30 DÍAS'), findsOneWidget);
      expect(find.text('PARA DECIDIR LA CARGA'), findsNothing);
      expect(find.textContaining('Hora pendiente'), findsNothing);
      expect(find.text('Falta hora de carga'), findsNothing);
      await screenshot(tester, 'load-followup');
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      expect(find.textContaining('anteriores y posteriores'), findsOneWidget);
      expect(find.textContaining('Seguimiento por fecha:'), findsOneWidget);
      expect(find.text('Capturar hora real'), findsNothing);
      expect(find.text('Corregir hora real'), findsNothing);
      expect(find.textContaining('Hora real pendiente'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('5.00 km/L'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Nivel disponible:'), findsNothing);
      expect(find.textContaining('Recorrido pendiente:'), findsNothing);
      expect(find.textContaining('referencias de combustible'), findsNothing);
      expect(find.text('Antes de autorizar'), findsNothing);
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Abrir carga'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Abrir carga'), findsNothing);
      expect(find.text('150.0 L'), findsOneWidget);
      expect(writes, isEmpty);
      expect(
        requests.any((r) => r.path.contains('set_logistics_fuel_load_time')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'EPCOM source and missing data remain clear through silent refresh',
    (tester) async {
      tables['logistics_vehicle_mileage']!.removeLast();
      tables['logistics_gps_daily_mileage'] = [
        gpsReading(2, null, status: 'pending'),
      ];
      await open(tester, width: 1100);
      expect(find.text('3.00 km/L (parcial)'), findsOneWidget);
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      expect(find.text('Kilometraje: EPCOM en preparación'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desde última carga'));
      await tester.pumpAndSettle();
      expect(find.text('3.00 km/L (parcial)'), findsOneWidget);
      expect(find.text('2 días con km · 1 sin km'), findsOneWidget);
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('no confirma un rendimiento bajo'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNothing);
      await screenshot(tester, 'partial-fuel-reference');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      tables['logistics_gps_daily_mileage'] = [gpsReading(2, 250)];
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('5.50 km/L'), findsOneWidget);
      expect(find.text('3.00 km/L (parcial)'), findsNothing);
      expect(find.text('2 días con km · 1 sin km'), findsNothing);
      await tester.tap(find.text('Últimos 30 días'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('250.0 km ·'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kilometraje: EPCOM · recorridos del día'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'epcom-mileage-detail');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('estimated fuel is visible in summary and original diesel row', (
    tester,
  ) async {
    tables['logistics_diesel_consumption']!.last['source_metadata'] = {
      'total_amount': '2700.00',
      'estimated_liters': '100.00',
      'reference_price': '27.00',
    };
    await open(tester);
    expect(find.textContaining('Incluye litros estimados'), findsWidgets);
    await screenshot(tester, 'estimated-fuel-summary');
    await tester.pumpWidget(
      MaterialApp(
        home: LogisticsDieselPage(
          initialDateRange: DateTimeRange(start: periodStart, end: periodStart),
          initialVehicleId: 'v1',
          initialVehicleLabel: 'T-01',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('≈ 100.00 L'), findsOneWidget);
    expect(
      find.byTooltip(
        'Litros estimados: \$2700.00 ÷ \$27.00/L. Precio de referencia de Celaya; no es el precio comprobado del ticket.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'estimated-diesel-row');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'weekly summary, detail, correction, source link and silent refresh keep period filter',
    (tester) async {
      tables['logistics_vehicle_mileage']!.first['diesel_price_per_liter'] =
          null;
      tables['logistics_vehicle_mileage']!.add(reading(3, 100, unit: 'v2'));
      await open(tester);
      await tester.tap(find.text('Últimos 7 días'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Últimos 7 días'),
            )
            .selected,
        true,
      );
      expect(find.text('Actualizar'), findsNothing);
      expect(find.text('TANQUE (L)'), findsNothing);
      expect(find.text('5.00 km/L'), findsOneWidget);
      expect(find.text('Pendiente de precio'), findsNWidgets(2));
      expect(tester.takeException(), isNull, reason: 'summary');
      await screenshot(tester, 'weekly-summary');
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tanque: 400 L'), findsOneWidget);
      await tester.tap(find.text('Capturar precio'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '26.50');
      await tester.tap(find.text('Guardar precios'));
      await tester.pumpAndSettle();
      expect(find.text(r'$2,650.00'), findsWidgets);
      expect(writes.single, {'diesel_price_per_liter': 26.5});
      await tester.tap(
        find.text(
          date(1)
              .split('-')
              .reversed
              .toList()
              .asMap()
              .entries
              .map((e) => e.key == 2 ? e.value.substring(2) : e.value)
              .join('/'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('EMPRESA UNO'), findsWidgets);
      expect(find.textContaining('CHOFER HISTÓRICO'), findsWidgets);
      expect(tester.takeException(), isNull, reason: 'detail');
      await screenshot(tester, 'unit-detail');
      await tester.tap(find.byTooltip('Abrir carga').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'source');
      final page = tester.widget<LogisticsDieselPage>(
        find.byType(LogisticsDieselPage),
      );
      expect(page.initialRecordId, 'load1');
      expect(page.initialVehicleId, 'v1');
      expect(page.initialDateRange!.start, periodStart);
      expect(find.text('Volver a Rendimiento'), findsOneWidget);
      await tester.tap(find.text('Volver a Rendimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas las unidades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T-01').last);
      await tester.pumpAndSettle();
      expect(find.text('C-02'), findsNothing);
      tables['logistics_vehicle_mileage']![1]['kilometers'] = 400;
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('6.00 km/L'), findsOneWidget);
      expect(find.text('C-02'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'incomplete units are visible in a compact window and month includes older activity',
    (tester) async {
      tables['logistics_vehicle_mileage']!.removeAt(0);
      tables['services']!.add(service('other', 1, unit: 'v2'));
      await open(tester, width: 1100);
      await tester.tap(find.text('Últimos 7 días'));
      await tester.pumpAndSettle();
      expect(find.text('500.0 km (parcial)'), findsWidgets);
      expect(find.text('Sin estimación'), findsOneWidget);
      expect(find.text('5.00 km/L (parcial)'), findsOneWidget);
      await screenshot(tester, 'missing-data');
      await tester.tap(find.text('T-01'));
      await tester.pumpAndSettle();
      expect(find.text('Importar kilometraje faltante'), findsOneWidget);
      expect(find.text('Capturar precio'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.textContaining('Detalle del periodo'), findsNothing);
      await tester.tap(find.text('Últimos 30 días'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Últimos 30 días'),
            )
            .selected,
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
