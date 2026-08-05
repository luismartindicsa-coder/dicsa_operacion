import 'package:supabase_flutter/supabase_flutter.dart';

const String _kLogisticsDieselConsumptionTable = 'logistics_diesel_consumption';

class LogisticsDieselConsumptionRecord {
  final String? id;
  final DateTime entryDate;
  final String? operatorEmployeeId;
  final String operatorName;
  final String? vehicleId;
  final String vehicleLabel;
  final double litersPurchased;
  final double litersRequested;
  final double balanceLiters;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LogisticsDieselConsumptionRecord({
    required this.id,
    required this.entryDate,
    required this.operatorEmployeeId,
    required this.operatorName,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.litersPurchased,
    required this.litersRequested,
    required this.balanceLiters,
    required this.createdAt,
    required this.updatedAt,
  });

  LogisticsDieselConsumptionRecord copyWith({
    Object? id = _unset,
    DateTime? entryDate,
    Object? operatorEmployeeId = _unset,
    String? operatorName,
    Object? vehicleId = _unset,
    String? vehicleLabel,
    double? litersPurchased,
    double? litersRequested,
    double? balanceLiters,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return LogisticsDieselConsumptionRecord(
      id: id == _unset ? this.id : id as String?,
      entryDate: entryDate ?? this.entryDate,
      operatorEmployeeId: operatorEmployeeId == _unset
          ? this.operatorEmployeeId
          : operatorEmployeeId as String?,
      operatorName: operatorName ?? this.operatorName,
      vehicleId: vehicleId == _unset ? this.vehicleId : vehicleId as String?,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      litersPurchased: litersPurchased ?? this.litersPurchased,
      litersRequested: litersRequested ?? this.litersRequested,
      balanceLiters:
          balanceLiters ??
          (litersPurchased ?? this.litersPurchased) -
              (litersRequested ?? this.litersRequested),
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
    'liters_purchased': litersPurchased,
    'liters_requested': litersRequested,
  };

  factory LogisticsDieselConsumptionRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    final purchased = _tryParseDouble(row['liters_purchased']) ?? 0;
    final requested = _tryParseDouble(row['liters_requested']) ?? 0;
    return LogisticsDieselConsumptionRecord(
      id: row['id']?.toString(),
      entryDate: _tryParseDate(row['entry_date']?.toString()) ?? DateTime.now(),
      operatorEmployeeId: row['operator_employee_id']?.toString(),
      operatorName: (row['operator_name'] ?? '').toString(),
      vehicleId: row['vehicle_id']?.toString(),
      vehicleLabel: (row['vehicle_label'] ?? '').toString(),
      litersPurchased: purchased,
      litersRequested: requested,
      balanceLiters:
          _tryParseDouble(row['balance_liters']) ?? (purchased - requested),
      createdAt: _tryParseDateTime(row['created_at']?.toString()),
      updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    );
  }
}

class LogisticsDieselConsumptionStore {
  static Future<List<LogisticsDieselConsumptionRecord>> loadEntries() async {
    final rows = await Supabase.instance.client
        .from(_kLogisticsDieselConsumptionTable)
        .select()
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (raw) => LogisticsDieselConsumptionRecord.fromRemoteRow(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .toList(growable: false);
  }

  static Future<LogisticsDieselConsumptionRecord> saveEntry(
    LogisticsDieselConsumptionRecord record,
  ) async {
    final row = await Supabase.instance.client
        .from(_kLogisticsDieselConsumptionTable)
        .upsert(record.toUpsertJson())
        .select()
        .single();
    return LogisticsDieselConsumptionRecord.fromRemoteRow(
      Map<String, dynamic>.from(row),
    );
  }

  static Future<void> deleteEntry(String id) async {
    await Supabase.instance.client
        .from(_kLogisticsDieselConsumptionTable)
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
