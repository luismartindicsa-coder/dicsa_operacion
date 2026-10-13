import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/utils/number_formatters.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_models.dart';
import 'weekly_projection_report.dart';
import 'weekly_projection_detail_pdf.dart';
import 'weekly_cash_flow_daily_pdf.dart';
import '../expected_income/expected_income_models.dart';

/// Reconciled summary plus itemized weekly receipts and payments, without expense tickets.
Future<Uint8List> buildWeeklyCashFlowPdf(
  ExpectedIncomeProjection projection,
  WeeklyExpensePlan plan, {
  required DateTime generatedAt,
  AssetBundle? assetBundle,
}) async {
  final report = WeeklyCashFlowReport(projection, plan);
  final calendar = WeeklyCashFlowCalendar(report, generatedAt);
  final flow = report.flow;
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
  String money(int? cents) =>
      cents == null ? 'Por definir' : formatMoney(cents / 100);
  pw.Widget text(
    String s, {
    double size = 10,
    bool bold = false,
    PdfColor color = ink,
  }) => pw.Text(
    s,
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    ),
  );
  pw.Widget card(
    String title,
    int? amount,
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
  final income = flow.income;
  final table = <List<String>>[
    [
      'Saldo inicial',
      money(flow.plan.openingCash),
      money(flow.plan.openingFiscal),
      '-',
      money(flow.opening),
    ],
    [
      'Cobros por ventas',
      for (final t in ['EFECTIVO', 'FISCAL', 'MIXTO'])
        money((income.byType[t] ?? 0) - (income.financingByType[t] ?? 0)),
      money(income.salesTotal),
    ],
    [
      'Disposición El Palomar',
      for (final t in ['EFECTIVO', 'FISCAL', 'MIXTO'])
        money(income.financingByType[t] ?? 0),
      money(income.financingTotal),
    ],
    [
      'Egresos programados',
      for (final t in ['EFECTIVO', 'FISCAL', 'SIN_CLASIFICAR'])
        money(flow.expense(t)),
      money(flow.expenses),
    ],
    if (plan.menudeoPayments.isNotEmpty)
      [
        'De los cuales: Menudeo estimado',
        money(plan.menudeoPayments.fold<int>(0, (s, r) => s + r.total)),
        money(0),
        money(0),
        money(plan.menudeoPayments.fold<int>(0, (s, r) => s + r.total)),
      ],
    [
      'Flujo neto',
      for (final t in ['EFECTIVO', 'FISCAL'])
        money((income.byType[t] ?? 0) - flow.expense(t)),
      money((income.byType['MIXTO'] ?? 0) - flow.expense('SIN_CLASIFICAR')),
      money(flow.net),
    ],
    [
      'Saldo final proyectado',
      money(flow.closingFor('EFECTIVO')),
      money(flow.closingFor('FISCAL')),
      '-',
      money(flow.closing),
    ],
  ];
  final incomeTable = projectionIncomeTable(report);
  final expenseTable = projectionExpenseTable(flow.plan);
  final document = pw.Document(
    title: 'Flujo semanal proyectado - ${programDate(flow.plan.week)}',
    author: 'DICSA',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      maxPages: incomeTable.children.length + expenseTable.children.length + 20,
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
                  text('Flujo semanal proyectado', size: 23, bold: true),
                  text(
                    '${programDate(flow.plan.week)} al ${programDate(flow.plan.week.add(const Duration(days: 6)))}  |  MXN',
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                text('Ingresos y egresos desglosados', bold: true),
                text('Lectura ${programDate(generatedAt)}', size: 8),
                text('Egresos v${flow.plan.revision}', size: 8),
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
                'Egresos sin tickets. Totales de los cobros y pagos incluidos en este reporte; no son movimientos ejecutados.',
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
              'ENTRADAS PREVISTAS',
              income.total,
              'Cobros + disposición El Palomar',
              primary: true,
            ),
            pw.SizedBox(width: 9),
            card(
              'EGRESOS PROGRAMADOS',
              flow.expenses,
              '${flow.plan.scheduledPayments.length} pagos incluidos',
            ),
            pw.SizedBox(width: 9),
            card('FLUJO NETO', flow.net, 'Entradas menos egresos'),
            pw.SizedBox(width: 9),
            card('SALDO FINAL', flow.closing, 'Saldo inicial + flujo neto'),
          ],
        ),
        pw.SizedBox(height: 14),
        text('Ingresos vs egresos por día', size: 14, bold: true),
        pw.SizedBox(height: 4),
        text(
          'Saldo al cierre = saldo anterior + ingresos - egresos. Efectivo y Fiscal se evalúan por separado.',
          size: 9,
        ),
        pw.SizedBox(height: 8),
        weeklyCashFlowDailyTable(calendar),
        pw.SizedBox(height: 8),
        text(
          'Se supone que el ingreso llega antes del pago del mismo día. Un saldo negativo indica el faltante acumulado.',
          size: 8,
        ),
        if (!plan.generated ||
            !calendar.pressure.openingComplete ||
            !calendar.pressure.classified) ...[
          pw.SizedBox(height: 4),
          text(
            !plan.generated
                ? 'Falta generar la propuesta de egresos: todavía no se puede confirmar si alcanza.'
                : !calendar.pressure.openingComplete
                ? 'Captura el saldo inicial pendiente para validar la disponibilidad de ese canal.'
                : 'Por distribuir: ingresos mixtos ${money(flow.income.byType['MIXTO'] ?? 0)} / egresos sin clasificar ${money(flow.expense('SIN_CLASIFICAR'))}. No se confirma disponibilidad por canal.',
            size: 8,
            bold: true,
          ),
        ],
        if (calendar.undated.total > 0) ...[
          pw.SizedBox(height: 4),
          text(
            'Sin fecha (El Palomar): Efectivo ${money(calendar.undated.byType['EFECTIVO'] ?? 0)} / Fiscal ${money(calendar.undated.byType['FISCAL'] ?? 0)} / Mixto ${money(calendar.undated.byType['MIXTO'] ?? 0)}. Incluido en el total semanal; no disponible en un día específico.',
            size: 8,
          ),
        ],
        if (calendar.pressure.days.any((d) => d.elapsed)) ...[
          pw.SizedBox(height: 4),
          text(
            calendar.pressure.days.every((d) => d.elapsed)
                ? 'Semana transcurrida: no se reconstruyen saldos diarios con movimientos pendientes. Consulta el desglose y los totales semanales.'
                : 'Corte ${programDate(generatedAt)}: saldo inicial = disponible actualizado. Cobros anteriores pendientes ${money(calendar.earlier.total)}: requieren nueva fecha; pagos anteriores pendientes ${money(calendar.earlierPayments)}: se reservan desde el corte.',
            size: 8,
          ),
        ],
        pw.NewPage(),
        text('Origen y aplicación de recursos', size: 14, bold: true),
        pw.SizedBox(height: 9),
        pw.TableHelper.fromTextArray(
          headers: [
            'Concepto',
            'Efectivo',
            'Fiscal',
            'Sin distribuir',
            'Total',
          ],
          data: table,
          columnWidths: {0: const pw.FlexColumnWidth(1.8)},
          border: pw.TableBorder.all(color: line, width: 0.4),
          headerDecoration: const pw.BoxDecoration(color: green),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: pw.TextStyle(color: ink, fontSize: 10),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 8,
          ),
          oddRowDecoration: const pw.BoxDecoration(color: soft),
          cellAlignment: pw.Alignment.centerRight,
          cellAlignments: {0: pw.Alignment.centerLeft},
        ),
        pw.SizedBox(height: 14),
        text(
          !flow.plan.generated
              ? 'Falta generar la propuesta de egresos. Flujo incompleto.'
              : flow.opening == null
              ? 'Captura el saldo inicial para conocer el saldo final.'
              : flow.closing! < 0
              ? 'Faltante proyectado: ${money(-flow.closing!)}.'
              : 'Saldo total previsto al cierre: ${money(flow.closing)}.',
          bold: true,
        ),
        pw.SizedBox(height: 5),
        text(
          flow.classified
              ? 'Efectivo y Fiscal clasificados.'
              : 'Ingresos mixtos o egresos sin clasificar: falta distribuir para conocer el saldo por tipo.',
          size: 9,
        ),
        pw.SizedBox(height: 8),
        text(
          'Si la semana ya inició, el saldo inicial debe ser el disponible actualizado: aquí solo se proyectan cobros y pagos pendientes.',
          size: 8,
        ),
        pw.NewPage(),
        text('Ingresos de la semana', size: 14, bold: true),
        pw.SizedBox(height: 5),
        text(
          'Cobros pendientes de embarques y de Ventas Mayoreo, más la disposición posible de El Palomar.',
          size: 9,
        ),
        if (income.financingTotal > 0) ...[
          pw.SizedBox(height: 4),
          text(
            'El Palomar se suma una sola vez, separado por Efectivo/Fiscal, con las fechas de recepción capturadas. Los importes sin fecha quedan Por definir.',
            size: 9,
          ),
        ],
        pw.SizedBox(height: 9),
        if (report.incomes.isEmpty)
          text('Sin ingresos para incluir en esta semana.')
        else
          incomeTable,
        pw.NewPage(freeSpace: 150),
        pw.SizedBox(height: 18),
        text('Egresos de la semana', size: 14, bold: true),
        pw.SizedBox(height: 5),
        text(
          'Facturas, convenios, pagos fijos, egresos manuales y estimaciones de Menudeo incluidos. Sin detalle de tickets.',
          size: 9,
        ),
        pw.SizedBox(height: 9),
        if (flow.plan.scheduledPayments.isEmpty)
          text('Sin egresos para incluir en este reporte.')
        else
          expenseTable,
        for (final warning in plan.menudeoWarnings) ...[
          pw.SizedBox(height: 6),
          text(warning, size: 9),
        ],
      ],
    ),
  );
  return document.save();
}
