import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/auth/auth_access.dart';
import 'package:dicsa_operacion/app/auth/role_router.dart';
import 'package:dicsa_operacion/app/services/inventory_page.dart';
import 'package:dicsa_operacion/app/services/warehouse_page.dart';
import 'package:dicsa_operacion/app/services/weighings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var active = true;
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://bascula-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          request.url.pathSegments.last == 'profiles'
              ? jsonEncode({'role': 'services', 'is_active': active})
              : '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json', 'content-range': '*/0'},
        ),
      ),
    );
    final expires =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    String encode(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    const userId = '00000000-0000-4000-8000-000000000001';
    final token =
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': userId, 'exp': expires, 'role': 'authenticated'})}.test-only';
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'test-only-refresh',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {
          'id': userId,
          'email': 'bascula@dicsamx.com',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-14T00:00:00Z',
        },
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    active = true;
    AuthAccess.invalidateResolvedProfileCache();
  });

  Widget app() => MaterialApp(
    theme: ThemeData(fontFamily: 'Roboto'),
    locale: const Locale('es', 'MX'),
    supportedLocales: const [Locale('es', 'MX')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const RoleRouter(),
  );
  void viewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> checkMenu(WidgetTester tester) async {
    await tester.tap(find.text('Navegación'));
    await tester.pumpAndSettle();
    final menu = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_ServicesSideMenu',
    );
    expect(menu, findsOneWidget);
    for (final label in ['Entradas y salidas', 'Pesadas', 'Almacen']) {
      expect(
        find.descendant(of: menu, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    for (final label in [
      'Producción',
      'Inventario',
      'Servicios',
      'Mantenimiento',
      'Compras OT',
      'Directorio',
      'Catálogos',
      'Dashboard general',
      'Dashboard operativo',
    ]) {
      expect(
        find.descendant(of: menu, matching: find.text(label)),
        findsNothing,
        reason: label,
      );
    }
  }

  testWidgets(
    'existing Báscula login starts at entries and navigates only its three pages with one click',
    (tester) async {
      viewport(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(InventoryPage), findsOneWidget);
      final profile = await AuthAccess.resolveCurrentProfile();
      expect(profile?.role, 'bascula');
      expect(AuthAccess.hasLogisticsAccess(profile), isFalse);

      await checkMenu(tester);
      await tester.tap(find.text('Pesadas').last);
      await tester.pumpAndSettle();
      expect(find.byType(WeighingsPage), findsOneWidget);

      await checkMenu(tester);
      await tester.tap(find.text('Almacen').last);
      await tester.pumpAndSettle();
      expect(find.byType(WarehousePage), findsOneWidget);

      await checkMenu(tester);
      await tester.tap(find.text('Entradas y salidas').last);
      await tester.pumpAndSettle();
      expect(find.byType(InventoryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('disabled Báscula account stays blocked', (tester) async {
    viewport(tester);
    active = false;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text('Usuario desactivado: bascula@dicsamx.com'),
      findsOneWidget,
    );
    expect(find.byType(InventoryPage), findsNothing);
    expect(find.text('Navegación'), findsNothing);
  });
}
