import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/auth/auth_access.dart';
import 'package:dicsa_operacion/app/auth/role_router.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_dashboard_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://documental-access-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {'role': 'gestion_documental', 'is_active': true},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    final expires =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    String encode(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    const userId = '00000000-0000-4000-8000-000000000003';
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
          'email': 'gestion@dicsamx.com',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-09-14T00:00:00Z',
        },
      }),
    );
    AuthAccess.invalidateResolvedProfileCache();
    await AuthAccess.resolveCurrentProfile();
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets(
    'documental session opens its dashboard without Direction navigation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('es', 'MX'),
          supportedLocales: [Locale('es', 'MX')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RoleRouter(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GestionDocumentalDashboardPage), findsOneWidget);
      expect(find.text('Dashboard Gestión Documental'), findsWidgets);
      await tester.tap(find.text('Navegación'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard Dirección'), findsNothing);
      expect(find.text('Documentación Legal'), findsWidgets);
      expect(find.text('Permisos y Trámites'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
