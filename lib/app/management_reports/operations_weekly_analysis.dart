import '../maintenance/maintenance_statuses.dart';
import 'expenses_weekly_analysis.dart';

/// Raw source rows are also injectable for offline report verification.
class OperationsWeeklySource {
  const OperationsWeeklySource({
    this.orders = const [],
    this.purchases = const [],
    this.transformations = const [],
    this.legacyProduction = const [],
  });
  final List<Map<String, dynamic>> orders,
      purchases,
      transformations,
      legacyProduction;
}

class OperationsOtCost {
  OperationsOtCost(this.order, this.purchases);
  final Map<String, dynamic> order;
  final ExpensesWeeklySummary purchases;
  String get id => _text(order['id']);
  String get folio => _label(order['ot_folio'], 'Sin folio');
  String get area => _label(order['area_label'], 'Sin area');
  String get equipment => _label(order['equipment_label'], 'Sin equipo');
  String get responsible => _label(
    order['assigned_to_name'],
    _label(order['mechanic_name'], 'Sin responsable'),
  );
  String get status => maintenanceStatusLabel(order['status']);
  double? get estimated => _positive(order['cost_estimated_total']);
  // The OT editor persists zero for an unfilled cost. It is not proven savings.
  double? get actual => _positive(order['cost_actual_total']);
  double? get variance =>
      estimated == null || actual == null ? null : actual! - estimated!;
}

class OperationsProductionRow {
  const OperationsProductionRow({
    required this.date,
    required this.shift,
    required this.materialKey,
    required this.material,
    required this.units,
    required this.kg,
    required this.legacy,
  });
  final DateTime date;
  final String shift, materialKey, material;
  final int? units;
  final double? kg;
  final bool legacy;
}

class OperationsProductionSummary {
  OperationsProductionSummary(this.rows);
  final List<OperationsProductionRow> rows;
  double get kg => rows.fold(0, (s, r) => s + (r.kg ?? 0));
  int get units => rows.fold(0, (s, r) => s + (r.units ?? 0));
  int get missingWeight => rows.where((r) => r.kg == null).length;
  int get missingUnits => rows.where((r) => r.units == null).length;
  bool get hasWeight => rows.any((r) => r.kg != null);
  bool get hasUnits => rows.any((r) => r.units != null);
}

class OperationsWeeklyAnalysis {
  OperationsWeeklyAnalysis(this.source, DateTime generatedAt)
    : cut = ExpensesWeeklyCut(generatedAt) {
    final orders = source.orders.where((r) {
      final date = _date(r['requested_at']);
      return date == null || !date.isAfter(cut.end);
    }).toList();
    final byId = {for (final r in orders) _text(r['id']): r};
    final byFolio = <String, List<Map<String, dynamic>>>{};
    for (final r in orders) {
      final folio = _text(r['ot_folio']);
      if (folio.isNotEmpty) byFolio.putIfAbsent(folio, () => []).add(r);
    }
    final linked = <ExpensesWeeklyOrder>[];
    final otIdByPurchase = <String, String>{};
    final unresolvedIds = <String>{};
    for (final r in source.purchases) {
      final id = _text(r['linked_ot_id']);
      final folio = _text(r['linked_ot_folio']);
      if (id.isEmpty && folio.isEmpty) continue;
      // Prefer the FK. A stale FK must not be repaired by guessing a folio.
      final candidates = byFolio[folio] ?? [];
      final ot = id.isNotEmpty
          ? byId[id]
          : candidates.length == 1
          ? candidates.single
          : null;
      final row = _purchase(
        r,
        ot == null
            ? _label(folio, 'OT sin resolver')
            : _label(ot['ot_folio'], 'OT sin folio'),
      );
      if (row == null) continue;
      linked.add(row);
      if (ot == null) {
        unresolvedIds.add(row.id);
      } else {
        otIdByPurchase[row.id] = _text(ot['id']);
      }
    }
    expenses = ExpensesWeeklyAnalysis(linked, cut);
    unresolvedPurchases = [
      ...expenses.current.rows,
      ...expenses.pending,
      ...expenses.undatedPurchases,
    ].where((r) => unresolvedIds.contains(r.id)).toList();
    final purchasesByOt = <String, List<ExpensesWeeklyOrder>>{};
    for (final r in expenses.current.rows) {
      final id = otIdByPurchase[r.id];
      if (id != null) purchasesByOt.putIfAbsent(id, () => []).add(r);
    }
    costs =
        orders
            .where(
              (r) =>
                  !isMaintenanceClosedStatus(
                    normalizeMaintenanceStatus(r['status']),
                  ) ||
                  cut.contains(_date(r['requested_at'])) ||
                  cut.contains(_date(r['updated_at'])) ||
                  purchasesByOt.containsKey(_text(r['id'])),
            )
            .map(
              (r) => OperationsOtCost(
                r,
                ExpensesWeeklySummary(purchasesByOt[_text(r['id'])] ?? []),
              ),
            )
            .toList()
          ..sort((a, b) {
            final cost = b.purchases.actual.compareTo(a.purchases.actual);
            return cost != 0 ? cost : a.folio.compareTo(b.folio);
          });
    currentProduction = OperationsProductionSummary(_production(false));
    previousProduction = OperationsProductionSummary(_production(true));
  }

