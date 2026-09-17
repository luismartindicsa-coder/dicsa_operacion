import 'dart:math' as math;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../direction_shipments_store.dart';
import 'operating_program_engine.dart';
import 'operating_program_models.dart';

const _navy = PdfColor.fromInt(0xff17365d);
const _green = PdfColor.fromInt(0xff2f6b4f);
const _lightGreen = PdfColor.fromInt(0xffedf4e8);
const _yellow = PdfColor.fromInt(0xfffff2cc);
const _ink = PdfColor.fromInt(0xff1f2937);
const _line = PdfColor.fromInt(0xffb7c9d6);

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _material(String code) =>
    programMaterialNames[programMaterials.indexOf(code)];

/// Live changes are notices only; production and shipment totals always belong
/// to the same saved version. Never silently replace the shipment snapshot.
List<String> programPdfShipmentNotes(
  OperatingProgram program,
  List<DirectionShipmentPlanRecord> current,
) {
  final saved = {for (final demand in program.demands) demand.id: demand};
  final notes = <String>{};
  for (final shipment in current) {
    if (shipment.quantityUnit != DirectionShipmentQuantityUnit.bales ||
        !programMaterials.contains(shipment.materialCode)) {
      continue;
    }
    final original = saved[shipment.id];
    final inWeek =
        !shipment.shipDate.isBefore(program.week) &&
        shipment.shipDate.isBefore(program.week.add(const Duration(days: 5)));
    if (original == null && !inWeek) continue;
    final label =
        '${shipment.clientName}: ${shipment.plannedQuantity} '
        '${_material(shipment.materialCode)} (${_date(shipment.shipDate)})';
    if (shipment.status == 'cancelado') {
      notes.add(
        'Cancelado: $label${original == null ? '' : '; actualizar esta versión'}',
      );
    } else if (original != null &&
        (programDate(original.date) != programDate(shipment.shipDate) ||
            original.quantity != shipment.plannedQuantity ||
            original.material != shipment.materialCode ||
            original.destination != shipment.clientName)) {
      notes.add(
        'Cambio posterior al programa: $label; antes '
        '${_date(original.date)}, ${original.quantity} ${_material(original.material)}, '
        '${original.destination}. Actualizar esta versión',
      );
    } else if (original == null && shipment.isActive) {
      notes.add('Fuera de esta versión (${shipment.status}): $label');
    } else if (original != null && shipment.status != 'confirmado') {
      notes.add('${shipment.status.toUpperCase()}: $label');
    }
    if (shipment.notes.trim().isNotEmpty) {
      notes.add('${shipment.clientName}: ${shipment.notes.trim()}');
    }
  }
  return notes.toList();
}

/// Reconcile materials separately before rendering. Capacity or surplus errors
/// block printing; infeasible shipment deadlines remain explicit floor alerts.
class OperatingProgramPrintData {
  final OperatingProgram program;
  final ProgramEvaluation evaluation;
  final List<String> notes;
  final List<int> shipmentTotals, yardUsed, productionTotals;

  OperatingProgramPrintData._(
    this.program,
    this.evaluation,
    this.notes,
    this.shipmentTotals,
    this.yardUsed,
    this.productionTotals,
  );

