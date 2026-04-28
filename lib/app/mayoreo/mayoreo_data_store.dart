import 'package:supabase_flutter/supabase_flutter.dart';

import 'mayoreo_seed_catalog_data.dart';

const String _kMayoreoCounterpartiesTable = 'mayoreo_counterparties';
const String _kMayoreoMaterialsTable = 'mayoreo_material_catalog';
const String _kMayoreoPricesTable = 'mayoreo_counterparty_material_prices';
const String _kMayoreoPriceHistoryTable = 'mayoreo_price_adjustment_history';

class MayoreoCatalogCompanyRecord {
  final String id;
  final String code;
  final String name;
  final String contact;
  final bool active;
  final String notes;

  const MayoreoCatalogCompanyRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.contact,
    required this.active,
    required this.notes,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'name': name,
    'contact': contact,
    'active': active,
    'notes': notes,
  };

  factory MayoreoCatalogCompanyRecord.fromJson(Map<String, dynamic> json) {
    return MayoreoCatalogCompanyRecord(
      id: (json['id'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      contact: (json['contact'] as String?) ?? '',
      active: json['active'] as bool? ?? true,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

class MayoreoCatalogMaterialRecord {
  final String id;
  final String code;
  final String level;
  final String name;
  final String unit;
  final String category;
  final String? family;
  final String? generalMaterialId;
  final bool active;
  final String notes;

  const MayoreoCatalogMaterialRecord({
    required this.id,
    required this.code,
    required this.level,
    required this.name,
    required this.unit,
    required this.category,
    required this.family,
    required this.generalMaterialId,
    required this.active,
    required this.notes,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'level': level,
    'name': name,
    'unit': unit,
    'category': category,
    'family': family,
    'generalMaterialId': generalMaterialId,
    'active': active,
    'notes': notes,
  };

  factory MayoreoCatalogMaterialRecord.fromJson(Map<String, dynamic> json) {
    return MayoreoCatalogMaterialRecord(
      id: (json['id'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      level: (json['level'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      family: json['family'] as String?,
      generalMaterialId: json['generalMaterialId'] as String?,
      active: json['active'] as bool? ?? true,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

class MayoreoCatalogPriceRecord {
  final String id;
  final String companyId;
  final String materialId;
  final double amount;
  final bool active;
  final String notes;
  final DateTime? updatedAt;

  const MayoreoCatalogPriceRecord({
    required this.id,
    required this.companyId,
    required this.materialId,
    required this.amount,
    required this.active,
    required this.notes,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'companyId': companyId,
    'materialId': materialId,
    'amount': amount,
    'active': active,
    'notes': notes,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory MayoreoCatalogPriceRecord.fromJson(Map<String, dynamic> json) {
    return MayoreoCatalogPriceRecord(
      id: (json['id'] as String?) ?? '',
      companyId: (json['companyId'] as String?) ?? '',
      materialId: (json['materialId'] as String?) ?? '',
      amount: ((json['amount'] as num?) ?? 0).toDouble(),
      active: json['active'] as bool? ?? true,
      notes: (json['notes'] as String?) ?? '',
      updatedAt: _tryParseDateTime(json['updatedAt'] as String?),
    );
  }
}

class MayoreoPriceHistoryRecord {
  final String id;
  final String companyId;
  final String companyName;
  final String materialId;
  final String materialName;
  final double previousPrice;
  final double newPrice;
  final String reason;
  final DateTime createdAt;

  const MayoreoPriceHistoryRecord({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.materialId,
    required this.materialName,
    required this.previousPrice,
    required this.newPrice,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'companyId': companyId,
    'companyName': companyName,
    'materialId': materialId,
    'materialName': materialName,
    'previousPrice': previousPrice,
    'newPrice': newPrice,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MayoreoPriceHistoryRecord.fromJson(Map<String, dynamic> json) {
    return MayoreoPriceHistoryRecord(
      id: (json['id'] as String?) ?? '',
      companyId: (json['companyId'] as String?) ?? '',
      companyName: (json['companyName'] as String?) ?? '',
      materialId: (json['materialId'] as String?) ?? '',
      materialName: (json['materialName'] as String?) ?? '',
      previousPrice: ((json['previousPrice'] as num?) ?? 0).toDouble(),
      newPrice: ((json['newPrice'] as num?) ?? 0).toDouble(),
      reason: (json['reason'] as String?) ?? '',
      createdAt:
          _tryParseDateTime(json['createdAt'] as String?) ?? DateTime.now(),
    );
  }
}

class MayoreoCatalogSnapshot {
  final List<MayoreoCatalogCompanyRecord> companies;
  final List<MayoreoCatalogMaterialRecord> materials;
  final List<MayoreoCatalogPriceRecord> prices;

  const MayoreoCatalogSnapshot({
    required this.companies,
    required this.materials,
    required this.prices,
  });

  const MayoreoCatalogSnapshot.empty()
    : companies = const <MayoreoCatalogCompanyRecord>[],
      materials = const <MayoreoCatalogMaterialRecord>[],
      prices = const <MayoreoCatalogPriceRecord>[];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'companies': companies.map((row) => row.toJson()).toList(growable: false),
    'materials': materials.map((row) => row.toJson()).toList(growable: false),
    'prices': prices.map((row) => row.toJson()).toList(growable: false),
  };

  factory MayoreoCatalogSnapshot.fromJson(Map<String, dynamic> json) {
    return MayoreoCatalogSnapshot(
      companies: _jsonList(
        json['companies'],
      ).map(MayoreoCatalogCompanyRecord.fromJson).toList(growable: false),
      materials: _jsonList(
        json['materials'],
      ).map(MayoreoCatalogMaterialRecord.fromJson).toList(growable: false),
      prices: _jsonList(
        json['prices'],
      ).map(MayoreoCatalogPriceRecord.fromJson).toList(growable: false),
    );
  }
}

class MayoreoDataStore {
  static Future<void> _catalogSaveQueue = Future<void>.value();

  static Future<MayoreoCatalogSnapshot> loadCatalogSnapshot() async {
    try {
      final remote = await _loadRemoteCatalogSnapshot();
      return remote ?? _normalizeCatalogSnapshot(kMayoreoSeedCatalogSnapshot);
    } catch (_) {
      return _normalizeCatalogSnapshot(kMayoreoSeedCatalogSnapshot);
    }
  }

  static Future<void> saveCatalogSnapshot(
    MayoreoCatalogSnapshot snapshot,
  ) async {
    final normalized = _normalizeCatalogSnapshot(snapshot);
    _catalogSaveQueue = _catalogSaveQueue
        .catchError((_) {})
        .then((_) => _saveRemoteCatalogSnapshot(normalized));
    await _catalogSaveQueue;
  }

  static Future<List<MayoreoPriceHistoryRecord>> loadPriceHistory() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kMayoreoPriceHistoryTable)
          .select()
          .order('created_at', ascending: false)
          .limit(2500);
      return (rows as List)
          .map(
            (row) => MayoreoPriceHistoryRecord(
              id: (row as Map)['id'].toString(),
              companyId: (row['company_id'] as String?) ?? '',
              companyName: (row['company_name_snapshot'] as String?) ?? '',
              materialId: (row['material_id'] as String?) ?? '',
              materialName: (row['material_name_snapshot'] as String?) ?? '',
              previousPrice: ((row['previous_price'] as num?) ?? 0).toDouble(),
              newPrice: ((row['new_price'] as num?) ?? 0).toDouble(),
              reason: (row['reason'] as String?) ?? '',
              createdAt:
                  _tryParseDateTime(row['created_at'] as String?) ??
                  DateTime.now(),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <MayoreoPriceHistoryRecord>[];
    }
  }

  static Future<void> savePriceHistory(
    List<MayoreoPriceHistoryRecord> rows,
  ) async {}
}

const List<String> _kMayoreoCanonicalGeneralCategories = <String>[
  'CARTON',
  'CHATARRA',
  'METAL',
  'PLASTICO',
  'MADERA',
  'PAPEL',
];

MayoreoCatalogSnapshot _normalizeCatalogSnapshot(MayoreoCatalogSnapshot input) {
  final canonicalGeneralRows = <MayoreoCatalogMaterialRecord>[
    for (final category in _kMayoreoCanonicalGeneralCategories)
      MayoreoCatalogMaterialRecord(
        id: 'ma_general_${category.toLowerCase()}',
        code: category,
        level: 'GENERAL',
        name: category,
        unit: 'KG',
        category: category,
        family: null,
        generalMaterialId: null,
        active: true,
        notes: 'GENERAL BASE MAYOREO',
      ),
  ];
  final canonicalGeneralIds = <String, String>{
    for (final row in canonicalGeneralRows) row.category: row.id,
  };

  final normalizedCommercialRows = input.materials
      .where((row) => row.level.trim().toUpperCase() == 'COMERCIAL')
      .map((row) {
        final category = _canonicalMayoreoGeneralCategory(
          row.category,
          family: row.family,
          name: row.name,
        );
        return MayoreoCatalogMaterialRecord(
          id: row.id,
          code: row.code,
          level: 'COMERCIAL',
          name: row.name,
          unit: row.unit,
          category: category,
          family: category,
          generalMaterialId: canonicalGeneralIds[category],
          active: row.active,
          notes: row.notes,
        );
      })
      .toList(growable: false);

  return MayoreoCatalogSnapshot(
    companies: input.companies,
    materials: <MayoreoCatalogMaterialRecord>[
      ...canonicalGeneralRows,
      ...normalizedCommercialRows,
    ],
    prices: input.prices,
  );
}

String _canonicalMayoreoGeneralCategory(
  String? raw, {
  String? family,
  String? name,
}) {
  final merged = <String>[?raw, ?family, ?name].join(' ').toUpperCase();

  if (merged.contains('CARTON')) return 'CARTON';
  if (merged.contains('CHATARRA') || merged.contains('FIERRO')) {
    return 'CHATARRA';
  }
  if (merged.contains('PLASTICO') || merged.contains('PET')) {
    return 'PLASTICO';
  }
  if (merged.contains('MADERA') || merged.contains('TARIMA')) {
    return 'MADERA';
  }
  if (merged.contains('PAPEL') ||
      merged.contains('ARCHIVO') ||
      merged.contains('PERIODICO') ||
      merged.contains('LIBRO') ||
      merged.contains('ORDINARIO') ||
      merged.contains('REVISTA')) {
    return 'PAPEL';
  }
  return 'METAL';
}

Future<MayoreoCatalogSnapshot?> _loadRemoteCatalogSnapshot() async {
  final supa = Supabase.instance.client;
  final responses = await Future.wait([
    supa.from(_kMayoreoCounterpartiesTable).select().order('name'),
    supa.from(_kMayoreoMaterialsTable).select().order('level').order('name'),
    supa
        .from(_kMayoreoPricesTable)
        .select()
        .order('updated_at', ascending: false),
  ]);
  final companiesData = responses[0] as List;
  final materialsData = responses[1] as List;
  final pricesData = responses[2] as List;
  if (companiesData.isEmpty && materialsData.isEmpty && pricesData.isEmpty) {
    final bootstrap = _normalizeCatalogSnapshot(kMayoreoSeedCatalogSnapshot);
    try {
      await _saveRemoteCatalogSnapshot(bootstrap);
    } catch (_) {}
    return bootstrap;
  }
  return _normalizeCatalogSnapshot(
    MayoreoCatalogSnapshot(
      companies: companiesData
          .map(
            (row) => MayoreoCatalogCompanyRecord(
              id: (row as Map)['id'].toString(),
              code: (row['code'] as String?) ?? '',
              name: (row['name'] as String?) ?? '',
              contact: (row['contact'] as String?) ?? '',
              active: row['is_active'] as bool? ?? true,
              notes: (row['notes'] as String?) ?? '',
            ),
          )
          .toList(growable: false),
      materials: materialsData
          .map(
            (row) => MayoreoCatalogMaterialRecord(
              id: (row as Map)['id'].toString(),
              code: (row['code'] as String?) ?? '',
              level: (row['level'] as String?) ?? '',
              name: (row['name'] as String?) ?? '',
              unit: (row['unit'] as String?) ?? 'KG',
              category: (row['category'] as String?) ?? '',
              family: row['family'] as String?,
              generalMaterialId: row['general_material_id'] as String?,
              active: row['is_active'] as bool? ?? true,
              notes: (row['notes'] as String?) ?? '',
            ),
          )
          .toList(growable: false),
      prices: pricesData
          .map(
            (row) => MayoreoCatalogPriceRecord(
              id: (row as Map)['id'].toString(),
              companyId: (row['company_id'] as String?) ?? '',
              materialId: (row['material_id'] as String?) ?? '',
              amount: ((row['final_price'] as num?) ?? 0).toDouble(),
              active: row['is_active'] as bool? ?? true,
              notes: (row['notes'] as String?) ?? '',
              updatedAt: _tryParseDateTime(row['updated_at'] as String?),
            ),
          )
          .toList(growable: false),
    ),
  );
}

Future<void> _saveRemoteCatalogSnapshot(MayoreoCatalogSnapshot snapshot) async {
  final supa = Supabase.instance.client;

  if (snapshot.companies.isNotEmpty) {
    await supa
        .from(_kMayoreoCounterpartiesTable)
        .upsert(
          snapshot.companies
              .map(
                (row) => <String, dynamic>{
                  'id': row.id,
                  'code': row.code,
                  'name': row.name,
                  'contact': row.contact,
                  'is_active': row.active,
                  'notes': row.notes.isEmpty ? null : row.notes,
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  if (snapshot.materials.isNotEmpty) {
    await supa
        .from(_kMayoreoMaterialsTable)
        .upsert(
          snapshot.materials
              .map(
                (row) => <String, dynamic>{
                  'id': row.id,
                  'code': row.code,
                  'level': row.level,
                  'name': row.name,
                  'unit': row.unit,
                  'category': row.category,
                  'family': row.family,
                  'general_material_id': row.generalMaterialId,
                  'is_active': row.active,
                  'notes': row.notes.isEmpty ? null : row.notes,
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  if (snapshot.prices.isNotEmpty) {
    await supa
        .from(_kMayoreoPricesTable)
        .upsert(
          snapshot.prices
              .map(
                (row) => <String, dynamic>{
                  'id': row.id,
                  'company_id': row.companyId,
                  'material_id': row.materialId,
                  'final_price': row.amount,
                  'is_active': row.active,
                  'notes': row.notes.isEmpty ? null : row.notes,
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  final existingPriceIds = await _loadRemoteIds(supa, _kMayoreoPricesTable);
  final nextPriceIds = snapshot.prices.map((row) => row.id).toSet();
  final deletedPriceIds = existingPriceIds.difference(nextPriceIds).toList();
  if (deletedPriceIds.isNotEmpty) {
    await supa
        .from(_kMayoreoPricesTable)
        .delete()
        .inFilter('id', deletedPriceIds);
  }

  final existingMaterialIds = await _loadRemoteIds(
    supa,
    _kMayoreoMaterialsTable,
  );
  final nextMaterialIds = snapshot.materials.map((row) => row.id).toSet();
  final deletedMaterialIds = existingMaterialIds
      .difference(nextMaterialIds)
      .toList();
  if (deletedMaterialIds.isNotEmpty) {
    await supa
        .from(_kMayoreoMaterialsTable)
        .delete()
        .inFilter('id', deletedMaterialIds);
  }

  final existingCompanyIds = await _loadRemoteIds(
    supa,
    _kMayoreoCounterpartiesTable,
  );
  final nextCompanyIds = snapshot.companies.map((row) => row.id).toSet();
  final deletedCompanyIds = existingCompanyIds
      .difference(nextCompanyIds)
      .toList();
  if (deletedCompanyIds.isNotEmpty) {
    await supa
        .from(_kMayoreoCounterpartiesTable)
        .delete()
        .inFilter('id', deletedCompanyIds);
  }
}

Future<Set<String>> _loadRemoteIds(SupabaseClient supa, String table) async {
  final rows = await supa.from(table).select('id');
  return (rows as List).map((row) => (row as Map)['id'].toString()).toSet();
}

List<Map<String, dynamic>> _jsonList(Object? value) {
  final raw = value as List<dynamic>? ?? const <dynamic>[];
  return raw
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
