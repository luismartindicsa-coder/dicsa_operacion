import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:flutter_test/flutter_test.dart';

final october = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
StatementBundle bundle(
  Map<String, List<StatementRow>> tables, {
  Map<String, StatementDecision> decisions = const {},
  StatementClosing closing = const StatementClosing(),
  StatementPeriod? period,
}) => StatementBundle(
  period: period ?? october,
  tables: tables,
  decisions: decisions,
  closing: closing,
);
StatementRow sale(String id, {double amount = 800}) => {
  'id': id,
  'sale_date': '2026-10-01T00:00:00+00:00',
  'ticket': id,
  'material_id': 'sell-carton',
  'material_name_snapshot': 'Paca',
  'approved_amount': amount,
  'approved_weight': 50,
  'approved_price': amount / 50,
};
Map<String, List<StatementRow>> materialSources() => {
  'material_general_catalog_v2': [
    {'id': 'carton', 'name': 'Cartón'},
  ],
  'compras_material_catalog': [
    {'id': 'buy-carton', 'name': 'Suelto', 'general_material_id': 'carton'},
  ],
  'mayoreo_material_catalog': [
    {'id': 'sell-carton', 'name': 'Paca', 'general_material_id': 'carton'},
  ],
  'compras_tickets': [
    {
      'id': 'p1',
      'ticket_date': '2026-10-01',
      'ticket_number': '1',
      'material_id': 'buy-carton',
      'net_weight': 100,
      'amount': 1000,
    },
  ],
  'mayoreo_sales_reports': [sale('s1')],
  'inventory_movements_v2': [
    {
      'id': 'in',
      'op_date': '2026-10-01',
      'inventory_level': 'GENERAL',
      'flow': 'IN',
      'origin_type': 'DIRECT_PURCHASE',
      'general_material_id': 'carton',
      'weight_kg': 100,
    },
    {
      'id': 'out',
      'op_date': '2026-10-01',
      'inventory_level': 'COMMERCIAL',
      'flow': 'OUT',
      'origin_type': 'SALE',
      'general_material_id': 'carton',
      'weight_kg': 50,
    },
    {
      'id': 'transform-in',
      'op_date': '2026-10-01',
      'inventory_level': 'COMMERCIAL',
      'flow': 'IN',
      'origin_type': 'TRANSFORMATION',
      'general_material_id': 'carton',
      'weight_kg': 100,
    },
    {
      'id': 'transform-out',
      'op_date': '2026-10-01',
      'inventory_level': 'GENERAL',
      'flow': 'OUT',
      'origin_type': 'TRANSFORMATION',
      'general_material_id': 'carton',
      'weight_kg': 100,
    },
    {
      'id': 'scrap',
      'op_date': '2026-10-01',
      'inventory_level': 'GENERAL',
      'flow': 'IN',
      'origin_type': 'TRANSFORMATION',
      'movement_reason': 'SCRAP_SEPARATION',
      'general_material_id': 'carton',
      'weight_kg': 20,
    },
  ],
  'inventory_opening_balances_v2': [
    {'weight_kg': 999999999},
  ], // must never be consumed
};
Map<String, List<StatementRow>> conversionSources() => {
  'finanzas_bank_movements': [
    {
      'id': 'b',
      'movement_date': '2026-10-30T00:00:00+00:00',
      'debit_amount': 156000,
      'credit_amount': 0,
      'linked_supplier_invoice_id': 'i',
      'counterparty_name_snapshot': 'MARICRUZ QUIROGA ACOSTA',
    },
  ],
  'direction_vault_vouchers': [
    {
      'id': 'v',
      'voucher_date': '2026-10-30',
      'voucher_type': 'deposit',
      'total_amount': 150000,
      'rubric': 'Venta de material',
      'person_label': 'BIANCA',
    },
  ],
  'finanzas_supplier_invoices': [
    {
      'id': 'i',
      'invoice_date': '2026-10-30',
      'invoice_folio': '160',
      'total_amount': 156000,
    },
  ],
  'finanzas_supplier_invoice_tickets': [
    {'id': 'l', 'invoice_id': 'i', 'ticket_id': 'p', 'applied_amount': 156000},
  ],
  'compras_tickets': [
    {
      'id': 'p',
      'ticket_date': '2026-10-30',
      'amount': 156000,
      'net_weight': 39000,
      'provider_name_snapshot': 'MARICRUZ QUIROGA ACOSTA',
    },
  ],
  'accounting_cash_conversions': [
    {
      'id': 'confirmed',
      'bank_id': 'b',
      'vault_id': 'v',
      'invoice_id': 'i',
      'effective_date': '2026-10-30',
      'bank_amount': 156000,
      'cash_amount': 150000,
      'fee': 6000,
      'note': 'Confirmado: solo efectivo',
    },
  ],
};
StatementDecision decision(
  StatementEntry e,
  StatementAccount account, {
  double? amount,
  bool estimated = false,
  String duplicate = '',
  DateTime? day,
}) => StatementDecision(
  id: e.fact.id,
  signature: e.fact.signature,
  note: 'Revisado con soporte',
  account: account,
  amount: amount ?? e.amount,
  estimated: estimated,
  duplicateOf: duplicate,
  economicDate: day,
);

