import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_engine.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_export.dart';
import 'profitability_fixtures.dart';

ProfitReview configured(ProfitSources sources) {
  final initial = analyzeProfitability(sources, const ProfitReview());
  return ProfitReview(
    identities: {'compras:c1': 'site:s1', 'payroll:PLANTA A': 'site:s1'},
    recipes: {
      'site:s1|compras:carton': const ProfitRecipe(
        outputs: [ProfitOutputRule('ventas:paca', .8)],
        note: 'Rendimiento medido',
      ),
    },
    costs: {
      for (final c in initial.costFacts)
        c.key: ProfitCostRule(
          treatment: ProfitCostTreatment.include,
          kind: c.suggestedKind,
          shares: const {'site:s1': 1},
          recognizedAmount: c.payrollNet ? 180 : null,
          note: 'Costo conciliado',
          sourceSignature: c.signature,
        ),
    },
  );
}

void main() {
  test(
    'compares source material with weighted comparable sales, not sale customer',
    () {
      final source = profitFixture();
      var review = configured(source);
      var a = analyzeProfitability(source, review);
      expect(a.benchmarks['ventas:paca']!.price, 6.5);
      expect(a.excludedSales, 1);
      final c = a.companies.single;
      expect(c.entity.key, 'site:s1');
      expect(c.purchases, 700);
      expect(c.materials.single.purchasePrice, 2);
      expect(c.value, 2080);
      expect(c.provisionalContribution, 1100);
      expect(c.contribution, isNull);
      review = review.copyWith(
        companies: {'site:s1': completeReview(a.evidenceSignature)},
      );
      a = analyzeProfitability(source, review);
      expect(a.companies.single.contribution, 1100);
      expect(a.companies.single.result, 1100);
      expect(a.companies.single.complete, true);
      expect(a.companies.single.attributedKm, 80);
      expect(a.companies.single.attributedLiters, isNull);
    },
  );
  test(
    'same names stay separate until explicitly linked; known men site link resolves',
    () {
      final source = profitFixture(
        overrides: {
          'men_tickets': [
            {
              'id': 'men1',
              'ticket_date': '2026-09-12',
              'ticket_number': 'M-1',
              'counterparty_id': 'm1',
              'counterparty_name_snapshot': 'PLANTA A',
              'commercial_material_id': 'carton',
              'material_label_snapshot': 'CARTON',
              'net_weight': 10,
              'payable_weight': 10,
              'amount_total': 20,
              'status': 'PAGADO',
              'direction': 'purchase',
            },
          ],
        },
      );
      final a = analyzeProfitability(source, const ProfitReview());
      expect(
        a.companies.map((c) => c.entity.key).toSet(),
        containsAll(['site:s1', 'compras:c1', 'payroll:PLANTA A']),
      );
      expect(
        a.companies.firstWhere((c) => c.entity.key == 'site:s1').purchases,
        20,
      );
    },
  );
  test(
    'no yield means no value, no payroll override means pending, loan does not lower recognized cost',
    () {
      final s = profitFixture();
      final initial = analyzeProfitability(s, const ProfitReview());
      expect(initial.companies.every((c) => c.contribution == null), true);
      expect(initial.costFacts.firstWhere((c) => c.payrollNet).amount, 130);
      final rh = initial.costFacts.firstWhere((c) => c.payrollNet);
      final a = analyzeProfitability(
        s,
        const ProfitReview().copyWith(
          costs: {
            rh.key: ProfitCostRule(
              treatment: ProfitCostTreatment.include,
              kind: ProfitCostKind.payroll,
              shares: const {'site:s1': 1},
              note: 'Pendiente bruto',
              sourceSignature: rh.signature,
            ),
          },
        ),
      );
      expect(a.pendingCosts[rh.key], contains('costo laboral'));
      expect(
        profitPayrollNet({
          'fiscal_net_amount': 100,
          'fiscal_manual_deduction_amount': 5,
          'fiscal_late_deduction_amount': 10,
          'cash_salary_amount': 50,
          'cash_absence_deduction_amount': 15,
          'check_amount': 90,
          'incidences_informational': true,
        }),
        145,
      );
    },
  );
  test(
    'cent allocations conserve total and documents linked as evidence are not charged twice',
    () {
      final s = profitFixture(
        overrides: {
          'finanzas_supplier_invoices': [
            {
              'id': 'i1',
              'invoice_date': '2026-09-12',
              'origin_type': 'MANUAL',
              'status': 'PENDIENTE',
              'total_amount': 100,
            },
          ],
        },
      );
      final a = analyzeProfitability(s, const ProfitReview());
      final bank = a.costFacts.firstWhere((f) => f.key == 'bank:fuel'),
          invoice = a.costFacts.firstWhere((f) => f.key == 'invoice:i1');
      final r = ProfitReview(
        costs: {
          bank.key: ProfitCostRule(
            treatment: ProfitCostTreatment.include,
            kind: ProfitCostKind.fuel,
            shares: const {'site:s1': .333333, 'site:s2': .666667},
            note: 'Km',
            sourceSignature: bank.signature,
          ),
          invoice.key: ProfitCostRule(
            treatment: ProfitCostTreatment.duplicate,
            kind: ProfitCostKind.fuel,
            note: 'Mismo costo',
            sourceSignature: invoice.signature,
            duplicateOf: bank.key,
          ),
        },
      );
      final result = analyzeProfitability(s, r);
      expect(result.assignedCosts, 100);
      expect(result.pendingCosts.containsKey(invoice.key), false);
      expect(
        result.companies
            .firstWhere((c) => c.entity.key == 'site:s1')
            .costs[ProfitCostKind.fuel],
        33.33,
      );
    },
  );
  test(
    'changes invalidate cost rules and review even with same record IDs',
    () {
      final s = profitFixture();
      var r = configured(s);
      final a = analyzeProfitability(s, r);
      r = r.copyWith(
        companies: {'site:s1': completeReview(a.evidenceSignature)},
      );
      final changed = profitFixture(
        overrides: {
          'finanzas_bank_movements': [
            {
              'id': 'fuel',
              'movement_date': '2026-09-12',
              'debit_amount': 110,
              'category': 'DIESEL',
              'reference': 'F-1',
            },
          ],
        },
      );
      final b = analyzeProfitability(changed, r);
      expect(b.pendingCosts['bank:fuel'], contains('cambió'));
      expect(
        b.companies.firstWhere((c) => c.entity.key == 'site:s1').contribution,
        isNull,
      );
    },
  );
  test(
    'invalid amount never produces estimated value; future and unapproved sales excluded',
    () {
      final s = profitFixture(
        overrides: {
          'compras_tickets': [
            {...purchase('p1', 100, 100, 100), 'amount': null},
          ],
          'mayoreo_sales_reports': [
            sale('ok', 10, 50),
            {...sale('future', 10, 100), 'sale_date': '2026-09-22'},
            sale('unapproved', 0, 100),
          ],
        },
      );
      final a = analyzeProfitability(s, configured(s));
      expect(a.benchmarks['ventas:paca']!.price, 5);
      expect(
        a.companies.firstWhere((c) => c.entity.key == 'site:s1').value,
        isNull,
      );
    },
  );
  test(
    'cycles, excessive yields, duplicated IDs and partial allocations fail',
    () {
      expect(
        () => const ProfitReview(identities: {'a': 'b', 'b': 'a'}).validate(),
        throwsStateError,
      );
      expect(
        () => const ProfitReview(
          recipes: {
            'a': ProfitRecipe(
              outputs: [ProfitOutputRule('x', .8), ProfitOutputRule('y', .3)],
              note: 'x',
            ),
          },
        ).validate(),
        throwsStateError,
      );
      expect(
        () => ProfitReview(
          costs: {
            'a': ProfitCostRule(
              treatment: ProfitCostTreatment.include,
              kind: ProfitCostKind.other,
              shares: const {'site:s1': .5},
              note: 'x',
              sourceSignature: 'x',
            ),
          },
        ).validate(),
        throwsStateError,
      );
      expect(
        () => analyzeProfitability(
          profitFixture(
            overrides: {
              'compras_tickets': [
                purchase('same', 10, 10, 10),
                purchase('same', 20, 20, 20),
              ],
            },
          ),
          const ProfitReview(),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'review must be repeated after recipe change; company review does not invalidate other reviews',
    () {
      final s = profitFixture();
      final r = configured(s);
      final a = analyzeProfitability(s, r);
      final marked = r.copyWith(
        companies: {'site:s1': completeReview(a.evidenceSignature)},
      );
      expect(
        analyzeProfitability(s, marked).evidenceSignature,
        a.evidenceSignature,
      );
      final changed = marked.copyWith(
        recipes: {
          'site:s1|compras:carton': const ProfitRecipe(
            outputs: [ProfitOutputRule('ventas:paca', .9)],
            note: 'Nueva recuperación',
          ),
        },
      );
      expect(analyzeProfitability(s, changed).companies.single.reviewed, false);
    },
  );
  test(
    'excluded tickets require exact evidence and can be restored; snapshots and CSV retain pending status',
    () {
      final s = profitFixture();
      final a = analyzeProfitability(s, const ProfitReview());
      final p = a.purchases.first;
      final r = ProfitReview(
        excludedPurchases: {
          p.key: {'signature': p.signature, 'note': 'Duplicado confirmado'},
        },
      );
      expect(analyzeProfitability(s, r).purchases.length, 1);
      expect(
        analyzeProfitability(
          s,
          r.copyWith(excludedPurchases: {}),
        ).purchases.length,
        2,
      );
      final json = jsonDecode(a.toPrettyJson()) as Map;
      expect(json['companies'][0]['contribution'], null);
      expect(json['source_counts']['compras_tickets'], 2);
      expect(profitCsvText('=SUM(1,2)'), startsWith('"\''));
      expect(profitCsv(a), contains('Información insuficiente'));
    },
  );
  test(
    'exit scenario uses actual avoidable cost rather than assigned overhead',
    () {
      const s = ProfitExitScenario(
        lostRevenue: 1000,
        avoidedPurchases: 400,
        avoidedOperations: 200,
        avoidedOverhead: 0,
        replacementContribution: 100,
        transitionCost: 50,
      );
      expect(s.improvement, -350);
    },
  );
  test('closed payroll gaps and overlaps prevent a complete result', () {
    final empty = profitFixture(overrides: {'hr_payroll_period_closures': []});
    expect(
      analyzeProfitability(empty, const ProfitReview()).issues.join(' '),
      contains('cubre 0 de 7'),
    );
    final overlapping = profitFixture(
      overrides: {
        'hr_payroll_period_closures': [
          {'id': 'close1', 'period_label': payrollLabel, 'status': 'cerrado'},
          {
            'id': 'close2',
            'period_label': 'EXTRA (11/09/2026 - 17/09/2026)',
            'status': 'cerrado',
          },
        ],
      },
    );
    expect(
      analyzeProfitability(overlapping, const ProfitReview()).issues.join(' '),
      contains('superpuesta'),
    );
  });
  test(
    'snapshot contains sale row evidence without individual payroll information',
    () {
      final json = analyzeProfitability(
        profitFixture(),
        const ProfitReview(),
      ).snapshot();
      expect((json['sale_evidence'] as Map)['mayoreo'], hasLength(3));
      expect((json['source_ids'] as Map)['hr_prenomina_draft_rows'], ['rh1']);
      expect(jsonEncode(json), isNot(contains('employee_id')));
      expect(jsonEncode(json), isNot(contains('employee_name')));
    },
  );
}
