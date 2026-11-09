import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/logistica/logistics_routes_pdf.dart';
import 'package:dicsa_operacion/app/services/services_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

LogisticsRoutePrintData route(
  String id, {
  DateTime? date,
  int? minutes = 480,
  String? vehicleId = 'v1',
  String vehicle = 'T-02',
  String? driverId = 'd1',
  String driver = 'JOSÉ RAMÍREZ',
  String? company,
  String material = 'Cartón',
}) => LogisticsRoutePrintData(
  id: id,
  date: date ?? DateTime(2026, 11, 5),
  minutes: minutes,
  vehicleId: vehicleId,
  vehicle: vehicle,
  driverId: driverId,
  driver: driver,
  company: company ?? 'EMPRESA $id',
  movement: 'Recolección',
  material: material,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final qaDir = Platform.environment['DICSA_ROUTES_QA_DIR'];
  late Directory output;
  setUpAll(() async {
    output = qaDir == null
        ? await Directory.systemTemp.createTemp('routes-pdf-')
        : await Directory(qaDir).create(recursive: true);
  });
  tearDownAll(() async {
    if (qaDir == null) await output.delete(recursive: true);
  });

  test(
    'separates date and assignment IDs; sorts time and puts unscheduled last',
    () {
      final input = [
        route('later', date: DateTime(2026, 11, 6)),
        route('missing', minutes: null),
        route('late', minutes: 900),
        route('early', minutes: 420, date: DateTime(2026, 11, 5, 12)),
        route('same-label', vehicleId: 'v2'),
        route('other-driver', driverId: 'd2'),
        route('natural-order', vehicleId: 'v10', vehicle: 'T-10'),
        route(
          'pending',
          vehicleId: null,
          vehicle: '',
          driverId: null,
          driver: '',
        ),
      ];
      final agendas = groupLogisticsRouteAgendas(input);
      expect(agendas, hasLength(6));
      final main = agendas.singleWhere((a) => a.routes.length == 3);
      expect(main.routes.map((r) => r.id), ['early', 'late', 'missing']);
      expect(main.routes.map((r) => r.timeLabel), [
        '07:00',
        '15:00',
        'Sin horario',
      ]);
      expect(agendas.last.routes.single.id, 'later');
      expect(
        agendas.indexWhere((a) => a.vehicle == 'T-02'),
        lessThan(agendas.indexWhere((a) => a.vehicle == 'T-10')),
      );
      expect(
        agendas.singleWhere((a) => a.vehicle == 'Unidad pendiente').driver,
        'Chofer pendiente',
      );
      expect(input.first.id, 'later');
    },
  );

  test(
    'prints a day board, splits many routes and preserves long content',
    () async {
      final examples = [
        route('01', minutes: 420, company: 'MAHLE'),
        route('02', minutes: 660, company: 'WHIRLPOOL'),
        route('03', minutes: 840, company: 'AVON'),
        route('04', minutes: null, company: 'CENTRO DE ACOPIO'),
        route(
          '05',
          vehicleId: 'v2',
          vehicle: 'C-04',
          driverId: 'd2',
          driver: 'MIGUEL HERNÁNDEZ',
          company: 'BACHOCO',
          minutes: 480,
        ),
        route(
          '06',
          vehicleId: 'v2',
          vehicle: 'C-04',
          driverId: 'd2',
          driver: 'MIGUEL HERNÁNDEZ',
          company: 'PARQUE INDUSTRIAL CELAYA',
          minutes: 750,
        ),
        route(
          '07',
          vehicleId: 'v3',
          vehicle: 'T-08',
          driverId: 'd3',
          driver: 'ANA LÓPEZ',
          company: 'EMPRESA DEL BAJÍO',
          minutes: 540,
        ),
      ];
      final bytes = await buildLogisticsRoutesPdf(
        routes: examples,
        isTodayDispatch: false,
        generatedAt: DateTime(2026, 11, 4),
      );
      await File('${output.path}/calendario-ejemplo.pdf').writeAsBytes(bytes);
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)),
        hasLength(1),
      );
      final stress = [
        for (var i = 0; i < 47; i++)
          route(
            'RUTA${i.toString().padLeft(3, '0')}',
            minutes: i == 46 ? null : 360 + i * 15,
          ),
        route(
          'LONG',
          vehicleId: 'v2',
          driverId: 'd2',
          driver: 'MARÍA DE LOS ÁNGELES HERNÁNDEZ SÁNCHEZ',
          company:
              'INICIO_LARGO ${List.filled(250, 'EMPRESA CON NOMBRE EXTENSO').join(' ')} FIN_LARGO',
          material: 'INICIO_MATERIAL ${'X' * 900} FIN_MATERIAL',
        ),
        route('DAY2', date: DateTime(2026, 11, 6)),
        const LogisticsRoutePrintData(
          id: 'NO_DATE',
          date: null,
          minutes: null,
          vehicleId: null,
          vehicle: '',
          driverId: null,
          driver: '',
          company: 'SIN_FECHA_EMPRESA',
          movement: '',
          material: '',
        ),
      ];
      final stressBytes = await buildLogisticsRoutesPdf(
        routes: stress,
        isTodayDispatch: true,
        generatedAt: DateTime(2026, 11, 4),
      );
      await File(
        '${output.path}/calendario-extenso.pdf',
      ).writeAsBytes(stressBytes);
      expect(
        RegExp(
          r'/Type\s*/Page\b',
        ).allMatches(latin1.decode(stressBytes)).length,
        greaterThan(5),
      );
    },
  );

  group('print actions', () {
    final picker = _RoutesPicker();
    final today = DateUtils.dateOnly(DateTime.now());
    final requests = <http.Request>[];
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    Map<String, dynamic> service(
      String id,
      int day, {
      String status = 'programado',
    }) => {
      'id': id,
      'service_date': date(today),
      'due_date': date(today.add(Duration(days: day))),
      'scheduled_time': id == 'PLAN_42' ? null : '08:30:00',
      'status': status,
      'planning_kind': 'OCASIONAL',
      'client_id': 'c1',
      'client_name': 'EMPRESA_$id',
      'material_type': 'CARTÓN',
      'vehicle_id': 'v1',
      'driver_employee_id': 'd1',
      'direction': 'recoleccion',
      'area': 'LOGISTICA',
      'notes': 'INDICACION_INTERNA_NO_IMPRIMIR',
      'created_at': today.toIso8601String(),
    };
    setUpAll(() async {
      FilePicker.platform = picker;
      SharedPreferences.setMockInitialValues({});
      for (final (family, asset) in [
        ('Roboto', 'assets/fonts/Roboto-Regular.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
      await Supabase.initialize(
        url: 'https://routes-pdf-test.invalid',
        anonKey: 'test',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          final endpoint = request.url.pathSegments.last;
          final Object body = switch (endpoint) {
            'sync_logistics_recurring_services' => {'inserted': 0},
            'services' => [
              for (var i = 0; i < 43; i++)
                service('PLAN_${i.toString().padLeft(2, '0')}', 1),
              service('HOY', 0),
              service('AYER', -1),
              service('FUERA', 8),
              service('CANCELADO', 1, status: 'cancelado'),
              service('COMPLETADO', 0, status: 'completado'),
            ],
            'sites' => [
              {'id': 'c1', 'name': 'EMPRESA', 'type': 'cliente'},
            ],
            'employees' => [
              {'id': 'd1', 'full_name': 'JOSÉ RAMÍREZ'},
            ],
            'vehicles' => [
              {'id': 'v1', 'code': 'T-02', 'status': 'activo'},
            ],
            _ => [],
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
    });
    tearDownAll(() => Supabase.instance.dispose());

    testWidgets(
      'both actions save filtered PDFs, including routes beyond the visible page',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Supabase.instance.client.realtime.connState = SocketStates.open;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: const ServicesPage(
              logisticsSilverMode: true,
              showLogisticsPlanningTopContent: false,
            ),
          ),
        );
        // Large mocked responses are decoded by Supabase's real JSON isolate.
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (find.text('43 visibles').evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();
        expect(find.text('43 visibles'), findsOneWidget);

        Future<void> export(String label, String file) async {
          picker.path = '${output.path}/$file';
          await tester.tap(find.text(label));
          for (var i = 0; i < 250; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 20));
            if (find.textContaining('guardado:').evaluate().isNotEmpty) break;
          }
          await tester.pumpAndSettle();
          expect(find.textContaining('guardado:'), findsOneWidget);
          expect(
            await tester.runAsync(() => File('${picker.path}.pdf').length()),
            greaterThan(5000),
          );
          expect(tester.takeException(), isNull);
        }

        await export('Imprimir rutas', 'planeacion-filtrada');
        expect(picker.suggestedName, startsWith('planeacion_logistica_'));
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.byTooltip('Cambiar vista de planeación'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Despacho de hoy').last);
        await tester.pumpAndSettle();
        expect(find.text('1 visibles'), findsOneWidget);
        await export('Imprimir despacho', 'despacho-filtrado');
        expect(picker.suggestedName, startsWith('despacho_hoy_logistica_'));
        expect(
          requests.where(
            (r) => r.method != 'GET' && !r.url.path.contains('/rpc/'),
          ),
          isEmpty,
        );
        // Cancellation does not write a file or leave the action busy.
        await tester.pump(const Duration(seconds: 5));
        picker.path = null;
        await tester.tap(find.text('Imprimir despacho'));
        await tester.pumpAndSettle();
        expect(find.text('Guardado cancelado'), findsOneWidget);
        Supabase.instance.client.realtime.connState = SocketStates.disconnected;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}

class _RoutesPicker extends FilePicker {
  String? path;
  String? suggestedName;
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
    suggestedName = fileName;
    return path;
  }
}
