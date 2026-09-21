import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../finanzas/finanzas_theme.dart';
import '../shared/utils/number_formatters.dart';
import 'finance_weekly_budget_analysis.dart';
import 'finance_weekly_budget_source.dart';
import 'management_reports_registry.dart';

Future<Uint8List> buildFinanceWeeklyBudgetPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
  FinanceWeeklyBudgetSource? source,
}) async {
  final data = FinanceWeeklyBudgetAnalysis(
    source ?? await loadFinanceWeeklyBudgetSource(),
    generatedAt,
  );
  final style = _BudgetPdfStyle();
  final pdf = pw.Document(
    title: 'Presupuesto semanal de egresos',
    author: generatedBy,
  );
  final period = '${_date(data.period.start)} al ${_date(data.period.end)}';
  final fixed = data.commitments.where((r) => r.fixed).toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  final byProvider = <String, List<FinanceBudgetInvoice>>{};
  for (final r in data.invoices) {
    byProvider.putIfAbsent('${r.account}|${r.supplierKey}', () => []).add(r);
  }
  final providers = byProvider.values.toList()
    ..sort(
      (a, b) => a.first.supplier.toLowerCase().compareTo(
        b.first.supplier.toLowerCase(),
      ),
    );
  int sum(
    Iterable<FinanceBudgetInvoice> rows,
    int Function(FinanceBudgetInvoice) pick,
  ) => rows.fold(0, (s, r) => s + pick(r));
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 1000,
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 9),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DICSA / Finanzas / Propuesta pendiente de autorización',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: style.ink,
            border: pw.Border(
              left: pw.BorderSide(color: style.accent, width: 5),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DICSA',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'PRESUPUESTO PROPUESTO',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'PLANEACIÓN FINANCIERA / USO INTERNO',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey300,
                ),
              ),
              pw.SizedBox(height: 11),
              pw.Text(
                'Presupuesto semanal de egresos',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 7),
              pw.Text(
                'Periodo: $period / Cifras en MXN',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Elaborado: ${_date(generatedAt)} / ${_clean(generatedBy, 95)}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey300,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Expanded(
              child: style.kpi(
                'FACTURAS PROPUESTAS',
                data.proposedInvoices,
                '${data.proposedRows.length} facturas',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: style.kpi(
                'PAGOS FIJOS',
                data.proposedFixedPayments,
                '${fixed.where((r) => r.proposed > 0).length} compromisos propuestos',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: style.kpi(
                'TOTAL PROPUESTO',
                data.proposedTotal,
                'Facturas + pagos fijos',
                dark: true,
              ),
            ),
          ],
        ),
        style.note(
          'Presupuesto de lo requerido para la próxima semana. Tope total: ${_money(FinanceWeeklyBudgetAnalysis.weeklyLimit)}, incluidos pagos fijos. Primero una factura completa por proveedor, la más antigua; después adicionales por carga alta si queda margen. No se calcula a partir del saldo bancario.',
        ),
        style.total('MARGEN SIN ASIGNAR DEL TOPE', data.remainingBudget),
        if (data.baseOverLimit > 0)
          style.warning(
            'NECESIDAD SUPERIOR AL TOPE: pagos fijos y una factura por proveedor requieren ${_money(data.baseRequirement)}. Excedente: ${_money(data.baseOverLimit)}. La propuesta conserva el máximo de ${_money(FinanceWeeklyBudgetAnalysis.weeklyLimit)}; consultar pendientes.',
          ),
        ...style.table(
          'Detalle de facturas propuestas',
          ['Empresa / cuenta', 'Factura', 'Vencimiento', 'Saldo', 'Propuesto'],
          [
            for (final r in data.proposedRows)
              [
                _accountLabel(r.supplier, r.account),
                r.invoice.folio.trim().isEmpty ? r.invoice.id : r.invoice.folio,
                '${_date(r.invoice.dueDate!)}\n${r.overdueDays > 0 ? '${r.overdueDays} días atrasada' : 'Por vencer'}',
                _money(r.balance),
                '${_money(r.proposed)}\n${r.additional ? 'Adicional' : 'Una por proveedor'}',
              ],
          ],
          empty:
              'No hay facturas completas elegibles dentro del remanente del tope semanal.',
        ),
        style.total('TOTAL FACTURAS PROPUESTAS', data.proposedInvoices),
        ...style.table(
          'Pagos fijos con fecha',
          [
            'Empresa / cuenta',
            'Concepto',
            'Fecha de pago',
            'Requerido',
            'Propuesto',
          ],
          [
            for (final r in fixed)
              [
                _accountLabel(r.label, r.account),
                r.reference,
                '${_date(r.dueDate!)}${r.dueDate!.isBefore(data.period.start) ? '\nArrastre' : ''}',
                _money(r.amount),
                _money(r.proposed),
              ],
          ],
          empty:
              'No hay pagos fijos pendientes con fecha dentro del horizonte.',
        ),
        style.total('TOTAL PAGOS FIJOS PROPUESTOS', data.proposedFixedPayments),
        style.composition(data.proposedInvoices, data.proposedFixedPayments),
        style.signatures(generatedBy),
        pw.NewPage(freeSpace: 500),
        style.heading('Base del plan de pagos'),
        style.note(
          'Selección al ${_date(data.period.asOf)}. Primera vuelta: una factura por empresa proveedora, aun si tiene varias cuentas de pago. Se cubren saldos completos por antigüedad y no se salta una factura antigua para pagar una más nueva del mismo proveedor. Si no caben todas las primeras facturas, no se agregan adicionales.',
        ),
        style.note(
          'Carga alta: al menos ${_money(FinanceWeeklyBudgetAnalysis.highDebtThreshold)} en facturas elegibles pendientes. Tras cubrir la primera vuelta, se prioriza al proveedor con mayor deuda restante y se toma su siguiente factura más antigua, mientras quepa completa. Adicionales propuestas: ${data.additionalCount}. El límite es un máximo, no una meta de gasto.',
        ),
        ...style.table(
          'Presupuesto por empresa y sucursal',
          [
            'Cuenta',
            'Facturas propuestas',
            'Fijos requeridos',
            'Fijos propuestos',
            'Total propuesto',
          ],
          [
            for (final a in data.accounts.where(
              (a) => a.proposed > 0 || a.fixedRequired > 0,
            ))
              [
                a.label,
                _money(a.proposed),
                _money(a.fixedRequired),
                _money(a.fixedProposed),
                _money(a.proposedTotal),
              ],
          ],
          empty: 'Sin partidas propuestas o pagos fijos requeridos.',
        ),
        style.note(
          'Referencia de flujo: hasta ocho semanas completas, del ${_date(data.period.historyStart)} al ${_date(data.period.historyEnd)}. Sirve para comparar el esfuerzo de pago; no reduce ni aumenta el tope o la selección de facturas.',
        ),
        ...style.table(
          'Historial de flujo semanal',
          [
            'Semana completa',
            'Entradas externas',
            'Pagos de facturas',
            'Otros cargos',
            'Flujo neto',
          ],
          [
            for (final w in data.combinedHistory)
              [
                '${_date(w.start)}\n${_date(w.start.add(const Duration(days: 6)))}',
                _money(w.credits),
                _money(w.supplierDebits),
                _money(w.otherDebits),
                _money(w.net),
              ],
          ],
          empty: 'No hay semanas completas de historial bancario.',
        ),
        style.note(
          'El historial excluye traspasos internos, ajustes y movimientos identificados hacia Bóveda o efectivo. Se incluyen semanas sin actividad posteriores al inicio del historial. No representa saldo disponible ni cobros futuros asegurados.',
        ),
        ...style.table(
          'Referencia histórica por cuenta',
          [
            'Cuenta',
            'Semanas',
            'Entradas: mediana',
            'Pagos de facturas: mediana',
          ],
          [
            for (final a in data.accounts)
              [
                a.label,
                '${a.history.length}',
                _money(a.medianCredits),
                _money(a.medianSupplierDebits),
              ],
          ],
        ),
        if (data.commitments.any((r) => !r.fixed)) ...[
          ...style.table(
            'Compromisos sujetos a convenio',
            ['Proveedor / cuenta', 'Referencia', 'Vencimiento', 'Pendiente'],
            [
              for (final r in data.commitments.where((r) => !r.fixed))
                [
                  _accountLabel(r.label, r.account),
                  r.reference,
                  r.dueDate == null ? 'Por confirmar' : _date(r.dueDate!),
                  _money(r.amount),
                ],
            ],
          ),
          style.note(
            'Las facturas sujetas a convenio conservan su calendario y requieren revisión aparte. Estos importes informativos no se suman a la propuesta de facturas libres + pagos fijos ni reducen el tope de esta selección.',
          ),
        ],
        ...style.table(
          'Resumen de facturas por empresa proveedora',
          ['Proveedor / cuenta', 'Saldo abierto', 'Propuesto', 'Sin programar'],
          [
            for (final rows in providers)
              [
                _accountLabel(rows.first.supplier, rows.first.account),
                _money(sum(rows, (r) => r.balance)),
                _money(sum(rows, (r) => r.proposed)),
                _money(sum(rows, (r) => r.remaining)),
              ],
          ],
        ),
        ...style.table(
          'Facturas pendientes de cubrir o revisar',
          ['Proveedor / factura', 'Vencimiento', 'Pendiente', 'Siguiente paso'],
          [
            for (final r in data.pendingRows)
              [
                '${_clean(r.supplier, 60)}\n${_clean(r.invoice.folio.trim().isEmpty ? r.invoice.id : r.invoice.folio, 45)}',
                r.invoice.dueDate == null
                    ? 'Sin fecha'
                    : _date(r.invoice.dueDate!),
                _money(r.remaining),
                r.decision,
              ],
          ],
          empty:
              'Las facturas abiertas dentro del alcance quedan cubiertas por la propuesta.',
        ),
        style.total('SALDO DE FACTURAS SIN PROGRAMAR', data.unprogrammed),
        if (data.warnings.isNotEmpty) ...[
          style.heading('Puntos para revisar antes de autorizar'),
          for (final warning in data.warnings) style.warning(warning),
        ],
        style.note(
          'Esta propuesta se construye con las fuentes disponibles al generarse. Los abonos a facturas se concilian sin incrementar saldos ya reducidos. No registra pagos, no cambia fechas ni modifica facturas. La aprobación y ejecución de pagos se realiza por el flujo habitual.',
        ),
      ],
    ),
  );
  return pdf.save();
}

