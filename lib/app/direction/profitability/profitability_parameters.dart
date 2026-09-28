import 'profitability_models.dart';

enum ProfitParameterKind {
  identity('Empresa / planta'),
  vehicle('Unidad / tipo de unidad'),
  labor('Personal'),
  process('Proceso por material'),
  recovery('Rendimiento recuperable'),
  activity('Horas / kg atribuibles'),
  coverage('Bloque sin costo / sin ingresos'),
  account('Concepto de la cuenta');

  final String label;
  const ProfitParameterKind(this.label);
}

/// Approved, effective-dated managerial assumptions. No sample rates are seeded.
/// Groups are labels only: identity resolution always terminates at a plant.
class ProfitParameter {
  final String id, note;
  final ProfitParameterKind kind;
  final DateTime from;
  final DateTime? to;
  final ProfitRow data;
  const ProfitParameter({
    required this.id,
    required this.kind,
    required this.from,
    this.to,
    required this.note,
    required this.data,
  });
  factory ProfitParameter.fromJson(ProfitRow r) => ProfitParameter(
    id: profitText(r['id']),
    kind: ProfitParameterKind.values.byName(r['kind']),
    from: profitDate(r['valid_from'])!,
    to: profitDate(r['valid_to']),
    note: profitText(r['note']),
    data: Map<String, dynamic>.from(r['data']),
  );
  bool active(DateTime date) =>
      !date.isBefore(from) && (to == null || !date.isAfter(to!));
  String text(String key) => profitText(data[key]);
  double? number(String key) => profitNumber(data[key]);
  String get company => text('company');
  String get scope => switch (kind) {
    ProfitParameterKind.identity => '${kind.name}|${text('site')}',
    ProfitParameterKind.vehicle => '${kind.name}|${text('unit')}',
    ProfitParameterKind.labor => '${kind.name}|$company|${text('role')}',
    ProfitParameterKind.process =>
      '${kind.name}|$company|${text('material')}|${text('process')}',
    ProfitParameterKind.recovery => '${kind.name}|$company|${text('material')}',
    ProfitParameterKind.activity =>
      '${kind.name}|$company|${text('measure')}|${text('subject')}',
    ProfitParameterKind.coverage => '${kind.name}|$company|${text('block')}',
    ProfitParameterKind.account =>
      '${kind.name}|$company|${text('line')}|${text('block')}',
  };
  List<String> get origins => [
    if (text('compras_supplier_id').isNotEmpty)
      'compras:${text('compras_supplier_id')}',
    if (text('mayoreo_customer_id').isNotEmpty)
      'ventas:${text('mayoreo_customer_id')}',
    if (text('menudeo_counterparty_id').isNotEmpty)
      'men:${text('menudeo_counterparty_id')}',
    if (text('hr_company_identifier').isNotEmpty)
      'payroll:${profitKey(text('hr_company_identifier'))}',
    for (final alias in text(
      'aliases',
    ).split(';').map(profitKey).where((v) => v.isNotEmpty))
      'expense:$alias',
  ];
  ProfitRow toJson() => {
    'id': id,
    'kind': kind.name,
    'valid_from': profitDateText(from),
    'valid_to': to == null ? null : profitDateText(to!),
    'note': note,
    'data': data,
  };
}

class ProfitMaster {
  final int revision;
  final List<ProfitParameter> rules;
  const ProfitMaster({this.revision = 0, this.rules = const []});
  factory ProfitMaster.fromJson(ProfitRow r) => ProfitMaster(
    revision: (r['revision'] as num?)?.toInt() ?? 0,
    rules: [
      for (final v in (r['config'] as Map? ?? r)['rules'] as List? ?? [])
        ProfitParameter.fromJson(Map<String, dynamic>.from(v)),
    ],
  );
  ProfitRow toJson() => {'rules': rules.map((r) => r.toJson()).toList()};
  Iterable<ProfitParameter> at(ProfitParameterKind kind, DateTime day) =>
      rules.where((r) => r.kind == kind && r.active(day));
  String resolve(String key, DateTime day) {
    for (final r in at(ProfitParameterKind.identity, day)) {
      if (r.origins.contains(key)) return r.text('site');
    }
    return key;
  }

  String group(String site, DateTime day) =>
      at(ProfitParameterKind.identity, day)
          .where((r) => r.text('site') == site)
          .firstOrNull
          ?.text('company_group') ??
      '';
  ProfitParameter? recipe(String company, String material, DateTime day) =>
      at(ProfitParameterKind.recovery, day)
          .where((r) => r.company == company && r.text('material') == material)
          .firstOrNull;

