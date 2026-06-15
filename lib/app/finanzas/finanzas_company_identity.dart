import 'package:supabase_flutter/supabase_flutter.dart';

const String kFinCompaniesTable = 'finanzas_catalog_companies';

String normalizeFinanzasCompanyAliasKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String buildFinanzasCanonicalCompanyId(String companyName) {
  final slug = companyName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return 'fin_auto_${slug.isEmpty ? 'company' : slug}';
}

class FinanzasResolvedCompanyIdentity {
  final String? companyId;
  final String companyName;
  final String source;

  const FinanzasResolvedCompanyIdentity({
    required this.companyId,
    required this.companyName,
    required this.source,
  });
}

class FinanzasCompanyIdentityResolver {
  static String inferSourceFromExternalId(String? rawId) {
    final normalizedId = rawId?.trim() ?? '';
    if (normalizedId.startsWith('compras_')) return 'COMPRAS';
    if (normalizedId.startsWith('ventas_')) return 'VENTAS';
    return 'DIRECTO';
  }

  static String? inferNotesFromSource(String source) {
    switch (source) {
      case 'COMPRAS':
        return 'SINCRONIZADO DESDE COMPRAS MAYOREO';
      case 'VENTAS':
        return 'SINCRONIZADO DESDE VENTAS MAYOREO';
      default:
        return null;
    }
  }

  static Future<FinanzasResolvedCompanyIdentity> ensureCompanyExists({
    required String? externalCompanyId,
    required String companyNameSnapshot,
  }) async {
    final normalizedId = externalCompanyId?.trim();
    final normalizedName = companyNameSnapshot.trim();
    final source = inferSourceFromExternalId(normalizedId);
    final notes = inferNotesFromSource(source);
    final client = Supabase.instance.client;

    if (normalizedId != null && normalizedId.isNotEmpty) {
      final existing = await client
          .from(kFinCompaniesTable)
          .select('id, name, source')
          .eq('id', normalizedId)
          .maybeSingle();
      if (existing != null) {
        return FinanzasResolvedCompanyIdentity(
          companyId: (existing['id'] ?? normalizedId).toString(),
          companyName: (existing['name'] ?? normalizedName).toString(),
          source: (existing['source'] ?? source).toString(),
        );
      }
    }

    if (normalizedName.isNotEmpty) {
      final existingByName = await client
          .from(kFinCompaniesTable)
          .select('id, name, source, linked_name, notes, is_active')
          .eq('name', normalizedName)
          .maybeSingle();
      if (existingByName != null) {
        final resolvedId = (existingByName['id'] ?? '').toString();
        if (resolvedId.isNotEmpty) {
          await client.from(kFinCompaniesTable).upsert(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': resolvedId,
              'name': normalizedName,
              'source': existingByName['source'] ?? source,
              'linked_name': normalizedName,
              'is_active': existingByName['is_active'] ?? true,
              'notes': (existingByName['notes'] ?? '').toString().trim().isEmpty
                  ? notes
                  : existingByName['notes'],
            },
          ], onConflict: 'id');
          return FinanzasResolvedCompanyIdentity(
            companyId: resolvedId,
            companyName: normalizedName,
            source: (existingByName['source'] ?? source).toString(),
          );
        }
      }
    }

    if ((normalizedId == null || normalizedId.isEmpty) &&
        normalizedName.isEmpty) {
      return FinanzasResolvedCompanyIdentity(
        companyId: null,
        companyName: normalizedName,
        source: source,
      );
    }

    final insertedId = normalizedId == null || normalizedId.isEmpty
        ? buildFinanzasCanonicalCompanyId(normalizedName)
        : normalizedId;
    final insertedName = normalizedName.isEmpty ? insertedId : normalizedName;
    await client.from(kFinCompaniesTable).upsert(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': insertedId,
        'name': insertedName,
        'source': source,
        'linked_name': insertedName,
        'is_active': true,
        'notes': notes,
      },
    ], onConflict: 'id');
    return FinanzasResolvedCompanyIdentity(
      companyId: insertedId,
      companyName: insertedName,
      source: source,
    );
  }
}
