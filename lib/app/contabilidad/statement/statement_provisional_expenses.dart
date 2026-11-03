import 'statement_automatic_rules.dart';
import 'statement_document_expenses.dart';
import 'statement_models.dart';
import 'statement_settlements.dart';

/// Known business expenditure is not zero just because its allocation needs
/// review. These gross estimates remain in the review queue AND in the result.
/// Settlement, asset and duplicate evidence still takes precedence.
StatementAutomaticTreatment? statementProvisionalVoucher(
  StatementRow row,
  List<StatementRow> lines, {
  required bool repeatedFolio,
  required bool possibleDocument,
}) {
  if (row['voucher_type'] != 'expense' ||
      repeatedFolio ||
      possibleDocument ||
      !statementVoucherAmountsValid(row, lines)) {
    return null;
  }
  final rubric = stKey(row['rubric']);
  final text = stKey(
    [
      row['comment'],
      for (final l in lines) ...[l['concept'], l['subconcept'], l['comment']],
    ].map(stText).join(' '),
  );
  if (RegExp(
    r'\b(PRESTAMO|ANTICIPO|CAPITAL|ACTIVO|ALMACEN|INVENTARIO|REMODELACION|CONSTRUCCION|IMPUESTOS?|IVA|ISR|IMSS|INFONAVIT|FONACOT|FACTURAS?|TICKETS?|OC|OT|MAQUINARIA|TERRENO|VENTAS?|TRASPASO|TRANSFERENCIA|DEPOSITO|DEPOSITADO|DEPOSITADOS|DINERO|DIONERO|ENTREGADO|ENTREGADA|AGARRO|PERSONALES|MEDICAMENTOS?|MEDICINA|REGALO)\b|CAMBIO (?:DE|POR)|SALDO A.*FAVOR|MENOS.*DEBIA|FUERON EN TOTAL|GASTOS? POR COMPROBAR|\b(PARCIALIDAD|ABONO|MITAD)\b',
  ).hasMatch(text)) {
    return null;
  }
  if (lines.any((l) => stKey(l['concept']) == 'COMISIONES') &&
      !RegExp(
        r'\b(FINIQUITO|TRABAJO|REPARACION|TORNO|REFACCION|REFACCIONES|SOLDADURA)\b',
      ).hasMatch(text)) {
    return null;
  }
  final severance = RegExp(r'\bFINIQUITO\b').hasMatch(text);
  final administrative = {
    'ADMINISTRATIVO',
    'ADMINISTRATIVOS',
    'GASTOS ADMINISTRATIVOS',
  }.contains(rubric);
  final operating = {
    'OPERATIVO',
    'OPERATIVOS',
    'GASTOS OPERATIVOS',
  }.contains(rubric);
  if (!operating && !administrative && !(rubric == 'NOMINA' && severance)) {
    return null;
  }
  // Equipment without evidence of use may be an asset or supplies in storage.
  if (!severance &&
      lines.any(
        (l) => {'EQUIPO', 'REMODELACION'}.contains(stKey(l['concept'])),
      )) {
    return null;
  }
  if (RegExp(r'\b(NOMINA|SUELDO|SALARIO)\b').hasMatch(text) && !severance) {
    return null;
  }
  final window = statementExpenseWindow(text, stDate(row['voucher_date']));
  // An explicit future period is not a current expense merely because paid.
  if (window == null ||
      (window.explicit &&
          (stDate(row['voucher_date'])!.isBefore(window.start) ||
              stDate(row['voucher_date'])!.isAfter(window.end)))) {
    return null;
  }
  return StatementAutomaticTreatment(
    severance
        ? StatementAccount.payroll
        : administrative
        ? StatementAccount.administrative
        : StatementAccount.operating,
    'paid_business_expense_provisional_v1',
    'Egreso del negocio capturado en ${row['rubric']}${severance ? ' por finiquito' : ''}: se descuenta el importe conocido del resultado provisional aunque su conciliación siga pendiente. Revisar comprobante, periodo, impuestos y cualquier parte ya reconocida en otra fuente; corregir la estimación, no sumarla de nuevo.',
    estimated: true,
    reviewRequired: true,
  );
}

StatementAutomaticTreatment? statementProvisionalInvoice(
  StatementRow invoice,
  List<StatementRow> payments,
  List<StatementRow> history, {
  required bool repeatedDocument,
}) {
  if (repeatedDocument) return null;
  // Missing folio does not erase a recorded, categorized service expenditure.
  if ({
    '',
    'PENDIENTE',
    'SIN FOLIO',
  }.contains(stKey(invoice['invoice_folio']))) {
    final result = recognizeSupplierExpense(
      {...invoice, 'invoice_folio': 'PROVISIONAL'},
      payments,
      repeatedDocument: false,
    );
    if (result != null && result.account.expense) {
      return StatementAutomaticTreatment(
        result.account,
        'supplier_pending_folio_provisional_v1',
        '${result.detail} Falta folio definitivo; el gasto ya está descontado y permanece por revisar.',
        estimated: true,
        reviewRequired: true,
      );
    }
  }
  if (payments.isNotEmpty) return null;
  final invoiceDate = stDate(invoice['invoice_date']);
  if (invoiceDate == null) return null;
  final recent =
      history.where((r) {
        final d = stDate(r['movement_date']);
        return d != null &&
            !d.isAfter(invoiceDate) &&
            invoiceDate.difference(d).inDays <= 60;
      }).toList()..sort(
        (a, b) =>
            stText(b['movement_date']).compareTo(stText(a['movement_date'])),
      );
  final documents = <String>{};
  final last = recent
      .where((r) => documents.add(stText(r['linked_supplier_invoice_id'])))
      .take(3)
      .toList();
  if (last.length < 2) return null;
  final result = recognizeSupplierExpense(
    invoice,
    last,
    repeatedDocument: false,
    recurringClassification: true,
  );
  if (result == null || !result.account.expense) return null;
  return StatementAutomaticTreatment(
    result.account,
    'supplier_recent_classification_provisional_v1',
    '${result.detail} Se usa la clasificación consistente de las últimas facturas pagadas dentro de 60 días. Hay clasificaciones históricas distintas: revisar naturaleza sin omitir este gasto provisional.',
    estimated: true,
    reviewRequired: true,
  );
}
