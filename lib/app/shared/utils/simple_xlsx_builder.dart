import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

Uint8List buildSimpleXlsx({
  required String sheetName,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final archive = Archive();
  final sheetXml = _buildSheetXml(headers: headers, rows: rows);
  final workbookXml = _buildWorkbookXml(sheetName);

  archive.addFile(
    ArchiveFile(
      '[Content_Types].xml',
      0,
      utf8.encode(_contentTypesXml).toList(),
    ),
  );
  archive.addFile(
    ArchiveFile('_rels/.rels', 0, utf8.encode(_rootRelsXml).toList()),
  );
  archive.addFile(
    ArchiveFile('xl/workbook.xml', 0, utf8.encode(workbookXml).toList()),
  );
  archive.addFile(
    ArchiveFile(
      'xl/_rels/workbook.xml.rels',
      0,
      utf8.encode(_workbookRelsXml).toList(),
    ),
  );
  archive.addFile(
    ArchiveFile('xl/styles.xml', 0, utf8.encode(_stylesXml).toList()),
  );
  archive.addFile(
    ArchiveFile('xl/worksheets/sheet1.xml', 0, utf8.encode(sheetXml).toList()),
  );
  archive.addFile(
    ArchiveFile('docProps/core.xml', 0, utf8.encode(_coreXml).toList()),
  );
  archive.addFile(
    ArchiveFile(
      'docProps/app.xml',
      0,
      utf8.encode(_appXml(sheetName)).toList(),
    ),
  );

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _buildWorkbookXml(String sheetName) {
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${_escapeXml(sheetName)}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
''';
}

String _buildSheetXml({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final allRows = <List<String>>[headers, ...rows];
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..writeln(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    )
    ..writeln(
      '  <dimension ref="A1:${_columnName(headers.length)}${allRows.length}"/>',
    )
    ..writeln('  <sheetViews><sheetView workbookViewId="0"/></sheetViews>')
    ..writeln('  <sheetFormatPr defaultRowHeight="15"/>')
    ..writeln('  <sheetData>');

  for (var rowIndex = 0; rowIndex < allRows.length; rowIndex++) {
    final rowNumber = rowIndex + 1;
    final row = allRows[rowIndex];
    buffer.writeln('    <row r="$rowNumber">');
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final cellRef = '${_columnName(columnIndex + 1)}$rowNumber';
      final value = _escapeXml(row[columnIndex]);
      buffer.writeln(
        '      <c r="$cellRef" t="inlineStr"><is><t>$value</t></is></c>',
      );
    }
    buffer.writeln('    </row>');
  }

  buffer
    ..writeln('  </sheetData>')
    ..writeln('</worksheet>');
  return buffer.toString();
}

String _columnName(int index) {
  var value = index;
  final result = StringBuffer();
  while (value > 0) {
    final remainder = (value - 1) % 26;
    result.writeCharCode(65 + remainder);
    value = (value - 1) ~/ 26;
  }
  return result.toString().split('').reversed.join();
}

String _escapeXml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

const String _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';

const String _rootRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

const String _workbookRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
''';

const String _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1">
    <font>
      <sz val="11"/>
      <name val="Calibri"/>
    </font>
  </fonts>
  <fills count="2">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>
''';

const String _coreXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:creator>DICSA</dc:creator>
  <cp:lastModifiedBy>DICSA</cp:lastModifiedBy>
</cp:coreProperties>
''';

String _appXml(String sheetName) {
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>DICSA</Application>
  <HeadingPairs>
    <vt:vector size="2" baseType="variant">
      <vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>
      <vt:variant><vt:i4>1</vt:i4></vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size="1" baseType="lpstr">
      <vt:lpstr>${_escapeXml(sheetName)}</vt:lpstr>
    </vt:vector>
  </TitlesOfParts>
</Properties>
''';
}
