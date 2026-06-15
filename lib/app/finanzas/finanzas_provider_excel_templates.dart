import 'dart:math' as math;
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../compras/compras_data_store.dart';
import '../compras/compras_tickets_store.dart';

enum FinanzasProviderExcelTemplateKind { avon, genericMaterials }

class FinanzasProviderExcelException implements Exception {
  final String message;

  const FinanzasProviderExcelException(this.message);

  @override
  String toString() => message;
}

class FinanzasProviderExcelTemplates {
  static Future<Uint8List> buildWorkbook({
    required FinanzasProviderExcelTemplateKind kind,
    required List<ComprasTicketRecord> tickets,
    required String providerName,
    String? providerLinkedName,
    ComprasCatalogSnapshot? comprasCatalogSnapshot,
  }) {
    switch (kind) {
      case FinanzasProviderExcelTemplateKind.avon:
        return _buildAvonWorkbook(tickets);
      case FinanzasProviderExcelTemplateKind.genericMaterials:
        return _buildGenericMaterialsWorkbook(
          tickets,
          providerName: providerName,
          providerLinkedName: providerLinkedName,
          comprasCatalogSnapshot: comprasCatalogSnapshot,
        );
    }
  }

  static Future<Uint8List> _buildAvonWorkbook(
    List<ComprasTicketRecord> rawTickets,
  ) async {
    final tickets = rawTickets.toList(growable: false)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.ticket.compareTo(b.ticket);
      });
    if (tickets.isEmpty) {
      throw const FinanzasProviderExcelException(
        'Selecciona al menos un ticket para llenar la plantilla Avon.',
      );
    }
    if (tickets.length > 50) {
      throw const FinanzasProviderExcelException(
        'La plantilla Avon soporta hasta 50 tickets por exportación.',
      );
    }

    final unsupportedMaterials =
        tickets
            .map((row) => row.materialNameSnapshot.trim())
            .where((name) => _avonSummaryRowForMaterial(name) == null)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (unsupportedMaterials.isNotEmpty) {
      throw FinanzasProviderExcelException(
        'Hay materiales sin mapeo para Avon: ${unsupportedMaterials.join(', ')}.',
      );
    }

    final templateBytes = (await rootBundle.load(
      'assets/templates/plantilla_avon.xlsx',
    )).buffer.asUint8List();
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final editor = _TemplateWorkbookEditor(archive);

    final semana = editor.sheet('SEMANA');
    semana.setText('C2', 'Semana del ${_weekRangeLabel(tickets)}');

    for (var rowIndex = 5; rowIndex <= 54; rowIndex++) {
      for (final column in const <String>[
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
      ]) {
        semana.setBlank('$column$rowIndex');
      }
    }

    for (var index = 0; index < tickets.length; index++) {
      final rowNumber = 5 + index;
      final ticket = tickets[index];
      final basuraHumedadKg = math.max<double>(
        0,
        ticket.netWeight - ticket.payableWeight,
      );

      semana.setText('G$rowNumber', ticket.materialNameSnapshot.trim());
      semana.setText('H$rowNumber', _shortDate(ticket.date));
      semana.setText('J$rowNumber', ticket.ticket.trim());
      semana.setNumber('K$rowNumber', ticket.grossWeight);
      semana.setNumber('L$rowNumber', ticket.tareWeight);
      semana.setNumber('M$rowNumber', basuraHumedadKg);
      semana.setNumber('N$rowNumber', ticket.payableWeight);
    }

    semana.setFormula('O55', 'SUM(N5:N54)', cachedValue: _sumPayable(tickets));
    semana.setFormula(
      'N56',
      'SUBTOTAL(9,N5:N54)',
      cachedValue: _sumPayable(tickets),
    );
    semana.setBlank('O56');

    final repPago = editor.sheet('Rep de pago 1');
    final quantityByRow = <int, double>{};
    for (final ticket in tickets) {
      final rowNumber = _avonSummaryRowForMaterial(
        ticket.materialNameSnapshot,
      )!;
      quantityByRow[rowNumber] =
          (quantityByRow[rowNumber] ?? 0) + ticket.payableWeight;
    }

    for (var rowNumber = 4; rowNumber <= 19; rowNumber++) {
      final quantity = quantityByRow[rowNumber] ?? 0;
      repPago.setNumber('C$rowNumber', quantity);
      repPago.touchFormula(
        'E$rowNumber',
        cachedValue: quantity * repPago.numberValue('D$rowNumber'),
      );
    }
    repPago.touchFormula(
      'C20',
      cachedValue: quantityByRow.values.fold<double>(
        0,
        (sum, item) => sum + item,
      ),
    );
    repPago.touchFormula(
      'E20',
      cachedValue: quantityByRow.entries.fold<double>(
        0,
        (sum, entry) =>
            sum + (entry.value * repPago.numberValue('D${entry.key}')),
      ),
    );

    return editor.encode();
  }

  static Future<Uint8List> _buildGenericMaterialsWorkbook(
    List<ComprasTicketRecord> rawTickets, {
    required String providerName,
    String? providerLinkedName,
    ComprasCatalogSnapshot? comprasCatalogSnapshot,
  }) async {
    final tickets = rawTickets.toList(growable: false)
      ..sort((a, b) {
        final byMaterial = a.materialNameSnapshot.compareTo(
          b.materialNameSnapshot,
        );
        if (byMaterial != 0) return byMaterial;
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.ticket.compareTo(b.ticket);
      });
    if (tickets.isEmpty) {
      throw const FinanzasProviderExcelException(
        'Selecciona al menos un ticket para llenar la plantilla genérica.',
      );
    }

    final catalog =
        comprasCatalogSnapshot ?? await ComprasDataStore.loadCatalogSnapshot();
    final providerId = _resolveComprasCatalogProviderId(
      catalog: catalog,
      providerName: providerName,
      providerLinkedName: providerLinkedName,
    );
    if (providerId == null) {
      throw FinanzasProviderExcelException(
        'No se encontró el proveedor "$providerName" dentro del catálogo de Compras para resolver precios vigentes.',
      );
    }

    final pricesByMaterialId = _latestActivePricesByMaterial(
      catalog: catalog,
      providerId: providerId,
    );

    final groupedTickets = <String, List<ComprasTicketRecord>>{};
    final materialOrder = <String>[];
    for (final ticket in tickets) {
      final materialName = ticket.materialNameSnapshot.trim();
      final bucket = groupedTickets.putIfAbsent(materialName, () {
        materialOrder.add(materialName);
        return <ComprasTicketRecord>[];
      });
      bucket.add(ticket);
    }

    final missingPriceMaterials = <String>[];
    for (final materialName in materialOrder) {
      final firstTicket = groupedTickets[materialName]!.first;
      if (!pricesByMaterialId.containsKey(firstTicket.materialId)) {
        missingPriceMaterials.add(materialName);
      }
    }
    if (missingPriceMaterials.isNotEmpty) {
      throw FinanzasProviderExcelException(
        'Faltan precios vigentes en Compras para: ${missingPriceMaterials.join(', ')}.',
      );
    }

    final oversizedMaterials = <String>[];
    for (final entry in groupedTickets.entries) {
      if (entry.value.length > _kGenericTemplateMaxTicketsPerMaterial) {
        oversizedMaterials.add('${entry.key} (${entry.value.length})');
      }
    }
    if (oversizedMaterials.isNotEmpty) {
      throw FinanzasProviderExcelException(
        'Cada material soporta hasta $_kGenericTemplateMaxTicketsPerMaterial tickets por exportación. Exceden: ${oversizedMaterials.join(', ')}.',
      );
    }

    final blockEntries = <_GenericTemplateBlockEntry>[];
    for (final materialName in materialOrder) {
      final materialTickets = groupedTickets[materialName]!;
      for (
        var start = 0;
        start < materialTickets.length;
        start += _kGenericTemplateRowsPerBlock
      ) {
        final end = math.min(
          start + _kGenericTemplateRowsPerBlock,
          materialTickets.length,
        );
        blockEntries.add(
          _GenericTemplateBlockEntry(
            materialName: materialName,
            tickets: materialTickets.sublist(start, end),
          ),
        );
      }
    }

    if (materialOrder.length > _kGenericTemplateSummaryRows.length) {
      throw FinanzasProviderExcelException(
        'La plantilla genérica soporta hasta ${_kGenericTemplateSummaryRows.length} materiales distintos por exportación. La selección trae ${materialOrder.length}.',
      );
    }
    if (blockEntries.length > _kGenericTemplateBlocks.length) {
      throw FinanzasProviderExcelException(
        'La plantilla genérica soporta hasta ${_kGenericTemplateBlocks.length} bloques de tickets por exportación. La selección requiere ${blockEntries.length} bloques.',
      );
    }

    final templateBytes = (await rootBundle.load(
      'assets/templates/plantilla_generica.xlsx',
    )).buffer.asUint8List();
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final editor = _TemplateWorkbookEditor(archive);
    final sheet = editor.sheet('Hoja1');

    sheet.setText('A1', 'SEMANA DEL "${_weekRangeLabel(tickets)}"');

    for (
      var blockIndex = 0;
      blockIndex < _kGenericTemplateBlocks.length;
      blockIndex++
    ) {
      final startRow = _kGenericTemplateBlocks[blockIndex];
      final titleRow = startRow;
      final dataStartRow = startRow + 2;
      final totalRow = startRow + 11;

      final blockEntry = blockIndex < blockEntries.length
          ? blockEntries[blockIndex]
          : null;
      final materialName = blockEntry?.materialName ?? '-';
      final materialTickets = blockEntry?.tickets ?? const <ComprasTicketRecord>[];
      final materialPrice = materialTickets.isEmpty
          ? 0.0
          : pricesByMaterialId[materialTickets.first.materialId]!;

      sheet.setText('A$titleRow', 'CONTROL  DE "$materialName"   ');

      for (
        var rowNumber = dataStartRow;
        rowNumber < dataStartRow + _kGenericTemplateRowsPerBlock;
        rowNumber++
      ) {
        for (final column in const <String>[
          'A',
          'B',
          'C',
          'D',
          'E',
          'F',
          'G',
          'H',
        ]) {
          sheet.setBlank('$column$rowNumber');
        }
      }

      var totalGross = 0.0;
      var totalTare = 0.0;
      var totalNet = 0.0;
      var totalAmount = 0.0;
      for (var rowOffset = 0; rowOffset < materialTickets.length; rowOffset++) {
        final rowNumber = dataStartRow + rowOffset;
        final ticket = materialTickets[rowOffset];
        final lineAmount = ticket.netWeight * materialPrice;
        totalGross += ticket.grossWeight;
        totalTare += ticket.tareWeight;
        totalNet += ticket.netWeight;
        totalAmount += lineAmount;
        sheet.setText('A$rowNumber', _shortDate(ticket.date));
        sheet.setBlank('B$rowNumber');
        sheet.setBlank('C$rowNumber');
        sheet.setNumber('D$rowNumber', ticket.grossWeight);
        sheet.setNumber('E$rowNumber', ticket.tareWeight);
        sheet.setNumber('F$rowNumber', ticket.netWeight);
        sheet.setNumber('G$rowNumber', materialPrice);
        sheet.setNumber('H$rowNumber', lineAmount);
      }

      sheet.setNumber('D$totalRow', totalGross);
      sheet.setNumber('E$totalRow', totalTare);
      sheet.setNumber('F$totalRow', totalNet);
      sheet.setNumber('H$totalRow', totalAmount);

    }

    for (final summaryRow in _kGenericTemplateSummaryRows) {
      sheet.setBlank('K$summaryRow');
      sheet.setBlank('L$summaryRow');
      sheet.setBlank('M$summaryRow');
      sheet.setNumber('N$summaryRow', 0.0);
    }

    for (var materialIndex = 0; materialIndex < materialOrder.length; materialIndex++) {
      final materialName = materialOrder[materialIndex];
      final rows = groupedTickets[materialName]!;
      final totalNet = rows.fold<double>(0, (acc, row) => acc + row.netWeight);
      final materialPrice = pricesByMaterialId[rows.first.materialId] ?? 0.0;
      final summaryRow = _kGenericTemplateSummaryRows[materialIndex];
      sheet.setText('K$summaryRow', materialName);
      sheet.setNumber('L$summaryRow', totalNet);
      sheet.setNumber('M$summaryRow', materialPrice);
      sheet.setNumber('N$summaryRow', totalNet * materialPrice);
    }

    final grandAmount = materialOrder.fold<double>(0, (sum, name) {
      final rows = groupedTickets[name]!;
      final price = pricesByMaterialId[rows.first.materialId] ?? 0;
      final net = rows.fold<double>(0, (acc, row) => acc + row.netWeight);
      return sum + (net * price);
    });
    sheet.setNumber('N15', grandAmount);
    sheet.setText('L15', '          GRAN TOTAL…..');

    return editor.encode();
  }
}