  final OperationsWeeklySource source;
  final ExpensesWeeklyCut cut;
  late final ExpensesWeeklyAnalysis expenses;
  late final List<OperationsOtCost> costs;
  late final List<ExpensesWeeklyOrder> unresolvedPurchases;
  late final OperationsProductionSummary currentProduction, previousProduction;

  Map<String, List<OperationsProductionRow>> productionByMaterial({
    bool previous = false,
  }) {
    final groups = <String, List<OperationsProductionRow>>{};
    for (final r in (previous ? previousProduction : currentProduction).rows) {
      groups.putIfAbsent(r.materialKey, () => []).add(r);
    }
    return groups;
  }

  List<OperationsProductionRow> _production(bool previous) {
    final start = previous ? cut.previousStart : cut.start;
    final end = previous ? cut.previousEnd : cut.end;
    bool inWindow(Map<String, dynamic> r) {
      final date = _date(r['op_date']);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }

    final runs = source.transformations.where(inWindow).toList();
    final result = <OperationsProductionRow>[];
    // One source for cardboard in each compared window, including incomplete
    // V2 runs: missing outputs must be exposed rather than replaced by legacy.
    final hasCardboard = runs.any(
      (r) =>
          _text((r['general_material'] as Map?)?['code']).toUpperCase() ==
          'CARTON',
    );
    for (final r in runs) {
      final outputs = (r['outputs'] as List? ?? []).cast<Map>();
      for (final output in outputs) {
        final material = output['commercial_material'] as Map?;
        final code = _productionCode(_text(material?['code']));
        result.add(
          OperationsProductionRow(
            date: _date(r['op_date'])!,
            shift: _shift(r['shift']),
            materialKey: code.isNotEmpty
                ? code
                : _label(output['commercial_material_id'], 'SIN_MATERIAL'),
            material: _label(material?['name'], _label(code, 'Sin material')),
            units: _positive(output['output_unit_count'])?.toInt(),
            kg: _positive(output['output_weight_kg']),
            legacy: false,
          ),
        );
      }
    }
    if (!hasCardboard) {
      for (final r in source.legacyProduction.where(inWindow)) {
        final units = _positive(r['bale_count'])?.toInt();
        if (units == null) continue;
        final code = _productionCode(_text(r['bale_material']));
        result.add(
          OperationsProductionRow(
            date: _date(r['op_date'])!,
            shift: _shift(r['shift']),
            materialKey: _label(code, 'SIN_MATERIAL'),
            material: _legacyMaterial(code),
            units: units,
            kg: null,
            legacy: true,
          ),
        );
      }
    }
    return result;
  }

