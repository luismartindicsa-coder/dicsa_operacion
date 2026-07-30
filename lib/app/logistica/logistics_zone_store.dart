import 'package:supabase_flutter/supabase_flutter.dart';

const String _kLogisticsZonesTable = 'logistics_zones';

String normalizeLogisticsZoneCode(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String buildLogisticsZoneId({required String code, required String name}) {
  final seed = code.trim().isNotEmpty ? code : name;
  final slug = seed
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return 'log_zone_${slug.isEmpty ? 'base' : slug}';
}

String normalizeLogisticsZoneColorHex(String value) {
  final cleaned = value.trim().replaceAll('#', '').toUpperCase();
  if (cleaned.length != 6) return '#C7CDD4';
  return '#$cleaned';
}

class LogisticsZoneRecord {
  final String id;
  final String code;
  final String name;
  final String city;
  final String state;
  final String colorHex;
  final String coverageHint;
  final int displayOrder;
  final List<dynamic> polygonPoints;
  final bool active;
  final String notes;
  final DateTime? updatedAt;

  const LogisticsZoneRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.state,
    required this.colorHex,
    required this.coverageHint,
    required this.displayOrder,
    required this.polygonPoints,
    required this.active,
    required this.notes,
    required this.updatedAt,
  });

  LogisticsZoneRecord copyWith({
    String? id,
    String? code,
    String? name,
    String? city,
    String? state,
    String? colorHex,
    String? coverageHint,
    int? displayOrder,
    List<dynamic>? polygonPoints,
    bool? active,
    String? notes,
    DateTime? updatedAt,
  }) {
    return LogisticsZoneRecord(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      city: city ?? this.city,
      state: state ?? this.state,
      colorHex: colorHex ?? this.colorHex,
      coverageHint: coverageHint ?? this.coverageHint,
      displayOrder: displayOrder ?? this.displayOrder,
      polygonPoints: polygonPoints ?? this.polygonPoints,
      active: active ?? this.active,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'name': name,
    'city': city,
    'state': state,
    'color_hex': colorHex,
    'coverage_hint': coverageHint.isEmpty ? null : coverageHint,
    'display_order': displayOrder,
    'polygon_points': polygonPoints,
    'is_active': active,
    'notes': notes.isEmpty ? null : notes,
  };

  factory LogisticsZoneRecord.fromRemoteRow(Map<String, dynamic> row) {
    return LogisticsZoneRecord(
      id: (row['id'] ?? '').toString(),
      code: (row['code'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      city: (row['city'] ?? 'Celaya').toString(),
      state: (row['state'] ?? 'Guanajuato').toString(),
      colorHex: normalizeLogisticsZoneColorHex(
        (row['color_hex'] ?? '#C7CDD4').toString(),
      ),
      coverageHint: (row['coverage_hint'] ?? '').toString(),
      displayOrder: (row['display_order'] as num? ?? 0).toInt(),
      polygonPoints: (row['polygon_points'] as List?)?.toList() ?? const [],
      active: row['is_active'] as bool? ?? true,
      notes: (row['notes'] ?? '').toString(),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class LogisticsZoneStore {
  static Future<List<LogisticsZoneRecord>> loadZones() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kLogisticsZonesTable)
          .select()
          .order('display_order')
          .order('name');
      return (rows as List)
          .map(
            (raw) => LogisticsZoneRecord.fromRemoteRow(
              Map<String, dynamic>.from(raw as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <LogisticsZoneRecord>[];
    }
  }

  static Future<void> saveZoneRow(LogisticsZoneRecord record) async {
    await Supabase.instance.client.from(_kLogisticsZonesTable).upsert(
      <Map<String, dynamic>>[record.toUpsertJson()],
      onConflict: 'id',
    );
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
