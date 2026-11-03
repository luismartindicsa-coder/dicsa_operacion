import '../contabilidad/statement_fixture.dart';

import 'package:dicsa_operacion/app/contabilidad/contabilidad_dashboard_page.dart';
import 'package:dicsa_operacion/app/management_reports/accounting_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/accounting_weekly_source.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_pdf_export.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:dicsa_operacion/app/management_reports/management_supervision_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var failTable = '';
  var dense = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://accounting-week-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        expect(
          r.method,
          'GET',
          reason:
              'Reports must never migrate legacy vouchers or mutate source records.',
        );
        final table = r.url.pathSegments.last;
        if (table == failTable) {
          return http.Response(
            '{"message":"permission denied","code":"42501"}',
            403,
            request: r,
          );
        }
        return accountingResponse(r, accountingFixture(dense: dense));
      }),
    );
  });
  setUp(() {
    requests.clear();
    failTable = '';
    dense = false;
  });
  tearDownAll(() => Supabase.instance.dispose());

  test(
    'reads both weeks from canonical sales without duplicating bank collections',
    () async {
      final source = await loadAccountingWeeklySource(DateTime(2026, 9, 18));
      final report = AccountingWeeklyAnalysis(source);
      expect(report.current.result, 400);
      expect(report.previous.result, 400);
      final now = source.currentStatement.snapshot;
      expect(now.revenue, 1200); // Mayoreo 1000 + ticket Menudeo 200.
      expect(now.otherIncome, 10);
      expect(now.commercialCost, 350);
      expect(now.recognizedExpenses, 130);
      expect(now.commercialResult, 850);
      expect(now.periodResult, 730);
      expect(now.isComplete, isFalse);
      expect(now.resultLabel, contains('provisional'));
      expect(source.previousStatement.snapshot.revenue, 910);
      expect(source.previousStatement.snapshot.periodResult, 620);
      final query = requests
          .singleWhere(
            (r) => r.url.pathSegments.last == 'v_commercial_market_events',
          )
          .url
          .queryParametersAll;
      expect(query['event_at'], [
        'gte.${source.cut.previous.start.toUtc().toIso8601String()}',
        'lt.${DateTime(2026, 9, 19).toUtc().toIso8601String()}',
      ]);
      expect(query['order']!.single, contains('source_event_id'));
    },
  );

  test(
    'commercial, bank, vault and voucher detail pagination include rows beyond server pages',
    () async {
      dense = true;
      final source = await loadAccountingWeeklySource(DateTime(2026, 9, 18));
      expect(source.events, hasLength(1005));
      expect(
        source.currentStatement.snapshot.revenue,
        2010,
      ); // Canonical sales only; cash remains pending.
      expect(source.previousStatement.snapshot.revenue, 0);
      for (final table in [
        'v_commercial_market_events',
        'finanzas_bank_movements',
        'direction_vault_vouchers',
        'direction_vault_voucher_lines',
      ]) {
        expect(
          requests.any(
            (r) =>
                r.url.pathSegments.last == table &&
                r.url.queryParameters['offset'] ==
                    (table == 'v_commercial_market_events' ? '500' : '1000'),
          ),
          isTrue,
          reason: table,
        );
      }
    },
  );

  test('any source failure prevents a false zero report', () async {
    for (final table in [
      'v_commercial_market_events',
      'finanzas_bank_movements',
      'direction_vault_vouchers',
      'men_tickets',
      'inventory_movements_v2',
    ]) {
      failTable = table;
      await expectLater(
        loadAccountingWeeklySource(DateTime(2026, 9, 18)),
        throwsA(anyOf(isA<PostgrestException>(), isA<StateError>())),
      );
    }
  });

  test(
    'central Friday generator dispatches the two agreed accounting reports',
    () async {
      final area = managementAreaDefinition(ManagementAreaKey.contabilidad);
      expect(area.reports.map((r) => r.key), [
        'accounting_trade_result',
        'accounting_income_statement',
      ]);
      final bytes = await buildManagementReportPdfBytes(
        area: area,
        frequency: ManagementReportFrequency.weeklyFriday,
        generatedAt: DateTime(2026, 9, 18),
        generatedBy: 'Prueba',
      );
      expect(bytes.take(4), [37, 80, 68, 70]);
      expect(
        requests.any(
          (r) => r.url.pathSegments.last == 'v_commercial_market_events',
        ),
        isTrue,
      );
      expect(
        requests.any(
          (r) => r.url.pathSegments.last == 'finanzas_bank_movements',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'accounting dashboard links to supervision with both weekly comparisons',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: ContabilidadDashboardPage(instantOpen: true)),
      );
      await tester.pumpAndSettle();
      final hub = find.widgetWithText(OutlinedButton, 'Hub');
      await tester.ensureVisible(hub);
      await tester.tap(hub);
      await tester.pumpAndSettle();
      expect(find.byType(ManagementSupervisionPage), findsOneWidget);
      expect(
        find.textContaining('Resultado comercial · semana vs anterior'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Estado de resultados · semana vs anterior'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
