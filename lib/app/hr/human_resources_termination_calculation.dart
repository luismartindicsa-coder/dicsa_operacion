import 'dart:math' as math;

enum HrTerminationMode {
  finiquito('Finiquito'),
  liquidacion('Liquidación'),
  indemnizacion('Indemnización');

  final String label;
  const HrTerminationMode(this.label);
}

String hrTerminationCurrency(num? amount) {
  if (amount == null) return 'Pendiente';
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '${amount < 0 ? '-' : ''}\$$whole.${parts.last}';
}

double hrTerminationMoney(double value) =>
    double.parse(value.toStringAsFixed(2));

DateTime hrTerminationDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime hrTerminationAnniversary(DateTime start, int year) => DateTime.utc(
  year,
  start.month,
  math.min(start.day, DateTime.utc(year, start.month + 1, 0).day),
);

DateTime hrTerminationLastAnniversary(DateTime start, DateTime end) {
  final anniversary = hrTerminationAnniversary(start, end.year);
  return anniversary.isAfter(hrTerminationDate(end))
      ? hrTerminationAnniversary(start, end.year - 1)
      : anniversary;
}

/// Actual anniversaries, including February 29; not rounded years of service.
double hrTerminationServiceYears(DateTime start, DateTime end) {
  final last = hrTerminationLastAnniversary(start, end);
  final next = hrTerminationAnniversary(start, last.year + 1);
  return last.year -
      start.year +
      hrTerminationDate(end).difference(last).inDays /
          next.difference(last).inDays;
}

class HrTerminationSplit {
  final double base;
  final double flow;
  const HrTerminationSplit(this.base, this.flow);
  static const zero = HrTerminationSplit(0, 0);
  double get total => hrTerminationMoney(base + flow);
  Map<String, dynamic> toJson() => {'base': base, 'flow': flow, 'total': total};
}

class HrTerminationLine {
  final String key;
  final String label;
  final String formula;
  final HrTerminationSplit amount;
  final bool deduction;
  const HrTerminationLine({
    required this.key,
    required this.label,
    required this.formula,
    required this.amount,
    this.deduction = false,
  });
  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'formula': formula,
    'amount': amount.toJson(),
    'deduction': deduction,
  };
}

/// Versioned calculation inputs. No payroll/CONTPAQ net is a salary input.
/// Official withholding is captured separately and never generates more flow.
class HrTerminationInput {
  static const version = '2026-09-09.1';
  final Map<String, dynamic> values;
  HrTerminationInput(Map<String, dynamic> source)
    : values = Map.unmodifiable(source);

  static String _label(String key) =>
      const {
        'weekly_base': 'el salario Base',
        'weekly_flow': 'el salario Flujo',
        'aguinaldo_days': 'los días anuales de aguinaldo',
        'vacation_days': 'los días anuales de vacaciones',
        'premium_percent': 'el porcentaje de prima',
        'minimum_daily': 'el salario mínimo diario',
        'integrated_daily_base': 'el integrado laboral diario Base',
        'integrated_daily_total': 'el integrado laboral diario Total',
        'start_date': 'la fecha de ingreso',
        'end_date': 'el último día de trabajo',
        'aguinaldo_start': 'el inicio del devengo de aguinaldo',
        'vacation_start': 'el inicio del devengo de vacaciones',
        'official_isr': 'el ISR oficial',
      }[key] ??
      'los importes y días del cálculo';

  String text(String key) => (values[key] ?? '').toString().trim();
  double number(String key, {double? fallback}) {
    final raw = values[key];
    final value = raw is num ? raw.toDouble() : double.tryParse(text(key));
    if (value == null && fallback != null && text(key).isEmpty) return fallback;
    if (value == null || !value.isFinite) {
      throw FormatException('Completa ${_label(key)} con un número válido.');
    }
    return value;
  }

  DateTime date(String key) {
    final value = DateTime.tryParse(text(key));
    if (value == null) throw FormatException('Completa ${_label(key)}.');
    return hrTerminationDate(value);
  }