  void validate() {
    if (rules.map((r) => r.id).toSet().length != rules.length) {
      throw StateError('Reglas duplicadas.');
    }
    for (final r in rules) {
      if (r.id.isEmpty ||
          r.note.trim().isEmpty ||
          (r.to?.isBefore(r.from) ?? false)) {
        throw StateError('Cada parámetro requiere vigencia y fundamento.');
      }
      void require(List<String> keys) {
        if (keys.any((k) => r.text(k).isEmpty)) {
          throw StateError('Completa ${keys.join(', ')}.');
        }
      }

      void nonnegative(List<String> keys, {bool any = false}) {
        if (keys.any(
              (k) =>
                  r.data[k] != null &&
                  (r.number(k) == null ||
                      r.number(k)! < 0 ||
                      r.number(k)! > 1e12),
            ) ||
            (any && keys.every((k) => r.number(k) == null))) {
          throw StateError(
            'Indica importes o cantidades válidos; vacío significa desconocido.',
          );
        }
      }

      switch (r.kind) {
        case ProfitParameterKind.identity:
          require(['company_group', 'site']);
          if (!r.text('site').startsWith('site:')) {
            throw StateError(
              'La identidad debe terminar en una planta de Operación.',
            );
          }
        case ProfitParameterKind.vehicle:
          require(['unit']);
          nonnegative([
            'fuel_cost_per_km',
            'maintenance_cost_per_km',
            'fixed_cost_per_service',
            'optional_cost_per_hour',
            'hours_per_service',
          ], any: true);
          if (r.number('optional_cost_per_hour') != null &&
              r.number('hours_per_service') == null) {
            throw StateError('Indica las horas estándar por servicio.');
          }
        case ProfitParameterKind.labor:
          require(['company', 'role', 'basis']);
          nonnegative([
            'labor_cost_per_hour',
            'labor_cost_per_day',
            'period_labor_cost',
            'working_days',
            'workers',
            'hours_per_service',
          ]);
          if (!['hour', 'day', 'dedicated'].contains(r.text('basis')) ||
              r.text('basis') == 'hour' &&
                  r.number('labor_cost_per_hour') == null ||
              r.text('basis') == 'day' &&
                  r.number('labor_cost_per_day') == null ||
              r.text('basis') == 'dedicated' &&
                  (r.number('period_labor_cost') == null ||
                      (r.number('working_days') ?? 0) <= 0)) {
            throw StateError('Define tarifa y base laboral completas.');
          }
          if (r.text('basis') != 'hour' &&
              ((r.number('workers') ?? 0) <= 0 ||
                  !['5', '6', '7'].contains(r.text('week_days')))) {
            throw StateError(
              'Indica personal dedicado y días laborables por semana (5, 6 o 7).',
            );
          }
        case ProfitParameterKind.process:
          require(['company', 'material', 'process', 'kg_basis']);
          nonnegative(['cost_per_kg'], any: true);
          if (!['received', 'activity'].contains(r.text('kg_basis'))) {
            throw StateError('Selecciona la base física del proceso.');
          }
        case ProfitParameterKind.recovery:
          require(['company', 'material']);
          ProfitReview(
            recipes: {'rule': ProfitRecipe.fromJson(r.data)},
          ).validate();
        case ProfitParameterKind.activity:
          require(['company', 'measure', 'subject']);
          nonnegative(['quantity'], any: true);
          if (!['hours', 'kg'].contains(r.text('measure')) || r.to != r.from) {
            throw StateError('La actividad debe pertenecer a un solo día.');
          }
        case ProfitParameterKind.account:
          require(['company', 'line', 'block', 'basis']);
          nonnegative(['rate', 'quantity', 'months'], any: true);
          if (r.number('rate') == null ||
              r.number('quantity') == null ||
              ![
                'monthly',
                'annual',
                'service',
                'tonne',
                'kg',
                'once',
              ].contains(r.text('basis')) ||
              ![
                'income',
                'value',
                'containers',
                'payroll',
                'administration',
                'training',
                'disposal',
                'scale',
                'fuel',
                'transport',
                'maintenance',
                'process',
                'other',
                'overhead',
              ].contains(r.text('block'))) {
            throw StateError(
              'Indica concepto, importe, cantidad y periodicidad válidos.',
            );
          }
        case ProfitParameterKind.coverage:
          require(['company', 'block']);
          if (![
            'income',
            'fuel',
            'transport',
            'payroll',
            'process',
            'maintenance',
            'other',
            'overhead',
          ].contains(r.text('block'))) {
            throw StateError('Bloque inválido.');
          }
      }
      for (final other in rules) {
        if (other.id == r.id ||
            r.from.isAfter(other.to ?? DateTime(9999)) ||
            other.from.isAfter(r.to ?? DateTime(9999))) {
          continue;
        }
        if (other.scope == r.scope ||
            r.kind == ProfitParameterKind.identity &&
                other.kind == r.kind &&
                r.origins
                    .toSet()
                    .intersection(other.origins.toSet())
                    .isNotEmpty) {
          throw StateError(
            'Hay vigencias superpuestas para ${r.scope}. Cierra la vigencia anterior antes de crear otra.',
          );
        }
      }
    }
  }
}

enum ProfitSourceType { actual, allocated, estimated, missing }

