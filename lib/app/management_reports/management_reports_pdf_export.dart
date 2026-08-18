import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../auth/auth_access.dart';
import '../shared/utils/file_download_save.dart';
import 'management_reports_history_store.dart';
import 'management_reports_operations_daily_pdf.dart';
import 'management_reports_registry.dart';

Future<ManagementReportRunRecord?> exportManagementReportPdf({
  required ManagementAreaDefinition area,
  required ManagementReportFrequency frequency,
}) async {
  final generatedAt = DateTime.now();
  final profile = await AuthAccess.resolveCurrentProfile();
  final generatedBy = profile?.email ?? 'usuario@dicsa.local';
  final bytes = await buildManagementReportPdfBytes(
    area: area,
    frequency: frequency,
    generatedAt: generatedAt,
    generatedBy: generatedBy,
  );
  final suggestedFileName = _managementReportFileName(
    area: area,
    frequency: frequency,
    generatedAt: generatedAt,
  );
  final savedPath = await saveBytesAs(
    bytes: bytes,
    suggestedFileName: suggestedFileName,
    dialogTitle: 'Guardar reporte de supervisión como PDF',
  );
  if (savedPath == null || savedPath.trim().isEmpty) return null;
  final fileName = savedPath.split(RegExp(r'[\\/]')).last;
  final record = ManagementReportRunRecord(
    areaKey: area.key,
    frequency: frequency,
    generatedAt: generatedAt,
    generatedBy: generatedBy,
    fileName: fileName,
  );
  await ManagementReportsHistoryStore.append(record);
  return record;
}

