import 'statement_models.dart';

/// Comparison of capture categories with economic recognition. Recorded and
/// linked amounts are gross cash movements, not additional deductible expenses.
class StatementExpenseCoverage {
  final String source, category;
  int count = 0;
  double recorded = 0, recognizedHere = 0, pending = 0, linked = 0;
  double linkedPending = 0, linkedIncludedPending = 0;
  final List<String> ids = [];
  StatementExpenseCoverage(this.source, this.category);
}

List<StatementExpenseCoverage> statementExpenseCoverage(StatementAnalysis a) {
  final entries = {for (final e in a.entries) e.fact.id: e};
  final groups = <String, StatementExpenseCoverage>{};
  for (final spec in [
    ('bank', 'Bancos', 'finanzas_bank_movements', 'movement_date', 'category'),
    ('vault', 'Bóveda', 'direction_vault_vouchers', 'voucher_date', 'rubric'),
    ('cash', 'Menudeo', 'men_cash_vouchers', 'voucher_date', 'rubric'),
  ]) {
    for (final r in a.bundle.rows(spec.$3)) {
      if (!a.bundle.period.includes(r[spec.$4])) continue;
      if (spec.$1 != 'bank' && r['voucher_type'] != 'expense') continue;
      final amount = stNumber(
        r[spec.$1 == 'bank' ? 'debit_amount' : 'total_amount'],
      );
      if (!amount.isFinite || amount <= 0) continue;
      final category = switch (stKey(r[spec.$5])) {
        'OPERATIVO' || 'OPERATIVOS' || 'GASTOS OPERATIVOS' => 'Operativos',
        'ADMINISTRATIVO' ||
        'ADMINISTRATIVOS' ||
        'GASTOS ADMINISTRATIVOS' => 'Administrativos',
        'SERVICIOS' => 'Servicios',
        _ => null,
      };
      if (category == null) continue;
      final key = '${spec.$2}|$category';
      final group = groups.putIfAbsent(
        key,
        () => StatementExpenseCoverage(spec.$2, category),
      );
      final id = '${spec.$1}:${r['id']}';
      final e = entries[id];
      group.count++;
      group.recorded += amount;
      group.ids.add(id);
      if (e == null || (e.pending && !e.account.affectsResult)) {
        group.pending += amount;
      } else if (e.account == StatementAccount.duplicate) {
        group.linked += amount;
        // Only current-period unresolved parents are included here. A payment
        // of an earlier invoice must not be advertised as this month's expense.
        final refs = e.decision?.duplicateOf.isNotEmpty == true
            ? [e.decision!.duplicateOf]
            : e.fact.references;
        if (refs.any(
          (id) =>
              entries[id]?.pending == true &&
              entries[id]?.account.affectsResult != true,
        )) {
          group.linkedPending += amount;
        }
        if (refs.any((id) => entries[id]?.includedPending == true)) {
          group.linkedIncludedPending += amount;
        }
      } else if (e.account == StatementAccount.operating ||
          e.account == StatementAccount.administrative) {
        group.recognizedHere += e.amount;
      }
    }
  }
  return groups.values.toList()..sort((a, b) {
    final source = a.source.compareTo(b.source);
    return source != 0 ? source : a.category.compareTo(b.category);
  });
}