  factory OperatingProgramPrintData(
    OperatingProgram program, {
    List<String> operationalNotes = const [],
  }) {
    program.conditions.validate();
    if (program.week.weekday != DateTime.monday ||
        program.demands.any(
          (d) =>
              !programMaterials.contains(d.material) ||
              d.quantity <= 0 ||
              d.date.isBefore(program.week) ||
              !d.date.isBefore(program.week.add(const Duration(days: 5))),
        )) {
      throw StateError('Revisar semana y materiales de los embarques.');
    }
    final evaluation = evaluateOperatingProgram(
      program.week,
      program.conditions,
      program.demands,
      program.lines,
    );
    if (evaluation.violations.isNotEmpty) {
      throw StateError(
        'Corregir el programa antes de imprimir: '
        '${evaluation.violations.join(' ')}',
      );
    }
    final shipments = [
      for (final material in programMaterials)
        program.demands
            .where((d) => d.material == material)
            .fold<int>(0, (sum, d) => sum + d.quantity),
    ];
    final yard = [
      for (var m = 0; m < 3; m++)
        math.min(
          shipments[m],
          program.conditions.yard[programMaterials[m]] ?? 0,
        ),
    ];
    final production = [
      for (final material in programMaterials)
        programQuantity(program.lines, material: material),
    ];
    for (var m = 0; m < 3; m++) {
      if (production[m] > shipments[m] - yard[m]) {
        throw StateError(
          '${programMaterialNames[m]}: producción ${production[m]} '
          'excede las ${shipments[m] - yard[m]} pacas requeridas. '
          'Ajustar el programa antes de imprimir.',
        );
      }
    }
    final notes = <String>[
      'Máximo: ${program.conditions.dailyCapacity} pacas/día',
      for (var d = 0; d < 5; d++) ...[
        if (!program.conditions.days[d].working)
          '${programDayNames[d]} no laborable'
        else ...[
          if (!program.conditions.days[d].dayAvailable)
            '${programDayNames[d]} sin turno día',
          if (!program.conditions.days[d].nightAvailable)
            '${programDayNames[d]} sin turno noche',
        ],
        if (program.conditions.days[d].lossPercent > 0 ||
            program.conditions.days[d].machineryNote.isNotEmpty)
          '${programDayNames[d]} maquinaria -${program.conditions.days[d].lossPercent}%'
              '${program.conditions.days[d].machineryNote.isEmpty ? '' : ': ${program.conditions.days[d].machineryNote}'}',
      ],
      ...operationalNotes.where((n) => n.trim().isNotEmpty),
    ];
    return OperatingProgramPrintData._(
      program,
      evaluation,
      notes,
      shipments,
      yard,
      production,
    );
  }

  List<ProgramDemand> shipmentsOn(int day) => program.demands
      .where(
        (s) =>
            programDate(s.date) ==
            programDate(program.week.add(Duration(days: day))),
      )
      .toList();

  String destinations(int day) {
    final groups = <String, Map<String, int>>{};
    for (final shipment in shipmentsOn(day)) {
      final quantities = groups.putIfAbsent(shipment.destination, () => {});
      quantities.update(
        shipment.material,
        (value) => value + shipment.quantity,
        ifAbsent: () => shipment.quantity,
      );
    }
    if (groups.isEmpty) {
      return program.conditions.days[day].working
          ? 'SIN EMBARQUE'
          : 'NO LABORABLE - SIN EMBARQUE';
    }
    return groups.entries
        .map(
          (entry) =>
              '${entry.key}: '
              '${[for (final material in programMaterials)
                if (entry.value.containsKey(material)) '${entry.value[material]} ${_material(material)}'].join(', ')}',
        )
        .join('; ');
  }

  List<String> get alerts => [
    for (final shortfall in evaluation.shortfalls)
      '${_date(shortfall.shipment.date)}: faltan ${shortfall.quantity} '
          '${_material(shortfall.shipment.material)} para ${shortfall.shipment.destination} '
          '(${shortfall.causes.join(', ')})',
  ];

  String get reconciliation => [
    for (var m = 0; m < 3; m++)
      '${programMaterialNames[m]} ${shipmentTotals[m]} - ${yardUsed[m]} = '
          '${shipmentTotals[m] - yardUsed[m]}',
  ].join('  |  ');
}

