import 'package:supabase_flutter/supabase_flutter.dart';

import '../compras/compras_data_store.dart';
import '../mayoreo/mayoreo_data_store.dart';
import '../mayoreo/mayoreo_sorting.dart';
import 'finanzas_seed_catalog_data.dart';

const String _kFinCompaniesTable = 'finanzas_catalog_companies';
const String _kFinConceptsTable = 'finanzas_catalog_concepts';
const String _kFinRelationsTable = 'finanzas_catalog_relations';

class FinanzasCatalogCompanyRecord {
  final String id;
  final String name;
  final String source;
  final String linkedName;
  final bool active;
  final String notes;

  const FinanzasCatalogCompanyRecord({
    required this.id,
    required this.name,
    required this.source,
    required this.linkedName,
    required this.active,
    required this.notes,
  });
}

class FinanzasCatalogConceptRecord {
  final String id;
  final String name;
  final String family;
  final String direction;
  final bool requiresCompany;
  final bool active;
  final String notes;

  const FinanzasCatalogConceptRecord({
    required this.id,
    required this.name,
    required this.family,
    required this.direction,
    required this.requiresCompany,
    required this.active,
    required this.notes,
  });
}

class FinanzasCatalogRelationRecord {
  final String id;
  final String companyId;
  final String conceptId;
  final String mode;
  final bool active;
  final String notes;

  const FinanzasCatalogRelationRecord({
    required this.id,
    required this.companyId,
    required this.conceptId,
    required this.mode,
    required this.active,
    required this.notes,
  });
}

class FinanzasCatalogSnapshot {
  final List<FinanzasCatalogCompanyRecord> companies;
  final List<FinanzasCatalogConceptRecord> concepts;
  final List<FinanzasCatalogRelationRecord> relations;

  const FinanzasCatalogSnapshot({
    required this.companies,
    required this.concepts,
    required this.relations,
  });

  const FinanzasCatalogSnapshot.empty()
    : companies = const <FinanzasCatalogCompanyRecord>[],
      concepts = const <FinanzasCatalogConceptRecord>[],
      relations = const <FinanzasCatalogRelationRecord>[];
}

class FinanzasDataStore {
  static Future<void> _saveQueue = Future<void>.value();

  static Future<FinanzasCatalogSnapshot> loadCatalogSnapshot() async {
    try {
      final remote = await _loadRemoteCatalogSnapshot();
      return remote ?? _normalizeSnapshot(kFinanzasSeedCatalogSnapshot);
    } catch (_) {
      return _normalizeSnapshot(kFinanzasSeedCatalogSnapshot);
    }
  }

  static Future<void> saveCatalogSnapshot(
    FinanzasCatalogSnapshot snapshot,
  ) async {
    final normalized = _normalizeSnapshot(snapshot);
    _saveQueue = _saveQueue
        .catchError((_) {})
        .then((_) => _saveRemoteCatalogSnapshot(normalized));
    await _saveQueue;
  }
}

FinanzasCatalogSnapshot _normalizeSnapshot(FinanzasCatalogSnapshot input) {
  final companies = input.companies.toList(growable: false)
    ..sort((a, b) => compareMayoreoAlpha(a.name, b.name));
  final concepts = input.concepts.toList(growable: false)
    ..sort((a, b) => compareMayoreoAlpha(a.name, b.name));
  final relations = input.relations.toList(growable: false)
    ..sort((a, b) {
      final companyCompare = compareMayoreoAlpha(a.companyId, b.companyId);
      if (companyCompare != 0) return companyCompare;
      final conceptCompare = compareMayoreoAlpha(a.conceptId, b.conceptId);
      if (conceptCompare != 0) return conceptCompare;
      return compareMayoreoAlpha(a.id, b.id);
    });
  return FinanzasCatalogSnapshot(
    companies: companies,
    concepts: concepts,
    relations: relations,
  );
}