class _BudgetPdfStyle {
  final ink = PdfColor.fromInt(kFinanzasBg.toARGB32());
  final accent = PdfColor.fromInt(kFinanzasOrange.toARGB32());
  final soft = PdfColors.orange50;
  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
    child: pw.Text(
      _clean(text),
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      ),
    ),
  );
  pw.Widget note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Text(
      _clean(text, 900),
      style: const pw.TextStyle(fontSize: 8.2, color: PdfColors.grey700),
    ),
  );
  pw.Widget warning(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Text(
      _clean(text, 450),
      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.red800),
    ),
  );
  pw.Widget kpi(String label, int amount, String note, {bool dark = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: dark ? ink : PdfColors.white,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: dark ? ink : PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7.5,
                color: dark ? PdfColors.white : PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.FittedBox(
              child: pw.Text(
                _money(amount),
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: dark ? PdfColors.white : ink,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              note,
              style: pw.TextStyle(
                fontSize: 7,
                color: dark ? PdfColors.grey300 : PdfColors.grey600,
              ),
            ),
          ],
        ),
      );
  List<pw.Widget> table(
    String title,
    List<String> headers,
    List<List<String>> rows, {
    String empty = 'Sin registros.',
  }) {
    if (rows.isEmpty) {
      return [
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [heading(title), note(empty)],
          ),
        ),
      ];
    }
    return [
      pw.NewPage(freeSpace: 140),
      heading(title),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows.map((r) => r.map((s) => _clean(s, 110)).toList()).toList(),
        border: null,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        headerStyle: pw.TextStyle(
          fontSize: 7.8,
          fontWeight: pw.FontWeight.bold,
          color: ink,
        ),
        cellStyle: const pw.TextStyle(fontSize: 8.3),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.6),
          for (var i = 1; i < headers.length; i++)
            i: const pw.FlexColumnWidth(1),
        },
        cellAlignments: {
          for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
        },
      ),
    ];
  }

  pw.Widget total(String label, int amount) => pw.Container(
    padding: const pw.EdgeInsets.all(9),
    color: soft,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
        pw.Text(
          _money(amount),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
      ],
    ),
  );
  pw.Widget composition(int invoices, int fixed) => pw.Inseparable(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        heading('Composición del presupuesto'),
        if (invoices + fixed > 0)
          pw.Row(
            children: [
              if (invoices > 0)
                pw.Expanded(
                  flex: invoices,
                  child: pw.Container(height: 9, color: accent),
                ),
              if (fixed > 0)
                pw.Expanded(
                  flex: fixed,
                  child: pw.Container(height: 9, color: ink),
                ),
            ],
          ),
        note(
          'Facturas: ${_money(invoices)} / Pagos fijos: ${_money(fixed)} / Total: ${_money(invoices + fixed)}',
        ),
      ],
    ),
  );
  pw.Widget signatures(String author) => pw.Inseparable(
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Row(
        children: [
          for (final title in ['ELABORÓ', 'REVISÓ', 'AUTORIZÓ'])
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                child: pw.Column(
                  children: [
                    pw.Divider(color: PdfColors.grey400),
                    pw.Text(
                      title,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

String _money(int cents) => '\$${formatDecimal(cents / 100, decimals: 2)}';
String _accountLabel(String name, String key) =>
    '${_clean(name, 60)}\n${_clean(key.replaceAll('|', ' / '), 48)}';
String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _clean(String text, [int max = 200]) {
  final value = text
      .replaceAll('·', ' / ')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF\n]'), ' ')
      .trim();
  return value.length <= max ? value : '${value.substring(0, max - 3)}...';
}
