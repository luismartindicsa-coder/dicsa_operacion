import 'dart:math' as math;

import 'operating_program_models.dart';

class ProgramShortfall {
  final ProgramDemand shipment;
  final int quantity;
  final List<String> causes;
  const ProgramShortfall(this.shipment, this.quantity, this.causes);
}

class ProgramEvaluation {
  final List<ProgramShortfall> shortfalls;
  final List<String> violations;
  final List<Map<String, int>> yardApplied, closingBalances;
  final Map<String, int> requiredByMaterial;
  final List<String> historicalWarnings;
  const ProgramEvaluation({
    required this.shortfalls,
    required this.violations,
    required this.yardApplied,
    required this.closingBalances,
    required this.requiredByMaterial,
    this.historicalWarnings = const [],
  });
  bool get valid => shortfalls.isEmpty && violations.isEmpty;
  int get requiredTotal => requiredByMaterial.values.fold(0, (a, b) => a + b);
  int get missingTotal => shortfalls.fold(0, (a, b) => a + b.quantity);
}

List<ProgramDemand> orderedProgramDemands(List<ProgramDemand> demands) {
  int priority(String p) => switch (p) {
    'alta' => 0,
    'normal' => 1,
    _ => 2,
  };
  return [...demands]..sort((a, b) {
    final date = a.date.compareTo(b.date);
    if (date != 0) return date;
    final rank = priority(a.priority).compareTo(priority(b.priority));
    return rank != 0 ? rank : a.id.compareTo(b.id);
  });
}

int programQuantity(
  List<ProgramLine> lines, {
  int? day,
  int? shift,
  String? material,
}) => lines
    .where(
      (l) =>
          (day == null || l.day == day) &&
          (shift == null || l.shift == shift) &&
          (material == null || l.material == material),
    )
    .fold(0, (a, b) => a + b.quantity);

List<ProgramLine> emptyProgramLines() => [
  for (var d = 0; d < 5; d++)
    for (var s = 0; s < 2; s++)
      for (final m in programMaterials) ProgramLine(d, s, m, 0),
];

