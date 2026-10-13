import 'dart:convert';
import 'profitability_parameters.dart';
import 'profitability_account_models.dart';
import 'package:crypto/crypto.dart';

typedef ProfitRow = Map<String, dynamic>;

String profitText(Object? value) => (value ?? '').toString().trim();
double? profitNumber(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

String profitKey(Object? value) {
  var text = profitText(value).toUpperCase();
  const accents = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U'};
  for (final entry in accents.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

DateTime? profitDate(Object? value) {
  final text = profitText(value);
  final day = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (day != null) {
    return DateTime(int.parse(day[3]!), int.parse(day[2]!), int.parse(day[1]!));
  }
  // Operational dates are calendar dates, not instants converted by the device.
  if (text.length < 10) return null;
  return DateTime.tryParse(text.substring(0, 10));
}

String profitDateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ProfitPeriod {
  final DateTime start, end;
  ProfitPeriod(DateTime start, DateTime end)
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start) || days > 366) {
      throw ArgumentError('El corte debe abarcar entre 1 y 366 días.');
    }
  }
  factory ProfitPeriod.pilot() =>
      ProfitPeriod(DateTime(2026, 9, 11), DateTime(2026, 9, 17));
  int get days => end.difference(start).inDays + 1;
  String get key => '${profitDateText(start)}_${profitDateText(end)}';
  String get label => '${profitDateText(start)} → ${profitDateText(end)}';
  bool contains(Object? raw) {
    final date = raw is DateTime ? raw : profitDate(raw);
    return date != null && !date.isBefore(start) && !date.isAfter(end);
  }

  ProfitPeriod shift(int days) => ProfitPeriod(
    start.add(Duration(days: days)),
    end.add(Duration(days: days)),
  );
}

class ProfitSources {
  final ProfitPeriod period;
  final DateTime readAt;
  final Map<String, List<ProfitRow>> tables;
  ProfitSources({
    required this.period,
    required this.readAt,
    required Map<String, List<ProfitRow>> tables,
  }) : tables = Map.unmodifiable({
         for (final e in tables.entries)
           e.key: List<ProfitRow>.unmodifiable(e.value),
       });
  List<ProfitRow> rows(String table) => tables[table] ?? const [];
  Map<String, ProfitCostRule> sharedCostRules(ProfitReview review) => {
    for (final r in rows('profit_shared_cost_reviews'))
      for (final entry in (r['costs'] as Map? ?? {}).entries)
        entry.key.toString(): ProfitCostRule.fromJson(
          Map<String, dynamic>.from(entry.value),
        ),
    ...review.costs,
  };
  Map<String, int> get counts => {
    for (final e in tables.entries) e.key: e.value.length,
  };
}

class ProfitEntity {
  final String key, name, source;
  const ProfitEntity(this.key, this.name, this.source);
  String get label => '$name · $source';
}

class ProfitOutputRule {
  final String benchmark;
  final double yieldFraction;
  const ProfitOutputRule(this.benchmark, this.yieldFraction);
  factory ProfitOutputRule.fromJson(ProfitRow row) => ProfitOutputRule(
    profitText(row['benchmark']),
    profitNumber(row['yield']) ?? -1,
  );
  ProfitRow toJson() => {'benchmark': benchmark, 'yield': yieldFraction};
}

class ProfitRecipe {
  final List<ProfitOutputRule> outputs;
  final String note;
  const ProfitRecipe({required this.outputs, required this.note});
  factory ProfitRecipe.fromJson(ProfitRow row) => ProfitRecipe(
    outputs: [
      for (final r in row['outputs'] as List? ?? [])
        ProfitOutputRule.fromJson(Map<String, dynamic>.from(r)),
    ],
    note: profitText(row['note']),
  );
  ProfitRow toJson() => {
    'outputs': outputs.map((r) => r.toJson()).toList(),
    'note': note,
  };
}

enum ProfitCostKind {
  fuel('Combustible'),
  payroll('Nómina'),
  transport('Transporte'),
  process('Proceso'),
  maintenance('Mantenimiento'),
  other('Otros'),
  overhead('Estructura');

  final String label;
  const ProfitCostKind(this.label);
  static ProfitCostKind parse(String value) =>
      values.firstWhere((r) => r.name == value, orElse: () => other);
}

enum ProfitCostTreatment {
  pending('Pendiente'),
  include('Reconocer y asignar'),
  exclude('Excluir del resultado'),
  duplicate('Evidencia de otro costo');

