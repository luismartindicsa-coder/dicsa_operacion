import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:flutter_test/flutter_test.dart';

final october = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
Map<String, List<StatementRow>> cash({
  String concept = 'Bascula',
  String comment = 'Báscula folio 544',
  String rubric = 'Operativo',
  String type = 'expense',
}) => {
  'men_cash_vouchers': [
    {
      'id': 'v',
      'voucher_date': '2026-10-01',
      'voucher_type': type,
      'folio': '1',
      'person_label': 'JUAN PEREZ',
      'rubric': rubric,
      'comment': comment,
      'total_amount': 100,
    },
  ],
  'men_cash_voucher_lines': [
    {'id': 'l', 'voucher_id': 'v', 'concept': concept, 'amount': 100},
  ],
};
StatementRow weighing(String id, {dynamic price = 80}) => {
  'id': id,
  'fecha': '2026-10-01',
  'ticket': id,
  'proveedor': 'PUBLICO',
  'precio': price,
};
StatementAnalysis analyze(
  Map<String, List<StatementRow>> tables, {
  Map<String, StatementDecision> decisions = const {},
  StatementPeriod? period,
}) => analyzeStatement(
  StatementBundle(
    period: period ?? october,
    tables: tables,
    decisions: decisions,
  ),
);

void main() {
  test(
    'ordinary administrative vouchers are expenses; assets and taxes remain pending',
    () {
      for (final concept in [
        'Recarga',
        'Papeleria',
        'Honorarios Abogado',
        'Comisiones',
      ]) {
        final a = analyze(
          cash(
            rubric: 'Administrativo',
            concept: concept,
            comment: concept == 'Comisiones'
                ? 'Pago a técnico de computadora'
                : concept,
          ),
        );
        expect(a.total(StatementAccount.administrative), 100, reason: concept);
        expect(a.total(StatementAccount.operating), 0);
      }
      for (final concept in [
        'Remodelacion',
        'Impuestos',
        'Nomina',
        'Desconocido',
      ]) {
        expect(
          analyze(
            cash(rubric: 'Administrativo', concept: concept, comment: concept),
          ).pending,
          hasLength(1),
          reason: concept,
        );
      }
      expect(
        analyze(
          cash(
            rubric: 'Administrativo',
            concept: 'Papeleria',
            comment: 'Anticipo 50%',
          ),
        ).pending,
        hasLength(1),
      );
    },
  );

  test(
    'ordinary additional expense is recognized independently of commercial tickets',
    () {
      final t = cash();
      t['men_tickets'] = [
        {
          'id': 'ticket',
          'ticket_date': '2026-10-01',
          'direction': 'COMPRA',
          'amount_total': 500,
          'net_weight': 50,
        },
      ];
      final a = analyze(t);
      expect(a.total(StatementAccount.operating), 100);
      expect(a.total(StatementAccount.balance), 500);
      expect(a.automaticCount, 1);
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'cash:v').automatic,
        isTrue,
      );
      expect(
        a.toSnapshot()['entries'],
        contains(
          containsPair('automatic_rule', 'retail_additional_operating_v1'),
        ),
      );
      expect(a.complete, isFalse); // Rules do not certify a closing.
    },
  );
  test('service and collection recognize revenue once even across months', () {
    final t = cash(
      concept: 'Ingreso',
      rubric: 'Pesadas',
      type: 'deposit',
      comment: 'Pesadas semana',
    );
    t['pesadas'] = [weighing('service', price: 100)];
    expect(analyze(t).result, 100);
    t['men_cash_vouchers']!.single['voucher_date'] = '2026-11-01';
    t['men_cash_vouchers']!.single['total_amount'] = 130;
    t['men_cash_voucher_lines']!.single['amount'] = 130;
    expect(analyze(t).result, 100);
    final november = analyze(
      t,
      period: StatementPeriod(DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
    );
    expect(november.result, 0);
    expect(november.total(StatementAccount.balance), 130);
    expect(
      november.entries.single.fact.detail,
      contains('no prueba la coincidencia'),
    );
  });
  test(
    'zero price is explicit; missing, negative or incomplete service is pending',
    () {
      final a = analyze({
        'pesadas': [
          weighing('free', price: 0),
          weighing('missing', price: null),
          weighing('invalid', price: 'not a price'),
          weighing('negative', price: -80),
          {...weighing('no-counterparty'), 'proveedor': ''},
          {...weighing('undated'), 'fecha': null},
        ],
      });
      expect(a.pending, hasLength(5));
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'weighing:free').account,
        StatementAccount.balance,
      );
      expect(a.result, 0);
    },
  );
  test(
    'duplicated tickets and duplicated voucher folios require explicit resolution',
    () {
      final t = cash();
      t['men_cash_vouchers']!.add({
        ...t['men_cash_vouchers']!.single,
        'id': 'v2',
      });
      t['men_cash_voucher_lines']!.add({
        ...t['men_cash_voucher_lines']!.single,
        'id': 'l2',
        'voucher_id': 'v2',
      });
      t['pesadas'] = [
        weighing('w'),
        {...weighing('w'), 'id': 'w2'},
      ];
      final a = analyze(t);
      expect(a.pending, hasLength(4));
      expect(a.result, 0);
      expect(a.automaticCount, 0);
      expect(a.entries.every((e) => e.fact.references.isNotEmpty), isTrue);
    },
  );
  test('contradictions, vague commissions and assets remain exceptions', () {
    for (final note in [
      'DINERO DE NOMINA',
      'ANTICIPO DE GRATIFICACIONES',
      'PRESTAMO',
      'PAGO DE FACTURA 234',
      'OC-123',
      'MITAD DE SU TICKET',
      'VENTAS ENTREGADAS EN EFECTIVO',
      'CAMBIO POR MONEDAS',
      'DINERO PARA JUAN',
      '20 pesos',
      'PAGO A JUAN SOLIS',
      'GASTOS POR COMPROBAR',
      'COMPRA DE MAQUINARIA',
      'IVA 16%',
      'COMPRA DE TORNILLOS FUERON EN TOTAL 5432',
    ]) {
      final a = analyze(cash(concept: 'Comisiones', comment: note));
      expect(a.pending, hasLength(1), reason: note);
      expect(a.result, 0, reason: note);
    }
    expect(
      analyze(cash(concept: 'Equipo', comment: 'Compra de equipo')).pending,
      hasLength(1),
    );
    expect(analyze(cash(rubric: 'Administrativo')).pending, hasLength(1));
    expect(
      analyze(
        cash(concept: 'Comisiones', comment: 'Comision deposito de Juan'),
      ).result,
      -100,
    );
  });
  test('every line must reconcile and have an eligible concept', () {
    final t = cash();
    t['men_cash_voucher_lines']!.single['amount'] = 99;
    expect(analyze(t).pending, hasLength(1));
    t['men_cash_voucher_lines']!.single['amount'] = 40;
    t['men_cash_voucher_lines']!.add({
      'id': 'other',
      'voucher_id': 'v',
      'concept': 'TRANSFERENCIA',
      'amount': 60,
    });
    expect(analyze(t).result, 0);
    expect(analyze(t).pending, hasLength(1));
    t['men_cash_voucher_lines']!.clear();
    expect(analyze(t).pending, hasLength(1));
    t['men_cash_voucher_lines']!.add({
      'id': 'other',
      'voucher_id': 'v',
      'concept': 'Bascula',
      'amount': null,
    });
    expect(analyze(t).pending, hasLength(1));
  });
  test(
    'amount alone never creates a match; corroborating documents block automatic expense',
    () {
      final t = cash();
      t['finanzas_supplier_invoices'] = [
        {
          'id': 'i',
          'invoice_date': '2026-09-30',
          'total_amount': 100,
          'provider_name_snapshot': 'OTRO PROVEEDOR',
        },
      ];
      expect(analyze(t).total(StatementAccount.operating), 100);
      final original = analyze(
        t,
      ).entries.singleWhere((e) => e.fact.id == 'cash:v');
      final reviewed = StatementDecision(
        id: original.fact.id,
        signature: original.fact.signature,
        note: 'Comprobante verificado',
        account: StatementAccount.operating,
        amount: 100,
      );
      t['finanzas_supplier_invoices']!.single['provider_name_snapshot'] =
          'JUAN PEREZ';
      final a = analyze(t, decisions: {reviewed.id: reviewed});
      final e = a.entries.singleWhere((e) => e.fact.id == reviewed.id);
      expect(e.pending, isTrue);
      expect(e.fact.references, ['invoice:i']);
      expect(e.issue, contains('Cambió la fuente'));
      t['finanzas_supplier_invoices']!.single['invoice_date'] = '2026-09-01';
      expect(analyze(t).total(StatementAccount.operating), 100);
    },
  );
  test(
    'maintenance, bank and vault matches also prevent duplicate recognition',
    () {
      final t = cash();
      t['maintenance_purchase_orders'] = [
        {
          'id': 'po',
          'order_date': '2026-09-30',
          'actual_total': 100,
          'quote_vendor_name': 'JUAN PEREZ',
          'status': 'purchased',
        },
      ];
      t['finanzas_bank_movements'] = [
        {
          'id': 'b',
          'movement_date': '2026-10-02',
          'debit_amount': 100,
          'counterparty_name_snapshot': 'JUAN PEREZ',
        },
      ];
      t['direction_vault_vouchers'] = [
        {
          'id': 'vv',
          'voucher_date': '2026-10-03',
          'voucher_type': 'expense',
          'total_amount': 100,
          'person_label': 'JUAN PEREZ',
        },
      ];
      final e = analyze(t).entries.singleWhere((e) => e.fact.id == 'cash:v');
      expect(e.pending, isTrue);
      expect(e.fact.references, ['bank:b', 'po:po', 'vault:vv']);
    },
  );
  test(
    'manual review overrides automation and changed source invalidates the review',
    () {
      final t = cash();
      final initial = analyze(t).entries.single;
      final d = StatementDecision(
        id: initial.fact.id,
        signature: initial.fact.signature,
        note: 'Reembolso del anticipo',
        account: StatementAccount.balance,
        amount: 100,
      );
      final reviewed = analyze(t, decisions: {d.id: d});
      expect(reviewed.result, 0);
      expect(reviewed.automaticCount, 0);
      expect(reviewed.entries.single.decision, d);
      t['men_cash_vouchers']!.single['comment'] = 'Dato corregido';
      final changed = analyze(t, decisions: {d.id: d});
      expect(changed.entries.single.pending, isTrue);
      expect(changed.automaticCount, 0);
    },
  );
  test(
    'old closing signature cannot certify the updated recognition policy',
    () {
      final a = analyze({});
      final old = stSignature({
        'engine': 1,
        'period': october.key,
        'entries': [],
        'warnings': [],
      });
      final oldClosing = StatementClosing(
        signature: old,
        note: 'Cierre previo',
        checks: statementClosingChecks.keys.toSet(),
        snapshot: {...a.toSnapshot(), 'source_signature': old},
      );
      expect(
        analyzeStatement(
          StatementBundle(period: october, tables: {}, closing: oldClosing),
        ).complete,
        isFalse,
      );
    },
  );
}