/// Nested shipment deadlines make cumulative capacity sufficient for
/// feasibility. Minimize peak daily utilization relative to actual historical
/// output, then favor each material's observed shifts within those ceilings.
List<ProgramLine> generateOperatingProgram(
  DateTime week,
  ProgramConditions conditions,
  List<ProgramDemand> demands,
) {
  conditions.validate();
  final history = conditions.history;
  if (history != null && !history.end.isBefore(week)) {
    throw ArgumentError('La referencia debe contener solo semanas anteriores.');
  }
  final yard = Map<String, int>.from(conditions.yard);
  final jobs = <({int day, String material, int quantity})>[];
  var assigned = 0;
  int capacityThrough(int day, int ceiling) =>
      List.generate(
        day,
        (d) => math.min(ceiling, conditions.available(d)),
      ).fold(0, (a, b) => a + b) +
      math.min(ceiling, conditions.slotCapacity(day, 0));
  for (final shipment in orderedProgramDemands(demands)) {
    final d = shipment.date.difference(week).inDays;
    if (d < 0 ||
        d > 4 ||
        !programMaterials.contains(shipment.material) ||
        shipment.quantity <= 0) {
      throw ArgumentError(
        'Embarque fuera de la semana o del catálogo del programa.',
      );
    }
    final used = math.min(yard[shipment.material] ?? 0, shipment.quantity);
    yard[shipment.material] = (yard[shipment.material] ?? 0) - used;
    final needed = shipment.quantity - used;
    final covered = math.min(
      needed,
      math.max(0, capacityThrough(d, conditions.dailyCapacity) - assigned),
    );
    if (covered > 0) {
      jobs.add((day: d, material: shipment.material, quantity: covered));
    }
    assigned += covered;
  }
  final lastDeadline = jobs.isEmpty ? -1 : jobs.last.day;
  final weights = List<double>.generate(5, (d) {
    if (history == null || !history.hasData) return 1;
    var reference = 0.0;
    for (var s = 0; s < 2; s++) {
      if (conditions.slotCapacity(d, s) > 0 &&
          (d < lastDeadline || (d == lastDeadline && s == 0))) {
        reference += history.average(day: d, shift: s);
      }
    }
    // No weekday observations: use the overall daily mean, visibly identified
    // as a fallback by evaluation, rather than assuming zero physical capacity.
    if (reference == 0) reference = history.average() / 5;
    return math.max(
      1,
      reference * (100 - conditions.days[d].lossPercent) / 100,
    );
  });
  int dailyLimit(int d, int level) =>
      math.min(conditions.available(d), (weights[d] * level / 1000).floor());
  int capacityAtLevel(int day, int level) =>
      List.generate(day, (d) => dailyLimit(d, level)).fold(0, (a, b) => a + b) +
      math.min(dailyLimit(day, level), conditions.slotCapacity(day, 0));
  bool fits(int level) {
    var total = 0;
    for (final job in jobs) {
      total += job.quantity;
      if (total > capacityAtLevel(job.day, level)) return false;
    }
    return true;
  }

  var low = 0;
  var high = List.generate(
    5,
    (d) => (conditions.available(d) * 1000 / weights[d]).ceil() + 1,
  ).reduce(math.max);
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (fits(mid)) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }
  final quantities = <String, int>{};
  final dailyLoads = List.filled(5, 0);
  final shiftLoads = List.generate(5, (_) => [0, 0]);
  for (final job in jobs) {
    for (var unit = 0; unit < job.quantity; unit++) {
      int? bestDay, bestShift;
      var bestDaily = double.infinity;
      var bestMaterialRatio = double.infinity;
      var bestShiftRatio = double.infinity;
      for (var d = 0; d <= job.day; d++) {
        if (dailyLoads[d] >= dailyLimit(d, low)) continue;
        for (var s = 0; s < 2; s++) {
          if (d == job.day && s == 1) continue;
          final cap = conditions.slotCapacity(d, s);
          if (shiftLoads[d][s] >= cap) continue;
          final ratio = (shiftLoads[d][s] + 1) / cap;
          final dailyRatio = (dailyLoads[d] + 1) / weights[d];
          final materialRatio = history?.hasData == true
              ? ((quantities['$d:$s:${job.material}'] ?? 0) + 1) /
                    history!.preference(d, s, job.material)
              : 0.0;
          if (dailyRatio < bestDaily ||
              (dailyRatio == bestDaily && materialRatio < bestMaterialRatio) ||
              (dailyRatio == bestDaily &&
                  materialRatio == bestMaterialRatio &&
                  ratio < bestShiftRatio)) {
            bestDay = d;
            bestShift = s;
            bestDaily = dailyRatio;
            bestMaterialRatio = materialRatio;
            bestShiftRatio = ratio;
          }
        }
      }
      if (bestDay == null || bestShift == null) {
        throw StateError('No se pudo asignar capacidad factible.');
      }
      dailyLoads[bestDay]++;
      shiftLoads[bestDay][bestShift]++;
      final key = '$bestDay:$bestShift:${job.material}';
      quantities[key] = (quantities[key] ?? 0) + 1;
    }
  }
  if (history?.hasData == true) {
    _alignHistoricalMaterials(
      history!,
      conditions,
      jobs,
      dailyLoads,
      quantities,
    );
  }
  return [
    for (final line in emptyProgramLines())
      ProgramLine(
        line.day,
        line.shift,
        line.material,
        quantities[line.key] ?? 0,
      ),
  ];
}