const List<int> _kGenericTemplateBlocks = <int>[
  2,
  15,
  28,
  41,
  54,
  67,
  80,
  93,
  106,
  119,
  132,
  145,
];

const int _kGenericTemplateRowsPerBlock = 9;
const int _kGenericTemplateMaxTicketsPerMaterial = 20;
const List<int> _kGenericTemplateSummaryRows = <int>[
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
];

class _GenericTemplateBlockEntry {
  final String materialName;
  final List<ComprasTicketRecord> tickets;

  const _GenericTemplateBlockEntry({
    required this.materialName,
    required this.tickets,
  });
}

String? _resolveComprasCatalogProviderId({
  required ComprasCatalogSnapshot catalog,
  required String providerName,
  String? providerLinkedName,
}) {
  String normalize(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  final candidates = <String>{
    normalize(providerName),
    if (providerLinkedName != null && providerLinkedName.trim().isNotEmpty)
      normalize(providerLinkedName),
  };

  for (final company in catalog.companies) {
    final companyName = normalize(company.name);
    final companyCode = normalize(company.code);
    if (candidates.contains(companyName) || candidates.contains(companyCode)) {
      return company.id;
    }
  }
  return null;
}

Map<String, double> _latestActivePricesByMaterial({
  required ComprasCatalogSnapshot catalog,
  required String providerId,
}) {
  final latest = <String, ComprasCatalogPriceRecord>{};
  for (final row in catalog.prices) {
    if (!row.active || row.companyId != providerId) continue;
    final current = latest[row.materialId];
    if (current == null) {
      latest[row.materialId] = row;
      continue;
    }
    final currentTime =
        current.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final nextTime = row.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (nextTime.isAfter(currentTime)) {
      latest[row.materialId] = row;
    }
  }
  return <String, double>{
    for (final entry in latest.entries) entry.key: entry.value.amount,
  };
}

double _sumPayable(List<ComprasTicketRecord> tickets) =>
    tickets.fold<double>(0, (sum, row) => sum + row.payableWeight);

String _shortDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _weekRangeLabel(List<ComprasTicketRecord> tickets) {
  final start = tickets.first.date;
  final end = tickets.last.date;
  final monthNames = <int, String>{
    1: 'ENERO',
    2: 'FEBRERO',
    3: 'MARZO',
    4: 'ABRIL',
    5: 'MAYO',
    6: 'JUNIO',
    7: 'JULIO',
    8: 'AGOSTO',
    9: 'SEPTIEMBRE',
    10: 'OCTUBRE',
    11: 'NOVIEMBRE',
    12: 'DICIEMBRE',
  };
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}-${end.day} ${monthNames[start.month]} ${start.year}';
  }
  return '${start.day} ${monthNames[start.month]} - ${end.day} ${monthNames[end.month]} ${end.year}';
}

