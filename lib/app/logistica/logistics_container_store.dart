import 'package:supabase_flutter/supabase_flutter.dart';

const String _kLogisticsContainersTable = 'logistics_containers';

class LogisticsContainerRecord {
  final String? id;
  final DateTime entryDate;
  final String? operatorEmployeeId;
  final String operatorName;
  final String containerLabel;
  final String legacyCode;
  final String materialName;
  final String? siteId;
  final String siteName;
  final String locationLabel;
  final double tareWeightKg;
  final double widthM;
  final double heightM;
  final double lengthM;
  final double capacityM3;
  final List<String> compatibleUnitTypes;
  final String notes;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LogisticsContainerRecord({
    required this.id,
    required this.entryDate,
    required this.operatorEmployeeId,
    required this.operatorName,
    required this.containerLabel,
    required this.legacyCode,
    required this.materialName,
    required this.siteId,
    required this.siteName,
    required this.locationLabel,
    required this.tareWeightKg,
    required this.widthM,
    required this.heightM,
    required this.lengthM,
    required this.capacityM3,
    required this.compatibleUnitTypes,
    required this.notes,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  LogisticsContainerRecord copyWith({
    Object? id = _unset,
    DateTime? entryDate,
    Object? operatorEmployeeId = _unset,
    String? operatorName,
    String? containerLabel,
    String? legacyCode,
    String? materialName,
    Object? siteId = _unset,
    String? siteName,
    String? locationLabel,
    double? tareWeightKg,
    double? widthM,
    double? heightM,
    double? lengthM,
    double? capacityM3,
    List<String>? compatibleUnitTypes,
    String? notes,
    bool? active,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return LogisticsContainerRecord(
      id: id == _unset ? this.id : id as String?,
      entryDate: entryDate ?? this.entryDate,
      operatorEmployeeId: operatorEmployeeId == _unset
          ? this.operatorEmployeeId
          : operatorEmployeeId as String?,
      operatorName: operatorName ?? this.operatorName,
      containerLabel: containerLabel ?? this.containerLabel,
      legacyCode: legacyCode ?? this.legacyCode,
      materialName: materialName ?? this.materialName,
      siteId: siteId == _unset ? this.siteId : siteId as String?,
      siteName: siteName ?? this.siteName,
      locationLabel: locationLabel ?? this.locationLabel,
      tareWeightKg: tareWeightKg ?? this.tareWeightKg,
      widthM: widthM ?? this.widthM,
      heightM: heightM ?? this.heightM,
      lengthM: lengthM ?? this.lengthM,
      capacityM3: capacityM3 ?? this.capacityM3,
      compatibleUnitTypes: compatibleUnitTypes ?? this.compatibleUnitTypes,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    if (id != null && id!.trim().isNotEmpty) 'id': id,
    'entry_date': _fmtDbDate(entryDate),
    'operator_employee_id': operatorEmployeeId,
    'operator_name': operatorName.trim().isEmpty ? null : operatorName.trim(),
    'container_label': containerLabel.trim(),
    'legacy_code': legacyCode.trim().isEmpty ? null : legacyCode.trim(),
    'material_name': materialName.trim().isEmpty ? null : materialName.trim(),
    'site_id': siteId,
    'site_name': siteName.trim().isEmpty ? null : siteName.trim(),
    'location_label': locationLabel.trim(),
    'tare_weight_kg': tareWeightKg,
    'width_m': widthM,
    'height_m': heightM,
    'length_m': lengthM,
    'capacity_m3': capacityM3,
    'compatible_unit_types': compatibleUnitTypes,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
    'is_active': active,
  };

  factory LogisticsContainerRecord.fromRemoteRow(Map<String, dynamic> row) {
    return LogisticsContainerRecord(
      id: row['id']?.toString(),
      entryDate: _tryParseDate(row['entry_date']?.toString()) ?? DateTime.now(),
      operatorEmployeeId: row['operator_employee_id']?.toString(),
      operatorName: (row['operator_name'] ?? '').toString(),
      containerLabel: (row['container_label'] ?? '').toString(),
      legacyCode: (row['legacy_code'] ?? '').toString(),
      materialName: (row['material_name'] ?? '').toString(),
      siteId: row['site_id']?.toString(),
      siteName: (row['site_name'] ?? '').toString(),
      locationLabel: (row['location_label'] ?? '').toString(),
      tareWeightKg: _tryParseDouble(row['tare_weight_kg']) ?? 0,
      widthM: _tryParseDouble(row['width_m']) ?? 0,
      heightM: _tryParseDouble(row['height_m']) ?? 0,
      lengthM: _tryParseDouble(row['length_m']) ?? 0,
      capacityM3: _tryParseDouble(row['capacity_m3']) ?? 0,
      compatibleUnitTypes: _normalizeStringList(row['compatible_unit_types']),
      notes: (row['notes'] ?? '').toString(),
      active: row['is_active'] as bool? ?? true,
      createdAt: _tryParseDateTime(row['created_at']?.toString()),
      updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    );
  }
}

class LogisticsContainerStore {
  static Future<List<LogisticsContainerRecord>> loadEntries() async {
    final rows = await Supabase.instance.client
        .from(_kLogisticsContainersTable)
        .select()
        .order('entry_date', ascending: false)
        .order('container_label');
    return (rows as List)
        .map(
          (raw) => LogisticsContainerRecord.fromRemoteRow(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .toList(growable: false);
  }

  static Future<LogisticsContainerRecord> saveEntry(
    LogisticsContainerRecord record,
  ) async {
    final row = await Supabase.instance.client
        .from(_kLogisticsContainersTable)
        .upsert(record.toUpsertJson())
        .select()
        .single();
    return LogisticsContainerRecord.fromRemoteRow(
      Map<String, dynamic>.from(row),
    );
  }

  static Future<void> deleteEntry(String id) async {
    await Supabase.instance.client
        .from(_kLogisticsContainersTable)
        .delete()
        .eq('id', id);
  }
}

double logisticsContainerComputedCapacityM3({
  required double widthM,
  required double heightM,
  required double lengthM,
}) {
  final width = widthM <= 0 ? 0 : widthM;
  final height = heightM <= 0 ? 0 : heightM;
  final length = lengthM <= 0 ? 0 : lengthM;
  return (width * height * length).toDouble();
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

List<String> _normalizeStringList(dynamic raw) {
  final values = <String>[];
  if (raw is List) {
    for (final item in raw) {
      final normalized = item.toString().trim().toUpperCase();
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }
  }
  return values;
}
