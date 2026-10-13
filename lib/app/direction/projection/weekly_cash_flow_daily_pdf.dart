import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/utils/number_formatters.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_detail_pdf.dart';
import 'weekly_projection_report.dart';

/// One row per day, comparing receipts and payments in each separate channel.
pw.Widget weeklyCashFlowDailyTable(WeeklyCashFlowCalendar calendar) {
  const ink = PdfColor.fromInt(0xff21312d),
      green = PdfColor.fromInt(0xff365f4c),
      soft = PdfColor.fromInt(0xffeef3ef),
      line = PdfColor.fromInt(0xffcbd6ce),
      red = PdfColor.fromInt(0xffa32e29),
      amber = PdfColor.fromInt(0xff895713);
  String money(int? cents) =>
      cents == null ? 'Sin capturar' : formatMoney(cents / 100);
  String status(DailyFlowStatus state) => switch (state) {
    DailyFlowStatus.elapsed => 'Transcurrido',
    DailyFlowStatus.missingOpening => 'Falta saldo',
    DailyFlowStatus.unclassified => 'Por distribuir',
    DailyFlowStatus.incomplete => 'Incompleto',
    DailyFlowStatus.shortfall => 'Faltante',
    DailyFlowStatus.sufficient => 'Alcanza',
  };
  PdfColor statusColor(DailyFlowStatus state) => switch (state) {
    DailyFlowStatus.shortfall => red,
    DailyFlowStatus.sufficient => green,
    DailyFlowStatus.elapsed => PdfColors.grey600,
    _ => amber,
  };
  pw.TableRow row(
    List<String> cells, {
    bool header = false,
    bool opening = false,
    bool shaded = false,
    Map<int, PdfColor> colors = const {},
  }) => pw.TableRow(
    repeat: header,
    decoration: pw.BoxDecoration(
      color: header ? green : (opening || shaded ? soft : PdfColors.white),
    ),
    children: [
      for (var c = 0; c < cells.length; c++)
        pw.Container(
          alignment: c == 0 || c == 4 || c == 8
              ? pw.Alignment.centerLeft
              : pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: pw.Text(
            cells[c],
            style: pw.TextStyle(
              fontSize: header || c == 4 || c == 8 ? 8 : 9,
              fontWeight:
                  header || opening || c == 3 || c == 4 || c == 7 || c == 8
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: header ? PdfColors.white : colors[c] ?? ink,
            ),
          ),
        ),
    ],
  );
  return pw.Table(
    border: pw.TableBorder.all(color: line, width: 0.4),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.05),
      for (final c in [1, 2, 3, 5, 6, 7]) c: const pw.FlexColumnWidth(1),
      4: const pw.FlexColumnWidth(0.85),
      8: const pw.FlexColumnWidth(0.85),
    },
    children: [
      row([
        'Día',
        'EFECTIVO\nIngresos',
        'EFECTIVO\nEgresos',
        'EFECTIVO\nSaldo al cierre',
        'EFECTIVO\n¿Alcanza?',
        'FISCAL\nIngresos',
        'FISCAL\nEgresos',
        'FISCAL\nSaldo al cierre',
        'FISCAL\n¿Alcanza?',
      ], header: true),
      row([
        'Saldo inicial',
        '-',
        '-',
        money(calendar.openingFor('EFECTIVO')),
        '-',
        '-',
        '-',
        money(calendar.openingFor('FISCAL')),
        '-',
      ], opening: true),
      for (final day in calendar.pressure.days)
        row(
          [
            '${projectionPdfDays[day.date.weekday - 1]} ${programDate(day.date).substring(5)}',
            for (final type in ['EFECTIVO', 'FISCAL']) ...[
              day.elapsed ? '-' : money(day.income[type] ?? 0),
              day.elapsed ? '-' : money(day.expenses[type] ?? 0),
              day.elapsed
                  ? '-'
                  : !calendar.pressure.classified
                  ? 'Por distribuir'
                  : money(calendar.closingFor(day, type)),
              status(calendar.statusFor(day, type)),
            ],
          ],
          shaded: day.date.weekday.isEven,
          colors: {
            for (final entry in {'EFECTIVO': 3, 'FISCAL': 7}.entries) ...{
              entry.value: statusColor(calendar.statusFor(day, entry.key)),
              entry.value + 1: statusColor(calendar.statusFor(day, entry.key)),
            },
          },
        ),
    ],
  );
}
