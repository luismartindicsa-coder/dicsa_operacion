import 'dart:math' as math;
import '../../hr/human_resources_compensation.dart';
import 'profitability_account_models.dart';
import 'profitability_material_basis.dart';
import 'profitability_material_units.dart';
import 'profitability_cost_basis.dart';
import 'profitability_payroll_allocation.dart';
import 'profitability_engine.dart'
    show analyzeProfitability, profitPayrollPeriod, profitPayrollNet;
import 'profitability_models.dart';
import 'profitability_parameters.dart';

String profitOperationalName(Object? raw) {
  var n = profitKey(
    raw,
  ).replaceAll('Ñ', 'N').replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
  n = n
      .replaceAll(RegExp(r'\bS A (DE C V|B DE C V)\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (n == 'SETEXMES') return 'SETEX'; // Dirección confirmó 22/09/2026.
  if (['BOCHS', 'DESPERDICIOS QUERETANA BOSCH'].contains(n)) return 'BOSCH';
  if (n == 'MONROE NORTE' || n == 'MONROE MEXICO') return 'MONROE';
  return n;
}

bool _internal(String name) => RegExp(
  r'^(DICSA\b|PATIO$|APASEO$|ADMINISTRACION$|LOGISTICA$|OPERACION$)',
).hasMatch(profitOperationalName(name));
Map<String, String> inferProfitIdentities(ProfitSources s) {
  final names = <String, List<String>>{};
  for (final spec in [
    ('sites', 'site'),
    ('compras_counterparties', 'compras'),
    ('men_counterparties', 'men'),
    ('mayoreo_counterparties', 'ventas'),
  ]) {
    for (final row in s.rows(spec.$1)) {
      final n = profitOperationalName(row['name']);
      if (n.isNotEmpty) (names[n] ??= []).add('${spec.$2}:${row['id']}');
    }
  }
  final result = <String, String>{};
  for (final entry in names.entries) {
    final sites = entry.value.where((k) => k.startsWith('site:')).toList();
    if (sites.length > 1) {
      continue; // An ambiguous name does not merge two plants.
    }
    final target = sites.firstOrNull ?? entry.value.first;
    for (final key in entry.value) {
      if (key != target) result[key] = target;
    }
    result['payroll:${profitKey(entry.key)}'] = target;
    result['expense:${profitKey(entry.key)}'] = target;
  }
  for (final table in [
    'sites',
    'compras_counterparties',
    'mayoreo_counterparties',
    'men_counterparties',
  ]) {
    for (final row in s.rows(table)) {
      final target = result['expense:${profitOperationalName(row['name'])}'];
      if (target != null) result['expense:${profitKey(row['name'])}'] = target;
    }
  }
  for (final row in [
    ...s.rows('hr_employee_profiles'),
    ...s.rows('hr_prenomina_draft_rows'),
  ]) {
    final label = profitText(row['empresa']), n = profitOperationalName(label);
    final target = result['payroll:$n'];
    if (target != null) result['payroll:${profitKey(label)}'] = target;
  }
  return result;
}

String profitMaterialFamily(String value) {
  final n = profitOperationalName(value);
  if (RegExp(r'\b(LENA|PEDACERIA MADERA)\b').hasMatch(n)) return 'LENA';
  if (RegExp(r'BASURA|\bRSU\b|RESIDUO SOLIDO').hasMatch(n)) return 'RSU';
  if (n.contains('CARTON') ||
      n == 'AMERICANO' ||
      n.contains('PACA NACIONAL') ||
      n.contains('PACA LIMPIA') ||
      n.contains('PACA AMERICANA')) {
    return n.contains('AMERICAN') ? 'CARTON AMERICANO' : 'CARTON';
  }
  for (final family in [
    'ACERO INOXIDABLE',
    'COBRE',
    'BRONCE',
    'ALUMINIO',
    'PET',
    'TARIMA',
  ]) {
    if (n.contains(family)) return family;
  }
  if (RegExp(
        r'CHATARRA|ACERO|REBABA|PLACA|FIERRO|PESADO|RETORNO INDUSTRIAL|TROQUEL|CINTA SIERRA|TUBO|MIXTO',
      ).hasMatch(n) &&
      !n.contains('PLASTICO')) {
    return 'CHATARRA';
  }
  if (RegExp(r'PAPEL|FOLLETO|BOND|CAPLE|ARCHIVO|MAGAZINE').hasMatch(n)) {
    return 'PAPEL';
  }
  if (RegExp(r'PLASTICO|PLAYO|POLIETILENO|GARRAFA|POLIESTIRENO').hasMatch(n)) {
    return 'PLASTICO';
  }
  return n;
}

class _AccountWork {
  final ProfitCompanyResult company;
  final Map<String, ProfitAccountLine> lines = {};
  final List<String> assumptions = [];
  final List<ProfitRow> trips = [];
  double km = 0, containers = 0;
  final Map<String, double> unitKm = {};
  final Map<String, double> unitDayKm = {};
  double movements = 0;
  _AccountWork(this.company);
  String get key => company.entity.key;
  ProfitAccountLine line(String key, [String? label]) => lines.putIfAbsent(
    key,
    () => ProfitAccountLine(
      key,
      label ??
          (key == 'Nómina compartida'
              ? profitAccountBlocks['administration']!
              : key),
    ),
  );
  double get kg => lines.values.fold(0, (s, l) => s + l.kg);
  double get services => trips.length.toDouble();
  double block(String b) => lines.values.fold(0, (s, l) => s + l.block(b));
  bool get monroe =>
      profitOperationalName(company.entity.name).startsWith('MONROE');
  bool get south => profitOperationalName(company.entity.name).contains('SUR');
}

/// One operational reading of the consolidated sources. Every applied fallback
/// has a numeric amount AND its explicit rule/reference; no pending cost gate.
/// The documentary analysis and historical snapshots remain available.
void populateProfitAccounts(
  ProfitAnalysis a,
  String Function(String, [DateTime?]) resolve,
) {
  final s = a.sources, p = s.period, master = a.master;
  final dayEnd = DateTime(s.readAt.year, s.readAt.month, s.readAt.day);
  final end = p.end.isAfter(dayEnd) ? dayEnd : p.end;
  if (end.isBefore(p.start)) return;
  final period = ProfitPeriod(p.start, end);
  final works = <String, _AccountWork>{};
  final nameIndex = {for (final e in a.entities) e.key: e.name};
  String named(String raw, DateTime day) {
    final normalized = profitOperationalName(raw);
    final candidates = a.entities
        .where((e) => profitOperationalName(e.name) == normalized)
        .toList();
    final sites = candidates.where((e) => e.key.startsWith('site:')).toList();
    if (sites.length == 1) return resolve(sites.single.key, day);
    if (sites.length > 1) return '';
    return candidates.isEmpty ? '' : resolve(candidates.first.key, day);
  }

  _AccountWork? ensure(String key) {
    if (key.isEmpty || _internal(nameIndex[key] ?? key)) return null;
    var c = a.companies.where((c) => c.entity.key == key).firstOrNull;
    if (c == null) {
      final e = a.entities.where((e) => e.key == key).firstOrNull;
      if (e == null) return null;
      c = ProfitCompanyResult(e, []);
      a.companies.add(c);
    }
    return works.putIfAbsent(key, () => _AccountWork(c!));
  }

  for (final c in a.companies.toList()) {
    if (c.materials.isNotEmpty || c.services > 0) ensure(c.entity.key);
  }
  for (final r in s.rows('hr_employee_profiles')) {
    if (_internal(profitText(r['empresa']))) continue;
    final entered = profitDate(r['fecha_ingreso']),
        left = profitDate(r['termination_date']);
    if (entered != null && entered.isAfter(end) ||
        left != null && left.isBefore(p.start)) {
      continue;
    }
    ensure(named(profitText(r['empresa']), end));
  }
  for (final fact in a.costFacts.where(
    (f) => f.payrollNet && !_internal(nameIndex[f.entityKey] ?? f.entityKey),
  )) {
    ensure(resolve(fact.entityKey, fact.date));
  }
  for (final r in s.rows('services')) {
    final day = profitDate(r['due_date'] ?? r['service_date']);
    if (day == null ||
        !period.contains(day) ||
        r['status'] != 'completado' ||
        r['area'] != 'LOGISTICA') {
      continue;
    }
    final key = profitText(r['client_id']).isEmpty
        ? named(profitText(r['client_name']), day)
        : resolve('site:${r['client_id']}', day);
    final w = ensure(key);
    if (w == null) continue;
    w.trips.add(r);
    final raw = profitText(r['material_type']);
    final line = w.line(
      profitMaterialFamily(raw.isEmpty ? 'Materiales varios' : raw),
    );
    line.services++;
  }
  for (final fact in a.costFacts) {
    if (fact.entityKey.isNotEmpty) ensure(resolve(fact.entityKey, fact.date));
  }
  final saleCatalog = {
    for (final r in s.rows('mayoreo_material_catalog')) profitText(r['id']): r,
  };
  bool serviceSale(ProfitRow row) {
    final unit = profitKey(
      saleCatalog[profitText(row['material_id'])]?['unit'],
    );
    return RegExp(
          r'SERVICIO|RECOLECCION|FLETE|PESADA',
        ).hasMatch(profitKey(row['material_name_snapshot'])) ||
        ['SERVICIO', 'VIAJE'].contains(unit);
  }

  String saleCompany(ProfitRow row, DateTime day) =>
      profitText(row['client_id']).isEmpty
      ? named(profitText(row['client_name_snapshot']), day)
      : resolve('ventas:${row['client_id']}', day);
  for (final row in s.rows('mayoreo_sales_reports')) {
    final day = profitDate(row['sale_date']);
    if (day != null && period.contains(day) && serviceSale(row)) {
      ensure(saleCompany(row, day));
    }
  }
  for (final rule in master.rules.where(
    (r) =>
        r.kind == ProfitParameterKind.account &&
        !r.from.isAfter(end) &&
        !(r.to?.isBefore(period.start) ?? false),
  )) {
    ensure(resolve(rule.company, rule.from));
  }
  final materialBasis = ProfitMaterialBasis(s, profitMaterialFamily);
  final physical = profitPhysicalBasis(
    a,
    materialBasis,
    (key, day) => resolve(key, day),
    named,
  );
  final accountPurchases = [...a.purchases, ...physical.additional];
  for (final purchase in accountPurchases) {
    ensure(
      physical.purchaseCompanies[purchase.key] ??
          resolve(purchase.entityKey, purchase.date),
    );
  }
  const ref =
      'Análisis manual MONROE · enero–abril 2025 · documento 06/01/2026';
  void add(
    _AccountWork w,
    String line,
    String block,
    double amount,
    String rule,
    String reference, {
    ProfitSourceType type = ProfitSourceType.estimated,
    DateTime? date,
    String level = 'inference',
    String? id,
    bool sharedSupport = false,
  }) {
    if (!amount.isFinite || amount < 0) {
      throw StateError('Importe operativo inválido en $block.');
    }
    w
        .line(line)
        .components
        .add(
          ProfitComponent(
            id:
                id ??
                'op:${w.key}:$line:$block:${w.line(line).components.length}',
            block: block,
            date: date ?? end,
            amount: amount,
            sourceType: type,
            reference: reference,
            rule: rule,
            confidence: type == ProfitSourceType.actual
                ? 1.0
                : type == ProfitSourceType.allocated
                ? 0.85
                : level == 'zero_basis'
                ? 0.2
                : level == 'neutral_value'
                ? 0.35
                : 0.6,
            line: line,
            basisLevel: level,
            sharedSupport: sharedSupport,
          ),
        );
  }

  String costLine(String block) => switch (block) {
    'payroll' => 'Personal dedicado',
    'administration' => 'Gastos administrativos distribuidos',
    'containers' => 'Contenedores',
    'training' => 'Capacitaciones',
    'overhead' => 'Estructura',
    _ => 'Costos de la cuenta',
  };
  final purchaseLines = <String, ({String company, String line})>{};
  for (final purchase in accountPurchases) {
    final company =
        physical.purchaseCompanies[purchase.key] ??
        resolve(purchase.entityKey, purchase.date);
    final w = works[company];
    if (w == null) continue;
    final line = materialBasis.family(purchase.material, purchase.materialKey);
    if (purchase.kgUnit) w.line(line).kg += purchase.physicalKg;
    if (purchase.pieceUnit) {
      w.line(line).pieces += purchase.pieces;
      const note =
          'Tarimas de MONROE por pieza, confirmado por Dirección el 29/09/2026. Las piezas no se suman como kilos ni se convierten a toneladas para repartir gastos.';
      if (!w.assumptions.contains(note)) w.assumptions.add(note);
    }
    purchaseLines[purchase.key] = (company: company, line: line);
    final note = physical.notes[purchase.key];
    if (note != null && !w.assumptions.contains(note)) w.assumptions.add(note);
  }
  for (final w in works.values) {
    // Service weight is only a fallback when neither intake nor purchases exist.
    for (final l in w.lines.values) {
      if (l.kg > 0) continue;
      final rows = w.trips.where(
        (r) => profitMaterialFamily(profitText(r['material_type'])) == l.key,
      );
      l.kg = rows.fold(
        0,
        (v, r) => v + math.max(0, profitNumber(r['weight_kg']) ?? 0),
      );
      if (l.kg == 0 && l.key == 'RSU' && l.services > 0 && w.monroe) {
        l.kg = l.services * (112380 / 85);
        w.assumptions.add(
          'RSU: peso estimado con 112,380 kg / 85 servicios del análisis MONROE; sustituir por peso registrado cuando exista.',
        );
      }
    }
    for (final component
        in w.company.operating?.components ?? <ProfitComponent>[]) {
      if (component.amount == null) continue;
      final purchase = purchaseLines.entries
          .where((e) => component.id.startsWith('${e.key}:'))
          .firstOrNull;
      final target = purchase == null ? w : works[purchase.value.company]!;
      final line =
          purchase?.value.line ??
          (component.block == 'income'
              ? 'Otros servicios'
              : costLine(component.block));
      add(
        target,
        line,
        component.block,
        component.amount!,
        component.rule,
        component.reference,
        type: component.sourceType,
        date: component.date,
        level: component.sourceType == ProfitSourceType.estimated
            ? 'standard'
            : 'source',
        id: component.id,
        sharedSupport: component.sharedSupport,
      );
    }
  }
  for (final purchase in accountPurchases) {
    final allocation = purchaseLines[purchase.key];
    if (allocation == null) continue;
    final w = works[allocation.company]!, line = allocation.line;
    final intake = purchase.key.startsWith('intake:');
    if (!w
        .line(line)
        .components
        .any((v) => v.id == '${purchase.key}:purchase')) {
      final peers = a.purchases
          .where(
            (v) =>
                v.materialKey == purchase.materialKey &&
                v.amountKnown &&
                v.payableKg > 0,
          )
          .toList();
      final kg = peers.fold<double>(0, (t, v) => t + v.payableKg),
          money = peers.fold<double>(0, (t, v) => t + v.amount);
      add(
        w,
        line,
        'purchase',
        purchase.amountKnown
            ? purchase.amount
            : kg > 0
            ? purchase.payableKg * money / kg
            : 0,
        intake
            ? physical.notes[purchase.key]!
            : 'Kg pagables × compra ponderada del mismo material; sin precio registrado se aplica la base disponible.',
        intake
            ? purchase.key
            : 'Compras · ${peers.map((v) => v.key).join(',')}',
        date: purchase.date,
        id: '${purchase.key}:purchase',
        level: intake
            ? purchase.amountKnown
                  ? 'intake_estimate'
                  : 'zero_basis'
            : kg > 0
            ? 'inference'
            : 'zero_basis',
      );
    }
    if ((!purchase.kgUnit && !purchase.pieceUnit) ||
        w.line(line).components.any((v) => v.id == '${purchase.key}:value')) {
      continue;
    }
    final valuation = materialBasis.purchasePrice(a, purchase);
    final candidates = valuation.benchmarks;
    if (valuation.inferenceNote.isNotEmpty &&
        !w.assumptions.contains(valuation.inferenceNote)) {
      w.assumptions.add(valuation.inferenceNote);
    }
    if (valuation.unitWarning.isNotEmpty &&
        !w.assumptions.contains(valuation.unitWarning)) {
      w.assumptions.add(valuation.unitWarning);
    }
    final quantity = valuation.quantity, price = valuation.price ?? 0;
    final exact =
        candidates.isNotEmpty &&
        candidates.every(
          (b) =>
              materialBasis.saleName(b.material) ==
              materialBasis.saleName(purchase.material),
        );
    final zero = ['LENA', 'RSU'].contains(line);
    final fallbackPurchase = w
        .line(line)
        .components
        .where((v) => v.id == '${purchase.key}:purchase')
        .fold<double>(0, (t, v) => t + v.amount!);
    final value = quantity > 0
        ? purchase.quantity * price
        : zero
        ? 0.0
        : fallbackPurchase;
    add(
      w,
      line,
      'value',
      value,
      quantity > 0
          ? '${purchase.quantity} ${profitUnitLabel(purchase.unit)} × ${price.toStringAsFixed(4)}/${profitUnitLabel(purchase.unit)} de ${exact ? 'venta comparable por nombre/calidad' : 'promedio ponderado de ventas de la familia $line (mezcla estimada)'}. ${valuation.description}. ${valuation.inferenceNote}${line == 'CARTON AMERICANO' ? ' Equivalencia cartón americano → Cartón Celanese confirmada por Dirección el 22/09/2026.' : ''} Recuperación operativa 100% como base sin merma capturada; ajustable.'
          : zero
          ? 'Valor recuperable cero para ${line == 'LENA' ? 'leña sin salida comercial' : 'residuos destinados a disposición'}.'
          : 'Sin venta comparable: valor de referencia igual a la compra, margen comercial base cero antes de atender la cuenta. ${valuation.unitWarning}'
                .trim(),
      quantity > 0
          ? 'Ventas · ${valuation.reference}${intake ? ' · ${purchase.key}' : ''}'
          : zero
          ? ref
          : purchase.key,
      date: purchase.date,
      id: '${purchase.key}:value',
      level: quantity > 0
          ? valuation.inferenceNote.isNotEmpty
                ? 'material_equivalence_estimate'
                : intake
                ? 'intake_estimate'
                : 'inference'
          : zero
          ? 'document_reference'
          : 'neutral_value',
    );
  }
  // Explicit concepts supersede automatic costs on their effective dates.
  for (
    var d = period.start;
    !d.isAfter(end);
    d = d.add(const Duration(days: 1))
  ) {
    for (final rule in master.at(ProfitParameterKind.account, d)) {
      final w = ensure(resolve(rule.company, d));
      if (w == null) continue;
      final block = rule.text('block'),
          line = rule.text('line'),
          rate = rule.number('rate')!,
          quantity = rule.number('quantity')!;
      final dailyServices = w.trips
          .where(
            (t) =>
                profitDate(t['due_date'] ?? t['service_date']) == d &&
                (profitMaterialFamily(profitText(t['material_type'])) == line ||
                    line == 'Toda la cuenta'),
          )
          .length;
      final dailyKg = accountPurchases
          .where(
            (t) =>
                purchaseLines[t.key]?.company == w.key &&
                (purchaseLines[t.key]?.line == line ||
                    line == 'Toda la cuenta'),
          )
          .where((t) => t.date == d)
          .fold<double>(0, (v, t) => v + t.physicalKg);
      final factor = switch (rule.text('basis')) {
        'monthly' => 1 / DateTime(d.year, d.month + 1, 0).day,
        'annual' => 1 / (12 * DateTime(d.year, d.month + 1, 0).day),
        'service' => dailyServices.toDouble(),
        'kg' => dailyKg,
        'tonne' => dailyKg / 1000,
        _ => d == rule.from ? 1.0 : 0.0,
      };
      // A confirmed source retains priority. Overrides replace estimated defaults.
      final existing = w.lines.values
          .expand((l) => l.components)
          .where(
            (v) =>
                v.block == block &&
                v.date == d &&
                (line == 'Toda la cuenta' || v.line == line),
          )
          .toList();
      if (existing.any(
        (v) =>
            v.sourceType == ProfitSourceType.actual ||
            v.sourceType == ProfitSourceType.allocated,
      )) {
        continue;
      }
      for (final l in w.lines.values) {
        l.components.removeWhere((v) => existing.contains(v));
      }
      add(
        w,
        line,
        block,
        rate * quantity * factor,
        '${rule.text('basis')}: $quantity × $rate × $factor. ${rule.note}',
        'Parámetro ${rule.id}',
        date: d,
        level: 'parameter',
      );
    }
  }
  bool fixed(_AccountWork w, String block, DateTime date) => w.lines.values
      .expand((l) => l.components)
      .any(
        (v) =>
            v.block == block && v.date == date && v.basisLevel == 'parameter',
      );

  // Transport activity: measured unit/day km split by services; remaining
  // service-days use the observed km/service of the same fleet, then the manual
  // route reference. Missing a mileage sheet never makes the trip free.
  final tripsByUnitDay = <String, List<({String key, ProfitRow row})>>{};
  for (final w in works.values) {
    for (final t in w.trips) {
      final d = profitDate(t['due_date'] ?? t['service_date'])!;
      (tripsByUnitDay['${profitDateText(d)}|${t['vehicle_id']}'] ??= []).add((
        key: w.key,
        row: t,
      ));
    }
  }
  final measured = <String, double>{};
  for (final r in s.rows('logistics_vehicle_mileage')) {
    final d = profitDate(r['entry_date']), km = profitNumber(r['kilometers']);
    if (d == null || !period.contains(d) || km == null || km < 0) continue;
    final key = '${profitDateText(d)}|${r['vehicle_id']}';
    measured[key] = (measured[key] ?? 0) + km;
  }
  var observedKm = 0.0, observedServices = 0;
  for (final e in tripsByUnitDay.entries) {
    if (measured.containsKey(e.key)) {
      observedKm += measured[e.key]!;
      observedServices += e.value.length;
    }
  }
  final avgKm = observedServices > 0 ? observedKm / observedServices : 31.6;
  for (final e in tripsByUnitDay.entries) {
    for (final t in e.value) {
      final w = works[t.key]!;
      final km = measured.containsKey(e.key)
          ? measured[e.key]! / e.value.length
          : w.monroe
          ? (w.south ? 49.8 : 31.6)
          : avgKm;
      w.km += km;
      final unit = profitText(t.row['vehicle_id']);
      w.unitKm.update(unit, (v) => v + km, ifAbsent: () => km);
      w.unitDayKm.update(e.key, (v) => v + km, ifAbsent: () => km);
      if (!measured.containsKey(e.key)) {
        w.assumptions.add(
          'Km sin registro: servicios × ${km.toStringAsFixed(2)} km (${w.monroe
              ? 'ruta del documento MONROE'
              : observedServices > 0
              ? 'promedio medido de la flota'
              : 'ruta de referencia MONROE'}).',
        );
      }
    }
  }
  final profileBySite = {
    for (final r in s.rows('logistics_company_profiles'))
      'site:${r['site_id']}': r,
  };
  for (final w in works.values) {
    final profile = profileBySite[w.key];
    w.containers = profitNumber(profile?['container_count']) ?? 0;
    if (w.monroe && w.containers == 0) {
      w.containers = w.south ? 3 : 5;
      w.assumptions.add(
        'Contenedores: cantidad del análisis MONROE; el perfil logístico aún no tiene unidades registradas.',
      );
    }
  }
  // Use the existing parser for historical financial references. This does not
  // add past transactions to this period: only the daily average is projected.
  final historyPeriod = ProfitPeriod(
    p.start.subtract(const Duration(days: 90)),
    p.start.subtract(const Duration(days: 1)),
  );
  final history = analyzeProfitability(
    ProfitSources(
      period: historyPeriod,
      readAt: s.readAt,
      tables: {...s.tables, 'profit_shared_cost_reviews': []},
    ),
    const ProfitReview(),
    master: const ProfitMaster(),
  );
  final bankRows = {
    for (final r in s.rows('finanzas_bank_movements')) 'bank:${r['id']}': r,
  };
  final costBasis = ProfitCostBasis(s);
  void retainCost(
    String id,
    String block,
    double amount,
    String reason, {
    DateTime? date,
  }) {
    if (amount <= 0) return;
    a.unassignedCosts.add({
      'id': id,
      'block': block,
      'amount': amount,
      'date': profitDateText(date ?? end),
      'reason': reason,
    });
  }

  final invoiceRows = {
    for (final r in s.rows('finanzas_supplier_invoices'))
      profitText(r['id']): r,
  };
  String factLabel(ProfitCostFact f) {
    final bank = bankRows[f.key];
    final invoice = f.key.startsWith('invoice:')
        ? invoiceRows[f.key.substring(8)]
        : invoiceRows[profitText(bank?['linked_supplier_invoice_id'])];
    return profitOperationalName(
      '${f.label} ${profitText(bank?['comment'])} ${profitText(invoice?['notes'])} ${profitText(invoice?['provider_name_snapshot'])}',
    );
  }

  String category(ProfitCostFact f) {
    final n = factLabel(f);
    if (RegExp(r'IMSS|INFONAVIT|IMPUEST.*NOMINA|ISN').hasMatch(n)) {
      return 'administration';
    }
    if (RegExp(r'NOMINA|SUELDO|SALARIO').hasMatch(n)) return 'payroll';
    if (RegExp(r'DIESEL|GASOLINA|COMBUSTIBLE|GASOLINERA').hasMatch(n)) {
      return 'fuel';
    }
    if (RegExp(r'BASCULA|PESADA').hasMatch(n)) return 'scale';
    if (RegExp(r'RELLENO|BASURERO|DISPOSICION').hasMatch(n)) return 'disposal';
    if (RegExp(r'CAPACITACION|CURSO').hasMatch(n)) return 'training';
    if (RegExp(r'CONTENEDOR|RENTA.*EQUIPO').hasMatch(n)) return 'containers';
    if (RegExp(r'ADMINISTR|HONORARIOS|CONTADOR|OFICINA').hasMatch(n)) {
      return 'administration';
    }
    if (RegExp(
      r'LUZ|ELECTRIC|\bCFE\b|COMPACT|PROCESO|MANIOBRA|CLASIFICACION',
    ).hasMatch(n)) {
      return 'process';
    }
    return f.suggestedKind.name;
  }

  final alreadyRecognized = <ProfitCostFact>[];
  final recognizedAmounts = <String, double>{};
  List<ProfitCostFact> canonical(
    List<ProfitCostFact> facts,
    ProfitSources sources,
  ) {
    final selected = <ProfitCostFact>[];
    final banks = {
      for (final r in sources.rows('finanzas_bank_movements'))
        'bank:${r['id']}': r,
    };
    final poOt = {
      for (final r in sources.rows('maintenance_purchase_orders'))
        'po:${r['id']}': profitText(r['linked_ot_id']),
    };
    final ids = facts.map((f) => f.key).toSet();
    void nonOperating(ProfitCostFact f, String reason) {
      if (!period.contains(f.date)) return;
      if (a.nonOperatingFlows.any((r) => r['id'] == f.key)) return;
      a.nonOperatingFlows.add({
        'id': f.key,
        'date': profitDateText(f.date),
        'amount': f.amount,
        'label': factLabel(f),
        'reason': reason,
        'signature': f.signature,
      });
    }

    for (final f in facts) {
      final bank = banks[f.key];
      // Dirección confirmed on 22/09/2026 that the self-cheques labelled
      // "CHEQUE DICSA / PAGO EN EFECTIVO" (0007667 and 0007668) fund
      // payroll/cash. Recognize the narrow bank pattern, not all cash payments.
      if (bank != null &&
          profitOperationalName(bank['counterparty_name_snapshot']) ==
              'CHEQUE DICSA' &&
          profitOperationalName(bank['comment']) == 'PAGO EN EFECTIVO') {
        nonOperating(
          f,
          'Retiro de cheque DICSA para fondear nómina/caja; el gasto se reconoce en RH o en su comprobante, no de nuevo al retirar efectivo.',
        );
        continue;
      }
      if (RegExp(
        r'PAGO TARJETA DE CREDITO|TRANSFERENCIA ENTRE CUENTAS|DEPOSITO|RETIRO DE EFECTIVO|REPOSICION DE FONDO|ABONO TC',
      ).hasMatch(factLabel(f))) {
        nonOperating(
          f,
          'Movimiento de tesorería; no consumo operativo adicional.',
        );
        continue;
      }
      if (f.payrollNet || category(f) == 'payroll') {
        continue; // RH is the single payroll source.
      }
      // This specific remittance was confirmed as employee withholding.
      // Do not extend the exclusion to other FONACOT fees or mixed invoices.
      if (f.key == 'bank:fin-bank-mov-1788294629527877' &&
          profitOperationalName(bank?['counterparty_name_snapshot']) ==
              'FONACOT' &&
          profitDateText(f.date) == '2026-09-01' &&
          (f.amount - 3613.76).abs() < .005) {
        if (period.contains(f.date)) {
          a.payrollWithholdingSettlements.add({
            'id': f.key,
            'date': profitDateText(f.date),
            'amount': f.amount,
            'label': factLabel(f),
            'signature': f.signature,
            'reason':
                'Entrega de descuentos de trabajadores, confirmado por Dirección el 22/09/2026. Es una liquidación de retenciones, no un gasto adicional ni una carga patronal.',
          });
        }
        continue;
      }
      // Invoice consumption remains whole even when settled in installments.
      // A payment is evidence of settlement, never a second consumption.
      final linkedInvoice = costBasis.invoice(f.key);
      if (bank != null &&
          linkedInvoice != null &&
          linkedInvoice['origin_type'] == 'MANUAL' &&
          !profitKey(linkedInvoice['status']).contains('CANCEL') &&
          (profitNumber(linkedInvoice['total_amount']) ?? 0) > 0) {
        continue;
      }
      // Dirección confirmed these material invoices are already represented
      // in purchase tickets, sometimes under another name (22/09/2026).
      // Keep that reconciliation visible without changing ticket valuation.
      final supplier = profitOperationalName(
        linkedInvoice?['provider_name_snapshot'] ??
            bank?['counterparty_name_snapshot'],
      );
      if (['MAURICIO ALCALA', 'MONICA CHAVEZ'].contains(supplier)) {
        if (period.contains(f.date)) {
          a.coveredMaterialPurchases.add({
            'id': f.key,
            'date': profitDateText(f.date),
            'amount': f.amount,
            'label': factLabel(f),
            'signature': f.signature,
            'reason':
                'Compra de material ya incluida en tickets de Compras/Menudeo, confirmado por Dirección el 22/09/2026. No se suma como otro gasto; confirmación operativa, sin enlace individual de factura a ticket.',
          });
        }
        continue;
      }
      // The invoice concept conflicts with the operational clarification.
      // Keep the amount in the global reconciliation, not in an arbitrary
      // customer allocation or in recurring historical estimates.
      final reviewed = a.effectiveCostRules[f.key];
      final hasReviewedTreatment =
          reviewed != null &&
          reviewed.treatment != ProfitCostTreatment.pending &&
          reviewed.sourceSignature == f.signature &&
          !a.pendingCosts.containsKey(f.key);
      if (supplier == 'MARICRUZ QUIROGA ACOSTA' && !hasReviewedTreatment) {
        if (period.contains(f.date)) {
          retainCost(
            f.key,
            'classification_pending',
            f.amount,
            'Maricruz Quiroga Acosta: concepto pendiente de conciliar. Finanzas lo identifica como compra de material; falta precisar el concepto y si está cubierto por tickets. Importe conservado provisionalmente en el resultado global, sin repartir entre empresas.',
            date: f.date,
          );
        }
        continue;
      }
      if (f.key.startsWith('po:') && ids.contains('ot:${poOt[f.key]}')) {
        continue;
      }
      if (costBasis.inventoryPurchase(f.key)) {
        if (period.contains(f.date)) {
          retainCost(
            f.key,
            'inventory',
            f.amount,
            'Compra para almacén sin OT de consumo vinculada; inventario pendiente de atribuir, no mantenimiento consumido.',
            date: f.date,
          );
        }
        continue;
      }
      if (bank != null &&
          profitText(bank['linked_external_ref']).isNotEmpty &&
          ids.any((id) => id.endsWith(':${bank['linked_external_ref']}'))) {
        continue;
      }
      final rule = a.effectiveCostRules[f.key];
      if (rule != null &&
          rule.treatment != ProfitCostTreatment.pending &&
          rule.sourceSignature == f.signature) {
        if (rule.treatment == ProfitCostTreatment.include &&
            !a.pendingCosts.containsKey(f.key)) {
          alreadyRecognized.add(f);
          recognizedAmounts[f.key] = rule.recognizedAmount ?? f.amount;
        }
        continue;
      }
      if (f.key.startsWith('ot:') &&
          works.values.any(
            (w) => w.lines.values
                .expand((l) => l.components)
                .any((v) => v.id == f.key),
          )) {
        alreadyRecognized.add(f);
        continue;
      }
      if (RegExp(
        r'GASTOS? FINANCIEROS?|PRESTAMO.*COBRO AUT',
      ).hasMatch(factLabel(f))) {
        nonOperating(
          f,
          'Financiamiento fuera del aporte operativo; el pago no distingue capital e intereses.',
        );
        continue;
      }
      if (RegExp(r'\bPERSONALES\b').hasMatch(factLabel(f))) {
        nonOperating(
          f,
          'Gasto clasificado como personal; fuera del costo de atender empresas.',
        );
        continue;
      }
      selected.add(f);
    }
    return selected;
  }

  final allFacts = canonical(
    {
      for (final f in [...history.costFacts, ...a.costFacts]) f.key: f,
    }.values.toList(),
    s,
  );
  final coverageCache = <String, ProfitPeriod>{};
  ProfitPeriod coverage(ProfitCostFact f) => coverageCache.putIfAbsent(
    f.key,
    () => costBasis.coverage(f.key, f.date, factLabel(f)),
  );
  final recurrenceCache = <String, String>{};
  String recurrenceKey(ProfitCostFact f, String block) => recurrenceCache
      .putIfAbsent('$block|${f.key}', () => costBasis.recurrence(f, block));
  bool overlaps(ProfitPeriod one, ProfitPeriod two) =>
      !one.end.isBefore(two.start) && !one.start.isAfter(two.end);
  final currentFacts = allFacts
          .where((f) => overlaps(coverage(f), period))
          .toList(),
      pastFacts = allFacts
          .where(
            (f) =>
                coverage(f).end.isBefore(period.start) &&
                overlaps(coverage(f), historyPeriod),
          )
          .toList();
  final pendingPools = <String, List<ProfitCostFact>>{},
      pastPools = <String, List<ProfitCostFact>>{};
  for (final f in currentFacts) {
    (pendingPools[category(f)] ??= []).add(f);
  }
  for (final f in pastFacts) {
    (pastPools[category(f)] ??= []).add(f);
  }
  // Count physical movements once per account/day: source documents may
  // describe the same activity. Without a link, the maximum count is a proxy.
  final movementCounts = <String, Map<String, int>>{};
  void movement(String company, DateTime day, String source) {
    final key = '$company|${profitDateText(day)}';
    final counts = movementCounts.putIfAbsent(key, () => {});
    counts.update(source, (v) => v + 1, ifAbsent: () => 1);
  }

  for (final purchase in accountPurchases) {
    final company = purchaseLines[purchase.key]?.company;
    if (company != null) movement(company, purchase.date, 'intake');
  }
  for (final w in works.values) {
    for (final trip in w.trips) {
      movement(
        w.key,
        profitDate(trip['due_date'] ?? trip['service_date'])!,
        'trip',
      );
    }
  }
  for (final row in s.rows('mayoreo_sales_reports')) {
    final date = profitDate(row['sale_date']);
    if (date != null && period.contains(date) && serviceSale(row)) {
      movement(saleCompany(row, date), date, 'service-sale');
    }
  }
  for (final entry in movementCounts.entries) {
    final key = entry.key.substring(0, entry.key.lastIndexOf('|'));
    works[key]?.movements += entry.value.values.reduce(math.max);
  }
  final activity = [
    for (final w in works.values)
      ProfitPayrollActivity(
        w.key,
        kg: w.kg,
        movements: w.movements,
        trips: w.services,
        kilometers: w.km,
      ),
  ];
  final transportShares = profitPayrollShares(activity, drivers: true);
  final supportShares = profitPayrollShares(activity, drivers: false);
  // Consistent allocation: by km for fuel/maintenance, services for collection,
  // kg for processing/disposal, equipment for rentals, equal accounts for support.
  double weight(_AccountWork w, String b) => switch (b) {
    'fuel' || 'maintenance' => w.km,
    'transport' || 'scale' => w.services,
    'process' => w.kg,
    'disposal' => w.lines['RSU']?.kg ?? 0,
    'containers' => w.containers,
    'administration' => w.movements,
    'training' =>
      w.block('payroll') +
          w.lines.values
              .expand((l) => l.components)
              .where(
                (v) => [
                  'payroll_period',
                  'salary_reference',
                ].contains(v.basisLevel),
              )
              .fold<double>(0, (t, v) => t + v.amount!),
    _ => supportShares[w.key]?.share ?? 0,
  };
  void distribute(
    _AccountWork w,
    String block,
    double amount,
    String formula,
    String references, {
    DateTime? date,
    ProfitSourceType type = ProfitSourceType.estimated,
    String level = 'inference',
    bool sharedSupport = false,
    String? accountLine,
  }) {
    if ([
      'payroll',
      'administration',
      'containers',
      'training',
      'overhead',
    ].contains(block)) {
      add(
        w,
        accountLine ?? costLine(block),
        block,
        amount,
        formula,
        references,
        type: type,
        date: date,
        level: level,
        sharedSupport: sharedSupport,
      );
      return;
    }
    final eligible = w.lines.values
        .where((l) => l.kg > 0 || l.services > 0)
        .toList();
    if (block == 'disposal') {
      add(
        w,
        'RSU',
        block,
        amount,
        formula,
        references,
        type: type,
        date: date,
        level: level,
        sharedSupport: sharedSupport,
      );
      return;
    }
    double lineWeight(ProfitAccountLine l) =>
        ['fuel', 'transport', 'maintenance', 'scale'].contains(block) &&
            eligible.any((l) => l.services > 0)
        ? l.services
        : l.kg;
    final denominator = eligible.fold<double>(0, (t, l) => t + lineWeight(l));
    if (eligible.isEmpty || denominator <= 0) {
      add(
        w,
        costLine(block),
        block,
        amount,
        formula,
        references,
        type: type,
        date: date,
        level: level,
        sharedSupport: sharedSupport,
      );
      return;
    }
    for (final l in eligible) {
      final fraction = lineWeight(l) / denominator;
      add(
        w,
        l.key,
        block,
        amount * fraction,
        '$formula · línea ${l.label}: ${lineWeight(l)} / $denominator.',
        references,
        type: type,
        date: date,
        level: level,
        sharedSupport: sharedSupport,
      );
    }
  }

  // Dispatch / load liters are the operational proxy for fuel use. Purchases
  // replenish inventory and only inform price; they are not charged a second time.
  final fuelLoads =
      <({String unit, DateTime date, double liters, String ref})>[];
  final coveredFuelDays = <String>{};
  for (final table in [
    'logistics_diesel_consumption',
    'logistics_gasoline_control',
  ]) {
    for (final row in s.rows(table)) {
      if (!period.contains(row['entry_date'])) continue;
      final liters =
          profitNumber(
            row[table == 'logistics_diesel_consumption'
                ? 'liters_requested'
                : 'liters_loaded'],
          ) ??
          0;
      if (liters > 0) {
        fuelLoads.add((
          unit: profitText(row['vehicle_id']),
          date: profitDate(row['entry_date'])!,
          liters: liters,
          ref: '$table:${row['id']}',
        ));
      }
    }
  }
  if (fuelLoads.isNotEmpty) {
    final purchasesLiters = s
        .rows('logistics_diesel_consumption')
        .where((r) => period.contains(r['entry_date']))
        .fold<double>(
          0,
          (v, r) => v + (profitNumber(r['liters_purchased']) ?? 0),
        );
    final fuelMoney = (pendingPools['fuel'] ?? []).fold<double>(
      0,
      (v, r) => v + r.amount,
    );
    final observedPrice = purchasesLiters > 0
        ? fuelMoney / purchasesLiters
        : 0.0;
    // Unlinked documents must not turn an incomplete payment into a near-zero
    // unit price. The documented rate bounds this sanity check, not a live quote.
    final hasPrice = observedPrice >= 23.67 / 2 && observedPrice <= 23.67 * 2;
    final price = hasPrice ? observedPrice : 23.67;
    for (final load in fuelLoads) {
      final unitDay = '${profitDateText(load.date)}|${load.unit}';
      final sameDay = works.values
          .where((w) => (w.unitDayKm[unitDay] ?? 0) > 0)
          .toList();
      final sameUnit = works.values
          .where((w) => load.unit.isNotEmpty && (w.unitKm[load.unit] ?? 0) > 0)
          .toList();
      final eligible = sameDay.isNotEmpty ? sameDay : sameUnit;
      double basis(_AccountWork w) => sameDay.isNotEmpty
          ? w.unitDayKm[unitDay] ?? 0
          : w.unitKm[load.unit] ?? 0;
      final total = eligible.fold<double>(0, (t, w) => t + basis(w));
      if (total <= 0) {
        retainCost(
          load.ref,
          'fuel',
          load.liters * price,
          'Carga sin servicio atribuible de la misma unidad; capacidad o consumo interno pendiente de vincular.',
          date: load.date,
        );
        continue;
      }
      for (final w in eligible) {
        final fraction = basis(w) / total;
        if (fixed(w, 'fuel', load.date)) continue;
        final source = w.lines.values
            .expand((l) => l.components)
            .any(
              (v) =>
                  v.block == 'fuel' &&
                  v.date == load.date &&
                  v.basisLevel == 'source',
            );
        if (source) continue;
        distribute(
          w,
          'fuel',
          load.liters * price * fraction,
          '${load.liters} litros × ${price.toStringAsFixed(4)}/L × ${(fraction * 100).toStringAsFixed(4)}% de km de la MISMA unidad '
              '${sameDay.isNotEmpty ? 'y día' : 'en el corte (sin ruta del día; referencia temporal)'}; nunca incluye km de otros vehículos.',
          '${load.ref} · ${hasPrice ? 'Precio inferido Finanzas/Logística' : ref}',
          date: load.date,
          level: 'fuel_dispatch',
        );
        for (final key in w.unitDayKm.keys.where(
          (k) => k.endsWith('|${load.unit}'),
        )) {
          if (sameDay.isEmpty || key == unitDay) {
            coveredFuelDays.add('${w.key}|$key');
          }
        }
      }
    }
  }
  // Closed payroll is used by day; uncovered days use weekly pay / 7.
  // Roles arrive inferred from a transient catalog match; no names are retained.
  final profilesById = {
    for (final r in s.rows('hr_employee_profiles')) profitText(r['id']): r,
  };
  String role(ProfitRow? r) =>
      r?['profit_payroll_role'] == 'driver' ? 'driver' : 'unclassified';
  String group(String name, String role) => '$name|$role';
  final payrollByDayCompany = <String, ({double amount, List<String> refs})>{};
  final publishedCompanyDays = <String>{};
  final closed = s
      .rows('hr_payroll_period_closures')
      .where((r) => r['status'] == 'cerrado')
      .map((r) => profitText(r['period_label']))
      .toSet();
  for (final row in s.rows('hr_prenomina_draft_rows')) {
    final label = profitText(row['period_label']);
    if (!closed.contains(label) || row['draft_status'] != 'publicado') continue;
    final dates = profitPayrollPeriod(label);
    if (dates == null) continue;
    double n(String k) => profitNumber(row[k]) ?? 0;
    final amount = math.max(
      0,
      profitPayrollNet(row) +
          n('loan_deduction_amount') +
          n('cash_infonavit_deduction_amount') +
          n('cash_fonacot_deduction_amount') +
          n('cash_isr_amount'),
    );
    for (
      var d = dates.start;
      !d.isAfter(dates.end);
      d = d.add(const Duration(days: 1))
    ) {
      if (!period.contains(d)) continue;
      final companyDay =
          '${profitDateText(d)}|${profitOperationalName(row['empresa'])}';
      publishedCompanyDays.add(companyDay);
      final k =
              '$companyDay|${role(profilesById[profitText(row['employee_id'])])}',
          old = payrollByDayCompany[k];
      payrollByDayCompany[k] = (
        amount: (old?.amount ?? 0) + amount / dates.days,
        refs: [...?old?.refs, 'RH:${row['id']}'],
      );
    }
  }
  final payrollGroups = <String, List<ProfitRow>>{};
  for (final row in s.rows('hr_employee_profiles')) {
    (payrollGroups[group(profitOperationalName(row['empresa']), role(row))] ??=
            [])
        .add(row);
  }
  final payrollNames = {
    ...payrollGroups.keys,
    ...payrollByDayCompany.keys.map((k) => k.split('|').skip(1).join('|')),
  };
  for (
    var d = period.start;
    !d.isAfter(end);
    d = d.add(const Duration(days: 1))
  ) {
    for (final payrollGroup in payrollNames) {
      final name = payrollGroup.split('|').first;
      final driver = payrollGroup.endsWith('|driver');
      final published =
          payrollByDayCompany['${profitDateText(d)}|$payrollGroup'];
      final companyHasPublication = publishedCompanyDays.contains(
        '${profitDateText(d)}|$name',
      );
      final employees = (payrollGroups[payrollGroup] ?? []).where((r) {
        final joined = profitDate(r['fecha_ingreso']),
            left = profitDate(r['termination_date']);
        return (joined == null || !joined.isAfter(d)) &&
            (left == null || !left.isBefore(d)) &&
            !(profitKey(r['employment_status']) == 'BAJA' && left == null);
      }).toList();
      final amount =
          published?.amount ??
          (companyHasPublication
              ? 0
              : employees.fold<double>(
                  0,
                  (v, r) => v + HrEmployeeCompensation.fromRow(r).total / 7,
                ));
      if (amount <= 0) continue;
      final key = named(name, d), dedicated = works[key];
      final eligible = dedicated == null ? works.values.toList() : [dedicated];
      final block = dedicated == null ? 'administration' : 'payroll';
      final shares = driver ? transportShares : supportShares;
      if (dedicated == null && shares.values.every((v) => v.share <= 0)) {
        retainCost(
          'rh:$payrollGroup:${profitDateText(d)}',
          'payroll',
          amount,
          'RH $name: ${driver ? 'transporte' : 'personal común'} sin actividad atribuible. Capacidad que permanece; no se carga a entregas directas.',
          date: d,
        );
        continue;
      }
      for (final w in eligible) {
        if (fixed(w, block, d) ||
            w.lines.values
                .expand((l) => l.components)
                .any(
                  (v) =>
                      v.block == block &&
                      v.date == d &&
                      v.basisLevel == 'source',
                )) {
          continue;
        }
        for (final line in w.lines.values) {
          line.components.removeWhere(
            (v) =>
                v.block == block && v.date == d && v.basisLevel == 'standard',
          );
        }
        final allocation = shares[w.key]!;
        final share = dedicated == null ? allocation.share : 1.0;
        if (share <= 0) continue;
        final line = dedicated != null
            ? costLine(block)
            : driver
            ? 'Nómina de transporte compartida'
            : 'Nómina de patio y soporte';
        add(
          w,
          line,
          block,
          amount * share,
          '${published != null ? 'Nómina publicada repartida en días; reintegra préstamos/retenciones de flujo' : 'Sueldo semanal acordado en RH / 7'}. '
          '${dedicated == null ? '${allocation.rule} Participación: ${(share * 100).toStringAsFixed(4)}%. ${driver ? 'Chofer inferido por coincidencia única con catálogo de Logística.' : 'Incluye personal interno sin función identificada; no se presume exclusivamente administrativo.'}' : 'Personal dedicado a esta empresa.'} '
          'Base operativa de remuneración; cargas patronales adicionales solo si están registradas.',
          published != null
              ? published.refs.join(',')
              : 'RH · ${employees.length} perfiles de $name · ${driver ? 'transporte inferido' : 'personal sin puesto desglosado'} · ${profitDigest(employees)}',
          date: d,
          type: ProfitSourceType.estimated,
          level: published != null ? 'payroll_period' : 'salary_reference',
          sharedSupport: dedicated == null,
        );
      }
    }
  }
  final laborWeights = <String, double>{}, dedicatedWages = <String, double>{};
  for (final w in works.values) {
    final wages = w.lines.values
        .expand((l) => l.components)
        .where(
          (v) => ['salary_reference', 'payroll_period'].contains(v.basisLevel),
        )
        .toList();
    laborWeights[w.key] = wages.fold<double>(0, (t, v) => t + v.amount!);
    dedicatedWages[w.key] = wages
        .where((v) => v.block == 'payroll')
        .fold<double>(0, (t, v) => t + v.amount!);
  }
  // History is a residual reference, not a second expense. Dated consumption
  // reduces the same cost pool's expected amount; explicit coverage replaces
  // its covered days. Unrelated concepts, centers and equipment stay separate.
  for (final block in [
    'fuel',
    'transport',
    'process',
    'maintenance',
    'containers',
    'disposal',
    'scale',
    'training',
    'administration',
    'other',
  ]) {
    if (block == 'fuel' && fuelLoads.isNotEmpty) continue;
    final current = pendingPools[block] ?? <ProfitCostFact>[];
    final recognized = [
      ...current,
      ...alreadyRecognized.where(
        (f) => category(f) == block && overlaps(coverage(f), period),
      ),
    ];
    final previous = pastPools[block] ?? <ProfitCostFact>[];
    final groups = <String, List<ProfitCostFact>>{};
    for (final f in previous) {
      final recurring = recurrenceKey(f, block);
      final exceptional = RegExp(
        r'FINIQUITO|REMODELACION|INDEMNIZACION|ACTIVO FIJO',
      ).hasMatch(factLabel(f));
      final unspecified =
          ['other', 'administration'].contains(block) &&
          !RegExp(
            r'RENTA|ARRENDAM|SEGURO|HONORARIO|CONTADOR|CONTABLE|CONTABILIDAD|TELEFON|INTERNET|MENSUAL|IMSS|INFONAVIT|IMPUEST|ISN',
          ).hasMatch(factLabel(f));
      if (exceptional || unspecified) {
        a.historicalCostEvidence.add({
          'id': f.key,
          'amount': f.amount,
          'applied': false,
          'reason':
              'Gasto histórico sin recurrencia operativa identificada; no se agrega como gasto nuevo del corte.',
        });
        continue;
      }
      (groups[recurring] ??= []).add(f);
    }
    final historyAmounts = <String, double>{},
        historyReferences = <String, String>{};
    final historyDays = <String, List<DateTime>>{};
    final historyEvidence = <String, ProfitRow>{};
    final representatives = <ProfitCostFact>[];
    for (final group in groups.values) {
      final representative = group.first;
      representatives.add(representative);
      final docs = [
        for (final f in group)
          {
            'id': f.key,
            'amount': f.amount,
            'coverage_start': profitDateText(coverage(f).start),
            'coverage_end': profitDateText(coverage(f).end),
            'signature': f.signature,
            if (costBasis.recurrenceCenter(f.key) != costBasis.center(f.key))
              'reconciliation':
                  'IMSS julio 2026: misma plantilla que el pago de septiembre en Celaya, confirmado por Dirección el 29/09/2026. Se conserva el centro original en Finanzas.',
          },
      ];
      final total = group.fold<double>(0, (t, f) {
        final c = coverage(f);
        final start = c.start.isBefore(historyPeriod.start)
            ? historyPeriod.start
            : c.start;
        final finish = c.end.isAfter(historyPeriod.end)
            ? historyPeriod.end
            : c.end;
        return t + f.amount * (finish.difference(start).inDays + 1) / c.days;
      });
      final reference = 'history:${profitDigest(docs)}';
      final matching = recognized
          .where(
            (f) =>
                recurrenceKey(f, block) == recurrenceKey(representative, block),
          )
          .toList();
      final uncovered =
          List.generate(period.days, (i) => period.start.add(Duration(days: i)))
              .where(
                (d) => !matching.any(
                  (f) => coverage(f).days > 1 && coverage(f).contains(d),
                ),
              )
              .toList();
      final expected = total / historyPeriod.days * uncovered.length;
      final observed = matching
          .where((f) => coverage(f).days == 1)
          .fold<double>(
            0,
            (t, f) => t + (recognizedAmounts[f.key] ?? f.amount),
          );
      final residual = math.max(0.0, expected - observed);
      historyAmounts[representative.key] = residual;
      historyDays[representative.key] = uncovered;
      historyReferences[representative.key] = reference;
      final evidence = <String, dynamic>{
        'id': reference,
        'amount': total,
        'daily_reference': total / historyPeriod.days,
        'expected_uncovered_amount': expected,
        'current_amount_offset': observed,
        'residual_amount': residual,
        'uncovered_days': uncovered.length,
        'current_documents': matching.map((f) => f.key).toList(),
        'block': block,
        'applied': false,
        'documents': docs,
      };
      historyEvidence[representative.key] = evidence;
      a.historicalCostEvidence.add(evidence);
    }
    for (final f in [...current, ...representatives]) {
      final historical = !current.contains(f);
      final covered = coverage(f);
      final coveredDays = historical
          ? historyDays[f.key]!
          : List.generate(
              period.days,
              (i) => period.start.add(Duration(days: i)),
            ).where(covered.contains).toList();
      if (coveredDays.isEmpty) continue;
      // Extraordinary purchases must not turn into a recurring daily tariff.
      if (historical &&
          RegExp(
            r'FINIQUITO|REMODELACION|INDEMNIZACION|ACTIVO FIJO',
          ).hasMatch(factLabel(f))) {
        continue;
      }
      final amount = historical
          ? historyAmounts[f.key]!
          : f.amount * coveredDays.length / covered.days;
      if (amount <= 0) continue;
      if (historical) historyEvidence[f.key]!['applied'] = true;
      final origin = f.entityKey.isNotEmpty ? resolve(f.entityKey, f.date) : '';
      final target = works[origin];
      final equipment = costBasis.equipment(f.key);
      final yard = costBasis.yardEquipment(f.key, factLabel(f));
      final laborCharge = RegExp(
        r'IMSS|INFONAVIT|IMPUEST.*NOMINA|ISN',
      ).hasMatch(factLabel(f));
      final eligible = target != null ? [target] : works.values.toList();
      double basis(_AccountWork w) {
        if (target != null) return 1;
        if (laborCharge || block == 'training') return laborWeights[w.key] ?? 0;
        if (block == 'maintenance' && equipment.isNotEmpty && !yard) {
          return w.unitKm[equipment] ?? 0;
        }
        if (yard || block == 'process') {
          return w.lines.values
              .where((l) => l.key != 'RSU')
              .fold<double>(0, (t, l) => t + l.kg);
        }
        return weight(w, block);
      }

      final idleLabor = laborCharge
          ? a.unassignedCosts
                .where((r) => r['block'] == 'payroll')
                .fold<double>(0, (t, r) => t + (profitNumber(r['amount']) ?? 0))
          : 0.0;
      final denominator =
          eligible.fold<double>(0, (t, w) => t + basis(w)) + idleLabor;
      if (idleLabor > 0 && denominator > 0) {
        retainCost(
          '${f.key}:idle-labor',
          block,
          amount * idleLabor / denominator,
          'Carga laboral de capacidad sin actividad atribuida.',
          date: coveredDays.last,
        );
      }
      if (denominator <= 0) {
        retainCost(
          f.key,
          block,
          amount,
          'Sin actividad causal para repartir ${factLabel(f)}; se conserva fuera del aporte de las empresas. Centro ${costBasis.center(f.key)}.',
          date: coveredDays.last,
        );
        continue;
      }
      final allocationLabel = target != null
          ? 'empresa identificada'
          : laborCharge || block == 'training'
          ? 'remuneración RH atribuida'
          : block == 'maintenance' && equipment.isNotEmpty && !yard
          ? 'km de la unidad $equipment'
          : yard || block == 'process'
          ? 'kg manejados, excluyendo RSU'
          : block == 'administration'
          ? 'movimientos operativos sin sumar documentos del mismo día'
          : block == 'other'
          ? 'proporciones de kg y movimientos'
          : switch (block) {
              'fuel' || 'maintenance' => 'km',
              'transport' || 'scale' => 'servicios',
              'containers' => 'contenedores',
              'disposal' => 'kg RSU',
              _ => 'actividad',
            };
      for (final w in eligible) {
        final fraction = basis(w) / denominator;
        if (fraction <= 0) continue;
        final days = historical
            ? coveredDays.where((d) => !fixed(w, block, d)).toList()
            : coveredDays;
        if (days.isEmpty) continue;
        for (final date in days) {
          if (!historical) {
            for (final line in w.lines.values) {
              line.components.removeWhere(
                (v) =>
                    v.block == block &&
                    v.date == date &&
                    ['standard', 'parameter'].contains(v.basisLevel),
              );
            }
          }
        }
        final assigned = amount * fraction * days.length / coveredDays.length;
        final formula =
            '${historical ? 'Complemento histórico: máximo de cero y referencia de 90 días para la cobertura pendiente (${historyEvidence[f.key]!["expected_uncovered_amount"]}) menos gasto actual comparable (${historyEvidence[f.key]!["current_amount_offset"]}); reserva del grupo $amount, ${days.length}/${coveredDays.length} días aplicables' : 'Consumo ${covered.label}; ${days.length}/${covered.days} días de cobertura'}; '
            'reparto por $allocationLabel: ${(fraction * 100).toStringAsFixed(4)}%. '
            'Centro ${costBasis.center(f.key)}. Todos los centros incluidos por Dirección.';
        final reference =
            '${historical ? historyReferences[f.key] : f.key} · ${factLabel(f)} · ${f.signature}';
        void emit(String targetBlock, double money, bool shared) {
          if (money <= 0) return;
          distribute(
            w,
            targetBlock,
            money,
            formula,
            reference,
            date: days.last,
            type: historical
                ? ProfitSourceType.estimated
                : ProfitSourceType.allocated,
            level: historical ? 'historical_average' : 'allocation',
            sharedSupport: shared,
            accountLine: laborCharge
                ? shared
                      ? 'Cargas laborales compartidas (Finanzas)'
                      : 'Cargas laborales de personal dedicado (Finanzas)'
                : null,
          );
        }

        if (laborCharge) {
          final total = laborWeights[w.key] ?? 0,
              direct = dedicatedWages[w.key] ?? 0;
          final dedicatedFraction = total > 0 ? direct / total : 0.0;
          emit('payroll', assigned * dedicatedFraction, false);
          emit('administration', assigned * (1 - dedicatedFraction), true);
        } else {
          emit(
            block,
            assigned,
            target == null &&
                ['administration', 'other', 'training'].contains(block),
          );
        }
      }
    }
  }
  // Direct service sales take precedence over route tariffs. They are not mixed
  // into recovered-material prices. Monetary amounts are never multiplied twice.
  final serviceSales = <String, List<ProfitRow>>{};
  for (final row in s.rows('mayoreo_sales_reports')) {
    final day = profitDate(row['sale_date']),
        amount = profitNumber(row['approved_amount']);
    if (day == null ||
        !period.contains(day) ||
        amount == null ||
        amount < 0 ||
        !serviceSale(row)) {
      continue;
    }
    final key = saleCompany(row, day);
    final w = ensure(key);
    if (w == null) continue;
    final line =
        profitMaterialFamily(profitText(row['material_name_snapshot'])) == 'RSU'
        ? 'RSU'
        : 'Otros servicios';
    (serviceSales['$key|$line'] ??= []).add(row);
    for (final l in w.lines.values) {
      l.components.removeWhere(
        (v) =>
            v.block == 'income' &&
            v.date == day &&
            v.sourceType == ProfitSourceType.estimated &&
            (v.line == line || v.line == 'Toda la cuenta'),
      );
    }
    add(
      w,
      line,
      'income',
      amount,
      'Importe de servicio aprobado en Ventas Mayoreo.',
      'Ventas:${row['id']} · ${profitDigest(row)}',
      type: ProfitSourceType.actual,
      date: day,
      level: 'source',
    );
  }
  List<DateTime> referenceDays(_AccountWork w, String block) {
    final components = w.lines.values
        .expand((l) => l.components)
        .where((v) => v.block == block)
        .toList();
    if (components.any((v) => v.basisLevel != 'parameter')) return [];
    return List.generate(
      period.days,
      (i) => period.start.add(Duration(days: i)),
    ).where((d) => !fixed(w, block, d)).toList();
  }

  for (final w in works.values) {
    final rsu = w.lines['RSU'];
    if (rsu != null && rsu.services > 0) {
      final parameterDays = w.lines.values
          .expand((l) => l.components)
          .where(
            (v) =>
                v.block == 'income' &&
                v.basisLevel == 'parameter' &&
                ['Toda la cuenta', 'RSU'].contains(v.line),
          )
          .map((v) => v.date)
          .toSet();
      final parameterServices = w.trips
          .where(
            (t) =>
                profitMaterialFamily(profitText(t['material_type'])) == 'RSU' &&
                parameterDays.contains(
                  profitDate(t['due_date'] ?? t['service_date']),
                ),
          )
          .length;
      final historicSales =
          [
                ...s.rows('profit_history_mayoreo'),
                ...s.rows('mayoreo_sales_reports'),
              ]
              .where(
                (r) =>
                    profitMaterialFamily(
                          profitText(r['material_name_snapshot']),
                        ) ==
                        'RSU' &&
                    ['SERVICIO', 'VIAJE'].contains(
                      profitKey(
                        saleCatalog[profitText(r['material_id'])]?['unit'],
                      ),
                    ) &&
                    RegExp(
                      r'SERVICIO|RECOLECCION',
                    ).hasMatch(profitKey(r['material_name_snapshot'])) &&
                    (profitNumber(r['approved_price']) ?? 0) > 0,
              )
              .toList();
      final ownSales = historicSales
          .where(
            (r) => saleCompany(r, profitDate(r['sale_date']) ?? end) == w.key,
          )
          .toList();
      final rates =
          (ownSales.isNotEmpty ? ownSales : historicSales)
              .map((r) => profitNumber(r['approved_price'])!)
              .toList()
            ..sort();
      final rate = ownSales.isNotEmpty
          ? rates[rates.length ~/ 2]
          : w.monroe
          ? 5800.0
          : rates.isNotEmpty
          ? rates[rates.length ~/ 2]
          : 0.0;
      final billed = (serviceSales['${w.key}|RSU'] ?? <ProfitRow>[])
          .fold<double>(0, (t, r) {
            final unit = profitKey(
              saleCatalog[profitText(r['material_id'])]?['unit'],
            );
            final quantity = profitNumber(r['approved_weight']) ?? 0;
            if (['SERVICIO', 'VIAJE'].contains(unit) && quantity > 0) {
              return t + quantity;
            }
            final statedRate = profitNumber(r['approved_price']) ?? rate;
            if (['SERVICIO', 'VIAJE'].contains(unit) && statedRate > 0) {
              return t + (profitNumber(r['approved_amount']) ?? 0) / statedRate;
            }
            if (quantity > 0 && rsu.kg > 0) {
              return t + rsu.services * quantity / rsu.kg;
            }
            return t +
                (rate > 0
                    ? (profitNumber(r['approved_amount']) ?? 0) / rate
                    : 0);
          });
      final otherCovered = rsu.components
          .where(
            (v) =>
                v.block == 'income' &&
                v.sourceType != ProfitSourceType.actual &&
                v.basisLevel != 'parameter',
          )
          .fold<double>(0, (t, v) => t + v.amount!);
      final remaining = math.max(
        0.0,
        rsu.services -
            parameterServices -
            billed -
            (rate > 0 ? otherCovered / rate : 0),
      );
      if (remaining > 0) {
        add(
          w,
          'RSU',
          'income',
          remaining * rate,
          '$remaining de ${rsu.services} recolecciones sin facturación cubierta × $rate por servicio; $billed servicios equivalentes ya documentados. ${ownSales.isEmpty && w.monroe ? 'MONROE paga a DICSA, confirmado por Dirección.' : 'Tarifa de referencia de servicios en Ventas.'}',
          !(ownSales.isEmpty && w.monroe) && rates.isNotEmpty
              ? 'Ventas · mediana de ${rates.length} tarifas de servicio'
              : ref,
          level: rate > 0 ? 'service_tariff' : 'zero_basis',
        );
      }
    }
    // A recorded load covers only its unit/day scope. Remaining routes keep
    // their own estimate; one load cannot make another truck's travel free.
    final uncoveredKm = w.unitDayKm.entries
        .where((entry) {
          final date = profitDate(entry.key.split('|').first)!;
          if (fixed(w, 'fuel', date)) return false;
          if (coveredFuelDays.contains('${w.key}|${entry.key}')) return false;
          return !w.lines.values
              .expand((l) => l.components)
              .any(
                (v) =>
                    v.block == 'fuel' &&
                    (v.basisLevel == 'source' && v.date == date ||
                        v.basisLevel == 'allocation'),
              );
        })
        .fold<double>(0, (t, e) => t + e.value);
    if (uncoveredKm > 0) {
      distribute(
        w,
        'fuel',
        uncoveredKm / 3 * 23.67,
        '$uncoveredKm km de unidad/día sin carga atribuida / 3 km/L × 23.67/L. Referencia de consumo, no carga medida.',
        ref,
        level: 'route_reference',
      );
    }
    final containerDays = referenceDays(w, 'containers');
    if (containerDays.isNotEmpty && w.containers > 0) {
      final containerMonths = containerDays.fold<double>(
        0,
        (v, d) => v + 1 / DateTime(d.year, d.month + 1, 0).day,
      );
      final rate = w.monroe ? (w.south ? 11123 / 3 : 20657 / 5) : 31780 / 8;
      add(
        w,
        'Contenedores',
        'containers',
        w.containers * rate * containerMonths,
        '${w.containers} unidades × ${rate.toStringAsFixed(2)} mensual × ${containerMonths.toStringAsFixed(5)} meses calendario.',
        'Logística + $ref',
        level: 'document_reference',
      );
    }
    if (!w.lines.values
            .expand((l) => l.components)
            .any((v) => v.block == 'disposal') &&
        (rsu?.kg ?? 0) > 0) {
      distribute(
        w,
        'disposal',
        rsu!.kg / 1000 * 707.60,
        '${rsu.kg.toStringAsFixed(2)} kg / 1,000 × 707.60 por tonelada.',
        ref,
        level: 'document_reference',
      );
    }
    if (!w.lines.values
            .expand((l) => l.components)
            .any((v) => v.block == 'scale') &&
        w.services > 0) {
      distribute(
        w,
        'scale',
        w.services * 100,
        '${w.services} recolecciones × una pesada externa estimada × 100. No usa Pesadas de la app como si fueran básculas externas.',
        ref,
        level: 'document_reference',
      );
    }
    final trainingDays = referenceDays(w, 'training');
    if (w.monroe && trainingDays.isNotEmpty) {
      final trainingMonths = trainingDays.fold<double>(
        0,
        (v, d) => v + 1 / DateTime(d.year, d.month + 1, 0).day,
      );
      final familyWorks = works.values.where((v) => v.monroe).toList();
      double staff(_AccountWork v) => s
          .rows('hr_employee_profiles')
          .where(
            (r) =>
                named(profitText(r['empresa']), end) == v.key &&
                profitKey(r['employment_status']) != 'BAJA',
          )
          .length
          .toDouble();
      final headcount = familyWorks.fold<double>(0, (v, x) => v + staff(x));
      final share = headcount > 0
          ? staff(w) / headcount
          : 1 / familyWorks.length;
      add(
        w,
        'Capacitaciones',
        'training',
        2250 * share * trainingMonths,
        '27,000 anuales / 12 × ${share.toStringAsFixed(5)} de personal Norte/Sur × meses calendario.',
        ref,
        level: 'document_reference',
      );
    }
    // No source, historic cost or applicable service: explicitly model zero
    // incremental charge, never label it as an observed or reconciled zero.
    for (final block in profitAccountBlocks.keys) {
      if (w.lines.values.any(
        (l) => l.components.any((v) => v.block == block),
      )) {
        continue;
      }
      add(
        w,
        block == 'value'
            ? 'Materiales'
            : block == 'income'
            ? 'Servicios'
            : costLine(block),
        block,
        0,
        'Sin actividad, cargo o referencia aplicable en las fuentes consultadas: base operativa de incremento cero, editable.',
        'Consulta de las cinco áreas · ${period.label}',
        level: 'zero_basis',
      );
    }
    final lines = w.lines.values.toList()
      ..sort((x, y) => y.contribution.compareTo(x.contribution));
    w.company.account = ProfitAccountResult(
      lines: lines,
      assumptions: w.assumptions.toSet().toList(),
      kilometers: w.km,
      serviceCount: w.services,
      containers: w.containers,
    );
    if (w.company.account!.components.any((v) => v.amount == null)) {
      throw StateError('El modelo operativo debe cuantificar cada componente.');
    }
  }
}
