import '../expected_income/expected_income_models.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_models.dart';

/// The PDF scope deliberately excludes expense tickets, including from totals.
WeeklyExpensePlan expenseReportPlan(WeeklyExpensePlan plan) => plan.copyWith(
  payments: plan.payments.where((r) => r.source != 'ticket').toList(),
);

class FlowIncomeDetail {
  final String id, client, reference, material, type;
  final DateTime? date;
  final int amount;
  final bool financing;
  const FlowIncomeDetail({
    required this.id,
    required this.client,
    required this.reference,
    required this.material,
    required this.type,
    required this.date,
    required this.amount,
    this.financing = false,
  });
}

/// Uses the already reconciled income projection, including Mayoreo collections
/// only once. Palomar is one possible draw, split by channel, without a date.
class WeeklyCashFlowReport {
  final ExpectedIncomeProjection projection;
  final WeeklyCashFlow flow;
  final List<FlowIncomeDetail> incomes;

  factory WeeklyCashFlowReport(
    ExpectedIncomeProjection projection,
    WeeklyExpensePlan plan,
  ) {
    final end = plan.week.add(const Duration(days: 7));
    bool inWeek(DateTime? date) =>
        date != null && !date.isBefore(plan.week) && date.isBefore(end);
    final incomes =
        <FlowIncomeDetail>[
          for (final r in projection.rows)
            if (r.ordinary &&
                r.pendingCents > 0 &&
                r.paymentType != null &&
                inWeek(r.collectionDate))
              for (final part in r.pendingByType.entries)
                if (part.value > 0)
                  FlowIncomeDetail(
                    id: 'shipment:${r.shipment.id}${r.allocationApplied ? ':${part.key}' : ''}',
                    client: r.shipment.clientName,
                    reference: r.sale == null
                        ? 'Embarque ${programDate(r.shipment.shipDate)} · ${r.state.label}'
                        : r.sale!.ticket.isEmpty
                        ? 'Venta embarcada'
                        : 'Venta ${r.sale!.ticket}',
                    material: incomeMaterialName(r.shipment.materialCode),
                    type: part.key,
                    date: r.collectionDate,
                    amount: part.value,
                  ),
          for (final c in projection.collections)
            if (c.pendingCents > 0 && inWeek(c.dueDate))
              FlowIncomeDetail(
                id: 'collection:${c.accountId}',
                client: c.client,
                reference:
                    'Cobranza Mayoreo${c.document.isEmpty ? '' : ' · ${c.document}'}',
                material: incomeMaterialName(
                  incomeMaterial(c.material) ?? c.material,
                ),
                type: 'FISCAL',
                date: c.dueDate,
                amount: c.pendingCents,
              ),
          for (final type in projection.current.financingByType.entries)
            if (type.value > 0)
              FlowIncomeDetail(
                id: 'palomar:${type.key}',
                client: 'EL PALOMAR',
                reference: 'Disposición proyectada',
                material: '-',
                type: type.key,
                date: null,
                amount: type.value,
                financing: true,
              ),
        ]..sort((a, b) {
          final date = a.date == null
              ? b.date == null
                    ? 0
                    : 1
              : b.date == null
              ? -1
              : a.date!.compareTo(b.date!);
          if (date != 0) return date;
          final client = a.client.toLowerCase().compareTo(
            b.client.toLowerCase(),
          );
          return client != 0 ? client : a.id.compareTo(b.id);
        });
    final totals = IncomeTotals();
    for (final r in incomes) {
      if (r.financing) {
        totals.addFinancing(r.type, r.amount);
      } else {
        totals.add(r.type, r.amount);
      }
    }
    for (final type in {
      ...totals.byType.keys,
      ...projection.current.byType.keys,
    }) {
      if ((totals.byType[type] ?? 0) !=
              (projection.current.byType[type] ?? 0) ||
          (totals.financingByType[type] ?? 0) !=
              (projection.current.financingByType[type] ?? 0)) {
        throw StateError(
          'El desglose de ingresos no coincide con los totales de la semana. Actualiza la proyección antes de exportar.',
        );
      }
    }
    return WeeklyCashFlowReport._(
      projection,
      WeeklyCashFlow(projection.current, expenseReportPlan(plan)),
      incomes,
    );
  }
  const WeeklyCashFlowReport._(this.projection, this.flow, this.incomes);
}
