import 'dart:io';

const List<String> _kCanonicalGeneralCategories = <String>[
  'CARTON',
  'CHATARRA',
  'METAL',
  'PLASTICO',
  'MADERA',
  'PAPEL',
];

void main(List<String> args) {
  final csvPath = args.isNotEmpty
      ? args.first
      : '/Users/martinvelzat/Downloads/V_Precios_Reporte (1).csv';
  final file = File(csvPath);
  if (!file.existsSync()) {
    stderr.writeln('CSV no encontrado: $csvPath');
    exitCode = 2;
    return;
  }

  final rows = _parseCsv(file.readAsStringSync());
  if (rows.length <= 1) {
    stderr.writeln('CSV sin datos utilizables: $csvPath');
    exitCode = 3;
    return;
  }

  final companies = <String, _CompanyRow>{};
  final materials = <String, _MaterialRow>{};
  final prices = <String, _PriceRow>{};

  for (final category in _kCanonicalGeneralCategories) {
    final generalId = 'ma_general_${category.toLowerCase()}';
    materials[generalId] = _MaterialRow(
      id: generalId,
      code: category,
      level: 'GENERAL',
      name: category,
      unit: 'KG',
      category: category,
      family: null,
      generalMaterialId: null,
      active: true,
      notes: 'GENERAL BASE MAYOREO',
    );
  }

  for (final row in rows.skip(1)) {
    if (row.length < 5) continue;
    final provider = row[0].trim();
    final material = row[1].trim();
    final price = _parsePrice(row[2]);
    final comment = row[3].trim();
    final status = row[4].trim().toUpperCase();

    if (provider.isEmpty || material.isEmpty || price == null) continue;

    final companyId = 'co_seed_${_slug(provider)}';
    final materialId = 'ma_comercial_${_slug(material)}';
    final category = _canonicalMayoreoGeneralCategory(material);
    final generalMaterialId = 'ma_general_${category.toLowerCase()}';
    final priceId = 'pr_${_slug(provider)}_${_slug(material)}';

    companies[companyId] = _CompanyRow(
      id: companyId,
      code: _code(provider),
      name: provider,
      contact: '',
      active: status != 'INACTIVO',
      notes: '',
    );

    materials[materialId] = _MaterialRow(
      id: materialId,
      code: _code(material),
      level: 'COMERCIAL',
      name: material,
      unit: 'KG',
      category: category,
      family: category,
      generalMaterialId: generalMaterialId,
      active: status != 'INACTIVO',
      notes: '',
    );

    prices[priceId] = _PriceRow(
      id: priceId,
      companyId: companyId,
      materialId: materialId,
      amount: price,
      active: status != 'INACTIVO',
      notes: comment,
    );
  }

  final sql = StringBuffer()
    ..writeln('-- Seed real Mayoreo catalog/prices derived from CSV base')
    ..writeln('begin;')
    ..writeln()
    ..writeln(_buildCompaniesUpsert(companies.values.toList()))
    ..writeln()
    ..writeln(_buildMaterialsUpsert(materials.values.toList()))
    ..writeln()
    ..writeln(_buildPricesUpsert(prices.values.toList()))
    ..writeln()
    ..writeln('commit;');

  stdout.write(sql.toString());
}

List<List<String>> _parseCsv(String raw) {
  final normalized = raw.replaceFirst('\uFEFF', '');
  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < normalized.length; i++) {
    final char = normalized[i];
    if (char == '"') {
      final nextIsQuote = i + 1 < normalized.length && normalized[i + 1] == '"';
      if (inQuotes && nextIsQuote) {
        cell.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes && char == ',') {
      row.add(cell.toString());
      cell.clear();
      continue;
    }
    if (!inQuotes && (char == '\n' || char == '\r')) {
      if (char == '\r' &&
          i + 1 < normalized.length &&
          normalized[i + 1] == '\n') {
        i++;
      }
      row.add(cell.toString());
      cell.clear();
      if (row.any((value) => value.isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
      row.clear();
      continue;
    }
    cell.write(char);
  }

  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.any((value) => value.isNotEmpty)) {
      rows.add(List<String>.from(row));
    }
  }

  return rows;
}

