import 'package:supabase_flutter/supabase_flutter.dart';

const String _kLogisticsGasolineControlTable = 'logistics_gasoline_control';

class LogisticsGasolineControlRecord {
  final String? id;
  final DateTime entryDate;
  final String? operatorEmployeeId;
  final String operatorName;
  final String? vehicleId;
  final String vehicleLabel;
  final double litersLoaded;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LogisticsGasolineControlRecord({
    required this.id,
    required this.entryDate,
    required this.operatorEmployeeId,
    required this.operatorName,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.litersLoaded,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  LogisticsGasolineControlRecord copyWith({
    Object? id = _unset,
    DateTime? entryDate,
    Object? operatorEmployeeId = _unset,
    String? operatorName,
    Object? vehicleId = _unset,
    String? vehicleLabel,
    double? litersLoaded,
    String? notes,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return LogisticsGasolineControlRecord(
      id: id == _unset ? this.id : id as String?,
      entryDate: entryDate ?? this.entryDate,
      operatorEmployeeId: operatorEmployeeId == _unset
          ? this.operatorEmployeeId
          : operatorEmployeeId as String?,
      operatorName: operatorName ?? this.operatorName,
      vehicleId: vehicleId == _unset ? this.vehicleId : vehicleId as String?,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      litersLoaded: litersLoaded ?? this.litersLoaded,
      notes: notes ?? this.notes,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    if (id != null && id!.trim().isNotEmpty) 'id': id,
    'entry_date': _fmtDbDate(entryDate),
    'operator_employee_id': operatorEmployeeId,
    'operator_name': operatorName.trim(),
    'vehicle_id': vehicleId,
    'vehicle_label': vehicleLabel.trim(),
    'liters_loaded': litersLoaded,
    'notes': notes.trim(),
  };

  factory LogisticsGasolineControlRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return LogisticsGasolineControlRecord(
      id: row['id']?.toString(),
      entryDate: _tryParseDate(row['entry_date']?.toString()) ?? DateTime.now(),
      operatorEmployeeId: row['operator_employee_id']?.toString(),
      operatorName: (row['operator_name'] ?? '').toString(),
      vehicleId: row['vehicle_id']?.toString(),
      vehicleLabel: (row['vehicle_label'] ?? '').toString(),
      litersLoaded: _tryParseDouble(row['liters_loaded']) ?? 0,
      notes: (row['notes'] ?? '').toString(),
      createdAt: _tryParseDateTime(row['created_at']?.toString()),
      updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    );
  }
}

class LogisticsGasolineControlStore {
  static Future<List<LogisticsGasolineControlRecord>> loadEntries() async {
    final rows = await Supabase.instance.client
        .from(_kLogisticsGasolineControlTable)
        .select()
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (raw) => LogisticsGasolineControlRecord.fromRemoteRow(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .toList(growable: false);
  }

  static Future<LogisticsGasolineControlRecord> saveEntry(
    LogisticsGasolineControlRecord record,
  ) async {
    final row = await Supabase.instance.client
        .from(_kLogisticsGasolineControlTable)
        .upsert(record.toUpsertJson())
        .select()
        .single();
    return LogisticsGasolineControlRecord.fromRemoteRow(
      Map<String, dynamic>.from(row),
    );
  }

  static Future<void> deleteEntry(String id) async {
    await Supabase.instance.client
        .from(_kLogisticsGasolineControlTable)
        .delete()
        .eq('id', id);
  }
}

const Object _unset = Object();

String _fmtDbDate(DateTime value) {
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  return '${value.year}-$mm-$dd';
}

double? _tryParseDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}

DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (value.length >= 10) {
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(5, 7));
    final day = int.tryParse(value.substring(8, 10));
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  return DateTime.tryParse(value);
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
