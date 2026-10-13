import '../../mayoreo/mayoreo_expected_collections.dart';
import '../operating_program/operating_program_models.dart';
import 'expected_income_models.dart';

class IncomeCollectionPrintRow {
  final String id, client, document, material, type, status;
  final DateTime date;
  final int pendingCents;
  final bool requiresShipment;
  const IncomeCollectionPrintRow({
    required this.id,
    required this.client,
    required this.document,
    required this.material,
    required this.type,
    required this.status,
    required this.date,
    required this.pendingCents,
    required this.requiresShipment,
  });
}

/// A collection checklist from the reconciled projection, not a second query.
/// Raw Mayoreo accounts provide the document number for linked sales only;
/// amounts always remain those already reconciled in the income projection.
class ExpectedIncomeCollectionReport {
  final List<IncomeCollectionPrintRow> rows;
  const ExpectedIncomeCollectionReport._(this.rows);

  factory ExpectedIncomeCollectionReport({
    required ExpectedIncomeProjection projection,
    required List<MayoreoExpectedCollection> sourceCollections,
    required DateTime week,
    required DateTime generatedAt,
  }) {
    final start = incomeDay(week),
        end = incomeDay(week).add(const Duration(days: 7));
    final today = incomeDay(generatedAt);
    bool inWeek(DateTime? date) =>
        date != null &&
        !incomeDay(date).isBefore(start) &&
        incomeDay(date).isBefore(end);
    String status(DateTime date) => incomeDay(date).isBefore(today)
        ? 'Vencido'
        : incomeDay(date) == today
        ? 'Cobrar hoy'
        : 'Por cobrar';
    final documents = {
      for (final c in sourceCollections)
        if (c.document.trim().isNotEmpty) c.accountId: c.document.trim(),
    };
    final rows = <IncomeCollectionPrintRow>[];
    for (final c in projection.collections) {
      if (c.pendingCents <= 0 || !inWeek(c.dueDate)) continue;
      rows.add(
        IncomeCollectionPrintRow(
          id: 'collection:${c.accountId}',
          client: c.client,
          document: c.document.trim().isEmpty
              ? 'Sin documento'
              : c.document.trim(),
          material: incomeMaterialName(
            incomeMaterial(c.material) ?? c.material,
          ),
          type: 'Fiscal',
          status: status(c.dueDate),
          date: incomeDay(c.dueDate),
          pendingCents: c.pendingCents,
          requiresShipment: false,
        ),
      );
    }
    for (final r in projection.rows) {
      if (!r.ordinary ||
          r.pendingCents <= 0 ||
          r.paymentType == null ||
          !inWeek(r.collectionDate)) {
        continue;
      }
      final pendingShipment = r.sale == null && !r.shipment.isShipped;
      final document = documents[r.sale?.id];
      final reference =
          document ??
          (r.sale?.ticket.trim().isNotEmpty == true
              ? 'Venta ${r.sale!.ticket.trim()}'
              : 'Embarque ${programDate(r.shipment.shipDate)}${pendingShipment ? '' : ' / sin documento'}');
      final types = r.pendingByType.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toList();
      final type = types.length == 1 ? types.single : 'MIXTO';
      rows.add(
        IncomeCollectionPrintRow(
          id: 'shipment:${r.shipment.id}',
          client: r.shipment.clientName,
          document: reference,
          material: incomeMaterialName(r.shipment.materialCode),
          type: switch (type) {
            'EFECTIVO' => 'Efectivo',
            'FISCAL' => 'Fiscal',
            _ => 'Mixto',
          },
          status: pendingShipment
              ? r.shipment.status == 'planeado'
                    ? 'Por confirmar y embarcar'
                    : 'Por embarcar'
              : status(r.collectionDate!),
          date: incomeDay(r.collectionDate!),
          pendingCents: r.pendingCents,
          requiresShipment: pendingShipment,
        ),
      );
    }
    rows.sort((a, b) {
      for (final value in [
        a.date.compareTo(b.date),
        incomeKey(a.client).compareTo(incomeKey(b.client)),
        a.document.compareTo(b.document),
        a.id.compareTo(b.id),
      ]) {
        if (value != 0) return value;
      }
      return 0;
    });
    return ExpectedIncomeCollectionReport._(List.unmodifiable(rows));
  }

  List<IncomeCollectionPrintRow> get receivables =>
      rows.where((r) => !r.requiresShipment).toList();
  List<IncomeCollectionPrintRow> get expected =>
      rows.where((r) => r.requiresShipment).toList();
  int get total => rows.fold(0, (sum, r) => sum + r.pendingCents);

  void validate(ExpectedIncomeProjection projection) {
    if (total != projection.current.salesTotal) {
      throw StateError(
        'El desglose de cobranza no coincide con los cobros de la semana. Actualiza la proyección antes de exportar.',
      );
    }
  }
}