Future<FinanzasCatalogSnapshot?> _loadRemoteCatalogSnapshot() async {
  final supa = Supabase.instance.client;
  final companiesData =
      await supa.from(_kFinCompaniesTable).select().order('name') as List;
  final conceptsData =
      await supa.from(_kFinConceptsTable).select().order('name') as List;
  final relationsData =
      await supa.from(_kFinRelationsTable).select().order('created_at') as List;
  final mayoreoSnapshot = await MayoreoDataStore.loadCatalogSnapshot();
  final comprasSnapshot = await ComprasDataStore.loadCatalogSnapshot();
  if (companiesData.isEmpty && conceptsData.isEmpty && relationsData.isEmpty) {
    final bootstrap = _mergeExternalCompanies(
      _normalizeSnapshot(kFinanzasSeedCatalogSnapshot),
      mayoreoSnapshot: mayoreoSnapshot,
      comprasSnapshot: comprasSnapshot,
    );
    try {
      await _saveRemoteCatalogSnapshot(bootstrap);
    } catch (_) {}
    return bootstrap;
  }
  final snapshot = _normalizeSnapshot(
    FinanzasCatalogSnapshot(
      companies: companiesData
          .map(
            (row) => FinanzasCatalogCompanyRecord(
              id: (row as Map)['id'].toString(),
              name: (row['name'] as String?) ?? '',
              source: (row['source'] as String?) ?? 'DIRECTO',
              linkedName: (row['linked_name'] as String?) ?? '',
              active: row['is_active'] as bool? ?? true,
              notes: (row['notes'] as String?) ?? '',
            ),
          )
          .toList(growable: false),
      concepts: conceptsData
          .map(
            (row) => FinanzasCatalogConceptRecord(
              id: (row as Map)['id'].toString(),
              name: (row['name'] as String?) ?? '',
              family: (row['family'] as String?) ?? 'OTRO',
              direction: (row['direction'] as String?) ?? 'SALIDA',
              requiresCompany: row['requires_company'] as bool? ?? true,
              active: row['is_active'] as bool? ?? true,
              notes: (row['notes'] as String?) ?? '',
            ),
          )
          .toList(growable: false),
      relations: relationsData
          .map(
            (row) => FinanzasCatalogRelationRecord(
              id: (row as Map)['id'].toString(),
              companyId: (row['company_id'] as String?) ?? '',
              conceptId: (row['concept_id'] as String?) ?? '',
              mode: (row['mode'] as String?) ?? 'MANUAL',
              active: row['is_active'] as bool? ?? true,
              notes: (row['notes'] as String?) ?? '',
            ),
          )
          .toList(growable: false),
    ),
  );
  final merged = _mergeExternalCompanies(
    snapshot,
    mayoreoSnapshot: mayoreoSnapshot,
    comprasSnapshot: comprasSnapshot,
  );
  if (_shouldSyncMergedCompanies(snapshot, merged)) {
    try {
      await _saveRemoteCatalogSnapshot(merged);
    } catch (_) {}
  }
  return merged;
}

FinanzasCatalogSnapshot _mergeExternalCompanies(
  FinanzasCatalogSnapshot base, {
  required MayoreoCatalogSnapshot mayoreoSnapshot,
  required ComprasCatalogSnapshot comprasSnapshot,
}) {
  final mergedCompanies = base.companies.toList(growable: true);
  final existingIds = mergedCompanies.map((row) => row.id).toSet();

  for (final company in mayoreoSnapshot.companies) {
    final id = 'ventas_${company.id}';
    if (existingIds.contains(id)) continue;
    mergedCompanies.add(
      FinanzasCatalogCompanyRecord(
        id: id,
        name: company.name,
        source: 'VENTAS',
        linkedName: company.name,
        active: company.active,
        notes: 'SINCRONIZADO DESDE VENTAS MAYOREO',
      ),
    );
    existingIds.add(id);
  }

  for (final company in comprasSnapshot.companies) {
    final id = 'compras_${company.id}';
    if (existingIds.contains(id)) continue;
    mergedCompanies.add(
      FinanzasCatalogCompanyRecord(
        id: id,
        name: company.name,
        source: 'COMPRAS',
        linkedName: company.name,
        active: company.active,
        notes: 'SINCRONIZADO DESDE COMPRAS MAYOREO',
      ),
    );
    existingIds.add(id);
  }

  return _normalizeSnapshot(
    FinanzasCatalogSnapshot(
      companies: mergedCompanies,
      concepts: base.concepts,
      relations: base.relations,
    ),
  );
}

