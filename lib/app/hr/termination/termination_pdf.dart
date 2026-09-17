import 'package:flutter/services.dart';
import '../human_resources_termination_calculation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Exports the saved snapshot, not a recalculation using today's formulas.
Future<Uint8List> buildHrTerminationPdf(
  Map<String, dynamic> record, {
  required DateTime generatedAt,
}) async {
  final input = Map<String, dynamic>.from(record['inputs'] as Map);
  final result = Map<String, dynamic>.from(record['result'] as Map);
  final lines = (result['lines'] as List).cast<Map>();
  final net = result['net'] as Map?;
  final gross = result['gross'] as Map;
  final deductions = result['deductions'] as Map;
  final mode = switch (record['mode']) {
    'liquidacion' => 'Liquidación',
    'indemnizacion' => 'Indemnización',
    _ => 'Finiquito',
  };
  final reviewed = record['status'] == 'revisado' && record['id'] != null;
  final purple = PdfColor.fromHex('#3B1F5C');
  final ink = PdfColor.fromHex('#24143D');
  final muted = PdfColor.fromHex('#685B79');
  final pale = PdfColor.fromHex('#F3EDFF');
  final border = PdfColor.fromHex('#DCD5E6');
  const margin = 28.0;
  final contentWidth = PdfPageFormat.a4.width - margin * 2;
  double number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String money(dynamic value) =>
      hrTerminationCurrency(value == null ? null : number(value));
  String date(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null
        ? '-'
        : '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  pw.TextStyle style({bool bold = false, double size = 8.5, PdfColor? color}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? ink,
      );
  pw.Widget text(
    String value, {
    bool bold = false,
    double size = 8.5,
    PdfColor? color,
  }) => pw.Text(
    value,
    style: style(bold: bold, size: size, color: color),
  );
  pw.MemoryImage? logo;
  try {
    final bytes = await rootBundle.load('assets/images/logo_dicsa.png');
    logo = pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {
    /* Optional branding only. */
  }
  List<String> amountRow(String label, Map amount) => [
    label,
    money(amount['base']),
    money(amount['flow']),
    money(amount['total']),
  ];
  final earnings = lines
      .where(
        (line) =>
            line['deduction'] != true &&
            (number((line['amount'] as Map)['total']) != 0 ||
                ['aguinaldo', 'vacations', 'premium'].contains(line['key'])),
      )
      .toList(growable: false);
  final deductionLines = lines.where(
    (line) =>
        line['deduction'] == true &&
        (line['key'] == 'isr' || number((line['amount'] as Map)['total']) != 0),
  );

  final formulaLabels = <String, List<String>>{};
  for (final line in earnings) {
    formulaLabels
        .putIfAbsent('${line['formula']}', () => [])
        .add('${line['label']}');
  }

  pw.Widget buildBody(double density) {
    pw.Widget text(
      String value, {
      bool bold = false,
      double size = 8.5,
      PdfColor? color,
    }) => pw.Text(
      value,
      style: style(bold: bold, size: size * density, color: color),
    );
    pw.Widget section(String label) => pw.Padding(
      padding: pw.EdgeInsets.only(top: 7 * density, bottom: 3 * density),
      child: text(label, bold: true, size: 9.5, color: purple),
    );
    pw.TableRow tableRow(
      List<String> values, {
      bool header = false,
      bool group = false,
      bool total = false,
    }) => pw.TableRow(
      decoration: pw.BoxDecoration(
        color: header
            ? purple
            : group || total
            ? pale
            : PdfColors.white,
        border: pw.Border(bottom: pw.BorderSide(color: border, width: 0.3)),
      ),
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        for (var index = 0; index < values.length; index++)
          pw.Padding(
            padding: pw.EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 2.5 * density,
            ),
            child: pw.Text(
              values[index],
              textAlign: index == 0 ? pw.TextAlign.left : pw.TextAlign.right,
              style: style(
                size: 8.5 * density,
                bold: header || group || total,
                color: header
                    ? PdfColors.white
                    : group || total
                    ? purple
                    : ink,
              ),
            ),
          ),
      ],
    );
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        text('${record['employee_name']}', bold: true, size: 12),
        pw.SizedBox(height: 3 * density),
        text('ID ${record['employee_id']} · ${record['empresa']}'),
        pw.SizedBox(height: 3 * density),
        text(
          'Ingreso: ${date(input['start_date'])}    Último día trabajado: ${date(input['end_date'])}',
        ),
        pw.SizedBox(height: 3 * density),
        text('Causa: ${input['reason'] ?? 'Pendiente'}'),
        pw.SizedBox(height: 7 * density),
        pw.Row(
          children: [
            for (final pair in [
              ('Fiscal', 'base'),
              ('Flujo', 'flow'),
              ('Total', 'total'),
            ])
              pw.Expanded(
                child: pw.Container(
                  margin: pw.EdgeInsets.only(right: pair.$2 == 'total' ? 0 : 6),
                  padding: pw.EdgeInsets.all(6 * density),
                  decoration: pw.BoxDecoration(
                    color: pale,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text(pair.$1, bold: true, color: purple),
                      pw.SizedBox(height: 3 * density),
                      text(money(net?[pair.$2]), bold: true, size: 14),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 7 * density),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(3.3),
            1: const pw.FlexColumnWidth(1.35),
            2: const pw.FlexColumnWidth(1.35),
            3: const pw.FlexColumnWidth(1.35),
          },
          children: [
            tableRow([
              'Concepto',
              'Base / Fiscal',
              'Flujo',
              'Total',
            ], header: true),
            tableRow(['Salario utilizado', '', '', ''], group: true),
            tableRow([
              'Semanal',
              money(input['weekly_base']),
              money(input['weekly_flow']),
              money(
                number(input['weekly_base']) + number(input['weekly_flow']),
              ),
            ]),
            tableRow([
              'Diario',
              money(number(input['weekly_base']) / 7),
              money(number(input['weekly_flow']) / 7),
              money(
                (number(input['weekly_base']) + number(input['weekly_flow'])) /
                    7,
              ),
            ]),
            tableRow([
              'Percepciones pendientes de pago',
              '',
              '',
              '',
            ], group: true),
            for (final line in earnings)
              tableRow(amountRow('${line['label']}', line['amount'] as Map)),
            tableRow(amountRow('BRUTO', gross), total: true),
            tableRow(['Deducciones confirmadas', '', '', ''], group: true),
            for (final line in deductionLines)
              if (line['key'] == 'isr' && net == null)
                tableRow(['ISR oficial CONTPAQ', 'Pendiente', '-', 'Pendiente'])
              else
                tableRow(amountRow('${line['label']}', line['amount'] as Map)),
            tableRow(
              amountRow(
                'TOTAL DEDUCCIONES${net == null ? ' (parcial)' : ''}',
                deductions,
              ),
              total: true,
            ),
            if (net != null) tableRow(amountRow('NETO', net), total: true),
          ],
        ),
        pw.SizedBox(height: 4 * density),
        if ('${input['salary_reference'] ?? ''}'.isNotEmpty)
          text(
            'Referencia salarial: ${input['salary_reference']}',
            size: 8,
            color: muted,
          ),
        text(
          'ISR oficial: ${input['isr_reference'] ?? 'Referencia pendiente'}',
          size: 8,
          color: muted,
        ),
        if ('${input['deductions_reference'] ?? ''}'.isNotEmpty)
          text('${input['deductions_reference']}', size: 8, color: muted),
        section('Bases y fórmulas'),
        text(
          'Devengo aguinaldo: ${date(input['aguinaldo_start'])} a ${date(input['end_date'])} · ${input['aguinaldo_days']} días al año',
          size: 8,
        ),
        text(
          'Devengo vacaciones: ${date(input['vacation_start'])} a ${date(input['end_date'])} · ${input['vacation_days']} días al año · Prima ${input['premium_percent']}%',
          size: 8,
        ),
        text(
          input['inclusive_dates'] == true
              ? 'Conteo: ambos extremos incluidos; divisor 365.'
              : 'Conteo: fecha final menos fecha inicial; divisor 365.',
          size: 8,
        ),
        for (final entry in formulaLabels.entries)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: 1.5 * density),
            child: text(
              '${entry.value.join(', ')}: ${entry.key}',
              size: 8,
              color: muted,
            ),
          ),
        if (record['mode'] != 'finiquito')
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: text(
              'Salario mínimo diario confirmado: ${money(input['minimum_daily'])}. Tope prima antigüedad: 2 salarios mínimos.',
              size: 8,
            ),
          ),
        if (record['mode'] == 'indemnizacion')
          text(
            'Integrado laboral diario Base ${money(input['integrated_daily_base'])} · Total ${money(input['integrated_daily_total'])}. ${input['integration_reference'] ?? ''}',
            size: 8,
          ),
        if ('${input['prior_payment_reference'] ?? ''}'.isNotEmpty)
          text('Pagos previos: ${input['prior_payment_reference']}', size: 8),
        if ('${input['notes'] ?? ''}'.isNotEmpty) ...[
          section('Observaciones RH'),
          text('${input['notes']}', size: 8),
        ],
        pw.SizedBox(height: 5 * density),
        text(
          'Fórmulas ${record['formula_version']} · Registro ${record['id'] ?? 'sin guardar'}',
          size: 7,
          color: muted,
        ),
        text(
          'El desglose Fiscal/Flujo identifica los canales de pago; no determina por sí mismo exenciones de ISR.',
          size: 7,
          color: muted,
        ),
      ],
    );
  }

  final pdf = pw.Document(
    title: '$mode · ${record['employee_name']}',
    author: 'DICSA · Recursos Humanos',
  );
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(margin),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(logo, width: 38, height: 38),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text(
                      'DICSA | Recursos Humanos',
                      bold: true,
                      size: 10,
                      color: purple,
                    ),
                    pw.SizedBox(height: 3),
                    text(mode, bold: true, size: 21),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  text(
                    reviewed ? 'REVISADO POR RH' : 'BORRADOR',
                    bold: true,
                    color: purple,
                  ),
                  text(
                    record['revision'] == null
                        ? 'Sin versión guardada'
                        : 'Versión ${record['revision']}',
                  ),
                  text(
                    'Emitido ${date(generatedAt.toIso8601String())}',
                    size: 7.5,
                    color: muted,
                  ),
                ],
              ),
            ],
          ),
          pw.Divider(color: purple),
          pw.SizedBox(height: 5),
          // Fit only the variable content. Signatures keep their physical size
          // even for the longest mode, extra concepts or lengthy observations.
          pw.Expanded(
            child: pw.LayoutBuilder(
              builder: (context, constraints) {
                // Reflow at the full page width before resorting to scaling for
                // exceptionally long free text. Never truncate saved content.
                late pw.Widget body;
                for (var step = 0; step <= 8; step++) {
                  body = buildBody(1 - step * 0.03);
                  body.layout(
                    context,
                    pw.BoxConstraints.tightFor(width: contentWidth),
                    parentUsesSize: true,
                  );
                  if (body.box!.height <= constraints!.maxHeight) {
                    return pw.Align(
                      alignment: pw.Alignment.topLeft,
                      child: body,
                    );
                  }
                }
                return pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.topLeft,
                  child: pw.SizedBox(width: contentWidth, child: body),
                );
              },
            ),
          ),
          pw.SizedBox(height: 8),
          pw.SizedBox(
            height: 96,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                text('Firmas', bold: true, size: 9.5, color: purple),
                pw.SizedBox(height: 52),
                pw.Row(
                  children: [
                    for (final label in [
                      'Colaborador',
                      'Recursos Humanos',
                      'Autorizó',
                    ])
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          child: pw.Column(
                            children: [
                              pw.Container(height: 0.6, color: muted),
                              pw.SizedBox(height: 4),
                              text(label, bold: true, size: 8),
                              text('Nombre y firma', size: 7, color: muted),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.Divider(color: border),
          pw.Row(
            children: [
              pw.Expanded(
                child: text(
                  'Cálculo de RH · No acredita pago ni timbrado',
                  size: 7,
                  color: muted,
                ),
              ),
              text('1 / 1', size: 7, color: muted),
            ],
          ),
        ],
      ),
    ),
  );
  return pdf.save();
}
