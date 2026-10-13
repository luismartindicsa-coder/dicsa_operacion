import 'profitability_models.dart';
import 'profitability_parameters.dart';
import 'profitability_operating.dart';
import 'profitability_inference.dart';
import 'profitability_cost_basis.dart';
import 'profitability_material_basis.dart';
import 'profitability_material_units.dart';

String resolveProfitEntity(String key, ProfitReview review) {
  final seen = <String>{};
  while (review.identities.containsKey(key)) {
    if (!seen.add(key)) throw StateError('Equivalencia circular.');
    key = review.identities[key]!;
  }
  return key;
}

ProfitPeriod? profitPayrollPeriod(String label) {
  final match = RegExp(
    r'(\d{2}/\d{2}/\d{4})\s*-\s*(\d{2}/\d{2}/\d{4})',
  ).firstMatch(label);
  if (match == null) return null;
  final start = profitDate(match[1]), end = profitDate(match[2]);
  return start == null || end == null ? null : ProfitPeriod(start, end);
}

/// Matches the closed Nómina delivery total. This is deliberately NOT called
/// employer cost. Fiscal cheques are a delivery channel, never added again.
double profitPayrollNet(ProfitRow row) {
  double n(String key) => profitNumber(row[key]) ?? 0;
  final info =
      (row['incidences_informational'] ??
          (row['source_snapshot'] as Map?)?['incidences_informational']) ==
      true;
  final fiscal =
      (n('fiscal_net_amount') -
              n('fiscal_manual_deduction_amount') -
              (info ? 0 : n('fiscal_late_deduction_amount')))
          .clamp(0, double.infinity);
  final complements = [
    'cash_salary_amount',
    'cash_vacation_amount',
    'transport_support_amount',
    'holiday_amount',
    'overtime_monetized_amount',
    'manual_bonus_amount',
    'manual_adjustment_amount',
  ].fold<double>(0, (s, k) => s + n(k));
  final deductions =
      n('cash_isr_amount') +
      (info ? 0 : n('cash_absence_deduction_amount')) +
      n('cash_infonavit_deduction_amount') +
      n('cash_fonacot_deduction_amount') +
      n('loan_deduction_amount');
  return fiscal + n('payment_outside_amount') + complements - deductions;
}