Future<Uint8List> buildManagementReportPdfBytes({
  required ManagementAreaDefinition area,
  required ManagementReportFrequency frequency,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  if (area.key == ManagementAreaKey.operaciones &&
      frequency == ManagementReportFrequency.daily) {
    return buildOperationsDailySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.finanzas &&
      frequency == ManagementReportFrequency.daily) {
    return buildFinanceDailySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.gastos &&
      frequency == ManagementReportFrequency.daily) {
    return buildExpensesDailySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.ventas &&
      frequency == ManagementReportFrequency.daily) {
    return buildSalesDailySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.ventas &&
      frequency == ManagementReportFrequency.weeklyFriday) {
    return buildSalesWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.finanzas &&
      frequency == ManagementReportFrequency.weeklyFriday) {
    return buildFinanceWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.menudeo &&
      frequency == ManagementReportFrequency.weeklyFriday) {
    return buildMenudeoWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.bascula &&
      frequency == ManagementReportFrequency.weeklyFriday) {
    return buildBasculaWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.logistica &&
      frequency == ManagementReportFrequency.weeklyFriday) {
    return buildLogisticsWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }
  if (area.key == ManagementAreaKey.operaciones &&
      frequency == ManagementReportFrequency.weeklyFriday) {
    return buildOperationsWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
    );
  }

  final reports = area.reportsFor(frequency);
  final readyCount = area.countByStatus(
    frequency,
    ManagementReportDataStatus.ready,
  );
  final partialCount = area.countByStatus(
    frequency,
    ManagementReportDataStatus.partial,
  );
  final pendingCount = area.countByStatus(
    frequency,
    ManagementReportDataStatus.pending,
  );
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.88));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.72));
  final title = switch (frequency) {
    ManagementReportFrequency.daily => 'Corte diario de supervision',
    ManagementReportFrequency.weeklyFriday =>
      'Cierre semanal para junta de viernes',
  };
  final cutLabel = switch (frequency) {
    ManagementReportFrequency.daily => _formatLongDateSpanish(generatedAt),
    ManagementReportFrequency.weeklyFriday => _weeklyCutLabel(generatedAt),
  };

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
      build: (context) {
        return [
          _pdfHeader(
            area: area,
            title: title,
            cutLabel: cutLabel,
            generatedAt: generatedAt,
            generatedBy: generatedBy,
            accent: accent,
            accentSoft: accentSoft,
            accentBorder: accentBorder,
          ),
          pw.SizedBox(height: 14),
          _pdfOverview(
            area: area,
            frequency: frequency,
            readyCount: readyCount,
            partialCount: partialCount,
            pendingCount: pendingCount,
            accent: accent,
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Enfoque de supervision',
            accent: accent,
            child: pw.Text(
              'Este reporte ayuda a dirigir, coordinar y supervisar sin depender de urgencias. El encargado del area debe estudiarlo antes de la junta, explicar desvíos y llegar con acciones propuestas.',
              style: _bodyStyle(),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Reportes incluidos en este corte',
            accent: accent,
            child: _pdfReportsTable(reports, accentSoft),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Guion de la junta',
            accent: accent,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfBullet('Qué pasó en el área durante este corte.'),
                _pdfBullet('Qué se desvió contra lo esperado.'),
                _pdfBullet('Qué requiere decisión o apoyo de Gerencia.'),
                _pdfBullet('Quién queda responsable y para cuándo cierra.'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Recordatorio operativo',
            accent: accent,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfBullet(
                  'El reporte no sustituye la operación fuente; la resume para supervisión.',
                ),
                _pdfBullet(
                  'Si un dato está mal, se corrige en el módulo origen y se regenera.',
                ),
                _pdfBullet(
                  'Las fuentes pendientes o parciales deben explicarse sin maquillar la lectura.',
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );
  return pdf.save();
}

String _managementReportFileName({
  required ManagementAreaDefinition area,
  required ManagementReportFrequency frequency,
  required DateTime generatedAt,
}) {
  final areaSlug = managementAreaKeySlug(area.key);
  final freqSlug = managementFrequencySlug(frequency);
  final dateStamp =
      '${generatedAt.year}${generatedAt.month.toString().padLeft(2, '0')}${generatedAt.day.toString().padLeft(2, '0')}';
  return 'supervision_${areaSlug}_${freqSlug}_$dateStamp.pdf';
}

pw.Widget _pdfHeader({
  required ManagementAreaDefinition area,
  required String title,
  required String cutLabel,
  required DateTime generatedAt,
  required String generatedBy,
  required PdfColor accent,
  required PdfColor accentSoft,
  required PdfColor accentBorder,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 18),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(18),
      border: pw.Border.all(color: accentBorder, width: 1.2),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
            color: accentSoft,
            borderRadius: pw.BorderRadius.circular(999),
          ),
          child: pw.Text(
            area.title.toUpperCase(),
            style: pw.TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#16202B'),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(cutLabel, style: _mutedStyle()),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _pdfMetaChip('Responsable', area.ownerLabel, accent),
            _pdfMetaChip('Generado', _formatDateTimeShort(generatedAt), accent),
            _pdfMetaChip('Usuario', generatedBy, accent),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _pdfOverview({
  required ManagementAreaDefinition area,
  required ManagementReportFrequency frequency,
  required int readyCount,
  required int partialCount,
  required int pendingCount,
  required PdfColor accent,
}) {
  final reports = area.reportsFor(frequency);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 7,
        child: _pdfSection(
          title: 'Resumen ejecutivo',
          accent: accent,
          child: pw.Text(
            '${area.subtitle} Este corte incluye ${reports.length} reportes con foco en lectura, desviaciones y responsables de seguimiento.',
            style: _bodyStyle(),
          ),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        flex: 5,
        child: _pdfSection(
          title: 'Estado de fuentes',
          accent: accent,
          child: pw.Column(
            children: [
              _pdfStatusRow('Listas', readyCount, PdfColor.fromHex('#2E9E5B')),
              _pdfStatusRow(
                'Parciales',
                partialCount,
                PdfColor.fromHex('#D78A1D'),
              ),
              _pdfStatusRow(
                'Pendientes',
                pendingCount,
                PdfColor.fromHex('#B63E3E'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _pdfReportsTable(
  List<ManagementReportDefinition> reports,
  PdfColor accentSoft,
) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColor.fromHex('#DCE7EE')),
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(3.0),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(2.4),
      3: pw.FlexColumnWidth(3.6),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: accentSoft),
        children: [
          _pdfTableCell('Reporte', bold: true),
          _pdfTableCell('Estado', bold: true),
          _pdfTableCell('Fuente', bold: true),
          _pdfTableCell('Pregunta de seguimiento', bold: true),
        ],
      ),
      for (final report in reports)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: reports.indexOf(report).isEven
                ? PdfColors.white
                : PdfColor.fromHex('#F8FBFD'),
          ),
          children: [
            _pdfTableCell(report.title),
            _pdfTableCell(managementStatusLabel(report.dataStatus)),
            _pdfTableCell(report.sourceLabel),
            _pdfTableCell(report.followUpPrompt),
          ],
        ),
    ],
  );
}

pw.Widget _pdfSection({
  required String title,
  required PdfColor accent,
  required pw.Widget child,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(14),
      border: pw.Border.all(color: PdfColor.fromHex('#DCE7EE')),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(height: 10),
        child,
      ],
    ),
  );
}

pw.Widget _pdfStatusRow(String label, int value, PdfColor color) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      children: [
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Text(label, style: _bodyStyle())),
        pw.Text(
          '$value',
          style: pw.TextStyle(
            color: color,
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfMetaChip(String label, String value, PdfColor accent) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(999),
      color: PdfColor.fromHex('#F4F8FB'),
      border: pw.Border.all(color: accent),
    ),
    child: pw.Text(
      '$label: $value',
      style: pw.TextStyle(
        color: PdfColor.fromHex('#203549'),
        fontSize: 10.5,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _pdfBullet(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '• ',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#203549'),
          ),
        ),
        pw.Expanded(child: pw.Text(text, style: _bodyStyle())),
      ],
    ),
  );
}

