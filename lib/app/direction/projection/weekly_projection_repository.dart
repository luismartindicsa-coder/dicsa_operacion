import 'package:supabase_flutter/supabase_flutter.dart';

import '../../management_reports/finance_weekly_budget_analysis.dart';
import '../../management_reports/finance_weekly_budget_source.dart';
import '../../shared/utils/fetch_all_supabase_rows.dart';
import '../expected_income/expected_income_models.dart';
import '../operating_program/operating_program_models.dart';
import 'menudeo_expense_projection.dart';
import 'weekly_projection_models.dart';

class WeeklyProjectionRepository {
  final SupabaseClient? client;
  WeeklyProjectionRepository({this.client});
  SupabaseClient get _db => client ?? Supabase.instance.client;
  Future<WeeklyExpensePlan> load(DateTime week) async {
    final row = await _db
        .from('direction_weekly_projections')
        .select()
        .eq('week_start', programDate(week))
        .maybeSingle();
    return row == null
        ? WeeklyExpensePlan(week: week)
        : WeeklyExpensePlan.fromJson(row);
  }

  Future<FinanceWeeklyBudgetAnalysis> proposal(
    DateTime week,
    DateTime now,
  ) async => FinanceWeeklyBudgetAnalysis(
    await loadFinanceWeeklyBudgetSource(includeUninvoiced: true),
    now,
    targetWeek: week,
  );

  Future<MenudeoExpenseHistory> menudeoHistory(
    DateTime week,
    DateTime now,
  ) async {
    final start = menudeoHistoryEnd(
      week,
      now,
    ).subtract(const Duration(days: 42));
    final nextDay = incomeDay(now).add(const Duration(days: 1));
    final weekEnd = week.add(const Duration(days: 7));
    final end = nextDay.isBefore(weekEnd) ? nextDay : weekEnd;
    final sources = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => _db
            .from('vw_men_tickets_grid')
            .select('id,ticket_date,direction,status,amount_total')
            .eq('direction', 'purchase')
            .eq('status', 'PAGADO')
            .gte('ticket_date', programDate(start))
            .lt('ticket_date', programDate(end))
            .order('ticket_date')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => _db
            .from('vw_men_cash_vouchers_grid')
            .select(
              'id,voucher_date,voucher_type,rubric,total_amount,line_count',
            )
            .eq('voucher_type', 'expense')
            .gte('voucher_date', programDate(start))
            .lt('voucher_date', programDate(end))
            .order('voucher_date')
            .order('id')
            .range(from, to),
      ),
    ]);
    final ids = sources[1].map((r) => r['id'] as String).toList();
    final lines = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += 80) {
      final batch = ids.skip(i).take(80).toList();
      lines.addAll(
        await fetchAllSupabaseRows(
          (from, to) => _db
              .from('men_cash_voucher_lines')
              .select('id,voucher_id,concept,concept_label_snapshot,amount')
              .inFilter('voucher_id', batch)
              .order('voucher_id')
              .order('id')
              .range(from, to),
        ),
      );
    }
    return MenudeoExpenseHistory.fromRows(
      tickets: sources[0],
      vouchers: sources[1],
      lines: lines,
    );
  }

  Future<WeeklyExpensePlan> save(WeeklyExpensePlan plan) async {
    final result = await _db.rpc(
      'direction_save_weekly_projection',
      params: {
        'p_week': programDate(plan.week),
        'p_expected_revision': plan.revision,
        'p_payments': plan.payments.map((r) => r.toJson()).toList(),
        'p_opening_cash': plan.openingCash,
        'p_opening_fiscal': plan.openingFiscal,
        'p_generated': plan.generated,
        'p_menudeo_settings': plan.menudeo.toJson(),
      },
    );
    return WeeklyExpensePlan.fromJson(Map<String, dynamic>.from(result));
  }
}
