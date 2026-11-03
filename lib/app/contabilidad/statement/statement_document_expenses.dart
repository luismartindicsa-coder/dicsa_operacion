import 'statement_models.dart';
import 'statement_automatic_rules.dart';

/// Only information already captured in DICSA is used. Gross supplier totals
/// remain estimates; neither VAT rates nor deductibility are inferred.
class StatementExpenseWindow {
  final DateTime start, end;
  final bool explicit;
  const StatementExpenseWindow(this.start, this.end, {this.explicit = false});
  bool overlaps(StatementPeriod p) =>
      !end.isBefore(p.start) && !start.isAfter(p.end);
  DateTime dateIn(StatementPeriod p) =>
      start.isBefore(p.start) ? p.start : start;
  double amountIn(double amount, StatementPeriod p) {
    if (!overlaps(p)) return 0;
    final first = dateIn(p), last = end.isAfter(p.end) ? p.end : end;
    final days = end.difference(start).inDays + 1;
    final cents = (amount * 100).round();
    // Cumulative rounding keeps adjacent ranges additive to the cent.
    return ((cents * (last.difference(start).inDays + 1) / days).round() -
            (cents * first.difference(start).inDays / days).round()) /
        100;
  }

  String get description => explicit
      ? 'Periodo capturado ${stDay(start)} a ${stDay(end)}; distribución proporcional por días.'
      : 'Sin periodo de servicio capturado: se usa provisionalmente la fecha del documento.';
}

const _months = {
  'ENE': 1,
  'ENERO': 1,
  'FEB': 2,
  'FEBRERO': 2,
  'MAR': 3,
  'MARZO': 3,
  'ABR': 4,
  'ABRIL': 4,
  'MAY': 5,
  'MAYO': 5,
  'JUN': 6,
  'JUNIO': 6,
  'JUL': 7,
  'JULIO': 7,
  'AGO': 8,
  'AGOSTO': 8,
  'SEP': 9,
  'SEPT': 9,
  'SEPTIEMBRE': 9,
  'SETIEMBRE': 9,
  'OCT': 10,
  'OCTUBRE': 10,
  'NOV': 11,
  'NOVIEMBRE': 11,
  'DIC': 12,
  'DICIEMBRE': 12,
};

