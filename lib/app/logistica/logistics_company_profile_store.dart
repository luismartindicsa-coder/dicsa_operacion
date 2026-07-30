import 'package:supabase_flutter/supabase_flutter.dart';

import '../mayoreo/mayoreo_sorting.dart';

const String _kLogisticsCompanyProfilesTable = 'logistics_company_profiles';

const List<String> kLogisticsScheduleFlexibilityOptions = <String>[
  'POR_DEFINIR',
  'FIJO',
  'NEGOCIABLE',
  'RESTRINGIDO',
];

const List<String> kLogisticsCollectionUrgencyOptions = <String>[
  'BAJA',
  'MEDIA',
  'ALTA',
  'CRITICA',
];

const List<String> kLogisticsVolumePressureOptions = <String>[
  'POR_DEFINIR',
  'BAJO',
  'MEDIO',
  'ALTO',
];

String logisticsScheduleFlexibilityLabel(String value) {
  switch (value) {
    case 'FIJO':
      return 'Fijo';
    case 'NEGOCIABLE':
      return 'Negociable';
    case 'RESTRINGIDO':
      return 'Restringido';
    default:
      return 'Por definir';
  }
}

String logisticsCollectionUrgencyLabel(String value) {
  switch (value) {
    case 'BAJA':
      return 'Baja';
    case 'ALTA':
      return 'Alta';
    case 'CRITICA':
      return 'Critica';
    default:
      return 'Media';
  }
}

String logisticsVolumePressureLabel(String value) {
  switch (value) {
    case 'BAJO':
      return 'Bajo';
    case 'MEDIO':
      return 'Medio';
    case 'ALTO':
      return 'Alto';
    default:
      return 'Por definir';
  }
}

class LogisticsCompanyProfileRecord {
  final String siteId;
  final String siteName;
  final bool active;
  final String? zoneId;
  final String zoneNotes;
  final double? latitude;
  final double? longitude;
  final String operationalContact;
  final String contactPhone;
  final String addressLine;
  final String addressReference;
  final String pickupWindow;
  final String scheduleFlexibility;
  final bool earlyPickupRequired;
  final bool hasContainers;
  final int containerCount;
  final String containerCapacityNote;
  final String collectionUrgency;
  final String volumePressure;
  final String notes;
  final DateTime? updatedAt;

  const LogisticsCompanyProfileRecord({
    required this.siteId,
    required this.siteName,
    required this.active,
    required this.zoneId,
    required this.zoneNotes,
    required this.latitude,
    required this.longitude,
    required this.operationalContact,
    required this.contactPhone,
    required this.addressLine,
    required this.addressReference,
    required this.pickupWindow,
    required this.scheduleFlexibility,
    required this.earlyPickupRequired,
    required this.hasContainers,
    required this.containerCount,
    required this.containerCapacityNote,
    required this.collectionUrgency,
    required this.volumePressure,
    required this.notes,
    required this.updatedAt,
  });