int? _avonSummaryRowForMaterial(String rawMaterial) {
  final normalized = rawMaterial.trim().toUpperCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  if (normalized.contains('CORRUGADO') || normalized.contains('CARTON')) {
    return 4;
  }
  if (normalized.contains('PLASTICO MIXTO')) return 5;
  if (normalized.contains('TARIMA')) return 6;
  if (normalized.contains('PEDACERA MADERA')) return 7;
  if (normalized.contains('CHATARRA')) return 8;
  if (normalized.contains('BRONCE')) return 9;
  if (normalized.contains('ACERO INOXIDABLE') || normalized.contains('INOX')) {
    return 10;
  }
  if (normalized.contains('FOLLETO')) return 11;
  if (normalized.contains('BOND')) return 12;
  if (normalized.contains('CAPLE') || normalized.contains('CAJILLA')) {
    return 13;
  }
  if (normalized.contains('FILTRO') && normalized.contains('CELULOSA')) {
    return 14;
  }
  if (normalized.contains('VIDRIO')) return 15;
  if (normalized.contains('PLASTICO LAVADO')) return 16;
  if (normalized.contains('TEXTIL')) return 17;
  if (normalized.contains('ALUMINIO')) return 18;
  if (normalized.contains('SABADOS') || normalized.contains('VIAJE')) {
    return 19;
  }
  if (normalized.contains('AJUSTE')) return 19;
  return null;
}

