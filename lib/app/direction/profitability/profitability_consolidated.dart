import 'dart:math' as math;
import 'profitability_account_models.dart';
import 'profitability_models.dart';

/// Planning assumptions, not evidence that a payment or contract disappears.
/// Payroll, equipment, maintenance, process and support remain by default.
const profitExitDefaultShares = <String, double>{
  'purchase': 1,
  'fuel': 1,
  'transport': 1,
  'disposal': 1,
  'scale': 1,
};

enum ProfitPlanMode { adjust, exit }

class ProfitDecisionPlan {
  final ProfitPlanMode mode;
  final double purchaseChange, valueChange, serviceChange, fewerTrips;
  final bool preserveServiceIncome;
  final double transitionCost, replacementContribution;
  final Map<String, double> exitShares;
  ProfitDecisionPlan({
    this.mode = ProfitPlanMode.exit,
    this.purchaseChange = 0,
    this.valueChange = 0,
    this.serviceChange = 0,
    this.fewerTrips = 0,
    this.preserveServiceIncome = false,
    this.transitionCost = 0,
    this.replacementContribution = 0,
    Map<String, double> exitShares = profitExitDefaultShares,
  }) : exitShares = Map.unmodifiable(exitShares) {
    for (final change in [purchaseChange, valueChange, serviceChange]) {
      if (!change.isFinite || change < -1 || change > 1) {
        throw ArgumentError(
          'Los cambios de precio deben estar entre -100% y 100%.',
        );
      }
    }
    if (!fewerTrips.isFinite ||
        fewerTrips < 0 ||
        fewerTrips > 1 ||
        !transitionCost.isFinite ||
        transitionCost < 0 ||
        !replacementContribution.isFinite ||
        replacementContribution < 0 ||
        exitShares.entries.any(
          (e) =>
              !profitAccountBlocks.containsKey(e.key) ||
              ['value', 'income'].contains(e.key) ||
              !e.value.isFinite ||
              e.value < 0 ||
              e.value > 1,
        )) {
      throw ArgumentError(
        'Los ahorros deben ser de 0% a 100% y los importes no negativos.',
      );
    }
  }
}

class ProfitDecisionImpact {
  final ProfitCompanyResult company;
  final ProfitDecisionPlan plan;
  final double before, after, baselineGenerated, baselineCosts;
  final double generationChange, costSaving, retainedCost;
  final double releasedTrips, releasedKm, lostKg;
  final Map<String, double> savings;
  const ProfitDecisionImpact({
    required this.company,
    required this.plan,
    required this.before,
    required this.after,
    required this.baselineGenerated,
    required this.baselineCosts,
    required this.generationChange,
    required this.costSaving,
    required this.retainedCost,
    required this.savings,
    required this.releasedTrips,
    required this.releasedKm,
    required this.lostKg,
  });
  double get change => after - before;
  double get resultWithoutReplacement => after - plan.replacementContribution;
  double get replacementToKeepResult =>
      math.max(0, before - resultWithoutReplacement);
}

class ProfitConsolidated {
  final List<ProfitCompanyResult> companies;
  ProfitConsolidated(Iterable<ProfitCompanyResult> rows)
    : companies = List.unmodifiable(rows.where((c) => c.account != null));
  late final double generated = companies.fold(
    0,
    (s, c) => s + c.account!.generated,
  );
  late final double operatingCosts = companies.fold(
    0,
    (s, c) => s + c.account!.costs,
  );
  late final double overhead = companies.fold(
    0,
    (s, c) => s + c.account!.block('overhead'),
  );
  late final double costs = operatingCosts + overhead;
  late final double result = generated - costs;

  ProfitDecisionImpact simulate(String companyKey, ProfitDecisionPlan plan) {
    final company = companies.singleWhere((c) => c.entity.key == companyKey);
    final a = company.account!;
    final exit = plan.mode == ProfitPlanMode.exit;
    final tripReduction = a.serviceCount > 0 ? plan.fewerTrips : 0.0;
    final savings = <String, double>{};
    for (final block in profitAccountBlocks.keys.where(
      (b) => !['value', 'income'].contains(b),
    )) {
      // Reducing routes at the same volume does not release wages or equipment.
      savings[block] =
          a.block(block) *
          (exit
              ? (plan.exitShares[block] ?? 0)
              : block == 'purchase'
              ? -plan.purchaseChange
              : ['fuel', 'transport', 'scale'].contains(block)
              ? tripReduction
              : 0);
    }
    final serviceFactor = plan.preserveServiceIncome ? 1.0 : 1 - tripReduction;
    final generationChange = exit
        ? -a.generated
        : a.block('value') * plan.valueChange +
              a.block('income') *
                  ((1 + plan.serviceChange) * serviceFactor - 1);
    final saved = savings.values.fold<double>(0, (s, v) => s + v);
    final baseCost = a.costs + a.block('overhead');
    final delta =
        generationChange +
        saved -
        plan.transitionCost +
        plan.replacementContribution;
    return ProfitDecisionImpact(
      company: company,
      plan: plan,
      before: result,
      after: result + delta,
      baselineGenerated: a.generated,
      baselineCosts: baseCost,
      generationChange: generationChange,
      costSaving: saved,
      retainedCost: baseCost - saved,
      savings: Map.unmodifiable(savings),
      releasedTrips: a.serviceCount * (exit ? 1 : tripReduction),
      releasedKm: a.kilometers * (exit ? 1 : tripReduction),
      lostKg: exit ? a.kg : 0,
    );
  }

  List<ProfitCompanyDecision> get priorities {
    final rows = [
      for (final c in companies)
        ProfitCompanyDecision(c, simulate(c.entity.key, ProfitDecisionPlan())),
    ];
    rows.sort((a, b) {
      final risk = a.priority.compareTo(b.priority);
      if (risk != 0) return risk;
      final gap = b.deficit.compareTo(a.deficit);
      if (gap != 0) return gap;
      final contribution = b.company.account!.afterOverhead.compareTo(
        a.company.account!.afterOverhead,
      );
      return contribution != 0
          ? contribution
          : a.company.entity.name.compareTo(b.company.entity.name);
    });
    return rows;
  }
}

class ProfitCompanyDecision {
  final ProfitCompanyResult company;
  final ProfitDecisionImpact exit;
  const ProfitCompanyDecision(this.company, this.exit);
  ProfitAccountResult get account => company.account!;
  double get deficit => math.max(0, -account.afterOverhead);
  double get contributionToRetainedCosts => account.generated - exit.costSaving;
  int get priority => account.generated <= 0
      ? 0
      : exit.change > .005
      ? 1
      : deficit > .005
      ? 2
      : 3;
  String get action => switch (priority) {
    0 => 'Verificar ingreso y actividad',
    1 => 'Renegociar; comparar salida',
    2 => 'Revisar reparto y condiciones',
    _ => 'Conservar aporte; optimizar',
  };
}
