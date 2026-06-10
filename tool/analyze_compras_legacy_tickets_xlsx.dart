import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

const String _kDefaultXlsxPath =
    '/Users/martinvelzat/Downloads/Tickets compras con material dicsa.xlsx';
const String _kDefaultCatalogSqlPath =
    'docs/migrations/compras_catalog_import_from_csv.sql';
const String _kDefaultReviewCsvPath =
    'docs/migrations/compras_legacy_tickets_review.csv';
const String _kDefaultImportSqlPath =
    'docs/migrations/compras_legacy_tickets_import.sql';

final RegExp _kCounterpartyRowPattern = RegExp(
  r"\('([^']*)', '([^']*)', '([^']*)', (?:null|'[^']*'), (?:true|false), (?:null|'[^']*')\)",
);
final RegExp _kMaterialRowPattern = RegExp(
  r"\('([^']*)', '([^']*)', '(GENERAL|COMERCIAL)', '([^']*)', '([^']*)', '([^']*)', (?:null|'[^']*'), (?:null|'[^']*'), (?:true|false), (?:null|'[^']*')\)",
);
final RegExp _kPriceRowPattern = RegExp(
  r"\('([^']*)', '([^']*)', '([^']*)', '(GENERAL|COMERCIAL)', ([0-9.]+), (?:true|false), (?:null|'((?:[^']|'{2})*)')\)",
);

void main(List<String> args) {
  final String xlsxPath = args.isNotEmpty ? args.first : _kDefaultXlsxPath;
  final String catalogSqlPath = args.length > 1
      ? args[1]
      : _kDefaultCatalogSqlPath;
  final String reviewCsvPath = args.length > 2
      ? args[2]
      : _kDefaultReviewCsvPath;
  final String importSqlPath = args.length > 3
      ? args[3]
      : _kDefaultImportSqlPath;

  final File xlsxFile = File(xlsxPath);
  final File catalogSqlFile = File(catalogSqlPath);

  if (!xlsxFile.existsSync()) {
    stderr.writeln('No existe el archivo Excel: $xlsxPath');
    exitCode = 2;
    return;
  }
  if (!catalogSqlFile.existsSync()) {
    stderr.writeln('No existe el SQL de catalogo: $catalogSqlPath');
    exitCode = 2;
    return;
  }

  final _ComprasCatalogCatalog catalog = _ComprasCatalogCatalog.fromSql(
    catalogSqlFile.readAsStringSync(),
  );
  final _Workbook workbook = _Workbook.fromXlsxBytes(
    xlsxFile.readAsBytesSync(),
  );

  final List<_TicketReviewRow> reviewRows = <_TicketReviewRow>[];
  int importable = 0;
  int blocked = 0;
  int review = 0;

  final List<_SheetRow> rows = workbook.rows;
  if (rows.length <= 1) {
    stderr.writeln('El Excel no trae filas de datos.');
    exitCode = 2;
    return;
  }

  final _MaterialInferenceIndex inferenceIndex = _MaterialInferenceIndex.build(
    rows.skip(1),
    workbook.headerColumns,
  );

  for (final _SheetRow row in rows.skip(1)) {
    final _TicketReviewRow reviewRow = _buildReviewRow(
      sourceRow: row,
      catalog: catalog,
      inferenceIndex: inferenceIndex,
      headerColumns: workbook.headerColumns,
    );
    reviewRows.add(reviewRow);
    switch (reviewRow.importStatus) {
      case 'IMPORTABLE':
        importable += 1;
      case 'BLOCKED':
        blocked += 1;
      default:
        review += 1;
    }
  }

  final File reviewCsvFile = File(reviewCsvPath);
  reviewCsvFile.createSync(recursive: true);
  reviewCsvFile.writeAsStringSync(_reviewRowsToCsv(reviewRows));
  final File importSqlFile = File(importSqlPath);
  importSqlFile.createSync(recursive: true);
  importSqlFile.writeAsStringSync(_reviewRowsToSql(reviewRows));

  final Set<String> missingProviders = reviewRows
      .where((row) => row.providerStatus != 'EXACT')
      .map((row) => row.provider)
      .where((value) => value.isNotEmpty)
      .toSet();
  final Set<String> missingMaterials = reviewRows
      .where((row) => !_isResolvedMaterialStatus(row.materialStatus))
      .map(
        (row) =>
            row.mappedMaterial.isNotEmpty ? row.mappedMaterial : row.material,
      )
      .where((value) => value.isNotEmpty)
      .toSet();

  stdout.writeln('Analisis completado.');
  stdout.writeln('Archivo: $xlsxPath');
  stdout.writeln('Filas revisadas: ${reviewRows.length}');
  stdout.writeln('Importables: $importable');
  stdout.writeln('Bloqueadas: $blocked');
  stdout.writeln('Para revisar: $review');
  stdout.writeln('Proveedores faltantes: ${missingProviders.length}');
  stdout.writeln('Materiales faltantes: ${missingMaterials.length}');
  stdout.writeln('Review CSV: ${reviewCsvFile.path}');
  stdout.writeln('Import SQL: ${importSqlFile.path}');
}

