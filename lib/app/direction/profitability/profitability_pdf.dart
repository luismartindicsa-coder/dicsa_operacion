import 'dart:convert';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'profitability_models.dart';
import 'profitability_account_models.dart';
import '../../shared/utils/number_formatters.dart';

const _blue = PdfColor.fromInt(0xff17365d);
const _cyan = PdfColor.fromInt(0xff31a9c6);
const _ink = PdfColor.fromInt(0xff253343);
const _muted = PdfColor.fromInt(0xff596778);
const _line = PdfColor.fromInt(0xffd4dde4);
const _light = PdfColor.fromInt(0xfff1f5f8);
String _money(double n) => formatMoney(n);
String _qty(double n) => formatDecimal(n, decimals: 1);
String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _clean(String s) => s
    .replaceAll(RegExp('[\u2010-\u2015\u2212]'), '-')
    .replaceAll('→', 'a')
    .replaceAll(RegExp('[“”]'), '"')
    .replaceAll('×', 'x');
bool _cost(ProfitRow c) =>
    !['value', 'income', 'overhead'].contains(c['block']);
double _sum(Iterable<ProfitRow> rows) =>
    rows.fold(0.0, (s, r) => s + (profitNumber(r['amount']) ?? 0));
List<ProfitRow> _rows(Object? value) => (value as List? ?? [])
    .map((r) => Map<String, dynamic>.from(r as Map))
    .toList();

/// Freeze the selected account and period from the displayed analysis. Export
/// never queries/recalculates a different period or includes other companies.
class ProfitabilityPdfData {
  final String companyKey, companyName;
  final ProfitPeriod period;
  final DateTime readAt, generatedAt;
  final ProfitRow account;
  final double globalUnclassifiedCosts;
  ProfitabilityPdfData._(
    this.companyKey,
    this.companyName,
    this.period,
    this.readAt,
    this.generatedAt,
    this.account,
    this.globalUnclassifiedCosts,
  );

  factory ProfitabilityPdfData(
    ProfitAnalysis analysis,
    String companyKey, {
    DateTime? generatedAt,
  }) {
    if (!analysis.inferOperations) {
      throw StateError('Abre el análisis operativo antes de generar el PDF.');
    }
    return ProfitabilityPdfData.fromSnapshot(
      analysis.snapshot(),
      companyKey,
      generatedAt: generatedAt,
    );
  }

