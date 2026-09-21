import 'dart:convert';

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
  Map<String, dynamic> bank(
    String id,
    String category,
    num credit,
    num debit, {
    String date = '2026-09-15',
    String counterparty = '',
  }) => {
    'id': id,
    'movement_date': date,
    'category': category,
    'credit_amount': credit,
    'debit_amount': debit,
    'counterparty_name_snapshot': counterparty,
  };
  Map<String, dynamic> voucher(
    String id,
    String type,
    String rubric,
    num amount, {
    String date = '2026-09-15',
  }) => {
    'id': id,
    'voucher_date': date,
    'voucher_type': type,
    'rubric': rubric,
    'total_amount': amount,
  };
  Map<String, dynamic> market(
    String id,
    String flow,
    num amount, {
    String date = '2026-09-15',
  }) => {
    'source_event_id': id,
    'source_area': 'menudeo',
    'channel': 'menudeo',
    'event_at': date,
    'flow': flow,
    'general_material_key': 'CARTON',
    'general_material_label': 'Cartón',
    'volume_kg': 100,
    'amount_total': amount,
  };
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
        List<Map<String, dynamic>> rows;
        switch (table) {
          case 'v_commercial_market_events':
            rows = dense
                ? [for (var i = 0; i < 505; i++) market('e$i', 'purchase', 1)]
                : [
                    market('buy', 'purchase', 500),
                    market('sell', 'sale', 900),
                    market('oldbuy', 'purchase', 300, date: '2026-09-08'),
                    market('oldsell', 'sale', 700, date: '2026-09-08'),
                  ];
          case 'finanzas_bank_movements':
            rows = dense
                ? [for (var i = 0; i < 505; i++) bank('b$i', 'VENTAS', 2, 0)]
                : [
                    bank('sales', 'VENTAS', 1000, 0),
                    bank('buys', 'COMPRA DE MATERIAL', 0, 300),
                    bank('expense', 'GASTOS OPERATIVOS', 0, 100),
                    bank('internal', 'MOVIMIENTOS INTERNOS', 500, 0),
                    bank(
                      'transfer',
                      'OTROS',
                      0,
                      75,
                      counterparty: 'CHEQUE A BOVEDA',
                    ),
                    bank('prior-sale', 'VENTAS', 800, 0, date: '2026-09-08'),
                    bank(
                      'prior-buy',
                      'COMPRA DE MATERIAL',
                      0,
                      250,
                      date: '2026-09-08',
                    ),
                    bank(
                      'prior-expense',
                      'GASTOS OPERATIVOS',
                      0,
                      40,
                      date: '2026-09-08',
                    ),
                    bank('weekend', 'VENTAS', 99999, 0, date: '2026-09-12'),
                  ];
          case 'direction_vault_vouchers':
            rows = dense
                ? [
                    for (var i = 0; i < 505; i++)
                      voucher('v$i', 'deposit', 'Venta de material', 1),
                  ]
                : [
                    voucher('v1', 'deposit', 'Venta de material', 20),
                    voucher('v2', 'expense', 'Gastos operativos', 10),
                    voucher('v3', 'deposit', 'Cheque', 75),
                    voucher(
                      'v4',
                      'deposit',
                      'Venta de material',
                      10,
                      date: '2026-09-08',
                    ),
                  ];
          case 'direction_vault_voucher_lines':
            final ids = r.url.queryParameters['voucher_id']!
                .substring(3)
                .replaceAll(RegExp(r'[()"]'), '')
                .split(',');
            rows = dense
                ? [
                    for (final id in ids)
                      for (var i = 0; i < (id == 'v0' ? 501 : 1); i++)
                        {'id': '$id-line-$i', 'voucher_id': id, 'amount': 1},
                  ]
                : [
                    for (final entry in {
                      'v1': 20,
                      'v2': 10,
                      'v3': 75,
                      'v4': 10,
                    }.entries)
                      if (ids.contains(entry.key))
                        {
                          'id': '${entry.key}-line',
                          'voucher_id': entry.key,
                          'amount': entry.value,
                        },
                  ];
          case 'cash_taxonomy_configs':
            rows = [
              {
                'payload': {
                  'rows': dense
                      ? []
                      : [
                          {
                            'id': 'v1',
                            'date': '2026-09-15',
                            'type': 'deposit',
                            'rubric': 'Venta de material',
                            'lines': [
                              {'amount': 99999},
                            ],
                          },
                          {
                            'id': 'legacy',
                            'date': '2026-09-15',
                            'type': 'deposit',
                            'rubric': 'Venta de material',
                            'lines': [
                              {'amount': 30},
                            ],
                          },
                        ],
                },
              },
            ];
          case 'vw_men_cash_vouchers_grid':
            rows = dense
                ? []
                : [
                    voucher('m1', 'deposit', 'Venta de material', 150),
                    voucher('m2', 'expense', 'Compra de material', 50),
                    voucher('m3', 'expense', 'Gastos operativos', 20),
                    voucher('m4', 'deposit', 'Otros', 10),
                    voucher('m5', 'deposit', 'Reposición de fondo', 9999),
                    voucher(
                      'm6',
                      'deposit',
                      'Venta de material',
                      100,
                      date: '2026-09-08',
                    ),
                  ];
          case 'vw_men_cash_cuts_grid':
          case 'men_cash_voucher_lines':
          case 'profiles':
            rows = [];
          default:
            throw StateError('Unexpected source: $table');
        }
        final offset = int.tryParse(r.url.queryParameters['offset'] ?? '') ?? 0;
        final limit =
            int.tryParse(r.url.queryParameters['limit'] ?? '') ?? rows.length;
        return http.Response(
          jsonEncode(rows.skip(offset).take(limit).toList()),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
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
    'reads both weeks from real accounting rules with no duplicate legacy or internal transfers',
    () async {
      final source = await loadAccountingWeeklySource(DateTime(2026, 9, 18));
      final report = AccountingWeeklyAnalysis(source);
      expect(report.current.result, 400);
      expect(report.previous.result, 400);
      final now = source.currentStatement.snapshot;
      expect(
        now.revenue,
        1200,
      ); // Bank 1000 + vault 20 + legacy 30 + menudeo 150.
      expect(now.otherIncome, 10);
      expect(now.commercialCost, 350);
      expect(now.recognizedExpenses, 130);
      expect(now.commercialResult, 860);
      expect(now.periodResult, 730);
      expect(now.internalExcluded, 75);
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
      expect(source.events, hasLength(505));
      expect(
        source.currentStatement.snapshot.revenue,
        2015,
      ); // Bank 1010 + vault 1005.
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
                r.url.queryParameters['offset'] == '500',
          ),
          isTrue,
          reason: table,
        );
      }
    },
  );

  test(
    'source failure, including legacy cash, prevents a false zero report',
    () async {
      for (final table in [
        'v_commercial_market_events',
        'finanzas_bank_movements',
        'direction_vault_vouchers',
        'cash_taxonomy_configs',
        'vw_men_cash_vouchers_grid',
      ]) {
        failTable = table;
        await expectLater(
          loadAccountingWeeklySource(DateTime(2026, 9, 18)),
          throwsA(isA<PostgrestException>()),
        );
      }
    },
  );

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
