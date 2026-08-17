import 'package:supabase_flutter/supabase_flutter.dart';

import '../mayoreo/mayoreo_sorting.dart';
import 'finanzas_data_store.dart';

const String _kFinDirectoryTable = 'finanzas_company_directory';

const List<String> kFinManualPriorityLevels = <String>[
  'NORMAL',
  'ALTA',
  'CRITICA',
];

String finManualPriorityLabel(String value) {
  switch (value) {
    case 'CRITICA':
      return 'Critica';
    case 'ALTA':
      return 'Alta';
    default:
      return 'Normal';
  }
}

class FinanzasCompanyDirectoryRecord {
  final String companyId;
  final String companyName;
  final String source;
  final String linkedName;
  final String operationalContact;
  final String phone;
  final String location;
  final bool hasContainers;
  final int containerCount;
  final int creditDays;
  final String paymentStage;
  final bool active;
  final String paymentNotes;
  final String manualPriority;
  final String priorityNote;
  final DateTime? updatedAt;

  const FinanzasCompanyDirectoryRecord({
    required this.companyId,
    required this.companyName,
    required this.source,
    required this.linkedName,
    required this.operationalContact,
    required this.phone,
    required this.location,
    required this.hasContainers,
    required this.containerCount,
    required this.creditDays,
    required this.paymentStage,
    required this.active,
    required this.paymentNotes,
    required this.manualPriority,
    required this.priorityNote,
    required this.updatedAt,
  });

