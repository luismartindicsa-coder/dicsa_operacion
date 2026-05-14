import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'menudeo_analysis_models.dart';

Future<Uint8List> buildMenudeoAnalysisReportPdf({
  required MenudeoAnalysisFilters filters,
  required MenudeoMarketViewData market,
  required MenudeoCashDataset cash,
  required MenudeoOperationDataset operation,
  required DateTime generatedAt,
}) async {
  final doc = pw.Document();
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {
    logoImage = null;
  }

  final executiveInsights = _buildExecutiveInsights(
    market: market,
    cash: cash,
    operation: operation,
  );
  final actionPlan = _buildActionPlan(
    market: market,
    cash: cash,
    operation: operation,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (context) => [
        _pdfHeader(
          logoImage: logoImage,
          generatedAt: generatedAt,
          rangeLabel: _rangeLabel(filters),
        ),
        pw.SizedBox(height: 14),
        _pdfSection(
          title: 'Resumen ejecutivo',
          child: _metricGrid([
            MapEntry(
              'Mercado · oportunidades',
              '${market.snapshot.actionablePrices}',
            ),
            MapEntry(
              'Mercado · impacto potencial',
              _money(market.snapshot.potentialImpact),
            ),
            MapEntry('Efectivo · neto', _money(cash.snapshot.netFlow)),
            MapEntry(
              'Efectivo · checks pendientes',
              '${cash.snapshot.pendingChecks}',
            ),
            MapEntry(
              'Operación · flujo comercial',
              _money(operation.snapshot.netCommercialFlow),
            ),
            MapEntry(
              'Operación · tickets pendientes',
              '${operation.snapshot.pendingTickets}',
            ),
          ]),
        ),
        pw.SizedBox(height: 12),
        _pdfSection(
          title: 'Insights clave',
          child: _bulletList(executiveInsights),
        ),
        pw.SizedBox(height: 12),
        _pdfSection(
          title: 'Acciones de trabajo sugeridas',
          child: _bulletList(actionPlan),
        ),
        pw.SizedBox(height: 12),
        _pdfTwoColumn(
          leftTitle: 'Mercado',
          leftChild: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metricGrid([
                MapEntry('Precios activos', '${market.snapshot.activePrices}'),
                MapEntry(
                  'Materiales presionados',
                  '${market.snapshot.pressuredMaterials}',
                ),
              ]),
              pw.SizedBox(height: 10),
              _simpleTable(
                headers: const [
                  'Contraparte',
                  'Material',
                  'Acción',
                  'Delta',
                  'Impacto',
                ],
                rows: market.opportunities
                    .where((row) => row.isActionable)
                    .take(6)
                    .map(
                      (row) => [
                        row.counterparty,
                        row.material,
                        menudeoActionLabel(row.action),
                        row.suggestedDelta.toStringAsFixed(2),
                        _money(row.impactEstimate),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'Sin oportunidades accionables en la ventana actual.',
              ),
            ],
          ),
          rightTitle: 'Efectivo',
          rightChild: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metricGrid([
                MapEntry('Depósitos', _money(cash.snapshot.deposits)),
                MapEntry('Gastos', _money(cash.snapshot.expenses)),
              ]),
              pw.SizedBox(height: 10),
              _simpleTable(
                headers: const ['Rubro', 'Monto', 'Share'],
                rows: cash.rubricRows
                    .take(5)
                    .map(
                      (row) => [
                        row.label,
                        _money(row.total),
                        _percent(row.share),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel: 'Sin gasto analizado en la ventana actual.',
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        _pdfTwoColumn(
          leftTitle: 'Operación',
          leftChild: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metricGrid([
                MapEntry(
                  'Compras pagadas',
                  _money(operation.snapshot.purchaseAmount),
                ),
                MapEntry(
                  'Ventas pagadas',
                  _money(operation.snapshot.saleAmount),
                ),
              ]),
              pw.SizedBox(height: 10),
              _simpleTable(
                headers: const ['Material', 'Monto', 'Kg', 'Tickets'],
                rows: operation.materialRows
                    .take(5)
                    .map(
                      (row) => [
                        row.label,
                        _money(row.amount),
                        row.weight.toStringAsFixed(0),
                        '${row.count}',
                      ],
                    )
                    .toList(growable: false),
                emptyLabel: 'Sin materiales operados en la ventana actual.',
              ),
            ],
          ),
          rightTitle: 'Riesgos abiertos',
          rightChild: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _simpleTable(
                headers: const ['Tipo', 'Detalle'],
                rows: [
                  for (final alert in market.alerts.take(2))
                    ['Mercado', alert.detail],
                  for (final alert in cash.alerts.take(2))
                    ['Efectivo', alert.detail],
                  for (final alert in operation.alerts.take(2))
                    ['Operación', alert.detail],
                ],
                emptyLabel: 'Sin alertas relevantes en la ventana actual.',
              ),
              pw.SizedBox(height: 10),
              _simpleTable(
                headers: const ['Ticket', 'Contraparte', 'Estatus', 'Monto'],
                rows: operation.pendingRows
                    .take(6)
                    .map(
                      (row) => [
                        row.ticketNumber.isEmpty ? row.id : row.ticketNumber,
                        row.counterparty.isEmpty
                            ? 'Sin contraparte'
                            : row.counterparty,
                        row.status,
                        _money(row.amount),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel: 'No hay tickets pendientes en la ventana actual.',
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        _pdfSection(
          title: 'Notas de lectura',
          child: _bulletList([
            'El reporte usa la ventana activa del análisis y resume el estado real capturado en la app al momento de exportar.',
            'En efectivo, los resúmenes contemplan el flujo capturado; el análisis detallado sigue excluyendo transferencias internas entre cajas.',
            'Las acciones sugeridas son operativas y ejecutivas: sirven para seguimiento mensual en Dirección, no sustituyen validación comercial final.',
          ]),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfHeader({
  required pw.MemoryImage? logoImage,
  required DateTime generatedAt,
  required String rangeLabel,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: const PdfColor.fromInt(0xFFD6E5EE)),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoImage != null)
          pw.Container(
            width: 48,
            height: 48,
            margin: const pw.EdgeInsets.only(right: 14),
            child: pw.Image(logoImage),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Reporte Ejecutivo Menudeo',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF173A78),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Dirección · Resumen mensual de mercado, efectivo y operación',
                style: const pw.TextStyle(
                  fontSize: 10.5,
                  color: PdfColor.fromInt(0xFF4F667F),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoBadge('Ventana', rangeLabel),
                  _infoBadge('Generado', _dateTime(generatedAt)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfSection({required String title, required pw.Widget child}) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: const PdfColor.fromInt(0xFFDCE7EE)),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13.5,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF173A78),
          ),
        ),
        pw.SizedBox(height: 10),
        child,
      ],
    ),
  );
}

pw.Widget _pdfTwoColumn({
  required String leftTitle,
  required pw.Widget leftChild,
  required String rightTitle,
  required pw.Widget rightChild,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _pdfSection(title: leftTitle, child: leftChild),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: _pdfSection(title: rightTitle, child: rightChild),
      ),
    ],
  );
}

pw.Widget _metricGrid(List<MapEntry<String, String>> metrics) {
  return pw.Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final metric in metrics)
        pw.Container(
          width: 150,
          padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF4F8FB),
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFDCE7EE)),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                metric.key,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  color: PdfColor.fromInt(0xFF60758C),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                metric.value,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF173A78),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _simpleTable({
  required List<String> headers,
  required List<List<String>> rows,
  required String emptyLabel,
}) {
  if (rows.isEmpty) {
    return pw.Text(
      emptyLabel,
      style: const pw.TextStyle(
        fontSize: 10,
        color: PdfColor.fromInt(0xFF60758C),
      ),
    );
  }
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(
      fontSize: 9.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFF173A78),
    ),
    cellStyle: const pw.TextStyle(
      fontSize: 9.5,
      color: PdfColor.fromInt(0xFF203549),
    ),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.fromLTRB(6, 6, 6, 6),
    border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFDCE7EE)),
    rowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FBFD)),
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
  );
}

