import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../contabilidad/contabilidad_theme.dart';
import '../shared/utils/number_formatters.dart';
import 'accounting_weekly_analysis.dart';
import 'accounting_weekly_source.dart';
import 'management_reports_registry.dart';

Future<Uint8List> buildAccountingWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
  AccountingWeeklySource? source,
}) async {
  final data = source ?? await loadAccountingWeeklySource(generatedAt);
  final report = AccountingWeeklyAnalysis(data);
  final cut = data.cut;
  final current = data.currentStatement.snapshot;
  final previous = data.previousStatement.snapshot;
  final style = _AccountingPdfStyle();
  final pdf = pw.Document(
    title: 'Contabilidad · Comparativo semanal',
    author: generatedBy,
  );
  final currentLabel =
      '${_date(cut.current.start)} al ${_date(cut.current.end)}';
  final previousLabel =
      '${_date(cut.previous.start)} al ${_date(cut.previous.end)}';
  List<String> compare(String label, double a, double b, {bool money = true}) =>
      [
        label,
        money ? _money(a) : _number(a),
        money ? _money(b) : _number(b),
        money ? _money(a - b) : _number(a - b),
        _percent(a, b),
      ];
  List<String> tradeRow(AccountingTradeComparison r) => [
    r.label,
    _money(r.current.purchases),
    _money(r.previous.purchases),
    _money(r.current.sales),
    _money(r.previous.sales),
    _money(r.current.result),
    _money(r.previous.result),
    _money(r.current.result - r.previous.result),
  ];
  const comparisonHeaders = [
    'Concepto',
    'Semana actual',
    'Semana anterior',
    'Variación',
    'Variación %',
  ];
  const tradeHeaders = [
    'Material / canal',
    'Compra actual',
    'Compra anterior',
    'Venta actual',
    'Venta anterior',
    'Resultado actual',
    'Resultado anterior',
    'Variación resultado',
  ];
  List<List<String>> breakdown(List<AccountingAmountComparison> rows) => [
    for (final row in rows)
      [
        row.label,
        row.source,
        _money(row.current),
        _money(row.previous),
        _money(row.change),
        _percent(row.current, row.previous),
      ],
  ];
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 2000,
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DICSA · Contabilidad · $currentLabel',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: style.soft,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DICSA · SUPERVISIÓN DE VIERNES',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: style.ink,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 7),
              pw.Text(
                '${area.title} · Comparativo semanal',
                style: pw.TextStyle(
                  fontSize: 23,
                  color: style.ink,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Resultado comercial y estado de resultados',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Actual: $currentLabel   |   Anterior: $previousLabel',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                cut.partial
                    ? 'CORTE PARCIAL · Se comparan los mismos días de ambas semanas.'
                    : 'CORTE DE LUNES A VIERNES · Sábado y domingo quedan fuera de ambas semanas.',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: style.ink,
                ),
              ),
              pw.Text(
                _clean(
                  'Generado: ${generatedAt.toIso8601String()} · $generatedBy',
                  max: 220,
                ),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        style.note(
          'Importes en MXN. El corte incluye los registros disponibles de los días indicados al momento de generarse. Variación = actual - anterior; porcentaje sobre el valor absoluto anterior. "Sin base" indica que el valor anterior es cero.',
        ),
        ...style.table(
          'Lectura ejecutiva',
          comparisonHeaders,
          [
            compare(
              'Resultado comercial: ventas menos compras registradas',
              report.current.result,
              report.previous.result,
            ),
            compare(
              'Utilidad bruta del estado de resultados',
              current.commercialResult,
              previous.commercialResult,
            ),
            compare(
              'Gastos del estado de resultados',
              current.recognizedExpenses,
              previous.recognizedExpenses,
            ),
            compare(
              'Utilidad neta del estado de resultados',
              current.periodResult,
              previous.periodResult,
            ),
          ],
          widths: [3.5, 1.6, 1.6, 1.6, 1.2],
          closingNote:
              'El resultado comercial usa operaciones de compra/venta. El estado de resultados usa entradas y salidas clasificadas de Bancos, Bóveda y Menudeo. Sus cifras responden a bases distintas y no se suman entre sí.',
        ),
        ...style.table(
          '1. Resultado comercial · comparativo',
          comparisonHeaders,
          [
            compare(
              'Compras registradas',
              report.current.purchases,
              report.previous.purchases,
            ),
            compare(
              'Ventas registradas',
              report.current.sales,
              report.previous.sales,
            ),
            compare(
              'Resultado comercial (ventas - compras)',
              report.current.result,
              report.previous.result,
            ),
            compare(
              'Kilogramos comprados',
              report.current.purchasedKg,
              report.previous.purchasedKg,
              money: false,
            ),
            compare(
              'Kilogramos vendidos',
              report.current.soldKg,
              report.previous.soldKg,
              money: false,
            ),
            compare(
              'Operaciones registradas',
              report.current.events.length.toDouble(),
              report.previous.events.length.toDouble(),
              money: false,
            ),
          ],
          widths: [3.5, 1.6, 1.6, 1.6, 1.2],
          closingNote:
              'Se utiliza la misma base del Resultado Comercial: Menudeo, Compras Mayoreo y Ventas Mayoreo por fecha de operación. Ventas menos compras es el saldo comercial del periodo; no aplica valuación de inventario ni costo de lo vendido.',
        ),
        if (report.current.events.isEmpty || report.previous.events.isEmpty)
          style.note(
            'Operaciones comerciales: ${report.current.events.length} en la semana actual y ${report.previous.events.length} en la anterior. Los ceros corresponden a una consulta sin movimientos, no a una falla de conexión.',
          ),
        if (report.materials.isNotEmpty) ...[
          ...style.table(
            'Resultado comercial por canal',
            tradeHeaders,
            report.channels.map(tradeRow).toList(),
            widths: [2.2, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3],
          ),
          ...style.table(
            'Resultado comercial por material · ambas semanas',
            tradeHeaders,
            report.materials.map(tradeRow).toList(),
            widths: [2.2, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3],
          ),
          ...style.table(
            'Precios ponderados por material · MXN/kg',
            [
              'Material',
              'Compra actual',
              'Compra anterior',
              'Venta actual',
              'Venta anterior',
              'Diferencia venta-compra actual',
              'Diferencia venta-compra anterior',
            ],
            [
              for (final r in report.materials)
                [
                  r.label,
                  _price(r.current.purchasePrice),
                  _price(r.previous.purchasePrice),
                  _price(r.current.salePrice),
                  _price(r.previous.salePrice),
                  _spread(r.current),
                  _spread(r.previous),
                ],
            ],
            widths: [2.4, 1.3, 1.3, 1.3, 1.3, 1.7, 1.7],
            closingNote:
                'Precio ponderado = importe / kg por material y flujo. Sin kg de compra o venta no se calcula su precio ni la diferencia entre ambos. Se incluyen también materiales que solo tuvieron movimiento en la semana anterior.',
          ),
        ],
        ...style.table(
          '2. Estado de resultados · comparativo',
          comparisonHeaders,
          [
            compare('Ventas de material', current.revenue, previous.revenue),
            compare(
              'Entradas por otros medios',
              current.otherIncome,
              previous.otherIncome,
            ),
            compare(
              '(-) Compra de material',
              -current.commercialCost,
              -previous.commercialCost,
            ),
            compare(
              'Utilidad bruta',
              current.commercialResult,
              previous.commercialResult,
            ),
            compare(
              '(-) Gastos',
              -current.recognizedExpenses,
              -previous.recognizedExpenses,
            ),
            compare(
              'Utilidad neta',
              current.periodResult,
              previous.periodResult,
            ),
          ],
          widths: [3.5, 1.6, 1.6, 1.6, 1.2],
          closingNote:
              'Misma lectura del Estado de Resultados de Contabilidad: ventas de material + otras entradas - compras de material - gastos, según rubros capturados. Se conservan las exclusiones de movimientos internos y la conciliación Banco-Bóveda por cheque.',
        ),
        ...style.table(
          'Gastos por rubro y fuente · variación semanal',
          [
            'Rubro',
            'Fuente',
            'Semana actual',
            'Semana anterior',
            'Variación',
            'Variación %',
          ],
          breakdown(report.expenses),
          widths: [3, 1.4, 1.5, 1.5, 1.5, 1.1],
          empty: 'Sin gastos reconocidos en ambas semanas.',
        ),
        ...style.table(
          'Entradas por otros medios · variación semanal',
          [
            'Rubro',
            'Fuente',
            'Semana actual',
            'Semana anterior',
            'Variación',
            'Variación %',
          ],
          breakdown(report.otherIncome),
          widths: [3, 1.4, 1.5, 1.5, 1.5, 1.1],
          empty: 'Sin otras entradas reconocidas en ambas semanas.',
        ),
        ...style.table(
          'Notas del corte y trazabilidad',
          ['Detalle'],
          [
            [
              '${report.current.events.length} operaciones comerciales actuales y ${report.previous.events.length} anteriores; se muestran todos los materiales y rubros de ambas semanas.',
            ],
            if (report.ignoredEvents > 0)
              [
                '${report.ignoredEvents} eventos sin fecha o con flujo desconocido se excluyeron del resultado comercial.',
              ],
            for (final note in data.currentStatement.warnings)
              ['Semana actual: $note'],
            for (final note in data.previousStatement.warnings)
              ['Semana anterior: $note'],
            [
              'Los movimientos conservan sus categorías originales. Bóveda incluye los comprobantes actuales y legados reconocidos por el área, sin duplicar comprobantes migrados.',
            ],
            [
              'Los textos extensos se abrevian. Consulta el detalle original en Resultado Comercial o Estado de Resultados de Contabilidad.',
            ],
          ],
          widths: [1],
          cellMax: 500,
        ),
      ],
    ),
  );
  return pdf.save();
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _number(double value) => formatDecimal(value);
String _money(double value) => '\$${_number(value)}';
String _price(double? value) => value == null ? 'Sin base' : _money(value);
String _spread(AccountingTradeTotals row) =>
    row.purchasePrice == null || row.salePrice == null
    ? 'Sin base'
    : _price(row.salePrice! - row.purchasePrice!);
