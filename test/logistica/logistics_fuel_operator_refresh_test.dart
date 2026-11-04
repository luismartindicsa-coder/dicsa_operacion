import 'dart:convert';

import 'package:dicsa_operacion/app/logistica/logistics_diesel_page.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gasoline_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final employees = <Map<String, dynamic>>[];
  var failOperators = false;
  var operatorRequests = 0;
  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fuel-operator-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        expect(r.method, 'GET');
        final table = r.url.pathSegments.last;
        if (table == 'employees') {
          operatorRequests++;
          expect(r.url.queryParameters['is_active'], 'eq.true');
          expect(r.url.queryParameters['is_driver'], 'eq.true');
          if (failOperators) {
            return http.Response(
              jsonEncode({'message': 'Unavailable', 'code': '503'}),
              503,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response(
          jsonEncode(table == 'employees' ? employees : []),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    employees.clear();
    failOperators = false;
    operatorRequests = 0;
  });

  for (final diesel in [true, false]) {
    final label = diesel ? 'diesel' : 'gasoline';
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1680, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: diesel
              ? const LogisticsDieselPage()
              : const LogisticsGasolinePage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester) async {
      final empty = find.text('—');
      await tester.tap(
        empty.evaluate().isNotEmpty ? empty.first : find.text('Opcional').first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      '$label finds a new operator even when the initial catalog was empty',
      (tester) async {
        await open(tester);
        expect(operatorRequests, 1);
        // Simulate a successful catalog creation while this page remains mounted.
        employees.add({'id': 'fernando-id', 'full_name': 'FERNANDO SORIA'});
        await tester.enterText(find.byType(TextField).first, '42.5');
        await pick(tester);
        expect(operatorRequests, 2);
        expect(find.text('FERNANDO SORIA'), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).last)
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.tap(find.text('FERNANDO SORIA'));
        await tester.pumpAndSettle();
        expect(find.text('FERNANDO SORIA'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '42.5',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '$label refresh failure preserves the draft and retry loads current names',
      (tester) async {
        employees.add({'id': 'old-id', 'full_name': 'OPERADOR ANTERIOR'});
        await open(tester);
        await tester.enterText(find.byType(TextField).first, '18.75');
        failOperators = true;
        await pick(tester);
        expect(
          find.textContaining('No se pudo actualizar el catálogo'),
          findsOneWidget,
        );
        expect(find.text('OPERADOR ANTERIOR'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '18.75',
        );
        failOperators = false;
        employees[0]['full_name'] = 'OPERADOR ACTUALIZADO';
        await pick(tester);
        expect(find.text('OPERADOR ACTUALIZADO'), findsOneWidget);
        expect(find.text('OPERADOR ANTERIOR'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '18.75',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