  bool flag(String key) => values[key] == true;
  HrTerminationMode get mode => HrTerminationMode.values.firstWhere(
    (value) => value.name == text('mode'),
    orElse: () => throw const FormatException('Selecciona una modalidad.'),
  );
  double get baseDaily => number('weekly_base') / 7;
  double get flowDaily => number('weekly_flow') / 7;
  double get totalDaily => baseDaily + flowDaily;
  int elapsed(String from) =>
      date('end_date').difference(date(from)).inDays +
      (flag('inclusive_dates') ? 1 : 0);
  double get serviceYears =>
      hrTerminationServiceYears(date('start_date'), date('end_date'));

  void validate() {
    final start = date('start_date');
    final end = date('end_date');
    if (start.isAfter(end)) {
      throw const FormatException('La baja no puede ser anterior al ingreso.');
    }
    for (final key in ['aguinaldo_start', 'vacation_start']) {
      if (date(key).isBefore(start) || date(key).isAfter(end)) {
        throw const FormatException(
          'Los periodos de devengo deben estar dentro de la relación laboral.',
        );
      }
    }
    for (final key in [
      'weekly_base',
      'weekly_flow',
      'aguinaldo_days',
      'vacation_days',
      'premium_percent',
      'unpaid_days',
      'prior_vacation_days',
      'savings_base',
      'savings_flow',
      'commissions_base',
      'commissions_flow',
      'night_bonus_base',
      'night_bonus_flow',
      'attendance_bonus_base',
      'attendance_bonus_flow',
      'paid_aguinaldo_base',
      'paid_aguinaldo_flow',
      'paid_vacation_base',
      'paid_vacation_flow',
      'paid_premium_base',
      'paid_premium_flow',
      'imss',
      'other_fiscal_deductions',
      'flow_deductions',
    ]) {
      if (number(key, fallback: 0) < 0) {
        throw const FormatException(
          'Los días, salarios, pagos y retenciones no pueden ser negativos.',
        );
      }
    }
    if (totalDaily <= 0) {
      throw const FormatException('Captura el salario de Personal.');
    }
    if (number('premium_percent') > 100) {
      throw const FormatException('La prima debe estar entre 0 y 100%.');
    }
    if (number('aguinaldo_days') > 366 || number('vacation_days') > 366) {
      throw const FormatException('Revisa los días anuales de prestaciones.');
    }
    if (mode != HrTerminationMode.finiquito && number('minimum_daily') <= 0) {
      throw const FormatException(
        'Captura el salario mínimo aplicable a la prima de antigüedad.',
      );
    }
    if (mode == HrTerminationMode.indemnizacion) {
      if (number('integrated_daily_base') < 0 ||
          number('integrated_daily_total') <= 0 ||
          number('integrated_daily_total') < number('integrated_daily_base')) {
        throw const FormatException(
          'Revisa el salario integrado laboral Base y Total.',
        );
      }
    }
    if (text('official_isr').isNotEmpty && number('official_isr') < 0) {
      throw const FormatException('El ISR no puede ser negativo.');
    }
  }

  Map<String, dynamic> toJson() => {...values, 'formula_version': version};
}

class HrTerminationResult {
  final List<HrTerminationLine> lines;
  final List<String> pending;
  final double? officialIsr;
  final HrTerminationSplit gross;
  final HrTerminationSplit deductions;
  HrTerminationResult._({
    required this.lines,
    required this.pending,
    required this.officialIsr,
    required this.gross,
    required this.deductions,
  });

  HrTerminationSplit? get net => officialIsr == null
      ? null
      : HrTerminationSplit(
          hrTerminationMoney(gross.base - deductions.base),
          hrTerminationMoney(gross.flow - deductions.flow),
        );
  bool get canReview => pending.isEmpty && net != null;

