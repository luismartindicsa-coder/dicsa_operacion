import 'dart:io';

const List<String> _kCanonicalGeneralCategories = <String>[
  'CARTON',
  'CHATARRA',
  'METAL',
  'PLASTICO',
  'MADERA',
  'PAPEL',
  'VIDRIO',
  'TEXTIL',
  'OTROS',
];

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/transform_mayoreo_catalog_csv.dart <csv> [--sql-out=<archivo>] [--review-out=<archivo>]',
    );
    exitCode = 64;
    return;
  }

  final csvPath = args.first;
  final sqlOut = _readFlag(args, '--sql-out=');
  final reviewOut = _readFlag(args, '--review-out=');

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
  final materialReview = <String, _MaterialReviewRow>{};

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
    if (row.length < 3) continue;
    final provider = row[0].trim();
    final material = row[1].trim();
    final price = _parsePrice(row[2]);
    final comment = row.length > 3 ? row[3].trim() : '';

    if (provider.isEmpty || material.isEmpty || price == null) continue;

    final companyId = 'co_import_${_slug(provider)}';
    final materialId = 'ma_comercial_${_slug(material)}';
    final categoryResult = _categorizeMaterial(material);
    final generalMaterialId =
        'ma_general_${categoryResult.category.toLowerCase()}';
    final priceId = 'pr_${_slug(provider)}_${_slug(material)}';

    companies[companyId] = _CompanyRow(
      id: companyId,
      code: _code(provider),
      name: provider,
      contact: '',
      active: true,
      notes: '',
    );

    materials[materialId] = _MaterialRow(
      id: materialId,
      code: _code(material),
      level: 'COMERCIAL',
      name: material,
      unit: 'KG',
      category: categoryResult.category,
      family: categoryResult.category,
      generalMaterialId: generalMaterialId,
      active: true,
      notes: '',
    );

    prices[priceId] = _PriceRow(
      id: priceId,
      companyId: companyId,
      materialId: materialId,
      amount: price,
      active: true,
      notes: comment,
    );

    materialReview.putIfAbsent(
      material.toUpperCase(),
      () => _MaterialReviewRow(
        material: material,
        inferredCategory: categoryResult.category,
        heuristic: categoryResult.heuristic,
        needsReview: categoryResult.needsReview,
      ),
    );
  }

  final sql = StringBuffer()
    ..writeln('-- Catalogo Mayoreo derivado desde CSV legacy')
    ..writeln('begin;')
    ..writeln()
    ..writeln(_buildCompaniesMerge(companies.values.toList()))
    ..writeln()
    ..writeln(_buildMaterialsMerge(materials.values.toList()))
    ..writeln()
    ..writeln(
      _buildPricesMerge(
        prices.values.toList(),
        companies.values.toList(),
        materials.values.toList(),
      ),
    )
    ..writeln()
    ..writeln('commit;');

  if (sqlOut != null && sqlOut.isNotEmpty) {
    File(sqlOut)
      ..createSync(recursive: true)
      ..writeAsStringSync(sql.toString());
  }

  if (reviewOut != null && reviewOut.isNotEmpty) {
    final sortedReview = materialReview.values.toList(growable: false)
      ..sort(
        (a, b) => a.material.toUpperCase().compareTo(b.material.toUpperCase()),
      );
    final csv = StringBuffer()
      ..writeln('Material,Categoria inferida,Heuristica,Revisar');
    for (final row in sortedReview) {
      csv.writeln(
        [
          _csvCell(row.material),
          _csvCell(row.inferredCategory),
          _csvCell(row.heuristic),
          row.needsReview ? 'SI' : 'NO',
        ].join(','),
      );
    }
    File(reviewOut)
      ..createSync(recursive: true)
      ..writeAsStringSync(csv.toString());
  }

  final reviewCount = materialReview.values
      .where((row) => row.needsReview)
      .length;
  stdout.writeln('CSV: $csvPath');
  stdout.writeln('Empresas: ${companies.length}');
  stdout.writeln(
    'Materiales comerciales: ${materials.values.where((row) => row.level == 'COMERCIAL').length}',
  );
  stdout.writeln('Relaciones precio: ${prices.length}');
  stdout.writeln('Materiales que conviene revisar manualmente: $reviewCount');
  if (sqlOut != null && sqlOut.isNotEmpty) {
    stdout.writeln('SQL generado en: $sqlOut');
  }
  if (reviewOut != null && reviewOut.isNotEmpty) {
    stdout.writeln('Revision de categorias generada en: $reviewOut');
  }

  if (sqlOut == null || sqlOut.isEmpty) {
    stdout.write(sql.toString());
  }
}

