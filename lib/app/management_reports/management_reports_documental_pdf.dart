import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../gestion_documental/gestion_documental_catalog.dart';
import '../gestion_documental/gestion_documental_records.dart';
import '../gestion_documental/gestion_documental_theme.dart';
import 'documental_weekly_analysis.dart';
import 'documental_weekly_source.dart';
import 'management_reports_registry.dart';

Future<Uint8List> buildDocumentalWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
  DocumentalWeeklySource? source,
}) async {
  final report = DocumentalWeeklyAnalysis(
    source ?? await loadDocumentalWeeklySource(),
  );
  final style = _DocumentalPdfStyle();
  final monday = DateTime(
    report.today.year,
    report.today.month,
    report.today.day - report.today.weekday + 1,
  );
  final friday = DateTime(monday.year, monday.month, monday.day + 4);
  final risks = report.risks;
  final agenda = report.agenda;
  String document(DocumentalRecord r) =>
      '${_text(r.reference.isEmpty ? "Sin folio" : r.reference, max: 30)} · ${_text(r.title, max: 75)}';
  String action(DocumentalRecord r) => report.action(r).isEmpty
      ? 'Sin siguiente acción capturada'
      : report.action(r);
  String kind(DocumentalRecord r) =>
      documentalCategories.firstWhere((c) => c.key == r.kind.key).title;
  String riskLabel(DateTime date) {
    final days = report.days(date);
    if (days < 0) return '${-days} ${days == -1 ? "día" : "días"} de atraso';
    if (days == 0) return 'Hoy';
    return 'En $days días';
  }

  final pdf = pw.Document(
    title: 'Gestión Documental · Viernes',
    author: generatedBy,
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 2000,
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DICSA · Gestión Documental · ${_date(report.today)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: style.soft,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DICSA · SUPERVISIÓN POR ÁREAS',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: style.ink,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Gestión Documental',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: style.ink,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Reporte para junta de viernes',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Semana de referencia: ${_date(monday)} al ${_date(friday)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Situación actual al ${_date(report.today)} · America/Mexico_City',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                _text(
                  'Generado: ${generatedAt.toUtc().toIso8601String()} · $generatedBy',
                  max: 200,
                ),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        style.note(
          'El corte refleja el estado consultado al generar el PDF. Las fechas de la semana son referencia para la junta; no reconstruyen un cierre histórico.',
        ),
        ...style.table(
          'Lectura ejecutiva',
          ['Indicador', 'Total'],
          [
            [
              'Expedientes registrados (todos los estatus)',
              '${report.records.length}',
            ],
            ['Activos: pendientes o en proceso', '${report.active.length}'],
            ['Vencidos activos', '${report.expired.length}'],
            ['Por vencer de hoy a 15 días', '${report.upcoming.length}'],
            [
              'Críticos de hoy a 5 días (incluidos en los anteriores)',
              '${report.critical.length}',
            ],
            [
              'Activos sin fecha de vencimiento',
              '${report.withoutExpiration.length}',
            ],
            ['Permisos y trámites activos', '${report.procedures.length}'],
            ['Obligaciones que requieren atención', '${risks.length}'],
          ],
          widths: [4, 1],
          rowsPerBlock: 8,
        ),
        style.note(
          'Completados, cancelados y no aplicables no generan alertas. Sin vencimiento significa que no se capturó una fecha; no implica incumplimiento. Un expediente puede tener varias obligaciones.',
        ),
        ...style.table(
          'Cobertura por categoría',
          ['Categoría', 'Total', 'Activos', 'Vencidos', '0-15 días'],
          [
            for (final category in documentalCategories)
              (() {
                final rows = report.records
                    .where((r) => r.kind.key == category.key)
                    .toList();
                return [
                  category.title,
                  '${rows.length}',
                  '${rows.where(report.isActive).length}',
                  '${rows.where((r) => report.isActive(r) && r.expiration != null && report.days(r.expiration!) < 0).length}',
                  '${rows.where((r) => report.isActive(r) && r.expiration != null && report.days(r.expiration!) >= 0 && report.days(r.expiration!) <= 15).length}',
                ];
              })(),
          ],
          widths: [3, 1, 1, 1, 1],
          rowsPerBlock: 11,
        ),
        ...style.table(
          'Obligaciones prioritarias · ${risks.length}',
          [
            'Expediente / categoría',
            'Obligación / fecha',
            'Responsable',
            'Siguiente acción',
          ],
          [
            for (final e in risks)
              [
                '${document(e.record)}\n${kind(e.record)}',
                '${e.kind.label}\n${_date(e.date)}\n${riskLabel(e.date)}',
                report.responsible(e.record),
                action(e.record),
              ],
          ],
          widths: [3, 2, 2, 3],
          empty:
              'Sin vencimientos o renovaciones dentro de 15 días ni programaciones atrasadas sin realización registrada.',
        ),
        ...style.table(
          'Permisos y trámites abiertos · ${report.procedures.length}',
          [
            'Trámite / dependencia',
            'Estatus / avance',
            'Vencimiento',
            'Responsable / acción',
          ],
          [
            for (final r in report.procedures)
              [
                '${document(r)}\n${r.authority}',
                '${r.status}\n${r.progress}% · ${r.priority}',
                _date(r.expiration),
                '${report.responsible(r)}\n${action(r)}',
              ],
          ],
          widths: [3, 2, 1.6, 3.4],
          empty: 'Sin permisos o trámites pendientes o en proceso.',
        ),
        ...style.table(
          'Cursos y seguridad e higiene',
          [
            'Expediente / tipo',
            'Persona / proveedor',
            'Estatus / avance',
            'Vencimiento / responsable',
          ],
          [
            for (final r in report.category(DocumentalRecordKind.safety))
              [
                '${document(r)}\n${r.type}',
                '${r.employeeName.isEmpty ? "Sin persona vinculada" : r.employeeName}\n${r.providerName}',
                '${r.status}\n${r.progress}%',
                '${_date(r.expiration)}\n${report.responsible(r)}',
              ],
          ],
          widths: [3, 2.5, 1.5, 3],
          empty: 'Sin expedientes de seguridad e higiene registrados.',
        ),
        ...style.table(
          'Contratos · resumen documental',
          [
            'Contrato / contraparte',
            'Firma / vencimiento',
            'Renovación',
            'Estatus / responsable',
          ],
          [
            for (final r in report.category(DocumentalRecordKind.contracts))
              [
                '${document(r)}\n${r.counterpartyName}',
                'Firma: ${_date(r.signatureDate)}\nVence: ${_date(r.expiration)}',
                '${r.renewalType}\n${r.renewalType == "No aplica" ? "-" : _date(r.renewalDate)}',
                '${r.status}\n${report.responsible(r)}\n${action(r)}',
              ],
          ],
          widths: [3, 2, 2, 3],
          empty: 'Sin contratos registrados.',
        ),
        ...style.table(
          'Seguros · vigencias y renovaciones',
          [
            'Póliza / aseguradora',
            'Bien o persona',
            'Vence / renueva',
            'Estatus / responsable',
          ],
          [
            for (final r in report.category(DocumentalRecordKind.insurance))
              [
                '${document(r)}\n${r.providerName}',
                r.insuredSubject,
                'Vence: ${_date(r.expiration)}\nRenueva: ${r.renewalType == "No aplica" ? "No aplica" : _date(r.renewalDate)}',
                '${r.status}\n${report.responsible(r)}',
              ],
          ],
          widths: [3, 2, 2, 3],
          empty: 'Sin pólizas registradas.',
        ),
        ...style.table(
          'Agenda · próximos 30 días · ${agenda.length} fechas',
          [
            'Fecha / obligación',
            'Expediente / categoría',
            'Responsable',
            'Estatus',
          ],
          [
            for (final e in agenda)
              [
                '${_date(e.date)}\n${e.kind.label}',
                '${document(e.record)}\n${kind(e.record)}',
                report.responsible(e.record),
                e.record.status,
              ],
          ],
          widths: [2, 4, 2.5, 1.5],
          empty: 'Sin fechas por atender en los próximos 30 días.',
        ),
        ...style.table(
          'Manifiestos · control de expedientes',
          [
            'Expediente / instalación',
            'Autorización',
            'Vencimiento',
            'Estatus / responsable',
          ],
          [
            for (final r in report.manifests)
              [
                '${document(r)}\n${r.installationName}',
                r.authorizationNumber,
                _date(r.expiration),
                '${r.status}\n${report.responsible(r)}',
              ],
          ],
          widths: [3, 2, 2, 3],
          empty: 'Sin manifiestos capturados en Medio Ambiente.',
        ),
        style.note(
          'Los manifiestos tienen control documental. El análisis de cantidad, material y destino todavía no está conectado; esos datos no forman parte de este expediente.',
        ),
        ...style.table(
          'Pendientes de incorporación',
          ['Reporte', 'Situación'],
          [
            for (final r in area.reports.where(
              (r) => r.dataStatus != ManagementReportDataStatus.ready,
            ))
              [
                r.title,
                '${managementStatusLabel(r.dataStatus)} · ${r.sourceLabel.replaceFirst(RegExp(r"^Pendiente: "), "")}',
              ],
          ],
          widths: [2, 3],
          closingNote:
              'Fuente: Gestión Documental, sus 11 categorías y responsables registrados. Se consultan todos los expedientes, sin filtros de pantalla. Los textos extensos se abrevian; el detalle completo y los archivos se consultan en el expediente. La agenda no crea recurrencias a partir de la periodicidad.',
        ),
      ],
    ),
  );
  return pdf.save();
}