bool _shouldSyncMergedCompanies(
  FinanzasCatalogSnapshot current,
  FinanzasCatalogSnapshot merged,
) {
  if (current.companies.length != merged.companies.length) return true;
  final currentIds = current.companies.map((row) => row.id).toSet();
  final mergedIds = merged.companies.map((row) => row.id).toSet();
  return currentIds.length != mergedIds.length ||
      currentIds.difference(mergedIds).isNotEmpty;
}

Future<void> _saveRemoteCatalogSnapshot(
  FinanzasCatalogSnapshot snapshot,
) async {
  final supa = Supabase.instance.client;

  if (snapshot.companies.isNotEmpty) {
    await supa
        .from(_kFinCompaniesTable)
        .upsert(
          snapshot.companies
              .map(
                (row) => <String, dynamic>{
                  'id': row.id,
                  'name': row.name,
                  'source': row.source,
                  'linked_name': row.linkedName.isEmpty ? null : row.linkedName,
                  'is_active': row.active,
                  'notes': row.notes.isEmpty ? null : row.notes,
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  if (snapshot.concepts.isNotEmpty) {
    await supa
        .from(_kFinConceptsTable)
        .upsert(
          snapshot.concepts
              .map(
                (row) => <String, dynamic>{
                  'id': row.id,
                  'name': row.name,
                  'family': row.family,
                  'direction': row.direction,
                  'requires_company': row.requiresCompany,
                  'is_active': row.active,
                  'notes': row.notes.isEmpty ? null : row.notes,
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  if (snapshot.relations.isNotEmpty) {
    await supa
        .from(_kFinRelationsTable)
        .upsert(
          snapshot.relations
              .map(
                (row) => <String, dynamic>{
                  'id': row.id,
                  'company_id': row.companyId,
                  'concept_id': row.conceptId,
                  'mode': row.mode,
                  'is_active': row.active,
                  'notes': row.notes.isEmpty ? null : row.notes,
                },
              )
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  final existingRelationIds = await _loadRemoteIds(supa, _kFinRelationsTable);
  final nextRelationIds = snapshot.relations.map((row) => row.id).toSet();
  final deletedRelationIds = existingRelationIds
      .difference(nextRelationIds)
      .toList(growable: false);
  if (deletedRelationIds.isNotEmpty) {
    await supa
        .from(_kFinRelationsTable)
        .delete()
        .inFilter('id', deletedRelationIds);
  }

  final existingConceptIds = await _loadRemoteIds(supa, _kFinConceptsTable);
  final nextConceptIds = snapshot.concepts.map((row) => row.id).toSet();
  final deletedConceptIds = existingConceptIds
      .difference(nextConceptIds)
      .toList(growable: false);
  if (deletedConceptIds.isNotEmpty) {
    await supa
        .from(_kFinConceptsTable)
        .delete()
        .inFilter('id', deletedConceptIds);
  }

  final existingCompanyIds = await _loadRemoteIds(supa, _kFinCompaniesTable);
  final nextCompanyIds = snapshot.companies.map((row) => row.id).toSet();
  final deletedCompanyIds = existingCompanyIds
      .difference(nextCompanyIds)
      .toList(growable: false);
  if (deletedCompanyIds.isNotEmpty) {
    await supa
        .from(_kFinCompaniesTable)
        .delete()
        .inFilter('id', deletedCompanyIds);
  }
}

Future<Set<String>> _loadRemoteIds(SupabaseClient supa, String table) async {
  final rows = await supa.from(table).select('id');
  return (rows as List).map((row) => (row as Map)['id'].toString()).toSet();
}
