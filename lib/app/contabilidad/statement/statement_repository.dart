import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/fetch_all_supabase_rows.dart';
import 'statement_models.dart';

class StatementSourceSpec {
  final String table, fields;
  final String? date;
  final int contextDays;
  const StatementSourceSpec(
    this.table,
    this.fields, [
    this.date,
    this.contextDays = 0,
  ]);
}

/// Cross-period document/settlement links are read independently of the report
/// window. Only economic events are cut by operating day in the engine.
const statementSourceSpecs = <StatementSourceSpec>[
  StatementSourceSpec(
    'mayoreo_sales_reports',
    'id,sale_date,ticket,client_name_snapshot,material_id,material_name_snapshot,approved_weight,approved_amount,approved_price,exit_weight,operation_type',
    'sale_date',
  ),
  StatementSourceSpec(
    'mayoreo_accounts',
    'id,status,document_number,paid_amount',
  ),
  StatementSourceSpec(
    'compras_tickets',
    'id,ticket_date,ticket_number,provider_name_snapshot,material_id,material_name_snapshot,net_weight,payable_weight,amount',
    'ticket_date',
  ),
  StatementSourceSpec(
    'men_tickets',
    'id,ticket_date,ticket_number,counterparty_name_snapshot,commercial_material_id,material_label_snapshot,net_weight,payable_weight,amount_total,status,direction',
    'ticket_date',
  ),
  StatementSourceSpec(
    'compras_material_catalog',
    'id,name,level,category,general_material_id',
  ),
  StatementSourceSpec(
    'mayoreo_material_catalog',
    'id,name,level,category,general_material_id',
  ),
  StatementSourceSpec(
    'material_commercial_catalog_v2',
    'id,name,general_material_id',
  ),
  StatementSourceSpec('material_general_catalog_v2', 'id,name'),
  StatementSourceSpec(
    'inventory_movements_v2',
    'id,op_date,flow,inventory_level,origin_type,weight_kg,net_kg,total_amount_kg,general_material_id,commercial_material_id,movement_reason,scale_ticket,reference,counterparty,transformation_run_id',
    'op_date',
  ),
  StatementSourceSpec(
    'finanzas_supplier_invoices',
    'id,invoice_date,invoice_folio,provider_name_snapshot,total_amount,origin_type,target_company,target_branch,notes,status',
  ),
  StatementSourceSpec(
    'finanzas_supplier_invoice_tickets',
    'id,invoice_id,ticket_id,applied_amount',
  ),
  StatementSourceSpec(
    'finanzas_bank_movements',
    'id,movement_date,company,branch,category,reference,comment,counterparty_name_snapshot,credit_amount,debit_amount,source_type,linked_supplier_invoice_id,linked_external_ref,linked_fixed_payment_id,applied_supplier_amount',
  ),
  StatementSourceSpec(
    'direction_vault_vouchers',
    'id,voucher_date,voucher_type,folio,person_label,rubric,comment,total_amount',
  ),
  StatementSourceSpec(
    'direction_vault_voucher_lines',
    'id,voucher_id,concept,subconcept,company,comment,amount',
  ),
  StatementSourceSpec(
    'men_cash_vouchers',
    'id,voucher_date,voucher_type,folio,person_label,rubric,comment,total_amount',
  ),
  StatementSourceSpec(
    'men_cash_voucher_lines',
    'id,voucher_id,concept,subconcept,company,comment,amount',
  ),
  StatementSourceSpec('pesadas', 'id,fecha,ticket,proveedor,precio', 'fecha'),
  StatementSourceSpec(
    'services',
    'id,service_date,due_date,status,client_name,area',
    'service_date',
  ),
  StatementSourceSpec(
    'hr_prenomina_draft_rows',
    'id,period_label,employee_id,empresa,draft_status,fiscal_net_amount,fiscal_manual_deduction_amount,fiscal_late_deduction_amount,fiscal_imss_amount,fiscal_infonavit_amount,fiscal_fonacot_amount,fiscal_vacation_amount,cash_salary_amount,cash_vacation_amount,transport_support_amount,holiday_amount,overtime_monetized_amount,manual_bonus_amount,manual_adjustment_amount,cash_isr_amount,cash_absence_deduction_amount,cash_infonavit_deduction_amount,cash_fonacot_deduction_amount,loan_deduction_amount,payment_outside_amount,source_snapshot,incidences_informational:source_snapshot->incidences_informational',
  ),
  StatementSourceSpec('hr_payroll_period_closures', 'id,period_label,status'),
  StatementSourceSpec(
    'maintenance_purchase_orders',
    'id,folio,order_date,purchased_at,status,actual_total,estimated_total,linked_ot_id,quote_vendor_name',
    'order_date',
    7,
  ),
  StatementSourceSpec(
    'maintenance_orders',
    'id,ot_folio,status,end_at,requested_at,cost_actual_total',
    'requested_at',
  ),
  StatementSourceSpec(
    'logistics_diesel_consumption',
    'id,entry_date,liters_purchased,liters_requested,load_origin',
    'entry_date',
  ),
  StatementSourceSpec(
    'logistics_gasoline_control',
    'id,entry_date,liters_loaded,load_origin',
    'entry_date',
  ),
  StatementSourceSpec('accounting_cash_conversions', '*'),
];

