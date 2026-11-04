import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum LogisticsCatalogKind {
  companies(
    'Empresas',
    'empresas',
    '01',
    'Directorio de empresas y recursos asignados.',
  ),
  zones('Zonas', 'zonas', '02', 'Cobertura geográfica y empresas por zona.'),
  drivers(
    'Choferes',
    'choferes',
    '03',
    'Personal, unidades y empresas asignadas.',
  ),
  vehicles(
    'Unidades',
    'unidades',
    '04',
    'Identificación, características y chofer asignado.',
  ),
  containers(
    'Contenedores',
    'contenedores',
    '05',
    'Inventario, ubicación y características físicas.',
  );

  final String label;
  final String fileKey;
  final String number;
  final String description;
  const LogisticsCatalogKind(
    this.label,
    this.fileKey,
    this.number,
    this.description,
  );
}

class LogisticsCatalogPdfField {
  final String label;
  final String value;
  const LogisticsCatalogPdfField(this.label, this.value);
}

class LogisticsCatalogPdfRecord {
  final String id;
  final String title;
  final String status;
  final List<LogisticsCatalogPdfField> fields;
  final List<LogisticsCatalogPdfField> references;
  const LogisticsCatalogPdfRecord({
    required this.id,
    required this.title,
    this.status = '',
    required this.fields,
    this.references = const [],
  });
}

class LogisticsCatalogPdfSection {
  final LogisticsCatalogKind kind;
  final List<LogisticsCatalogPdfRecord> records;
  final List<LogisticsCatalogPdfField> metrics;
  final int totalCount;
  final String search;
  const LogisticsCatalogPdfSection({
    required this.kind,
    required this.records,
    this.metrics = const [],
    required this.totalCount,
    this.search = '',
  });
}

// Natural order lets the printed directory read A1, A2, ... A10, A11.
int compareLogisticsCatalogLabels(String a, String b) {
  String fold(String value) {
    const from = 'ÁÉÍÓÚÜÑáéíóúüñ';
    const to = 'AEIOUUNaeiouun';
    for (var i = 0; i < from.length; i++) {
      value = value.replaceAll(from[i], to[i]);
    }
    return value.toUpperCase().trim();
  }

  final left = RegExp(
    r'\d+|\D+',
  ).allMatches(fold(a)).map((m) => m[0]!).toList();
  final right = RegExp(
    r'\d+|\D+',
  ).allMatches(fold(b)).map((m) => m[0]!).toList();
  for (var i = 0; i < math.min(left.length, right.length); i++) {
    final l = int.tryParse(left[i]);
    final r = int.tryParse(right[i]);
    final result = l != null && r != null
        ? l.compareTo(r)
        : left[i].compareTo(right[i]);
    if (result != 0) return result;
  }
  final result = left.length.compareTo(right.length);
  return result != 0 ? result : a.compareTo(b);
}

String logisticsCatalogPdfFileName(
  List<LogisticsCatalogPdfSection> sections,
  DateTime generatedAt,
) {
  final kind = sections.length == 1
      ? sections.single.kind.fileKey
      : 'completos';
  final date =
      '${generatedAt.year}${_two(generatedAt.month)}${_two(generatedAt.day)}';
  return 'catalogos_operativos_${kind}_$date.pdf';
}

const _ink = PdfColor.fromInt(0xFF202831);
const _muted = PdfColor.fromInt(0xFF56616B);
const _line = PdfColor.fromInt(0xFFBCC4CA);
const _paper = PdfColor.fromInt(0xFFF2F4F5);
const _margin = pw.EdgeInsets.fromLTRB(54, 30, 36, 30);
const _bodyStyle = pw.TextStyle(fontSize: 10.5, color: _ink, lineSpacing: 2);

