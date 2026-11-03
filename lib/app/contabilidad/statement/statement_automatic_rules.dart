import 'statement_models.dart';

/// These rules classify economic events; they do not attest that cash balances
/// reconcile. DICSA confirmed that ordinary Operativo vouchers are additional
/// to commercial tickets. Contradictory evidence still requires review.
class StatementAutomaticTreatment {
  final StatementAccount account;
  final String rule, detail;
  final bool estimated;
  final bool reviewRequired;
  const StatementAutomaticTreatment(
    this.account,
    this.rule,
    this.detail, {
    this.estimated = false,
    this.reviewRequired = false,
  });
  const StatementAutomaticTreatment.review(this.detail)
    : account = StatementAccount.pending,
      rule = '',
      estimated = false,
      reviewRequired = true;
}

double? statementValidNumber(dynamic value) {
  final n = value is num ? value.toDouble() : double.tryParse(stText(value));
  return n != null && n.isFinite ? n : null;
}

StatementAutomaticTreatment? recognizeRetailVoucher(
  StatementRow voucher,
  List<StatementRow> lines, {
  required bool repeatedFolio,
  required bool possibleDocument,
}) {
  final receipt =
      voucher['voucher_type'] == 'deposit' &&
      stKey(voucher['rubric']) == 'PESADAS';
  final operating =
      voucher['voucher_type'] == 'expense' &&
      {
        'OPERATIVO',
        'OPERATIVOS',
        'GASTOS OPERATIVOS',
      }.contains(stKey(voucher['rubric']));
  final administrative =
      voucher['voucher_type'] == 'expense' &&
      {
        'ADMINISTRATIVO',
        'ADMINISTRATIVOS',
        'GASTOS ADMINISTRATIVOS',
      }.contains(stKey(voucher['rubric']));
  if (!receipt && !operating && !administrative) return null;
  final total = statementValidNumber(voucher['total_amount']);
  if (total == null ||
      total <= 0 ||
      lines.isEmpty ||
      lines.any(
        (l) =>
            statementValidNumber(l['amount']) == null ||
            statementValidNumber(l['amount'])! < 0,
      ) ||
      (lines.fold<double>(0, (s, l) => s + stNumber(l['amount'])) - total)
              .abs() >
          .01) {
    return const StatementAutomaticTreatment.review(
      'Revisar importe y renglones del vale: faltan datos válidos o no coinciden con la cabecera.',
    );
  }
  if (repeatedFolio) {
    return const StatementAutomaticTreatment.review(
      'Folio repetido en la misma fecha y tipo de vale. Aclara si son operaciones distintas.',
    );
  }
  if (possibleDocument) {
    return const StatementAutomaticTreatment.review(
      'Posible comprobante o pago de la misma operación: coinciden importe, contraparte y fechas cercanas. Revisa los documentos relacionados antes de reconocer otro gasto.',
    );
  }
  final text = stKey(
    [
      voucher['comment'],
      for (final l in lines) ...[l['concept'], l['subconcept'], l['comment']],
    ].map(stText).join(' '),
  );
  final conflict = RegExp(
    r'\b(NOMINA|SUELDO[S]?|SALARIO[S]?|FINIQUITO[S]?|LIQUIDACION|'
    r'PRESTAMO[S]?|ANTICIPO[S]?|CREDITO|REEMBOLSO|IMPUESTO[S]?|IVA|ISR|'
    r'IMSS|INFONAVIT|FONACOT|FACTURA[S]?|CFDI|OC|OT|TICKET[S]?|'
    r'TRASPASO|TRANSFERENCIA|VENTA[S]?|CAPITAL|ACTIVO[S]?|'
    r'REMODELACION|CONSTRUCCION|INVERSION|PERSONALES|MEDICAMENTO[S]?|REGALO)\b|'
    r'GASTOS? POR COMPROBAR|MENOS.*DEBIA|DESCONTAR|SALDO A.*FAVOR|'
    r'FUERON EN TOTAL|\b(PARCIALIDAD|ABONO|MITAD)\b|'
    r'CAMBIO (?:DE|POR) (?:CHEQUE[S]?|MONEDA[S]?)|'
    r'COMPRA (?:DE )?(?:CAMION|MONTACARGAS|MAQUINARIA|TERRENO)',
  );
  if (conflict.hasMatch(text)) {
    return const StatementAutomaticTreatment.review(
      'El comentario o un renglón indica nómina, anticipo, liquidación, activo u otra operación distinta del gasto ordinario. Revisa su clasificación y documento de origen.',
    );
  }
  if (receipt) {
    if (lines.any((l) => stKey(l['concept']) != 'INGRESO')) {
      return const StatementAutomaticTreatment.review(
        'El ingreso de Pesadas contiene otros conceptos. Separa el cobro del servicio de las otras operaciones.',
      );
    }
    return const StatementAutomaticTreatment(
      StatementAccount.balance,
      'retail_weighing_collection_v1',
      'Cobro de Pesadas: el ingreso se reconoce en el servicio con precio y fecha, una sola vez. Este vale liquida el cobro; no prueba la coincidencia de tickets ni de cortes semanales. Revisar saldos y diferencias al cierre.',
    );
  }
  const concepts = {
    'BASCULA',
    'COMISIONES',
    'GRATIFICACION',
    'COMBUSTIBLE',
    'MANTENIMIENTO',
    'GAS',
    'VIATICOS',
    'VIGILANCIA',
    'CENA',
    'COMIDA',
    'OXIGENO',
    'CASETAS',
  };
  const administrativeConcepts = {
    'RECARGA',
    'PAPELERIA',
    'HONORARIOS ABOGADO',
    'COMISIONES',
  };
  final allowedConcepts = administrative ? administrativeConcepts : concepts;
  bool supplies(StatementRow l) =>
      operating &&
      stKey(l['concept']) == 'EQUIPO' &&
      RegExp(
        r'\b(GUANTES|BARBIQUEJOS|ESCOBAS|RASTRILLOS|CAMISOLAS|CUTTER|LONA)\b',
      ).hasMatch(text) &&
      !RegExp(
        r'\b(MOTOR|MAQUINA|MONTACARGAS|COMPUTADORA|PRENSA)\b',
      ).hasMatch(text);
  if (lines.any(
    (l) => !allowedConcepts.contains(stKey(l['concept'])) && !supplies(l),
  )) {
    return const StatementAutomaticTreatment.review(
      'Concepto sin regla de gasto ordinario, o vale con conceptos mixtos. Verifica si corresponde a gasto, almacén o activo.',
    );
  }
  // Comisiones is also used operationally for handing over sale proceeds and
  // personal advances. Its label alone is insufficient when the note is vague.
  final comments = stKey(
    [
      voucher['comment'],
      for (final l in lines) l['comment'],
    ].map(stText).join(' '),
  );
  if (RegExp(
        r'\b(DINERO|DIONERO|ENTREGADO|ENTREGADA|AGARRO)\b',
      ).hasMatch(comments) ||
      (RegExp(r'\bDEPOSIT(?:O|ADO|ADOS|OS)\b').hasMatch(comments) &&
          !RegExp(r'\bCOMISION(?:ES)?\b').hasMatch(comments)) ||
      (lines.any((l) => stKey(l['concept']) == 'COMISIONES') &&
          !RegExp(
            r'\b(COMISION(?:ES)?|CASETA[S]?|GASOLINA|BASCULA|COPIAS|LLAVE[S]?|'
            r'ANTECEDENTES|TECNICO|ACTA|INTERNET|PERMISO DE CIRCULACION|'
            r'SOLDADURA|COMIDA|TORNILLOS|REFACCION(?:ES)?)\b',
          ).hasMatch(comments))) {
    return const StatementAutomaticTreatment.review(
      'El vale describe una entrega de dinero o no identifica el gasto. Confirma su destino antes de tratarlo como gasto ordinario.',
    );
  }
  if (lines.any(supplies)) {
    return const StatementAutomaticTreatment(
      StatementAccount.operating,
      'retail_supplies_gross_v1',
      'Consumibles, protección personal o herramienta menor descritos en el vale. Se incorpora el importe capturado como estimación de gasto; revisar consumo, impuestos y cualquier activo al cierre.',
      estimated: true,
    );
  }
  if (administrative) {
    return const StatementAutomaticTreatment(
      StatementAccount.administrative,
      'retail_ordinary_administrative_v1',
      'Gasto administrativo ordinario identificado por rubro y concepto del vale: papelería, recarga, honorarios o servicio descrito. Se reconoce una vez desde caja. Revisar comprobantes, IVA y periodo de devengo al cierre; remodelaciones, impuestos y anticipos siguen pendientes.',
    );
  }
  return const StatementAutomaticTreatment(
    StatementAccount.operating,
    'retail_additional_operating_v1',
    'Gasto operativo adicional a los tickets, según el flujo confirmado de Menudeo. Se reconoce una vez desde el vale, en su fecha. El cierre debe verificar comprobantes, IVA y periodo de devengo.',
  );
}