  factory ProfitabilityPdfData.fromSnapshot(
    ProfitRow snapshot,
    String companyKey, {
    DateTime? generatedAt,
  }) {
    final selected = _rows(
      snapshot['companies'],
    ).where((r) => r['key'] == companyKey).toList();
    final start = profitDate(snapshot['start']),
        end = profitDate(snapshot['end']);
    final readAt = DateTime.tryParse(profitText(snapshot['read_at']));
    if (selected.length != 1 ||
        selected.single['account'] is! Map ||
        start == null ||
        end == null ||
        end.isBefore(start) ||
        readAt == null) {
      throw StateError(
        'Selecciona una empresa con análisis operativo y periodo válidos.',
      );
    }
    final account = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(selected.single['account'])) as Map,
    );
    final data = ProfitabilityPdfData._(
      companyKey,
      profitText(selected.single['name']),
      ProfitPeriod(start, end),
      readAt.toLocal(),
      generatedAt ?? DateTime.now(),
      account,
      profitNumber(
            (snapshot['reporting_scope'] as Map?)?['unclassified_costs'],
          ) ??
          0,
    );
    data._validate();
    return data;
  }

  List<ProfitRow> get lines => _rows(account['lines']);
  Iterable<ProfitRow> get components =>
      lines.expand((l) => _rows(l['components']));
  List<ProfitRow> get materialLines => lines
      .where(
        (l) =>
            number(l, 'kg') > 0 ||
            number(l, 'services') > 0 ||
            number(l, 'value') + number(l, 'income') > 0,
      )
      .toList();
  double number(ProfitRow r, String key) => profitNumber(r[key]) ?? 0;
  double get generated => number(account, 'generated');
  double get costs => number(account, 'costs');
  double get contribution => number(account, 'contribution');
  double get sharedSupport =>
      _sum(components.where((c) => c['shared_support'] == true && _cost(c)));
  double get materialCosts =>
      materialLines.fold(0, (s, r) => s + number(r, 'costs'));
  double get companyCosts => costs - materialCosts;
  double block(String block) =>
      _sum(components.where((c) => c['block'] == block));
  double sourceAmount(String block, String type) => _sum(
    components.where((c) => c['block'] == block && c['source_type'] == type),
  );
  double get estimatedCost => _sum(
    components.where((c) => _cost(c) && c['source_type'] == 'estimated'),
  );
  String get periodLabel => '${_date(period.start)} al ${_date(period.end)}';
  String get fileName {
    var name = profitKey(companyName)
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp('[^A-Z0-9]+'), '_')
        .replaceAll(RegExp('^_+|_+\$'), '')
        .toLowerCase();
    if (name.isEmpty) name = 'empresa';
    if (name.length > 80) name = name.substring(0, 80);
    return 'rentabilidad_${name}_${profitDateText(period.start)}_${profitDateText(period.end)}.pdf';
  }

  void _validate() {
    for (final key in [
      'generated',
      'costs',
      'contribution',
      'kg',
      'services',
      'kilometers',
      'containers',
    ]) {
      if (profitNumber(account[key]) == null) {
        throw StateError('El análisis contiene un total inválido: $key.');
      }
    }
    for (final c in components) {
      if (profitNumber(c['amount']) == null ||
          number(c, 'amount') < 0 ||
          !profitAccountBlocks.containsKey(c['block']) ||
          !['actual', 'allocated', 'estimated'].contains(c['source_type'])) {
        throw StateError('No se puede exportar un componente sin cuantificar.');
      }
    }
    void reconciles(double x, double y) {
      if ((x - y).abs() > .011) {
        throw StateError(
          'Los totales del PDF no concilian con el análisis seleccionado.',
        );
      }
    }

    for (final l in lines) {
      if ([
        'costs',
        'value',
        'income',
        'kg',
        'services',
        'contribution',
      ].any((k) => profitNumber(l[k]) == null)) {
        throw StateError('Línea incompleta para exportar.');
      }
      reconciles(number(l, 'costs'), _sum(_rows(l['components']).where(_cost)));
      for (final block in ['value', 'income']) {
        reconciles(
          number(l, block),
          _sum(_rows(l['components']).where((c) => c['block'] == block)),
        );
      }
      reconciles(
        number(l, 'contribution'),
        number(l, 'value') + number(l, 'income') - number(l, 'costs'),
      );
    }
    reconciles(generated, block('value') + block('income'));
    reconciles(costs, _sum(components.where(_cost)));
    reconciles(contribution, generated - costs);
  }

  /// Repeated per-day allocations share one basis entry. Raw employee IDs and
  /// hashes are never printed. Long ticket lists become explicit source counts.
  List<({String basis, double amount, int entries})> bases(String block) {
    final groups = <String, ({double amount, int entries})>{};
    for (final c in components.where(
      (c) => c['block'] == block && number(c, 'amount') > 0,
    )) {
      final type = switch (c['source_type']) {
        'actual' => 'Registrado',
        'allocated' => 'Repartido',
        _ => 'Estimado',
      };
      final basis =
          '$type. ${profitPdfReadableBasis(profitText(c['calculation_rule']))}';
      final old = groups[basis];
      groups[basis] = (
        amount: (old?.amount ?? 0) + number(c, 'amount'),
        entries: (old?.entries ?? 0) + 1,
      );
    }
    return [
      for (final e in groups.entries)
        (basis: e.key, amount: e.value.amount, entries: e.value.entries),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
  }
}

