import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/utils/number_formatters.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_models.dart';
import 'weekly_projection_report.dart';
import 'weekly_projection_detail_pdf.dart';

/// Itemized weekly payments with daily subtotals and repeating page/table headers.
/// Uses the reconciled snapshot, excluding tickets from both detail and totals.
Future<Uint8List> buildWeeklyExpensesPdf(
  WeeklyExpensePlan plan, {
  required DateTime generatedAt,
  AssetBundle? assetBundle,
}) async {
  final assets = assetBundle ?? rootBundle;
  final logo = pw.MemoryImage(
    (await assets.load('assets/images/logo_dicsa.png')).buffer.asUint8List(),
  );
  var regular = pw.Font.helvetica(), bold = pw.Font.helveticaBold();
  try {
    regular = pw.Font.ttf(await assets.load('assets/fonts/Roboto-Regular.ttf'));
    bold = pw.Font.ttf(await assets.load('assets/fonts/Roboto-Bold.ttf'));
  } on FlutterError {
    /* Existing desktop bundles can use standard fonts. */
  }
  const ink = PdfColor.fromInt(0xff21312d),
      green = PdfColor.fromInt(0xff365f4c),
      soft = PdfColor.fromInt(0xffeef3ef),
      line = PdfColor.fromInt(0xffcbd6ce);
  final report = expenseReportPlan(plan);
  final payments = report.scheduledPayments.toList();
  String money(int cents) => formatMoney(cents / 100);
  String count(int n) => '$n ${n == 1 ? 'pago' : 'pagos'}';
  pw.Widget text(
    String value, {
    double size = 10,
    bool bold = false,
    PdfColor color = ink,
  }) => pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    ),
  );
  pw.Widget card(
    String title,
    int amount,
    String detail, {
    bool primary = false,
  }) => pw.Expanded(
    child: pw.Container(
      height: 82,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: primary ? green : soft,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          text(
            title,
            size: 9,
            bold: true,
            color: primary ? PdfColors.white : green,
          ),
          pw.SizedBox(height: 9),
          pw.SizedBox(
            height: 24,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.centerLeft,
              child: text(
                money(amount),
                size: 22,
                bold: true,
                color: primary ? PdfColors.white : ink,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          text(detail, size: 8, color: primary ? PdfColors.white : ink),
        ],
      ),
    ),
  );
  final expenseTable = projectionExpenseTable(report);
  final document = pw.Document(
    title: 'Egresos proyectados - ${programDate(plan.week)}',
    author: 'DICSA',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      maxPages: expenseTable.children.length + 20,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pw.Row(
          children: [
            pw.Image(logo, width: 43, height: 43),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  text('DICSA / DIRECCIÓN', size: 9, bold: true, color: green),
                  pw.SizedBox(height: 3),
                  text(
                    'Egresos proyectados de la semana',
                    size: 23,
                    bold: true,
                  ),
                  text(
                    '${programDate(plan.week)} al ${programDate(plan.week.add(const Duration(days: 6)))}  |  MXN',
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                text('Desglose de pagos', bold: true),
                text('Lectura ${programDate(generatedAt)}', size: 8),
                text('Egresos v${plan.revision}', size: 8),
              ],
            ),
          ],
        ),
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: line),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              text(
                'Proyección sin tickets. Totales solo de pagos incluidos en este reporte; no acredita pagos realizados.',
                size: 8,
              ),
              text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                size: 8,
              ),
            ],
          ),
        ],
      ),
      build: (_) => [
        pw.Row(
          children: [
            card(
              'TOTAL PROGRAMADO',
              report.total,
              '${count(payments.length)} ${payments.length == 1 ? 'incluido' : 'incluidos'}',
              primary: true,
            ),
            for (final type in projectionPaymentTypes.entries) ...[
              pw.SizedBox(width: 9),
              card(
                type.value.toUpperCase(),
                report.totalForType(type.key),
                count(payments.where((r) => r.paymentType == type.key).length),
              ),
            ],
          ],
        ),
        pw.SizedBox(height: 12),
        if (report.menudeoPayments.any((r) => r.total > 0)) ...[
          text(
            'Menudeo incluido como estimación de compras y gastos pendientes en Efectivo; no corresponde a pagos ejecutados.',
            size: 9,
          ),
          pw.SizedBox(height: 8),
        ],
        for (final warning in report.menudeoWarnings) ...[
          text(warning, size: 9),
          pw.SizedBox(height: 5),
        ],
        if (!plan.generated) ...[
          text(
            'Propuesta de Finanzas aún no generada: este reporte puede estar incompleto.',
            size: 9,
            bold: true,
          ),
          pw.SizedBox(height: 8),
        ],
        if (report.totalForType('SIN_CLASIFICAR') > 0) ...[
          text(
            'El total incluye pagos sin clasificar. Falta distribuirlos entre Efectivo y Fiscal.',
            size: 9,
          ),
          pw.SizedBox(height: 8),
        ],
        if (payments.isEmpty)
          text('Sin egresos programados para esta semana.', bold: true)
        else ...[
          expenseTable,
        ],
      ],
    ),
  );
  return document.save();
}
