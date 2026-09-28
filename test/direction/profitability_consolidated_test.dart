import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_parameters.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_account_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_consolidated.dart';

ProfitCompanyResult decisionCompany(
  String key,
  Map<String, double> amounts, {
  double trips = 5,
}) {
  final line = ProfitAccountLine('material', 'CARTON')..kg = 1000;
  line.components.addAll(
    amounts.entries.map(
      (e) => ProfitComponent(
        id: '$key:${e.key}',
        block: e.key,
        date: DateTime(2026, 9, 1),
        amount: e.value,
        sourceType: ProfitSourceType.estimated,
        reference: 'fixture',
        rule: 'fixture',
        confidence: .5,
        sharedSupport: e.key == 'administration',
      ),
    ),
  );
  return ProfitCompanyResult(ProfitEntity(key, key, 'test'), [])
    ..account = ProfitAccountResult(
      lines: [line],
      assumptions: [],
      kilometers: trips * 20,
      serviceCount: trips,
      containers: 1,
    );
}

ProfitConsolidated decisionFixture() => ProfitConsolidated([
  decisionCompany('A', {
    'value': 1000,
    'income': 200,
    'purchase': 600,
    'fuel': 100,
    'payroll': 300,
    'administration': 400,
    'containers': 50,
    'overhead': 50,
  }),
  decisionCompany('B', {'value': 1000, 'purchase': 400}),
]);

