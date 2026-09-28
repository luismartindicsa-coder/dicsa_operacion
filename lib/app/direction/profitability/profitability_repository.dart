import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/fetch_all_supabase_rows.dart';
import 'profitability_engine.dart';
import 'profitability_models.dart';
import 'profitability_parameters.dart';
import 'profitability_payroll_allocation.dart';

/// Narrow, paginated reads. No source operation is written by this module.
class ProfitSourceSpec {
  final String table, fields;
  final String? date, fallbackDate;
  const ProfitSourceSpec(
    this.table,
    this.fields, [
    this.date,
    this.fallbackDate,
  ]);
}

const profitSourceSpecs = [
  ProfitSourceSpec('sites', 'id,name,type,is_active'),
  ProfitSourceSpec('employees', 'id,full_name,is_driver'),
  ProfitSourceSpec(
    'logistics_vehicle_profiles',
    'id:vehicle_id,vehicle_id,vehicle_code,logistics_unit_type',
  ),
  ProfitSourceSpec('pesadas', 'id,fecha,ticket,proveedor,precio', 'fecha'),
  ProfitSourceSpec('compras_counterparties', 'id,name,is_active'),
  ProfitSourceSpec('mayoreo_counterparties', 'id,name,is_active'),
  ProfitSourceSpec('men_counterparties', 'id,name,site_id,kind,is_active'),
  ProfitSourceSpec(
    'compras_material_catalog',
    'id,name,unit,category,family,general_material_id',
  ),
  ProfitSourceSpec(
    'mayoreo_material_catalog',
    'id,name,unit,category,family,general_material_id',
  ),
  ProfitSourceSpec(
    'material_commercial_catalog_v2',
    'id,name,general_material_id',
  ),
  ProfitSourceSpec('material_general_catalog_v2', 'id,name'),
  ProfitSourceSpec(
    'inventory_movements_v2',
    'id,op_date,flow,inventory_level,origin_type,weight_kg,net_kg,source_commercial_material_id,general_material_id,counterparty_site_id,counterparty,scale_ticket,reference',
    'op_date',
  ),
  ProfitSourceSpec(
    'logistics_company_profiles',
    'id:site_id,site_id,site_name,has_containers,container_count,latitude,longitude',
  ),
  ProfitSourceSpec(
    'hr_employee_profiles',
    'id,nombre,empresa,salario,salario_flujo,salario_real_percibido,employment_status,fecha_ingreso,termination_date',
  ),
  ProfitSourceSpec(
    'compras_tickets',
    'id,ticket_date,ticket_number,provider_id,provider_name_snapshot,material_id,material_name_snapshot,net_weight,payable_weight,amount',
    'ticket_date',
  ),
  ProfitSourceSpec(
    'men_tickets',
    'id,ticket_date,ticket_number,counterparty_id,counterparty_name_snapshot,commercial_material_id,material_label_snapshot,net_weight,payable_weight,price_at_entry,amount_total,status,direction',
    'ticket_date',
  ),
  ProfitSourceSpec(
    'mayoreo_sales_reports',
    'id,sale_date,ticket,client_id,client_name_snapshot,material_id,material_name_snapshot,approved_weight,approved_price,approved_amount,operation_type',
    'sale_date',
  ),
  ProfitSourceSpec(
    'services',
    'id,service_date,due_date,area,status,client_id,client_name,vehicle_id,direction,material_type,material_id,weight_kg',
    'due_date',
    'service_date',
  ),
  ProfitSourceSpec(
    'logistics_vehicle_mileage',
    'id,entry_date,vehicle_id,vehicle_key,kilometers',
    'entry_date',
  ),
  ProfitSourceSpec(
    'logistics_diesel_consumption',
    'id,entry_date,vehicle_id,liters_purchased,liters_requested,load_origin',
    'entry_date',
  ),
  ProfitSourceSpec(
    'logistics_gasoline_control',
    'id,entry_date,vehicle_id,liters_loaded,load_origin',
    'entry_date',
  ),
  ProfitSourceSpec(
    'finanzas_bank_movements',
    'id,movement_date,company,branch,category,reference,comment,counterparty_name_snapshot,debit_amount,source_type,linked_supplier_invoice_id,linked_external_ref,linked_fixed_payment_id',
    'movement_date',
  ),
  ProfitSourceSpec(
    'finanzas_supplier_invoices',
    'id,invoice_date,invoice_folio,provider_name_snapshot,total_amount,status,origin_type,target_company,target_branch,notes',
    'invoice_date',
  ),
  ProfitSourceSpec(
    'men_cash_vouchers',
    'id,voucher_date,voucher_type,folio,rubric,total_amount',
    'voucher_date',
  ),
  ProfitSourceSpec(
    'direction_vault_vouchers',
    'id,voucher_date,voucher_type,folio,rubric,total_amount',
    'voucher_date',
  ),
  ProfitSourceSpec(
    'maintenance_orders',
    'id,end_at,requested_at,status,ot_folio,equipment_id,equipment_label,site_id,cost_actual_total',
    'end_at',
    'requested_at',
  ),
  ProfitSourceSpec(
    'maintenance_purchase_orders',
    'id,purchased_at,order_date,status,folio,target_label,quote_vendor_name,actual_total,linked_ot_id',
    'purchased_at',
    'order_date',
  ),
  ProfitSourceSpec(
    'hr_payroll_period_closures',
    'id,period_label,status,closed_at',
  ),
];
const profitPayrollFields =
    'id,period_label,employee_id,empresa,draft_status,fiscal_net_amount,fiscal_manual_deduction_amount,fiscal_late_deduction_amount,cash_salary_amount,cash_vacation_amount,transport_support_amount,holiday_amount,overtime_monetized_amount,manual_bonus_amount,manual_adjustment_amount,cash_isr_amount,cash_absence_deduction_amount,cash_infonavit_deduction_amount,cash_fonacot_deduction_amount,loan_deduction_amount,payment_outside_amount,incidences_informational:source_snapshot->incidences_informational';