class _TemplateWorkbookEditor {
  final Archive _archive;
  final Map<String, String> _sheetPathsByName;
  final Map<String, _WorksheetEditor> _worksheetEditors =
      <String, _WorksheetEditor>{};

  _TemplateWorkbookEditor(this._archive)
    : _sheetPathsByName = _resolveSheetPaths(_archive);

  _WorksheetEditor sheet(String name) {
    final path = _sheetPathsByName[name];
    if (path == null) {
      throw FinanzasProviderExcelException(
        'La plantilla no contiene la hoja "$name".',
      );
    }
    return _worksheetEditors.putIfAbsent(
      path,
      () => _WorksheetEditor(_archive, path),
    );
  }

  Uint8List encode() {
    final rebuilt = Archive()..comment = _archive.comment;
    for (final file in _archive) {
      final editedWorksheet = _worksheetEditors[file.name];
      final replacementBytes = editedWorksheet?.encodedBytes;
      final ArchiveFile rebuiltFile;
      if (!file.isFile) {
        rebuiltFile = ArchiveFile.directory(file.name);
      } else if (replacementBytes != null) {
        rebuiltFile = ArchiveFile.bytes(file.name, replacementBytes);
      } else {
        rebuiltFile = ArchiveFile.bytes(
          file.name,
          file.readBytes() ?? const <int>[],
        );
      }
      rebuiltFile.mode = file.mode;
      rebuiltFile.ownerId = file.ownerId;
      rebuiltFile.groupId = file.groupId;
      rebuiltFile.creationTime = file.creationTime;
      rebuiltFile.lastModTime = file.lastModTime;
      rebuiltFile.comment = file.comment;
      rebuiltFile.compression = file.compression;
      rebuiltFile.compressionLevel = file.compressionLevel;
      rebuilt.add(rebuiltFile);
    }
    return ZipEncoder().encodeBytes(rebuilt);
  }

