import 'dart:convert';
import 'dart:io';

class _ReviewRow {
  const _ReviewRow({
    required this.sourceName,
    required this.countInCsv,
    required this.status,
    required this.matchSource,
    required this.matchName,
    required this.notes,
  });

  final String sourceName;
  final int countInCsv;
  final String status;
  final String matchSource;
  final String matchName;
  final String notes;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/analyze_finanzas_provider_catalog_csv.dart <csv_path>',
    );
    exit(64);
  }

  final csvPath = args.first;
  final csvFile = File(csvPath);
  if (!csvFile.existsSync()) {
    stderr.writeln('CSV not found: $csvPath');
    exit(66);
  }

  final comprasSql = File(
    'apps/dicsa_operacion/supabase/migrations/20260610190000_import_compras_catalog_from_legacy_csv.sql',
  );
  final ventasSql = File(
    'apps/dicsa_operacion/supabase/migrations/20260428194500_seed_mayoreo_catalog_real_prices.sql',
  );

  final comprasNames = _parseComprasNames(comprasSql.readAsStringSync());
  final ventasNames = _parseVentasNames(ventasSql.readAsStringSync());
  final currentNames = <String, String>{
    for (final row in comprasNames) row: 'COMPRAS',
    for (final row in ventasNames) row: 'VENTAS',
  };

  final csvNames = _parseCsvProviderNames(csvFile);
  final counts = <String, int>{};
  for (final name in csvNames) {
    counts.update(name, (value) => value + 1, ifAbsent: () => 1);
  }

  final canonicalCurrent = <String, List<String>>{};
  for (final name in currentNames.keys) {
    canonicalCurrent
        .putIfAbsent(_canonicalize(name), () => <String>[])
        .add(name);
  }

  final reviewRows = <_ReviewRow>[];
  for (final name in counts.keys.toList()..sort()) {
    final count = counts[name] ?? 1;
    if (currentNames.containsKey(name)) {
      reviewRows.add(
        _ReviewRow(
          sourceName: name,
          countInCsv: count,
          status: 'EXACTO_EXISTE',
          matchSource: currentNames[name] ?? '',
          matchName: name,
          notes: 'Ya existe exactamente en el catálogo actual.',
        ),
      );
      continue;
    }

    final canonical = _canonicalize(name);
    final canonicalMatches = canonicalCurrent[canonical] ?? const <String>[];
    if (canonicalMatches.isNotEmpty) {
      final match = canonicalMatches.first;
      reviewRows.add(
        _ReviewRow(
          sourceName: name,
          countInCsv: count,
          status: 'PARECIDO_REVISAR',
          matchSource: currentNames[match] ?? '',
          matchName: match,
          notes:
              'Coincide al normalizar nombre; revisar si es la misma empresa.',
        ),
      );
      continue;
    }

    final fuzzy = _bestFuzzyMatch(name, currentNames.keys);
    if (fuzzy != null) {
      reviewRows.add(
        _ReviewRow(
          sourceName: name,
          countInCsv: count,
          status: 'PARECIDO_REVISAR',
          matchSource: currentNames[fuzzy.$1] ?? '',
          matchName: fuzzy.$1,
          notes:
              'Similitud ${fuzzy.$2.toStringAsFixed(2)}; revisar antes de importar.',
        ),
      );
      continue;
    }

    reviewRows.add(
      _ReviewRow(
        sourceName: name,
        countInCsv: count,
        status: 'NUEVO',
        matchSource: '',
        matchName: '',
        notes: 'No se encontró coincidencia actual en Compras o Ventas.',
      ),
    );
  }

  final outDir = Directory('apps/dicsa_operacion/docs/migrations');
  outDir.createSync(recursive: true);
  final outFile = File('${outDir.path}/finanzas_provider_catalog_review.csv');
  final sink = outFile.openWrite();
  sink.writeln('csv_name,count_in_csv,status,match_source,match_name,notes');
  for (final row in reviewRows) {
    sink.writeln(
      [
        row.sourceName,
        row.countInCsv.toString(),
        row.status,
        row.matchSource,
        row.matchName,
        row.notes,
      ].map(_escapeCsv).join(','),
    );
  }
  sink.close();

  final exact = reviewRows.where((row) => row.status == 'EXACTO_EXISTE').length;
  final similar = reviewRows
      .where((row) => row.status == 'PARECIDO_REVISAR')
      .length;
  final newOnes = reviewRows.where((row) => row.status == 'NUEVO').length;

  stdout.writeln('CSV providers únicos: ${counts.length}');
  stdout.writeln('Exactos ya existentes: $exact');
  stdout.writeln('Parecidos para revisar: $similar');
  stdout.writeln('Nuevos a migrar: $newOnes');
  stdout.writeln('Review generado en: ${outFile.path}');
}

List<String> _parseCsvProviderNames(File csvFile) {
  final raw = csvFile.readAsStringSync();
  final lines = const LineSplitter().convert(raw);
  final values = <String>[];
  for (var i = 1; i < lines.length; i++) {
    final columns = _splitCsvLine(lines[i]);
    if (columns.isEmpty) continue;
    final name = _normalize(columns.first);
    if (name.isNotEmpty) values.add(name);
  }
  return values;
}

List<String> _parseComprasNames(String sql) {
  final pattern = RegExp(
    r"\('cp_import_[^']+',\s*'[^']+',\s*'([^']+)'",
    multiLine: true,
  );
  return {
    for (final match in pattern.allMatches(sql))
      _normalize(match.group(1) ?? ''),
  }.where((row) => row.isNotEmpty).toList();
}

List<String> _parseVentasNames(String sql) {
  final block = sql.split('insert into public.mayoreo_material_catalog').first;
  final pattern = RegExp(r"\('[^']+',\s*'[^']+',\s*'([^']+)'", multiLine: true);
  return {
    for (final match in pattern.allMatches(block))
      _normalize(match.group(1) ?? ''),
  }.where((row) => row.isNotEmpty).toList();
}

String _normalize(String input) =>
    input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

String _canonicalize(String input) {
  var text = _normalize(input);
  text = text
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ñ', 'N');
  text = text.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  text = text.replaceAll('&', ' Y ');
  text = text.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ');
  text = text.replaceAll(
    RegExp(r'\b(SA|DE|CV|S|A|C|V|SRL|RL|THE|EL|LA|LOS|LAS)\b'),
    ' ',
  );
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

(String, double)? _bestFuzzyMatch(String candidate, Iterable<String> existing) {
  final a = _canonicalize(candidate);
  if (a.isEmpty) return null;
  String? bestName;
  var bestScore = 0.0;
  for (final row in existing) {
    final b = _canonicalize(row);
    if (b.isEmpty) continue;
    final score = _diceCoefficient(a, b);
    if (score > bestScore) {
      bestScore = score;
      bestName = row;
    }
  }
  if (bestName == null || bestScore < 0.74) return null;
  return (bestName, bestScore);
}

double _diceCoefficient(String a, String b) {
  if (a == b) return 1;
  if (a.length < 2 || b.length < 2) return 0;
  final aBigrams = <String, int>{};
  for (var i = 0; i < a.length - 1; i++) {
    final chunk = a.substring(i, i + 2);
    aBigrams.update(chunk, (value) => value + 1, ifAbsent: () => 1);
  }
  var overlap = 0;
  for (var i = 0; i < b.length - 1; i++) {
    final chunk = b.substring(i, i + 2);
    final count = aBigrams[chunk] ?? 0;
    if (count > 0) {
      aBigrams[chunk] = count - 1;
      overlap++;
    }
  }
  return (2 * overlap) / ((a.length - 1) + (b.length - 1));
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

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
