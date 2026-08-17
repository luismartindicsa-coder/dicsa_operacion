import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../maintenance/maintenance_statuses.dart';
import 'management_reports_registry.dart';

const String _kOperationsDailyOtFields =
    'id,ot_folio,status,priority,type,category,impact,requested_at,area_label,'
    'equipment_label,requester_name,assigned_to_name,mechanic_name,'
    'problem_description,cost_estimated_total';

const Map<String, String> _kPriorityLabels = <String, String>{
  'alta': 'Alta',
  'media': 'Media',
  'baja': 'Baja',
};

const Map<String, String> _kImpactLabels = <String, String>{
  'paro_total': 'Paro total',
  'paro_parcial': 'Paro parcial',
  'sin_impacto': 'Sin impacto',
};

Future<Uint8List> buildOperationsDailySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final rows = await _loadOperationsDailyOtRows(generatedAt);
  final insights = _buildOperationsDailyInsights(rows);
  final accent = _pdfColorFromFlutter(area.accent);
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(area.accent, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(area.accent, 0.74));
  final dayStart = DateTime(
    generatedAt.year,
    generatedAt.month,
    generatedAt.day,
  );

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            area: area,
            title: 'Corte diario de supervision',
            cutLabel: 'Operaciones | ${_formatLongDateSpanish(dayStart)}',
            generatedAt: generatedAt,
            generatedBy: generatedBy,
            accent: accent,
            accentSoft: accentSoft,
            accentBorder: accentBorder,
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Alcance del corte',
            accent: accent,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                _pdfBullet(
                  'Reporte real incluido hoy: OTs diarias nuevas desde maintenance_orders.',
                ),
                _pdfBullet(
                  'El KPI diario de limpieza sigue pendiente porque todavia no existe una fuente homologada en la app.',
                ),
                _pdfBullet(
                  'Este PDF sirve para coordinar accion del dia, no para revisar OTs historicas abiertas.',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Resumen ejecutivo',
            accent: accent,
            child: _pdfBulletList(insights.executiveSummary),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'KPIs de OTs nuevas',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem('OTs nuevas', '${insights.total}'),
                _PdfKpiItem('OTs altas', '${insights.highPriority}'),
                _PdfKpiItem('OTs con paro', '${insights.withParo}'),
                _PdfKpiItem(
                  'Sin responsable claro',
                  '${insights.withoutResponsible}',
                ),
                _PdfKpiItem(
                  'Areas con mas carga',
                  insights.topAreasLabel,
                  note: 'Top del dia',
                ),
                _PdfKpiItem(
                  'Costo estimado visible',
                  _formatCurrency(insights.visibleEstimatedCost),
                  note: '${insights.rowsWithEstimatedCost} OT con monto',
                ),
              ],
            ),
          ),
          if (insights.alerts.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 14),
            _pdfSection(
              title: 'Alertas automaticas',
              accent: accent,
              child: _pdfBulletList(insights.alerts),
            ),
          ],
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Foco del dia',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'OT',
                'Hora',
                'Area',
                'Impacto',
                'Prioridad',
                'Responsable',
                'Motivo',
              ],
              rows: insights.focusRows
                  .map(
                    (row) => <String>[
                      row.folio,
                      _formatHour(row.requestedAt),
                      row.areaLabel,
                      row.impactLabel,
                      row.priorityLabel,
                      row.responsibleLabel,
                      row.focusReason,
                    ],
                  )
                  .toList(growable: false),
              emptyLabel: 'No hubo OTs nuevas con foco especial en este corte.',
              headerColor: accent,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Resumen por area',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Area',
                'OTs nuevas',
                'Altas',
                'Con paro',
                'Sin responsable',
              ],
              rows: insights.areaRows
                  .map(
                    (row) => <String>[
                      row.areaLabel,
                      '${row.total}',
                      '${row.highPriority}',
                      '${row.withParo}',
                      '${row.withoutResponsible}',
                    ],
                  )
                  .toList(growable: false),
              emptyLabel: 'Sin OTs nuevas para resumir por area.',
              headerColor: accent,
            ),
          ),
          pw.NewPage(),
          _pdfSection(
            title: 'Listado completo del dia',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'OT',
                'Hora',
                'Area',
                'Equipo',
                'Estatus',
                'Prioridad',
                'Impacto',
                'Solicitante',
                'Responsable / Mecanico',
                'Descripcion corta',
              ],
              rows: rows
                  .map(
                    (row) => <String>[
                      row.folio,
                      _formatHour(row.requestedAt),
                      row.areaLabel,
                      row.equipmentLabel,
                      row.statusLabel,
                      row.priorityLabel,
                      row.impactLabel,
                      row.requesterName,
                      row.ownerAndMechanicLabel,
                      row.shortDescription,
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No se registraron OTs nuevas en el dia seleccionado.',
              headerColor: accent,
              compact: true,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Cierre gerencial',
            accent: accent,
            child: _pdfBulletList(insights.closeoutPrompts),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

Future<List<_OperationsDailyOtRow>> _loadOperationsDailyOtRows(
  DateTime generatedAt,
) async {
  final start = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
  final end = start.add(const Duration(days: 1));
  final raw = await Supabase.instance.client
      .from('maintenance_orders')
      .select(_kOperationsDailyOtFields)
      .gte('requested_at', start.toIso8601String())
      .lt('requested_at', end.toIso8601String())
      .order('requested_at', ascending: true)
      .limit(1000);

  final rows = (raw as List)
      .cast<Map<String, dynamic>>()
      .map(_OperationsDailyOtRow.fromJson)
      .toList(growable: false);

  rows.sort((a, b) {
    final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return left.compareTo(right);
  });
  return rows;
}

_OperationsDailyInsights _buildOperationsDailyInsights(
  List<_OperationsDailyOtRow> rows,
) {
  final total = rows.length;
  final highPriority = rows.where((row) => row.isHighPriority).length;
  final withParo = rows.where((row) => row.hasParo).length;
  final totalStops = rows.where((row) => row.isTotalStop).length;
  final withoutResponsible = rows.where((row) => row.missingResponsible).length;
  final rowsWithEstimatedCost = rows
      .where((row) => row.estimatedCost != null)
      .length;
  final visibleEstimatedCost = rows.fold<double>(
    0,
    (sum, row) => sum + (row.estimatedCost ?? 0),
  );

  final groupedByArea = <String, List<_OperationsDailyOtRow>>{};
  for (final row in rows) {
    groupedByArea.putIfAbsent(row.areaLabel, () => <_OperationsDailyOtRow>[]);
    groupedByArea[row.areaLabel]!.add(row);
  }

  final areaRows =
      groupedByArea.entries
          .map(
            (entry) => _OperationsDailyAreaRow(
              areaLabel: entry.key,
              total: entry.value.length,
              highPriority: entry.value
                  .where((row) => row.isHighPriority)
                  .length,
              withParo: entry.value.where((row) => row.hasParo).length,
              withoutResponsible: entry.value
                  .where((row) => row.missingResponsible)
                  .length,
            ),
          )
          .toList()
        ..sort((a, b) {
          final byTotal = b.total.compareTo(a.total);
          if (byTotal != 0) return byTotal;
          return a.areaLabel.compareTo(b.areaLabel);
        });

  final topAreasLabel = areaRows.isEmpty
      ? 'Sin carga'
      : areaRows
            .take(2)
            .map((row) => '${row.areaLabel} (${row.total})')
            .join(' | ');

  final focusRows = [...rows]
    ..sort((a, b) {
      final byScore = b.focusScore.compareTo(a.focusScore);
      if (byScore != 0) return byScore;
      final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });

  final filteredFocus = focusRows
      .where(
        (row) => row.isHighPriority || row.hasParo || row.missingResponsible,
      )
      .take(8)
      .toList(growable: false);

  final executiveSummary = <String>[];
  if (total == 0) {
    executiveSummary.add(
      'No se registraron OTs nuevas en maintenance_orders durante este dia.',
    );
  } else {
    executiveSummary.add('Hoy nacieron $total OTs nuevas en Operaciones.');
    if (areaRows.isNotEmpty) {
      executiveSummary.add(
        'La mayor carga nueva del dia se concentro en ${areaRows.first.areaLabel} con ${areaRows.first.total} OTs.',
      );
    }
    if (highPriority > 0) {
      executiveSummary.add(
        'Se detectaron $highPriority OTs de prioridad alta que requieren lectura directa en junta.',
      );
    } else {
      executiveSummary.add(
        'No hubo OTs nuevas de prioridad alta en este corte.',
      );
    }
    if (withParo > 0) {
      executiveSummary.add(
        'Entraron $withParo OTs con impacto de paro; $totalStops fueron paro total.',
      );
    }
    if (withoutResponsible > 0) {
      executiveSummary.add(
        'Hay $withoutResponsible OTs nuevas sin responsable claro o mecanico asignado.',
      );
    } else {
      executiveSummary.add(
        'Todas las OTs nuevas ya muestran responsable o mecanico asignado.',
      );
    }
  }
  executiveSummary.add(
    'El KPI diario de limpieza no se incluye todavia porque su fuente sigue pendiente de homologacion.',
  );

  final alerts = <String>[];
  for (final areaRow in areaRows.where((row) => row.total >= 3)) {
    alerts.add(
      '${areaRow.areaLabel} acumulo ${areaRow.total} OTs nuevas en el mismo dia.',
    );
  }
  if (highPriority >= 2) {
    alerts.add(
      'Se abrieron $highPriority OTs de prioridad alta; revisar si son urgencia real o falla de prevencion.',
    );
  }
  final totalStopFolios = rows
      .where((row) => row.isTotalStop)
      .map((row) => row.folio)
      .take(3)
      .join(', ');
  if (totalStopFolios.isNotEmpty) {
    alerts.add('Hay OTs con paro total: $totalStopFolios.');
  }
  final missingOwnerFolios = rows
      .where((row) => row.missingResponsible)
      .map((row) => row.folio)
      .take(4)
      .join(', ');
  if (missingOwnerFolios.isNotEmpty) {
    alerts.add(
      'Las siguientes OTs nuevas siguen sin responsable claro: $missingOwnerFolios.',
    );
  }

  final quoteOrApprovalCount = rows
      .where(
        (row) =>
            row.status == 'cotizacion' || row.status == 'autorizacion_finanzas',
      )
      .length;

  final closeoutPrompts = <String>[
    'Operaciones debe explicar cuales OTs de hoy no debieron nacer y que accion preventiva se tomara.',
    'Toda OT nueva sin responsable debe quedar asignada hoy mismo al cerrar la junta.',
    'Gerencia debe pedir accion concreta para las OTs marcadas en foco del dia, no solo explicacion.',
    if (quoteOrApprovalCount > 0)
      '$quoteOrApprovalCount OTs nuevas ya estan en cotizacion o autorizacion; validar si la planeacion llego tarde.',
    'El KPI de limpieza sigue fuera de este corte hasta definir captura formal y fuente homologada.',
  ];

  return _OperationsDailyInsights(
    total: total,
    highPriority: highPriority,
    withParo: withParo,
    withoutResponsible: withoutResponsible,
    visibleEstimatedCost: visibleEstimatedCost,
    rowsWithEstimatedCost: rowsWithEstimatedCost,
    topAreasLabel: topAreasLabel,
    areaRows: areaRows,
    focusRows: filteredFocus,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

class _OperationsDailyOtRow {
  final String folio;
  final String status;
  final String priority;
  final String impact;
  final String areaLabel;
  final String equipmentLabel;
  final String requesterName;
  final String assignedToName;
  final String mechanicName;
  final String problemDescription;
  final DateTime? requestedAt;
  final double? estimatedCost;

  const _OperationsDailyOtRow({
    required this.folio,
    required this.status,
    required this.priority,
    required this.impact,
    required this.areaLabel,
    required this.equipmentLabel,
    required this.requesterName,
    required this.assignedToName,
    required this.mechanicName,
    required this.problemDescription,
    required this.requestedAt,
    required this.estimatedCost,
  });

  factory _OperationsDailyOtRow.fromJson(Map<String, dynamic> json) {
    return _OperationsDailyOtRow(
      folio: _stringOrFallback(json['ot_folio'], 'Sin folio'),
      status: normalizeMaintenanceStatus(json['status']),
      priority: _normalizeTag(json['priority']),
      impact: _normalizeTag(json['impact']),
      areaLabel: _stringOrFallback(json['area_label'], 'Sin area'),
      equipmentLabel: _stringOrFallback(json['equipment_label'], 'Sin equipo'),
      requesterName: _stringOrFallback(
        json['requester_name'],
        'Sin solicitante',
      ),
      assignedToName: _cleanString(json['assigned_to_name']),
      mechanicName: _cleanString(json['mechanic_name']),
      problemDescription: _stringOrFallback(
        json['problem_description'],
        'Sin descripcion',
      ),
      requestedAt: DateTime.tryParse((json['requested_at'] ?? '').toString()),
      estimatedCost: _toNullableDouble(json['cost_estimated_total']),
    );
  }

  bool get isHighPriority => priority == 'alta';
  bool get hasParo => impact == 'paro_total' || impact == 'paro_parcial';
  bool get isTotalStop => impact == 'paro_total';
  bool get missingResponsible => assignedToName.isEmpty && mechanicName.isEmpty;

  String get statusLabel {
    final label = maintenanceStatusLabel(status).trim();
    return label.isEmpty ? 'Sin estatus' : label;
  }

  String get priorityLabel => _kPriorityLabels[priority] ?? 'Sin prioridad';

  String get impactLabel => _kImpactLabels[impact] ?? 'Sin impacto';

  String get responsibleLabel {
    if (assignedToName.isNotEmpty) return assignedToName;
    if (mechanicName.isNotEmpty) return mechanicName;
    return 'Sin responsable';
  }

  String get ownerAndMechanicLabel {
    if (assignedToName.isEmpty && mechanicName.isEmpty) {
      return 'Sin responsable';
    }
    if (assignedToName.isNotEmpty && mechanicName.isNotEmpty) {
      return '$assignedToName / $mechanicName';
    }
    return assignedToName.isNotEmpty ? assignedToName : mechanicName;
  }

  String get shortDescription => _truncate(problemDescription, 68);

  int get focusScore {
    var score = 0;
    if (isHighPriority) score += 4;
    if (impact == 'paro_total') score += 4;
    if (impact == 'paro_parcial') score += 2;
    if (missingResponsible) score += 3;
    if (status == 'cotizacion' || status == 'autorizacion_finanzas') {
      score += 1;
    }
    return score;
  }

  String get focusReason {
    final reasons = <String>[];
    if (isHighPriority) reasons.add('Alta');
    if (impact == 'paro_total') reasons.add('Paro total');
    if (impact == 'paro_parcial') reasons.add('Paro parcial');
    if (missingResponsible) reasons.add('Sin responsable');
    if (reasons.isEmpty) {
      reasons.add('Revisar en junta');
    }
    return reasons.join(' | ');
  }
}

class _OperationsDailyAreaRow {
  final String areaLabel;
  final int total;
  final int highPriority;
  final int withParo;
  final int withoutResponsible;

  const _OperationsDailyAreaRow({
    required this.areaLabel,
    required this.total,
    required this.highPriority,
    required this.withParo,
    required this.withoutResponsible,
  });
}

class _OperationsDailyInsights {
  final int total;
  final int highPriority;
  final int withParo;
  final int withoutResponsible;
  final double visibleEstimatedCost;
  final int rowsWithEstimatedCost;
  final String topAreasLabel;
  final List<_OperationsDailyAreaRow> areaRows;
  final List<_OperationsDailyOtRow> focusRows;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _OperationsDailyInsights({
    required this.total,
    required this.highPriority,
    required this.withParo,
    required this.withoutResponsible,
    required this.visibleEstimatedCost,
    required this.rowsWithEstimatedCost,
    required this.topAreasLabel,
    required this.areaRows,
    required this.focusRows,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
  });
}

class _PdfKpiItem {
  final String label;
  final String value;
  final String? note;

  const _PdfKpiItem(this.label, this.value, {this.note});
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
      children: <pw.Widget>[
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
          children: <pw.Widget>[
            _pdfMetaChip('Responsable', area.ownerLabel, accent),
            _pdfMetaChip('Generado', _formatDateTimeShort(generatedAt), accent),
            _pdfMetaChip('Usuario', generatedBy, accent),
          ],
        ),
      ],
    ),
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
      children: <pw.Widget>[
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

pw.Widget _pdfBullet(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          '- ',
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

pw.Widget _pdfBulletList(List<String> items) {
  if (items.isEmpty) {
    return pw.Text('Sin hallazgos en este corte.', style: _bodyStyle());
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: items.map(_pdfBullet).toList(growable: false),
  );
}

pw.Widget _pdfKpiGrid({
  required PdfColor accent,
  required PdfColor accentSoft,
  required List<_PdfKpiItem> items,
}) {
  return pw.Wrap(
    spacing: 10,
    runSpacing: 10,
    children: items
        .map(
          (item) => pw.Container(
            width: 165,
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: pw.BoxDecoration(
              color: accentSoft,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: accent, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  item.label,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    color: accent,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  item.value,
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColor.fromHex('#16202B'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if ((item.note ?? '').trim().isNotEmpty) ...<pw.Widget>[
                  pw.SizedBox(height: 4),
                  pw.Text(item.note!, style: _mutedStyle(fontSize: 9.2)),
                ],
              ],
            ),
          ),
        )
        .toList(growable: false),
  );
}

pw.Widget _pdfSimpleTable({
  required List<String> headers,
  required List<List<String>> rows,
  required String emptyLabel,
  required PdfColor headerColor,
  bool compact = false,
}) {
  if (rows.isEmpty) {
    return pw.Text(emptyLabel, style: _mutedStyle());
  }
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(
      fontSize: compact ? 8.1 : 9.1,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: pw.BoxDecoration(color: headerColor),
    cellStyle: pw.TextStyle(
      fontSize: compact ? 7.7 : 8.8,
      color: PdfColor.fromHex('#203549'),
    ),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    cellPadding: pw.EdgeInsets.fromLTRB(
      compact ? 4 : 6,
      compact ? 4 : 6,
      compact ? 4 : 6,
      compact ? 4 : 6,
    ),
    border: pw.TableBorder.all(color: PdfColor.fromHex('#DCE7EE')),
    rowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FBFD)),
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
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

pw.TextStyle _bodyStyle() {
  return pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.normal,
    color: PdfColor.fromHex('#203549'),
    lineSpacing: 3,
  );
}

pw.TextStyle _mutedStyle({double fontSize = 10.8}) {
  return pw.TextStyle(
    fontSize: fontSize,
    fontWeight: pw.FontWeight.normal,
    color: PdfColor.fromHex('#60758C'),
  );
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
  final month = months[(date.month - 1).clamp(0, 11)];
  return '${date.day} de $month de ${date.year}';
}

String _formatHour(DateTime? date) {
  if (date == null) return '-';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatCurrency(double value) {
  final sign = value < 0 ? '-' : '';
  final absolute = value.abs().toStringAsFixed(2);
  final parts = absolute.split('.');
  final whole = parts.first;
  final decimal = parts.last;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final indexFromEnd = whole.length - i;
    buffer.write(whole[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return '$sign\$${buffer.toString()}.$decimal';
}

String _cleanString(dynamic value) {
  return (value ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _stringOrFallback(dynamic value, String fallback) {
  final cleaned = _cleanString(value);
  return cleaned.isEmpty ? fallback : cleaned;
}

String _normalizeTag(dynamic value) {
  return (value ?? '').toString().trim().toLowerCase();
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}

String _truncate(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars - 3).trimRight()}...';
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