String _date(DateTime? date) => date == null
    ? 'Sin fecha'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _text(String value, {int max = 160}) {
  final clean = value.replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF\n]'), ' ');
  return clean.length <= max ? clean : '${clean.substring(0, max - 3)}...';
}

class _DocumentalPdfStyle {
  final ink = PdfColor.fromInt(documentalAreaTokens.primaryStrong.toARGB32());
  final soft = PdfColor.fromInt(documentalAreaTokens.primarySoft.toARGB32());

  pw.Widget note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 9),
    child: pw.Text(
      _text(text, max: 1000),
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
    ),
  );

  List<pw.Widget> table(
    String title,
    List<String> headers,
    List<List<String>> rows, {
    required List<double> widths,
    String empty = 'Sin registros.',
    int rowsPerBlock = 6,
    String? closingNote,
  }) {
    final data = rows.isEmpty
        ? [List.generate(headers.length, (i) => i == 0 ? empty : '-')]
        : rows;
    return [
      for (var start = 0; start < data.length; start += rowsPerBlock)
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 14),
              pw.Text(
                _text(start == 0 ? title : '$title · continuación'),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: ink,
                ),
              ),
              pw.SizedBox(height: 7),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data
                    .skip(start)
                    .take(rowsPerBlock)
                    .map((row) => row.map((cell) => _text(cell)).toList())
                    .toList(),
                columnWidths: {
                  for (var i = 0; i < widths.length; i++)
                    i: pw.FlexColumnWidth(widths[i]),
                },
                headerDecoration: pw.BoxDecoration(color: soft),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: ink,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.topLeft,
                headerAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
              if (closingNote != null && start + rowsPerBlock >= data.length)
                note(closingNote),
            ],
          ),
        ),
    ];
  }
}
