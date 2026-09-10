import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/utils/fetch_all_supabase_rows.dart';

class HrTerminationRepository {
  final SupabaseClient client;
  HrTerminationRepository(this.client);
  static const table = 'hr_employee_termination_calculations';

  Future<List<Map<String, dynamic>>> employees() => fetchAllSupabaseRows(
    (from, to) => client
        .from('hr_employee_profiles')
        .select(
          'id,nombre,empresa,fecha_ingreso,fecha_alta,salario,salario_flujo,salario_real_percibido,fiscal_payment_mode,employment_status,termination_date,termination_reason',
        )
        .order('nombre')
        .range(from, to),
  );

  Future<List<Map<String, dynamic>>> history(String employeeId) async =>
      await client
          .from(table)
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false)
          .limit(50);

  Future<Map<String, List<Map<String, dynamic>>>> antecedents(
    String employeeId,
  ) async {
    final values = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_employee_vacation_events')
            .select(
              'id,event_type,exercise_year,start_date,end_date,days_applied,status,notes,attendance_period_label',
            )
            .eq('employee_id', employeeId)
            .order('start_date', ascending: false)
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_employee_vacation_calculations')
            .select(
              'id,vacation_event_id,exercise_year,days_paid,vacation_pay,vacation_bonus_pay,transfer_component,cash_component,status,is_final',
            )
            .eq('employee_id', employeeId)
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_prenomina_draft_rows')
            .select('id,period_label,draft_status,fiscal_net_amount')
            .eq('employee_id', employeeId)
            .order('created_at', ascending: false)
            .range(from, to),
      ),
    ]);
    return {
      'events': values[0],
      'vacation_payments': values[1],
      'payrolls': values[2],
    };
  }

  /// Append a complete version. Never updates Personal, attendance or payroll.
  Future<Map<String, dynamic>> save(Map<String, dynamic> record) async =>
      await client.from(table).insert(record).select().single();
}