/// Assign materials jointly after fixing the balanced daily totals. A minimum
/// cost flow can reassign an earlier allocation so shipment order cannot take
/// another material's habitual shift. Edges enforce deadlines and shared caps.
void _alignHistoricalMaterials(
  ProgramProductionHistory history,
  ProgramConditions conditions,
  List<({int day, String material, int quantity})> jobs,
  List<int> dailyLoads,
  Map<String, int> quantities,
) {
  if (jobs.isEmpty) return;
  final cells = emptyProgramLines();
  final firstJob = 1;
  final firstCell = firstJob + jobs.length;
  final firstSlot = firstCell + cells.length;
  final firstDay = firstSlot + 10;
  final sink = firstDay + 5;
  final graph = List.generate(sink + 1, (_) => <_HistoryFlowEdge>[]);
  _HistoryFlowEdge edge(
    int from,
    int to,
    int capacity,
    double cost, {
    double slope = 0,
  }) {
    final forward = _HistoryFlowEdge(
      to,
      graph[to].length,
      capacity,
      cost,
      slope: slope,
    );
    final reverse = _HistoryFlowEdge(
      from,
      graph[from].length,
      0,
      -cost,
      forward: forward,
    );
    graph[from].add(forward);
    graph[to].add(reverse);
    return forward;
  }

  final required = jobs.fold<int>(0, (sum, j) => sum + j.quantity);
  for (var j = 0; j < jobs.length; j++) {
    final job = jobs[j];
    edge(0, firstJob + j, job.quantity, 0);
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      if (cell.material == job.material && cell.day + cell.shift <= job.day) {
        edge(firstJob + j, firstCell + i, job.quantity, 0);
      }
    }
  }
  final outputs = <_HistoryFlowEdge>[];
  for (var i = 0; i < cells.length; i++) {
    final cell = cells[i];
    final preference = history.preference(cell.day, cell.shift, cell.material);
    // Increasing marginal cost balances equally observed slots instead of
    // filling the first slot on every tie. Reverse costs track the same curve
    // so a later material can still reclaim its habitual production window.
    final cost = 1 / preference;
    outputs.add(
      edge(
        firstCell + i,
        firstSlot + cell.day * 2 + cell.shift,
        required,
        cost,
        slope: cost,
      ),
    );
  }
  for (var d = 0; d < 5; d++) {
    for (var s = 0; s < 2; s++) {
      final reference = math.max(
        0.001,
        history.average(day: d, shift: s) * 0.8 +
            history.average(shift: s) / 5 * 0.2,
      );
      final cost = 1 / reference;
      edge(
        firstSlot + d * 2 + s,
        firstDay + d,
        conditions.slotCapacity(d, s),
        cost,
        slope: cost,
      );
    }
    edge(firstDay + d, sink, dailyLoads[d], 0);
  }
  var remaining = required;
  while (remaining > 0) {
    final distance = List.filled(graph.length, double.infinity);
    final previousNode = List.filled(graph.length, -1);
    final previousEdge = List.filled(graph.length, -1);
    final queued = List.filled(graph.length, false);
    final queue = <int>[0];
    distance[0] = 0;
    queued[0] = true;
    for (var head = 0; head < queue.length; head++) {
      final node = queue[head];
      queued[node] = false;
      for (var i = 0; i < graph[node].length; i++) {
        final e = graph[node][i];
        final next = distance[node] + e.cost;
        if (e.capacity <= 0 || next >= distance[e.to] - 1e-9) continue;
        distance[e.to] = next;
        previousNode[e.to] = node;
        previousEdge[e.to] = i;
        if (!queued[e.to]) {
          queued[e.to] = true;
          queue.add(e.to);
        }
      }
    }
    if (previousNode[sink] < 0) {
      throw StateError('No se pudo distribuir el programa según sus plazos.');
    }
    // Marginal costs change after each unit on a material/slot edge.
    var amount = 1;
    for (var node = sink; node != 0; node = previousNode[node]) {
      amount = math.min(
        amount,
        graph[previousNode[node]][previousEdge[node]].capacity,
      );
    }
    for (var node = sink; node != 0; node = previousNode[node]) {
      final e = graph[previousNode[node]][previousEdge[node]];
      e.capacity -= amount;
      graph[e.to][e.reverse].capacity += amount;
    }
    remaining -= amount;
  }
  for (var i = 0; i < cells.length; i++) {
    quantities[cells[i].key] = required - outputs[i].capacity;
  }
}

