import 'package:supabase_flutter/supabase_flutter.dart';

import '../gestion_documental/gestion_documental_records.dart';
import '../gestion_documental/gestion_documental_store.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'documental_weekly_analysis.dart';

Future<DocumentalWeeklySource> loadDocumentalWeeklySource({
  SupabaseClient? client,
}) async {
  final database = client ?? Supabase.instance.client;
  // The RPC explicitly checks access before RLS can turn a denied SELECT into
  // an empty list. It also supplies the same business day as the dashboard.
  final dashboard = await SupabaseDocumentalStore(database).loadDashboard();
  final rows = await fetchAllSupabaseRows(
    (from, to) => database
        .from('documental_records')
        .select(
          'id,category,title,document_type,status,priority,responsible_user_id,'
          'reference,revision,expiration_date,start_date,authority,'
          'progress_percentage,next_action,related_employee_name,study_type,'
          'provider_name,periodicity,authorization_number,installation_name,'
          'vehicle_label,counterparty_name,signature_date,renewal_type,'
          'renewal_date,renewal_notes,insured_subject,coverage_description,'
          'maintenance_subject,scheduled_date,performed_date,audit_result,'
          'audit_findings',
        )
        .order('id', ascending: true)
        .range(from, to),
    pageSize: 500,
  );
  final expected = dashboard.categories.values.fold<int>(
    0,
    (n, c) => n + c.total,
  );
  if (rows.length != expected ||
      rows.map((r) => r['id']).toSet().length != expected) {
    throw StateError(
      'El expediente documental cambió durante la consulta o llegó incompleto. '
      'Vuelve a generar el reporte.',
    );
  }
  return DocumentalWeeklySource(
    context: dashboard.context,
    records: rows.map(DocumentalRecord.new).toList(growable: false),
  );
}