double? _parsePrice(String raw) {
  final normalized = raw.replaceAll('\$', '').replaceAll(',', '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String _canonicalMayoreoGeneralCategory(String raw) {
  final merged = _stripAccents(raw).toUpperCase();
  if (merged.contains('CARTON')) return 'CARTON';
  if (merged.contains('CHATARRA') || merged.contains('FIERRO')) {
    return 'CHATARRA';
  }
  if (merged.contains('PLASTICO') || merged.contains('PET')) {
    return 'PLASTICO';
  }
  if (merged.contains('MADERA') || merged.contains('TARIMA')) {
    return 'MADERA';
  }
  if (merged.contains('PAPEL') ||
      merged.contains('ARCHIVO') ||
      merged.contains('PERIODICO') ||
      merged.contains('LIBRO') ||
      merged.contains('ORDINARIO') ||
      merged.contains('REVISTA')) {
    return 'PAPEL';
  }
  return 'METAL';
}

String _stripAccents(String value) {
  return value
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('Ñ', 'N')
      .replaceAll('ñ', 'n');
}

String _slug(String value) {
  final normalized = _stripAccents(value).toLowerCase();
  final buffer = StringBuffer();
  var wroteUnderscore = false;
  for (final codeUnit in normalized.codeUnits) {
    final ch = String.fromCharCode(codeUnit);
    final isAlphaNum =
        (codeUnit >= 97 && codeUnit <= 122) ||
        (codeUnit >= 48 && codeUnit <= 57);
    if (isAlphaNum) {
      buffer.write(ch);
      wroteUnderscore = false;
      continue;
    }
    if (!wroteUnderscore) {
      buffer.write('_');
      wroteUnderscore = true;
    }
  }
  final collapsed = buffer.toString().replaceAll(RegExp(r'_+'), '_');
  return collapsed.replaceAll(RegExp(r'^_|_$'), '');
}

String _code(String value) => _slug(value).toUpperCase();

String _buildCompaniesUpsert(List<_CompanyRow> companies) {
  final values = companies
      .map(
        (row) =>
            "(${[_sqlString(row.id), _sqlString(row.code), _sqlString(row.name), _sqlNullableString(row.contact), _sqlBool(row.active), _sqlNullableString(row.notes)].join(', ')})",
      )
      .join(',\n  ');
  return '''
insert into public.mayoreo_counterparties (
  id,
  code,
  name,
  contact,
  is_active,
  notes
) values
  $values
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  contact = excluded.contact,
  is_active = excluded.is_active,
  notes = excluded.notes;''';
}

String _buildMaterialsUpsert(List<_MaterialRow> materials) {
  final values = materials
      .map(
        (row) =>
            "(${[_sqlString(row.id), _sqlString(row.code), _sqlString(row.level), _sqlString(row.name), _sqlString(row.unit), _sqlString(row.category), _sqlNullableString(row.family), _sqlNullableString(row.generalMaterialId), _sqlBool(row.active), _sqlNullableString(row.notes)].join(', ')})",
      )
      .join(',\n  ');
  return '''
insert into public.mayoreo_material_catalog (
  id,
  code,
  level,
  name,
  unit,
  category,
  family,
  general_material_id,
  is_active,
  notes
) values
  $values
on conflict (id) do update
set
  code = excluded.code,
  level = excluded.level,
  name = excluded.name,
  unit = excluded.unit,
  category = excluded.category,
  family = excluded.family,
  general_material_id = excluded.general_material_id,
  is_active = excluded.is_active,
  notes = excluded.notes;''';
}

String _buildPricesUpsert(List<_PriceRow> prices) {
  final values = prices
      .map(
        (row) =>
            "(${[_sqlString(row.id), _sqlString(row.companyId), _sqlString(row.materialId), _sqlNumber(row.amount), _sqlBool(row.active), _sqlNullableString(row.notes)].join(', ')})",
      )
      .join(',\n  ');
  return '''
insert into public.mayoreo_counterparty_material_prices (
  id,
  company_id,
  material_id,
  final_price,
  is_active,
  notes
) values
  $values
on conflict (id) do update
set
  company_id = excluded.company_id,
  material_id = excluded.material_id,
  final_price = excluded.final_price,
  is_active = excluded.is_active,
  notes = excluded.notes;''';
}

String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

String _sqlNullableString(String? value) {
  if (value == null || value.trim().isEmpty) return 'null';
  return _sqlString(value);
}

String _sqlBool(bool value) => value ? 'true' : 'false';

String _sqlNumber(double value) => value.toStringAsFixed(2);

class _CompanyRow {
  final String id;
  final String code;
  final String name;
  final String contact;
  final bool active;
  final String notes;

  const _CompanyRow({
    required this.id,
    required this.code,
    required this.name,
    required this.contact,
    required this.active,
    required this.notes,
  });
}

class _MaterialRow {
  final String id;
  final String code;
  final String level;
  final String name;
  final String unit;
  final String category;
  final String? family;
  final String? generalMaterialId;
  final bool active;
  final String notes;

  const _MaterialRow({
    required this.id,
    required this.code,
    required this.level,
    required this.name,
    required this.unit,
    required this.category,
    required this.family,
    required this.generalMaterialId,
    required this.active,
    required this.notes,
  });
}

class _PriceRow {
  final String id;
  final String companyId;
  final String materialId;
  final double amount;
  final bool active;
  final String notes;

  const _PriceRow({
    required this.id,
    required this.companyId,
    required this.materialId,
    required this.amount,
    required this.active,
    required this.notes,
  });
}