Future<Uint8List> buildLogisticsCatalogPdf({
  required List<LogisticsCatalogPdfSection> sections,
  required DateTime generatedAt,
}) async {
  if (sections.isEmpty) throw ArgumentError('Selecciona un catálogo.');
  if (sections.map((s) => s.kind).toSet().length != sections.length) {
    throw ArgumentError('Un catálogo no puede aparecer dos veces.');
  }
  for (final section in sections) {
    if (section.records.map((r) => r.id).toSet().length !=
            section.records.length ||
        section.totalCount < section.records.length) {
      throw ArgumentError(
        'Identificación o conteo inválido en ${section.kind.label}.',
      );
    }
  }
  final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final logoData = await rootBundle.load('assets/images/logo_dicsa.png');
  final logo = pw.MemoryImage(
    logoData.buffer.asUint8List(logoData.offsetInBytes, logoData.lengthInBytes),
  );
  final sorted = [
    for (final section in sections)
      LogisticsCatalogPdfSection(
        kind: section.kind,
        records: [...section.records]
          ..sort((a, b) => compareLogisticsCatalogLabels(a.title, b.title)),
        metrics: section.metrics,
        totalCount: section.totalCount,
        search: section.search,
      ),
  ];
  // The first pass records painted destinations, including continuations. The
  // second prints exact page numbers without changing index column geometry.
  Map<String, int> pageNumbers = {};
  Uint8List? result;
  for (var pass = 0; pass < 2; pass++) {
    final collected = <String, int>{};
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final document = pw.Document(
      title:
          'DICSA | Catálogos operativos | ${sorted.length == 1 ? sorted.single.kind.label : 'General'}',
      author: 'DICSA',
      creator: 'DICSA - Logística',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final measure = regular.getFont(pw.Context(document: document.document));
    final stamp =
        '${_two(generatedAt.day)}/${_two(generatedAt.month)}/${generatedAt.year}';
    final edition =
        '$stamp · ${_two(generatedAt.hour)}:${_two(generatedAt.minute)}';
    pw.Widget destination(String key, pw.Widget child) => _PageReference(
      name: key,
      pages: collected,
      child: pw.Anchor(name: key, child: child),
    );
    pw.Widget footer(pw.Context context, String label) => pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: .5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'DICSA · $label · $stamp',
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _ink),
          ),
        ],
      ),
    );
    pw.Widget header(String label, String part) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      margin: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: .7)),
      ),
      child: pw.Row(
        children: [
          pw.Image(logo, width: 30, height: 30),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DICSA / CATÁLOGOS OPERATIVOS',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  label,
                  style: const pw.TextStyle(fontSize: 11, color: _ink),
                ),
              ],
            ),
          ),
          pw.Text(part, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    );
    void addPages(String label, String part, List<pw.Widget> content) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: _margin,
          maxPages: math.max(100, content.length * 2 + 10),
          header: (_) => header(label, part),
          footer: (context) => footer(context, label),
          build: (_) => content,
        ),
      );
    }

    pw.Widget indexEntry(String label, String key, {String? detail}) => pw.Link(
      destination: key,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    label,
                    style: const pw.TextStyle(fontSize: 10.5, color: _ink),
                  ),
                  if (detail != null)
                    pw.Text(
                      detail,
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 32,
              child: pw.Text(
                '${pageNumbers[key] ?? 0}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (sorted.length > 1) {
      addPages('Archivo general', 'CONTENIDO', [
        pw.SizedBox(height: 22),
        pw.Text(
          'Catálogos\noperativos',
          style: pw.TextStyle(
            fontSize: 32,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Directorio de consulta · Logística',
          style: const pw.TextStyle(fontSize: 15, color: _muted),
        ),
        pw.SizedBox(height: 26),
        pw.Text('Edición: $edition', style: _bodyStyle),
        pw.SizedBox(height: 8),
        pw.Text(
          'Información registrada al momento de la emisión.',
          style: _bodyStyle,
        ),
        pw.SizedBox(height: 32),
        _heading('Contenido'),
        for (final section in sorted)
          indexEntry(
            '${section.kind.number}  ${section.kind.label}',
            'section-${section.kind.fileKey}',
            detail: '${section.records.length} registros',
          ),
        pw.SizedBox(height: 24),
        _guide(),
      ]);
    }
    for (final section in sorted) {
      final kind = section.kind;
      final prefix = kind.fileKey;
      final label = '${kind.number} / ${kind.label}';
      final references = section.records
          .where((r) => r.references.isNotEmpty)
          .toList();
      final directoryRows = <pw.TableRow>[];
      final half = (section.records.length / 2).ceil();
      for (var i = 0; i < half; i++) {
        final left = section.records[i];
        final right = i + half < section.records.length
            ? section.records[i + half]
            : null;
        directoryRows.add(
          pw.TableRow(
            children: [
              indexEntry(left.title, '$prefix-${left.id}'),
              pw.SizedBox(width: 24),
              right == null
                  ? pw.SizedBox()
                  : indexEntry(right.title, '$prefix-${right.id}'),
            ],
          ),
        );
      }
      addPages(label, 'ÍNDICE', [
        destination(
          'section-$prefix',
          pw.Outline(
            name: 'outline-$prefix',
            title: kind.label,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  kind.label,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Text(kind.description, style: _bodyStyle),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Edición: $edition',
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 12),
        _metrics([
          LogisticsCatalogPdfField(
            'Registros incluidos',
            '${section.records.length}',
          ),
          ...section.metrics.take(3),
        ]),
        pw.SizedBox(height: 12),
        pw.Text(
          section.search.trim().isEmpty
              ? 'Alcance: catálogo completo (${section.totalCount} registros).'
              : 'Selección: "${section.search.trim()}" · ${section.records.length} de ${section.totalCount} registros.',
          style: _bodyStyle,
        ),
        pw.SizedBox(height: 16),
        _heading('Localizador de fichas'),
        if (directoryRows.isEmpty)
          pw.Text('Sin registros para esta selección.', style: _bodyStyle)
        else
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FixedColumnWidth(24),
              2: pw.FlexColumnWidth(1),
            },
            children: directoryRows,
          ),
        if (references.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          indexEntry(
            'Referencias de captura',
            'references-$prefix',
            detail: 'Texto original y antecedentes de registro',
          ),
        ],
        pw.SizedBox(height: 18),
        _guide(),
      ]);
      final cards = <pw.Widget>[];
      for (final record in section.records) {
        final parts = _fieldParts(record.fields, measure);
        for (var i = 0; i < parts.length; i++) {
          var card = _card(
            record,
            parts[i],
            continuation: i > 0,
            referencePage: record.references.isEmpty
                ? null
                : pageNumbers['ref-$prefix-${record.id}'],
          );
          if (i == 0) card = destination('$prefix-${record.id}', card);
          cards.add(card);
        }
      }
      if (cards.isNotEmpty) addPages(label, 'FICHAS', cards);
      if (references.isNotEmpty) {
        final content = <pw.Widget>[
          destination('references-$prefix', _heading('Referencias de captura')),
          pw.Text(
            'Antecedentes conservados para consulta. Las asignaciones vigentes se presentan en las fichas.',
            style: _bodyStyle,
          ),
          pw.SizedBox(height: 16),
        ];
        for (final record in references) {
          final parts = _fieldParts(
            record.references,
            measure,
            reference: true,
          );
          for (var i = 0; i < parts.length; i++) {
            var card = _card(
              record,
              parts[i],
              continuation: i > 0,
              isReference: true,
            );
            if (i == 0) card = destination('ref-$prefix-${record.id}', card);
            content.add(card);
          }
        }
        addPages(label, 'REFERENCIAS', content);
      }
    }
    result = await document.save();
    if (pass == 1 &&
        (collected.length != pageNumbers.length ||
            collected.entries.any((e) => pageNumbers[e.key] != e.value))) {
      throw StateError('El índice cambió durante la paginación.');
    }
    pageNumbers = collected;
  }
  return result!;
}