/// Candidate matches are exceptions, never automatic duplicate certifications.
/// Amount alone is not evidence: also require a specific counterparty and a
/// nearby date. References are retained in the fact signature for invalidation.
class StatementExpenseEvidence {
  final _byAmount = <int, List<StatementRow>>{};
  StatementExpenseEvidence(StatementBundle b) {
    void add(
      String prefix,
      StatementRow row,
      dynamic date,
      dynamic amount,
      dynamic party,
    ) {
      final value = statementValidNumber(amount);
      if (value == null || value <= 0 || stDate(date) == null) return;
      (_byAmount[(value * 100).round()] ??= []).add({
        'id': '$prefix:${row['id']}',
        'date': date,
        'party': party,
        'row': row,
      });
    }

    for (final r in b.rows('finanzas_supplier_invoices')) {
      add(
        'invoice',
        r,
        r['invoice_date'],
        r['total_amount'],
        r['provider_name_snapshot'],
      );
    }
    for (final r in b.rows('maintenance_purchase_orders')) {
      if (r['status'] == 'purchased') {
        add(
          'po',
          r,
          r['order_date'],
          r['actual_total'] ?? r['estimated_total'],
          r['quote_vendor_name'],
        );
      }
    }
    for (final r in b.rows('finanzas_bank_movements')) {
      add(
        'bank',
        r,
        r['movement_date'],
        r['debit_amount'],
        r['counterparty_name_snapshot'],
      );
    }
    for (final r in b.rows('direction_vault_vouchers')) {
      if (r['voucher_type'] == 'expense') {
        add(
          'vault',
          r,
          r['voucher_date'],
          r['total_amount'],
          r['person_label'],
        );
      }
    }
  }
  List<StatementRow> matches(StatementRow voucher, List<StatementRow> lines) {
    final day = stDate(voucher['voucher_date']);
    if (day == null || voucher['voucher_type'] != 'expense') return [];
    final text = _words(
      [
        voucher['person_label'],
        voucher['comment'],
        for (final l in lines) l['comment'],
      ].map(stText).join(' '),
    );
    final candidates =
        _byAmount[(stNumber(voucher['total_amount']) * 100).round()] ?? [];
    return candidates.where((c) {
      if (stDate(c['date'])!.difference(day).inDays.abs() > 7) return false;
      final party = _words(c['party']);
      return party.isNotEmpty &&
          party.every(text.contains) &&
          (party.length >= 2 || party.single.length >= 6);
    }).toList()..sort((a, b) => stText(a['id']).compareTo(stText(b['id'])));
  }

  static Set<String> _words(dynamic text) => stKey(text)
      .split(RegExp(r'[^A-Z0-9Ñ]+'))
      .where(
        (s) =>
            s.length >= 3 &&
            !{
              'DEL',
              'LOS',
              'LAS',
              'PARA',
              'POR',
              'CON',
              'SRA',
              'SR',
              'SEÑOR',
              'SEÑORA',
              'SA',
              'SAPI',
              'SAS',
              'DE',
              'CV',
              'RL',
              'DICSA',
              'PUBLICO',
              'GENERAL',
              'EFECTIVO',
              'VARIOS',
              'PAGO',
              'PAGOS',
              'OTRO',
            }.contains(s),
      )
      .toSet();
}
