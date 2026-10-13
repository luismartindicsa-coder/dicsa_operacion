import 'dart:math' as math;
import 'profitability_models.dart';
import 'profitability_parameters.dart';

const profitAccountBlocks = <String, String>{
  'value': 'Valor del material',
  'income': 'Servicios cobrados',
  'purchase': 'Compra de materiales',
  'containers': 'Contenedores y equipo',
  'disposal': 'Relleno sanitario',
  'fuel': 'Combustible',
  'transport': 'Recolección y transporte',
  'payroll': 'Personal operativo',
  'administration': 'Personal compartido y administración',
  'process': 'Proceso y maniobras',
  'maintenance': 'Mantenimiento',
  'scale': 'Báscula externa',
  'training': 'Capacitaciones',
  'other': 'Otros servicios y gastos',
  'overhead': 'Estructura adicional',
};

const profitCostBasisLabels = {
  'documents': 'Documentos y nómina publicada, directos o repartidos',
  'inferred_purchase': 'Compra estimada o pendiente de conciliar',
  'salary_reference': 'Nómina estimada para días sin cierre',
  'historical_average': 'Complementos históricos',
  'other_estimates': 'Otras estimaciones y tarifas',
};

class ProfitAccountLine {
  final String key, label;
  double kg = 0, pieces = 0, services = 0;
  final List<ProfitComponent> components = [];
  ProfitAccountLine(this.key, this.label);
  double block(String name) =>
      components.where((c) => c.block == name).fold(0, (s, c) => s + c.amount!);
  double get materialValue => block('value');
  double get income => block('income');
  double get generated => materialValue + income;
  double get costs => components
      .where((c) => !['value', 'income', 'overhead'].contains(c.block))
      .fold(0, (s, c) => s + c.amount!);
  double get contribution => generated - costs;
  double get additionalPerKg => kg > 0 ? math.max(0, -contribution) / kg : 0;
  double get additionalPerService =>
      services > 0 ? math.max(0, -contribution) / services : 0;
  double get minimumServiceRate =>
      services > 0 ? math.max(0, costs - materialValue) / services : 0;
  ProfitRow toJson() => {
    'key': key,
    'label': label,
    'kg': kg,
    'pieces': pieces,
    'services': services,
    'value': materialValue,
    'income': income,
    'costs': costs,
    'contribution': contribution,
    'additional_per_kg': additionalPerKg,
    'additional_per_service': additionalPerService,
    'minimum_service_rate': minimumServiceRate,
    'components': components.map((c) => c.toJson()).toList(),
  };
}

class ProfitAccountResult {
  final List<ProfitAccountLine> lines;
  final List<String> assumptions;
  final double kilometers, serviceCount, containers;
  ProfitAccountResult({
    required this.lines,
    required this.assumptions,
    required this.kilometers,
    required this.serviceCount,
    required this.containers,
  });
  Iterable<ProfitComponent> get components => lines.expand((l) => l.components);
  double block(String name) =>
      components.where((c) => c.block == name).fold(0, (s, c) => s + c.amount!);
  double get generated => block('value') + block('income');
  double get costs => lines.fold(0, (s, l) => s + l.costs);

  /// An exhaustive partition of the existing cost, never an additional charge.
  Map<String, double> get costBasis {
    final result = {for (final key in profitCostBasisLabels.keys) key: 0.0};
    for (final c in components) {
      if (['value', 'income', 'overhead'].contains(c.block)) continue;
      final key = c.basisLevel == 'salary_reference'
          ? 'salary_reference'
          : c.basisLevel == 'historical_average'
          ? 'historical_average'
          : c.block == 'purchase' && c.sourceType == ProfitSourceType.estimated
          ? 'inferred_purchase'
          : c.basisLevel == 'payroll_period' ||
                c.sourceType != ProfitSourceType.estimated
          ? 'documents'
          : 'other_estimates';
      result[key] = result[key]! + (c.amount ?? 0);
    }
    return result;
  }

  double get contribution => generated - costs;
  double get afterOverhead => contribution - block('overhead');
  double get historicalCostEstimate => components
      .where(
        (c) =>
            c.basisLevel == 'historical_average' &&
            !['value', 'income', 'overhead'].contains(c.block),
      )
      .fold(0, (s, c) => s + c.amount!);
  double get sharedSupport => components
      .where(
        (c) =>
            c.sharedSupport &&
            !['value', 'income', 'overhead'].contains(c.block),
      )
      .fold(0, (s, c) => s + c.amount!);
  double get beforeSharedSupport => contribution + sharedSupport;
  double get kg => lines.fold(0, (s, l) => s + l.kg);
  double get pieces => lines.fold(0, (s, l) => s + l.pieces);
  double get margin => generated > 0 ? contribution / generated : 0;
  double get perKg => kg > 0 ? contribution / kg : 0;
  double get costPerService => serviceCount > 0 ? costs / serviceCount : 0;
  double get inferredAmount => components
      .where((c) => c.sourceType == ProfitSourceType.estimated)
      .fold(0, (s, c) => s + c.amount!.abs());
  double get totalAmount => components.fold(0, (s, c) => s + c.amount!.abs());
  double get inferredShare =>
      totalAmount > 0 ? inferredAmount / totalAmount : 0;
  String get decision => generated <= 0
      ? 'Revisar ingreso atribuido'
      : contribution < 0
      ? beforeSharedSupport > 0
            ? 'Cubre atención; revisar soporte'
            : 'Revisar condiciones y bases'
      : contribution == 0
      ? 'Revisar actividad'
      : 'Aporta a DICSA';
  ProfitRow toJson() => {
    'generated': generated,
    'costs': costs,
    'cost_basis': costBasis,
    'contribution': contribution,
    'after_overhead': afterOverhead,
    'shared_support': sharedSupport,
    'historical_cost_estimate': historicalCostEstimate,
    'before_shared_support': beforeSharedSupport,
    'kg': kg,
    'pieces': pieces,
    'services': serviceCount,
    'kilometers': kilometers,
    'containers': containers,
    'margin': margin,
    'per_kg': perKg,
    'cost_per_service': costPerService,
    'inferred_share': inferredShare,
    'assumptions': assumptions,
    'lines': lines.map((l) => l.toJson()).toList(),
  };
}

/// Calendar-month accrual: Feb, 30 and 31-day months each sum to one month.
double profitMonthFraction(ProfitPeriod period) {
  var result = 0.0;
  for (
    var d = period.start;
    !d.isAfter(period.end);
    d = d.add(const Duration(days: 1))
  ) {
    result += 1 / DateTime(d.year, d.month + 1, 0).day;
  }
  return result;
}
