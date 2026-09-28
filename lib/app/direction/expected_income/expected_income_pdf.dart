import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/utils/number_formatters.dart';
import '../direction_shipments_store.dart';
import '../operating_program/operating_program_models.dart';
import 'expected_income_engine.dart';
import 'expected_income_models.dart';

/// One consistent snapshot of the same projection shown in Ingresos esperados.
/// The PDF never creates sales, collections, or revolving-account movements.
class ExpectedIncomePrintData {
  final DateTime week, generatedAt;
  final ExpectedIncomeProjection projection;
  final String productionSource;
  ExpectedIncomePrintData({
    required DirectionShipmentPlanningBundle bundle,
    required ExpectedIncomeData data,
    required this.generatedAt,
  }) : week = bundle.weekStartDate,
       projection = projectExpectedIncome(
         bundle: bundle,
         data: data,
         now: generatedAt,
       ),
       productionSource = data.productionSource;

  String get fileName =>
      'ingreso_proyectado_embarques_${programDate(week)}.pdf';
  List<IncomeTotals> get periods => [
    projection.current,
    projection.next,
    projection.later,
    projection.overdue,
    projection.undated,
  ];
  int period(DateTime date) => date.isBefore(week)
      ? 3
      : date.isBefore(week.add(const Duration(days: 7)))
      ? 0
      : date.isBefore(week.add(const Duration(days: 14)))
      ? 1
      : 2;
  List<int> get additionalCollections {
    final result = List.filled(5, 0);
    for (final c in projection.collections) {
      result[period(c.dueDate)] += c.pendingCents;
    }
    return result;
  }

  List<int> get shipmentCollections => [
    for (var i = 0; i < periods.length; i++)
      periods[i].salesTotal - additionalCollections[i],
  ];
  int get unvalued => projection.rows
      .where((r) => r.state != IncomeState.cancelled && r.valueCents == null)
      .length;
  int get tentative => projection.rows
      .where(
        (r) =>
            r.state != IncomeState.cancelled && r.shipment.status == 'planeado',
      )
      .length;

