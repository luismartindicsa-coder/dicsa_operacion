import 'dart:math' as math;

import '../direction_shipments_store.dart';
import 'expected_income_models.dart';
import 'palomar_coverage.dart';

/// Commercial grades requested by Dirección. Do not match by family or prefix:
/// carton limpio and the other varieties of mixto/retorno have different prices.
const palomarDispatchGrades = <String, String>{
  'ORDINARIO DE PRIMERA': 'Limpio',
  'REBABA': 'Rebaba',
  'MIXTO': 'Mixto',
  'RETORNO INDUSTRIAL': 'Retorno industrial',
  'PESADO': 'Pesado',
};

class PalomarDispatchMaterial {
  final String catalogName, label;
  final PalomarMaterialQuote? quote;
  final int historicalCents, targetCents;
  final double share;
  const PalomarDispatchMaterial({
    required this.catalogName,
    required this.label,
    required this.quote,
    required this.historicalCents,
    required this.targetCents,
    required this.share,
  });
}

class PalomarDispatchDay {
  final DateTime date;
  final Map<String, PalomarCoverageSend> materials;
  final int? closing;
  const PalomarDispatchDay(this.date, this.materials, this.closing);
  int get total => materials.values.fold(0, (sum, s) => sum + s.amount!);
}

class PalomarWeeklyDispatch {
  final PalomarCoverage coverage;
  final DateTime week, historyFrom, historyUntil;
  final List<PalomarDispatchMaterial> materials;
  final List<PalomarDispatchDay> days;
  final List<String> warnings;
  final int historicalRecords;
  const PalomarWeeklyDispatch({
    required this.coverage,
    required this.week,
    required this.historyFrom,
    required this.historyUntil,
    required this.materials,
    required this.days,
    required this.warnings,
    required this.historicalRecords,
  });
  int get proposedCents => days.fold(0, (sum, day) => sum + day.total);
  int? get closing =>
      coverage.complete ? coverage.projectedBalance - proposedCents : null;
}

/// Largest remainder allocation preserves all cents/units, with earlier items
/// receiving the ties. Empty history uses equal shares, explicitly shown in UI.
List<int> _allocate(int total, List<int> weights) {
  if (weights.isEmpty) return [];
  if (weights.every((w) => w == 0)) weights = List.filled(weights.length, 1);
  final sum = weights.reduce((a, b) => a + b);
  final divisor = BigInt.from(sum);
  final products = [
    for (final w in weights) BigInt.from(total) * BigInt.from(w),
  ];
  final result = [for (final product in products) (product ~/ divisor).toInt()];
  final order = List.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final remainder = (products[b] % divisor).compareTo(
        products[a] % divisor,
      );
      return remainder == 0 ? a.compareTo(b) : remainder;
    });
  final extra = total - result.reduce((a, b) => a + b);
  for (var i = 0; i < extra; i++) {
    result[order[i]]++;
  }
  return result;
}