void main() {
  test(
    'real consolidated cut reconciles every exit without removing shared payroll',
    () async {
      final path = Platform.environment['DICSA_PROFIT_CONSOLIDATED_INPUT'];
      if (path == null) return;
      final s =
          (jsonDecode(await File(path).readAsString()) as Map)['analysis']
              as Map;
      final companies = <ProfitCompanyResult>[];
      var expectedResult = 0.0;
      for (final c in s['companies'] as List) {
        final a = c['account'];
        if (a is! Map) continue;
        final amounts = <String, double>{};
        for (final line in a['lines'] as List) {
          for (final component in line['components'] as List) {
            final block = component['block'] as String;
            amounts[block] =
                (amounts[block] ?? 0) + (component['amount'] as num).toDouble();
          }
        }
        companies.add(
          decisionCompany(
            c['key'],
            amounts,
            trips: (a['services'] as num).toDouble(),
          ),
        );
        expectedResult += (a['after_overhead'] as num).toDouble();
      }
      final total = ProfitConsolidated(companies);
      expect(total.result, closeTo(expectedResult, .001));
      for (final c in companies) {
        final impact = total.simulate(c.entity.key, ProfitDecisionPlan());
        final others = companies
            .where((r) => r != c)
            .fold<double>(0, (s, r) => s + r.account!.afterOverhead);
        expect(impact.after, closeTo(others - impact.retainedCost, .001));
        expect(impact.savings['administration'], 0);
        expect(impact.savings['payroll'], 0);
        expect(impact.retainedCost, greaterThanOrEqualTo(-.001));
      }
      // Aggregate evidence only; no personnel details or credentials.
      debugPrint(
        'Consolidado: ${companies.length} cuentas; resultado ${total.result.toStringAsFixed(2)}; salidas conciliadas.',
      );
    },
  );
  test(
    'closing a loss after allocation can worsen the whole operation; all retained costs remain',
    () {
      final all = decisionFixture();
      final impact = all.simulate('A', ProfitDecisionPlan());
      expect(all.result, 300);
      expect(all.companies.first.account!.afterOverhead, -300);
      expect(impact.costSaving, 700);
      expect(impact.retainedCost, 800);
      expect(impact.change, -500);
      expect(impact.after, -200);
      expect(
        impact.after,
        all.companies.last.account!.afterOverhead - impact.retainedCost,
      );
      expect(impact.releasedTrips, 5);
      expect(impact.releasedKm, 100);
      expect(impact.lostKg, 1000);
      expect(impact.replacementToKeepResult, 500);
      expect(all.priorities.first.action, 'Revisar reparto y condiciones');
    },
  );
  test(
    'an account below assumed variable cost is a candidate to compare exit',
    () {
      final all = ProfitConsolidated([
        decisionCompany('loss', {
          'value': 200,
          'purchase': 600,
          'fuel': 100,
          'administration': 400,
        }),
      ]);
      final impact = all.simulate('loss', ProfitDecisionPlan());
      expect(impact.before, -900);
      expect(impact.change, 500);
      expect(
        impact.after,
        -400,
      ); // Full remaining support, even with no customers.
      expect(all.priorities.single.action, 'Renegociar; comparar salida');
    },
  );
  test('custom avoidability, transition and net replacement enter once', () {
    final all = decisionFixture();
    final impact = all.simulate(
      'A',
      ProfitDecisionPlan(
        exitShares: {
          ...profitExitDefaultShares,
          'payroll': 1,
          'administration': .5,
        },
        transitionCost: 50,
        replacementContribution: 80,
      ),
    );
    expect(impact.costSaving, 1200);
    expect(impact.retainedCost, 300);
    expect(impact.change, 30);
    expect(impact.after, 330);
    expect(impact.replacementToKeepResult, 50);
  });
  test(
    'prices and fewer routes keep material and wages, and reduce per-trip service income',
    () {
      final all = decisionFixture();
      final original = jsonEncode(all.companies.first.account!.toJson());
      final impact = all.simulate(
        'A',
        ProfitDecisionPlan(
          mode: ProfitPlanMode.adjust,
          purchaseChange: -.1,
          valueChange: .2,
          serviceChange: .1,
          fewerTrips: .5,
        ),
      );
      expect(impact.generationChange, closeTo(110, 1e-9));
      expect(impact.costSaving, 110);
      expect(impact.change, closeTo(220, 1e-9));
      expect(impact.releasedTrips, 2.5);
      expect(impact.lostKg, 0);
      expect(impact.savings['payroll'], 0);
      expect(impact.savings['administration'], 0);
      expect(jsonEncode(all.companies.first.account!.toJson()), original);
      final fixedIncome = all.simulate(
        'A',
        ProfitDecisionPlan(
          mode: ProfitPlanMode.adjust,
          purchaseChange: -.1,
          valueChange: .2,
          serviceChange: .1,
          fewerTrips: .5,
          preserveServiceIncome: true,
        ),
      );
      expect(fixedIncome.change, closeTo(330, 1e-9));
    },
  );
  test(
    'no-op and absence of trips never create logistics savings or service losses',
    () {
      final all = ProfitConsolidated([
        decisionCompany('direct', {
          'value': 100,
          'income': 100,
          'purchase': 100,
          'administration': 100,
        }, trips: 0),
      ]);
      final noOp = all.simulate(
        'direct',
        ProfitDecisionPlan(mode: ProfitPlanMode.adjust),
      );
      final fewer = all.simulate(
        'direct',
        ProfitDecisionPlan(mode: ProfitPlanMode.adjust, fewerTrips: 1),
      );
      expect(noOp.change, 0);
      expect(fewer.change, 0);
      expect(fewer.releasedTrips, 0);
      expect(fewer.retainedCost, 200);
    },
  );
  test(
    'missing income is flagged before an exit suggestion and empty cuts are valid',
    () {
      final all = ProfitConsolidated([
        decisionCompany('no-income', {'purchase': 100}),
      ]);
      expect(all.priorities.single.priority, 0);
      expect(all.priorities.single.action, 'Verificar ingreso y actividad');
      expect(ProfitConsolidated([]).result, 0);
      expect(ProfitConsolidated([]).priorities, isEmpty);
    },
  );
  test(
    'invalid rates, unknown cost blocks and non-finite values are rejected',
    () {
      for (final build in <Function()>[
        () => ProfitDecisionPlan(purchaseChange: -1.1),
        () => ProfitDecisionPlan(valueChange: double.nan),
        () => ProfitDecisionPlan(fewerTrips: 1.1),
        () => ProfitDecisionPlan(transitionCost: -1),
        () => ProfitDecisionPlan(replacementContribution: double.infinity),
        () => ProfitDecisionPlan(exitShares: {'administration': 1.1}),
        () => ProfitDecisionPlan(exitShares: {'value': 1}),
        () => ProfitDecisionPlan(exitShares: {'unknown': 1}),
      ]) {
        expect(build, throwsArgumentError);
      }
    },
  );
}
