import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';
import 'package:dicsa_operacion/app/contabilidad/contabilidad_pdf_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rows = <String, List<Map<String, dynamic>>>{};
  final requests = <http.Request>[];
  final range = DateTimeRange(
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 31),
  );
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://statement-base.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        expect(r.method, 'GET');
        final table = r.url.pathSegments.last;
        if (!rows.containsKey(table)) {
          throw StateError('Unexpected source: $table');
        }
        var selected = rows[table]!;
        for (final filter in r.url.queryParameters.entries) {
          if (filter.value.startsWith('in.(')) {
            final ids = filter.value
                .substring(4, filter.value.length - 1)
                .split(',')
                .map((s) => s.replaceAll('"', ''))
                .toSet();
            selected = selected
                .where((v) => ids.contains(v[filter.key].toString()))
                .toList();
          }
        }
        final offset = int.tryParse(r.url.queryParameters['offset'] ?? '') ?? 0;
        final limit =
            int.tryParse(r.url.queryParameters['limit'] ?? '') ??
            selected.length;
        return http.Response(
          jsonEncode(selected.skip(offset).take(limit).toList()),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    rows.clear();
    for (final name in [
      'finanzas_bank_movements',
      'direction_vault_vouchers',
      'direction_vault_voucher_lines',
      'cash_taxonomy_configs',
      'vw_men_cash_vouchers_grid',
      'vw_men_cash_cuts_grid',
      'men_cash_voucher_lines',
    ]) {
      rows[name] = [];
    }
  });
  Future<ContabilidadIncomeStatementDataset> load() =>
      const ContabilidadIncomeStatementStore().loadSimplified(
        windowDays: 31,
        dateRange: range,
      );
  Map<String, dynamic> bank(
    String id,
    String category,
    double credit,
    double debit, {
    String day = '2026-10-05',
    String party = '',
  }) => {
    'id': id,
    'movement_date': day,
    'category': category,
    'credit_amount': credit,
    'debit_amount': debit,
    'counterparty_name_snapshot': party,
  };
  test(
    'base preserves captured categories, excludes internal funding and reconciles its breakdown',
    () async {
      rows['finanzas_bank_movements'] = [
        bank('sale', 'VENTAS', 1000, 0),
        bank('purchase', 'COMPRA DE MATERIAL', 0, 400),
        bank('expense', 'GASTOS OPERATIVOS', 0, 100),
        bank('other', 'OTROS', 30, 0),
        bank('internal', 'MOVIMIENTOS INTERNOS', 500, 0),
        bank('old', 'VENTAS', 9000, 0, day: '2026-09-30'),
        bank('cheque', 'OTROS', 0, 500, party: 'CHEQUE 20'),
      ];
      rows['direction_vault_vouchers'] = [
        {
          'id': 'v',
          'voucher_date': '2026-10-05',
          'voucher_type': 'deposit',
          'rubric': 'Cheque',
        },
      ];
      rows['direction_vault_voucher_lines'] = [
        {'id': 'vl', 'voucher_id': 'v', 'amount': 500},
      ];
      rows['vw_men_cash_vouchers_grid'] = [
        for (final id in ['c1', 'c2'])
          {
            'id': id,
            'voucher_date': '2026-10-05',
            'voucher_type': 'expense',
            'rubric': 'Operativo',
            'total_amount': 25,
          },
        {
          'id': 'fund',
          'voucher_date': '2026-10-05',
          'voucher_type': 'deposit',
          'rubric': 'Reposicion de fondo',
          'total_amount': 300,
        },
      ];
      final a = await load();
      expect(a.snapshot.revenue, 1000);
      expect(a.snapshot.commercialCost, 400);
      expect(a.snapshot.otherIncome, 30);
      expect(a.snapshot.recognizedExpenses, 150);
      expect(a.snapshot.periodResult, 480);
      expect(a.snapshot.internalExcluded, 500);
      expect(
        a.lines.fold<double>(0, (s, l) => l.emphasis ? s : s + l.amount),
        480,
      );
      expect(a.expenseBreakdown.fold<double>(0, (s, r) => s + r.amount), 150);
      expect(
        a.expenseBreakdown.singleWhere((r) => r.sourceLabel == 'Menudeo').count,
        2,
      );
      expect(a.recognition, isNull);
      expect(a.snapshot.resultLabel, 'Resultado base');
      expect(a.snapshot.isComplete, isFalse);
      expect(
        requests.any((r) => r.url.path.contains('accounting_statement')),
        isFalse,
      );
      final out = Platform.environment['DICSA_BASE_ARTIFACTS'];
      if (out != null) {
        await File(
          '$out/base_prueba.pdf',
        ).writeAsBytes(await buildContabilidadIncomeStatementPdf(statement: a));
      }
    },
  );
  test(
    'base reads beyond the first page and does not migrate legacy records',
    () async {
      rows['finanzas_bank_movements'] = [
        for (var i = 0; i < 1005; i++) bank('b$i', 'VENTAS', 2, 0),
      ];
      rows['cash_taxonomy_configs'] = [
        {
          'payload': {'rows': []},
        },
      ];
      final a = await load();
      expect(a.snapshot.revenue, 2010);
      expect(
        requests
            .where((r) => r.url.path.endsWith('finanzas_bank_movements'))
            .length,
        3,
      );
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    },
  );
}