  static Map<String, String> _resolveSheetPaths(Archive archive) {
    final workbookXml = _readArchiveString(archive, 'xl/workbook.xml');
    final relsXml = _readArchiveString(archive, 'xl/_rels/workbook.xml.rels');
    final workbook = XmlDocument.parse(workbookXml);
    final rels = XmlDocument.parse(relsXml);

    final relTargetById = <String, String>{};
    for (final rel in rels.findAllElements('Relationship')) {
      relTargetById[rel.getAttribute('Id') ?? ''] =
          rel.getAttribute('Target') ?? '';
    }

    final result = <String, String>{};
    for (final sheet in workbook.findAllElements('sheet')) {
      final name = sheet.getAttribute('name');
      final relId = sheet.getAttribute('r:id');
      final target = relTargetById[relId];
      if (name == null || target == null || target.isEmpty) continue;
      result[name] = target.startsWith('xl/') ? target : 'xl/$target';
    }
    return result;
  }
}

class _WorksheetEditor {
  final String path;
  late final XmlDocument _document;
  late final XmlElement _worksheet;
  late final XmlElement _sheetData;

  _WorksheetEditor(Archive archive, this.path) {
    _document = XmlDocument.parse(_readArchiveString(archive, path));
    _worksheet = _document.rootElement;
    _sheetData = _worksheet.getElement('sheetData')!;
  }