  LogisticsCompanyProfileRecord copyWith({
    String? siteId,
    String? siteName,
    bool? active,
    String? zoneId,
    bool clearZoneId = false,
    String? zoneNotes,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? operationalContact,
    String? contactPhone,
    String? addressLine,
    String? addressReference,
    String? pickupWindow,
    String? scheduleFlexibility,
    bool? earlyPickupRequired,
    bool? hasContainers,
    int? containerCount,
    String? containerCapacityNote,
    String? collectionUrgency,
    String? volumePressure,
    String? notes,
    DateTime? updatedAt,
  }) {
    return LogisticsCompanyProfileRecord(
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      active: active ?? this.active,
      zoneId: clearZoneId ? null : (zoneId ?? this.zoneId),
      zoneNotes: zoneNotes ?? this.zoneNotes,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      operationalContact: operationalContact ?? this.operationalContact,
      contactPhone: contactPhone ?? this.contactPhone,
      addressLine: addressLine ?? this.addressLine,
      addressReference: addressReference ?? this.addressReference,
      pickupWindow: pickupWindow ?? this.pickupWindow,
      scheduleFlexibility: scheduleFlexibility ?? this.scheduleFlexibility,
      earlyPickupRequired: earlyPickupRequired ?? this.earlyPickupRequired,
      hasContainers: hasContainers ?? this.hasContainers,
      containerCount: containerCount ?? this.containerCount,
      containerCapacityNote:
          containerCapacityNote ?? this.containerCapacityNote,
      collectionUrgency: collectionUrgency ?? this.collectionUrgency,
      volumePressure: volumePressure ?? this.volumePressure,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'site_id': siteId,
    'site_name': siteName,
    'zone_id': zoneId,
    'zone_notes': zoneNotes.isEmpty ? null : zoneNotes,
    'latitude': latitude,
    'longitude': longitude,
    'operational_contact': operationalContact.isEmpty
        ? null
        : operationalContact,
    'contact_phone': contactPhone.isEmpty ? null : contactPhone,
    'address_line': addressLine.isEmpty ? null : addressLine,
    'address_reference': addressReference.isEmpty ? null : addressReference,
    'pickup_window': pickupWindow.isEmpty ? null : pickupWindow,
    'schedule_flexibility': scheduleFlexibility,
    'early_pickup_required': earlyPickupRequired,
    'has_containers': hasContainers,
    'container_count': hasContainers ? containerCount : 0,
    'container_capacity_note': containerCapacityNote.isEmpty
        ? null
        : containerCapacityNote,
    'collection_urgency': collectionUrgency,
    'volume_pressure': volumePressure,
    'notes': notes.isEmpty ? null : notes,
  };

  factory LogisticsCompanyProfileRecord.fromRemoteRow(
    Map<String, dynamic> row, {
    bool active = true,
  }) {
    return LogisticsCompanyProfileRecord(
      siteId: (row['site_id'] ?? '').toString(),
      siteName: (row['site_name'] ?? '').toString(),
      active: active,
      zoneId: row['zone_id']?.toString(),
      zoneNotes: (row['zone_notes'] ?? '').toString(),
      latitude: _tryParseDouble(row['latitude']),
      longitude: _tryParseDouble(row['longitude']),
      operationalContact: (row['operational_contact'] ?? '').toString(),
      contactPhone: (row['contact_phone'] ?? '').toString(),
      addressLine: (row['address_line'] ?? '').toString(),
      addressReference: (row['address_reference'] ?? '').toString(),
      pickupWindow: (row['pickup_window'] ?? '').toString(),
      scheduleFlexibility: (row['schedule_flexibility'] ?? 'POR_DEFINIR')
          .toString(),
      earlyPickupRequired: row['early_pickup_required'] as bool? ?? false,
      hasContainers: row['has_containers'] as bool? ?? false,
      containerCount: (row['container_count'] as num? ?? 0).toInt(),
      containerCapacityNote: (row['container_capacity_note'] ?? '').toString(),
      collectionUrgency: (row['collection_urgency'] ?? 'MEDIA').toString(),
      volumePressure: (row['volume_pressure'] ?? 'POR_DEFINIR').toString(),
      notes: (row['notes'] ?? '').toString(),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class LogisticsCompanyProfileStore {
  static Future<List<LogisticsCompanyProfileRecord>> loadProfiles() async {
    final client = Supabase.instance.client;
    final responses = await Future.wait<dynamic>([
      client
          .from('sites')
          .select('id,name,type,is_active')
          .eq('type', 'cliente')
          .order('name'),
      _loadRemoteBySiteId(),
    ]);

    final sites = (responses[0] as List).cast<Map<String, dynamic>>();
    final remoteBySiteId =
        responses[1] as Map<String, LogisticsCompanyProfileRecord>;
    final rowsToSync = <LogisticsCompanyProfileRecord>[];

    final merged =
        sites
            .map((site) {
              final siteId = (site['id'] ?? '').toString();
              final siteName = (site['name'] ?? '').toString();
              final active = site['is_active'] as bool? ?? true;
              final remote = remoteBySiteId[siteId];
              final record = LogisticsCompanyProfileRecord(
                siteId: siteId,
                siteName: siteName,
                active: active,
                zoneId: remote?.zoneId,
                zoneNotes: remote?.zoneNotes ?? '',
                latitude: remote?.latitude,
                longitude: remote?.longitude,
                operationalContact: remote?.operationalContact ?? '',
                contactPhone: remote?.contactPhone ?? '',
                addressLine: remote?.addressLine ?? '',
                addressReference: remote?.addressReference ?? '',
                pickupWindow: remote?.pickupWindow ?? '',
                scheduleFlexibility:
                    remote?.scheduleFlexibility ?? 'POR_DEFINIR',
                earlyPickupRequired: remote?.earlyPickupRequired ?? false,
                hasContainers: remote?.hasContainers ?? false,
                containerCount: remote?.hasContainers == true
                    ? remote!.containerCount
                    : 0,
                containerCapacityNote: remote?.containerCapacityNote ?? '',
                collectionUrgency: remote?.collectionUrgency ?? 'MEDIA',
                volumePressure: remote?.volumePressure ?? 'POR_DEFINIR',
                notes: remote?.notes ?? '',
                updatedAt: remote?.updatedAt,
              );
              if (_needsSync(record, remote)) {
                rowsToSync.add(record);
              }
              return record;
            })
            .where((record) => record.active)
            .toList(growable: false)
          ..sort((a, b) => compareMayoreoAlpha(a.siteName, b.siteName));

    if (rowsToSync.isNotEmpty) {
      try {
        await saveProfileRows(rowsToSync);
      } catch (_) {}
    }

    return merged;
  }

  static Future<void> saveProfileRow(
    LogisticsCompanyProfileRecord record,
  ) async {
    await Supabase.instance.client.from(_kLogisticsCompanyProfilesTable).upsert(
      <Map<String, dynamic>>[record.toUpsertJson()],
      onConflict: 'site_id',
    );
  }

  static Future<void> saveProfileRows(
    List<LogisticsCompanyProfileRecord> records,
  ) async {
    if (records.isEmpty) return;
    await Supabase.instance.client
        .from(_kLogisticsCompanyProfilesTable)
        .upsert(
          records.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'site_id',
        );
  }

  static Future<Map<String, LogisticsCompanyProfileRecord>>
  _loadRemoteBySiteId() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kLogisticsCompanyProfilesTable)
          .select()
          .order('site_name');
      final records = <String, LogisticsCompanyProfileRecord>{};
      for (final raw in rows as List) {
        final record = LogisticsCompanyProfileRecord.fromRemoteRow(
          Map<String, dynamic>.from(raw as Map),
        );
        records[record.siteId] = record;
      }
      return records;
    } catch (_) {
      return <String, LogisticsCompanyProfileRecord>{};
    }
  }

  static bool _needsSync(
    LogisticsCompanyProfileRecord next,
    LogisticsCompanyProfileRecord? current,
  ) {
    if (current == null) return true;
    return current.siteName != next.siteName;
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}

double? _tryParseDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString().trim());
}
