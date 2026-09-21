import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../direction/direction_theme.dart';
import 'accounting_weekly_analysis.dart';
import 'direction_weekly_source.dart';
import 'direction_weekly_summary.dart';
import 'management_reports_registry.dart';

Future<Uint8List> buildDirectionWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
  List<DirectionAreaSummary>? summaries,
}) async {
  final loaded = summaries ?? await loadDirectionWeeklySource(generatedAt);
  final byArea = {for (final row in loaded) row.area: row};
  final rows = [
    for (final key in DirectionSummaryArea.values)
      byArea[key] ?? DirectionAreaSummary.unavailable(key),
  ];
  if (!rows.any(
    (r) => r.available && r.area != DirectionSummaryArea.supervision,
  )) {
    throw StateError(
      'No fue posible consultar las áreas de la app. Revisa la conexión y los permisos antes de generar Dirección General.',
    );
  }
  final cut = AccountingWeeklyCut(generatedAt);
  final available = rows.where((r) => r.available).length;
  final incomplete = available < rows.length;
  final style = _DirectionPdfStyle();
  final pdf = pw.Document(
    title: 'Dirección General · Resumen de todas las áreas',
    author: generatedBy,
  );
  final period = '${_date(cut.current.start)} al ${_date(cut.current.end)}';
  final prior = '${_date(cut.previous.start)} al ${_date(cut.previous.end)}';
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 100,
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DICSA · Dirección General · $period',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          width: double.infinity,
          decoration: pw.BoxDecoration(
            color: style.soft,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DICSA · SUPERVISIÓN DE VIERNES',
                style: pw.TextStyle(fontSize: 9, color: style.ink),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                area.title,
                style: pw.TextStyle(
                  fontSize: 25,
                  fontWeight: pw.FontWeight.bold,
                  color: style.ink,
                ),
              ),
              pw.Text(
                'Resumen ejecutivo de todas las áreas de la app',
                style: const pw.TextStyle(fontSize: 13),
              ),
              pw.SizedBox(height: 9),
              pw.Text(
                'Semana: $period\nComparativo: $prior',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${cut.partial ? 'CORTE PARCIAL' : 'CORTE LUNES A VIERNES'} · $available de ${rows.length} bloques consultados',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: style.ink,
                ),
              ),
              if (incomplete)
                pw.Text(
                  'CONSOLIDADO INCOMPLETO · Hay áreas no disponibles.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.red800,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 6),
              pw.Text(
                _clean(
                  'Generado: ${generatedAt.toIso8601String()} · $generatedBy',
                  180,
                ),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        style.note(
          'Los indicadores semanales cubren los días señalados. Saldos, existencias, expedientes y estados son los actuales al consultar. RH conserva su periodo de nómina; Gerencia conserva el horizonte de su plan.',
        ),
        style.heading('Panorama de áreas y módulos'),
        style.table(
          ['Área / módulo', 'Indicador principal', 'Consulta / alertas'],
          [
            for (final row in rows)
              [
                row.area.title,
                row.metrics.isEmpty
                    ? 'Sin información disponible'
                    : '${row.metrics.first.label}: ${row.metrics.first.current}',
                !row.available
                    ? 'NO DISPONIBLE'
                    : row.alerts.isEmpty
                    ? 'Consultada'
                    : '${row.alerts.length} aviso(s)',
              ],
          ],
          small: true,
        ),
        style.note(
          'Importes en MXN. No sumar importes entre áreas: una operación puede aparecer en Báscula, Compras/Ventas, Bancos y Contabilidad. El resultado consolidado se encuentra en Contabilidad. "—" significa que no se presenta comparación histórica.',
        ),
        pw.NewPage(),
        for (var index = 0; index < rows.length; index++)
          style.area(rows[index], index + 1),
      ],
    ),
  );
  return pdf.save();
}

class _DirectionPdfStyle {
  final ink = PdfColor.fromInt(kDirectionOliveDeep.toARGB32());
  final soft = PdfColor.fromInt(kDirectionIvory.toARGB32());
  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
    child: pw.Text(
      _clean(text),
      style: pw.TextStyle(
        fontSize: 12,
        color: ink,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
  pw.Widget note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Text(
      _clean(text, 700),
      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
    ),
  );
  pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    bool small = false,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows.map((r) => r.map((s) => _clean(s, 160)).toList()).toList(),
    border: null,
    headerDecoration: pw.BoxDecoration(color: ink),
    headerStyle: pw.TextStyle(
      fontSize: small ? 8 : 9,
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
    ),
    cellStyle: pw.TextStyle(fontSize: small ? 8 : 9),
    cellPadding: pw.EdgeInsets.symmetric(
      horizontal: 6,
      vertical: small ? 5 : 4,
    ),
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    columnWidths: const {
      0: pw.FlexColumnWidth(2.5),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(1.5),
    },
    cellAlignments: const {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerLeft,
    },
  );
  pw.Widget area(DirectionAreaSummary row, int index) => pw.Inseparable(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        heading('${index.toString().padLeft(2, '0')} · ${row.area.title}'),
        pw.Text(
          _clean('${row.basis} · Responsable: ${row.area.owner}', 240),
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 6),
        if (row.available && row.metrics.isNotEmpty)
          table(
            ['Indicador', 'Semana / actual', 'Semana anterior'],
            [
              for (final metric in row.metrics)
                [metric.label, metric.current, metric.previous],
            ],
          )
        else
          pw.Text(
            'NO DISPONIBLE · Información pendiente de consulta.',
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.red800,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        if (row.alerts.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          for (final alert in row.alerts.take(2))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                _clean('Atención: $alert', 260),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800),
              ),
            ),
          if (row.alerts.length > 2)
            pw.Text(
              '${row.alerts.length - 2} aviso(s) adicional(es); revisar el reporte o módulo del área.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
        for (final text in row.notes.take(2)) note(text),
        if (row.notes.length > 2)
          note(
            'Hay ${row.notes.length - 2} notas de cobertura adicionales en el reporte del área.',
          ),
        pw.Text(
          _clean('Base: ${row.area.source}'),
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300, height: 1),
      ],
    ),
  );
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _clean(String value, [int max = 200]) {
  final text = value
      .replaceAll('·', ' / ')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF\n]'), ' ')
      .trim();
  return text.length <= max ? text : '${text.substring(0, max - 3)}...';
}
