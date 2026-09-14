import 'package:supabase_flutter/supabase_flutter.dart';

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

  const LogisticsVehicleMileageRecord({
    required this.id,
    required this.entryDate,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.vehicleKey,
    required this.kilometers,
    required this.sourceFileName,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    if (id != null && id!.trim().isNotEmpty) 'id': id,
    'entry_date': _formatDbDate(entryDate),
    'vehicle_id': vehicleId,
    'vehicle_label': vehicleLabel.trim(),
    'vehicle_key': vehicleKey,
    'kilometers': kilometers,
    'source_file_name': sourceFileName.trim(),
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
    );
  }
}

class LogisticsVehicleMileageStore {
  static Future<List<LogisticsVehicleMileageRecord>> loadEntries() async {
    final rows = await Supabase.instance.client
        .from(_kMileageTable)
        .select()
        .order('entry_date', ascending: false)
        .order('vehicle_key');
    return (rows as List)
        .map(
          (raw) => LogisticsVehicleMileageRecord.fromRemoteRow(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .toList(growable: false);
  }

  static Future<void> upsertEntries(
    List<LogisticsVehicleMileageRecord> entries,
  ) async {
    if (entries.isEmpty) return;
    await Supabase.instance.client
        .from(_kMileageTable)
        .upsert(
          entries.map((entry) => entry.toUpsertJson()).toList(growable: false),
          onConflict: 'entry_date,vehicle_key',
        );
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
