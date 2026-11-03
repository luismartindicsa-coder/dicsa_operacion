import 'statement_automatic_rules.dart';
import 'statement_models.dart';

bool statementVoucherAmountsValid(StatementRow row, List<StatementRow> lines) {
  final total = statementValidNumber(row['total_amount']);
  return total != null &&
      total > 0 &&
      lines.isNotEmpty &&
      lines.every((l) => (statementValidNumber(l['amount']) ?? -1) >= 0) &&
      (lines.fold<double>(0, (s, l) => s + stNumber(l['amount'])) - total)
              .abs() <
          .01;
}

/// Classification of settlements is independent of certification of the payroll
/// accrual. All payroll settlements also feed one explicit coverage exception.
StatementAutomaticTreatment? recognizeVoucherSettlement(
  StatementRow row,
  List<StatementRow> lines,
) {
  if (!statementVoucherAmountsValid(row, lines)) return null;
  final rubric = stKey(row['rubric']);
  final outgoing = row['voucher_type'] == 'expense';
  final incoming = row['voucher_type'] == 'deposit';
  if (!incoming && !outgoing) return null;
  if ({'PERSONALES', 'GASTOS PERSONALES'}.contains(rubric)) {
    return const StatementAutomaticTreatment(
      StatementAccount.balance,
      'personal_excluded_v1',
      'Rubro personal: retiro o movimiento de socios/familia, excluido del resultado de DICSA conforme a la clasificación confirmada. No es gasto del negocio.',
    );
  }
  final text = stKey(
    [
      row['comment'],
      for (final l in lines) ...[l['concept'], l['subconcept'], l['comment']],
    ].map(stText).join(' '),
  );
  if (outgoing &&
      rubric == 'NOMINA' &&
      lines.every(
        (l) => {'PRESTAMO', 'NOMINA', 'EMPRESA'}.contains(stKey(l['concept'])),
      )) {
    if (RegExp(r'\b(PRESTAMO|ANTICIPO)\b').hasMatch(text) &&
        !RegExp(r'\b(INTERES|INTERESES|COMISION|FINIQUITO)\b').hasMatch(text)) {
      return const StatementAutomaticTreatment(
        StatementAccount.balance,
        'employee_advance_v1',
        'Préstamo o anticipo al personal: cuenta por recuperar/aplicar, sin gasto adicional en este pago. Su aplicación no reduce la remuneración devengada.',
      );
    }
    if (!RegExp(
      r'\b(FINIQUITO|LIQUIDACION|PRESTAMO|INTERES|INTERESES)\b',
    ).hasMatch(text)) {
      return payrollSettlement;
    }
  }
  if (incoming &&
      RegExp(r'\bNOMINA[S]?\b').hasMatch(text) &&
      RegExp(r'\b(CHEQUE|CHEQUES|CH)\b').hasMatch(text) &&
      lines.every((l) => {'NOMINA', 'OTRO'}.contains(stKey(l['concept'])))) {
    return const StatementAutomaticTreatment(
      StatementAccount.balance,
      'payroll_cash_transfer_v1',
      'Cambio de cheque para fondear nómina: traslado de banco a efectivo, sin ingreso ni gasto nuevo. La coincidencia de saldos se verifica en tesorería.',
    );
  }
  return null;
}

const payrollSettlement = StatementAutomaticTreatment(
  StatementAccount.balance,
  'payroll_settlement_v1',
  'Pago de nómina: el gasto se reconoce desde RH por su periodo, no vuelve a sumarse al pagar. Los pagos y cualquier remuneración faltante se revisan juntos en Cobertura de pagos de nómina; esta regla no certifica que todos estén incluidos en RH.',
);

StatementAutomaticTreatment? recognizeBankSettlement(StatementRow row) {
  final debit = statementValidNumber(row['debit_amount']);
  final credit = statementValidNumber(row['credit_amount']);
  if (debit == null || credit == null || debit <= 0 || credit != 0) return null;
  final category = stKey(row['category']);
  final text = stKey(
    '${stText(row['counterparty_name_snapshot'])} ${stText(row['reference'])} ${stText(row['comment'])}',
  );
  if (category == 'NOMINA' &&
      !RegExp(
        r'\b(FINIQUITO|LIQUIDACION|PRESTAMO|ANTICIPO|IMSS|ISR|FONACOT|INFONAVIT)\b',
      ).hasMatch(text)) {
    return payrollSettlement;
  }
  if (stKey(row['counterparty_name_snapshot']) == 'CHEQUE DICSA' &&
      stKey(row['comment']) == 'PAGO EN EFECTIVO') {
    return const StatementAutomaticTreatment(
      StatementAccount.balance,
      'own_cheque_cash_transfer_v1',
      'Cheque propio cambiado a efectivo: traslado entre bancos y caja. El gasto se reconoce en el documento de destino, no al retirar el dinero.',
    );
  }
  return null;
}