ProfitAnalysis analyzeProfitability(
  ProfitSources sources,
  ProfitReview review, {
  ProfitMaster master = const ProfitMaster(),
  bool inferOperations = false,
}) {
  review.validate();
  master.validate();
  final costRules = sources.sharedCostRules(review);
  review.copyWith(costs: costRules).validate();
  final period = sources.period;
  final today = DateTime(
    sources.readAt.year,
    sources.readAt.month,
    sources.readAt.day,
  );
  final issues = <String>[];
  final entities = <String, ProfitEntity>{};
  final benchmarks = <String, ProfitBenchmark>{};
  final historicalBenchmarks = <String, ProfitBenchmark>{};
  final purchases = <ProfitPurchase>[];
  final costs = <ProfitCostFact>[];
  int excludedSales = 0, excludedPurchases = 0;
  final costBasis = ProfitCostBasis(sources);
  bool within(Object? date) =>
      period.contains(date) && !(profitDate(date)?.isAfter(today) ?? true);
  bool costWithin(Object? date, String key) {
    if (within(date)) return true;
    final day = profitDate(date);
    if (inferOperations &&
        day != null &&
        !day.isAfter(today) &&
        (key.startsWith('bank:') || key.startsWith('invoice:'))) {
      final coverage = costBasis.coverage(key, day);
      if (!coverage.end.isBefore(period.start) &&
          !coverage.start.isAfter(period.end)) {
        return true;
      }
    }
    final rule = costRules[key];
    return rule?.treatment == ProfitCostTreatment.include &&
        rule?.coverageStart != null &&
        rule?.coverageEnd != null &&
        !rule!.coverageStart!.isAfter(period.end) &&
        !rule.coverageEnd!.isBefore(period.start);
  }

  if (period.end.isAfter(today)) {
    issues.add(
      'El corte incluye fechas futuras; no representa un periodo realizado completo.',
    );
  }
  for (final e in sources.tables.entries) {
    final ids = e.value
        .map((r) => profitText(r['id']))
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.toSet().length != ids.length) {
      throw StateError('La fuente ${e.key} contiene IDs duplicados.');
    }
  }
  void entity(String key, String name, String source) {
    if (key.endsWith(':') || name.isEmpty) return;
    entities.putIfAbsent(key, () => ProfitEntity(key, name, source));
  }

  for (final r in sources.rows('sites')) {
    entity('site:${r['id']}', profitText(r['name']), 'Operación');
  }
  for (final spec in [
    ('compras_counterparties', 'compras', 'Compras'),
    ('men_counterparties', 'men', 'Menudeo'),
    ('mayoreo_counterparties', 'ventas', 'Ventas'),
  ]) {
    for (final r in sources.rows(spec.$1)) {
      entity('${spec.$2}:${r['id']}', profitText(r['name']), spec.$3);
    }
  }
  if (inferOperations) {
    for (final r in sources.rows('hr_employee_profiles')) {
      entity(
        'payroll:${profitKey(r['empresa'])}',
        profitText(r['empresa']),
        'RH',
      );
    }
  }
  final linkedMen = {
    for (final r in sources.rows('men_counterparties'))
      if (profitText(r['site_id']).isNotEmpty &&
          entities.containsKey('site:${r['site_id']}'))
        'men:${r['id']}': 'site:${r['site_id']}',
  };
  final inferredIdentities = inferOperations
      ? inferProfitIdentities(sources)
      : <String, String>{};
  String resolve(String key, [DateTime? day]) {
    key = master.resolve(key, day ?? period.end);
    final seen = <String>{};
    while (review.identities.containsKey(key) || linkedMen.containsKey(key)) {
      if (!seen.add(key)) {
        throw StateError('Equivalencia circular entre catálogos.');
      }
      key = master.resolve(
        review.identities[key] ?? linkedMen[key]!,
        day ?? period.end,
      );
    }
    return inferredIdentities[key] ?? key;
  }

  final purchaseCatalog = {
    for (final r in sources.rows('compras_material_catalog'))
      profitText(r['id']): r,
  };
  final saleCatalog = {
    for (final r in sources.rows('mayoreo_material_catalog'))
      profitText(r['id']): r,
  };
  void addPurchase(ProfitRow row, {required bool retail}) {
    if (!within(row['ticket_date'])) return;
    final prefix = retail ? 'men' : 'compras';
    final key = '$prefix:${row['id']}';
    final entityId = profitText(
      row[retail ? 'counterparty_id' : 'provider_id'],
    );
    final entityKey = entityId.isEmpty ? 'unknown:$key' : '$prefix:$entityId';
    if (entityId.isEmpty) {
      issues.add(
        'Compra ${row['ticket_number']}: falta vínculo con la empresa de origen.',
      );
    }
    final name = profitText(
      row[retail ? 'counterparty_name_snapshot' : 'provider_name_snapshot'],
    );
    entity(
      entityKey,
      name.isEmpty ? 'Sin empresa · ${row['ticket_number']}' : name,
      retail ? 'Menudeo' : 'Compras',
    );
    final materialId = profitText(
      row[retail ? 'commercial_material_id' : 'material_id'],
    );
    final materialName = profitText(
      row[retail ? 'material_label_snapshot' : 'material_name_snapshot'],
    );
    final signature = profitDigest(row);
    final excluded = review.excludedPurchases[key];
    if (excluded != null &&
        excluded['signature'] == signature &&
        profitText(excluded['note']).isNotEmpty) {
      excludedPurchases++;
      return;
    }
    if (excluded != null) {
      issues.add(
        'La exclusión del ticket ${row['ticket_number']} requiere revisión por cambios en origen.',
      );
    }
    final amount = profitNumber(row[retail ? 'amount_total' : 'amount']);
    final payable = profitNumber(row['payable_weight']);
    final physical = profitNumber(row['net_weight']);
    if (retail && !['PAGADO', 'PENDIENTE'].contains(profitKey(row['status']))) {
      excludedPurchases++;
      issues.add('Compra ${row['ticket_number']}: estado no elegible.');
      return;
    }
    if (amount == null ||
        amount < 0 ||
        payable == null ||
        payable < 0 ||
        physical == null ||
        physical <= 0 ||
        materialId.isEmpty) {
      // Keep its known cost and company visible; the material is not valued.
      issues.add(
        'Compra ${row['ticket_number']}: peso, material o importe incompleto.',
      );
    }
    final quantityUnit = profitPurchaseUnit(
      row,
      retail: retail,
      catalog: purchaseCatalog[materialId],
    );
    final validQuantity =
        amount != null &&
        payable != null &&
        physical != null &&
        materialId.isNotEmpty;
    purchases.add(
      ProfitPurchase(
        key: key,
        entityKey: entityKey,
        materialKey: '$prefix:$materialId',
        material: materialName.isEmpty ? 'Sin material' : materialName,
        reference: profitText(row['ticket_number']),
        source: retail ? 'Menudeo' : 'Compras',
        signature: signature,
        date: profitDate(row['ticket_date'])!,
        physicalKg: quantityUnit == 'PZA' ? 0 : physical ?? 0,
        payableKg: quantityUnit == 'PZA' ? 0 : payable ?? 0,
        pieces: quantityUnit == 'PZA' ? physical ?? 0 : 0,
        payablePieces: quantityUnit == 'PZA' ? payable ?? 0 : 0,
        pieceUnit: validQuantity && quantityUnit == 'PZA',
        amount: amount ?? 0,
        amountKnown: amount != null && amount >= 0,
        kgUnit: validQuantity && quantityUnit == 'KG',
      ),
    );
  }

  void addSale(ProfitRow row, {required bool retail, bool historical = false}) {
    if (retail && row['direction'] != 'sale') return;
    final saleDay = profitDate(row[retail ? 'ticket_date' : 'sale_date']);
    if (saleDay == null ||
        (historical
            ? (!saleDay.isBefore(period.start) ||
                  saleDay.isBefore(
                    period.start.subtract(const Duration(days: 90)),
                  ))
            : !within(saleDay.toIso8601String()))) {
      return;
    }
    final weight = profitNumber(
      row[retail ? 'payable_weight' : 'approved_weight'],
    );
    final amount = profitNumber(
      row[retail ? 'amount_total' : 'approved_amount'],
    );
    final price = profitNumber(
      row[retail ? 'price_at_entry' : 'approved_price'],
    );
    final id = profitText(
      row[retail ? 'commercial_material_id' : 'material_id'],
    );
    final unit = retail
        ? profitRetailSaleUnit(row)
        : profitQuantityUnit(saleCatalog[id]?['unit']);
    final eligible = retail
        ? ['PAGADO', 'PENDIENTE'].contains(profitKey(row['status']))
        : ['KG', 'PZA'].contains(unit);
    if (!eligible ||
        id.isEmpty ||
        weight == null ||
        weight <= 0 ||
        amount == null ||
        amount <= 0 ||
        price == null ||
        price <= 0) {
      excludedSales++;
      return;
    }
    final key =
        '${retail ? 'men' : 'ventas'}:$id${unit == 'KG' ? '' : '@$unit'}';
    final benchmark = (historical ? historicalBenchmarks : benchmarks)
        .putIfAbsent(
          key,
          () => ProfitBenchmark(
            key,
            profitText(
              row[retail
                  ? 'material_label_snapshot'
                  : 'material_name_snapshot'],
            ),
            retail ? 'Menudeo' : 'Mayoreo',
            unit: unit,
          ),
        );
    benchmark.quantity += weight;
    benchmark.amount += amount;
    benchmark.count++;
    final date = profitDate(row[retail ? 'ticket_date' : 'sale_date'])!;
    if (benchmark.first == null || date.isBefore(benchmark.first!)) {
      benchmark.first = date;
    }
    if (benchmark.last == null || date.isAfter(benchmark.last!)) {
      benchmark.last = date;
    }
  }

  for (final row in sources.rows('compras_tickets')) {
    addPurchase(row, retail: false);
  }
  for (final row in sources.rows('men_tickets')) {
    if (row['direction'] == 'purchase') addPurchase(row, retail: true);
    if (row['direction'] == 'sale') addSale(row, retail: true);
  }
  for (final row in sources.rows('mayoreo_sales_reports')) {
    addSale(row, retail: false);
  }

  for (final row in sources.rows('profit_history_mayoreo')) {
    addSale(row, retail: false, historical: true);
  }
  for (final row in sources.rows('profit_history_men')) {
    addSale(row, retail: true, historical: true);
  }
  for (final entry in historicalBenchmarks.entries) {
    benchmarks.putIfAbsent(entry.key, () => entry.value);
  }
  final materialBasis = ProfitMaterialBasis(sources, profitMaterialFamily);

  ProfitCostKind kind(String text) {
    final n = profitKey(text);
    if (RegExp('DIESEL|GASOLINA|COMBUSTIBLE').hasMatch(n)) {
      return ProfitCostKind.fuel;
    }
    if (RegExp('FLETE|TRANSPORTE|CASETA|MANIOBRA').hasMatch(n)) {
      return ProfitCostKind.transport;
    }
    if (RegExp('MANTENIMIENTO|REFACCION|REPARACION').hasMatch(n)) {
      return ProfitCostKind.maintenance;
    }
    return ProfitCostKind.other;
  }

  bool settledElsewhere(String category) => [
    'MOVIMIENTOS INTERNOS',
    'REPOSICION DE FONDO',
    'COMPRA DE MATERIAL',
    'NOMINA',
  ].contains(profitKey(category));
  for (final prefix in ['men_cash', 'direction_vault']) {
    final heads = {
      for (final r in sources.rows('${prefix}_vouchers'))
        profitText(r['id']): r,
    };
    final totals = <String, double>{};
    for (final line in sources.rows('${prefix}_voucher_lines')) {
      final head = heads[profitText(line['voucher_id'])];
      if (head == null ||
          !costWithin(head['voucher_date'], '$prefix:${line['id']}') ||
          head['voucher_type'] != 'expense') {
        continue;
      }
      final amount = profitNumber(line['amount']);
      final rubric = profitText(head['rubric']);
      if (settledElsewhere(rubric)) continue;
      totals.update(
        profitText(head['id']),
        (v) => v + (amount ?? 0),
        ifAbsent: () => amount ?? 0,
      );
      if (amount == null || amount < 0) {
        issues.add('Vale ${head['folio']}: importe de renglón no válido.');
        continue;
      }
      if (amount == 0) continue;
      final company = profitText(line['company']);
      final entityKey = company.isEmpty ? '' : 'expense:${profitKey(company)}';
      entity(entityKey, company, 'Gastos');
      final label =
          '${head['folio']} · $rubric · ${profitText(line['concept'])} ${profitText(line['subconcept'])}';
      costs.add(
        ProfitCostFact(
          key: '$prefix:${line['id']}',
          label: label,
          source: prefix == 'men_cash' ? 'Caja Menudeo' : 'Bóveda',
          date: profitDate(head['voucher_date'])!,
          amount: amount,
          signature: profitSignature([head, line]),
          entityKey: entityKey,
          suggestedKind: kind(label),
        ),
      );
    }
    for (final head in heads.values) {
      if (!costWithin(head['voucher_date'], '$prefix:residual:${head['id']}') ||
          head['voucher_type'] != 'expense' ||
          settledElsewhere(profitText(head['rubric']))) {
        continue;
      }
      final total = profitNumber(head['total_amount']);
      if (total == null) {
        issues.add('Vale ${head['folio']}: total faltante.');
        continue;
      }
      final residual = total - (totals[profitText(head['id'])] ?? 0);
      if (residual.abs() > .011) {
        issues.add(
          'Vale ${head['folio']}: diferencia de ${residual.toStringAsFixed(2)} entre total y renglones.',
        );
        if (residual > 0) {
          costs.add(
            ProfitCostFact(
              key: '$prefix:residual:${head['id']}',
              label:
                  '${head['folio']} · ${profitText(head['rubric'])} · Sin detalle conciliado',
              source: prefix == 'men_cash' ? 'Caja Menudeo' : 'Bóveda',
              date: profitDate(head['voucher_date'])!,
              amount: residual,
              signature: profitSignature([
                head,
                totals[profitText(head['id'])],
              ]),
            ),
          );
        }
      }
    }
  }
  for (final row in sources.rows('finanzas_bank_movements')) {
    final amount = profitNumber(row['debit_amount']);
    if (!costWithin(row['movement_date'], 'bank:${row['id']}') ||
        amount == null ||
        amount <= 0 ||
        settledElsewhere(profitText(row['category']))) {
      continue;
    }
    final label =
        '${profitText(row['reference'])} · ${profitText(row['category'])} · ${profitText(row['counterparty_name_snapshot'])}';
    costs.add(
      ProfitCostFact(
        key: 'bank:${row['id']}',
        label: label,
        source: 'Bancos · documento por conciliar',
        date: profitDate(row['movement_date'])!,
        amount: amount,
        signature: profitDigest(row),
        suggestedKind: kind('$label ${row['comment']}'),
      ),
    );
  }
  for (final row in sources.rows('finanzas_supplier_invoices')) {
    final amount = profitNumber(row['total_amount']);
    if (!costWithin(row['invoice_date'], 'invoice:${row['id']}') ||
        row['origin_type'] != 'MANUAL' ||
        profitKey(row['status']).contains('CANCEL') ||
        amount == null ||
        amount <= 0) {
      continue;
    }
    costs.add(
      ProfitCostFact(
        key: 'invoice:${row['id']}',
        label: '${row['invoice_folio']} · ${row['provider_name_snapshot']}',
        source: 'Factura manual · documento por conciliar',
        date: profitDate(row['invoice_date'])!,
        amount: amount,
        signature: profitDigest(row),
      ),
    );
  }
  for (final row in sources.rows('maintenance_orders')) {
    final date = row['end_at'] ?? row['requested_at'];
    final amount = profitNumber(row['cost_actual_total']);
    if (!costWithin(date, 'ot:${row['id']}') ||
        amount == null ||
        amount <= 0 ||
        row['status'] == 'rechazado') {
      continue;
    }
    costs.add(
      ProfitCostFact(
        key: 'ot:${row['id']}',
        label:
            '${row['ot_folio']} · ${row['equipment_label']} · ${row['status']}',
        source: 'OT · costo declarado',
        date: profitDate(date)!,
        amount: amount,
        signature: profitDigest(row),
        vehicleId: profitText(row['equipment_id']),
        suggestedKind: ProfitCostKind.maintenance,
      ),
    );
  }
  for (final row in sources.rows('maintenance_purchase_orders')) {
    if (row['status'] != 'purchased' ||
        !costWithin(
          row['purchased_at'] ?? row['order_date'],
          'po:${row['id']}',
        )) {
      continue;
    }
    final amount = profitNumber(row['actual_total']);
    if (amount == null || amount < 0) {
      issues.add('Orden ${row['folio']}: compra sin importe real válido.');
      continue;
    }
    if (amount == 0) continue;
    costs.add(
      ProfitCostFact(
        key: 'po:${row['id']}',
        label:
            '${row['folio']} · ${row['target_label']} · ${row['quote_vendor_name']}',
        source: 'Orden comprada · documento por conciliar',
        date: profitDate(row['purchased_at'] ?? row['order_date'])!,
        amount: amount,
        signature: profitDigest(row),
        suggestedKind: ProfitCostKind.maintenance,
      ),
    );
  }

  final closures = <String>{};
  final coveredDays = <String>{};
  for (final row in sources.rows('hr_payroll_period_closures')) {
    final label = profitText(row['period_label']);
    final dates = profitPayrollPeriod(label);
    if (row['status'] != 'cerrado' ||
        dates == null ||
        dates.end.isBefore(period.start) ||
        dates.start.isAfter(period.end)) {
      continue;
    }
    if (!period.contains(dates.start) || !period.contains(dates.end)) {
      issues.add(
        'Nómina $label cruza el corte. Selecciona periodos completos o concilia su devengo.',
      );
      continue;
    }
    closures.add(label);
    for (
      var d = dates.start;
      !d.isAfter(dates.end);
      d = d.add(const Duration(days: 1))
    ) {
      if (!coveredDays.add(profitDateText(d))) {
        issues.add(
          'Nómina cerrada superpuesta en ${profitDateText(d)}; conciliar periodos.',
        );
      }
    }
  }
  if (coveredDays.length != period.days) {
    issues.add(
      'Nómina cerrada cubre ${coveredDays.length} de ${period.days} días del corte.',
    );
  }
  final payrollGroups = <String, List<ProfitRow>>{};
  final payrollSeen = <String>{};
  for (final row in sources.rows('hr_prenomina_draft_rows')) {
    final label = profitText(row['period_label']);
    if (!closures.contains(label)) continue;
    if (profitText(row['employee_id']).isEmpty) {
      issues.add(
        'Nómina $label contiene una fila sin identificador de empleado.',
      );
    }
    final employeePeriod = '$label|${row['employee_id']}';
    if (!payrollSeen.add(employeePeriod)) {
      throw StateError(
        'Nómina contiene dos filas del mismo empleado y periodo.',
      );
    }
    if (row['draft_status'] != 'publicado') {
      issues.add('Nómina cerrada $label contiene filas sin publicar.');
      continue;
    }
    final company = profitText(row['empresa']);
    entity('payroll:${profitKey(company)}', company, 'RH');
    (payrollGroups['$label|${profitKey(company)}'] ??= []).add(row);
  }
  if (closures.isNotEmpty && payrollGroups.isEmpty) {
    issues.add(
      'Los cierres de nómina no tienen renglones publicados visibles.',
    );
  }
  for (final entry in payrollGroups.entries) {
    final rows = entry.value
      ..sort((a, b) => profitText(a['id']).compareTo(profitText(b['id'])));
    final label = profitText(rows.first['period_label']);
    final company = profitText(rows.first['empresa']);
    final amount = rows.fold<double>(0, (s, r) => s + profitPayrollNet(r));
    if (amount < 0) {
      issues.add('Nómina $company: neto negativo por conciliar.');
      continue;
    }
    costs.add(
      ProfitCostFact(
        key: 'payroll:${entry.key}',
        label: '$company · $label · ${rows.length} personas',
        source: 'RH · neto publicado, no costo patronal',
        date: profitPayrollPeriod(label)!.end,
        amount: amount,
        signature: profitDigest(rows),
        entityKey: 'payroll:${profitKey(company)}',
        suggestedKind: ProfitCostKind.payroll,
        payrollNet: true,
      ),
    );
  }
  for (final pair in review.identities.entries) {
    if (!entities.containsKey(pair.key) || !entities.containsKey(pair.value)) {
      issues.add(
        'Equivalencia ${pair.key}: origen o destino no disponible en este corte.',
      );
    }
  }

  final grouped = <String, List<ProfitPurchase>>{};
  for (final purchase in purchases) {
    final key =
        '${resolve(purchase.entityKey, purchase.date)}|${purchase.materialKey}';
    (grouped[key] ??= []).add(purchase);
  }
  final companies = <String, ProfitCompanyResult>{};
  ProfitCompanyResult company(String key) => companies.putIfAbsent(
    key,
    () => ProfitCompanyResult(
      entities[key] ?? ProfitEntity(key, key, 'Sin identidad'),
      [],
    ),
  );
  for (final group in grouped.entries) {
    final rows = group.value
      ..sort((a, b) {
        final date = b.date.compareTo(a.date);
        final reference = a.reference.compareTo(b.reference);
        return date != 0
            ? date
            : reference != 0
            ? reference
            : a.key.compareTo(b.key);
      });
    final entityKey = resolve(rows.first.entityKey, rows.first.date);
    final masterRecipes = rows
        .map((p) => master.recipe(entityKey, p.materialKey, p.date))
        .toList();
    final stableMaster =
        masterRecipes.isNotEmpty &&
            masterRecipes.first != null &&
            masterRecipes.every((r) => r?.id == masterRecipes.first!.id)
        ? masterRecipes.first
        : null;
    final recipe =
        review.recipes[group.key] ??
        (stableMaster == null
            ? null
            : ProfitRecipe.fromJson(stableMaster.data));
    final warnings = <String>[];
    double? value;
    if (rows.any(
      (p) =>
          (!p.kgUnit && !p.pieceUnit) ||
          p.quantity <= 0 ||
          p.payableQuantity < 0 ||
          p.amount < 0,
    )) {
      warnings.add('Unidad o peso de entrada pendiente de validar.');
    }
    if (recipe == null) {
      warnings.add('Define salida comercial y rendimiento recuperable.');
    }
    if (recipe != null && warnings.isEmpty) {
      var perKg = 0.0;
      for (final output in recipe.outputs) {
        final valuation = materialBasis.outputPrice(
          benchmarks,
          output.benchmark,
          unit: rows.first.unit,
        );
        if (valuation.price == null) {
          warnings.add(
            'No hay venta aprobada comparable en el corte para ${output.benchmark}.',
          );
        } else {
          perKg += output.yieldFraction * valuation.price!;
        }
      }
      if (warnings.isEmpty) {
        value = rows.fold<double>(0, (s, p) => s + p.quantity) * perKg;
      }
    }
    final result = ProfitMaterialResult(
      key: group.key,
      material: rows.first.material,
      entityKey: entityKey,
      purchases: rows,
      recipe: recipe,
      value: value,
      issues: warnings,
    );
    company(entityKey).materials.add(result);
    company(
      entityKey,
    ).issues.addAll(warnings.map((w) => '${result.material}: $w'));
  }

  // Possible cross-channel duplicate is evidence for review, not auto-deletion.
  final tickets = <String, List<ProfitPurchase>>{};
  for (final p in purchases) {
    if (p.reference.isEmpty) continue;
    (tickets['${profitDateText(p.date)}|${profitKey(p.reference)}'] ??= []).add(
      p,
    );
  }
  for (final rows in tickets.values) {
    if (rows.map((p) => p.source).toSet().length < 2) continue;
    for (final p in rows) {
      company(resolve(p.entityKey, p.date)).issues.add(
        'Ticket ${p.reference} aparece en dos canales; conciliar si corresponde al mismo material.',
      );
    }
  }
  final byDayVehicle = <String, List<ProfitRow>>{};
  for (final row in sources.rows('services')) {
    final date = row['due_date'] ?? row['service_date'];
    if (!within(date) ||
        row['status'] != 'completado' ||
        row['area'] != 'LOGISTICA') {
      continue;
    }
    final id = profitText(row['client_id']);
    if (id.isEmpty) {
      issues.add('Servicio completado sin empresa.');
      continue;
    }
    final c = company(resolve('site:$id', profitDate(date)));
    c.services++;
    final vehicle = profitText(row['vehicle_id']);
    if (vehicle.isEmpty) {
      c.issues.add('Servicio ${row['id']} sin unidad.');
      continue;
    }
    (byDayVehicle['${profitDateText(profitDate(date)!)}|$vehicle'] ??= []).add(
      row,
    );
  }
  for (final row in sources.rows('logistics_vehicle_mileage')) {
    if (!within(row['entry_date'])) continue;
    final trips =
        byDayVehicle['${row['entry_date']}|${row['vehicle_id']}'] ?? [];
    final keys = trips.map((r) => resolve('site:${r['client_id']}')).toSet();
    final km = profitNumber(row['kilometers']);
    if (keys.length == 1 && km != null && km >= 0) {
      final c = company(keys.single);
      c.attributedKm = (c.attributedKm ?? 0) + km;
    }
  }
  final costById = {for (final c in costs) c.key: c};
  if (costById.length != costs.length) {
    throw StateError('Comprobantes duplicados en las fuentes.');
  }
  final pending = <String, String>{};
  for (final fact in costs) {
    final rule = costRules[fact.key];
    if (fact.entityKey.isNotEmpty) company(resolve(fact.entityKey, fact.date));
    String? reason;
    if (rule == null || rule.treatment == ProfitCostTreatment.pending) {
      reason = 'Clasificar y conciliar el documento.';
    } else if (rule.sourceSignature != fact.signature) {
      reason = 'El origen cambió; revisar importe, periodo y reparto.';
    } else if (rule.treatment == ProfitCostTreatment.duplicate) {
      final target = costById[rule.duplicateOf];
      final targetRule = costRules[rule.duplicateOf];
      if (target == null ||
          target.key == fact.key ||
          targetRule?.treatment != ProfitCostTreatment.include ||
          targetRule!.sourceSignature != target.signature ||
          (target.payrollNet && targetRule.recognizedAmount == null) ||
          targetRule.shares.keys.any(
            (k) =>
                !entities.containsKey(k) || !entities.containsKey(resolve(k)),
          )) {
        reason = 'La evidencia debe vincularse a un costo reconocido vigente.';
      }
    } else if (rule.treatment == ProfitCostTreatment.include) {
      if (fact.payrollNet && rule.recognizedAmount == null) {
        reason =
            'Conciliar neto pagado a costo laboral, con importe explícito.';
      } else if (rule.shares.keys.any(
        (k) => !entities.containsKey(k) || !entities.containsKey(resolve(k)),
      )) {
        reason = 'El reparto tiene una empresa no disponible.';
      } else {
        final amount = rule.recognizedAmount ?? fact.amount;
        final shares = rule.shares.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final cents = (amount * 100).round();
        var remaining = cents;
        for (var i = 0; i < shares.length; i++) {
          final allocated = i == shares.length - 1
              ? remaining
              : (cents * shares[i].value).floor();
          remaining -= allocated;
          final c = company(resolve(shares[i].key, fact.date));
          c.costs.update(
            rule.kind,
            (v) => v + allocated / 100,
            ifAbsent: () => allocated / 100,
          );
          c.costIds.add(fact.key);
        }
      }
    }
    if (reason != null) pending[fact.key] = reason;
  }
  for (final key in costRules.keys) {
    if (!costById.containsKey(key)) {
      issues.add('El documento $key ya no aparece en las fuentes del corte.');
    }
  }
  final signature = profitDigest({
    'period': period.key,
    'master_revision': master.revision,
    'master_config': master.toJson(),
    'tables': sources.tables,
    'identities': review.identities,
    'recipes': {
      for (final e in review.recipes.entries) e.key: e.value.toJson(),
    },
    'costs': {for (final e in costRules.entries) e.key: e.value.toJson()},
    'excluded_purchases': review.excludedPurchases,
  });
  for (final c in companies.values) {
    final validation = review.companies[c.entity.key];
    c.reviewed =
        validation?.complete == true &&
        validation?.evidenceSignature == signature;
    if (!c.reviewed) {
      c.issues.add(
        'Revisión de identidad, costos y base de importes pendiente o desactualizada.',
      );
    }
    if (pending.isNotEmpty) {
      c.issues.add(
        '${pending.length} documentos del corte pendientes de asignar, excluir o conciliar.',
      );
    }
    if (issues.isNotEmpty) {
      c.issues.add(
        'El corte tiene ${issues.length} observaciones de fuentes por resolver.',
      );
    }
    if (c.materials.isEmpty) {
      c.issues.add(
        'Sin compra de material elegible en el corte; no inferir rentabilidad con actividad parcial.',
      );
    }
  }
  final sorted = companies.values.toList()
    ..sort((a, b) {
      final byName = a.entity.name.compareTo(b.entity.name);
      return byName != 0 ? byName : a.entity.key.compareTo(b.entity.key);
    });
  final sortedEntities = entities.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
  costs.sort((a, b) {
    final date = b.date.compareTo(a.date);
    final reference = a.label.compareTo(b.label);
    return date != 0
        ? date
        : reference != 0
        ? reference
        : a.key.compareTo(b.key);
  });
  final analysis = ProfitAnalysis(
    sources: sources,
    review: review,
    master: master,
    inferOperations: inferOperations,
    entities: sortedEntities,
    benchmarks: benchmarks,
    purchases: purchases,
    costFacts: costs,
    companies: sorted,
    pendingCosts: pending,
    issues: issues,
    excludedSales: excludedSales,
    excludedPurchases: excludedPurchases,
    evidenceSignature: signature,
  );
  populateProfitOperating(analysis, resolve);
  if (inferOperations) {
    populateProfitAccounts(analysis, resolve);
    // Scope is applied AFTER allocation; excluded activity retains its costs.
    final catalog = sources.rows('compras_counterparties');
    analysis.reportKeys = {
      for (final row in catalog) resolve('compras:${row['id']}', period.end),
    };
    final names = catalog.map((r) => profitOperationalName(r['name'])).toSet();
    for (final row in catalog) {
      final key = resolve('compras:${row['id']}', period.end);
      for (final company in analysis.companies.where(
        (c) => c.entity.key == key,
      )) {
        company.catalogName = profitText(row['name']);
      }
    }
    for (final c in analysis.companies) {
      final group = profitOperationalName(
        master.group(c.entity.key, period.end),
      );
      if (group.isNotEmpty && names.contains(group)) {
        analysis.reportKeys!.add(c.entity.key);
      }
      // The supplied MONROE document explicitly covers both plants, separately.
      if (names.contains('MONROE') &&
          profitOperationalName(c.entity.name) == 'MONROE SUR') {
        analysis.reportKeys!.add(c.entity.key);
      }
    }
  }
  return analysis;
}
