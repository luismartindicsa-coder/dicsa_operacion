/// Compensation agreed in Personal. CONTPAQ's net is never an input here.
class HrEmployeeCompensation {
  final double base;
  final double flow;
  final bool fiscalByCheck;
  final double overtimeHourlyRate;

  const HrEmployeeCompensation({
    required this.base,
    required this.flow,
    this.fiscalByCheck = false,
    this.overtimeHourlyRate = 60,
  });

  double get total => _money(base + flow);

  factory HrEmployeeCompensation.fromRow(Map<String, dynamic> row) {
    final base = _number(row['salario']);
    // Compatibility for profiles that predate the explicit flow column only.
    // An explicitly saved zero must never fall back to the old perceived total.
    final legacyFlow = base > 0
        ? (_number(row['salario_real_percibido']) - base)
              .clamp(0, double.infinity)
              .toDouble()
        : 0.0;
    return HrEmployeeCompensation(
      base: base,
      flow: row['salario_flujo'] == null
          ? _money(legacyFlow)
          : _number(row['salario_flujo']),
      fiscalByCheck: row['fiscal_payment_mode'] == 'cheque',
      overtimeHourlyRate: row['overtime_hourly_rate'] == null
          ? 60
          : _number(row['overtime_hourly_rate']),
    );
  }

  Map<String, dynamic> toRow() => {
    'salario': _money(base),
    'salario_flujo': _money(flow),
    // Vacaciones and other consumers retain their total/percibido field.
    'salario_real_percibido': total,
    'fiscal_payment_mode': fiscalByCheck ? 'cheque' : 'deposito',
    'overtime_hourly_rate': overtimeHourlyRate,
  };

  static double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(
              (value ?? '')
                  .toString()
                  .replaceAll(',', '')
                  .replaceAll(r'$', '')
                  .trim(),
            ) ??
            0;
  static double _money(double value) => double.parse(value.toStringAsFixed(2));
}