  FinanzasCompanyDirectoryRecord copyWith({
    String? companyId,
    String? companyName,
    String? source,
    String? linkedName,
    String? operationalContact,
    String? phone,
    String? location,
    bool? hasContainers,
    int? containerCount,
    int? creditDays,
    String? paymentStage,
    bool? active,
    String? paymentNotes,
    String? manualPriority,
    String? priorityNote,
    DateTime? updatedAt,
  }) {
    return FinanzasCompanyDirectoryRecord(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      source: source ?? this.source,
      linkedName: linkedName ?? this.linkedName,
      operationalContact: operationalContact ?? this.operationalContact,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      hasContainers: hasContainers ?? this.hasContainers,
      containerCount: containerCount ?? this.containerCount,
      creditDays: creditDays ?? this.creditDays,
      paymentStage: paymentStage ?? this.paymentStage,
      active: active ?? this.active,
      paymentNotes: paymentNotes ?? this.paymentNotes,
      manualPriority: manualPriority ?? this.manualPriority,
      priorityNote: priorityNote ?? this.priorityNote,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'company_id': companyId,
    'company_name': companyName,
    'source': source,
    'linked_name': linkedName.isEmpty ? null : linkedName,
    'operational_contact': operationalContact.isEmpty
        ? null
        : operationalContact,
    'phone': phone.isEmpty ? null : phone,
    'location': location.isEmpty ? null : location,
    'has_containers': hasContainers,
    'container_count': hasContainers ? containerCount : 0,
    'credit_days': creditDays,
    'payment_stage': paymentStage,
    'is_active': active,
    'payment_notes': paymentNotes.isEmpty ? null : paymentNotes,
    'manual_priority': manualPriority,
    'priority_note': priorityNote.isEmpty ? null : priorityNote,
  };

  factory FinanzasCompanyDirectoryRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasCompanyDirectoryRecord(
      companyId: (row['company_id'] ?? '').toString(),
      companyName: (row['company_name'] ?? '').toString(),
      source: (row['source'] ?? 'DIRECTO').toString(),
      linkedName: (row['linked_name'] ?? '').toString(),
      operationalContact: (row['operational_contact'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      location: (row['location'] ?? '').toString(),
      hasContainers: row['has_containers'] as bool? ?? false,
      containerCount: (row['container_count'] as num? ?? 0).toInt(),
      creditDays: (row['credit_days'] as num? ?? 0).toInt(),
      paymentStage: (row['payment_stage'] as String?) ?? 'AL_CORRIENTE',
      active: row['is_active'] as bool? ?? true,
      paymentNotes: (row['payment_notes'] ?? '').toString(),
      manualPriority: (row['manual_priority'] ?? 'NORMAL').toString(),
      priorityNote: (row['priority_note'] ?? '').toString(),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasCompanyDirectoryStore {
  static Future<List<FinanzasCompanyDirectoryRecord>> loadDirectory() async {
    final catalog = await FinanzasDataStore.loadCatalogSnapshot();
    final remoteByCompanyId = await _loadRemoteByCompanyId();
    final mergedByCompanyId = <String, FinanzasCompanyDirectoryRecord>{};
    for (final company in catalog.companies) {
      final remote = remoteByCompanyId[company.id];
      mergedByCompanyId[company.id] = FinanzasCompanyDirectoryRecord(
        companyId: company.id,
        companyName: company.name,
        source: company.source,
        linkedName: company.linkedName,
        operationalContact: remote?.operationalContact ?? '',
        phone: remote?.phone ?? '',
        location: remote?.location ?? '',
        hasContainers: remote?.hasContainers ?? false,
        containerCount: remote?.hasContainers == true
            ? remote!.containerCount
            : 0,
        creditDays: remote?.creditDays ?? 0,
        paymentStage: remote?.paymentStage ?? 'AL_CORRIENTE',
        active: company.active,
        paymentNotes: remote?.paymentNotes ?? '',
        manualPriority: remote?.manualPriority ?? 'NORMAL',
        priorityNote: remote?.priorityNote ?? '',
        updatedAt: remote?.updatedAt,
      );
    }
    final merged = mergedByCompanyId.values.toList(growable: false)
      ..sort((a, b) => compareMayoreoAlpha(a.companyName, b.companyName));
    final rowsToSync = merged
        .where(
          (record) => _needsSync(record, remoteByCompanyId[record.companyId]),
        )
        .toList(growable: false);

    if (rowsToSync.isNotEmpty) {
      try {
        await saveDirectoryRows(rowsToSync);
      } catch (_) {}
    }
    return merged;
  }

  static Future<void> saveDirectoryRow(
    FinanzasCompanyDirectoryRecord record,
  ) async {
    await Supabase.instance.client.from(_kFinDirectoryTable).upsert(
      <Map<String, dynamic>>[record.toUpsertJson()],
      onConflict: 'company_id',
    );
  }

  static Future<void> saveDirectoryRows(
    List<FinanzasCompanyDirectoryRecord> records,
  ) async {
    if (records.isEmpty) return;
    final deduped = <String, FinanzasCompanyDirectoryRecord>{
      for (final row in records) row.companyId: row,
    };
    await Supabase.instance.client
        .from(_kFinDirectoryTable)
        .upsert(
          deduped.values
              .map((row) => row.toUpsertJson())
              .toList(growable: false),
          onConflict: 'company_id',
        );
  }

  static Future<Map<String, FinanzasCompanyDirectoryRecord>>
  _loadRemoteByCompanyId() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinDirectoryTable)
          .select()
          .order('company_name');
      final records = <String, FinanzasCompanyDirectoryRecord>{};
      for (final raw in rows as List) {
        final record = FinanzasCompanyDirectoryRecord.fromRemoteRow(
          Map<String, dynamic>.from(raw as Map),
        );
        records[record.companyId] = record;
      }
      return records;
    } catch (_) {
      return <String, FinanzasCompanyDirectoryRecord>{};
    }
  }

  static bool _needsSync(
    FinanzasCompanyDirectoryRecord next,
    FinanzasCompanyDirectoryRecord? current,
  ) {
    if (current == null) return true;
    return current.companyName != next.companyName ||
        current.source != next.source ||
        current.linkedName != next.linkedName ||
        current.active != next.active;
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