String profitPdfReadableBasis(String raw) {
  var text = raw.replaceAllMapped(
    RegExp(
      r'(?:men|compras|intake):[A-Za-z0-9_-]+(?:,(?:men|compras|intake):[A-Za-z0-9_-]+)*',
    ),
    (m) => '${m[0]!.split(',').length} registro(s) comparable(s)',
  );
  text = text.replaceAll(RegExp(r'\b[0-9a-f]{64}\b'), '');
  text = text.replaceAllMapped(
    RegExp(r'\d+\.\d{5,}'),
    (m) => double.parse(m[0]!).toStringAsFixed(4),
  );
  return _clean(text).replaceAll(RegExp(r'\s+'), ' ').trim();
}

Future<Uint8List> buildProfitabilityPdf(
  ProfitabilityPdfData data, {
  AssetBundle? assetBundle,
}) async {
  final assets = assetBundle ?? rootBundle;
  final bytes = await assets.load('assets/images/logo_dicsa.png');
  final logo = pw.MemoryImage(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  var regular = pw.Font.helvetica(), bold = pw.Font.helveticaBold();
  try {
    regular = pw.Font.ttf(await assets.load('assets/fonts/Roboto-Regular.ttf'));
    bold = pw.Font.ttf(await assets.load('assets/fonts/Roboto-Bold.ttf'));
  } on FlutterError {
    // Standard PDF fonts preserve offline export in an older asset manifest.
  }
  final doc = pw.Document(
    title:
        'Análisis integral de costos y rentabilidad - ${data.companyName} - ${data.periodLabel}',
    author: 'Desperdicios Industriales Celaya, S.A. de C.V.',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  pw.Widget text(
    String s, {
    double size = 10,
    bool bold = false,
    PdfColor color = _ink,
  }) => pw.Text(
    _clean(s),
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
      lineSpacing: 2,
    ),
  );
  pw.Widget paragraph(String s) =>
      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 9), child: text(s));
  pw.Widget section(String s) => pw.Header(
    level: 1,
    title: s,
    margin: const pw.EdgeInsets.only(top: 18, bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _cyan, width: 1)),
    ),
    child: pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: text(s, size: 15, bold: true, color: _blue),
    ),
  );
  pw.Table table(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
    bool lastTotal = false,
  }) => pw.Table(
    columnWidths: widths,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: .4),
      bottom: pw.BorderSide(color: _line, width: .6),
    ),
    children: [
      for (var row = -1; row < rows.length; row++)
        pw.TableRow(
          repeat: row == -1,
          decoration: pw.BoxDecoration(
            color: row == -1
                ? _blue
                : lastTotal && row == rows.length - 1
                ? _light
                : PdfColors.white,
          ),
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            for (var col = 0; col < headers.length; col++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 7,
                ),
                child: pw.Align(
                  alignment: col == 0
                      ? pw.Alignment.centerLeft
                      : pw.Alignment.centerRight,
                  child: text(
                    (row == -1 ? headers : rows[row])[col],
                    size: 9,
                    bold: row == -1 || lastTotal && row == rows.length - 1,
                    color: row == -1 ? PdfColors.white : _ink,
                  ),
                ),
              ),
          ],
        ),
    ],
  );
  pw.Widget costs(List<String> blocks) => pw.Inseparable(
    child: table(
      ['Concepto', 'Registrado', 'Repartido', 'Estimado', 'Total'],
      [
        for (final block in blocks)
          [
            profitAccountBlocks[block]!,
            for (final type in ['actual', 'allocated', 'estimated'])
              _money(data.sourceAmount(block, type)),
            _money(data.block(block)),
          ],
      ],
      widths: {
        0: const pw.FlexColumnWidth(2.4),
        for (var i = 1; i < 5; i++) i: const pw.FlexColumnWidth(1),
      },
    ),
  );
  pw.Widget statement(List<List<String>> rows) => pw.Inseparable(
    child: table(
      ['Concepto', 'Importe MXN'],
      rows,
      widths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.2),
      },
      lastTotal: true,
    ),
  );
  final materials = data.materialLines;
  final account = data.account;
  final purchaseInferred = data.sourceAmount('purchase', 'estimated');

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _blue, width: 2),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _cyan, width: .8),
          ),
          padding: const pw.EdgeInsets.all(36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 24),
              pw.Image(logo, width: 230, height: 130, fit: pw.BoxFit.contain),
              pw.SizedBox(height: 36),
              pw.Text(
                'Análisis integral de costos y rentabilidad',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 30,
                  fontWeight: pw.FontWeight.bold,
                  color: _blue,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Desperdicios Industriales Celaya, S.A. de C.V.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 13, color: _muted),
              ),
              pw.Spacer(),
              pw.Text(
                _clean(data.companyName),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 23,
                  fontWeight: pw.FontWeight.bold,
                  color: _blue,
                ),
              ),
              pw.SizedBox(height: 12),
              text('Periodo: ${data.periodLabel}', size: 12),
              pw.SizedBox(height: 28),
              text('Análisis operativo para Dirección', size: 11, bold: true),
              if (data.globalUnclassifiedCosts > 0)
                text(
                  'Resultado provisional: importes globales por conciliar',
                  size: 10,
                  bold: true,
                ),
              text('Elaborado el ${_date(data.generatedAt)}', color: _muted),
              pw.SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
  final theme = pw.PageTheme(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.fromLTRB(56, 45, 56, 45),
    buildBackground: (_) => pw.Center(
      child: pw.Opacity(opacity: .035, child: pw.Image(logo, width: 360)),
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageTheme: theme,
      maxPages: 250,
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: text(data.companyName, size: 9, bold: true, color: _blue),
            ),
            pw.SizedBox(width: 10),
            text(data.periodLabel, size: 8, color: _muted),
          ],
        ),
      ),
      footer: (c) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            text(
              'DICSA | Rentabilidad operativa | Uso interno',
              size: 8,
              color: _muted,
            ),
            text('${c.pageNumber} / ${c.pagesCount}', size: 8, color: _muted),
          ],
        ),
      ),
      build: (_) => [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: text(
            'Celaya, Guanajuato, ${_date(data.generatedAt)}',
            color: _muted,
          ),
        ),
        section('1. Alcance y resultado del periodo'),
        paragraph(
          'Este documento presenta los materiales y servicios asociados a ${data.companyName}, sus costos de atención y el aporte a DICSA para el periodo seleccionado. Consolida Compras, Ventas, RH, Logística, Finanzas y entradas físicas. Los importes corresponden a la misma lectura de la pantalla, realizada el ${_date(data.readAt)} a las ${data.readAt.hour.toString().padLeft(2, '0')}:${data.readAt.minute.toString().padLeft(2, '0')}. Se expresan en pesos mexicanos.',
        ),
        statement([
          ['Valor recuperable del material', _money(data.block('value'))],
          ['Ingresos por servicios', _money(data.block('income'))],
          ['Total generado', _money(data.generated)],
          ['Costo total de la cuenta', _money(data.costs)],
          ['APORTE OPERATIVO DEL PERIODO', _money(data.contribution)],
        ]),
        pw.SizedBox(height: 10),
        paragraph(
          'El valor recuperable se estima con ventas comparables y la recuperación aplicada por el modelo. No equivale necesariamente a una venta realizada. Los importes se presentan según las fuentes; este reporte no calcula utilidad contable ni normaliza el tratamiento fiscal.',
        ),
        if (data.sharedSupport > 0) ...[
          statement([
            [
              'Aporte antes del soporte compartido',
              _money(data.contribution + data.sharedSupport),
            ],
            [
              'Soporte compartido incluido en el costo total',
              _money(data.sharedSupport),
            ],
            ['Aporte después del reparto', _money(data.contribution)],
          ]),
          pw.SizedBox(height: 7),
          paragraph(
            'El soporte compartido ya forma parte del costo total. Este puente explica el resultado; no agrega otro cargo. Su asignación no implica que todo ese costo desaparezca al dejar de atender la cuenta.',
          ),
        ],
        pw.NewPage(freeSpace: 260),
        section('2. Materiales y servicios atendidos'),
        paragraph(
          '${_qty(data.number(account, 'kg'))} kg de material, ${_qty(data.number(account, 'services'))} servicios y ${_qty(data.number(account, 'kilometers'))} km atribuidos en el periodo.',
        ),
        if (materials.isEmpty)
          paragraph(
            'Sin volumen o ingresos atribuidos a líneas de material en el periodo seleccionado.',
          )
        else
          table(
            [
              'Material / servicio',
              'Kg',
              'Genera',
              'Costos atribuidos',
              'Aporte',
            ],
            [
              for (final l in materials)
                [
                  profitText(l['label']),
                  _qty(data.number(l, 'kg')),
                  _money(data.number(l, 'value') + data.number(l, 'income')),
                  _money(data.number(l, 'costs')),
                  _money(data.number(l, 'contribution')),
                ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(1.7),
              1: const pw.FlexColumnWidth(.85),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
            },
          ),
        pw.SizedBox(height: 10),
        statement([
          [
            'Costos atribuidos a materiales y servicios',
            _money(data.materialCosts),
          ],
          ['Costos que permanecen a nivel empresa', _money(data.companyCosts)],
          ['COSTO TOTAL (incluye ambas partes una vez)', _money(data.costs)],
        ]),
        pw.NewPage(freeSpace: 175),
        section('3. Compra y valoración del material'),
        paragraph(
          'Los costos atribuidos incluyen la compra del material y los gastos de atención distribuidos a esa línea. Los siguientes rubros explican esos mismos costos; no se suman de nuevo al total.',
        ),
        costs(['purchase']),
        if (purchaseInferred > 0) ...[
          pw.SizedBox(height: 8),
          paragraph(
            '${_money(purchaseInferred)} de la compra es estimada. Se infiere para cantidades sin compra conciliada o sin precio registrado, con las bases comparables disponibles. No acredita un pago efectuado a esta empresa.',
          ),
        ],
        if (materials.any(
          (l) => data.number(l, 'kg') > 0 && data.number(l, 'value') == 0,
        )) ...[
          pw.SizedBox(height: 8),
          paragraph(
            'Materiales con recuperación modelada en cero: ${materials.where((l) => data.number(l, 'kg') > 0 && data.number(l, 'value') == 0).map((l) => '${l['label']} (${_qty(data.number(l, 'kg'))} kg)').join('; ')}. Su retiro, compra y disposición pueden generar costos aun cuando el modelo no reconozca valor de venta.',
          ),
        ],
        pw.NewPage(freeSpace: 180),
        section('4. Personal operativo y soporte compartido'),
        paragraph(
          'RH aporta la nómina publicada y las referencias de remuneración para días sin cierre. El personal dedicado se atribuye a la planta; el reparto del personal común se detalla en las bases del cálculo. Se presentan importes agregados.',
        ),
        costs(['payroll', 'administration']),
        pw.NewPage(freeSpace: 225),
        section('5. Logística, combustible y mantenimiento'),
        paragraph(
          'Los gastos se asignan mediante la actividad disponible: km, servicios y kg. El combustible puede usar litros despachados como aproximación al consumo. El historial complementa solo la diferencia pendiente respecto del gasto actual comparable, respetando su cobertura y atribución.',
        ),
        costs(['fuel', 'transport', 'process', 'maintenance']),
        pw.NewPage(freeSpace: 235),
        section('6. Equipo, residuos y servicios complementarios'),
        paragraph(
          'Contenedores atribuidos: ${_qty(data.number(account, 'containers'))}. Los cobros por recolección de residuos son ingresos; la disposición en relleno es un costo. Se mantienen separados en el resultado.',
        ),
        costs(['containers', 'disposal', 'scale', 'training', 'other']),
        pw.NewPage(freeSpace: 460),
        section('7. Resumen integral de costos'),
        paragraph(
          'Desglose del costo total ya mostrado en el resultado. Registrado = importe directo; repartido = documento distribuido; estimado = tarifa, promedio o inferencia. La base del reparto también puede ser estimada. Los ceros indican que el modelo no aplicó un cargo y no acreditan gratuidad.',
        ),
        statement([
          for (final b in profitAccountBlocks.entries)
            if (!['value', 'income', 'overhead'].contains(b.key))
              [b.value, _money(data.block(b.key))],
          ['TOTAL DE COSTOS DEL PERIODO', _money(data.costs)],
        ]),
        if (data.block('overhead') > 0) ...[
          pw.SizedBox(height: 9),
          statement([
            ['Estructura adicional', _money(data.block('overhead'))],
            [
              'Aporte después de estructura adicional',
              _money(data.contribution - data.block('overhead')),
            ],
          ]),
        ],
        pw.NewPage(freeSpace: 155),
        section('8. Lectura operativa'),
        if (data.globalUnclassifiedCosts > 0)
          paragraph(
            'Resultado provisional: hay ${_money(data.globalUnclassifiedCosts)} pendientes de clasificar en toda la operación. Se conservan en la conciliación global y no están repartidos entre empresas. No representan un cargo confirmado a esta cuenta; aclarar su concepto puede modificar el reparto.',
          ),
        paragraph(
          data.generated == 0
              ? 'No hay ingreso o recuperación atribuidos. Es necesario revisar esa cobertura antes de concluir sobre la conveniencia de la cuenta.'
              : data.contribution >= 0
              ? 'La cuenta presenta un aporte estimado de ${_money(data.contribution)} después de los costos y del soporte asignado. La conclusión depende de las referencias de recuperación, precios y reparto utilizadas.'
              : data.contribution + data.sharedSupport > 0
              ? 'La cuenta cubre los costos previos al soporte compartido, pero presenta un déficit de ${_money(-data.contribution)} después de ese reparto. Revisar condiciones de atención y asignación de estructura antes de decidir sobre su continuidad.'
              : 'El modelo presenta un déficit operativo de ${_money(-data.contribution)}. Conviene revisar precios, recuperación y recursos consumidos para identificar la compensación necesaria.',
        ),
        paragraph(
          '${_money(data.estimatedCost)} del costo total utiliza estimaciones. Las comparaciones por periodos cortos pueden cambiar por diferencias de fechas entre entradas, compras, nómina y pagos.',
        ),
        if (materials.any((l) => data.number(l, 'contribution') < 0)) ...[
          table(
            ['Línea con déficit', 'Importe por recuperar', 'Adicional por kg'],
            [
              for (final l in materials.where(
                (l) => data.number(l, 'contribution') < 0,
              ))
                [
                  profitText(l['label']),
                  _money(-data.number(l, 'contribution')),
                  data.number(l, 'kg') > 0
                      ? _money(
                          -data.number(l, 'contribution') /
                              data.number(l, 'kg'),
                        )
                      : 'No aplica',
                ],
            ],
          ),
          pw.SizedBox(height: 8),
          paragraph(
            'Este equilibrio corresponde a los costos atribuidos a cada línea. Los costos que permanecen a nivel empresa se consideran en el resultado total.',
          ),
        ],
        pw.NewPage(freeSpace: 200),
        section('9. Bases principales del cálculo'),
        paragraph(
          'Las bases se agrupan por fórmula. Se muestran las tres de mayor importe por rubro y el resto cuantificado. Los conceptos de esta sección respaldan los totales anteriores y no representan cargos adicionales. El detalle completo está en “Cómo se calculó” y en la exportación de bases de la app.',
        ),
        for (final block in profitAccountBlocks.keys.where(
          (b) => data.block(b) > 0,
        ))
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
                  child: text(
                    '${profitAccountBlocks[block]}: ${_money(data.block(block))}',
                    bold: true,
                    color: _blue,
                  ),
                ),
                for (final basis in data.bases(block).take(3))
                  paragraph(
                    '${_money(basis.amount)} | ${basis.entries} componente(s). ${basis.basis}',
                  ),
                if (data.bases(block).length > 3)
                  paragraph(
                    'Otras ${data.bases(block).length - 3} bases: ${_money(data.bases(block).skip(3).fold<double>(0, (s, b) => s + b.amount))}. Incluidas en el total de este rubro.',
                  ),
              ],
            ),
          ),
        pw.SizedBox(height: 20),
        text('Elaborado por Dirección - DICSA', bold: true, color: _blue),
      ],
    ),
  );
  return doc.save();
}