/// Supported unambiguous ranges only. Ambiguous/invalid dates fail closed.
StatementExpenseWindow? statementExpenseWindow(dynamic raw, DateTime? date) {
  if (date == null) return null;
  final text = stKey(raw);
  DateTime? valid(int y, int m, int d) => stDate(
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
  );
  StatementExpenseWindow? range(DateTime? start, DateTime? end) {
    if (start == null ||
        end == null ||
        end.isBefore(start) ||
        end.difference(start).inDays > 3660) {
      return null;
    }
    return StatementExpenseWindow(start, end, explicit: true);
  }

  final numericDates = RegExp(
    r'\b(\d{1,2})/(\d{1,2})/(20\d{2})\b',
  ).allMatches(text).toList();
  if (numericDates.isNotEmpty) {
    if (numericDates.length != 2 || !text.contains('PERIODO')) return null;
    DateTime? parse(RegExpMatch m) =>
        valid(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    return range(parse(numericDates[0]), parse(numericDates[1]));
  }
  final compact = RegExp(
    r'\b(?:DEL\s*)?(\d{1,2})\s*([A-Z]+)\s*[-/]\s*(\d{1,2})\s*([A-Z]+)(?:\s+(20\d{2}))?\b',
  ).firstMatch(text);
  if (compact != null &&
      _months.containsKey(compact[2]) &&
      _months.containsKey(compact[4])) {
    final y = int.tryParse(compact[5] ?? '') ?? date.year;
    final m1 = _months[compact[2]]!, m2 = _months[compact[4]]!;
    return range(
      valid(y, m1, int.parse(compact[1]!)),
      valid(y, m2, int.parse(compact[3]!)),
    );
  }
  final months = RegExp(
    r'\b([A-Z]+)\b',
  ).allMatches(text).where((m) => _months.containsKey(m[1])).toList();
  if (months.isEmpty) {
    if (RegExp(
      r'\b(PERIODO|ANUAL|BIMESTRAL|TRIMESTRAL|SEMESTRAL|VIGENCIA)\b',
    ).hasMatch(text)) {
      return null;
    }
    return StatementExpenseWindow(date, date);
  }
  if (months.length != 1) return null;
  final month = _months[months.single[1]]!;
  final years = RegExp(
    r'\b20\d{2}\b',
  ).allMatches(text).map((m) => int.parse(m[0]!)).toSet();
  if (years.length > 1) return null;
  // A month without year is usable only in the same calendar year and not
  // across the December/January boundary, where capture is ambiguous.
  if (years.isEmpty && date.month == 1 && month == 12) return null;
  final year = years.firstOrNull ?? date.year;
  final beforeMonth = text.substring(0, months.single.start);
  final days = RegExp(
    r'(\d{1,2})\s*[-/]\s*(\d{1,2})\s*$',
  ).firstMatch(beforeMonth);
  if (days != null) {
    return range(
      valid(year, month, int.parse(days[1]!)),
      valid(year, month, int.parse(days[2]!)),
    );
  }
  return range(DateTime(year, month, 1), DateTime(year, month + 1, 0));
}

StatementAutomaticTreatment? recognizeSupplierExpense(
  StatementRow invoice,
  List<StatementRow> payments, {
  required bool repeatedDocument,
  bool recurringClassification = false,
}) {
  if (repeatedDocument) {
    return const StatementAutomaticTreatment.review(
      'Proveedor, razón social y folio repetidos. Aclara el documento antes de reconocerlo automáticamente.',
    );
  }
  final amount = statementValidNumber(invoice['total_amount']);
  if (amount == null ||
      amount <= 0 ||
      stDate(invoice['invoice_date']) == null) {
    return null;
  }
  if ({
    '',
    'PENDIENTE',
    'SIN FOLIO',
  }.contains(stKey(invoice['invoice_folio']))) {
    return null;
  }
  final party = stKey(invoice['provider_name_snapshot']);
  final notes = stKey(invoice['notes']);
  final context = stKey(
    '$party $notes ${payments.map((r) => stText(r['comment'])).join(' ')}',
  );
  if (RegExp(
    r'\b(MARICRUZ|BIANCA|ANTICIPO|PRESTAMO|CAPITAL|FINIQUITO|LIQUIDACION|'
    r'TARJETA|CREDITO|TERRENO|CONSTRUCCION|REMODELACION|RESIDENCIAL|'
    r'ALMACEN|INVENTARIO|EXISTENCIAS|ACTIVO|MAQUINARIA|CANCELAD[OA])\b|\b\d+[.,]?\d*\s*KG\b|CONTRATO.*\d+\s*/\s*\d+',
  ).hasMatch(stKey(context))) {
    return null;
  }
  // Insurance requires a coverage interval; managing insurance is a service.
  if (RegExp(r'\b(SEGURO[S]?|POLIZA)\b').hasMatch(context) &&
      !RegExp(r'GESTORIA|ADMINISTRACION').hasMatch(context)) {
    return null;
  }
  StatementAccount? account;
  String reason = '';
  if (RegExp(
    r'SERVICIOS? CONTABLES|HONORARIOS|CONSULTORIA|PROTECCION CIVIL|SISTEMA FACTURAS|CONTPAQ|GESTORIA|ADMINISTRACION SEGUROS',
  ).hasMatch(context)) {
    account = StatementAccount.administrative;
    reason =
        'Servicio administrativo descrito en la factura o su pago vinculado.';
  } else if ({'CFE', 'ADT SEGURIDAD'}.contains(party) ||
      RegExp(
        r'\b(REFACCIONES?|REPARACION|MANTENIMIENTO|SOLDADURA|ESCOMBRO)\b|RECUPERACION DE ROSCAS',
      ).hasMatch(notes) ||
      (party == 'GAMA CENTRO DE LINEA HIDRAULICA' &&
          RegExp(r'\b(GRUA|PRENSA|G[1-9]\d*)\b').hasMatch(notes))) {
    account = StatementAccount.operating;
    reason =
        'Servicio o refacción de operación identificado en DICSA; consumo y periodo sujetos al cierre.';
  } else if ({'ATT', 'AT&T', 'TELMEX', 'TELCEL'}.contains(party)) {
    account = StatementAccount.administrative;
    reason = 'Telefonía identificada por el proveedor registrado.';
  } else {
    final categories = payments
        .map((r) => stKey(r['category']))
        .where((c) => c.isNotEmpty)
        .toSet();
    if (categories.isNotEmpty &&
        categories.every(
          (c) => {'SERVICIOS', 'GASTOS OPERATIVOS'}.contains(c),
        )) {
      account = StatementAccount.operating;
      reason = recurringClassification
          ? 'Clasificación recurrente de servicio o gasto operativo en al menos dos facturas del mismo proveedor y razón social; esta factura puede estar pendiente de pago.'
          : 'Factura clasificada exclusivamente como servicio o gasto operativo en sus pagos bancarios vinculados.';
    } else if (categories.length == 1 &&
        categories.single == 'GASTOS ADMINISTRATIVOS') {
      account = StatementAccount.administrative;
      reason = recurringClassification
          ? 'Clasificación administrativa recurrente en al menos dos facturas del mismo proveedor y razón social; esta factura puede estar pendiente de pago.'
          : 'Factura clasificada como gasto administrativo en sus pagos bancarios vinculados.';
    }
  }
  if (account == null) return null;
  return StatementAutomaticTreatment(
    account,
    'supplier_expense_gross_v1',
    '$reason Total capturado con impuestos, incluido provisionalmente por instrucción del usuario. La app no desglosa base, IVA ni retenciones; este importe no es una base fiscal validada.',
    estimated: true,
  );
}

StatementAutomaticTreatment? recognizeBankCharge(StatementRow row) {
  if (stNumber(row['debit_amount']) <= 0 ||
      stNumber(row['credit_amount']) != 0 ||
      stText(row['linked_supplier_invoice_id']).isNotEmpty ||
      stText(row['linked_fixed_payment_id']).isNotEmpty ||
      stText(row['linked_external_ref']).isNotEmpty) {
    return null;
  }
  final party = stKey(row['counterparty_name_snapshot']);
  final text = stKey('$party ${row['reference']} ${row['comment']}');
  // VAT, loans, capital and card settlements are never bank-service expenses.
  if (RegExp(
    r'\b(IVA|ISR|RETENCION|PRESTAMO|CREDITO|TARJETA|CAPITAL|ANTICIPO)\b',
  ).hasMatch(text)) {
    return null;
  }
  if (party == 'SERVICIO DE BANCA DIGITAL' ||
      RegExp(r'EMISION LIBRAMIENTO CHQ|PENALIZ SDO PROM').hasMatch(text)) {
    return const StatementAutomaticTreatment(
      StatementAccount.financial,
      'bank_service_charge_v1',
      'Comisión o servicio bancario identificado en el movimiento. Los renglones separados de IVA no se suman como otra comisión. Verificar periodo y base al cierre.',
      estimated: true,
    );
  }
  return null;
}