void main() {
  test(
    'undated source stays pending until an explicit economic day is assigned',
    () {
      final t = {
        'finanzas_supplier_invoices': <StatementRow>[
          {'id': 'undated', 'total_amount': 75},
        ],
      };
      final a = analyzeStatement(bundle(t));
      expect(a.pending, hasLength(1));
      final invalid = decision(a.entries.single, StatementAccount.operating);
      expect(
        analyzeStatement(bundle(t, decisions: {invalid.id: invalid})).pending,
        hasLength(1),
      );
      final valid = decision(
        a.entries.single,
        StatementAccount.operating,
        day: DateTime(2026, 10, 31),
      );
      final reviewed = analyzeStatement(
        bundle(t, decisions: {valid.id: valid}),
      );
      expect(reviewed.result, -75);
      expect(
        (reviewed.toSnapshot()['entries'] as List).single['date'],
        '2026-10-31',
      );
    },
  );
  test(
    'aggregate cost cannot disappear by assigning a day outside its period',
    () {
      final a = analyzeStatement(bundle(materialSources()));
      final d = decision(
        a.entries.singleWhere((e) => e.fact.id.startsWith('cost:')),
        StatementAccount.cost,
        day: DateTime(2026, 11, 1),
      );
      expect(d.validate, throwsStateError);
      expect(
        analyzeStatement(
          bundle(materialSources(), decisions: {d.id: d}),
        ).pending.any((e) => e.fact.id == d.id),
        isTrue,
      );
    },
  );
  test(
    'audited unlink restores reconciliation instead of retaining the conversion fee',
    () {
      final t = conversionSources();
      t['accounting_cash_conversions']!.single['active'] = false;
      final a = analyzeStatement(bundle(t));
      expect(a.total(StatementAccount.financial), 0);
      expect(a.pending.any((e) => e.fact.source == 'Bóveda'), isTrue);
      expect(a.pending.any((e) => e.fact.source == 'Compras Mayoreo'), isTrue);
    },
  );
  test('operating UTC-labelled midnight remains first calendar day', () {
    expect(stDate('2026-10-01T00:00:00+00:00'), DateTime(2026, 10, 1));
    expect(stDate('2026-02-31'), isNull);
    final a = analyzeStatement(bundle(materialSources()));
    expect(a.total(StatementAccount.sales), 800);
    expect(a.total(StatementAccount.cost), 500);
    expect(a.result, 300);
    expect(a.estimated, isTrue);
    expect(a.complete, isFalse);
    expect(a.materials.single.receivedKg, 100);
    expect(a.materials.single.dispatchedKg, 50);
    expect(a.materials.single.recoveries, 1);
  });
  test(
    'loan proceeds never create income and financial principal is not presumed expense',
    () {
      final a = analyzeStatement(
        bundle({
          'finanzas_bank_movements': [
            {
              'id': 'loan',
              'movement_date': '2026-10-01T00:00:00Z',
              'credit_amount': 750000,
              'comment': 'PRESTAMO FINSUS',
            },
            {
              'id': 'repayment',
              'movement_date': '2026-10-02',
              'debit_amount': 20000,
              'category': 'GASTOS FINANCIEROS',
              'comment': 'PAGO CREDITO',
            },
          ],
        }),
      );
      expect(a.result, 0);
      expect(a.pending.single.fact.id, 'bank:repayment');
      expect(a.total(StatementAccount.balance), 750000);
    },
  );
  test('ticket invoice and bank settlement are not three purchases', () {
    final t = materialSources();
    t['finanzas_supplier_invoices'] = [
      {'id': 'i', 'invoice_date': '2026-10-01', 'total_amount': 1000},
    ];
    t['finanzas_supplier_invoice_tickets'] = [
      {'id': 'l', 'invoice_id': 'i', 'ticket_id': 'p1', 'applied_amount': 1000},
    ];
    t['finanzas_bank_movements'] = [
      {
        'id': 'b',
        'movement_date': '2026-10-02',
        'debit_amount': 1000,
        'linked_supplier_invoice_id': 'i',
      },
    ];
    final a = analyzeStatement(bundle(t));
    expect(a.total(StatementAccount.cost), 500);
    expect(a.result, 300);
    expect(
      a.entries.where((e) => e.account == StatementAccount.duplicate).length,
      2,
    );
  });
  test('collection of a previous sale has no new revenue', () {
    final a = analyzeStatement(
      bundle({
        'mayoreo_accounts': [
          {'id': 'old'},
        ],
        'finanzas_bank_movements': [
          {
            'id': 'receipt',
            'movement_date': '2026-10-01',
            'credit_amount': 12000,
            'linked_external_ref': 'old',
          },
        ],
      }),
    );
    expect(a.total(StatementAccount.sales), 0);
    expect(a.result, 0);
    expect(a.entries.single.account, StatementAccount.duplicate);
  });
  test(
    'retail tickets enter independently of vouchers and cancellation is excluded',
    () {
      final a = analyzeStatement(
        bundle({
          'men_tickets': [
            {
              'id': 'r1',
              'ticket_date': '2026-10-01',
              'direction': 'VENTA',
              'amount_total': 650,
              'net_weight': 10,
              'status': 'PENDIENTE',
            },
            {
              'id': 'r2',
              'ticket_date': '2026-10-01',
              'direction': 'VENTA',
              'amount_total': 9999,
              'status': 'CANCELADO',
            },
            {
              'id': 'r3',
              'ticket_date': '2026-10-01',
              'direction': 'COMPRA',
              'amount_total': 300,
              'net_weight': 10,
              'status': 'PAGADO',
            },
          ],
        }),
      );
      expect(a.total(StatementAccount.sales), 650);
      expect(a.complete, isFalse);
      expect(a.entries.any((e) => e.fact.id == 'retail:r2'), isFalse);
    },
  );
  test(
    'confirmed cash conversion recognizes only fee and no 39000 kg purchase',
    () {
      final a = analyzeStatement(bundle(conversionSources()));
      expect(a.result, -6000);
      expect(a.total(StatementAccount.sales), 0);
      expect(a.total(StatementAccount.cost), 0);
      expect(a.materials, isEmpty);
      expect(a.pending, isEmpty);
    },
  );
  test('conversion spans periods without becoming income at receipt', () {
    final t = conversionSources();
    t['finanzas_bank_movements']!.single['movement_date'] =
        '2026-09-30T00:00:00Z';
    t['direction_vault_vouchers']!.single['voucher_date'] = '2026-10-02';
    expect(analyzeStatement(bundle(t)).result, 0);
    expect(
      analyzeStatement(
        bundle(
          t,
          period: StatementPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
        ),
      ).result,
      -6000,
    );
  });
  test(
    'changed conversion values invalidate link instead of forcing four percent',
    () {
      final t = conversionSources();
      t['direction_vault_vouchers']!.single['total_amount'] = 149800;
      final a = analyzeStatement(bundle(t));
      expect(a.warnings, isNotEmpty);
      expect(a.complete, isFalse);
      expect(a.total(StatementAccount.financial), 0);
      expect(a.materials, isEmpty);
    },
  );
  test(
    'no price or physical exit is a pending cost, never a certified zero',
    () {
      final a = analyzeStatement(
        bundle({
          'mayoreo_sales_reports': [sale('s')],
        }),
      );
      expect(a.pending.any((e) => e.fact.id.startsWith('cost:')), isTrue);
      expect(a.complete, isFalse);
    },
  );
  test('mixed voucher is not discarded because a line says transferencia', () {
    final a = analyzeStatement(
      bundle({
        'men_cash_vouchers': [
          {
            'id': 'v',
            'voucher_date': '2026-10-02',
            'voucher_type': 'expense',
            'total_amount': 100,
          },
        ],
        'men_cash_voucher_lines': [
          {
            'id': 'l1',
            'voucher_id': 'v',
            'concept': 'TRANSFERENCIA',
            'amount': 40,
          },
          {
            'id': 'l2',
            'voucher_id': 'v',
            'concept': 'GASTO REAL',
            'amount': 60,
          },
        ],
      }),
    );
    expect(a.pending.single.fact.amount, 100);
    expect(a.pending.single.fact.id, 'cash:v');
  });
  test(
    'review is invalidated by source change and economic day moves recognition',
    () {
      final t = {
        'finanzas_supplier_invoices': <StatementRow>[
          {'id': 'i', 'invoice_date': '2026-09-20', 'total_amount': 100},
        ],
      };
      final sep = analyzeStatement(
        bundle(
          t,
          period: StatementPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
        ),
      );
      final d = decision(
        sep.entries.single,
        StatementAccount.operating,
        day: DateTime(2026, 10, 1),
      );
      expect(analyzeStatement(bundle(t, decisions: {d.id: d})).result, -100);
      t['finanzas_supplier_invoices']!.single['total_amount'] = 150;
      final changed = analyzeStatement(bundle(t, decisions: {d.id: d}));
      expect(changed.result, 0);
      expect(changed.pending.single.issue, contains('Cambió'));
    },
  );
  test('duplicate cycles and unresolved targets remain pending', () {
    final t = {
      'finanzas_supplier_invoices': <StatementRow>[
        for (final id in ['a', 'b'])
          {'id': id, 'invoice_date': '2026-10-01', 'total_amount': 100},
      ],
    };
    final base = analyzeStatement(bundle(t));
    final ds = {
      for (final e in base.entries)
        e.fact.id: decision(
          e,
          StatementAccount.duplicate,
          duplicate: e.fact.id == 'invoice:a' ? 'invoice:b' : 'invoice:a',
        ),
    };
    expect(analyzeStatement(bundle(t, decisions: ds)).pending.length, 2);
  });
  test(
    'published payroll is partial remuneration and cheque is not added twice',
    () {
      final a = analyzeStatement(
        bundle({
          'hr_prenomina_draft_rows': [
            {
              'id': 'n',
              'employee_id': 'e',
              'empresa': 'DICSA',
              'period_label': 'Periodo · 25/09/2026 - 01/10/2026',
              'draft_status': 'publicado',
              'fiscal_net_amount': 700,
              'cash_salary_amount': 140,
              'check_amount': 700,
            },
          ],
        }),
      );
      expect(
        a.total(StatementAccount.payroll),
        120,
      ); // one of seven days; not 220
      expect(a.estimated, isTrue);
      expect(a.complete, isFalse);
      expect(a.pending.single.fact.id, startsWith('payroll-coverage:'));
      expect(a.pending.single.fact.label, contains('30 días'));
    },
  );
  test(
    'closing requires complete sources and becomes stale after a change',
    () {
      final t = {
        'finanzas_supplier_invoices': <StatementRow>[
          {'id': 'i', 'invoice_date': '2026-10-01', 'total_amount': 100},
        ],
      };
      final initial = analyzeStatement(bundle(t)),
          d = decision(
            analyzeStatement(bundle(t)).entries.single,
            StatementAccount.operating,
          );
      final ds = {d.id: d};
      final a = analyzeStatement(bundle(t, decisions: ds));
      final closing = StatementClosing(
        signature: a.signature,
        note: 'Revisado',
        checks: statementClosingChecks.keys.toSet(),
        snapshot: a.toSnapshot(),
      );
      expect(initial.complete, isFalse);
      expect(
        analyzeStatement(bundle(t, decisions: ds, closing: closing)).complete,
        isTrue,
      );
      t['finanzas_supplier_invoices']!.single['total_amount'] = 101;
      expect(
        analyzeStatement(bundle(t, decisions: ds, closing: closing)).complete,
        isFalse,
      );
    },
  );
  test(
    'documented signed adjustments support reversals without overwriting sales',
    () {
      final a = analyzeStatement(
        bundle(
          {},
          closing: StatementClosing(
            adjustments: [
              {
                'id': 'a',
                'date': '2026-10-10',
                'account': 'sales',
                'amount': 100,
                'note': 'Servicio devengado',
              },
              {
                'id': 'b',
                'date': '2026-10-15',
                'account': 'sales',
                'amount': -20,
                'note': 'Nota de crédito',
              },
              {
                'id': 'c',
                'date': '2026-10-31',
                'account': 'incomeTax',
                'amount': 10,
                'note': 'Impuesto causado',
              },
            ],
          ),
        ),
      );
      expect(a.total(StatementAccount.sales), 80);
      expect(a.result, 70);
      expect(a.complete, isFalse);
    },
  );
}