pw.Widget _heading(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  ),
);

pw.Widget _guide() => pw.Container(
  padding: const pw.EdgeInsets.all(12),
  decoration: const pw.BoxDecoration(color: _paper),
  child: pw.Text(
    'Consulta por nombre o código en orden alfabético y numérico. '
    'Los números del índice corresponden a las páginas de esta edición. '
    '"No registrado" indica un dato pendiente; "Sin asignación" indica que no existe una relación registrada.',
    style: const pw.TextStyle(fontSize: 9.5, color: _muted, lineSpacing: 2),
  ),
);

pw.Widget _metrics(List<LogisticsCatalogPdfField> metrics) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    for (final metric in metrics)
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: _line, width: 1)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                metric.value,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                metric.label,
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ),
      ),
  ],
);

pw.Widget _card(
  LogisticsCatalogPdfRecord record,
  List<LogisticsCatalogPdfField> fields, {
  bool continuation = false,
  bool isReference = false,
  int? referencePage,
}) {
  if (isReference) {
    return pw.Inseparable(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: .5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${record.title}${continuation ? ' / Continuación' : ''}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 6),
            for (final field in fields) ...[
              pw.Text(
                field.label,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: _muted,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(field.value, style: _bodyStyle),
              pw.SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }
  return pw.Inseparable(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: .6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  record.title,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              if (!isReference && record.status.isNotEmpty) ...[
                pw.SizedBox(width: 10),
                pw.Text(
                  record.status,
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ],
          ),
          if (continuation)
            pw.Text(
              'Continuación',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          pw.SizedBox(height: 9),
          for (final field in fields)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 112,
                    child: pw.Text(
                      field.label,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        color: _muted,
                        fontWeight: pw.FontWeight.bold,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Text(field.value, style: _bodyStyle)),
                ],
              ),
            ),
          if (record.references.isNotEmpty &&
              !isReference &&
              !continuation) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Antecedentes y texto original: página ${referencePage ?? 0}.',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ],
      ),
    ),
  );
}

