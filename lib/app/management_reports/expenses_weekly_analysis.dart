class ExpensesWeeklyCut {
  ExpensesWeeklyCut(DateTime generatedAt) {
    final day = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
    start = day.subtract(Duration(days: day.weekday - DateTime.monday));
    friday = start.add(const Duration(days: 4));
    final fridayEnd = friday
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));
    end = generatedAt.isBefore(fridayEnd) ? generatedAt : fridayEnd;
    previousStart = start.subtract(const Duration(days: 7));
    previousEnd = end.subtract(const Duration(days: 7));
  }
  late final DateTime start, friday, end, previousStart, previousEnd;
  bool contains(DateTime? date, {bool previous = false}) {
    if (date == null) return false;
    return !date.isBefore(previous ? previousStart : start) &&
        !date.isAfter(previous ? previousEnd : end);
  }
}

class ExpensesWeeklyOrder {
  const ExpensesWeeklyOrder({
    required this.id,
    required this.folio,
    required this.orderDate,
    required this.status,
    required this.vendor,
    required this.target,
    required this.concept,
    required this.ot,
    required this.estimated,
    required this.actual,
    required this.purchasedAt,
    required this.sentToCashAt,
    required this.createdAt,
  });
  final String id, folio, status, vendor, target, concept, ot;
  final DateTime orderDate;
  final DateTime? purchasedAt, sentToCashAt, createdAt;
  final double? estimated, actual;
  bool get purchased => status == 'purchased';
  bool get open =>
      ['draft', 'pending_direction', 'authorized'].contains(status);
  bool get comparable => estimated != null && estimated! > 0 && actual != null;
  double? get variance => comparable ? actual! - estimated! : null;
  double? get variancePercent =>
      comparable ? variance! / estimated! * 100 : null;
  String get stage => switch (status) {
    'purchased' => 'Comprada',
    'authorized' => sentToCashAt == null ? 'Autorizada' : 'Enviada a caja',
    'pending_direction' => 'Pendiente Direccion',
    'rejected' => 'Rechazada',
    _ => 'Borrador',
  };
}

class ExpensesWeeklySummary {
  ExpensesWeeklySummary(this.rows);
  final List<ExpensesWeeklyOrder> rows;
  List<ExpensesWeeklyOrder> get comparable =>
      rows.where((r) => r.comparable).toList();
  int get withoutActual => rows.where((r) => r.actual == null).length;
  double get actual => rows.fold(0, (v, r) => v + (r.actual ?? 0));
  double get comparableEstimate =>
      comparable.fold(0, (v, r) => v + r.estimated!);
  double get comparableActual => comparable.fold(0, (v, r) => v + r.actual!);
  double? get variance =>
      comparable.isEmpty ? null : comparableActual - comparableEstimate;
  double? get variancePercent =>
      comparableEstimate > 0 ? variance! / comparableEstimate * 100 : null;
  int get overBudget => comparable.where((r) => r.variance! > .009).length;
}

class ExpensesWeeklyAnalysis {
  ExpensesWeeklyAnalysis(List<ExpensesWeeklyOrder> rows, this.cut) {
    // Status and amounts are current source values, not historical snapshots.
    final visible = rows
        .where(
          (r) =>
              !r.orderDate.isAfter(cut.end) &&
              (r.createdAt == null || !r.createdAt!.isAfter(cut.end)),
        )
        .toList();
    current = ExpensesWeeklySummary(
      visible.where((r) => r.purchased && cut.contains(r.purchasedAt)).toList()
        ..sort(_sort),
    );
    previous = ExpensesWeeklySummary(
      visible
          .where(
            (r) => r.purchased && cut.contains(r.purchasedAt, previous: true),
          )
          .toList()
        ..sort(_sort),
    );
    opened = visible.where((r) => cut.contains(r.orderDate)).toList()
      ..sort(_sort);
    pending = visible.where((r) => r.open).toList()..sort(_sort);
    rejected =
        visible
            .where((r) => r.status == 'rejected' && cut.contains(r.orderDate))
            .toList()
          ..sort(_sort);
    undatedPurchases =
        visible.where((r) => r.purchased && r.purchasedAt == null).toList()
          ..sort(_sort);
  }
  final ExpensesWeeklyCut cut;
  late final ExpensesWeeklySummary current, previous;
  late final List<ExpensesWeeklyOrder> opened,
      pending,
      rejected,
      undatedPurchases;
  static int _sort(ExpensesWeeklyOrder a, ExpensesWeeklyOrder b) {
    final date = (b.purchasedAt ?? b.orderDate).compareTo(
      a.purchasedAt ?? a.orderDate,
    );
    return date != 0 ? date : a.folio.compareTo(b.folio);
  }

  double get pendingEstimate =>
      pending.fold(0, (sum, r) => sum + (r.estimated ?? 0));
  List<ExpensesWeeklyOrder> get backlog =>
      pending.where((r) => r.orderDate.isBefore(cut.start)).toList();
  Map<String, ExpensesWeeklySummary> groupBy(
    String Function(ExpensesWeeklyOrder) key,
  ) {
    final groups = <String, List<ExpensesWeeklyOrder>>{};
    for (final row in current.rows) {
      groups.putIfAbsent(key(row), () => []).add(row);
    }
    final names = groups.keys.toList()..sort();
    return {
      for (final name in names) name: ExpensesWeeklySummary(groups[name]!),
    };
  }
}
