import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_settlements.dart';
import 'package:flutter_test/flutter_test.dart';

final period = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
StatementBundle bundle(Map<String, List<StatementRow>> tables) =>
    StatementBundle(period: period, tables: tables);
Map<String, List<StatementRow>> conversion() => {
  'finanzas_supplier_invoices': [
    {
      'id': 'i',
      'invoice_date': '2026-10-01',
      'invoice_folio': '142',
      'provider_name_snapshot': 'MARICRUZ QUIROGA ACOSTA',
      'total_amount': 83200,
    },
  ],
  'finanzas_bank_movements': [
    {
      'id': 'b',
      'movement_date': '2026-10-01',
      'debit_amount': 83200,
      'credit_amount': 0,
      'linked_supplier_invoice_id': 'i',
    },
  ],
  'direction_vault_vouchers': [
    {
      'id': 'v',
      'voucher_date': '2026-10-01',
      'voucher_type': 'deposit',
      'total_amount': 80000,
      'person_label': 'BIANCA',
    },
  ],
  'direction_vault_voucher_lines': [
    {'id': 'l', 'voucher_id': 'v', 'amount': 80000, 'concept': 'Bianca'},
  ],
  'finanzas_supplier_invoice_tickets': [
    {'id': 'link', 'invoice_id': 'i', 'ticket_id': 'p'},
  ],
  'compras_tickets': [
    {
      'id': 'p',
      'ticket_date': '2026-10-01',
      'provider_name_snapshot': 'MARICRUZ QUIROGA',
      'amount': 83200,
      'net_weight': 20000,
    },
  ],
};

