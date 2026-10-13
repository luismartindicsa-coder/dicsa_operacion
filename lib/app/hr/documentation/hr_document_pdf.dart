import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'hr_document.dart';

Future<Uint8List> buildHrDocumentPdf(HrDocument record) async {
  if (record.kind != 'generated') {
    throw StateError('Solo los documentos capturados generan PDF.');
  }
  final errors = record.validation(forPdf: true);
  if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final ink = PdfColor.fromHex('#24143D');
  final accent = PdfColor.fromHex('#6E47A8');
  final document = pw.Document(
    title: record.title,
    author: record.values['empresa'] ?? 'Recursos Humanos',
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 38, 44, 38),
      maxPages: 200,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        margin: const pw.EdgeInsets.only(bottom: 18),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: accent, width: 0.7)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'RECURSOS HUMANOS',
              style: pw.TextStyle(fontSize: 9, color: accent, font: bold),
            ),
            pw.Text(record.folio, style: pw.TextStyle(fontSize: 8, color: ink)),
          ],
        ),
      ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${hrDocumentDisplayDate(record.date)} · Versión ${record.revision == 0 ? 1 : record.revision}',
              style: pw.TextStyle(fontSize: 8, color: accent),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: accent),
            ),
          ],
        ),
      ),
      build: (_) => [
        pw.Text(
          record.title,
          style: pw.TextStyle(font: bold, fontSize: 19, color: ink),
        ),
        pw.SizedBox(height: 22),
        // Bounded text blocks let even long, unbroken notes flow across pages.
        for (final paragraph in hrDocumentPdfParagraphs(record.renderedBody()))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 9),
            child: pw.Text(
              paragraph,
              style: pw.TextStyle(fontSize: 10.5, lineSpacing: 3, color: ink),
            ),
          ),
        if (record.signatures.isNotEmpty) pw.SizedBox(height: 24),
        for (var i = 0; i < record.signatures.length; i += 2)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 30, bottom: 16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (
                  var j = i;
                  j < i + 2 && j < record.signatures.length;
                  j++
                ) ...[
                  if (j > i) pw.SizedBox(width: 28),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.SizedBox(height: 24),
                        pw.Divider(color: ink, thickness: .5),
                        if ((record.signatures[j]['name'] ?? '').isNotEmpty)
                          pw.Text(
                            record.signatures[j]['name']!,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: bold, fontSize: 10),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          record.signatures[j]['label'] ?? '',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );
  return document.save();
}

Iterable<String> hrDocumentPdfParagraphs(String body) sync* {
  for (final paragraph in body.split(RegExp(r'\n\s*\n'))) {
    final lines = paragraph.trim().split('\n');
    for (var i = 0; i < lines.length; i += 15) {
      var text = lines.skip(i).take(15).join('\n');
      while (text.length > 1400) {
        var end = text.lastIndexOf(' ', 1400);
        if (end < 700) end = 1400;
        yield text.substring(0, end);
        text = text.substring(end).trimLeft();
      }
      if (text.isNotEmpty) yield text;
    }
  }
}