  List<ExpectedIncomeRow> get activeRows =>
      projection.rows.where((r) => r.state != IncomeState.cancelled).toList();
  int get bales =>
      activeRows.fold(0, (sum, r) => sum + r.shipment.plannedQuantity);
  int get cancelled => projection.rows.length - activeRows.length;
  int get missingProduction =>
      activeRows.where((r) => r.missingBales > 0).length;
  int get unreconciled => activeRows.where((r) => r.cashExcluded).length;
  List<({String material, int bales, int valueCents, int unvalued})>
  get materials => [
    for (final material in programMaterials)
      (
        material: incomeMaterialName(material),
        bales: activeRows
            .where((r) => r.shipment.materialCode == material)
            .fold(0, (sum, r) => sum + r.shipment.plannedQuantity),
        valueCents: activeRows
            .where((r) => r.shipment.materialCode == material)
            .fold(0, (sum, r) => sum + (r.valueCents ?? 0)),
        unvalued: activeRows
            .where(
              (r) =>
                  r.shipment.materialCode == material && r.valueCents == null,
            )
            .length,
      ),
  ];
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _money(int cents) => formatMoney(cents / 100);
const _ink = PdfColor.fromInt(0xff21312d);
const _accent = PdfColor.fromInt(0xff365f4c);
const _soft = PdfColor.fromInt(0xffeef3ef);
const _line = PdfColor.fromInt(0xffcbd6ce);

Future<Uint8List> buildExpectedIncomePdf(
  ExpectedIncomePrintData data, {
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
    // Keep export usable after hot reload with an older desktop asset bundle.
  }
  final document = pw.Document(
    title: 'Ingreso proyectado por embarque - ${programDate(data.week)}',
    author: 'DICSA',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final p = data.projection;
  pw.Widget text(
    String value, {
    double size = 9,
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
  pw.Widget money(int cents, {double size = 18, PdfColor color = _ink}) =>
      pw.SizedBox(
        height: size + 4,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerLeft,
          child: text(_money(cents), size: size, bold: true, color: color),
        ),
      );
  pw.Widget card(
    String title,
    int cents,
    String caption, {
    bool primary = false,
  }) => pw.Expanded(
    child: pw.Container(
      height: 79,
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: primary ? _accent : _soft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          text(
            title,
            size: 9,
            bold: true,
            color: primary ? PdfColors.white : _accent,
          ),
          pw.SizedBox(height: 8),
          money(cents, size: 20, color: primary ? PdfColors.white : _ink),
          pw.Spacer(),
          text(caption, size: 8, color: primary ? PdfColors.white : _ink),
        ],
      ),
    ),
  );
  pw.Widget panel(
    String title,
    List<pw.Widget> children, {
    required double height,
  }) => pw.Container(
    height: height,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line, width: .6),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        text(title, size: 11, bold: true, color: _accent),
        pw.SizedBox(height: 9),
        ...children,
      ],
    ),
  );
  pw.Widget line(String label, int cents, {bool total = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 3, child: text(label, size: 10, bold: total)),
        pw.Expanded(
          flex: 2,
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: text(_money(cents), size: 11, bold: total),
            ),
          ),
        ),
      ],
    ),
  );
  pw.Widget mini(String label, int cents) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        text(label, size: 9),
        pw.SizedBox(height: 6),
        money(cents, size: 16),
      ],
    ),
  );
  pw.Widget materialCell(
    String value, {
    bool heading = false,
    bool right = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Align(
      alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        child: text(value, size: 10, bold: heading),
      ),
    ),
  );
  final attention = [
    '${data.tentative} sin confirmar',
    '${data.unvalued} sin valuar',
    '${data.missingProduction} con faltante de producción',
    '${data.unreconciled} por conciliar',
    if (p.warnings.isNotEmpty) '${p.warnings.length} alertas de fuentes',
  ];
  final palomarStatus = !p.palomar.configured
      ? 'Cuenta pendiente de configurar'
      : !p.palomar.complete
      ? 'Faltan embarques por valuar'
      : p.palomar.availableDraw > 0
      ? 'Disposición estimada al cierre de la semana'
      : 'Sin disposición disponible al cierre';
  // Fixed executive layout: aggregate every shipment/account into these panels.
  // Record counts, names and notes cannot add pages or shrink the whole report.
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Image(logo, width: 40, height: 40),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text(
                      'DICSA  /  DIRECCIÓN',
                      size: 9,
                      bold: true,
                      color: _accent,
                    ),
                    pw.SizedBox(height: 3),
                    text('Ingreso proyectado semanal', size: 21, bold: true),
                    pw.SizedBox(height: 4),
                    text(
                      'Semana ${_date(data.week)} al ${_date(data.week.add(const Duration(days: 6)))}  |  Cartón en pacas  |  MXN',
                    ),
                  ],
                ),
              ),
              text(
                'RESUMEN EJECUTIVO\nGenerado ${_date(data.generatedAt)}  ${data.generatedAt.hour.toString().padLeft(2, '0')}:${data.generatedAt.minute.toString().padLeft(2, '0')}',
                size: 8,
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              card(
                'FLUJO DE ESTA SEMANA',
                p.current.total,
                'Cobros + financiamiento',
                primary: true,
              ),
              pw.SizedBox(width: 10),
              card(
                'VALOR DE EMBARQUES',
                p.generated,
                'Importe valuado; incluye El Palomar',
              ),
              pw.SizedBox(width: 10),
              card('PRÓXIMA SEMANA', p.next.total, 'Cobros previstos'),
              pw.SizedBox(width: 10),
              card('COBRADO', p.collected, 'De los embarques de esta semana'),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: text(
              'Embarques vigentes: ${data.activeRows.length}   |   Pacas: ${data.bales}   |   Cancelados excluidos: ${data.cancelled}',
              size: 9,
              bold: true,
            ),
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: panel('Origen del flujo de esta semana', [
                  line(
                    'Cobros de estos embarques',
                    data.shipmentCollections[0],
                  ),
                  line(
                    'Cobranza adicional de Mayoreo',
                    data.additionalCollections[0],
                  ),
                  line('El Palomar - financiamiento', p.current.financingTotal),
                  pw.Divider(color: _line, height: 8, thickness: .5),
                  line('Total esperado', p.current.total, total: true),
                  pw.Spacer(),
                  text(
                    'Mayoreo incluye cobros de ventas anteriores, sin duplicar cuentas vinculadas.',
                    size: 8,
                  ),
                ], height: 167),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: panel('Embarques por material', [
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(.7),
                      2: const pw.FlexColumnWidth(1.6),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          materialCell('Material', heading: true),
                          materialCell('Pacas', heading: true, right: true),
                          materialCell('Valor MXN', heading: true, right: true),
                        ],
                      ),
                      for (final m in data.materials)
                        pw.TableRow(
                          children: [
                            materialCell(m.material),
                            materialCell('${m.bales}', right: true),
                            materialCell(
                              m.unvalued == 0
                                  ? _money(m.valueCents)
                                  : m.valueCents == 0
                                  ? 'Sin valuar'
                                  : '${_money(m.valueCents)}*',
                              right: true,
                            ),
                          ],
                        ),
                    ],
                  ),
                  pw.Spacer(),
                  text(
                    'Cancelados excluidos. * Valor parcial; partidas sin precio en seguimiento.',
                    size: 8,
                  ),
                ], height: 167),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: panel('Tipo de ingreso de esta semana', [
                  pw.Row(
                    children: [
                      mini('Efectivo', p.current.byType['EFECTIVO'] ?? 0),
                      pw.SizedBox(width: 10),
                      mini('Fiscal', p.current.byType['FISCAL'] ?? 0),
                      pw.SizedBox(width: 10),
                      mini('Mixto', p.current.byType['MIXTO'] ?? 0),
                    ],
                  ),
                  pw.SizedBox(height: 13),
                  pw.Divider(color: _line, height: 1, thickness: .5),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      mini('Posterior', p.later.total),
                      pw.SizedBox(width: 10),
                      mini('Vencido previo', p.overdue.total),
                      pw.SizedBox(width: 10),
                      mini('Sin fecha / tipo', p.undated.total),
                    ],
                  ),
                ], height: 148),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: panel('El Palomar - cuenta revolvente', [
                  pw.Row(
                    children: [
                      mini('Saldo al cierre', p.palomar.closing),
                      pw.SizedBox(width: 10),
                      mini('Disposición posible', p.palomar.availableDraw),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  text(palomarStatus, size: 8, bold: true),
                  pw.Spacer(),
                  text(
                    'Las remisiones reducen el saldo. La disposición ya está incluida en el flujo semanal.',
                    size: 8,
                  ),
                ], height: 148),
              ),
            ],
          ),
          pw.Spacer(),
          text('Seguimiento: ${attention.join('  |  ')}.', size: 8),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              text(
                'Proyección sujeta a embarque y cobro. Detalle disponible en Ingresos esperados.',
                size: 8,
              ),
              text('1 / 1', size: 8),
            ],
          ),
        ],
      ),
    ),
  );
  return document.save();
}
