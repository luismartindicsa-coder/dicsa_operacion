import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_dashboard_page.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_theme.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_store.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_record_draft.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';
import 'documental_test_repository.dart';

Future<void> mount(
  WidgetTester tester,
  Size size, {
  DocumentalTestRepository? repository,
}) async {
  final store = repository ?? DocumentalTestRepository();
  addTearDown(store.events.close);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => DocumentalRepositoryScope(
        repository: store,
        child: RepaintBoundary(key: const ValueKey('capture'), child: child!),
      ),
      home: const GestionDocumentalDashboardPage(instantOpen: true),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> legalRequired(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('documental-picker-Responsable interno')),
  );
  await tester.pumpAndSettle();
  await tapText(tester, 'Responsable de prueba');
  await tapText(tester, 'Seguimiento');
  for (final item in [
    ('Estatus del proceso', 'Pendiente'),
    ('Prioridad', 'Media'),
  ]) {
    await tester.tap(find.byKey(ValueKey('documental-picker-${item.$1}')));
    await tester.pumpAndSettle();
    await tapText(tester, item.$2);
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['DOCUMENTAL_PREVIEW'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/documental_$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
    final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
    final font = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
    final icons = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://documental-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets(
    'live dashboard and calendar use server dates and open original records without interrupting edits',
    (tester) async {
      final store = DocumentalTestRepository()
        ..todayOverride = DateTime(2028, 2, 29);
      final today = store.today;
      Future<DocumentalDetail> seed(
        DocumentalRecordKind kind,
        String title, {
        DateTime? expires,
        String status = 'Pendiente',
      }) => store.save(
        DocumentalSaveOperation(
          DocumentalRecordDraft(kind: kind)
            ..title = title
            ..documentType = documentalTypesFor(kind).first
            ..responsibleId = '00000000-0000-4000-8000-000000000001'
            ..status = status
            ..priority = 'Media'
            ..progressPercentage = kind.tracksProgress ? 25 : null
            ..hasExpiration = expires != null
            ..expirationDate = expires,
        ),
      );
      final legal = await seed(
        DocumentalRecordKind.legal,
        'Escritura pendiente',
        expires: today,
      );
      await seed(
        DocumentalRecordKind.legal,
        'Expediente cerrado',
        expires: today.subtract(const Duration(days: 1)),
        status: 'Completado',
      );
      await seed(DocumentalRecordKind.procedures, 'Permiso pendiente');
      await seed(
        DocumentalRecordKind.procedures,
        'Permiso en proceso',
        status: 'En proceso',
      );
      final policy = await store.save(
        DocumentalSaveOperation(
          DocumentalRecordDraft(kind: DocumentalRecordKind.insurance)
            ..title = 'Póliza vigente'
            ..documentType = 'Póliza'
            ..authority = 'Aseguradora'
            ..insuredSubject = 'Instalación'
            ..responsibleId = '00000000-0000-4000-8000-000000000001'
            ..status = 'Pendiente'
            ..priority = 'Media'
            ..progressPercentage = 40
            ..startDate = DateTime(2028, 3, 1)
            ..hasExpiration = true
            ..expirationDate = DateTime(2028, 3, 15)
            ..renewalType = 'Por acuerdo'
            ..renewalDate = today,
        ),
      );
      final audit = await store.save(
        DocumentalSaveOperation(
          DocumentalRecordDraft(kind: DocumentalRecordKind.audits)
            ..title = 'Auditoría programada'
            ..documentType = 'Interna'
            ..authority = 'Auditor interno'
            ..responsibleId = '00000000-0000-4000-8000-000000000001'
            ..status = 'Pendiente'
            ..priority = 'Media'
            ..progressPercentage = 10
            ..scheduledDate = today
            ..performedDate = today,
        ),
      );
      await mount(tester, const Size(1440, 1000), repository: store);
      String metric(String key) =>
          tester.widget<Text>(find.byKey(ValueKey('metric-$key'))).data!;
      expect(metric('active'), '5');
      expect(metric('upcoming'), '2');
      expect(metric('critical'), '1');
      expect(metric('expired'), '0');
      expect(metric('pending_procedures'), '1');
      expect(metric('in_progress_procedures'), '1');
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('category-documentacion-legal-Registros'),
              ),
            )
            .data,
        '2',
      );
      await capture(tester, 'dashboard_live');
      final entry = find.byKey(
        ValueKey('event-${legal.record.id}-vencimiento'),
      );
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await capture(tester, 'dashboard_upcoming');
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tapText(tester, 'Editar expediente');
      await tester.enterText(
        find.byKey(const ValueKey('Nombre del documento')),
        'Escritura actualizada',
      );
      final loads = store.dashboardLoads;
      store.events.add(null);
      await tester.pumpAndSettle();
      expect(store.dashboardLoads, loads);
      expect(find.text('Escritura actualizada'), findsOneWidget);
      await tapText(tester, 'Seguimiento');
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Estatus del proceso')),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Completado');
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      expect(metric('active'), '4');
      expect(metric('critical'), '0');
      expect(metric('upcoming'), '1');
      final calendar = find.widgetWithText(OutlinedButton, 'Calendario');
      await tester.ensureVisible(calendar);
      await tester.pumpAndSettle();
      await tester.tap(calendar);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-day-total')))
            .data,
        '4 fechas',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('calendar-count-2028-02-29')),
            )
            .data,
        '4',
      );
      expect(
        find.byKey(ValueKey('event-${policy.record.id}-renovacion')),
        findsOneWidget,
      );
      await capture(tester, 'calendar_live');
      await tapText(tester, 'Todas las fechas');
      await tapText(tester, 'Programación');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-day-total')))
            .data,
        '1 fecha',
      );
      await tapText(tester, 'Todas las categorías');
      await tapText(tester, 'Auditorías');
      await tapText(tester, 'Responsable');
      await tapText(tester, 'Responsable de prueba');
      await tapText(tester, 'Estatus');
      await tapText(tester, 'Completado');
      expect(find.text('Sin fechas para este día'), findsOneWidget);
      await tapText(tester, 'Limpiar filtros');
      final day = find.byKey(const ValueKey('calendar-day-2028-02-29'));
      await tester.ensureVisible(day);
      await tester.pumpAndSettle();
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-day-total')))
            .data,
        '1 fecha',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('event-${policy.record.id}-inicio')),
        findsOneWidget,
      );
      await tapText(tester, 'Hoy');
      final scheduled = find.byKey(
        ValueKey('event-${audit.record.id}-programacion'),
      );
      await tester.ensureVisible(scheduled);
      await tester.pumpAndSettle();
      await tester.tap(scheduled);
      await tester.pumpAndSettle();
      await tapText(tester, 'Editar expediente');
      await tapText(tester, 'Programación y vigencia');
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Fecha programada')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final calendarLoads = store.calendarLoads;
      store.events.add(null);
      await tester.pumpAndSettle();
      expect(store.calendarLoads, calendarLoads);
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-day-total')))
            .data,
        '3 fechas',
      );
      expect(
        find.byKey(ValueKey('event-${audit.record.id}-programacion')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('event-${audit.record.id}-realizacion')),
        findsOneWidget,
      );
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Agenda del día'));
        await tester.pumpAndSettle();
        await capture(tester, 'calendar_live_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'calendar paginates a complete day and counts every document on the dashboard',
    (tester) async {
      final store = DocumentalTestRepository()
        ..todayOverride = DateTime(2028, 2, 29);
      for (var i = 0; i < 55; i++) {
        await store.save(
          DocumentalSaveOperation(
            DocumentalRecordDraft()
              ..title = 'Documento ${i.toString().padLeft(3, '0')}'
              ..documentType = 'Escritura'
              ..responsibleId = '00000000-0000-4000-8000-000000000001'
              ..status = 'Pendiente'
              ..priority = 'Media'
              ..hasExpiration = true
              ..expirationDate = store.today,
          ),
        );
      }
      await mount(tester, const Size(1440, 1000), repository: store);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('metric-active'))).data,
        '55',
      );
      expect(
        find.text(
          'Se muestran las primeras 12 fechas. Consulta el resto en el calendario.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Calendario');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('calendar-day-total')))
            .data,
        '55 fechas',
      );
      expect(find.text('Documento 000'), findsOneWidget);
      expect(find.text('Documento 054'), findsNothing);
      final next = find.byTooltip('Página siguiente');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Documento 054'), findsOneWidget);
      expect(find.text('Documento 000'), findsNothing);
      expect(find.text('51–55 de 55'), findsOneWidget);
      // A refresh that removes the last page returns to a valid page automatically.
      store.records.removeWhere(
        (id, detail) => int.parse(detail.record.title.split(' ').last) >= 50,
      );
      store.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('1–50 de 50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'overview distinguishes unavailable data from zero and refreshes on the server midnight',
    (tester) async {
      final store = DocumentalTestRepository()
        ..unavailable = true
        ..todayOverride = DateTime(2028, 2, 28)
        ..overviewMidnight = const Duration(seconds: 10);
      await mount(tester, const Size(1440, 1000), repository: store);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('metric-active'))).data,
        '—',
      );
      expect(find.text('Sin próximas fechas'), findsNothing);
      expect(
        find.text(
          'Gestión Documental aún no está habilitada en la base de datos.',
        ),
        findsOneWidget,
      );
      store.unavailable = false;
      store.events.add(null);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('metric-active'))).data,
        '0',
      );
      expect(find.text('Sin próximas fechas'), findsOneWidget);
      await store.save(
        DocumentalSaveOperation(
          DocumentalRecordDraft()
            ..title = 'Vence hoy'
            ..documentType = 'Escritura'
            ..responsibleId = '00000000-0000-4000-8000-000000000001'
            ..status = 'Pendiente'
            ..priority = 'Media'
            ..hasExpiration = true
            ..expirationDate = store.today,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('metric-critical'))).data,
        '1',
      );
      store.todayOverride = DateTime(2028, 2, 29);
      store.overviewMidnight = const Duration(days: 1);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('metric-expired'))).data,
        '1',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('metric-critical'))).data,
        '0',
      );
      await tapText(tester, 'Calendario');
      expect(find.text('Sin fechas para este día'), findsOneWidget);
      store.unavailable = true;
      store.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Sin fechas para este día'), findsNothing);
      expect(
        find.text(
          'Gestión Documental aún no está habilitada en la base de datos.',
        ),
        findsOneWidget,
      );
      store.unavailable = false;
      store.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Sin fechas para este día'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'audits preserve outcomes, findings, actions and evidence independently of status and scheduled dates',
    (tester) async {
      final store = DocumentalTestRepository();
      final picker = _LegalTestFilePicker();
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = _LegalTestFilePicker());
      await mount(tester, const Size(1440, 1000), repository: store);
      await tester.ensureVisible(find.text('Auditorías').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Auditorías');
      await tapText(tester, 'Nuevo');
      expect(find.text('Nueva auditoría'), findsOneWidget);
      Future<void> fill(String label, String value) async {
        final field = find.byKey(ValueKey(label));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      Future<void> pick(String label, String value) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tapText(tester, value);
      }

      Future<void> date(String label, int days) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        for (var i = 0; i < days.abs(); i++) {
          await tester.sendKeyEvent(
            days < 0
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      await fill('Nombre de la auditoría', 'Auditoría de procesos');
      await pick('Tipo de auditoría', 'Interna');
      await pick('Responsable interno', 'Responsable de prueba');
      await tapText(tester, 'Resultados y seguimiento');
      await pick('Estatus del proceso', 'Pendiente');
      await pick('Prioridad', 'Media');
      await fill('Avance (%)', '35');
      await tapText(tester, 'Vista previa');
      expect(find.text('Indica el organismo o auditor.'), findsOneWidget);
      await fill('Organismo / auditor', 'Organismo auditor');
      await fill('Folio / referencia', 'AUD-001');
      await tester.pumpAndSettle();
      await capture(tester, 'audit_capture');
      await tapText(tester, 'Programación y vigencia');
      await date('Fecha programada', 3);
      await date('Fecha realizada', -1);
      await date('Inicio de vigencia', -30);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await date('Fecha de vencimiento', 20);
      await capture(tester, 'audit_schedule');
      await tapText(tester, 'Resultados y seguimiento');
      await pick('Resultado', 'Con observaciones');
      await fill('Hallazgos', 'Falta evidencia de calibración');
      await fill('Acciones pendientes', 'Entregar plan correctivo');
      await fill('Observaciones', 'Revisión de equipos');
      await tester.pumpAndSettle();
      await capture(tester, 'audit_findings');
      await tapText(tester, 'Documentación');
      expect(
        find.text('Evidencia / documento final (principal)'),
        findsOneWidget,
      );
      picker.result = FilePickerResult([
        PlatformFile(name: 'informe-v1.pdf', size: 128),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await capture(tester, 'audit_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      var saved = store.records.values.single;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(saved.record.authority, 'Organismo auditor');
      expect(saved.record.auditResult, 'Con observaciones');
      expect(saved.record.auditFindings, 'Falta evidencia de calibración');
      expect(saved.record.data['next_action'], 'Entregar plan correctivo');
      expect(saved.record.data['observations'], 'Revisión de equipos');
      expect(saved.record.scheduledDate, today.add(const Duration(days: 3)));
      expect(
        saved.record.performedDate,
        today.subtract(const Duration(days: 1)),
      );
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(find.text('Resultado'), findsOneWidget);
      await capture(tester, 'audit_list');
      final search = find.byType(TextField).first;
      for (final value in [
        'Organismo auditor',
        'calibración',
        'plan correctivo',
        'AUD-001',
      ]) {
        await tester.enterText(search, value);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Auditoría de procesos'), findsOneWidget);
      }
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tapText(tester, 'Tipo');
      await tapText(tester, 'Externa');
      expect(find.text('Auditoría de procesos'), findsNothing);
      await tapText(tester, 'Externa');
      await tapText(tester, 'Interna');
      expect(find.text('Auditoría de procesos'), findsOneWidget);
      await tapText(tester, 'Más recientes');
      await tapText(tester, 'Fecha programada');
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Auditoría de procesos'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await fill('Avance (%)', '80');
      await pick('Resultado', 'Conforme');
      await fill('Hallazgos', 'Hallazgo atendido');
      await fill('Acciones pendientes', 'Archivar cierre');
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Datos generales');
      await fill('Organismo / auditor', 'Organismo actualizado');
      await tapText(tester, 'Programación y vigencia');
      await date('Fecha programada', 4);
      await date('Fecha realizada', 1);
      await tapText(tester, 'Documentación');
      picker.result = FilePickerResult([
        PlatformFile(name: 'informe-v2.pdf', size: 256),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.single;
      expect(saved.record.authority, 'Organismo actualizado');
      expect(saved.record.auditResult, 'Conforme');
      expect(saved.record.status, 'Pendiente');
      expect(saved.record.auditFindings, 'Hallazgo atendido');
      expect(saved.record.data['next_action'], 'Archivar cierre');
      expect(saved.record.scheduledDate, today.add(const Duration(days: 7)));
      expect(saved.record.performedDate, today);
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(saved.history.last.record.auditResult, 'Con observaciones');
      expect(
        saved.history.last.record.auditFindings,
        'Falta evidencia de calibración',
      );
      expect(
        saved.history.last.record.data['next_action'],
        'Entregar plan correctivo',
      );
      expect(
        saved.history.last.record.scheduledDate,
        today.add(const Duration(days: 3)),
      );
      expect(
        saved.files.where((f) => !f.current).single.name,
        'informe-v1.pdf',
      );
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      final oldFindings = find.descendant(
        of: history,
        matching: find.text('Falta evidencia de calibración'),
      );
      await tester.ensureVisible(oldFindings);
      await tester.pumpAndSettle();
      expect(oldFindings, findsOneWidget);
      await capture(tester, 'audit_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('80%'));
        await tester.pumpAndSettle();
        await capture(tester, 'audit_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'maintenance preserves scope, scheduling, periodicity and evidence independently of document validity',
    (tester) async {
      final store = DocumentalTestRepository();
      final picker = _LegalTestFilePicker();
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = _LegalTestFilePicker());
      await mount(tester, const Size(1440, 1000), repository: store);
      await tester.ensureVisible(find.text('Mantenimiento').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Mantenimiento');
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo registro de mantenimiento'), findsOneWidget);
      Future<void> fill(String label, String value) async {
        final field = find.byKey(ValueKey(label));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      Future<void> pick(String label, String value) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tapText(tester, value);
      }

      Future<void> date(String label, int days) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        for (var i = 0; i < days.abs(); i++) {
          await tester.sendKeyEvent(
            days < 0
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      await fill('Documento / actividad', 'Inspección de equipos');
      await pick('Tipo de registro', 'Inspección periódica');
      await legalRequired(tester);
      await fill('Avance (%)', '35');
      await tapText(tester, 'Vista previa');
      expect(
        find.text('Indica el equipo, instalación o alcance.'),
        findsOneWidget,
      );
      await fill('Equipo / instalación / alcance', 'Equipos de planta');
      await fill('Proveedor / servicio', 'Proveedor técnico');
      await fill('Emisor / certificador', 'Certificador de prueba');
      await fill('Folio / referencia', 'MT-001');
      await pick('Periodicidad', 'Trimestral');
      await tester.pumpAndSettle();
      await capture(tester, 'maintenance_capture');
      await tapText(tester, 'Programación y vigencia');
      await date('Fecha programada', 3);
      await date('Fecha realizada', 2);
      await date('Inicio de vigencia', -1);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await date('Fecha de vencimiento', 20);
      await capture(tester, 'maintenance_schedule');
      await tapText(tester, 'Documentación');
      picker.result = FilePickerResult([
        PlatformFile(name: 'evidencia-v1.pdf', size: 128),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await capture(tester, 'maintenance_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      var saved = store.records.values.single;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(saved.record.maintenanceSubject, 'Equipos de planta');
      expect(saved.record.providerName, 'Proveedor técnico');
      expect(saved.record.periodicity, 'Trimestral');
      expect(saved.record.scheduledDate, today.add(const Duration(days: 3)));
      expect(saved.record.performedDate, today.add(const Duration(days: 2)));
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(find.text('Programada'), findsOneWidget);
      await capture(tester, 'maintenance_list');
      final search = find.byType(TextField).first;
      for (final value in [
        'Equipos de planta',
        'Proveedor técnico',
        'MT-001',
      ]) {
        await tester.enterText(search, value);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Inspección de equipos'), findsOneWidget);
      }
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tapText(tester, 'Más recientes');
      await tapText(tester, 'Fecha programada');
      expect(find.text('Fecha programada'), findsOneWidget);
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Inspección de equipos'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await fill('Avance (%)', '80');
      await tapText(tester, 'Datos generales');
      await fill('Equipo / instalación / alcance', 'Instalación norte');
      await fill('Proveedor / servicio', 'Proveedor renovado');
      await pick('Periodicidad', 'Anual');
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Programación y vigencia');
      await date('Fecha programada', 4);
      await date('Fecha realizada', 6);
      await tapText(tester, 'Documentación');
      picker.result = FilePickerResult([
        PlatformFile(name: 'evidencia-v2.pdf', size: 256),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.single;
      expect(saved.record.maintenanceSubject, 'Instalación norte');
      expect(saved.record.providerName, 'Proveedor renovado');
      expect(saved.record.periodicity, 'Anual');
      expect(saved.record.scheduledDate, today.add(const Duration(days: 7)));
      expect(saved.record.performedDate, today.add(const Duration(days: 8)));
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(saved.history.last.record.maintenanceSubject, 'Equipos de planta');
      expect(saved.history.last.record.providerName, 'Proveedor técnico');
      expect(saved.history.last.record.periodicity, 'Trimestral');
      expect(
        saved.history.last.record.scheduledDate,
        today.add(const Duration(days: 3)),
      );
      expect(
        saved.history.last.record.performedDate,
        today.add(const Duration(days: 2)),
      );
      expect(
        saved.files.where((f) => !f.current).single.name,
        'evidencia-v1.pdf',
      );
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      final oldScope = find.descendant(
        of: history,
        matching: find.text('Equipos de planta'),
      );
      await tester.ensureVisible(oldScope);
      await tester.pumpAndSettle();
      expect(oldScope, findsOneWidget);
      await capture(tester, 'maintenance_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('80%'));
        await tester.pumpAndSettle();
        await capture(tester, 'maintenance_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'insurance validates insurer and subject, preserves coverage and policy versions with independent renewal',
    (tester) async {
      final store = DocumentalTestRepository();
      final picker = _LegalTestFilePicker();
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = _LegalTestFilePicker());
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Seguros');
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo seguro'), findsOneWidget);
      Future<void> fill(String label, String value) async {
        final field = find.byKey(ValueKey(label));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      Future<void> pick(String label, String value) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tapText(tester, value);
      }

      Future<void> date(String label, int days) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        for (var i = 0; i < days.abs(); i++) {
          await tester.sendKeyEvent(
            days < 0
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      await fill('Póliza / seguro', 'Seguro de flota');
      await pick('Tipo de seguro', 'Póliza');
      await legalRequired(tester);
      await fill('Avance (%)', '35');
      await tapText(tester, 'Vista previa');
      expect(find.text('Escribe el nombre de la aseguradora.'), findsOneWidget);
      expect(
        find.text('Indica el bien, persona o unidad asegurada.'),
        findsOneWidget,
      );
      await fill('Aseguradora', 'Aseguradora de prueba');
      await fill('Número de póliza', 'POL-001');
      await fill('Bien, persona o unidad asegurada', 'Flota y operadores');
      await fill('Cobertura', 'Daños materiales y asistencia');
      await tester.pumpAndSettle();
      await capture(tester, 'insurance_capture');
      await tapText(tester, 'Vigencia');
      await date('Inicio de vigencia', -1);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await date('Fecha de vencimiento', 20);
      await pick('Renovación', 'Por acuerdo');
      await date('Fecha de renovación', 18);
      await fill('Condiciones de renovación', 'Avisar antes de renovar');
      await tester.pumpAndSettle();
      await capture(tester, 'insurance_validity');
      await tapText(tester, 'Documentación');
      expect(find.text('Póliza (principal)'), findsOneWidget);
      picker.result = FilePickerResult([
        PlatformFile(name: 'poliza-v1.pdf', size: 128),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await capture(tester, 'insurance_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      var saved = store.records.values.single;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(saved.record.insuredSubject, 'Flota y operadores');
      expect(saved.record.coverageDescription, 'Daños materiales y asistencia');
      expect(saved.record.authority, 'Aseguradora de prueba');
      expect(saved.record.reference, 'POL-001');
      expect(
        saved.record.date('start_date'),
        today.subtract(const Duration(days: 1)),
      );
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(saved.record.renewalDate, today.add(const Duration(days: 18)));
      await capture(tester, 'insurance_list');
      final search = find.byType(TextField).first;
      for (final value in [
        'Flota y operadores',
        'Daños materiales',
        'POL-001',
      ]) {
        await tester.enterText(search, value);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Seguro de flota'), findsOneWidget);
      }
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Seguro de flota'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await fill('Avance (%)', '80');
      await tapText(tester, 'Datos generales');
      await fill('Bien, persona o unidad asegurada', 'Instalación asegurada');
      await fill('Cobertura', 'Incendio');
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Vigencia');
      await pick('Renovación', 'No aplica');
      expect(
        find.byKey(const ValueKey('documental-picker-Fecha de renovación')),
        findsNothing,
      );
      await tapText(tester, 'Documentación');
      picker.result = FilePickerResult([
        PlatformFile(name: 'poliza-v2.pdf', size: 256),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.single;
      expect(saved.record.insuredSubject, 'Instalación asegurada');
      expect(saved.record.coverageDescription, 'Incendio');
      expect(saved.record.renewalDate, isNull);
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(saved.history.last.record.insuredSubject, 'Flota y operadores');
      expect(
        saved.history.last.record.coverageDescription,
        'Daños materiales y asistencia',
      );
      expect(
        saved.history.last.record.renewalDate,
        today.add(const Duration(days: 18)),
      );
      expect(saved.files.where((f) => !f.current).single.name, 'poliza-v1.pdf');
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      final oldSubject = find.descendant(
        of: history,
        matching: find.text('Flota y operadores'),
      );
      await tester.ensureVisible(oldSubject);
      await tester.pumpAndSettle();
      expect(oldSubject, findsOneWidget);
      await capture(tester, 'insurance_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('80%'));
        await tester.pumpAndSettle();
        await capture(tester, 'insurance_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'contracts keep counterparties, signature, validity, renewal and signed versions independent',
    (tester) async {
      final store = DocumentalTestRepository();
      final picker = _LegalTestFilePicker();
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = _LegalTestFilePicker());
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Contratos');
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo contrato'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('Contrato / acuerdo')),
        'Contrato de servicios',
      );
      Future<void> pick(String label, String value) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tapText(tester, value);
      }

      Future<void> date(String label, int days) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        for (var i = 0; i < days.abs(); i++) {
          await tester.sendKeyEvent(
            days < 0
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      await pick('Tipo de contrato', 'Contrato');
      await legalRequired(tester);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '35');
      await tapText(tester, 'Vista previa');
      expect(find.text('Escribe el nombre de la contraparte.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('Contraparte')),
        'Contraparte de prueba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Folio / referencia')),
        'CT-001',
      );
      await tester.pumpAndSettle();
      await capture(tester, 'contract_capture');
      await tapText(tester, 'Vigencia');
      await date('Fecha de firma', -1);
      await date('Fecha inicial', 1);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await date('Fecha final', 20);
      await pick('Renovación', 'Por acuerdo');
      await date('Fecha de renovación', 18);
      await tester.enterText(
        find.byKey(const ValueKey('Condiciones de renovación')),
        'Avisar antes de renovar',
      );
      await tester.pumpAndSettle();
      await capture(tester, 'contract_validity');
      await tapText(tester, 'Documentación');
      expect(find.text('Archivo firmado (principal)'), findsOneWidget);
      picker.result = FilePickerResult([
        PlatformFile(name: 'contrato-firmado-v1.pdf', size: 128),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await capture(tester, 'contract_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      var saved = store.records.values.single;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(saved.record.counterpartyName, 'Contraparte de prueba');
      expect(
        saved.record.signatureDate,
        today.subtract(const Duration(days: 1)),
      );
      expect(
        saved.record.date('start_date'),
        today.add(const Duration(days: 1)),
      );
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(saved.record.renewalDate, today.add(const Duration(days: 18)));
      expect(saved.record.renewalType, 'Por acuerdo');
      expect(saved.files.single.name, 'contrato-firmado-v1.pdf');
      await capture(tester, 'contract_list');
      final search = find.byType(TextField).first;
      await tester.enterText(search, 'Contraparte de prueba');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Contrato de servicios'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Contrato de servicios'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '80');
      await tapText(tester, 'Datos generales');
      await tester.enterText(
        find.byKey(const ValueKey('Contraparte')),
        'Contraparte renovada',
      );
      await tapText(tester, 'Vigencia');
      await date('Fecha de firma', 1);
      await pick('Renovación', 'Automática');
      await date('Fecha de renovación', 1);
      await tester.enterText(
        find.byKey(const ValueKey('Condiciones de renovación')),
        'Aviso actualizado',
      );
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Documentación');
      picker.result = FilePickerResult([
        PlatformFile(name: 'contrato-firmado-v2.pdf', size: 256),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.single;
      expect(saved.record.counterpartyName, 'Contraparte renovada');
      expect(saved.record.signatureDate, today);
      expect(saved.record.renewalDate, today.add(const Duration(days: 19)));
      expect(saved.record.expiration, today.add(const Duration(days: 20)));
      expect(saved.record.renewalType, 'Automática');
      expect(saved.record.renewalNotes, 'Aviso actualizado');
      expect(
        saved.history.last.record.counterpartyName,
        'Contraparte de prueba',
      );
      expect(saved.history.last.record.renewalNotes, 'Avisar antes de renovar');
      expect(saved.history.last.record.renewalType, 'Por acuerdo');
      expect(
        saved.files.where((f) => !f.current).single.name,
        'contrato-firmado-v1.pdf',
      );
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.descendant(of: history, matching: find.text('Por acuerdo')),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'contract_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('80%'));
        await tester.pumpAndSettle();
        await capture(tester, 'contract_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Contrato de servicios'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tapText(tester, 'Vigencia');
      await pick('Renovación', 'No aplica');
      expect(
        find.byKey(const ValueKey('documental-picker-Fecha de renovación')),
        findsNothing,
      );
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      expect(store.records.values.single.record.renewalDate, isNull);
      expect(
        store.records.values.single.record.expiration,
        today.add(const Duration(days: 20)),
      );
      await tapText(tester, 'Cerrar');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'civil protection captures activities, filters types and keeps authority and area history',
    (tester) async {
      final store = DocumentalTestRepository();
      await store.save(
        DocumentalSaveOperation(
          DocumentalRecordDraft(kind: DocumentalRecordKind.safety)
            ..title = 'Capacitación de otra categoría'
            ..documentType = 'Capacitación'
            ..responsibleId = '00000000-0000-4000-8000-000000000001'
            ..status = 'Pendiente'
            ..priority = 'Media'
            ..progressPercentage = 0,
        ),
      );
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Protección Civil');
      expect(find.text('Capacitación de otra categoría'), findsNothing);
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo registro de Protección Civil'), findsOneWidget);
      expect(find.text('Trabajador relacionado'), findsNothing);
      expect(find.text('Tipo de estudio'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('Documento / actividad')),
        'Simulacro de evacuación',
      );
      Future<void> pickType(String value) async {
        await tester.tap(
          find.byKey(const ValueKey('documental-picker-Tipo de registro')),
        );
        await tester.pumpAndSettle();
        await tapText(tester, value);
      }

      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Tipo de registro')),
      );
      await tester.pumpAndSettle();
      for (final type in documentalCivilProtectionTypes) {
        expect(find.text(type), findsOneWidget);
      }
      await capture(tester, 'civil_picker');
      await tapText(tester, 'Simulacro');
      for (final entry in {
        'Autoridad / entidad': 'Coordinación de prueba',
        'Área / departamento': 'Patio de prueba',
        'Folio / referencia': 'PC-001',
      }.entries) {
        await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      }
      await tester.pumpAndSettle();
      await capture(tester, 'civil_capture');
      await legalRequired(tester);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '35');
      await tapText(tester, 'Vista previa');
      await capture(tester, 'civil_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      expect(
        find.text('Coordinación de prueba · Patio de prueba'),
        findsOneWidget,
      );
      expect(find.text('PC-001 · Simulacro'), findsOneWidget);
      await capture(tester, 'civil_list');
      var saved = store.records.values.singleWhere(
        (r) => r.record.kind == DocumentalRecordKind.civilProtection,
      );
      expect(saved.record.expiration, isNull);
      final search = find.byType(TextField).first;
      for (final value in [
        'PC-001',
        'Coordinación de prueba',
        'Patio de prueba',
      ]) {
        await tester.enterText(search, value);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Simulacro de evacuación'), findsOneWidget);
      }
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tapText(tester, 'Tipo');
      await tapText(tester, 'Programa interno');
      expect(find.text('Sin coincidencias'), findsOneWidget);
      await tapText(tester, 'Programa interno');
      await tapText(tester, 'Simulacro');
      expect(find.text('Simulacro de evacuación'), findsOneWidget);
      await tapText(tester, 'Simulacro');
      await tapText(tester, 'Todos');
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Simulacro de evacuación'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('Avance (%)')),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '80');
      await tapText(tester, 'Datos generales');
      await pickType('Visto bueno');
      await tester.enterText(
        find.byKey(const ValueKey('Autoridad / entidad')),
        'Autoridad actualizada',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Área / departamento')),
        'Oficinas',
      );
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.singleWhere(
        (r) => r.record.kind == DocumentalRecordKind.civilProtection,
      );
      expect(saved.record.progress, 80);
      expect(saved.record.type, 'Visto bueno');
      expect(saved.record.authority, 'Autoridad actualizada');
      expect(saved.record.data['department'], 'Oficinas');
      expect(saved.history.last.record.type, 'Simulacro');
      expect(saved.history.last.record.authority, 'Coordinación de prueba');
      expect(saved.history.last.record.data['department'], 'Patio de prueba');
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.descendant(
          of: history,
          matching: find.text('Coordinación de prueba'),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'civil_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('80%'));
        await tester.pumpAndSettle();
        await capture(tester, 'civil_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'personnel links RH workers including inactive staff and preserves historical identity',
    (tester) async {
      final store = DocumentalTestRepository();
      await store.save(
        DocumentalSaveOperation(
          DocumentalRecordDraft(kind: DocumentalRecordKind.safety)
            ..title = 'Capacitación de otra categoría'
            ..documentType = 'DC3'
            ..relatedEmployeeId = '00000000-0000-4000-8000-000000000005'
            ..responsibleId = '00000000-0000-4000-8000-000000000001'
            ..status = 'Pendiente'
            ..priority = 'Media'
            ..progressPercentage = 10,
        ),
      );
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Personal');
      expect(find.text('Capacitación de otra categoría'), findsNothing);
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo documento de personal'), findsOneWidget);
      expect(find.text('Tipo de estudio'), findsNothing);
      expect(find.text('Unidad relacionada'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('Documento laboral')),
        'Contrato del trabajador',
      );
      Future<void> pick(String label, String value) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tapText(tester, value);
      }

      await pick('Tipo de registro', 'Contrato laboral');
      final employeePicker = find.byKey(
        const ValueKey('documental-picker-Trabajador relacionado'),
      );
      await tester.ensureVisible(employeePicker);
      await tester.tap(employeePicker);
      await tester.pumpAndSettle();
      final pickerSearch = find
          .byType(EditableText)
          .evaluate()
          .map((e) => e.widget as EditableText)
          .singleWhere((w) => w.focusNode.hasFocus);
      expect(pickerSearch.controller.text, isEmpty);
      await capture(tester, 'personnel_picker');
      await tapText(tester, 'Trabajador de prueba');
      await tester.enterText(
        find.byKey(const ValueKey('Folio / referencia')),
        'RH-001',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Emisor / institución')),
        'Emisor de prueba',
      );
      await capture(tester, 'personnel_capture');
      await legalRequired(tester);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '35');
      await tapText(tester, 'Vista previa');
      expect(find.text('Trabajador de prueba'), findsOneWidget);
      await capture(tester, 'personnel_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      expect(
        store.records.values
            .singleWhere((d) => d.record.kind == DocumentalRecordKind.personnel)
            .record
            .employeeId,
        '00000000-0000-4000-8000-000000000005',
      );
      expect(find.text('Trabajador de prueba'), findsOneWidget);
      await capture(tester, 'personnel_list');
      final search = find.byType(TextField).first;
      for (final value in [
        'Trabajador de prueba',
        'RH-001',
        'Emisor de prueba',
      ]) {
        await tester.enterText(search, value);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Contrato del trabajador'), findsOneWidget);
      }
      await tester.enterText(search, 'Trabajador de baja');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Sin coincidencias'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Contrato del trabajador'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('Avance (%)')),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '80');
      await tapText(tester, 'Datos generales');
      await pick('Trabajador relacionado', 'Trabajador de baja (inactivo)');
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      var saved = store.records.values.singleWhere(
        (d) => d.record.kind == DocumentalRecordKind.personnel,
      );
      expect(saved.record.employeeName, 'Trabajador de baja');
      expect(saved.record.progress, 80);
      expect(saved.history.last.record.employeeName, 'Trabajador de prueba');
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      final oldWorker = find.descendant(
        of: history,
        matching: find.text('Trabajador de prueba'),
      );
      await tester.ensureVisible(oldWorker);
      await tester.pumpAndSettle();
      await capture(tester, 'personnel_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('80%'));
        await tester.pumpAndSettle();
        await capture(tester, 'personnel_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Contrato del trabajador'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tapText(tester, 'Datos generales');
      await pick('Trabajador relacionado', 'Sin trabajador específico');
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.singleWhere(
        (d) => d.record.kind == DocumentalRecordKind.personnel,
      );
      expect(saved.record.employeeId, isNull);
      expect(saved.record.employeeName, isEmpty);
      expect(saved.history[1].record.employeeName, 'Trabajador de baja');
      await tapText(tester, 'Cerrar');
      expect(find.text('Sin trabajador específico'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vehicles link existing units, search plates and preserve history when scope changes',
    (tester) async {
      final store = DocumentalTestRepository();
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Vehículos');
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo documento vehicular'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('Documento vehicular')),
        'Seguro de unidad',
      );
      Future<void> pick(String label, String value) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tapText(tester, value);
      }

      await pick('Tipo de registro', 'Seguro');
      final vehiclePicker = find.byKey(
        const ValueKey('documental-picker-Unidad relacionada'),
      );
      await tester.ensureVisible(vehiclePicker);
      await tester.tap(vehiclePicker);
      await tester.pumpAndSettle();
      final pickerSearch = find
          .byType(EditableText)
          .evaluate()
          .map((e) => e.widget as EditableText)
          .singleWhere((w) => w.focusNode.hasFocus);
      expect(pickerSearch.controller.text, isEmpty);
      await capture(tester, 'vehicle_picker');
      await tapText(tester, 'C1 · ABC-123');
      await tester.enterText(
        find.byKey(const ValueKey('Folio / póliza / referencia')),
        'POL-001',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Emisor / aseguradora')),
        'Aseguradora de prueba',
      );
      await capture(tester, 'vehicle_capture');
      await legalRequired(tester);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '35');
      await tapText(tester, 'Vista previa');
      expect(find.text('C1 · ABC-123'), findsOneWidget);
      await capture(tester, 'vehicle_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      expect(
        store.records.values.single.record.vehicleId,
        '00000000-0000-4000-8000-000000000007',
      );
      expect(find.text('C1 · ABC-123'), findsOneWidget);
      await capture(tester, 'vehicle_list');
      final search = find.byType(TextField).first;
      for (final value in ['ABC-123', 'C1', 'POL-001']) {
        await tester.enterText(search, value);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Seguro de unidad'), findsOneWidget);
      }
      await tester.enterText(search, 'DEF-456');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Sin coincidencias'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Seguro de unidad'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('Avance (%)')),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '80');
      await tapText(tester, 'Datos generales');
      await pick('Unidad relacionada', 'C2 · DEF-456');
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      var saved = store.records.values.single;
      expect(saved.record.vehicleLabel, 'C2 · DEF-456');
      expect(saved.record.progress, 80);
      expect(saved.history.last.record.vehicleLabel, 'C1 · ABC-123');
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      final oldUnit = find.descendant(
        of: history,
        matching: find.text('C1 · ABC-123'),
      );
      await tester.ensureVisible(oldUnit);
      await tester.pumpAndSettle();
      await capture(tester, 'vehicle_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('80%'));
        await tester.pumpAndSettle();
        await capture(tester, 'vehicle_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Seguro de unidad'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tapText(tester, 'Datos generales');
      await pick('Unidad relacionada', 'Sin unidad específica');
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.single;
      expect(saved.record.vehicleId, isNull);
      expect(saved.record.vehicleLabel, isEmpty);
      expect(saved.history[1].record.vehicleLabel, 'C2 · DEF-456');
      await tapText(tester, 'Cerrar');
      expect(find.text('Sin unidad específica'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'environment keeps authorization, installation and renewal history separate',
    (tester) async {
      final store = DocumentalTestRepository();
      for (final kind in DocumentalRecordKind.values.where(
        (k) => k != DocumentalRecordKind.environment,
      )) {
        await store.save(
          DocumentalSaveOperation(
            DocumentalRecordDraft(kind: kind)
              ..title = 'Exclusivo de ${kind.name}'
              ..documentType = documentalTypesFor(kind).first
              ..responsibleId = '00000000-0000-4000-8000-000000000001'
              ..status = 'Pendiente'
              ..priority = 'Media'
              ..progressPercentage = 0,
          ),
        );
      }
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Medio Ambiente');
      for (final kind in [
        DocumentalRecordKind.legal,
        DocumentalRecordKind.procedures,
        DocumentalRecordKind.safety,
      ]) {
        expect(find.text('Exclusivo de ${kind.name}'), findsNothing);
      }
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo documento ambiental'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('Documento ambiental')),
        'Autorización de operación',
      );
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Tipo de registro')),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Autorización');
      for (final field in {
        'Autoridad ambiental': 'Autoridad de prueba',
        'Folio / referencia': 'FOL-001',
        'Número de autorización': 'AMB-001',
        'Instalación relacionada': 'Patio de prueba',
      }.entries) {
        await tester.ensureVisible(find.byKey(ValueKey(field.key)));
        await tester.enterText(find.byKey(ValueKey(field.key)), field.value);
      }
      await tester.pumpAndSettle();
      await capture(tester, 'environment_capture');
      await legalRequired(tester);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '25');
      await tapText(tester, 'Vista previa');
      await capture(tester, 'environment_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      expect(find.text('1 documento'), findsOneWidget);
      expect(find.text('AMB-001 · Autorización'), findsOneWidget);
      expect(
        find.text('Patio de prueba · Autoridad de prueba'),
        findsOneWidget,
      );
      await capture(tester, 'environment_list');
      var saved = store.records.values.singleWhere(
        (r) => r.record.kind == DocumentalRecordKind.environment,
      );
      expect(saved.record.authorizationNumber, 'AMB-001');
      expect(saved.record.reference, 'FOL-001');
      expect(saved.record.expiration, isNull);
      final search = find.byType(TextField).first;
      await tester.enterText(search, 'AMB-001');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Autorización de operación'), findsOneWidget);
      await tester.enterText(search, 'sin coincidencia');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Sin coincidencias'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Autorización de operación'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '75');
      await tapText(tester, 'Datos generales');
      await tester.enterText(
        find.byKey(const ValueKey('Número de autorización')),
        'AMB-002',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Instalación relacionada')),
        'Patio renovado',
      );
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.singleWhere(
        (r) => r.record.kind == DocumentalRecordKind.environment,
      );
      expect(saved.record.authorizationNumber, 'AMB-002');
      expect(saved.record.installationName, 'Patio renovado');
      expect(saved.record.reference, 'FOL-001');
      expect(saved.record.progress, 75);
      expect(saved.history.last.record.authorizationNumber, 'AMB-001');
      expect(saved.history.last.record.installationName, 'Patio de prueba');
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      final authorization = find.descendant(
        of: history,
        matching: find.text('AMB-001'),
      );
      await tester.ensureVisible(authorization);
      await tester.pumpAndSettle();
      await capture(tester, 'environment_history');
      await tapText(tester, 'Cerrar');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('75%'));
        await tester.pumpAndSettle();
        await capture(tester, 'environment_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'safety links workers, preserves specific fields and supports area-wide records',
    (tester) async {
      final store = DocumentalTestRepository();
      for (final kind in [
        DocumentalRecordKind.legal,
        DocumentalRecordKind.procedures,
      ]) {
        await store.save(
          DocumentalSaveOperation(
            DocumentalRecordDraft(kind: kind)
              ..title = 'Exclusivo de ${kind.name}'
              ..documentType = documentalTypesFor(kind).first
              ..responsibleId = '00000000-0000-4000-8000-000000000001'
              ..status = 'Pendiente'
              ..priority = 'Media'
              ..progressPercentage = 0,
          ),
        );
      }
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Seguridad e Higiene');
      expect(find.text('Exclusivo de legal'), findsNothing);
      expect(find.text('Exclusivo de procedures'), findsNothing);
      await tapText(tester, 'Nuevo');
      expect(find.text('Nuevo documento de seguridad'), findsOneWidget);
      Future<void> pick(String label, String option) async {
        final field = find.byKey(ValueKey('documental-picker-$label'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        final input = find.byType(TextField).last;
        expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
        await tapText(tester, option);
      }

      await tester.enterText(
        find.byKey(const ValueKey('Documento / actividad')),
        'Capacitación de seguridad',
      );
      await pick('Tipo de registro', 'DC3');
      await tester.enterText(
        find.byKey(const ValueKey('Área / departamento')),
        'Patio',
      );
      await pick('Responsable interno', 'Responsable de prueba');
      await pick('Trabajador relacionado', 'Trabajador de prueba');
      await pick('Tipo de estudio', 'Ergonomía');
      await tester.ensureVisible(
        find.byKey(const ValueKey('Proveedor / capacitador')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('Proveedor / capacitador')),
        'Capacitador de prueba',
      );
      await pick('Periodicidad', 'Anual');
      await capture(tester, 'safety_capture');
      await tapText(tester, 'Seguimiento');
      await pick('Estatus del proceso', 'Pendiente');
      await pick('Prioridad', 'Alta');
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '40');
      await tester.enterText(
        find.byKey(const ValueKey('Próxima acción')),
        'Recibir constancia',
      );
      await tapText(tester, 'Vista previa');
      await capture(tester, 'safety_detail');
      await tapText(tester, 'Guardar documento');
      await tapText(tester, 'Cerrar');
      expect(find.text('1 documento'), findsOneWidget);
      expect(find.text('Trabajador de prueba · Patio'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      await capture(tester, 'safety_list');
      var saved = store.records.values.singleWhere(
        (r) => r.record.kind == DocumentalRecordKind.safety,
      );
      expect(saved.record.periodicity, 'Anual');
      expect(saved.record.employeeId, '00000000-0000-4000-8000-000000000005');
      expect(saved.record.expiration, isNull);
      expect(saved.record.providerName, 'Capacitador de prueba');
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Capacitación de seguridad'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('Avance (%)')),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '80');
      await tapText(tester, 'Datos generales');
      await pick('Periodicidad', 'Semestral');
      await pick('Trabajador relacionado', 'Sin trabajador específico');
      store.events.add(null);
      await tester.pumpAndSettle();
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar documento');
      saved = store.records.values.singleWhere(
        (r) => r.record.kind == DocumentalRecordKind.safety,
      );
      expect(saved.record.employeeId, isNull);
      expect(saved.record.progress, 80);
      expect(saved.record.periodicity, 'Semestral');
      expect(saved.history.last.record.employeeName, 'Trabajador de prueba');
      expect(saved.history.last.record.periodicity, 'Anual');
      final history = find.byKey(const ValueKey('history-1'));
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: history, matching: find.text('Anual')),
        findsOneWidget,
      );
      await capture(tester, 'safety_history');
      await tapText(tester, 'Cerrar');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tipo'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Estudio');
      expect(find.text('Sin coincidencias'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Estudio'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Todos');
      for (final size in [const Size(800, 900), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Capacitación de seguridad'));
        await capture(tester, 'safety_list_${size.width.toInt()}');
        expect(find.text('80%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'procedures validate progress, keep categories separate and update follow-up with history',
    (tester) async {
      final store = DocumentalTestRepository();
      await store.save(
        DocumentalSaveOperation(
          DocumentalRecordDraft()
            ..title = 'Acta exclusiva de Legal'
            ..documentType = 'Acta constitutiva'
            ..responsibleId = '00000000-0000-4000-8000-000000000001'
            ..status = 'Pendiente'
            ..priority = 'Media',
        ),
      );
      await mount(tester, const Size(1440, 1000), repository: store);
      await tapText(tester, 'Permisos y Trámites');
      expect(find.text('Acta exclusiva de Legal'), findsNothing);
      await tapText(tester, 'Nuevo');
      await tester.enterText(
        find.byKey(const ValueKey('Trámite / expediente')),
        'Licencia de funcionamiento',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Dependencia')),
        'Municipio de Celaya',
      );
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Tipo de gestión')),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Licencia');
      await legalRequired(tester);
      await tapText(tester, 'Vista previa');
      expect(find.text('Captura un avance de 0 a 100.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '101');
      await tapText(tester, 'Vista previa');
      expect(find.text('Captura un avance de 0 a 100.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '35');
      await tester.enterText(
        find.byKey(const ValueKey('Próxima acción')),
        'Presentar solicitud',
      );
      await tester.pumpAndSettle();
      expect(find.text('Captura un avance de 0 a 100.'), findsNothing);
      await capture(tester, 'procedures_capture');
      await tapText(tester, 'Vista previa');
      expect(find.text('Detalle del trámite'), findsOneWidget);
      await capture(tester, 'procedures_detail');
      await tapText(tester, 'Guardar trámite');
      expect(find.text('Expediente guardado · Versión 1'), findsOneWidget);
      await tapText(tester, 'Cerrar');
      expect(find.text('1 trámite'), findsOneWidget);
      expect(find.text('35%'), findsOneWidget);
      expect(find.text('Municipio de Celaya'), findsOneWidget);
      await capture(tester, 'procedures_list');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Prioridad'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Alta');
      expect(find.text('Sin coincidencias'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Alta'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Todos');
      await tester.tap(
        find.byTooltip('Actualizar seguimiento de Licencia de funcionamiento'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final progress = find.descendant(
        of: find.byKey(const ValueKey('Avance (%)')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(progress).focusNode.hasFocus, isTrue);
      await tester.enterText(find.byKey(const ValueKey('Avance (%)')), '68');
      await tester.enterText(
        find.byKey(const ValueKey('Próxima acción')),
        'Entregar acuse',
      );
      store.events.add(null);
      await tester.pump();
      expect(find.text('Entregar acuse'), findsOneWidget);
      await tapText(tester, 'Vista previa');
      await tapText(tester, 'Guardar trámite');
      final saved = store.records.values.singleWhere(
        (r) => r.record.kind == DocumentalRecordKind.procedures,
      );
      expect(saved.record.progress, 68);
      expect(saved.history.last.record.progress, 35);
      expect(saved.record.data['next_action'], 'Entregar acuse');
      await tester.ensureVisible(find.byKey(const ValueKey('history-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('history-1')));
      await tester.pumpAndSettle();
      await capture(tester, 'procedures_history');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('history-1')),
          matching: find.text('35%'),
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Cerrar');
      for (final size in const [Size(800, 900), Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Licencia de funcionamiento'));
        await tester.pumpAndSettle();
        await capture(tester, 'procedures_list_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('legal record saves, reloads, filters and keeps revisions', (
    tester,
  ) async {
    final store = DocumentalTestRepository();
    await mount(tester, const Size(1440, 1000), repository: store);
    await tapText(tester, 'Documentación Legal');
    await tapText(tester, 'Nuevo');
    await tester.enterText(
      find.byKey(const ValueKey('Nombre del documento')),
      'Acta registrada',
    );
    await tester.tap(
      find.byKey(const ValueKey('documental-picker-Tipo de documento')),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Acta constitutiva');
    await legalRequired(tester);
    await tapText(tester, 'Vista previa');
    store.failSave = true;
    await tapText(tester, 'Guardar documento');
    expect(find.text('Fallo de guardado de prueba'), findsOneWidget);
    expect(store.records, isEmpty);
    store.failSave = false;
    await tapText(tester, 'Guardar documento');
    expect(find.text('Expediente guardado · Versión 1'), findsOneWidget);
    await tapText(tester, 'Cerrar');
    expect(find.text('Acta registrada'), findsOneWidget);
    await capture(tester, 'legal_saved_list');
    await tester.tap(find.byTooltip('Abrir Acta registrada'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await capture(tester, 'legal_reopened');
    await tapText(tester, 'Editar expediente');
    await tapText(tester, 'Seguimiento');
    await tester.enterText(
      find.byKey(const ValueKey('Observaciones')),
      'Versión revisada',
    );
    store.events.add(null);
    await tester.pump();
    expect(find.text('Versión revisada'), findsOneWidget);
    await tapText(tester, 'Vista previa');
    await tapText(tester, 'Guardar documento');
    expect(find.text('Expediente guardado · Versión 2'), findsOneWidget);
    expect(store.records.values.single.history.length, 2);
    await tester.ensureVisible(find.text('Historial'));
    await tester.pumpAndSettle();
    await capture(tester, 'legal_saved_history');
    await tapText(tester, 'Cerrar');
    await tester.tap(find.text('Acta registrada'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('1 seleccionados'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Expediente guardado · Versión 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Detalle del documento'), findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await capture(tester, 'legal_saved_list_390');
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'inexistente');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Sin coincidencias'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing backend shows an error and keeps creation disabled', (
    tester,
  ) async {
    await mount(
      tester,
      const Size(800, 900),
      repository: DocumentalTestRepository()..unavailable = true,
    );
    await tapText(tester, 'Documentación Legal');
    expect(
      find.text(
        'Gestión Documental aún no está habilitada en la base de datos.',
      ),
      findsOneWidget,
    );
    final button = find.ancestor(
      of: find.text('Nuevo'),
      matching: find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legal capture validates and preserves values through preview and cancel',
    (tester) async {
      await mount(tester, const Size(1440, 1000));
      await tapText(tester, 'Documentación Legal');
      await tapText(tester, 'Nuevo');
      final name = find.byKey(const ValueKey('Nombre del documento'));
      final input = find.descendant(
        of: name,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
      expect(
        AreaThemeScope.of(tester.element(find.byType(Dialog))),
        same(documentalAreaTokens),
      );
      await capture(tester, 'legal_capture');
      await tapText(tester, 'Vista previa');
      expect(find.text('Escribe el nombre del documento.'), findsOneWidget);
      await tester.enterText(name, 'Acta constitutiva · prueba visual');
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Tipo de documento')),
      );
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Buscar');
      final editableSearch = find.descendant(
        of: search,
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(editableSearch).focusNode.hasFocus,
        isTrue,
      );
      await tester.enterText(search, 'Acta');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await legalRequired(tester);
      await tapText(tester, 'Seguimiento');
      await tester.enterText(
        find.byKey(const ValueKey('Observaciones')),
        'Revisar escritura original.',
      );
      await tapText(tester, 'Vista previa');
      expect(find.text('Detalle del documento'), findsOneWidget);
      expect(find.text('Sin vencimiento'), findsWidgets);
      expect(
        tester
            .widget<ElevatedButton>(
              find.ancestor(
                of: find.text('Guardar documento'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ElevatedButton,
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await capture(tester, 'legal_detail');
      await tester.ensureVisible(find.text('Historial'));
      await tester.pumpAndSettle();
      await capture(tester, 'legal_detail_history');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Nuevo documento legal'), findsOneWidget);
      expect(find.text('Revisar escritura original.'), findsOneWidget);
      await tapText(tester, 'Datos generales');
      expect(find.text('Acta constitutiva · prueba visual'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar captura'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar').last);
      await tester.pumpAndSettle();
      expect(find.text('Acta constitutiva · prueba visual'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tapText(tester, 'Descartar captura');
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Expediente por integrar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legal validity is optional and selected files never appear uploaded',
    (tester) async {
      final picker = _LegalTestFilePicker();
      FilePicker.platform = picker;
      await mount(tester, const Size(1440, 1000));
      await tapText(tester, 'Documentación Legal');
      await tapText(tester, 'Nuevo');
      await tester.enterText(
        find.byKey(const ValueKey('Nombre del documento')),
        'Poder de prueba',
      );
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Tipo de documento')),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Poder notarial');
      await legalRequired(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Vigencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tapText(tester, 'Vista previa');
      expect(find.text('Selecciona la fecha de vencimiento.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Fecha de vencimiento')),
      );
      await tester.pumpAndSettle();
      expect(
        AreaThemeScope.of(tester.element(find.byType(Dialog).last)),
        same(documentalAreaTokens),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await capture(tester, 'legal_validity');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Sin vencimiento'), findsOneWidget);
      await tapText(tester, 'Documentación');
      picker.result = FilePickerResult([
        PlatformFile(name: 'poder.pdf', size: 2048),
      ]);
      await tapText(tester, 'Seleccionar archivo');
      expect(find.text('poder.pdf'), findsOneWidget);
      expect(find.text('2 KB · Seleccionado, sin subir'), findsOneWidget);
      picker.result = null;
      await tapText(tester, 'Cambiar selección');
      expect(find.text('poder.pdf'), findsOneWidget);
      picker.result = FilePickerResult([
        PlatformFile(name: 'anexo.pdf', size: 1024),
      ]);
      await tapText(tester, 'Agregar complementarios');
      await tapText(tester, 'Agregar complementarios');
      expect(find.text('anexo.pdf'), findsOneWidget);
      await capture(tester, 'legal_files');
      await tester.tap(find.byTooltip('Quitar anexo.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('anexo.pdf'), findsNothing);
      picker.fail = true;
      await tapText(tester, 'Agregar complementarios');
      expect(
        find.text(
          'No se pudo abrir el selector de archivos. Intenta de nuevo.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Vista previa');
      expect(find.text('Detalle del documento'), findsOneWidget);
      expect(find.text('poder.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category switching preserves one dashboard and closes the overlay',
    (tester) async {
      await mount(tester, const Size(1440, 1000));
      await capture(tester, 'dashboard');
      await tapText(tester, 'Documentación Legal');
      expect(find.text('Admite documentos sin vencimiento'), findsOneWidget);
      await capture(tester, 'legal');
      await tapText(tester, 'Navegación');
      await capture(tester, 'navigation');
      await tapText(tester, 'Permisos y Trámites');
      expect(find.text('Sin trámites registrados'), findsOneWidget);
      expect(find.text('Navegación').hitTestable(), findsOneWidget);
      await tapText(tester, 'Navegación');
      final dashboardAccess = find.text('Dashboard Gestión Documental').last;
      await tester.ensureVisible(dashboardAccess);
      await tester.pumpAndSettle();
      await capture(tester, 'navigation_access');
      await tester.tap(dashboardAccess);
      await tester.pumpAndSettle();
      expect(find.text('Expedientes por categoría'), findsOneWidget);
      await tapText(tester, 'Documentación Legal');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Expedientes por categoría'), findsOneWidget);
      expect(find.text('Admite documentos sin vencimiento'), findsNothing);
      await tapText(tester, 'Navegación');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Navegación').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pickers keep the pink theme and search focus; calendar changes selection',
    (tester) async {
      await mount(tester, const Size(1440, 1000));
      await tapText(tester, 'Calendario');
      final today = DateUtils.dateOnly(DateTime.now());
      final dates = MaterialLocalizations.of(
        tester.element(find.text('Agenda del día')),
      );
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(
        find.text(dates.formatMonthYear(DateTime(today.year, today.month + 1))),
        findsOneWidget,
      );
      await tapText(tester, 'Hoy');
      expect(find.text(dates.formatFullDate(today)), findsOneWidget);
      await capture(tester, 'calendar');
      await tapText(tester, 'Todas las categorías');
      final dialog = find.byType(Dialog);
      expect(
        AreaThemeScope.of(tester.element(dialog)),
        same(documentalAreaTokens),
      );
      final search = find.descendant(
        of: dialog,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(search).focusNode.hasFocus, isTrue);
      await tester.enterText(search, 'Seguros');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Seguros').hitTestable(), findsWidgets);
      await tapText(tester, 'Ir a fecha');
      expect(
        AreaThemeScope.of(tester.element(find.byType(Dialog))),
        same(documentalAreaTokens),
      );
      await capture(tester, 'date_picker');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [Size(390, 844), Size(800, 900)]) {
    testWidgets('dashboard, category and calendar fit $size', (tester) async {
      await mount(tester, size);
      expect(tester.takeException(), isNull);
      await capture(tester, 'compact_${size.width.toInt()}');
      final calendarButton = find.widgetWithText(OutlinedButton, 'Calendario');
      await tester.ensureVisible(calendarButton);
      await tester.tap(calendarButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'calendar_${size.width.toInt()}');
      await tapText(tester, 'Dashboard Gestión Documental');
      final legal = find.text('Documentación Legal').first;
      await tester.ensureVisible(legal);
      await tester.tap(legal);
      await tester.pumpAndSettle();
      expect(find.text('Admite documentos sin vencimiento'), findsOneWidget);
      final newButton = find.text('Nuevo');
      await tester.ensureVisible(newButton);
      await tester.tap(newButton);
      await tester.pumpAndSettle();
      await capture(tester, 'legal_capture_${size.width.toInt()}');
      await tester.enterText(
        find.byKey(const ValueKey('Nombre del documento')),
        'Acta constitutiva',
      );
      await tester.tap(
        find.byKey(const ValueKey('documental-picker-Tipo de documento')),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Acta constitutiva');
      await legalRequired(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Vigencia'));
      await tester.pumpAndSettle();
      expect(find.text('Sin vencimiento'), findsOneWidget);
      await tapText(tester, 'Vista previa');
      expect(find.text('Detalle del documento'), findsOneWidget);
      await capture(tester, 'legal_detail_${size.width.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }
}

class _LegalTestFilePicker extends FilePicker {
  FilePickerResult? result;
  bool fail = false;

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
  }) async {
    if (fail) throw StateError('picker unavailable');
    return result;
  }
}
