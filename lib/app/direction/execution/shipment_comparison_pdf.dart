import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/utils/number_formatters.dart';
import '../direction_shipments_store.dart';
import '../operating_program/operating_program_models.dart';
import 'shipment_comparison_report.dart';

Future<Uint8List> buildShipmentComparisonPdf(
  ShipmentComparisonReport report, {
  AssetBundle? assetBundle,
}) async {
  final assets = assetBundle ?? rootBundle;
  final logo = pw.MemoryImage(
    (await assets.load('assets/images/logo_dicsa.png')).buffer.asUint8List(),
  );
  var regular = pw.Font.helvetica(), bold = pw.Font.helveticaBold();
  try {
    regular = pw.Font.ttf(await assets.load('assets/fonts/Roboto-Regular.ttf'));
    bold = pw.Font.ttf(await assets.load('assets/fonts/Roboto-Bold.ttf'));
  } on FlutterError {
    /* Compatibility with older installed asset bundles. */
  }
  const ink = PdfColor.fromInt(0xff21312d),
      green = PdfColor.fromInt(0xff365f4c),
      soft = PdfColor.fromInt(0xffeef3ef),
      line = PdfColor.fromInt(0xffcbd6ce),
      red = PdfColor.fromInt(0xffa32e29),
      amber = PdfColor.fromInt(0xff895713);
  pw.Widget text(
    String s, {
    double size = 9,
    bool bold = false,
    PdfColor color = ink,
  }) => pw.Text(
    s,
    style: pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  );
  String quantity(int n) => formatDecimal(n, decimals: 0);
  String totals(int Function(String) getTotal) => [
    for (final unit in ['pacas', 'kg'])
      if (report.units.contains(unit)) '${quantity(getTotal(unit))} $unit',
  ].join('\n');
  pw.Widget card(String title, String amount, String detail) => pw.Expanded(
    child: pw.Container(
      height: 92,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: soft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          text(title, size: 9, bold: true, color: green),
          pw.SizedBox(height: 6),
          text(amount.isEmpty ? '-' : amount, size: 16, bold: true),
          pw.Spacer(),
          text(detail, size: 8),
        ],
      ),
    ),
  );
  List<String> parts(String value, int limit) {
    var chars = value.trim().runes.toList();
    final result = <String>[];
    while (chars.length > limit) {
      var end = limit;
      for (var i = limit; i > limit ~/ 2; i--) {
        if (chars[i] == 32 || chars[i] == 10) {
          end = i;
          break;
        }
      }
      result.add(String.fromCharCodes(chars.take(end)));
      chars = chars.sublist(end);
      while (chars.isNotEmpty && (chars.first == 32 || chars.first == 10)) {
        chars.removeAt(0);
      }
    }
    result.add(String.fromCharCodes(chars));
    return result;
  }

  pw.TableRow tableRow(
    List<String> cells, {
    bool header = false,
    bool shade = false,
    int? delta,
    bool confirmed = false,
  }) => pw.TableRow(
    repeat: header,
    decoration: pw.BoxDecoration(
      color: header
          ? green
          : shade
          ? soft
          : PdfColors.white,
    ),
    children: [
      for (var c = 0; c < cells.length; c++)
        pw.Container(
          alignment: c >= 4 && c <= 6
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: text(
            cells[c],
            bold: header || c == 5,
            color: header
                ? PdfColors.white
                : c == 6 && delta != null && delta < 0
                ? red
                : c == 7
                ? (confirmed ? green : amber)
                : ink,
          ),
        ),
    ],
  );
  final tableRows = <pw.TableRow>[
    tableRow([
      'Día',
      'Cliente / destino',
      'Material',
      'Unidad',
      'Planeado',
      'Real',
      'Diferencia',
      'Estado / observación',
    ], header: true),
  ];
  for (var i = 0; i < report.rows.length; i++) {
    final row = report.rows[i];
    final day = row.source.date;
    final clients = parts(
      row.source.client.isEmpty ? 'Sin destino' : row.source.client,
      200,
    );
    final details = parts(row.detail, 260);
    final length = clients.length > details.length
        ? clients.length
        : details.length;
    for (var n = 0; n < length; n++) {
      tableRows.add(
        tableRow(
          [
            n == 0
                ? '${const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][day.weekday - 1]}\n${programDate(day).substring(5)}'
                : 'Continúa',
            n < clients.length ? clients[n] : '',
            n == 0 ? directionShipmentMaterialLabel(row.source.material) : '',
            n == 0 ? row.unit : '',
            n == 0
                ? (row.planned == null ? 'Sin plan' : quantity(row.planned!))
                : '',
            n == 0 ? (row.actual == null ? '-' : quantity(row.actual!)) : '',
            n == 0
                ? (row.difference == null
                      ? '-'
                      : '${row.difference! > 0 ? '+' : ''}${quantity(row.difference!)}')
                : '',
            n < details.length ? details[n] : '',
          ],
          shade: i.isOdd,
          delta: row.difference,
          confirmed: row.confirmed,
        ),
      );
    }
  }
  final document = pw.Document(
    title: 'Embarques: planeado vs real - ${programDate(report.week)}',
    author: 'DICSA',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      maxPages: tableRows.length + 10,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Row(
          children: [
            pw.Image(logo, width: 43, height: 43),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  text('DICSA / DIRECCIÓN', bold: true, color: green),
                  pw.SizedBox(height: 3),
                  text('Embarques: planeado vs real', size: 23, bold: true),
                  text(
                    '${programDate(report.week)} al ${programDate(report.week.add(const Duration(days: 5)))}',
                  ),
                ],
              ),
            ),
            text('Emitido ${programDate(report.generatedAt)}', size: 8),
          ],
        ),
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: line),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              text(
                'Diferencia = real - planeado. Pacas y kg se reportan por separado.',
                size: 8,
              ),
              text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                size: 8,
              ),
            ],
          ),
        ],
      ),
      build: (_) => [
        pw.Row(
          children: [
            card(
              'PLANEADO',
              totals(report.plannedFor),
              'Referencia original de los grupos',
            ),
            pw.SizedBox(width: 9),
            card(
              'REAL CONFIRMADO',
              totals(report.confirmedFor),
              'Confirmado por Dirección',
            ),
            pw.SizedBox(width: 9),
            card(
              'POR CONFIRMAR',
              '${report.pending}',
              'Grupos con registro precargado',
            ),
            pw.SizedBox(width: 9),
            card(
              'SIN CAPTURA',
              '${report.missing}',
              'Grupos futuros: ${report.future}',
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        text(
          'Planeado conserva la referencia anterior a confirmar. Real usa la confirmación de Dirección; en su ausencia muestra el registro precargado como Por confirmar. Sin captura no equivale a cero.',
          size: 9,
        ),
        pw.SizedBox(height: 5),
        text(
          'Un renglón por día, destino y material. Sin plan identifica un real adicional sin referencia; su diferencia queda pendiente.',
          size: 8,
        ),
        pw.SizedBox(height: 12),
        if (report.rows.isEmpty)
          text(
            'No hay embarques planeados ni realizados para comparar en esta semana.',
          )
        else
          pw.Table(
            children: tableRows,
            border: pw.TableBorder.all(color: line, width: 0.4),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(1.7),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(0.6),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(0.8),
              6: const pw.FlexColumnWidth(0.8),
              7: const pw.FlexColumnWidth(2),
            },
          ),
      ],
    ),
  );
  return document.save();
}
