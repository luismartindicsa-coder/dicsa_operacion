import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_finanzas_provider_import_sql.dart <review_csv> <output_sql>',
    );
    exit(64);
  }

  final reviewFile = File(args[0]);
  if (!reviewFile.existsSync()) {
    stderr.writeln('Review CSV not found: ${reviewFile.path}');
    exit(66);
  }

  final outputFile = File(args[1]);
  outputFile.parent.createSync(recursive: true);

  final rows = _parseCsv(reviewFile.readAsStringSync());
  if (rows.isEmpty) {
    stderr.writeln('Review CSV is empty.');
    exit(65);
  }

  final header = rows.first;
  final nameIndex = header.indexOf('csv_name');
  final statusIndex = header.indexOf('status');
  if (nameIndex == -1 || statusIndex == -1) {
    stderr.writeln('Review CSV missing required columns.');
    exit(65);
  }

  final newNames = <String>{};
  for (final row in rows.skip(1)) {
    if (row.length <= statusIndex || row.length <= nameIndex) continue;
    if (row[statusIndex].trim().toUpperCase() != 'NUEVO') continue;
    final name = _normalize(row[nameIndex]);
    if (name.isNotEmpty) newNames.add(name);
  }

  final sortedNames = newNames.toList(growable: false)..sort();
  final buffer = StringBuffer()
    ..writeln('begin;')
    ..writeln()
    ..writeln('create temporary table tmp_import_finanzas_companies (')
    ..writeln('  id text,')
    ..writeln('  name text,')
    ..writeln('  source text,')
    ..writeln('  linked_name text,')
    ..writeln('  is_active boolean,')
    ..writeln('  notes text')
    ..writeln(') on commit drop;')
    ..writeln()
    ..writeln('insert into tmp_import_finanzas_companies (')
    ..writeln('  id,')
    ..writeln('  name,')
    ..writeln('  source,')
    ..writeln('  linked_name,')
    ..writeln('  is_active,')
    ..writeln('  notes')
    ..writeln(') values');

  for (var i = 0; i < sortedNames.length; i++) {
    final name = sortedNames[i];
    final id = _financeImportId(name);
    final ending = i == sortedNames.length - 1 ? ';' : ',';
    buffer.writeln(
      "  ('${_sql(id)}', '${_sql(name)}', 'DIRECTO', null, true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10')$ending",
    );
  }

  buffer
    ..writeln()
    ..writeln('insert into public.finanzas_catalog_companies (')
    ..writeln('  id,')
    ..writeln('  name,')
    ..writeln('  source,')
    ..writeln('  linked_name,')
    ..writeln('  is_active,')
    ..writeln('  notes')
    ..writeln(')')
    ..writeln('select')
    ..writeln('  src.id,')
    ..writeln('  src.name,')
    ..writeln('  src.source,')
    ..writeln('  src.linked_name,')
    ..writeln('  src.is_active,')
    ..writeln('  src.notes')
    ..writeln('from tmp_import_finanzas_companies src')
    ..writeln('where not exists (')
    ..writeln('  select 1')
    ..writeln('  from public.finanzas_catalog_companies dst')
    ..writeln('  where upper(dst.name) = upper(src.name)')
    ..writeln(');')
    ..writeln()
    ..writeln('commit;')
    ..writeln();

  outputFile.writeAsStringSync(buffer.toString());
  stdout.writeln('Providers to import: ${sortedNames.length}');
  stdout.writeln('SQL generated at: ${outputFile.path}');
}

List<List<String>> _parseCsv(String content) {
  final rows = <List<String>>[];
  for (final line in const LineSplitter().convert(content)) {
    rows.add(_splitCsvLine(line));
  }
  return rows;
}

List<String> _splitCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char == ',' && !inQuotes) {
      result.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  result.add(buffer.toString());
  return result;
}

String _normalize(String input) =>
    input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

String _financeImportId(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return 'fc_import_$slug';
}

String _sql(String value) => value.replaceAll("'", "''");