String? _readFlag(List<String> args, String prefix) {
  for (final arg in args.skip(1)) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
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
      if (row.any((value) => value.trim().isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
      row.clear();
      continue;
    }
    cell.write(char);
  }

  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.any((value) => value.trim().isNotEmpty)) {
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

_CategoryResult _categorizeMaterial(String raw) {
  final merged = _stripAccents(raw).toUpperCase();

  if (merged.contains('CARTON')) {
    return const _CategoryResult('CARTON', 'CARTON keyword', false);
  }
  if (merged.contains('CHATARRA') || merged.contains('FIERRO')) {
    return const _CategoryResult('CHATARRA', 'CHATARRA/FIERRO keyword', false);
  }
  if (merged.contains('PLASTICO') || merged.contains('PET')) {
    return const _CategoryResult('PLASTICO', 'PLASTICO/PET keyword', false);
  }
  if (merged.contains('MADERA') || merged.contains('TARIMA')) {
    return const _CategoryResult('MADERA', 'MADERA/TARIMA keyword', false);
  }
  if (merged.contains('PAPEL') ||
      merged.contains('ARCHIVO') ||
      merged.contains('PERIODICO') ||
      merged.contains('LIBRO') ||
      merged.contains('ORDINARIO') ||
      merged.contains('REVISTA') ||
      merged.contains('BOND') ||
      merged.contains('CAPLE') ||
      merged.contains('FOLLETO')) {
    return const _CategoryResult('PAPEL', 'PAPEL family keyword', false);
  }
  if (merged.contains('VIDRIO') || merged.contains('CRISTAL')) {
    return const _CategoryResult('VIDRIO', 'VIDRIO/CRISTAL keyword', false);
  }
  if (merged.contains('TEXTIL') ||
      merged.contains('TELA') ||
      merged.contains('TRAPO') ||
      merged.contains('ROPA')) {
    return const _CategoryResult(
      'TEXTIL',
      'TEXTIL/TELA/TRAPO/ROPA keyword',
      false,
    );
  }
  if (merged.contains('OTRO') || merged.contains('OTROS')) {
    return const _CategoryResult('OTROS', 'OTRO/OTROS keyword', false);
  }
  return const _CategoryResult('OTROS', 'fallback default', true);
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

String _buildCompaniesMerge(List<_CompanyRow> companies) {
  final ordered = companies.toList(growable: false)
    ..sort((a, b) => a.name.toUpperCase().compareTo(b.name.toUpperCase()));
  final values = ordered
      .map(
        (row) =>
            "(${[_sqlString(row.id), _sqlString(row.code), _sqlString(row.name), _sqlNullableString(row.contact), _sqlBool(row.active), _sqlNullableString(row.notes)].join(', ')})",
      )
      .join(',\n  ');
  return '''
create temporary table tmp_import_mayoreo_counterparties (
  id text,
  code text,
  name text,
  contact text,
  is_active boolean,
  notes text
) on commit drop;

insert into tmp_import_mayoreo_counterparties (
  id,
  code,
  name,
  contact,
  is_active,
  notes
) values
  $values;

insert into public.mayoreo_counterparties (
  id,
  code,
  name,
  contact,
  is_active,
  notes
)
select
  src.id,
  src.code,
  src.name,
  src.contact,
  src.is_active,
  src.notes
from tmp_import_mayoreo_counterparties src
where not exists (
  select 1
  from public.mayoreo_counterparties dst
  where upper(dst.name) = upper(src.name)
);

update public.mayoreo_counterparties dst
set
  code = src.code,
  contact = src.contact,
  is_active = src.is_active,
  notes = src.notes
from tmp_import_mayoreo_counterparties src
where upper(dst.name) = upper(src.name);''';
}

String _buildMaterialsMerge(List<_MaterialRow> materials) {
  final ordered = materials.toList(growable: false)
    ..sort((a, b) {
      final levelCompare = a.level.compareTo(b.level);
      if (levelCompare != 0) return levelCompare;
      return a.name.toUpperCase().compareTo(b.name.toUpperCase());
    });
  final values = ordered
      .map(
        (row) =>
            "(${[_sqlString(row.id), _sqlString(row.code), _sqlString(row.level), _sqlString(row.name), _sqlString(row.unit), _sqlString(row.category), _sqlNullableString(row.family), _sqlNullableString(row.generalMaterialId), _sqlBool(row.active), _sqlNullableString(row.notes)].join(', ')})",
      )
      .join(',\n  ');
  return '''
create temporary table tmp_import_mayoreo_materials (
  id text,
  code text,
  level text,
  name text,
  unit text,
  category text,
  family text,
  general_material_id text,
  is_active boolean,
  notes text
) on commit drop;

insert into tmp_import_mayoreo_materials (
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
  $values;

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
)
select
  src.id,
  src.code,
  src.level,
  src.name,
  src.unit,
  src.category,
  src.family,
  null,
  src.is_active,
  src.notes
from tmp_import_mayoreo_materials src
where src.level = 'GENERAL'
  and not exists (
    select 1
    from public.mayoreo_material_catalog dst
    where upper(dst.name) = upper(src.name)
      and dst.level = src.level
  );

update public.mayoreo_material_catalog dst
set
  code = src.code,
  unit = src.unit,
  category = src.category,
  family = src.family,
  is_active = src.is_active,
  notes = src.notes
from tmp_import_mayoreo_materials src
where src.level = 'GENERAL'
  and upper(dst.name) = upper(src.name)
  and dst.level = src.level;

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
)
select
  src.id,
  src.code,
  src.level,
  src.name,
  src.unit,
  src.category,
  src.family,
  general_dst.id,
  src.is_active,
  src.notes
from tmp_import_mayoreo_materials src
join tmp_import_mayoreo_materials general_src
  on general_src.id = src.general_material_id
join public.mayoreo_material_catalog general_dst
  on upper(general_dst.name) = upper(general_src.name)
 and general_dst.level = 'GENERAL'
where src.level = 'COMERCIAL'
  and not exists (
    select 1
    from public.mayoreo_material_catalog dst
    where upper(dst.name) = upper(src.name)
      and dst.level = src.level
  );

update public.mayoreo_material_catalog dst
set
  code = src.code,
  unit = src.unit,
  category = src.category,
  family = src.family,
  general_material_id = general_dst.id,
  is_active = src.is_active,
  notes = src.notes
from tmp_import_mayoreo_materials src
join tmp_import_mayoreo_materials general_src
  on general_src.id = src.general_material_id
join public.mayoreo_material_catalog general_dst
  on upper(general_dst.name) = upper(general_src.name)
 and general_dst.level = 'GENERAL'
where src.level = 'COMERCIAL'
  and upper(dst.name) = upper(src.name)
  and dst.level = src.level;''';
}

String _buildPricesMerge(
  List<_PriceRow> prices,
  List<_CompanyRow> companies,
  List<_MaterialRow> materials,
) {
  final ordered = prices.toList(growable: false)
    ..sort((a, b) => a.id.compareTo(b.id));
  final companyNamesById = <String, String>{
    for (final row in companies) row.id: row.name,
  };
  final materialKeysById = <String, (String, String)>{
    for (final row in materials) row.id: (row.name, row.level),
  };
  final resolvedValues = ordered
      .map((row) {
        final companyName = companyNamesById[row.companyId]!;
        final materialMeta = materialKeysById[row.materialId]!;
        return "(${[_sqlString(row.id), _sqlString(companyName), _sqlString(materialMeta.$1), _sqlString(materialMeta.$2), row.amount.toStringAsFixed(4), _sqlBool(row.active), _sqlNullableString(row.notes)].join(', ')})";
      })
      .join(',\n  ');
  return '''
create temporary table tmp_import_mayoreo_prices (
  id text,
  company_name text,
  material_name text,
  material_level text,
  final_price numeric(14,4),
  is_active boolean,
  notes text
) on commit drop;

insert into tmp_import_mayoreo_prices (
  id,
  company_name,
  material_name,
  material_level,
  final_price,
  is_active,
  notes
) values
  $resolvedValues;

insert into public.mayoreo_counterparty_material_prices (
  id,
  company_id,
  material_id,
  final_price,
  is_active,
  notes
)
select
  src.id,
  company.id,
  material.id,
  src.final_price,
  src.is_active,
  src.notes
from tmp_import_mayoreo_prices src
join public.mayoreo_counterparties company
  on upper(company.name) = upper(src.company_name)
join public.mayoreo_material_catalog material
  on upper(material.name) = upper(src.material_name)
 and material.level = src.material_level
on conflict (company_id, material_id) do update
set
  final_price = excluded.final_price,
  is_active = excluded.is_active,
  notes = excluded.notes;''';
}

String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

String _sqlNullableString(String? value) {
  if (value == null || value.trim().isEmpty) return 'null';
  return _sqlString(value.trim());
}

String _sqlBool(bool value) => value ? 'true' : 'false';

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

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

class _CategoryResult {
  final String category;
  final String heuristic;
  final bool needsReview;

  const _CategoryResult(this.category, this.heuristic, this.needsReview);
}

class _MaterialReviewRow {
  final String material;
  final String inferredCategory;
  final String heuristic;
  final bool needsReview;

  const _MaterialReviewRow({
    required this.material,
    required this.inferredCategory,
    required this.heuristic,
    required this.needsReview,
  });
}
