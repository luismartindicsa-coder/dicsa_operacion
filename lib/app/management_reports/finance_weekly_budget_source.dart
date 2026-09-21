import 'package:supabase_flutter/supabase_flutter.dart';

import '../finanzas/finanzas_bank_accounts_store.dart';
import '../finanzas/finanzas_fixed_payments_store.dart';
import '../finanzas/finanzas_provider_accounts_store.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'finance_weekly_budget_analysis.dart';

/// Strict, paginated read: an unavailable source must not produce missing obligations. Unlike the interactive stores, this loader never swallows errors.
Future<FinanceWeeklyBudgetSource> loadFinanceWeeklyBudgetSource() async {
  Future<List<Map<String, dynamic>>> rows(String table) => fetchAllSupabaseRows(
    (from, to) => Supabase.instance.client
        .from(table)
        .select()
        .order('id')
        .range(from, to),
    pageSize: 500,
  );
  final results = await Future.wait<dynamic>([
    FinanzasBankAccountsStore.loadMovementsStrict(),
    rows('finanzas_supplier_invoices'),
    rows('finanzas_fixed_payments'),
    rows('finanzas_supplier_agreements'),
    rows('finanzas_supplier_agreement_installments'),
    rows('finanzas_supplier_agreement_invoices'),
  ]);
  List<T> decode<T>(int index, T Function(Map<String, dynamic>) parse) =>
      (results[index] as List<Map<String, dynamic>>).map(parse).toList();
  return FinanceWeeklyBudgetSource(
    movements: results[0] as List<FinanzasBankMovementRecord>,
    invoices: decode(1, FinanzasSupplierInvoiceRecord.fromRemoteRow),
    fixedPayments: decode(2, FinanzasFixedPaymentRecord.fromRemoteRow),
    agreements: decode(3, FinanzasSupplierAgreementRecord.fromRemoteRow),
    installments: decode(
      4,
      FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow,
    ),
    agreementLinks: decode(
      5,
      FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow,
    ),
  );
}
