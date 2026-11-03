import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../shared/utils/file_download_save.dart';
import '../shared/utils/number_formatters.dart';
import 'contabilidad_flow_analysis_store.dart';
import 'contabilidad_income_statement_store.dart';

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
}) async {
  final bytes = await buildContabilidadIncomeStatementPdf(statement: statement);
  await saveBytesAs(
    bytes: bytes,
    suggestedFileName: 'estado_resultados_${_dateStamp(DateTime.now())}.pdf',
    dialogTitle: 'Guardar estado de resultados como PDF',
  );
}

Future<Uint8List> buildContabilidadIncomeStatementPdf({
  required ContabilidadIncomeStatementDataset statement,
}) async {
  return _buildPdf(
    title: 'Estado de Resultados · ${statement.snapshot.statementStatus}',
    notes: [
      if (!statement.snapshot.isAccrual)
        'Lectura de caja con las categorías registradas en Bancos, Bóveda y Menudeo. Otras entradas puede incluir financiamiento. Las revisiones del cierre contable se consultan por separado.',
      ...statement.warnings,
    ],
    range: statement.range,
    sections: <_PdfSectionData>[
      _PdfSectionData(
        'Resultado del periodo',
        statement.lines
            .map(
              (line) => _PdfMetric(line.label, line.amount, line.amountLabel),
            )
            .toList(growable: false),
      ),
      if (statement.recognition != null)
        _PdfSectionData('Gastos incluidos por fuente · incluye estimaciones', [
          for (final row in statement.sourceRows.where(
            (r) =>
                r.recognizedExpenses > .009 &&
                r.label != 'Entradas y Salidas / Compras',
          ))
            _PdfMetric(row.label, row.recognizedExpenses),
        ]),
      if (statement.expenseCoverage.isNotEmpty)
        _PdfSectionData('Capturado por categoría · no sumar al resultado', [
          for (final row in statement.expenseCoverage) ...[
            _PdfMetric(
              '${row.source} · ${row.category} · Registrado (${row.count})',
              row.recorded,
            ),
            _PdfMetric(
              '${row.source} · ${row.category} · Gasto reconocido aquí',
              row.recognizedHere,
            ),
            _PdfMetric(
              '${row.source} · ${row.category} · Por aclarar',
              row.pending,
            ),
            _PdfMetric(
              '${row.source} · ${row.category} · Pagos vinculados',
              row.linked,
            ),
            if (row.linkedPending > .009)
              _PdfMetric(
                'De esos pagos: documentos pendientes del periodo',
                row.linkedPending,
              ),
          ],
        ]),
      _PdfSectionData(
        statement.snapshot.isAccrual
            ? 'Otros ingresos reconocidos'
            : 'Otras entradas registradas',
        statement.otherIncomeBreakdown
            .map(
              (row) => _PdfMetric(
                '${row.label} | ${row.sourceLabel} (${row.count})',
                row.amount,
              ),
            )
            .toList(growable: false),
      ),
      _PdfSectionData(
        'Desglose de gastos por categoria y fuente',
        statement.expenseBreakdown
            .map(
              (row) => _PdfMetric(
                '${row.label} | ${row.sourceLabel} (${row.count})',
                row.amount,
              ),
            )
            .toList(growable: false),
      ),
      if (statement.snapshot.internalExcluded > 0.009)
        _PdfSectionData(
          statement.snapshot.isAccrual
              ? 'Registros de balance · sin efecto en resultado'
              : 'Traspasos internos aislados',
          <_PdfMetric>[
            _PdfMetric(
              statement.snapshot.isAccrual
                  ? 'Importes clasificados en balance; no es un flujo neto'
                  : 'Banco a Bóveda por cheque (no afecta resultado)',
              statement.snapshot.internalExcluded,
            ),
          ],
        ),
    ],
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
  List<String> notes = const [],
}) async {
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 20 + sections.fold<int>(0, (sum, s) => sum + s.metrics.length),
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
          'Periodo: ${_rangeLabel(range)} | Generado: ${_rangeLabel(DateTimeRange(start: DateTime.now(), end: DateTime.now())).split(' - ').first}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        for (final note in notes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(note, style: const pw.TextStyle(fontSize: 10)),
          ),
        for (final section in sections.where((s) => s.metrics.isNotEmpty)) ...[
          if (section.metrics.length <= 3)
            pw.Inseparable(child: _section(section))
          else
            _section(section),
          pw.SizedBox(height: 14),
        ],
      ],
    ),
  );
  return document.save();
}

// Keep the table directly under MultiPage so hundreds of recognized operations
// can span pages. A Container/Column around it makes the section indivisible.
pw.Widget _section(_PdfSectionData section) => pw.Table(
  border: pw.TableBorder.all(color: PdfColor.fromHex('#D7E6E7')),
  columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(1.3)},
  children: [
    pw.TableRow(
      repeat: true,
      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E6EEEE')),
      children: [
        for (final label in [section.title, 'Importe'])
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#12373C'),
              ),
            ),
          ),
      ],
    ),
    for (final metric in section.metrics)
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              metric.label,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                metric.valueLabel ?? formatMoney(metric.value),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
  ],
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
  final String? valueLabel;
  const _PdfMetric(this.label, this.value, [this.valueLabel]);
}
