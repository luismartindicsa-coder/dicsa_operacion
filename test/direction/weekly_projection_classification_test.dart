import 'package:dicsa_operacion/app/compras/compras_tickets_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as f;

final week = DateTime(2026, 9, 21);
ComprasTicketRecord ticket(
  String id, {
  String status = 'SIN_FACTURA',
  String payment = 'PENDIENTE_DE_PAGO',
}) => ComprasTicketRecord.fromRemoteRow({
  'id': id,
  'ticket_date': '2026-09-18',
  'ticket_number': id,
  'provider_id': 'supplier',
  'provider_name_snapshot': 'Proveedor',
  'amount': 1000,
  'factura_status': status,
  'pago_status': payment,
});
List<ProjectedPayment> proposal(FinanceWeeklyBudgetSource source) =>
    paymentProposal(
      FinanceWeeklyBudgetAnalysis(source, week, targetWeek: week),
    );

void main() {
  test(
    'Finance invoices are fiscal regardless of origin; sin factura tickets are cash',
    () {
      final result = proposal(
        f.budgetSource(
          invoices: [
            f.invoice('invoice', 1000, '2026-09-25'),
            f
                .invoice('manual', 900, '2026-09-25', provider: 'B')
                .copyWith(originType: 'MANUAL'),
          ],
          tickets: [
            ticket('cash'),
            ticket('pending', status: 'PENDIENTE_DE_FACTURAR'),
          ],
        ),
      );
      expect(
        {for (final r in result) r.id: r.paymentType},
        {
          'invoice:invoice': 'FISCAL',
          'invoice:manual': 'FISCAL',
          'ticket:cash': 'EFECTIVO',
          'ticket:pending': 'SIN_CLASIFICAR',
        },
      );
      expect(result.every((r) => r.paymentTypeAutomatic), isTrue);
      // Reading classifications does not silently expand the Friday selection.
      expect(
        result.where((r) => r.source == 'ticket').every((r) => !r.included),
        isTrue,
      );
    },
  );
  test(
    'invoiced/linked/paid tickets never duplicate the payable; direct applications reduce balance once',
    () {
      final result = proposal(
        f.budgetSource(
          tickets: [
            ticket('cash'),
            ticket('paid', payment: 'PAGADO'),
            ticket('invoiced', status: 'FACTURADO'),
            ticket('linked'),
          ],
          invoiceTickets: [
            FinanzasSupplierInvoiceTicketRecord.fromRemoteRow({
              'id': 'link',
              'invoice_id': 'i',
              'ticket_id': 'linked',
              'applied_amount': 1000,
            }),
          ],
          ticketApplications: [
            ComprasTicketPaymentApplicationRecord.fromRemoteRow({
              'id': 'p',
              'ticket_id': 'cash',
              'provider_movement_id': 'm',
              'applied_amount': 300,
              'applied_at': '2026-09-20',
            }),
          ],
        ),
      );
      expect(result.length, 1);
      expect(result.single.id, 'ticket:cash');
      expect(result.single.available, 70000);
      expect(result.single.paymentType, 'EFECTIVO');
    },
  );
  test(
    'invoice agreements inherit fiscal; amount agreements remain undetermined and protect their tickets',
    () {
      final result = proposal(
        f.budgetSource(
          agreements: [
            for (final type in ['POR_FACTURAS', 'POR_MONTO'])
              FinanzasSupplierAgreementRecord.fromRemoteRow({
                'id': type,
                'provider_id': type == 'POR_MONTO' ? 'supplier' : 'another',
                'provider_name_snapshot': 'Convenio',
                'agreement_type': type,
                'remaining_amount': 1000,
                'status': 'ACTIVO',
              }),
          ],
          installments: [
            for (final type in ['POR_FACTURAS', 'POR_MONTO'])
              FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow({
                'id': 'installment-$type',
                'agreement_id': type,
                'due_date': '2026-09-23',
                'amount': 1000,
              }),
          ],
          tickets: [ticket('cash')],
        ),
      );
      expect(
        result
            .firstWhere((r) => r.id == 'agreement:installment-POR_FACTURAS')
            .paymentType,
        'FISCAL',
      );
      expect(
        result
            .firstWhere((r) => r.id == 'agreement:installment-POR_MONTO')
            .paymentType,
        'SIN_CLASIFICAR',
      );
      expect(result.firstWhere((r) => r.id == 'ticket:cash').available, 0);
    },
  );
  test(
    'agreement invoice remains unavailable even when another review reason takes priority',
    () {
      final result = proposal(
        f.budgetSource(
          invoices: [f.invoice('linked', 1000, '2026-09-24', company: '')],
          agreements: [
            FinanzasSupplierAgreementRecord.fromRemoteRow({
              'id': 'active',
              'status': 'ACTIVO',
              'remaining_amount': 1000,
              'agreement_type': 'POR_FACTURAS',
              'provider_name_snapshot': 'Proveedor A',
            }),
          ],
          links: [
            FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow({
              'id': 'link',
              'agreement_id': 'active',
              'invoice_id': 'linked',
            }),
          ],
        ),
      ).singleWhere((r) => r.source == 'invoice');
      expect(result.warning, 'Revisar cuenta de pago');
      expect(result.available, 0);
      expect(result.included, false);
    },
  );
  test(
    'legacy unclassified projection fills Finance type while preserving amount, date, exclusion and notes',
    () {
      final current = proposal(
        f.budgetSource(invoices: [f.invoice('i', 1000, '2026-09-25')]),
      );
      final json =
          current.single
              .copyWith(amount: 12345, included: false, notes: 'Mantener')
              .toJson()
            ..remove('payment_type_automatic')
            ..['payment_type'] = 'SIN_CLASIFICAR';
      final result = reconcilePayments([
        ProjectedPayment.fromJson(json),
      ], current).single;
      expect(result.paymentType, 'FISCAL');
      expect(result.paymentTypeAutomatic, isTrue);
      expect(result.amount, 12345);
      expect(result.included, isFalse);
      expect(result.notes, 'Mantener');
      expect(result.date, DateTime(2026, 9, 25));
    },
  );
  test(
    'manual classification survives refresh and serialization even after Finance changes',
    () {
      final current = proposal(
        f.budgetSource(invoices: [f.invoice('i', 1000, '2026-09-25')]),
      );
      final manual = current.single.copyWith(
        paymentType: 'EFECTIVO',
        paymentTypeAutomatic: false,
      );
      final result = reconcilePayments([
        ProjectedPayment.fromJson(manual.toJson()),
      ], current).single;
      expect(result.paymentType, 'EFECTIVO');
      expect(result.paymentTypeAutomatic, isFalse);
      final legacy = manual.toJson()..remove('payment_type_automatic');
      expect(
        reconcilePayments([
          ProjectedPayment.fromJson(legacy),
        ], current).single.paymentType,
        'EFECTIVO',
      );
    },
  );
  test(
    'automatic ticket classification follows Finance; invoicing removes ticket to prevent duplication',
    () {
      final original = proposal(
        f.budgetSource(tickets: [ticket('cash')]),
      ).single.copyWith(amount: 10000, included: true);
      final nowPending = proposal(
        f.budgetSource(
          tickets: [ticket('cash', status: 'PENDIENTE_DE_FACTURAR')],
        ),
      );
      expect(
        reconcilePayments([original], nowPending).single.paymentType,
        'SIN_CLASIFICAR',
      );
      final nowInvoiced = proposal(
        f.budgetSource(
          tickets: [ticket('cash', status: 'FACTURADO')],
          invoices: [f.invoice('i', 1000, '2026-09-25')],
        ),
      );
      expect(reconcilePayments([original], nowInvoiced).single.total, 0);
      expect(nowInvoiced.single.paymentType, 'FISCAL');
    },
  );
}