pw.Widget _pdfTableCell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10.2,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: PdfColor.fromHex('#203549'),
      ),
    ),
  );
}

pw.TextStyle _bodyStyle() {
  return pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.normal,
    color: PdfColor.fromHex('#203549'),
    lineSpacing: 3,
  );
}

pw.TextStyle _mutedStyle() {
  return pw.TextStyle(
    fontSize: 10.8,
    fontWeight: pw.FontWeight.normal,
    color: PdfColor.fromHex('#60758C'),
  );
}

String _weeklyCutLabel(DateTime reference) {
  final friday = _nextOrSameFriday(reference);
  final weekStart = friday.subtract(const Duration(days: 4));
  return 'Semana operativa ${_formatLongDateSpanish(weekStart)} al ${_formatLongDateSpanish(friday)} · Junta viernes ${_formatLongDateSpanish(friday)}';
}

DateTime _nextOrSameFriday(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final delta = (DateTime.friday - normalized.weekday + 7) % 7;
  return normalized.add(Duration(days: delta));
}

String _formatDateTimeShort(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_formatShortDate(date)} $hour:$minute';
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatLongDateSpanish(DateTime date) {
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final month = months[math.max(0, math.min(11, date.month - 1))];
  return '${date.day} de $month de ${date.year}';
}

PdfColor _pdfColorFromFlutter(Color color) {
  final argb = color.toARGB32();
  return PdfColor.fromHex(
    '#${argb.toRadixString(16).substring(2).toUpperCase()}',
  );
}

Color _blendWithWhite(Color color, double amount) {
  final clamped = amount.clamp(0.0, 1.0);
  final red = (color.r * 255.0).round().clamp(0, 255);
  final green = (color.g * 255.0).round().clamp(0, 255);
  final blue = (color.b * 255.0).round().clamp(0, 255);
  final nextRed = red + ((255 - red) * clamped).round();
  final nextGreen = green + ((255 - green) * clamped).round();
  final nextBlue = blue + ((255 - blue) * clamped).round();
  return Color.fromARGB(255, nextRed, nextGreen, nextBlue);
}

Color _managementAccentInk(Color color) {
  return color;
}
