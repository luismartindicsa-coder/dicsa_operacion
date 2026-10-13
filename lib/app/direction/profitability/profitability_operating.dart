import 'profitability_models.dart';
import 'profitability_parameters.dart';
import 'profitability_engine.dart' show profitPayrollPeriod;
import 'profitability_inference.dart' show profitMaterialFamily;
import 'profitability_material_basis.dart';
import 'profitability_material_units.dart';

/// Enriches the SAME consolidated analysis used by reconciliation and snapshots.
/// Documentary completeness remains available; it does not gate this result.
void populateProfitOperating(
  ProfitAnalysis a,
  String Function(String, [DateTime?]) resolve,
) {
  final master = a.master, period = a.sources.period;
  final materialBasis = ProfitMaterialBasis(a.sources, profitMaterialFamily);
  final costRules = a.effectiveCostRules;
  final components = <String, List<ProfitComponent>>{};
  final alerts = <String, List<String>>{};
  final coverage =
      <
        ({
          String company,
          String block,
          DateTime from,
          DateTime to,
          String vehicle,
        })
      >[];
  bool within(DateTime day) =>
      period.contains(day) &&
      !day.isAfter(
        DateTime(
          a.sources.readAt.year,
          a.sources.readAt.month,
          a.sources.readAt.day,
        ),
      );
  Iterable<DateTime> days(DateTime start, DateTime end) sync* {
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      yield d;
    }
  }

  List<ProfitComponent> forCompany(String key) {
    if (!a.companies.any((c) => c.entity.key == key)) {
      final entity =
          a.entities.where((e) => e.key == key).firstOrNull ??
          ProfitEntity(key, key, 'Sin identidad');
      a.companies.add(ProfitCompanyResult(entity, []));
    }
    return components.putIfAbsent(key, () => []);
  }

  bool covered(
    String company,
    String block,
    DateTime day, [
    String vehicle = '',
  ]) => coverage.any(
    (c) =>
        c.company == company &&
        c.block == block &&
        !day.isBefore(c.from) &&
        !day.isAfter(c.to) &&
        (c.vehicle.isEmpty || c.vehicle == vehicle),
  );
  void add(
    String company,
    String block,
    DateTime day,
    double? amount,
    ProfitSourceType type,
    String id,
    String reference,
    String rule, {
    String vehicle = '',
    bool fallback = false,
  }) {
    if (!within(day) || fallback && covered(company, block, day, vehicle)) {
      return;
    }
    forCompany(company).add(
      ProfitComponent(
        id: id,
        block: block,
        date: day,
        amount: amount,
        sourceType: amount == null ? ProfitSourceType.missing : type,
        reference: reference,
        rule: rule,
        confidence: amount == null
            ? 0
            : switch (type) {
                ProfitSourceType.actual => 1,
                ProfitSourceType.allocated => .85,
                ProfitSourceType.estimated => .6,
                ProfitSourceType.missing => 0,
              },
        vehicle: vehicle,
      ),
    );
  }

  // Reconciled costs win only inside their explicit concept / date / unit scope.
  // Allocate cents over the COMPLETE covered period before clipping to the view.
  void recognizeCost(ProfitCostFact fact) {
    final rule = costRules[fact.key];
    if (rule == null ||
        rule.treatment != ProfitCostTreatment.include ||
        a.pendingCosts.containsKey(fact.key)) {
      return;
    }
    final payrollPeriod = fact.payrollNet
        ? profitPayrollPeriod(fact.label)
        : null;
    final start = rule.coverageStart ?? payrollPeriod?.start ?? fact.date;
    final end = rule.coverageEnd ?? payrollPeriod?.end ?? fact.date;
    final allDays = days(start, end).toList();
    final shares = rule.shares.entries.toList()
      ..sort((x, y) => x.key.compareTo(y.key));
    var remaining = ((rule.recognizedAmount ?? fact.amount) * 100).round();
    final totalCents = remaining;
    for (var i = 0; i < shares.length; i++) {
      final cents = i == shares.length - 1
          ? remaining
          : (totalCents * shares[i].value).floor();
      remaining -= cents;
      final type = rule.estimated
          ? ProfitSourceType.estimated
          : (shares.length == 1 && allDays.length == 1
                ? ProfitSourceType.actual
                : ProfitSourceType.allocated);
      for (var di = 0; di < allDays.length; di++) {
        final d = allDays[di];
        final key = resolve(shares[i].key, d);
        if (!within(d) ||
            rule.estimated &&
                covered(key, rule.kind.name, d, rule.coverageVehicle)) {
          continue;
        }
        final dailyCents =
            cents ~/ allDays.length + (di < cents % allDays.length ? 1 : 0);
        add(
          key,
          rule.kind.name,
          d,
          dailyCents / 100,
          type,
          '${fact.key}:${profitDateText(d)}:$i',
          '${fact.key} · ${fact.signature}',
          '${rule.note} · ${(shares[i].value * 100).toStringAsFixed(2)}% · cobertura ${profitDateText(start)} a ${profitDateText(end)} · reparto uniforme por día',
          vehicle: rule.coverageVehicle,
        );
        coverage.add((
          company: key,
          block: rule.kind.name,
          from: d,
          to: d,
          vehicle: rule.coverageVehicle,
        ));
        if (rule.includesMaintenance) {
          coverage.add((
            company: key,
            block: 'maintenance',
            from: d,
            to: d,
            vehicle: rule.coverageVehicle,
          ));
          add(
            key,
            'maintenance',
            d,
            0,
            type,
            '${fact.key}:maintenance:$di:$i',
            fact.key,
            'Mantenimiento incluido en transporte; no se suma una segunda vez.',
            vehicle: rule.coverageVehicle,
          );
        }
      }
    }
  }

  for (final fact in a.costFacts.where(
    (f) => costRules[f.key]?.estimated != true,
  )) {
    recognizeCost(fact);
  }

  // Closed OT with an explicit site is direct evidence. Purchases linked to the
  // same OT and its payments stay documentary candidates, not additional costs.
  for (final row in a.sources.rows('maintenance_orders')) {
    final d = profitDate(row['end_at'] ?? row['requested_at']);
    final amount = profitNumber(row['cost_actual_total']);
    final id = 'ot:${row['id']}';
    if (d == null ||
        !within(d) ||
        row['status'] != 'cerrado' ||
        amount == null ||
        amount <= 0 ||
        profitText(row['site_id']).isEmpty ||
        costRules.containsKey(id)) {
      continue;
    }
    final key = resolve('site:${row['site_id']}', d),
        vehicle = profitText(row['equipment_id']);
    if (covered(key, 'maintenance', d, vehicle)) continue;
    add(
      key,
      'maintenance',
      d,
      amount,
      ProfitSourceType.actual,
      id,
      '$id · ${profitDigest(row)}',
      'OT cerrada, costo real y planta explícita.',
      vehicle: vehicle,
    );
    coverage.add((
      company: key,
      block: 'maintenance',
      from: d,
      to: d,
      vehicle: vehicle,
    ));
  }

  for (final fact in a.costFacts.where(
    (f) => costRules[f.key]?.estimated == true,
  )) {
    recognizeCost(fact);
  }

  for (final c in a.companies.toList()) {
    forCompany(c.entity.key);
    for (final m in c.materials) {
      for (final p in m.purchases) {
        final key = c.entity.key;
        add(
          key,
          'purchase',
          p.date,
          p.amountKnown ? p.amount : null,
          ProfitSourceType.actual,
          '${p.key}:purchase',
          '${p.key} · ${p.signature}',
          '${p.payableQuantity} ${profitUnitLabel(p.unit)} pagables · importe registrado',
        );
        final standard = master.recipe(key, p.materialKey, p.date);
        final recipe =
            a.review.recipes[m.key] ??
            (standard == null ? null : ProfitRecipe.fromJson(standard.data));
        double? value;
        final refs = <String>[];
        final outputs = [
          for (final o in recipe?.outputs ?? <ProfitOutputRule>[])
            (
              rule: o,
              valuation: materialBasis.outputPrice(
                a.benchmarks,
                o.benchmark,
                unit: p.unit,
              ),
            ),
        ];
        if (recipe != null &&
            (p.kgUnit || p.pieceUnit) &&
            p.quantity > 0 &&
            outputs.every((o) => o.valuation.price != null)) {
          value =
              p.quantity *
              outputs.fold<double>(
                0,
                (s, o) => s + o.rule.yieldFraction * o.valuation.price!,
              );
          for (final o in outputs) {
            refs.add(
              '${o.valuation.reference}; ${o.rule.yieldFraction * 100}% × ${o.valuation.description}',
            );
          }
        }
        add(
          key,
          'value',
          p.date,
          value,
          ProfitSourceType.estimated,
          '${p.key}:value',
          '${p.key}; ${standard == null ? 'receta del corte ${m.key}' : 'parámetro ${standard.id}'}; ${refs.join('; ')}',
          value == null
              ? 'Falta rendimiento, peso válido o venta comparable.'
              : '${p.quantity} ${profitUnitLabel(p.unit)} × Σ(rendimiento × venta ponderada). ${recipe!.note}',
        );
      }
    }
  }

  // Pesadas records a service charge, separate from a material sale. Free text
  // is attributed ONLY through an explicitly approved alias in the master.
  for (final row in a.sources.rows('pesadas')) {
    final d = profitDate(row['fecha']), amount = profitNumber(row['precio']);
    if (d == null || !within(d) || amount == null || amount < 0) continue;
    final raw = 'expense:${profitKey(row['proveedor'])}';
    final key = resolve(raw, d);
    if (key == raw) continue;
    add(
      key,
      'income',
      d,
      amount,
      ProfitSourceType.actual,
      'weighing:${row['id']}',
      'pesadas:${row['id']} · ticket ${row['ticket']} · ${profitDigest(row)}',
      'Cargo de pesada registrado; alias aprobado. No equivale a cobro bancario.',
    );
  }

  final vehicles = {
    for (final r in a.sources.rows('logistics_vehicle_profiles'))
      profitText(r['vehicle_id']): r,
  };
  final trips = <String, List<ProfitRow>>{};
  final tripsByCompanyDay = <String, int>{};
  for (final row in a.sources.rows('services')) {
    final d = profitDate(row['due_date'] ?? row['service_date']);
    if (d == null ||
        !within(d) ||
        row['area'] != 'LOGISTICA' ||
        row['status'] != 'completado' ||
        profitText(row['client_id']).isEmpty) {
      continue;
    }
    final key = resolve('site:${row['client_id']}', d);
    forCompany(key);
    final index = '$key|${profitDateText(d)}';
    tripsByCompanyDay[index] = (tripsByCompanyDay[index] ?? 0) + 1;
    (trips['${profitDateText(d)}|${row['vehicle_id']}'] ??= []).add(row);
  }
  final mileage = <String, List<ProfitRow>>{};
  for (final r in a.sources.rows('logistics_vehicle_mileage')) {
    final d = profitDate(r['entry_date']);
    if (d != null && within(d)) {
      (mileage['${profitDateText(d)}|${r['vehicle_id']}'] ??= []).add(r);
    }
  }
  for (final entry in trips.entries) {
    final rows = entry.value, d = profitDate(entry.key.split('|').first)!;
    final vehicle = profitText(rows.first['vehicle_id']);
    final type = profitText(vehicles[vehicle]?['logistics_unit_type']);
    final available = master.at(ProfitParameterKind.vehicle, d);
    final rate =
        available
            .where((r) => r.text('unit') == 'vehicle:$vehicle')
            .firstOrNull ??
        available.where((r) => r.text('unit') == 'type:$type').firstOrNull;
    final kmRows = mileage[entry.key] ?? [];
    // One measured daily total, split by completed services when shared. This
    // attribution is always disclosed; never presented as measured trip km.
    final km =
        kmRows.isEmpty ||
            kmRows.any((r) => (profitNumber(r['kilometers']) ?? -1) < 0)
        ? null
        : kmRows.fold<double>(0, (s, r) => s + profitNumber(r['kilometers'])!);
    final perCompany = <String, int>{};
    for (final r in rows) {
      final key = resolve('site:${r['client_id']}', d);
      perCompany[key] = (perCompany[key] ?? 0) + 1;
    }
    for (final e in perCompany.entries) {
      final key = e.key, share = e.value / rows.length;
      final ref =
          'parámetro ${rate?.id ?? 'faltante'}; servicios ${rows.map((r) => r['id']).join(',')}; km ${kmRows.map((r) => r['id']).join(',')}';
      for (final item in [
        ('fuel', 'fuel_cost_per_km'),
        ('maintenance', 'maintenance_cost_per_km'),
      ]) {
        final cost = rate?.number(item.$2);
        add(
          key,
          item.$1,
          d,
          km == null || cost == null ? null : km * share * cost,
          ProfitSourceType.estimated,
          '${entry.key}:$key:${item.$1}',
          ref,
          '${km ?? '?'} km de unidad/día × ${e.value}/${rows.length} servicios × ${cost ?? '?'} MXN/km. Reparto por servicios; no distancia medida por viaje.',
          vehicle: vehicle,
          fallback: true,
        );
      }
      final fixed = rate?.number('fixed_cost_per_service');
      final hourly = rate?.number('optional_cost_per_hour');
      final hours = rate?.number('hours_per_service');
      add(
        key,
        'transport',
        d,
        fixed == null && hourly == null
            ? null
            : e.value * ((fixed ?? 0) + (hourly ?? 0) * (hours ?? 0)),
        ProfitSourceType.estimated,
        '${entry.key}:$key:transport',
        ref,
        '${e.value} servicios × (${fixed ?? 0} fijo + ${hourly ?? 0}/hora × ${hours ?? 0} horas estándar). Combustible y mantenimiento separados.',
        vehicle: vehicle,
        fallback: true,
      );
    }
  }

  for (final c in a.companies.toList()) {
    final key = c.entity.key;
    final purchases = c.materials.expand((m) => m.purchases).toList();
    for (final day in days(period.start, period.end).where(within)) {
      for (final r
          in master
              .at(ProfitParameterKind.labor, day)
              .where((r) => r.company == key)) {
        final activity = master
            .at(ProfitParameterKind.activity, day)
            .where(
              (v) =>
                  v.company == key &&
                  v.text('measure') == 'hours' &&
                  v.text('subject') == r.text('role'),
            )
            .firstOrNull;
        final count = tripsByCompanyDay['$key|${profitDateText(day)}'] ?? 0;
        double? amount;
        String formula;
        if (r.text('basis') == 'hour') {
          final hours =
              activity?.number('quantity') ??
              (r.number('hours_per_service') == null || count == 0
                  ? null
                  : count * r.number('hours_per_service')!);
          amount = hours == null
              ? null
              : hours * r.number('labor_cost_per_hour')!;
          formula =
              '${hours ?? '?'} horas atribuibles × ${r.number('labor_cost_per_hour')}/hora';
          if (hours == null && count == 0 && activity == null) continue;
        } else {
          if (day.weekday > int.parse(r.text('week_days'))) continue;
          final daily = r.text('basis') == 'day'
              ? r.number('labor_cost_per_day')!
              : r.number('period_labor_cost')! / r.number('working_days')!;
          amount = daily * r.number('workers')!;
          formula =
              '${r.text('basis') == 'dedicated' ? '${r.number('period_labor_cost')} / ${r.number('working_days')} días' : daily.toStringAsFixed(2)} × ${r.number('workers')} personas';
        }
        add(
          key,
          'payroll',
          day,
          amount,
          ProfitSourceType.estimated,
          '${r.id}:${profitDateText(day)}',
          'parámetro ${r.id}; actividad ${activity?.id ?? 'estándar por servicio/día'}',
          '${r.text('role')}: $formula. ${r.note}',
          fallback: true,
        );
      }
      for (final r
          in master
              .at(ProfitParameterKind.process, day)
              .where((r) => r.company == key)) {
        final activity = master
            .at(ProfitParameterKind.activity, day)
            .where(
              (v) =>
                  v.company == key &&
                  v.text('measure') == 'kg' &&
                  v.text('subject') == r.text('material'),
            )
            .firstOrNull;
        final received = purchases
            .where((p) => p.date == day && p.materialKey == r.text('material'))
            .toList();
        if (r.text('kg_basis') == 'received' && received.isEmpty ||
            r.text('kg_basis') == 'activity' &&
                activity == null &&
                received.isEmpty) {
          continue;
        }
        final kg = r.text('kg_basis') == 'received'
            ? received.fold<double>(0, (s, p) => s + p.physicalKg)
            : activity?.number('quantity');
        add(
          key,
          'process',
          day,
          kg == null ? null : kg * r.number('cost_per_kg')!,
          ProfitSourceType.estimated,
          '${r.id}:${profitDateText(day)}',
          'parámetro ${r.id}; ${activity?.id ?? received.map((p) => p.key).join(',')}',
          '${r.text('process')}: ${kg ?? '?'} kg ${r.text('kg_basis') == 'received' ? 'recibidos como aproximación aprobada al proceso' : 'de actividad registrada'} × ${r.number('cost_per_kg')}/kg. ${r.note}',
          fallback: true,
        );
      }
    }
    // Explicit zero-cost / no-income assertions are dated and evidenced.
    for (final block in [
      'income',
      'fuel',
      'transport',
      'payroll',
      'process',
      'maintenance',
      'other',
      'overhead',
    ]) {
      final relevantDays = days(period.start, period.end)
          .where(within)
          .where(
            (d) =>
                purchases.any((p) => p.date == d) ||
                (tripsByCompanyDay['$key|${profitDateText(d)}'] ?? 0) > 0 ||
                forCompany(key).any((v) => v.date == d && v.amount != null),
          )
          .toSet();
      for (final d in relevantDays) {
        if (forCompany(key).any((v) => v.block == block && v.date == d)) {
          continue;
        }
        final zero = master
            .at(ProfitParameterKind.coverage, d)
            .where((r) => r.company == key && r.text('block') == block)
            .firstOrNull;
        add(
          key,
          block,
          d,
          zero == null ? null : 0,
          ProfitSourceType.allocated,
          'coverage:$key:$block:${profitDateText(d)}',
          zero == null ? 'Sin base cuantificada' : 'parámetro ${zero.id}',
          zero == null
              ? 'No hay costo/ingreso conciliado, actividad con tarifa ni declaración de no aplicabilidad.'
              : 'Sin importe aplicable: ${zero.note}',
        );
      }
    }
    final list = forCompany(key);
    for (var i = 0; i < list.length; i++) {
      final v = list[i];
      if (v.amount != null) continue;
      final zero = master
          .at(ProfitParameterKind.coverage, v.date)
          .where((r) => r.company == key && r.text('block') == v.block)
          .firstOrNull;
      if (zero != null) {
        list[i] = ProfitComponent(
          id: v.id,
          block: v.block,
          date: v.date,
          amount: 0,
          sourceType: ProfitSourceType.allocated,
          reference: 'parámetro ${zero.id}',
          rule: 'Sin importe aplicable: ${zero.note}',
          confidence: .85,
          vehicle: v.vehicle,
        );
      }
    }
    final notes = alerts.putIfAbsent(key, () => []);
    final fuel = list
        .where(
          (v) =>
              v.block == 'fuel' && v.sourceType == ProfitSourceType.estimated,
        )
        .fold<double>(0, (s, v) => s + (v.amount ?? 0));
    if (fuel > 0) {
      notes.add('Combustible estimado por km: ${fuel.toStringAsFixed(2)} MXN.');
    }
    if (list.any((v) => v.block == 'value' && v.amount == null)) {
      notes.add(
        'Falta valorar parte del material; el aporte es parcial y no permite concluir una pérdida total.',
      );
    }
    final missing = list
        .where((v) => v.amount == null)
        .map((v) => v.block)
        .toSet();
    if (missing.isNotEmpty) {
      notes.add(
        'Sin cuantificar: ${missing.join(', ')}. No se representan como cero.',
      );
    }
    c.operating = ProfitOperatingResult(
      list,
      alerts: notes,
      group: master.group(key, period.end),
    );
  }
  a.companies.sort((x, y) => x.entity.name.compareTo(y.entity.name));
}