  final String label;
  const ProfitCostTreatment(this.label);
}

class ProfitCostRule {
  final ProfitCostTreatment treatment;
  final ProfitCostKind kind;
  final Map<String, double> shares;
  final double? recognizedAmount;
  final String note, duplicateOf, sourceSignature;
  final bool estimated;
  final DateTime? coverageStart, coverageEnd;
  final bool includesMaintenance;
  final String coverageVehicle;
  const ProfitCostRule({
    required this.treatment,
    required this.kind,
    this.shares = const {},
    this.recognizedAmount,
    required this.note,
    this.duplicateOf = '',
    required this.sourceSignature,
    this.estimated = false,
    this.coverageStart,
    this.coverageEnd,
    this.includesMaintenance = false,
    this.coverageVehicle = '',
  });
  factory ProfitCostRule.fromJson(ProfitRow row) => ProfitCostRule(
    treatment: ProfitCostTreatment.values.firstWhere(
      (r) => r.name == row['treatment'],
      orElse: () => ProfitCostTreatment.pending,
    ),
    kind: ProfitCostKind.parse(profitText(row['kind'])),
    shares: {
      for (final e in (row['shares'] as Map? ?? {}).entries)
        e.key.toString(): profitNumber(e.value) ?? -1,
    },
    recognizedAmount: profitNumber(row['amount']),
    note: profitText(row['note']),
    duplicateOf: profitText(row['duplicate_of']),
    sourceSignature: profitText(row['source_signature']),
    estimated: row['estimated'] == true,
    coverageStart: profitDate(row['coverage_start']),
    coverageEnd: profitDate(row['coverage_end']),
    includesMaintenance: row['includes_maintenance'] == true,
    coverageVehicle: profitText(row['coverage_vehicle']),
  );
  ProfitRow toJson() => {
    'treatment': treatment.name,
    'kind': kind.name,
    'shares': shares,
    'amount': recognizedAmount,
    'note': note,
    'duplicate_of': duplicateOf,
    'source_signature': sourceSignature,
    'estimated': estimated,
    if (coverageStart != null) 'coverage_start': profitDateText(coverageStart!),
    if (coverageEnd != null) 'coverage_end': profitDateText(coverageEnd!),
    if (includesMaintenance) 'includes_maintenance': true,
    if (coverageVehicle.isNotEmpty) 'coverage_vehicle': coverageVehicle,
  };
}

class ProfitCompanyReview {
  final bool identity, labor, fuel, process, expenses, taxBasis;
  final String note, evidenceSignature;
  const ProfitCompanyReview({
    this.identity = false,
    this.labor = false,
    this.fuel = false,
    this.process = false,
    this.expenses = false,
    this.taxBasis = false,
    this.note = '',
    this.evidenceSignature = '',
  });
  bool get complete =>
      identity &&
      labor &&
      fuel &&
      process &&
      expenses &&
      taxBasis &&
      note.isNotEmpty;
  factory ProfitCompanyReview.fromJson(ProfitRow r) => ProfitCompanyReview(
    identity: r['identity'] == true,
    labor: r['labor'] == true,
    fuel: r['fuel'] == true,
    process: r['process'] == true,
    expenses: r['expenses'] == true,
    taxBasis: r['tax_basis'] == true,
    note: profitText(r['note']),
    evidenceSignature: profitText(r['evidence_signature']),
  );
  ProfitRow toJson() => {
    'identity': identity,
    'labor': labor,
    'fuel': fuel,
    'process': process,
    'expenses': expenses,
    'tax_basis': taxBasis,
    'note': note,
    'evidence_signature': evidenceSignature,
  };
}

