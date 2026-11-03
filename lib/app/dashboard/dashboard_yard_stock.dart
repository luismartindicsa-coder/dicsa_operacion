import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';

const dashboardScrapMaterialCodes = <String>{
  'MIXTO',
  'PESADO',
  'PLACA_Y_ESTRUCTURA_LARGA',
  'PLACA_Y_ESTRUCTURA_CORTA',
  'RETORNO_INDUSTRIAL',
  'RETORNO_INDUSTRIAL_ALTO_RES',
  'REBABA',
};

class DashboardYardStock {
  final DateTime? lastExitDate;
  final double weightKg;
  final int entryCount;

  const DashboardYardStock({
    this.lastExitDate,
    this.weightKg = 0,
    this.entryCount = 0,
  });
}

String? dashboardScrapEntryCode(
  Map<String, dynamic> row, {
  required String? sourceCode,
  Map<String, String> counterpartyNamesById = const {},
}) {
  final counterparty =
      (counterpartyNamesById[row['counterparty_site_id']] ??
              row['counterparty'] ??
              '')
          .toString()
          .trim()
          .toUpperCase()
          .replaceAll('Ú', 'U');
  // Público's generic scrap belongs to Mixto in both the cards and daily chart.
  return sourceCode == 'CHATARRA' && counterparty == 'PUBLICO'
      ? 'MIXTO'
      : sourceCode;
}

/// Each material starts at zero on its last exit's operational date.
/// That day's entries are included; capture timestamps do not order movements.
/// Without a recorded exit there is no reference for an on-floor balance.
Map<String, DashboardYardStock> buildDashboardYardStock({
  required Iterable<Map<String, dynamic>> movements,
  required Map<String, String> materialCodesById,
  Map<String, String> counterpartyNamesById = const {},
  required DateTime asOf,
  String site = 'DICSA_CELAYA',
}) {
  final today = DateTime(asOf.year, asOf.month, asOf.day);
  final exits = <String, DateTime>{};
  final entries = <({String code, DateTime date, double kg})>[];
  for (final row in movements) {
    if (row['site'] != null && row['site'] != site) continue;
    final rawDate = (row['op_date'] ?? '').toString();
    final date = rawDate.length < 10
        ? null
        : DateTime.tryParse(rawDate.substring(0, 10));
    if (date == null || date.isAfter(today)) continue;
    final isEntry = row['flow'] == 'IN' && row['inventory_level'] == 'GENERAL';
    final isExit =
        row['flow'] == 'OUT' && row['inventory_level'] == 'COMMERCIAL';
    if (!isEntry && !isExit) continue;
    final id =
        row[isEntry
            ? 'source_commercial_material_id'
            : 'commercial_material_id'];
    final sourceCode = materialCodesById[id];
    final code = isEntry
        ? dashboardScrapEntryCode(
            row,
            sourceCode: sourceCode,
            counterpartyNamesById: counterpartyNamesById,
          )
        : sourceCode;
    if (!dashboardScrapMaterialCodes.contains(code)) continue;
    if (isExit) {
      final previous = exits[code];
      if (previous == null || date.isAfter(previous)) exits[code!] = date;
    } else {
      // Match the net weight shown by Entradas y Salidas, including saved zero.
      final weight = row['net_kg'] ?? row['weight_kg'];
      final kg = weight is num
          ? weight.toDouble()
          : double.tryParse('$weight') ?? 0;
      if (!kg.isFinite || kg < 0) continue;
      entries.add((code: code!, date: date, kg: kg));
    }
  }

  final weights = <String, double>{};
  final counts = <String, int>{};
  for (final entry in entries) {
    final cut = exits[entry.code];
    if (cut == null || entry.date.isBefore(cut)) continue;
    weights[entry.code] = (weights[entry.code] ?? 0) + entry.kg;
    counts[entry.code] = (counts[entry.code] ?? 0) + 1;
  }
  return {
    for (final code in dashboardScrapMaterialCodes)
      code: DashboardYardStock(
        lastExitDate: exits[code],
        weightKg: weights[code] ?? 0,
        entryCount: counts[code] ?? 0,
      ),
  };
}

Future<Map<String, DashboardYardStock>> loadDashboardYardStock(
  SupabaseClient client, {
  required Iterable<Map<String, dynamic>> commercialCatalog,
  required DateTime asOf,
  String site = 'DICSA_CELAYA',
}) async {
  final materialCodesById = <String, String>{
    for (final row in commercialCatalog)
      if ((dashboardScrapMaterialCodes.contains(row['code']) ||
              row['code'] == 'CHATARRA') &&
          row['id'] != null)
        row['id'].toString(): row['code'].toString(),
  };
  final outgoingMaterialIds = [
    for (final entry in materialCodesById.entries)
      if (dashboardScrapMaterialCodes.contains(entry.value)) entry.key,
  ];
  final counterpartyNamesById = <String, String>{};
  if (materialCodesById.containsValue('CHATARRA')) {
    // The movement's site id has no PostgREST foreign-key relationship.
    final sites = await fetchAllSupabaseRows(
      (from, to) => client
          .from('sites')
          .select('id,name')
          .order('id', ascending: true)
          .range(from, to),
    );
    for (final row in sites) {
      counterpartyNamesById[row['id'].toString()] = row['name'].toString();
    }
  }
  final date =
      '${asOf.year}-${asOf.month.toString().padLeft(2, '0')}-${asOf.day.toString().padLeft(2, '0')}';
  final batches = materialCodesById.isEmpty
      ? const <List<Map<String, dynamic>>>[]
      : await Future.wait([
          for (final isEntry in [true, false])
            if (isEntry || outgoingMaterialIds.isNotEmpty)
              fetchAllSupabaseRows(
                (from, to) => client
                    .from('inventory_movements_v2')
                    .select(
                      'id,op_date,flow,inventory_level,site,weight_kg,net_kg,'
                      'source_commercial_material_id,commercial_material_id,'
                      'counterparty,counterparty_site_id',
                    )
                    .eq('flow', isEntry ? 'IN' : 'OUT')
                    .eq('inventory_level', isEntry ? 'GENERAL' : 'COMMERCIAL')
                    .inFilter(
                      isEntry
                          ? 'source_commercial_material_id'
                          : 'commercial_material_id',
                      isEntry
                          ? materialCodesById.keys.toList()
                          : outgoingMaterialIds,
                    )
                    .or('site.eq.$site,site.is.null')
                    .lte('op_date', date)
                    .order('id', ascending: true)
                    .range(from, to),
              ),
        ]);
  return buildDashboardYardStock(
    movements: batches.expand((rows) => rows),
    materialCodesById: materialCodesById,
    counterpartyNamesById: counterpartyNamesById,
    asOf: asOf,
    site: site,
  );
}