class ProfitBundle {
  final ProfitSources sources;
  final ProfitReview review;
  final ProfitMaster master;
  final bool inferOperations;
  const ProfitBundle(
    this.sources,
    this.review, [
    this.master = const ProfitMaster(),
    this.inferOperations = true,
  ]);
  ProfitAnalysis get analysis => analyzeProfitability(
    sources,
    review,
    master: master,
    inferOperations: inferOperations,
  );
}

class ProfitabilityRepository {
  final SupabaseClient? client;
  ProfitabilityRepository({this.client});
  SupabaseClient get db => client ?? Supabase.instance.client;

  Future<ProfitBundle> load(ProfitPeriod period) async {
    final allowed = await db.rpc('direction_program_can_manage');
    if (allowed != true) {
      throw StateError('Este análisis requiere acceso de Dirección.');
    }
    // Load settings first: absence of the migration is an error, never a blank plan.
    ProfitRow? settings;
    try {
      settings = await db
          .from('direction_profitability_reviews')
          .select()
          .eq('period_start', profitDateText(period.start))
          .eq('period_end', profitDateText(period.end))
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        throw StateError(
          'Falta activar el almacenamiento de Rentabilidad en la base de datos. La consulta completa estará disponible al aplicar la actualización del módulo.',
        );
      }
      rethrow;
    }
    final masterRows = await db
        .from('direction_profitability_master')
        .select()
        .eq('id', 1)
        .maybeSingle();
    return ProfitBundle(
      await loadSources(period, sharedCosts: await loadSharedCosts(period)),
      settings == null ? const ProfitReview() : ProfitReview.fromJson(settings),
      masterRows == null
          ? const ProfitMaster()
          : ProfitMaster.fromJson(masterRows),
    );
  }

  Future<ProfitSources> loadSources(
    ProfitPeriod period, {
    List<ProfitRow> sharedCosts = const [],
  }) async {
    var costStart = period.start.subtract(const Duration(days: 90)),
        costEnd = period.end;
    // Read documents later in the same month so a monthly charge covers an
    // earlier subperiod too. Never read future documents beyond today's date.
    final monthEnd = DateTime(period.end.year, period.end.month + 1, 0);
    final now = DateTime.now();
    final availableEnd = monthEnd.isAfter(now) ? now : monthEnd;
    if (availableEnd.isAfter(costEnd)) costEnd = availableEnd;
    for (final r in sharedCosts) {
      final start = profitDate(r['period_start'])!,
          end = profitDate(r['period_end'])!;
      if (start.isBefore(costStart)) costStart = start;
      if (end.isAfter(costEnd)) costEnd = end;
    }
    Future<List<ProfitRow>> readSpec(ProfitSourceSpec spec) async {
      if (![
        'finanzas_bank_movements',
        'finanzas_supplier_invoices',
        'men_cash_vouchers',
        'direction_vault_vouchers',
        'maintenance_orders',
        'maintenance_purchase_orders',
      ].contains(spec.table)) {
        return loadSource(spec, period);
      }
      final result = <ProfitRow>[];
      for (var start = costStart; !start.isAfter(costEnd);) {
        final candidate = start.add(const Duration(days: 365));
        final end = candidate.isBefore(costEnd) ? candidate : costEnd;
        result.addAll(await loadSource(spec, ProfitPeriod(start, end)));
        start = end.add(const Duration(days: 1));
      }
      result.sort((a, b) => profitText(a['id']).compareTo(profitText(b['id'])));
      return result;
    }

    final rows = await Future.wait(profitSourceSpecs.map(readSpec));
    final tables = <String, List<ProfitRow>>{
      for (var i = 0; i < rows.length; i++) profitSourceSpecs[i].table: rows[i],
    };
    inferProfitPayrollRoles(tables);
    final labels =
        tables['hr_payroll_period_closures']!
            .where((r) {
              final dates = profitPayrollPeriod(profitText(r['period_label']));
              return dates != null &&
                  !dates.end.isBefore(period.start) &&
                  !dates.start.isAfter(period.end);
            })
            .map((r) => profitText(r['period_label']))
            .toSet()
            .toList()
          ..sort();
    final dependent = await Future.wait([
      loadRelated(
        'men_cash_voucher_lines',
        'voucher_id',
        tables['men_cash_vouchers']!.map((r) => profitText(r['id'])).toList(),
        'id,voucher_id,company,concept,subconcept,amount,unit,quantity,driver,destination',
      ),
      loadRelated(
        'direction_vault_voucher_lines',
        'voucher_id',
        tables['direction_vault_vouchers']!
            .map((r) => profitText(r['id']))
            .toList(),
        'id,voucher_id,company,concept,subconcept,amount,unit,quantity,driver,destination',
      ),
      loadRelated(
        'hr_prenomina_draft_rows',
        'period_label',
        labels,
        profitPayrollFields,
      ),
    ]);
    tables['men_cash_voucher_lines'] = dependent[0];
    tables['direction_vault_voucher_lines'] = dependent[1];
    tables['hr_prenomina_draft_rows'] = dependent[2];
    final history = await Future.wait([
      loadSaleHistory(period, retail: false),
      loadSaleHistory(period, retail: true),
    ]);
    tables['profit_history_mayoreo'] = history[0];
    tables['profit_history_men'] = history[1];
    tables['profit_shared_cost_reviews'] = sharedCosts;
    return ProfitSources(
      period: period,
      readAt: DateTime.now(),
      tables: tables,
    );
  }

  Future<List<ProfitRow>> loadSource(
    ProfitSourceSpec spec,
    ProfitPeriod period,
  ) async {
    try {
      return await fetchAllSupabaseRows((from, to) {
        var query = db.from(spec.table).select(spec.fields);
        if (spec.table == 'employees') query = query.eq('is_driver', true);
        if (spec.table == 'inventory_movements_v2') {
          query = query
              .eq('flow', 'IN')
              .eq('inventory_level', 'GENERAL')
              .eq('origin_type', 'DIRECT_PURCHASE');
        }
        if (spec.date != null) {
          final start = profitDateText(period.start),
              until = profitDateText(period.end.add(const Duration(days: 1)));
          if (spec.fallbackDate == null) {
            query = query.gte(spec.date!, start).lt(spec.date!, until);
          } else {
            query = query.or(
              'and(${spec.date}.gte.$start,${spec.date}.lt.$until),and(${spec.date}.is.null,${spec.fallbackDate}.gte.$start,${spec.fallbackDate}.lt.$until)',
            );
          }
        }
        return query
            .order(
              spec.table == 'logistics_vehicle_profiles'
                  ? 'vehicle_id'
                  : spec.table == 'logistics_company_profiles'
                  ? 'site_id'
                  : 'id',
            )
            .range(from, to);
      });
    } catch (e) {
      throw StateError('No se pudo leer ${spec.table}. $e');
    }
  }

  Future<List<ProfitRow>> loadSharedCosts(ProfitPeriod period) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => db
          .from('direction_profitability_reviews')
          .select(
            'period_start,period_end,revision,costs:config->costs,updated_at',
          )
          .gte('period_end', profitDateText(period.start))
          .lte('period_start', profitDateText(period.end))
          .order('updated_at')
          .order('period_start')
          .order('period_end')
          .range(from, to),
    );
    return [
      for (final row in rows)
        if (row['costs'] is Map &&
            (row['costs'] as Map).isNotEmpty &&
            !(row['period_start'] == profitDateText(period.start) &&
                row['period_end'] == profitDateText(period.end)) &&
            // Bound retrieval to one year; each source period itself is <=366 days.
            profitDate(row['period_start'])!.difference(period.end).inDays >=
                -365 &&
            profitDate(row['period_end'])!.difference(period.start).inDays <=
                365)
          {...row, 'id': '${row['period_start']}_${row['period_end']}'},
    ];
  }

  Future<List<ProfitRow>> loadSaleHistory(
    ProfitPeriod period, {
    required bool retail,
  }) => fetchAllSupabaseRows((from, to) {
    final table = retail ? 'men_tickets' : 'mayoreo_sales_reports';
    final spec = profitSourceSpecs.firstWhere((s) => s.table == table);
    var query = db
        .from(table)
        .select(spec.fields)
        .gte(
          spec.date!,
          profitDateText(period.start.subtract(const Duration(days: 90))),
        )
        .lt(spec.date!, profitDateText(period.start));
    if (retail) query = query.eq('direction', 'sale');
    return query.order('id').range(from, to);
  });

  Future<ProfitMaster> saveMaster(ProfitMaster master) async {
    master.validate();
    final data = await db.rpc(
      'direction_save_profitability_master',
      params: {
        'p_expected_revision': master.revision,
        'p_config': master.toJson(),
      },
    );
    return ProfitMaster.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<ProfitRow>> loadRelated(
    String table,
    String foreignKey,
    List<String> ids,
    String fields,
  ) async {
    final rows = <ProfitRow>[];
    for (var i = 0; i < ids.length; i += 80) {
      final batch = ids.sublist(i, (i + 80).clamp(0, ids.length));
      rows.addAll(
        await fetchAllSupabaseRows(
          (from, to) => db
              .from(table)
              .select(fields)
              .inFilter(foreignKey, batch)
              .order('id')
              .range(from, to),
        ),
      );
    }
    rows.sort((a, b) => profitText(a['id']).compareTo(profitText(b['id'])));
    return rows;
  }

  Future<ProfitReview> save(ProfitPeriod period, ProfitReview review) async {
    review.validate();
    final data = await db.rpc(
      'direction_save_profitability_review',
      params: {
        'p_start': profitDateText(period.start),
        'p_end': profitDateText(period.end),
        'p_expected_revision': review.revision,
        'p_config': review.toJson(),
      },
    );
    return ProfitReview.fromJson(Map<String, dynamic>.from(data));
  }

  Future<String> saveSnapshot(ProfitAnalysis analysis) async {
    final result = await db.rpc(
      'direction_save_profitability_snapshot',
      params: {
        'p_start': profitDateText(analysis.sources.period.start),
        'p_end': profitDateText(analysis.sources.period.end),
        'p_expected_revision': analysis.review.revision,
        'p_payload': analysis.snapshot(),
      },
    );
    return profitText(result);
  }

  Future<List<ProfitRow>> history(ProfitPeriod period) => fetchAllSupabaseRows(
    (from, to) => db
        .from('direction_profitability_snapshots')
        .select('id,created_at,review_revision,payload')
        .eq('period_start', profitDateText(period.start))
        .eq('period_end', profitDateText(period.end))
        .order('created_at', ascending: false)
        .order('id')
        .range(from, to),
  );
}
