import 'package:flutter/material.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../contabilidad_theme.dart';
import 'statement_expense_coverage.dart';
import 'statement_models.dart';

/// Same Accounting auxiliary card, showing the economic source before cash
/// categories. Invoice expense must not appear to be missing because its bank
/// settlement correctly contributes zero additional expense.
class StatementRecognizedExpensesPanel extends StatelessWidget {
  final StatementAnalysis analysis;
  final String Function(num) money;
  const StatementRecognizedExpensesPanel({
    super.key,
    required this.analysis,
    required this.money,
  });
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<StatementEntry>>{};
    for (final e in analysis.entries.where(
      (e) => e.account.expense && e.account != StatementAccount.cost,
    )) {
      (groups['${e.fact.source} · ${e.account.label}'] ??= []).add(e);
    }
    final keys = groups.keys.toList()..sort();
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'GASTOS INCLUIDOS EN EL RESULTADO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cada gasto se reconoce en su fuente económica. Las facturas aparecen aquí aunque su pago bancario no agregue otro gasto. Los importes estimados ya están descontados.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.4,
              height: 1.4,
            ),
          ),
          for (final key in keys) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 18,
              runSpacing: 4,
              children: [
                Text(
                  key,
                  style: const TextStyle(
                    color: kContabilidadInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  money(groups[key]!.fold<double>(0, (s, e) => s + e.amount)),
                  style: const TextStyle(
                    color: kContabilidadInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (groups[key]!.any((e) => e.estimated))
              Text(
                'Incluye ${money(groups[key]!.where((e) => e.estimated).fold<double>(0, (s, e) => s + e.amount))} estimados.',
                style: const TextStyle(
                  color: kContabilidadMutedInk,
                  fontSize: 12.8,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class StatementExpenseCoveragePanel extends StatelessWidget {
  final List<StatementExpenseCoverage> rows;
  final String Function(num) money;
  const StatementExpenseCoveragePanel({
    super.key,
    required this.rows,
    required this.money,
  });

  @override
  Widget build(BuildContext context) => ContractGlassCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'REGISTRADO Y RECONOCIDO POR FUENTE',
          style: TextStyle(
            color: kContabilidadGlow,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Registrado son salidas según su categoría original, con los impuestos capturados. Reconocido aquí muestra el gasto operativo o administrativo que esa fuente aporta al resultado. Los pagos vinculados se revisan desde su factura y no se suman otra vez.',
          style: TextStyle(
            color: kContabilidadMutedInk,
            fontSize: 13.4,
            height: 1.4,
          ),
        ),
        for (final row in rows) ...[
          const SizedBox(height: 18),
          Text(
            '${row.source} · ${row.category} · ${row.count} movimientos',
            style: const TextStyle(
              color: kContabilidadInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _amount('Registrado', row.recorded),
              _amount('Reconocido aquí', row.recognizedHere),
              _amount('Por aclarar', row.pending),
              _amount('Pagos vinculados', row.linked),
            ],
          ),
          if (row.linkedIncludedPending > .009) ...[
            const SizedBox(height: 6),
            Text(
              '${money(row.linkedIncludedPending)} de los pagos vinculados corresponden a documentos pendientes de revisión cuyo gasto ya está incluido provisionalmente.',
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 12.8,
              ),
            ),
          ],
          if (row.linkedPending > .009) ...[
            const SizedBox(height: 6),
            Text(
              '${money(row.linkedPending)} de los pagos vinculados apuntan a documentos pendientes de este periodo.',
              style: const TextStyle(color: kContabilidadGlow, fontSize: 12.8),
            ),
          ],
        ],
        const SizedBox(height: 16),
        const Text(
          'Las columnas explican el tratamiento; no se suman entre sí. Un importe por aclarar puede corresponder a gasto, impuestos, nómina, activo, traspaso u otro periodo.',
          style: TextStyle(
            color: kContabilidadMutedInk,
            fontSize: 12.8,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _amount(String label, double amount) => SizedBox(
    width: 195,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: kContabilidadMutedInk, fontSize: 12.8),
        ),
        Text(
          money(amount),
          style: const TextStyle(
            color: kContabilidadInk,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