class _HistoryFlowEdge {
  final int to, reverse;
  final double baseCost, slope;
  final int initialCapacity;
  final _HistoryFlowEdge? forward;
  int capacity;
  _HistoryFlowEdge(
    this.to,
    this.reverse,
    this.capacity,
    this.baseCost, {
    this.slope = 0,
    this.forward,
  }) : initialCapacity = capacity;

  double get cost => forward == null
      ? baseCost + (initialCapacity - capacity) * slope
      : -(forward!.baseCost + (capacity - 1) * forward!.slope);
}

ProgramEvaluation evaluateOperatingProgram(
  DateTime week,
  ProgramConditions conditions,
  List<ProgramDemand> demands,
  List<ProgramLine> lines,
) {
  conditions.validate();
  final violations = <String>[];
  final seen = <String>{};
  for (final line in lines) {
    if (!seen.add(line.key) ||
        line.day < 0 ||
        line.day > 4 ||
        line.shift < 0 ||
        line.shift > 1 ||
        !programMaterials.contains(line.material) ||
        line.quantity < 0) {
      violations.add('Línea de producción inválida o duplicada.');
    }
  }
  for (var d = 0; d < 5; d++) {
    final quantity = programQuantity(lines, day: d);
    if (quantity > conditions.available(d)) {
      violations.add(
        '${programDayNames[d]}: $quantity pacas exceden ${conditions.available(d)} disponibles.',
      );
    }
    for (var s = 0; s < 2; s++) {
      final amount = programQuantity(lines, day: d, shift: s);
      if (amount > conditions.slotCapacity(d, s)) {
        violations.add(
          '${programDayNames[d]} ${s == 0 ? 'día' : 'noche'}: $amount pacas exceden ${conditions.slotCapacity(d, s)} disponibles.',
        );
      }
    }
  }
  final required = <String, int>{
    for (final m in programMaterials)
      m: math.max(
        0,
        demands
                .where((d) => d.material == m)
                .fold<int>(0, (a, b) => a + b.quantity) -
            (conditions.yard[m] ?? 0),
      ),
  };
  final yard = Map<String, int>.from(conditions.yard);
  final produced = <String, int>{for (final m in programMaterials) m: 0};
  final missing = <String, int>{for (final m in programMaterials) m: 0};
  final applied = List.generate(5, (_) => <String, int>{});
  final balances = List.generate(5, (_) => <String, int>{});
  final shortfalls = <ProgramShortfall>[];
  final ordered = orderedProgramDemands(demands);
  for (var d = 0; d < 5; d++) {
    for (final m in programMaterials) {
      produced[m] =
          produced[m]! + programQuantity(lines, day: d, shift: 0, material: m);
    }
    for (final shipment in ordered.where(
      (s) => s.date.difference(week).inDays == d,
    )) {
      final m = shipment.material;
      if (!programMaterials.contains(m)) continue;
      final yardUsed = math.min(yard[m] ?? 0, shipment.quantity);
      yard[m] = (yard[m] ?? 0) - yardUsed;
      applied[d][m] = (applied[d][m] ?? 0) + yardUsed;
      final need = shipment.quantity - yardUsed;
      final productionUsed = math.min(math.max(0, produced[m]!), need);
      produced[m] = produced[m]! - productionUsed;
      final deficit = need - productionUsed;
      if (deficit > 0) {
        missing[m] = missing[m]! + deficit;
        final causes = <String>[];
        if ((conditions.yard[m] ?? 0) < shipment.quantity) {
          causes.add('Patio inicial insuficiente');
        }
        if (conditions.days.take(d + 1).any((c) => !c.working)) {
          causes.add('Día no laborable');
        }
        if (List.generate(d + 1, (i) => i).any(
          (i) =>
              !conditions.days[i].dayAvailable ||
              (i < d && !conditions.days[i].nightAvailable),
        )) {
          causes.add('Turno no disponible');
        }
        if (conditions.days.take(d + 1).any((c) => c.lossPercent > 0)) {
          causes.add('Afectación de maquinaria');
        }
        final neededByDate = programMaterials.fold<int>(
          0,
          (sum, material) =>
              sum +
              math.max(
                0,
                ordered
                        .where(
                          (s) =>
                              s.material == material &&
                              !s.date.isAfter(shipment.date),
                        )
                        .fold<int>(0, (total, s) => total + s.quantity) -
                    (conditions.yard[material] ?? 0),
              ),
        );
        final availableByDate =
            List.generate(
              d,
              conditions.available,
            ).fold<int>(0, (a, b) => a + b) +
            conditions.slotCapacity(d, 0);
        causes.add(
          neededByDate > availableByDate
              ? 'Falta de capacidad antes de la salida: $neededByDate pacas requeridas / $availableByDate disponibles'
              : 'Producción de este material no asignada a tiempo',
        );
        shortfalls.add(ProgramShortfall(shipment, deficit, causes));
      }
    }
    for (final m in programMaterials) {
      produced[m] =
          produced[m]! + programQuantity(lines, day: d, shift: 1, material: m);
      balances[d][m] = yard[m]! + produced[m]! - missing[m]!;
    }
  }
  return ProgramEvaluation(
    shortfalls: shortfalls,
    violations: violations,
    yardApplied: applied,
    closingBalances: balances,
    requiredByMaterial: required,
    historicalWarnings: _historyWarnings(conditions, lines),
  );
}

