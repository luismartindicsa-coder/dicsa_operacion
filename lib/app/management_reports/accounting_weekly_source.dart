import 'package:supabase_flutter/supabase_flutter.dart';

import '../commercial/commercial_store.dart';
import '../contabilidad/contabilidad_income_statement_store.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'accounting_weekly_analysis.dart';

Future<AccountingWeeklySource> loadAccountingWeeklySource(
  DateTime generatedAt, {
  Future<List<CommercialMarketEventRecord>>? marketEvents,
}) async {
  final cut = AccountingWeeklyCut(generatedAt);
  const statements = ContabilidadIncomeStatementStore();
  final results = await Future.wait<dynamic>([
    marketEvents ?? loadAccountingMarketEvents(cut),
    statements.loadSimplified(
      windowDays: 5,
      dateRange: cut.current,
      migrateLegacyVouchers: false,
      strictLegacyVouchers: true,
    ),
    statements.loadSimplified(
      windowDays: 5,
      dateRange: cut.previous,
      migrateLegacyVouchers: false,
      strictLegacyVouchers: true,
    ),
  ]);
  return AccountingWeeklySource(
    cut: cut,
    events: results[0] as List<CommercialMarketEventRecord>,
    currentStatement: results[1] as ContabilidadIncomeStatementDataset,
    previousStatement: results[2] as ContabilidadIncomeStatementDataset,
  );
}

Future<List<CommercialMarketEventRecord>> loadAccountingMarketEvents(
  AccountingWeeklyCut cut,
) async {
  final end = cut.current.end;
  final until = DateTime(end.year, end.month, end.day + 1);
  final rows = await fetchAllSupabaseRows(
    (from, to) => Supabase.instance.client
        .from('v_commercial_market_events')
        .select(
          'source_area,source_event_id,event_at,channel,flow,general_material_key,general_material_label,volume_kg,amount_total,unit_price',
        )
        .gte('event_at', cut.previous.start.toUtc().toIso8601String())
        .lt('event_at', until.toUtc().toIso8601String())
        .order('event_at')
        .order('source_area')
        .order('source_event_id')
        .range(from, to),
    pageSize: 500,
  );
  return rows.map(CommercialMarketEventRecord.fromRow).toList(growable: false);
}
