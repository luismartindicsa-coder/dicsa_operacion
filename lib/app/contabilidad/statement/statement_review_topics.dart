import 'statement_models.dart';

enum StatementReviewTopic {
  conversions(
    'Bianca / Maricruz',
    'Verifica las entradas o pagos que no coinciden con una factura y el 4%. Los cruces inequívocos ya se resuelven automáticamente.',
  ),
  payroll(
    'Nómina y finiquitos',
    'Revisa la cobertura de RH en conjunto. Los pagos de nómina son liquidaciones; registra únicamente remuneraciones o provisiones faltantes y separa finiquitos.',
  ),
  taxes(
    'Impuestos y retenciones',
    'Separa impuestos recuperables, retenciones y gasto propio. Un pago fiscal puede cubrir varios conceptos o periodos.',
  ),
  finance(
    'Créditos, seguros y arrendamientos',
    'Separa capital, intereses, depósitos en garantía y periodos de cobertura antes de reconocer gasto.',
  ),
  maintenance(
    'Compras y mantenimiento',
    'Vincula OC, OT y comprobantes. Distingue consumibles usados, existencias en almacén y activos; reconoce cada compra una sola vez.',
  ),
  invoices(
    'Facturas sin tratamiento completo',
    'Completa naturaleza y periodo con la información capturada; verifica si el gasto ya aparece en un vale o en otro documento.',
  ),
  collections(
    'Ventas y cobros',
    'Verifica que cada ingreso o entrega de dinero corresponda a una venta reconocida. Los cobros no generan otra venta.',
  ),
  materials(
    'Materiales y costo',
    'Relaciona compras, pagos y Entradas/Salidas; revisa familias sin costo o sin salidas y los supuestos de transformación.',
  ),
  cash(
    'Vales y movimientos por aclarar',
    'Aclara el destino de entregas de dinero y separa conceptos mixtos. Un nombre de persona o la categoría Comisiones no demuestra por sí solo un gasto.',
  ),
  coverage(
    'Servicios y combustible',
    'Comprueba qué servicios ya están facturados y qué combustible fue consumido; evita repetir facturas y vales reconocidos.',
  ),
  weighing(
    'Pesadas por aclarar',
    'Corrige tickets repetidos o incompletos en Pesadas y reconoce el servicio válido una sola vez.',
  ),
  changed(
    'Fuentes modificadas',
    'La fuente cambió después de una revisión. Comprueba los nuevos datos antes de volver a aplicar la clasificación.',
  );

  final String label, guidance;
  const StatementReviewTopic(this.label, this.guidance);
}

/// Topics are navigation, never accounting decisions. Every unresolved entry
/// remains visible and contributes to the real pending count and closing gate.
Map<StatementReviewTopic, List<StatementEntry>> statementReviewTopics(
  StatementAnalysis a,
) {
  const prefixes = {
    'bank': 'finanzas_bank_movements',
    'vault': 'direction_vault_vouchers',
    'cash': 'men_cash_vouchers',
    'invoice': 'finanzas_supplier_invoices',
  };
  final originals = <String, StatementRow>{
    for (final p in prefixes.entries)
      for (final r in a.bundle.rows(p.value)) '${p.key}:${r['id']}': r,
  };
  final grouped = <StatementReviewTopic, List<StatementEntry>>{};
  for (final e in a.pending) {
    final r = originals[e.fact.id] ?? {};
    final text = stKey(
      [
        e.fact.label,
        r['category'],
        r['rubric'],
        r['reference'],
        r['comment'],
        r['notes'],
      ].map(stText).join(' '),
    );
    final StatementReviewTopic topic;
    if (e.issue != null) {
      topic = StatementReviewTopic.changed;
    } else if (e.fact.id.startsWith('conversion:') ||
        RegExp(r'\bBIANCA\b|MARICRUZ QUIROGA').hasMatch(text)) {
      topic = StatementReviewTopic.conversions;
    } else if (e.fact.source == 'RH' ||
        RegExp(r'\b(NOMINA|FINIQUITO|SUELDO|SALARIO)\b').hasMatch(text)) {
      topic = StatementReviewTopic.payroll;
    } else if (RegExp(
      r'\b(IMPUESTOS?|IVA|ISR|IMSS|INFONAVIT|FONACOT|RETENCIONES?)\b',
    ).hasMatch(text)) {
      topic = StatementReviewTopic.taxes;
    } else if ([
      'Compras mantenimiento',
      'Mantenimiento',
    ].contains(e.fact.source)) {
      topic = StatementReviewTopic.maintenance;
    } else if (RegExp(
      r'\b(CREDITO|TARJETA|KONFIO|PACCAR|ARRENDAMIENTO|ARRENDADORA|SEGURO|QUALITAS|GARANTIA)\b',
    ).hasMatch(text)) {
      topic = StatementReviewTopic.finance;
    } else if (e.fact.source == 'Facturas proveedor') {
      topic = StatementReviewTopic.invoices;
    } else if (e.fact.source == 'Entradas y Salidas / Compras' ||
        e.fact.source == 'Compras Mayoreo' ||
        stKey(r['rubric']) == 'COMPRA DE MATERIAL') {
      topic = StatementReviewTopic.materials;
    } else if (e.fact.source == 'Ventas Mayoreo' ||
        stNumber(r['credit_amount']) > 0 ||
        RegExp(r'\bVENTAS?\b').hasMatch(text)) {
      topic = StatementReviewTopic.collections;
    } else if (['Servicios', 'Logística'].contains(e.fact.source)) {
      topic = StatementReviewTopic.coverage;
    } else if (e.fact.source == 'Pesadas') {
      topic = StatementReviewTopic.weighing;
    } else {
      topic = StatementReviewTopic.cash;
    }
    (grouped[topic] ??= []).add(e);
  }
  return Map.fromEntries(
    grouped.entries.toList()
      ..sort((x, y) => x.key.label.compareTo(y.key.label)),
  );
}
