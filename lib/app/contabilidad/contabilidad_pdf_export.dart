import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../shared/utils/file_download_save.dart';
import '../shared/utils/number_formatters.dart';
import 'contabilidad_flow_analysis_store.dart';
import 'contabilidad_income_statement_store.dart';

class ContabilidadReviewedExpensePdfRow {
  final String label;
  final String source;
  final String family;
  final double amount;

  const ContabilidadReviewedExpensePdfRow({
    required this.label,
    required this.source,
    required this.family,
    required this.amount,
  });
}

Future<void> exportContabilidadFlowPdf({
  required ContabilidadFlowDataset flow,
  required ContabilidadPeriodicFlowDataset payables,
  required ContabilidadPeriodicIncomeDataset income,
  required ContabilidadPeriodicOperationalDataset operational,
}) async {
  final bytes = await _buildPdf(
    title: 'Analisis de Flujo',
    range: flow.range,
    sections: <_PdfSectionData>[
      _PdfSectionData('Flujo real', <_PdfMetric>[
        _PdfMetric('Entradas reales', flow.snapshot.realInflows),
        _PdfMetric('Salidas reales', flow.snapshot.realOutflows),
        _PdfMetric('Flujo neto', flow.snapshot.realNetFlow),
        _PdfMetric('Traspasos internos', flow.snapshot.internalTransfers),
      ]),
      _PdfSectionData('Facturas de proveedor del periodo', <_PdfMetric>[
        _PdfMetric('Facturado', payables.invoicedAmount),
        _PdfMetric('Pagado', payables.paidAmount),
        _PdfMetric('Pendiente', payables.pendingAmount),
        _PdfMetric('Pagado vencido', payables.paidLateAmount),
      ]),
      _PdfSectionData('Ingresos - ventas mayoristas facturadas', <_PdfMetric>[
        _PdfMetric('Facturado', income.invoicedAmount),
        _PdfMetric('Cobrado vinculado', income.collectedCurrentAmount),
        _PdfMetric('Por cobrar', income.pendingAmount),
        _PdfMetric(
          'Cobros de atrasos',
          income.collectedHistoricalOverdueAmount,
        ),
      ]),
      _operationalSection(operational),
    ],
  );
  await saveBytesAs(
    bytes: bytes,
    suggestedFileName: 'analisis_flujo_${_dateStamp(DateTime.now())}.pdf',
    dialogTitle: 'Guardar analisis de flujo como PDF',
  );
}

