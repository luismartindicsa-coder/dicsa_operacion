import '../contabilidad/statement_fixture.dart';

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
        final data = accountingFixture();
        data['finanzas_bank_movements']!.first['category'] = 'VENTAS';
        return accountingResponse(request, {
          ...data,
          'vw_men_cash_vouchers_grid': [],
          'vw_men_cash_cuts_grid': [],
          'cash_taxonomy_configs': [],
        });
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('card shows the same captured cash base as the statement', (
    tester,
  ) async {
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
    expect(find.text('\$1,000.00'), findsOneWidget);
    expect(find.text('\$530.00'), findsOneWidget);
    final net = find.byKey(const ValueKey('direction-accounting-net-result'));
    await tester.scrollUntilVisible(
      net,
      70,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(net).data, '\$1,530.00');
    expect(requests.map((request) => request.method).toSet(), {'GET'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
        ),
        throwsA(isA<Exception>()),
      );
    },
  );
}