_TicketReviewRow _buildReviewRow({
  required _SheetRow sourceRow,
  required _ComprasCatalogCatalog catalog,
  required _MaterialInferenceIndex inferenceIndex,
  required Map<String, String> headerColumns,
}) {
  final String providerRaw = sourceRow
      .byHeader(headerColumns, 'Proveedor')
      .trim();
  final String materialRaw = sourceRow
      .byHeader(headerColumns, 'Material')
      .trim();
  final String materialDicsaRaw = sourceRow
      .byHeader(headerColumns, 'MaterialDicsa')
      .trim();
  final String estadoRaw = sourceRow.byHeader(headerColumns, 'Estado').trim();
  final String facturadoRaw = sourceRow
      .byHeader(headerColumns, 'Facturado')
      .trim();
  final String referenciaRaw = sourceRow
      .byHeader(headerColumns, 'Referencia')
      .trim();
  final String comentarioRaw = sourceRow
      .byHeader(headerColumns, 'Comentario')
      .trim();

  final String provider = _normalizeName(providerRaw);
  final String material = _normalizeName(materialRaw);
  final String materialDicsa = _normalizeName(materialDicsaRaw);
  final String providerStatus = provider.isEmpty
      ? 'BLANK'
      : (catalog.providers.contains(provider) ? 'EXACT' : 'MISSING');
  final _MaterialInference inference = inferenceIndex.resolve(
    provider: provider,
    material: material,
    materialDicsa: materialDicsa,
    price: sourceRow.numberByHeader(headerColumns, 'Precio'),
  );
  final String aliasedMaterial = _materialAlias(inference.material);
  final String materialStatus;
  if (aliasedMaterial.isEmpty) {
    materialStatus = 'BLANK';
  } else if (inference.strategy == 'AUTO_INFERRED_PRICE') {
    materialStatus = 'AUTO_INFERRED_PRICE';
  } else if (inference.strategy == 'AUTO_INFERRED_DICSA') {
    materialStatus = 'AUTO_INFERRED_DICSA';
  } else if (material.isEmpty && inference.strategy == 'AUTO_ALIAS') {
    materialStatus = 'AUTO_ALIAS';
  } else if (catalog.materials.contains(aliasedMaterial)) {
    materialStatus = 'EXACT';
  } else if (aliasedMaterial != material &&
      catalog.materials.contains(aliasedMaterial)) {
    materialStatus = 'AUTO_ALIAS';
  } else {
    materialStatus = 'MISSING';
  }

  final double grossWeight = sourceRow.numberByHeader(headerColumns, 'Bruto');
  final double tareWeight = sourceRow.numberByHeader(headerColumns, 'Tara');
  final double netWeight = sourceRow.numberByHeader(headerColumns, 'Neto');
  final double humidityValue = sourceRow.numberByHeader(
    headerColumns,
    'Humedad',
  );
  final double trashValue = sourceRow.numberByHeader(headerColumns, 'Basura');
  final double payableWeight = sourceRow.numberByHeader(headerColumns, 'Peso');
  final double price = sourceRow.numberByHeader(headerColumns, 'Precio');
  final double premium = sourceRow.numberByHeader(headerColumns, 'Sobreprecio');
  final double amount = sourceRow.numberByHeader(headerColumns, 'Importe');
  final double deductionKg = humidityValue + trashValue;
  final double humidityPercent = netWeight > 0
      ? (humidityValue / netWeight) * 100
      : 0;
  final double trashPercent = netWeight > 0
      ? (trashValue / netWeight) * 100
      : 0;
  final double recomputedPayable = netWeight - deductionKg;
  final double recomputedAmount = payableWeight * (price + premium);
  final double? catalogPrice =
      providerStatus == 'EXACT' && _isResolvedMaterialStatus(materialStatus)
      ? catalog.priceFor(provider, aliasedMaterial)
      : null;
  final String priceStatus;
  if (catalogPrice == null) {
    priceStatus = 'NO_CATALOG_PRICE';
  } else if ((catalogPrice - price).abs() <= 0.0001) {
    priceStatus = 'MATCH';
  } else {
    priceStatus = 'DIFFERS';
  }

  final List<String> blockingReasons = <String>[];
  if (providerStatus != 'EXACT') {
    blockingReasons.add('PROVEEDOR_$providerStatus');
  }
  if (!_isResolvedMaterialStatus(materialStatus)) {
    blockingReasons.add('MATERIAL_$materialStatus');
  }
  if ((recomputedPayable - payableWeight).abs() > 0.5) {
    blockingReasons.add('PESO_INCONSISTENTE');
  }
  if ((recomputedAmount - amount).abs() > 1.0) {
    blockingReasons.add('IMPORTE_INCONSISTENTE');
  }

  final String importStatus;
  if (blockingReasons.isNotEmpty) {
    importStatus = 'BLOCKED';
  } else if (priceStatus == 'DIFFERS') {
    importStatus = 'REVIEW';
  } else {
    importStatus = 'IMPORTABLE';
  }

  final String targetFacturaStatus = facturadoRaw.toUpperCase() == 'FACTURADO'
      ? 'FACTURADO'
      : 'PENDIENTE_DE_FACTURAR';

  return _TicketReviewRow(
    rowNumber: sourceRow.rowNumber,
    dateIso: _excelDateToIso(sourceRow.byHeader(headerColumns, 'Fecha')),
    ticket: sourceRow.byHeader(headerColumns, 'Ticket').trim(),
    provider: provider,
    material: material,
    materialDicsa: materialDicsa,
    mappedMaterial: aliasedMaterial,
    inferredBy: inference.strategy,
    providerStatus: providerStatus,
    materialStatus: materialStatus,
    grossWeight: grossWeight,
    tareWeight: tareWeight,
    netWeight: netWeight,
    humidityKg: humidityValue,
    trashKg: trashValue,
    humidityPercent: humidityPercent,
    trashPercent: trashPercent,
    payableWeight: payableWeight,
    recomputedPayableWeight: recomputedPayable,
    price: price,
    catalogPrice: catalogPrice,
    premium: premium,
    amount: amount,
    recomputedAmount: recomputedAmount,
    estadoRaw: estadoRaw,
    facturadoRaw: facturadoRaw,
    targetFacturaStatus: targetFacturaStatus,
    targetPagoStatus: 'PENDIENTE_DE_PAGO',
    targetCoverageStatus: 'SIN_CUBRIR',
    referenciaRaw: referenciaRaw,
    comentarioRaw: comentarioRaw,
    priceStatus: priceStatus,
    importStatus: importStatus,
    blockingReason: blockingReasons.join('|'),
  );
}

