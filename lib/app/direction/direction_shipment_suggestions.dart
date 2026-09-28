part of 'direction_shipments_store.dart';

const _suggestionMaterials = ['PACA_NACIONAL', 'PACA_LIMPIA', 'PACA_AMERICANA'];

/// Operación keeps raw arrivals in kg and finished departures in bales.
/// These units must never be added together or converted without a yield.
class DirectionShipmentMovement {
  final DateTime date;
  final DateTime? recordedAt;
  final String flow, level, material, client, origin;
  final int bales;
  final double kilograms;
  const DirectionShipmentMovement({
    required this.date,
    this.recordedAt,
    required this.flow,
    required this.level,
    required this.material,
    this.client = '',
    this.origin = '',
    this.bales = 0,
    this.kilograms = 0,
  });

  factory DirectionShipmentMovement.fromRow(Map<String, dynamic> row) {
    final level = '${row['inventory_level']}';
    final material =
        row[level == 'COMMERCIAL' ? 'commercial_material' : 'general_material']
            as Map?;
    return DirectionShipmentMovement(
      date: _parseDate(row['op_date']),
      recordedAt: _tryParseDateTime(row['created_at']),
      flow: '${row['flow']}',
      origin: '${row['origin_type'] ?? ''}',
      level: level,
      material:
          _normalizePlanningMaterialCode(material?['code']?.toString()) ??
          _normalizeSearchText(material?['code']?.toString()),
      client: _suggestionClient('${row['counterparty'] ?? ''}'),
      bales: math.max(0, (row['unit_count'] as num?)?.toInt() ?? 0),
      kilograms: math.max(
        0,
        ((row['net_kg'] ?? row['weight_kg']) as num?)?.toDouble() ?? 0,
      ),
    );
  }
}

class DirectionShipmentTargetCoverage {
  final String baleType;
  final int target, actual, committed, suggested;
  final int currentFloor, productionActual;
  const DirectionShipmentTargetCoverage({
    required this.baleType,
    required this.target,
    required this.actual,
    required this.committed,
    required this.suggested,
    this.currentFloor = 0,
    this.productionActual = 0,
  });
  int get shortfall => math.max(0, target - actual - committed - suggested);
  String get label =>
      baleType == 'revuelto' ? 'Nacional' : _gerenciaBaleTypeLabel(baleType);
  int shipmentGoal(int selected) => actual + committed + selected;
  int productionGoal(int selected) =>
      productionActual + math.max(0, committed + selected - currentFloor);
}

class DirectionShipmentSuggestionReport {
  final DateTime weekStart, generatedAt;
  final List<DirectionSuggestedShipmentRecord> suggestions;
  final List<DirectionShipmentTargetCoverage> coverage;
  final List<String> observations;
  final double intakeFactor;
  final int operationHistoryCount, directionHistoryCount, productionRecordCount;
  final String sourceKey;
  final int incomingRecordCount, dailyCapacity;
  final Map<String, int> openingFloorByMaterial, currentFloorByMaterial;
  final Set<String> estimatedFloorMaterials;
  final Set<String> missingFloorMaterials;
  final Map<DateTime, Map<String, int>> productionForecast,
      dayProductionForecast;
  const DirectionShipmentSuggestionReport({
    required this.weekStart,
    required this.generatedAt,
    required this.suggestions,
    required this.coverage,
    required this.observations,
    required this.intakeFactor,
    required this.operationHistoryCount,
    required this.directionHistoryCount,
    required this.productionRecordCount,
    required this.sourceKey,
    this.incomingRecordCount = 0,
    this.dailyCapacity = 0,
    this.openingFloorByMaterial = const {},
    this.currentFloorByMaterial = const {},
    this.estimatedFloorMaterials = const {},
    this.missingFloorMaterials = const {},
    this.productionForecast = const {},
    this.dayProductionForecast = const {},
  });
  int productionThrough(String material, DateTime date) =>
      _suggestionProductionThrough(
        productionForecast,
        dayProductionForecast,
        material,
        date,
      );
}

