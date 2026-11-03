import '../expected_income/expected_income_models.dart';
import '../operating_program/operating_program_models.dart';

class FlowIncomeDetail {
  final String id, client, reference, material, type;
  final DateTime? date;
  final int amount;
  final bool financing, carriedOver;
  const FlowIncomeDetail({
    required this.id,
    required this.client,
    required this.reference,
    required this.material,
    required this.type,
    required this.date,
    required this.amount,
    this.financing = false,
    this.carriedOver = false,
  });
}

/// Cash-flow scope over reconciled receivables, without changing their due dates
/// or the Monday-Sunday buckets in Ingresos. Sunday Palomar receipts cannot fund
/// this week's commitments. Prior unpaid receivables join the weekly total but
/// need a new agreed date before funding a particular day.
class WeeklyCashFlowIncome {
  final IncomeTotals totals, carryover, excludedPalomar;
  final Map<DateTime, IncomeTotals> timeline;
  final List<FlowIncomeDetail> incomes;

  factory WeeklyCashFlowIncome(ExpectedIncomeProjection source, DateTime week) {
    final start = incomeDay(week),
        end = incomeDay(week).add(const Duration(days: 7));
    bool inWeek(DateTime? date) =>
        date != null && !date.isBefore(start) && date.isBefore(end);
    bool prior(DateTime? date) => date != null && date.isBefore(start);
    final totals = _copyTotals(source.current);
    final carryover = IncomeTotals(), excludedPalomar = IncomeTotals();
    final timeline = {
      for (final e in source.timeline.entries) e.key: _copyTotals(e.value),
    };
    final incomes = <FlowIncomeDetail>[];

    for (final row in source.rows) {
      if (!row.ordinary || row.pendingCents <= 0 || row.paymentType == null) {
        continue;
      }
      final overdue =
          prior(row.collectionDate) &&
          (row.state == IncomeState.shipped ||
              row.state == IncomeState.receivable);
      if (!inWeek(row.collectionDate) && !overdue) continue;
      final reference = row.estimatedFromBales
          ? '${row.sale == null ? 'Embarque ${programDate(row.shipment.shipDate)}' : 'Venta ${row.sale!.ticket}'} · Importe estimado'
          : row.sale == null
          ? 'Embarque ${programDate(row.shipment.shipDate)} · ${row.state.label}'
          : row.sale!.ticket.isEmpty
          ? 'Venta embarcada'
          : 'Venta ${row.sale!.ticket}';
      for (final part in row.pendingByType.entries.where((p) => p.value > 0)) {
        if (overdue) {
          totals.add(part.key, part.value);
          carryover.add(part.key, part.value);
        }
        incomes.add(
          FlowIncomeDetail(
            id: 'shipment:${row.shipment.id}${row.allocationApplied ? ':${part.key}' : ''}',
            client: row.shipment.clientName,
            reference: overdue
                ? 'Vencido ${programDate(row.collectionDate!)} · $reference'
                : reference,
            material: incomeMaterialName(row.shipment.materialCode),
            type: part.key,
            date: overdue ? null : row.collectionDate,
            amount: part.value,
            carriedOver: overdue,
          ),
        );
      }
    }
    // These accounts have already been deduplicated against linked shipments.
    for (final collection in source.collections) {
      final overdue = prior(collection.dueDate);
      if (collection.pendingCents <= 0 ||
          (!inWeek(collection.dueDate) && !overdue)) {
        continue;
      }
      final reference =
          'Cobranza Mayoreo${collection.document.isEmpty ? '' : ' · ${collection.document}'}';
      if (overdue) {
        totals.add('FISCAL', collection.pendingCents);
        carryover.add('FISCAL', collection.pendingCents);
      }
      incomes.add(
        FlowIncomeDetail(
          id: 'collection:${collection.accountId}',
          client: collection.client,
          reference: overdue
              ? 'Vencido ${programDate(collection.dueDate)} · $reference'
              : reference,
          material: incomeMaterialName(
            incomeMaterial(collection.material) ?? collection.material,
          ),
          type: 'FISCAL',
          date: overdue ? null : collection.dueDate,
          amount: collection.pendingCents,
          carriedOver: overdue,
        ),
      );
    }
    for (final part in source.current.financingByType.entries) {
      if (part.value <= 0) continue;
      final date = source.palomar.dateFor(part.key);
      if (date != null && (date.weekday == DateTime.sunday || !inWeek(date))) {
        totals.addFinancing(part.key, -part.value);
        excludedPalomar.addFinancing(part.key, part.value);
        timeline[date]?.addFinancing(part.key, -part.value);
        continue;
      }
      incomes.add(
        FlowIncomeDetail(
          id: 'palomar:${part.key}',
          client: 'EL PALOMAR',
          reference: 'Disposición proyectada',
          material: '-',
          type: part.key,
          date: date,
          amount: part.value,
          financing: true,
        ),
      );
    }
    incomes.sort((a, b) {
      final date = a.date == null
          ? (b.date == null ? 0 : 1)
          : b.date == null
          ? -1
          : a.date!.compareTo(b.date!);
      if (date != 0) return date;
      final client = a.client.toLowerCase().compareTo(b.client.toLowerCase());
      return client != 0 ? client : a.id.compareTo(b.id);
    });
    return WeeklyCashFlowIncome._(
      totals,
      carryover,
      excludedPalomar,
      timeline,
      incomes,
    );
  }
  const WeeklyCashFlowIncome._(
    this.totals,
    this.carryover,
    this.excludedPalomar,
    this.timeline,
    this.incomes,
  );

  static IncomeTotals _copyTotals(IncomeTotals source) => IncomeTotals()
    ..byType.addAll(source.byType)
    ..financingByType.addAll(source.financingByType);
}