  List<String> get warnings => [
    if (expenses.current.withoutActual > 0)
      '${expenses.current.withoutActual} OC(s) compradas ligadas a OT sin importe real; el gasto semanal es parcial.',
    if (expenses.undatedPurchases.isNotEmpty)
      '${expenses.undatedPurchases.length} OC(s) compradas sin fecha de compra; no se asignan a una semana.',
    if (unresolvedPurchases.isNotEmpty)
      '${unresolvedPurchases.length} OC(s) con referencia de OT no resuelta; revisar el vinculo en Compras.',
    if (costs.any((r) => r.actual == null))
      '${costs.where((r) => r.actual == null).length} OT(s) del seguimiento sin costo real positivo registrado; no se interpretan como ahorro.',
    if (currentProduction.missingWeight > 0)
      '${currentProduction.missingWeight} salida(s) de produccion sin peso comparable; se conservan sus unidades y no se inventan kilogramos.',
    if (currentProduction.rows.any((r) => r.legacy) ||
        previousProduction.rows.any((r) => r.legacy))
      'Se uso produccion historica de pacas en un corte sin transformaciones de carton; su peso no esta disponible.',
    if (source.transformations.any(
      (r) =>
          cut.contains(_date(r['op_date'])) &&
          (r['outputs'] as List? ?? []).isEmpty,
    ))
      'Hay transformaciones de la semana sin salidas registradas; completar Produccion.',
    if (currentProduction.rows.any((r) => r.shift == 'Sin turno'))
      'Hay produccion sin turno identificado; permanece incluida en el total.',
  ];
}

ExpensesWeeklyOrder? _purchase(Map<String, dynamic> r, String ot) {
  final date = _date(r['order_date']);
  if (date == null) return null;
  final lines = (r['lines'] as List? ?? []).cast<Map>();
  final lineEstimate = lines.fold<double>(
    0,
    (s, l) =>
        s +
        (_positive(l['line_total']) ??
            (_positive(l['qty']) ?? 0) * (_positive(l['amount']) ?? 0)),
  );
  return ExpensesWeeklyOrder(
    id: _text(r['id']),
    folio: _label(r['folio'], 'Sin folio'),
    orderDate: date,
    status: _text(r['status']).toLowerCase(),
    vendor: _label(r['quote_vendor_name'], 'Sin proveedor'),
    target: _label(r['target_label'], 'Sin destino'),
    concept: _label(
      r['linked_material_label'],
      lines.isEmpty
          ? 'Sin concepto'
          : _label(lines.first['description'], 'Sin concepto'),
    ),
    ot: ot,
    estimated:
        _positive(r['estimated_total']) ??
        (lineEstimate > 0 ? lineEstimate : null),
    actual: _positive(r['actual_total']),
    purchasedAt: _date(r['purchased_at']),
    sentToCashAt: _date(r['sent_to_cash_at']),
    createdAt: _date(r['created_at']),
  );
}

String _text(Object? value) => (value ?? '').toString().trim();
String _label(Object? value, String fallback) =>
    _text(value).isEmpty ? fallback : _text(value);
DateTime? _date(Object? value) => DateTime.tryParse(_text(value))?.toLocal();
double? _positive(Object? value) {
  final n = double.tryParse(_text(value));
  return n != null && n.isFinite && n > 0 ? n : null;
}

String _shift(Object? value) => switch (_text(value).toUpperCase()) {
  'DAY' || 'DIA' => 'Dia',
  'NIGHT' || 'NOCHE' => 'Noche',
  _ => 'Sin turno',
};
String _productionCode(String code) => switch (code.toUpperCase()) {
  'BALE_CLEAN' => 'PACA_LIMPIA',
  'BALE_NATIONAL' => 'PACA_NACIONAL',
  'BALE_AMERICAN' => 'PACA_AMERICANA',
  'CAPLE' => 'PACA_CAPLE',
  'BALE_TRASH' => 'PACA_BASURA',
  _ => code.toUpperCase(),
};
String _legacyMaterial(String code) => switch (code) {
  'PACA_LIMPIA' => 'Paca limpia',
  'PACA_NACIONAL' => 'Paca nacional',
  'PACA_AMERICANA' => 'Paca americana',
  'PACA_CAPLE' => 'Paca caple',
  'PACA_BASURA' => 'Paca basura',
  _ => _label(code, 'Sin material'),
};