class StatementRepository {
  final SupabaseClient? client;
  const StatementRepository({this.client});
  SupabaseClient get db => client ?? Supabase.instance.client;

  Future<StatementBundle> load(StatementPeriod period) async {
    // No migration, network or permission error is turned into an empty ledger.
    if (await db.rpc(
          'accounting_statement_can_read',
          params: const {},
          get: true,
        ) !=
        true) {
      throw StateError('No hay acceso a las fuentes del estado de resultados.');
    }
    final settings = await Future.wait<dynamic>([
      db.rpc('accounting_statement_can_manage', params: const {}, get: true),
      fetchAllSupabaseRows(
        (from, to) => db
            .from('accounting_statement_reviews')
            .select()
            .order('id')
            .range(from, to),
      ),
      db
          .from('accounting_statement_closures')
          .select()
          .eq('period_start', stDay(period.start))
          .eq('period_end', stDay(period.end))
          .maybeSingle(),
    ]);
    final decisions = {
      for (final r in settings[1] as List)
        stText(r['id']): StatementDecision.fromRow(
          Map<String, dynamic>.from(r as Map),
        ),
    };
    const prefixes = {
      'mayoreo_sales_reports': 'sale',
      'compras_tickets': 'purchase',
      'men_tickets': 'retail',
      'pesadas': 'weighing',
      'maintenance_purchase_orders': 'po',
      'maintenance_orders': 'ot',
    };
    final loaded = await Future.wait(
      statementSourceSpecs.map((spec) async {
        try {
          final rows = await fetchAllSupabaseRows((from, to) {
            var query = db.from(spec.table).select(spec.fields);
            if (spec.date != null) {
              final first = stDay(
                DateTime(
                  period.start.year,
                  period.start.month,
                  period.start.day - spec.contextDays,
                ),
              );
              final next = stDay(
                DateTime(
                  period.end.year,
                  period.end.month,
                  period.end.day + 1 + spec.contextDays,
                ),
              );
              query = query.or(
                'and(${spec.date}.gte.$first,${spec.date}.lt.$next),${spec.date}.is.null',
              );
            }
            return query.order('id').range(from, to);
          });
          // A document recorded in a different month may have a reviewed
          // economic date in this period. Fetch it by ID as well, not by cash day.
          final prefix = prefixes[spec.table];
          if (prefix != null) {
            final present = rows.map((r) => stText(r['id'])).toSet();
            final ids = decisions.values
                .where(
                  (d) =>
                      d.id.startsWith('$prefix:') &&
                      period.contains(d.economicDate),
                )
                .map((d) => d.id.substring(prefix.length + 1))
                .where((id) => !present.contains(id))
                .toList();
            for (var i = 0; i < ids.length; i += 150) {
              final chunk = ids.skip(i).take(150).toList();
              rows.addAll(
                await fetchAllSupabaseRows(
                  (from, to) => db
                      .from(spec.table)
                      .select(spec.fields)
                      .inFilter('id', chunk)
                      .order('id')
                      .range(from, to),
                ),
              );
            }
          }
          rows.sort((a, b) => stText(a['id']).compareTo(stText(b['id'])));
          return rows;
        } catch (e) {
          throw StateError(
            'No se pudo leer ${spec.table}. El estado está incompleto. $e',
          );
        }
      }),
    );
    return StatementBundle(
      period: period,
      canManage: settings[0] == true,
      tables: {
        for (var i = 0; i < loaded.length; i++)
          statementSourceSpecs[i].table: loaded[i],
      },
      decisions: decisions,
      closing: settings[2] == null
          ? const StatementClosing()
          : StatementClosing.fromRow(
              Map<String, dynamic>.from(settings[2] as Map),
            ),
    );
  }

  Future<void> saveDecision(StatementDecision decision) async {
    decision.validate();
    await db.rpc(
      'accounting_save_statement_review',
      params: {
        'p_id': decision.id,
        'p_expected_revision': decision.revision,
        'p_payload': decision.toRow(),
      },
    );
  }

  Future<void> saveClosing(
    StatementPeriod period,
    StatementClosing closing,
  ) async {
    await db.rpc(
      'accounting_save_statement_closing',
      params: {
        'p_start': stDay(period.start),
        'p_end': stDay(period.end),
        'p_expected_revision': closing.revision,
        'p_payload': closing.toJson(),
      },
    );
  }

  Future<void> saveConversion({
    required String bankId,
    required String vaultId,
    required String note,
    required double bankAmount,
    required double cashAmount,
  }) async {
    await db.rpc(
      'accounting_link_cash_conversion',
      params: {
        'p_bank_id': bankId,
        'p_vault_id': vaultId,
        'p_bank_amount': bankAmount,
        'p_cash_amount': cashAmount,
        'p_note': note,
      },
    );
  }

  Future<void> unlinkConversion(String id, String note) async {
    await db.rpc(
      'accounting_unlink_cash_conversion',
      params: {'p_id': id, 'p_note': note},
    );
  }
}