class ProfitReview {
  final int revision;
  final Map<String, String> identities;
  final Map<String, ProfitRecipe> recipes;
  final Map<String, ProfitCostRule> costs;
  final Map<String, ProfitCompanyReview> companies;
  // Exact source signature and explanation for excluded duplicate/invalid tickets.
  final Map<String, ProfitRow> excludedPurchases;
  const ProfitReview({
    this.revision = 0,
    this.identities = const {},
    this.recipes = const {},
    this.costs = const {},
    this.companies = const {},
    this.excludedPurchases = const {},
  });
  factory ProfitReview.fromJson(ProfitRow row) {
    final data = Map<String, dynamic>.from(row['config'] as Map? ?? row);
    Map<String, T> read<T>(String key, T Function(ProfitRow) build) => {
      for (final e in (data[key] as Map? ?? {}).entries)
        e.key.toString(): build(Map<String, dynamic>.from(e.value)),
    };
    return ProfitReview(
      revision: (row['revision'] as num?)?.toInt() ?? 0,
      identities: {
        for (final e in (data['identities'] as Map? ?? {}).entries)
          e.key.toString(): e.value.toString(),
      },
      recipes: read('recipes', ProfitRecipe.fromJson),
      costs: read('costs', ProfitCostRule.fromJson),
      companies: read('companies', ProfitCompanyReview.fromJson),
      excludedPurchases: read('excluded_purchases', (r) => r),
    );
  }
  ProfitRow toJson() => {
    'identities': identities,
    'recipes': {for (final e in recipes.entries) e.key: e.value.toJson()},
    'costs': {for (final e in costs.entries) e.key: e.value.toJson()},
    'companies': {for (final e in companies.entries) e.key: e.value.toJson()},
    'excluded_purchases': excludedPurchases,
  };
  ProfitReview copyWith({
    int? revision,
    Map<String, String>? identities,
    Map<String, ProfitRecipe>? recipes,
    Map<String, ProfitCostRule>? costs,
    Map<String, ProfitCompanyReview>? companies,
    Map<String, ProfitRow>? excludedPurchases,
  }) => ProfitReview(
    revision: revision ?? this.revision,
    identities: identities ?? this.identities,
    recipes: recipes ?? this.recipes,
    costs: costs ?? this.costs,
    companies: companies ?? this.companies,
    excludedPurchases: excludedPurchases ?? this.excludedPurchases,
  );

  void validate() {
    for (final start in identities.keys) {
      var key = start;
      final seen = <String>{};
      while (identities.containsKey(key)) {
        if (!seen.add(key) || identities[key]!.isEmpty) {
          throw StateError(
            'Las equivalencias contienen un ciclo o un destino vacío.',
          );
        }
        key = identities[key]!;
      }
    }
    for (final recipe in recipes.values) {
      final sum = recipe.outputs.fold<double>(0, (s, o) => s + o.yieldFraction);
      if (recipe.note.trim().isEmpty ||
          recipe.outputs.isEmpty ||
          sum > 1.000001 ||
          recipe.outputs.any(
            (o) =>
                o.benchmark.isEmpty ||
                !o.yieldFraction.isFinite ||
                o.yieldFraction <= 0,
          ) ||
          recipe.outputs.map((r) => r.benchmark).toSet().length !=
              recipe.outputs.length) {
        throw StateError(
          'Define salidas distintas, rendimiento total mayor a 0 y máximo 100%, y su fundamento.',
        );
      }
    }
    for (final rule in costs.values) {
      if ((rule.coverageStart == null) != (rule.coverageEnd == null) ||
          rule.coverageStart != null &&
              (rule.coverageEnd!.isBefore(rule.coverageStart!) ||
                  rule.coverageEnd!.difference(rule.coverageStart!).inDays >
                      365) ||
          rule.includesMaintenance && rule.kind != ProfitCostKind.transport) {
        throw StateError(
          'Define una cobertura válida de hasta 366 días; solo transporte puede incluir mantenimiento.',
        );
      }
      if (rule.treatment == ProfitCostTreatment.pending) continue;
      if (rule.note.trim().isEmpty || rule.sourceSignature.isEmpty) {
        throw StateError(
          'Cada costo revisado requiere evidencia y referencia de origen.',
        );
      }
      if (rule.treatment == ProfitCostTreatment.duplicate &&
          rule.duplicateOf.isEmpty) {
        throw StateError('Selecciona el costo que reconoce este comprobante.');
      }
      if (rule.treatment == ProfitCostTreatment.include) {
        final sum = rule.shares.values.fold<double>(0, (s, v) => s + v);
        if (rule.shares.isEmpty ||
            (sum - 1).abs() > .000001 ||
            rule.shares.values.any((v) => !v.isFinite || v <= 0) ||
            rule.recognizedAmount != null &&
                (!rule.recognizedAmount!.isFinite ||
                    rule.recognizedAmount! < 0)) {
          throw StateError(
            'El reparto debe sumar 100% y el importe reconocido no puede ser negativo.',
          );
        }
      }
    }
  }
}

