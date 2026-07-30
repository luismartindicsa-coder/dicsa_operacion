import 'package:supabase_flutter/supabase_flutter.dart';

import '../mayoreo/mayoreo_sorting.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'compras_data_store.dart';

const String _kComprasProviderDirectoryTable = 'compras_provider_directory';

class ComprasProviderDirectoryRecord {
  final String providerId;
  final String providerCode;
  final String providerName;
  final String catalogContact;
  final String operationalContact;
  final String phone;
  final String location;
  final bool hasContainers;
  final int containerCount;
  final int creditDays;
  final String paymentStage;
  final bool active;
  final String paymentNotes;
  final DateTime? updatedAt;

  const ComprasProviderDirectoryRecord({
    required this.providerId,
    required this.providerCode,
    required this.providerName,
    required this.catalogContact,
    required this.operationalContact,
    required this.phone,
    required this.location,
    required this.hasContainers,
    required this.containerCount,
    required this.creditDays,
    required this.paymentStage,
    required this.active,
    required this.paymentNotes,
    required this.updatedAt,
  });

  ComprasProviderDirectoryRecord copyWith({
    String? providerId,
    String? providerCode,
    String? providerName,
    String? catalogContact,
    String? operationalContact,
    String? phone,
    String? location,
    bool? hasContainers,
    int? containerCount,
    int? creditDays,
    String? paymentStage,
    bool? active,
    String? paymentNotes,
    DateTime? updatedAt,
  }) {
    return ComprasProviderDirectoryRecord(
      providerId: providerId ?? this.providerId,
      providerCode: providerCode ?? this.providerCode,
      providerName: providerName ?? this.providerName,
      catalogContact: catalogContact ?? this.catalogContact,
      operationalContact: operationalContact ?? this.operationalContact,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      hasContainers: hasContainers ?? this.hasContainers,
      containerCount: containerCount ?? this.containerCount,
      creditDays: creditDays ?? this.creditDays,
      paymentStage: paymentStage ?? this.paymentStage,
      active: active ?? this.active,
      paymentNotes: paymentNotes ?? this.paymentNotes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'provider_id': providerId,
    'provider_code': providerCode,
    'provider_name': providerName,
    'catalog_contact': catalogContact.isEmpty ? null : catalogContact,
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
  };

  factory ComprasProviderDirectoryRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return ComprasProviderDirectoryRecord(
      providerId: (row['provider_id'] ?? '').toString(),
      providerCode: (row['provider_code'] ?? '').toString(),
      providerName: (row['provider_name'] ?? '').toString(),
      catalogContact: (row['catalog_contact'] ?? '').toString(),
      operationalContact: (row['operational_contact'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      location: (row['location'] ?? '').toString(),
      hasContainers: row['has_containers'] as bool? ?? false,
      containerCount: (row['container_count'] as num? ?? 0).toInt(),
      creditDays: (row['credit_days'] as num? ?? 0).toInt(),
      paymentStage: (row['payment_stage'] as String?) ?? 'AL_CORRIENTE',
      active: row['is_active'] as bool? ?? true,
      paymentNotes: (row['payment_notes'] ?? '').toString(),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class ComprasProviderDirectoryStore {
  static Future<List<ComprasProviderDirectoryRecord>> loadDirectory() async {
    final catalog = await ComprasDataStore.loadCatalogSnapshot();
    final catalogProviders = catalog.companies;
    final remoteByProviderId = await _loadRemoteByProviderId();
    final rowsToSync = <ComprasProviderDirectoryRecord>[];

    final merged =
        catalogProviders
            .map((provider) {
              final remote = remoteByProviderId[provider.id];
              final record = ComprasProviderDirectoryRecord(
                providerId: provider.id,
                providerCode: provider.code,
                providerName: provider.name,
                catalogContact: provider.contact,
                operationalContact:
                    remote?.operationalContact ?? provider.contact,
                phone: remote?.phone ?? '',
                location: remote?.location ?? '',
                hasContainers: remote?.hasContainers ?? false,
                containerCount: remote?.hasContainers == true
                    ? remote!.containerCount
                    : 0,
                creditDays: remote?.creditDays ?? 0,
                paymentStage: remote?.paymentStage ?? 'AL_CORRIENTE',
                active: provider.active,
                paymentNotes: remote?.paymentNotes ?? '',
                updatedAt: remote?.updatedAt,
              );
              if (_needsSync(record, remote)) {
                rowsToSync.add(record);
              }
              return record;
            })
            .toList(growable: false)
          ..sort((a, b) => compareMayoreoAlpha(a.providerName, b.providerName));

    if (rowsToSync.isNotEmpty) {
      try {
        await saveDirectoryRows(rowsToSync);
      } catch (_) {}
    }
    return merged;
  }

  static Future<void> saveDirectoryRow(
    ComprasProviderDirectoryRecord record,
  ) async {
    await Supabase.instance.client.from(_kComprasProviderDirectoryTable).upsert(
      <Map<String, dynamic>>[record.toUpsertJson()],
      onConflict: 'provider_id',
    );
  }

  static Future<void> saveDirectoryRows(
    List<ComprasProviderDirectoryRecord> records,
  ) async {
    if (records.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasProviderDirectoryTable)
        .upsert(
          records.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'provider_id',
        );
  }

  static Future<Map<String, ComprasProviderDirectoryRecord>>
  _loadRemoteByProviderId() async {
    try {
      final rows = await fetchAllSupabaseRows(
        (from, to) => Supabase.instance.client
            .from(_kComprasProviderDirectoryTable)
            .select()
            .order('provider_name')
            .range(from, to),
      );
      final records = <String, ComprasProviderDirectoryRecord>{};
      for (final raw in rows) {
        final record = ComprasProviderDirectoryRecord.fromRemoteRow(
          Map<String, dynamic>.from(raw),
        );
        records[record.providerId] = record;
      }
      return records;
    } catch (_) {
      return <String, ComprasProviderDirectoryRecord>{};
    }
  }

  static bool _needsSync(
    ComprasProviderDirectoryRecord next,
    ComprasProviderDirectoryRecord? current,
  ) {
    if (current == null) return true;
    return current.providerCode != next.providerCode ||
        current.providerName != next.providerName ||
        current.catalogContact != next.catalogContact ||
        current.active != next.active;
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
