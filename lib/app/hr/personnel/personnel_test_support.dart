part of '../human_resources_personnel_page.dart';

/// Opens the real expediente dialog and returns the same payroll payload that
/// its repository persists. No Supabase calls or file uploads are performed.
@visibleForTesting
Future<Map<String, dynamic>?> hrPersonnelCompensationEditorForTesting(
  BuildContext context, {
  required Map<String, dynamic> employee,
}) async {
  final pay = HrEmployeeCompensation.fromRow(employee);
  final row = await showDialog<_HumanResourcesEmployeeRow>(
    context: context,
    builder: (_) => _HumanResourcesEmployeeDialog.edit(
      employee: _HumanResourcesEmployeeRow(
        id: 'test',
        nombre: 'COLABORADOR DE PRUEBA',
        empresa: 'DICSA CELAYA',
        horario: '08:00 - 18:00',
        diasLabora: const ['Lun', 'Mar', 'Mie', 'Jue', 'Vie'],
        nss: '',
        rfc: '',
        curp: '',
        fechaIngreso: '2020-01-01',
        telefono: '',
        numeroCuenta: '',
        calzado: '',
        salario: pay.base.toStringAsFixed(2),
        salarioFlujo: pay.flow.toStringAsFixed(2),
        fiscalPaymentMode: pay.fiscalByCheck ? 'cheque' : 'deposito',
        overtimeHourlyRate: pay.overtimeHourlyRate,
      ),
      reservedIds: const {},
    ),
  );
  return row?.compensation.toRow();
}
