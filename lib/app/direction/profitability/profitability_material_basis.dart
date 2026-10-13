import 'dart:math' as math;
import 'profitability_models.dart';
import 'profitability_material_units.dart';
import 'profitability_inference.dart' show profitOperationalName;

/// Catalogs share names, not IDs, across the commercial and physical systems.
class ProfitMaterialBasis {
  final ProfitSources sources;
  final String Function(String) fallback;
  late final catalogs = <String, ProfitRow>{
    for (final (table, prefix) in [
      ('compras_material_catalog', 'compras'),
      ('mayoreo_material_catalog', 'ventas'),
      ('material_commercial_catalog_v2', 'men'),
    ])
      for (final r in sources.rows(table)) '$prefix:${r['id']}': r,
  };
  ProfitMaterialBasis(this.sources, this.fallback);
  String family(String name, [String key = '']) {
    final row = catalogs[key.split('@').first];
    final category = profitKey(row?['family'] ?? row?['category']);
    final inferred = fallback(name);
    if (inferred == 'CARTON AMERICANO') return inferred;
    if (category == 'METAL') {
      // ACERO, COPPER and aluminum products must never become cheap scrap.
      return inferred == 'CHATARRA' ? profitOperationalName(name) : inferred;
    }
    if (['CARTON', 'CHATARRA', 'PAPEL', 'PLASTICO'].contains(category)) {
      return category;
    }
    final parent = sources
        .rows('material_general_catalog_v2')
        .where((r) => r['id'] == row?['general_material_id'])
        .firstOrNull;
    final physicalFamily = profitKey(parent?['name']);
    if (['CARTON', 'CHATARRA', 'PAPEL', 'PLASTICO'].contains(physicalFamily)) {
      return physicalFamily;
    }
    return inferred;
  }

