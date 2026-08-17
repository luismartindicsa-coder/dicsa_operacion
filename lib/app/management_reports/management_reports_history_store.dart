import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'management_reports_registry.dart';

class ManagementReportRunRecord {
  final ManagementAreaKey areaKey;
  final ManagementReportFrequency frequency;
  final DateTime generatedAt;
  final String generatedBy;
  final String fileName;

  const ManagementReportRunRecord({
    required this.areaKey,
    required this.frequency,
    required this.generatedAt,
    required this.generatedBy,
    required this.fileName,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'area_key': managementAreaKeySlug(areaKey),
      'frequency': managementFrequencySlug(frequency),
      'generated_at': generatedAt.toIso8601String(),
      'generated_by': generatedBy,
      'file_name': fileName,
    };
  }

  factory ManagementReportRunRecord.fromJson(Map<String, dynamic> json) {
    return ManagementReportRunRecord(
      areaKey: managementAreaKeyFromSlug((json['area_key'] ?? '').toString()),
      frequency: managementFrequencyFromSlug(
        (json['frequency'] ?? '').toString(),
      ),
      generatedAt:
          DateTime.tryParse((json['generated_at'] ?? '').toString()) ??
          DateTime.now(),
      generatedBy: (json['generated_by'] ?? 'Usuario DICSA').toString(),
      fileName: (json['file_name'] ?? 'reporte.pdf').toString(),
    );
  }
}

class ManagementReportsHistoryStore {
  static const String _storageKey = 'management_reports_history_v1';
  static const int _maxEntries = 60;

  static Future<List<ManagementReportRunRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ManagementReportRunRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ManagementReportRunRecord>[];
      return decoded
          .whereType<Map>()
          .map(
            (row) => ManagementReportRunRecord.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <ManagementReportRunRecord>[];
    }
  }

  static Future<List<ManagementReportRunRecord>> loadForArea(
    ManagementAreaKey areaKey,
  ) async {
    final rows = await loadAll();
    return rows.where((row) => row.areaKey == areaKey).toList(growable: false)
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  static Future<ManagementReportRunRecord?> latestFor(
    ManagementAreaKey areaKey,
    ManagementReportFrequency frequency,
  ) async {
    final rows = await loadForArea(areaKey);
    for (final row in rows) {
      if (row.frequency == frequency) return row;
    }
    return null;
  }

  static Future<void> append(ManagementReportRunRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await loadAll();
    final nextRows = <ManagementReportRunRecord>[
      record,
      ...rows,
    ].take(_maxEntries).toList(growable: false);
    final raw = jsonEncode(
      nextRows.map((row) => row.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey, raw);
  }
}
