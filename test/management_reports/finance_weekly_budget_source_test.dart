import 'dart:convert';

import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_source.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_pdf_export.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  const tables = [
    'finanzas_bank_movements',
    'finanzas_supplier_invoices',
    'finanzas_fixed_payments',
    'finanzas_supplier_agreements',
    'finanzas_supplier_agreement_installments',
    'finanzas_supplier_agreement_invoices',
  ];
  var failTable = '';
  var count = 1;
  Map<String, dynamic> row(String table, int i) => switch (table) {
    'finanzas_bank_movements' => {
      'id': 'bank$i',
      'movement_date': '2026-09-18',
      'company': 'DICSA',
      'branch': 'CELAYA',
      'credit_amount': 1000,
      'debit_amount': 0,
    },
    'finanzas_supplier_invoices' => {
      'id': 'invoice$i',
      'invoice_date': '2026-07-01',
      'due_date': '2026-08-01',
      'total_amount': 900,
      'balance_amount': 900,
      'provider_name_snapshot': 'Proveedor $i',
      'invoice_folio': 'F$i',
      'target_company': 'DICSA',
      'target_branch': 'CELAYA',
    },
    'finanzas_fixed_payments' => {
      'id': 'fixed$i',
      'payment_date': '2026-09-23',
      'received_date': '2026-09-01',
      'amount': 300,
      'company_name_snapshot': 'Servicios $i',
      'target_company': 'DICSA',
      'branch': 'CELAYA',
    },
    'finanzas_supplier_agreements' => {
      'id': 'agreement$i',
      'remaining_amount': 100,
      'target_company': 'DICSA',
      'target_branch': 'CELAYA',
      'provider_name_snapshot': 'Convenio $i',
    },
    'finanzas_supplier_agreement_installments' => {
      'id': 'installment$i',
      'agreement_id': 'agreement$i',
      'due_date': '2026-09-24',
      'amount': 100,
      'paid_amount': 0,
      'status': 'PENDIENTE',
      'sequence_number': 1,
    },
    'finanzas_supplier_agreement_invoices' => {
      'id': 'link$i',
      'agreement_id': 'agreement$i',
      'installment_id': 'installment$i',
      'invoice_id': 'separate-bill$i',
    },
    'compras_tickets' => {
      'id': 'ticket$i',
      'ticket_date': '2026-09-18',
      'ticket_number': 'T$i',
      'amount': 1000,
      'factura_status': 'SIN_FACTURA',
    },
    'compras_ticket_payment_applications' => {
      'id': 'application$i',
      'ticket_id': 'ticket$i',
      'provider_movement_id': 'payment$i',
      'applied_amount': 100,
      'applied_at': '2026-09-18',
    },
    'finanzas_supplier_invoice_tickets' => {
      'id': 'invoice-ticket$i',
      'ticket_id': 'ticket$i',
      'invoice_id': 'invoice$i',
      'applied_amount': 1000,
    },
    _ => throw StateError('Unexpected source $table'),
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://finance-budget-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(
          request.method,
          'GET',
          reason: 'A proposal cannot execute payments.',
        );
        final table = request.url.pathSegments.last;
        if (table == failTable) {
          return http.Response(
            '{"message":"permission denied","code":"42501"}',
            403,
            request: request,
          );
        }
        final offset =
            int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;
        final limit =
            int.tryParse(request.url.queryParameters['limit'] ?? '') ?? count;
        return http.Response(
          jsonEncode([
            for (var i = offset; i < count && i < offset + limit; i++)
              row(table, i),
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  setUp(() {
    requests.clear();
    failTable = '';
    count = 1;
  });
  tearDownAll(() => Supabase.instance.dispose());

  test(
    'real sources supply fixed requirements and one invoice without a bank balance limit',
    () async {
      final source = await loadFinanceWeeklyBudgetSource();
      final budget = FinanceWeeklyBudgetAnalysis(source, DateTime(2026, 9, 18));
      expect(
        requests.map((r) => r.url.pathSegments.last).toSet(),
        tables.toSet(),
      );
      expect(budget.fixedPayments, 30000);
      expect(budget.agreementHold, 10000);
      expect(budget.proposedInvoices, 90000);
      expect(budget.proposedTotal, 120000);
    },
  );

  test(
    'pagination includes bank, invoices, fixed payments and commitments after row 500',
    () async {
      count = 505;
      final source = await loadFinanceWeeklyBudgetSource();
      expect([
        source.movements.length,
        source.invoices.length,
        source.fixedPayments.length,
        source.agreements.length,
        source.installments.length,
        source.agreementLinks.length,
      ], everyElement(505));
      for (final table in tables) {
        expect(
          requests.any(
            (r) =>
                r.url.pathSegments.last == table &&
                r.url.queryParameters['offset'] == '500',
          ),
          isTrue,
          reason: table,
        );
      }
    },
  );

  test(
    'unavailable obligations or bank history cannot become a zero balance report',
    () async {
      for (final table in tables) {
        failTable = table;
        await expectLater(
          loadFinanceWeeklyBudgetSource(),
          throwsA(isA<PostgrestException>()),
        );
      }
    },
  );

  test(
    'projection reads every Finance ticket classification, link and application strictly',
    () async {
      count = 505;
      final source = await loadFinanceWeeklyBudgetSource(
        includeUninvoiced: true,
      );
      expect(source.tickets.length, 505);
      expect(source.tickets.last.facturaStatus, 'SIN_FACTURA');
      expect(source.ticketApplications.length, 505);
      expect(source.invoiceTickets.length, 505);
      for (final table in [
        'compras_tickets',
        'compras_ticket_payment_applications',
        'finanzas_supplier_invoice_tickets',
      ]) {
        expect(
          requests.any(
            (r) =>
                r.url.pathSegments.last == table &&
                r.url.queryParameters['offset'] == '500',
          ),
          isTrue,
        );
        failTable = table;
        await expectLater(
          loadFinanceWeeklyBudgetSource(includeUninvoiced: true),
          throwsA(isA<PostgrestException>()),
        );
      }
    },
  );
  test(
    'central Finance Friday generator uses the budget sources and dated fixed payments',
    () async {
      final bytes = await buildManagementReportPdfBytes(
        area: managementAreaDefinition(ManagementAreaKey.finanzas),
        frequency: ManagementReportFrequency.weeklyFriday,
        generatedAt: DateTime(2026, 9, 18),
        generatedBy: 'QA',
      );
      expect(bytes.take(4), [37, 80, 68, 70]);
      expect(
        requests.map((r) => r.url.pathSegments.last).toSet(),
        tables.toSet(),
      );
      failTable = 'finanzas_fixed_payments';
      await expectLater(
        buildManagementReportPdfBytes(
          area: managementAreaDefinition(ManagementAreaKey.finanzas),
          frequency: ManagementReportFrequency.weeklyFriday,
          generatedAt: DateTime(2026, 9, 18),
          generatedBy: 'QA',
        ),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
