import 'package:flutter/material.dart';

import '../../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../../shared/utils/number_formatters.dart';
import '../direction_shipments_store.dart';
import '../direction_theme.dart';
import '../operating_program/operating_program_models.dart';
import 'expected_income_models.dart';
import 'palomar_coverage.dart';
import 'palomar_weekly_dispatch.dart';

/// Informational weekly material totals; never writes shipments or income.
class PalomarCoverageView extends StatefulWidget {
  final ExpectedIncomeData data;
  final DirectionShipmentPlanningBundle bundle;
  final DateTime now;
  const PalomarCoverageView({
    super.key,
    required this.data,
    required this.bundle,
    required this.now,
  });

  @override
  State<PalomarCoverageView> createState() => _PalomarCoverageViewState();
}

class _PalomarCoverageViewState extends State<PalomarCoverageView> {
  String money(int value) => formatMoney(value / 100);
  Widget text(
    String value, {
    bool strong = false,
    bool warning = false,
    TextAlign? align,
  }) => Text(
    value,
    textAlign: align,
    style: TextStyle(
      color: warning
          ? kDirectionWarning
          : strong
          ? kDirectionSurfaceText
          : kDirectionMutedText,
      fontWeight: strong ? FontWeight.w800 : FontWeight.normal,
    ),
  );

  Widget table(List<List<String>> rows) => LayoutBuilder(
    builder: (context, constraints) {
      final widths = [
        constraints.maxWidth * .46,
        constraints.maxWidth * .27,
        constraints.maxWidth * .27,
      ];
      Widget row(List<String> values, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: ContractGridScaledRow(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < values.length; i++)
                SizedBox(
                  width: widths[i],
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 2 ? 0 : 12),
                    child: text(
                      values[i],
                      strong: strong,
                      align: i == 0 ? TextAlign.left : TextAlign.right,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      return Column(
        children: [
          row([
            'Material',
            'Cantidad por enviar',
            'Importe estimado',
          ], strong: true),
          const Divider(height: 1),
          for (final values in rows.take(rows.length - 1)) row(values),
          const Divider(height: 1),
          row(rows.last, strong: true),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final dispatch = projectPalomarWeeklyDispatch(
      data: widget.data,
      bundle: widget.bundle,
      now: widget.now,
    );
    final coverage = dispatch.coverage;
    final deadline = coverage.deadline;
    final canCalculate =
        deadline != null &&
        !deadline.isBefore(incomeDay(widget.now)) &&
        coverage.complete &&
        (dispatch.days.isNotEmpty || coverage.remaining == 0);
    final rows = <List<String>>[];
    final totals = <String, int>{};
    for (final material in dispatch.materials) {
      final sends = dispatch.days
          .map((d) => d.materials[material.catalogName])
          .whereType<PalomarCoverageSend>();
      final quantity = sends.fold<int>(0, (sum, s) => sum + s.quantity!);
      final value = sends.fold<int>(0, (sum, s) => sum + s.amount!);
      final unit = material.quote?.unit;
      final missingPrice = material.targetCents > 0 && material.quote == null;
      if (unit != null && quantity > 0) {
        totals.update(unit, (v) => v + quantity, ifAbsent: () => quantity);
      }
      rows.add([
        material.label == 'Limpio'
            ? 'Limpio (Ordinario de primera)'
            : material.label,
        missingPrice
            ? 'Falta precio'
            : '${formatDecimal(quantity, decimals: 0)}${unit == null ? '' : ' $unit'}',
        missingPrice ? 'Por calcular' : money(value),
      ]);
    }
    rows.add([
      'TOTAL SEMANAL',
      totals.isEmpty
          ? '—'
          : totals.entries
                .map((e) => '${formatDecimal(e.value, decimals: 0)} ${e.key}')
                .join(' · '),
      money(dispatch.proposedCents),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 30),
        text('Material por enviar esta semana', strong: true),
        const SizedBox(height: 6),
        text(
          'Semana del ${programDate(dispatch.week)} al ${programDate(dispatch.week.add(const Duration(days: 6)))}',
        ),
        if (deadline == null)
          text(
            'Define la fecha de recepción para calcular cuánto enviar.',
            warning: true,
          )
        else if (!canCalculate)
          text(
            !coverage.complete
                ? 'No fue posible calcular el saldo real de Mayoreo.'
                : 'Actualiza la fecha de recepción; no quedan días de envío disponibles.',
            warning: true,
          )
        else ...[
          text(
            'Saldo real por cubrir: ${money(coverage.remaining)} · al ${programDate(deadline)}',
          ),
          const SizedBox(height: 8),
          table(rows),
          text(
            'Referencia del saldo real. Los envíos y abonos previstos se descuentan cuando se aplican en Mayoreo.',
          ),
          if (coverage.remaining == 0)
            text('El saldo real de la cuenta ya está cubierto.')
          else if (dispatch.closing! > 0)
            text(
              'Faltan ${money(dispatch.closing!)} por cubrir; revisa los materiales sin precio.',
              warning: true,
            ),
          if (coverage.remaining > 0 && dispatch.historicalRecords == 0)
            text(
              'Sin historial reciente: reparto inicial de 20% del importe por material.',
            ),
        ],
      ],
    );
  }
}