String _reviewRowsToCsv(List<_TicketReviewRow> rows) {
  final List<List<String>> table = <List<String>>[
    <String>[
      'row_number',
      'date',
      'ticket',
      'provider',
      'provider_status',
      'material',
      'material_dicsa',
      'mapped_material',
      'inferred_by',
      'material_status',
      'gross_weight',
      'tare_weight',
      'net_weight',
      'humidity_kg',
      'trash_kg',
      'humidity_percent',
      'trash_percent',
      'payable_weight',
      'recomputed_payable_weight',
      'price',
      'catalog_price',
      'price_status',
      'premium',
      'amount',
      'recomputed_amount',
      'estado_raw',
      'facturado_raw',
      'target_factura_status',
      'target_pago_status',
      'target_coverage_status',
      'referencia',
      'comentario',
      'import_status',
      'blocking_reason',
    ],
  ];

  for (final _TicketReviewRow row in rows) {
    table.add(<String>[
      row.rowNumber.toString(),
      row.dateIso,
      row.ticket,
      row.provider,
      row.providerStatus,
      row.material,
      row.materialDicsa,
      row.mappedMaterial,
      row.inferredBy,
      row.materialStatus,
      _fmt(row.grossWeight),
      _fmt(row.tareWeight),
      _fmt(row.netWeight),
      _fmt(row.humidityKg),
      _fmt(row.trashKg),
      _fmt(row.humidityPercent),
      _fmt(row.trashPercent),
      _fmt(row.payableWeight),
      _fmt(row.recomputedPayableWeight),
      _fmt(row.price),
      row.catalogPrice == null ? '' : _fmt(row.catalogPrice!),
      row.priceStatus,
      _fmt(row.premium),
      _fmt(row.amount),
      _fmt(row.recomputedAmount),
      row.estadoRaw,
      row.facturadoRaw,
      row.targetFacturaStatus,
      row.targetPagoStatus,
      row.targetCoverageStatus,
      row.referenciaRaw,
      row.comentarioRaw,
      row.importStatus,
      row.blockingReason,
    ]);
  }

  return table.map(_csvLine).join('\n');
}

