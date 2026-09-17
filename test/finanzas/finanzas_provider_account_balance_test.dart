import 'package:dicsa_operacion/app/compras/compras_tickets_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_bank_accounts_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_account_balance.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'includes purchases without invoices and deducts partial/full payments',
    () {
      final balance = _balance(
        tickets: [
          _ticket('open', 1000),
          _ticket('partial', 800),
          _ticket('paid', 600),
        ],
        movements: [_movement('payment', 'ABONO', 900)],
        applications: [
          _application('partial', 'payment', 300),
          _application('paid', 'payment', 600),
        ],
      );
      expect(balance.payableAmount, 1500);
      expect(balance.sinFacturaAmount, 1500);
      expect(balance.openInvoicesCount, 0);
      expect(balance.openNonInvoiceTicketsCount, 2);
      expect(balance.nextDueDate, DateTime(2026, 9, 17));
    },
  );

  test(
    'mixed account counts each invoice once, including stale ticket status',
    () {
      final balance = _balance(
        tickets: [
          _ticket('cash', 1000),
          _ticket('pending', 500, status: 'PENDIENTE_DE_FACTURAR'),
          _ticket('invoiced', 2000, status: 'FACTURADO'),
          _ticket('stale', 300, status: 'PENDIENTE_DE_FACTURAR'),
        ],
        invoices: [
          _invoice('invoice', 2300, balance: 1500),
          _invoice('manual', 700),
        ],
        invoicedIds: {'invoiced', 'stale'},
      );
      expect(balance.facturadoAmount, 2200);
      expect(balance.sinFacturaAmount, 1000);
      expect(balance.pendienteFacturarAmount, 500);
      expect(balance.payableAmount, 3700);
      expect(balance.openInvoicesCount, 2);
      expect(balance.openNonInvoiceTicketsCount, 2);
    },
  );

  test(
    'bank settlement is not deducted again from persisted invoice balance',
    () {
      final balance = _balance(
        invoices: [_invoice('invoice', 1000, balance: 600)],
        banks: [
          FinanzasBankMovementRecord.fromRemoteRow({
            'id': 'bank',
            'linked_supplier_invoice_id': 'invoice',
            'debit_amount': 399.99,
            'applied_supplier_amount': 400,
          }),
        ],
      );
      expect(balance.payableAmount, 600);
    },
  );

  test('signed adjustments and charges change the provider balance', () {
    final balance = _balance(
      tickets: [_ticket('ticket', 1000)],
      movements: [
        _movement('increase', 'AJUSTE', 100),
        _movement('decrease', 'AJUSTE', -250.25),
        _movement('charge', 'CARGO', 50),
      ],
    );
    expect(balance.adjustmentAmount, -100.25);
    expect(balance.openAmount, 899.75);
    expect(balance.payableAmount, 899.75);
  });

  test('adjustments can settle a balance without an invoice or payment', () {
    expect(
      _balance(
        tickets: [_ticket('ticket', 1000)],
        movements: [_movement('adjustment', 'AJUSTE', -1000)],
      ).payableAmount,
      0,
    );
    expect(
      _balance(
        movements: [_movement('adjustment', 'AJUSTE', 500)],
      ).payableAmount,
      500,
    );
  });

  test('preserves a credit balance while payable never becomes negative', () {
    final balance = _balance(
      tickets: [_ticket('ticket', 1000)],
      movements: [_movement('adjustment', 'AJUSTE', -1200)],
    );
    expect(balance.openAmount, -200);
    expect(balance.payableAmount, 0);
  });

  test('unapplied portion of an abono covers a charge only once', () {
    final balance = _balance(
      tickets: [_ticket('ticket', 1000)],
      movements: [
        _movement('payment', 'ABONO', 1200),
        _movement('charge', 'CARGO', 300),
      ],
      applications: [_application('ticket', 'payment', 1000)],
    );
    expect(balance.sinFacturaAmount, 0);
    expect(balance.unappliedPaymentAmount, 200);
    expect(balance.payableAmount, 100);
  });

  test(
    'preserves negative ticket credits without double-counting invoice tickets',
    () {
      final balance = _balance(
        tickets: [_ticket('debt', 1000), _ticket('credit', -150)],
      );
      expect(balance.payableAmount, 850);
    },
  );

  test('editing and removing an adjustment recomputes from saved records', () {
    final tickets = [_ticket('ticket', 1000)];
    expect(
      _balance(
        tickets: tickets,
        movements: [_movement('a', 'AJUSTE', 100)],
      ).payableAmount,
      1100,
    );
    expect(
      _balance(
        tickets: tickets,
        movements: [_movement('a', 'AJUSTE', -100)],
      ).payableAmount,
      900,
    );
    expect(_balance(tickets: tickets).payableAmount, 1000);
  });
}

ProviderAccountBalance _balance({
  List<ComprasTicketRecord> tickets = const [],
  List<FinanzasSupplierInvoiceRecord> invoices = const [],
  Set<String> invoicedIds = const {},
  List<FinanzasBankMovementRecord> banks = const [],
  List<ComprasProviderMovementRecord> movements = const [],
  List<ComprasTicketPaymentApplicationRecord> applications = const [],
}) => computeProviderAccountBalance(
  tickets: tickets,
  invoices: invoices,
  invoicedTicketIds: invoicedIds,
  bankMovements: banks,
  directMovements: movements,
  applications: applications,
  creditDays: 7,
);

ComprasTicketRecord _ticket(
  String id,
  double amount, {
  String status = 'SIN_FACTURA',
}) => ComprasTicketRecord.fromRemoteRow({
  'id': id,
  'provider_id': 'provider',
  'amount': amount,
  'factura_status': status,
  'ticket_date': '2026-09-10',
});

FinanzasSupplierInvoiceRecord _invoice(
  String id,
  double total, {
  double? balance,
}) => FinanzasSupplierInvoiceRecord.fromRemoteRow({
  'id': id,
  'provider_id': 'provider',
  'total_amount': total,
  'balance_amount': balance ?? total,
  'invoice_date': '2026-09-10',
  'due_date': '2026-09-20',
});

ComprasProviderMovementRecord _movement(
  String id,
  String type,
  double amount,
) => ComprasProviderMovementRecord.fromRemoteRow({
  'id': id,
  'provider_id': 'provider',
  'movement_type': type,
  'amount': amount,
  'movement_date': '2026-09-10',
});

ComprasTicketPaymentApplicationRecord _application(
  String ticket,
  String movement,
  double amount,
) => ComprasTicketPaymentApplicationRecord.fromRemoteRow({
  'id': '$ticket-$movement',
  'ticket_id': ticket,
  'provider_movement_id': movement,
  'applied_amount': amount,
  'applied_at': '2026-09-10',
});
