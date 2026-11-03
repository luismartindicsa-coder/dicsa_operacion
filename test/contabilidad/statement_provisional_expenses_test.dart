import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_review_topics.dart';
import 'package:flutter_test/flutter_test.dart';

final october = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
Map<String, List<StatementRow>> sources() => {
  'men_cash_vouchers': [
    {
      'id': 'v',
      'voucher_type': 'expense',
      'voucher_date': '2026-10-02',
      'rubric': 'Nomina',
      'comment': 'FINIQUITO JUAN PEREZ',
      'total_amount': 1000,
    },
  ],
  'men_cash_voucher_lines': [
    {'id': 'l', 'voucher_id': 'v', 'concept': 'Empresa', 'amount': 1000},
  ],
};
StatementAnalysis analyze(
  Map<String, List<StatementRow>> tables, {
  Map<String, StatementDecision> decisions = const {},
}) => analyzeStatement(
  StatementBundle(period: october, tables: tables, decisions: decisions),
);
void main() {
  test(
    'known expenditure reduces provisional result while review stays open',
    () {
      final a = analyze(sources());
      final e = a.entries.single;
      expect(e.pending, isTrue);
      expect(e.includedPending, isTrue);
      expect(e.account, StatementAccount.payroll);
      expect(e.estimated, isTrue);
      expect(a.result, -1000);
      expect(a.complete, isFalse);
      expect(
        a.toSnapshot()['entries'],
        contains(
          allOf(
            containsPair('pending', true),
            containsPair('included_pending', true),
            containsPair('account', 'payroll'),
          ),
        ),
      );
      expect(
        statementReviewTopics(a)[StatementReviewTopic.payroll],
        hasLength(1),
      );
    },
  );
  test('review replaces the estimate instead of adding another expense', () {
    final t = sources();
    final e = analyze(t).entries.single;
    final d = StatementDecision(
      id: e.fact.id,
      signature: e.fact.signature,
      account: StatementAccount.payroll,
      amount: 800,
      note: '800 devengados; 200 anticipo',
    );
    final a = analyze(t, decisions: {d.id: d});
    expect(a.result, -800);
    expect(a.pending, isEmpty);
    expect(a.entries.single.estimated, isFalse);
    t['men_cash_vouchers']!.single['total_amount'] = 1100;
    t['men_cash_voucher_lines']!.single['amount'] = 1100;
    final changed = analyze(t, decisions: {d.id: d});
    expect(changed.pending, hasLength(1));
    expect(changed.entries.single.issue, isNotNull);
    expect(
      changed.result,
      0,
    ); // Stale reviewed evidence must not silently apply.
  });
  test(
    'personal, advance, future service and duplicate evidence never become current expense',
    () {
      for (final text in [
        'ANTICIPO FINIQUITO',
        'FINIQUITO NOVIEMBRE 2026',
        'DINERO PARA NOMINA',
      ]) {
        final t = sources();
        t['men_cash_vouchers']!.single['comment'] = text;
        expect(analyze(t).result, 0, reason: text);
      }
      final t = sources();
      t['men_cash_vouchers']!.single['rubric'] = 'Personales';
      expect(analyze(t).result, 0);
      final duplicate = sources();
      duplicate['finanzas_supplier_invoices'] = [
        {
          'id': 'i',
          'invoice_date': '2026-10-02',
          'provider_name_snapshot': 'JUAN PEREZ',
          'total_amount': 1000,
        },
      ];
      expect(analyze(duplicate).result, 0);
    },
  );
  test('every unresolved operation stays in exactly one review topic', () {
    final t = sources();
    t['finanzas_bank_movements'] = [
      {
        'id': 'b',
        'movement_date': '2026-10-03',
        'debit_amount': 50,
        'credit_amount': 0,
        'category': 'IMPUESTOS',
        'reference': 'ISR',
      },
    ];
    final a = analyze(t);
    final topics = statementReviewTopics(a);
    expect(
      topics.values.expand((x) => x).map((e) => e.fact.id).toSet(),
      a.pending.map((e) => e.fact.id).toSet(),
    );
    expect(
      topics.values.fold<int>(0, (n, v) => n + v.length),
      a.pending.length,
    );
    expect(topics[StatementReviewTopic.taxes], hasLength(1));
  });
}