class ProfitPurchase {
  final String key,
      entityKey,
      materialKey,
      material,
      reference,
      source,
      signature;
  final DateTime date;
  final double physicalKg, payableKg, amount;
  final double pieces, payablePieces;
  final bool kgUnit, amountKnown;
  final bool pieceUnit;
  double get quantity => pieceUnit ? pieces : physicalKg;
  double get payableQuantity => pieceUnit ? payablePieces : payableKg;
  String get unit => pieceUnit ? 'PZA' : 'KG';
  const ProfitPurchase({
    required this.key,
    required this.entityKey,
    required this.materialKey,
    required this.material,
    required this.reference,
    required this.source,
    required this.signature,
    required this.date,
    required this.physicalKg,
    required this.payableKg,
    required this.amount,
    required this.kgUnit,
    this.amountKnown = true,
    this.pieces = 0,
    this.payablePieces = 0,
    this.pieceUnit = false,
  });
}

class ProfitBenchmark {
  final String key, material, source;
  final String unit;
  double quantity = 0, amount = 0;
  double get kg => unit == 'KG' ? quantity : 0;
  int count = 0;
  DateTime? first, last;
  ProfitBenchmark(this.key, this.material, this.source, {this.unit = 'KG'});
  double? get price => quantity > 0 ? amount / quantity : null;
}

class ProfitCostFact {
  final String key, label, source, entityKey, vehicleId, signature;
  final DateTime date;
  final double amount;
  final ProfitCostKind suggestedKind;
  final bool payrollNet;
  const ProfitCostFact({
    required this.key,
    required this.label,
    required this.source,
    required this.date,
    required this.amount,
    required this.signature,
    this.entityKey = '',
    this.vehicleId = '',
    this.suggestedKind = ProfitCostKind.other,
    this.payrollNet = false,
  });
}

class ProfitMaterialResult {
  final String key, material, entityKey;
  final List<ProfitPurchase> purchases;
  final ProfitRecipe? recipe;
  final double? value;
  final List<String> issues;
  ProfitMaterialResult({
    required this.key,
    required this.material,
    required this.entityKey,
    required this.purchases,
    required this.recipe,
    required this.value,
    required this.issues,
  });
  double get physicalKg => purchases.fold(0, (s, p) => s + p.physicalKg);
  double get pieces => purchases.fold(0, (s, p) => s + p.pieces);
  double get payableKg => purchases.fold(0, (s, p) => s + p.payableKg);
  double get purchaseAmount => purchases.fold(0, (s, p) => s + p.amount);
  double? get purchasePrice =>
      payableKg > 0 ? purchaseAmount / payableKg : null;
}

class ProfitCompanyResult {
  final ProfitEntity entity;
  String? catalogName;
  String get displayName => catalogName ?? entity.name;
  final List<ProfitMaterialResult> materials;
  final Map<ProfitCostKind, double> costs = {};
  final List<String> issues = [], costIds = [];
  int services = 0;
  double? attributedKm, attributedLiters;
  bool reviewed = false;
  ProfitOperatingResult? operating;
  ProfitAccountResult? account;
  ProfitCompanyResult(this.entity, this.materials);
  double get kg => materials.fold(0, (s, m) => s + m.physicalKg);
  double get payableKg => materials.fold(0, (s, m) => s + m.payableKg);
  double get purchases => materials.fold(0, (s, m) => s + m.purchaseAmount);
  double? get value =>
      materials.isEmpty || materials.any((m) => m.value == null)
      ? null
      : materials.fold<double>(0, (s, m) => s + m.value!);
  double get operatingCosts => costs.entries
      .where((e) => e.key != ProfitCostKind.overhead)
      .fold(0, (s, e) => s + e.value);
  double get overhead => costs[ProfitCostKind.overhead] ?? 0;
  double? get provisionalContribution =>
      value == null ? null : value! - purchases - operatingCosts;
  bool get complete =>
      reviewed && issues.isEmpty && materials.isNotEmpty && value != null;
  double? get contribution => complete ? provisionalContribution : null;
  double? get result => contribution == null ? null : contribution! - overhead;
  String get decision => !complete
      ? 'Información insuficiente'
      : contribution! < 0
      ? 'Renegociar / reorganizar'
      : result! < 0
      ? 'Revisar estructura'
      : 'Conservar · estimación';
}