Future<void> exportContabilidadIncomeStatementPdf({
  required ContabilidadIncomeStatementDataset statement,
  required ContabilidadPeriodicFlowDataset payables,
  required ContabilidadPeriodicIncomeDataset income,
  required ContabilidadPeriodicOperationalDataset operational,
  required List<ContabilidadReviewedExpensePdfRow> reviewedExpenses,
}) async {
  final snapshot = statement.snapshot;
  final reviewedTotal = reviewedExpenses.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );
  final reviewedByFamily = <String, double>{};
  for (final row in reviewedExpenses) {
    reviewedByFamily.update(
      row.family,
      (value) => value + row.amount,
      ifAbsent: () => row.amount,
    );
  }
  final bytes = await _buildPdf(
    title: 'Estado de Resultados',
    range: statement.range,
    sections: <_PdfSectionData>[
      _PdfSectionData('Resultado del periodo', <_PdfMetric>[
        _PdfMetric('Ingresos', snapshot.revenue),
        _PdfMetric('Costo comercial', snapshot.commercialCost),
        _PdfMetric(
          'Gastos reconocidos',
          snapshot.recognizedExpenses + reviewedTotal,
        ),
        _PdfMetric('Resultado', snapshot.periodResult - reviewedTotal),
      ]),
      _PdfSectionData('Desglose de gastos reconocidos', <_PdfMetric>[
        _PdfMetric(
          'Gasto operativo',
          snapshot.operatingExpense + (reviewedByFamily['Operativo'] ?? 0),
        ),
        _PdfMetric(
          'Gasto administrativo',
          snapshot.administrativeExpense +
              (reviewedByFamily['Administrativo'] ?? 0),
        ),
        _PdfMetric(
          'Gasto financiero',
          snapshot.financialExpense + (reviewedByFamily['Financiero'] ?? 0),
        ),
        _PdfMetric(
          'Nomina',
          snapshot.payrollExpense + (reviewedByFamily['Nomina'] ?? 0),
        ),
        _PdfMetric(
          'Total gastos reconocidos',
          snapshot.recognizedExpenses + reviewedTotal,
        ),
      ]),
      _PdfSectionData(
        'Detalle de gastos por rubro y fuente',
        statement.expenseBreakdown
            .where((row) => row.amount > 0.009)
            .map(
              (row) =>
                  _PdfMetric('${row.label} | ${row.sourceLabel}', row.amount),
            )
            .toList(growable: false),
      ),
      if (reviewedExpenses.isNotEmpty)
        _PdfSectionData(
          'Gastos reconocidos desde Revision',
          reviewedExpenses
              .map(
                (row) => _PdfMetric(
                  '${row.label} | ${row.source} | ${row.family}',
                  row.amount,
                ),
              )
              .toList(growable: false),
        ),
      _PdfSectionData('Facturas de proveedor del periodo', <_PdfMetric>[
        _PdfMetric('Facturado', payables.invoicedAmount),
        _PdfMetric('Pagado', payables.paidAmount),
        _PdfMetric('Pendiente', payables.pendingAmount),
      ]),
      _PdfSectionData('Ingresos - ventas mayoristas facturadas', <_PdfMetric>[
        _PdfMetric('Facturado', income.invoicedAmount),
        _PdfMetric('Cobrado vinculado', income.collectedCurrentAmount),
        _PdfMetric('Por cobrar', income.pendingAmount),
      ]),
      _operationalSection(operational),
    ],
  );
  await saveBytesAs(
    bytes: bytes,
    suggestedFileName: 'estado_resultados_${_dateStamp(DateTime.now())}.pdf',
    dialogTitle: 'Guardar estado de resultados como PDF',
  );
}

_PdfSectionData _operationalSection(
  ContabilidadPeriodicOperationalDataset data,
) => _PdfSectionData('Operacion - Boveda y efectivo', <_PdfMetric>[
  _PdfMetric('Entradas', data.vaultInflows + data.cashInflows),
  _PdfMetric('Salidas', data.vaultOutflows + data.cashOutflows),
  _PdfMetric('Neto operativo', data.operationalNet),
  _PdfMetric('Internos de Boveda aislados', data.vaultInternalTransfers),
]);

Future<Uint8List> _buildPdf({
  required String title,
  required DateTimeRange? range,
  required List<_PdfSectionData> sections,
}) async {
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Text(
        'DICSA | Contabilidad',
        style: pw.TextStyle(
          color: PdfColor.fromHex('#397A80'),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Pagina ${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (_) => <pw.Widget>[
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 25,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#12373C'),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Periodo: ${_rangeLabel(range)} | Generado: ${_rangeLabel(DateTimeRange(start: DateTime.now(), end: DateTime.now()))}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        ...sections.map(_section),
      ],
    ),
  );
  return document.save();
}

pw.Widget _section(_PdfSectionData section) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 14),
  padding: const pw.EdgeInsets.all(14),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: PdfColor.fromHex('#D7E6E7')),
    borderRadius: pw.BorderRadius.circular(8),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        section.title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#12373C'),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColor.fromHex('#E6EEEE')),
        children: section.metrics
            .map(
              (metric) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(metric.label),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        formatMoney(metric.value),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    ],
  ),
);

String _rangeLabel(DateTimeRange? range) {
  if (range == null) return 'Sin rango';
  String date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  return '${date(range.start)} - ${date(range.end)}';
}

String _dateStamp(DateTime value) =>
    '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';

class _PdfSectionData {
  final String title;
  final List<_PdfMetric> metrics;
  const _PdfSectionData(this.title, this.metrics);
}

class _PdfMetric {
  final String label;
  final double value;
  const _PdfMetric(this.label, this.value);
}
