import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';

const String _kMileageTable = 'logistics_vehicle_mileage';

String logisticsVehicleKey(String value) {
  final normalized = value.trim().toUpperCase();
  final match = RegExp(r'^([A-Z]+)[^A-Z0-9]*0*(\d+)').firstMatch(normalized);
  if (match != null) return '${match.group(1)}${match.group(2)}';
  return normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

class LogisticsVehicleMileageRecord {
  final String? id;
  final DateTime entryDate;
  final String? vehicleId;
  final String vehicleLabel;
  final String vehicleKey;
  final double kilometers;
  final String sourceFileName;
  final double? dieselPricePerLiter;
  final double? gasolinePricePerLiter;

  const LogisticsVehicleMileageRecord({
    required this.id,
    required this.entryDate,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.vehicleKey,
    required this.kilometers,
    required this.sourceFileName,
    this.dieselPricePerLiter,
    this.gasolinePricePerLiter,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    if (id != null && id!.trim().isNotEmpty) 'id': id,
    'entry_date': _formatDbDate(entryDate),
    'vehicle_id': vehicleId,
    'vehicle_label': vehicleLabel.trim(),
    'vehicle_key': vehicleKey,
    'kilometers': kilometers,
    'source_file_name': sourceFileName.trim(),
    // Blank import inputs preserve prices already captured on a previous import.
    if (dieselPricePerLiter != null)
      'diesel_price_per_liter': dieselPricePerLiter,
    if (gasolinePricePerLiter != null)
      'gasoline_price_per_liter': gasolinePricePerLiter,
  };

  factory LogisticsVehicleMileageRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return LogisticsVehicleMileageRecord(
      id: row['id']?.toString(),
      entryDate: _parseDbDate(row['entry_date']?.toString()) ?? DateTime.now(),
      vehicleId: row['vehicle_id']?.toString(),
      vehicleLabel: (row['vehicle_label'] ?? '').toString(),
      vehicleKey: (row['vehicle_key'] ?? '').toString(),
      kilometers: _toDouble(row['kilometers']),
      sourceFileName: (row['source_file_name'] ?? '').toString(),
      dieselPricePerLiter: _nullableDouble(row['diesel_price_per_liter']),
      gasolinePricePerLiter: _nullableDouble(row['gasoline_price_per_liter']),
    );
  }
}

class LogisticsVehicleMileageStore {
  static Future<List<LogisticsVehicleMileageRecord>> loadEntries() async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from(_kMileageTable)
          .select()
          .order('entry_date', ascending: false)
          .order('vehicle_key')
          .range(from, to),
    );
    return rows
        .map(LogisticsVehicleMileageRecord.fromRemoteRow)
        .toList(growable: false);
  }

  static Future<void> upsertEntries(
    List<LogisticsVehicleMileageRecord> entries,
  ) async {
    if (entries.isEmpty) return;
    // PostgREST batches must have identical keys. Group by captured prices so
    // a blank price cannot become an explicit null and erase a previous price.
    final batches = <int, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final key =
          (entry.dieselPricePerLiter != null ? 1 : 0) +
          (entry.gasolinePricePerLiter != null ? 2 : 0);
      batches.putIfAbsent(key, () => []).add(entry.toUpsertJson());
    }
    for (final batch in batches.values) {
      await Supabase.instance.client
          .from(_kMileageTable)
          .upsert(batch, onConflict: 'entry_date,vehicle_key');
    }
  }
}

String _formatDbDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? _parseDbDate(String? raw) {
  if (raw == null || raw.length < 10) return null;
  return DateTime.tryParse(raw.substring(0, 10));
}

double _toDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

double? _nullableDouble(dynamic raw) =>
    raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
