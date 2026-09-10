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
  final pending = (result['pending'] as List?) ?? [];
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

  pw.TextStyle style({bool bold = false, double size = 9, PdfColor? color}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? ink,
      );
  pw.Widget text(
    String value, {
    bool bold = false,
    double size = 9,
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
  pw.Widget section(String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
    child: text(label, bold: true, size: 12, color: purple),
  );
  pw.Widget table(List<List<String>> rows) => pw.TableHelper.fromTextArray(
    headers: ['Concepto', 'Base / Fiscal', 'Flujo', 'Total'],
    data: rows,
    headerStyle: style(bold: true, color: PdfColors.white),
    headerDecoration: pw.BoxDecoration(color: purple),
    cellStyle: style(),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    border: null,
    oddRowDecoration: pw.BoxDecoration(color: pale),
    columnWidths: {
      0: const pw.FlexColumnWidth(3.3),
      1: const pw.FlexColumnWidth(1.35),
      2: const pw.FlexColumnWidth(1.35),
      3: const pw.FlexColumnWidth(1.35),
    },
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerRight,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
    },
  );
  List<String> row(String label, Map amount) => [
    label,
    money(amount['base']),
    money(amount['flow']),
    money(amount['total']),
  ];
  final pdf = pw.Document(
    title: '$mode · ${record['employee_name']}',
    author: 'DICSA · Recursos Humanos',
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logo, width: 44, height: 44),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text(
                      'DICSA | Recursos Humanos',
                      bold: true,
                      size: 11,
                      color: purple,
                    ),
                    pw.SizedBox(height: 4),
                    text(mode, bold: true, size: 24),
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
                    size: 8,
                    color: muted,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: purple),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Column(
          children: [
            pw.Divider(color: PdfColor.fromHex('#DCD5E6')),
            pw.Row(
              children: [
                pw.Expanded(
                  child: text(
                    'Cálculo de RH · No acredita pago ni timbrado',
                    size: 8,
                    color: muted,
                  ),
                ),
                text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  size: 8,
                  color: muted,
                ),
              ],
            ),
          ],
        ),
      ),
      build: (_) => [
        text('${record['employee_name']}', bold: true, size: 14),
        pw.SizedBox(height: 5),
        text('ID ${record['employee_id']} · ${record['empresa']}'),
        pw.SizedBox(height: 8),
        text(
          'Ingreso: ${date(input['start_date'])}    Último día trabajado: ${date(input['end_date'])}',
        ),
        pw.SizedBox(height: 5),
        text('Causa: ${input['reason'] ?? 'Pendiente'}'),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            for (final pair in [
              ('Fiscal', 'base'),
              ('Flujo', 'flow'),
              ('Total', 'total'),
            ])
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 6),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: pale,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text(pair.$1, bold: true, color: purple),
                      pw.SizedBox(height: 6),
                      text(money(net?[pair.$2]), bold: true, size: 17),
                    ],
                  ),
                ),
              ),
          ],
        ),
        section('Salario utilizado'),
        table([
          [
            'Semanal',
            money(input['weekly_base']),
            money(input['weekly_flow']),
            money(number(input['weekly_base']) + number(input['weekly_flow'])),
          ],
          [
            'Diario',
            money(number(input['weekly_base']) / 7),
            money(number(input['weekly_flow']) / 7),
            money(
              (number(input['weekly_base']) + number(input['weekly_flow'])) / 7,
            ),
          ],
        ]),
        if ('${input['salary_reference'] ?? ''}'.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: text(
              'Referencia: ${input['salary_reference']}',
              color: muted,
            ),
          ),
        section('Percepciones pendientes de pago'),
        table([
          for (final line in lines.where(
            (l) =>
                l['deduction'] != true &&
                (number((l['amount'] as Map)['total']) != 0 ||
                    ['aguinaldo', 'vacations', 'premium'].contains(l['key'])),
          ))
            row('${line['label']}', line['amount'] as Map),
          row('BRUTO', gross),
        ]),
        section('Deducciones confirmadas'),
        table([
          for (final line in lines.where(
            (l) =>
                l['deduction'] == true &&
                (l['key'] == 'isr' ||
                    number((l['amount'] as Map)['total']) != 0),
          ))
            if (line['key'] == 'isr' && net == null)
              ['ISR oficial CONTPAQ', 'Pendiente', '-', 'Pendiente']
            else
              row('${line['label']}', line['amount'] as Map),
          row(
            'TOTAL DEDUCCIONES${net == null ? ' (parcial)' : ''}',
            deductions,
          ),
          if (net != null) row('NETO', net),
        ]),
        pw.SizedBox(height: 8),
        text(
          'ISR oficial: ${input['isr_reference'] ?? 'Referencia pendiente'}',
          color: muted,
        ),
        if ('${input['deductions_reference'] ?? ''}'.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: text('${input['deductions_reference']}', color: muted),
          ),
        pw.NewPage(),
        section('Bases y fórmulas'),
        text(
          'Devengo aguinaldo: ${date(input['aguinaldo_start'])} a ${date(input['end_date'])} · ${input['aguinaldo_days']} días al año',
        ),
        pw.SizedBox(height: 5),
        text(
          'Devengo vacaciones: ${date(input['vacation_start'])} a ${date(input['end_date'])} · ${input['vacation_days']} días al año · Prima ${input['premium_percent']}%',
        ),
        pw.SizedBox(height: 5),
        text(
          input['inclusive_dates'] == true
              ? 'Conteo: ambos extremos incluidos; divisor 365.'
              : 'Conteo: fecha final menos fecha inicial; divisor 365.',
        ),
        for (final line in lines.where(
          (l) =>
              l['deduction'] != true &&
              (number((l['amount'] as Map)['total']) != 0 ||
                  ['aguinaldo', 'vacations', 'premium'].contains(l['key'])),
        ))
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: text(
              '${line['label']}: ${line['formula']}',
              size: 8,
              color: muted,
            ),
          ),
        if (record['mode'] != 'finiquito')
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: text(
              'Salario mínimo diario confirmado: ${money(input['minimum_daily'])}. Tope prima antigüedad: 2 salarios mínimos.',
              size: 8,
            ),
          ),
        if (record['mode'] == 'indemnizacion')
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: text(
              'Integrado laboral diario Base ${money(input['integrated_daily_base'])} · Total ${money(input['integrated_daily_total'])}. ${input['integration_reference'] ?? ''}',
              size: 8,
            ),
          ),
        if ('${input['prior_payment_reference'] ?? ''}'.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: text(
              'Pagos previos: ${input['prior_payment_reference']}',
              size: 8,
            ),
          ),
        if (pending.isNotEmpty) section('Pendientes para revisión'),
        for (final p in pending)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: text('- $p', size: 9),
          ),
        if ('${input['notes'] ?? ''}'.isNotEmpty) section('Observaciones RH'),
        if ('${input['notes'] ?? ''}'.isNotEmpty) text('${input['notes']}'),
        pw.SizedBox(height: 12),
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
    ),
  );
  return pdf.save();
}
