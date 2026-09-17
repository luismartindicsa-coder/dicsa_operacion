import 'direction_shipments_store.dart';

class DirectionShipmentSummaryRow {
  final DateTime date;
  final String materialCode;
  final String destination;
  final String status;
  final int bales;

  const DirectionShipmentSummaryRow({
    required this.date,
    required this.materialCode,
    required this.destination,
    required this.status,
    required this.bales,
  });

  String get materialLabel => directionShipmentMaterialLabel(materialCode);
  bool get isShipped => status == 'embarcado';
  String get statusLabel => switch (status) {
    'embarcado' => 'Embarcado',
    'confirmado' => 'Confirmado',
    'movido' => 'Movido',
    'planeado' => 'Planeado',
    _ => status,
  };
}

class DirectionShipmentsWeeklySummary {
  final DateTime weekStart;
  final List<DirectionShipmentSummaryRow> rows;

  const DirectionShipmentsWeeklySummary._(this.weekStart, this.rows);

  DateTime get weekEnd => weekStart.add(const Duration(days: 5));
  int get pendingBales => rows
      .where((row) => !row.isShipped)
      .fold(0, (total, row) => total + row.bales);
  int get shippedBales => rows
      .where((row) => row.isShipped)
      .fold(0, (total, row) => total + row.bales);
  int get totalBales => pendingBales + shippedBales;

  factory DirectionShipmentsWeeklySummary.fromShipments(
    DateTime weekDate,
    Iterable<DirectionShipmentPlanRecord> shipments,
  ) {
    final start = DirectionShipmentsStore.normalizeWeekStartDate(weekDate);
    final end = start.add(const Duration(days: 6));
    final totals = <(DateTime, String, String, String), int>{};
    for (final shipment in shipments) {
      final date = DateTime(
        shipment.shipDate.year,
        shipment.shipDate.month,
        shipment.shipDate.day,
      );
      if (date.isBefore(start) ||
          !date.isBefore(end) ||
          shipment.isCancelled ||
          shipment.quantityUnit != DirectionShipmentQuantityUnit.bales ||
          shipment.plannedQuantity <= 0) {
        continue;
      }
      final destination = shipment.clientName
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ')
          .toUpperCase();
      final material = directionShipmentMaterialByCode(shipment.materialCode);
      final key = (
        date,
        material?.code ?? shipment.materialCode,
        destination.isEmpty ? 'Sin destino' : destination,
        shipment.status,
      );
      totals.update(
        key,
        (value) => value + shipment.plannedQuantity,
        ifAbsent: () => shipment.plannedQuantity,
      );
    }
    final rows = totals.entries.map((entry) {
      final (date, material, destination, status) = entry.key;
      return DirectionShipmentSummaryRow(
        date: date,
        materialCode: material,
        destination: destination,
        status: status,
        bales: entry.value,
      );
    }).toList();
    rows.sort((a, b) {
      final dateOrder = b.date.compareTo(a.date);
      if (dateOrder != 0) return dateOrder;
      final materialOrder = a.materialLabel.compareTo(b.materialLabel);
      if (materialOrder != 0) return materialOrder;
      final destinationOrder = a.destination.compareTo(b.destination);
      if (destinationOrder != 0) return destinationOrder;
      return a.statusLabel.compareTo(b.statusLabel);
    });
    return DirectionShipmentsWeeklySummary._(start, List.unmodifiable(rows));
  }

  static Future<DirectionShipmentsWeeklySummary> loadWeek(DateTime date) async {
    final shipments = await DirectionShipmentsStore.loadWeeklyShipments(date);
    return DirectionShipmentsWeeklySummary.fromShipments(date, shipments);
  }
}
