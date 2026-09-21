import 'dart:io';

import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_finance_budget_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'finance_weekly_budget_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final at = DateTime(2026, 9, 18, 17);
  test(
    'Friday budgets next Monday through Sunday, including year changes and weekends',
    () {
      for (final day in [18, 19, 20]) {
        final period = FinanceBudgetPeriod(DateTime(2026, 9, day));
        expect(period.start, DateTime(2026, 9, 21));
        expect(period.end, DateTime(2026, 9, 27));
        expect(period.historyEnd, DateTime(2026, 9, 13));
      }
      expect(
        FinanceBudgetPeriod(DateTime(2026, 12, 25)).end,
        DateTime(2027, 1, 3),
      );
    },
  );
  test(
    'selection depends on requirements, not bank balances or forecast history',
    () {
      for (final movements in [
        history(balance: 0),
        history(balance: 1000000),
        history(spike: true),
        <dynamic>[],
      ]) {
        final report = FinanceWeeklyBudgetAnalysis(
          budgetSource(
            movements: movements.cast(),
            fixedPayments: [fixed('rent', 300, '2026-09-22')],
            invoices: [
              invoice('new-A', 400, '2026-08-10'),
              invoice('old-A', 800, '2026-07-30'),
              invoice('old-B', 500, '2026-08-01', provider: 'Proveedor B'),
            ],
          ),
          at,
        );
        expect(report.proposedRows.map((r) => r.invoice.id), [
          'old-A',
          'old-B',
        ]);
        expect(report.proposedInvoices, 130000);
        expect(report.proposedTotal, 160000);
        expect(report.additionalCount, 0);
      }
    },
  );
  test(
    'historical median excludes internal transfers and never sets the budget',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          movements: [
            ...history(spike: true),
            bank(
              'transfer',
              '2026-08-03',
              200000,
              0,
              category: 'MOVIMIENTOS INTERNOS',
            ),
            bank(
              'vault',
              '2026-08-04',
              300000,
              0,
              counterparty: 'CHEQUE A BOVEDA',
            ),
            bank('future', '2026-09-22', 900000, 0),
          ],
        ),
        at,
      );
      expect(data.accounts.single.medianCredits, 100000);
      expect(data.accounts.single.history, hasLength(8));
      expect(data.ignoredFutureMovements, 1);
      expect(data.excludedForecastMovements, 2);
      expect(data.proposedTotal, 0);
    },
  );
  test('short history is disclosed but cannot prevent invoice selection', () {
    final data = FinanceWeeklyBudgetAnalysis(
      budgetSource(
        movements: [
          bank('recent', '2026-09-03', 10, 0),
          bank('week', '2026-09-07', 10, 0),
        ],
        invoices: [invoice('a', 90000, '2026-08-01')],
      ),
      at,
    );
    expect(data.accounts.single.history, hasLength(1));
    expect(data.proposedInvoices, 9000000);
    expect(data.warnings.single, contains('solo como referencia'));
  });
  test(
    'one base invoice per supplier across branches and paying companies',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          invoices: [
            invoice('a-old', 50000, '2026-07-01', company: 'VH'),
            invoice('a-new', 40000, '2026-07-02'),
            invoice('b', 20000, '2026-07-03', provider: 'B'),
          ],
        ),
        at,
      );
      expect(data.proposedRows.map((r) => r.invoice.id), ['a-old', 'b']);
      expect(
        data.accounts.firstWhere((a) => a.key == 'VH|CELAYA').proposed,
        5000000,
      );
    },
  );
  test(
    'extra whole invoices target high debt only after one invoice for every supplier',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          fixedPayments: [fixed('rent', 50000, '2026-09-22')],
          invoices: [
            invoice('a-1', 100000, '2026-07-01'),
            invoice('a-2', 200000, '2026-07-02'),
            invoice('b-1', 50000, '2026-07-03', provider: 'B'),
            invoice('b-2', 50000, '2026-07-04', provider: 'B'),
            invoice('c-1', 20000, '2026-07-05', provider: 'C'),
            invoice('c-2', 5000, '2026-07-06', provider: 'C'),
          ],
        ),
        at,
      );
      expect(data.proposedTotal, 47000000);
      expect(data.remainingBudget, 3000000);
      expect(data.additionalCount, 2);
      expect(
        data.proposedRows.where((r) => r.additional).map((r) => r.invoice.id),
        ['a-2', 'b-2'],
      );
      expect(data.invoices.last.proposed, 0);
      expect(data.proposedRows.every((r) => r.proposed == r.balance), isTrue);
    },
  );
  test(
    'uncovered base invoices block extras and total includes fixed payments within 500k',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          fixedPayments: [fixed('rent', 50000, '2026-09-22')],
          invoices: [
            invoice('a-1', 400000, '2026-07-01'),
            invoice('a-2', 10000, '2026-07-02'),
            invoice('b', 60000, '2026-07-03', provider: 'B'),
            invoice('c', 20000, '2026-07-04', provider: 'C'),
          ],
        ),
        at,
      );
      expect(data.proposedTotal, 47000000);
      expect(data.baseOverLimit, 3000000);
      expect(data.uncoveredProviders, 1);
      expect(data.additionalCount, 0);
      expect(data.proposedRows.map((r) => r.invoice.id), ['a-1', 'c']);
    },
  );
  test(
    'invoice larger than the ceiling is not split or bypassed for a newer invoice',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          invoices: [
            invoice('a-old', 600000, '2026-07-01'),
            invoice('a-new', 10000, '2026-07-02'),
            invoice('b', 25000, '2026-07-03', provider: 'B'),
          ],
        ),
        at,
      );
      expect(data.proposedRows.map((r) => r.invoice.id), ['b']);
      expect(data.proposedTotal, 2500000);
    },
  );
  test('cap is exact to the cent including fixed payments', () {
    final data = FinanceWeeklyBudgetAnalysis(
      budgetSource(
        fixedPayments: [fixed('fee', .01, '2026-09-22')],
        invoices: [
          invoice('a', 199999.99, '2026-07-01'),
          invoice('b', 300000, '2026-07-02', provider: 'B'),
        ],
      ),
      at,
    );
    expect(data.proposedTotal, FinanceWeeklyBudgetAnalysis.weeklyLimit);
    expect(data.remainingBudget, 0);
  });
  test(
    'fixed payments include dated backlog, exclude paid and later items, reconcile partial bank payment',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          movements: [
            bank('balance', '2026-09-18', 1000, 0),
            bank(
              'part',
              '2026-09-18',
              0,
              100,
              category: 'SERVICIOS',
              fixed: 'partial',
            ),
          ],
          fixedPayments: [
            fixed('late', 100, '2026-09-10'),
            fixed('sunday', 150, '2026-09-27', method: 'EFECTIVO'),
            fixed('future', 500, '2026-09-28'),
            fixed('paid', 800, '2026-09-22', status: 'PAGADO'),
            fixed('partial', 300, '2026-09-23'),
          ],
        ),
        at,
      );
      expect(data.fixedPayments, 45000);
      expect(data.commitments, hasLength(3));
      expect(
        data.commitments
            .firstWhere((r) => r.label == 'Servicios partial')
            .amount,
        20000,
      );
      expect(data.proposedTotal, 45000);
    },
  );
  test(
    'reconciles invoice balance without resurrecting prior reductions or paying missing due dates',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          movements: [
            bank('balance', '2026-09-18', 2000, 0),
            bank(
              'paid',
              '2026-09-18',
              0,
              199.50,
              invoice: 'part',
              applied: 200,
            ),
          ],
          invoices: [
            invoice('part', 1000, '2026-08-01', balance: 300),
            invoice('none', 1000, null),
            invoice('future', 1000, '2026-09-28'),
            invoice('settled', 1000, '2026-08-01', status: 'PAGADA'),
          ],
        ),
        at,
      );
      expect(
        data.invoices.firstWhere((r) => r.invoice.id == 'part').balance,
        30000,
      );
      expect(data.proposedInvoices, 30000);
      expect(
        data.invoices.firstWhere((r) => r.invoice.id == 'none').reviewReason,
        'Confirmar vencimiento',
      );
    },
  );
  test(
    'agreement-linked invoices preserve their schedule without consuming the new selection ceiling',
    () {
      final agreement = FinanzasSupplierAgreementRecord.fromRemoteRow({
        'id': 'a',
        'provider_id': 'Proveedor A',
        'provider_name_snapshot': 'Proveedor A',
        'remaining_amount': 500,
        'total_amount': 500,
        'installment_amount': 200,
        'status': 'ACTIVO',
      });
      final installment =
          FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow({
            'id': 'i',
            'agreement_id': 'a',
            'sequence_number': 1,
            'due_date': '2026-09-23',
            'amount': 200,
            'paid_amount': 50,
            'status': 'PENDIENTE',
          });
      final link = FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow({
        'id': 'l',
        'agreement_id': 'a',
        'installment_id': 'i',
        'invoice_id': 'covered',
      });
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          movements: [bank('b', '2026-09-18', 500, 0)],
          invoices: [
            invoice('covered', 500, '2026-07-10'),
            invoice('other', 500, '2026-07-11', provider: 'Otro'),
          ],
          agreements: [agreement],
          installments: [installment],
          links: [link],
        ),
        at,
      );
      expect(data.agreementHold, 15000);
      expect(data.proposedInvoices, 50000);
      expect(data.proposedTotal, 50000);
      expect(data.invoices.first.proposed, 0);
      expect(data.invoices.first.reviewReason, contains('convenio'));
    },
  );
  test(
    'fixed requirements exceeding the ceiling stay visible and no invoice is added',
    () {
      final data = FinanceWeeklyBudgetAnalysis(
        budgetSource(
          fixedPayments: [
            fixed('first', 400000, '2026-09-22'),
            fixed('large', 150000, '2026-09-23'),
            fixed('small', 50000, '2026-09-24'),
          ],
          invoices: [invoice('a', 1000, '2026-08-01')],
        ),
        at,
      );
      expect(data.fixedPayments, 60000000);
      expect(data.proposedFixedPayments, 45000000);
      expect(data.pendingFixedPayments, 15000000);
      expect(data.proposedInvoices, 0);
      expect(
        data.proposedTotal,
        lessThanOrEqualTo(FinanceWeeklyBudgetAnalysis.weeklyLimit),
      );
    },
  );
  test(
    'duplicate transaction ids and nonfinite amounts cannot inflate proposed resources',
    () {
      final b = bank('same', '2026-09-18', 100, 0);
      expect(
        () => FinanceWeeklyBudgetAnalysis(budgetSource(movements: [b, b]), at),
        throwsStateError,
      );
      expect(
        () => FinanceWeeklyBudgetAnalysis(
          budgetSource(movements: [bank('nan', '2026-09-18', double.nan, 0)]),
          at,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'reference layout renders normal, dense and empty plans without payroll or cash allocations',
    () async {
      final out = Platform.environment['DICSA_FINANCE_BUDGET_QA_DIR'];
      for (final mode in [
        'normal',
        'denso',
        'vacio',
        'restringido',
        'fijos_excedidos',
      ]) {
        final dense = mode == 'denso';
        final restricted = mode == 'restringido';
        final source = mode == 'vacio'
            ? budgetSource()
            : budgetSource(
                movements: [
                  ...history(
                    balance: restricted
                        ? 500
                        : dense
                        ? 300000
                        : 15000,
                  ),
                  if (restricted)
                    bank('vh', '2026-09-18', 100, 0, company: 'VH'),
                ],
                invoices: [
                  for (var i = 0; i < (dense ? 65 : 15); i++)
                    invoice(
                      'F-${4541 + i}',
                      restricted
                          ? 180000 + i * 2000
                          : dense
                          ? 10000 + i * 200
                          : 500 + i * 20,
                      '2026-08-${(i % 28 + 1).toString().padLeft(2, '0')}',
                      provider: dense
                          ? 'Proveedor ${i % 12} ${List.filled(6, 'nombre comercial extenso').join(' ')}'
                          : 'Proveedor ${i % 7 + 1}',
                    ),
                ],
                fixedPayments: mode == 'fijos_excedidos'
                    ? [fixed('grande', 600000, '2026-09-22')]
                    : restricted
                    ? [
                        fixed('renta', 30000, '2026-09-22'),
                        fixed(
                          'sin-cobertura',
                          500,
                          '2026-09-23',
                          company: 'VH',
                        ),
                      ]
                    : [
                        fixed(
                          'renta',
                          1200,
                          '2026-09-22',
                          notes: dense
                              ? List.filled(20, 'Concepto largo').join(' ')
                              : 'Renta de instalaciones',
                        ),
                        fixed('servicios', 850, '2026-09-25'),
                        fixed('atrasado', 350, '2026-09-15'),
                      ],
              );
        final bytes = await buildFinanceWeeklyBudgetPdfBytes(
          area: managementAreaDefinition(ManagementAreaKey.finanzas),
          generatedAt: at,
          generatedBy: 'QA / DATOS SIMULADOS',
          source: source,
        );
        expect(bytes.take(4), [37, 80, 68, 70]);
        if (out != null) {
          await Directory(out).create(recursive: true);
          await File('$out/finanzas_$mode.pdf').writeAsBytes(bytes);
        }
      }
    },
  );
}