/// DICSA confirmed the cash exchange and 4% charge. Infer only unique triples:
/// linked, fully paid Maricruz invoice + Bianca receipt + exact 4% difference.
/// Ambiguity, partial payments, changed explicit links and inconsistent amounts
/// never get resolved by a greedy nearest-amount match.
List<StatementRow> statementAutomaticConversions(StatementBundle b) {
  final explicit = b.rows('accounting_cash_conversions');
  final blockedBanks = explicit.map((r) => stText(r['bank_id'])).toSet();
  final blockedVaults = explicit.map((r) => stText(r['vault_id'])).toSet();
  final blockedInvoices = explicit.map((r) => stText(r['invoice_id'])).toSet();
  final invoices = {
    for (final r in b.rows('finanzas_supplier_invoices')) stText(r['id']): r,
  };
  final lines = <String, List<StatementRow>>{};
  for (final r in b.rows('direction_vault_voucher_lines')) {
    (lines[stText(r['voucher_id'])] ??= []).add(r);
  }
  final allBanks = b.rows('finanzas_bank_movements');
  final candidates = <StatementRow>[];
  for (final bank in allBanks) {
    final id = stText(bank['id']);
    final invoiceId = stText(bank['linked_supplier_invoice_id']);
    final invoice = invoices[invoiceId];
    final bankDate = stDate(bank['movement_date']);
    if (invoice == null ||
        bankDate == null ||
        blockedBanks.contains(id) ||
        blockedInvoices.contains(invoiceId)) {
      continue;
    }
    if (!{
          'MARICRUZ QUIROGA',
          'MARICRUZ QUIROGA ACOSTA',
        }.contains(stKey(invoice['provider_name_snapshot'])) ||
        RegExp(r'CANCEL').hasMatch(stKey(invoice['status'])) ||
        stText(invoice['invoice_folio']).isEmpty ||
        stDate(invoice['invoice_date']) == null ||
        stDate(invoice['invoice_date'])!.difference(bankDate).inDays.abs() >
            7 ||
        stNumber(bank['debit_amount']) <= 0 ||
        stNumber(bank['credit_amount']) != 0 ||
        (stNumber(bank['debit_amount']) - stNumber(invoice['total_amount']))
                .abs() >=
            .005 ||
        allBanks
                .where(
                  (r) =>
                      stText(r['linked_supplier_invoice_id']) == invoiceId &&
                      stNumber(r['debit_amount']) > 0,
                )
                .length !=
            1) {
      continue;
    }
    for (final cash in b.rows('direction_vault_vouchers')) {
      final cashId = stText(cash['id']);
      final ls = lines[cashId] ?? [];
      final day = stDate(cash['voucher_date']);
      if (blockedVaults.contains(cashId) ||
          day == null ||
          day.difference(bankDate).inDays.abs() > 3 ||
          cash['voucher_type'] != 'deposit' ||
          !statementVoucherAmountsValid(cash, ls)) {
        continue;
      }
      if (!(stKey(cash['person_label']) == 'BIANCA' ||
          RegExp(r'\bBIANCA\b').hasMatch(stKey(cash['comment'])) ||
          ls.every((l) => stKey(l['concept']) == 'BIANCA'))) {
        continue;
      }
      if (ls.any((l) => !{'BIANCA', 'OTRO'}.contains(stKey(l['concept'])))) {
        continue;
      }
      final received = stNumber(cash['total_amount']);
      final fee = (received * 4).round() / 100;
      if ((stNumber(bank['debit_amount']) - received - fee).abs() >= .005) {
        continue;
      }
      candidates.add({
        'id': 'auto:$id:$cashId',
        'bank_id': id,
        'vault_id': cashId,
        'invoice_id': invoiceId,
        'bank_amount': stNumber(bank['debit_amount']),
        'cash_amount': received,
        'fee': fee,
        'effective_date': stDay(bankDate),
        'active': true,
        'automatic': true,
        'same_day': day == bankDate,
        'note':
            'Cruce automático: factura Maricruz, pago íntegro vinculado y entrada Bianca; diferencia exacta del 4% sobre efectivo.',
      });
    }
  }
  final result = <StatementRow>[];
  // Same-day document triples have stronger evidence; each endpoint must still
  // have exactly one match. Remaining endpoints require mutual uniqueness too.
  for (final sameDay in [true, false]) {
    final pool = candidates
        .where(
          (r) =>
              (!sameDay || r['same_day'] == true) &&
              !blockedBanks.contains(r['bank_id']) &&
              !blockedVaults.contains(r['vault_id']),
        )
        .toList();
    final accepted = pool
        .where(
          (r) =>
              pool.where((x) => x['bank_id'] == r['bank_id']).length == 1 &&
              pool.where((x) => x['vault_id'] == r['vault_id']).length == 1,
        )
        .toList();
    for (final r in accepted) {
      result.add(r);
      blockedBanks.add(stText(r['bank_id']));
      blockedVaults.add(stText(r['vault_id']));
    }
  }
  return result;
}