class ProfitAnalysis {
  static const engineVersion = 3;
  final ProfitSources sources;
  final ProfitReview review;
  final ProfitMaster master;
  final bool inferOperations;
  final List<ProfitEntity> entities;
  final Map<String, ProfitBenchmark> benchmarks;
  final List<ProfitPurchase> purchases;
  final List<ProfitCostFact> costFacts;
  final List<ProfitCompanyResult> companies;
  final Map<String, String> pendingCosts;
  final List<String> issues;
  final int excludedSales, excludedPurchases;
  final String evidenceSignature;
  ProfitAnalysis({
    required this.sources,
    required this.review,
    this.master = const ProfitMaster(),
    this.inferOperations = false,
    required this.entities,
    required this.benchmarks,
    required this.purchases,
    required this.costFacts,
    required this.companies,
    required this.pendingCosts,
    required this.issues,
    required this.excludedSales,
    required this.excludedPurchases,
    required this.evidenceSignature,
  });
  final List<ProfitRow> nonOperatingFlows = [];
  final List<ProfitRow> coveredMaterialPurchases = [];
  final List<ProfitRow> payrollWithholdingSettlements = [];
  final List<ProfitRow> unassignedCosts = [];
  final List<ProfitRow> historicalCostEvidence = [];
  Set<String>? reportKeys;
  List<ProfitCompanyResult> get reportCompanies => reportKeys == null
      ? companies
      : companies.where((c) => reportKeys!.contains(c.entity.key)).toList();
  double get retainedOperatingCosts => unassignedCosts
      .where((r) => r['block'] != 'inventory')
      .fold<double>(0, (t, r) => t + (profitNumber(r['amount']) ?? 0));
  double get unclassifiedCosts => unassignedCosts
      .where((r) => r['block'] == 'classification_pending')
      .fold<double>(0, (t, r) => t + (profitNumber(r['amount']) ?? 0));
  double get modeledResult =>
      companies.fold<double>(0, (t, c) => t + (c.account?.afterOverhead ?? 0)) -
      retainedOperatingCosts;
  ProfitRow get reportingScope => {
    'catalog': 'compras_counterparties',
    'cost_centers':
        'Todos, incluidos VH y Mazatlán; confirmado por Dirección 22/09/2026',
    'companies': reportCompanies.where((c) => c.account != null).length,
    'confirmed_aliases': {
      'SETEX': 'SETEXMES',
      'BOSCH / BOCHS': 'DESPERDICIOS QUERETANA BOSCH',
    },
    'result_all_activities': modeledResult,
    'retained_operating_costs': retainedOperatingCosts,
    'unclassified_costs': unclassifiedCosts,
    'result_provisional': unclassifiedCosts > 0,
    'other_activities': [
      for (final c in companies)
        if (reportKeys != null &&
            !reportKeys!.contains(c.entity.key) &&
            c.account != null)
          {
            'key': c.entity.key,
            'name': c.entity.name,
            'generated': c.account!.generated,
            'costs': c.account!.costs,
            'contribution': c.account!.contribution,
          },
    ],
    'unassigned_costs': unassignedCosts,
    'material_invoices_covered_by_tickets': coveredMaterialPurchases,
    'payroll_withholding_settlements': payrollWithholdingSettlements,
  };
  Map<String, ProfitCostRule> get effectiveCostRules =>
      sources.sharedCostRules(review);
  double get purchaseTotal => companies.fold(0, (s, c) => s + c.purchases);
  double get assignedCosts =>
      companies.fold(0, (s, c) => s + c.operatingCosts + c.overhead);
  // Candidate documents can overlap. This amount must never be labelled expense.
  double get pendingDocumentAmount => costFacts
      .where((c) => pendingCosts.containsKey(c.key))
      .fold(0, (s, c) => s + c.amount);
  ProfitRow snapshot() => {
    'engine_version': engineVersion,
    'inference_model': inferOperations
        ? 'operational-account-v2'
        : 'documentary',
    if (inferOperations) 'payroll_allocation_model': 'activity-proportions-v2',
    if (inferOperations) 'cost_allocation_model': 'consumption-residual-v3',
    'sale_price_model': 'material-weighted-mayoreo-menudeo-v1',
    if (inferOperations) 'historical_cost_evidence': historicalCostEvidence,
    if (inferOperations) 'reporting_scope': reportingScope,
    'non_operating_flows': nonOperatingFlows,
    'master_revision': master.revision,
    'master_config': master.toJson(),
    'start': profitDateText(sources.period.start),
    'end': profitDateText(sources.period.end),
    'read_at': sources.readAt.toIso8601String(),
    'source_counts': sources.counts,
    'source_ids': {
      for (final table in sources.tables.entries)
        if (table.key != 'hr_employee_profiles')
          table.key: table.value
              .map((r) => profitText(r['id']))
              .where((id) => id.isNotEmpty)
              .toList(),
    },
    'sale_evidence': {
      'mayoreo': sources.rows('mayoreo_sales_reports'),
      'historical_mayoreo': sources.rows('profit_history_mayoreo'),
      'historical_menudeo': sources.rows('profit_history_men'),
      'menudeo': sources
          .rows('men_tickets')
          .where((r) => r['direction'] == 'sale')
          .map(
            (r) => {
              for (final key in [
                'id',
                'ticket_date',
                'ticket_number',
                'commercial_material_id',
                'material_label_snapshot',
                'payable_weight',
                'price_at_entry',
                'amount_total',
                'status',
              ])
                key: r[key],
            },
          )
          .toList(),
    },
    'service_income_evidence': sources.rows('pesadas'),
    'intake_evidence': sources.rows('inventory_movements_v2'),
    'logistics_evidence': {
      for (final table in [
        'services',
        'logistics_vehicle_mileage',
        'logistics_diesel_consumption',
        'logistics_gasoline_control',
      ])
        table: sources.rows(table),
    },
    'review_revision': review.revision,
    'basis':
        'Contribución estimada por material originado; no utilidad realizada',
    'config': review.toJson(),
    'evidence_signature': evidenceSignature,
    'issues': issues,
    'pending_costs': pendingCosts,
    'excluded_sales': excludedSales,
    'excluded_purchases': excludedPurchases,
    'companies': [
      for (final c in reportCompanies)
        {
          'key': c.entity.key,
          'operating': c.operating?.toJson(),
          'account': c.account?.toJson(),
          'name': c.displayName,
          'source': c.entity.source,
          'kg': c.kg,
          'payable_kg': c.payableKg,
          'purchases': c.purchases,
          'estimated_value': c.value,
          'costs': {for (final e in c.costs.entries) e.key.name: e.value},
          'provisional_contribution': c.provisionalContribution,
          'contribution': c.contribution,
          'result': c.result,
          'services': c.services,
          'decision': c.decision,
          'issues': c.issues,
          'cost_ids': c.costIds,
          'materials': [
            for (final m in c.materials)
              {
                'key': m.key,
                'label': m.material,
                'physical_kg': m.physicalKg,
                'pieces': m.pieces,
                'payable_kg': m.payableKg,
                'purchase_amount': m.purchaseAmount,
                'estimated_value': m.value,
                'issues': m.issues,
                'purchase_ids': m.purchases.map((p) => p.key).toList(),
              },
          ],
        },
    ],
    'benchmarks': [
      for (final b in benchmarks.values)
        {
          'key': b.key,
          'material': b.material,
          'source': b.source,
          'kg': b.kg,
          'quantity': b.quantity,
          'unit': b.unit,
          'amount': b.amount,
          'price': b.price,
          'count': b.count,
          'first_date': b.first == null ? null : profitDateText(b.first!),
          'last_date': b.last == null ? null : profitDateText(b.last!),
        },
    ],
    'shared_cost_review_evidence': sources.rows('profit_shared_cost_reviews'),
    'cost_evidence': [
      for (final c in costFacts)
        {
          'key': c.key,
          'source': c.source,
          'label': c.label,
          'date': profitDateText(c.date),
          'document_amount': c.amount,
          'signature': c.signature,
        },
    ],
    'purchase_evidence': [
      for (final p in purchases)
        {
          'key': p.key,
          'reference': p.reference,
          'date': profitDateText(p.date),
          'physical_kg': p.physicalKg,
          'payable_kg': p.payableKg,
          'pieces': p.pieces,
          'payable_pieces': p.payablePieces,
          'quantity_unit': p.unit,
          'amount': p.amount,
          'signature': p.signature,
        },
    ],
  };
  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(snapshot());
}

class ProfitExitScenario {
  final double lostRevenue,
      avoidedPurchases,
      avoidedOperations,
      avoidedOverhead,
      replacementContribution,
      transitionCost;
  const ProfitExitScenario({
    required this.lostRevenue,
    required this.avoidedPurchases,
    required this.avoidedOperations,
    required this.avoidedOverhead,
    required this.replacementContribution,
    required this.transitionCost,
  });
  double get improvement =>
      avoidedPurchases +
      avoidedOperations +
      avoidedOverhead +
      replacementContribution -
      lostRevenue -
      transitionCost;
}

String profitSignature(Iterable<Object?> values) =>
    profitDigest(values.toList());
String profitDigest(Object? value) {
  Object? canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: canonical(v[k])};
    }
    if (v is Iterable) return v.map(canonical).toList();
    return v;
  }

  return sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
}