List<String> _historyWarnings(
  ProgramConditions conditions,
  List<ProgramLine> lines,
) {
  final history = conditions.history;
  if (history == null || !history.hasData) {
    return [
      'Sin histórico suficiente de Producción: el reparto usa únicamente la capacidad configurada.',
    ];
  }
  final warnings = <String>[];
  if (history.observedWeeks.length < 6) {
    warnings.add(
      'Referencia parcial: ${history.observedWeeks.length} de 6 semanas con registros. Las semanas sin registros no se consideran producción cero.',
    );
  }
  if (history.unknownShiftCount > 0) {
    warnings.add(
      '${history.unknownShiftCount} registros sin turno válido no se usaron en el reparto.',
    );
  }
  for (final m in programMaterials) {
    if (programQuantity(lines, material: m) > 0 &&
        history.total(material: m) == 0) {
      warnings.add(
        '${programMaterialNames[programMaterials.indexOf(m)]}: sin historial propio; se usa el patrón general de Operación.',
      );
    }
  }
  for (var d = 0; d < 5; d++) {
    if (programQuantity(lines, day: d) == 0) continue;
    if (history.total(day: d) == 0) {
      warnings.add(
        '${programDayNames[d]}: sin registros de ese día; se usa la referencia diaria general.',
      );
      continue;
    }
    for (var s = 0; s < 2; s++) {
      final planned = programQuantity(lines, day: d, shift: s);
      final reference =
          history.average(day: d, shift: s) *
          (100 - conditions.days[d].lossPercent) /
          100;
      if (planned > reference.ceil()) {
        warnings.add(
          '${programDayNames[d]} ${s == 0 ? 'día' : 'noche'}: $planned pacas programadas / ${reference.toStringAsFixed(1)} de promedio histórico ajustado. Requiere mayor ritmo que el registrado.',
        );
      }
    }
  }
  return warnings;
}

List<ProgramLine> moveProgramProduction(
  List<ProgramLine> lines, {
  required int fromDay,
  required int fromShift,
  required int toDay,
  required int toShift,
  required String material,
  required int quantity,
}) {
  if (quantity <= 0 ||
      quantity >
          programQuantity(
            lines,
            day: fromDay,
            shift: fromShift,
            material: material,
          ) ||
      toDay < 0 ||
      toDay > 4 ||
      toShift < 0 ||
      toShift > 1 ||
      !programMaterials.contains(material)) {
    throw ArgumentError('Cantidad o destino del movimiento inválido.');
  }
  return [
    for (final line in lines)
      ProgramLine(
        line.day,
        line.shift,
        line.material,
        line.quantity -
            (line.day == fromDay &&
                    line.shift == fromShift &&
                    line.material == material
                ? quantity
                : 0) +
            (line.day == toDay &&
                    line.shift == toShift &&
                    line.material == material
                ? quantity
                : 0),
      ),
  ];
}