// Break only oversized content, at line boundaries. Normal records stay whole.
// A bounded part fits a fresh letter page even for unbroken strings and notes.
List<List<LogisticsCatalogPdfField>> _fieldParts(
  List<LogisticsCatalogPdfField> fields,
  PdfFont font, {
  bool reference = false,
}) {
  final parts = <List<LogisticsCatalogPdfField>>[];
  var current = <LogisticsCatalogPdfField>[];
  var height = 0.0;
  for (final field in fields) {
    final lines = _wrap(
      field.value.trim().isEmpty ? 'No registrado' : field.value,
      font,
      reference ? 508 : 368,
      10.5,
    );
    for (var start = 0; start < lines.length; start += 5) {
      final text = lines
          .sublist(start, math.min(start + 5, lines.length))
          .join('\n');
      final label = '${field.label}${start == 0 ? '' : ' (cont.)'}';
      final labelLines = _wrap(label, font, 106, 9.5).length;
      final nextHeight =
          math.max(
            math.min(5, lines.length - start) * 15.0,
            labelLines * 14.0,
          ) +
          (reference ? 25 : 5);
      if (height + nextHeight > 350 && current.isNotEmpty) {
        parts.add(current);
        current = [];
        height = 0;
      }
      current.add(LogisticsCatalogPdfField(label, text));
      height += nextHeight;
    }
  }
  if (current.isNotEmpty || parts.isEmpty) parts.add(current);
  return parts;
}

List<String> _wrap(String input, PdfFont font, double width, double size) {
  final lines = <String>[];
  for (final paragraph in input.replaceAll('\r', '').split('\n')) {
    var line = '';
    for (final word
        in paragraph.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      final candidate = line.isEmpty ? word : '$line $word';
      if (font.stringMetrics(candidate).width * size <= width) {
        line = candidate;
        continue;
      }
      if (line.isNotEmpty) {
        lines.add(line);
        line = '';
      }
      for (final rune in word.runes) {
        final next = '$line${String.fromCharCode(rune)}';
        if (line.isNotEmpty && font.stringMetrics(next).width * size > width) {
          lines.add(line);
          line = String.fromCharCode(rune);
        } else {
          line = next;
        }
      }
    }
    lines.add(line);
  }
  return lines.isEmpty ? [''] : lines;
}

class _PageReference extends pw.SingleChildWidget {
  final String name;
  final Map<String, int> pages;
  _PageReference({
    required this.name,
    required this.pages,
    required pw.Widget child,
  }) : super(child: child);
  @override
  void paint(pw.Context context) {
    pages.putIfAbsent(name, () => context.pageNumber);
    super.paint(context);
    paintChild(context);
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