pw.Widget _bulletList(List<String> items) {
  if (items.isEmpty) {
    return pw.Text(
      'Sin hallazgos relevantes en la ventana actual.',
      style: const pw.TextStyle(
        fontSize: 10,
        color: PdfColor.fromInt(0xFF60758C),
      ),
    );
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final item in items.take(8))
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
              pw.Expanded(
                child: pw.Text(
                  item,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(0xFF203549),
                    lineSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _infoBadge(String label, String value) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF4F8FB),
      border: pw.Border.all(color: const PdfColor.fromInt(0xFFDCE7EE)),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(999)),
    ),
    child: pw.Text(
      '$label: $value',
      style: const pw.TextStyle(
        fontSize: 9.5,
        color: PdfColor.fromInt(0xFF35506A),
      ),
    ),
  );
}

List<String> _buildExecutiveInsights({
  required MenudeoMarketViewData market,
  required MenudeoCashDataset cash,
  required MenudeoOperationDataset operation,
}) {
  final insights = <String>[];
  if (market.opportunities.isNotEmpty) {
    final top = market.opportunities.first;
    insights.add(
      '${top.counterparty} en ${top.material} concentra la primera oportunidad de mercado con acción sugerida ${menudeoActionLabel(top.action).toLowerCase()} e impacto estimado de ${_money(top.impactEstimate)}.',
    );
  }
  if (cash.rubricRows.isNotEmpty) {
    final top = cash.rubricRows.first;
    insights.add(
      '${top.label} es hoy el rubro dominante del gasto analizado con ${_percent(top.share)} del total depurado.',
    );
  }
  if (cash.logisticsUnitRows.isNotEmpty) {
    final top = cash.logisticsUnitRows.first;
    insights.add(
      '${top.label} lidera el gasto por unidad con ${_money(top.total)}, distribuido entre combustible, mantenimiento y viajes.',
    );
  }
  if (operation.materialRows.isNotEmpty) {
    final top = operation.materialRows.first;
    insights.add(
      '${top.label} es el material con mayor flujo pagado en operación con ${_money(top.amount)} y ${top.weight.toStringAsFixed(0)} kg.',
    );
  }
  if (operation.pendingRows.isNotEmpty) {
    insights.add(
      'Existen ${operation.pendingRows.length} tickets abiertos o en conciliación que siguen afectando el cierre operativo del periodo.',
    );
  }
  insights.addAll(market.alerts.take(2).map((alert) => alert.detail));
  insights.addAll(cash.alerts.take(2).map((alert) => alert.detail));
  insights.addAll(operation.alerts.take(2).map((alert) => alert.detail));
  return insights;
}

