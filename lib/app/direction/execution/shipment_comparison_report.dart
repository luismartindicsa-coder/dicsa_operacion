import '../direction_shipments_store.dart';
import '../operating_program/operating_program_models.dart';

class ShipmentComparisonRow {
  final DirectionExecutionRow source;
  final bool future;
  ShipmentComparisonRow(this.source, DateTime asOf)
    : future = source.date.isAfter(DateTime(asOf.year, asOf.month, asOf.day));
  int? get planned => source.baseline;
  int? get actual => future ? null : source.actual;
  int? get difference =>
      planned == null || actual == null ? null : actual! - planned!;
  bool get confirmed => !future && source.confirmed;
  String get unit {
    final material = directionShipmentMaterialByCode(source.material);
    if (material == null) {
      throw StateError('Material sin unidad definida: ${source.material}');
    }
    return material.shortUnitLabel;
  }

  String get status => future
      ? 'Pendiente de ejecución'
      : !confirmed
      ? actual == null
            ? 'Sin captura'
            : 'Por confirmar'
      : actual == 0
      ? (planned == null ? 'Sin embarque confirmado' : 'Cancelado · real 0')
      : planned == null
      ? 'Adicional confirmado'
      : 'Embarcado · confirmado';
  String get detail => [
    status,
    if (confirmed && !source.confirmation!.agendaSynced)
      'Agenda pendiente de actualizar',
    if (confirmed && source.sourceChanged)
      'Origen cambió; revisar confirmación',
    if (confirmed && source.confirmation!.notes.trim().isNotEmpty)
      source.confirmation!.notes.trim(),
  ].join('\n');
}

/// Same reconciled groups as Real. An explicit zero and a missing reading are
/// different; the immutable confirmation baseline wins over the updated agenda.
class ShipmentComparisonReport {
  final DateTime week, generatedAt;
  final List<ShipmentComparisonRow> rows;
  ShipmentComparisonReport({
    required this.week,
    required this.generatedAt,
    required List<DirectionExecutionRow> rows,
  }) : rows =
           [
             for (final row in rows)
               if (row.kind == 'shipment' &&
                   !row.date.isBefore(week) &&
                   row.date.isBefore(week.add(const Duration(days: 6))))
                 ShipmentComparisonRow(row, generatedAt),
           ]..sort((a, b) {
             final date = a.source.date.compareTo(b.source.date);
             if (date != 0) return date;
             final client = a.source.client.compareTo(b.source.client);
             return client != 0
                 ? client
                 : a.source.material.compareTo(b.source.material);
           });

  String get fileName => 'embarques_planeado_vs_real_${programDate(week)}.pdf';
  Set<String> get units => {for (final row in rows) row.unit};
  int plannedFor(String unit) =>
      rows.where((r) => r.unit == unit).fold(0, (s, r) => s + (r.planned ?? 0));
  int confirmedFor(String unit) => rows
      .where((r) => r.unit == unit && r.confirmed)
      .fold(0, (s, r) => s + r.actual!);
  int get pending => rows.where((r) => !r.confirmed && r.actual != null).length;
  int get missing => rows.where((r) => r.actual == null && !r.future).length;
  int get future => rows.where((r) => r.future).length;
}
