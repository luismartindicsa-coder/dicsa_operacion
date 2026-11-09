import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_performance_data.dart';
import 'logistics_performance_period.dart';

String fuelFollowupDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String fuelFollowupTime(DateTime date) {
  final local = date.toLocal();
  return '${fuelFollowupDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class LogisticsLoadMileage {
  final String vehicleId, status, kind;
  final DateTime loadDate, from;
  final DateTime? through, fetchedAt;
  final double? kilometers;
  final List<Map<String, dynamic>> snapshot;

  LogisticsLoadMileage.fromRow(Map<String, dynamic> row)
    : vehicleId = row['vehicle_id'].toString(),
      status = row['status'].toString(),
      kind = row['window_kind'].toString(),
      loadDate = DateTime.parse(row['load_date'].toString()),
      from = DateTime.parse(row['from_at'].toString()),
      through = DateTime.tryParse(row['through_at']?.toString() ?? ''),
      fetchedAt = DateTime.tryParse(row['fetched_at']?.toString() ?? ''),
      kilometers = double.tryParse(row['kilometers']?.toString() ?? ''),
      snapshot = (row['load_snapshot'] as List? ?? const [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();

  static Future<List<LogisticsLoadMileage>> loadEntries() async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('logistics_gps_load_mileage')
          .select()
          .order('vehicle_id')
          .range(from, to),
    );
    return rows.map(LogisticsLoadMileage.fromRow).toList();
  }
}

class LogisticsFuelFollowup {
  final PerformanceUnit unit;
  final DateTime now;
  final LogisticsLoadMileage? cached;
  LogisticsFuelFollowup(this.unit, this.now, this.cached);

  PerformanceDay? get day => unit.days
      .where(
        (d) =>
            d.loads.isNotEmpty &&
            !d.date.isAfter(DateTime(now.year, now.month, now.day)),
      )
      .firstOrNull;
  List<PerformanceLoad> get dayLoads => day?.loads ?? const [];
  bool get hasTime =>
      dayLoads.isNotEmpty && dayLoads.every((l) => l.loadedAt != null);
  DateTime? get loadedAt => !hasTime
      ? null
      : (dayLoads.map((l) => l.loadedAt!).toList()..sort()).last;
  List<PerformanceLoad> get lastLoads => hasTime
      ? dayLoads.where((l) => l.loadedAt == loadedAt).toList()
      : dayLoads;
  double get liters => lastLoads.fold(0, (sum, l) => sum + l.liters);
  bool get estimatedLiters => lastLoads.any((l) => l.litersEstimated);
  String get kind => hasTime
      ? 'since_load'
      : day?.date == DateTime(now.year, now.month, now.day)
      ? 'load_day'
      : 'after_load_day';
  DateTime? get from => hasTime
      ? loadedAt
      : day == null
      ? null
      : kind == 'load_day'
      ? day!.date
      : day!.date.add(const Duration(days: 1));

  // A new/edited load invalidates old distance immediately, before the worker's
  // next rotation. Do not reuse yesterday's window after the midnight change.
  LogisticsLoadMileage? get mileage {
    final value = cached;
    if (value == null ||
        day == null ||
        value.vehicleId != day!.vehicleId ||
        value.loadDate != day!.date ||
        value.kind != kind ||
        !value.from.isAtSameMomentAs(from!) ||
        value.snapshot.length != dayLoads.length) {
      return null;
    }
    for (final load in dayLoads) {
      final match = value.snapshot
          .where(
            (s) =>
                s['id'] == load.id &&
                s['fuel'] == (load.diesel ? 'diesel' : 'gasoline'),
          )
          .firstOrNull;
      if (match == null ||
          double.tryParse(match['liters'].toString()) != load.liters) {
        return null;
      }
      final time = DateTime.tryParse(match['loaded_at']?.toString() ?? '');
      if ((time == null) != (load.loadedAt == null) ||
          (time != null && !time.isAtSameMomentAs(load.loadedAt!))) {
        return null;
      }
    }
    return value;
  }

  bool get fresh {
    final m = mileage;
    return m != null &&
        ['ok', 'running'].contains(m.status) &&
        m.kilometers != null &&
        m.fetchedAt != null &&
        m.through != null &&
        !m.through!.isAfter(now) &&
        now.difference(m.fetchedAt!).inMinutes < 10 &&
        now.difference(m.through!).inMinutes < 15;
  }

  String get distanceLabel => mileage?.kilometers == null
      ? 'Pendiente de GPS'
      : '${mileage!.kilometers!.toStringAsFixed(1)} km${fresh ? '' : ' · revisar actualización'}';
  String get intervalLabel => switch (kind) {
    'since_load' => 'Desde la hora de carga',
    'load_day' => 'Recorrido de hoy · incluye antes de cargar',
    _ => 'Desde el día siguiente a la carga',
  };
  // A short window with partial deliveries can exclude fuel used for its km.
  // Use 30 closed days as the historical reference, never the live distance
  // divided by the last delivery. Delivered liters are not measured consumption.
  DateTime get performanceStart => logisticsClosedPeriod('month', now).start;
  DateTime get performanceEnd => logisticsClosedPeriod('month', now).end;
  PerformanceUnit get periodSummary => PerformanceUnit(
    unit.days.where(
      (d) =>
          !d.date.isBefore(performanceStart) && !d.date.isAfter(performanceEnd),
    ),
  );
  String get performanceLabel => periodSummary.performanceLabel;
  String get performanceNote {
    final summary = periodSummary;
    if (summary.mileageDays == 0) return 'Sin kilómetros del periodo';
    if (summary.fuel.total <= 0) return 'Sin litros del periodo';
    if (summary.fuel.mixed) return 'Combustibles mezclados';
    if (summary.hasPartialPerformance) return summary.mileageCoverageLabel;
    return 'Referencia por litros cargados';
  }
}