String _reviewRowsToSql(List<_TicketReviewRow> rows) {
  final List<_TicketReviewRow> migratableRows = rows
      .where((row) => row.importStatus != 'BLOCKED')
      .toList();

  final StringBuffer buffer = StringBuffer()
    ..writeln('-- Tickets legacy de Compras Mayoreo derivados desde Excel')
    ..writeln('-- Solo incluye filas con proveedor/material resoluble.')
    ..writeln('begin;')
    ..writeln()
    ..writeln('create temporary table tmp_import_compras_tickets_legacy (')
    ..writeln('  id text,')
    ..writeln('  ticket_date timestamptz,')
    ..writeln('  ticket_number text,')
    ..writeln('  provider_name text,')
    ..writeln('  material_name text,')
    ..writeln('  gross_weight numeric(14,3),')
    ..writeln('  tare_weight numeric(14,3),')
    ..writeln('  net_weight numeric(14,3),')
    ..writeln('  humidity_percent numeric(8,3),')
    ..writeln('  trash_percent numeric(8,3),')
    ..writeln('  payable_weight numeric(14,3),')
    ..writeln('  price numeric(14,4),')
    ..writeln('  premium numeric(14,4),')
    ..writeln('  amount numeric(14,2),')
    ..writeln('  factura_status text,')
    ..writeln('  pago_status text,')
    ..writeln('  coverage_status text,')
    ..writeln('  legacy_referencia text,')
    ..writeln('  legacy_comentario text')
    ..writeln(') on commit drop;')
    ..writeln()
    ..writeln('insert into tmp_import_compras_tickets_legacy (')
    ..writeln('  id,')
    ..writeln('  ticket_date,')
    ..writeln('  ticket_number,')
    ..writeln('  provider_name,')
    ..writeln('  material_name,')
    ..writeln('  gross_weight,')
    ..writeln('  tare_weight,')
    ..writeln('  net_weight,')
    ..writeln('  humidity_percent,')
    ..writeln('  trash_percent,')
    ..writeln('  payable_weight,')
    ..writeln('  price,')
    ..writeln('  premium,')
    ..writeln('  amount,')
    ..writeln('  factura_status,')
    ..writeln('  pago_status,')
    ..writeln('  coverage_status,')
    ..writeln('  legacy_referencia,')
    ..writeln('  legacy_comentario')
    ..writeln(') values');

  for (int index = 0; index < migratableRows.length; index += 1) {
    final _TicketReviewRow row = migratableRows[index];
    buffer.write('  (');
    buffer.write(_sqlString('ct_legacy_row_${row.rowNumber}'));
    buffer.write(', ');
    buffer.write(_sqlString('${row.dateIso}T00:00:00Z'));
    buffer.write(', ');
    buffer.write(_sqlString(row.ticket));
    buffer.write(', ');
    buffer.write(_sqlString(row.provider));
    buffer.write(', ');
    buffer.write(_sqlString(row.mappedMaterial));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.grossWeight, 3));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.tareWeight, 3));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.netWeight, 3));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.humidityPercent, 3));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.trashPercent, 3));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.payableWeight, 3));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.price, 4));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.premium, 4));
    buffer.write(', ');
    buffer.write(_sqlNumber(row.amount, 2));
    buffer.write(', ');
    buffer.write(_sqlString(row.targetFacturaStatus));
    buffer.write(', ');
    buffer.write(_sqlString(row.targetPagoStatus));
    buffer.write(', ');
    buffer.write(_sqlString(row.targetCoverageStatus));
    buffer.write(', ');
    buffer.write(_sqlNullableString(row.referenciaRaw));
    buffer.write(', ');
    buffer.write(_sqlNullableString(row.comentarioRaw));
    buffer.write(index == migratableRows.length - 1 ? ');\n\n' : '),\n');
  }

  buffer
    ..writeln('insert into public.compras_tickets (')
    ..writeln('  id,')
    ..writeln('  ticket_date,')
    ..writeln('  ticket_number,')
    ..writeln('  provider_id,')
    ..writeln('  provider_name_snapshot,')
    ..writeln('  material_id,')
    ..writeln('  material_name_snapshot,')
    ..writeln('  gross_weight,')
    ..writeln('  tare_weight,')
    ..writeln('  net_weight,')
    ..writeln('  humidity_percent,')
    ..writeln('  trash_percent,')
    ..writeln('  payable_weight,')
    ..writeln('  price,')
    ..writeln('  premium,')
    ..writeln('  amount,')
    ..writeln('  factura_status,')
    ..writeln('  pago_status,')
    ..writeln('  coverage_status')
    ..writeln(')')
    ..writeln('select')
    ..writeln('  src.id,')
    ..writeln('  src.ticket_date,')
    ..writeln('  src.ticket_number,')
    ..writeln('  provider.id,')
    ..writeln('  provider.name,')
    ..writeln('  material.id,')
    ..writeln('  material.name,')
    ..writeln('  src.gross_weight,')
    ..writeln('  src.tare_weight,')
    ..writeln('  src.net_weight,')
    ..writeln('  src.humidity_percent,')
    ..writeln('  src.trash_percent,')
    ..writeln('  src.payable_weight,')
    ..writeln('  src.price,')
    ..writeln('  src.premium,')
    ..writeln('  src.amount,')
    ..writeln('  src.factura_status,')
    ..writeln('  src.pago_status,')
    ..writeln('  src.coverage_status')
    ..writeln('from tmp_import_compras_tickets_legacy src')
    ..writeln('join public.compras_counterparties provider')
    ..writeln('  on upper(provider.name) = upper(src.provider_name)')
    ..writeln('join public.compras_material_catalog material')
    ..writeln('  on upper(material.name) = upper(src.material_name)')
    ..writeln(" and material.level = 'COMERCIAL'")
    ..writeln('on conflict (id) do update')
    ..writeln('set')
    ..writeln('  ticket_date = excluded.ticket_date,')
    ..writeln('  ticket_number = excluded.ticket_number,')
    ..writeln('  provider_id = excluded.provider_id,')
    ..writeln('  provider_name_snapshot = excluded.provider_name_snapshot,')
    ..writeln('  material_id = excluded.material_id,')
    ..writeln('  material_name_snapshot = excluded.material_name_snapshot,')
    ..writeln('  gross_weight = excluded.gross_weight,')
    ..writeln('  tare_weight = excluded.tare_weight,')
    ..writeln('  net_weight = excluded.net_weight,')
    ..writeln('  humidity_percent = excluded.humidity_percent,')
    ..writeln('  trash_percent = excluded.trash_percent,')
    ..writeln('  payable_weight = excluded.payable_weight,')
    ..writeln('  price = excluded.price,')
    ..writeln('  premium = excluded.premium,')
    ..writeln('  amount = excluded.amount,')
    ..writeln('  factura_status = excluded.factura_status,')
    ..writeln('  pago_status = excluded.pago_status,')
    ..writeln('  coverage_status = excluded.coverage_status;')
    ..writeln()
    ..writeln('commit;');

  return buffer.toString();
}

