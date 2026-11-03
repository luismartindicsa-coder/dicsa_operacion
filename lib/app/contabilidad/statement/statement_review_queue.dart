import 'statement_models.dart';

enum StatementReviewLane {
  clarify('Datos por completar'),
  closing('Revisiones de cierre'),
  included('Ya incluidos en el contable');

  final String label;
  const StatementReviewLane(this.label);
}

class StatementReviewCase {
  final String id, relation;
  final List<StatementEntry> entries;
  final StatementReviewLane lane;
  const StatementReviewCase(this.id, this.entries, this.lane, this.relation);
  bool get grouped => entries.length > 1;
}

/// Navigation only: never changes recognition, amounts, saved reviews or the
/// closing gate. A linked document is still visible and independently editable.
List<StatementReviewCase> statementReviewQueue(StatementAnalysis a) {
  final entries = {for (final e in a.pending) e.fact.id: e};
  final parents = {for (final id in entries.keys) id: id};
  String root(String id) {
    while (parents[id] != id) {
      id = parents[id]!;
    }
    return id;
  }

  final relations = <String, String>{};
  void join(String left, String right, String reason) {
    if (!parents.containsKey(left) || !parents.containsKey(right)) return;
    final l = root(left), r = root(right);
    if (l != r) parents[r] = l;
    relations[left] = reason;
    relations[right] = reason;
  }

  final originals = <String, StatementRow>{};
  for (final spec in const {
    'bank': 'finanzas_bank_movements',
    'cash': 'men_cash_vouchers',
    'vault': 'direction_vault_vouchers',
  }.entries) {
    for (final r in a.bundle.rows(spec.value)) {
      originals['${spec.key}:${r['id']}'] = r;
    }
  }
  for (final e in entries.values) {
    for (final ref in e.fact.references) {
      join(e.fact.id, ref, 'Documentos vinculados en el registro');
    }
  }
  for (final r in a.bundle.rows('maintenance_purchase_orders')) {
    join(
      'po:${r['id']}',
      'ot:${r['linked_ot_id']}',
      'Orden de compra y orden de trabajo vinculadas',
    );
  }

  // A very narrow suggestion: a unique opposite cash movement on the same day
  // and amount explicitly described as exchange of coins on both sides.
  // Ambiguous matches are left separate; even unique matches are NOT settled.
  bool coinExchange(String id) {
    final r = originals[id];
    return r != null &&
        (id.startsWith('cash:') || id.startsWith('vault:')) &&
        stKey(r['comment']).contains('MONEDAS') &&
        entries[id]!.amount > 0 &&
        entries[id]!.fact.date != null;
  }

  final coins = entries.keys.where(coinExchange).toList();
  final candidates = <String, List<String>>{};
  for (final id in coins) {
    final e = entries[id]!;
    candidates[id] = coins.where((other) {
      final o = entries[other]!;
      return id.split(':').first != other.split(':').first &&
          e.fact.date == o.fact.date &&
          (e.amount - o.amount).abs() < .005 &&
          {
            stText(originals[id]!['voucher_type']),
            stText(originals[other]!['voucher_type']),
          }.containsAll({'deposit', 'expense'});
    }).toList();
  }
  for (final pair in candidates.entries) {
    if (pair.value.length == 1 && candidates[pair.value.single]?.length == 1) {
      join(
        pair.key,
        pair.value.single,
        'Posible cambio de monedas: misma fecha e importe. Confirmar relación.',
      );
    }
  }

  StatementReviewLane lane(StatementEntry e) {
    if (e.issue != null || e.fact.date == null) {
      return StatementReviewLane.clarify;
    }
    if (e.includedPending) return StatementReviewLane.included;
    final id = e.fact.id;
    if (id.startsWith('sale:') ||
        id.startsWith('retail:') ||
        id.startsWith('purchase:') ||
        id.startsWith('weighing:')) {
      return StatementReviewLane.clarify;
    }
    final r = originals[id];
    if (r != null) {
      final category = stKey(r['category'] ?? r['rubric']);
      if (category.isEmpty ||
          const {'OTRO', 'OTROS', 'AJUSTES'}.contains(category)) {
        return StatementReviewLane.clarify;
      }
    }
    // Captured categories, supporting documents, estimates and period coverage
    // are closing work, not a request to recapture the base movement.
    return StatementReviewLane.closing;
  }

  final groups = <String, List<StatementEntry>>{};
  for (final e in entries.values) {
    (groups[root(e.fact.id)] ??= []).add(e);
  }
  return [
    for (final group in groups.entries)
      StatementReviewCase(
        group.key,
        group.value,
        group.value.any((e) => lane(e) == StatementReviewLane.clarify)
            ? StatementReviewLane.clarify
            : group.value.every((e) => lane(e) == StatementReviewLane.included)
            ? StatementReviewLane.included
            : StatementReviewLane.closing,
        group.value
                .map((e) => relations[e.fact.id])
                .whereType<String>()
                .firstOrNull ??
            '',
      ),
  ];
}