PalomarWeeklyDispatch projectPalomarWeeklyDispatch({
  required ExpectedIncomeData data,
  required DirectionShipmentPlanningBundle bundle,
  required DateTime now,
}) {
  // This read-only reference answers how much material covers the real debt.
  // Unsent plans and expected credits are not posted remittances and must not
  // suppress the quantities, or block them because of an unrelated plan price.
  final coverage = projectPalomarCoverage(
    data: data,
    bundle: bundle,
    now: now,
    includeForecast: false,
  );
  final today = incomeDay(now);
  final week = incomeDay(bundle.weekStartDate);
  final currentWeek = today.subtract(Duration(days: today.weekday - 1));
  final historyUntil = week.isBefore(currentWeek) ? week : currentWeek;
  final historyFrom = historyUntil.subtract(const Duration(days: 42));
  final rule = data.ruleFor('EL PALOMAR');
  final warnings = [...coverage.warnings];
  final quotes = <String, PalomarMaterialQuote?>{};
  for (final name in palomarDispatchGrades.keys) {
    final matches = data.palomarCoverageMaterials
        .where((q) => incomeKey(q.label).replaceAll('_', ' ') == name)
        .toList();
    final usable = matches.where((q) => q.usable).toList();
    quotes[name] = usable.length == 1 ? usable.single : null;
    if (quotes[name] == null && coverage.remaining > 0) {
      warnings.add(
        '${palomarDispatchGrades[name]} ($name): falta un precio vigente y una unidad únicos para El Palomar en Mayoreo.',
      );
    }
  }
  final namesByCode = {
    for (final q in data.palomarCoverageMaterials)
      if (palomarDispatchGrades.containsKey(
        incomeKey(q.label).replaceAll('_', ' '),
      ))
        q.code: incomeKey(q.label).replaceAll('_', ' '),
  };
  final history = <String, int>{};
  final weekdays = <String, Map<int, int>>{};
  var records = 0;
  void addHistory(String? name, DateTime date, int? value) {
    if (name == null ||
        !palomarDispatchGrades.containsKey(name) ||
        date.isBefore(historyFrom) ||
        !date.isBefore(historyUntil) ||
        value == null ||
        value <= 0) {
      return;
    }
    history.update(name, (v) => v + value, ifAbsent: () => value);
    weekdays
        .putIfAbsent(name, () => {})
        .update(date.weekday, (v) => v + value, ifAbsent: () => value);
    records++;
  }

  final sales = {for (final sale in data.sales) sale.id: sale};
  final sampled = <String>{};
  for (final sale in sales.values) {
    if (rule == null ||
        data.ruleFor(sale.client)?.key != rule.key ||
        sale.cancelled) {
      continue;
    }
    final value =
        sale.approvedCents ??
        (sale.weight != null &&
                sale.price != null &&
                sale.weight!.isFinite &&
                sale.price!.isFinite
            ? incomeCents(sale.weight! * sale.price!)
            : null);
    final before = records;
    addHistory(namesByCode[sale.material], sale.date, value);
    if (records > before) sampled.add(sale.id);
  }
  // Manual remittances also inform the mix. Linked sales/remittances count once;
  // adjustments and projected movements never train the shipping pattern.
  final seenMovements = <String>{};
  for (final m in data.palomarMovements) {
    if (!seenMovements.add(m.id) ||
        m.projected ||
        m.signedCents >= 0 ||
        !m.concept.startsWith('remisionAplicada') ||
        (m.reportId != null &&
            (sampled.contains(m.reportId) ||
                sales[m.reportId]?.cancelled == true))) {
      continue;
    }
    final label = m.concept.split('·').skip(1).join('·').trim();
    addHistory(incomeKey(label), m.date, -m.signedCents);
  }
  final weights = [
    for (final name in palomarDispatchGrades.keys) history[name] ?? 0,
  ];
  final historicalTotal = weights.fold<int>(0, (sum, v) => sum + v);
  final targets = _allocate(coverage.remaining, weights);
  final materials = <PalomarDispatchMaterial>[
    for (var i = 0; i < palomarDispatchGrades.length; i++)
      PalomarDispatchMaterial(
        catalogName: palomarDispatchGrades.keys.elementAt(i),
        label: palomarDispatchGrades.values.elementAt(i),
        quote: quotes[palomarDispatchGrades.keys.elementAt(i)],
        historicalCents: weights[i],
        targetCents: targets[i],
        share: historicalTotal == 0
            ? 1 / weights.length
            : weights[i] / historicalTotal,
      ),
  ];
  final dates = <DateTime>[];
  final deadline = coverage.deadline;
  if (deadline != null && !deadline.isBefore(today)) {
    for (
      var date = today.isAfter(week) ? today : week;
      !date.isAfter(deadline);
      date = date.add(const Duration(days: 1))
    ) {
      if (date.weekday != DateTime.sunday) dates.add(date);
    }
  }
  final cells = {
    for (final date in dates) date: <String, PalomarCoverageSend>{},
  };
  if (coverage.complete && dates.isNotEmpty) {
    for (final material in materials) {
      final quote = material.quote;
      if (quote == null || material.targetCents <= 0) continue;
      final dayWeights = [
        for (final date in dates)
          weekdays[material.catalogName]?[date.weekday] ?? 0,
      ];
      final quantity = quote.quantityFor(material.targetCents)!;
      final quantities = _allocate(quantity, dayWeights);
      // Per-day monetary rounding must still cover this material's full target.
      final last = quantities.lastIndexWhere((q) => q > 0);
      if (last >= 0) {
        final other = [
          for (var i = 0; i < quantities.length; i++)
            if (i != last) quote.amount(quantities[i])!,
        ].fold<int>(0, (sum, v) => sum + v);
        quantities[last] = math.max(
          quantities[last],
          quote.quantityFor(math.max(0, material.targetCents - other))!,
        );
      }
      for (var i = 0; i < dates.length; i++) {
        if (quantities[i] == 0) continue;
        cells[dates[i]]![material.catalogName] = PalomarCoverageSend(
          date: dates[i],
          material: quote.code,
          quantity: quantities[i],
          unit: quote.unit,
          amount: quote.amount(quantities[i]),
          status: 'Propuesto',
          additional: true,
        );
      }
    }
  }
  if (historicalTotal == 0 && coverage.remaining > 0) {
    warnings.add(
      'Sin envíos históricos de estos materiales en las últimas 6 semanas completas: reparto inicial de 20% del importe por material y uniforme entre días disponibles.',
    );
  } else if (weights.any((w) => w == 0) && coverage.remaining > 0) {
    warnings.add(
      'Los materiales sin envíos en las últimas 6 semanas completas quedan en cero; la mezcla sigue los materiales registrados.',
    );
  }
  final days = <PalomarDispatchDay>[];
  var proposed = 0;
  for (final date in dates) {
    proposed += cells[date]!.values.fold<int>(0, (sum, s) => sum + s.amount!);
    final events = coverage.events.where((e) => !e.date.isAfter(date));
    final closing = coverage.complete
        ? coverage.balance +
              events.fold<int>(0, (sum, e) => sum + e.signedCents!) -
              proposed
        : null;
    days.add(PalomarDispatchDay(date, cells[date]!, closing));
  }
  return PalomarWeeklyDispatch(
    coverage: coverage,
    week: week,
    historyFrom: historyFrom,
    historyUntil: historyUntil,
    materials: materials,
    days: days,
    warnings: warnings,
    historicalRecords: records,
  );
}