String _csvLine(List<String> columns) => columns.map(_csvEscape).join(',');

String _csvEscape(String value) {
  final String escaped = value.replaceAll('"', '""');
  if (escaped.contains(',') ||
      escaped.contains('"') ||
      escaped.contains('\n')) {
    return '"$escaped"';
  }
  return escaped;
}

String _fmt(num value) => value.toStringAsFixed(3);

bool _isResolvedMaterialStatus(String status) =>
    status == 'EXACT' ||
    status == 'AUTO_ALIAS' ||
    status == 'AUTO_INFERRED_PRICE' ||
    status == 'AUTO_INFERRED_DICSA';

String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

String _sqlNullableString(String value) =>
    value.trim().isEmpty ? 'null' : _sqlString(value);

String _sqlNumber(num value, int scale) => value.toStringAsFixed(scale);

String _normalizeName(String value) {
  return value
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toUpperCase();
}

String _materialAlias(String material) {
  const Map<String, String> aliases = <String, String>{
    'ACERO INOXIABLE': 'ACERO INOXIDABLE',
  };
  return aliases[material] ?? material;
}

String _excelDateToIso(String rawValue) {
  final double? serial = double.tryParse(rawValue);
  if (serial == null) {
    return rawValue;
  }
  final DateTime base = DateTime.utc(1899, 12, 30);
  final DateTime value = base.add(Duration(days: serial.floor()));
  return value.toIso8601String().split('T').first;
}

