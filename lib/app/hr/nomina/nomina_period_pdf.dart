part of '../human_resources_nomina_page.dart';

/// Period report presentation only. Payroll models, handlers and amounts remain
/// owned by Nómina; the report never replaces their final calculated values.
Future<Uint8List> _buildHrNominaPeriodReportPdf({
  required List<_HrNominaSummaryRow> rows,
  required _HrNominaMetrics metrics,
  required String periodLabel,
  required DateTime generatedAt,
  required bool isPeriodClosed,
}) async {
  pw.MemoryImage? logo;
  try {
    final bytes = await rootBundle.load('assets/images/logo_dicsa.png');
    logo = pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {
    // All report data remains readable without the optional brand asset.
  }
  return _HrNominaPeriodPdf(
    rows: rows,
    metrics: metrics,
    period: periodLabel,
    emittedAt: generatedAt,
    closed: isPeriodClosed,
    logo: logo,
  ).build();
}

class _HrNominaPdfPalette {
  static final purple = PdfColor.fromHex('#3B1F5C');
  static final lavender = PdfColor.fromHex('#F3EDFF');
  static final ink = PdfColor.fromHex('#24143D');
  static final muted = PdfColor.fromHex('#685B79');
  static final rule = PdfColor.fromHex('#DCD5E6');
  static final stripe = PdfColor.fromHex('#F8F7FA');
  static final green = PdfColor.fromHex('#28664C');
  static final greenSoft = PdfColor.fromHex('#F0F6F2');
  static final red = PdfColor.fromHex('#983B45');
}

class _HrNominaPeriodPdf {
  final List<_HrNominaSummaryRow> rows;
  final _HrNominaMetrics metrics;
  final String period;
  final DateTime emittedAt;
  final bool closed;
  final pw.MemoryImage? logo;

  const _HrNominaPeriodPdf({
    required this.rows,
    required this.metrics,
    required this.period,
    required this.emittedAt,
    required this.closed,
    required this.logo,
  });

  String get shortPeriod => period.split(' · ').first;
  bool get allInformational =>
      rows.isNotEmpty && rows.every((r) => r.incidencesInformational);
  double sum(double Function(_HrNominaSummaryRow) field) =>
      rows.fold(0, (total, row) => total + field(row));
  // Same display expression as the original report's "Fiscal base" column.
  double fiscalOrigin(_HrNominaSummaryRow r) =>
      r.fiscalAmount +
      (r.incidencesInformational ? 0 : r.fiscalLateDeductionAmount);
  double bonus(_HrNominaSummaryRow r) =>
      r.overtimeMonetizedAmount + r.manualBonusAmount;
  bool equalMoney(double a, double b) => (a * 100).round() == (b * 100).round();

  pw.TextStyle style({double size = 9, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? _HrNominaPdfPalette.ink,
      );

  Future<Uint8List> build() async {
    final document = pw.Document(
      title: 'Desglose de nómina $period',
      author: 'DICSA - Recursos Humanos',
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            executiveHeader(),
            pw.SizedBox(height: 16),
            summary(),
            pw.SizedBox(height: 16),
            reconciliation(),
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 6, child: flowComposition()),
                pw.SizedBox(width: 22),
                pw.Expanded(flex: 5, child: validation()),
              ],
            ),
            pw.Spacer(),
            pw.Text(
              closed
                  ? 'Documento generado a partir del cierre confirmado de Prenómina. Los importes corresponden al estado de la corrida al momento de su emisión.'
                  : 'Documento preliminar generado desde Nómina. El periodo todavía no tiene cierre confirmado en Prenómina. Los importes corresponden al momento de su emisión.',
              style: style(size: 8, color: _HrNominaPdfPalette.muted),
            ),
            pw.SizedBox(height: 12),
            footer(context),
          ],
        ),
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 20),
        // Automatic pagination; guard scales with the source population.
        maxPages: 20 + rows.length,
        header: (_) => runningHeader(),
        footer: footer,
        build: (_) => [
          sectionTitle(
            'RESUMEN POR COLABORADOR',
            'Fiscal, distribución y flujo neto. Las deducciones mostradas ya están incluidas en el flujo.',
          ),
          employeeSummaryTable(),
          pw.NewPage(freeSpace: 120),
          sectionTitle(
            'ANEXO A · DESGLOSE FISCAL',
            'Distribución fiscal por colaborador. Fiscal de origen conserva el valor antes denominado Fiscal base; no es el salario contractual.',
          ),
          note(
            allInformational
                ? 'El neto fiscal conserva los descuentos de su fuente fiscal. Las incidencias de retardo son informativas y no se descuentan nuevamente.'
                : 'Las incidencias informativas no se descuentan nuevamente. En los registros sin ese indicador, el efecto del retardo ya está incluido en el neto fiscal mostrado.',
          ),
          fiscalAppendix(),
          pw.NewPage(freeSpace: 120),
          sectionTitle(
            'ANEXO B · DESGLOSE DE FLUJO',
            'Componentes operativos fuera del fiscal. Flujo neto conserva las deducciones y los ajustes del modelo existente.',
          ),
          note(
            'ISR operativo se detalla también en el anexo C como parte de las deducciones; no se aplica dos veces. Pago fuera se presenta por separado en el resumen.',
          ),
          flowAppendix(),
          pw.NewPage(freeSpace: 120),
          sectionTitle(
            'ANEXO C · DEDUCCIONES',
            'Deducciones RH / Flujo. INFONAVIT y FONACOT corresponden a conceptos operativos, no a descuentos fiscales de origen.',
          ),
          note(
            allInformational
                ? 'Faltas informadas es una referencia y no forma parte del total de deducciones. No se vuelven a incluir descuentos contenidos en el neto fiscal.'
                : 'Las faltas marcadas con (ref.) son informativas y no forman parte del total de deducciones. Las demás conservan su aplicación original.',
          ),
          deductionsAppendix(),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget executiveHeader() {
    final range = HumanResourcesPeriodRange.tryParse(period);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            if (logo != null) ...[
              pw.Image(logo!, width: 36, height: 36),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DICSA', style: style(size: 16, bold: true)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Desperdicios Industriales Celaya, S.A. de C.V.',
                    style: style(size: 9, color: _HrNominaPdfPalette.muted),
                  ),
                ],
              ),
            ),
            pw.Text('RECURSOS HUMANOS', style: style(size: 8, bold: true)),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'NÓMINA · CIERRE DEL PERIODO',
          style: style(size: 22, bold: true, color: _HrNominaPdfPalette.purple),
        ),
        pw.SizedBox(height: 9),
        pw.Container(height: 2, color: _HrNominaPdfPalette.purple),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: meta(
                'PERIODO',
                range == null
                    ? period
                    : '$shortPeriod\nInicio ${_nominaDate(range.start)} · Fin ${_nominaDate(range.end)}',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 3,
              child: meta(
                'ESTADO',
                closed ? 'Cierre confirmado' : 'Vista preliminar',
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: meta('EMISIÓN', _hrNominaPdfDate(emittedAt)),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget meta(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: style(size: 7.5, bold: true, color: _HrNominaPdfPalette.muted),
      ),
      pw.SizedBox(height: 4),
      pw.Text(value, style: style(size: 9)),
    ],
  );

  pw.Widget metric(
    String label,
    String value, {
    bool total = false,
    bool flow = false,
  }) => pw.Container(
    height: 66,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: total
          ? _HrNominaPdfPalette.lavender
          : flow
          ? _HrNominaPdfPalette.greenSoft
          : _HrNominaPdfPalette.stripe,
      borderRadius: pw.BorderRadius.circular(5),
      border: total
          ? pw.Border.all(color: _HrNominaPdfPalette.purple, width: .8)
          : null,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(label, style: style(size: 7.5, bold: true)),
        pw.SizedBox(height: 8),
        pw.Text(
          value,
          style: style(
            size: total ? 19 : 15,
            bold: true,
            color: flow
                ? _HrNominaPdfPalette.green
                : _HrNominaPdfPalette.purple,
          ),
        ),
      ],
    ),
  );

  pw.Widget summary() => pw.Column(
    children: [
      pw.Row(
        children: [
          pw.Expanded(
            flex: 8,
            child: metric('COLABORADORES', '${metrics.rows}'),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            flex: 10,
            child: metric('FISCAL', _fmtHrNominaMoney(metrics.fiscal)),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            flex: 10,
            child: metric(
              'FLUJO',
              _fmtHrNominaMoney(metrics.operationalCash),
              flow: true,
            ),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            flex: 13,
            child: metric(
              'TOTAL A PAGAR',
              _fmtHrNominaMoney(metrics.total),
              total: true,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 13),
      pw.Row(
        children: [
          pw.Expanded(
            child: meta(
              'DEPÓSITO FISCAL',
              _fmtHrNominaMoney(metrics.fiscalDeposited),
            ),
          ),
          pw.Expanded(
            child: meta('CHEQUE FISCAL', _fmtHrNominaMoney(metrics.fiscalCash)),
          ),
          pw.Expanded(
            child: meta('PAGO FUERA', _fmtHrNominaMoney(metrics.outside)),
          ),
          pw.Expanded(
            child: meta(
              'DEDUCCIONES RH / FLUJO',
              _fmtHrNominaMoney(metrics.deductions),
            ),
          ),
        ],
      ),
    ],
  );

  pw.Widget reconciliation() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      equation('CONCILIACIÓN FISCAL', [
        ('Depósito fiscal', metrics.fiscalDeposited),
        ('Cheque fiscal', metrics.fiscalCash),
        ('TOTAL FISCAL', metrics.fiscal),
      ]),
      pw.SizedBox(height: 10),
      equation('CONCILIACIÓN TOTAL', [
        ('Fiscal', metrics.fiscal),
        ('Flujo', metrics.operationalCash),
        ('Pago fuera', metrics.outside),
        ('TOTAL A PAGAR', metrics.total),
      ]),
      pw.SizedBox(height: 7),
      pw.Text(
        'El cheque es fiscal entregado en efectivo. No se suma otra vez al flujo ni al total.',
        style: style(size: 8, color: _HrNominaPdfPalette.muted),
      ),
    ],
  );

  pw.Widget equation(
    String title,
    List<(String, double)> terms,
  ) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _HrNominaPdfPalette.rule, width: .6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: style(size: 8, bold: true, color: _HrNominaPdfPalette.purple),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            for (var i = 0; i < terms.length; i++) ...[
              if (i > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                  child: pw.Text(
                    i == terms.length - 1 ? '=' : '+',
                    style: style(size: 14, color: _HrNominaPdfPalette.muted),
                  ),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      terms[i].$1,
                      style: style(size: 7.5, bold: i == terms.length - 1),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _fmtHrNominaMoney(terms[i].$2),
                      style: style(size: 12, bold: i == terms.length - 1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  pw.Widget flowComposition() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        'COMPOSICIÓN DEL FLUJO',
        style: style(size: 11, bold: true, color: _HrNominaPdfPalette.purple),
      ),
      pw.SizedBox(height: 7),
      amountLine('Sueldo flujo', sum((r) => r.cashSalaryAmount)),
      amountLine('Vacaciones flujo', sum((r) => r.cashVacationAmount)),
      amountLine('Transporte', sum((r) => r.transportSupportAmount)),
      amountLine('Festivo', sum((r) => r.holidayAmount)),
      amountLine('Bonos y horas extra', sum(bonus)),
      amountLine('Ajustes RH', sum((r) => r.manualAdjustmentAmount)),
      pw.Divider(color: _HrNominaPdfPalette.rule, height: 8),
      amountLine('Percepciones flujo', metrics.complements, bold: true),
      amountLine('Deducciones RH / Flujo', -metrics.deductions),
      pw.Divider(color: _HrNominaPdfPalette.rule, height: 8),
      amountLine('FLUJO NETO', metrics.operationalCash, bold: true, size: 12),
    ],
  );

  pw.Widget amountLine(
    String label,
    double amount, {
    bool bold = false,
    double size = 9,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: style(size: size, bold: bold),
          ),
        ),
        pw.Text(
          _fmtHrNominaMoney(amount),
          style: style(
            size: size,
            bold: bold,
            color: amount < 0 ? _HrNominaPdfPalette.red : null,
          ),
        ),
      ],
    ),
  );

  pw.Widget validation() {
    final fiscalOk =
        equalMoney(
          metrics.fiscalDeposited + metrics.fiscalCash,
          metrics.fiscal,
        ) &&
        rows.every(
          (r) => equalMoney(
            r.fiscalDepositedAmount + r.fiscalCashAmount,
            r.fiscalAmount,
          ),
        );
    final totalOk =
        equalMoney(
          metrics.fiscal + metrics.operationalCash + metrics.outside,
          metrics.total,
        ) &&
        rows.every(
          (r) => equalMoney(
            r.fiscalAmount + r.operationalCashAmount + r.paymentOutsideAmount,
            r.totalAmount,
          ),
        );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'VALIDACIONES',
          style: style(size: 11, bold: true, color: _HrNominaPdfPalette.purple),
        ),
        pw.SizedBox(height: 10),
        validationLine(fiscalOk, 'Depósito + cheque = fiscal'),
        validationLine(totalOk, 'Fiscal + flujo + pago fuera = total'),
        validationLine(
          closed,
          closed
              ? 'Periodo cerrado desde Prenómina'
              : 'Periodo sin cierre confirmado',
        ),
        validationLine(
          metrics.rows == rows.length,
          '${rows.length} colaboradores incluidos',
        ),
        validationLine(true, 'Importes expresados en MXN'),
        pw.SizedBox(height: 10),
        pw.Text(
          'Los importes finales provienen de la corrida existente. Estas comprobaciones no aplican ajustes ni deducciones.',
          style: style(size: 8, color: _HrNominaPdfPalette.muted),
        ),
      ],
    );
  }

  pw.Widget validationLine(bool valid, String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 9),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 22,
          height: 14,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: valid
                  ? _HrNominaPdfPalette.green
                  : _HrNominaPdfPalette.red,
              width: .6,
            ),
          ),
          child: pw.Text(
            valid ? 'OK' : '!',
            style: style(
              size: 7.5,
              bold: true,
              color: valid
                  ? _HrNominaPdfPalette.green
                  : _HrNominaPdfPalette.red,
            ),
          ),
        ),
        pw.SizedBox(width: 7),
        pw.Expanded(
          child: pw.Text(
            valid ? label : 'Revisión requerida: $label',
            style: style(size: 8.5),
          ),
        ),
      ],
    ),
  );

  pw.Widget runningHeader() => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 7),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _HrNominaPdfPalette.purple, width: .8),
      ),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          'DICSA · NÓMINA',
          style: style(size: 10, bold: true, color: _HrNominaPdfPalette.purple),
        ),
        pw.Spacer(),
        pw.Text(
          '$shortPeriod · ${closed ? 'Cierre confirmado' : 'Vista preliminar'}',
          style: style(size: 8),
        ),
      ],
    ),
  );

  pw.Widget footer(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: _HrNominaPdfPalette.rule, width: .5),
      ),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'DICSA · Recursos Humanos · Nómina\n$shortPeriod',
            style: style(size: 7.5, color: _HrNominaPdfPalette.muted),
          ),
        ),
        pw.Text(
          'Emisión ${_hrNominaPdfDate(emittedAt)}\nPágina ${context.pageNumber} de ${context.pagesCount}',
          textAlign: pw.TextAlign.right,
          style: style(size: 7.5, color: _HrNominaPdfPalette.muted),
        ),
      ],
    ),
  );

  pw.Widget sectionTitle(String title, String subtitle) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8, bottom: 9),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: style(size: 16, bold: true, color: _HrNominaPdfPalette.purple),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          subtitle,
          style: style(size: 9, color: _HrNominaPdfPalette.muted),
        ),
      ],
    ),
  );

  pw.Widget note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 9),
    child: pw.Text(
      text,
      style: style(size: 8, color: _HrNominaPdfPalette.muted),
    ),
  );

  pw.Widget table({
    required List<String> headers,
    required List<List<String>> data,
    required List<double> widths,
    required List<String> totals,
    int textColumns = 2,
    int? strongColumn,
  }) {
    pw.Widget cell(
      String value,
      int col, {
      bool header = false,
      bool total = false,
    }) => pw.Padding(
      padding: pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: header || total ? 4 : 3,
      ),
      child: pw.Text(
        value,
        textAlign: col == 0
            ? pw.TextAlign.center
            : col < textColumns
            ? pw.TextAlign.left
            : pw.TextAlign.right,
        style: style(
          size: header ? 8 : 8.5,
          bold: header || total || col == strongColumn,
          color: header
              ? PdfColors.white
              : value.startsWith('-\$')
              ? _HrNominaPdfPalette.red
              : null,
        ),
      ),
    );
    return pw.Table(
      columnWidths: {
        for (var i = 0; i < widths.length; i++)
          i: pw.FlexColumnWidth(widths[i]),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: _HrNominaPdfPalette.rule,
          width: .35,
        ),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _HrNominaPdfPalette.purple),
          children: [
            for (var c = 0; c < headers.length; c++)
              cell(headers[c], c, header: true),
          ],
        ),
        for (var r = 0; r < data.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: r.isOdd ? _HrNominaPdfPalette.stripe : PdfColors.white,
            ),
            children: [
              for (var c = 0; c < headers.length; c++) cell(data[r][c], c),
            ],
          ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _HrNominaPdfPalette.lavender),
          children: [
            for (var c = 0; c < headers.length; c++)
              cell(totals[c], c, total: true),
          ],
        ),
      ],
    );
  }

  pw.Widget employeeSummaryTable() => table(
    headers: [
      'ID',
      'COLABORADOR',
      'EMPRESA',
      'FISCAL',
      'DEPÓSITO',
      'CHEQUE',
      'FLUJO\nNETO',
      'DEDUCCIONES\nRH / FLUJO',
      'PAGO\nFUERA',
      'TOTAL\nA PAGAR',
    ],
    widths: [.55, 2.8, 1.25, 1, 1, 1, 1, 1.15, .9, 1.15],
    textColumns: 3,
    strongColumn: 9,
    data: [
      for (final r in rows)
        [
          r.employeeId,
          r.employeeName,
          r.empresa,
          ...[
            r.fiscalAmount,
            r.fiscalDepositedAmount,
            r.fiscalCashAmount,
            r.operationalCashAmount,
            r.deductionsAmount,
            r.paymentOutsideAmount,
            r.totalAmount,
          ].map(_fmtHrNominaMoney),
        ],
    ],
    totals: [
      '',
      'TOTAL DEL PERIODO',
      '',
      ...[
        metrics.fiscal,
        metrics.fiscalDeposited,
        metrics.fiscalCash,
        metrics.operationalCash,
        metrics.deductions,
        metrics.outside,
        metrics.total,
      ].map(_fmtHrNominaMoney),
    ],
  );

  pw.Widget fiscalAppendix() => table(
    headers: [
      'ID',
      'ANEXO A · COLABORADOR',
      'EMPRESA',
      'FISCAL DE\nORIGEN',
      allInformational ? 'RETARDO\nINFORMADO' : 'RETARDO\nREGISTRADO',
      'FISCAL\nNETO',
      'DEPÓSITO',
      'CHEQUE',
    ],
    widths: [.55, 3.3, 1.4, 1.2, 1.1, 1.2, 1.2, 1.2],
    textColumns: 3,
    strongColumn: 5,
    data: [
      for (final r in rows)
        [
          r.employeeId,
          r.employeeName,
          r.empresa,
          ...[
            fiscalOrigin(r),
            r.fiscalLateDeductionAmount,
            r.fiscalAmount,
            r.fiscalDepositedAmount,
            r.fiscalCashAmount,
          ].map(_fmtHrNominaMoney),
        ],
    ],
    totals: [
      '',
      'TOTAL FISCAL',
      '',
      ...[
        sum(fiscalOrigin),
        sum((r) => r.fiscalLateDeductionAmount),
        metrics.fiscal,
        metrics.fiscalDeposited,
        metrics.fiscalCash,
      ].map(_fmtHrNominaMoney),
    ],
  );

  pw.Widget flowAppendix() => table(
    headers: [
      'ID',
      'ANEXO B · COLABORADOR',
      'SUELDO\nFLUJO',
      'VACACIONES\nFLUJO',
      'ISR\nOPERATIVO',
      'TRANSPORTE',
      'FESTIVO',
      'BONOS /\nH.E.',
      'AJUSTE\nRH',
      'FLUJO\nNETO',
    ],
    widths: [.55, 3.1, 1.15, 1.15, .95, 1.05, .85, 1.25, 1.1, 1.15],
    strongColumn: 9,
    data: [
      for (final r in rows)
        [
          r.employeeId,
          r.employeeName,
          ...[
            r.cashSalaryAmount,
            r.cashVacationAmount,
            r.cashIsrAmount,
            r.transportSupportAmount,
            r.holidayAmount,
            bonus(r),
            r.manualAdjustmentAmount,
            r.operationalCashAmount,
          ].map(_fmtHrNominaMoney),
        ],
    ],
    totals: [
      '',
      'TOTAL FLUJO',
      ...[
        sum((r) => r.cashSalaryAmount),
        sum((r) => r.cashVacationAmount),
        sum((r) => r.cashIsrAmount),
        sum((r) => r.transportSupportAmount),
        sum((r) => r.holidayAmount),
        sum(bonus),
        sum((r) => r.manualAdjustmentAmount),
        metrics.operationalCash,
      ].map(_fmtHrNominaMoney),
    ],
  );

  pw.Widget deductionsAppendix() => table(
    headers: [
      'ID',
      'ANEXO C · COLABORADOR',
      'ISR\nOPERATIVO',
      allInformational ? 'FALTAS\nINFORMADAS' : 'FALTAS',
      'INFONAVIT\nFLUJO',
      'FONACOT\nFLUJO',
      'PRÉSTAMO',
      'TOTAL\nDEDUCCIONES',
    ],
    widths: [.55, 3.8, 1, 1.1, 1.15, 1.1, 1, 1.25],
    strongColumn: 7,
    data: [
      for (final r in rows)
        [
          r.employeeId,
          r.employeeName,
          _fmtHrNominaMoney(r.cashIsrAmount),
          '${_fmtHrNominaMoney(r.cashAbsenceDeductionAmount)}${!allInformational && r.incidencesInformational ? ' (ref.)' : ''}',
          ...[
            r.cashInfonavitDeductionAmount,
            r.cashFonacotDeductionAmount,
            r.loanDeductionAmount,
            r.deductionsAmount,
          ].map(_fmtHrNominaMoney),
        ],
    ],
    totals: [
      '',
      'TOTAL DEDUCCIONES',
      ...[
        sum((r) => r.cashIsrAmount),
        sum((r) => r.cashAbsenceDeductionAmount),
        sum((r) => r.cashInfonavitDeductionAmount),
        sum((r) => r.cashFonacotDeductionAmount),
        sum((r) => r.loanDeductionAmount),
        metrics.deductions,
      ].map(_fmtHrNominaMoney),
    ],
  );
}
