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
