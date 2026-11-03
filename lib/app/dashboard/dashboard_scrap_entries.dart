import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';
import 'dashboard_yard_stock.dart';

class DashboardScrapEntrySeries {
  final String code;
  final String name;
  final Map<DateTime, double> kgByDay;

  const DashboardScrapEntrySeries({
    required this.code,
    required this.name,
    required this.kgByDay,
  });
}

/// Daily receipts retain their history even when a later exit resets floor stock.
List<DashboardScrapEntrySeries> buildDashboardScrapEntries({
  required Iterable<Map<String, dynamic>> movements,
  required DateTime from,
  required DateTime asOf,
  Map<String, String> counterpartyNamesById = const {},
  String site = 'DICSA_CELAYA',
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(asOf.year, asOf.month, asOf.day);
  final weights = <String, Map<DateTime, double>>{};
  final names = <String, String>{};
  for (final row in movements) {
    if (row['flow'] != 'IN' || row['inventory_level'] != 'GENERAL') continue;
    if (row['site'] != null && row['site'] != site) continue;
    if ((row['general_material'] as Map?)?['code'] != 'CHATARRA') continue;
    final rawDate = (row['op_date'] ?? '').toString();
    final date = rawDate.length < 10
        ? null
        : DateTime.tryParse(rawDate.substring(0, 10));
    if (date == null || date.isBefore(start) || date.isAfter(end)) continue;
    final weight = row['net_kg'] ?? row['weight_kg'];
    final kg = weight is num ? weight.toDouble() : double.tryParse('$weight');
    if (kg == null || !kg.isFinite || kg < 0) continue;

    final extra = row['source_commercial'] as Map?;
    final sourceCode = extra?['code']?.toString();
    final code = dashboardScrapEntryCode(
      row,
      sourceCode: sourceCode,
      counterpartyNamesById: counterpartyNamesById,
    );
    final key = code == null || code.isEmpty ? 'SIN_CLASIFICAR' : code;
    names[key] = key == 'SIN_CLASIFICAR'
        ? 'Sin clasificar'
        : key == 'MIXTO'
        ? 'Mixto'
        : (extra?['name'] ?? key).toString();
    final perDay = weights.putIfAbsent(key, () => <DateTime, double>{});
    perDay[date] = (perDay[date] ?? 0) + kg;
  }
  final series = [
    for (final entry in weights.entries)
      DashboardScrapEntrySeries(
        code: entry.key,
        name: names[entry.key]!,
        kgByDay: entry.value,
      ),
  ];
  double total(DashboardScrapEntrySeries s) =>
      s.kgByDay.values.fold(0.0, (sum, kg) => sum + kg);
  series.sort((a, b) {
    final byWeight = total(b).compareTo(total(a));
    return byWeight != 0 ? byWeight : a.name.compareTo(b.name);
  });
  return series;
}

Future<List<DashboardScrapEntrySeries>> loadDashboardScrapEntries(
  SupabaseClient client, {
  required DateTime from,
  required DateTime asOf,
  String site = 'DICSA_CELAYA',
}) async {
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final (movements, sites) = await (
    fetchAllSupabaseRows(
      (start, end) => client
          .from('inventory_movements_v2')
          .select(
            'id,op_date,flow,inventory_level,site,weight_kg,net_kg,'
            'counterparty,counterparty_site_id,'
            'general_material:general_material_id!inner(code),'
            'source_commercial:source_commercial_material_id(code,name)',
          )
          .eq('flow', 'IN')
          .eq('inventory_level', 'GENERAL')
          .eq('general_material.code', 'CHATARRA')
          .or('site.eq.$site,site.is.null')
          .gte('op_date', date(from))
          .lte('op_date', date(asOf))
          .order('id', ascending: true)
          .range(start, end),
    ),
    fetchAllSupabaseRows(
      (start, end) => client
          .from('sites')
          .select('id,name')
          .order('id', ascending: true)
          .range(start, end),
    ),
  ).wait;
  return buildDashboardScrapEntries(
    movements: movements,
    from: from,
    asOf: asOf,
    site: site,
    counterpartyNamesById: {
      for (final row in sites) row['id'].toString(): row['name'].toString(),
    },
  );
}
