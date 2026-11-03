import 'statement_models.dart';
import 'statement_automatic_rules.dart';
import 'statement_payroll.dart';
import 'statement_document_expenses.dart';
import 'statement_settlements.dart';
import 'statement_provisional_expenses.dart';

/// Recognition is separate from document/payment provenance. No operational
/// record is edited and no unknown cost is silently certified as zero.
StatementAnalysis analyzeStatement(StatementBundle b) {
  final facts = <String, StatementFact>{}, warnings = <String>[];
  final material = <String, StatementMaterial>{};
  final period = b.period;
  String display(dynamic value) =>
      stText(value).isEmpty ? 'Sin dato' : stText(value);
  Map<String, StatementRow> index(String table) => {
    for (final r in b.rows(table)) stText(r['id']): r,
  };
  final banks = index('finanzas_bank_movements'),
      vault = index('direction_vault_vouchers');
  final invoices = index('finanzas_supplier_invoices'),
      accounts = index('mayoreo_accounts');
  final invoiceTickets = <String, List<StatementRow>>{};
  for (final r in b.rows('finanzas_supplier_invoice_tickets')) {
    (invoiceTickets[stText(r['invoice_id'])] ??= []).add(r);
  }
  bool relevant(String id, dynamic day) =>
      stDate(day) == null ||
      period.includes(day) ||
      period.contains(b.decisions[id]?.economicDate);
  void add(StatementFact f) {
    if (f.date != null &&
        !period.contains(f.date) &&
        !period.contains(b.decisions[f.id]?.economicDate)) {
      return;
    }
    if (facts.containsKey(f.id)) {
      throw StateError('Operación repetida: ${f.id}');
    }
    if (!f.amount.isFinite) throw StateError('Importe inválido: ${f.id}');
    facts[f.id] = f;
  }

  void rowFact(
    String prefix,
    String source,
    StatementRow r,
    String day,
    String title,
    double amount,
    StatementAccount account,
    String detail, {
    bool review = false,
    bool includeWhilePending = false,
    bool estimated = false,
    String automaticRule = '',
    List<String> refs = const [],
    dynamic evidence,
  }) {
    add(
      StatementFact(
        id: '$prefix:${r['id']}',
        source: source,
        label: title,
        date: stDate(r[day]),
        amount: amount,
        account: account,
        detail: detail,
        automaticRule: automaticRule,
        estimated: estimated,
        reviewRequired: review || stDate(r[day]) == null,
        includeWhilePending: includeWhilePending,
        references: refs,
        evidence: evidence ?? r,
      ),
    );
  }

  void expenseFact(
    String prefix,
    String source,
    StatementRow r,
    String day,
    String title,
    double amount,
    StatementAutomaticTreatment treatment,
    StatementExpenseWindow? window,
    dynamic evidence,
  ) {
    final nativeDay = stDate(r[day]);
    final inPeriod = window?.overlaps(period) == true;
    if (!inPeriod && !relevant('$prefix:${r['id']}', r[day])) return;
    final pending =
        treatment.account == StatementAccount.pending || window == null;
    add(
      StatementFact(
        id: '$prefix:${r['id']}',
        source: source,
        label: title,
        date: inPeriod ? window!.dateIn(period) : nativeDay,
        amount: !pending && inPeriod ? window.amountIn(amount, period) : amount,
        account: pending
            ? StatementAccount.pending
            : inPeriod
            ? treatment.account
            : StatementAccount.balance,
        estimated: treatment.estimated && !pending && inPeriod,
        reviewRequired: treatment.reviewRequired && inPeriod,
        includeWhilePending: treatment.reviewRequired && !pending && inPeriod,
        automaticRule: pending ? '' : treatment.rule,
        detail:
            '${treatment.detail} ${window?.description ?? 'El periodo escrito no es inequívoco; requiere aclaración.'}${!pending && !inPeriod ? ' No corresponde al periodo consultado.' : ''}',
        evidence: [
          evidence,
          treatment.rule,
          if (window != null && window.explicit) period.key,
        ],
      ),
    );
  }

  bool cancelled(dynamic status) => [
    'CANCELADO',
    'CANCELADA',
    'CANCELLED',
    'CANCELED',
    'CANCELADA/O',
  ].contains(stKey(status));
  bool conversionParty(dynamic name) =>
      stKey(name) == 'MARICRUZ QUIROGA ACOSTA' ||
      stKey(name) == 'MARICRUZ QUIROGA';
  bool bianca(StatementRow r, List<StatementRow> lines) =>
      stKey(r['person_label']) == 'BIANCA' ||
      RegExp(r'\bBIANCA\b').hasMatch(stKey(r['comment'])) ||
      lines.any((l) => stKey(l['concept']) == 'BIANCA');

  // Explicit, auditable conversions, including the user-confirmed invoice 160.
  final consumedBanks = <String>{},
      consumedVaults = <String>{},
      nonMaterialInvoices = <String>{};
  final automaticConversions = statementAutomaticConversions(b);
  final conversionEvidence = <String, StatementRow>{};
  for (final link in [
    ...b.rows('accounting_cash_conversions'),
    ...automaticConversions,
  ]) {
    if (link['active'] == false) continue;
    final bankId = stText(link['bank_id']), vaultId = stText(link['vault_id']);
    final bank = banks[bankId],
        cash = vault[vaultId],
        invoiceId = stText(link['invoice_id']);
    if (invoiceId.isNotEmpty) nonMaterialInvoices.add(invoiceId);
    final day =
        stDate(bank?['movement_date']) ?? stDate(link['effective_date']);
    final inPeriod =
        period.contains(day) || period.includes(cash?['voucher_date']);
    final valid =
        bank != null &&
        cash != null &&
        stText(bank['linked_supplier_invoice_id']) == invoiceId &&
        (stNumber(bank['debit_amount']) - stNumber(link['bank_amount'])).abs() <
            .005 &&
        stNumber(bank['credit_amount']).abs() < .005 &&
        cash['voucher_type'] == 'deposit' &&
        (stNumber(cash['total_amount']) - stNumber(link['cash_amount'])).abs() <
            .005 &&
        (stNumber(link['bank_amount']) -
                    stNumber(link['cash_amount']) -
                    stNumber(link['fee']))
                .abs() <
            .005;
    if (!valid) {
      if (inPeriod) {
        warnings.add(
          'Cambió la operación de efectivo ${link['id']}; vuelve a conciliar sus documentos.',
        );
      }
      continue;
    }
    consumedBanks.add(bankId);
    consumedVaults.add(vaultId);
    if (link['automatic'] == true) {
      conversionEvidence['bank:$bankId'] = link;
      conversionEvidence['vault:$vaultId'] = link;
      conversionEvidence['invoice:$invoiceId'] = link;
    }
    add(
      StatementFact(
        id: 'conversion:${link['id']}',
        source: 'Banco / Bóveda',
        label: 'Costo de conversión de efectivo',
        date: day,
        amount: stNumber(link['fee']),
        account: StatementAccount.financial,
        automaticRule: link['automatic'] == true
            ? 'bianca_unique_four_percent_v1'
            : '',
        detail:
            '${link['note']} · Banco ${link['bank_amount']} · Efectivo ${link['cash_amount']}. No genera compra física ni venta.',
        references: [
          'bank:$bankId',
          'vault:$vaultId',
          if (invoiceId.isNotEmpty) 'invoice:$invoiceId',
        ],
        evidence: [
          link,
          bank,
          cash,
          invoices[invoiceId],
          invoiceTickets[invoiceId] ?? [],
        ],
      ),
    );
  }
  final nonMaterialTickets = <String>{};
  for (final id in nonMaterialInvoices) {
    nonMaterialTickets.addAll(
      (invoiceTickets[id] ?? []).map((r) => stText(r['ticket_id'])),
    );
  }

  final general = index('material_general_catalog_v2');
  final catalogs = <String, Map<String, StatementRow>>{
    'purchase': index('compras_material_catalog'),
    'sale': index('mayoreo_material_catalog'),
    'retail': index('material_commercial_catalog_v2'),
  };
  StatementMaterial family(String channel, dynamic id, dynamic label) {
    final nativeKey = stText(
      catalogs[channel]?[stText(id)]?['general_material_id'],
    );
    var key = general.containsKey(nativeKey) ? nativeKey : '';
    // Mayoreo explicitly seeds GENERAL categories as ma_general_<category>.
    // Bridge those catalog records to the one exact physical GENERAL category;
    // never infer a family from a commercial product label.
    if (key.isEmpty && nativeKey.isNotEmpty) {
      final category = catalogs[channel]?[nativeKey];
      final name = stKey(category?['name']);
      final matches = general.values
          .where((g) => stKey(g['name']) == name)
          .toList();
      if (category?['level'] == 'GENERAL' &&
          name.isNotEmpty &&
          stKey(category?['category']) == name &&
          nativeKey == 'ma_general_${name.toLowerCase()}' &&
          matches.length == 1) {
        key = stText(matches.single['id']);
      }
    }
    final resolved = key.isEmpty
        ? 'unmapped:$channel:${stText(id)}:${stText(label)}'
        : key;
    return material.putIfAbsent(
      resolved,
      () => StatementMaterial(
        resolved,
        stText(general[key]?['name']).isNotEmpty
            ? stText(general[key]?['name'])
            : '${stText(label)} · sin equivalencia',
      ),
    );
  }

  StatementMaterial physicalFamily(StatementRow r) {
    final key = stText(r['general_material_id']).isNotEmpty
        ? stText(r['general_material_id'])
        : stText(
            catalogs['retail']?[stText(
              r['commercial_material_id'],
            )]?['general_material_id'],
          );
    return material.putIfAbsent(
      key.isEmpty ? 'unmapped:physical:${r['id']}' : key,
      () => StatementMaterial(
        key,
        stText(general[key]?['name']).isEmpty
            ? 'Material sin equivalencia'
            : stText(general[key]?['name']),
      ),
    );
  }

  for (final r in b.rows('compras_tickets')) {
    final id = 'purchase:${r['id']}';
    if (!relevant(id, r['ticket_date'])) continue;
    final nonPhysical = nonMaterialTickets.contains(stText(r['id']));
    final needsReview =
        conversionParty(r['provider_name_snapshot']) && !nonPhysical;
    rowFact(
      'purchase',
      'Compras Mayoreo',
      r,
      'ticket_date',
      'Compra ${display(r['ticket_number'])} · ${display(r['provider_name_snapshot'])}',
      stNumber(r['amount']),
      needsReview ? StatementAccount.pending : StatementAccount.balance,
      nonPhysical
          ? 'Documento de conversión de efectivo: sin compra física.'
          : needsReview
          ? 'Posible operación de efectivo. Vincula banco y Bóveda antes de usar estos kilos.'
          : 'Adquisición de material. El pago no determina el costo de lo vendido.',
    );
    if (!nonPhysical && !needsReview && period.includes(r['ticket_date'])) {
      final f = family(
        'purchase',
        r['material_id'],
        r['material_name_snapshot'],
      );
      f.purchases += stNumber(r['amount']);
      f.purchasedKg += stNumber(r['net_weight']);
    }
  }
  for (final r in b.rows('men_tickets')) {
    if (cancelled(r['status'])) continue;
    final sell =
        stKey(r['direction']) == 'VENTA' ||
        stKey(r['direction']) == 'SALE' ||
        stKey(r['direction']) == 'OUT';
    final buy =
        stKey(r['direction']) == 'COMPRA' ||
        stKey(r['direction']) == 'PURCHASE' ||
        stKey(r['direction']) == 'IN';
    final id = 'retail:${r['id']}';
    if (!relevant(id, r['ticket_date'])) continue;
    rowFact(
      'retail',
      'Menudeo',
      r,
      'ticket_date',
      'Ticket ${display(r['ticket_number'])} · ${display(r['counterparty_name_snapshot'])}',
      stNumber(r['amount_total']),
      sell
          ? StatementAccount.sales
          : buy
          ? StatementAccount.balance
          : StatementAccount.pending,
      sell
          ? 'Venta comercial; su cobro o depósito no genera otra venta.'
          : buy
          ? 'Compra de material; se lleva al costo al venderse.'
          : 'Dirección del ticket sin identificar.',
    );
    if (period.includes(r['ticket_date'])) {
      final f = family(
        'retail',
        r['commercial_material_id'],
        r['material_label_snapshot'],
      );
      if (sell) f.soldKg += stNumber(r['net_weight']);
      if (buy) {
        f.purchases += stNumber(r['amount_total']);
        f.purchasedKg += stNumber(r['net_weight']);
      }
    }
  }
  for (final r in b.rows('mayoreo_sales_reports')) {
    final a = accounts[stText(r['id'])];
    if (cancelled(a?['status'])) continue;
    final approved =
        stNumber(r['approved_weight']) > 0 &&
        stNumber(r['approved_price']) > 0 &&
        stNumber(r['approved_amount']) > 0;
    rowFact(
      'sale',
      'Ventas Mayoreo',
      r,
      'sale_date',
      'Venta ${display(r['ticket'])} · ${display(r['client_name_snapshot'])}',
      stNumber(r['approved_amount']),
      approved ? StatementAccount.sales : StatementAccount.pending,
      approved
          ? 'Importe comercial aprobado. Factura, cuenta y cobro son representaciones de esta venta.'
          : 'Entrega sin importe aprobado: no se presume venta de cero.',
      evidence: [r, a?['status']],
    );
    if (period.includes(r['sale_date'])) {
      family('sale', r['material_id'], r['material_name_snapshot']).soldKg +=
          stNumber(r['approved_weight']);
    }
  }
  for (final r in b.rows('inventory_movements_v2')) {
    if (stDate(r['op_date']) == null) {
      warnings.add(
        'Movimiento físico ${r['id']} sin fecha: corrige su fecha en Entradas y Salidas.',
      );
    }
    if (!period.includes(r['op_date'])) continue;
    final f = physicalFamily(r);
    final kg = stNumber(r['net_kg'] ?? r['weight_kg']);
    if (r['movement_reason'] == 'SCRAP_SEPARATION') {
      f.recoveries++;
      continue;
    }
    if (r['origin_type'] == 'DIRECT_PURCHASE' &&
        r['inventory_level'] == 'GENERAL' &&
        r['flow'] == 'IN') {
      f.receivedKg += kg;
    }
    if (r['origin_type'] == 'SALE' &&
        r['inventory_level'] == 'COMMERCIAL' &&
        r['flow'] == 'OUT') {
      f.dispatchedKg += kg;
    }
  }
  for (final f in material.values) {
    if (f.dispatchedKg == 0 && f.soldKg == 0) continue;
    final missing =
        f.average == null ||
        f.dispatchedKg <= 0 ||
        f.key.startsWith('unmapped:');
    add(
      StatementFact(
        id: 'cost:${period.key}:${f.key}',
        source: 'Entradas y Salidas / Compras',
        label: 'Costo vendido · ${f.label}',
        date: period.end,
        amount: f.estimatedCost ?? 0,
        account: missing ? StatementAccount.pending : StatementAccount.cost,
        detail:
            'Entradas externas ${f.receivedKg.toStringAsFixed(2)} kg; salidas ${f.dispatchedKg.toStringAsFixed(2)} kg; ventas comerciales ${f.soldKg.toStringAsFixed(2)} kg. Promedio de adquisiciones sobre peso físico neto. Falta validar apertura, rendimientos y costos de transformación. No usa el saldo de Inventario.',
        evidence: f.toJson(),
        estimated: true,
        reviewRequired: missing,
      ),
    );
  }

  final invoicePayments = <String, List<StatementRow>>{};
  for (final r in b.rows('finanzas_bank_movements')) {
    final invoiceId = stText(r['linked_supplier_invoice_id']);
    if (invoiceId.isNotEmpty &&
        stNumber(r['debit_amount']) > 0 &&
        stNumber(r['credit_amount']) == 0) {
      (invoicePayments[invoiceId] ??= []).add(r);
    }
  }
  String documentKey(StatementRow r) =>
      '${stKey(r['provider_name_snapshot'])}|${stKey(r['target_company'])}|${stKey(r['invoice_folio']).replaceAll(RegExp(r'[^A-Z0-9]'), '')}';
  String supplierKey(StatementRow r) =>
      '${stKey(r['provider_name_snapshot'])}|${stKey(r['target_company'])}';
  final supplierPayments = <String, List<StatementRow>>{};
  for (final r in b.rows('finanzas_supplier_invoices')) {
    if (cancelled(r['status']) ||
        stDate(r['invoice_date']) == null ||
        stDate(r['invoice_date'])!.isAfter(period.end) ||
        (invoiceTickets[stText(r['id'])] ?? []).isNotEmpty) {
      continue;
    }
    (supplierPayments[supplierKey(r)] ??= []).addAll(
      invoicePayments[stText(r['id'])] ?? [],
    );
  }
  final repeatedInvoices = <String, List<StatementRow>>{};
  for (final r in b.rows('finanzas_supplier_invoices')) {
    if (!cancelled(r['status']) && stText(r['invoice_folio']).isNotEmpty) {
      (repeatedInvoices[documentKey(r)] ??= []).add(r);
    }
  }
  for (final r in b.rows('finanzas_supplier_invoices')) {
    if (cancelled(r['status'])) continue;
    final id = stText(r['id']), linked = invoiceTickets[id] ?? [];
    final noMaterial = nonMaterialInvoices.contains(id);
    final payments = invoicePayments[id] ?? [];
    final history = supplierPayments[supplierKey(r)] ?? [];
    final useHistory =
        payments.isEmpty &&
        stKey(r['provider_name_snapshot']).isNotEmpty &&
        stKey(r['target_company']).isNotEmpty &&
        history
                .map((r) => stText(r['linked_supplier_invoice_id']))
                .toSet()
                .length >=
            2;
    final classificationPayments = useHistory ? history : payments;
    final repeats = repeatedInvoices[documentKey(r)] ?? [];
    var treatment =
        !noMaterial &&
            linked.isEmpty &&
            !conversionParty(r['provider_name_snapshot'])
        ? recognizeSupplierExpense(
            r,
            classificationPayments,
            repeatedDocument:
                repeats.length > 1 && stKey(r['invoice_folio']) != 'PENDIENTE',
            recurringClassification: useHistory,
          )
        : null;
    if ((treatment == null || treatment.account == StatementAccount.pending) &&
        !noMaterial &&
        linked.isEmpty &&
        !conversionParty(r['provider_name_snapshot'])) {
      treatment =
          statementProvisionalInvoice(
            r,
            payments,
            history,
            repeatedDocument:
                repeats.length > 1 && stKey(r['invoice_folio']) != 'PENDIENTE',
          ) ??
          treatment;
    }
    if (treatment != null) {
      expenseFact(
        'invoice',
        'Facturas proveedor',
        r,
        'invoice_date',
        'Factura ${display(r['invoice_folio'])} · ${display(r['provider_name_snapshot'])}',
        stNumber(r['total_amount']),
        treatment,
        statementExpenseWindow(r['notes'], stDate(r['invoice_date'])),
        [
          r,
          linked,
          classificationPayments,
          if (treatment.reviewRequired) history,
          if (repeats.length > 1) repeats,
        ],
      );
      continue;
    }
    rowFact(
      'invoice',
      'Facturas proveedor',
      r,
      'invoice_date',
      'Factura ${display(r['invoice_folio'])} · ${display(r['provider_name_snapshot'])}',
      stNumber(r['total_amount']),
      noMaterial || linked.isNotEmpty
          ? StatementAccount.duplicate
          : StatementAccount.pending,
      noMaterial
          ? 'Soporte de conversión de efectivo; no es otra compra.'
          : linked.isNotEmpty
          ? 'Documenta tickets de compra. No se suma nuevamente como costo.'
          : 'Factura sin vínculo económico. Define base sin impuestos recuperables, naturaleza y fecha; vincula si ya está en otro módulo.',
      refs: linked.map((v) => 'purchase:${v['ticket_id']}').toList(),
      evidence: [r, linked],
    );
  }
  StatementAccount cashAccount(String rubric, String context, bool incoming) {
    final c = stKey(rubric), t = stKey(context);
    if (c == 'MOVIMIENTOS INTERNOS' || c == 'REPOSICION DE FONDO') {
      return StatementAccount.balance;
    }
    if (incoming &&
        RegExp(
          r'PRESTAMO|DISPOSICION.*CREDITO|APORTACION.*CAPITAL',
        ).hasMatch(t)) {
      return StatementAccount.balance;
    }
    // Every unlinked receipt can be collection of an existing sale. Every
    // cash expense can already be in an invoice, payroll or maintenance order.
    // Resolve explicitly instead of guessing from a category or a person's name.
    return StatementAccount.pending;
  }

  final payrollPayments = <StatementRow>[];
  for (final r in b.rows('finanzas_bank_movements')) {
    final invoiceId = stText(r['linked_supplier_invoice_id']),
        saleId = stText(r['linked_external_ref']);
    final debit = stNumber(r['debit_amount']),
        credit = stNumber(r['credit_amount']);
    final settlement =
        (invoiceId.isNotEmpty &&
            invoices.containsKey(invoiceId) &&
            !cancelled(invoices[invoiceId]?['status'])) ||
        (saleId.isNotEmpty && accounts.containsKey(saleId)) ||
        consumedBanks.contains(stText(r['id']));
    final transfer = settlement ? null : recognizeBankSettlement(r);
    if (transfer?.rule == 'payroll_settlement_v1' &&
        period.includes(r['movement_date'])) {
      payrollPayments.add({'source_id': 'bank:${r['id']}', 'row': r});
    }
    final charge = settlement ? null : recognizeBankCharge(r);
    if (charge != null) {
      expenseFact(
        'bank',
        'Bancos',
        r,
        'movement_date',
        '${display(r['counterparty_name_snapshot'])} · ${display(r['reference'])}',
        debit,
        charge,
        statementExpenseWindow(
          '${stText(r['reference'])} ${stText(r['comment'])}',
          stDate(r['movement_date']),
        ),
        r,
      );
      continue;
    }
    final a = settlement
        ? StatementAccount.duplicate
        : transfer?.account ??
              cashAccount(
                stText(r['category']),
                '${display(r['reference'])} ${r['comment']} ${display(r['counterparty_name_snapshot'])}',
                credit > 0,
              );
    rowFact(
      'bank',
      'Bancos',
      r,
      'movement_date',
      '${display(r['counterparty_name_snapshot'])} · ${display(r['reference'])}',
      debit + credit,
      debit > 0 && credit > 0 ? StatementAccount.pending : a,
      settlement
          ? 'Liquidación de documento u operación vinculada. No crea otro ingreso o gasto.'
          : transfer?.detail ??
                '${r['company']} · ${r['category']} · ${r['comment'] ?? ''}. ${credit > 0 ? 'Abono' : 'Cargo'}: clasifica la operación real; separa capital e impuestos.',
      automaticRule:
          transfer?.rule ??
          (conversionEvidence.containsKey('bank:${r['id']}')
              ? 'bianca_settlement_v1'
              : ''),
      evidence: conversionEvidence.containsKey('bank:${r['id']}')
          ? [r, conversionEvidence['bank:${r['id']}']]
          : r,
      refs: [
        if (invoiceId.isNotEmpty) 'invoice:$invoiceId',
        if (saleId.isNotEmpty) 'sale:$saleId',
      ],
    );
  }
  final expenseEvidence = StatementExpenseEvidence(b);
  for (final kind in ['vault', 'cash']) {
    final table = kind == 'vault'
        ? 'direction_vault_vouchers'
        : 'men_cash_vouchers';
    final lines = <String, List<StatementRow>>{};
    final folios = <String, List<StatementRow>>{};
    String folioKey(StatementRow r) =>
        '${stDate(r['voucher_date'])}|${r['voucher_type']}|${stKey(r['folio'])}';
    for (final r in b.rows(table)) {
      if (stText(r['folio']).isNotEmpty) {
        (folios[folioKey(r)] ??= []).add(r);
      }
    }
    for (final r in b.rows(
      kind == 'vault'
          ? 'direction_vault_voucher_lines'
          : 'men_cash_voucher_lines',
    )) {
      (lines[stText(r['voucher_id'])] ??= []).add(r);
    }
    for (final r in b.rows(table)) {
      if (!relevant('$kind:${r['id']}', r['voucher_date'])) continue;
      final ls = lines[stText(r['id'])] ?? [],
          incoming = r['voucher_type'] == 'deposit';
      final total = stNumber(r['total_amount']);
      final isConversion =
          kind == 'vault' && consumedVaults.contains(stText(r['id']));
      final context =
          '${display(r['person_label'])} ${r['comment']} ${ls.map((l) => l['concept']).join(' ')}';
      final repeated =
          (folios[folioKey(r)] ?? [])
              .where((other) => other['id'] != r['id'])
              .toList()
            ..sort((a, b) => stText(a['id']).compareTo(stText(b['id'])));
      final documents = kind == 'cash'
          ? expenseEvidence.matches(r, ls)
          : <StatementRow>[];
      final transfer = recognizeVoucherSettlement(r, ls);
      if (transfer?.rule == 'payroll_settlement_v1' &&
          period.includes(r['voucher_date'])) {
        payrollPayments.add({
          'source_id': '$kind:${r['id']}',
          'row': r,
          'lines': ls,
        });
      }
      var treatment =
          transfer ??
          (kind == 'cash'
              ? recognizeRetailVoucher(
                  r,
                  ls,
                  repeatedFolio: repeated.isNotEmpty,
                  possibleDocument: documents.isNotEmpty,
                )
              : null);
      if (treatment == null || treatment.account == StatementAccount.pending) {
        treatment =
            statementProvisionalVoucher(
              r,
              ls,
              repeatedFolio: repeated.isNotEmpty,
              possibleDocument: documents.isNotEmpty,
            ) ??
            treatment;
      }
      final a = isConversion
          ? StatementAccount.duplicate
          : treatment?.account ??
                cashAccount(stText(r['rubric']), context, incoming);
      // Keep the whole voucher visible. A word like "transferencia" in one
      // concept must not hide all its other lines.
      rowFact(
        kind,
        kind == 'vault' ? 'Bóveda' : 'Caja Menudeo',
        r,
        'voucher_date',
        'Vale ${display(r['folio'])} · ${display(r['person_label'])}',
        total,
        a,
        isConversion
            ? 'Efectivo recibido de operación vinculada; no venta.'
            : '${r['rubric']} · $context. ${treatment?.detail ?? (bianca(r, ls) ? 'Vincula esta entrada a la operación de efectivo y su costo.' : 'Enlaza con su operación de origen o reconoce únicamente el importe que corresponde al periodo.')}',
        automaticRule: treatment?.rule ?? '',
        estimated: treatment?.estimated ?? false,
        review: treatment?.reviewRequired == true,
        includeWhilePending:
            treatment?.reviewRequired == true &&
            treatment?.account.expense == true,
        refs: [
          for (final d in documents) stText(d['id']),
          for (final d in repeated) '$kind:${d['id']}',
        ],
        evidence: [
          r,
          ls,
          if (documents.isNotEmpty) documents,
          if (repeated.isNotEmpty) repeated,
          if (conversionEvidence.containsKey('$kind:${r['id']}'))
            conversionEvidence['$kind:${r['id']}'],
        ],
      );
      if (period.includes(r['voucher_date']) &&
          ls.isNotEmpty &&
          (ls.fold<double>(0, (s, l) => s + stNumber(l['amount'])) - total)
                  .abs() >
              .01) {
        warnings.add(
          'Vale ${display(r['folio'])} de ${kind == 'vault' ? 'Bóveda' : 'Menudeo'}: cabecera y renglones no coinciden.',
        );
      }
    }
  }
  final weighingTickets = <String, List<StatementRow>>{};
  String weighingKey(StatementRow r) =>
      '${stDate(r['fecha'])}|${stKey(r['ticket'])}';
  for (final r in b.rows('pesadas')) {
    if (stText(r['ticket']).isNotEmpty) {
      (weighingTickets[weighingKey(r)] ??= []).add(r);
    }
  }
  for (final r in b.rows('pesadas')) {
    final price = statementValidNumber(r['precio']);
    final repeated =
        (weighingTickets[weighingKey(r)] ?? [])
            .where((other) => other['id'] != r['id'])
            .toList()
          ..sort((a, b) => stText(a['id']).compareTo(stText(b['id'])));
    final valid =
        price != null &&
        price >= 0 &&
        repeated.isEmpty &&
        stText(r['ticket']).isNotEmpty &&
        stText(r['proveedor']).isNotEmpty;
    rowFact(
      'weighing',
      'Pesadas',
      r,
      'fecha',
      'Pesada ${display(r['ticket'])} · ${display(r['proveedor'])}',
      price ?? 0,
      valid
          ? (price > 0
                ? StatementAccount.otherIncome
                : StatementAccount.balance)
          : StatementAccount.pending,
      valid
          ? (price > 0
                ? 'Servicio de Pesadas reconocido por su precio y fecha. El depósito de caja es su cobro y no genera otro ingreso. Verificar base fiscal al cierre.'
                : 'Servicio con precio explícito de cero; sin ingreso. Un precio faltante requiere revisión.')
          : repeated.isNotEmpty
          ? 'Ticket repetido en la misma fecha. Confirma cuál es el servicio válido antes de reconocerlo.'
          : 'Falta ticket, contraparte o un precio válido del servicio.',
      automaticRule: valid ? 'weighing_service_v1' : '',
      evidence: repeated.isEmpty ? r : [r, repeated],
      refs: [for (final d in repeated) 'weighing:${d['id']}'],
    );
  }
  final services = b
      .rows('services')
      .where(
        (r) =>
            !cancelled(r['status']) &&
            (stDate(r['service_date']) == null ||
                period.includes(r['service_date'])),
      )
      .toList();
  if (services.isNotEmpty) {
    add(
      StatementFact(
        id: 'service-coverage:${period.key}',
        source: 'Servicios',
        label: '${services.length} servicios · cobertura de facturación',
        date: period.end,
        amount: 0,
        account: StatementAccount.pending,
        detail:
            'El módulo no captura importes cobrables. Confirma cuáles son internos o ya están en ventas; registra los servicios adicionales devengados mediante ajuste documentado.',
        evidence: services,
      ),
    );
  }
  final payrollGroups = <String, List<StatementRow>>{};
  final employeeDays = <String, String>{};
  final payrollCoveredDays = <DateTime>{};
  final overlappingPayroll = <String>{};
  final payrollClosures = {
    for (final r in b.rows('hr_payroll_period_closures'))
      stText(r['period_label']): r,
  };
  for (final r in b.rows('hr_prenomina_draft_rows')) {
    if (r['draft_status'] != 'publicado') continue;
    final dates = statementPayrollDates(stText(r['period_label']));
    if (dates == null) {
      warnings.add(
        'Nómina publicada con periodo no interpretable: ${r['period_label']}',
      );
      continue;
    }
    if (dates.$2.isBefore(period.start) || dates.$1.isAfter(period.end)) {
      continue;
    }
    for (
      var day = dates.$1;
      !day.isAfter(dates.$2);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (!period.contains(day)) continue;
      payrollCoveredDays.add(day);
      final key = '${r['employee_id']}|${stDay(day)}';
      final old = employeeDays[key];
      if (old != null) {
        overlappingPayroll.addAll([old, stText(r['id'])]);
      }
      employeeDays[key] = stText(r['id']);
    }
    (payrollGroups['${r['period_label']}|${r['empresa']}'] ??= []).add(r);
  }
  for (final group in payrollGroups.entries) {
    final dates = statementPayrollDates(
      stText(group.value.first['period_label']),
    )!;
    final start = dates.$1.isBefore(period.start) ? period.start : dates.$1;
    final end = dates.$2.isAfter(period.end) ? period.end : dates.$2;
    final ratio =
        (end.difference(start).inDays + 1) /
        (dates.$2.difference(dates.$1).inDays + 1);
    var remuneration = 0.0;
    var review = false;
    for (final r in group.value) {
      final amount = statementPayrollRemuneration(r);
      if (stText(r['employee_id']).isEmpty ||
          overlappingPayroll.contains(stText(r['id']))) {
        warnings.add(
          'Nómina con empleado faltante, repetido o periodo superpuesto en ${group.key}.',
        );
        review = true;
        continue;
      }
      if (amount == null) {
        review = true;
      } else {
        remuneration += amount * ratio;
      }
    }
    final closure = payrollClosures[stText(group.value.first['period_label'])];
    add(
      StatementFact(
        id: 'payroll:${period.key}:${group.key}',
        source: 'RH',
        label: 'Nómina · ${group.key}',
        date: end,
        amount: remuneration,
        account: review ? StatementAccount.pending : StatementAccount.payroll,
        estimated: true,
        automaticRule: review ? '' : 'published_payroll_partial_v1',
        detail:
            '${review ? 'Revisar importes, anticipos de vacaciones o empleados repetidos antes de reconocer este grupo. ' : ''}'
            'Base parcial de remuneración publicada, prorrateada por días: neto fiscal más retenciones fiscales capturadas y complementos antes de préstamos y retenciones de efectivo. El cheque fiscal no se suma otra vez. '
            'Vacaciones incluidas en el neto oficial no se repiten. Falta completar el bruto fiscal, cuotas patronales y provisiones; NO es costo patronal completo. '
            '${closure?['status'] == 'cerrado' ? 'Periodo cerrado en RH.' : 'Publicación sin cierre de RH.'} '
            'Los pagos de banco, Bóveda y caja se revisan juntos en Cobertura de pagos de nómina; no añadirlos de nuevo como gasto.',
        evidence: [group.value, ?closure],
      ),
    );
  }
  if (payrollGroups.isNotEmpty) {
    final missing = <String>[];
    for (
      var d = period.start;
      !d.isAfter(period.end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (!payrollCoveredDays.contains(d)) missing.add(stDay(d));
    }
    if (missing.isNotEmpty) {
      add(
        StatementFact(
          id: 'payroll-coverage:${period.key}',
          source: 'RH',
          label: 'Nómina · ${missing.length} días sin publicación',
          date: period.end,
          amount: 0,
          account: StatementAccount.pending,
          detail:
              'No hay nómina publicada para ${missing.join(', ')}. El costo laboral reconocido es parcial; falta registrar o provisionar esos días, sin trasladar automáticamente los pagos a su fecha de banco.',
          evidence: {'missing_days': missing},
        ),
      );
    }
  }
  if (payrollPayments.isNotEmpty) {
    add(
      StatementFact(
        id: 'payroll-payments:${period.key}',
        source: 'RH',
        label:
            'Cobertura de pagos de nómina · ${payrollPayments.length} movimientos',
        date: period.end,
        amount: 0,
        account: StatementAccount.pending,
        detail:
            'Los pagos de Bancos, Bóveda y Menudeo se clasifican como liquidaciones, sin volver a sumar nómina. Verifica en conjunto que RH incluya a todos los empleados, complementos y periodos pagados. Los anticipos y préstamos se excluyen de este grupo. Registra mediante ajuste cualquier remuneración devengada que falte; los importes de pago no equivalen al costo bruto.',
        references: payrollPayments.map((r) => stText(r['source_id'])).toList(),
        evidence: [
          payrollPayments,
          b.rows('hr_prenomina_draft_rows'),
          b.rows('hr_payroll_period_closures'),
        ],
      ),
    );
  }
  final linkedOt = <String>{};
  for (final r in b.rows('maintenance_purchase_orders')) {
    if (r['status'] != 'purchased') continue;
    if (stText(r['linked_ot_id']).isNotEmpty) {
      linkedOt.add(stText(r['linked_ot_id']));
    }
    rowFact(
      'po',
      'Compras mantenimiento',
      r,
      'order_date',
      'OC ${display(r['folio'])} · ${r['quote_vendor_name']}',
      stNumber(r['actual_total'] ?? r['estimated_total']),
      StatementAccount.pending,
      'Compra operativa. Determina gasto, refacción en almacén o activo; enlaza factura/vale/pago. No sumar otra vez su OT.',
    );
  }
  for (final r in b.rows('maintenance_orders')) {
    if (stNumber(r['cost_actual_total']) <= 0) continue;
    rowFact(
      'ot',
      'Mantenimiento',
      r,
      'requested_at',
      'OT ${r['ot_folio']}',
      stNumber(r['cost_actual_total']),
      linkedOt.contains(stText(r['id']))
          ? StatementAccount.duplicate
          : StatementAccount.pending,
      linkedOt.contains(stText(r['id']))
          ? 'OT con OC vinculada: conciliar el costo en la OC.'
          : 'Confirma servicio incurrido y costo; enlaza comprobante y liquidación.',
    );
  }
  final fuel =
      [
            ...b.rows('logistics_diesel_consumption'),
            ...b.rows('logistics_gasoline_control'),
          ]
          .where(
            (r) =>
                stDate(r['entry_date']) == null ||
                period.includes(r['entry_date']),
          )
          .toList();
  if (fuel.isNotEmpty) {
    add(
      StatementFact(
        id: 'fuel-coverage:${period.key}',
        source: 'Logística',
        label: 'Combustible · adquisición y consumo',
        date: period.end,
        amount: 0,
        account: StatementAccount.pending,
        detail:
            'Los litros no son un gasto adicional a facturas y vales. Concilia compra a tanque, consumo, costo y existencias; vincula la fuente monetaria reconocida.',
        evidence: fuel,
      ),
    );
  }
  // Closing entries add missing accruals, reversals or tax bases without rewriting
  // operational tickets. Signed amounts allow supported credits/reversals.
  for (final r in b.closing.adjustments) {
    final a = StatementAccount.values
        .where((a) => a.name == r['account'])
        .firstOrNull;
    if (a == null ||
        !a.affectsResult ||
        stText(r['note']).isEmpty ||
        !period.includes(r['date'])) {
      warnings.add('Ajuste de cierre inválido: ${r['id']}');
      continue;
    }
    rowFact(
      'adjustment',
      'Ajustes de cierre',
      r,
      'date',
      stText(r['note']),
      stNumber(r['amount']),
      a,
      'Ajuste documentado del periodo.',
      evidence: r,
    );
  }
  final entries = <StatementEntry>[];
  for (final f in facts.values) {
    final d = b.decisions[f.id];
    if (d == null) {
      entries.add(StatementEntry(f, null));
      continue;
    }
    if (d.signature != f.signature) {
      entries.add(
        StatementEntry(
          f,
          null,
          'Cambió la fuente; la clasificación anterior ya no se aplica.',
        ),
      );
      continue;
    }
    try {
      d.validate();
      if (f.date == null && d.economicDate == null) {
        throw StateError('Falta fecha económica');
      }
    } catch (_) {
      entries.add(StatementEntry(f, null, 'Clasificación inválida.'));
      continue;
    }
    if (d.economicDate != null && !period.contains(d.economicDate)) {
      entries.add(
        StatementEntry(
          f,
          StatementDecision(
            id: d.id,
            signature: d.signature,
            note: d.note,
            account: StatementAccount.balance,
            amount: d.amount,
            revision: d.revision,
            economicDate: d.economicDate,
          ),
        ),
      );
      continue;
    }
    if (d.account == StatementAccount.duplicate) {
      final visited = <String>{f.id};
      var target = d.duplicateOf;
      var invalid = false;
      while (true) {
        if (!visited.add(target) || !facts.containsKey(target)) {
          invalid = true;
          break;
        }
        final td = b.decisions[target], tf = facts[target]!;
        if (td != null && td.signature != tf.signature) {
          invalid = true;
          break;
        }
        if (td?.account == StatementAccount.duplicate) {
          target = td!.duplicateOf;
          continue;
        }
        final ta = td?.account ?? tf.account;
        if (ta == StatementAccount.pending ||
            (td == null && tf.reviewRequired)) {
          invalid = true;
        }
        break;
      }
      if (invalid) {
        entries.add(
          StatementEntry(
            f,
            null,
            'El vínculo no tiene operación resuelta en este periodo o forma un ciclo.',
          ),
        );
        continue;
      }
    }
    entries.add(StatementEntry(f, d));
  }
  entries.sort((a, c) {
    final date = (c.decision?.economicDate ?? c.fact.date ?? period.start)
        .compareTo(a.decision?.economicDate ?? a.fact.date ?? period.start);
    return date != 0 ? date : a.fact.label.compareTo(c.fact.label);
  });
  final signatureEntries =
      entries
          .map(
            (e) => {
              'id': e.fact.id,
              'source': e.fact.signature,
              'decision': e.decision?.toRow(),
              'issue': e.issue,
            },
          )
          .toList()
        ..sort((a, c) => stText(a['id']).compareTo(stText(c['id'])));
  return StatementAnalysis(
    bundle: b,
    entries: entries,
    materials: material.values.toList()
      ..sort((a, c) => a.label.compareTo(c.label)),
    warnings: warnings.toSet().toList()..sort(),
    signature: stSignature({
      'engine': 1,
      'recognition_revision': 6,
      'period': period.key,
      'entries': signatureEntries,
      'warnings': warnings.toSet().toList()..sort(),
    }),
  );
}