  Uint8List get encodedBytes =>
      Uint8List.fromList(utf8.encode(_document.toXmlString()));

  void setText(String cellRef, String value) {
    final cell = _cell(cellRef);
    cell.children.clear();
    cell.setAttribute('t', 'inlineStr');
    cell.children.add(
      XmlElement(XmlName('is'), const [], [
        XmlElement(XmlName('t'), const [], [XmlText(value)]),
      ]),
    );
  }

  void setNumber(String cellRef, double value) {
    final cell = _cell(cellRef);
    cell.children.clear();
    cell.removeAttribute('t');
    cell.children.add(
      XmlElement(XmlName('v'), const [], [XmlText(_number(value))]),
    );
  }

  void setBlank(String cellRef) {
    final cell = _cell(cellRef);
    cell.children.clear();
    cell.removeAttribute('t');
  }

  void setFormula(String cellRef, String formula, {double? cachedValue}) {
    final cell = _cell(cellRef);
    cell.children.clear();
    cell.removeAttribute('t');
    cell.children.add(XmlElement(XmlName('f'), const [], [XmlText(formula)]));
    if (cachedValue != null) {
      cell.children.add(
        XmlElement(XmlName('v'), const [], [XmlText(_number(cachedValue))]),
      );
    }
  }

  void touchFormula(String cellRef, {double? cachedValue}) {
    final cell = _cell(cellRef);
    final formula = cell.getElement('f');
    if (formula == null) return;
    final currentFormula = formula.innerText;
    setFormula(cellRef, currentFormula, cachedValue: cachedValue);
  }

  double numberValue(String cellRef) {
    final cell = _cell(cellRef);
    final raw = cell.getElement('v')?.innerText.trim() ?? '0';
    return double.tryParse(raw) ?? 0;
  }

  XmlElement _cell(String cellRef) {
    final rowNumber = int.parse(RegExp(r'\d+').firstMatch(cellRef)!.group(0)!);
    final row = _row(rowNumber);
    for (final child in row.findElements('c')) {
      if (child.getAttribute('r') == cellRef) return child;
    }
    final templateCell = row
        .findElements('c')
        .firstWhere(
          (child) =>
              _columnLetters(child.getAttribute('r') ?? '') ==
              _columnLetters(cellRef),
          orElse: () => row.findElements('c').last,
        );
    final clone = XmlDocument.parse(templateCell.toXmlString()).rootElement;
    clone.setAttribute('r', cellRef);
    clone.children.clear();
    row.children.add(clone);
    return clone;
  }

  XmlElement _row(int rowNumber) {
    for (final row in _sheetData.findElements('row')) {
      if (row.getAttribute('r') == '$rowNumber') return row;
    }
    throw FinanzasProviderExcelException(
      'La plantilla no contiene la fila $rowNumber en $path.',
    );
  }
}

String _readArchiveString(Archive archive, String path) {
  for (final file in archive) {
    if (file.name == path) {
      return utf8.decode(file.readBytes() ?? const <int>[]);
    }
  }
  throw FinanzasProviderExcelException(
    'No se encontró "$path" dentro de la plantilla.',
  );
}

String _columnLetters(String cellRef) =>
    cellRef.replaceAll(RegExp(r'[^A-Z]'), '');

String _number(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