class _ComprasCatalogCatalog {
  _ComprasCatalogCatalog({
    required this.providers,
    required this.materials,
    required this.prices,
  });

  final Set<String> providers;
  final Set<String> materials;
  final Map<String, double> prices;

  factory _ComprasCatalogCatalog.fromSql(String sql) {
    final Set<String> providers = <String>{};
    final Set<String> materials = <String>{};
    final Map<String, double> prices = <String, double>{};

    for (final RegExpMatch match in _kCounterpartyRowPattern.allMatches(sql)) {
      providers.add(_normalizeName(match.group(3)!));
    }
    for (final RegExpMatch match in _kMaterialRowPattern.allMatches(sql)) {
      if (match.group(3) == 'COMERCIAL') {
        materials.add(_normalizeName(match.group(4)!));
      }
    }
    for (final RegExpMatch match in _kPriceRowPattern.allMatches(sql)) {
      final String company = _normalizeName(match.group(2)!);
      final String material = _normalizeName(match.group(3)!);
      final double finalPrice = double.parse(match.group(5)!);
      prices['$company|$material'] = finalPrice;
    }

    return _ComprasCatalogCatalog(
      providers: providers,
      materials: materials,
      prices: prices,
    );
  }

  double? priceFor(String provider, String material) =>
      prices['$provider|$material'];
}

class _Workbook {
  _Workbook({required this.rows, required this.headerColumns});

  final List<_SheetRow> rows;
  final Map<String, String> headerColumns;