String _percent(double a, double b) {
  final change = accountingChangePercent(a, b);
  return change == null
      ? 'Sin base'
      : '${change > 0 ? "+" : ""}${change.toStringAsFixed(1)}%';
}

String _clean(String value, {int max = 110}) {
  final clean = value.replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF\n]'), ' ');
  return clean.length <= max ? clean : '${clean.substring(0, max - 3)}...';
}

class _AccountingPdfStyle {
  final ink = PdfColor.fromInt(kContabilidadBgTeal.toARGB32());
  final soft = PdfColor.fromInt(contabilidadAreaTokens.primarySoft.toARGB32());
  pw.Widget note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Text(
      _clean(text, max: 1200),
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
    ),
  );
  List<pw.Widget> table(
    String title,
    List<String> headers,
    List<List<String>> rows, {
    required List<double> widths,
    String empty = 'Sin movimientos en ambas semanas.',
    String? closingNote,
    int cellMax = 110,
  }) {
    final data = rows.isEmpty
        ? [List.generate(headers.length, (i) => i == 0 ? empty : '-')]
        : rows;
    return [
      for (var start = 0; start < data.length; start += 8)
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 13),
              pw.Text(
                _clean(start == 0 ? title : '$title · continuación'),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: ink,
                ),
              ),
              pw.SizedBox(height: 7),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data
                    .skip(start)
                    .take(8)
                    .map(
                      (row) => row
                          .map((cell) => _clean(cell, max: cellMax))
                          .toList(),
                    )
                    .toList(),
                columnWidths: {
                  for (var i = 0; i < widths.length; i++)
                    i: pw.FlexColumnWidth(widths[i]),
                },
                headerDecoration: pw.BoxDecoration(color: soft),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: ink,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerAlignment: pw.Alignment.centerLeft,
                cellAlignment: pw.Alignment.topLeft,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
              if (closingNote != null && start + 8 >= data.length)
                note(closingNote),
            ],
          ),
        ),
    ];
  }
}
