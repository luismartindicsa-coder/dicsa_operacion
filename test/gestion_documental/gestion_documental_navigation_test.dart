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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> mount(WidgetTester tester, Size size) async {
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
      builder: (context, child) =>
          RepaintBoundary(key: const ValueKey('capture'), child: child!),
      home: const GestionDocumentalDashboardPage(instantOpen: true),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).hitTestable().first);
  await tester.pumpAndSettle();
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
    'category switching preserves one dashboard and closes the overlay',
    (tester) async {
      await mount(tester, const Size(1440, 1000));
      await capture(tester, 'dashboard');
      await tapText(tester, 'Documentación Legal');
      expect(find.text('Admite documentos sin vencimiento'), findsOneWidget);
      await capture(tester, 'legal');
      await tapText(tester, 'Navegación');
      await tapText(tester, 'Permisos y Trámites');
      expect(find.text('Dependencia'), findsOneWidget);
      expect(find.text('Navegación').hitTestable(), findsOneWidget);
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
      await tapText(tester, 'Gestión Documental · Resumen');
      final legal = find.text('Documentación Legal').first;
      await tester.ensureVisible(legal);
      await tester.tap(legal);
      await tester.pumpAndSettle();
      expect(find.text('Admite documentos sin vencimiento'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