/// Always A4 landscape. Measure content at readable sizes before painting.
/// Never clip destinations, omit alerts, shrink text or silently switch to A3.
Future<Uint8List> buildOperatingProgramPdf(
  OperatingProgram program, {
  List<String> operationalNotes = const [],
  AssetBundle? assetBundle,
}) async {
  final data = OperatingProgramPrintData(
    program,
    operationalNotes: operationalNotes,
  );
  final bundle = assetBundle ?? rootBundle;
  final logo = await bundle.load('assets/images/logo_dicsa.png');
  // A running desktop session may have reloaded the Dart code without the new
  // asset manifest. PDF's standard fonts keep export available in that session.
  // Prefer embedded Roboto whenever the packaged fonts are available.
  var regularFont = pw.Font.helvetica();
  var boldFont = pw.Font.helveticaBold();
  try {
    final regular = await bundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await bundle.load('assets/fonts/Roboto-Bold.ttf');
    regularFont = pw.Font.ttf(regular);
    boldFont = pw.Font.ttf(bold);
  } on FlutterError {
    // Asset not yet bundled; standard PDF fonts need no asset or network fetch.
  }
  final document = pw.Document(
    title: 'Programa operativo de cartón - ${programDate(program.week)}',
    author: 'DICSA',
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );
  pw.Widget text(
    String value, {
    double size = 11,
    bool bold = false,
    PdfColor color = _ink,
  }) => pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  );
  pw.Widget section(String title) => pw.Container(
    color: _green,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: text(title, bold: true, color: PdfColors.white),
  );
  pw.Widget cell(
    String value, {
    bool left = false,
    bool heading = false,
    bool total = false,
    bool numeric = false,
    bool blocked = false,
  }) => pw.Container(
    alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
    color: blocked && !total ? _yellow : null,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
    child: text(
      value,
      size: numeric ? 12 : (heading ? 10 : 10.5),
      bold: numeric || heading || total,
      color: total ? PdfColors.white : _ink,
    ),
  );
  pw.TableRow row(
    List<String> values, {
    int? day,
    bool heading = false,
    bool total = false,
    bool shipments = false,
  }) => pw.TableRow(
    decoration: pw.BoxDecoration(
      color: total
          ? _green
          : heading
          ? const PdfColor.fromInt(0xfff1f5f8)
          : day != null && !program.conditions.days[day].working
          ? _yellow
          : day != null && day.isEven
          ? _lightGreen
          : PdfColors.white,
    ),
    verticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      for (var i = 0; i < values.length; i++)
        cell(
          values[i],
          left: i == 0 || (shipments && i == 1),
          heading: heading,
          total: total,
          numeric: !heading && i >= (shipments ? 2 : 1),
          blocked:
              !shipments &&
              day != null &&
              i >= 1 &&
              i <= 6 &&
              program.conditions.slotCapacity(day, (i - 1) % 2) == 0,
        ),
    ],
  );
  final totalShipments = data.shipmentTotals.fold<int>(0, (a, b) => a + b);
  final totalProduction = programQuantity(program.lines);
  final history = program.conditions.history;
  final historySource = history?.hasData == true
      ? 'Fuente Día/Noche: histórico de Producción, ${_date(history!.start)} al ${_date(history.end)} '
            '(${history.observedWeeks.length} semanas con registros).'
      : 'Fuente Día/Noche: capacidad configurada; sin referencia histórica guardada.';
  final body = pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        color: _navy,
        padding: const pw.EdgeInsets.all(8),
        child: pw.Row(
          children: [
            pw.Image(
              pw.MemoryImage(
                logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
              ),
              width: 50,
              height: 50,
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  text(
                    'PROGRAMA OPERATIVO DE CARTÓN',
                    size: 20,
                    bold: true,
                    color: PdfColors.white,
                  ),
                  pw.SizedBox(height: 3),
                  text(
                    'EMBARQUES, DESTINOS Y PRODUCCIÓN POR TURNOS',
                    size: 11,
                    bold: true,
                    color: PdfColors.white,
                  ),
                  pw.SizedBox(height: 5),
                  text(
                    'Semana del ${_date(program.week)} al ${_date(program.week.add(const Duration(days: 4)))}'
                    '   |   ${program.statusLabel.toUpperCase()} v${program.version}',
                    size: 11,
                    color: PdfColors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        color: _yellow,
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            text(
              'AMANECEN EN PATIO:  ${[for (var m = 0; m < 3; m++) '${programMaterialNames[m]} ${program.conditions.yard[programMaterials[m]] ?? 0}'].join('  |  ')}'
              '     Producción requerida: ${data.evaluation.requiredTotal} pacas',
              bold: true,
            ),
            pw.SizedBox(height: 3),
            text('${data.notes.join('. ')}.', size: 10),
            if (data.alerts.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              text(
                'ATENCIÓN: ${data.alerts.join('; ')}.',
                size: 10.5,
                bold: true,
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(height: 4),
      section('EMBARQUES ESPERADOS Y DESTINO'),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .5),
        columnWidths: {
          0: const pw.FixedColumnWidth(81),
          1: const pw.FlexColumnWidth(4.8),
          for (var i = 2; i < 6; i++) i: const pw.FlexColumnWidth(1),
        },
        children: [
          row(
            ['DÍA', 'A QUIÉN', 'NACIONAL', 'LIMPIO', 'AMERICANO', 'TOTAL'],
            heading: true,
            shipments: true,
          ),
          for (var d = 0; d < 5; d++)
            row(
              [
                '${programDayNames[d]} ${program.week.add(Duration(days: d)).day}',
                data.destinations(d),
                for (final material in programMaterials)
                  '${data.shipmentsOn(d).where((s) => s.material == material).fold<int>(0, (sum, s) => sum + s.quantity)}',
                '${data.shipmentsOn(d).fold<int>(0, (sum, s) => sum + s.quantity)}',
              ],
              day: d,
              shipments: true,
            ),
          row(
            [
              'TOTAL',
              'EMBARQUES (PACAS)',
              ...data.shipmentTotals.map((q) => '$q'),
              '$totalShipments',
            ],
            total: true,
            shipments: true,
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      section('PRODUCCIÓN ESPERADA POR TURNO'),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .5),
        columnWidths: {
          0: const pw.FixedColumnWidth(81),
          for (var i = 1; i < 8; i++) i: const pw.FlexColumnWidth(1),
        },
        children: [
          row([
            'DÍA',
            for (final material in programMaterialNames) ...[
              '${material.toUpperCase()}\nDÍA',
              '${material.toUpperCase()}\nNOCHE',
            ],
            'TOTAL',
          ], heading: true),
          for (var d = 0; d < 5; d++)
            row([
              '${programDayNames[d]} ${program.week.add(Duration(days: d)).day}',
              for (final material in programMaterials)
                for (var s = 0; s < 2; s++)
                  '${programQuantity(program.lines, day: d, shift: s, material: material)}',
              '${programQuantity(program.lines, day: d)}',
            ], day: d),
          row([
            'TOTAL',
            for (final material in programMaterials)
              for (var s = 0; s < 2; s++)
                '${programQuantity(program.lines, shift: s, material: material)}',
            '$totalProduction',
          ], total: true),
        ],
      ),
      pw.SizedBox(height: 5),
      text(
        'PRODUCCIÓN: ${[for (var m = 0; m < 3; m++) '${programMaterialNames[m]} ${data.productionTotals[m]}'].join(' | ')}'
        '    TURNOS: Día ${programQuantity(program.lines, shift: 0)} | Noche ${programQuantity(program.lines, shift: 1)}'
        '    TOTAL: $totalProduction pacas',
        size: 10,
        bold: true,
      ),
      pw.SizedBox(height: 3),
      text(
        'CUADRE (embarques - patio utilizado = requerido): ${data.reconciliation}'
        '${totalProduction < data.evaluation.requiredTotal ? ' | Sin programar: ${data.evaluation.requiredTotal - totalProduction}' : ''}',
        size: 10,
      ),
      pw.SizedBox(height: 7),
      pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: .5)),
        ),
        padding: const pw.EdgeInsets.only(top: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            text(
              'Producción y embarques sujetos a ajuste si cambia patio, disponibilidad de turno o programación.',
              size: 10,
            ),
            text(historySource, size: 10),
            text(
              'Turno día: cubre el mismo día. Turno noche: solo embarques posteriores. Amarillo: día o turno no disponible.',
              size: 10,
            ),
          ],
        ),
      ),
    ],
  );
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => _OnePageContent(child: body),
    ),
  );
  return document.save();
}

class _OnePageContent extends pw.SingleChildWidget {
  _OnePageContent({required super.child});

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    super.layout(
      context,
      pw.BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: parentUsesSize,
    );
    if (box!.height > constraints.maxHeight + .01) {
      throw StateError(
        'El detalle no cabe legible en una página A4 horizontal. '
        'Abreviar destinos u observaciones antes de exportar; no se omitió ningún dato.',
      );
    }
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }
}
