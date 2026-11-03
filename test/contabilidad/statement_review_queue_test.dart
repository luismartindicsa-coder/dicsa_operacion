import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_review_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final period = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
  test(
    'captured categories and closure coverage do not become missing data',
    () {
      final a = analyzeStatement(
        StatementBundle(
          period: period,
          tables: {
            'finanzas_bank_movements': [
              {
                'id': 'tax',
                'movement_date': '2026-10-05',
                'category': 'GASTOS ADMINISTRATIVOS',
                'debit_amount': 50,
                'comment': 'IVA',
              },
            ],
            'maintenance_purchase_orders': [
              {
                'id': 'po',
                'order_date': '2026-10-05',
                'status': 'purchased',
                'actual_total': 90,
              },
            ],
            'services': [
              {'id': 'service', 'service_date': '2026-10-05'},
            ],
            'mayoreo_sales_reports': [
              {'id': 'sale', 'sale_date': '2026-10-05', 'ticket': '7'},
            ],
          },
        ),
      );
      final before = a.toSnapshot();
      final queue = statementReviewQueue(a);
      final clarify = queue.where((c) => c.lane == StatementReviewLane.clarify);
      expect(clarify.map((c) => c.id), ['sale:sale']);
      expect(
        queue.expand((c) => c.entries).map((e) => e.fact.id).toSet(),
        a.pending.map((e) => e.fact.id).toSet(),
      );
      expect(a.toSnapshot(), before);
      expect(a.complete, isFalse);
    },
  );

  StatementAnalysis coins({bool ambiguous = false}) => analyzeStatement(
    StatementBundle(
      period: period,
      tables: {
        'direction_vault_vouchers': [
          for (final id in ['v', if (ambiguous) 'v2'])
            {
              'id': id,
              'voucher_date': '2026-10-06',
              'voucher_type': 'deposit',
              'rubric': 'Otro',
              'comment': 'OSCAR A MARY MONEDAS',
              'total_amount': 3300,
            },
        ],
        'men_cash_vouchers': [
          {
            'id': 'c',
            'voucher_date': '2026-10-06',
            'voucher_type': 'expense',
            'rubric': 'Operativo',
            'comment': 'CAMBIO POR MONEDAS',
            'total_amount': 3300,
          },
        ],
      },
    ),
  );
  test(
    'related cash documents form one case without being settled or summed',
    () {
      final a = coins();
      final queue = statementReviewQueue(a);
      expect(queue, hasLength(1));
      expect(queue.single.entries, hasLength(2));
      expect(queue.single.relation, contains('Confirmar relación'));
      expect(a.pending, hasLength(2));
      expect(a.result, 0);
      expect(a.complete, isFalse);
    },
  );
  test('ambiguous equal cash movements remain separate', () {
    final queue = statementReviewQueue(coins(ambiguous: true));
    expect(queue, hasLength(3));
    expect(queue.every((c) => !c.grouped), isTrue);
  });
  test('a changed saved review still requires attention', () {
    final b = StatementBundle(
      period: period,
      tables: {
        'finanzas_bank_movements': [
          {
            'id': 'b',
            'movement_date': '2026-10-05',
            'category': 'GASTOS OPERATIVOS',
            'debit_amount': 100,
          },
        ],
      },
      decisions: {
        'bank:b': StatementDecision(
          id: 'bank:b',
          signature: 'a' * 64,
          note: 'Revisado antes del cambio',
          account: StatementAccount.operating,
          amount: 90,
        ),
      },
    );
    final a = analyzeStatement(b);
    final queue = statementReviewQueue(a);
    expect(queue.single.lane, StatementReviewLane.clarify);
    expect(queue.single.entries.single.issue, isNotNull);
    expect(b.decisions['bank:b']!.amount, 90);
  });

  test(
    'saved October snapshot preserves every review and its result',
    () {
      final root = Platform.environment['DICSA_REVIEW_SNAPSHOT']!;
      final tables = <String, List<StatementRow>>{};
      for (final f in Directory('$root/raw').listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        tables[f.uri.pathSegments.last.replaceAll(
          '.json',
          '',
        )] = (jsonDecode(f.readAsStringSync()) as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
      }
      final a = analyzeStatement(
        StatementBundle(period: period, tables: tables),
      );
      final before =
          jsonDecode(File('$root/resultado_octubre.json').readAsStringSync())
              as Map;
      final queue = statementReviewQueue(a);
      expect(a.result, closeTo((before['result'] as num).toDouble(), .005));
      expect(a.pending.length, before['pending_count']);
      expect(
        queue.expand((c) => c.entries).map((e) => e.fact.id).toSet(),
        a.pending.map((e) => e.fact.id).toSet(),
      );
      // ignore: avoid_print
      print(
        'October review lanes: ${StatementReviewLane.values.map((l) => '${l.name}=${queue.where((c) => c.lane == l).length}').join(', ')}; '
        'grouped=${queue.where((c) => c.grouped).length}; documents=${a.pending.length}; result=${a.result}',
      );
    },
    skip: Platform.environment['DICSA_REVIEW_SNAPSHOT'] == null,
  );
}
