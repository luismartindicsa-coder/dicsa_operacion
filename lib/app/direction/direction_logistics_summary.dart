import 'package:supabase_flutter/supabase_flutter.dart';

import '../logistica/logistics_diesel_store.dart';
import '../logistica/logistics_gasoline_store.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';

enum DirectionFuelType { diesel, gasoline }

class DirectionFuelDriverSummary {
  final String name;
  final double liters;

  const DirectionFuelDriverSummary({required this.name, required this.liters});
}

class DirectionLogisticsWeeklySummary {
  final DateTime weekStart;
  final double dieselPurchased;
  final double dieselRequested;
  final double gasolineLoaded;
  final int dieselEntries;
  final int gasolineEntries;
  final List<DirectionFuelDriverSummary> dieselDrivers;
  final List<DirectionFuelDriverSummary> gasolineDrivers;

  const DirectionLogisticsWeeklySummary._({
    required this.weekStart,
    required this.dieselPurchased,
    required this.dieselRequested,
    required this.gasolineLoaded,
    required this.dieselEntries,
    required this.gasolineEntries,
    required this.dieselDrivers,
    required this.gasolineDrivers,
  });

  static DateTime startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  factory DirectionLogisticsWeeklySummary.fromEntries({
    required DateTime weekDate,
    required Iterable<LogisticsDieselConsumptionRecord> diesel,
    required Iterable<LogisticsGasolineControlRecord> gasoline,
  }) {
    final start = startOfWeek(weekDate);
    final end = start.add(const Duration(days: 7));
    bool inWeek(DateTime date) {
      final day = DateTime(date.year, date.month, date.day);
      return !day.isBefore(start) && day.isBefore(end);
    }

    final dieselRows = diesel.where((row) => inWeek(row.entryDate)).toList();
    final gasolineRows = gasoline
        .where((row) => inWeek(row.entryDate))
        .toList();
    return DirectionLogisticsWeeklySummary._(
      weekStart: start,
      dieselPurchased: dieselRows.fold(
        0,
        (sum, row) => sum + row.litersPurchased,
      ),
      dieselRequested: dieselRows.fold(
        0,
        (sum, row) => sum + row.litersRequested,
      ),
      gasolineLoaded: gasolineRows.fold(
        0,
        (sum, row) => sum + row.litersLoaded,
      ),
      dieselEntries: dieselRows.length,
      gasolineEntries: gasolineRows.length,
      dieselDrivers: _groupDrivers(
        dieselRows.map(
          (row) => (
            row.operatorEmployeeId,
            row.operatorName,
            row.entryDate,
            row.litersRequested,
          ),
        ),
      ),
      gasolineDrivers: _groupDrivers(
        gasolineRows.map(
          (row) => (
            row.operatorEmployeeId,
            row.operatorName,
            row.entryDate,
            row.litersLoaded,
          ),
        ),
      ),
    );
  }
}

// Keep employee identities distinct, even when two drivers share a name.
// Purchase-only diesel rows contribute to purchases, not to driver usage.
List<DirectionFuelDriverSummary> _groupDrivers(
  Iterable<(String?, String, DateTime, double)> rows,
) {
  final totals = <String, double>{};
  final labels = <String, (String, DateTime)>{};
  for (final (employeeId, rawName, date, liters) in rows) {
    if (liters <= 0) continue;
    final id = employeeId?.trim() ?? '';
    final name = rawName.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    final key = id.isEmpty ? 'name:$name' : 'id:$id';
    totals.update(key, (value) => value + liters, ifAbsent: () => liters);
    final previous = labels[key];
    if (previous == null || (name.isNotEmpty && !date.isBefore(previous.$2))) {
      labels[key] = (
        name.isEmpty ? (id.isEmpty ? 'Sin chofer' : 'Sin nombre') : name,
        date,
      );
    }
  }
  final result =
      totals.entries
          .map(
            (entry) => DirectionFuelDriverSummary(
              name: labels[entry.key]!.$1,
              liters: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) {
          final amount = b.liters.compareTo(a.liters);
          return amount == 0 ? a.name.compareTo(b.name) : amount;
        });
  return List.unmodifiable(result);
}

class DirectionLogisticsStore {
  final SupabaseClient? _client;

  const DirectionLogisticsStore({SupabaseClient? client}) : _client = client;

  Future<DirectionLogisticsWeeklySummary> loadWeek(DateTime date) async {
    final client = _client ?? Supabase.instance.client;
    final start = DirectionLogisticsWeeklySummary.startOfWeek(date);
    final end = start.add(const Duration(days: 7));
    String dbDate(DateTime day) => day.toIso8601String().substring(0, 10);
    final result = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => client
            .from('logistics_diesel_consumption')
            .select(
              'id,entry_date,operator_employee_id,operator_name,liters_purchased,liters_requested',
            )
            .gte('entry_date', dbDate(start))
            .lt('entry_date', dbDate(end))
            .order('entry_date', ascending: false)
            .order('created_at', ascending: false)
            .order('id', ascending: true)
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('logistics_gasoline_control')
            .select(
              'id,entry_date,operator_employee_id,operator_name,liters_loaded',
            )
            .gte('entry_date', dbDate(start))
            .lt('entry_date', dbDate(end))
            .order('entry_date', ascending: false)
            .order('created_at', ascending: false)
            .order('id', ascending: true)
            .range(from, to),
      ),
    ]);
    return DirectionLogisticsWeeklySummary.fromEntries(
      weekDate: start,
      diesel: result[0].map(LogisticsDieselConsumptionRecord.fromRemoteRow),
      gasoline: result[1].map(LogisticsGasolineControlRecord.fromRemoteRow),
    );
  }
}
