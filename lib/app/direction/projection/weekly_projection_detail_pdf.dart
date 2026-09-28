import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/utils/number_formatters.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_models.dart';
import 'weekly_projection_report.dart';

const projectionPdfDays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

class ProjectionPdfRow {
  final List<String> cells;
  final bool subtotal;
  const ProjectionPdfRow(this.cells, {this.subtotal = false});
}

/// Bounded continuation rows keep long text legible without truncating it.
pw.Table projectionDetailTable(
  List<String> headers,
  List<ProjectionPdfRow> rows,
) {
  const ink = PdfColor.fromInt(0xff21312d),
      green = PdfColor.fromInt(0xff365f4c),
      soft = PdfColor.fromInt(0xffeef3ef),
      line = PdfColor.fromInt(0xffcbd6ce);
  pw.Widget text(String value, {bool bold = false, bool header = false}) =>
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 9,
          color: header ? PdfColors.white : ink,
          fontWeight: bold || header
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      );
  pw.TableRow row(
    List<String> values, {
    bool header = false,
    bool subtotal = false,
  }) => pw.TableRow(
    repeat: header,
    decoration: pw.BoxDecoration(
      color: header
          ? green
          : subtotal
          ? soft
          : PdfColors.white,
    ),
    children: [
      for (var c = 0; c < values.length; c++)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: c == 5 && !header && values[c].isNotEmpty
              ? pw.SizedBox(
                  height: 13,
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    alignment: pw.Alignment.centerRight,
                    child: text(values[c], bold: subtotal),
                  ),
                )
              : text(values[c], bold: subtotal, header: header),
        ),
    ],
  );
  List<String> parts(String value, int limit) {
    var remaining = value.replaceAll(RegExp(r'\s+'), ' ').trim().runes.toList();
    final result = <String>[];
    while (remaining.length > limit) {
      var end = limit;
      for (var i = limit; i > limit ~/ 2; i--) {
        if (remaining[i] == 32) {
          end = i;
          break;
        }
      }
      result.add(String.fromCharCodes(remaining.take(end)));
      remaining = remaining.sublist(end);
      if (remaining.first == 32) remaining.removeAt(0);
    }
    result.add(String.fromCharCodes(remaining));
    return result;
  }

  final tableRows = <pw.TableRow>[row(headers, header: true)];
  for (final entry in rows) {
    final columns = [
      [entry.cells[0]],
      parts(entry.cells[1], 280),
      parts(entry.cells[2], 280),
      parts(entry.cells[3], 160),
      parts(entry.cells[4], 120),
      [entry.cells[5]],
    ];
    final lines = columns.map((c) => c.length).reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < lines; i++) {
      tableRows.add(
        row([
          for (var c = 0; c < columns.length; c++)
            c == 0 && i > 0
                ? 'Continúa\n${i + 1}/$lines'
                : i < columns[c].length
                ? columns[c][i]
                : '',
        ], subtotal: entry.subtotal),
      );
    }
  }
  return pw.Table(
    children: tableRows,
    border: pw.TableBorder.all(color: line, width: 0.4),
    columnWidths: {
      0: const pw.FlexColumnWidth(0.9),
      1: const pw.FlexColumnWidth(1.9),
      2: const pw.FlexColumnWidth(1.8),
      3: const pw.FlexColumnWidth(1.15),
      4: const pw.FlexColumnWidth(0.9),
      5: const pw.FlexColumnWidth(1.3),
    },
  );
}

pw.Table projectionExpenseTable(WeeklyExpensePlan plan) {
  final report = expenseReportPlan(plan);
  final payments = report.scheduledPayments.toList()
    ..sort((a, b) {
      for (final c in [
        a.date.compareTo(b.date),
        a.reference.toLowerCase().compareTo(b.reference.toLowerCase()),
        a.payee.toLowerCase().compareTo(b.payee.toLowerCase()),
        a.id.compareTo(b.id),
      ]) {
        if (c != 0) return c;
      }
      return 0;
    });
  String money(int cents) => formatMoney(cents / 100);
  String count(int n) => '$n ${n == 1 ? 'pago' : 'pagos'}';
  final rows = <ProjectionPdfRow>[];
  for (var d = 0; d < 7; d++) {
    final date = programDate(plan.week.add(Duration(days: d)));
    final daily = payments.where((p) => programDate(p.date) == date).toList();
    if (daily.isEmpty) continue;
    for (final p in daily) {
      rows.add(
        ProjectionPdfRow([
          '${projectionPdfDays[d]}\n$date',
          p.payee,
          p.reference,
          p.account.isEmpty ? '-' : p.account.replaceAll('|', ' / '),
          projectionPaymentTypes[p.paymentType] ?? p.paymentType,
          money(p.amount),
        ]),
      );
    }
    rows.add(
      ProjectionPdfRow([
        '',
        'Subtotal ${projectionPdfDays[d]}',
        count(daily.length),
        '',
        '',
        money(daily.fold(0, (s, p) => s + p.amount)),
      ], subtotal: true),
    );
  }
  rows.add(
    ProjectionPdfRow([
      '',
      'TOTAL EGRESOS',
      count(payments.length),
      '',
      '',
      money(report.total),
    ], subtotal: true),
  );
  return projectionDetailTable([
    'Fecha de pago',
    'Beneficiario / concepto',
    'Factura / referencia',
    'Cuenta',
    'Tipo',
    'Importe',
  ], rows);
}

pw.Table projectionIncomeTable(WeeklyCashFlowReport report) {
  final rows = <ProjectionPdfRow>[];
  for (var d = 0; d < 8; d++) {
    final date = d == 7 ? null : report.flow.plan.week.add(Duration(days: d));
    final daily = report.incomes.where((r) => r.date == date).toList();
    if (daily.isEmpty) continue;
    for (final r in daily) {
      rows.add(
        ProjectionPdfRow([
          date == null
              ? 'Por definir'
              : '${projectionPdfDays[d]}\n${programDate(date)}',
          r.client,
          r.reference,
          r.material,
          r.type == 'MIXTO'
              ? 'Mixto'
              : projectionPaymentTypes[r.type] ?? r.type,
          formatMoney(r.amount / 100),
        ]),
      );
    }
    rows.add(
      ProjectionPdfRow([
        '',
        date == null
            ? 'Subtotal sin fecha'
            : 'Subtotal ${projectionPdfDays[d]}',
        '',
        '',
        '',
        formatMoney(daily.fold<int>(0, (s, r) => s + r.amount) / 100),
      ], subtotal: true),
    );
  }
  rows.add(
    ProjectionPdfRow([
      '',
      'TOTAL INGRESOS',
      '',
      '',
      '',
      formatMoney(report.flow.income.total / 100),
    ], subtotal: true),
  );
  return projectionDetailTable([
    'Fecha de cobro',
    'Cliente / origen',
    'Documento / referencia',
    'Material',
    'Tipo',
    'Importe',
  ], rows);
}