List<String> _buildActionPlan({
  required MenudeoMarketViewData market,
  required MenudeoCashDataset cash,
  required MenudeoOperationDataset operation,
}) {
  final actions = <String>[];
  for (final row
      in market.opportunities.where((row) => row.isActionable).take(3)) {
    actions.add(
      '${menudeoActionLabel(row.action)} precio a ${row.counterparty} en ${row.material} con delta sugerido de ${row.suggestedDelta.toStringAsFixed(2)} y seguimiento inmediato del impacto.',
    );
  }
  if (cash.rubricRows.isNotEmpty) {
    final top = cash.rubricRows.first;
    actions.add(
      'Revisar el rubro ${top.label} porque concentra ${_percent(top.share)} del gasto analizado del periodo.',
    );
  }
  if (cash.logisticsUnitRows.isNotEmpty) {
    final top = cash.logisticsUnitRows.first;
    actions.add(
      'Auditar la unidad ${top.label} y validar si el peso de combustible, mantenimiento y viajes corresponde al uso real del mes.',
    );
  }
  if (operation.pendingRows.isNotEmpty) {
    actions.add(
      'Cerrar o conciliar los tickets pendientes del periodo antes del siguiente corte directivo para evitar arrastre operativo.',
    );
  }
  return actions;
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _rangeLabel(MenudeoAnalysisFilters filters) {
  final range = filters.dateRange;
  if (range == null) return 'Últimos ${filters.windowDays} días';
  return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
}

String _shortDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}
