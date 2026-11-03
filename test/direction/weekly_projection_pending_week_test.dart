import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_due_alerts_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as f;

final week = DateTime(2026, 9, 21);
FinanceWeeklyBudgetAnalysis analyze(FinanceWeeklyBudgetSource source) =>
    FinanceWeeklyBudgetAnalysis(
      source,
      week,
      targetWeek: week,
      onlyWeekPending: true,
    );

void main() {
  test(
    'automatic selection uses the Pendientes week, including Monday and Sunday',
    () {
      final source = f.budgetSource(
        invoices: [
          f.invoice('old', 100, '2026-09-20'),
          f.invoice('monday', 200, '2026-09-21'),
          f.invoice('sunday', 300, '2026-09-27', provider: 'B'),
          f.invoice('next', 400, '2026-09-28', provider: 'C'),
          f.invoice('undated', 500, null, provider: 'D'),
          f.invoice('paid', 600, '2026-09-23', status: 'PAGADA'),
        ],
        fixedPayments: [
          f.fixed('old', 600000, '2026-09-20'),
          f.fixed('monday', 100, '2026-09-21', method: 'EFECTIVO'),
          f.fixed('sunday', 200, '2026-09-27', method: 'BANCO'),
          f.fixed('next', 300, '2026-09-28'),
        ],
      );
      final pending = FinanzasDueAlertsStore.summarize(
        now: week.add(const Duration(days: 2)),
        invoices: source.invoices,
        fixedPayments: source.fixedPayments,
        agreements: source.agreements,
        installments: source.installments,
        agreementInvoiceLinks: source.agreementLinks,
      );
      final analysis = analyze(source);
      final proposal = paymentProposal(analysis);
      expect(proposal.where((r) => r.included).map((r) => r.id).toSet(), {
        'invoice:monday',
        'invoice:sunday',
        'fixed:monday',
        'fixed:sunday',
      });
      expect(pending.weekItems.length, 4);
      expect(
        analysis.proposedTotal,
        (pending.weekItems.fold<double>(0, (s, r) => s + r.amount) * 100)
            .round(),
      );
      expect(analysis.fixedPayments, 30000);
      expect(analysis.pendingFixedPayments, 0);
      expect(analysis.baseRequirement, 80000);
      expect(analysis.accounts.single.fixedRequired, 30000);
      expect(
        proposal.singleWhere((r) => r.id == 'invoice:old').available,
        10000,
      );
      expect(
        proposal.singleWhere((r) => r.id == 'fixed:old').available,
        60000000,
      );
      // Original Friday report still includes dated backlog.
      final friday = FinanceWeeklyBudgetAnalysis(
        source,
        week,
        targetWeek: week,
      );
      expect(friday.fixedPayments, 60030000);
      expect(friday.pendingFixedPayments, 60000000);
    },
  );

  test(
    'weekly selection keeps fixed priority, whole invoices, supplier order and cap',
    () {
      final analysis = analyze(
        f.budgetSource(
          fixedPayments: [f.fixed('rent', 50000, '2026-09-23')],
          invoices: [
            f.invoice('old-A', 600000, '2026-09-20'),
            f.invoice('a-1', 100000, '2026-09-21'),
            f.invoice('a-2', 200000, '2026-09-22'),
            f.invoice('b-1', 50000, '2026-09-21', provider: 'B'),
            f.invoice('b-2', 50000, '2026-09-22', provider: 'B'),
            f.invoice('c-1', 20000, '2026-09-21', provider: 'C'),
            f.invoice('c-2', 5000, '2026-09-22', provider: 'C'),
          ],
        ),
      );
      expect(analysis.proposedTotal, 47000000);
      expect(analysis.additionalCount, 2);
      expect(analysis.proposedRows.map((r) => r.invoice.id).toSet(), {
        'a-1',
        'a-2',
        'b-1',
        'b-2',
        'c-1',
      });
      expect(
        analysis.proposedRows.every((r) => r.proposed == r.balance),
        isTrue,
      );
      expect(analysis.remainingBudget, 3000000);
      final blocked = analyze(
        f.budgetSource(
          fixedPayments: [f.fixed('over-limit', 500001, '2026-09-24')],
          invoices: [f.invoice('invoice', 1, '2026-09-25')],
        ),
      );
      expect(blocked.proposedInvoices, 0);
      expect(blocked.pendingFixedPayments, 50000100);
    },
  );

  test('week scope keeps net balances and agreement protection', () {
    final analysis = analyze(
      f.budgetSource(
        invoices: [
          f.invoice('partial', 1000, '2026-09-24', balance: 800),
          f.invoice('covered', 900, '2026-09-25', provider: 'B'),
          f.invoice('cancelled', 1000, '2026-09-24', status: 'CANCELADA'),
        ],
        fixedPayments: [f.fixed('partial', 300, '2026-09-23')],
        movements: [
          f.bank('invoice-paid', '2026-09-21', 0, 300, invoice: 'partial'),
          f.bank('fixed-paid', '2026-09-21', 0, 100, fixed: 'partial'),
          f.bank('future', '2026-09-22', 0, 700, invoice: 'partial'),
        ],
        agreements: [
          FinanzasSupplierAgreementRecord.fromRemoteRow({
            'id': 'agreement',
            'provider_name_snapshot': 'B',
            'target_company': 'DICSA',
            'target_branch': 'CELAYA',
            'status': 'ACTIVO',
            'remaining_amount': 900,
          }),
        ],
        installments: [
          FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow({
            'id': 'installment',
            'agreement_id': 'agreement',
            'due_date': '2026-09-25',
            'amount': 900,
            'paid_amount': 0,
            'status': 'PENDIENTE',
          }),
        ],
        links: [
          FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow({
            'id': 'link',
            'agreement_id': 'agreement',
            'installment_id': 'installment',
            'invoice_id': 'covered',
          }),
        ],
      ),
    );
    final rows = {for (final row in paymentProposal(analysis)) row.id: row};
    expect(rows['invoice:partial']!.total, 70000);
    expect(rows['fixed:partial']!.total, 20000);
    expect(rows['invoice:covered']!.available, 0);
    expect(rows['agreement:installment']!.available, 90000);
    expect(rows['agreement:installment']!.included, isFalse);
    expect(rows.containsKey('invoice:cancelled'), isFalse);
  });

  test(
    'selected week crosses year boundaries without changing the read cutoff',
    () {
      final now = DateTime(2026, 12, 25);
      final target = DateTime(2026, 12, 28);
      final source = f.budgetSource(
        invoices: [
          f.invoice('previous', 100, '2026-12-27'),
          f.invoice('monday', 200, '2026-12-28'),
          f.invoice('sunday', 300, '2027-01-03', provider: 'B'),
          f.invoice('next', 400, '2027-01-04', provider: 'C'),
        ],
      );
      for (final readAt in [
        now,
        DateTime(2026, 12, 30),
        DateTime(2027, 1, 8),
      ]) {
        final analysis = FinanceWeeklyBudgetAnalysis(
          source,
          readAt,
          targetWeek: target,
          onlyWeekPending: true,
        );
        expect(analysis.period.asOf, readAt);
        expect(analysis.proposedRows.map((r) => r.invoice.id), [
          'monday',
          'sunday',
        ]);
      }
    },
  );
}
