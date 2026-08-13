import '../compras/compras_tickets_store.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_payment_center_budget_models.dart';
import 'finanzas_payment_center_reserves_store.dart';
import 'finanzas_payment_learning_store.dart';
import 'finanzas_provider_accounts_store.dart';

Future<FinanzasPaymentCenterSourceSnapshot>
loadFinanzasPaymentCenterSourceSnapshot() async {
  final results = await Future.wait<dynamic>([
    FinanzasCompanyDirectoryStore.loadDirectory(),
    ComprasTicketsStore.loadTickets(),
    ComprasTicketsStore.loadTicketPaymentApplications(),
    FinanzasProviderAccountsStore.loadInvoices(),
    FinanzasProviderAccountsStore.loadAgreements(),
    FinanzasProviderAccountsStore.loadAgreementInstallments(),
    FinanzasProviderAccountsStore.loadAgreementInvoices(),
    FinanzasBankAccountsStore.loadMovements(),
    FinanzasFixedPaymentsStore.loadPayments(),
    FinanzasPaymentLearningStore.loadLogs(),
    FinanzasPaymentCenterReservesStore.loadReserves(),
  ]);

  return FinanzasPaymentCenterSourceSnapshot(
    directory: results[0] as List<FinanzasCompanyDirectoryRecord>,
    tickets: results[1] as List<ComprasTicketRecord>,
    ticketApplications:
        results[2] as List<ComprasTicketPaymentApplicationRecord>,
    invoices: results[3] as List<FinanzasSupplierInvoiceRecord>,
    agreements: results[4] as List<FinanzasSupplierAgreementRecord>,
    installments:
        results[5] as List<FinanzasSupplierAgreementInstallmentRecord>,
    agreementInvoiceLinks:
        results[6] as List<FinanzasSupplierAgreementInvoiceRecord>,
    bankMovements: results[7] as List<FinanzasBankMovementRecord>,
    fixedPayments: results[8] as List<FinanzasFixedPaymentRecord>,
    learningLogs: results[9] as List<FinanzasPaymentLearningRecord>,
    reserves: results[10] as List<FinanzasPaymentCenterReserveRecord>,
  );
}