void main() {
  test(
    'unique document triple charges only 4% and excludes fictitious material',
    () {
      final a = analyzeStatement(bundle(conversion()));
      expect(a.total(StatementAccount.financial), 3200);
      expect(a.total(StatementAccount.sales), 0);
      expect(a.materials, isEmpty);
      expect(a.pending, isEmpty);
      expect(
        a.entries.where((e) => e.fact.id.startsWith('conversion:')),
        hasLength(1),
      );
    },
  );
  test(
    'ambiguous cash, partial payment and changed explicit links cannot auto match',
    () {
      var t = conversion();
      t['direction_vault_vouchers']!.add({
        ...t['direction_vault_vouchers']!.first,
        'id': 'v2',
      });
      t['direction_vault_voucher_lines']!.add({
        ...t['direction_vault_voucher_lines']!.first,
        'id': 'l2',
        'voucher_id': 'v2',
      });
      expect(statementAutomaticConversions(bundle(t)), isEmpty);
      t = conversion();
      t['finanzas_bank_movements']!.add({
        ...t['finanzas_bank_movements']!.first,
        'id': 'b2',
      });
      expect(statementAutomaticConversions(bundle(t)), isEmpty);
      t = conversion();
      t['accounting_cash_conversions'] = [
        {
          'id': 'explicit',
          'bank_id': 'b',
          'vault_id': 'v',
          'invoice_id': 'i',
          'active': true,
          'bank_amount': 123,
        },
      ];
      final a = analyzeStatement(bundle(t));
      expect(a.total(StatementAccount.financial), 0);
      expect(a.warnings, isNotEmpty);
      expect(statementAutomaticConversions(bundle(t)), isEmpty);
    },
  );
  test(
    'wrong fee, mixed lines and receipts outside date window remain pending',
    () {
      for (final change in ['fee', 'lines', 'date', 'supplier']) {
        final t = conversion();
        if (change == 'fee') {
          t['finanzas_bank_movements']!.first['debit_amount'] = 83000;
          t['finanzas_supplier_invoices']!.first['total_amount'] = 83000;
        }
        if (change == 'lines') {
          t['direction_vault_voucher_lines']!.first['concept'] =
              'Venta de material';
        }
        if (change == 'date') {
          t['direction_vault_vouchers']!.first['voucher_date'] = '2026-10-10';
        }
        if (change == 'supplier') {
          t['finanzas_supplier_invoices']!.first['provider_name_snapshot'] =
              'OTRO';
        }
        expect(
          statementAutomaticConversions(bundle(t)),
          isEmpty,
          reason: change,
        );
      }
    },
  );
  test(
    'conversion fee belongs to bank economic day across months, never twice',
    () {
      final t = conversion();
      t['finanzas_bank_movements']!.first['movement_date'] = '2026-09-30';
      t['finanzas_supplier_invoices']!.first['invoice_date'] = '2026-09-30';
      expect(analyzeStatement(bundle(t)).total(StatementAccount.financial), 0);
      final september = analyzeStatement(
        StatementBundle(
          period: StatementPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
          tables: t,
        ),
      );
      expect(september.total(StatementAccount.financial), 3200);
    },
  );
  test(
    'personal exclusion depends on rubric, not a surname or vague comment',
    () {
      final row = <String, dynamic>{
        'voucher_type': 'expense',
        'total_amount': 100,
        'rubric': 'Gastos personales',
        'person_label': 'DIANA VELAZQUEZ',
      };
      final lines = <StatementRow>[
        {'concept': 'Comida', 'amount': 100},
      ];
      expect(
        recognizeVoucherSettlement(row, lines)?.account,
        StatementAccount.balance,
      );
      row['rubric'] = 'Operativo';
      expect(recognizeVoucherSettlement(row, lines), isNull);
      row['rubric'] = 'Personales';
      lines.first['amount'] = 90;
      expect(recognizeVoucherSettlement(row, lines), isNull);
    },
  );
  test(
    'payroll payments are grouped into a visible coverage exception, even without RH',
    () {
      final a = analyzeStatement(
        bundle({
          'men_cash_vouchers': [
            for (var i = 0; i < 3; i++)
              {
                'id': 'v$i',
                'voucher_date': '2026-10-02',
                'voucher_type': 'expense',
                'rubric': 'Nomina',
                'total_amount': 100,
              },
          ],
          'men_cash_voucher_lines': [
            for (var i = 0; i < 3; i++)
              {
                'id': 'l$i',
                'voucher_id': 'v$i',
                'concept': 'Empresa',
                'amount': 100,
              },
          ],
        }),
      );
      expect(a.result, 0);
      expect(a.pending, hasLength(1));
      expect(a.pending.single.fact.id, startsWith('payroll-payments:'));
      expect(a.pending.single.fact.references, hasLength(3));
      expect(a.complete, isFalse);
      expect(a.automaticCount, 3);
    },
  );
  test(
    'catalog GENERAL bridge combines physical and commercial cost, never product-name guessing',
    () {
      final t = <String, List<StatementRow>>{
        'material_general_catalog_v2': [
          {'id': 'physical', 'name': 'CARTÓN'},
        ],
        'compras_material_catalog': [
          {
            'id': 'ma_general_carton',
            'level': 'GENERAL',
            'category': 'CARTON',
            'name': 'CARTON',
          },
          {'id': 'commercial', 'general_material_id': 'ma_general_carton'},
        ],
        'compras_tickets': [
          {
            'id': 'p',
            'ticket_date': '2026-10-01',
            'material_id': 'commercial',
            'net_weight': 100,
            'amount': 400,
          },
        ],
        'inventory_movements_v2': [
          {
            'id': 'out',
            'op_date': '2026-10-10',
            'general_material_id': 'physical',
            'net_kg': 50,
            'flow': 'OUT',
            'origin_type': 'SALE',
            'inventory_level': 'COMMERCIAL',
          },
        ],
      };
      expect(analyzeStatement(bundle(t)).total(StatementAccount.cost), 200);
      t['material_general_catalog_v2']!.add({
        'id': 'ambiguous',
        'name': 'CARTON',
      });
      expect(analyzeStatement(bundle(t)).total(StatementAccount.cost), 0);
      expect(analyzeStatement(bundle(t)).pending, isNotEmpty);
    },
  );
}