  String comparableName(String name) {
    final n = profitOperationalName(name)
        .replaceAll(RegExp(r'\b(EN PACAS|PACA DE|PACAS DE|PACA|PACAS)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Business equivalence confirmed by Dirección on 22/09/2026.
    return fallback(name) == 'CARTON AMERICANO' ? 'CARTON CELANESE' : n;
  }

  String saleName(String name) =>
      comparableName(name).replaceAll(RegExp(r'\bTARIMAS\b'), 'TARIMA');

  // Intake often records generic cardboard before commercial grading. Keep
  // grade-specific sale prices, but reconcile physical cardboard only once.
  String quantityFamily(String name, String key) {
    final f = family(name, key);
    return f == 'CARTON AMERICANO' ? 'CARTON' : f;
  }

  String _saleFamily(String name, String key) {
    // MADERA PIEZA is attached to CHATARRA in the retail catalog. Correct sale
    // comparisons without changing intake reconciliation or purchase costs.
    if (profitOperationalName(name).contains('MADERA') &&
        !profitOperationalName(name).contains('PLASTICO')) {
      return fallback(name);
    }
    return family(name, key);
  }

  List<ProfitBenchmark> comparables(
    Map<String, ProfitBenchmark> benchmarks,
    String name,
    String key, {
    bool familyFallback = true,
    String unit = 'KG',
  }) {
    if (name.trim().isEmpty || family(name, key) == 'RSU') return [];
    final eligible = benchmarks.values.where(
      (b) =>
          (b.key.startsWith('ventas:') || b.key.startsWith('men:')) &&
          b.price != null &&
          // Wood tickets use the same quantity field for potentially different
          // units. Do not turn piece/load prices into a per-kg benchmark.
          b.unit == unit &&
          !RegExp(
            r'SERVICIO|RECOLECCION|FLETE|PESADA',
          ).hasMatch(profitKey(b.material)),
    );
    List<ProfitBenchmark> match(Iterable<ProfitBenchmark> pool) {
      final targetFamily = _saleFamily(name, key);
      final generic =
          familyFallback &&
          [
            'CARTON',
            'CHATARRA',
            'PAPEL',
            'PLASTICO',
          ].contains(saleName(name)) &&
          saleName(name) == targetFamily;
      final exact = pool
          .where((b) => saleName(b.material) == saleName(name))
          .toList();
      return (!generic && exact.isNotEmpty) || !familyFallback
          ? exact
          : pool
                .where(
                  (b) =>
                      _saleFamily(b.material, b.key) == _saleFamily(name, key),
                )
                .toList();
    }

    // A current sale in either area takes precedence over older prices from
    // the other area. History is only a fallback when neither has a match.
    final current = match(
      eligible.where((b) => b.last != null && sources.period.contains(b.last!)),
    );
    return current.isNotEmpty ? current : match(eligible);
  }

  ProfitSalePrice price(
    Map<String, ProfitBenchmark> benchmarks,
    String name,
    String key, {
    bool familyFallback = true,
    String unit = 'KG',
  }) => ProfitSalePrice(
    comparables(
      benchmarks,
      name,
      key,
      familyFallback: familyFallback,
      unit: unit,
    ),
    sources.period,
    unit: unit,
    unitPending: benchmarks.values
        .where(
          (b) =>
              b.unit == 'PENDIENTE' &&
              (comparableName(b.material) == comparableName(name) ||
                  (familyFallback &&
                      family(b.material, b.key) == family(name, key))),
        )
        .toList(),
  );

  ProfitSalePrice purchasePrice(ProfitAnalysis a, ProfitPurchase purchase) {
    final standard = price(
      a.benchmarks,
      purchase.material,
      purchase.materialKey,
      unit: purchase.unit,
    );
    if (standard.price != null ||
        !purchase.kgUnit ||
        comparableName(purchase.material) != 'CAJON MADERA') {
      return standard;
    }
    final purchases = a.purchases
        .where((p) => p.kgUnit && comparableName(p.material) == 'CAJON MADERA')
        .toList();
    // Inference requested by Dirección: require a unique origin and equal
    // aggregate quantities in this cut; never persist a global material alias.
    if (purchases.map((p) => p.entityKey).toSet().length != 1) return standard;
    final quantity = purchases.fold<double>(0, (t, p) => t + p.physicalKg);
    final sales = a.benchmarks.values
        .where(
          (b) =>
              b.unit == 'KG' &&
              [
                'MADERA PIEZA',
                'PIEZA MADERA',
              ].contains(comparableName(b.material)) &&
              b.first != null &&
              b.last != null &&
              sources.period.contains(b.last!) &&
              purchases.every((p) => !b.first!.isBefore(p.date)),
        )
        .toList();
    final sold = sales.fold<double>(0, (t, b) => t + b.quantity);
    if (quantity <= 0 || (quantity - sold).abs() > .01) return standard;
    return ProfitSalePrice(
      sales,
      sources.period,
      unit: purchase.unit,
      inferenceNote:
          'Equivalencia provisional CAJON MADERA → MADERA PIEZA: '
          '$quantity capturados en compras de un solo origen y $sold en ventas posteriores del periodo. '
          'Kg según catálogo de Compras; origen y unidad de la venta sin confirmar. '
          'Coincidir en cantidad no demuestra trazabilidad; revisar esta inferencia.',
    );
  }

  /// A recovery rule selects an output material, not an exclusive sales area.
  ProfitSalePrice outputPrice(
    Map<String, ProfitBenchmark> benchmarks,
    String key, {
    String unit = 'KG',
  }) => price(
    benchmarks,
    benchmarks[key]?.material ??
        profitText(catalogs[key.split('@').first]?['name']),
    key,
    familyFallback: false,
    unit: unit,
  );
}

class ProfitSalePrice {
  final List<ProfitBenchmark> benchmarks;
  final List<ProfitBenchmark> unitPending;
  final ProfitPeriod period;
  final String unit;
  final String inferenceNote;
  ProfitSalePrice(
    this.benchmarks,
    this.period, {
    this.unitPending = const [],
    this.unit = 'KG',
    this.inferenceNote = '',
  });
  String get unitWarning => unitPending.isEmpty
      ? ''
      : 'Ventas de Menudeo de ${unitPending.map((b) => b.material).toSet().join(", ")} '
            'pendientes de conciliar kilos, piezas o cargas; no se mezclan sus precios. '
            'El valor provisional no representa ventas realizadas de esta empresa.';
  double get quantity => benchmarks.fold(0, (s, b) => s + b.quantity);
  double get amount => benchmarks.fold(0, (s, b) => s + b.amount);
  double? get price => quantity > 0 ? amount / quantity : null;
  bool get historical =>
      benchmarks.isNotEmpty &&
      benchmarks.every((b) => b.last == null || !period.contains(b.last!));
  String get areas =>
      (benchmarks.map((b) => b.source).toSet().toList()..sort()).join(' + ');
  String get description =>
      '$areas · ${historical ? 'referencia histórica de hasta 90 días' : 'periodo seleccionado'}: '
      '${amount.toStringAsFixed(2)} / ${quantity.toStringAsFixed(2)} ${profitUnitLabel(unit)} = '
      '${(price ?? 0).toStringAsFixed(4)}/${profitUnitLabel(unit)}';
  String get reference => benchmarks
      .map(
        (b) =>
            '${b.source} · ${b.material} · ${b.key}; ${b.amount.toStringAsFixed(2)}; '
            '${b.quantity.toStringAsFixed(2)} ${profitUnitLabel(b.unit)}; ${b.count} ventas; '
            '${b.first == null ? "sin fecha" : profitDateText(b.first!)} a '
            '${b.last == null ? "sin fecha" : profitDateText(b.last!)}',
      )
      .join(' | ');
}

class ProfitPhysicalBasis {
  final Map<String, String> purchaseCompanies = {};
  final List<ProfitPurchase> additional = [];
  final Map<String, String> notes = {};
}

/// Reconcile quantities before valuing them: never sum purchases and intake.
/// Exact folio/material/weight matches move BOTH value and purchase cost to
/// the physical plant. Unlinked quantities use the greater source per family.
ProfitPhysicalBasis profitPhysicalBasis(
  ProfitAnalysis a,
  ProfitMaterialBasis material,
  String Function(String, DateTime) resolve,
  String Function(String, DateTime) named,
) {
  final result = ProfitPhysicalBasis(), s = a.sources;
  final groups = <String, List<ProfitRow>>{};
  final links = <String, List<({String company, ProfitRow row})>>{};
  final today = DateTime(s.readAt.year, s.readAt.month, s.readAt.day);
  for (final r in s.rows('inventory_movements_v2')) {
    final day = profitDate(r['op_date']);
    if (day == null ||
        !s.period.contains(day) ||
        day.isAfter(today) ||
        r['flow'] != 'IN' ||
        r['inventory_level'] != 'GENERAL' ||
        r['origin_type'] != 'DIRECT_PURCHASE') {
      continue;
    }
    final kg = profitNumber(r['net_kg'] ?? r['weight_kg']) ?? 0;
    if (kg <= 0) continue;
    final label = profitOperationalName(r['counterparty']);
    // Public yard intake belongs to many suppliers: not a separate customer.
    if (label.isEmpty || RegExp(r'^(PUBLICO|DICSA|PATIO)\b').hasMatch(label)) {
      continue;
    }
    final company = profitText(r['counterparty_site_id']).isEmpty
        ? named(label, day)
        : resolve('site:${r['counterparty_site_id']}', day);
    if (company.isEmpty) continue;
    final key = 'men:${r['source_commercial_material_id']}';
    final name = profitText(material.catalogs[key]?['name']);
    if (name.isEmpty) continue;
    (groups['$company|${material.quantityFamily(name, key)}'] ??= []).add(r);
    final folio = profitText(r['reference']).isEmpty
        ? profitText(r['scale_ticket'])
        : profitText(r['reference']);
    final matches = a.purchases
        .where(
          (p) =>
              folio.isNotEmpty &&
              p.reference == folio &&
              p.kgUnit &&
              p.materialKey == key &&
              (p.physicalKg - kg).abs() < 0.01 &&
              p.date.difference(day).inDays.abs() <= 31,
        )
        .toList();
    if (matches.length == 1) {
      (links[matches.single.key] ??= []).add((company: company, row: r));
    }
  }
  for (final p in a.purchases) {
    final matched = links[p.key];
    final company = matched?.length == 1
        ? matched!.single.company
        : resolve(p.entityKey, p.date);
    result.purchaseCompanies[p.key] = company;
    if (company != resolve(p.entityKey, p.date)) {
      result.notes[p.key] =
          'Origen físico conciliado con entrada ${matched!.single.row['id']}: mismo folio ${p.reference}, material y ${p.physicalKg} kg. Compra registrada a nombre de otra contraparte; valor y costo se atribuyen juntos a la planta.';
    }
  }
  for (final group in groups.entries) {
    final split = group.key.lastIndexOf('|'),
        company = group.key.substring(0, split),
        family = group.key.substring(split + 1);
    final purchases = a.purchases
        .where(
          (p) =>
              p.kgUnit &&
              result.purchaseCompanies[p.key] == company &&
              material.quantityFamily(p.material, p.materialKey) == family,
        )
        .toList();
    final bought = purchases.fold<double>(0, (t, p) => t + p.physicalKg);
    final received = group.value.fold<double>(
      0,
      (t, r) => t + (profitNumber(r['net_kg'] ?? r['weight_kg']) ?? 0),
    );
    final residual = math.max(0.0, received - bought);
    if (residual <= 0.01) continue;
    for (final r in group.value) {
      final key = 'men:${r['source_commercial_material_id']}',
          name = profitText(material.catalogs[key]?['name']);
      final physical =
          (profitNumber(r['net_kg'] ?? r['weight_kg']) ?? 0) *
          residual /
          received;
      var peers = purchases
          .where((p) => p.amountKnown && p.physicalKg > 0)
          .toList();
      if (peers.isEmpty) {
        peers = a.purchases
            .where(
              (p) =>
                  p.kgUnit &&
                  p.amountKnown &&
                  p.physicalKg > 0 &&
                  material.comparableName(p.material) ==
                      material.comparableName(name),
            )
            .toList();
      }
      if (peers.isEmpty) {
        peers = a.purchases
            .where(
              (p) =>
                  p.kgUnit &&
                  p.amountKnown &&
                  p.physicalKg > 0 &&
                  material.family(p.material, p.materialKey) == family,
            )
            .toList();
      }
      final baseKg = peers.fold<double>(0, (t, p) => t + p.physicalKg),
          cost = peers.fold<double>(0, (t, p) => t + p.amount);
      final id = 'intake:${r['id']}';
      result.additional.add(
        ProfitPurchase(
          key: id,
          entityKey: company,
          materialKey: key,
          material: name,
          reference: profitText(r['reference']),
          source: 'Entradas',
          signature: profitDigest(r),
          date: profitDate(r['op_date'])!,
          physicalKg: physical,
          payableKg: physical,
          amount: baseKg > 0 ? physical * cost / baseKg : 0,
          kgUnit: true,
          amountKnown: baseKg > 0,
        ),
      );
      result.purchaseCompanies[id] = company;
      result.notes[id] =
          'Conciliación estimada por planta/familia: máximo entre $received kg de entradas y $bought kg de compras; incremento $residual kg, distribuido entre las entradas. No suma ambos registros. Costo de compra inferido ${baseKg > 0 ? '${cost / baseKg}/kg físico de ${peers.map((p) => p.key).join(',')}' : 'sin precio comparable, base 0 por revisar'}. Diferencias de fecha u origen pueden requerir ajuste.';
    }
  }
  return result;
}
