import 'package:supabase_flutter/supabase_flutter.dart';

import 'compras_seed_catalog_data.dart';
import '../mayoreo/mayoreo_sorting.dart';

const String _kComprasCounterpartiesTable = 'compras_counterparties';
const String _kComprasMaterialsTable = 'compras_material_catalog';
const String _kComprasPricesTable = 'compras_counterparty_material_prices';
const String _kComprasPriceHistoryTable = 'compras_price_adjustment_history';

class ComprasCatalogProviderRecord {
  final String id;
  final String code;
  final String name;
  final String contact;
  final bool active;
  final String notes;

  const ComprasCatalogProviderRecord({
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

  factory ComprasCatalogProviderRecord.fromJson(Map<String, dynamic> json) {
    return ComprasCatalogProviderRecord(
      id: (json['id'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      contact: (json['contact'] as String?) ?? '',
      active: json['active'] as bool? ?? true,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

class ComprasCatalogMaterialRecord {
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

  const ComprasCatalogMaterialRecord({
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

  factory ComprasCatalogMaterialRecord.fromJson(Map<String, dynamic> json) {
    return ComprasCatalogMaterialRecord(
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

class ComprasCatalogPriceRecord {
  final String id;
  final String companyId;
  final String materialId;
  final double amount;
  final bool active;
  final String notes;
  final DateTime? updatedAt;

  const ComprasCatalogPriceRecord({
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

  factory ComprasCatalogPriceRecord.fromJson(Map<String, dynamic> json) {
    return ComprasCatalogPriceRecord(
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

class ComprasPriceHistoryRecord {
  final String id;
  final String companyId;
  final String companyName;
  final String materialId;
  final String materialName;
  final double previousPrice;
  final double newPrice;
  final String reason;
  final DateTime createdAt;

  const ComprasPriceHistoryRecord({
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

  factory ComprasPriceHistoryRecord.fromJson(Map<String, dynamic> json) {
    return ComprasPriceHistoryRecord(
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

class ComprasCatalogSnapshot {
  final List<ComprasCatalogProviderRecord> companies;
  final List<ComprasCatalogMaterialRecord> materials;
  final List<ComprasCatalogPriceRecord> prices;

  const ComprasCatalogSnapshot({
    required this.companies,
    required this.materials,
    required this.prices,
  });

  const ComprasCatalogSnapshot.empty()
    : companies = const <ComprasCatalogProviderRecord>[],
      materials = const <ComprasCatalogMaterialRecord>[],
      prices = const <ComprasCatalogPriceRecord>[];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'companies': companies.map((row) => row.toJson()).toList(growable: false),
    'materials': materials.map((row) => row.toJson()).toList(growable: false),
    'prices': prices.map((row) => row.toJson()).toList(growable: false),
  };

  factory ComprasCatalogSnapshot.fromJson(Map<String, dynamic> json) {
    return ComprasCatalogSnapshot(
      companies: _jsonList(
        json['companies'],
      ).map(ComprasCatalogProviderRecord.fromJson).toList(growable: false),
      materials: _jsonList(
        json['materials'],
      ).map(ComprasCatalogMaterialRecord.fromJson).toList(growable: false),
      prices: _jsonList(
        json['prices'],
      ).map(ComprasCatalogPriceRecord.fromJson).toList(growable: false),
    );
  }
}

class ComprasDataStore {
  static Future<void> _catalogSaveQueue = Future<void>.value();

  static Future<ComprasCatalogSnapshot> loadCatalogSnapshot() async {
    try {
      final remote = await _loadRemoteCatalogSnapshot();
      return remote ?? _normalizeCatalogSnapshot(kComprasSeedCatalogSnapshot);
    } catch (_) {
      return _normalizeCatalogSnapshot(kComprasSeedCatalogSnapshot);
    }
  }

  static Future<void> saveCatalogSnapshot(
    ComprasCatalogSnapshot snapshot,
  ) async {
    final normalized = _normalizeCatalogSnapshot(snapshot);
    _catalogSaveQueue = _catalogSaveQueue
        .catchError((_) {})
        .then((_) => _saveRemoteCatalogSnapshot(normalized));
    await _catalogSaveQueue;
  }

  static Future<void> saveCompanyRecords(
    List<ComprasCatalogProviderRecord> rows,
  ) async {
    final normalized = _normalizeCatalogSnapshot(
      ComprasCatalogSnapshot(
        companies: rows,
        materials: const <ComprasCatalogMaterialRecord>[],
        prices: const <ComprasCatalogPriceRecord>[],
      ),
    );
    final companies = normalized.companies;
    if (companies.isNotEmpty) {
      await Supabase.instance.client
          .from(_kComprasCounterpartiesTable)
          .upsert(
            companies
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
  }

  static Future<void> savePriceRecords(
    List<ComprasCatalogPriceRecord> rows,
  ) async {
    final normalized = _normalizeCatalogSnapshot(
      ComprasCatalogSnapshot(
        companies: const <ComprasCatalogProviderRecord>[],
        materials: const <ComprasCatalogMaterialRecord>[],
        prices: rows,
      ),
    );
    final prices = normalized.prices;
    if (prices.isNotEmpty) {
      await Supabase.instance.client
          .from(_kComprasPricesTable)
          .upsert(
            prices
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
  }

  static Future<void> saveMaterialRecords(
    List<ComprasCatalogMaterialRecord> rows,
  ) async {
    final normalized = _normalizeCatalogSnapshot(
      ComprasCatalogSnapshot(
        companies: const <ComprasCatalogProviderRecord>[],
        materials: rows,
        prices: const <ComprasCatalogPriceRecord>[],
      ),
    );
    final materials = normalized.materials;
    if (materials.isNotEmpty) {
      await Supabase.instance.client
          .from(_kComprasMaterialsTable)
          .upsert(
            materials
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
  }

  static Future<void> deleteCompanyRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasCounterpartiesTable)
        .delete()
        .inFilter('id', ids);
  }

  static Future<void> deleteMaterialRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasMaterialsTable)
        .delete()
        .inFilter('id', ids);
  }

  static Future<void> deletePriceRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasPricesTable)
        .delete()
        .inFilter('id', ids);
  }

  static Future<List<ComprasPriceHistoryRecord>> loadPriceHistory() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kComprasPriceHistoryTable)
          .select()
          .order('created_at', ascending: false)
          .limit(2500);
      return (rows as List)
          .map(
            (row) => ComprasPriceHistoryRecord(
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
      return const <ComprasPriceHistoryRecord>[];
    }
  }

  static Future<void> savePriceHistory(
    List<ComprasPriceHistoryRecord> rows,
  ) async {
    if (rows.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasPriceHistoryTable)
        .upsert(
          rows
              .map(
                (row) => <String, dynamic>{
                  'id': row.id,
                  'company_id': row.companyId,
                  'company_name_snapshot': row.companyName,
                  'material_id': row.materialId,
                  'material_name_snapshot': row.materialName,
                  'previous_price': row.previousPrice,
                  'new_price': row.newPrice,
                  'reason': row.reason,
                  'created_at': row.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }
}

Future<List<Map<String, dynamic>>> _fetchAllRows(
  PostgrestTransformBuilder<List<Map<String, dynamic>>> Function(
    int from,
    int to,
  )
  buildQuery,
) async {
  const int pageSize = 1000;
  final List<Map<String, dynamic>> collected = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final rows = await buildQuery(from, from + pageSize - 1);
    collected.addAll(rows);
    if (rows.length < pageSize) {
      break;
    }
    from += pageSize;
  }
  return collected;
}

const List<String> _kMayoreoCanonicalGeneralCategories = <String>[
  'CARTON',
  'CHATARRA',
  'METAL',
  'PLASTICO',
  'MADERA',
  'PAPEL',
  'VIDRIO',
  'TEXTIL',
  'OTROS',
];

ComprasCatalogSnapshot _normalizeCatalogSnapshot(ComprasCatalogSnapshot input) {
  final existingGeneralRows = input.materials
      .where((row) => row.level.trim().toUpperCase() == 'GENERAL')
      .map(
        (row) => ComprasCatalogMaterialRecord(
          id: row.id,
          code: row.code,
          level: 'GENERAL',
          name: row.name,
          unit: row.unit,
          category: _canonicalMayoreoGeneralCategory(
            row.category,
            family: row.family,
            name: row.name,
          ),
          family: null,
          generalMaterialId: null,
          active: row.active,
          notes: row.notes,
        ),
      )
      .toList(growable: false);
  final existingGeneralByCategory = <String, ComprasCatalogMaterialRecord>{
    for (final row in existingGeneralRows) row.category: row,
  };
  final canonicalGeneralRows = <ComprasCatalogMaterialRecord>[
    for (final category in _kMayoreoCanonicalGeneralCategories)
      existingGeneralByCategory[category] ??
          ComprasCatalogMaterialRecord(
            id: 'ca_general_${category.toLowerCase()}',
            code: category,
            level: 'GENERAL',
            name: category,
            unit: 'KG',
            category: category,
            family: null,
            generalMaterialId: null,
            active: true,
            notes: 'GENERAL BASE COMPRAS',
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
        return ComprasCatalogMaterialRecord(
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

  final companies = input.companies.toList(growable: false)
    ..sort((a, b) => compareMayoreoAlpha(a.name, b.name));
  final extraGeneralRows = existingGeneralRows
      .where(
        (row) =>
            !canonicalGeneralRows.any((canonical) => canonical.id == row.id),
      )
      .toList(growable: false);
  final materials =
      <ComprasCatalogMaterialRecord>[
        ...canonicalGeneralRows,
        ...extraGeneralRows,
        ...normalizedCommercialRows,
      ]..sort((a, b) {
        final levelCompare = compareMayoreoAlpha(a.level, b.level);
        if (levelCompare != 0) return levelCompare;
        return compareMayoreoAlpha(a.name, b.name);
      });
  final prices = input.prices.toList(growable: false)
    ..sort((a, b) {
      final companyCompare = compareMayoreoAlpha(a.companyId, b.companyId);
      if (companyCompare != 0) return companyCompare;
      final materialCompare = compareMayoreoAlpha(a.materialId, b.materialId);
      if (materialCompare != 0) return materialCompare;
      return compareMayoreoAlpha(a.id, b.id);
    });

  return ComprasCatalogSnapshot(
    companies: companies,
    materials: materials,
    prices: prices,
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
  if (merged.contains('VIDRIO') || merged.contains('CRISTAL')) {
    return 'VIDRIO';
  }
  if (merged.contains('TEXTIL') ||
      merged.contains('TELA') ||
      merged.contains('TRAPO') ||
      merged.contains('ROPA')) {
    return 'TEXTIL';
  }
  if (merged.contains('OTRO') || merged.contains('OTROS')) {
    return 'OTROS';
  }
  return 'OTROS';
}

Future<ComprasCatalogSnapshot?> _loadRemoteCatalogSnapshot() async {
  final supa = Supabase.instance.client;
  final responses = await Future.wait([
    _fetchAllRows(
      (from, to) => supa
          .from(_kComprasCounterpartiesTable)
          .select()
          .order('name')
          .range(from, to),
    ),
    _fetchAllRows(
      (from, to) => supa
          .from(_kComprasMaterialsTable)
          .select()
          .order('level')
          .order('name')
          .range(from, to),
    ),
    _fetchAllRows(
      (from, to) => supa
          .from(_kComprasPricesTable)
          .select()
          .order('updated_at', ascending: false)
          .range(from, to),
    ),
  ]);
  final companiesData = responses[0] as List;
  final materialsData = responses[1] as List;
  final pricesData = responses[2] as List;
  if (companiesData.isEmpty && materialsData.isEmpty && pricesData.isEmpty) {
    final bootstrap = _normalizeCatalogSnapshot(kComprasSeedCatalogSnapshot);
    try {
      await _saveRemoteCatalogSnapshot(bootstrap);
    } catch (_) {}
    return bootstrap;
  }
  return _normalizeCatalogSnapshot(
    ComprasCatalogSnapshot(
      companies: companiesData
          .map(
            (row) => ComprasCatalogProviderRecord(
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
            (row) => ComprasCatalogMaterialRecord(
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
            (row) => ComprasCatalogPriceRecord(
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

Future<void> _saveRemoteCatalogSnapshot(ComprasCatalogSnapshot snapshot) async {
  final supa = Supabase.instance.client;

  if (snapshot.companies.isNotEmpty) {
    await supa
        .from(_kComprasCounterpartiesTable)
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
        .from(_kComprasMaterialsTable)
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
        .from(_kComprasPricesTable)
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
