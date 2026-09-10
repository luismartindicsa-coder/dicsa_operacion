import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/fetch_all_supabase_rows.dart';
import '../human_resources_loans.dart';

class HrLoanRepository {
  final SupabaseClient client;
  HrLoanRepository(this.client);

  Future<HrLoanFundState> load() async {
    final results = await Future.wait([
      client
          .from('hr_loan_fund')
          .select('capital')
          .eq('id', true)
          .single()
          .then((row) => row),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_employee_loans')
            .select()
            .order('issued_on', ascending: false)
            .order('folio')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_loan_payments')
            .select()
            .order('paid_on', ascending: false)
            .order('id')
            .range(from, to),
      ),
    ]);
    return HrLoanFundState(
      capitalCents: hrLoanCents((results[0] as Map)['capital']),
      loans: (results[1] as List)
          .map((r) => HrLoan.fromRow(Map<String, dynamic>.from(r)))
          .toList(),
      payments: (results[2] as List)
          .map((r) => HrLoanPayment.fromRow(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> employees() => fetchAllSupabaseRows(
    (from, to) => client
        .from('hr_employee_profiles')
        .select('id,nombre,empresa')
        .neq('employment_status', 'baja')
        .order('nombre')
        .range(from, to),
  );

  Future<String> create(Map<String, dynamic> parameters) async =>
      (await client.rpc('hr_loan_create', params: parameters)).toString();
  Future<void> cashPayment(Map<String, dynamic> parameters) async {
    await client.rpc('hr_loan_record_cash_payment', params: parameters);
  }

  Future<void> setPayrollChannel(Map<String, dynamic> parameters) async {
    await client.rpc('hr_loan_set_payroll_channel', params: parameters);
  }
}