  factory HrTerminationResult.calculate(HrTerminationInput input) {
    input.validate();
    final lines = <HrTerminationLine>[];
    final pending = <String>[];
    double n(String key) => input.number(key, fallback: 0);
    void salary(
      String key,
      String label,
      double units,
      String formula, {
      double? baseDaily,
      double? totalDaily,
    }) {
      final base = hrTerminationMoney((baseDaily ?? input.baseDaily) * units);
      final total = hrTerminationMoney(
        (totalDaily ?? input.totalDaily) * units,
      );
      lines.add(
        HrTerminationLine(
          key: key,
          label: label,
          formula: formula,
          amount: HrTerminationSplit(base, hrTerminationMoney(total - base)),
        ),
      );
    }

    final annualDays = input.number('aguinaldo_days');
    final vacationDays = input.number('vacation_days');
    final bonusRate = input.number('premium_percent') / 100;
    final aguinaldoUnits = annualDays / 365 * input.elapsed('aguinaldo_start');
    final vacationUnits =
        vacationDays / 365 * input.elapsed('vacation_start') +
        n('prior_vacation_days');
    salary(
      'salary',
      'Días pendientes de pago',
      n('unpaid_days'),
      '${n('unpaid_days')} días × salario diario',
    );
    salary(
      'aguinaldo',
      'Aguinaldo proporcional',
      aguinaldoUnits,
      '$annualDays / 365 × ${input.elapsed('aguinaldo_start')} días × salario diario',
    );
    salary(
      'vacations',
      'Vacaciones pendientes y proporcionales',
      vacationUnits,
      '($vacationDays / 365 × ${input.elapsed('vacation_start')} días + ${n('prior_vacation_days')} pendientes anteriores) × salario diario',
    );
    salary(
      'premium',
      'Prima vacacional',
      vacationUnits * bonusRate,
      'Vacaciones × ${input.number('premium_percent')}%',
    );

    // Prior settlements offset their own concept, not this week's fiscal net.
    for (final pair in [
      ('aguinaldo', 'aguinaldo'),
      ('vacations', 'vacation'),
      ('premium', 'premium'),
    ]) {
      final index = lines.indexWhere((line) => line.key == pair.$1);
      final original = lines[index];
      final paidBase = hrTerminationMoney(n('paid_${pair.$2}_base'));
      final paidFlow = hrTerminationMoney(n('paid_${pair.$2}_flow'));
      if (paidBase == 0 && paidFlow == 0) continue;
      if (paidBase > original.amount.base || paidFlow > original.amount.flow) {
        pending.add(
          'Revisar pagos previos de ${original.label.toLowerCase()}: exceden el devengo calculado.',
        );
      }
      lines[index] = HrTerminationLine(
        key: original.key,
        label: original.label,
        formula:
            '${original.formula}; menos pagos previos Base $paidBase / Flujo $paidFlow',
        amount: HrTerminationSplit(
          hrTerminationMoney(math.max(0, original.amount.base - paidBase)),
          hrTerminationMoney(math.max(0, original.amount.flow - paidFlow)),
        ),
      );
    }

    if (input.mode != HrTerminationMode.finiquito) {
      final cap = input.number('minimum_daily') * 2;
      salary(
        'seniority',
        'Liquidación · prima de antigüedad',
        12 * input.serviceYears,
        '12 días × ${input.serviceYears.toStringAsFixed(6)} años × salario diario (tope: 2 salarios mínimos)',
        baseDaily: math.min(input.baseDaily, cap),
        totalDaily: math.min(input.totalDaily, cap),
      );
    }
    if (input.mode == HrTerminationMode.indemnizacion) {
      salary(
        'indemnity',
        'Indemnización constitucional',
        90,
        '90 días × salario integrado laboral confirmado',
        baseDaily: input.number('integrated_daily_base'),
        totalDaily: input.number('integrated_daily_total'),
      );
    }
    for (final extra in [
      ('savings', 'Fondo de ahorro'),
      ('commissions', 'Comisiones'),
      ('night_bonus', 'Bono nocturno'),
      ('attendance_bonus', 'Bono de asistencia y puntualidad'),
    ]) {
      lines.add(
        HrTerminationLine(
          key: extra.$1,
          label: extra.$2,
          formula: 'Saldo confirmado por RH',
          amount: HrTerminationSplit(
            hrTerminationMoney(n('${extra.$1}_base')),
            hrTerminationMoney(n('${extra.$1}_flow')),
          ),
        ),
      );
    }
    final gross = HrTerminationSplit(
      hrTerminationMoney(lines.fold<double>(0, (s, l) => s + l.amount.base)),
      hrTerminationMoney(lines.fold<double>(0, (s, l) => s + l.amount.flow)),
    );
    final isr = input.text('official_isr').isEmpty
        ? null
        : hrTerminationMoney(input.number('official_isr'));
    if (isr == null) {
      pending.add(
        'Capturar ISR oficial de CONTPAQ, incluido cero cuando corresponda.',
      );
    }
    if (input.text('isr_reference').isEmpty) {
      pending.add('Registrar la referencia del ISR de CONTPAQ.');
    }
    if (!input.flag('history_reviewed')) {
      pending.add('Revisar nóminas y pagos previos de prestaciones.');
    }
    if (input.text('reason').isEmpty) {
      pending.add('Confirmar la causa de separación.');
    }
    if (input.flag('salary_changed_from_personal') &&
        input.text('salary_reference').isEmpty) {
      pending.add('Registrar el motivo del salario distinto al de Personal.');
    }
    if (input.mode == HrTerminationMode.indemnizacion &&
        input.text('integration_reference').isEmpty) {
      pending.add('Registrar la referencia del salario integrado laboral.');
    }
    if ([
          'paid_aguinaldo',
          'paid_vacation',
          'paid_premium',
        ].any((p) => n('${p}_base') > 0 || n('${p}_flow') > 0) &&
        input.text('prior_payment_reference').isEmpty) {
      pending.add('Identificar los recibos y devengos de los pagos previos.');
    }

    if (input.mode != HrTerminationMode.finiquito &&
        !input.flag('separation_reviewed')) {
      pending.add(
        'Confirmar la procedencia y las bases de liquidación/indemnización.',
      );
    }
    for (final d in [
      ('isr', 'ISR oficial CONTPAQ', isr ?? 0, 0.0),
      ('imss', 'IMSS confirmado', hrTerminationMoney(n('imss')), 0.0),
      (
        'fiscal_deductions',
        'Otras deducciones fiscales',
        hrTerminationMoney(n('other_fiscal_deductions')),
        0.0,
      ),
      (
        'flow_deductions',
        'Deducciones Flujo',
        0.0,
        hrTerminationMoney(n('flow_deductions')),
      ),
    ]) {
      lines.add(
        HrTerminationLine(
          key: d.$1,
          label: d.$2,
          formula: d.$1 == 'isr'
              ? input.text('isr_reference')
              : 'Captura confirmada por RH',
          amount: HrTerminationSplit(d.$3, d.$4),
          deduction: true,
        ),
      );
    }
    final deductions = HrTerminationSplit(
      hrTerminationMoney(
        (isr ?? 0) +
            hrTerminationMoney(n('imss')) +
            hrTerminationMoney(n('other_fiscal_deductions')),
      ),
      hrTerminationMoney(n('flow_deductions')),
    );
    if (gross.base < deductions.base || gross.flow < deductions.flow) {
      pending.add(
        'Las deducciones exceden el importe disponible en un canal; revisar sin compensar entre canales.',
      );
    }
    return HrTerminationResult._(
      lines: List.unmodifiable(lines),
      pending: List.unmodifiable(pending),
      officialIsr: isr,
      gross: gross,
      deductions: deductions,
    );
  }

  Map<String, dynamic> toJson() => {
    'lines': lines.map((l) => l.toJson()).toList(),
    'gross': gross.toJson(),
    'deductions': deductions.toJson(),
    'net': net?.toJson(),
    'pending': pending,
  };
}