  factory _Workbook.fromXlsxBytes(List<int> bytes) {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final Map<String, ArchiveFile> byName = <String, ArchiveFile>{
      for (final ArchiveFile file in archive) file.name: file,
    };
    final List<String> sharedStrings = _parseSharedStrings(
      utf8.decode(byName['xl/sharedStrings.xml']!.content as List<int>),
    );
    final String worksheetXml = utf8.decode(
      byName['xl/worksheets/sheet1.xml']!.content as List<int>,
    );
    final List<_SheetRow> rows = _parseRows(worksheetXml, sharedStrings);
    final Map<String, String> headerColumns = <String, String>{};
    if (rows.isNotEmpty) {
      rows.first.values.forEach((String column, String value) {
        final String trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          headerColumns[trimmed] = column;
        }
      });
    }
    return _Workbook(rows: rows, headerColumns: headerColumns);
  }

  static List<String> _parseSharedStrings(String xml) {
    final XmlDocument document = XmlDocument.parse(xml);
    return document
        .findAllElements('si')
        .map(
          (node) => node.descendants
              .whereType<XmlText>()
              .map((text) => text.value)
              .join(),
        )
        .toList();
  }

  static List<_SheetRow> _parseRows(String xml, List<String> sharedStrings) {
    final XmlDocument document = XmlDocument.parse(xml);
    final List<_SheetRow> rows = <_SheetRow>[];
    for (final XmlElement rowNode in document.findAllElements('row')) {
      final Map<String, String> values = <String, String>{};
      final int rowNumber =
          int.tryParse(rowNode.getAttribute('r') ?? '') ?? rows.length + 1;
      for (final XmlElement cellNode in rowNode.findElements('c')) {
        final String reference = cellNode.getAttribute('r') ?? '';
        final String column = reference.replaceAll(RegExp(r'\d'), '');
        final String type = cellNode.getAttribute('t') ?? '';
        String value = '';
        if (type == 'inlineStr') {
          value = cellNode
              .findElements('is')
              .expand((node) => node.descendants.whereType<XmlText>())
              .map((text) => text.value)
              .join();
        } else {
          final String raw = cellNode
              .findElements('v')
              .map((node) => node.innerText)
              .join();
          if (type == 's') {
            final int sharedIndex = int.tryParse(raw) ?? -1;
            value = sharedIndex >= 0 && sharedIndex < sharedStrings.length
                ? sharedStrings[sharedIndex]
                : '';
          } else {
            value = raw;
          }
        }
        values[column] = value;
      }
      rows.add(_SheetRow(rowNumber: rowNumber, values: values));
    }
    return rows;
  }
}

class _SheetRow {
  _SheetRow({required this.rowNumber, required this.values});

  final int rowNumber;
  final Map<String, String> values;

  String cell(String column) => values[column] ?? '';

  double number(String column) => double.tryParse(cell(column)) ?? 0;

  String byHeader(Map<String, String> headerColumns, String header) {
    final String? column = headerColumns[header];
    if (column == null) {
      return '';
    }
    return cell(column);
  }

  double numberByHeader(Map<String, String> headerColumns, String header) =>
      double.tryParse(byHeader(headerColumns, header)) ?? 0;
}

class _MaterialInferenceIndex {
  _MaterialInferenceIndex({
    required this.byProviderDicsa,
    required this.byProviderDicsaPrice,
  });

  final Map<String, Set<String>> byProviderDicsa;
  final Map<String, Set<String>> byProviderDicsaPrice;

  factory _MaterialInferenceIndex.build(
    Iterable<_SheetRow> rows,
    Map<String, String> headerColumns,
  ) {
    final Map<String, Set<String>> byProviderDicsa = <String, Set<String>>{};
    final Map<String, Set<String>> byProviderDicsaPrice =
        <String, Set<String>>{};

    for (final _SheetRow row in rows) {
      final String provider = _normalizeName(
        row.byHeader(headerColumns, 'Proveedor'),
      );
      final String material = _materialAlias(
        _normalizeName(row.byHeader(headerColumns, 'Material')),
      );
      final String materialDicsa = _normalizeName(
        row.byHeader(headerColumns, 'MaterialDicsa'),
      );
      final double price = row.numberByHeader(headerColumns, 'Precio');
      if (provider.isEmpty || material.isEmpty || materialDicsa.isEmpty) {
        continue;
      }
      final String pairKey = '$provider|$materialDicsa';
      final String pricedKey =
          '$provider|$materialDicsa|${price.toStringAsFixed(4)}';
      byProviderDicsa.putIfAbsent(pairKey, () => <String>{}).add(material);
      byProviderDicsaPrice
          .putIfAbsent(pricedKey, () => <String>{})
          .add(material);
    }

    return _MaterialInferenceIndex(
      byProviderDicsa: byProviderDicsa,
      byProviderDicsaPrice: byProviderDicsaPrice,
    );
  }