class ProfitComponent {
  final String id, block, reference, rule;
  final DateTime date;
  final double? amount;
  final ProfitSourceType sourceType;
  final double confidence;
  final String vehicle, line, basisLevel;
  final bool sharedSupport;
  const ProfitComponent({
    required this.id,
    required this.block,
    required this.date,
    required this.amount,
    required this.sourceType,
    required this.reference,
    required this.rule,
    required this.confidence,
    this.vehicle = '',
    this.line = '',
    this.basisLevel = 'source',
    this.sharedSupport = false,
  });
  ProfitRow toJson() => {
    'id': id,
    'block': block,
    'date': profitDateText(date),
    'amount': amount,
    'source_type': sourceType.name,
    'source_reference': reference,
    'calculation_rule': rule,
    'confidence': confidence,
    'vehicle': vehicle,
    'line': line,
    'basis_level': basisLevel,
    'shared_support': sharedSupport,
  };
}

/// The monetary percentages describe KNOWN amounts, never an invented
/// denominator for unknown costs. Block coverage is reported independently.
class ProfitOperatingResult {
  final List<ProfitComponent> components;
  final List<String> alerts;
  final String group;
  ProfitOperatingResult(
    this.components, {
    this.alerts = const [],
    this.group = '',
  });
  Iterable<ProfitComponent> inBlock(String block) =>
      components.where((c) => c.block == block);
  double known(String block) =>
      inBlock(block).fold(0, (s, c) => s + (c.amount ?? 0));
  bool missing(String block) => inBlock(block).any((c) => c.amount == null);
  double? total(String block) =>
      inBlock(block).every((c) => c.amount == null) ? null : known(block);
  static const costBlocks = [
    'purchase',
    'fuel',
    'transport',
    'payroll',
    'process',
    'maintenance',
    'other',
    'containers',
    'administration',
    'training',
    'disposal',
    'scale',
  ];
  double? get operations =>
      components.any(
        (c) =>
            costBlocks.contains(c.block) &&
            c.block != 'purchase' &&
            c.amount != null,
      )
      ? costBlocks
            .where((b) => b != 'purchase')
            .fold<double>(0, (s, b) => s + known(b))
      : null;
  double get costs => costBlocks.fold(0, (s, b) => s + known(b));
  double get value => known('value') + known('income');
  bool get hasValue => components.any(
    (c) =>
        ['value', 'income'].contains(c.block) &&
        c.amount != null &&
        c.amount! > 0,
  );
  double? get contribution => hasValue ? value - costs : null;
  double? get afterOverhead =>
      contribution == null ? null : contribution! - known('overhead');
  double? get margin =>
      contribution == null || value <= 0 ? null : contribution! / value;
  int get missingCount => components.where((c) => c.amount == null).length;
  bool get partial => missingCount > 0;
  Set<String> get blocks => components.map((c) => c.block).toSet();
  double get blockCoverage => blocks.isEmpty
      ? 0
      : blocks.where((b) => !missing(b)).length / blocks.length;
  double amountOf(ProfitSourceType type) => components
      .where((c) => c.sourceType == type)
      .fold(0, (s, c) => s + (c.amount?.abs() ?? 0));
  double get knownAmount =>
      components.fold(0, (s, c) => s + (c.amount?.abs() ?? 0));
  double get verifiedShare => knownAmount == 0
      ? 0
      : (amountOf(ProfitSourceType.actual) +
                amountOf(ProfitSourceType.allocated)) /
            knownAmount;
  double get confidence => knownAmount == 0
      ? 0
      : components.fold<double>(
              0,
              (s, c) => s + (c.amount?.abs() ?? 0) * c.confidence,
            ) /
            knownAmount *
            blockCoverage;
  ProfitRow toJson() => {
    'components': components.map((c) => c.toJson()).toList(),
    'contribution': contribution,
    'after_overhead': afterOverhead,
    'partial': partial,
    'block_coverage': blockCoverage,
    'verified_share_of_known_amount': verifiedShare,
    'confidence': confidence,
    'group': group,
    'alerts': alerts,
  };
}

/// Replaces an operational concept only inside its new validity. Prior and
/// future conditions survive; the existing master CAS/history applies as usual.
List<ProfitParameter> replaceProfitAccountConcept(
  ProfitMaster master,
  ProfitParameter next,
) {
  final result = <ProfitParameter>[];
  for (final previous in master.rules) {
    final last = previous.to ?? DateTime(9999, 12, 31),
        nextLast = next.to ?? DateTime(9999, 12, 31);
    if (previous.scope != next.scope ||
        next.from.isAfter(last) ||
        previous.from.isAfter(nextLast)) {
      result.add(previous);
      continue;
    }
    if (previous.from.isBefore(next.from)) {
      result.add(
        ProfitParameter(
          id: previous.id,
          kind: previous.kind,
          from: previous.from,
          to: next.from.subtract(const Duration(days: 1)),
          note: previous.note,
          data: previous.data,
        ),
      );
    }
    if (last.isAfter(nextLast)) {
      result.add(
        ProfitParameter(
          id: '${previous.id}:after:${next.id}',
          kind: previous.kind,
          from: nextLast.add(const Duration(days: 1)),
          to: previous.to,
          note: previous.note,
          data: previous.data,
        ),
      );
    }
  }
  return [...result, next];
}
