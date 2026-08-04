import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final config = _parseArgs(args);
  final baselineDir = Directory(config['baseline']!);
  final currentDir = Directory(config['current']!);
  final outDir = Directory(config['out']!);

  if (!baselineDir.existsSync()) {
    stderr.writeln('No existe baseline: ${baselineDir.path}');
    exitCode = 2;
    return;
  }
  if (!currentDir.existsSync()) {
    stderr.writeln('No existe current: ${currentDir.path}');
    exitCode = 2;
    return;
  }

  final upsertsDir = Directory('${outDir.path}/upserts')
    ..createSync(recursive: true);
  final deletesDir = Directory('${outDir.path}/deletes')
    ..createSync(recursive: true);
  final summary = <String, dynamic>{
    'generatedAt': DateTime.now().toIso8601String(),
    'tables': <Map<String, dynamic>>[],
  };

  final baselineFiles = {
    for (final entity in baselineDir.listSync().whereType<File>())
      entity.uri.pathSegments.last: entity,
  };
  final currentFiles =
      currentDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final currentFile in currentFiles) {
    final fileName = currentFile.uri.pathSegments.last;
    final tableName = fileName.replaceFirst(RegExp(r'\.json$'), '');
    final baselineFile = baselineFiles[fileName];
    final baselineRows = baselineFile == null
        ? const <Map<String, dynamic>>[]
        : _readRows(baselineFile);
    final currentRows = _readRows(currentFile);

    final diff = _diffRows(
      tableName: tableName,
      baselineRows: baselineRows,
      currentRows: currentRows,
    );

    final upsertFile = File('${upsertsDir.path}/$fileName');
    upsertFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(diff.upserts),
    );

    final deleteFile = File('${deletesDir.path}/$fileName');
    deleteFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(diff.deleteIds),
    );

    (summary['tables'] as List<Map<String, dynamic>>).add(<String, dynamic>{
      'table': tableName,
      'baselineCount': baselineRows.length,
      'currentCount': currentRows.length,
      'upsertCount': diff.upserts.length,
      'deleteCount': diff.deleteIds.length,
      'keyField': diff.keyField,
    });
  }

  final summaryFile = File('${outDir.path}/summary.json');
  summaryFile
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));

  stdout.writeln('Diff generado en ${outDir.path}');
}

Map<String, String> _parseArgs(List<String> args) {
  final config = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    if (i + 1 >= args.length) {
      stderr.writeln('Falta valor para $arg');
      exit(2);
    }
    config[arg.substring(2)] = args[i + 1];
    i += 1;
  }

  for (final key in const ['baseline', 'current', 'out']) {
    if ((config[key] ?? '').trim().isEmpty) {
      stderr.writeln(
        'Uso: dart run tool/diff_supabase_snapshot.dart '
        '--baseline <dir> --current <dir> --out <dir>',
      );
      exit(2);
    }
  }
  return config;
}

List<Map<String, dynamic>> _readRows(File file) {
  final raw = file.readAsStringSync().trim();
  if (raw.isEmpty) return const <Map<String, dynamic>>[];
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw FormatException('Se esperaba una lista JSON en ${file.path}');
  }
  return decoded
      .whereType<Map>()
      .map(
        (row) => _sortMapKeys(
          Map<String, dynamic>.from(row.cast<String, dynamic>()),
        ),
      )
      .toList(growable: false);
}

_SnapshotDiff _diffRows({
  required String tableName,
  required List<Map<String, dynamic>> baselineRows,
  required List<Map<String, dynamic>> currentRows,
}) {
  final keyField = _resolveKeyField(baselineRows, currentRows);
  if (keyField == null) {
    return _SnapshotDiff(
      keyField: 'full-row',
      upserts: currentRows,
      deleteIds: const <String>[],
    );
  }

  final baselineById = <String, Map<String, dynamic>>{
    for (final row in baselineRows)
      _normalizeKey(row[keyField], tableName: tableName, keyField: keyField):
          row,
  };
  final currentById = <String, Map<String, dynamic>>{
    for (final row in currentRows)
      _normalizeKey(row[keyField], tableName: tableName, keyField: keyField):
          row,
  };

  final upserts = <Map<String, dynamic>>[];
  for (final entry in currentById.entries) {
    final baselineRow = baselineById[entry.key];
    if (baselineRow == null || !_jsonDeepEquals(baselineRow, entry.value)) {
      upserts.add(entry.value);
    }
  }

  final deleteIds =
      baselineById.keys
          .where((id) => !currentById.containsKey(id))
          .toList(growable: false)
        ..sort();

  return _SnapshotDiff(
    keyField: keyField,
    upserts: upserts,
    deleteIds: deleteIds,
  );
}

String? _resolveKeyField(
  List<Map<String, dynamic>> baselineRows,
  List<Map<String, dynamic>> currentRows,
) {
  const candidates = <String>['id'];
  final combined = <Map<String, dynamic>>[...baselineRows, ...currentRows];
  if (combined.isEmpty) return 'id';

  for (final candidate in candidates) {
    final values = <String>{};
    var valid = true;
    for (final row in combined) {
      final raw = row[candidate];
      if (raw == null || raw.toString().trim().isEmpty) {
        valid = false;
        break;
      }
      final normalized = raw.toString().trim();
      if (!values.add(normalized)) {
        valid = false;
        break;
      }
    }
    if (valid) return candidate;
  }
  return null;
}

String _normalizeKey(
  Object? value, {
  required String tableName,
  required String keyField,
}) {
  final normalized = value?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    throw StateError('Fila sin $keyField en $tableName');
  }
  return normalized;
}

Map<String, dynamic> _sortMapKeys(Map<String, dynamic> input) {
  final sortedEntries = input.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return <String, dynamic>{
    for (final entry in sortedEntries)
      entry.key: switch (entry.value) {
        Map value => _sortMapKeys(
          Map<String, dynamic>.from(value.cast<String, dynamic>()),
        ),
        List value => value.map(_normalizeValue).toList(growable: false),
        _ => entry.value,
      },
  };
}

Object? _normalizeValue(Object? value) {
  if (value is Map) {
    return _sortMapKeys(
      Map<String, dynamic>.from(value.cast<String, dynamic>()),
    );
  }
  if (value is List) {
    return value.map(_normalizeValue).toList(growable: false);
  }
  return value;
}

bool _jsonDeepEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  return jsonEncode(a) == jsonEncode(b);
}

class _SnapshotDiff {
  const _SnapshotDiff({
    required this.keyField,
    required this.upserts,
    required this.deleteIds,
  });

  final String keyField;
  final List<Map<String, dynamic>> upserts;
  final List<String> deleteIds;
}