int _suggestionProductionThrough(
  Map<DateTime, Map<String, int>> total,
  Map<DateTime, Map<String, int>> day,
  String material,
  DateTime date,
) => total.entries
    .where((e) => !e.key.isAfter(date))
    .fold(
      0,
      (n, e) =>
          n +
          (e.key == date
              ? (day[e.key]?[material] ?? 0)
              : (e.value[material] ?? 0)),
    );

String directionSuggestionKey(DirectionSuggestedShipmentRecord row) =>
    jsonEncode([
      _fmtDate(row.suggestedDate),
      row.clientName,
      row.materialCode,
      row.suggestedQuantity,
      row.proposalIndex,
    ]);

String _suggestionClient(String name) =>
    _normalizeSearchText(_canonicalPriorityClientName(name) ?? name);

class _ObservedShipment {
  final DateTime date;
  final String client, material;
  final int quantity;
  final List<int> loads;
  const _ObservedShipment(
    this.date,
    this.client,
    this.material,
    this.quantity, [
    this.loads = const [],
  ]);
  String get key => jsonEncode([_fmtDate(date), client, material]);
}

/// Deterministic, conservative weekly proposal. It does not claim a global
/// optimum or infer orders, freight capacity or a kg-to-bale conversion.
DirectionShipmentSuggestionReport buildDirectionShipmentSuggestions({
  required DateTime weekStart,
  required DateTime asOf,
  required List<DirectionShipmentPlanRecord> shipments,
  required Map<String, int> floorCounts,
  required Map<String, DateTime> floorCountedAt,
  required List<DirectionProductionHistoryRecord> production,
  required List<DirectionProductionCapacityImpactRecord> impacts,
  // Kept as an optional reference for callers; goals never gate the proposal.
  List<DirectionShipmentTarget> targets = const [],
  Map<String, dynamic>? savedProgramConditions,
  required List<DirectionShipmentMovement> movements,
  List<DirectionExecutionActual> executionActuals = const [],
}) {
  final start = _weekStartMonday(weekStart);
  final today = _dateOnly(asOf);
  final friday = start.add(const Duration(days: 4));
  final sunday = start.add(const Duration(days: 6));
  final historyEnd = start.isBefore(_weekStartMonday(today))
      ? start
      : _weekStartMonday(today);
  final historyStart = historyEnd.subtract(const Duration(days: 42));
  final commercialStart = start.subtract(const Duration(days: 112));
  production = directionProductionWithActuals(
    production,
    executionActuals,
    before: today,
  );
  final observations = <String>[
    'Propuesta de cartón de lunes a viernes. Mantiene 5 pacas de reserva por material y protege los embarques ya capturados hasta el sábado.',
    'El historial y el piso determinan la propuesta. Las metas de embarque y producción se calculan como resultado de la selección; no se requieren metas previas.',
    if (executionActuals.any((a) => a.active && a.date.isBefore(historyEnd)))
      'Los resultados confirmados en Real sustituyen los registros equivalentes de Operación en el historial de producción y embarques; no se suman dos veces.',
  ];
  bool inWeek(DateTime date) => !date.isBefore(start) && date.isBefore(sunday);
  final actualOut = <String, _ObservedShipment>{};
  final directionOut = <String, _ObservedShipment>{};
  void add(Map<String, _ObservedShipment> bucket, _ObservedShipment event) {
    if (event.quantity <= 0 ||
        event.date.isAfter(today) ||
        event.date.isBefore(commercialStart) ||
        !_suggestionMaterials.contains(event.material)) {
      return;
    }
    final old = bucket[event.key];
    bucket[event.key] = _ObservedShipment(
      event.date,
      event.client,
      event.material,
      event.quantity + (old?.quantity ?? 0),
      [...?old?.loads, event.quantity],
    );
  }

  for (final row in movements) {
    if (row.flow == 'OUT' &&
        row.level == 'COMMERCIAL' &&
        row.origin != 'TRANSFORMATION') {
      add(
        actualOut,
        _ObservedShipment(
          _dateOnly(row.date),
          _suggestionClient(row.client),
          row.material,
          row.bales,
        ),
      );
    }
  }
  for (final row in directionShipmentSourcePlans(shipments, executionActuals)) {
    if (row.isShipped &&
        row.quantityUnit == DirectionShipmentQuantityUnit.bales) {
      add(
        directionOut,
        _ObservedShipment(
          _dateOnly(row.shipDate),
          _suggestionClient(row.clientName),
          row.materialCode,
          row.plannedQuantity,
        ),
      );
    }
  }
  // Without a cross-system shipment ID, reconcile totals for the exact same
  // operational day, client and material. Never sum two copies of that total.
  final reconciled = <String, _ObservedShipment>{...actualOut};
  for (final entry in directionOut.entries) {
    if (entry.value.quantity > (reconciled[entry.key]?.quantity ?? 0)) {
      reconciled[entry.key] = entry.value;
    }
  }
  for (final a in executionActuals) {
    if (!a.active ||
        a.kind != 'shipment' ||
        !_suggestionMaterials.contains(a.material) ||
        a.date.isAfter(today) ||
        a.date.isBefore(commercialStart))
      continue;
    final event = _ObservedShipment(
      a.date,
      _suggestionClient(a.client),
      a.material,
      a.quantity,
      a.loads,
    );
    // Explicit zero removes an erroneous source shipment from history too.
    if (a.quantity == 0) {
      reconciled.remove(event.key);
    } else {
      reconciled[event.key] = event;
    }
  }
  if (directionOut.keys.any(actualOut.containsKey)) {
    observations.add(
      'Salidas y embarques realizados del mismo día, cliente y material se concilian por el mayor total; revisa diferencias de captura entre áreas.',
    );
  }
  final actualByType = <String, int>{};
  final history = <String, List<_ObservedShipment>>{};
  final clientWeekQuantity = <String, int>{};
  for (final event in reconciled.values) {
    final type = _gerenciaBaleTypeKeyForMaterial(event.material)!;
    final clientKey = '${event.client}|${event.material}';
    if (inWeek(event.date)) {
      actualByType[type] = (actualByType[type] ?? 0) + event.quantity;
      clientWeekQuantity[clientKey] =
          (clientWeekQuantity[clientKey] ?? 0) + event.quantity;
    } else if (event.date.isBefore(start) && event.client.isNotEmpty) {
      history.putIfAbsent(clientKey, () => []).add(event);
    }
  }
  final commitments =
      directionOutstandingShipmentPlans(shipments, executionActuals, today)
          .where(
            (s) =>
                s.isActive &&
                _suggestionMaterials.contains(s.materialCode) &&
                inWeek(s.shipDate) &&
                s.quantityUnit == DirectionShipmentQuantityUnit.bales,
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final committedByType = <String, int>{};
  for (final row in commitments) {
    final type = _gerenciaBaleTypeKeyForMaterial(row.materialCode);
    if (type == null) continue;
    committedByType[type] = (committedByType[type] ?? 0) + row.plannedQuantity;
    final key = '${_suggestionClient(row.clientName)}|${row.materialCode}';
    clientWeekQuantity[key] =
        (clientWeekQuantity[key] ?? 0) + row.plannedQuantity;
  }
  if (commitments.any(
    (s) => actualOut.containsKey(
      _ObservedShipment(
        _dateOnly(s.shipDate),
        _suggestionClient(s.clientName),
        s.materialCode,
        0,
      ).key,
    ),
  )) {
    observations.add(
      'Hay embarques pendientes con una salida coincidente. Se mantiene su reserva hasta actualizar el estado en Dirección.',
    );
  }

  // GENERAL OUT / TRANSFORMATION is material consumed in production, not
  // missing arrivals. Compare actual IN receipts, never IN minus processing.
  final recentStart = today.subtract(const Duration(days: 7));
  final supplyStart = recentStart.subtract(const Duration(days: 42));
  double recentKg = 0, baselineKg = 0;
  var incomingCount = 0;
  for (final row in movements) {
    if (row.level != 'GENERAL' ||
        row.flow != 'IN' ||
        !['CARTON', 'CARDBOARD'].contains(_normalizeSearchText(row.material)) ||
        row.date.isBefore(supplyStart) ||
        !row.date.isBefore(today)) {
      continue;
    }
    incomingCount++;
    if (row.date.isBefore(recentStart)) {
      baselineKg += row.kilograms;
    } else {
      recentKg += row.kilograms;
    }
  }
  final intakeFactor = baselineKg > 0
      ? (math.max(0, recentKg) / (baselineKg / 6)).clamp(0.0, 1.0)
      : 1.0;
  observations.add(
    baselineKg <= 0
        ? 'Entradas: $incomingCount registros en la ventana, ${recentKg.round()} kg recientes. '
              'Sin base comparable se conserva la capacidad observada en Producción, sujeta a abastecimiento.'
        : 'Entradas de cartón: $incomingCount registros; ${recentKg.round()} kg recientes / '
              'referencia semanal ${(baselineKg / 6).round()} kg. Factor de abastecimiento ${(intakeFactor * 100).round()}%.',
  );

  final productionHistory = production
      .where(
        (p) =>
            !p.date.isBefore(historyStart) &&
            p.date.isBefore(historyEnd) &&
            (p.quantity > 0 || p.source == 'direction_execution_actuals') &&
            _suggestionMaterials.contains(p.materialCode),
      )
      .toList();
  final actualProduction = <String, int>{};
  for (final row in production) {
    final type = _gerenciaBaleTypeKeyForMaterial(row.materialCode);
    if (type != null &&
        _suggestionMaterials.contains(row.materialCode) &&
        inWeek(row.date) &&
        !row.date.isAfter(today)) {
      actualProduction[type] =
          (actualProduction[type] ?? 0) + math.max(0, row.quantity);
    }
  }
  final inventory = reconcileDirectionShipmentInventory(
    weekStart: start,
    asOf: asOf,
    counts: floorCounts,
    countedAt: floorCountedAt,
    production: production,
    movements: movements,
    shipments: shipments,
    savedProgramConditions: savedProgramConditions,
    executionActuals: executionActuals,
  );
  observations.addAll(inventory.observations);
  final validFloor = inventory.current;
  final historyCapacity = directionHistoricalDailyCapacity(
    historyEnd,
    productionHistory,
  );
  final dailyCapacity =
      (savedProgramConditions?['daily_capacity'] as num?)?.toInt() ??
      historyCapacity;
  final totalHistorical = productionHistory
      .where((p) => ['DAY', 'NIGHT'].contains(p.shiftKey))
      .fold(0, (n, p) => n + p.quantity);
  final dayHistorical = productionHistory
      .where((p) => p.shiftKey == 'DAY')
      .fold(0, (n, p) => n + p.quantity);
  final dayShare =
      (savedProgramConditions?['day_share'] as num?)?.toInt() ??
      (totalHistorical > 0
          ? (100 * dayHistorical / totalHistorical).round()
          : 50);
  final savedDays = savedProgramConditions?['days'] as List?;
  Map dayConditions(DateTime date) {
    final index = date.difference(start).inDays;
    return savedDays != null && index >= 0 && index < savedDays.length
        ? savedDays[index] as Map
        : const {};
  }

  bool working(DateTime date) => dayConditions(date)['working'] != false;
  var firstObservedWeek = historyEnd;
  for (final p in productionHistory) {
    final w = _weekStartMonday(p.date);
    if (w.isBefore(firstObservedWeek)) firstObservedWeek = w;
  }
  final historyWeeks = math.max(
    1,
    historyEnd.difference(firstObservedWeek).inDays ~/ 7,
  );
  final forecast = <DateTime, Map<String, int>>{};
  final dayForecast = <DateTime, Map<String, int>>{};
  for (
    var day = today;
    !day.isAfter(friday);
    day = day.add(const Duration(days: 1))
  ) {
    if (day.isBefore(start)) continue;
    forecast[day] = {};
    dayForecast[day] = {};
    final c1 = _impactPercentForMachineOnDate(
      impacts: impacts,
      machineKey: 'c1',
      date: day,
    );
    final c2 = _impactPercentForMachineOnDate(
      impacts: impacts,
      machineKey: 'c2',
      date: day,
    );
    final cap = (dailyCapacity * (1 - (c1 + c2) / 200)).floor();
    final settings = dayConditions(day);
    for (final shift in ['DAY', 'NIGHT']) {
      final base = <String, int>{};
      for (final material in _suggestionMaterials) {
        double adjusted = 0;
        for (final p in productionHistory.where(
          (p) =>
              p.materialCode == material &&
              p.date.weekday == day.weekday &&
              p.shiftKey == shift,
        )) {
          final loss = p.compactadoraKey == 'c1'
              ? c1
              : p.compactadoraKey == 'c2'
              ? c2
              : math.max(c1, c2);
          adjusted += p.quantity * (1 - loss / 100);
        }
        base[material] = (adjusted / historyWeeks * intakeFactor).floor();
      }
      final dayCap = (cap * dayShare.clamp(0, 100) / 100).round();
      final slotCap =
          !working(day) ||
              settings[shift == 'DAY' ? 'day_available' : 'night_available'] ==
                  false
          ? 0
          : shift == 'DAY'
          ? dayCap
          : cap - dayCap;
      final sum = base.values.fold(0, (n, v) => n + v);
      for (final material in _suggestionMaterials) {
        var quantity = sum > slotCap && sum > 0
            ? (base[material]! * slotCap / sum).floor()
            : base[material]!;
        if (day == today) {
          final alreadyMade = production
              .where(
                (p) =>
                    _dateOnly(p.date) == today &&
                    p.materialCode == material &&
                    (shift == 'DAY'
                        ? p.shiftKey == 'DAY'
                        : p.shiftKey != 'DAY'),
              )
              .fold(0, (n, p) => n + p.quantity);
          quantity = math.max(0, quantity - alreadyMade);
        }
        forecast[day]![material] = (forecast[day]![material] ?? 0) + quantity;
        if (shift == 'DAY') dayForecast[day]![material] = quantity;
      }
    }
  }
  int future(String material, DateTime date) =>
      _suggestionProductionThrough(forecast, dayForecast, material, date);
  int weeklyLimit(List<_ObservedShipment> events) {
    final sizes = events.expand((e) => e.loads).toList()..sort();
    final earliest = events
        .map((e) => e.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final weeks = math.max(
      1,
      math.min(16, start.difference(_weekStartMonday(earliest)).inDays ~/ 7),
    );
    return math.max(
      sizes[(sizes.length - 1) ~/ 2],
      (events.fold(0, (n, e) => n + e.quantity) / weeks).round(),
    );
  }

  final orderedTargets = [
    for (final type in ['revuelto', 'limpio', 'americano'])
      DirectionShipmentTarget(
        baleTypeKey: type,
        sortOrder: 0,
        productionTargetBales: 0,
        notes: '',
        shipmentTargetBales: history.values
            .where(
              (e) =>
                  _suggestionMaterials.contains(e.first.material) &&
                  _gerenciaBaleTypeKeyForMaterial(e.first.material) == type,
            )
            .fold(0, (n, e) => n + weeklyLimit(e)),
      ),
  ];
  final suggestions = <DirectionSuggestedShipmentRecord>[];
  int available(String material, DateTime date) {
    final reserved = commitments
        .where((s) => s.materialCode == material && !s.shipDate.isAfter(date))
        .fold(0, (n, s) => n + s.plannedQuantity);
    final proposed = suggestions
        .where(
          (s) => s.materialCode == material && !s.suggestedDate.isAfter(date),
        )
        .fold(0, (n, s) => n + s.suggestedQuantity);
    return (validFloor[material] ?? 0) +
        future(material, date) -
        reserved -
        proposed;
  }

  final planningAllowed =
      start == _weekStartMonday(today) && !friday.isBefore(today);
  if (!planningAllowed) {
    observations.add(
      'La propuesta se genera para los días restantes de la semana actual, de lunes a viernes.',
    );
  }
  final coverage = <DirectionShipmentTargetCoverage>[];
  for (final target in orderedTargets) {
    var need = math.max(
      0,
      target.shipmentTargetBales -
          (actualByType[target.baleTypeKey] ?? 0) -
          (committedByType[target.baleTypeKey] ?? 0),
    );
    final candidates = history.values
        .where(
          (events) =>
              _suggestionMaterials.contains(events.first.material) &&
              _gerenciaBaleTypeKeyForMaterial(events.first.material) ==
                  target.baleTypeKey,
        )
        .toList();
    candidates.sort((a, b) {
      final priority = _priorityClientRank(
        a.first.client,
      ).compareTo(_priorityClientRank(b.first.client));
      if (priority != 0) return priority;
      final count = b.length.compareTo(a.length);
      return count != 0 ? count : a.first.client.compareTo(b.first.client);
    });
    if (planningAllowed) {
      for (final events in candidates) {
        if (need <= 0) break;
        final material = events.first.material;
        if (!validFloor.containsKey(material)) continue;
        events.sort((a, b) => a.date.compareTo(b.date));
        final sizes = events.expand((e) => e.loads).toList()..sort();
        final typical = sizes[(sizes.length - 1) ~/ 2];
        final clientLimit = weeklyLimit(events);
        final client = events.first.client;
        final clientKey = '$client|$material';
        var clientRemaining = math.max(
          0,
          clientLimit - (clientWeekQuantity[clientKey] ?? 0),
        );
        final weekdayCounts = <int, int>{};
        for (final e in events) {
          weekdayCounts[e.date.weekday] =
              (weekdayCounts[e.date.weekday] ?? 0) + 1;
        }
        while (need > 0 && clientRemaining > 0) {
          final desired = math.min(typical, math.min(need, clientRemaining));
          final minimum = math.max(8, (typical * 0.8).ceil());
          if (desired < minimum) break;
          DateTime? bestDate;
          var bestQuantity = 0;
          double bestScore = -double.infinity;
          for (
            var date = today;
            !date.isAfter(friday);
            date = date.add(const Duration(days: 1))
          ) {
            if (!working(date)) continue;
            // Protect every subsequent commitment, not just those due before
            // this suggestion. Otherwise an early shipment steals Friday stock.
            var safe = available(material, date) - 5;
            for (
              var checkpoint = date.add(const Duration(days: 1));
              checkpoint.isBefore(sunday);
              checkpoint = checkpoint.add(const Duration(days: 1))
            ) {
              safe = math.min(safe, available(material, checkpoint) - 5);
            }
            final quantity = math.min(desired, math.max(0, safe));
            if (quantity < minimum) continue;
            final sameDay =
                commitments.where((s) => _dateOnly(s.shipDate) == date).length +
                suggestions.where((s) => s.suggestedDate == date).length;
            // Quantity dominates, then habitual delivery day, balanced loading,
            // and an earlier dispatch. No fabricated truck/appointment capacity.
            final score =
                quantity * 1000.0 +
                (weekdayCounts[date.weekday] ?? 0) * 10 -
                sameDay * 5 -
                date.difference(today).inDays;
            if (score > bestScore) {
              bestScore = score;
              bestDate = date;
              bestQuantity = quantity;
            }
          }
          if (bestDate == null) break;
          final before = available(material, bestDate);
          final projected = future(material, bestDate);
          suggestions.add(
            DirectionSuggestedShipmentRecord(
              suggestedDate: bestDate,
              proposalIndex: suggestions.length,
              clientName: client,
              materialCode: material,
              materialScope: DirectionShipmentMaterialScope.commercial,
              quantityUnit: DirectionShipmentQuantityUnit.bales,
              suggestedQuantity: bestQuantity,
              projectedAvailableBeforeQuantity: before,
              projectedRemainingAfterQuantity: before - bestQuantity,
              expectedFutureQuantity: projected,
              currentFloorQuantity: validFloor[material]!,
              remainingHistoricalDemandQuantity: need,
              historicalAverageQuantity: typical,
              historicalShipmentCount: events.length,
              lastShipmentDate: events.last.date,
              risk: inventory.missingMaterials.contains(material)
                  ? DirectionShipmentRisk.unknown
                  : inventory.estimatedMaterials.contains(material)
                  ? DirectionShipmentRisk.estimated
                  : projected > 0 ||
                        before - bestQuantity <
                            math.max(5, (bestQuantity * .15).ceil())
                  ? DirectionShipmentRisk.tight
                  : DirectionShipmentRisk.good,
              gerenciaBaleTypeKey: target.baleTypeKey,
              explanation:
                  'Demanda histórica ${_gerenciaBaleTypeLabel(target.baleTypeKey)}: $need pacas aún por cubrir. '
                  'Carga habitual $typical pacas; ${events.length} días con embarque realizado. '
                  'Piso ${validFloor[material]}, producción disponible antes de la carga $projected. '
                  '${projected > 0 ? 'Depende de producir según historial, entradas y turnos. ' : ''}'
                  'Reserva mínima 5 pacas; compromisos posteriores protegidos.',
            ),
          );
          need -= bestQuantity;
          clientRemaining -= bestQuantity;
        }
      }
    }
    final total = suggestions
        .where((s) => s.gerenciaBaleTypeKey == target.baleTypeKey)
        .fold(0, (n, s) => n + s.suggestedQuantity);
    coverage.add(
      DirectionShipmentTargetCoverage(
        baleType: target.baleTypeKey,
        target: target.shipmentTargetBales,
        currentFloor: validFloor.entries
            .where(
              (e) =>
                  _gerenciaBaleTypeKeyForMaterial(e.key) == target.baleTypeKey,
            )
            .fold(0, (n, e) => n + e.value),
        productionActual: actualProduction[target.baleTypeKey] ?? 0,
        actual: actualByType[target.baleTypeKey] ?? 0,
        committed: committedByType[target.baleTypeKey] ?? 0,
        suggested: total,
      ),
    );
    if (need > 0) {
      observations.add(
        '${_gerenciaBaleTypeLabel(target.baleTypeKey)}: quedan $need pacas de demanda histórica sin propuesta factible; revisa piso, capacidad, historial de clientes y tamaño de carga.',
      );
    }
  }
  suggestions.sort((a, b) {
    final dateOrder = b.suggestedDate.compareTo(a.suggestedDate);
    return dateOrder != 0
        ? dateOrder
        : directionSuggestionKey(a).compareTo(directionSuggestionKey(b));
  });
  // A stable review token changes with inventory, calendar, reservations or suggestions.
  // Timestamps are intentionally absent so a silent reload does not invalidate
  // an otherwise identical proposal every twenty seconds.
  final sourceKey = jsonEncode([
    _fmtDate(start),
    for (final s in commitments)
      [s.id, _fmtDate(s.shipDate), s.materialCode, s.plannedQuantity, s.status],
    savedProgramConditions,
    inventory.opening,
    inventory.current,
    for (final entry in forecast.entries) [_fmtDate(entry.key), entry.value],
    for (final c in coverage) [c.baleType, c.actual, c.committed],
    for (final s in suggestions) directionSuggestionKey(s),
  ]);
  return DirectionShipmentSuggestionReport(
    weekStart: start,
    generatedAt: asOf,
    suggestions: List.unmodifiable(suggestions),
    coverage: List.unmodifiable(coverage),
    observations: List.unmodifiable(observations),
    intakeFactor: intakeFactor,
    operationHistoryCount: actualOut.length,
    directionHistoryCount: directionOut.length,
    productionRecordCount: productionHistory.length,
    sourceKey: sourceKey,
    incomingRecordCount: incomingCount,
    dailyCapacity: dailyCapacity,
    openingFloorByMaterial: inventory.opening,
    currentFloorByMaterial: inventory.current,
    estimatedFloorMaterials: inventory.estimatedMaterials,
    missingFloorMaterials: inventory.missingMaterials,
    productionForecast: forecast,
    dayProductionForecast: dayForecast,
  );
}
