import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../shared/utils/number_formatters.dart';

const double menudeoTicketWidthMm = 78;
const double menudeoTicketHeightMm = 133;

Future<Uint8List> buildMenudeoTicketPdf({
  required Map<String, dynamic> row,
  required double humidity,
  required double trash,
  required double premium,
  required String exitOrderNumber,
  required bool isSale,
  int copies = 1,
  DateTime? printedAt,
}) async {
  if (copies < 1) throw ArgumentError.value(copies, 'copies');
  final doc = pw.Document();
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {}

  final bruto = ((row['gross'] as num?) ?? 0).toDouble();
  final tara = ((row['tare'] as num?) ?? 0).toDouble();
  final neto = bruto - tara;
  final precio = ((row['price'] as num?) ?? 0).toDouble();
  final peso = (neto * (1 - (humidity / 100))) - trash;
  final importe = peso * (precio + premium);
  final printTime = printedAt ?? DateTime.now();
  final printedTime =
      '${printTime.hour.toString().padLeft(2, '0')}:${printTime.minute.toString().padLeft(2, '0')}';
  final ticketPageFormat = PdfPageFormat(
    menudeoTicketWidthMm * PdfPageFormat.mm,
    menudeoTicketHeightMm * PdfPageFormat.mm,
    marginLeft: 2.5 * PdfPageFormat.mm,
    marginRight: 2.5 * PdfPageFormat.mm,
    marginTop: 3 * PdfPageFormat.mm,
    marginBottom: 3.5 * PdfPageFormat.mm,
  );

  pw.Page buildTicketPage() {
    return pw.Page(
      pageFormat: ticketPageFormat,
      margin: const pw.EdgeInsets.fromLTRB(4, 5, 4, 6),
      build: (context) {
        pw.Widget divider({double spacing = 5}) {
          return pw.Padding(
            padding: pw.EdgeInsets.symmetric(vertical: spacing),
            child: pw.Container(
              width: double.infinity,
              height: 1,
              color: PdfColors.grey500,
            ),
          );
        }

        pw.Widget buildPairRow(
          String leftLabel,
          String leftValue,
          String rightLabel,
          String rightValue,
        ) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 28,
                        child: pw.Text(
                          leftLabel,
                          style: pw.TextStyle(
                            fontSize: 8.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                        child: pw.Text(
                          leftValue.isEmpty ? ' ' : leftValue,
                          style: const pw.TextStyle(fontSize: 8.6),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 24,
                        child: pw.Text(
                          rightLabel,
                          style: pw.TextStyle(
                            fontSize: 8.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                        child: pw.Text(
                          rightValue.isEmpty ? ' ' : rightValue,
                          style: const pw.TextStyle(fontSize: 8.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        pw.Widget buildRow(String label, String value) {
          final emphasized = label == 'Importe';
          final labelWidth = emphasized
              ? 40.0
              : label.length >= 10
              ? 54.0
              : label.length >= 8
              ? 48.0
              : 36.0;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: labelWidth,
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: emphasized ? 9.6 : 8.4,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: emphasized ? 6 : 5),
                if (emphasized)
                  pw.Expanded(
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        value.isEmpty ? ' ' : value,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 15.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  pw.Expanded(
                    child: pw.Text(
                      value.isEmpty ? ' ' : value,
                      style: pw.TextStyle(
                        fontSize: 8.6,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: PdfColors.grey600, width: 1),
          ),
          padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 9),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Spacer(),
                  if (logoImage != null)
                    pw.SizedBox(
                      width: 38,
                      height: 18,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  if (logoImage != null) pw.SizedBox(width: 4),
                  pw.Text(
                    'DICSA',
                    style: pw.TextStyle(
                      fontSize: 12.8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Spacer(),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Desperdicios Industriales Celaya SA de CV',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 7.7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'Calle Bernal #7 Col. Rancho Seco Celaya, Gto.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.0),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Tel: 461-616-7310 ext. 102',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.0),
                ),
              ),
              divider(spacing: 5),
              pw.Center(
                child: pw.Text(
                  isSale ? 'COMPROBANTE DE VENTA' : 'COMPROBANTE DE COMPRA',
                  style: pw.TextStyle(
                    fontSize: 8.9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              divider(spacing: 5),
              buildPairRow(
                'Fecha',
                (row['date'] ?? '').toString(),
                'Hora',
                printedTime,
              ),
              buildRow('Ticket', (row['ticket'] ?? '').toString()),
              buildRow(
                isSale ? 'Cliente' : 'Proveedor',
                (row['provider'] ?? '').toString(),
              ),
              if (isSale && exitOrderNumber.trim().isNotEmpty)
                buildRow('Orden salida', exitOrderNumber.trim()),
              buildRow('Material', (row['material'] ?? '').toString()),
              divider(spacing: 4),
              buildPairRow(
                'Bruto',
                '${bruto.toStringAsFixed(2)} kg',
                'Tara',
                '${tara.toStringAsFixed(2)} kg',
              ),
              buildPairRow(
                'Neto',
                '${neto.toStringAsFixed(2)} kg',
                'Peso',
                '${peso.toStringAsFixed(2)} kg',
              ),
              divider(spacing: 4),
              buildPairRow(
                'Hum.',
                '${humidity.toStringAsFixed(2)} %',
                'Bas.',
                '${trash.toStringAsFixed(2)} kg',
              ),
              buildPairRow(
                'Precio',
                '${formatMoney(precio)} /kg',
                'Sobre',
                '${formatMoney(premium)} /kg',
              ),
              divider(spacing: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.fromLTRB(7, 7, 7, 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey500, width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: buildRow('Importe', formatMoney(importe)),
              ),
              pw.Spacer(),
              pw.Row(
                children: [
                  pw.Text(
                    'Firma:',
                    style: pw.TextStyle(
                      fontSize: 9.8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Container(
                      height: 10,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  '¡GRACIAS!',
                  style: pw.TextStyle(
                    fontSize: 9.4,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Windows sends one page per print job; desktop previews retain both copies.
  for (var copy = 0; copy < copies; copy++) {
    doc.addPage(buildTicketPage());
  }
  return doc.save();
}
