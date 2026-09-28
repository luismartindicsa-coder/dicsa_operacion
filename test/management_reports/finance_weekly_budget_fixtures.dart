import 'package:dicsa_operacion/app/finanzas/finanzas_bank_accounts_store.dart';
import 'package:dicsa_operacion/app/compras/compras_tickets_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_fixed_payments_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';

FinanzasBankMovementRecord bank(
  String id,
  String date,
  double credit,
  double debit, {
  String category = 'VENTAS',
  String company = 'DICSA',
  String branch = 'CELAYA',
  String? invoice,
  String? fixed,
  String counterparty = '',
  double? applied,
}) => FinanzasBankMovementRecord.fromRemoteRow({
  'id': id,
  'movement_date': date,
  'company': company,
  'branch': branch,
  'account_key': '$company|$branch',
  'credit_amount': credit,
  'debit_amount': debit,
  'category': category,
  'counterparty_name_snapshot': counterparty,
  'linked_supplier_invoice_id': invoice,
  'linked_fixed_payment_id': fixed,
  'applied_supplier_amount': applied,
});

FinanzasSupplierInvoiceRecord invoice(
  String id,
  double amount,
  String? due, {
  String provider = 'Proveedor A',
  String company = 'DICSA',
  String branch = 'CELAYA',
  String status = 'PENDIENTE',
  double? balance,
}) => FinanzasSupplierInvoiceRecord.fromRemoteRow({
  'id': id,
  'provider_id': provider,
  'provider_name_snapshot': provider,
  'target_company': company,
  'target_branch': branch,
  'invoice_folio': id,
  'invoice_date': '2026-07-01',
  'due_date': due,
  'total_amount': amount,
  'balance_amount': balance ?? amount,
  'status': status,
});

FinanzasFixedPaymentRecord fixed(
  String id,
  double amount,
  String date, {
  String company = 'DICSA',
  String branch = 'CELAYA',
  String status = 'PENDIENTE',
  String? method,
  String notes = 'Servicio programado',
}) => FinanzasFixedPaymentRecord.fromRemoteRow({
  'id': id,
  'company_id': id,
  'company_name_snapshot': 'Servicios $id',
  'target_company': company,
  'branch': branch,
  'received_date': '2026-09-01',
  'payment_date': date,
  'amount': amount,
  'status': status,
  'execution_method': method,
  'notes': notes,
});

List<FinanzasBankMovementRecord> history({
  double balance = 500,
  bool spike = false,
}) {
  final rows = [bank('opening', '2026-07-13', 0, 0, category: 'AJUSTES')];
  var net = 0.0;
  for (var w = 0; w < 8; w++) {
    final date = DateTime(2026, 7, 20).add(Duration(days: 7 * w));
    final credit = spike && w == 7 ? 100000.0 : 1000.0;
    rows.add(bank('in$w', date.toIso8601String(), credit, 0));
    rows.add(
      bank(
        'inv$w',
        date.add(const Duration(days: 1)).toIso8601String(),
        0,
        400,
        category: 'COMPRA DE MATERIAL',
        invoice: 'historical-$w',
      ),
    );
    rows.add(
      bank(
        'other$w',
        date.add(const Duration(days: 2)).toIso8601String(),
        0,
        200,
        category: 'SERVICIOS',
      ),
    );
    net += credit - 600;
  }
  rows.add(
    bank(
      'balance-adjustment',
      '2026-09-18',
      balance > net ? balance - net : 0,
      net > balance ? net - balance : 0,
      category: 'AJUSTES',
    ),
  );
  return rows;
}

FinanceWeeklyBudgetSource budgetSource({
  List<FinanzasBankMovementRecord> movements = const [],
  List<FinanzasSupplierInvoiceRecord> invoices = const [],
  List<FinanzasFixedPaymentRecord> fixedPayments = const [],
  List<FinanzasSupplierAgreementRecord> agreements = const [],
  List<FinanzasSupplierAgreementInstallmentRecord> installments = const [],
  List<FinanzasSupplierAgreementInvoiceRecord> links = const [],
  List<ComprasTicketRecord> tickets = const [],
  List<ComprasTicketPaymentApplicationRecord> ticketApplications = const [],
  List<FinanzasSupplierInvoiceTicketRecord> invoiceTickets = const [],
}) => FinanceWeeklyBudgetSource(
  movements: movements,
  invoices: invoices,
  fixedPayments: fixedPayments,
  agreements: agreements,
  installments: installments,
  agreementLinks: links,
  tickets: tickets,
  ticketApplications: ticketApplications,
  invoiceTickets: invoiceTickets,
);
