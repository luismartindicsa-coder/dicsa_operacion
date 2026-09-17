import 'dart:convert';

import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';
import 'package:dicsa_operacion/app/direction/direction_accounting_dashboard_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var failBank = false;
  Map<String, dynamic> bank(
    String id,
    String category,
    num credit,
    num debit, {
    String date = '2026-09-15',
  }) => {
    'id': id,
    'movement_date': date,
    'category': category,
    'credit_amount': credit,
    'debit_amount': debit,
  };
  Map<String, dynamic> voucher(
    String id,
    String type,
    String rubric,
    num amount,
  ) => {
    'id': id,
    'voucher_date': '2026-09-15',
    'voucher_type': type,
    'rubric': rubric,
    'total_amount': amount,
  };
  Map<String, dynamic> legacy(
    String id,
    String type,
    String rubric,
    num amount,
  ) => {
    'id': id,
    'date': '2026-09-15',
    'type': type,
    'rubric': rubric,
    'lines': [
      {'amount': amount},
    ],
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://accounting-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(
          request.method,
          'GET',
          reason: 'A dashboard must not migrate or write vouchers.',
        );
        final table = request.url.pathSegments.last;
        if (failBank && table == 'finanzas_bank_movements') {
          return http.Response(
            '{"message":"unavailable"}',
            503,
            request: request,
          );
        }
        final Object data = switch (table) {
          'finanzas_bank_movements' => [
            bank('b1', 'VENTAS', 1000, 0),
            bank('b2', 'COMPRA DE MATERIAL', 0, 300),
            bank('b3', 'GASTOS OPERATIVOS', 0, 100),
            bank('b4', 'MOVIMIENTOS INTERNOS', 500, 0),
            bank('old', 'VENTAS', 99999, 0, date: '2026-09-08'),
          ],
          'cash_taxonomy_configs' => [
            {
              'payload': {
                'rows': [
                  legacy('v1', 'deposit', 'Venta de material', 200),
                  legacy('v2', 'deposit', 'Otros', 40),
                  legacy('v3', 'expense', 'Gastos operativos', 30),
                ],
              },
            },
          ],
          'vw_men_cash_vouchers_grid' => [
            voucher('m1', 'deposit', 'Venta de material', 150),
            voucher('m2', 'expense', 'Compra de material', 50),
            voucher('m3', 'expense', 'Gastos operativos', 20),
            voucher('m4', 'deposit', 'Otros', 10),
            voucher('m5', 'deposit', 'Reposición de fondo', 500),
          ],
          _ => <Map<String, dynamic>>[],
        };
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets(
    'default card uses accounting totals and reads legacy cash without migrating it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 428,
              child: DirectionAccountingDashboardCard(
                now: () => DateTime(2026, 9, 15),
                onOpenStatement: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('\$1,350.00'), findsOneWidget);
      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text('\$-350.00'), findsOneWidget);
      expect(find.text('\$1,050.00'), findsOneWidget);
      expect(find.text('\$-150.00'), findsOneWidget);
      final net = find.byKey(const ValueKey('direction-accounting-net-result'));
      await tester.scrollUntilVisible(
        net,
        70,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(net).data, '\$900.00');
      expect(requests.map((request) => request.method).toSet(), {'GET'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'strict accounting source failure is not converted to a zero statement',
    () async {
      failBank = true;
      await expectLater(
        const ContabilidadIncomeStatementStore().loadSimplified(
          windowDays: 7,
          dateRange: DateTimeRange(
            start: DateTime(2026, 9, 9),
            end: DateTime(2026, 9, 15),
          ),
          migrateLegacyVouchers: false,
        ),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
