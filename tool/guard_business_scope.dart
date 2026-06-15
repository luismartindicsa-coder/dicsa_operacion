import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(64);
  }

  final allow = <String>{};
  final paths = <String>[];

  for (var i = 0; i < args.length; i += 1) {
    final arg = args[i];
    if (arg == '--allow') {
      if (i + 1 >= args.length) {
        stderr.writeln('Falta valor para --allow');
        exit(64);
      }
      allow.addAll(
        args[i + 1]
            .split(',')
            .map((token) => token.trim().toLowerCase())
            .where((token) => token.isNotEmpty),
      );
      i += 1;
      continue;
    }
    paths.add(arg);
  }

  if (allow.isEmpty) {
    stderr.writeln('Debes indicar al menos un scope con --allow');
    exit(64);
  }
  if (paths.isEmpty) {
    stderr.writeln('Debes indicar al menos un archivo SQL para revisar');
    exit(64);
  }

  final domainPrefixes = <String, List<String>>{
    'compras': const <String>['compras_'],
    'finanzas': const <String>['finanzas_'],
    'mayoreo': const <String>['mayoreo_'],
    'menudeo': const <String>['menudeo_', 'men_'],
  };

  final forbiddenPrefixes = <String, String>{};
  for (final entry in domainPrefixes.entries) {
    if (allow.contains(entry.key)) continue;
    for (final prefix in entry.value) {
      forbiddenPrefixes[prefix] = entry.key;
    }
  }

  final findings = <String>[];

  for (final rawPath in paths) {
    final file = File(rawPath);
    if (!file.existsSync()) {
      findings.add('Archivo no encontrado: $rawPath');
      continue;
    }

    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final original = lines[index];
      final line = original.toLowerCase();
      for (final entry in forbiddenPrefixes.entries) {
        if (line.contains(entry.key)) {
          findings.add(
            '${file.path}:${index + 1}: referencia prohibida a '
            '"${entry.key}" (${entry.value})',
          );
        }
      }
    }
  }

  if (findings.isNotEmpty) {
    stderr.writeln('Scope guard fallo. Se encontraron referencias prohibidas:');
    for (final finding in findings) {
      stderr.writeln(' - $finding');
    }
    exit(2);
  }

  stdout.writeln(
    'Scope guard OK para [${allow.toList()..sort()}] en ${paths.length} archivo(s).',
  );
}

void _printUsage() {
  stdout.writeln(
    'Uso: dart run tool/guard_business_scope.dart '
    '--allow compras,finanzas <archivo.sql> [mas.sql...]',
  );
}
