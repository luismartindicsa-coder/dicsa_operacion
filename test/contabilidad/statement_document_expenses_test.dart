import 'package:dicsa_operacion/app/contabilidad/statement/statement_document_expenses.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final october = StatementPeriod(
    DateTime(2026, 10, 1),
    DateTime(2026, 10, 31),
  );
  final september = StatementPeriod(
    DateTime(2026, 9, 1),
    DateTime(2026, 9, 30),
  );
  StatementRow invoice({
    String id = 'i',
    String date = '2026-10-03',
    String provider = 'CFE',
    String notes = '',
    String folio = '123',
    double total = 116,
  }) => {
    'id': id,
    'invoice_date': date,
    'provider_name_snapshot': provider,
    'notes': notes,
    'invoice_folio': folio,
    'total_amount': total,
    'target_company': 'DICSA',
    'status': 'PENDIENTE',
  };
  StatementRow bank({
    String id = 'b',
    String link = 'i',
    String date = '2026-10-05',
    double amount = 116,
    String party = 'CFE',
    String category = 'SERVICIOS',
    String reference = '',
    String comment = '',
  }) => {
    'id': id,
    'movement_date': date,
    'debit_amount': amount,
    'credit_amount': 0,
    'linked_supplier_invoice_id': link,
    'counterparty_name_snapshot': party,
    'category': category,
    'reference': reference,
    'comment': comment,
  };
  StatementAnalysis analyze(
    Map<String, List<StatementRow>> tables, {
    StatementPeriod? period,
  }) => analyzeStatement(
    StatementBundle(period: period ?? october, tables: tables),
  );

  test(
    'tax-inclusive invoice is recognized once, its partial payments never again',
    () {
      final a = analyze({
        'finanzas_supplier_invoices': [invoice()],
        'finanzas_bank_movements': [
          bank(amount: 50),
          bank(id: 'b2', amount: 66),
        ],
      });
      expect(a.total(StatementAccount.operating), 116);
      expect(a.result, -116);
      expect(a.pending, isEmpty);
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'invoice:i').estimated,
        isTrue,
      );
      expect(
        a.entries.where((e) => e.account == StatementAccount.duplicate).length,
        2,
      );
      expect(a.complete, isFalse);
    },
  );

  test(
    'described repairs are recognized even if unpaid; ticket material and conversion never are',
    () {
      final a = analyze({
        'finanzas_supplier_invoices': [
          invoice(
            id: 'repair',
            provider: 'Proveedor de taller',
            notes: 'REPARACION MOTOR G3',
          ),
          invoice(id: 'material', provider: 'CFE', folio: '124'),
          invoice(
            id: 'cash',
            provider: 'MARICRUZ QUIROGA ACOSTA',
            folio: '125',
          ),
        ],
        'finanzas_supplier_invoice_tickets': [
          {'invoice_id': 'material', 'ticket_id': 'p'},
        ],
      });
      expect(a.total(StatementAccount.operating), 116);
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'invoice:material').account,
        StatementAccount.duplicate,
      );
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'invoice:cash').pending,
        isTrue,
      );
    },
  );

  test(
    'service dates split across months, not by payment date, without lost cents',
    () {
      final data = {
        'finanzas_supplier_invoices': [
          invoice(
            provider: 'ATT',
            notes: 'PERIODO 16/09/2026-15/10/2026',
            total: 5176.61,
          ),
        ],
        'finanzas_bank_movements': [bank(amount: 5176.61)],
      };
      final sep = analyze(data, period: september), oct = analyze(data);
      expect(sep.total(StatementAccount.administrative), 2588.31);
      expect(oct.total(StatementAccount.administrative), 2588.30);
      expect(sep.result + oct.result, closeTo(-5176.61, .001));
    },
  );

  test(
    'a late invoice with October service enters October; September payment does not',
    () {
      final a = analyze({
        'finanzas_supplier_invoices': [
          invoice(
            id: 'old',
            date: '2026-10-03',
            notes: 'SERVICIOS CONTABLES SEPTIEMBRE 2026',
          ),
          invoice(
            id: 'late',
            date: '2026-11-03',
            folio: '124',
            notes: 'SERVICIOS CONTABLES OCTUBRE 2026',
          ),
        ],
        'finanzas_bank_movements': [bank(link: 'old')],
      });
      expect(a.total(StatementAccount.administrative), 116);
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'invoice:old').account,
        StatementAccount.balance,
      );
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'invoice:late').account,
        StatementAccount.administrative,
      );
    },
  );

  test('bank categories classify services without inventing tax breakdown', () {
    final a = analyze({
      'finanzas_supplier_invoices': [invoice(provider: 'Proveedor servicio')],
      'finanzas_bank_movements': [bank(party: 'Proveedor servicio')],
    });
    expect(a.total(StatementAccount.operating), 116);
    expect(
      a.entries.singleWhere((e) => e.fact.id == 'invoice:i').fact.detail,
      contains('con impuestos'),
    );
  });

  test(
    'contradictory categories, assets, advances, insurance and finance stay unresolved',
    () {
      for (final note in [
        'ANTICIPO INDICADOR',
        'COMPRA ACTIVO',
        'RENTA CONTRATO AP 2/48',
        'POLIZA SEGUROS',
        'PRESTAMO',
        '3000KG',
        'ALMACEN',
      ]) {
        final a = analyze({
          'finanzas_supplier_invoices': [invoice(notes: note)],
          'finanzas_bank_movements': [bank()],
        });
        expect(a.result, 0, reason: note);
        expect(a.pending, hasLength(1), reason: note);
      }
      final a = analyze({
        'finanzas_supplier_invoices': [invoice(provider: 'Desconocido')],
        'finanzas_bank_movements': [
          bank(category: 'SERVICIOS'),
          bank(id: 'b2', category: 'COMPRA DE MATERIAL'),
        ],
      });
      expect(a.result, 0);
      expect(a.pending, hasLength(1));
    },
  );

  test(
    'cancelled and repeated documents cannot create ordinary expense automatically',
    () {
      final a = analyze({
        'finanzas_supplier_invoices': [
          invoice(),
          invoice(id: 'copy'),
          invoice(id: 'void', folio: '124')..['status'] = 'CANCELADA',
        ],
      });
      expect(a.result, 0);
      expect(a.pending, hasLength(2));
    },
  );

  test(
    'bank service charge is separated from VAT and credit capital, and uses its service month',
    () {
      final a = analyze({
        'finanzas_bank_movements': [
          bank(
            id: 'oct',
            link: '',
            party: 'SERVICIO DE BANCA DIGITAL',
            amount: 450,
            reference: 'RENTA 01-31 OCT 2026',
          ),
          bank(
            id: 'sep',
            link: '',
            party: 'SERVICIO DE BANCA DIGITAL',
            amount: 344.5,
            reference: '01-30 SEP 2026',
          ),
          bank(
            id: 'vat',
            link: '',
            party: 'IVA COM SERV BANCA',
            amount: 127.12,
          ),
          bank(
            id: 'capital',
            link: '',
            party: 'PAGO TARJETA DE CREDITO',
            amount: 150000,
          ),
        ],
      });
      expect(a.total(StatementAccount.financial), 450);
      expect(a.pending, hasLength(2));
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'bank:sep').account,
        StatementAccount.balance,
      );
    },
  );

  test('invalid or ambiguous service ranges remain pending', () {
    for (final notes in [
      'PERIODO 31/09/2026-15/10/2026',
      'SEPTIEMBRE OCTUBRE',
      'ANUAL',
      'PERIODO 15/10/2026-01/10/2026',
    ]) {
      final a = analyze({
        'finanzas_supplier_invoices': [invoice(notes: notes)],
      });
      expect(a.pending, hasLength(1), reason: notes);
      expect(a.result, 0);
    }
  });

  test(
    'recurring categories recognize unpaid service only within the same company',
    () {
      final data = {
        'finanzas_supplier_invoices': [
          invoice(
            id: 'old1',
            date: '2026-09-02',
            provider: 'Servicio recurrente',
            folio: '1',
          ),
          invoice(
            id: 'old2',
            date: '2026-09-15',
            provider: 'Servicio recurrente',
            folio: '2',
          ),
          invoice(
            id: 'new',
            provider: 'Servicio recurrente',
            folio: '3',
            notes: '11-20 OCTUBRE 2026',
          ),
          invoice(
            id: 'other-company',
            provider: 'Servicio recurrente',
            folio: '4',
          )..['target_company'] = 'OTRA',
        ],
        'finanzas_bank_movements': [
          bank(link: 'old1'),
          bank(id: 'b2', link: 'old2'),
        ],
      };
      final a = analyze(data);
      expect(a.total(StatementAccount.operating), 116);
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'invoice:new').fact.detail,
        contains('recurrente'),
      );
      expect(
        a.entries
            .singleWhere((e) => e.fact.id == 'invoice:other-company')
            .pending,
        isTrue,
      );
    },
  );

  test(
    'cash matching an invoice stays pending and is not recognized a second time',
    () {
      final a = analyze({
        'finanzas_supplier_invoices': [
          invoice(provider: 'PROVEEDOR SERVICIO', notes: 'REPARACION'),
        ],
        'men_cash_vouchers': [
          {
            'id': 'c',
            'voucher_date': '2026-10-03',
            'voucher_type': 'expense',
            'rubric': 'OPERATIVO',
            'folio': '99',
            'total_amount': 116,
            'person_label': 'PROVEEDOR SERVICIO',
          },
        ],
        'men_cash_voucher_lines': [
          {'voucher_id': 'c', 'concept': 'MANTENIMIENTO', 'amount': 116},
        ],
      });
      expect(a.total(StatementAccount.operating), 116);
      expect(
        a.entries.singleWhere((e) => e.fact.id == 'cash:c').pending,
        isTrue,
      );
    },
  );

  test('every consecutive subperiod adds to the captured total', () {
    final window = statementExpenseWindow(
      '01-31 OCTUBRE 2026',
      DateTime(2026, 10, 5),
    )!;
    var sum = 0.0;
    for (var d = 1; d <= 31; d++) {
      sum += window.amountIn(
        116,
        StatementPeriod(DateTime(2026, 10, d), DateTime(2026, 10, d)),
      );
    }
    expect(sum, closeTo(116, .00001));
    expect(
      statementExpenseWindow('DEL 01SEP-30SEP', DateTime(2026, 10, 1))!.start,
      DateTime(2026, 9, 1),
    );
    expect(
      statementExpenseWindow('11-20 OCTUBRE 2026', DateTime(2026, 10, 23))!.end,
      DateTime(2026, 10, 20),
    );
  });
}