  _MaterialInference resolve({
    required String provider,
    required String material,
    required String materialDicsa,
    required double price,
  }) {
    final String aliased = _materialAlias(material);
    if (aliased.isNotEmpty) {
      final String strategy = aliased == material ? 'SOURCE' : 'AUTO_ALIAS';
      return _MaterialInference(material: aliased, strategy: strategy);
    }
    if (provider.isEmpty || materialDicsa.isEmpty) {
      return const _MaterialInference(material: '', strategy: 'NONE');
    }
    final String pricedKey =
        '$provider|$materialDicsa|${price.toStringAsFixed(4)}';
    final Set<String>? pricedMatches = byProviderDicsaPrice[pricedKey];
    if (pricedMatches != null && pricedMatches.length == 1) {
      return _MaterialInference(
        material: pricedMatches.first,
        strategy: 'AUTO_INFERRED_PRICE',
      );
    }
    final String pairKey = '$provider|$materialDicsa';
    final Set<String>? pairMatches = byProviderDicsa[pairKey];
    if (pairMatches != null && pairMatches.length == 1) {
      return _MaterialInference(
        material: pairMatches.first,
        strategy: 'AUTO_INFERRED_DICSA',
      );
    }
    return const _MaterialInference(material: '', strategy: 'NONE');
  }
}

class _MaterialInference {
  const _MaterialInference({required this.material, required this.strategy});

  final String material;
  final String strategy;
}

class _TicketReviewRow {
  _TicketReviewRow({
    required this.rowNumber,
    required this.dateIso,
    required this.ticket,
    required this.provider,
    required this.material,
    required this.materialDicsa,
    required this.mappedMaterial,
    required this.inferredBy,
    required this.providerStatus,
    required this.materialStatus,
    required this.grossWeight,
    required this.tareWeight,
    required this.netWeight,
    required this.humidityKg,
    required this.trashKg,
    required this.humidityPercent,
    required this.trashPercent,
    required this.payableWeight,
    required this.recomputedPayableWeight,
    required this.price,
    required this.catalogPrice,
    required this.priceStatus,
    required this.premium,
    required this.amount,
    required this.recomputedAmount,
    required this.estadoRaw,
    required this.facturadoRaw,
    required this.targetFacturaStatus,
    required this.targetPagoStatus,
    required this.targetCoverageStatus,
    required this.referenciaRaw,
    required this.comentarioRaw,
    required this.importStatus,
    required this.blockingReason,
  });

  final int rowNumber;
  final String dateIso;
  final String ticket;
  final String provider;
  final String material;
  final String materialDicsa;
  final String mappedMaterial;
  final String inferredBy;
  final String providerStatus;
  final String materialStatus;
  final double grossWeight;
  final double tareWeight;
  final double netWeight;
  final double humidityKg;
  final double trashKg;
  final double humidityPercent;
  final double trashPercent;
  final double payableWeight;
  final double recomputedPayableWeight;
  final double price;
  final double? catalogPrice;
  final String priceStatus;
  final double premium;
  final double amount;
  final double recomputedAmount;
  final String estadoRaw;
  final String facturadoRaw;
  final String targetFacturaStatus;
  final String targetPagoStatus;
  final String targetCoverageStatus;
  final String referenciaRaw;
  final String comentarioRaw;
  final String importStatus;
  final String blockingReason;
}
