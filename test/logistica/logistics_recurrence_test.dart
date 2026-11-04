import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/services/services_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_fixed_services_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <http.Request>[];
  late Map<String, dynamic> template;
  late Map<String, dynamic> visit;
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final today = DateUtils.dateOnly(DateTime.now());
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final (family, asset) in [
      ('Roboto', 'assets/fonts/Roboto-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    await Supabase.initialize(
      url: 'https://recurrence-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        calls.add(request);
        final endpoint = request.url.pathSegments.last;
        dynamic body;
        if (endpoint == 'sync_logistics_recurring_services') {
          body = {'inserted': 0};
        } else if (endpoint == 'change_logistics_recurrence_from_visit') {
          visit.addAll(
            Map<String, dynamic>.from(
              (jsonDecode(request.body) as Map)['p_patch'] as Map,
            ),
          );
          body = null;
        } else if (endpoint == 'save_logistics_recurrence') {
          final payload = jsonDecode(request.body) as Map;
          template = {
            ...template,
            ...Map<String, dynamic>.from(payload['p_record'] as Map),
            'effective_from': payload['p_from'],
          };
          body = template;
        } else {
          body = switch (endpoint) {
            'services' => [visit],
            'sites' => [
              {'id': 'c1', 'name': 'MALHE', 'type': 'cliente'},
            ],
            'employees' => [
              {'id': 'd1', 'full_name': 'CHOFER UNO'},
            ],
            'vehicles' => [
              {'id': 'v1', 'code': 'C1', 'status': 'activo'},
            ],
            'logistics_fixed_services' => [template],
            _ => [],
          };
        }
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
  setUp(() {
    calls.clear();
    template = {
      'id': 'f1',
      'site_id': 'c1',
      'site_name': 'MALHE',
      'material_name': 'SIN_MATERIAL',
      'movement': 'recoleccion',
      'scheduled_time': null,
      'weekdays': [1, 3, 5],
      'default_vehicle_id': 'v1',
      'default_driver_employee_id': null,
      'is_active': true,
      'visits_per_day': 1,
      'effective_from': date(today),
    };
    visit = {
      'id': 's1',
      'service_date': date(today.add(const Duration(days: 1))),
      'due_date': date(today.add(const Duration(days: 1))),
      'scheduled_time': null,
      'status': 'programado',
      'planning_kind': 'FIJO',
      'fixed_service_id': 'f1',
      'client_id': 'c1',
      'client_name': 'MALHE',
      'material_type': 'SIN_MATERIAL',
      'vehicle_id': 'v1',
      'driver_employee_id': 'd1',
      'direction': 'recoleccion',
      'area': 'LOGISTICA',
      'notes': 'ORIGINAL',
      'created_at': today.toIso8601String(),
      'recurrence_date': date(today.add(const Duration(days: 1))),
      'recurrence_visit': 1,
      'recurrence_exception': false,
      'recurrence_auto_cancelled': false,
    };
  });
  Future<void> capture(WidgetTester tester, String name) async {
    final folder = Platform.environment['DICSA_RECURRENCE_QA_DIR'];
    if (folder == null) return;
    await tester.runAsync(() async {
      await Directory(folder).create(recursive: true);
      final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
      final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'automatically loads week, groups resources and saves optional fields with daily quantity',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // HTTP/RPC are mocked; realtime delivery is outside this UI test.
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
      await tester.pumpAndSettle();
      expect(
        calls.where(
          (r) => r.url.path.endsWith('sync_logistics_recurring_services'),
        ),
        hasLength(1),
      );
      await tester.tap(find.text('Programación semanal').first);
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.textContaining('CHOFER UNO'), findsWidgets);
      expect(tester.takeException(), isNull);
      await capture(tester, 'week');
      await tester.tap(find.text('Repeticiones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar repetición'));
      await tester.pumpAndSettle();
      expect(find.text('Material pendiente'), findsOneWidget);
      expect(find.text('Sin horario fijo'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      await capture(tester, 'editor');
      await tester.ensureVisible(find.text('Guardar programación'));
      await tester.tap(find.text('Guardar programación'));
      await tester.pumpAndSettle();
      final save = calls.lastWhere(
        (r) => r.url.path.endsWith('save_logistics_recurrence'),
      );
      final payload = jsonDecode(save.body) as Map;
      expect(payload['p_record']['visits_per_day'], 3);
      expect(payload['p_record']['material_id'], isNull);
      expect(payload['p_record']['scheduled_time'], isNull);
      expect(payload['p_from'], date(today));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cerrar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ORIGINAL'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDITAR'));
      await tester.pumpAndSettle();
      final notes = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'ORIGINAL',
      );
      expect(notes, findsOneWidget);
      await tester.enterText(notes, 'CAMBIO SEMANAL');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Solo este servicio'), findsOneWidget);
      expect(find.text('Este y los siguientes'), findsOneWidget);
      await tester.tap(find.text('Este y los siguientes'));
      await tester.pumpAndSettle();
      final following = calls.lastWhere(
        (r) => r.url.path.endsWith('change_logistics_recurrence_from_visit'),
      );
      expect((jsonDecode(following.body) as Map)['p_patch'], {
        'notes': 'CAMBIO SEMANAL',
      });
      expect(tester.takeException(), isNull);
      Supabase.instance.client.realtime.connState = SocketStates.disconnected;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  test(
    'suggestions count distinct dates, preserve configured quantity and require three observed weeks',
    () {
      final rows = <Map<String, dynamic>>[];
      for (final d in [
        '2026-10-05',
        '2026-10-12',
        '2026-10-19',
        '2026-10-06',
      ]) {
        for (var i = 0; i < 15; i++) {
          rows.add({
            'client_id': 'c1',
            'client_name': 'MALHE',
            'direction': 'recoleccion',
            'service_date': d,
            'area': 'LOGISTICA',
            'status': 'completado',
          });
        }
      }
      final suggested = logisticsRecurrenceSuggestions(
        rows,
        [],
        DateTime(2026, 10),
      );
      expect(suggested, hasLength(1));
      expect(suggested.single.weekdays, [1]);
      expect(suggested.single.visitsPerDay, 1);
      expect(suggested.single.materialId, isNull);
      expect(suggested.single.scheduledTime, '');
      expect(
        logisticsRecurrenceSuggestions(rows, [], DateTime(2026, 9)),
        isEmpty,
      );
      expect(
        logisticsRecurrenceSuggestions(rows, [
          suggested.single,
        ], DateTime(2026, 10)),
        isEmpty,
      );
    },
  );
}
