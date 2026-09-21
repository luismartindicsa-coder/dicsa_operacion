import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';
import 'expenses_weekly_analysis.dart';
import 'operations_weekly_analysis.dart';

Future<OperationsWeeklySource> loadOperationsWeeklySource(
  DateTime generatedAt,
) async {
  final client = Supabase.instance.client;
  final cut = ExpensesWeeklyCut(generatedAt);
  String date(DateTime d) => d.toIso8601String().substring(0, 10);
  final results = await Future.wait<List<Map<String, dynamic>>>([
    fetchAllSupabaseRows(
      (from, to) => client
          .from('maintenance_orders')
          .select(
            'id,ot_folio,status,priority,type,category,impact,requested_at,'
            'updated_at,area_label,equipment_label,requester_name,assigned_to_name,'
            'mechanic_name,problem_description,diagnosis,work_summary,'
            'cost_estimated_total,cost_actual_total',
          )
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => client
          .from('maintenance_purchase_orders')
          .select(
            'id,folio,order_date,status,quote_vendor_name,target_label,'
            'estimated_total,actual_total,linked_ot_id,linked_ot_folio,'
            'linked_material_label,purchased_at,sent_to_cash_at,created_at,'
            'lines:maintenance_purchase_order_lines(description,line_total,qty,amount)',
          )
          .lte('order_date', date(cut.end))
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => client
          .from('material_transformation_runs_v2')
          .select(
            'id,op_date,shift,general_material:source_general_material_id(code),'
            'outputs:material_transformation_run_outputs_v2('
            'commercial_material_id,output_unit_count,output_weight_kg,'
            'commercial_material:commercial_material_id(code,name))',
          )
          .gte('op_date', date(cut.previousStart))
          .lte('op_date', date(cut.end))
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => client
          .from('production_runs')
          .select('id,op_date,shift,bale_material,bale_count')
          .gte('op_date', date(cut.previousStart))
          .lte('op_date', date(cut.end))
          .order('id', ascending: true)
          .range(from, to),
    ),
  ]);
  return OperationsWeeklySource(
    orders: results[0],
    purchases: results[1],
    transformations: results[2],
    legacyProduction: results[3],
  );
}
