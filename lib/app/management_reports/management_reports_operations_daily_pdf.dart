import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../finanzas/finanzas_bank_accounts_store.dart';
import '../finanzas/finanzas_due_alerts_store.dart';
import '../finanzas/finanzas_payment_center_budget_engine.dart';
import '../finanzas/finanzas_payment_center_budget_loader.dart';
import '../finanzas/finanzas_payment_center_budget_models.dart';
import '../finanzas/finanzas_payment_center_reserves_store.dart';
import '../finanzas/finanzas_provider_accounts_store.dart';
import '../maintenance/maintenance_statuses.dart';
import '../mayoreo/mayoreo_financial_status.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'management_reports_registry.dart';

const String _kOperationsDailyOtFields =
    'id,ot_folio,status,priority,type,category,impact,requested_at,area_label,'
    'equipment_label,requester_name,assigned_to_name,mechanic_name,'
    'problem_description,cost_estimated_total';

const String _kSalesDailyReportFields =
    'id,ticket,sale_date,client_name_snapshot,remision,material_name_snapshot,'
    'exit_weight,price_snapshot,approved_weight,approved_price,approved_amount,'
    'operation_type,observations,created_at,updated_at';

const String _kSalesCollectionAccountFields =
    'id,ticket,sale_date,client_id,client_name_snapshot,remision,'
    'material_name_snapshot,approved_weight,approved_price,approved_amount,'
    'operation_type,sale_notes,document_number,document_date,'
    'estimated_payment_date,settlement_date,status,financial_notes,paid_amount';

const String _kMenudeoWeeklyTicketFields =
    'id,ticket_date,ticket_number,counterparty_name_snapshot,price_id,'
    'material_label_snapshot,price_at_entry,payable_weight,amount_total,'
    'status,comment,direction,exit_order_number,created_at';

const String _kMenudeoWeeklyVoucherFields =
    'id,voucher_date,folio,voucher_type,person_label,rubric,comment,'
    'total_amount,line_count,concepts_preview,created_at';

const String _kMenudeoWeeklyCashCutFields =
    'id,cut_date,opened_at,closed_at,opening_cash,sales_total,purchases_total,'
    'deposits_total,expenses_total,theoretical_cash_total,counted_cash_total,'
    'difference_total,pending_checks_count,status,notes';

const String _kMenudeoWeeklyPriceAdjustmentFields =
    'id,price_id,counterparty_name,material_label_snapshot,previous_price,'
    'new_price,reason,created_at,direction,event_kind,adjustment_mode,'
    'adjustment_value,applied_by';

const String _kOperationsWeeklyOtFields =
    'id,ot_folio,status,priority,type,category,impact,requested_at,updated_at,'
    'area_label,equipment_label,requester_name,assigned_to_name,mechanic_name,'
    'problem_description,diagnosis,work_summary,cost_estimated_total,'
    'cost_actual_total';

const String _kExpensesPurchaseOrderFields =
    'id,folio,order_date,target_label,quote_vendor_name,quote_vendor_type,'
    'quote_contact,notes,status,requested_by_name,requested_at,'
    'direction_comment,created_at,updated_at,sent_to_cash_at,'
    'sent_to_cash_by_name,purchased_at,purchased_by_name,estimated_total,'
    'actual_total,linked_ot_id,linked_ot_folio,linked_material_label,'
    'generated_from_ot';

const String _kExpensesPurchaseOrderLineFields =
    'id,purchase_order_id,line_no,description,line_total,qty,amount';

const String _kExpensesLinkedOtFields =
    'id,ot_folio,status,area_label,equipment_label';

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

const int _kOperationsWeeklyVisibleAreaRows = 14;
const int _kOperationsWeeklyVisibleEquipmentRows = 18;
const int _kOperationsWeeklyVisibleResolvedRows = 28;
const int _kOperationsWeeklyVisibleOpenRows = 40;

Future<Uint8List> buildOperationsDailySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final rows = await _loadOperationsDailyOtRows(generatedAt);
  final insights = _buildOperationsDailyInsights(rows);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final dayStart = DateTime(
    generatedAt.year,
    generatedAt.month,
    generatedAt.day,
  );

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Operaciones · OTs diarias nuevas',
            subtitle:
                'Area Operaciones · seguimiento diario de ordenes de trabajo creadas en la fecha del corte.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry('Corte', _formatLongDateSpanish(dayStart)),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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

Future<Uint8List> buildOperationsWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final cut = _resolveOperationsWeeklyCut(generatedAt);
  final rows = await _loadOperationsWeeklyOtRows();
  final insights = _buildOperationsWeeklyInsights(rows, cut);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final visibleAreaRows = insights.areaRows
      .take(_kOperationsWeeklyVisibleAreaRows)
      .toList(growable: false);
  final visibleEquipmentRows = insights.equipmentRows
      .take(_kOperationsWeeklyVisibleEquipmentRows)
      .toList(growable: false);
  final visibleResolvedRows = insights.resolvedWeekRows
      .take(_kOperationsWeeklyVisibleResolvedRows)
      .toList(growable: false);
  final visibleOpenRows = insights.openRows
      .take(_kOperationsWeeklyVisibleOpenRows)
      .toList(growable: false);
  final hiddenAreaCount = insights.areaRows.length - visibleAreaRows.length;
  final hiddenEquipmentCount =
      insights.equipmentRows.length - visibleEquipmentRows.length;
  final hiddenResolvedCount =
      insights.resolvedWeekRows.length - visibleResolvedRows.length;
  final hiddenOpenCount = insights.openRows.length - visibleOpenRows.length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 80,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Operaciones · Seguimiento semanal de OTs',
            subtitle:
                'Area Operaciones · corte ejecutivo para revisar abiertas, atrasadas, resueltas y pendientes de impulso antes de la junta.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry(
                'Corte',
                '${_formatShortDate(cut.weekStart)} - ${_formatShortDate(cut.friday)}',
              ),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: Seguimiento de OTs desde maintenance_orders.',
                ),
                _pdfBullet(
                  'El corte semanal activo va del ${_formatLongDateSpanish(cut.weekStart)} al ${_formatLongDateSpanish(cut.friday)} y esta acumulado unicamente hasta ${_formatDateTimeShort(cut.cutoffAt)}.',
                ),
                _pdfBullet(
                  'Atrasada = OT que sigue abierta y fue solicitada antes del ${_formatLongDateSpanish(cut.weekStart)} o ya supera 72 horas sin cerrar.',
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
            title: 'KPIs semanales de seguimiento',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem('OTs abiertas', '${insights.openCount}'),
                _PdfKpiItem(
                  'OTs criticas abiertas',
                  '${insights.criticalOpenCount}',
                  note: 'Alta o con paro',
                ),
                _PdfKpiItem(
                  'OTs atrasadas',
                  '${insights.delayedOpenCount}',
                  note: 'Arrastre previo o 72h+',
                ),
                _PdfKpiItem(
                  'Esperando impulso',
                  '${insights.waitingActionCount}',
                  note: 'Cotizacion / autorizacion',
                ),
                _PdfKpiItem(
                  'Cerradas en semana',
                  '${insights.closedWeekCount}',
                  note: 'Movimiento visible',
                ),
                _PdfKpiItem(
                  'Rechazadas en semana',
                  '${insights.rejectedWeekCount}',
                  note: 'Requieren correccion',
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
            title: 'Foco semanal',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'OT',
                'Area',
                'Equipo',
                'Estatus',
                'Horas abierta',
                'Responsable',
                'Motivo',
              ],
              rows: insights.focusRows
                  .map(
                    (row) => <String>[
                      row.folio,
                      row.areaLabel,
                      row.equipmentLabel,
                      row.statusLabel,
                      row.ageHoursLabel(cut.cutoffAt),
                      row.responsibleLabel,
                      row.focusReason(cut),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No hay OTs abiertas con foco especial en este corte semanal.',
              headerColor: accent,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Resumen por area',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenAreaCount > 0
                  ? 'Se muestran las ${visibleAreaRows.length} areas con mayor carga abierta de ${insights.areaRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Area',
                  'Abiertas',
                  'Criticas',
                  'Atrasadas',
                  'Espera impulso',
                  'Cerradas semana',
                ],
                rows: visibleAreaRows
                    .map(
                      (row) => <String>[
                        row.areaLabel,
                        '${row.openCount}',
                        '${row.criticalCount}',
                        '${row.delayedCount}',
                        '${row.waitingCount}',
                        '${row.closedWeekCount}',
                      ],
                    )
                    .toList(growable: false),
                emptyLabel: 'Sin OTs abiertas para resumir por area.',
                headerColor: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Resumen por equipo',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenEquipmentCount > 0
                  ? 'Se muestran los ${visibleEquipmentRows.length} equipos con mayor presion abierta de ${insights.equipmentRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Equipo',
                  'Area',
                  'Abiertas',
                  'Criticas',
                  'Atrasadas',
                  'Espera impulso',
                ],
                rows: visibleEquipmentRows
                    .map(
                      (row) => <String>[
                        row.equipmentLabel,
                        row.areaLabel,
                        '${row.openCount}',
                        '${row.criticalCount}',
                        '${row.delayedCount}',
                        '${row.waitingCount}',
                      ],
                    )
                    .toList(growable: false),
                emptyLabel: 'Sin equipos con OTs abiertas en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Movimientos resueltos de la semana',
            accent: accent,
            headers: const <String>[
              'OT',
              'Resultado',
              'Area',
              'Equipo',
              'Ultimo movimiento',
              'Responsable',
              'Observacion corta',
            ],
            rows: visibleResolvedRows
                .map(
                  (row) => <String>[
                    row.folio,
                    row.statusLabel,
                    row.areaLabel,
                    row.equipmentLabel,
                    _formatDateTimeShort(row.updatedAt!),
                    row.responsibleLabel,
                    row.shortDescription,
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'Todavia no hay OTs cerradas o rechazadas dentro de esta semana operativa.',
            headerColor: accent,
            maxRowsPerSection: 18,
            startOnNewPage: true,
            introNote: hiddenResolvedCount > 0
                ? 'Se muestran ${visibleResolvedRows.length} movimientos resueltos de ${insights.resolvedWeekRows.length}; el resto ya queda reflejado en los KPIs semanales.'
                : null,
          ),
          ..._pdfChunkedTableSections(
            title: 'Listado completo abierto',
            accent: accent,
            headers: const <String>[
              'OT',
              'Solicitada',
              'Area',
              'Equipo',
              'Estatus',
              'Prioridad',
              'Impacto',
              'Responsable',
              'Ultimo mov.',
              'Bloqueo actual',
            ],
            rows: visibleOpenRows
                .map(
                  (row) => <String>[
                    row.folio,
                    _formatShortDate(
                      row.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                    ),
                    row.areaLabel,
                    row.equipmentLabel,
                    row.statusLabel,
                    row.priorityLabel,
                    row.impactLabel,
                    row.responsibleLabel,
                    _formatDateTimeShort(
                      row.updatedAt ?? row.requestedAt ?? cut.cutoffAt,
                    ),
                    row.blockerLabel(cut),
                  ],
                )
                .toList(growable: false),
            emptyLabel: 'No hay OTs abiertas en este momento.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 16,
            introNote: hiddenOpenCount > 0
                ? 'Se muestran las ${visibleOpenRows.length} OTs abiertas con mayor riesgo de ${insights.openRows.length}; el resto se resume arriba por area, equipo y estatus.'
                : null,
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

Future<Uint8List> buildFinanceDailySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final sourceSnapshot = await loadFinanzasPaymentCenterSourceSnapshot();
  final operationalSnapshot = buildFinanzasPaymentCenterOperationalSnapshot(
    sourceSnapshot,
  );
  final insights = _buildFinanceDailyInsights(
    operationalSnapshot,
    generatedAt: generatedAt,
  );
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final dayStart = DateTime(
    generatedAt.year,
    generatedAt.month,
    generatedAt.day,
  );

  final visiblePlannedRows = insights.plannedItems
      .take(48)
      .toList(growable: false);
  final visibleBlockedUrgentRows = insights.blockedUrgentItems
      .take(36)
      .toList(growable: false);
  final visibleRiskRows = insights.riskItems.take(24).toList(growable: false);
  final hiddenPlannedCount =
      insights.plannedItems.length - visiblePlannedRows.length;
  final hiddenBlockedUrgentCount =
      insights.blockedUrgentItems.length - visibleBlockedUrgentRows.length;
  final hiddenRiskCount = insights.riskItems.length - visibleRiskRows.length;
  final visibleReserveRows = operationalSnapshot.reserveSummary.activeReserves
      .take(18)
      .toList(growable: false);
  final hiddenReserveCount =
      operationalSnapshot.reserveSummary.activeReserves.length -
      visibleReserveRows.length;
  final reserveIntroNote =
      operationalSnapshot.reserveSummary.activeReserves.isEmpty
      ? null
      : hiddenReserveCount > 0
      ? 'Estas reservas ya descuentan caja disponible. Se muestran ${visibleReserveRows.length} reservas activas de ${operationalSnapshot.reserveSummary.activeReserves.length}.'
      : 'Estas reservas ya descuentan caja disponible dentro del corte de hoy.';

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 60,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Finanzas · Presupuesto diario',
            subtitle:
                'Area Finanzas · corte diario de caja para decidir que si se paga hoy, que se protege y con cuanto se cierra la jornada.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry('Corte', _formatLongDateSpanish(dayStart)),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: presupuesto y pagos urgentes desde Centro de pagos.',
                ),
                _pdfBullet(
                  'La lectura parte del saldo bancario ya existente y de lo ya capturado en reservas, convenios, facturas y pagos fijos dentro de la app.',
                ),
                _pdfBullet(
                  'Si el dinero aun no entro al banco, aqui no se cuenta como caja disponible; primero responde que si se paga hoy y despues con que margen se llega a manana.',
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
            title: 'KPIs del dia',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem(
                  'Saldo en bancos',
                  _formatCurrency(insights.budgetToday.realTotalBalance),
                ),
                _PdfKpiItem(
                  'Reservas activas',
                  _formatCurrency(insights.budgetToday.protectedReserveTotal),
                ),
                _PdfKpiItem(
                  'Libre real hoy',
                  _formatCurrency(insights.budgetToday.availableBudgetAmount),
                ),
                _PdfKpiItem(
                  'Minimo visible hoy',
                  _formatCurrency(insights.budgetToday.minimumTodayAmount),
                ),
                _PdfKpiItem(
                  'Si se mueve hoy',
                  _formatCurrency(insights.budgetToday.plannedTodayAmount),
                  note: '${insights.plannedItems.length} movimientos',
                ),
                _PdfKpiItem(
                  'Libre al cierre',
                  _formatCurrency(insights.budgetToday.freeMarginAfterPlanned),
                  note:
                      'Manana visible ${_formatCurrency(insights.tomorrowCommittedAmount)}',
                ),
              ],
            ),
          ),
          if (visibleReserveRows.isNotEmpty)
            ..._pdfChunkedTableSections(
              title: 'Reservas protegidas activas',
              accent: accent,
              headers: const <String>[
                'Reserva',
                'Tipo',
                'Alcance',
                'Cuenta',
                'Monto',
                'Bloquea caja',
                'Vigencia',
              ],
              rows: visibleReserveRows
                  .map(
                    (reserve) => <String>[
                      _sanitizePdfText(_truncate(reserve.name, 32)),
                      _sanitizePdfText(
                        '${finPaymentCenterReserveTypeLabel(reserve.reserveType)} · ${finPaymentCenterReserveClassificationLabel(reserve.classification)}',
                      ),
                      _sanitizePdfText(
                        finPaymentCenterReserveScopeLabel(reserve.scopeType),
                      ),
                      _sanitizePdfText(
                        reserve.isGlobal
                            ? 'Global'
                            : _buildFinanceAccountLabel(
                                reserve.targetCompany ?? '',
                                reserve.targetBranch ?? '',
                              ),
                      ),
                      _formatCurrency(reserve.amount),
                      reserve.blocksCash ? 'Si' : 'No',
                      _sanitizePdfText(_buildReserveWindowLabel(reserve)),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel: 'No hay reservas protegidas activas visibles.',
              headerColor: accent,
              compact: true,
              maxRowsPerSection: 12,
              introNote: reserveIntroNote,
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
            title: 'Decision de caja hoy',
            accent: accent,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  insights.decisionHeadline,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#16202B'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(insights.decisionNarrative, style: _bodyStyle()),
                pw.SizedBox(height: 12),
                _pdfBulletList(insights.decisionSupportLines),
              ],
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Que si se paga hoy',
            accent: accent,
            headers: const <String>[
              'Proveedor',
              'Movimiento',
              'Referencia',
              'Vence',
              'Prioridad',
              'Decision',
              'Monto hoy',
              'Cuenta',
            ],
            rows: visiblePlannedRows
                .map(
                  (item) => <String>[
                    _sanitizePdfText(item.providerName),
                    item.itemType,
                    _sanitizePdfText(_truncate(item.sourceLabel, 42)),
                    _formatOptionalDate(item.dueDate),
                    item.urgencyLabel,
                    item.executionDecision.label,
                    _formatCurrency(item.executionAmount),
                    _sanitizePdfText(
                      _buildFinanceAccountLabel(
                        item.targetCompany,
                        item.targetBranch,
                      ),
                    ),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'Hoy no aparece un movimiento aterrizado para ejecutar desde la caja real visible.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 16,
            introNote: hiddenPlannedCount > 0
                ? 'Se muestran ${visiblePlannedRows.length} movimientos sugeridos de ${insights.plannedItems.length}; el resto queda resumido en los KPIs y por cuenta.'
                : null,
          ),
          ..._pdfChunkedTableSections(
            title: 'Lo urgente que no cabe hoy',
            accent: accent,
            headers: const <String>[
              'Proveedor',
              'Movimiento',
              'Referencia',
              'Vence',
              'Visible',
              'Hoy',
              'Cuenta',
              'Lectura',
            ],
            rows: visibleBlockedUrgentRows
                .map(
                  (item) => <String>[
                    _sanitizePdfText(item.providerName),
                    item.itemType,
                    _sanitizePdfText(_truncate(item.sourceLabel, 38)),
                    _formatOptionalDate(item.dueDate),
                    _formatCurrency(item.amountSuggested),
                    item.executionAmount > 0.009
                        ? _formatCurrency(item.executionAmount)
                        : 'Esperar',
                    _sanitizePdfText(
                      _buildFinanceAccountLabel(
                        item.targetCompany,
                        item.targetBranch,
                      ),
                    ),
                    _sanitizePdfText(
                      _truncate(
                        item.executionSummary.trim().isNotEmpty
                            ? item.executionSummary
                            : item.recommendation,
                        74,
                      ),
                    ),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay urgencias visibles pendientes fuera del plan del dia.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenBlockedUrgentCount > 0
                ? 'Se muestran ${visibleBlockedUrgentRows.length} urgencias bloqueadas o recortadas de ${insights.blockedUrgentItems.length}; el resto sigue reflejado en la lectura por cuenta.'
                : null,
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Como queda cada cuenta',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Cuenta',
                'Saldo real',
                'Reserva',
                'Libre real',
                'Minimo hoy',
                'Si sale hoy',
                'Pendiente visible',
                'Libre al cierre',
              ],
              rows: insights.budgetToday.accounts
                  .map(
                    (account) => <String>[
                      _sanitizePdfText(
                        _buildFinanceAccountLabel(
                          account.targetCompany,
                          account.targetBranch,
                        ),
                      ),
                      _formatCurrency(account.realBalance),
                      _formatCurrency(account.reserveAmount),
                      _formatCurrency(account.availableBalance),
                      _formatCurrency(account.minimumTodayAmount),
                      _formatCurrency(account.plannedTodayAmount),
                      _formatCurrency(account.pendingVisibleTodayAmount),
                      _formatCurrency(account.marginAfterPlanned),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel: 'No hay cuentas bancarias visibles en este corte.',
              headerColor: accent,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Resumen semanal visible',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Dia',
                'Comprometido',
                'Sugerido',
                'Proveedores',
                'Movimientos',
                'Libre tras comprometido',
                'Libre tras sugerido',
              ],
              rows: insights.budgetWeek.days
                  .map(
                    (day) => <String>[
                      _formatLongDateSpanish(day.date),
                      _formatCurrency(day.committedAmount),
                      _formatCurrency(day.suggestedAdditionalAmount),
                      '${day.providerCount}',
                      '${day.itemCount}',
                      _formatCurrency(day.remainingAfterCommitted),
                      _formatCurrency(day.remainingAfterSuggested),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'Todavia no hay una presion semanal visible para resumir.',
              headerColor: accent,
            ),
          ),
          if (visibleRiskRows.isNotEmpty)
            ..._pdfChunkedTableSections(
              title: 'Movimientos para revisar',
              accent: accent,
              headers: const <String>[
                'Proveedor',
                'Movimiento',
                'Referencia',
                'Vence',
                'Monto',
                'Cuenta',
                'Lectura',
              ],
              rows: visibleRiskRows
                  .map(
                    (item) => <String>[
                      _sanitizePdfText(item.providerName),
                      item.itemType,
                      _sanitizePdfText(_truncate(item.sourceLabel, 40)),
                      _formatOptionalDate(item.dueDate),
                      _formatCurrency(item.amountSuggested),
                      _sanitizePdfText(
                        _buildFinanceAccountLabel(
                          item.targetCompany,
                          item.targetBranch,
                        ),
                      ),
                      _sanitizePdfText(_truncate(item.recommendation, 72)),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel: 'No hay riesgos especiales a revisar hoy.',
              headerColor: accent,
              compact: true,
              maxRowsPerSection: 14,
              startOnNewPage: true,
              introNote: hiddenRiskCount > 0
                  ? 'Se muestran ${visibleRiskRows.length} riesgos de ${insights.riskItems.length}; el resto se agrupa dentro de la lectura ejecutiva.'
                  : null,
            ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Checklist de cierre',
            accent: accent,
            child: _pdfBulletList(insights.closeoutPrompts),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

Future<Uint8List> buildFinanceWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final results = await Future.wait<dynamic>([
    loadFinanzasPaymentCenterSourceSnapshot(),
    FinanzasBankAccountsStore.loadOpenClientAccounts(),
    FinanzasDueAlertsStore.loadSummary(),
  ]);
  final sourceSnapshot = results[0] as FinanzasPaymentCenterSourceSnapshot;
  final openClientAccounts =
      results[1] as List<FinanzasClientPaymentAccountRecord>;
  final dueAlerts = results[2] as FinanzasDueAlertsSummary;
  final operationalSnapshot = buildFinanzasPaymentCenterOperationalSnapshot(
    sourceSnapshot,
  );
  final insights = _buildFinanceWeeklyInsights(
    operationalSnapshot,
    sourceSnapshot: sourceSnapshot,
    openClientAccounts: openClientAccounts,
    dueAlerts: dueAlerts,
    generatedAt: generatedAt,
  );
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final week = insights.budgetWeek;
  final visibleProviderRows = insights.providerRows
      .take(24)
      .toList(growable: false);
  final visibleCommittedRows = insights.committedItems
      .take(36)
      .toList(growable: false);
  final visibleRiskRows = insights.riskItems.take(24).toList(growable: false);
  final visibleOutsideRows = insights.outsideWindowProviders
      .take(18)
      .toList(growable: false);
  final visibleOverdueRows = insights.overdueInvoiceRows
      .take(18)
      .toList(growable: false);
  final visibleAgreementRows = insights.agreementRows
      .take(18)
      .toList(growable: false);
  final visibleBankFlowRows = insights.bankFlowRows
      .take(10)
      .toList(growable: false);
  final hiddenProviderCount =
      insights.providerRows.length - visibleProviderRows.length;
  final hiddenCommittedCount =
      insights.committedItems.length - visibleCommittedRows.length;
  final hiddenRiskCount = insights.riskItems.length - visibleRiskRows.length;
  final hiddenOutsideCount =
      insights.outsideWindowProviders.length - visibleOutsideRows.length;
  final hiddenOverdueCount =
      insights.overdueInvoiceRows.length - visibleOverdueRows.length;
  final hiddenAgreementCount =
      insights.agreementRows.length - visibleAgreementRows.length;
  final marginKpiLabel = insights.fridayMarginAfterPressure < -0.009
      ? 'Descubierto al viernes'
      : 'Margen al viernes';
  final marginKpiNote =
      week.riskReviewAmount > 0.009 || week.outsideWindowAmount > 0.009
      ? 'Ext. riesgo ${_formatCurrency(week.riskReviewAmount)} | Fuera ${_formatCurrency(week.outsideWindowAmount)}'
      : 'Hasta ${_formatShortDate(insights.cut.friday)}';

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 70,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Finanzas · Corte viernes de presupuesto y flujo',
            subtitle:
                'Area Finanzas · lectura semanal para junta de viernes con caja protegida, vencidos, convenios y flujo bancario observado sin salir de la app.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry(
                'Junta viernes',
                '${_formatShortDate(insights.cut.weekStart)} - ${_formatShortDate(insights.cut.friday)}',
              ),
              MapEntry(
                'Observado hasta',
                _formatDateTimeShort(insights.cut.cutoffAt),
              ),
              MapEntry(
                'Horizonte ext.',
                '${_formatShortDate(week.startDate)} - ${_formatShortDate(week.endDate)}',
              ),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: presupuesto visible desde centro de pagos, mas snapshot de facturas vencidas, convenios y flujo bancario observado.',
                ),
                _pdfBullet(
                  'La junta del viernes cubre ${insights.cut.fridayWindowLabel}; los movimientos reales solo se observan hasta ${_formatDateTimeShort(insights.cut.cutoffAt)}.',
                ),
                _pdfBullet(
                  'El horizonte extendido llega al ${_formatLongDateSpanish(week.endDate)} para no esconder arrastre del fin de semana siguiente.',
                ),
                _pdfBullet(
                  'Comprometido = vencido o con fecha dentro de la ventana; sugerido = presion visible sin fecha aterrizada; riesgo = movimientos que aun requieren criterio o fecha para presupuestarse bien.',
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
            title: 'KPIs de la junta del viernes',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem(
                  'Caja protegida',
                  _formatCurrency(week.availableBudgetAmount),
                  note: 'Real ${_formatCurrency(week.realTotalBalance)}',
                ),
                _PdfKpiItem(
                  'Reservas activas',
                  _formatCurrency(week.protectedReserveTotal),
                  note:
                      '${operationalSnapshot.reserveSummary.activeCount} activas',
                ),
                _PdfKpiItem(
                  'Comprometido a viernes',
                  _formatCurrency(insights.fridayCommittedAmount),
                  note: '${insights.committedItems.length} movimientos',
                ),
                _PdfKpiItem(
                  'Presion adicional',
                  _formatCurrency(insights.fridaySuggestedAmount),
                  note: 'Visible al ${_formatShortDate(insights.cut.friday)}',
                ),
                _PdfKpiItem(
                  'Facturas vencidas',
                  _formatCurrency(insights.overdueVisibleAmount),
                  note: '${insights.overdueInvoiceRows.length} abiertas',
                ),
                _PdfKpiItem(
                  'Convenios atrasados',
                  '${insights.delayedAgreementCount}',
                  note: _formatCurrency(insights.delayedAgreementAmount),
                ),
                _PdfKpiItem(
                  marginKpiLabel,
                  _formatCurrency(insights.fridayMarginAfterPressure),
                  note: marginKpiNote,
                ),
                _PdfKpiItem(
                  'Flujo observado',
                  _formatCurrency(insights.observedWeekNet),
                  note:
                      'Entradas ${_formatCurrency(insights.observedWeekCredits)} | Salidas ${_formatCurrency(insights.observedWeekDebits)}',
                ),
                _PdfKpiItem(
                  'Cobranza abierta',
                  _formatCurrency(insights.openClientCollections),
                  note: 'No cuenta hasta entrar al banco',
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
            title: 'Lectura gerencial para la junta del viernes',
            accent: accent,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  insights.decisionHeadline,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#16202B'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(insights.decisionNarrative, style: _bodyStyle()),
                pw.SizedBox(height: 12),
                _pdfBulletList(insights.decisionSupportLines),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Pulso diario para la junta del viernes',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Dia',
                'Comprometido',
                'Sugerido',
                'Proveedores',
                'Movimientos',
                'Libre tras comprometido',
                'Libre tras presion',
              ],
              rows: week.days
                  .where(
                    (day) =>
                        !_pdfDateOnly(day.date).isAfter(insights.cut.friday),
                  )
                  .map(
                    (day) => <String>[
                      _formatLongDateSpanish(day.date),
                      _formatCurrency(day.committedAmount),
                      _formatCurrency(day.suggestedAdditionalAmount),
                      '${day.providerCount}',
                      '${day.itemCount}',
                      _formatCurrency(day.remainingAfterCommitted),
                      _formatCurrency(day.remainingAfterSuggested),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'Todavia no hay movimientos visibles dentro de la semana presupuestal.',
              headerColor: accent,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Facturas vencidas al corte observado',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenOverdueCount > 0
                  ? 'Se muestran ${visibleOverdueRows.length} facturas de ${insights.overdueInvoiceRows.length}; el resto sigue concentrado en el KPI de vencidos.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Proveedor',
                  'Folio',
                  'Vence',
                  'Dias atraso',
                  'Saldo',
                  'Prioridad',
                  'Estatus',
                ],
                rows: visibleOverdueRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(_truncate(row.providerName, 28)),
                        _sanitizePdfText(row.folio),
                        _formatShortDate(row.dueDate),
                        '${row.daysOverdueAt(insights.cut.cutoffAt)}',
                        _formatCurrency(row.balanceAmount),
                        row.priorityLabel,
                        row.statusLabel,
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay facturas vencidas visibles al ${_formatDateTimeShort(insights.cut.cutoffAt)}.',
                headerColor: accent,
                compact: true,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Convenios y negociacion visible',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenAgreementCount > 0
                  ? 'Se muestran ${visibleAgreementRows.length} convenios de ${insights.agreementRows.length}; el resto queda dentro del resumen ejecutivo.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Proveedor',
                  'Estatus',
                  'Prox. vence',
                  'Restante',
                  'Cuota',
                  'Tipo',
                  'Frecuencia',
                ],
                rows: visibleAgreementRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(_truncate(row.providerName, 28)),
                        row.statusLabel,
                        _formatOptionalDate(row.nextDueDate),
                        _formatCurrency(row.remainingAmount),
                        _formatCurrency(row.installmentAmount),
                        row.agreementTypeLabel,
                        row.frequencyLabel,
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay convenios activos o atrasados visibles para esta junta.',
                headerColor: accent,
                compact: true,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Flujo bancario observado de la semana',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Cuenta',
                'Entradas',
                'Salidas',
                'Neto',
                'Movimientos',
              ],
              rows: visibleBankFlowRows
                  .map(
                    (row) => <String>[
                      _sanitizePdfText(row.accountLabel),
                      _formatCurrency(row.credits),
                      _formatCurrency(row.debits),
                      _formatCurrency(row.netAmount),
                      '${row.movementCount}',
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No hay movimientos bancarios visibles del ${_formatLongDateSpanish(insights.cut.weekStart)} al ${_formatLongDateSpanish(_pdfDateOnly(insights.cut.cutoffAt))}.',
              headerColor: accent,
              compact: true,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Cuentas bancarias y caja protegida · horizonte extendido',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note:
                  'Este bloque ya mira del ${_formatLongDateSpanish(week.startDate)} al ${_formatLongDateSpanish(week.endDate)} para no esconder arrastre posterior al viernes.',
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Cuenta',
                  'Saldo real',
                  'Reserva',
                  'Libre',
                  'Comprometido',
                  'Sugerido',
                  'Margen tras comprometido',
                  'Margen tras presion',
                ],
                rows: week.accounts
                    .map(
                      (account) => <String>[
                        _sanitizePdfText(
                          _buildFinanceAccountLabel(
                            account.targetCompany,
                            account.targetBranch,
                          ),
                        ),
                        _formatCurrency(account.realBalance),
                        _formatCurrency(account.reserveAmount),
                        _formatCurrency(account.availableBalance),
                        _formatCurrency(account.committedWeekAmount),
                        _formatCurrency(account.suggestedAdditionalAmount),
                        _formatCurrency(account.marginAfterCommitted),
                        _formatCurrency(account.marginAfterWeekPressure),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay cuentas bancarias visibles para este horizonte extendido.',
                headerColor: accent,
              ),
            ),
          ),
          ..._pdfChunkedTableSections(
            title:
                'Proveedores con mayor presion visible · horizonte extendido',
            accent: accent,
            headers: const <String>[
              'Proveedor',
              'Foco',
              'Referencias',
              'Prox. vence',
              'Comprometido',
              'Sugerido',
              'Cuenta',
              'Lectura',
            ],
            rows: visibleProviderRows
                .map(
                  (provider) => <String>[
                    _sanitizePdfText(provider.providerName),
                    _sanitizePdfText(
                      provider.primaryActionItem?.itemType ?? 'Sin foco',
                    ),
                    _sanitizePdfText(
                      _truncate(provider.sourcePreviews.join(', '), 42),
                    ),
                    _formatOptionalDate(
                      _findFinanceWeeklyProviderDueDate(provider),
                    ),
                    _formatCurrency(provider.committedWeekAmount),
                    _formatCurrency(provider.suggestedAdditionalAmount),
                    _sanitizePdfText(
                      _buildFinanceAccountLabel(
                        provider.targetCompany,
                        provider.targetBranch,
                      ),
                    ),
                    _sanitizePdfText(
                      _truncate(
                        _buildFinanceWeeklyProviderReading(provider, week),
                        74,
                      ),
                    ),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay proveedores con presion visible dentro del horizonte extendido.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenProviderCount > 0
                ? 'Se muestran ${visibleProviderRows.length} proveedores de ${insights.providerRows.length}; el resto ya queda resumido por cuenta, por dia y por arrastre extendido.'
                : null,
          ),
          ..._pdfChunkedTableSections(
            title: 'Compromisos visibles por movimiento',
            accent: accent,
            headers: const <String>[
              'Proveedor',
              'Movimiento',
              'Referencia',
              'Vence',
              'Prioridad',
              'Monto',
              'Cuenta',
              'Lectura',
            ],
            rows: visibleCommittedRows
                .map(
                  (item) => <String>[
                    _sanitizePdfText(item.providerName),
                    item.itemType,
                    _sanitizePdfText(_truncate(item.sourceLabel, 40)),
                    _formatOptionalDate(item.dueDate),
                    item.urgencyLabel,
                    _formatCurrency(item.amountSuggested),
                    _sanitizePdfText(
                      _buildFinanceAccountLabel(
                        item.targetCompany,
                        item.targetBranch,
                      ),
                    ),
                    _sanitizePdfText(
                      _truncate(
                        _buildFinanceWeeklyMovementReading(item, week),
                        72,
                      ),
                    ),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay compromisos con fecha visible dentro de la semana activa.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 16,
            introNote: hiddenCommittedCount > 0
                ? 'Se muestran ${visibleCommittedRows.length} movimientos de ${insights.committedItems.length}; el resto sigue reflejado en la presion semanal.'
                : null,
          ),
          if (visibleRiskRows.isNotEmpty)
            ..._pdfChunkedTableSections(
              title: 'Riesgos a revisar antes de presupuestar',
              accent: accent,
              headers: const <String>[
                'Proveedor',
                'Movimiento',
                'Referencia',
                'Estado',
                'Monto',
                'Cuenta',
                'Lectura',
              ],
              rows: visibleRiskRows
                  .map(
                    (item) => <String>[
                      _sanitizePdfText(item.providerName),
                      item.itemType,
                      _sanitizePdfText(_truncate(item.sourceLabel, 40)),
                      _sanitizePdfText(_truncate(item.agreementLabel, 28)),
                      _formatCurrency(item.amountSuggested),
                      _sanitizePdfText(
                        _buildFinanceAccountLabel(
                          item.targetCompany,
                          item.targetBranch,
                        ),
                      ),
                      _sanitizePdfText(
                        _truncate(
                          _buildFinanceWeeklyMovementReading(item, week),
                          72,
                        ),
                      ),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel: 'No hay riesgos especiales a revisar.',
              headerColor: accent,
              compact: true,
              maxRowsPerSection: 14,
              startOnNewPage: true,
              introNote: hiddenRiskCount > 0
                  ? 'Se muestran ${visibleRiskRows.length} riesgos de ${insights.riskItems.length}; el resto sigue agrupado dentro de la lectura semanal.'
                  : null,
            ),
          if (visibleOutsideRows.isNotEmpty)
            ..._pdfChunkedTableSections(
              title: 'Abierto fuera de la semana visible',
              accent: accent,
              headers: const <String>[
                'Proveedor',
                'Foco',
                'Referencias',
                'Presion fuera',
                'Prox. vence',
                'Cuenta',
                'Lectura',
              ],
              rows: visibleOutsideRows
                  .map(
                    (provider) => <String>[
                      _sanitizePdfText(provider.providerName),
                      _sanitizePdfText(
                        provider.primaryActionItem?.itemType ?? 'Sin foco',
                      ),
                      _sanitizePdfText(
                        _truncate(provider.sourcePreviews.join(', '), 40),
                      ),
                      _formatCurrency(provider.outsideWindowAmount),
                      _formatOptionalDate(
                        _findFinanceWeeklyProviderDueDate(provider),
                      ),
                      _sanitizePdfText(
                        _buildFinanceAccountLabel(
                          provider.targetCompany,
                          provider.targetBranch,
                        ),
                      ),
                      _sanitizePdfText(
                        _truncate(
                          _buildFinanceWeeklyOutsideWindowReading(
                            provider,
                            week,
                          ),
                          72,
                        ),
                      ),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No hay arrastre visible fuera de esta semana presupuestal.',
              headerColor: accent,
              compact: true,
              maxRowsPerSection: 14,
              introNote: hiddenOutsideCount > 0
                  ? 'Se muestran ${visibleOutsideRows.length} proveedores con arrastre fuera de ventana de ${insights.outsideWindowProviders.length}.'
                  : null,
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

Future<Uint8List> buildExpensesDailySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final rows = await _loadExpensesDailyPurchaseOrderRows();
  final insights = _buildExpensesDailyInsights(rows, generatedAt);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final dayStart = DateTime(
    generatedAt.year,
    generatedAt.month,
    generatedAt.day,
  );

  final visibleFocusRows = insights.focusRows.take(12).toList(growable: false);
  final visibleMovementRows = insights.movementTodayRows
      .take(28)
      .toList(growable: false);
  final visibleOtLinkedRows = insights.otLinkedRows
      .take(32)
      .toList(growable: false);
  final visibleTargetRows = insights.targetRows
      .take(16)
      .toList(growable: false);
  final visibleBacklogRows = insights.backlogRows
      .take(32)
      .toList(growable: false);
  final hiddenMovementCount =
      insights.movementTodayRows.length - visibleMovementRows.length;
  final hiddenOtLinkedCount =
      insights.otLinkedRows.length - visibleOtLinkedRows.length;
  final hiddenBacklogCount =
      insights.backlogRows.length - visibleBacklogRows.length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 60,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Gastos · Seguimiento diario de OCs',
            subtitle:
                'Area Gastos · lectura diaria para decidir que compra si se mueve hoy, que OC sigue atorada y que arrastre operativo continua abierto desde Compras OT.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry('Corte', _formatLongDateSpanish(dayStart)),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: OCs y compras visibles desde maintenance_purchase_orders, sus renglones y la OT ligada cuando existe.',
                ),
                _pdfBullet(
                  'Urgencia visible en este PDF = OC abierta que ya esta en caja, sigue pendiente de Direccion, arrastra dias previos o esta ligada a OT.',
                ),
                _pdfBullet(
                  'La retroalimentacion automatica del flujo de compras sigue pendiente; este corte todavia no mide tiempos intermedios fuera de la propia OC.',
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
            title: 'KPIs del dia',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem(
                  'OCs activas',
                  '${insights.activeRows.length}',
                  note: _formatCurrency(insights.activeVisibleAmount),
                ),
                _PdfKpiItem(
                  'Mandadas a caja',
                  '${insights.sentToCashCount}',
                  note: _formatCurrency(insights.sentToCashVisibleAmount),
                ),
                _PdfKpiItem(
                  'Pend. Direccion',
                  '${insights.pendingDirectionCount}',
                  note: _formatCurrency(insights.pendingDirectionVisibleAmount),
                ),
                _PdfKpiItem(
                  'Ligadas a OT',
                  '${insights.otLinkedActiveCount}',
                  note: _formatCurrency(insights.otLinkedVisibleAmount),
                ),
                _PdfKpiItem(
                  'Compradas hoy',
                  '${insights.purchasedTodayRows.length}',
                  note: _formatCurrency(insights.purchasedTodayAmount),
                ),
                _PdfKpiItem(
                  'Arrastre abierto',
                  '${insights.backlogRows.length}',
                  note: insights.oldestBacklogDate == null
                      ? 'Sin arrastre previo'
                      : 'Desde ${_formatShortDate(insights.oldestBacklogDate!)}',
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
            title: 'Urgencia visible del dia',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'OC',
                'Fecha',
                'Estatus',
                'Destino',
                'Proveedor / concepto',
                'OT',
                'Monto',
                'Motivo',
              ],
              rows: visibleFocusRows
                  .map(
                    (row) => <String>[
                      row.folio,
                      _formatShortDate(row.orderDate),
                      row.statusLabel,
                      _sanitizePdfText(row.targetLabel),
                      _sanitizePdfText(
                        _truncate(row.vendorAndConceptLabel, 36),
                      ),
                      _sanitizePdfText(row.otLabel),
                      _formatCurrency(row.activeAmount),
                      _sanitizePdfText(
                        _truncate(row.focusReasonAt(dayStart), 38),
                      ),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No hay OCs activas con urgencia visible especial en este corte.',
              headerColor: accent,
              compact: true,
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Movimiento visible de hoy',
            accent: accent,
            headers: const <String>[
              'OC',
              'Movimiento',
              'Estatus',
              'Destino',
              'Proveedor / concepto',
              'OT',
              'Monto est.',
              'Monto real',
            ],
            rows: visibleMovementRows
                .map(
                  (row) => <String>[
                    row.folio,
                    _sanitizePdfText(
                      _truncate(row.movementLabelAt(dayStart), 28),
                    ),
                    row.statusLabel,
                    _sanitizePdfText(row.targetLabel),
                    _sanitizePdfText(_truncate(row.vendorAndConceptLabel, 28)),
                    _sanitizePdfText(row.otLabel),
                    row.estimatedTotal > 0.009
                        ? _formatCurrency(row.estimatedTotal)
                        : row.actualTotal != null
                        ? _formatCurrency(row.actualTotal!)
                        : '-',
                    row.actualTotal != null
                        ? _formatCurrency(row.actualTotal!)
                        : row.isPurchased
                        ? _formatCurrency(row.realizedAmount)
                        : '-',
                  ],
                )
                .toList(growable: false),
            emptyLabel: 'Hoy no hay movimiento visible dentro de las OCs.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenMovementCount > 0
                ? 'Se muestran ${visibleMovementRows.length} movimientos de hoy de ${insights.movementTodayRows.length}; el resto queda resumido en los KPIs.'
                : null,
          ),
          ..._pdfChunkedTableSections(
            title: 'Compras ligadas a OT',
            accent: accent,
            headers: const <String>[
              'OC',
              'OT',
              'Estatus OT',
              'Estatus OC',
              'Destino',
              'Concepto',
              'Monto',
              'Lectura',
            ],
            rows: visibleOtLinkedRows
                .map(
                  (row) => <String>[
                    row.folio,
                    _sanitizePdfText(row.otLabel),
                    _sanitizePdfText(row.linkedOtStatusLabel),
                    row.statusLabel,
                    _sanitizePdfText(row.targetLabel),
                    _sanitizePdfText(_truncate(row.conceptLabel, 24)),
                    _formatCurrency(
                      row.requiresFollowUp
                          ? row.activeAmount
                          : row.realizedAmount,
                    ),
                    _sanitizePdfText(_truncate(row.otFollowUpLabel, 40)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay OCs ligadas a OT con seguimiento visible en este corte.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenOtLinkedCount > 0
                ? 'Se muestran ${visibleOtLinkedRows.length} OCs ligadas a OT de ${insights.otLinkedRows.length}; el resto sigue agrupado en el resumen por destino.'
                : null,
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Resumen por destino',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Destino',
                'Activas',
                'Ligadas OT',
                'En caja',
                'Pend. Dir.',
                'Monto visible',
              ],
              rows: visibleTargetRows
                  .map(
                    (row) => <String>[
                      _sanitizePdfText(row.targetLabel),
                      '${row.activeCount}',
                      '${row.otLinkedCount}',
                      '${row.sentToCashCount}',
                      '${row.pendingDirectionCount}',
                      _formatCurrency(row.activeAmount),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No hay OCs activas para resumir por destino en este momento.',
              headerColor: accent,
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Arrastre abierto',
            accent: accent,
            headers: const <String>[
              'OC',
              'Fecha',
              'Dias',
              'Estatus',
              'Destino',
              'Proveedor / concepto',
              'Monto',
              'Lectura',
            ],
            rows: visibleBacklogRows
                .map(
                  (row) => <String>[
                    row.folio,
                    _formatShortDate(row.orderDate),
                    '${row.backlogAgeDaysAt(dayStart)}',
                    row.statusLabel,
                    _sanitizePdfText(row.targetLabel),
                    _sanitizePdfText(_truncate(row.vendorAndConceptLabel, 24)),
                    _formatCurrency(row.activeAmount),
                    _sanitizePdfText(_truncate(row.backlogReadLabel, 40)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay OCs activas arrastradas desde dias previos en este corte.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            startOnNewPage: true,
            introNote: hiddenBacklogCount > 0
                ? 'Se muestran ${visibleBacklogRows.length} OCs arrastradas de ${insights.backlogRows.length}; el resto queda resumido en el KPI de arrastre.'
                : null,
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

Future<Uint8List> buildSalesDailySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final rows = await _loadSalesDailyReportRows();
  final insights = _buildSalesDailyInsights(rows, generatedAt);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final dayStart = DateTime(
    generatedAt.year,
    generatedAt.month,
    generatedAt.day,
  );

  final visibleFocusRows = insights.focusRows.take(12).toList(growable: false);
  final visiblePendingTodayRows = insights.pendingTodayRows
      .take(42)
      .toList(growable: false);
  final visibleBacklogRows = insights.backlogPendingRows
      .take(36)
      .toList(growable: false);
  final visibleClientRows = insights.clientRows
      .take(16)
      .toList(growable: false);
  final hiddenPendingTodayCount =
      insights.pendingTodayRows.length - visiblePendingTodayRows.length;
  final hiddenBacklogCount =
      insights.backlogPendingRows.length - visibleBacklogRows.length;
  final hiddenClientCount =
      insights.clientRows.length - visibleClientRows.length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 70,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Ventas · Pendientes de relacionar o documentar',
            subtitle:
                'Area Ventas · lectura diaria para revisar que venta quedo colgada hoy, que arrastre sigue abierto y quien debe moverlo antes de cerrar el dia sin mezclar facturas con cheques.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry('Corte', _formatLongDateSpanish(dayStart)),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: ventas pendientes de relacionar desde mayoreo_sales_reports y ventas relacionadas pendientes de documentar desde mayoreo_accounts.',
                ),
                _pdfBullet(
                  'Por relacionar = la venta todavia no trae aprobacion comercial visible; por documentar = ya se relaciono, pero sigue faltando factura o documento comercial.',
                ),
                _pdfBullet(
                  'Este corte cruza la captura operativa con Cuentas Mayoreo para definir exactamente que sigue colgado hoy antes de cerrar el dia.',
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
            title: 'KPIs del dia',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem('Reportes hoy', '${insights.todayRows.length}'),
                _PdfKpiItem(
                  'Relacionados hoy',
                  '${insights.relatedTodayRows.length}',
                ),
                _PdfKpiItem(
                  'Pendientes hoy',
                  '${insights.pendingTodayRows.length}',
                ),
                _PdfKpiItem(
                  'Por relacionar',
                  '${insights.pendingRelationshipCount}',
                ),
                _PdfKpiItem(
                  'Por documentar',
                  '${insights.pendingDocumentCount}',
                ),
                _PdfKpiItem('Por revisar', '${insights.pendingReviewCount}'),
                _PdfKpiItem(
                  'Arrastre previo',
                  '${insights.backlogPendingRows.length}',
                ),
                _PdfKpiItem(
                  'KG pendientes',
                  '${_formatQuantity(insights.pendingVisibleWeight)} KG',
                ),
                _PdfKpiItem(
                  'Importe pendiente visible',
                  _formatCurrency(insights.pendingVisibleAmount),
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
                'Fecha',
                'Cliente',
                'Etapa',
                'Remision',
                'Material',
                'Tipo',
                'Importe',
                'Motivo',
              ],
              rows: visibleFocusRows
                  .map(
                    (row) => <String>[
                      _formatShortDate(row.date),
                      _sanitizePdfText(row.clientName),
                      row.pendingStageLabel,
                      _sanitizePdfText(row.remisionLabel),
                      _sanitizePdfText(_truncate(row.materialName, 28)),
                      row.operationTypeLabel,
                      _formatCurrency(row.pendingSnapshotAmount),
                      _sanitizePdfText(row.focusReasonAt(dayStart)),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'Hoy no hay ventas pendientes visibles para seguir en junta.',
              headerColor: accent,
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Pendientes operativos capturados hoy',
            accent: accent,
            headers: const <String>[
              'Ticket',
              'Cliente',
              'Remision',
              'Material',
              'Etapa',
              'Tipo',
              'Importe vis.',
              'Lectura',
            ],
            rows: visiblePendingTodayRows
                .map(
                  (row) => <String>[
                    _sanitizePdfText(row.ticket),
                    _sanitizePdfText(row.clientName),
                    _sanitizePdfText(row.remisionLabel),
                    _sanitizePdfText(_truncate(row.materialName, 24)),
                    row.pendingStageLabel,
                    row.operationTypeLabel,
                    _formatCurrency(row.pendingSnapshotAmount),
                    _sanitizePdfText(_truncate(row.attentionLabel, 42)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'Todo lo capturado hoy ya quedo relacionado y documentado dentro de Ventas.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenPendingTodayCount > 0
                ? 'Se muestran ${visiblePendingTodayRows.length} pendientes de hoy de ${insights.pendingTodayRows.length}; el resto sigue resumido en los KPIs.'
                : null,
          ),
          ..._pdfChunkedTableSections(
            title: 'Arrastre pendiente previo',
            accent: accent,
            headers: const <String>[
              'Fecha',
              'Dias',
              'Ticket',
              'Cliente',
              'Remision',
              'Etapa',
              'Tipo',
              'Importe vis.',
              'Lectura',
            ],
            rows: visibleBacklogRows
                .map(
                  (row) => <String>[
                    _formatShortDate(row.date),
                    '${row.pendingAgeDaysAt(dayStart)}',
                    _sanitizePdfText(row.ticket),
                    _sanitizePdfText(row.clientName),
                    _sanitizePdfText(row.remisionLabel),
                    row.pendingStageLabel,
                    row.operationTypeLabel,
                    _formatCurrency(row.pendingSnapshotAmount),
                    _sanitizePdfText(_truncate(row.attentionLabel, 38)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay arrastre pendiente previo al ${_formatLongDateSpanish(dayStart)}.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenBacklogCount > 0
                ? 'Se muestran ${visibleBacklogRows.length} arrastres previos de ${insights.backlogPendingRows.length}; el resto queda agrupado por cliente.'
                : null,
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Clientes con mas presion pendiente',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenClientCount > 0
                  ? 'Se muestran los ${visibleClientRows.length} clientes con mayor pendiente visible de ${insights.clientRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Cliente',
                  'Pend. hoy',
                  'Arrastre',
                  'Por rel.',
                  'Por doc.',
                  'Total pend.',
                  'Importe vis.',
                  'Mas antigua',
                ],
                rows: visibleClientRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(row.clientName),
                        '${row.pendingTodayCount}',
                        '${row.backlogCount}',
                        '${row.relationshipPendingCount}',
                        '${row.documentPendingCount}',
                        '${row.totalPendingCount}',
                        _formatCurrency(row.pendingAmount),
                        row.oldestPendingDate == null
                            ? '-'
                            : _formatShortDate(row.oldestPendingDate!),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay clientes con pendiente visible en este corte.',
                headerColor: accent,
              ),
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

Future<Uint8List> buildSalesWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final cut = _resolveSalesWeeklyCut(generatedAt);
  final rows = await _loadSalesCollectionAccountRows(cut);
  final insights = _buildSalesWeeklyCollectionInsights(rows, cut);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final visibleClientRows = insights.clientRows
      .take(18)
      .toList(growable: false);
  final visibleOpenRows = insights.openRows.take(42).toList(growable: false);
  final visibleCollectedRows = insights.collectedWeekRows
      .take(32)
      .toList(growable: false);
  final hiddenClientCount =
      insights.clientRows.length - visibleClientRows.length;
  final hiddenOpenCount = insights.openRows.length - visibleOpenRows.length;
  final hiddenCollectedCount =
      insights.collectedWeekRows.length - visibleCollectedRows.length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 70,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Ventas · Facturas y cheques pendientes de cobrar',
            subtitle:
                'Area Ventas · corte semanal para revisar cobranza abierta, arrastre, promesas de pago y movimiento real de cobro visible.',
            badges: <MapEntry<String, String>>[
              MapEntry(
                'Corte',
                '${_formatShortDate(cut.weekStart)} - ${_formatShortDate(cut.friday)}',
              ),
              MapEntry('Area', area.title),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: facturas y cheques pendientes de cobrar desde mayoreo_accounts, reconciliados contra movimientos bancarios VENTA_FACTURA.',
                ),
                _pdfBullet(
                  'Pendiente = cuenta comercial abierta con saldo visible por cobrar; cobrada en semana = registro con movimiento o liquidacion visible dentro del corte activo.',
                ),
                _pdfBullet(
                  'El corte semanal activo va del ${_formatLongDateSpanish(cut.weekStart)} al ${_formatLongDateSpanish(cut.friday)} y esta acumulado unicamente hasta ${_formatDateTimeShort(cut.cutoffAt)}.',
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
            title: 'KPIs semanales de cobranza',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem('Cuentas abiertas', '${insights.openRows.length}'),
                _PdfKpiItem(
                  'Saldo pendiente',
                  _formatCurrency(insights.totalPendingBalance),
                ),
                _PdfKpiItem(
                  'Promesas vencidas',
                  '${insights.overdueEstimatedRows.length}',
                  note: 'Fecha estimada vencida',
                ),
                _PdfKpiItem(
                  'Pend. de facturar',
                  '${insights.pendingInvoiceRows.length}',
                ),
                _PdfKpiItem(
                  'Cobrado en semana',
                  _formatCurrency(insights.collectedWeekAmount),
                  note: '${insights.collectedWeekRows.length} movimientos',
                ),
                _PdfKpiItem('Pago parcial', '${insights.partialRows.length}'),
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
            title: 'Foco semanal',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Cliente',
                'Documento',
                'Tipo',
                'Vta.',
                'Promesa',
                'Saldo',
                'Estatus',
                'Motivo',
              ],
              rows: insights.focusRows
                  .map(
                    (row) => <String>[
                      _sanitizePdfText(row.clientName),
                      _sanitizePdfText(row.documentLabel),
                      row.operationTypeLabel,
                      _formatShortDate(row.saleDate),
                      _formatOptionalDate(row.estimatedPaymentDate),
                      _formatCurrency(row.pendingBalance),
                      row.statusLabel,
                      _sanitizePdfText(row.focusReason(cut)),
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No hay cuentas abiertas con foco especial en este corte.',
              headerColor: accent,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Resumen por cliente',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenClientCount > 0
                  ? 'Se muestran los ${visibleClientRows.length} clientes con mayor saldo pendiente de ${insights.clientRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Cliente',
                  'Abiertas',
                  'Promesa vencida',
                  'Pend. facturar',
                  'Pago parcial',
                  'Saldo pendiente',
                  'Mas antigua',
                ],
                rows: visibleClientRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(row.clientName),
                        '${row.openCount}',
                        '${row.overdueCount}',
                        '${row.pendingInvoiceCount}',
                        '${row.partialCount}',
                        _formatCurrency(row.pendingBalance),
                        row.oldestSaleDate == null
                            ? '-'
                            : _formatShortDate(row.oldestSaleDate!),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay clientes con cobranza pendiente en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Listado completo pendiente',
            accent: accent,
            headers: const <String>[
              'Cliente',
              'Documento',
              'Tipo',
              'Venta',
              'Promesa pago',
              'Pagado',
              'Pendiente',
              'Estatus',
              'Lectura',
            ],
            rows: visibleOpenRows
                .map(
                  (row) => <String>[
                    _sanitizePdfText(row.clientName),
                    _sanitizePdfText(row.documentLabel),
                    row.operationTypeLabel,
                    _formatShortDate(row.saleDate),
                    _formatOptionalDate(row.estimatedPaymentDate),
                    _formatCurrency(row.paidAmount),
                    _formatCurrency(row.pendingBalance),
                    row.statusLabel,
                    _sanitizePdfText(_truncate(row.collectionNote, 48)),
                  ],
                )
                .toList(growable: false),
            emptyLabel: 'No hay cobranza pendiente visible en este momento.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenOpenCount > 0
                ? 'Se muestran las ${visibleOpenRows.length} cuentas con mayor riesgo de ${insights.openRows.length}; el resto se resume por cliente arriba.'
                : null,
          ),
          ..._pdfChunkedTableSections(
            title: 'Cobranza visible de la semana',
            accent: accent,
            headers: const <String>[
              'Cliente',
              'Documento',
              'Tipo',
              'Ultimo cobro',
              'Monto cobrado',
              'Saldo actual',
              'Estatus',
            ],
            rows: visibleCollectedRows
                .map(
                  (row) => <String>[
                    _sanitizePdfText(row.clientName),
                    _sanitizePdfText(row.documentLabel),
                    row.operationTypeLabel,
                    _formatOptionalDate(row.latestPaymentAt),
                    _formatCurrency(row.paidThisWeekAmount(cut)),
                    _formatCurrency(row.pendingBalance),
                    row.statusLabel,
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'Todavia no hay cobranza visible registrada dentro de esta semana operativa.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenCollectedCount > 0
                ? 'Se muestran ${visibleCollectedRows.length} movimientos cobrados de ${insights.collectedWeekRows.length}; el resto ya queda reflejado en los KPIs.'
                : null,
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

Future<Uint8List> buildMenudeoWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final cut = _resolveMenudeoWeeklyCut(generatedAt);
  final source = await _loadMenudeoWeeklySourceBundle(cut);
  final insights = _buildMenudeoWeeklyInsights(source, cut);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final visibleCounterpartyRows = insights.counterpartyRows
      .take(18)
      .toList(growable: false);
  final visibleVoucherRows = insights.voucherRubricRows
      .take(16)
      .toList(growable: false);
  final visibleAdjustmentRows = insights.adjustmentRows
      .take(28)
      .toList(growable: false);
  final visibleCashCutRows = insights.cashCutRows
      .take(14)
      .toList(growable: false);
  final visibleIssueRows = insights.issueRows.take(36).toList(growable: false);
  final hiddenCounterpartyCount =
      insights.counterpartyRows.length - visibleCounterpartyRows.length;
  final hiddenVoucherCount =
      insights.voucherRubricRows.length - visibleVoucherRows.length;
  final hiddenAdjustmentCount =
      insights.adjustmentRows.length - visibleAdjustmentRows.length;
  final hiddenCashCutCount =
      insights.cashCutRows.length - visibleCashCutRows.length;
  final hiddenIssueCount = insights.issueRows.length - visibleIssueRows.length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 70,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Menudeo · caja, compras y ventas semanales',
            subtitle:
                'Area Menudeo · corte semanal para revisar compras, ventas, caja, ajustes de precio y salud comercial real sin recapturar informacion.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry(
                'Corte',
                '${_formatShortDate(cut.weekStart)} - ${_formatShortDate(cut.friday)}',
              ),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: tickets de compra y venta desde vw_men_tickets_grid, vouchers desde vw_men_cash_vouchers_grid, cortes desde vw_men_cash_cuts_grid y ajustes desde vw_men_price_adjustment_history.',
                ),
                _pdfBullet(
                  'El corte semanal activo va del ${_formatLongDateSpanish(cut.weekStart)} al ${_formatLongDateSpanish(cut.friday)} y esta acumulado unicamente hasta ${_formatDateTimeShort(cut.cutoffAt)}.',
                ),
                _pdfBullet(
                  'La comparacion compra vs venta usa el mismo avance operativo de la semana previa: ${_formatLongDateSpanish(cut.previousWeekStart)} al ${_formatLongDateSpanish(cut.previousProgressEnd)}.',
                ),
                _pdfBullet(
                  'Este reporte no reemplaza tickets, vouchers ni caja; los resume para la junta del viernes y cualquier correccion se hace en la fuente origen.',
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
            title: 'KPIs semanales de menudeo',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem(
                  'Compras visibles',
                  '${insights.purchaseRow.currentTicketCount}',
                  note:
                      '${_formatQuantity(insights.purchaseRow.currentPayableKg)} KG',
                ),
                _PdfKpiItem(
                  'Ventas visibles',
                  '${insights.saleRow.currentTicketCount}',
                  note:
                      '${_formatQuantity(insights.saleRow.currentPayableKg)} KG',
                ),
                _PdfKpiItem(
                  'Venta - compra',
                  _formatCurrency(insights.visibleCommercialSpread),
                  note:
                      'Venta ${_formatCurrency(insights.saleRow.currentAmount)}',
                ),
                _PdfKpiItem(
                  'Depositos / gastos',
                  _formatCurrency(insights.currentDepositsAmount),
                  note:
                      'Gastos ${_formatCurrency(insights.currentExpensesAmount)}',
                ),
                _PdfKpiItem(
                  'Ajustes de precio',
                  '${insights.currentAdjustmentCount}',
                  note: '${insights.adjustmentsWithoutReasonCount} sin motivo',
                ),
                _PdfKpiItem(
                  'Cortes cerrados',
                  '${insights.closedCashCutCount}',
                  note: 'Dif. ${_formatCurrency(insights.totalCashDifference)}',
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
            title: 'Comparativo compra vs venta',
            accent: accent,
            child: _pdfSimpleTable(
              headers: const <String>[
                'Frente',
                'Tickets act.',
                'Tickets prev.',
                'KG act.',
                'KG prev.',
                'Importe act.',
                'Importe prev.',
                'Precio medio act.',
                'Delta importe',
              ],
              rows: insights.directionRows
                  .map(
                    (row) => <String>[
                      row.directionLabel,
                      '${row.currentTicketCount}',
                      '${row.previousTicketCount}',
                      '${_formatQuantity(row.currentPayableKg)} KG',
                      '${_formatQuantity(row.previousPayableKg)} KG',
                      _formatCurrency(row.currentAmount),
                      _formatCurrency(row.previousAmount),
                      _formatCurrency(row.currentAveragePrice),
                      '${row.deltaAmount >= 0 ? '+' : '-'}${_formatCurrency(row.deltaAmount.abs())}',
                    ],
                  )
                  .toList(growable: false),
              emptyLabel:
                  'No hay tickets visibles de compra o venta para comparar en este corte.',
              headerColor: accent,
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Contrapartes con mayor movimiento',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenCounterpartyCount > 0
                  ? 'Se muestran las ${visibleCounterpartyRows.length} contrapartes con mayor movimiento de ${insights.counterpartyRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Frente',
                  'Contraparte',
                  'Tickets',
                  'Pend.',
                  'KG',
                  'Importe',
                  'Precio medio',
                  'Lectura',
                ],
                rows: visibleCounterpartyRows
                    .map(
                      (row) => <String>[
                        row.directionLabel,
                        _sanitizePdfText(row.counterpartyLabel),
                        '${row.ticketCount}',
                        '${row.pendingCount}',
                        '${_formatQuantity(row.payableKg)} KG',
                        _formatCurrency(row.amount),
                        _formatCurrency(row.averagePrice),
                        _sanitizePdfText(_truncate(row.note, 50)),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay contrapartes con tickets visibles en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Rubros de caja visibles',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenVoucherCount > 0
                  ? 'Se muestran los ${visibleVoucherRows.length} rubros con mayor monto de ${insights.voucherRubricRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Tipo',
                  'Rubro',
                  'Vouchers',
                  'Importe',
                  'Personas',
                  'Lectura',
                ],
                rows: visibleVoucherRows
                    .map(
                      (row) => <String>[
                        row.typeLabel,
                        _sanitizePdfText(row.rubricLabel),
                        '${row.voucherCount}',
                        _formatCurrency(row.totalAmount),
                        '${row.personCount}',
                        _sanitizePdfText(_truncate(row.note, 52)),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay vouchers visibles de deposito o gasto dentro de este corte.',
                headerColor: accent,
              ),
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Ajustes de precio de la semana',
            accent: accent,
            headers: const <String>[
              'Fecha',
              'Frente',
              'Contraparte',
              'Material',
              'Anterior',
              'Nuevo',
              'Delta',
              'Motivo',
            ],
            rows: visibleAdjustmentRows
                .map(
                  (row) => <String>[
                    _formatOptionalDate(row.createdAt),
                    row.directionLabel,
                    _sanitizePdfText(_truncate(row.counterpartyLabel, 24)),
                    _sanitizePdfText(_truncate(row.materialLabel, 24)),
                    _formatCurrency(row.previousPrice),
                    _formatCurrency(row.newPrice),
                    '${row.delta >= 0 ? '+' : '-'}${_formatCurrency(row.delta.abs())}',
                    _sanitizePdfText(_truncate(row.reasonLabel, 40)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay ajustes de precio visibles registrados en esta semana.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 12,
            introNote: hiddenAdjustmentCount > 0
                ? 'Se muestran ${visibleAdjustmentRows.length} ajustes de ${insights.adjustmentRows.length}; el resto ya queda resumido en KPIs y alertas.'
                : null,
          ),
          _pdfSection(
            title: 'Cortes de caja de la semana',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenCashCutCount > 0
                  ? 'Se muestran ${visibleCashCutRows.length} cortes de ${insights.cashCutRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Fecha',
                  'Estatus',
                  'Ventas',
                  'Compras',
                  'Depositos',
                  'Gastos',
                  'Conteo',
                  'Diferencia',
                  'Pend.',
                ],
                rows: visibleCashCutRows
                    .map(
                      (row) => <String>[
                        _formatOptionalDate(row.date),
                        row.statusLabel,
                        _formatCurrency(row.salesTotal),
                        _formatCurrency(row.purchasesTotal),
                        _formatCurrency(row.depositsTotal),
                        _formatCurrency(row.expensesTotal),
                        _formatCurrency(row.countedCashTotal),
                        _formatCurrency(row.differenceTotal),
                        '${row.pendingChecksCount}',
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay cortes de caja visibles dentro de este corte semanal.',
                headerColor: accent,
              ),
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Tickets, caja y precios a revisar',
            accent: accent,
            headers: const <String>[
              'Fuente',
              'Fecha',
              'Referencia',
              'Estatus',
              'Lectura',
            ],
            rows: visibleIssueRows
                .map(
                  (row) => <String>[
                    row.sourceLabel,
                    _formatOptionalDate(row.date),
                    _sanitizePdfText(_truncate(row.referenceLabel, 28)),
                    _sanitizePdfText(row.statusLabel),
                    _sanitizePdfText(_truncate(row.note, 60)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay hallazgos visibles de tickets, caja o ajustes en este corte.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            startOnNewPage: true,
            introNote: hiddenIssueCount > 0
                ? 'Se muestran ${visibleIssueRows.length} hallazgos de ${insights.issueRows.length}; el resto ya queda reflejado en alertas y KPIs.'
                : null,
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

_MenudeoWeeklyCut _resolveMenudeoWeeklyCut(DateTime generatedAt) {
  final friday = _nextOrSameFriday(generatedAt);
  final weekStart = friday.subtract(const Duration(days: 4));
  final fridayEnd = DateTime(
    friday.year,
    friday.month,
    friday.day,
    23,
    59,
    59,
    999,
  );
  final cutoffAt = generatedAt.isBefore(fridayEnd) ? generatedAt : fridayEnd;
  return _MenudeoWeeklyCut(
    weekStart: weekStart,
    friday: friday,
    cutoffAt: cutoffAt,
  );
}

Future<_MenudeoWeeklySourceBundle> _loadMenudeoWeeklySourceBundle(
  _MenudeoWeeklyCut cut,
) async {
  final currentStart = _formatDbDate(cut.weekStart);
  final currentEnd = _formatDbDate(cut.progressEnd);
  final previousStart = _formatDbDate(cut.previousWeekStart);
  final previousEnd = _formatDbDate(cut.previousProgressEnd);
  final adjustmentsCurrentEndExclusive = _formatDbDate(
    cut.progressEnd.add(const Duration(days: 1)),
  );

  final results = await Future.wait<dynamic>([
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('vw_men_tickets_grid')
          .select(_kMenudeoWeeklyTicketFields)
          .gte('ticket_date', currentStart)
          .lte('ticket_date', currentEnd)
          .order('ticket_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('vw_men_tickets_grid')
          .select(_kMenudeoWeeklyTicketFields)
          .gte('ticket_date', previousStart)
          .lte('ticket_date', previousEnd)
          .order('ticket_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('vw_men_cash_vouchers_grid')
          .select(_kMenudeoWeeklyVoucherFields)
          .gte('voucher_date', currentStart)
          .lte('voucher_date', currentEnd)
          .order('voucher_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('vw_men_cash_cuts_grid')
          .select(_kMenudeoWeeklyCashCutFields)
          .gte('cut_date', currentStart)
          .lte('cut_date', currentEnd)
          .order('cut_date', ascending: true)
          .order('opened_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('vw_men_price_adjustment_history')
          .select(_kMenudeoWeeklyPriceAdjustmentFields)
          .gte('created_at', currentStart)
          .lt('created_at', adjustmentsCurrentEndExclusive)
          .order('created_at', ascending: false)
          .range(from, to),
    ),
  ]);

  List<Map<String, dynamic>> jsonList(dynamic raw) {
    return (raw as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  return _MenudeoWeeklySourceBundle(
    currentTicketRows: jsonList(
      results[0],
    ).map(_MenudeoWeeklyTicketRow.fromJson).toList(growable: false),
    previousTicketRows: jsonList(
      results[1],
    ).map(_MenudeoWeeklyTicketRow.fromJson).toList(growable: false),
    currentVoucherRows: jsonList(
      results[2],
    ).map(_MenudeoWeeklyVoucherRow.fromJson).toList(growable: false),
    currentCashCutRows: jsonList(
      results[3],
    ).map(_MenudeoWeeklyCashCutRow.fromJson).toList(growable: false),
    currentAdjustmentRows: jsonList(
      results[4],
    ).map(_MenudeoWeeklyPriceAdjustmentRow.fromJson).toList(growable: false),
  );
}

_MenudeoWeeklyInsights _buildMenudeoWeeklyInsights(
  _MenudeoWeeklySourceBundle source,
  _MenudeoWeeklyCut cut,
) {
  final purchaseRow = _summarizeMenudeoDirection(
    direction: 'purchase',
    currentRows: source.currentTicketRows,
    previousRows: source.previousTicketRows,
  );
  final saleRow = _summarizeMenudeoDirection(
    direction: 'sale',
    currentRows: source.currentTicketRows,
    previousRows: source.previousTicketRows,
  );
  final currentDepositsAmount = source.currentVoucherRows
      .where((row) => row.isDeposit)
      .fold<double>(0, (sum, row) => sum + row.totalAmount);
  final currentExpensesAmount = source.currentVoucherRows
      .where((row) => row.isExpense)
      .fold<double>(0, (sum, row) => sum + row.totalAmount);
  final closedCashCutCount = source.currentCashCutRows
      .where((row) => row.isClosed)
      .length;
  final openCashCutCount =
      source.currentCashCutRows.length - closedCashCutCount;
  final totalCashDifference = source.currentCashCutRows.fold<double>(
    0,
    (sum, row) => sum + row.differenceTotal,
  );
  final pendingChecksCount = source.currentCashCutRows.fold<int>(
    0,
    (sum, row) => sum + row.pendingChecksCount,
  );
  final currentAdjustmentCount = source.currentAdjustmentRows.length;
  final adjustmentsWithoutReasonCount = source.currentAdjustmentRows
      .where((row) => !row.hasReason)
      .length;
  final missingPriceLinkCount = source.currentTicketRows
      .where((row) => !row.hasPriceLink)
      .length;
  final paidSalesWithoutExitOrderCount = source.currentTicketRows
      .where((row) => row.isSale && row.isPaid && !row.hasExitOrder)
      .length;
  final pendingCarryoverCount = source.currentTicketRows
      .where(
        (row) =>
            row.isPending && _pdfDateOnly(row.date).isBefore(cut.progressEnd),
      )
      .length;
  final cashCutsWithDifferenceCount = source.currentCashCutRows
      .where((row) => row.differenceTotal.abs() >= 0.01)
      .length;
  final vouchersMissingRubricCount = source.currentVoucherRows
      .where((row) => row.isExpense && !row.hasRubric)
      .length;

  final counterpartyRows = _summarizeMenudeoCounterpartyRows(
    source.currentTicketRows,
  );
  final voucherRubricRows = _summarizeMenudeoVoucherRubricRows(
    source.currentVoucherRows,
  );
  final adjustmentRows = [...source.currentAdjustmentRows]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final cashCutRows = [...source.currentCashCutRows]
    ..sort((a, b) => b.date.compareTo(a.date));
  final issueRows = _collectMenudeoIssueRows(
    currentTicketRows: source.currentTicketRows,
    currentVoucherRows: source.currentVoucherRows,
    currentCashCutRows: source.currentCashCutRows,
    currentAdjustmentRows: source.currentAdjustmentRows,
    cut: cut,
  );

  final visibleCommercialSpread =
      saleRow.currentAmount - purchaseRow.currentAmount;
  final executiveSummary = <String>[];
  if (source.currentTicketRows.isEmpty &&
      source.currentVoucherRows.isEmpty &&
      source.currentCashCutRows.isEmpty &&
      source.currentAdjustmentRows.isEmpty) {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)} no hay actividad visible capturada en tickets, caja o ajustes de Menudeo.',
    );
  } else {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)}, Menudeo registra ${purchaseRow.currentTicketCount} ticket(s) de compra por ${_formatCurrency(purchaseRow.currentAmount)} y ${saleRow.currentTicketCount} ticket(s) de venta por ${_formatCurrency(saleRow.currentAmount)}.',
    );
    executiveSummary.add(
      'Contra el mismo avance operativo de la semana previa, compras van ${purchaseRow.deltaTicketCount >= 0 ? '+' : ''}${purchaseRow.deltaTicketCount} ticket(s) y ventas ${saleRow.deltaTicketCount >= 0 ? '+' : ''}${saleRow.deltaTicketCount} ticket(s).',
    );
    executiveSummary.add(
      'La lectura visible venta - compra de la semana es ${_formatCurrency(visibleCommercialSpread)}, con depositos por ${_formatCurrency(currentDepositsAmount)} y gastos por ${_formatCurrency(currentExpensesAmount)}.',
    );
    executiveSummary.add(
      'Se movieron $currentAdjustmentCount ajuste(s) de precio y ${source.currentCashCutRows.length} bloque(s) de caja visibles, de los cuales $closedCashCutCount ya quedaron cerrados.',
    );
    if (counterpartyRows.isNotEmpty) {
      executiveSummary.add(
        'La contraparte con mayor movimiento visible es ${_sanitizePdfText(counterpartyRows.first.counterpartyLabel)} en ${counterpartyRows.first.directionLabel} con ${counterpartyRows.first.ticketCount} ticket(s) por ${_formatCurrency(counterpartyRows.first.amount)}.',
      );
    }
    if (issueRows.isNotEmpty) {
      executiveSummary.add(
        'Quedan ${issueRows.length} hallazgo(s) visibles entre tickets, caja y precios para revisar antes del cierre semanal.',
      );
    } else {
      executiveSummary.add(
        'No hay hallazgos visibles abiertos en tickets, caja ni precios dentro de este corte.',
      );
    }
  }

  final alerts = <String>[];
  if (pendingCarryoverCount > 0) {
    alerts.add(
      'Hay $pendingCarryoverCount ticket(s) que siguen pendientes desde dias previos de la semana.',
    );
  }
  if (paidSalesWithoutExitOrderCount > 0) {
    alerts.add(
      'Hay $paidSalesWithoutExitOrderCount venta(s) marcadas como pagadas sin numero de orden de salida visible.',
    );
  }
  if (missingPriceLinkCount > 0) {
    alerts.add(
      'Hay $missingPriceLinkCount ticket(s) sin precio ligado al catalogo historico.',
    );
  }
  if (vouchersMissingRubricCount > 0) {
    alerts.add(
      'Hay $vouchersMissingRubricCount gasto(s) sin rubro capturado dentro de caja.',
    );
  }
  if (cashCutsWithDifferenceCount > 0) {
    alerts.add(
      'Hay $cashCutsWithDifferenceCount corte(s) con diferencia distinta de cero.',
    );
  }
  if (pendingChecksCount > 0) {
    alerts.add(
      'Siguen $pendingChecksCount movimiento(s) pendientes de checar dentro de los bloques de caja visibles.',
    );
  }
  if (adjustmentsWithoutReasonCount > 0) {
    alerts.add(
      'Hay $adjustmentsWithoutReasonCount ajuste(s) de precio sin motivo capturado.',
    );
  }
  if (visibleCommercialSpread < 0) {
    alerts.add(
      'La lectura visible venta - compra de la semana va negativa en ${_formatCurrency(visibleCommercialSpread.abs())}.',
    );
  }
  if (openCashCutCount > 0) {
    alerts.add(
      'Hay $openCashCutCount bloque(s) de caja todavia abiertos dentro del periodo visible.',
    );
  }

  final closeoutPrompts = <String>[
    'Toda compra o venta que siga pendiente debe salir de la junta con responsable, siguiente paso y hora compromiso.',
    if (paidSalesWithoutExitOrderCount > 0)
      'Toda venta pagada sin orden de salida debe aclararse hoy mismo para no contaminar la lectura comercial.',
    if (cashCutsWithDifferenceCount > 0 || pendingChecksCount > 0)
      'Todo corte con diferencia o pendientes por checar debe cerrarse con causa raiz y accion puntual.',
    if (vouchersMissingRubricCount > 0)
      'Todo gasto sin rubro debe reclasificarse en caja antes del siguiente corte.',
    if (adjustmentsWithoutReasonCount > 0)
      'Todo ajuste de precio sin motivo debe completarse para dejar trazabilidad comercial.',
    'Si un ticket, voucher, corte o precio ya cambio, se corrige en Menudeo y se regenera el reporte; no se maquilla el PDF.',
  ];

  return _MenudeoWeeklyInsights(
    purchaseRow: purchaseRow,
    saleRow: saleRow,
    directionRows: <_MenudeoWeeklyDirectionRow>[purchaseRow, saleRow],
    currentDepositsAmount: currentDepositsAmount,
    currentExpensesAmount: currentExpensesAmount,
    currentAdjustmentCount: currentAdjustmentCount,
    adjustmentsWithoutReasonCount: adjustmentsWithoutReasonCount,
    closedCashCutCount: closedCashCutCount,
    openCashCutCount: openCashCutCount,
    totalCashDifference: totalCashDifference,
    visibleCommercialSpread: visibleCommercialSpread,
    counterpartyRows: counterpartyRows,
    voucherRubricRows: voucherRubricRows,
    adjustmentRows: adjustmentRows,
    cashCutRows: cashCutRows,
    issueRows: issueRows,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

_MenudeoWeeklyDirectionRow _summarizeMenudeoDirection({
  required String direction,
  required List<_MenudeoWeeklyTicketRow> currentRows,
  required List<_MenudeoWeeklyTicketRow> previousRows,
}) {
  final current = currentRows
      .where((row) => row.direction == direction)
      .toList(growable: false);
  final previous = previousRows
      .where((row) => row.direction == direction)
      .toList(growable: false);
  final currentPayableKg = current.fold<double>(
    0,
    (sum, row) => sum + row.payableWeight,
  );
  final previousPayableKg = previous.fold<double>(
    0,
    (sum, row) => sum + row.payableWeight,
  );
  final currentAmount = current.fold<double>(
    0,
    (sum, row) => sum + row.amountTotal,
  );
  final previousAmount = previous.fold<double>(
    0,
    (sum, row) => sum + row.amountTotal,
  );
  return _MenudeoWeeklyDirectionRow(
    direction: direction,
    currentTicketCount: current.length,
    previousTicketCount: previous.length,
    currentPayableKg: currentPayableKg,
    previousPayableKg: previousPayableKg,
    currentAmount: currentAmount,
    previousAmount: previousAmount,
  );
}

List<_MenudeoWeeklyCounterpartyRow> _summarizeMenudeoCounterpartyRows(
  List<_MenudeoWeeklyTicketRow> rows,
) {
  final buckets = <String, List<_MenudeoWeeklyTicketRow>>{};
  for (final row in rows) {
    final key = '${row.direction}|${_normalizeTag(row.counterpartyName)}';
    buckets.putIfAbsent(key, () => <_MenudeoWeeklyTicketRow>[]).add(row);
  }
  final summaryRows =
      buckets.entries
          .map((entry) {
            final items = entry.value;
            final direction = items.first.direction;
            final payableKg = items.fold<double>(
              0,
              (sum, row) => sum + row.payableWeight,
            );
            final amount = items.fold<double>(
              0,
              (sum, row) => sum + row.amountTotal,
            );
            final pendingCount = items.where((row) => row.isPending).length;
            final materialCount = items
                .map((row) => row.materialLabel)
                .where((value) => value.trim().isNotEmpty)
                .toSet()
                .length;
            final noteParts = <String>[
              '$materialCount material(es)',
              if (pendingCount > 0) '$pendingCount pendiente(s)',
            ];
            return _MenudeoWeeklyCounterpartyRow(
              direction: direction,
              counterpartyLabel: items.first.counterpartyLabel,
              ticketCount: items.length,
              pendingCount: pendingCount,
              payableKg: payableKg,
              amount: amount,
              note: noteParts.join(' | '),
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final amountCompare = b.amount.compareTo(a.amount);
          if (amountCompare != 0) return amountCompare;
          final ticketCompare = b.ticketCount.compareTo(a.ticketCount);
          if (ticketCompare != 0) return ticketCompare;
          return a.counterpartyLabel.toLowerCase().compareTo(
            b.counterpartyLabel.toLowerCase(),
          );
        });
  return summaryRows;
}

List<_MenudeoWeeklyVoucherRubricRow> _summarizeMenudeoVoucherRubricRows(
  List<_MenudeoWeeklyVoucherRow> rows,
) {
  final buckets = <String, List<_MenudeoWeeklyVoucherRow>>{};
  for (final row in rows) {
    final key = '${row.voucherType}|${_normalizeTag(row.rubric)}';
    buckets.putIfAbsent(key, () => <_MenudeoWeeklyVoucherRow>[]).add(row);
  }
  final summaryRows =
      buckets.entries
          .map((entry) {
            final items = entry.value;
            final totalAmount = items.fold<double>(
              0,
              (sum, row) => sum + row.totalAmount,
            );
            final personCount = items
                .map((row) => row.personLabel)
                .where((value) => value.trim().isNotEmpty)
                .toSet()
                .length;
            final maxLineCount = items.fold<int>(
              0,
              (current, row) =>
                  row.lineCount > current ? row.lineCount : current,
            );
            final noteParts = <String>[
              '$maxLineCount concepto(s) max.',
              if (personCount > 0) '$personCount persona(s)',
            ];
            return _MenudeoWeeklyVoucherRubricRow(
              voucherType: items.first.voucherType,
              rubricLabel: items.first.rubricLabel,
              voucherCount: items.length,
              totalAmount: totalAmount,
              personCount: personCount,
              note: noteParts.join(' | '),
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final amountCompare = b.totalAmount.compareTo(a.totalAmount);
          if (amountCompare != 0) return amountCompare;
          final voucherCompare = b.voucherCount.compareTo(a.voucherCount);
          if (voucherCompare != 0) return voucherCompare;
          return a.rubricLabel.toLowerCase().compareTo(
            b.rubricLabel.toLowerCase(),
          );
        });
  return summaryRows;
}

List<_MenudeoWeeklyIssueRow> _collectMenudeoIssueRows({
  required List<_MenudeoWeeklyTicketRow> currentTicketRows,
  required List<_MenudeoWeeklyVoucherRow> currentVoucherRows,
  required List<_MenudeoWeeklyCashCutRow> currentCashCutRows,
  required List<_MenudeoWeeklyPriceAdjustmentRow> currentAdjustmentRows,
  required _MenudeoWeeklyCut cut,
}) {
  final issueRows = <_MenudeoWeeklyIssueRow>[];

  for (final row in currentTicketRows) {
    final noteParts = <String>[];
    var severity = 0;
    if (!row.hasPriceLink) {
      noteParts.add('Sin precio ligado al catalogo');
      severity = 5;
    }
    if (!row.hasCounterparty) {
      noteParts.add('Sin contraparte');
      if (severity < 4) severity = 4;
    }
    if (!row.hasMaterial) {
      noteParts.add('Sin material');
      if (severity < 4) severity = 4;
    }
    if (row.isSale && row.isPaid && !row.hasExitOrder) {
      noteParts.add('Venta pagada sin orden de salida');
      if (severity < 4) severity = 4;
    }
    if (row.isPending && _pdfDateOnly(row.date).isBefore(cut.progressEnd)) {
      noteParts.add('Sigue pendiente de dia previo');
      if (severity < 3) severity = 3;
    }
    if (noteParts.isEmpty) continue;
    if (row.comment.trim().isNotEmpty) {
      noteParts.add(_truncate(row.comment.trim(), 28));
    }
    issueRows.add(
      _MenudeoWeeklyIssueRow(
        sourceLabel: row.directionLabel,
        date: row.date,
        referenceLabel: row.ticketNumber,
        statusLabel: row.statusLabel,
        note: noteParts.join(' | '),
        severity: severity,
      ),
    );
  }

  for (final row in currentVoucherRows) {
    final noteParts = <String>[];
    var severity = 0;
    if (row.isExpense && !row.hasRubric) {
      noteParts.add('Gasto sin rubro');
      severity = 4;
    }
    if (!row.hasPerson) {
      noteParts.add('Sin responsable');
      if (severity < 3) severity = 3;
    }
    if (row.lineCount <= 0) {
      noteParts.add('Sin lineas visibles');
      if (severity < 4) severity = 4;
    }
    if (noteParts.isEmpty) continue;
    if (row.comment.trim().isNotEmpty) {
      noteParts.add(_truncate(row.comment.trim(), 28));
    }
    issueRows.add(
      _MenudeoWeeklyIssueRow(
        sourceLabel: row.typeLabel,
        date: row.date,
        referenceLabel: row.folio,
        statusLabel: row.rubricLabel,
        note: noteParts.join(' | '),
        severity: severity,
      ),
    );
  }

  for (final row in currentCashCutRows) {
    final noteParts = <String>[];
    var severity = 0;
    if (row.differenceTotal.abs() >= 0.01) {
      noteParts.add('Dif. ${_formatCurrency(row.differenceTotal)}');
      severity = 5;
    }
    if (row.pendingChecksCount > 0) {
      noteParts.add('${row.pendingChecksCount} pendiente(s) por checar');
      if (severity < 4) severity = 4;
    }
    if (!row.isClosed && _pdfDateOnly(row.date).isBefore(cut.progressEnd)) {
      noteParts.add('Bloque sigue abierto');
      if (severity < 3) severity = 3;
    }
    if (noteParts.isEmpty) continue;
    if (row.notes.trim().isNotEmpty) {
      noteParts.add(_truncate(row.notes.trim(), 28));
    }
    issueRows.add(
      _MenudeoWeeklyIssueRow(
        sourceLabel: 'Caja',
        date: row.date,
        referenceLabel: _formatShortDate(row.date),
        statusLabel: row.statusLabel,
        note: noteParts.join(' | '),
        severity: severity,
      ),
    );
  }

  for (final row in currentAdjustmentRows) {
    if (row.hasReason) continue;
    issueRows.add(
      _MenudeoWeeklyIssueRow(
        sourceLabel: 'Precio',
        date: row.createdAt,
        referenceLabel: row.counterpartyLabel,
        statusLabel: row.directionLabel,
        note:
            'Ajuste sin motivo capturado | ${_truncate(row.materialLabel, 30)}',
        severity: 3,
      ),
    );
  }

  issueRows.sort((a, b) {
    final severityCompare = b.severity.compareTo(a.severity);
    if (severityCompare != 0) return severityCompare;
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    return a.referenceLabel.toLowerCase().compareTo(
      b.referenceLabel.toLowerCase(),
    );
  });
  return issueRows;
}

String _menudeoDirectionLabel(String raw) {
  switch (_normalizeTag(raw)) {
    case 'purchase':
      return 'Compra';
    case 'sale':
      return 'Venta';
    default:
      return raw.trim().isEmpty ? 'Sin frente' : raw.trim();
  }
}

String _menudeoVoucherTypeLabel(String raw) {
  switch (_normalizeTag(raw)) {
    case 'deposit':
      return 'Deposito';
    case 'expense':
      return 'Gasto';
    default:
      return raw.trim().isEmpty ? 'Sin tipo' : raw.trim();
  }
}

Future<Uint8List> buildLogisticsWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final cut = _resolveLogisticsWeeklyCut(generatedAt);
  final source = await _loadLogisticsWeeklySourceBundle(cut);
  final insights = _buildLogisticsWeeklyInsights(source, cut);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final visibleOperatorRows = insights.operatorRows
      .take(18)
      .toList(growable: false);
  final visibleUnitRows = insights.unitRows.take(18).toList(growable: false);
  final visibleCompanyRows = insights.companyRows
      .take(18)
      .toList(growable: false);
  final visibleIssueRows = insights.issueRows.take(32).toList(growable: false);
  final hiddenOperatorCount =
      insights.operatorRows.length - visibleOperatorRows.length;
  final hiddenUnitCount = insights.unitRows.length - visibleUnitRows.length;
  final hiddenCompanyCount =
      insights.companyRows.length - visibleCompanyRows.length;
  final hiddenIssueCount = insights.issueRows.length - visibleIssueRows.length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 70,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Logistica · viajes y combustible semanal',
            subtitle:
                'Area Logistica · corte semanal para revisar viajes visibles, combustible por chofer y unidad, empresas con mayor movimiento y cancelaciones o faltantes operativos.',
            badges: <MapEntry<String, String>>[
              MapEntry('Area', area.title),
              MapEntry(
                'Corte',
                '${_formatShortDate(cut.weekStart)} - ${_formatShortDate(cut.friday)}',
              ),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: servicios de area LOGISTICA por due_date, diesel de logistics_diesel_consumption y gasolina de logistics_gasoline_control.',
                ),
                _pdfBullet(
                  'Viaje visible = servicio de Logistica con fecha comprometida dentro del corte. El corte semanal activo va del ${_formatLongDateSpanish(cut.weekStart)} al ${_formatLongDateSpanish(cut.friday)} y esta acumulado unicamente hasta ${_formatDateTimeShort(cut.cutoffAt)}.',
                ),
                _pdfBullet(
                  'La comparacion contra semana pasada usa el mismo avance operativo: ${_formatLongDateSpanish(cut.previousWeekStart)} al ${_formatLongDateSpanish(cut.previousProgressEnd)}.',
                ),
                _pdfBullet(
                  'Este corte todavia no cuantifica kilometros ni incidencias humanas formalizadas porque esa fuente aun no vive homologada en la app.',
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
            title: 'KPIs semanales de logistica',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem(
                  'Viajes visibles',
                  '${insights.currentTripCount}',
                  note:
                      'Vs previo ${_formatSignedCount(insights.currentTripCount - insights.previousTripCount)}',
                ),
                _PdfKpiItem(
                  'Completados',
                  '${insights.completedTripCount}',
                  note: '${insights.inProgressTripCount} en curso',
                ),
                _PdfKpiItem(
                  'Cancelados',
                  '${insights.canceledTripCount}',
                  note: '${insights.pendingTripCount} por ejecutar',
                ),
                _PdfKpiItem(
                  'Sin asignacion',
                  '${insights.unassignedTripCount}',
                  note: 'Chofer o unidad faltante',
                ),
                _PdfKpiItem(
                  'Diesel solicitado',
                  '${_formatQuantity(insights.currentDieselRequestedLiters)} L',
                  note:
                      'Comprado ${_formatQuantity(insights.currentDieselPurchasedLiters)} L',
                ),
                _PdfKpiItem(
                  'Gasolina cargada',
                  '${_formatQuantity(insights.currentGasolineLoadedLiters)} L',
                  note:
                      'Comb. visible ${_formatQuantity(insights.currentFuelVisibleLiters)} L',
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
            title: 'Combustible por chofer',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenOperatorCount > 0
                  ? 'Se muestran los ${visibleOperatorRows.length} choferes con mayor carga visible de ${insights.operatorRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Chofer',
                  'Viajes',
                  'Diesel sol.',
                  'Diesel comp.',
                  'Gasolina',
                  'Comb. visible',
                  'Unidades',
                  'Lectura',
                ],
                rows: visibleOperatorRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(row.operatorLabel),
                        '${row.tripCount}',
                        '${_formatQuantity(row.dieselRequestedLiters)} L',
                        '${_formatQuantity(row.dieselPurchasedLiters)} L',
                        '${_formatQuantity(row.gasolineLoadedLiters)} L',
                        '${_formatQuantity(row.fuelVisibleLiters)} L',
                        '${row.unitCount}',
                        _sanitizePdfText(_truncate(row.note, 50)),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay choferes con viajes o combustible visible en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Presion por unidad',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenUnitCount > 0
                  ? 'Se muestran las ${visibleUnitRows.length} unidades con mayor carga visible de ${insights.unitRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Unidad',
                  'Viajes',
                  'Diesel sol.',
                  'Gasolina',
                  'Comb. visible',
                  'Choferes',
                  'Cancelados',
                  'Lectura',
                ],
                rows: visibleUnitRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(row.unitLabel),
                        '${row.tripCount}',
                        '${_formatQuantity(row.dieselRequestedLiters)} L',
                        '${_formatQuantity(row.gasolineLoadedLiters)} L',
                        '${_formatQuantity(row.fuelVisibleLiters)} L',
                        '${row.operatorCount}',
                        '${row.canceledTripCount}',
                        _sanitizePdfText(_truncate(row.note, 50)),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay unidades con viajes o combustible visible en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Empresas con mayor movimiento',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenCompanyCount > 0
                  ? 'Se muestran las ${visibleCompanyRows.length} empresas con mayor movimiento de ${insights.companyRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Empresa / destino',
                  'Viajes',
                  'Completados',
                  'Cancelados',
                  'Choferes',
                  'Unidades',
                  'Lectura',
                ],
                rows: visibleCompanyRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(row.companyLabel),
                        '${row.tripCount}',
                        '${row.completedTripCount}',
                        '${row.canceledTripCount}',
                        '${row.operatorCount}',
                        '${row.unitCount}',
                        _sanitizePdfText(_truncate(row.note, 52)),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay empresas con viajes visibles en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Viajes y capturas a revisar',
            accent: accent,
            headers: const <String>[
              'Fuente',
              'Fecha',
              'Referencia',
              'Estatus',
              'Chofer / unidad',
              'Lectura',
            ],
            rows: visibleIssueRows
                .map(
                  (row) => <String>[
                    row.sourceLabel,
                    _formatOptionalDate(row.date),
                    _sanitizePdfText(_truncate(row.referenceLabel, 28)),
                    _sanitizePdfText(row.statusLabel),
                    _sanitizePdfText(_truncate(row.assignmentLabel, 30)),
                    _sanitizePdfText(_truncate(row.note, 58)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay viajes ni capturas con observaciones visibles en este corte.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            introNote: hiddenIssueCount > 0
                ? 'Se muestran ${visibleIssueRows.length} hallazgos de ${insights.issueRows.length}; el resto ya queda reflejado en alertas y KPIs.'
                : null,
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

_LogisticsWeeklyCut _resolveLogisticsWeeklyCut(DateTime generatedAt) {
  final friday = _nextOrSameFriday(generatedAt);
  final weekStart = friday.subtract(const Duration(days: 4));
  final fridayEnd = DateTime(
    friday.year,
    friday.month,
    friday.day,
    23,
    59,
    59,
    999,
  );
  final cutoffAt = generatedAt.isBefore(fridayEnd) ? generatedAt : fridayEnd;
  return _LogisticsWeeklyCut(
    weekStart: weekStart,
    friday: friday,
    cutoffAt: cutoffAt,
  );
}

Future<_LogisticsWeeklySourceBundle> _loadLogisticsWeeklySourceBundle(
  _LogisticsWeeklyCut cut,
) async {
  final currentStart = _formatDbDate(cut.weekStart);
  final currentEnd = _formatDbDate(cut.progressEnd);
  final previousStart = _formatDbDate(cut.previousWeekStart);
  final previousEnd = _formatDbDate(cut.previousProgressEnd);
  final results = await Future.wait<dynamic>([
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('logistics_diesel_consumption')
          .select(
            'id,entry_date,operator_name,vehicle_label,liters_purchased,'
            'liters_requested,balance_liters,created_at',
          )
          .gte('entry_date', currentStart)
          .lte('entry_date', currentEnd)
          .order('entry_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('logistics_diesel_consumption')
          .select(
            'id,entry_date,operator_name,vehicle_label,liters_purchased,'
            'liters_requested,balance_liters,created_at',
          )
          .gte('entry_date', previousStart)
          .lte('entry_date', previousEnd)
          .order('entry_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('logistics_gasoline_control')
          .select(
            'id,entry_date,operator_name,vehicle_label,liters_loaded,notes,'
            'created_at',
          )
          .gte('entry_date', currentStart)
          .lte('entry_date', currentEnd)
          .order('entry_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('logistics_gasoline_control')
          .select(
            'id,entry_date,operator_name,vehicle_label,liters_loaded,notes,'
            'created_at',
          )
          .gte('entry_date', previousStart)
          .lte('entry_date', previousEnd)
          .order('entry_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('services')
          .select(
            'id,service_date,due_date,status,planning_kind,direction,'
            'driver_employee_id,vehicle_id,notes,area,client_name,created_at',
          )
          .eq('area', 'LOGISTICA')
          .gte('due_date', currentStart)
          .lte('due_date', currentEnd)
          .order('due_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('services')
          .select(
            'id,service_date,due_date,status,planning_kind,direction,'
            'driver_employee_id,vehicle_id,notes,area,client_name,created_at',
          )
          .eq('area', 'LOGISTICA')
          .gte('due_date', previousStart)
          .lte('due_date', previousEnd)
          .order('due_date', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    Supabase.instance.client
        .from('employees')
        .select('id,full_name')
        .eq('is_driver', true)
        .order('full_name'),
    Supabase.instance.client.from('vehicles').select('id,code').order('code'),
  ]);

  List<Map<String, dynamic>> jsonList(dynamic raw) {
    return (raw as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  final driverNamesById = <String, String>{};
  for (final row in jsonList(results[6])) {
    final id = _cleanString(row['id']);
    final fullName = _cleanString(row['full_name']);
    if (id.isEmpty || fullName.isEmpty) continue;
    driverNamesById[id] = fullName;
  }

  final vehicleLabelsById = <String, String>{};
  for (final row in jsonList(results[7])) {
    final id = _cleanString(row['id']);
    final code = _cleanString(row['code']);
    if (id.isEmpty || code.isEmpty) continue;
    vehicleLabelsById[id] = code;
  }

  return _LogisticsWeeklySourceBundle(
    currentDieselRows: jsonList(
      results[0],
    ).map(_LogisticsWeeklyDieselRow.fromJson).toList(growable: false),
    previousDieselRows: jsonList(
      results[1],
    ).map(_LogisticsWeeklyDieselRow.fromJson).toList(growable: false),
    currentGasolineRows: jsonList(
      results[2],
    ).map(_LogisticsWeeklyGasolineRow.fromJson).toList(growable: false),
    previousGasolineRows: jsonList(
      results[3],
    ).map(_LogisticsWeeklyGasolineRow.fromJson).toList(growable: false),
    currentServiceRows: jsonList(results[4])
        .map(
          (row) => _LogisticsWeeklyServiceRow.fromJson(
            row,
            driverNamesById: driverNamesById,
            vehicleLabelsById: vehicleLabelsById,
          ),
        )
        .toList(growable: false),
    previousServiceRows: jsonList(results[5])
        .map(
          (row) => _LogisticsWeeklyServiceRow.fromJson(
            row,
            driverNamesById: driverNamesById,
            vehicleLabelsById: vehicleLabelsById,
          ),
        )
        .toList(growable: false),
  );
}

_LogisticsWeeklyInsights _buildLogisticsWeeklyInsights(
  _LogisticsWeeklySourceBundle source,
  _LogisticsWeeklyCut cut,
) {
  final currentTripCount = source.currentServiceRows.length;
  final previousTripCount = source.previousServiceRows.length;
  final completedTripCount = source.currentServiceRows
      .where((row) => row.isCompleted)
      .length;
  final inProgressTripCount = source.currentServiceRows
      .where((row) => row.isInProgress)
      .length;
  final canceledTripCount = source.currentServiceRows
      .where((row) => row.isCanceled)
      .length;
  final pendingTripCountRaw =
      currentTripCount -
      completedTripCount -
      inProgressTripCount -
      canceledTripCount;
  final pendingTripCount = pendingTripCountRaw < 0 ? 0 : pendingTripCountRaw;
  final unassignedTripCount = source.currentServiceRows
      .where((row) => !row.hasAssignedDriver || !row.hasAssignedVehicle)
      .length;

  final currentDieselRequestedLiters = source.currentDieselRows.fold<double>(
    0,
    (sum, row) => sum + row.litersRequested,
  );
  final currentDieselPurchasedLiters = source.currentDieselRows.fold<double>(
    0,
    (sum, row) => sum + row.litersPurchased,
  );
  final previousDieselRequestedLiters = source.previousDieselRows.fold<double>(
    0,
    (sum, row) => sum + row.litersRequested,
  );
  final currentGasolineLoadedLiters = source.currentGasolineRows.fold<double>(
    0,
    (sum, row) => sum + row.litersLoaded,
  );
  final previousGasolineLoadedLiters = source.previousGasolineRows.fold<double>(
    0,
    (sum, row) => sum + row.litersLoaded,
  );
  final currentFuelVisibleLiters =
      currentDieselRequestedLiters + currentGasolineLoadedLiters;
  final previousFuelVisibleLiters =
      previousDieselRequestedLiters + previousGasolineLoadedLiters;
  final negativeDieselBalanceCount = source.currentDieselRows
      .where((row) => row.hasNegativeBalance)
      .length;

  final operatorRows = _summarizeLogisticsOperatorRows(
    currentServices: source.currentServiceRows,
    currentDieselRows: source.currentDieselRows,
    currentGasolineRows: source.currentGasolineRows,
  );
  final unitRows = _summarizeLogisticsUnitRows(
    currentServices: source.currentServiceRows,
    currentDieselRows: source.currentDieselRows,
    currentGasolineRows: source.currentGasolineRows,
  );
  final companyRows = _summarizeLogisticsCompanyRows(source.currentServiceRows);
  final issueRows = _collectLogisticsIssueRows(
    currentServices: source.currentServiceRows,
    currentDieselRows: source.currentDieselRows,
    currentGasolineRows: source.currentGasolineRows,
  );

  final executiveSummary = <String>[];
  if (currentTripCount == 0 &&
      currentFuelVisibleLiters <= 0.01 &&
      source.currentDieselRows.isEmpty &&
      source.currentGasolineRows.isEmpty) {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)} no hay viajes ni combustible visible capturado para Logistica.',
    );
  } else {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)}, Logistica registra $currentTripCount viaje(s) visibles: $completedTripCount completado(s), $inProgressTripCount en curso, $pendingTripCount por ejecutar y $canceledTripCount cancelado(s).',
    );
    executiveSummary.add(
      'El combustible visible suma ${_formatQuantity(currentFuelVisibleLiters)} L: diesel solicitado ${_formatQuantity(currentDieselRequestedLiters)} L, diesel comprado ${_formatQuantity(currentDieselPurchasedLiters)} L y gasolina cargada ${_formatQuantity(currentGasolineLoadedLiters)} L.',
    );
    executiveSummary.add(
      'Contra el mismo avance operativo de la semana previa, los viajes van ${_formatSignedCount(currentTripCount - previousTripCount)} y el combustible visible ${currentFuelVisibleLiters - previousFuelVisibleLiters >= 0 ? '+' : '-'}${_formatQuantity((currentFuelVisibleLiters - previousFuelVisibleLiters).abs())} L.',
    );
    if (operatorRows.isNotEmpty) {
      executiveSummary.add(
        'El chofer con mayor carga visible es ${_sanitizePdfText(operatorRows.first.operatorLabel)} con ${operatorRows.first.tripCount} viaje(s) y ${_formatQuantity(operatorRows.first.fuelVisibleLiters)} L.',
      );
    }
    if (unitRows.isNotEmpty) {
      executiveSummary.add(
        'La unidad con mayor carga visible es ${_sanitizePdfText(unitRows.first.unitLabel)} con ${unitRows.first.tripCount} viaje(s) y ${_formatQuantity(unitRows.first.fuelVisibleLiters)} L.',
      );
    }
    if (unassignedTripCount > 0 || issueRows.isNotEmpty) {
      executiveSummary.add(
        'Quedan $unassignedTripCount viaje(s) sin asignacion completa y ${issueRows.length} hallazgo(s) visibles para revisar antes de cerrar la semana.',
      );
    } else {
      executiveSummary.add(
        'No hay viajes sin asignacion completa ni hallazgos visibles abiertos dentro del corte actual.',
      );
    }
  }

  final alerts = <String>[];
  if (canceledTripCount > 0) {
    alerts.add(
      'Hay $canceledTripCount viaje(s) cancelado(s) dentro del corte activo y deben explicarse en junta.',
    );
  }
  if (unassignedTripCount > 0) {
    alerts.add(
      'Hay $unassignedTripCount viaje(s) sin chofer o unidad asignada, lo que deja huecos operativos visibles.',
    );
  }
  if (negativeDieselBalanceCount > 0) {
    alerts.add(
      'Hay $negativeDieselBalanceCount captura(s) de diesel donde lo solicitado supera lo comprado.',
    );
  }
  if (operatorRows.isNotEmpty &&
      currentFuelVisibleLiters > 0.01 &&
      operatorRows.first.fuelVisibleLiters / currentFuelVisibleLiters >= 0.35) {
    alerts.add(
      '${_sanitizePdfText(operatorRows.first.operatorLabel)} concentra ${_formatPercent((operatorRows.first.fuelVisibleLiters / currentFuelVisibleLiters) * 100)} del combustible visible de la semana.',
    );
  }
  if (companyRows.isNotEmpty && companyRows.first.tripCount >= 4) {
    alerts.add(
      '${_sanitizePdfText(companyRows.first.companyLabel)} concentra ${companyRows.first.tripCount} viaje(s) visibles en este corte.',
    );
  }

  final closeoutPrompts = <String>[
    'Todo viaje cancelado debe salir de la junta con causa raiz y accion puntual para evitar repeticion.',
    if (unassignedTripCount > 0)
      'Todo viaje sin chofer o sin unidad debe salir con responsable y hora objetivo de asignacion.',
    if (negativeDieselBalanceCount > 0)
      'Todo desfase entre diesel solicitado y comprado debe aclararse hoy mismo contra la captura operativa.',
    'Si una unidad o un chofer esta concentrando demasiada carga, se define rebalanceo puntual para la siguiente semana.',
    'Si un viaje o una carga de combustible ya cambio en la fuente, se corrige en Logistica y se regenera el reporte; no se maquilla el PDF.',
  ];

  return _LogisticsWeeklyInsights(
    currentTripCount: currentTripCount,
    previousTripCount: previousTripCount,
    completedTripCount: completedTripCount,
    inProgressTripCount: inProgressTripCount,
    pendingTripCount: pendingTripCount,
    canceledTripCount: canceledTripCount,
    unassignedTripCount: unassignedTripCount,
    currentDieselRequestedLiters: currentDieselRequestedLiters,
    currentDieselPurchasedLiters: currentDieselPurchasedLiters,
    currentGasolineLoadedLiters: currentGasolineLoadedLiters,
    currentFuelVisibleLiters: currentFuelVisibleLiters,
    operatorRows: operatorRows,
    unitRows: unitRows,
    companyRows: companyRows,
    issueRows: issueRows,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

List<_LogisticsWeeklyOperatorRow> _summarizeLogisticsOperatorRows({
  required List<_LogisticsWeeklyServiceRow> currentServices,
  required List<_LogisticsWeeklyDieselRow> currentDieselRows,
  required List<_LogisticsWeeklyGasolineRow> currentGasolineRows,
}) {
  final labelsByKey = <String, String>{};
  final tripsByKey = <String, List<_LogisticsWeeklyServiceRow>>{};
  final unitsByKey = <String, Set<String>>{};
  final dieselRequestedByKey = <String, double>{};
  final dieselPurchasedByKey = <String, double>{};
  final gasolineByKey = <String, double>{};

  for (final row in currentServices) {
    final key = _normalizeLogisticsKey(row.operatorLabel);
    labelsByKey[key] = row.operatorLabel;
    tripsByKey.putIfAbsent(key, () => <_LogisticsWeeklyServiceRow>[]).add(row);
    unitsByKey.putIfAbsent(key, () => <String>{}).add(row.vehicleDisplayLabel);
  }
  for (final row in currentDieselRows) {
    final key = _normalizeLogisticsKey(row.operatorLabel);
    labelsByKey.putIfAbsent(key, () => row.operatorLabel);
    dieselRequestedByKey[key] =
        (dieselRequestedByKey[key] ?? 0) + row.litersRequested;
    dieselPurchasedByKey[key] =
        (dieselPurchasedByKey[key] ?? 0) + row.litersPurchased;
    unitsByKey.putIfAbsent(key, () => <String>{}).add(row.vehicleDisplayLabel);
  }
  for (final row in currentGasolineRows) {
    final key = _normalizeLogisticsKey(row.operatorLabel);
    labelsByKey.putIfAbsent(key, () => row.operatorLabel);
    gasolineByKey[key] = (gasolineByKey[key] ?? 0) + row.litersLoaded;
    unitsByKey.putIfAbsent(key, () => <String>{}).add(row.vehicleDisplayLabel);
  }

  final keys = <String>{
    ...labelsByKey.keys,
    ...tripsByKey.keys,
    ...dieselRequestedByKey.keys,
    ...dieselPurchasedByKey.keys,
    ...gasolineByKey.keys,
  };

  final rows =
      keys
          .map((key) {
            final services =
                tripsByKey[key] ?? const <_LogisticsWeeklyServiceRow>[];
            final tripCount = services.length;
            final canceledTripCount = services
                .where((row) => row.isCanceled)
                .length;
            final dieselRequestedLiters = dieselRequestedByKey[key] ?? 0;
            final dieselPurchasedLiters = dieselPurchasedByKey[key] ?? 0;
            final gasolineLoadedLiters = gasolineByKey[key] ?? 0;
            final fuelVisibleLiters =
                dieselRequestedLiters + gasolineLoadedLiters;
            final unitCount = (unitsByKey[key] ?? const <String>{})
                .where((label) => label.trim().isNotEmpty)
                .length;
            final noteParts = <String>[];
            if (tripCount > 0 && fuelVisibleLiters > 0.01) {
              noteParts.add(
                '${_formatQuantity(fuelVisibleLiters / tripCount, decimals: 1)} L/viaje',
              );
            } else if (tripCount == 0 && fuelVisibleLiters > 0.01) {
              noteParts.add('Sin viaje visible ligado');
            } else if (tripCount > 0) {
              noteParts.add('Sin combustible capturado');
            }
            if (canceledTripCount > 0) {
              noteParts.add('$canceledTripCount cancelado(s)');
            }
            if (unitCount > 0) {
              noteParts.add('$unitCount unidad(es)');
            }
            return _LogisticsWeeklyOperatorRow(
              operatorLabel: labelsByKey[key] ?? 'Sin operador',
              tripCount: tripCount,
              canceledTripCount: canceledTripCount,
              dieselRequestedLiters: dieselRequestedLiters,
              dieselPurchasedLiters: dieselPurchasedLiters,
              gasolineLoadedLiters: gasolineLoadedLiters,
              unitCount: unitCount,
              note: noteParts.isEmpty
                  ? 'Sin observaciones visibles'
                  : noteParts.join(' | '),
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final fuelCompare = b.fuelVisibleLiters.compareTo(
            a.fuelVisibleLiters,
          );
          if (fuelCompare != 0) return fuelCompare;
          final tripCompare = b.tripCount.compareTo(a.tripCount);
          if (tripCompare != 0) return tripCompare;
          return a.operatorLabel.toLowerCase().compareTo(
            b.operatorLabel.toLowerCase(),
          );
        });
  return rows;
}

List<_LogisticsWeeklyUnitRow> _summarizeLogisticsUnitRows({
  required List<_LogisticsWeeklyServiceRow> currentServices,
  required List<_LogisticsWeeklyDieselRow> currentDieselRows,
  required List<_LogisticsWeeklyGasolineRow> currentGasolineRows,
}) {
  final labelsByKey = <String, String>{};
  final tripsByKey = <String, List<_LogisticsWeeklyServiceRow>>{};
  final operatorsByKey = <String, Set<String>>{};
  final dieselRequestedByKey = <String, double>{};
  final gasolineByKey = <String, double>{};

  for (final row in currentServices) {
    final key = _normalizeLogisticsKey(row.vehicleDisplayLabel);
    labelsByKey[key] = row.vehicleDisplayLabel;
    tripsByKey.putIfAbsent(key, () => <_LogisticsWeeklyServiceRow>[]).add(row);
    operatorsByKey.putIfAbsent(key, () => <String>{}).add(row.operatorLabel);
  }
  for (final row in currentDieselRows) {
    final key = _normalizeLogisticsKey(row.vehicleDisplayLabel);
    labelsByKey.putIfAbsent(key, () => row.vehicleDisplayLabel);
    dieselRequestedByKey[key] =
        (dieselRequestedByKey[key] ?? 0) + row.litersRequested;
    operatorsByKey.putIfAbsent(key, () => <String>{}).add(row.operatorLabel);
  }
  for (final row in currentGasolineRows) {
    final key = _normalizeLogisticsKey(row.vehicleDisplayLabel);
    labelsByKey.putIfAbsent(key, () => row.vehicleDisplayLabel);
    gasolineByKey[key] = (gasolineByKey[key] ?? 0) + row.litersLoaded;
    operatorsByKey.putIfAbsent(key, () => <String>{}).add(row.operatorLabel);
  }

  final keys = <String>{
    ...labelsByKey.keys,
    ...tripsByKey.keys,
    ...dieselRequestedByKey.keys,
    ...gasolineByKey.keys,
  };

  final rows =
      keys
          .map((key) {
            final services =
                tripsByKey[key] ?? const <_LogisticsWeeklyServiceRow>[];
            final tripCount = services.length;
            final canceledTripCount = services
                .where((row) => row.isCanceled)
                .length;
            final dieselRequestedLiters = dieselRequestedByKey[key] ?? 0;
            final gasolineLoadedLiters = gasolineByKey[key] ?? 0;
            final fuelVisibleLiters =
                dieselRequestedLiters + gasolineLoadedLiters;
            final operatorCount = (operatorsByKey[key] ?? const <String>{})
                .where((label) => label.trim().isNotEmpty)
                .length;
            final noteParts = <String>[];
            if (tripCount > 0 && fuelVisibleLiters > 0.01) {
              noteParts.add(
                '${_formatQuantity(fuelVisibleLiters / tripCount, decimals: 1)} L/viaje',
              );
            } else if (tripCount == 0 && fuelVisibleLiters > 0.01) {
              noteParts.add('Sin viaje visible ligado');
            } else if (tripCount > 0) {
              noteParts.add('Sin combustible capturado');
            }
            if (operatorCount > 0) {
              noteParts.add('$operatorCount chofer(es)');
            }
            if (canceledTripCount > 0) {
              noteParts.add('$canceledTripCount cancelado(s)');
            }
            return _LogisticsWeeklyUnitRow(
              unitLabel: labelsByKey[key] ?? 'Sin unidad',
              tripCount: tripCount,
              canceledTripCount: canceledTripCount,
              dieselRequestedLiters: dieselRequestedLiters,
              gasolineLoadedLiters: gasolineLoadedLiters,
              operatorCount: operatorCount,
              note: noteParts.isEmpty
                  ? 'Sin observaciones visibles'
                  : noteParts.join(' | '),
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final fuelCompare = b.fuelVisibleLiters.compareTo(
            a.fuelVisibleLiters,
          );
          if (fuelCompare != 0) return fuelCompare;
          final tripCompare = b.tripCount.compareTo(a.tripCount);
          if (tripCompare != 0) return tripCompare;
          return a.unitLabel.toLowerCase().compareTo(b.unitLabel.toLowerCase());
        });
  return rows;
}

List<_LogisticsWeeklyCompanyRow> _summarizeLogisticsCompanyRows(
  List<_LogisticsWeeklyServiceRow> rows,
) {
  final buckets = <String, List<_LogisticsWeeklyServiceRow>>{};
  for (final row in rows) {
    buckets.putIfAbsent(row.companyName, () => <_LogisticsWeeklyServiceRow>[]);
    buckets[row.companyName]!.add(row);
  }
  final summaryRows =
      buckets.entries
          .map((entry) {
            final items = entry.value;
            final completedTripCount = items
                .where((row) => row.isCompleted)
                .length;
            final canceledTripCount = items
                .where((row) => row.isCanceled)
                .length;
            final pendingCount = items
                .where((row) => !row.isCompleted && !row.isCanceled)
                .length;
            final operatorCount = items
                .map((row) => row.operatorLabel)
                .where((label) => label.trim().isNotEmpty)
                .toSet()
                .length;
            final unitCount = items
                .map((row) => row.vehicleDisplayLabel)
                .where((label) => label.trim().isNotEmpty)
                .toSet()
                .length;
            final noteParts = <String>[];
            if (pendingCount > 0) noteParts.add('$pendingCount pendiente(s)');
            if (canceledTripCount > 0) {
              noteParts.add('$canceledTripCount cancelado(s)');
            }
            if (operatorCount > 0) noteParts.add('$operatorCount chofer(es)');
            return _LogisticsWeeklyCompanyRow(
              companyLabel: entry.key,
              tripCount: items.length,
              completedTripCount: completedTripCount,
              canceledTripCount: canceledTripCount,
              operatorCount: operatorCount,
              unitCount: unitCount,
              note: noteParts.isEmpty
                  ? 'Sin observaciones visibles'
                  : noteParts.join(' | '),
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final tripCompare = b.tripCount.compareTo(a.tripCount);
          if (tripCompare != 0) return tripCompare;
          final canceledCompare = b.canceledTripCount.compareTo(
            a.canceledTripCount,
          );
          if (canceledCompare != 0) return canceledCompare;
          return a.companyLabel.toLowerCase().compareTo(
            b.companyLabel.toLowerCase(),
          );
        });
  return summaryRows;
}

List<_LogisticsWeeklyIssueRow> _collectLogisticsIssueRows({
  required List<_LogisticsWeeklyServiceRow> currentServices,
  required List<_LogisticsWeeklyDieselRow> currentDieselRows,
  required List<_LogisticsWeeklyGasolineRow> currentGasolineRows,
}) {
  final issueRows = <_LogisticsWeeklyIssueRow>[];

  for (final row in currentServices) {
    final noteParts = <String>[];
    var severity = 0;
    if (row.isCanceled) {
      noteParts.add('Cancelado dentro del corte');
      severity = 5;
    }
    if (!row.hasAssignedDriver) {
      noteParts.add('Sin chofer');
      if (severity < 4) severity = 4;
    }
    if (!row.hasAssignedVehicle) {
      noteParts.add('Sin unidad');
      if (severity < 4) severity = 4;
    }
    if (noteParts.isEmpty) continue;
    if (row.notes.isNotEmpty) {
      noteParts.add(_truncate(row.notes, 32));
    }
    issueRows.add(
      _LogisticsWeeklyIssueRow(
        sourceLabel: 'Viaje',
        date: row.effectiveDate,
        referenceLabel: row.companyName,
        statusLabel: row.statusLabel,
        assignmentLabel: row.assignmentLabel,
        note: noteParts.join(' | '),
        severity: severity,
      ),
    );
  }

  for (final row in currentDieselRows) {
    final noteParts = <String>[];
    var severity = 0;
    if (row.hasNegativeBalance) {
      noteParts.add(
        'Solicito ${_formatQuantity(row.litersRequested)} L y compro ${_formatQuantity(row.litersPurchased)} L',
      );
      severity = 4;
    }
    if (!row.hasOperator) {
      noteParts.add('Sin operador');
      if (severity < 3) severity = 3;
    }
    if (!row.hasVehicle) {
      noteParts.add('Sin unidad');
      if (severity < 3) severity = 3;
    }
    if (noteParts.isEmpty) continue;
    issueRows.add(
      _LogisticsWeeklyIssueRow(
        sourceLabel: 'Diesel',
        date: row.date,
        referenceLabel: row.vehicleDisplayLabel,
        statusLabel: row.hasNegativeBalance
            ? 'Desfase diesel'
            : 'Captura incompleta',
        assignmentLabel: row.operatorLabel,
        note: noteParts.join(' | '),
        severity: severity,
      ),
    );
  }

  for (final row in currentGasolineRows) {
    final noteParts = <String>[];
    var severity = 0;
    if (!row.hasOperator) {
      noteParts.add('Sin operador');
      if (severity < 3) severity = 3;
    }
    if (!row.hasVehicle) {
      noteParts.add('Sin unidad');
      if (severity < 3) severity = 3;
    }
    if (noteParts.isEmpty) continue;
    if (row.notes.isNotEmpty) noteParts.add(_truncate(row.notes, 32));
    issueRows.add(
      _LogisticsWeeklyIssueRow(
        sourceLabel: 'Gasolina',
        date: row.date,
        referenceLabel: row.vehicleDisplayLabel,
        statusLabel: 'Captura incompleta',
        assignmentLabel: row.operatorLabel,
        note: noteParts.join(' | '),
        severity: severity,
      ),
    );
  }

  issueRows.sort((a, b) {
    final severityCompare = b.severity.compareTo(a.severity);
    if (severityCompare != 0) return severityCompare;
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    return a.referenceLabel.toLowerCase().compareTo(
      b.referenceLabel.toLowerCase(),
    );
  });
  return issueRows;
}

String _normalizeLogisticsKey(String value) {
  return _cleanString(value).toLowerCase();
}

String _formatLogisticsStatusLabel(String statusRaw) {
  final cleaned = statusRaw.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return 'Sin estado';
  return cleaned
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class _LogisticsWeeklyCut {
  final DateTime weekStart;
  final DateTime friday;
  final DateTime cutoffAt;

  const _LogisticsWeeklyCut({
    required this.weekStart,
    required this.friday,
    required this.cutoffAt,
  });

  DateTime get progressEnd => _pdfDateOnly(cutoffAt);

  DateTime get previousWeekStart => weekStart.subtract(const Duration(days: 7));

  DateTime get previousProgressEnd => previousWeekStart.add(
    Duration(days: progressEnd.difference(weekStart).inDays),
  );
}

class _LogisticsWeeklySourceBundle {
  final List<_LogisticsWeeklyDieselRow> currentDieselRows;
  final List<_LogisticsWeeklyDieselRow> previousDieselRows;
  final List<_LogisticsWeeklyGasolineRow> currentGasolineRows;
  final List<_LogisticsWeeklyGasolineRow> previousGasolineRows;
  final List<_LogisticsWeeklyServiceRow> currentServiceRows;
  final List<_LogisticsWeeklyServiceRow> previousServiceRows;

  const _LogisticsWeeklySourceBundle({
    required this.currentDieselRows,
    required this.previousDieselRows,
    required this.currentGasolineRows,
    required this.previousGasolineRows,
    required this.currentServiceRows,
    required this.previousServiceRows,
  });
}

class _LogisticsWeeklyDieselRow {
  final String id;
  final DateTime date;
  final String operatorName;
  final String vehicleLabel;
  final double litersPurchased;
  final double litersRequested;
  final double balanceLiters;
  final DateTime? createdAt;

  const _LogisticsWeeklyDieselRow({
    required this.id,
    required this.date,
    required this.operatorName,
    required this.vehicleLabel,
    required this.litersPurchased,
    required this.litersRequested,
    required this.balanceLiters,
    required this.createdAt,
  });

  factory _LogisticsWeeklyDieselRow.fromJson(Map<String, dynamic> json) {
    final purchased = _toNullableDouble(json['liters_purchased']) ?? 0;
    final requested = _toNullableDouble(json['liters_requested']) ?? 0;
    return _LogisticsWeeklyDieselRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      date:
          DateTime.tryParse((json['entry_date'] ?? '').toString()) ??
          DateTime.now(),
      operatorName: _cleanString(json['operator_name']),
      vehicleLabel: _cleanString(json['vehicle_label']),
      litersPurchased: purchased,
      litersRequested: requested,
      balanceLiters:
          (_toNullableDouble(json['balance_liters']) ?? (purchased - requested))
              .toDouble(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  bool get hasOperator => operatorName.isNotEmpty;

  bool get hasVehicle => vehicleLabel.isNotEmpty;

  bool get hasNegativeBalance => balanceLiters < -0.01;

  String get operatorLabel => hasOperator ? operatorName : 'Sin operador';

  String get vehicleDisplayLabel => hasVehicle ? vehicleLabel : 'Sin unidad';
}

class _LogisticsWeeklyGasolineRow {
  final String id;
  final DateTime date;
  final String operatorName;
  final String vehicleLabel;
  final double litersLoaded;
  final String notes;
  final DateTime? createdAt;

  const _LogisticsWeeklyGasolineRow({
    required this.id,
    required this.date,
    required this.operatorName,
    required this.vehicleLabel,
    required this.litersLoaded,
    required this.notes,
    required this.createdAt,
  });

  factory _LogisticsWeeklyGasolineRow.fromJson(Map<String, dynamic> json) {
    return _LogisticsWeeklyGasolineRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      date:
          DateTime.tryParse((json['entry_date'] ?? '').toString()) ??
          DateTime.now(),
      operatorName: _cleanString(json['operator_name']),
      vehicleLabel: _cleanString(json['vehicle_label']),
      litersLoaded: _toNullableDouble(json['liters_loaded']) ?? 0,
      notes: _cleanString(json['notes']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  bool get hasOperator => operatorName.isNotEmpty;

  bool get hasVehicle => vehicleLabel.isNotEmpty;

  String get operatorLabel => hasOperator ? operatorName : 'Sin operador';

  String get vehicleDisplayLabel => hasVehicle ? vehicleLabel : 'Sin unidad';
}

class _LogisticsWeeklyServiceRow {
  final String id;
  final DateTime? serviceDate;
  final DateTime? dueDate;
  final String status;
  final String planningKind;
  final String direction;
  final String driverEmployeeId;
  final String driverName;
  final String vehicleId;
  final String vehicleLabel;
  final String notes;
  final String companyName;
  final DateTime? createdAt;

  const _LogisticsWeeklyServiceRow({
    required this.id,
    required this.serviceDate,
    required this.dueDate,
    required this.status,
    required this.planningKind,
    required this.direction,
    required this.driverEmployeeId,
    required this.driverName,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.notes,
    required this.companyName,
    required this.createdAt,
  });

  factory _LogisticsWeeklyServiceRow.fromJson(
    Map<String, dynamic> json, {
    required Map<String, String> driverNamesById,
    required Map<String, String> vehicleLabelsById,
  }) {
    final driverEmployeeId = _cleanString(json['driver_employee_id']);
    final vehicleId = _cleanString(json['vehicle_id']);
    return _LogisticsWeeklyServiceRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      serviceDate: DateTime.tryParse((json['service_date'] ?? '').toString()),
      dueDate: DateTime.tryParse((json['due_date'] ?? '').toString()),
      status: _normalizeTag(json['status']),
      planningKind: _normalizeTag(json['planning_kind']),
      direction: _cleanString(json['direction']),
      driverEmployeeId: driverEmployeeId,
      driverName: _cleanString(driverNamesById[driverEmployeeId]),
      vehicleId: vehicleId,
      vehicleLabel: _cleanString(vehicleLabelsById[vehicleId]),
      notes: _cleanString(json['notes']),
      companyName: _stringOrFallback(json['client_name'], 'Sin empresa'),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  DateTime get effectiveDate =>
      dueDate ?? serviceDate ?? createdAt ?? DateTime.now();

  bool get isCanceled => status == 'cancelado';

  bool get isCompleted => status == 'completado';

  bool get isInProgress {
    return status == 'en_ruta' ||
        status == 'en ruta' ||
        status == 'enruta' ||
        status == 'en_sitio' ||
        status == 'en sitio' ||
        status == 'ensitio';
  }

  bool get hasAssignedDriver =>
      driverEmployeeId.isNotEmpty || driverName.isNotEmpty;

  bool get hasAssignedVehicle =>
      vehicleId.isNotEmpty || vehicleLabel.isNotEmpty;

  String get operatorLabel {
    if (driverName.isNotEmpty) return driverName;
    if (driverEmployeeId.isNotEmpty) return 'Chofer asignado';
    return 'Sin chofer';
  }

  String get vehicleDisplayLabel {
    if (vehicleLabel.isNotEmpty) return vehicleLabel;
    if (vehicleId.isNotEmpty) return 'Unidad asignada';
    return 'Sin unidad';
  }

  String get statusLabel => _formatLogisticsStatusLabel(status);

  String get assignmentLabel => '$operatorLabel / $vehicleDisplayLabel';
}

class _LogisticsWeeklyOperatorRow {
  final String operatorLabel;
  final int tripCount;
  final int canceledTripCount;
  final double dieselRequestedLiters;
  final double dieselPurchasedLiters;
  final double gasolineLoadedLiters;
  final int unitCount;
  final String note;

  const _LogisticsWeeklyOperatorRow({
    required this.operatorLabel,
    required this.tripCount,
    required this.canceledTripCount,
    required this.dieselRequestedLiters,
    required this.dieselPurchasedLiters,
    required this.gasolineLoadedLiters,
    required this.unitCount,
    required this.note,
  });

  double get fuelVisibleLiters => dieselRequestedLiters + gasolineLoadedLiters;
}

class _LogisticsWeeklyUnitRow {
  final String unitLabel;
  final int tripCount;
  final int canceledTripCount;
  final double dieselRequestedLiters;
  final double gasolineLoadedLiters;
  final int operatorCount;
  final String note;

  const _LogisticsWeeklyUnitRow({
    required this.unitLabel,
    required this.tripCount,
    required this.canceledTripCount,
    required this.dieselRequestedLiters,
    required this.gasolineLoadedLiters,
    required this.operatorCount,
    required this.note,
  });

  double get fuelVisibleLiters => dieselRequestedLiters + gasolineLoadedLiters;
}

class _LogisticsWeeklyCompanyRow {
  final String companyLabel;
  final int tripCount;
  final int completedTripCount;
  final int canceledTripCount;
  final int operatorCount;
  final int unitCount;
  final String note;

  const _LogisticsWeeklyCompanyRow({
    required this.companyLabel,
    required this.tripCount,
    required this.completedTripCount,
    required this.canceledTripCount,
    required this.operatorCount,
    required this.unitCount,
    required this.note,
  });
}

class _LogisticsWeeklyIssueRow {
  final String sourceLabel;
  final DateTime date;
  final String referenceLabel;
  final String statusLabel;
  final String assignmentLabel;
  final String note;
  final int severity;

  const _LogisticsWeeklyIssueRow({
    required this.sourceLabel,
    required this.date,
    required this.referenceLabel,
    required this.statusLabel,
    required this.assignmentLabel,
    required this.note,
    required this.severity,
  });
}

class _LogisticsWeeklyInsights {
  final int currentTripCount;
  final int previousTripCount;
  final int completedTripCount;
  final int inProgressTripCount;
  final int pendingTripCount;
  final int canceledTripCount;
  final int unassignedTripCount;
  final double currentDieselRequestedLiters;
  final double currentDieselPurchasedLiters;
  final double currentGasolineLoadedLiters;
  final double currentFuelVisibleLiters;
  final List<_LogisticsWeeklyOperatorRow> operatorRows;
  final List<_LogisticsWeeklyUnitRow> unitRows;
  final List<_LogisticsWeeklyCompanyRow> companyRows;
  final List<_LogisticsWeeklyIssueRow> issueRows;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _LogisticsWeeklyInsights({
    required this.currentTripCount,
    required this.previousTripCount,
    required this.completedTripCount,
    required this.inProgressTripCount,
    required this.pendingTripCount,
    required this.canceledTripCount,
    required this.unassignedTripCount,
    required this.currentDieselRequestedLiters,
    required this.currentDieselPurchasedLiters,
    required this.currentGasolineLoadedLiters,
    required this.currentFuelVisibleLiters,
    required this.operatorRows,
    required this.unitRows,
    required this.companyRows,
    required this.issueRows,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
  });
}

class _MenudeoWeeklyCut {
  final DateTime weekStart;
  final DateTime friday;
  final DateTime cutoffAt;

  const _MenudeoWeeklyCut({
    required this.weekStart,
    required this.friday,
    required this.cutoffAt,
  });

  DateTime get progressEnd => _pdfDateOnly(cutoffAt);

  DateTime get previousWeekStart => weekStart.subtract(const Duration(days: 7));

  DateTime get previousProgressEnd => previousWeekStart.add(
    Duration(days: progressEnd.difference(weekStart).inDays),
  );
}

class _MenudeoWeeklySourceBundle {
  final List<_MenudeoWeeklyTicketRow> currentTicketRows;
  final List<_MenudeoWeeklyTicketRow> previousTicketRows;
  final List<_MenudeoWeeklyVoucherRow> currentVoucherRows;
  final List<_MenudeoWeeklyCashCutRow> currentCashCutRows;
  final List<_MenudeoWeeklyPriceAdjustmentRow> currentAdjustmentRows;

  const _MenudeoWeeklySourceBundle({
    required this.currentTicketRows,
    required this.previousTicketRows,
    required this.currentVoucherRows,
    required this.currentCashCutRows,
    required this.currentAdjustmentRows,
  });
}

class _MenudeoWeeklyTicketRow {
  final String id;
  final DateTime date;
  final String ticketNumber;
  final String counterpartyName;
  final String priceId;
  final String materialName;
  final double priceAtEntry;
  final double payableWeight;
  final double amountTotal;
  final String status;
  final String comment;
  final String direction;
  final String exitOrderNumber;
  final DateTime? createdAt;

  const _MenudeoWeeklyTicketRow({
    required this.id,
    required this.date,
    required this.ticketNumber,
    required this.counterpartyName,
    required this.priceId,
    required this.materialName,
    required this.priceAtEntry,
    required this.payableWeight,
    required this.amountTotal,
    required this.status,
    required this.comment,
    required this.direction,
    required this.exitOrderNumber,
    required this.createdAt,
  });

  factory _MenudeoWeeklyTicketRow.fromJson(Map<String, dynamic> json) {
    return _MenudeoWeeklyTicketRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      date:
          DateTime.tryParse((json['ticket_date'] ?? '').toString()) ??
          DateTime.now(),
      ticketNumber: _stringOrFallback(json['ticket_number'], 'Sin ticket'),
      counterpartyName: _cleanString(json['counterparty_name_snapshot']),
      priceId: _cleanString(json['price_id']),
      materialName: _cleanString(json['material_label_snapshot']),
      priceAtEntry: _toNullableDouble(json['price_at_entry']) ?? 0,
      payableWeight: _toNullableDouble(json['payable_weight']) ?? 0,
      amountTotal: _toNullableDouble(json['amount_total']) ?? 0,
      status: _cleanString(json['status']).toUpperCase(),
      comment: _cleanString(json['comment']),
      direction: _normalizeTag(json['direction']),
      exitOrderNumber: _cleanString(json['exit_order_number']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  bool get hasCounterparty => counterpartyName.isNotEmpty;

  bool get hasMaterial => materialName.isNotEmpty;

  bool get hasPriceLink => priceId.isNotEmpty;

  bool get hasExitOrder => exitOrderNumber.isNotEmpty;

  bool get isSale => direction == 'sale';

  bool get isPurchase => direction == 'purchase';

  bool get isPaid => status == 'PAGADO';

  bool get isPending => !isPaid;

  String get directionLabel => _menudeoDirectionLabel(direction);

  String get counterpartyLabel =>
      hasCounterparty ? counterpartyName : 'Sin contraparte';

  String get materialLabel => hasMaterial ? materialName : 'Sin material';

  String get statusLabel => status.isEmpty ? 'Sin estatus' : status;
}

class _MenudeoWeeklyVoucherRow {
  final String id;
  final DateTime date;
  final String folio;
  final String voucherType;
  final String personName;
  final String rubric;
  final String comment;
  final double totalAmount;
  final int lineCount;
  final String conceptsPreview;
  final DateTime? createdAt;

  const _MenudeoWeeklyVoucherRow({
    required this.id,
    required this.date,
    required this.folio,
    required this.voucherType,
    required this.personName,
    required this.rubric,
    required this.comment,
    required this.totalAmount,
    required this.lineCount,
    required this.conceptsPreview,
    required this.createdAt,
  });

  factory _MenudeoWeeklyVoucherRow.fromJson(Map<String, dynamic> json) {
    return _MenudeoWeeklyVoucherRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      date:
          DateTime.tryParse((json['voucher_date'] ?? '').toString()) ??
          DateTime.now(),
      folio: _stringOrFallback(json['folio'], 'Sin folio'),
      voucherType: _normalizeTag(json['voucher_type']),
      personName: _cleanString(json['person_label']),
      rubric: _cleanString(json['rubric']),
      comment: _cleanString(json['comment']),
      totalAmount: _toNullableDouble(json['total_amount']) ?? 0,
      lineCount: (json['line_count'] as num?)?.toInt() ?? 0,
      conceptsPreview: _cleanString(json['concepts_preview']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  bool get isDeposit => voucherType == 'deposit';

  bool get isExpense => voucherType == 'expense';

  bool get hasPerson => personName.isNotEmpty;

  bool get hasRubric => rubric.isNotEmpty;

  String get typeLabel => _menudeoVoucherTypeLabel(voucherType);

  String get personLabel => hasPerson ? personName : 'Sin responsable';

  String get rubricLabel => hasRubric ? rubric : 'Sin rubro';
}

class _MenudeoWeeklyCashCutRow {
  final String id;
  final DateTime date;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double salesTotal;
  final double purchasesTotal;
  final double depositsTotal;
  final double expensesTotal;
  final double theoreticalCashTotal;
  final double countedCashTotal;
  final double differenceTotal;
  final int pendingChecksCount;
  final String status;
  final String notes;

  const _MenudeoWeeklyCashCutRow({
    required this.id,
    required this.date,
    required this.openedAt,
    required this.closedAt,
    required this.openingCash,
    required this.salesTotal,
    required this.purchasesTotal,
    required this.depositsTotal,
    required this.expensesTotal,
    required this.theoreticalCashTotal,
    required this.countedCashTotal,
    required this.differenceTotal,
    required this.pendingChecksCount,
    required this.status,
    required this.notes,
  });

  factory _MenudeoWeeklyCashCutRow.fromJson(Map<String, dynamic> json) {
    return _MenudeoWeeklyCashCutRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      date:
          DateTime.tryParse(
            (json['cut_date'] ?? json['opened_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      openedAt: DateTime.tryParse((json['opened_at'] ?? '').toString()),
      closedAt: DateTime.tryParse((json['closed_at'] ?? '').toString()),
      openingCash: _toNullableDouble(json['opening_cash']) ?? 0,
      salesTotal: _toNullableDouble(json['sales_total']) ?? 0,
      purchasesTotal: _toNullableDouble(json['purchases_total']) ?? 0,
      depositsTotal: _toNullableDouble(json['deposits_total']) ?? 0,
      expensesTotal: _toNullableDouble(json['expenses_total']) ?? 0,
      theoreticalCashTotal:
          _toNullableDouble(json['theoretical_cash_total']) ?? 0,
      countedCashTotal: _toNullableDouble(json['counted_cash_total']) ?? 0,
      differenceTotal: _toNullableDouble(json['difference_total']) ?? 0,
      pendingChecksCount:
          int.tryParse((json['pending_checks_count'] ?? '').toString()) ?? 0,
      status: _cleanString(json['status']).toUpperCase(),
      notes: _cleanString(json['notes']),
    );
  }

  bool get isClosed => status == 'CERRADO' || closedAt != null;

  String get statusLabel => status.isEmpty ? 'Sin estatus' : status;
}

class _MenudeoWeeklyPriceAdjustmentRow {
  final String id;
  final String priceId;
  final String counterpartyName;
  final String materialName;
  final double previousPrice;
  final double newPrice;
  final String reason;
  final DateTime createdAt;
  final String direction;
  final String eventKind;
  final String adjustmentMode;
  final double adjustmentValue;
  final String appliedBy;

  const _MenudeoWeeklyPriceAdjustmentRow({
    required this.id,
    required this.priceId,
    required this.counterpartyName,
    required this.materialName,
    required this.previousPrice,
    required this.newPrice,
    required this.reason,
    required this.createdAt,
    required this.direction,
    required this.eventKind,
    required this.adjustmentMode,
    required this.adjustmentValue,
    required this.appliedBy,
  });

  factory _MenudeoWeeklyPriceAdjustmentRow.fromJson(Map<String, dynamic> json) {
    return _MenudeoWeeklyPriceAdjustmentRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      priceId: _cleanString(json['price_id']),
      counterpartyName: _cleanString(json['counterparty_name']),
      materialName: _cleanString(json['material_label_snapshot']),
      previousPrice: _toNullableDouble(json['previous_price']) ?? 0,
      newPrice: _toNullableDouble(json['new_price']) ?? 0,
      reason: _cleanString(json['reason']),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      direction: _normalizeTag(json['direction']),
      eventKind: _cleanString(json['event_kind']),
      adjustmentMode: _cleanString(json['adjustment_mode']),
      adjustmentValue: _toNullableDouble(json['adjustment_value']) ?? 0,
      appliedBy: _cleanString(json['applied_by']),
    );
  }

  double get delta => newPrice - previousPrice;

  bool get hasReason => reason.isNotEmpty;

  String get directionLabel => _menudeoDirectionLabel(direction);

  String get counterpartyLabel =>
      counterpartyName.isEmpty ? 'Sin contraparte' : counterpartyName;

  String get materialLabel =>
      materialName.isEmpty ? 'Sin material' : materialName;

  String get reasonLabel => hasReason ? reason : 'Sin motivo';
}

class _MenudeoWeeklyDirectionRow {
  final String direction;
  final int currentTicketCount;
  final int previousTicketCount;
  final double currentPayableKg;
  final double previousPayableKg;
  final double currentAmount;
  final double previousAmount;

  const _MenudeoWeeklyDirectionRow({
    required this.direction,
    required this.currentTicketCount,
    required this.previousTicketCount,
    required this.currentPayableKg,
    required this.previousPayableKg,
    required this.currentAmount,
    required this.previousAmount,
  });

  String get directionLabel => _menudeoDirectionLabel(direction);

  int get deltaTicketCount => currentTicketCount - previousTicketCount;

  double get currentAveragePrice =>
      currentPayableKg <= 0 ? 0 : currentAmount / currentPayableKg;

  double get deltaAmount => currentAmount - previousAmount;
}

class _MenudeoWeeklyCounterpartyRow {
  final String direction;
  final String counterpartyLabel;
  final int ticketCount;
  final int pendingCount;
  final double payableKg;
  final double amount;
  final String note;

  const _MenudeoWeeklyCounterpartyRow({
    required this.direction,
    required this.counterpartyLabel,
    required this.ticketCount,
    required this.pendingCount,
    required this.payableKg,
    required this.amount,
    required this.note,
  });

  String get directionLabel => _menudeoDirectionLabel(direction);

  double get averagePrice => payableKg <= 0 ? 0 : amount / payableKg;
}

class _MenudeoWeeklyVoucherRubricRow {
  final String voucherType;
  final String rubricLabel;
  final int voucherCount;
  final double totalAmount;
  final int personCount;
  final String note;

  const _MenudeoWeeklyVoucherRubricRow({
    required this.voucherType,
    required this.rubricLabel,
    required this.voucherCount,
    required this.totalAmount,
    required this.personCount,
    required this.note,
  });

  String get typeLabel => _menudeoVoucherTypeLabel(voucherType);
}

class _MenudeoWeeklyIssueRow {
  final String sourceLabel;
  final DateTime date;
  final String referenceLabel;
  final String statusLabel;
  final String note;
  final int severity;

  const _MenudeoWeeklyIssueRow({
    required this.sourceLabel,
    required this.date,
    required this.referenceLabel,
    required this.statusLabel,
    required this.note,
    required this.severity,
  });
}

class _MenudeoWeeklyInsights {
  final _MenudeoWeeklyDirectionRow purchaseRow;
  final _MenudeoWeeklyDirectionRow saleRow;
  final List<_MenudeoWeeklyDirectionRow> directionRows;
  final double currentDepositsAmount;
  final double currentExpensesAmount;
  final int currentAdjustmentCount;
  final int adjustmentsWithoutReasonCount;
  final int closedCashCutCount;
  final int openCashCutCount;
  final double totalCashDifference;
  final double visibleCommercialSpread;
  final List<_MenudeoWeeklyCounterpartyRow> counterpartyRows;
  final List<_MenudeoWeeklyVoucherRubricRow> voucherRubricRows;
  final List<_MenudeoWeeklyPriceAdjustmentRow> adjustmentRows;
  final List<_MenudeoWeeklyCashCutRow> cashCutRows;
  final List<_MenudeoWeeklyIssueRow> issueRows;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _MenudeoWeeklyInsights({
    required this.purchaseRow,
    required this.saleRow,
    required this.directionRows,
    required this.currentDepositsAmount,
    required this.currentExpensesAmount,
    required this.currentAdjustmentCount,
    required this.adjustmentsWithoutReasonCount,
    required this.closedCashCutCount,
    required this.openCashCutCount,
    required this.totalCashDifference,
    required this.visibleCommercialSpread,
    required this.counterpartyRows,
    required this.voucherRubricRows,
    required this.adjustmentRows,
    required this.cashCutRows,
    required this.issueRows,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
  });
}

Future<Uint8List> buildBasculaWeeklySupervisionPdfBytes({
  required ManagementAreaDefinition area,
  required DateTime generatedAt,
  required String generatedBy,
}) async {
  final cut = _resolveBasculaWeeklyCut(generatedAt);
  final source = await _loadBasculaWeeklySourceBundle(cut);
  final insights = _buildBasculaWeeklyInsights(source, cut);
  final logoImage = await _tryLoadManagementReportLogo();
  final accentBase = area.accent;
  final accent = _pdfColorFromFlutter(_managementAccentInk(accentBase));
  final accentSoft = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.9));
  final accentBorder = _pdfColorFromFlutter(_blendWithWhite(accentBase, 0.74));
  final visibleIncomingRows = insights.incomingMaterialRows
      .take(18)
      .toList(growable: false);
  final visibleOutgoingRows = insights.outgoingMaterialRows
      .take(18)
      .toList(growable: false);
  final visibleMixRows = insights.counterpartyMixRows
      .take(8)
      .toList(growable: false);
  final visibleComparisonRows = insights.comparisonRows
      .take(16)
      .toList(growable: false);
  final visibleIssueRows = insights.issueRows.take(36).toList(growable: false);
  final hiddenIncomingCount =
      insights.incomingMaterialRows.length - visibleIncomingRows.length;
  final hiddenOutgoingCount =
      insights.outgoingMaterialRows.length - visibleOutgoingRows.length;
  final hiddenMixCount =
      insights.counterpartyMixRows.length - visibleMixRows.length;
  final hiddenComparisonCount =
      insights.comparisonRows.length - visibleComparisonRows.length;
  final hiddenIssueCount = insights.issueRows.length - visibleIssueRows.length;

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageTheme: _managementReportPdfPageTheme(PdfPageFormat.a4.landscape),
      maxPages: 70,
      build: (context) {
        return <pw.Widget>[
          _pdfHeader(
            logoImage: logoImage,
            eyebrow: 'REPORTE DE SEGUIMIENTO',
            title: 'Bascula · corte semanal de entradas y salidas',
            subtitle:
                'Area Bascula · lectura semanal para revisar material entrante, material saliente, mezcla por contraparte y errores visibles de ticket o captura.',
            badges: <MapEntry<String, String>>[
              MapEntry(
                'Corte',
                '${_formatShortDate(cut.weekStart)} - ${_formatShortDate(cut.friday)}',
              ),
              MapEntry('Area', area.title),
              MapEntry('Responsable', area.ownerLabel),
              MapEntry('Generado', _formatDateTimeShort(generatedAt)),
            ],
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
                  'Reporte real incluido hoy: pesadas + inventory_movements_v2 para entradas a inventario general y salidas de inventario comercial.',
                ),
                _pdfBullet(
                  'El corte semanal activo va del ${_formatLongDateSpanish(cut.weekStart)} al ${_formatLongDateSpanish(cut.friday)} y esta acumulado unicamente hasta ${_formatDateTimeShort(cut.cutoffAt)}.',
                ),
                _pdfBullet(
                  'La comparacion contra semana pasada usa el mismo avance operativo: ${_formatLongDateSpanish(cut.previousWeekStart)} al ${_formatLongDateSpanish(cut.previousProgressEnd)}.',
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
            title: 'KPIs semanales de bascula',
            accent: accent,
            child: _pdfKpiGrid(
              accent: accent,
              accentSoft: accentSoft,
              items: <_PdfKpiItem>[
                _PdfKpiItem(
                  'Tickets pesados',
                  '${insights.currentWeighingCount}',
                  note:
                      'Avance previo ${_formatSignedCount(insights.currentWeighingCount - insights.previousWeighingCount)}',
                ),
                _PdfKpiItem(
                  'Entradas general',
                  '${_formatQuantity(insights.totalIncomingKg)} KG',
                  note: '${insights.currentIncomingMovementCount} movimientos',
                ),
                _PdfKpiItem(
                  'Salidas comercial',
                  '${_formatQuantity(insights.totalOutgoingKg)} KG',
                  note: '${insights.currentOutgoingMovementCount} movimientos',
                ),
                _PdfKpiItem(
                  'Materiales entrada',
                  '${insights.incomingMaterialRows.length}',
                ),
                _PdfKpiItem(
                  'Materiales salida',
                  '${insights.outgoingMaterialRows.length}',
                ),
                _PdfKpiItem(
                  'Hallazgos visibles',
                  '${insights.issueRows.length}',
                  note: '${insights.unmatchedWeighingCount} pesadas sin ligar',
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
            title: 'Que material entro',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenIncomingCount > 0
                  ? 'Se muestran los ${visibleIncomingRows.length} materiales de entrada con mayor volumen de ${insights.incomingMaterialRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Material',
                  'Movs',
                  'Tickets',
                  'KG netos',
                  'Participacion',
                  'Ultimo mov.',
                ],
                rows: visibleIncomingRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(row.materialLabel),
                        '${row.movementCount}',
                        '${row.ticketCount}',
                        '${_formatQuantity(row.totalKg)} KG',
                        _formatPercent(row.share * 100),
                        _formatOptionalDate(row.latestDate),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay entradas visibles de inventario general en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Que material salio',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenOutgoingCount > 0
                  ? 'Se muestran los ${visibleOutgoingRows.length} materiales de salida con mayor volumen de ${insights.outgoingMaterialRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Material',
                  'Movs',
                  'Tickets',
                  'KG netos',
                  'Participacion',
                  'Ultimo mov.',
                ],
                rows: visibleOutgoingRows
                    .map(
                      (row) => <String>[
                        _sanitizePdfText(row.materialLabel),
                        '${row.movementCount}',
                        '${row.ticketCount}',
                        '${_formatQuantity(row.totalKg)} KG',
                        _formatPercent(row.share * 100),
                        _formatOptionalDate(row.latestDate),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay salidas visibles de inventario comercial en este corte.',
                headerColor: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Entradas de publico vs proveedor',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: insights.unknownCounterpartyCount > 0
                  ? '${insights.unknownCounterpartyCount} entrada(s) siguen sin proveedor capturado y se reflejan como Sin clasificar.'
                  : hiddenMixCount > 0
                  ? 'Se muestran ${visibleMixRows.length} segmentos visibles de ${insights.counterpartyMixRows.length}.'
                  : null,
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Segmento',
                  'Movs',
                  'Contrapartes',
                  'KG netos',
                  'Participacion',
                  'Lectura',
                ],
                rows: visibleMixRows
                    .map(
                      (row) => <String>[
                        row.segmentLabel,
                        '${row.movementCount}',
                        '${row.counterpartyCount}',
                        '${_formatQuantity(row.totalKg)} KG',
                        _formatPercent(row.share * 100),
                        _sanitizePdfText(_truncate(row.note, 42)),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'No hay entradas visibles suficientes para clasificar publico vs proveedor.',
                headerColor: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            title: 'Comparacion contra semana pasada',
            accent: accent,
            child: _pdfTableWithOptionalNote(
              note: hiddenComparisonCount > 0
                  ? 'Se muestran ${visibleComparisonRows.length} materiales con mayor variacion de ${insights.comparisonRows.length}.'
                  : 'Comparacion contra el mismo avance operativo de la semana previa.',
              child: _pdfSimpleTable(
                headers: const <String>[
                  'Frente',
                  'Material',
                  'KG actual',
                  'KG previo',
                  'Delta',
                  'Lectura',
                ],
                rows: visibleComparisonRows
                    .map(
                      (row) => <String>[
                        row.flowLabel,
                        _sanitizePdfText(row.materialLabel),
                        '${_formatQuantity(row.currentKg)} KG',
                        '${_formatQuantity(row.previousKg)} KG',
                        '${row.deltaKg >= 0 ? '+' : '-'}${_formatQuantity(row.deltaKg.abs())} KG',
                        _sanitizePdfText(_truncate(row.note, 46)),
                      ],
                    )
                    .toList(growable: false),
                emptyLabel:
                    'Todavia no hay base comparable suficiente contra la semana previa.',
                headerColor: accent,
              ),
            ),
          ),
          ..._pdfChunkedTableSections(
            title: 'Tickets y movimientos a revisar',
            accent: accent,
            headers: const <String>[
              'Fuente',
              'Fecha',
              'Ticket',
              'Material',
              'Contraparte',
              'Lectura',
            ],
            rows: visibleIssueRows
                .map(
                  (row) => <String>[
                    row.sourceLabel,
                    _formatOptionalDate(row.date),
                    _sanitizePdfText(row.ticketLabel),
                    _sanitizePdfText(_truncate(row.materialLabel, 24)),
                    _sanitizePdfText(_truncate(row.counterpartyLabel, 24)),
                    _sanitizePdfText(_truncate(row.note, 58)),
                  ],
                )
                .toList(growable: false),
            emptyLabel:
                'No hay tickets ni movimientos con observaciones visibles en este corte.',
            headerColor: accent,
            compact: true,
            maxRowsPerSection: 14,
            startOnNewPage: true,
            introNote: hiddenIssueCount > 0
                ? 'Se muestran ${visibleIssueRows.length} hallazgos de ${insights.issueRows.length}; el resto queda resumido en alertas y KPIs.'
                : null,
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

_BasculaWeeklyCut _resolveBasculaWeeklyCut(DateTime generatedAt) {
  final friday = _nextOrSameFriday(generatedAt);
  final weekStart = friday.subtract(const Duration(days: 4));
  final fridayEnd = DateTime(
    friday.year,
    friday.month,
    friday.day,
    23,
    59,
    59,
    999,
  );
  final cutoffAt = generatedAt.isBefore(fridayEnd) ? generatedAt : fridayEnd;
  return _BasculaWeeklyCut(
    weekStart: weekStart,
    friday: friday,
    cutoffAt: cutoffAt,
  );
}

Future<_BasculaWeeklySourceBundle> _loadBasculaWeeklySourceBundle(
  _BasculaWeeklyCut cut,
) async {
  final currentStart = _formatDbDate(cut.weekStart);
  final currentEnd = _formatDbDate(cut.progressEnd);
  final previousStart = _formatDbDate(cut.previousWeekStart);
  final previousEnd = _formatDbDate(cut.previousProgressEnd);

  final results = await Future.wait<dynamic>([
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('pesadas')
          .select('id,fecha,ticket,proveedor,precio,created_at')
          .gte('fecha', currentStart)
          .lte('fecha', currentEnd)
          .order('fecha', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('pesadas')
          .select('id,fecha,ticket,proveedor,precio,created_at')
          .gte('fecha', previousStart)
          .lte('fecha', previousEnd)
          .order('fecha', ascending: true)
          .order('created_at', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('inventory_movements_v2')
          .select(
            'id,op_date,flow,inventory_level,reference,scale_ticket,'
            'counterparty,counterparty_site_id,weight_kg,net_kg,total_amount_kg,'
            'unit_count,origin_type,movement_reason,notes,'
            'general_material:general_material_id(code,name),'
            'commercial_material:commercial_material_id(code,name),'
            'source_commercial:source_commercial_material_id(code,name)',
          )
          .eq('flow', 'IN')
          .eq('inventory_level', 'GENERAL')
          .gte('op_date', currentStart)
          .lte('op_date', currentEnd)
          .order('op_date', ascending: true)
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('inventory_movements_v2')
          .select(
            'id,op_date,flow,inventory_level,reference,scale_ticket,'
            'counterparty,counterparty_site_id,weight_kg,net_kg,total_amount_kg,'
            'unit_count,origin_type,movement_reason,notes,'
            'general_material:general_material_id(code,name),'
            'commercial_material:commercial_material_id(code,name),'
            'source_commercial:source_commercial_material_id(code,name)',
          )
          .eq('flow', 'IN')
          .eq('inventory_level', 'GENERAL')
          .gte('op_date', previousStart)
          .lte('op_date', previousEnd)
          .order('op_date', ascending: true)
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('inventory_movements_v2')
          .select(
            'id,op_date,flow,inventory_level,reference,scale_ticket,'
            'counterparty,counterparty_site_id,weight_kg,net_kg,total_amount_kg,'
            'unit_count,origin_type,movement_reason,notes,'
            'general_material:general_material_id(code,name),'
            'commercial_material:commercial_material_id(code,name),'
            'source_commercial:source_commercial_material_id(code,name)',
          )
          .eq('flow', 'OUT')
          .eq('inventory_level', 'COMMERCIAL')
          .gte('op_date', currentStart)
          .lte('op_date', currentEnd)
          .order('op_date', ascending: true)
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('inventory_movements_v2')
          .select(
            'id,op_date,flow,inventory_level,reference,scale_ticket,'
            'counterparty,counterparty_site_id,weight_kg,net_kg,total_amount_kg,'
            'unit_count,origin_type,movement_reason,notes,'
            'general_material:general_material_id(code,name),'
            'commercial_material:commercial_material_id(code,name),'
            'source_commercial:source_commercial_material_id(code,name)',
          )
          .eq('flow', 'OUT')
          .eq('inventory_level', 'COMMERCIAL')
          .gte('op_date', previousStart)
          .lte('op_date', previousEnd)
          .order('op_date', ascending: true)
          .order('id', ascending: true)
          .range(from, to),
    ),
  ]);

  final currentWeighings = (results[0] as List<Map<String, dynamic>>)
      .map(_BasculaWeighingRow.fromJson)
      .toList(growable: false);
  final previousWeighings = (results[1] as List<Map<String, dynamic>>)
      .map(_BasculaWeighingRow.fromJson)
      .toList(growable: false);
  final currentIncomingRows = (results[2] as List<Map<String, dynamic>>)
      .map(_BasculaMovementRow.fromJson)
      .toList(growable: false);
  final previousIncomingRows = (results[3] as List<Map<String, dynamic>>)
      .map(_BasculaMovementRow.fromJson)
      .toList(growable: false);
  final currentOutgoingRows = (results[4] as List<Map<String, dynamic>>)
      .map(_BasculaMovementRow.fromJson)
      .toList(growable: false);
  final previousOutgoingRows = (results[5] as List<Map<String, dynamic>>)
      .map(_BasculaMovementRow.fromJson)
      .toList(growable: false);
  return _BasculaWeeklySourceBundle(
    currentWeighings: currentWeighings,
    previousWeighings: previousWeighings,
    currentIncomingRows: currentIncomingRows,
    previousIncomingRows: previousIncomingRows,
    currentOutgoingRows: currentOutgoingRows,
    previousOutgoingRows: previousOutgoingRows,
  );
}

_BasculaWeeklyInsights _buildBasculaWeeklyInsights(
  _BasculaWeeklySourceBundle source,
  _BasculaWeeklyCut cut,
) {
  final currentWeighings = source.currentWeighings;
  final previousWeighings = source.previousWeighings;
  final currentIncomingRows = source.currentIncomingRows;
  final previousIncomingRows = source.previousIncomingRows;
  final currentOutgoingRows = source.currentOutgoingRows;
  final previousOutgoingRows = source.previousOutgoingRows;

  final totalIncomingKg = currentIncomingRows.fold<double>(
    0,
    (sum, row) => sum + row.netKg,
  );
  final previousIncomingKg = previousIncomingRows.fold<double>(
    0,
    (sum, row) => sum + row.netKg,
  );
  final totalOutgoingKg = currentOutgoingRows.fold<double>(
    0,
    (sum, row) => sum + row.netKg,
  );
  final previousOutgoingKg = previousOutgoingRows.fold<double>(
    0,
    (sum, row) => sum + row.netKg,
  );

  final incomingMaterialRows = _summarizeBasculaMaterials(
    currentIncomingRows,
    flowLabel: 'Entrada',
  );
  final outgoingMaterialRows = _summarizeBasculaMaterials(
    currentOutgoingRows,
    flowLabel: 'Salida',
  );
  final counterpartyMixRows = _summarizeBasculaCounterpartyMix(
    currentIncomingRows,
  );
  final comparisonRows = _summarizeBasculaComparison(
    currentIncomingRows: currentIncomingRows,
    previousIncomingRows: previousIncomingRows,
    currentOutgoingRows: currentOutgoingRows,
    previousOutgoingRows: previousOutgoingRows,
  );
  final issues = _collectBasculaIssues(
    currentWeighings: currentWeighings,
    currentIncomingRows: currentIncomingRows,
    currentOutgoingRows: currentOutgoingRows,
  );

  final unmatchedWeighingCount = issues
      .where((row) => row.issueKey == 'pesada_sin_entrada')
      .length;
  final missingTicketCount = issues
      .where((row) => row.issueKey == 'movimiento_sin_ticket')
      .length;
  final duplicateWeighingCount = issues
      .where((row) => row.issueKey == 'ticket_duplicado_pesadas')
      .length;
  final unknownCounterpartyCount = issues
      .where((row) => row.issueKey == 'entrada_sin_proveedor')
      .length;

  final executiveSummary = <String>[
    'Al corte del ${_formatDateTimeShort(cut.cutoffAt)}, Bascula registra ${currentWeighings.length} pesadas, ${_formatQuantity(totalIncomingKg)} KG de entrada general y ${_formatQuantity(totalOutgoingKg)} KG de salida comercial.',
  ];
  if (incomingMaterialRows.isNotEmpty) {
    final topIncoming = incomingMaterialRows.first;
    executiveSummary.add(
      'El material de entrada con mayor volumen es ${_sanitizePdfText(topIncoming.materialLabel)} con ${_formatQuantity(topIncoming.totalKg)} KG en ${topIncoming.movementCount} movimiento(s).',
    );
  }
  if (outgoingMaterialRows.isNotEmpty) {
    final topOutgoing = outgoingMaterialRows.first;
    executiveSummary.add(
      'El material de salida con mayor volumen es ${_sanitizePdfText(topOutgoing.materialLabel)} con ${_formatQuantity(topOutgoing.totalKg)} KG en ${topOutgoing.movementCount} movimiento(s).',
    );
  }
  executiveSummary.add(
    'Contra el mismo avance de la semana pasada, la entrada ${_describeBasculaDelta(totalIncomingKg - previousIncomingKg)} y la salida ${_describeBasculaDelta(totalOutgoingKg - previousOutgoingKg)}.',
  );
  if (counterpartyMixRows.isNotEmpty) {
    final leadMix = counterpartyMixRows.first;
    executiveSummary.add(
      'La mezcla visible de entrada se concentra en ${leadMix.segmentLabel} con ${_formatPercent(leadMix.share * 100)} del kg capturado.',
    );
  }
  if (issues.isNotEmpty) {
    executiveSummary.add(
      'Siguen visibles ${issues.length} hallazgo(s) operativos; $unmatchedWeighingCount pesada(s) no estan ligadas a una entrada y $missingTicketCount movimiento(s) siguen sin ticket o folio.',
    );
  }

  final alerts = <String>[
    if (unmatchedWeighingCount > 0)
      'Hay $unmatchedWeighingCount pesada(s) sin entrada ligada en inventario general dentro del mismo corte.',
    if (missingTicketCount > 0)
      'Hay $missingTicketCount movimiento(s) sin ticket o folio visible dentro de entradas o salidas.',
    if (unknownCounterpartyCount > 0)
      'Hay $unknownCounterpartyCount entrada(s) sin proveedor capturado para distinguir PUBLICO vs proveedor.',
    if (duplicateWeighingCount > 0)
      'Hay $duplicateWeighingCount ticket(s) repetidos en pesadas y conviene revisar si hay doble captura.',
    if (currentIncomingRows.isEmpty)
      'No hay entradas visibles de inventario general en el avance actual de la semana.',
    if (currentOutgoingRows.isEmpty)
      'No hay salidas visibles de inventario comercial en el avance actual de la semana.',
  ];

  final closeoutPrompts = <String>[
    'Explicar por que materiales se cargo la semana en entradas y salidas, y si ese mix era el esperado.',
    if (unmatchedWeighingCount > 0)
      'Resolver hoy las pesadas sin entrada ligada para no dejar ticket vivo fuera del inventario.',
    if (missingTicketCount > 0)
      'Completar ticket o folio en los movimientos que siguen sueltos para no perder trazabilidad.',
    if (unknownCounterpartyCount > 0)
      'Capturar el proveedor faltante en esas entradas para que el corte separe bien PUBLICO vs proveedor.',
    'Si un dato no hace sentido, se corrige en pesadas o inventario y luego se regenera el viernes; no se maquilla en el PDF.',
  ];

  return _BasculaWeeklyInsights(
    currentWeighingCount: currentWeighings.length,
    previousWeighingCount: previousWeighings.length,
    currentIncomingMovementCount: currentIncomingRows.length,
    currentOutgoingMovementCount: currentOutgoingRows.length,
    totalIncomingKg: totalIncomingKg,
    previousIncomingKg: previousIncomingKg,
    totalOutgoingKg: totalOutgoingKg,
    previousOutgoingKg: previousOutgoingKg,
    unmatchedWeighingCount: unmatchedWeighingCount,
    missingTicketCount: missingTicketCount,
    duplicateWeighingCount: duplicateWeighingCount,
    unknownCounterpartyCount: unknownCounterpartyCount,
    incomingMaterialRows: incomingMaterialRows,
    outgoingMaterialRows: outgoingMaterialRows,
    counterpartyMixRows: counterpartyMixRows,
    comparisonRows: comparisonRows,
    issueRows: issues,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

List<_BasculaMaterialSummaryRow> _summarizeBasculaMaterials(
  List<_BasculaMovementRow> rows, {
  required String flowLabel,
}) {
  final totalKg = rows.fold<double>(0, (sum, row) => sum + row.netKg);
  final grouped = <String, List<_BasculaMovementRow>>{};
  for (final row in rows) {
    grouped
        .putIfAbsent(row.materialLabel, () => <_BasculaMovementRow>[])
        .add(row);
  }
  final summary =
      grouped.entries
          .map((entry) {
            final ticketKeys = <String>{};
            DateTime? latestDate;
            var kg = 0.0;
            for (final row in entry.value) {
              kg += row.netKg;
              ticketKeys.addAll(
                row.ticketKeys.isEmpty
                    ? <String>{'row:${row.id}'}
                    : row.ticketKeys,
              );
              if (latestDate == null || row.opDate.isAfter(latestDate)) {
                latestDate = row.opDate;
              }
            }
            return _BasculaMaterialSummaryRow(
              flowLabel: flowLabel,
              materialLabel: entry.key,
              movementCount: entry.value.length,
              ticketCount: ticketKeys.length,
              totalKg: kg,
              share: totalKg <= 0.009 ? 0 : kg / totalKg,
              latestDate: latestDate,
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final kgCompare = b.totalKg.compareTo(a.totalKg);
          if (kgCompare != 0) return kgCompare;
          return a.materialLabel.toLowerCase().compareTo(
            b.materialLabel.toLowerCase(),
          );
        });
  return summary;
}

List<_BasculaCounterpartyMixRow> _summarizeBasculaCounterpartyMix(
  List<_BasculaMovementRow> rows,
) {
  final totalKg = rows.fold<double>(0, (sum, row) => sum + row.netKg);
  final grouped = <String, List<_BasculaMovementRow>>{};
  for (final row in rows) {
    final segment = _classifyBasculaCounterparty(row.counterpartyLabel);
    grouped.putIfAbsent(segment, () => <_BasculaMovementRow>[]).add(row);
  }
  final summary =
      grouped.entries
          .map((entry) {
            final counterparties = entry.value
                .map((row) => row.counterpartyLabel.trim())
                .where(
                  (label) => label.isNotEmpty && label != 'Sin contraparte',
                )
                .toSet();
            final kg = entry.value.fold<double>(
              0,
              (sum, row) => sum + row.netKg,
            );
            return _BasculaCounterpartyMixRow(
              segmentLabel: entry.key,
              movementCount: entry.value.length,
              counterpartyCount: counterparties.length,
              totalKg: kg,
              share: totalKg <= 0.009 ? 0 : kg / totalKg,
              note: _buildBasculaCounterpartyMixNote(
                segment: entry.key,
                share: totalKg <= 0.009 ? 0 : kg / totalKg,
              ),
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final kgCompare = b.totalKg.compareTo(a.totalKg);
          if (kgCompare != 0) return kgCompare;
          return a.segmentLabel.toLowerCase().compareTo(
            b.segmentLabel.toLowerCase(),
          );
        });
  return summary;
}

List<_BasculaComparisonRow> _summarizeBasculaComparison({
  required List<_BasculaMovementRow> currentIncomingRows,
  required List<_BasculaMovementRow> previousIncomingRows,
  required List<_BasculaMovementRow> currentOutgoingRows,
  required List<_BasculaMovementRow> previousOutgoingRows,
}) {
  final rows = <_BasculaComparisonRow>[
    ..._buildBasculaComparisonRows(
      currentRows: currentIncomingRows,
      previousRows: previousIncomingRows,
      flowLabel: 'Entrada',
    ),
    ..._buildBasculaComparisonRows(
      currentRows: currentOutgoingRows,
      previousRows: previousOutgoingRows,
      flowLabel: 'Salida',
    ),
  ];
  rows.sort((a, b) {
    final flowCompare = a.flowLabel.compareTo(b.flowLabel);
    if (flowCompare != 0) return flowCompare;
    final deltaCompare = b.deltaKg.abs().compareTo(a.deltaKg.abs());
    if (deltaCompare != 0) return deltaCompare;
    final currentCompare = b.currentKg.compareTo(a.currentKg);
    if (currentCompare != 0) return currentCompare;
    return a.materialLabel.toLowerCase().compareTo(
      b.materialLabel.toLowerCase(),
    );
  });
  return rows;
}

List<_BasculaComparisonRow> _buildBasculaComparisonRows({
  required List<_BasculaMovementRow> currentRows,
  required List<_BasculaMovementRow> previousRows,
  required String flowLabel,
}) {
  final currentByMaterial = _sumBasculaKgByMaterial(currentRows);
  final previousByMaterial = _sumBasculaKgByMaterial(previousRows);
  final labels = <String>{
    ...currentByMaterial.keys,
    ...previousByMaterial.keys,
  }.toList(growable: false);
  final rows = labels
      .map(
        (label) => _BasculaComparisonRow(
          flowLabel: flowLabel,
          materialLabel: label,
          currentKg: currentByMaterial[label] ?? 0,
          previousKg: previousByMaterial[label] ?? 0,
          note: _buildBasculaComparisonNote(
            currentKg: currentByMaterial[label] ?? 0,
            previousKg: previousByMaterial[label] ?? 0,
          ),
        ),
      )
      .where((row) => row.currentKg > 0.009 || row.previousKg > 0.009)
      .toList(growable: false);
  rows.sort((a, b) {
    final deltaCompare = b.deltaKg.abs().compareTo(a.deltaKg.abs());
    if (deltaCompare != 0) return deltaCompare;
    final currentCompare = b.currentKg.compareTo(a.currentKg);
    if (currentCompare != 0) return currentCompare;
    return a.materialLabel.toLowerCase().compareTo(
      b.materialLabel.toLowerCase(),
    );
  });
  return rows;
}

Map<String, double> _sumBasculaKgByMaterial(List<_BasculaMovementRow> rows) {
  final map = <String, double>{};
  for (final row in rows) {
    map.update(
      row.materialLabel,
      (value) => value + row.netKg,
      ifAbsent: () => row.netKg,
    );
  }
  return map;
}

List<_BasculaIssueRow> _collectBasculaIssues({
  required List<_BasculaWeighingRow> currentWeighings,
  required List<_BasculaMovementRow> currentIncomingRows,
  required List<_BasculaMovementRow> currentOutgoingRows,
}) {
  final issues = <_BasculaIssueRow>[];
  final incomingTicketKeys = <String>{};
  for (final row in currentIncomingRows) {
    incomingTicketKeys.addAll(row.ticketKeys);
  }

  final weighingsByTicket = <String, List<_BasculaWeighingRow>>{};
  for (final row in currentWeighings) {
    final key = _normalizeBasculaTicketKey(row.ticket);
    if (key.isEmpty) continue;
    weighingsByTicket.putIfAbsent(key, () => <_BasculaWeighingRow>[]).add(row);
  }
  for (final entry in weighingsByTicket.entries) {
    if (entry.value.length <= 1) continue;
    final first = entry.value.first;
    issues.add(
      _BasculaIssueRow(
        issueKey: 'ticket_duplicado_pesadas',
        sourceLabel: 'Pesadas',
        date: first.date,
        ticketLabel: first.ticket,
        materialLabel: 'Sin material',
        counterpartyLabel: first.provider,
        note:
            'El ticket aparece ${entry.value.length} veces en pesadas y conviene revisar si existe doble captura.',
        severity: 4,
      ),
    );
  }
  for (final row in currentWeighings) {
    final key = _normalizeBasculaTicketKey(row.ticket);
    if (key.isEmpty || incomingTicketKeys.contains(key)) continue;
    issues.add(
      _BasculaIssueRow(
        issueKey: 'pesada_sin_entrada',
        sourceLabel: 'Pesadas',
        date: row.date,
        ticketLabel: row.ticket,
        materialLabel: 'Sin material',
        counterpartyLabel: row.provider,
        note:
            'La pesada no tiene una entrada ligada visible en inventario general dentro del mismo corte.',
        severity: 5,
      ),
    );
  }

  for (final row in <_BasculaMovementRow>[
    ...currentIncomingRows,
    ...currentOutgoingRows,
  ]) {
    if (row.ticketKeys.isEmpty) {
      issues.add(
        _BasculaIssueRow(
          issueKey: 'movimiento_sin_ticket',
          sourceLabel: row.isIncoming ? 'Entrada' : 'Salida',
          date: row.opDate,
          ticketLabel: 'Sin ticket',
          materialLabel: row.materialLabel,
          counterpartyLabel: row.counterpartyLabel,
          note:
              'El movimiento no trae ticket ni folio visible; se pierde trazabilidad de bascula.',
          severity: 4,
        ),
      );
    }
    if (row.counterpartyLabel == 'Sin contraparte') {
      issues.add(
        _BasculaIssueRow(
          issueKey: 'movimiento_sin_contraparte',
          sourceLabel: row.isIncoming ? 'Entrada' : 'Salida',
          date: row.opDate,
          ticketLabel: row.ticketLabel,
          materialLabel: row.materialLabel,
          counterpartyLabel: row.counterpartyLabel,
          note:
              'El movimiento sigue sin contraparte capturada y requiere correccion en inventario.',
          severity: 3,
        ),
      );
      continue;
    }
    if (row.isIncoming) {
      final segment = _classifyBasculaCounterparty(row.counterpartyLabel);
      if (segment == 'Sin clasificar') {
        issues.add(
          _BasculaIssueRow(
            issueKey: 'entrada_sin_proveedor',
            sourceLabel: 'Entrada',
            date: row.opDate,
            ticketLabel: row.ticketLabel,
            materialLabel: row.materialLabel,
            counterpartyLabel: row.counterpartyLabel,
            note:
                'La entrada sigue sin proveedor capturado; no se puede decidir si es PUBLICO o proveedor.',
            severity: 2,
          ),
        );
      }
    }
  }

  issues.sort((a, b) {
    final severityCompare = b.severity.compareTo(a.severity);
    if (severityCompare != 0) return severityCompare;
    final dateCompare = a.date.compareTo(b.date);
    if (dateCompare != 0) return dateCompare;
    return a.ticketLabel.toLowerCase().compareTo(b.ticketLabel.toLowerCase());
  });
  return issues;
}

String _classifyBasculaCounterparty(String counterpartyLabel) {
  final normalizedName = _sanitizePdfText(
    counterpartyLabel,
  ).trim().toUpperCase();
  if (normalizedName.isEmpty || normalizedName == 'SIN CONTRAPARTE') {
    return 'Sin clasificar';
  }
  if (normalizedName == 'PUBLICO') {
    return 'Publico';
  }
  return 'Proveedor';
}

String _buildBasculaCounterpartyMixNote({
  required String segment,
  required double share,
}) {
  if (segment == 'Sin clasificar') {
    return 'Falta proveedor en entrada';
  }
  if (share >= 0.6) {
    return 'Concentracion fuerte en este segmento';
  }
  if (share >= 0.35) {
    return 'Peso relevante dentro del mix';
  }
  return 'Participacion secundaria';
}

String _buildBasculaComparisonNote({
  required double currentKg,
  required double previousKg,
}) {
  final delta = currentKg - previousKg;
  if (currentKg > 0.009 && previousKg <= 0.009) {
    return 'Aparece en este avance';
  }
  if (currentKg <= 0.009 && previousKg > 0.009) {
    return 'Se cae contra avance previo';
  }
  if (delta.abs() <= 0.009) {
    return 'Sin cambio visible';
  }
  if (delta > 0) {
    return 'Sube ${_formatQuantity(delta)} KG';
  }
  return 'Baja ${_formatQuantity(delta.abs())} KG';
}

String _describeBasculaDelta(double deltaKg) {
  if (deltaKg.abs() <= 0.009) return 'se mantiene sin cambio visible';
  if (deltaKg > 0) return 'sube ${_formatQuantity(deltaKg)} KG';
  return 'baja ${_formatQuantity(deltaKg.abs())} KG';
}

String _normalizeBasculaTicketKey(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String _formatDbDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Future<List<_SalesDailyReportRow>> _loadSalesDailyReportRows() async {
  final results = await Future.wait<dynamic>([
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('mayoreo_sales_reports')
          .select(_kSalesDailyReportFields)
          .order('sale_date', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('mayoreo_accounts')
          .select(_kSalesCollectionAccountFields)
          .order('sale_date', ascending: false)
          .order('updated_at', ascending: false)
          .order('id', ascending: true)
          .range(from, to),
    ),
    FinanzasBankAccountsStore.loadMovements(),
  ]);
  final sourceRows = (results[0] as List<Map<String, dynamic>>)
      .map((row) => _SalesDailyReportRow.fromJson(row))
      .toList(growable: false);
  final rawAccountRows = (results[1] as List<Map<String, dynamic>>)
      .map((item) => _SalesCollectionAccountRow.fromJson(item))
      .toList(growable: false);
  final bankMovements = results[2] as List<FinanzasBankMovementRecord>;
  final accountsById = <String, _SalesCollectionAccountRow>{
    for (final row in _reconcileSalesCollectionAccountRows(
      rawAccountRows,
      bankMovements,
    ))
      row.id: row,
  };
  final rows = sourceRows
      .map((row) {
        final account = accountsById[row.id];
        if (account == null) return row;
        return row.copyWithAccountState(
          documentNumber: account.documentNumber,
          documentDate: account.documentDate,
          estimatedPaymentDate: account.estimatedPaymentDate,
          settlementDate: account.settlementDate,
          statusKey: account.statusKey,
          financialNotes: account.financialNotes,
          paidAmount: account.paidAmount,
        );
      })
      .toList(growable: false);
  rows.sort((a, b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    return a.ticket.toLowerCase().compareTo(b.ticket.toLowerCase());
  });
  return rows;
}

_SalesWeeklyCut _resolveSalesWeeklyCut(DateTime generatedAt) {
  final friday = _nextOrSameFriday(generatedAt);
  final weekStart = friday.subtract(const Duration(days: 4));
  final fridayEnd = DateTime(
    friday.year,
    friday.month,
    friday.day,
    23,
    59,
    59,
    999,
  );
  final cutoffAt = generatedAt.isBefore(fridayEnd) ? generatedAt : fridayEnd;
  return _SalesWeeklyCut(
    weekStart: weekStart,
    friday: friday,
    cutoffAt: cutoffAt,
  );
}

Future<List<_SalesCollectionAccountRow>> _loadSalesCollectionAccountRows(
  _SalesWeeklyCut cut,
) async {
  final results = await Future.wait<dynamic>([
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('mayoreo_accounts')
          .select(_kSalesCollectionAccountFields)
          .order('sale_date', ascending: false)
          .order('updated_at', ascending: false)
          .order('id', ascending: true)
          .range(from, to),
    ),
    FinanzasBankAccountsStore.loadMovements(),
  ]);
  final rawRows = (results[0] as List<Map<String, dynamic>>)
      .map((row) => _SalesCollectionAccountRow.fromJson(row))
      .toList(growable: false);
  final bankMovements = results[1] as List<FinanzasBankMovementRecord>;
  final rows = _reconcileSalesCollectionAccountRows(
    rawRows,
    bankMovements,
    weekCut: cut,
  );
  rows.sort((a, b) {
    final pendingCompare = b.pendingBalance.compareTo(a.pendingBalance);
    if (pendingCompare != 0) return pendingCompare;
    return a.saleDate.compareTo(b.saleDate);
  });
  return rows;
}

List<_SalesCollectionAccountRow> _reconcileSalesCollectionAccountRows(
  List<_SalesCollectionAccountRow> rawRows,
  List<FinanzasBankMovementRecord> bankMovements, {
  _SalesWeeklyCut? weekCut,
}) {
  final creditsByAccountId = <String, double>{};
  final weekCreditsByAccountId = <String, double>{};
  final latestCreditDateByAccountId = <String, DateTime>{};
  for (final movement in bankMovements) {
    if (movement.sourceType != 'VENTA_FACTURA') continue;
    final accountId = (movement.linkedExternalRef ?? '').trim();
    if (accountId.isEmpty) continue;
    final appliedAmount = movement.creditAmount.clamp(0, double.infinity);
    if (appliedAmount <= 0.009) continue;
    creditsByAccountId.update(
      accountId,
      (value) => value + appliedAmount,
      ifAbsent: () => appliedAmount.toDouble(),
    );
    final movementDate = _pdfDateOnly(movement.date);
    if (weekCut != null &&
        !movementDate.isBefore(weekCut.weekStart) &&
        !movementDate.isAfter(_pdfDateOnly(weekCut.cutoffAt))) {
      weekCreditsByAccountId.update(
        accountId,
        (value) => value + appliedAmount,
        ifAbsent: () => appliedAmount.toDouble(),
      );
    }
    final previousDate = latestCreditDateByAccountId[accountId];
    if (previousDate == null || movement.date.isAfter(previousDate)) {
      latestCreditDateByAccountId[accountId] = movement.date;
    }
  }

  return rawRows
      .map((row) {
        final bankPaidAmount = creditsByAccountId[row.id];
        final effectivePaidAmount =
            row.operationType == 'factura' && bankPaidAmount != null
            ? bankPaidAmount.clamp(0, row.approvedAmount).toDouble()
            : row.paidAmount;
        final effectiveSettlementDate =
            row.operationType == 'factura' && effectivePaidAmount > 0.009
            ? latestCreditDateByAccountId[row.id] ?? row.settlementDate
            : row.settlementDate;
        final effectiveStatus = _deriveSalesReportStatusKey(
          baseStatus: row.statusKey,
          operationType: row.operationType,
          documentNumber: row.documentNumber,
          documentDate: row.documentDate,
          settlementDate: effectiveSettlementDate,
          paidAmount: effectivePaidAmount,
          approvedAmount: row.approvedAmount,
        );
        return row.copyWith(
          paidAmount: effectivePaidAmount,
          settlementDate: effectiveSettlementDate,
          statusKey: effectiveStatus,
          latestPaymentAt:
              latestCreditDateByAccountId[row.id] ?? row.latestPaymentAt,
          weekCollectedAmount: weekCut == null
              ? row.weekCollectedAmount
              : weekCreditsByAccountId[row.id] ?? 0,
        );
      })
      .toList(growable: false);
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

_OperationsWeeklyCut _resolveOperationsWeeklyCut(DateTime generatedAt) {
  final friday = _nextOrSameFriday(generatedAt);
  final weekStart = friday.subtract(const Duration(days: 4));
  final fridayEnd = DateTime(
    friday.year,
    friday.month,
    friday.day,
    23,
    59,
    59,
    999,
  );
  final cutoffAt = generatedAt.isBefore(fridayEnd) ? generatedAt : fridayEnd;
  return _OperationsWeeklyCut(
    weekStart: weekStart,
    friday: friday,
    cutoffAt: cutoffAt,
  );
}

Future<List<_OperationsWeeklyOtRow>> _loadOperationsWeeklyOtRows() async {
  final raw = await fetchAllSupabaseRows(
    (from, to) => Supabase.instance.client
        .from('maintenance_orders')
        .select(_kOperationsWeeklyOtFields)
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .range(from, to),
  );
  final rows = raw
      .map(
        (row) =>
            _OperationsWeeklyOtRow.fromJson(Map<String, dynamic>.from(row)),
      )
      .toList(growable: false);
  rows.sort((a, b) {
    final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return left.compareTo(right);
  });
  return rows;
}

_OperationsWeeklyInsights _buildOperationsWeeklyInsights(
  List<_OperationsWeeklyOtRow> rows,
  _OperationsWeeklyCut cut,
) {
  final openRows = rows.where((row) => row.isOpen).toList(growable: false)
    ..sort((a, b) {
      final riskCompare = b.riskScore(cut).compareTo(a.riskScore(cut));
      if (riskCompare != 0) return riskCompare;
      final left = a.updatedAt ?? a.requestedAt ?? cut.cutoffAt;
      final right = b.updatedAt ?? b.requestedAt ?? cut.cutoffAt;
      return right.compareTo(left);
    });
  final delayedOpenRows = openRows
      .where((row) => row.isDelayed(cut))
      .toList(growable: false);
  final criticalOpenRows = openRows
      .where((row) => row.isCriticalOpen)
      .toList(growable: false);
  final waitingActionRows = openRows
      .where((row) => row.isWaitingAction)
      .toList(growable: false);

  final closedWeekRows = rows
      .where((row) => row.isClosed && _isWithinWeeklyCut(row.updatedAt, cut))
      .toList(growable: false);
  final rejectedWeekRows = rows
      .where((row) => row.isRejected && _isWithinWeeklyCut(row.updatedAt, cut))
      .toList(growable: false);
  final resolvedWeekRows =
      <_OperationsWeeklyOtRow>[...closedWeekRows, ...rejectedWeekRows]
        ..sort((a, b) {
          final left = a.updatedAt ?? a.requestedAt ?? cut.cutoffAt;
          final right = b.updatedAt ?? b.requestedAt ?? cut.cutoffAt;
          return right.compareTo(left);
        });

  final groupedByArea = <String, List<_OperationsWeeklyOtRow>>{};
  for (final row in openRows) {
    groupedByArea.putIfAbsent(row.areaLabel, () => <_OperationsWeeklyOtRow>[]);
    groupedByArea[row.areaLabel]!.add(row);
  }
  final areaRows =
      groupedByArea.entries
          .map(
            (entry) => _OperationsWeeklyAreaRow(
              areaLabel: entry.key,
              openCount: entry.value.length,
              criticalCount: entry.value
                  .where((row) => row.isCriticalOpen)
                  .length,
              delayedCount: entry.value
                  .where((row) => row.isDelayed(cut))
                  .length,
              waitingCount: entry.value
                  .where((row) => row.isWaitingAction)
                  .length,
              closedWeekCount: closedWeekRows
                  .where((row) => row.areaLabel == entry.key)
                  .length,
            ),
          )
          .toList()
        ..sort((a, b) {
          final byOpen = b.openCount.compareTo(a.openCount);
          if (byOpen != 0) return byOpen;
          return a.areaLabel.compareTo(b.areaLabel);
        });

  final groupedByEquipment = <String, List<_OperationsWeeklyOtRow>>{};
  for (final row in openRows) {
    final key = '${row.areaLabel}|||${row.equipmentLabel}';
    groupedByEquipment.putIfAbsent(key, () => <_OperationsWeeklyOtRow>[]);
    groupedByEquipment[key]!.add(row);
  }
  final equipmentRows =
      groupedByEquipment.entries.map((entry) {
        final first = entry.value.first;
        return _OperationsWeeklyEquipmentRow(
          equipmentLabel: first.equipmentLabel,
          areaLabel: first.areaLabel,
          openCount: entry.value.length,
          criticalCount: entry.value.where((row) => row.isCriticalOpen).length,
          delayedCount: entry.value.where((row) => row.isDelayed(cut)).length,
          waitingCount: entry.value.where((row) => row.isWaitingAction).length,
        );
      }).toList()..sort((a, b) {
        final byOpen = b.openCount.compareTo(a.openCount);
        if (byOpen != 0) return byOpen;
        return a.equipmentLabel.compareTo(b.equipmentLabel);
      });

  final focusRows = openRows
      .where(
        (row) =>
            row.isCriticalOpen ||
            row.isDelayed(cut) ||
            row.isWaitingAction ||
            row.missingResponsible,
      )
      .take(10)
      .toList(growable: false);

  final executiveSummary = <String>[];
  if (openRows.isEmpty && resolvedWeekRows.isEmpty) {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)} no hay OTs abiertas ni movimientos de cierre visibles en la semana operativa activa.',
    );
  } else {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)}, Operaciones mantiene ${openRows.length} OTs abiertas.',
    );
    if (delayedOpenRows.isNotEmpty) {
      executiveSummary.add(
        '${delayedOpenRows.length} OTs abiertas ya venian arrastradas desde antes del ${_formatLongDateSpanish(cut.weekStart)} o superan 72 horas sin cierre.',
      );
    } else {
      executiveSummary.add(
        'No hay OTs abiertas atrasadas respecto al inicio de la semana operativa del ${_formatLongDateSpanish(cut.weekStart)}.',
      );
    }
    executiveSummary.add(
      'En la semana operativa actual se cerraron ${closedWeekRows.length} OTs y se rechazaron ${rejectedWeekRows.length}.',
    );
    if (areaRows.isNotEmpty) {
      executiveSummary.add(
        'El area con mayor seguimiento abierto es ${areaRows.first.areaLabel} con ${areaRows.first.openCount} OTs.',
      );
    }
    if (equipmentRows.isNotEmpty) {
      executiveSummary.add(
        'El equipo o unidad con mayor presion abierta es ${equipmentRows.first.equipmentLabel} dentro de ${equipmentRows.first.areaLabel}.',
      );
    }
    if (waitingActionRows.isNotEmpty) {
      executiveSummary.add(
        'Hay ${waitingActionRows.length} OTs abiertas esperando cotizacion o autorizacion para poder avanzar.',
      );
    }
  }

  final alerts = <String>[];
  if (criticalOpenRows.isNotEmpty) {
    alerts.add(
      'Hay ${criticalOpenRows.length} OTs abiertas criticas por prioridad alta o impacto de paro.',
    );
  }
  if (delayedOpenRows.isNotEmpty) {
    alerts.add(
      'Hay ${delayedOpenRows.length} OTs abiertas atrasadas que ya cargan arrastre previo a la semana operativa actual.',
    );
  }
  if (waitingActionRows.isNotEmpty) {
    alerts.add(
      'Hay ${waitingActionRows.length} OTs abiertas atoradas en cotizacion o autorizacion financiera.',
    );
  }
  if (areaRows.isNotEmpty && areaRows.first.openCount >= 3) {
    alerts.add(
      '${areaRows.first.areaLabel} concentra ${areaRows.first.openCount} OTs abiertas en este corte.',
    );
  }
  if (equipmentRows.isNotEmpty && equipmentRows.first.openCount >= 2) {
    alerts.add(
      '${equipmentRows.first.equipmentLabel} acumula ${equipmentRows.first.openCount} OTs abiertas y requiere lectura puntual del equipo.',
    );
  }
  if (rejectedWeekRows.isNotEmpty) {
    alerts.add(
      'Se rechazaron ${rejectedWeekRows.length} OTs durante esta semana; revisar causa y reingreso si aplica.',
    );
  }

  final closeoutPrompts = <String>[
    'Que OTs abiertas anteriores al ${_formatLongDateSpanish(cut.weekStart)} deben cerrarse antes del viernes ${_formatLongDateSpanish(cut.friday)}.',
    'Que equipos concentran fallas repetidas y que accion preventiva concreta se tomara.',
    'Que OTs siguen en cotizacion o autorizacion y quien las destraba hoy.',
    if (rejectedWeekRows.isNotEmpty)
      'Explicar por que se rechazaron ${rejectedWeekRows.length} OTs esta semana y si deben corregirse o descartarse.',
    if (criticalOpenRows.isNotEmpty)
      'Las OTs criticas abiertas no deben salir de la junta sin responsable, fecha y siguiente paso definido.',
  ];

  return _OperationsWeeklyInsights(
    openCount: openRows.length,
    criticalOpenCount: criticalOpenRows.length,
    delayedOpenCount: delayedOpenRows.length,
    waitingActionCount: waitingActionRows.length,
    closedWeekCount: closedWeekRows.length,
    rejectedWeekCount: rejectedWeekRows.length,
    openRows: openRows,
    resolvedWeekRows: resolvedWeekRows,
    areaRows: areaRows,
    equipmentRows: equipmentRows,
    focusRows: focusRows,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

bool _isWithinWeeklyCut(DateTime? value, _OperationsWeeklyCut cut) {
  if (value == null) return false;
  return !value.isBefore(cut.weekStart) && !value.isAfter(cut.cutoffAt);
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

Future<List<_ExpensesPurchaseOrderRow>>
_loadExpensesDailyPurchaseOrderRows() async {
  final results = await Future.wait<dynamic>([
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('maintenance_purchase_orders')
          .select(_kExpensesPurchaseOrderFields)
          .order('order_date', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: true)
          .range(from, to),
    ),
    fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('maintenance_purchase_order_lines')
          .select(_kExpensesPurchaseOrderLineFields)
          .order('purchase_order_id', ascending: true)
          .order('line_no', ascending: true)
          .order('id', ascending: true)
          .range(from, to),
    ),
  ]);

  final rawOrders = (results[0] as List<Map<String, dynamic>>)
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
  final rawLines = (results[1] as List<Map<String, dynamic>>)
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);

  final lineDescriptionsByOrderId = <String, List<String>>{};
  final lineTotalsByOrderId = <String, double>{};
  for (final line in rawLines) {
    final orderId = _cleanString(line['purchase_order_id']);
    if (orderId.isEmpty) continue;
    final description = _cleanString(line['description']);
    if (description.isNotEmpty) {
      lineDescriptionsByOrderId.putIfAbsent(orderId, () => <String>[]);
      lineDescriptionsByOrderId[orderId]!.add(description);
    }
    final explicitTotal = _toNullableDouble(line['line_total']);
    final qty = _toNullableDouble(line['qty']) ?? 0;
    final amount = _toNullableDouble(line['amount']) ?? 0;
    final lineTotal = explicitTotal != null && explicitTotal > 0.009
        ? explicitTotal
        : qty * amount;
    lineTotalsByOrderId.update(
      orderId,
      (value) => value + lineTotal,
      ifAbsent: () => lineTotal,
    );
  }

  final linkedOtIds = rawOrders
      .map((row) => _cleanString(row['linked_ot_id']))
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  final linkedOtById = <String, Map<String, dynamic>>{};
  if (linkedOtIds.isNotEmpty) {
    final linkedOtRows = await Supabase.instance.client
        .from('maintenance_orders')
        .select(_kExpensesLinkedOtFields)
        .inFilter('id', linkedOtIds);
    for (final raw in linkedOtRows as List) {
      final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final id = _cleanString(row['id']);
      if (id.isEmpty) continue;
      linkedOtById[id] = row;
    }
  }

  final rows = rawOrders
      .map(
        (row) => _ExpensesPurchaseOrderRow.fromJson(
          row,
          lineDescriptions:
              lineDescriptionsByOrderId[_cleanString(row['id'])] ??
              const <String>[],
          lineEstimatedTotal: lineTotalsByOrderId[_cleanString(row['id'])] ?? 0,
          linkedOt: linkedOtById[_cleanString(row['linked_ot_id'])],
        ),
      )
      .toList(growable: false);
  rows.sort((a, b) {
    final dateCompare = b.orderDate.compareTo(a.orderDate);
    if (dateCompare != 0) return dateCompare;
    return a.folio.toLowerCase().compareTo(b.folio.toLowerCase());
  });
  return rows;
}

_ExpensesDailyInsights _buildExpensesDailyInsights(
  List<_ExpensesPurchaseOrderRow> rows,
  DateTime generatedAt,
) {
  final today = _pdfDateOnly(generatedAt);
  final activeRows = rows.where((row) => row.requiresFollowUp).toList()
    ..sort((a, b) {
      final scoreCompare = b
          .focusScoreAt(today)
          .compareTo(a.focusScoreAt(today));
      if (scoreCompare != 0) return scoreCompare;
      final ageCompare = b
          .backlogAgeDaysAt(today)
          .compareTo(a.backlogAgeDaysAt(today));
      if (ageCompare != 0) return ageCompare;
      return b.sortAnchorAt.compareTo(a.sortAnchorAt);
    });
  final movementTodayRows =
      rows.where((row) => row.hasVisibleMovementOn(today)).toList()
        ..sort((a, b) => b.sortAnchorAt.compareTo(a.sortAnchorAt));
  final purchasedTodayRows = movementTodayRows
      .where((row) => row.isPurchasedToday(today))
      .toList(growable: false);
  final sentToCashRows = activeRows
      .where((row) => row.isSentToCash)
      .toList(growable: false);
  final pendingDirectionRows = activeRows
      .where((row) => row.isPendingDirection)
      .toList(growable: false);
  final rejectedRows = activeRows
      .where((row) => row.isRejected)
      .toList(growable: false);
  final otLinkedActiveRows = activeRows
      .where((row) => row.isLinkedToOt)
      .toList(growable: false);
  final otLinkedRows =
      rows
          .where(
            (row) =>
                row.isLinkedToOt &&
                (row.requiresFollowUp || row.hasVisibleMovementOn(today)),
          )
          .toList()
        ..sort((a, b) {
          final activeCompare = (b.requiresFollowUp ? 1 : 0).compareTo(
            a.requiresFollowUp ? 1 : 0,
          );
          if (activeCompare != 0) return activeCompare;
          final scoreCompare = b
              .focusScoreAt(today)
              .compareTo(a.focusScoreAt(today));
          if (scoreCompare != 0) return scoreCompare;
          return b.sortAnchorAt.compareTo(a.sortAnchorAt);
        });
  final backlogRows =
      activeRows.where((row) => row.isBacklogBefore(today)).toList()
        ..sort((a, b) {
          final ageCompare = b
              .backlogAgeDaysAt(today)
              .compareTo(a.backlogAgeDaysAt(today));
          if (ageCompare != 0) return ageCompare;
          final amountCompare = b.activeAmount.compareTo(a.activeAmount);
          if (amountCompare != 0) return amountCompare;
          return a.folio.toLowerCase().compareTo(b.folio.toLowerCase());
        });
  final targetGroups = <String, List<_ExpensesPurchaseOrderRow>>{};
  for (final row in activeRows) {
    targetGroups.putIfAbsent(
      row.targetLabel,
      () => <_ExpensesPurchaseOrderRow>[],
    );
    targetGroups[row.targetLabel]!.add(row);
  }
  final targetRows =
      targetGroups.entries
          .map(
            (entry) => _ExpensesDailyTargetRow(
              targetLabel: entry.key,
              activeCount: entry.value.length,
              otLinkedCount: entry.value
                  .where((row) => row.isLinkedToOt)
                  .length,
              sentToCashCount: entry.value
                  .where((row) => row.isSentToCash)
                  .length,
              pendingDirectionCount: entry.value
                  .where((row) => row.isPendingDirection)
                  .length,
              activeAmount: entry.value.fold<double>(
                0,
                (sum, row) => sum + row.activeAmount,
              ),
            ),
          )
          .toList()
        ..sort((a, b) {
          final byCount = b.activeCount.compareTo(a.activeCount);
          if (byCount != 0) return byCount;
          final byAmount = b.activeAmount.compareTo(a.activeAmount);
          if (byAmount != 0) return byAmount;
          return a.targetLabel.toLowerCase().compareTo(
            b.targetLabel.toLowerCase(),
          );
        });

  final activeVisibleAmount = activeRows.fold<double>(
    0,
    (sum, row) => sum + row.activeAmount,
  );
  final sentToCashVisibleAmount = sentToCashRows.fold<double>(
    0,
    (sum, row) => sum + row.activeAmount,
  );
  final pendingDirectionVisibleAmount = pendingDirectionRows.fold<double>(
    0,
    (sum, row) => sum + row.activeAmount,
  );
  final otLinkedVisibleAmount = otLinkedActiveRows.fold<double>(
    0,
    (sum, row) => sum + row.activeAmount,
  );
  final purchasedTodayAmount = purchasedTodayRows.fold<double>(
    0,
    (sum, row) => sum + row.realizedAmount,
  );
  final backlogVisibleAmount = backlogRows.fold<double>(
    0,
    (sum, row) => sum + row.activeAmount,
  );
  final movementTodayVisibleAmount = movementTodayRows.fold<double>(
    0,
    (sum, row) =>
        sum + (row.isPurchased ? row.realizedAmount : row.activeAmount),
  );
  final todayVarianceAmount = purchasedTodayRows.fold<double>(
    0,
    (sum, row) => sum + (row.varianceAmount ?? 0),
  );
  final missingVisibleAmountRows = activeRows
      .where((row) => !row.hasVisibleActiveAmount)
      .toList(growable: false);
  final oldestBacklogDate = backlogRows.isEmpty
      ? null
      : backlogRows
            .map((row) => row.orderDate)
            .reduce((left, right) => left.isBefore(right) ? left : right);

  final executiveSummary = <String>[];
  if (activeRows.isEmpty && movementTodayRows.isEmpty) {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(generatedAt)} no hay OCs activas ni movimiento visible hoy dentro de Compras OT.',
    );
  } else {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(generatedAt)}, Gastos mantiene ${activeRows.length} OCs con seguimiento activo por ${_formatCurrency(activeVisibleAmount)}.',
    );
    if (sentToCashRows.isNotEmpty) {
      executiveSummary.add(
        '${sentToCashRows.length} OCs ya estan mandadas a caja por ${_formatCurrency(sentToCashVisibleAmount)} y siguen sin cerrarse como compra verificada.',
      );
    } else {
      executiveSummary.add(
        'No hay OCs activas mandadas a caja pendientes de cierre en este corte.',
      );
    }
    if (pendingDirectionRows.isNotEmpty) {
      executiveSummary.add(
        '${pendingDirectionRows.length} OCs siguen atoradas en Direccion por ${_formatCurrency(pendingDirectionVisibleAmount)} antes de pasar a compra.',
      );
    }
    if (purchasedTodayRows.isNotEmpty) {
      executiveSummary.add(
        'Hoy ya se verificaron ${purchasedTodayRows.length} compras por ${_formatCurrency(purchasedTodayAmount)} dentro del flujo visible.',
      );
    }
    if (otLinkedActiveRows.isNotEmpty) {
      executiveSummary.add(
        '${otLinkedActiveRows.length} OCs activas siguen ligadas a OT por ${_formatCurrency(otLinkedVisibleAmount)}.',
      );
    }
    if (backlogRows.isNotEmpty && oldestBacklogDate != null) {
      executiveSummary.add(
        'Siguen arrastradas ${backlogRows.length} OCs previas desde ${_formatLongDateSpanish(oldestBacklogDate)} por ${_formatCurrency(backlogVisibleAmount)}.',
      );
    }
    if (targetRows.isNotEmpty) {
      executiveSummary.add(
        'El destino con mayor carga abierta es ${_sanitizePdfText(targetRows.first.targetLabel)} con ${targetRows.first.activeCount} OCs por ${_formatCurrency(targetRows.first.activeAmount)}.',
      );
    }
    if (movementTodayRows.isNotEmpty) {
      executiveSummary.add(
        'El movimiento visible de hoy suma ${movementTodayRows.length} OCs por ${_formatCurrency(movementTodayVisibleAmount)} entre aperturas, envios a caja y compras verificadas.',
      );
    }
    if (todayVarianceAmount.abs() >= 0.009) {
      executiveSummary.add(
        'En las compras cerradas hoy ya se observa una variacion neta de ${_formatCurrency(todayVarianceAmount)} contra el estimado visible.',
      );
    }
  }
  executiveSummary.add(
    'La retroalimentacion completa del flujo de compras sigue pendiente; este corte solo lee lo ya capturado en la propia OC y su liga a OT.',
  );

  final alerts = <String>[];
  if (sentToCashRows.isNotEmpty) {
    alerts.add(
      'Hay ${sentToCashRows.length} OCs en caja sin cierre de compra verificada.',
    );
  }
  if (pendingDirectionRows.isNotEmpty) {
    alerts.add(
      'Hay ${pendingDirectionRows.length} OCs bloqueadas en Direccion antes de poder comprar.',
    );
  }
  if (rejectedRows.isNotEmpty) {
    alerts.add(
      'Hay ${rejectedRows.length} OCs rechazadas que siguen vivas y requieren correccion para no quedarse en el limbo.',
    );
  }
  if (missingVisibleAmountRows.isNotEmpty) {
    final folios = missingVisibleAmountRows
        .map((row) => row.folio)
        .take(4)
        .join(', ');
    alerts.add(
      'Falta monto visible en ${missingVisibleAmountRows.length} OCs activas: $folios.',
    );
  }
  if (backlogRows.isNotEmpty &&
      oldestBacklogDate != null &&
      backlogRows.first.backlogAgeDaysAt(today) >= 2) {
    alerts.add(
      'La OC activa mas antigua viene desde ${_formatLongDateSpanish(oldestBacklogDate)} y ya carga arrastre operativo.',
    );
  }
  if (otLinkedActiveRows.length >= 3) {
    alerts.add(
      'Las OCs ligadas a OT ya concentran ${otLinkedActiveRows.length} seguimientos activos en este corte.',
    );
  }
  if (todayVarianceAmount.abs() >= 10000) {
    alerts.add(
      'La variacion neta visible en compras cerradas hoy ya pega ${_formatCurrency(todayVarianceAmount)} contra el estimado.',
    );
  }

  final closeoutPrompts = <String>[
    'Que OCs ya mandadas a caja deben cerrarse hoy mismo y cuales realmente se quedan para manana.',
    'Que OCs pendientes de Direccion si bloquean operacion y cuales siguen siendo urgencia mal planeada.',
    'Que OCs ligadas a OT si estan resolviendo la OT correcta o solo siguen estirando el problema.',
    'Que arrastre abierto de dias previos ya debe cerrarse, cancelarse o justificarse con siguiente paso real.',
    if (missingVisibleAmountRows.isNotEmpty)
      'No debe salir de la junta ninguna OC activa sin monto visible capturado.',
    if (rejectedRows.isNotEmpty)
      'Las OCs rechazadas deben salir con correccion puntual o decision de descarte, no quedarse abiertas por inercia.',
  ];

  return _ExpensesDailyInsights(
    activeRows: activeRows,
    movementTodayRows: movementTodayRows,
    purchasedTodayRows: purchasedTodayRows,
    focusRows: activeRows.take(12).toList(growable: false),
    otLinkedRows: otLinkedRows,
    backlogRows: backlogRows,
    targetRows: targetRows,
    activeVisibleAmount: activeVisibleAmount,
    sentToCashVisibleAmount: sentToCashVisibleAmount,
    pendingDirectionVisibleAmount: pendingDirectionVisibleAmount,
    otLinkedVisibleAmount: otLinkedVisibleAmount,
    purchasedTodayAmount: purchasedTodayAmount,
    backlogVisibleAmount: backlogVisibleAmount,
    movementTodayVisibleAmount: movementTodayVisibleAmount,
    todayVarianceAmount: todayVarianceAmount,
    sentToCashCount: sentToCashRows.length,
    pendingDirectionCount: pendingDirectionRows.length,
    rejectedCount: rejectedRows.length,
    otLinkedActiveCount: otLinkedActiveRows.length,
    missingVisibleAmountCount: missingVisibleAmountRows.length,
    oldestBacklogDate: oldestBacklogDate,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

class _ExpensesPurchaseOrderRow {
  final String id;
  final String folio;
  final DateTime orderDate;
  final String targetLabel;
  final String vendorName;
  final String vendorType;
  final String contact;
  final String notes;
  final String status;
  final String requestedByName;
  final DateTime? requestedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String directionComment;
  final DateTime? sentToCashAt;
  final String sentToCashByName;
  final DateTime? purchasedAt;
  final String purchasedByName;
  final double estimatedTotal;
  final double? actualTotal;
  final String linkedOtId;
  final String linkedOtFolio;
  final String linkedMaterialLabel;
  final bool generatedFromOt;
  final String linkedOtStatus;
  final String linkedOtArea;
  final String linkedOtEquipment;
  final List<String> lineDescriptions;

  const _ExpensesPurchaseOrderRow({
    required this.id,
    required this.folio,
    required this.orderDate,
    required this.targetLabel,
    required this.vendorName,
    required this.vendorType,
    required this.contact,
    required this.notes,
    required this.status,
    required this.requestedByName,
    required this.requestedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.directionComment,
    required this.sentToCashAt,
    required this.sentToCashByName,
    required this.purchasedAt,
    required this.purchasedByName,
    required this.estimatedTotal,
    required this.actualTotal,
    required this.linkedOtId,
    required this.linkedOtFolio,
    required this.linkedMaterialLabel,
    required this.generatedFromOt,
    required this.linkedOtStatus,
    required this.linkedOtArea,
    required this.linkedOtEquipment,
    required this.lineDescriptions,
  });

  factory _ExpensesPurchaseOrderRow.fromJson(
    Map<String, dynamic> json, {
    required List<String> lineDescriptions,
    required double lineEstimatedTotal,
    Map<String, dynamic>? linkedOt,
  }) {
    final requestedAt = DateTime.tryParse(
      (json['requested_at'] ?? '').toString(),
    );
    final createdAt = DateTime.tryParse((json['created_at'] ?? '').toString());
    final orderDate =
        DateTime.tryParse((json['order_date'] ?? '').toString()) ??
        requestedAt ??
        createdAt ??
        DateTime.now();
    final explicitEstimated = _toNullableDouble(json['estimated_total']) ?? 0;
    final normalizedEstimated = explicitEstimated > 0.009
        ? explicitEstimated
        : lineEstimatedTotal;
    final explicitActual = _toNullableDouble(json['actual_total']);
    return _ExpensesPurchaseOrderRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      folio: _stringOrFallback(json['folio'], 'Sin folio'),
      orderDate: orderDate,
      targetLabel: _stringOrFallback(json['target_label'], 'Sin destino'),
      vendorName: _cleanString(json['quote_vendor_name']),
      vendorType: _cleanString(json['quote_vendor_type']),
      contact: _cleanString(json['quote_contact']),
      notes: _cleanString(json['notes']),
      status: _normalizeTag(json['status']),
      requestedByName: _cleanString(json['requested_by_name']),
      requestedAt: requestedAt,
      createdAt: createdAt,
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      directionComment: _cleanString(json['direction_comment']),
      sentToCashAt: DateTime.tryParse(
        (json['sent_to_cash_at'] ?? '').toString(),
      ),
      sentToCashByName: _cleanString(json['sent_to_cash_by_name']),
      purchasedAt: DateTime.tryParse((json['purchased_at'] ?? '').toString()),
      purchasedByName: _cleanString(json['purchased_by_name']),
      estimatedTotal: normalizedEstimated < 0 ? 0 : normalizedEstimated,
      actualTotal: explicitActual == null || explicitActual <= 0.009
          ? null
          : explicitActual,
      linkedOtId: _cleanString(json['linked_ot_id']),
      linkedOtFolio: _cleanString(
        linkedOt?['ot_folio'] ?? json['linked_ot_folio'],
      ),
      linkedMaterialLabel: _cleanString(json['linked_material_label']),
      generatedFromOt: json['generated_from_ot'] == true,
      linkedOtStatus: normalizeMaintenanceStatus(linkedOt?['status']),
      linkedOtArea: _cleanString(linkedOt?['area_label']),
      linkedOtEquipment: _cleanString(linkedOt?['equipment_label']),
      lineDescriptions: lineDescriptions,
    );
  }

  bool get isPurchased => status == 'purchased';
  bool get isPendingDirection => status == 'pending_direction';
  bool get isAuthorized => status == 'authorized';
  bool get isRejected => status == 'rejected';
  bool get isDraft => status == 'draft';
  bool get requiresFollowUp => !isPurchased;
  bool get isSentToCash => isAuthorized && sentToCashAt != null;
  bool get isLinkedToOt => linkedOtId.isNotEmpty || linkedOtFolio.isNotEmpty;
  bool get hasVisibleActiveAmount => activeAmount > 0.009;

  double get activeAmount {
    final amount = estimatedTotal > 0.009 ? estimatedTotal : (actualTotal ?? 0);
    return amount < 0 ? 0 : amount;
  }

  double get realizedAmount {
    final amount = actualTotal ?? estimatedTotal;
    return amount < 0 ? 0 : amount;
  }

  double? get varianceAmount {
    if (actualTotal == null || estimatedTotal <= 0.009) return null;
    return actualTotal! - estimatedTotal;
  }

  String get vendorLabel {
    if (vendorName.isNotEmpty) return vendorName;
    if (vendorType.isNotEmpty) return vendorType;
    return 'Sin proveedor';
  }

  String get conceptLabel {
    if (linkedMaterialLabel.isNotEmpty) return linkedMaterialLabel;
    if (lineDescriptions.isNotEmpty) return lineDescriptions.first;
    return vendorLabel;
  }

  String get vendorAndConceptLabel {
    final concept = conceptLabel;
    if (vendorName.isEmpty) return concept;
    if (concept.toLowerCase() == vendorName.toLowerCase()) return vendorName;
    return '$vendorName | $concept';
  }

  String get otLabel => linkedOtFolio.isEmpty ? 'Sin OT' : linkedOtFolio;

  String get linkedOtStatusLabel {
    if (!isLinkedToOt) return 'Sin OT';
    final label = maintenanceStatusShortLabel(linkedOtStatus).trim();
    if (label.isNotEmpty) return label;
    return linkedOtStatus.isEmpty ? 'Sin estatus OT' : linkedOtStatus;
  }

  String get statusLabel => switch (status) {
    'authorized' => 'Autorizada',
    'purchased' => 'Comprada',
    'pending_direction' => 'Pendiente Direccion',
    'rejected' => 'Rechazada',
    _ => 'Borrador',
  };

  String get actionStageLabel {
    if (isPurchased) return 'Compra verificada';
    if (isSentToCash) return 'Mandada a caja';
    if (isAuthorized) return 'Pendiente de compra';
    if (isPendingDirection) return 'Pendiente de Direccion';
    if (isRejected) return 'Requiere correccion';
    return 'Lista para captura';
  }

  String get otFollowUpLabel {
    final parts = <String>[actionStageLabel];
    if (linkedOtStatusLabel != 'Sin OT' &&
        linkedOtStatusLabel != 'Sin estatus OT') {
      parts.add(linkedOtStatusLabel);
    }
    if (linkedOtEquipment.isNotEmpty) parts.add(linkedOtEquipment);
    return parts.join(' | ');
  }

  String get noteLabel {
    final parts = <String>[];
    if (directionComment.isNotEmpty) parts.add(directionComment);
    if (notes.isNotEmpty) parts.add(notes);
    if (parts.isNotEmpty) return parts.join(' | ');
    return actionStageLabel;
  }

  String get backlogReadLabel {
    final parts = <String>[actionStageLabel];
    if (isLinkedToOt) parts.add('Ligada OT');
    if (noteLabel != actionStageLabel) parts.add(noteLabel);
    return parts.join(' | ');
  }

  DateTime get sortAnchorAt {
    var latest = requestedAt ?? createdAt ?? orderDate;
    for (final candidate in <DateTime?>[updatedAt, sentToCashAt, purchasedAt]) {
      if (candidate != null && candidate.isAfter(latest)) {
        latest = candidate;
      }
    }
    return latest;
  }

  bool hasVisibleMovementOn(DateTime dayStart) {
    return _pdfDateOnly(orderDate).isAtSameMomentAs(dayStart) ||
        _isOnReportDay(sentToCashAt, dayStart) ||
        _isOnReportDay(purchasedAt, dayStart);
  }

  bool isPurchasedToday(DateTime dayStart) =>
      isPurchased && _isOnReportDay(purchasedAt, dayStart);

  bool isBacklogBefore(DateTime dayStart) =>
      requiresFollowUp && _pdfDateOnly(orderDate).isBefore(dayStart);

  int backlogAgeDaysAt(DateTime dayStart) {
    final diff = dayStart.difference(_pdfDateOnly(orderDate)).inDays;
    return diff < 0 ? 0 : diff;
  }

  int focusScoreAt(DateTime dayStart) {
    if (!requiresFollowUp) return 0;
    var score = 0;
    if (isSentToCash) {
      score += 8;
    } else if (isAuthorized) {
      score += 5;
    }
    if (isPendingDirection) score += 6;
    if (isRejected) score += 5;
    if (isDraft) score += 2;
    if (isLinkedToOt) score += 4;
    if (generatedFromOt) score += 1;
    final ageDays = backlogAgeDaysAt(dayStart);
    if (ageDays > 0) {
      final boundedAge = ageDays > 5 ? 5 : ageDays;
      score += boundedAge * 2;
    }
    if (!hasVisibleActiveAmount) score += 4;
    if (activeAmount >= 200000) {
      score += 4;
    } else if (activeAmount >= 100000) {
      score += 3;
    } else if (activeAmount >= 30000) {
      score += 1;
    }
    if (linkedOtStatus == 'cotizacion' ||
        linkedOtStatus == 'autorizacion_finanzas') {
      score += 2;
    }
    return score;
  }

  String focusReasonAt(DateTime dayStart) {
    final reasons = <String>[];
    if (isSentToCash) reasons.add('En caja');
    if (isPendingDirection) reasons.add('Pend. Direccion');
    if (isRejected) reasons.add('Rechazada');
    if (isLinkedToOt) reasons.add('Ligada OT');
    final ageDays = backlogAgeDaysAt(dayStart);
    if (ageDays > 0) reasons.add('Arrastre $ageDays d');
    if (!hasVisibleActiveAmount) reasons.add('Sin monto');
    if (reasons.isEmpty) reasons.add('Seguimiento activo');
    return reasons.join(' | ');
  }

  String movementLabelAt(DateTime dayStart) {
    final labels = <String>[];
    if (isPurchasedToday(dayStart)) labels.add('Comprada hoy');
    if (_isOnReportDay(sentToCashAt, dayStart)) labels.add('Mandada a caja');
    if (_pdfDateOnly(orderDate).isAtSameMomentAs(dayStart)) {
      labels.add('OC de hoy');
    }
    if (labels.isEmpty) labels.add(actionStageLabel);
    return labels.join(' | ');
  }
}

class _ExpensesDailyTargetRow {
  final String targetLabel;
  final int activeCount;
  final int otLinkedCount;
  final int sentToCashCount;
  final int pendingDirectionCount;
  final double activeAmount;

  const _ExpensesDailyTargetRow({
    required this.targetLabel,
    required this.activeCount,
    required this.otLinkedCount,
    required this.sentToCashCount,
    required this.pendingDirectionCount,
    required this.activeAmount,
  });
}

class _ExpensesDailyInsights {
  final List<_ExpensesPurchaseOrderRow> activeRows;
  final List<_ExpensesPurchaseOrderRow> movementTodayRows;
  final List<_ExpensesPurchaseOrderRow> purchasedTodayRows;
  final List<_ExpensesPurchaseOrderRow> focusRows;
  final List<_ExpensesPurchaseOrderRow> otLinkedRows;
  final List<_ExpensesPurchaseOrderRow> backlogRows;
  final List<_ExpensesDailyTargetRow> targetRows;
  final double activeVisibleAmount;
  final double sentToCashVisibleAmount;
  final double pendingDirectionVisibleAmount;
  final double otLinkedVisibleAmount;
  final double purchasedTodayAmount;
  final double backlogVisibleAmount;
  final double movementTodayVisibleAmount;
  final double todayVarianceAmount;
  final int sentToCashCount;
  final int pendingDirectionCount;
  final int rejectedCount;
  final int otLinkedActiveCount;
  final int missingVisibleAmountCount;
  final DateTime? oldestBacklogDate;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _ExpensesDailyInsights({
    required this.activeRows,
    required this.movementTodayRows,
    required this.purchasedTodayRows,
    required this.focusRows,
    required this.otLinkedRows,
    required this.backlogRows,
    required this.targetRows,
    required this.activeVisibleAmount,
    required this.sentToCashVisibleAmount,
    required this.pendingDirectionVisibleAmount,
    required this.otLinkedVisibleAmount,
    required this.purchasedTodayAmount,
    required this.backlogVisibleAmount,
    required this.movementTodayVisibleAmount,
    required this.todayVarianceAmount,
    required this.sentToCashCount,
    required this.pendingDirectionCount,
    required this.rejectedCount,
    required this.otLinkedActiveCount,
    required this.missingVisibleAmountCount,
    required this.oldestBacklogDate,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
  });
}

class _SalesDailyReportRow {
  final String id;
  final String ticket;
  final DateTime date;
  final String clientName;
  final String remision;
  final String materialName;
  final double exitWeight;
  final double priceSnapshot;
  final double? approvedWeight;
  final double? approvedPrice;
  final double approvedAmount;
  final String operationType;
  final String observations;
  final String documentNumber;
  final DateTime? documentDate;
  final DateTime? estimatedPaymentDate;
  final DateTime? settlementDate;
  final String statusKey;
  final String financialNotes;
  final double paidAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const _SalesDailyReportRow({
    required this.id,
    required this.ticket,
    required this.date,
    required this.clientName,
    required this.remision,
    required this.materialName,
    required this.exitWeight,
    required this.priceSnapshot,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
    required this.operationType,
    required this.observations,
    required this.documentNumber,
    required this.documentDate,
    required this.estimatedPaymentDate,
    required this.settlementDate,
    required this.statusKey,
    required this.financialNotes,
    required this.paidAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _SalesDailyReportRow.fromJson(Map<String, dynamic> json) {
    return _SalesDailyReportRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      ticket: _stringOrFallback(json['ticket'], 'Sin ticket'),
      date:
          DateTime.tryParse((json['sale_date'] ?? '').toString()) ??
          DateTime.now(),
      clientName: _stringOrFallback(
        json['client_name_snapshot'],
        'Sin cliente',
      ),
      remision: _cleanString(json['remision']),
      materialName: _stringOrFallback(
        json['material_name_snapshot'],
        'Sin material',
      ),
      exitWeight: _toNullableDouble(json['exit_weight']) ?? 0,
      priceSnapshot: _toNullableDouble(json['price_snapshot']) ?? 0,
      approvedWeight: _toNullableDouble(json['approved_weight']),
      approvedPrice: _toNullableDouble(json['approved_price']),
      approvedAmount: _toNullableDouble(json['approved_amount']) ?? 0,
      operationType: _normalizeTag(json['operation_type']),
      observations: _cleanString(json['observations']),
      documentNumber: '',
      documentDate: null,
      estimatedPaymentDate: null,
      settlementDate: null,
      statusKey: '',
      financialNotes: '',
      paidAmount: 0,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }

  _SalesDailyReportRow copyWithAccountState({
    required String documentNumber,
    required DateTime? documentDate,
    required DateTime? estimatedPaymentDate,
    required DateTime? settlementDate,
    required String statusKey,
    required String financialNotes,
    required double paidAmount,
  }) {
    return _SalesDailyReportRow(
      id: id,
      ticket: ticket,
      date: date,
      clientName: clientName,
      remision: remision,
      materialName: materialName,
      exitWeight: exitWeight,
      priceSnapshot: priceSnapshot,
      approvedWeight: approvedWeight,
      approvedPrice: approvedPrice,
      approvedAmount: approvedAmount,
      operationType: operationType,
      observations: observations,
      documentNumber: documentNumber,
      documentDate: documentDate,
      estimatedPaymentDate: estimatedPaymentDate,
      settlementDate: settlementDate,
      statusKey: statusKey,
      financialNotes: financialNotes,
      paidAmount: paidAmount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isRelated =>
      approvedWeight != null && approvedPrice != null && approvedWeight! > 0;

  double get snapshotAmount => exitWeight * priceSnapshot;

  String get _defaultStatusKey =>
      operationType == 'cheque' ? 'pendientecheque' : 'pendientefactura';

  String get normalizedStatusKey {
    if (!isRelated) return 'porrelacionar';
    return _deriveSalesReportStatusKey(
      baseStatus: statusKey.isEmpty ? _defaultStatusKey : statusKey,
      operationType: operationType,
      documentNumber: documentNumber,
      documentDate: documentDate,
      settlementDate: settlementDate,
      paidAmount: paidAmount,
      approvedAmount: approvedAmount > 0 ? approvedAmount : snapshotAmount,
    );
  }

  bool get hasDocumentEvidence =>
      documentNumber.trim().isNotEmpty || documentDate != null;

  bool get isPendingRelationship => !isRelated;

  bool get isCancelled => normalizedStatusKey == 'cancelada';

  bool get isFinalized =>
      normalizedStatusKey == 'pagada' ||
      normalizedStatusKey == 'chequecanjeado';

  bool get needsManualReview =>
      isRelated && normalizedStatusKey == 'porrevisar';

  bool get isPendingDocument =>
      isRelated &&
      !isCancelled &&
      !isFinalized &&
      !needsManualReview &&
      !hasDocumentEvidence;

  bool get isPendingOperationalClosure =>
      !isCancelled &&
      !isFinalized &&
      (isPendingRelationship || isPendingDocument || needsManualReview);

  double get pendingSnapshotAmount {
    if (!isPendingOperationalClosure) return 0;
    if (isPendingRelationship) return snapshotAmount;
    final approvedVisibleAmount = approvedAmount > 0 ? approvedAmount : 0.0;
    return approvedVisibleAmount > 0 ? approvedVisibleAmount : snapshotAmount;
  }

  bool get missingRemision => remision.trim().isEmpty;

  String get remisionLabel => missingRemision ? 'Sin remision' : remision;

  String get operationTypeLabel =>
      operationType == 'cheque' ? 'Cheque' : 'Factura';

  String get observationsLabel =>
      observations.trim().isEmpty ? 'Sin observacion' : observations;

  String get pendingStageLabel {
    if (isPendingRelationship) return 'Por relacionar';
    if (needsManualReview) return 'Por revisar';
    return operationType == 'cheque' ? 'Pend. cheque' : 'Pend. factura';
  }

  String get commercialReadLabel {
    if (isPendingRelationship) {
      return 'Falta aprobacion comercial';
    }
    if (needsManualReview) {
      return 'Requiere revision manual';
    }
    if (operationType == 'cheque') {
      return 'Falta documento de cheque';
    }
    return 'Falta factura';
  }

  String get attentionLabel {
    final notes = <String>[];
    if (financialNotes.trim().isNotEmpty) notes.add(financialNotes.trim());
    if (observations.trim().isNotEmpty) notes.add(observations.trim());
    if (notes.isNotEmpty) return notes.join(' | ');
    return commercialReadLabel;
  }

  int pendingAgeDaysAt(DateTime referenceDate) {
    final normalizedRef = _pdfDateOnly(referenceDate);
    final normalizedDate = _pdfDateOnly(date);
    final diff = normalizedRef.difference(normalizedDate).inDays;
    return diff < 0 ? 0 : diff;
  }

  int focusScoreAt(DateTime referenceDate) {
    if (!isPendingOperationalClosure) return 0;
    var score = pendingAgeDaysAt(referenceDate) * 5;
    if (isPendingRelationship) score += 6;
    if (isPendingDocument) score += 5;
    if (needsManualReview) score += 4;
    if (operationType == 'factura') score += 3;
    if (missingRemision) score += 3;
    if (attentionLabel != commercialReadLabel) score += 1;
    if (pendingSnapshotAmount >= 200000) {
      score += 5;
    } else if (pendingSnapshotAmount >= 100000) {
      score += 3;
    } else if (pendingSnapshotAmount >= 30000) {
      score += 1;
    }
    return score;
  }

  String focusReasonAt(DateTime referenceDate) {
    final reasons = <String>[];
    final ageDays = pendingAgeDaysAt(referenceDate);
    if (ageDays > 0) {
      reasons.add('Arrastre $ageDays d');
    } else {
      reasons.add('Pendiente de hoy');
    }
    reasons.add(pendingStageLabel);
    if (missingRemision) reasons.add('Sin remision');
    if (needsManualReview) reasons.add('Revision manual');
    if (attentionLabel != commercialReadLabel) reasons.add('Con notas');
    return reasons.join(' | ');
  }
}

class _SalesDailyClientRow {
  final String clientName;
  final int pendingTodayCount;
  final int backlogCount;
  final int relationshipPendingCount;
  final int documentPendingCount;
  final int reviewCount;
  final double pendingWeight;
  final double pendingAmount;
  final DateTime? oldestPendingDate;

  const _SalesDailyClientRow({
    required this.clientName,
    required this.pendingTodayCount,
    required this.backlogCount,
    required this.relationshipPendingCount,
    required this.documentPendingCount,
    required this.reviewCount,
    required this.pendingWeight,
    required this.pendingAmount,
    required this.oldestPendingDate,
  });

  int get totalPendingCount => pendingTodayCount + backlogCount;
}

class _SalesDailyInsights {
  final List<_SalesDailyReportRow> allRows;
  final List<_SalesDailyReportRow> todayRows;
  final List<_SalesDailyReportRow> relatedTodayRows;
  final List<_SalesDailyReportRow> pendingTodayRows;
  final List<_SalesDailyReportRow> backlogPendingRows;
  final List<_SalesDailyReportRow> focusRows;
  final List<_SalesDailyClientRow> clientRows;
  final double pendingVisibleWeight;
  final double pendingVisibleAmount;
  final int pendingRelationshipCount;
  final int pendingDocumentCount;
  final int pendingReviewCount;
  final int pendingRelationshipTodayCount;
  final int pendingDocumentTodayCount;
  final int pendingReviewTodayCount;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _SalesDailyInsights({
    required this.allRows,
    required this.todayRows,
    required this.relatedTodayRows,
    required this.pendingTodayRows,
    required this.backlogPendingRows,
    required this.focusRows,
    required this.clientRows,
    required this.pendingVisibleWeight,
    required this.pendingVisibleAmount,
    required this.pendingRelationshipCount,
    required this.pendingDocumentCount,
    required this.pendingReviewCount,
    required this.pendingRelationshipTodayCount,
    required this.pendingDocumentTodayCount,
    required this.pendingReviewTodayCount,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
  });
}

class _BasculaWeeklyCut {
  final DateTime weekStart;
  final DateTime friday;
  final DateTime cutoffAt;

  const _BasculaWeeklyCut({
    required this.weekStart,
    required this.friday,
    required this.cutoffAt,
  });

  DateTime get progressEnd => _pdfDateOnly(cutoffAt);

  DateTime get previousWeekStart => weekStart.subtract(const Duration(days: 7));

  DateTime get previousProgressEnd => previousWeekStart.add(
    Duration(days: progressEnd.difference(weekStart).inDays),
  );
}

class _BasculaWeeklySourceBundle {
  final List<_BasculaWeighingRow> currentWeighings;
  final List<_BasculaWeighingRow> previousWeighings;
  final List<_BasculaMovementRow> currentIncomingRows;
  final List<_BasculaMovementRow> previousIncomingRows;
  final List<_BasculaMovementRow> currentOutgoingRows;
  final List<_BasculaMovementRow> previousOutgoingRows;

  const _BasculaWeeklySourceBundle({
    required this.currentWeighings,
    required this.previousWeighings,
    required this.currentIncomingRows,
    required this.previousIncomingRows,
    required this.currentOutgoingRows,
    required this.previousOutgoingRows,
  });
}

class _BasculaWeighingRow {
  final String id;
  final DateTime date;
  final String ticket;
  final String provider;
  final double price;
  final DateTime? createdAt;

  const _BasculaWeighingRow({
    required this.id,
    required this.date,
    required this.ticket,
    required this.provider,
    required this.price,
    required this.createdAt,
  });

  factory _BasculaWeighingRow.fromJson(Map<String, dynamic> json) {
    return _BasculaWeighingRow(
      id: (json['id'] ?? '').toString(),
      date:
          DateTime.tryParse((json['fecha'] ?? '').toString()) ?? DateTime.now(),
      ticket: _stringOrFallback(json['ticket'], 'Sin ticket'),
      provider: _stringOrFallback(json['proveedor'], 'Sin proveedor'),
      price: _toNullableDouble(json['precio']) ?? 0,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class _BasculaMovementRow {
  final String id;
  final DateTime opDate;
  final String flow;
  final String inventoryLevel;
  final String materialCode;
  final String materialName;
  final String counterpartySiteId;
  final String counterparty;
  final String reference;
  final String scaleTicket;
  final double netKg;
  final double totalAmountKg;
  final int unitCount;
  final String originType;
  final String movementReason;
  final String notes;

  const _BasculaMovementRow({
    required this.id,
    required this.opDate,
    required this.flow,
    required this.inventoryLevel,
    required this.materialCode,
    required this.materialName,
    required this.counterpartySiteId,
    required this.counterparty,
    required this.reference,
    required this.scaleTicket,
    required this.netKg,
    required this.totalAmountKg,
    required this.unitCount,
    required this.originType,
    required this.movementReason,
    required this.notes,
  });

  factory _BasculaMovementRow.fromJson(Map<String, dynamic> json) {
    final general = (json['general_material'] as Map?)?.cast<String, dynamic>();
    final commercial = (json['commercial_material'] as Map?)
        ?.cast<String, dynamic>();
    final sourceCommercial = (json['source_commercial'] as Map?)
        ?.cast<String, dynamic>();
    final code = _cleanString(
      (general?['code'] ??
              commercial?['code'] ??
              sourceCommercial?['code'] ??
              '')
          .toString(),
    );
    final name = _cleanString(
      (general?['name'] ??
              commercial?['name'] ??
              sourceCommercial?['name'] ??
              '')
          .toString(),
    );
    return _BasculaMovementRow(
      id: (json['id'] ?? '').toString(),
      opDate:
          DateTime.tryParse((json['op_date'] ?? '').toString()) ??
          DateTime.now(),
      flow: (json['flow'] ?? '').toString().trim().toUpperCase(),
      inventoryLevel: (json['inventory_level'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
      materialCode: code,
      materialName: name,
      counterpartySiteId: (json['counterparty_site_id'] ?? '')
          .toString()
          .trim(),
      counterparty: _cleanString((json['counterparty'] ?? '').toString()),
      reference: _cleanString((json['reference'] ?? '').toString()),
      scaleTicket: _cleanString((json['scale_ticket'] ?? '').toString()),
      netKg:
          (_toNullableDouble(json['net_kg']) ??
                  _toNullableDouble(json['weight_kg']) ??
                  0)
              .clamp(0, double.infinity)
              .toDouble(),
      totalAmountKg: (_toNullableDouble(json['total_amount_kg']) ?? 0)
          .clamp(0, double.infinity)
          .toDouble(),
      unitCount: (json['unit_count'] as num?)?.toInt() ?? 0,
      originType: _cleanString((json['origin_type'] ?? '').toString()),
      movementReason: _cleanString((json['movement_reason'] ?? '').toString()),
      notes: _cleanString((json['notes'] ?? '').toString()),
    );
  }

  bool get isIncoming => flow == 'IN';

  String get materialLabel {
    if (materialCode.isNotEmpty && materialName.isNotEmpty) {
      return '$materialCode | $materialName';
    }
    if (materialCode.isNotEmpty) return materialCode;
    if (materialName.isNotEmpty) return materialName;
    return 'Sin material';
  }

  String get counterpartyLabel =>
      counterparty.trim().isEmpty ? 'Sin contraparte' : counterparty.trim();

  String get ticketLabel {
    if (reference.trim().isNotEmpty) return reference.trim();
    if (scaleTicket.trim().isNotEmpty) return scaleTicket.trim();
    return 'Sin ticket';
  }

  List<String> get ticketKeys {
    final keys = <String>{
      if (_normalizeBasculaTicketKey(reference).isNotEmpty)
        _normalizeBasculaTicketKey(reference),
      if (_normalizeBasculaTicketKey(scaleTicket).isNotEmpty)
        _normalizeBasculaTicketKey(scaleTicket),
    };
    return keys.toList(growable: false);
  }
}

class _BasculaMaterialSummaryRow {
  final String flowLabel;
  final String materialLabel;
  final int movementCount;
  final int ticketCount;
  final double totalKg;
  final double share;
  final DateTime? latestDate;

  const _BasculaMaterialSummaryRow({
    required this.flowLabel,
    required this.materialLabel,
    required this.movementCount,
    required this.ticketCount,
    required this.totalKg,
    required this.share,
    required this.latestDate,
  });
}

class _BasculaCounterpartyMixRow {
  final String segmentLabel;
  final int movementCount;
  final int counterpartyCount;
  final double totalKg;
  final double share;
  final String note;

  const _BasculaCounterpartyMixRow({
    required this.segmentLabel,
    required this.movementCount,
    required this.counterpartyCount,
    required this.totalKg,
    required this.share,
    required this.note,
  });
}

class _BasculaComparisonRow {
  final String flowLabel;
  final String materialLabel;
  final double currentKg;
  final double previousKg;
  final String note;

  const _BasculaComparisonRow({
    required this.flowLabel,
    required this.materialLabel,
    required this.currentKg,
    required this.previousKg,
    required this.note,
  });

  double get deltaKg => currentKg - previousKg;
}

class _BasculaIssueRow {
  final String issueKey;
  final String sourceLabel;
  final DateTime date;
  final String ticketLabel;
  final String materialLabel;
  final String counterpartyLabel;
  final String note;
  final int severity;

  const _BasculaIssueRow({
    required this.issueKey,
    required this.sourceLabel,
    required this.date,
    required this.ticketLabel,
    required this.materialLabel,
    required this.counterpartyLabel,
    required this.note,
    required this.severity,
  });
}

class _BasculaWeeklyInsights {
  final int currentWeighingCount;
  final int previousWeighingCount;
  final int currentIncomingMovementCount;
  final int currentOutgoingMovementCount;
  final double totalIncomingKg;
  final double previousIncomingKg;
  final double totalOutgoingKg;
  final double previousOutgoingKg;
  final int unmatchedWeighingCount;
  final int missingTicketCount;
  final int duplicateWeighingCount;
  final int unknownCounterpartyCount;
  final List<_BasculaMaterialSummaryRow> incomingMaterialRows;
  final List<_BasculaMaterialSummaryRow> outgoingMaterialRows;
  final List<_BasculaCounterpartyMixRow> counterpartyMixRows;
  final List<_BasculaComparisonRow> comparisonRows;
  final List<_BasculaIssueRow> issueRows;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _BasculaWeeklyInsights({
    required this.currentWeighingCount,
    required this.previousWeighingCount,
    required this.currentIncomingMovementCount,
    required this.currentOutgoingMovementCount,
    required this.totalIncomingKg,
    required this.previousIncomingKg,
    required this.totalOutgoingKg,
    required this.previousOutgoingKg,
    required this.unmatchedWeighingCount,
    required this.missingTicketCount,
    required this.duplicateWeighingCount,
    required this.unknownCounterpartyCount,
    required this.incomingMaterialRows,
    required this.outgoingMaterialRows,
    required this.counterpartyMixRows,
    required this.comparisonRows,
    required this.issueRows,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
  });
}

class _SalesWeeklyCut {
  final DateTime weekStart;
  final DateTime friday;
  final DateTime cutoffAt;

  const _SalesWeeklyCut({
    required this.weekStart,
    required this.friday,
    required this.cutoffAt,
  });
}

class _SalesCollectionAccountRow {
  final String id;
  final String ticket;
  final DateTime saleDate;
  final String clientId;
  final String clientName;
  final String remision;
  final String materialName;
  final double approvedWeight;
  final double approvedPrice;
  final double approvedAmount;
  final String operationType;
  final String saleNotes;
  final String documentNumber;
  final DateTime? documentDate;
  final DateTime? estimatedPaymentDate;
  final DateTime? settlementDate;
  final String statusKey;
  final String financialNotes;
  final double paidAmount;
  final DateTime? latestPaymentAt;
  final double weekCollectedAmount;

  const _SalesCollectionAccountRow({
    required this.id,
    required this.ticket,
    required this.saleDate,
    required this.clientId,
    required this.clientName,
    required this.remision,
    required this.materialName,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
    required this.operationType,
    required this.saleNotes,
    required this.documentNumber,
    required this.documentDate,
    required this.estimatedPaymentDate,
    required this.settlementDate,
    required this.statusKey,
    required this.financialNotes,
    required this.paidAmount,
    required this.latestPaymentAt,
    required this.weekCollectedAmount,
  });

  factory _SalesCollectionAccountRow.fromJson(Map<String, dynamic> json) {
    return _SalesCollectionAccountRow(
      id: _stringOrFallback(json['id'], 'sin-id'),
      ticket: _stringOrFallback(json['ticket'], 'Sin ticket'),
      saleDate:
          DateTime.tryParse((json['sale_date'] ?? '').toString()) ??
          DateTime.now(),
      clientId: _cleanString(json['client_id']),
      clientName: _stringOrFallback(
        json['client_name_snapshot'],
        'Sin cliente',
      ),
      remision: _cleanString(json['remision']),
      materialName: _stringOrFallback(
        json['material_name_snapshot'],
        'Sin material',
      ),
      approvedWeight: _toNullableDouble(json['approved_weight']) ?? 0,
      approvedPrice: _toNullableDouble(json['approved_price']) ?? 0,
      approvedAmount: _toNullableDouble(json['approved_amount']) ?? 0,
      operationType: _normalizeTag(json['operation_type']),
      saleNotes: _cleanString(json['sale_notes']),
      documentNumber: _cleanString(json['document_number']),
      documentDate: DateTime.tryParse((json['document_date'] ?? '').toString()),
      estimatedPaymentDate: DateTime.tryParse(
        (json['estimated_payment_date'] ?? '').toString(),
      ),
      settlementDate: DateTime.tryParse(
        (json['settlement_date'] ?? '').toString(),
      ),
      statusKey: _normalizeTag(json['status']),
      financialNotes: _cleanString(json['financial_notes']),
      paidAmount: _toNullableDouble(json['paid_amount']) ?? 0,
      latestPaymentAt: null,
      weekCollectedAmount: 0,
    );
  }

  _SalesCollectionAccountRow copyWith({
    double? paidAmount,
    DateTime? settlementDate,
    bool clearSettlementDate = false,
    String? statusKey,
    DateTime? latestPaymentAt,
    double? weekCollectedAmount,
  }) {
    return _SalesCollectionAccountRow(
      id: id,
      ticket: ticket,
      saleDate: saleDate,
      clientId: clientId,
      clientName: clientName,
      remision: remision,
      materialName: materialName,
      approvedWeight: approvedWeight,
      approvedPrice: approvedPrice,
      approvedAmount: approvedAmount,
      operationType: operationType,
      saleNotes: saleNotes,
      documentNumber: documentNumber,
      documentDate: documentDate,
      estimatedPaymentDate: estimatedPaymentDate,
      settlementDate: clearSettlementDate
          ? null
          : settlementDate ?? this.settlementDate,
      statusKey: statusKey ?? this.statusKey,
      financialNotes: financialNotes,
      paidAmount: paidAmount ?? this.paidAmount,
      latestPaymentAt: latestPaymentAt ?? this.latestPaymentAt,
      weekCollectedAmount: weekCollectedAmount ?? this.weekCollectedAmount,
    );
  }

  double get pendingBalance =>
      (approvedAmount - paidAmount).clamp(0, double.infinity).toDouble();

  bool get isPalomarAccount => isMayoreoPalomarClientName(clientName);

  bool get isOpen =>
      pendingBalance > 0.5 &&
      statusKey != 'cancelada' &&
      statusKey != 'pagada' &&
      statusKey != 'chequecanjeado' &&
      statusKey != 'chequecanjeado';

  bool get isPartial => paidAmount > 0.5 && pendingBalance > 0.5 && isOpen;

  bool get isPendingInvoice =>
      operationType == 'factura' &&
      documentNumber.trim().isEmpty &&
      documentDate == null &&
      isOpen;

  bool get hasOverdueEstimatedPayment {
    if (!isOpen || estimatedPaymentDate == null) return false;
    final today = _pdfDateOnly(DateTime.now());
    return !_pdfDateOnly(estimatedPaymentDate!).isAfter(today);
  }

  bool get hasDocumentEvidence =>
      documentNumber.trim().isNotEmpty || documentDate != null;

  String get documentLabel {
    if (documentNumber.trim().isNotEmpty) return documentNumber.trim();
    return operationType == 'cheque' ? 'Cheque sin numero' : 'Sin factura';
  }

  String get operationTypeLabel =>
      operationType == 'cheque' ? 'Cheque' : 'Factura';

  String get statusLabel => _salesCollectionStatusLabel(statusKey);

  String get collectionNote {
    final notes = <String>[];
    if (financialNotes.trim().isNotEmpty) notes.add(financialNotes.trim());
    if (saleNotes.trim().isNotEmpty) notes.add(saleNotes.trim());
    if (notes.isEmpty) {
      if (isPendingInvoice) return 'Sin factura emitida todavia.';
      if (hasOverdueEstimatedPayment) return 'Promesa de pago vencida.';
      return 'Seguimiento comercial.';
    }
    return notes.join(' | ');
  }

  int ageDaysAt(DateTime referenceDate) {
    final diff = _pdfDateOnly(referenceDate).difference(_pdfDateOnly(saleDate));
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  int focusScore(_SalesWeeklyCut cut) {
    var score = 0;
    if (hasOverdueEstimatedPayment) score += 6;
    if (isPendingInvoice) score += 5;
    if (isPartial) score += 4;
    if (operationType == 'cheque') score += 1;
    if (estimatedPaymentDate == null) score += 2;
    if (pendingBalance >= 300000) {
      score += 6;
    } else if (pendingBalance >= 150000) {
      score += 4;
    } else if (pendingBalance >= 50000) {
      score += 2;
    }
    if (ageDaysAt(cut.cutoffAt) >= 14) score += 4;
    if (ageDaysAt(cut.cutoffAt) >= 7) score += 2;
    return score;
  }

  String focusReason(_SalesWeeklyCut cut) {
    final reasons = <String>[];
    if (hasOverdueEstimatedPayment) reasons.add('Promesa vencida');
    if (isPendingInvoice) reasons.add('Pendiente facturar');
    if (isPartial) reasons.add('Pago parcial');
    if (pendingBalance >= 150000) reasons.add('Monto alto');
    final ageDays = ageDaysAt(cut.cutoffAt);
    if (ageDays >= 7) reasons.add('Arrastre ${ageDays}d');
    if (reasons.isEmpty) reasons.add('Seguimiento');
    return reasons.join(' | ');
  }

  bool hadCollectionDuring(_SalesWeeklyCut cut) {
    if (weekCollectedAmount > 0.5) return true;
    final paymentDate = latestPaymentAt ?? settlementDate;
    if (paymentDate == null || paidAmount <= 0.5) return false;
    final dateOnly = _pdfDateOnly(paymentDate);
    return !dateOnly.isBefore(cut.weekStart) &&
        !dateOnly.isAfter(_pdfDateOnly(cut.cutoffAt));
  }

  double paidThisWeekAmount(_SalesWeeklyCut cut) {
    if (weekCollectedAmount > 0.5) {
      return weekCollectedAmount.clamp(0, double.infinity).toDouble();
    }
    return hadCollectionDuring(cut)
        ? paidAmount.clamp(0, double.infinity).toDouble()
        : 0;
  }
}

class _SalesWeeklyClientRow {
  final String clientName;
  final int openCount;
  final int overdueCount;
  final int pendingInvoiceCount;
  final int partialCount;
  final double pendingBalance;
  final DateTime? oldestSaleDate;

  const _SalesWeeklyClientRow({
    required this.clientName,
    required this.openCount,
    required this.overdueCount,
    required this.pendingInvoiceCount,
    required this.partialCount,
    required this.pendingBalance,
    required this.oldestSaleDate,
  });
}

class _SalesWeeklyCollectionInsights {
  final List<_SalesCollectionAccountRow> openRows;
  final List<_SalesCollectionAccountRow> collectedWeekRows;
  final List<_SalesCollectionAccountRow> overdueEstimatedRows;
  final List<_SalesCollectionAccountRow> pendingInvoiceRows;
  final List<_SalesCollectionAccountRow> partialRows;
  final List<_SalesCollectionAccountRow> focusRows;
  final List<_SalesWeeklyClientRow> clientRows;
  final double totalPendingBalance;
  final double collectedWeekAmount;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _SalesWeeklyCollectionInsights({
    required this.openRows,
    required this.collectedWeekRows,
    required this.overdueEstimatedRows,
    required this.pendingInvoiceRows,
    required this.partialRows,
    required this.focusRows,
    required this.clientRows,
    required this.totalPendingBalance,
    required this.collectedWeekAmount,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
  });
}

_SalesDailyInsights _buildSalesDailyInsights(
  List<_SalesDailyReportRow> rows,
  DateTime generatedAt,
) {
  String describePendingMix({
    required int relationshipCount,
    required int invoiceDocumentCount,
    required int checkDocumentCount,
    required int reviewCount,
  }) {
    final parts = <String>[];
    if (relationshipCount > 0) parts.add('$relationshipCount por relacionar');
    if (invoiceDocumentCount > 0) {
      parts.add('$invoiceDocumentCount pendientes de factura');
    }
    if (checkDocumentCount > 0) {
      parts.add('$checkDocumentCount pendientes de documento de cheque');
    }
    if (reviewCount > 0) parts.add('$reviewCount por revisar');
    return parts.isEmpty ? 'sin pendientes visibles' : parts.join(', ');
  }

  final today = _pdfDateOnly(generatedAt);
  final todayRows = rows
      .where((row) => _pdfDateOnly(row.date).isAtSameMomentAs(today))
      .toList(growable: false);
  final relatedTodayRows = todayRows
      .where((row) => row.isRelated)
      .toList(growable: false);
  final pendingTodayRows =
      todayRows
          .where((row) => row.isPendingOperationalClosure)
          .toList(growable: false)
        ..sort((a, b) {
          final scoreCompare = b
              .focusScoreAt(today)
              .compareTo(a.focusScoreAt(today));
          if (scoreCompare != 0) return scoreCompare;
          final amountCompare = b.pendingSnapshotAmount.compareTo(
            a.pendingSnapshotAmount,
          );
          if (amountCompare != 0) return amountCompare;
          return a.ticket.toLowerCase().compareTo(b.ticket.toLowerCase());
        });
  final backlogPendingRows =
      rows
          .where(
            (row) =>
                row.isPendingOperationalClosure &&
                _pdfDateOnly(row.date).isBefore(today),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          final amountCompare = b.pendingSnapshotAmount.compareTo(
            a.pendingSnapshotAmount,
          );
          if (amountCompare != 0) return amountCompare;
          return a.ticket.toLowerCase().compareTo(b.ticket.toLowerCase());
        });
  final allPendingRows = <_SalesDailyReportRow>[
    ...backlogPendingRows,
    ...pendingTodayRows,
  ];
  final pendingRelationshipCount = allPendingRows
      .where((row) => row.isPendingRelationship)
      .length;
  final pendingInvoiceDocumentCount = allPendingRows
      .where((row) => row.isPendingDocument && row.operationType == 'factura')
      .length;
  final pendingCheckDocumentCount = allPendingRows
      .where((row) => row.isPendingDocument && row.operationType == 'cheque')
      .length;
  final pendingDocumentCount = allPendingRows
      .where((row) => row.isPendingDocument)
      .length;
  final pendingReviewCount = allPendingRows
      .where((row) => row.needsManualReview)
      .length;
  final pendingRelationshipTodayCount = pendingTodayRows
      .where((row) => row.isPendingRelationship)
      .length;
  final pendingInvoiceDocumentTodayCount = pendingTodayRows
      .where((row) => row.isPendingDocument && row.operationType == 'factura')
      .length;
  final pendingCheckDocumentTodayCount = pendingTodayRows
      .where((row) => row.isPendingDocument && row.operationType == 'cheque')
      .length;
  final pendingDocumentTodayCount = pendingTodayRows
      .where((row) => row.isPendingDocument)
      .length;
  final pendingReviewTodayCount = pendingTodayRows
      .where((row) => row.needsManualReview)
      .length;
  final pendingRelationshipBacklogCount =
      pendingRelationshipCount - pendingRelationshipTodayCount;
  final pendingInvoiceDocumentBacklogCount =
      pendingInvoiceDocumentCount - pendingInvoiceDocumentTodayCount;
  final pendingCheckDocumentBacklogCount =
      pendingCheckDocumentCount - pendingCheckDocumentTodayCount;
  final pendingReviewBacklogCount =
      pendingReviewCount - pendingReviewTodayCount;
  final focusRows = [...allPendingRows]
    ..sort((a, b) {
      final scoreCompare = b
          .focusScoreAt(today)
          .compareTo(a.focusScoreAt(today));
      if (scoreCompare != 0) return scoreCompare;
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return b.pendingSnapshotAmount.compareTo(a.pendingSnapshotAmount);
    });

  final clientBuckets = <String, List<_SalesDailyReportRow>>{};
  for (final row in allPendingRows) {
    clientBuckets.putIfAbsent(row.clientName, () => <_SalesDailyReportRow>[]);
    clientBuckets[row.clientName]!.add(row);
  }
  final clientRows =
      clientBuckets.entries
          .map((entry) {
            final items = entry.value;
            final pendingTodayCount = items
                .where((row) => _pdfDateOnly(row.date).isAtSameMomentAs(today))
                .length;
            final backlogCount = items.length - pendingTodayCount;
            final relationshipPendingCount = items
                .where((row) => row.isPendingRelationship)
                .length;
            final documentPendingCount = items
                .where((row) => row.isPendingDocument)
                .length;
            final reviewCount = items
                .where((row) => row.needsManualReview)
                .length;
            final pendingWeight = items.fold<double>(
              0,
              (sum, row) => sum + row.exitWeight,
            );
            final pendingAmount = items.fold<double>(
              0,
              (sum, row) => sum + row.pendingSnapshotAmount,
            );
            DateTime? oldestPendingDate;
            for (final row in items) {
              if (oldestPendingDate == null ||
                  row.date.isBefore(oldestPendingDate)) {
                oldestPendingDate = row.date;
              }
            }
            return _SalesDailyClientRow(
              clientName: entry.key,
              pendingTodayCount: pendingTodayCount,
              backlogCount: backlogCount,
              relationshipPendingCount: relationshipPendingCount,
              documentPendingCount: documentPendingCount,
              reviewCount: reviewCount,
              pendingWeight: pendingWeight,
              pendingAmount: pendingAmount,
              oldestPendingDate: oldestPendingDate,
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final totalCompare = b.totalPendingCount.compareTo(
            a.totalPendingCount,
          );
          if (totalCompare != 0) return totalCompare;
          final amountCompare = b.pendingAmount.compareTo(a.pendingAmount);
          if (amountCompare != 0) return amountCompare;
          return a.clientName.toLowerCase().compareTo(
            b.clientName.toLowerCase(),
          );
        });

  final pendingVisibleWeight = allPendingRows.fold<double>(
    0,
    (sum, row) => sum + row.exitWeight,
  );
  final pendingVisibleAmount = allPendingRows.fold<double>(
    0,
    (sum, row) => sum + row.pendingSnapshotAmount,
  );
  final todaySnapshotAmount = todayRows.fold<double>(
    0,
    (sum, row) => sum + row.snapshotAmount,
  );
  final pendingFacturaCount = allPendingRows
      .where((row) => row.operationType == 'factura')
      .length;
  final pendingChequeCount = allPendingRows.length - pendingFacturaCount;
  final missingRemisionCount = allPendingRows
      .where((row) => row.missingRemision)
      .length;
  final oldestBacklogDate = backlogPendingRows.isEmpty
      ? null
      : backlogPendingRows.first.date;

  final executiveSummary = <String>[];
  if (todayRows.isEmpty && allPendingRows.isEmpty) {
    executiveSummary.add(
      'No hay reportes de venta mayoreo capturados hoy ni pendientes visibles al corte del ${_formatDateTimeShort(generatedAt)}.',
    );
  } else {
    if (todayRows.isNotEmpty) {
      executiveSummary.add(
        'Hoy se capturaron ${todayRows.length} reportes de venta mayoreo por ${_formatQuantity(todayRows.fold<double>(0, (sum, row) => sum + row.exitWeight))} KG y un snapshot visible de ${_formatCurrency(todaySnapshotAmount)}.',
      );
      if (pendingTodayRows.isNotEmpty) {
        executiveSummary.add(
          'Quedaron ${pendingTodayRows.length} pendientes operativos del dia: ${describePendingMix(relationshipCount: pendingRelationshipTodayCount, invoiceDocumentCount: pendingInvoiceDocumentTodayCount, checkDocumentCount: pendingCheckDocumentTodayCount, reviewCount: pendingReviewTodayCount)} por ${_formatCurrency(pendingTodayRows.fold<double>(0, (sum, row) => sum + row.pendingSnapshotAmount))}.',
        );
      } else {
        executiveSummary.add(
          'Todo lo capturado hoy ya quedo relacionado y documentado comercialmente dentro de Ventas.',
        );
      }
      if (relatedTodayRows.isNotEmpty) {
        executiveSummary.add(
          '${relatedTodayRows.length} reporte(s) de hoy ya muestran relacion comercial visible dentro del flujo actual.',
        );
      }
    } else {
      executiveSummary.add(
        'Hoy no se capturaron reportes nuevos, pero si sigue pendiente arrastre comercial visible.',
      );
    }
    if (backlogPendingRows.isNotEmpty) {
      executiveSummary.add(
        'Siguen arrastrados ${backlogPendingRows.length} pendientes previos desde ${_formatLongDateSpanish(oldestBacklogDate!)}: ${describePendingMix(relationshipCount: pendingRelationshipBacklogCount, invoiceDocumentCount: pendingInvoiceDocumentBacklogCount, checkDocumentCount: pendingCheckDocumentBacklogCount, reviewCount: pendingReviewBacklogCount)}.',
      );
    }
    if (clientRows.isNotEmpty) {
      executiveSummary.add(
        'El cliente con mayor pendiente visible es ${_sanitizePdfText(clientRows.first.clientName)} con ${clientRows.first.totalPendingCount} pendiente(s) por ${_formatCurrency(clientRows.first.pendingAmount)}.',
      );
    }
    if (allPendingRows.isNotEmpty) {
      executiveSummary.add(
        'El pendiente visible actual mezcla ${describePendingMix(relationshipCount: pendingRelationshipCount, invoiceDocumentCount: pendingInvoiceDocumentCount, checkDocumentCount: pendingCheckDocumentCount, reviewCount: pendingReviewCount)} en $pendingFacturaCount factura(s) y $pendingChequeCount cheque(s) por ${_formatCurrency(pendingVisibleAmount)}.',
      );
    }
  }

  final alerts = <String>[];
  if (pendingRelationshipTodayCount > 0) {
    alerts.add(
      'Hay $pendingRelationshipTodayCount ventas de hoy que todavia no quedan relacionadas comercialmente dentro del modulo.',
    );
  }
  if (pendingDocumentCount > 0) {
    final documentParts = <String>[];
    if (pendingInvoiceDocumentCount > 0) {
      documentParts.add(
        '$pendingInvoiceDocumentCount venta(s) factura sin factura emitida',
      );
    }
    if (pendingCheckDocumentCount > 0) {
      documentParts.add(
        '$pendingCheckDocumentCount venta(s) cheque sin documento capturado',
      );
    }
    alerts.add(
      'Hay ${documentParts.join(' y ')} dentro de ventas ya relacionadas.',
    );
  }
  if (pendingReviewCount > 0) {
    alerts.add(
      'Hay $pendingReviewCount casos con estatus por revisar y deben aclararse para no contaminar el corte de manana.',
    );
  }
  if (backlogPendingRows.isNotEmpty) {
    alerts.add(
      'Hay arrastre previo abierto desde ${_formatLongDateSpanish(oldestBacklogDate!)} y ya debe revisarse en junta.',
    );
  }
  if (missingRemisionCount > 0) {
    alerts.add(
      '$missingRemisionCount pendientes visibles no traen remision capturada.',
    );
  }
  if (clientRows.isNotEmpty && clientRows.first.totalPendingCount >= 3) {
    alerts.add(
      '${_sanitizePdfText(clientRows.first.clientName)} concentra ${clientRows.first.totalPendingCount} pendientes visibles en este corte.',
    );
  }
  if (pendingVisibleAmount >= 300000) {
    alerts.add(
      'El snapshot pendiente visible ya supera ${_formatCurrency(300000)} y requiere seguimiento ejecutivo inmediato.',
    );
  }

  final closeoutPrompts = <String>[
    'Toda venta por relacionar debe salir de la junta con responsable, siguiente paso y hora objetivo de cierre dentro del dia.',
    if (pendingDocumentCount > 0)
      'Toda venta ya relacionada pero sin factura o sin documento de cheque debe salir con responsable y hora comprometida de documentacion.',
    if (pendingReviewCount > 0)
      'Los casos por revisar deben definirse hoy mismo para no arrastrar ruido al siguiente corte.',
    if (backlogPendingRows.isNotEmpty)
      'El arrastre comercial previo no debe pasar a manana sin explicacion puntual por cliente.',
    if (missingRemisionCount > 0)
      'Las remisiones faltantes deben aclararse hoy mismo porque siguen rompiendo la lectura comercial.',
    'Si una venta ya se resolvio, se corrige en Ventas Mayoreo o Cuentas Mayoreo y se regenera el corte; no se maquilla el reporte.',
  ];

  return _SalesDailyInsights(
    allRows: rows,
    todayRows: todayRows,
    relatedTodayRows: relatedTodayRows,
    pendingTodayRows: pendingTodayRows,
    backlogPendingRows: backlogPendingRows,
    focusRows: focusRows.take(12).toList(growable: false),
    clientRows: clientRows,
    pendingVisibleWeight: pendingVisibleWeight,
    pendingVisibleAmount: pendingVisibleAmount,
    pendingRelationshipCount: pendingRelationshipCount,
    pendingDocumentCount: pendingDocumentCount,
    pendingReviewCount: pendingReviewCount,
    pendingRelationshipTodayCount: pendingRelationshipTodayCount,
    pendingDocumentTodayCount: pendingDocumentTodayCount,
    pendingReviewTodayCount: pendingReviewTodayCount,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

_SalesWeeklyCollectionInsights _buildSalesWeeklyCollectionInsights(
  List<_SalesCollectionAccountRow> rows,
  _SalesWeeklyCut cut,
) {
  final openRows = rows.where((row) => row.isOpen).toList(growable: false)
    ..sort((a, b) {
      final scoreCompare = b.focusScore(cut).compareTo(a.focusScore(cut));
      if (scoreCompare != 0) return scoreCompare;
      final pendingCompare = b.pendingBalance.compareTo(a.pendingBalance);
      if (pendingCompare != 0) return pendingCompare;
      return a.saleDate.compareTo(b.saleDate);
    });
  final overdueEstimatedRows = openRows
      .where((row) => row.hasOverdueEstimatedPayment)
      .toList(growable: false);
  final pendingInvoiceRows = openRows
      .where((row) => row.isPendingInvoice)
      .toList(growable: false);
  final partialRows = openRows
      .where((row) => row.isPartial)
      .toList(growable: false);
  final collectedWeekRows =
      rows.where((row) => row.hadCollectionDuring(cut)).toList(growable: false)
        ..sort((a, b) {
          final left = a.latestPaymentAt ?? a.settlementDate ?? a.saleDate;
          final right = b.latestPaymentAt ?? b.settlementDate ?? b.saleDate;
          return right.compareTo(left);
        });
  final focusRows = openRows.take(10).toList(growable: false);
  final totalPendingBalance = openRows.fold<double>(
    0,
    (sum, row) => sum + row.pendingBalance,
  );
  final collectedWeekAmount = collectedWeekRows.fold<double>(
    0,
    (sum, row) => sum + row.paidThisWeekAmount(cut),
  );

  final clientBuckets = <String, List<_SalesCollectionAccountRow>>{};
  for (final row in openRows) {
    clientBuckets.putIfAbsent(
      row.clientName,
      () => <_SalesCollectionAccountRow>[],
    );
    clientBuckets[row.clientName]!.add(row);
  }
  final clientRows =
      clientBuckets.entries
          .map((entry) {
            final items = entry.value;
            final overdueCount = items
                .where((row) => row.hasOverdueEstimatedPayment)
                .length;
            final pendingInvoiceCount = items
                .where((row) => row.isPendingInvoice)
                .length;
            final partialCount = items.where((row) => row.isPartial).length;
            final pendingBalance = items.fold<double>(
              0,
              (sum, row) => sum + row.pendingBalance,
            );
            DateTime? oldestSaleDate;
            for (final row in items) {
              if (oldestSaleDate == null ||
                  row.saleDate.isBefore(oldestSaleDate)) {
                oldestSaleDate = row.saleDate;
              }
            }
            return _SalesWeeklyClientRow(
              clientName: entry.key,
              openCount: items.length,
              overdueCount: overdueCount,
              pendingInvoiceCount: pendingInvoiceCount,
              partialCount: partialCount,
              pendingBalance: pendingBalance,
              oldestSaleDate: oldestSaleDate,
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final balanceCompare = b.pendingBalance.compareTo(a.pendingBalance);
          if (balanceCompare != 0) return balanceCompare;
          final openCompare = b.openCount.compareTo(a.openCount);
          if (openCompare != 0) return openCompare;
          return a.clientName.toLowerCase().compareTo(
            b.clientName.toLowerCase(),
          );
        });

  final chequeOpenCount = openRows
      .where((row) => row.operationType == 'cheque')
      .length;
  final facturaOpenCount = openRows.length - chequeOpenCount;
  final oldestOpenDate = openRows.isEmpty
      ? null
      : openRows
            .map((row) => row.saleDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);

  final executiveSummary = <String>[];
  if (openRows.isEmpty && collectedWeekRows.isEmpty) {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)} no hay cobranza abierta ni movimiento visible de cobro en la semana operativa actual.',
    );
  } else {
    executiveSummary.add(
      'Al corte del ${_formatDateTimeShort(cut.cutoffAt)}, Ventas mantiene ${openRows.length} cuenta(s) abiertas por ${_formatCurrency(totalPendingBalance)}.',
    );
    if (overdueEstimatedRows.isNotEmpty) {
      executiveSummary.add(
        '${overdueEstimatedRows.length} cuenta(s) ya traen fecha estimada de pago vencida y siguen sin cerrar.',
      );
    } else {
      executiveSummary.add(
        'No hay promesas de pago vencidas visibles dentro de las cuentas abiertas.',
      );
    }
    if (pendingInvoiceRows.isNotEmpty) {
      executiveSummary.add(
        '${pendingInvoiceRows.length} cuenta(s) siguen pendientes de facturar, lo que frena la cobranza formal.',
      );
    }
    executiveSummary.add(
      'La mezcla abierta actual es $facturaOpenCount factura(s) y $chequeOpenCount cheque(s).',
    );
    if (clientRows.isNotEmpty) {
      executiveSummary.add(
        'El cliente con mayor saldo pendiente es ${_sanitizePdfText(clientRows.first.clientName)} con ${_formatCurrency(clientRows.first.pendingBalance)} abiertos.',
      );
    }
    if (collectedWeekRows.isNotEmpty) {
      executiveSummary.add(
        'En la semana operativa actual se movieron cobros visibles por ${_formatCurrency(collectedWeekAmount)}.',
      );
    }
  }

  final alerts = <String>[];
  if (overdueEstimatedRows.isNotEmpty) {
    alerts.add(
      'Hay ${overdueEstimatedRows.length} promesas de pago vencidas que ya requieren llamada, visita o escalacion puntual.',
    );
  }
  if (pendingInvoiceRows.isNotEmpty) {
    alerts.add(
      'Hay ${pendingInvoiceRows.length} cuentas pendientes de facturar; sin ese documento la cobranza sigue colgada.',
    );
  }
  if (partialRows.isNotEmpty) {
    alerts.add(
      'Hay ${partialRows.length} cuentas con pago parcial que deben cerrarse o reprogramarse con claridad.',
    );
  }
  if (clientRows.isNotEmpty && clientRows.first.pendingBalance >= 200000) {
    alerts.add(
      '${_sanitizePdfText(clientRows.first.clientName)} concentra ${_formatCurrency(clientRows.first.pendingBalance)} del saldo abierto actual.',
    );
  }
  if (oldestOpenDate != null &&
      _pdfDateOnly(oldestOpenDate).isBefore(cut.weekStart)) {
    alerts.add(
      'Todavia hay arrastre previo al ${_formatLongDateSpanish(cut.weekStart)} dentro de cobranza abierta.',
    );
  }

  final closeoutPrompts = <String>[
    'Que cliente debe cobrar Ventas esta semana con nombre, responsable y fecha concreta.',
    if (overdueEstimatedRows.isNotEmpty)
      'Las promesas de pago vencidas no deben salir de la junta sin accion puntual del mismo dia.',
    if (pendingInvoiceRows.isNotEmpty)
      'Toda cuenta pendiente de facturar debe aclararse con responsable y hora de emision.',
    if (partialRows.isNotEmpty)
      'Los pagos parciales deben cerrarse con siguiente fecha comprometida o decision comercial clara.',
    'Si un cobro ya entro a bancos, se corrige en la fuente operativa o bancaria y se regenera el corte.',
  ];

  return _SalesWeeklyCollectionInsights(
    openRows: openRows,
    collectedWeekRows: collectedWeekRows,
    overdueEstimatedRows: overdueEstimatedRows,
    pendingInvoiceRows: pendingInvoiceRows,
    partialRows: partialRows,
    focusRows: focusRows,
    clientRows: clientRows,
    totalPendingBalance: totalPendingBalance,
    collectedWeekAmount: collectedWeekAmount,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
  );
}

String _salesCollectionStatusLabel(String statusKey) {
  switch (statusKey) {
    case 'pendientefactura':
      return 'PENDIENTE DE FACTURAR';
    case 'facturadapendientepago':
      return 'FACTURA PENDIENTE DE PAGO';
    case 'pagada':
      return 'PAGADA';
    case 'pagoparcial':
      return 'PAGO PARCIAL';
    case 'cancelada':
      return 'CANCELADA';
    case 'pendientecheque':
      return 'PENDIENTE DE CHEQUE';
    case 'chequerecibido':
      return 'CHEQUE RECIBIDO';
    case 'chequependientecanje':
      return 'CHEQUE PENDIENTE DE CANJE';
    case 'chequecanjeado':
      return 'CHEQUE CANJEADO';
    default:
      return 'POR REVISAR';
  }
}

class _FinanceDailyInsights {
  final FinanzasPaymentCenterOperationalSnapshot snapshot;
  final String decisionHeadline;
  final String decisionNarrative;
  final List<String> decisionSupportLines;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;
  final List<FinanzasPaymentCenterOperationalItem> plannedItems;
  final List<FinanzasPaymentCenterOperationalItem> blockedUrgentItems;
  final List<FinanzasPaymentCenterOperationalItem> riskItems;
  final double tomorrowCommittedAmount;

  const _FinanceDailyInsights({
    required this.snapshot,
    required this.decisionHeadline,
    required this.decisionNarrative,
    required this.decisionSupportLines,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
    required this.plannedItems,
    required this.blockedUrgentItems,
    required this.riskItems,
    required this.tomorrowCommittedAmount,
  });

  FinanzasPaymentCenterBudgetTodaySummary get budgetToday =>
      snapshot.budgetToday;

  FinanzasPaymentCenterBudgetWeekSummary get budgetWeek => snapshot.budgetWeek;
}

_FinanceDailyInsights _buildFinanceDailyInsights(
  FinanzasPaymentCenterOperationalSnapshot snapshot, {
  required DateTime generatedAt,
}) {
  final budgetToday = snapshot.budgetToday;
  final budgetWeek = snapshot.budgetWeek;
  final today = budgetToday.today;
  final tomorrowSummary = budgetWeek.days.length > 1
      ? budgetWeek.days[1]
      : null;
  final plannedItems = snapshot.items
      .where(
        (item) =>
            item.executionDecision !=
                FinanzasPaymentCenterExecutionDecision.esperar &&
            item.executionAmount > 0.009,
      )
      .toList(growable: false);
  final blockedUrgentItems = snapshot.items
      .where((item) {
        final dueOnly = item.dueDate == null
            ? null
            : _pdfDateOnly(item.dueDate!);
        final isUrgentBucket =
            item.bucket == FinanzasPaymentCenterPriorityBucket.obligatorio ||
            item.bucket == FinanzasPaymentCenterPriorityBucket.urgente;
        final isDueNow =
            dueOnly != null &&
            (dueOnly.isAtSameMomentAs(today) || dueOnly.isBefore(today));
        return (isUrgentBucket || isDueNow) && item.executionAmount <= 0.009;
      })
      .toList(growable: false);
  final riskItems = budgetToday.riskItems.toList(growable: false);
  final overdueVisibleCount = snapshot.items.where((item) {
    final dueOnly = item.dueDate == null ? null : _pdfDateOnly(item.dueDate!);
    return dueOnly != null && dueOnly.isBefore(today);
  }).length;
  final accountsWithShortfall = budgetToday.accounts
      .where((account) => account.uncoveredMinimumTodayAmount > 0.009)
      .toList(growable: false);
  final accountsWithPlan = budgetToday.accounts
      .where((account) => account.plannedTodayAmount > 0.009)
      .toList(growable: false);
  final activeReserves = snapshot.reserveSummary.activeCount;
  final sortedWeekDays = [...budgetWeek.days]
    ..sort((a, b) => b.pressureAmount.compareTo(a.pressureAmount));
  final peakWeekDay = sortedWeekDays.isEmpty ? null : sortedWeekDays.first;

  final executiveSummary = <String>[
    'Al corte del ${_formatDateTimeShort(generatedAt)}, Finanzas trae saldo real de ${_formatCurrency(budgetToday.realTotalBalance)} y reservas protegidas por ${_formatCurrency(budgetToday.protectedReserveTotal)}.',
    'La caja realmente libre para decidir hoy queda en ${_formatCurrency(budgetToday.availableBudgetAmount)}.',
  ];
  if (budgetToday.minimumTodayAmount > 0.009) {
    executiveSummary.add(
      'Hoy el minimo visible comprometido suma ${_formatCurrency(budgetToday.minimumTodayAmount)} y el plan aterrizado logra mover ${_formatCurrency(budgetToday.plannedTodayAmount)}.',
    );
  } else {
    executiveSummary.add(
      'Hoy no aparece una salida obligatoria inmediata dentro del corte visible.',
    );
  }
  if (budgetToday.uncoveredMinimumTodayAmount > 0.009) {
    executiveSummary.add(
      'Queda descubierto ${_formatCurrency(budgetToday.uncoveredMinimumTodayAmount)} del minimo visible de hoy; eso ya requiere reacomodo a manana o revision directa.',
    );
  } else if (budgetToday.plannedTodayAmount > 0.009) {
    executiveSummary.add(
      'Despues del plan del dia todavia quedan ${_formatCurrency(budgetToday.freeMarginAfterPlanned)} libres para cerrar y entrar a manana.',
    );
  }
  if (tomorrowSummary != null && tomorrowSummary.committedAmount > 0.009) {
    executiveSummary.add(
      'Manana ${_formatLongDateSpanish(tomorrowSummary.date)} ya aparece comprometido ${_formatCurrency(tomorrowSummary.committedAmount)}.',
    );
  }
  if (peakWeekDay != null) {
    final day = peakWeekDay;
    if (day.pressureAmount > 0.009) {
      executiveSummary.add(
        'El dia con mayor presion visible de la semana es ${_formatLongDateSpanish(day.date)} con ${_formatCurrency(day.pressureAmount)}.',
      );
    }
  }

  final alerts = <String>[];
  if (budgetToday.uncoveredMinimumTodayAmount > 0.009) {
    alerts.add(
      'La caja protegida de hoy no alcanza para cubrir ${_formatCurrency(budgetToday.uncoveredMinimumTodayAmount)} del minimo visible.',
    );
  }
  if (blockedUrgentItems.isNotEmpty) {
    alerts.add(
      'Hay ${blockedUrgentItems.length} urgencias visibles que no aterrizan hoy dentro del plan real.',
    );
  }
  if (riskItems.isNotEmpty) {
    alerts.add(
      'Hay ${riskItems.length} movimientos marcados como riesgo a revisar antes de decidir.',
    );
  }
  if (overdueVisibleCount > 0) {
    alerts.add(
      'Siguen visibles $overdueVisibleCount movimientos con vencimiento previo al ${_formatLongDateSpanish(today)}.',
    );
  }
  if (activeReserves > 0) {
    alerts.add(
      'Hay $activeReserves reservas activas protegiendo flujo dentro de este corte.',
    );
  }
  if (accountsWithShortfall.isNotEmpty) {
    alerts.add(
      '${accountsWithShortfall.length} cuentas quedan con minimo visible descubierto aunque ya se aplico la proteccion de caja.',
    );
  }

  final decisionHeadline = _buildFinanceDecisionHeadline(budgetToday);
  final decisionNarrative = _buildFinanceDecisionNarrative(
    budgetToday,
    tomorrowSummary,
  );
  final decisionSupportLines = <String>[
    'Se mueven hoy ${plannedItems.length} movimientos aterrizados en el plan real.',
    if (activeReserves > 0)
      '$activeReserves reservas activas protegen ${_formatCurrency(budgetToday.protectedReserveTotal)} antes de abrir caja.',
    if (accountsWithPlan.isNotEmpty)
      '${accountsWithPlan.length} cuentas bancarias si traen salida aterrizada hoy.',
    if (blockedUrgentItems.isNotEmpty)
      '${blockedUrgentItems.length} urgencias visibles quedan en espera o revisadas por limite de caja.',
    if (budgetToday.riskReviewAmount > 0.009)
      'Monto en riesgo a revisar hoy: ${_formatCurrency(budgetToday.riskReviewAmount)}.',
  ];

  final closeoutPrompts = <String>[
    'Confirmar que movimientos del bloque "Que si se paga hoy" si van a salir hoy y por que cuenta.',
    if (activeReserves > 0)
      'Validar si alguna reserva protegida ya no aplica o si sigue intocable para no maquillar la caja libre.',
    if (blockedUrgentItems.isNotEmpty)
      'Definir responsable y siguiente paso para las urgencias visibles que no caben hoy sin maquillar la lectura.',
    if (tomorrowSummary != null && tomorrowSummary.committedAmount > 0.009)
      'Asegurar desde hoy el espacio de caja para manana ${_formatLongDateSpanish(tomorrowSummary.date)} con ${_formatCurrency(tomorrowSummary.committedAmount)} comprometidos.',
    if (budgetWeek.weekPressureAmount > 0.009)
      'Revisar si la semana visible por ${_formatCurrency(budgetWeek.weekPressureAmount)} cabe con la caja actual o si ya requiere priorizacion adicional.',
    'Si un dato no hace sentido, se corrige en su modulo fuente y se regenera el corte; no se ajusta manualmente aqui.',
  ];

  return _FinanceDailyInsights(
    snapshot: snapshot,
    decisionHeadline: decisionHeadline,
    decisionNarrative: decisionNarrative,
    decisionSupportLines: decisionSupportLines,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
    plannedItems: plannedItems,
    blockedUrgentItems: blockedUrgentItems,
    riskItems: riskItems,
    tomorrowCommittedAmount: tomorrowSummary?.committedAmount ?? 0,
  );
}

String _buildFinanceDecisionHeadline(
  FinanzasPaymentCenterBudgetTodaySummary summary,
) {
  if (summary.plannedTodayAmount > 0.009 &&
      summary.uncoveredMinimumTodayAmount <= 0.009) {
    return 'Hoy ya queda claro que si se puede mover.';
  }
  if (summary.plannedTodayAmount > 0.009) {
    return 'Hoy ya hay un plan parcial aterrizado.';
  }
  if (summary.minimumTodayAmount > 0.009) {
    return 'Hoy hay presion visible, pero la caja no alcanza para resolverla.';
  }
  return 'Hoy no hay presion inmediata con salida sugerida.';
}

String _buildFinanceDecisionNarrative(
  FinanzasPaymentCenterBudgetTodaySummary summary,
  FinanzasPaymentCenterBudgetWeekDaySummary? tomorrowSummary,
) {
  final tomorrowLine = tomorrowSummary == null
      ? ''
      : ' Manana ${_formatLongDateSpanish(tomorrowSummary.date)} ya aparece comprometido ${_formatCurrency(tomorrowSummary.committedAmount)}.';
  if (summary.plannedTodayAmount > 0.009 &&
      summary.uncoveredMinimumTodayAmount > 0.009) {
    return 'Hoy se tiene que pagar ${_formatCurrency(summary.minimumTodayAmount)} y si cabe mover ${_formatCurrency(summary.plannedTodayAmount)}. El resto minimo que no alcanzo hoy es ${_formatCurrency(summary.uncoveredMinimumTodayAmount)} y se va a manana o revision.$tomorrowLine';
  }
  if (summary.plannedTodayAmount > 0.009) {
    return 'Hoy se tiene que pagar ${_formatCurrency(summary.minimumTodayAmount)} y si cabe mover ${_formatCurrency(summary.plannedTodayAmount)}. Despues de eso quedan ${_formatCurrency(summary.freeMarginAfterPlanned)} libres.$tomorrowLine';
  }
  if (summary.minimumTodayAmount > 0.009) {
    return 'Hoy se tiene que pagar ${_formatCurrency(summary.minimumTodayAmount)}, pero con la caja protegida no alcanza para aterrizar un plan real.$tomorrowLine';
  }
  return 'Hoy no aparece una salida obligatoria inmediata. La caja queda libre para revisar manana y el resto de la semana visible sin perder el foco del dia.';
}

String _buildFinanceAccountLabel(String company, String branch) {
  final companyClean = company.trim();
  final branchClean = branch.trim();
  if (companyClean.isEmpty && branchClean.isEmpty) return 'Sin cuenta';
  if (branchClean.isEmpty) return companyClean;
  if (companyClean.isEmpty) return branchClean;
  return '$companyClean · $branchClean';
}

String _buildReserveWindowLabel(FinanzasPaymentCenterReserveRecord reserve) {
  final start = _formatOptionalDate(reserve.effectiveDate);
  if (reserve.endDate == null) return 'Desde $start';
  return '$start a ${_formatOptionalDate(reserve.endDate)}';
}

class _FinanceWeeklyCut {
  final DateTime weekStart;
  final DateTime friday;
  final DateTime cutoffAt;

  const _FinanceWeeklyCut({
    required this.weekStart,
    required this.friday,
    required this.cutoffAt,
  });

  DateTime get extendedEnd => friday.add(const Duration(days: 2));

  String get fridayWindowLabel =>
      '${_formatLongDateSpanish(weekStart)} al ${_formatLongDateSpanish(friday)}';

  String get extendedWindowLabel =>
      '${_formatLongDateSpanish(weekStart)} al ${_formatLongDateSpanish(extendedEnd)}';
}

class _FinanceWeeklyOverdueInvoiceRow {
  final String providerName;
  final String folio;
  final DateTime dueDate;
  final double balanceAmount;
  final String manualPriority;
  final String status;

  const _FinanceWeeklyOverdueInvoiceRow({
    required this.providerName,
    required this.folio,
    required this.dueDate,
    required this.balanceAmount,
    required this.manualPriority,
    required this.status,
  });

  int daysOverdueAt(DateTime cutoffAt) =>
      _pdfDateOnly(cutoffAt).difference(_pdfDateOnly(dueDate)).inDays;

  String get priorityLabel {
    switch (manualPriority.trim().toUpperCase()) {
      case 'CRITICA':
        return 'Critica';
      case 'ALTA':
        return 'Alta';
      default:
        return 'Normal';
    }
  }

  String get statusLabel => finSupplierInvoiceStatusLabel(status);
}

class _FinanceWeeklyAgreementRow {
  final String providerName;
  final String status;
  final DateTime? nextDueDate;
  final double remainingAmount;
  final double installmentAmount;
  final String agreementType;
  final String frequency;

  const _FinanceWeeklyAgreementRow({
    required this.providerName,
    required this.status,
    required this.nextDueDate,
    required this.remainingAmount,
    required this.installmentAmount,
    required this.agreementType,
    required this.frequency,
  });

  String get statusLabel => finSupplierAgreementStatusLabel(status);

  String get agreementTypeLabel => finSupplierAgreementTypeLabel(agreementType);

  String get frequencyLabel => finSupplierAgreementFrequencyLabel(frequency);
}

class _FinanceWeeklyBankFlowRow {
  final String accountKey;
  final String company;
  final String branch;
  final double credits;
  final double debits;
  final int movementCount;

  const _FinanceWeeklyBankFlowRow({
    required this.accountKey,
    required this.company,
    required this.branch,
    required this.credits,
    required this.debits,
    required this.movementCount,
  });

  double get netAmount => credits - debits;

  String get accountLabel => _buildFinanceAccountLabel(company, branch);
}

enum _FinanceWeeklyPlacementBand {
  committed,
  suggested,
  outsideWindow,
  riskReview,
}

class _FinanceWeeklyInsights {
  final _FinanceWeeklyCut cut;
  final FinanzasPaymentCenterOperationalSnapshot snapshot;
  final FinanzasPaymentCenterBudgetWeekSummary budgetWeek;
  final FinanzasDueAlertsSummary dueAlerts;
  final double openClientCollections;
  final double fridayCommittedAmount;
  final double fridaySuggestedAmount;
  final double observedWeekCredits;
  final double observedWeekDebits;
  final List<_FinanceWeeklyOverdueInvoiceRow> overdueInvoiceRows;
  final List<_FinanceWeeklyAgreementRow> agreementRows;
  final List<_FinanceWeeklyBankFlowRow> bankFlowRows;
  final String decisionHeadline;
  final String decisionNarrative;
  final List<String> decisionSupportLines;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;
  final List<FinanzasPaymentCenterBudgetWeekProviderSummary> providerRows;
  final List<FinanzasPaymentCenterBudgetWeekProviderSummary>
  outsideWindowProviders;
  final List<FinanzasPaymentCenterOperationalItem> committedItems;
  final List<FinanzasPaymentCenterOperationalItem> suggestedItems;
  final List<FinanzasPaymentCenterOperationalItem> riskItems;

  const _FinanceWeeklyInsights({
    required this.cut,
    required this.snapshot,
    required this.budgetWeek,
    required this.dueAlerts,
    required this.openClientCollections,
    required this.fridayCommittedAmount,
    required this.fridaySuggestedAmount,
    required this.observedWeekCredits,
    required this.observedWeekDebits,
    required this.overdueInvoiceRows,
    required this.agreementRows,
    required this.bankFlowRows,
    required this.decisionHeadline,
    required this.decisionNarrative,
    required this.decisionSupportLines,
    required this.executiveSummary,
    required this.alerts,
    required this.closeoutPrompts,
    required this.providerRows,
    required this.outsideWindowProviders,
    required this.committedItems,
    required this.suggestedItems,
    required this.riskItems,
  });

  FinanzasPaymentCenterBudgetTodaySummary get budgetToday =>
      snapshot.budgetToday;

  double get fridayPressureAmount =>
      fridayCommittedAmount + fridaySuggestedAmount;

  double get fridayMarginAfterCommitted =>
      budgetWeek.availableBudgetAmount - fridayCommittedAmount;

  double get fridayMarginAfterPressure =>
      budgetWeek.availableBudgetAmount - fridayPressureAmount;

  double get observedWeekNet => observedWeekCredits - observedWeekDebits;

  double get overdueVisibleAmount =>
      overdueInvoiceRows.fold<double>(0, (sum, row) => sum + row.balanceAmount);

  int get delayedAgreementCount =>
      agreementRows.where((row) => row.status == 'ATRASADO').length;

  double get delayedAgreementAmount => agreementRows
      .where((row) => row.status == 'ATRASADO')
      .fold<double>(0, (sum, row) => sum + row.remainingAmount);
}

_FinanceWeeklyInsights _buildFinanceWeeklyInsights(
  FinanzasPaymentCenterOperationalSnapshot snapshot, {
  required FinanzasPaymentCenterSourceSnapshot sourceSnapshot,
  required List<FinanzasClientPaymentAccountRecord> openClientAccounts,
  required FinanzasDueAlertsSummary dueAlerts,
  required DateTime generatedAt,
}) {
  final cut = _resolveFinanceWeeklyCut(generatedAt);
  final budgetWeek = buildFinanzasPaymentCenterBudgetWeekSummary(
    items: snapshot.items,
    realAccountBalances: snapshot.realAccountBalances,
    reserveSummary: snapshot.reserveSummary,
    startDate: cut.weekStart,
  );
  final startDate = cut.weekStart;
  final endDate = cut.friday;
  final providerRows =
      budgetWeek.accounts
          .expand((account) => account.providers)
          .where(
            (provider) =>
                provider.committedWeekAmount > 0.009 ||
                provider.suggestedAdditionalAmount > 0.009 ||
                provider.riskReviewAmount > 0.009 ||
                provider.outsideWindowAmount > 0.009,
          )
          .toList(growable: false)
        ..sort(_compareFinanceBudgetWeekProviderSummaries);
  final committedItems =
      snapshot.items
          .where(
            (item) =>
                _resolveFinanceWeeklyPlacement(item, startDate, endDate) ==
                _FinanceWeeklyPlacementBand.committed,
          )
          .toList(growable: false)
        ..sort(_compareFinanceWeeklyItems);
  final suggestedItems =
      snapshot.items
          .where(
            (item) =>
                _resolveFinanceWeeklyPlacement(item, startDate, endDate) ==
                _FinanceWeeklyPlacementBand.suggested,
          )
          .toList(growable: false)
        ..sort(_compareFinanceWeeklyItems);
  final riskItems =
      snapshot.items
          .where(
            (item) =>
                _resolveFinanceWeeklyPlacement(item, startDate, endDate) ==
                _FinanceWeeklyPlacementBand.riskReview,
          )
          .toList(growable: false)
        ..sort(_compareFinanceWeeklyItems);
  final outsideWindowProviders =
      providerRows
          .where((provider) => provider.outsideWindowAmount > 0.009)
          .toList(growable: false)
        ..sort((a, b) {
          final amountCompare = b.outsideWindowAmount.compareTo(
            a.outsideWindowAmount,
          );
          if (amountCompare != 0) return amountCompare;
          return _compareFinanceBudgetWeekProviderSummaries(a, b);
        });
  final overdueCommittedCount = committedItems.where((item) {
    final dueDate = item.dueDate == null ? null : _pdfDateOnly(item.dueDate!);
    return dueDate != null && dueDate.isBefore(startDate);
  }).length;
  final accountsShortOnCommitted = budgetWeek.accounts
      .where((account) => account.marginAfterCommitted < -0.009)
      .toList(growable: false);
  final accountsShortOnPressure = budgetWeek.accounts
      .where((account) => account.marginAfterWeekPressure < -0.009)
      .toList(growable: false);
  final fridayDays = budgetWeek.days
      .where((day) => !_pdfDateOnly(day.date).isAfter(cut.friday))
      .toList(growable: false);
  final fridayCommittedAmount = fridayDays.fold<double>(
    0,
    (sum, day) => sum + day.committedAmount,
  );
  final fridaySuggestedAmount = fridayDays.fold<double>(
    0,
    (sum, day) => sum + day.suggestedAdditionalAmount,
  );
  final sortedDays = [...fridayDays]
    ..sort((a, b) => b.pressureAmount.compareTo(a.pressureAmount));
  final peakDay = sortedDays.isEmpty ? null : sortedDays.first;
  final topAccount = budgetWeek.accounts.isEmpty
      ? null
      : budgetWeek.accounts.first;
  final topProvider = providerRows.isEmpty ? null : providerRows.first;
  final overdueInvoiceRows = _buildFinanceWeeklyOverdueInvoiceRows(
    invoices: sourceSnapshot.invoices,
    bankMovements: sourceSnapshot.bankMovements,
    cutoffAt: cut.cutoffAt,
  );
  final agreementRows = _buildFinanceWeeklyAgreementRows(
    agreements: sourceSnapshot.agreements,
    friday: cut.friday,
  );
  final bankFlowRows = _buildFinanceWeeklyBankFlowRows(
    movements: sourceSnapshot.bankMovements,
    weekStart: cut.weekStart,
    cutoffAt: cut.cutoffAt,
  );
  final observedWeekCredits = bankFlowRows.fold<double>(
    0,
    (sum, row) => sum + row.credits,
  );
  final observedWeekDebits = bankFlowRows.fold<double>(
    0,
    (sum, row) => sum + row.debits,
  );
  final openClientCollections = openClientAccounts.fold<double>(
    0,
    (sum, row) => sum + row.pendingBalance,
  );
  final delayedAgreementCount = agreementRows
      .where((row) => row.status == 'ATRASADO')
      .length;
  final delayedAgreementAmount = agreementRows
      .where((row) => row.status == 'ATRASADO')
      .fold<double>(0, (sum, row) => sum + row.remainingAmount);
  final overdueVisibleAmount = overdueInvoiceRows.fold<double>(
    0,
    (sum, row) => sum + row.balanceAmount,
  );
  final fridayPressureAmount = fridayCommittedAmount + fridaySuggestedAmount;
  final fridayMarginAfterCommitted =
      budgetWeek.availableBudgetAmount - fridayCommittedAmount;
  final fridayMarginAfterPressure =
      budgetWeek.availableBudgetAmount - fridayPressureAmount;
  final observedWeekNet = observedWeekCredits - observedWeekDebits;

  final executiveSummary = <String>[
    'Al corte del ${_formatDateTimeShort(cut.cutoffAt)}, Finanzas trae saldo real de ${_formatCurrency(budgetWeek.realTotalBalance)} y reservas protegidas por ${_formatCurrency(budgetWeek.protectedReserveTotal)}.',
    'La junta del viernes cubre ${cut.fridayWindowLabel} y deja caja protegida visible por ${_formatCurrency(budgetWeek.availableBudgetAmount)}.',
  ];
  if (fridayCommittedAmount > 0.009) {
    executiveSummary.add(
      'Dentro de esa ventana ya aparecen ${committedItems.length} movimientos comprometidos por ${_formatCurrency(fridayCommittedAmount)}.',
    );
  } else {
    executiveSummary.add(
      'Dentro de la ventana de viernes aun no aparece compromiso con fecha aterrizada.',
    );
  }
  if (fridayCommittedAmount > budgetWeek.availableBudgetAmount) {
    executiveSummary.add(
      'Solo con lo comprometido al viernes ya faltan ${_formatCurrency((fridayCommittedAmount - budgetWeek.availableBudgetAmount).abs())}.',
    );
  } else {
    executiveSummary.add(
      'Solo con lo comprometido al viernes todavia quedan ${_formatCurrency(fridayMarginAfterCommitted)} libres.',
    );
  }
  if (fridaySuggestedAmount > 0.009) {
    if (fridayPressureAmount > budgetWeek.availableBudgetAmount) {
      executiveSummary.add(
        'Si tambien se intenta absorber la presion adicional al viernes, faltan ${_formatCurrency((fridayPressureAmount - budgetWeek.availableBudgetAmount).abs())}.',
      );
    } else {
      executiveSummary.add(
        'Aun considerando la presion adicional al viernes, la ventana cerraria con ${_formatCurrency(fridayMarginAfterPressure)} libres.',
      );
    }
  }
  if (peakDay != null && peakDay.pressureAmount > 0.009) {
    executiveSummary.add(
      'El dia con mayor presion para la junta es ${_formatLongDateSpanish(peakDay.date)} con ${_formatCurrency(peakDay.pressureAmount)}.',
    );
  }
  if (overdueInvoiceRows.isNotEmpty) {
    executiveSummary.add(
      'Siguen abiertas ${overdueInvoiceRows.length} facturas vencidas por ${_formatCurrency(overdueVisibleAmount)} al ${_formatDateTimeShort(cut.cutoffAt)}.',
    );
  }
  if (delayedAgreementCount > 0) {
    executiveSummary.add(
      'Hay $delayedAgreementCount convenios atrasados con ${_formatCurrency(delayedAgreementAmount)} todavia expuestos.',
    );
  }
  if (observedWeekCredits > 0.009 || observedWeekDebits > 0.009) {
    executiveSummary.add(
      'Del ${_formatLongDateSpanish(cut.weekStart)} al ${_formatLongDateSpanish(_pdfDateOnly(cut.cutoffAt))} el flujo observado trae ${_formatCurrency(observedWeekNet)} netos.',
    );
  }
  if (openClientCollections > 0.009) {
    executiveSummary.add(
      'La cobranza abierta suma ${_formatCurrency(openClientCollections)}, pero no incrementa presupuesto hasta entrar a banco.',
    );
  }
  if (topProvider != null) {
    executiveSummary.add(
      'En horizonte extendido al ${_formatLongDateSpanish(budgetWeek.endDate)}, el proveedor con mayor presion visible es ${_sanitizePdfText(topProvider.providerName)} con ${_formatCurrency(topProvider.weekPressureAmount)}.',
    );
  }
  if (topAccount != null && topAccount.weekPressureAmount > 0.009) {
    executiveSummary.add(
      'La cuenta mas presionada en el horizonte extendido es ${_buildFinanceAccountLabel(topAccount.targetCompany, topAccount.targetBranch)} con ${_formatCurrency(topAccount.weekPressureAmount)} visibles.',
    );
  }
  if (budgetWeek.riskReviewAmount > 0.009 ||
      budgetWeek.outsideWindowAmount > 0.009) {
    executiveSummary.add(
      'Ademas quedan ${_formatCurrency(budgetWeek.riskReviewAmount)} en riesgo a revisar y ${_formatCurrency(budgetWeek.outsideWindowAmount)} abiertos fuera del viernes.',
    );
  }

  final alerts = <String>[];
  if (fridayCommittedAmount > budgetWeek.availableBudgetAmount) {
    alerts.add(
      'Ni siquiera el compromiso visible al viernes cabe con la caja protegida actual; faltan ${_formatCurrency((fridayCommittedAmount - budgetWeek.availableBudgetAmount).abs())}.',
    );
  } else if (fridayPressureAmount > budgetWeek.availableBudgetAmount) {
    alerts.add(
      'La base al viernes si cabe, pero al sumar la presion adicional falta ${_formatCurrency((fridayPressureAmount - budgetWeek.availableBudgetAmount).abs())}.',
    );
  }
  if (overdueCommittedCount > 0) {
    alerts.add(
      'Hay $overdueCommittedCount movimientos ya vencidos que se arrastran al primer dia visible de la semana.',
    );
  }
  if (dueAlerts.overdueCount > 0 || dueAlerts.dueTodayCount > 0) {
    alerts.add(
      'Las alertas de vencimiento ya traen ${dueAlerts.overdueCount} atrasadas y ${dueAlerts.dueTodayCount} que vencen hoy.',
    );
  }
  if (overdueInvoiceRows.isNotEmpty) {
    alerts.add(
      'Siguen abiertas ${overdueInvoiceRows.length} facturas vencidas por ${_formatCurrency(overdueVisibleAmount)}.',
    );
  }
  if (delayedAgreementCount > 0) {
    alerts.add(
      'Hay $delayedAgreementCount convenios atrasados con ${_formatCurrency(delayedAgreementAmount)} por negociar o normalizar.',
    );
  }
  if (riskItems.isNotEmpty) {
    alerts.add(
      'Hay ${riskItems.length} movimientos sin criterio suficiente para presupuestarlos bien todavia.',
    );
  }
  if (outsideWindowProviders.isNotEmpty) {
    alerts.add(
      '${outsideWindowProviders.length} proveedores todavia concentran ${_formatCurrency(budgetWeek.outsideWindowAmount)} fuera de la junta del viernes.',
    );
  }
  if (accountsShortOnCommitted.isNotEmpty) {
    alerts.add(
      '${accountsShortOnCommitted.length} cuentas del horizonte extendido ya quedan en descubierto solo con lo comprometido visible.',
    );
  }
  if (accountsShortOnPressure.isNotEmpty) {
    alerts.add(
      '${accountsShortOnPressure.length} cuentas del horizonte extendido no absorben la presion total aunque se descuente la caja protegida.',
    );
  }
  if (observedWeekNet < -0.009) {
    alerts.add(
      'El flujo observado de la semana viene negativo por ${_formatCurrency(observedWeekNet.abs())}.',
    );
  }
  if (snapshot.reserveSummary.activeCount > 0) {
    alerts.add(
      'Hay ${snapshot.reserveSummary.activeCount} reservas activas protegiendo ${_formatCurrency(budgetWeek.protectedReserveTotal)} antes de abrir semana.',
    );
  }

  final decisionHeadline = _buildFinanceWeeklyDecisionHeadline(
    availableBudgetAmount: budgetWeek.availableBudgetAmount,
    fridayCommittedAmount: fridayCommittedAmount,
    fridayPressureAmount: fridayPressureAmount,
  );
  final decisionNarrative = _buildFinanceWeeklyDecisionNarrative(
    cut: cut,
    availableBudgetAmount: budgetWeek.availableBudgetAmount,
    fridayCommittedAmount: fridayCommittedAmount,
    fridayPressureAmount: fridayPressureAmount,
    peakDay: peakDay,
    overdueVisibleAmount: overdueVisibleAmount,
    delayedAgreementCount: delayedAgreementCount,
  );
  final decisionSupportLines = <String>[
    'La junta del viernes trae ${committedItems.length} movimientos comprometidos y ${suggestedItems.length} movimientos de presion adicional.',
    'Cobranza abierta hoy: ${_formatCurrency(openClientCollections)}.',
    if (overdueInvoiceRows.isNotEmpty)
      '${overdueInvoiceRows.length} facturas vencidas siguen abiertas por ${_formatCurrency(overdueVisibleAmount)}.',
    if (delayedAgreementCount > 0)
      '$delayedAgreementCount convenios atrasados mantienen ${_formatCurrency(delayedAgreementAmount)} en seguimiento.',
    if (snapshot.reserveSummary.activeCount > 0)
      '${snapshot.reserveSummary.activeCount} reservas activas siguen apartando ${_formatCurrency(budgetWeek.protectedReserveTotal)} del flujo.',
    if (riskItems.isNotEmpty)
      '${riskItems.length} movimientos siguen en riesgo a revisar antes de presupuestarlos dentro de la semana.',
    if (outsideWindowProviders.isNotEmpty)
      '${outsideWindowProviders.length} proveedores mantienen ${_formatCurrency(budgetWeek.outsideWindowAmount)} abiertos fuera de la ventana de viernes.',
    if (topProvider != null)
      'La mayor presion extendida hoy se concentra en ${_sanitizePdfText(topProvider.providerName)}.',
  ];

  final closeoutPrompts = <String>[
    'Confirmar que los movimientos del bloque "Compromisos visibles por movimiento" si corresponden a la junta del viernes ${cut.fridayWindowLabel}.',
    if (fridayPressureAmount > budgetWeek.availableBudgetAmount)
      'Definir explicitamente que se recorre, que se negocia o que se protege para no prometer un viernes que la caja no soporta.',
    if (overdueInvoiceRows.isNotEmpty)
      'Toda factura vencida debe salir de la junta con plan de pago, convenio o motivo real de espera.',
    if (delayedAgreementCount > 0)
      'Los convenios atrasados deben salir con responsable, siguiente contacto y fecha concreta de regularizacion.',
    if (riskItems.isNotEmpty)
      'Los movimientos sin criterio o fecha visible deben salir de la junta con responsable y modulo fuente para corregirse.',
    if (outsideWindowProviders.isNotEmpty)
      'El arrastre fuera del viernes no debe perderse: revisar si alguno ya debe entrar desde ahora en convenio o prioridad real.',
    if (snapshot.reserveSummary.activeCount > 0)
      'Validar que las reservas protegidas sigan vigentes antes de liberar caja en la junta.',
    if (openClientCollections > 0.009)
      'No contar cobranza abierta como caja disponible hasta verla reflejada en movimientos bancarios reales.',
    'Si un dato no hace sentido, se corrige en su modulo fuente y se regenera el corte; no se ajusta manualmente aqui.',
  ];

  return _FinanceWeeklyInsights(
    cut: cut,
    snapshot: snapshot,
    budgetWeek: budgetWeek,
    dueAlerts: dueAlerts,
    openClientCollections: openClientCollections,
    fridayCommittedAmount: fridayCommittedAmount,
    fridaySuggestedAmount: fridaySuggestedAmount,
    observedWeekCredits: observedWeekCredits,
    observedWeekDebits: observedWeekDebits,
    overdueInvoiceRows: overdueInvoiceRows,
    agreementRows: agreementRows,
    bankFlowRows: bankFlowRows,
    decisionHeadline: decisionHeadline,
    decisionNarrative: decisionNarrative,
    decisionSupportLines: decisionSupportLines,
    executiveSummary: executiveSummary,
    alerts: alerts,
    closeoutPrompts: closeoutPrompts,
    providerRows: providerRows,
    outsideWindowProviders: outsideWindowProviders,
    committedItems: committedItems,
    suggestedItems: suggestedItems,
    riskItems: riskItems,
  );
}

_FinanceWeeklyCut _resolveFinanceWeeklyCut(DateTime generatedAt) {
  final friday = _nextOrSameFriday(generatedAt);
  final weekStart = friday.subtract(const Duration(days: 4));
  final fridayEnd = DateTime(
    friday.year,
    friday.month,
    friday.day,
    23,
    59,
    59,
    999,
  );
  final cutoffAt = generatedAt.isBefore(fridayEnd) ? generatedAt : fridayEnd;
  return _FinanceWeeklyCut(
    weekStart: weekStart,
    friday: friday,
    cutoffAt: cutoffAt,
  );
}

List<_FinanceWeeklyOverdueInvoiceRow> _buildFinanceWeeklyOverdueInvoiceRows({
  required List<FinanzasSupplierInvoiceRecord> invoices,
  required List<FinanzasBankMovementRecord> bankMovements,
  required DateTime cutoffAt,
}) {
  final appliedByInvoiceId = <String, double>{};
  for (final movement in bankMovements) {
    final invoiceId = (movement.linkedSupplierInvoiceId ?? '').trim();
    if (invoiceId.isEmpty) continue;
    final applied = movement.effectiveSupplierAppliedAmount
        .clamp(0, double.infinity)
        .toDouble();
    if (applied <= 0.009) continue;
    appliedByInvoiceId.update(
      invoiceId,
      (value) => value + applied,
      ifAbsent: () => applied,
    );
  }
  final today = _pdfDateOnly(cutoffAt);
  final rows = <_FinanceWeeklyOverdueInvoiceRow>[];
  for (final invoice in invoices) {
    final effectiveBalance = _resolveFinanceEffectiveInvoiceBalance(
      invoice,
      appliedByInvoiceId: appliedByInvoiceId,
    );
    if (effectiveBalance <= 0.009) continue;
    final dueDate = invoice.dueDate;
    if (dueDate == null) continue;
    final dueOnly = _pdfDateOnly(dueDate);
    if (!dueOnly.isBefore(today)) continue;
    rows.add(
      _FinanceWeeklyOverdueInvoiceRow(
        providerName: invoice.providerNameSnapshot.trim().isEmpty
            ? 'Sin proveedor'
            : invoice.providerNameSnapshot.trim(),
        folio: invoice.folio.trim().isEmpty
            ? 'Sin folio'
            : invoice.folio.trim(),
        dueDate: dueOnly,
        balanceAmount: effectiveBalance,
        manualPriority: invoice.manualPriority,
        status: invoice.status,
      ),
    );
  }
  rows.sort((a, b) {
    final dueCompare = a.dueDate.compareTo(b.dueDate);
    if (dueCompare != 0) return dueCompare;
    final amountCompare = b.balanceAmount.compareTo(a.balanceAmount);
    if (amountCompare != 0) return amountCompare;
    return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
  });
  return rows;
}

double _resolveFinanceEffectiveInvoiceBalance(
  FinanzasSupplierInvoiceRecord invoice, {
  required Map<String, double> appliedByInvoiceId,
}) {
  final linkedPaid = appliedByInvoiceId[invoice.id];
  if (linkedPaid == null) {
    return invoice.balanceAmount.clamp(0.0, invoice.totalAmount).toDouble();
  }
  return (invoice.totalAmount - linkedPaid)
      .clamp(0.0, invoice.totalAmount)
      .toDouble();
}

List<_FinanceWeeklyAgreementRow> _buildFinanceWeeklyAgreementRows({
  required List<FinanzasSupplierAgreementRecord> agreements,
  required DateTime friday,
}) {
  final fridayOnly = _pdfDateOnly(friday);
  final rows = agreements
      .where(
        (row) =>
            row.status != 'CANCELADO' &&
            row.remainingAmount > 0.009 &&
            (row.status == 'ATRASADO' ||
                row.nextDueDate == null ||
                !_pdfDateOnly(row.nextDueDate!).isAfter(fridayOnly)),
      )
      .map(
        (row) => _FinanceWeeklyAgreementRow(
          providerName: row.providerNameSnapshot.trim().isEmpty
              ? 'Convenio proveedor'
              : row.providerNameSnapshot.trim(),
          status: row.status,
          nextDueDate: row.nextDueDate == null
              ? null
              : _pdfDateOnly(row.nextDueDate!),
          remainingAmount: row.remainingAmount,
          installmentAmount: row.installmentAmount,
          agreementType: row.agreementType,
          frequency: row.frequency,
        ),
      )
      .toList(growable: false);
  rows.sort((a, b) {
    final statusScore = _financeWeeklyAgreementStatusScore(
      b.status,
    ).compareTo(_financeWeeklyAgreementStatusScore(a.status));
    if (statusScore != 0) return statusScore;
    final aDue = a.nextDueDate;
    final bDue = b.nextDueDate;
    if (aDue != null && bDue == null) return -1;
    if (aDue == null && bDue != null) return 1;
    if (aDue != null && bDue != null) {
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) return dueCompare;
    }
    final amountCompare = b.remainingAmount.compareTo(a.remainingAmount);
    if (amountCompare != 0) return amountCompare;
    return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
  });
  return rows;
}

int _financeWeeklyAgreementStatusScore(String status) {
  switch (status) {
    case 'ATRASADO':
      return 3;
    case 'ACTIVO':
      return 2;
    case 'CUMPLIDO':
      return 1;
    default:
      return 0;
  }
}

List<_FinanceWeeklyBankFlowRow> _buildFinanceWeeklyBankFlowRows({
  required List<FinanzasBankMovementRecord> movements,
  required DateTime weekStart,
  required DateTime cutoffAt,
}) {
  final cutoffDay = _pdfDateOnly(cutoffAt);
  final grouped = <String, _MutableFinanceWeeklyBankFlow>{};
  for (final movement in movements) {
    final movementDay = _pdfDateOnly(movement.date);
    if (movementDay.isBefore(weekStart) || movementDay.isAfter(cutoffDay)) {
      continue;
    }
    final key = movement.accountKey.trim().isEmpty
        ? '${movement.company}|${movement.branch}'
        : movement.accountKey.trim();
    final row =
        grouped[key] ??
        _MutableFinanceWeeklyBankFlow(
          accountKey: movement.accountKey,
          company: movement.company,
          branch: movement.branch,
        );
    row.credits += movement.creditAmount;
    row.debits += movement.debitAmount;
    row.movementCount += 1;
    grouped[key] = row;
  }
  final rows = grouped.values
      .map(
        (row) => _FinanceWeeklyBankFlowRow(
          accountKey: row.accountKey,
          company: row.company,
          branch: row.branch,
          credits: row.credits,
          debits: row.debits,
          movementCount: row.movementCount,
        ),
      )
      .toList(growable: false);
  rows.sort((a, b) {
    final magnitudeCompare = b.netAmount.abs().compareTo(a.netAmount.abs());
    if (magnitudeCompare != 0) return magnitudeCompare;
    final debitCompare = b.debits.compareTo(a.debits);
    if (debitCompare != 0) return debitCompare;
    return a.accountLabel.toLowerCase().compareTo(b.accountLabel.toLowerCase());
  });
  return rows;
}

class _MutableFinanceWeeklyBankFlow {
  final String accountKey;
  final String company;
  final String branch;
  double credits = 0;
  double debits = 0;
  int movementCount = 0;

  _MutableFinanceWeeklyBankFlow({
    required this.accountKey,
    required this.company,
    required this.branch,
  });
}

_FinanceWeeklyPlacementBand _resolveFinanceWeeklyPlacement(
  FinanzasPaymentCenterOperationalItem item,
  DateTime startDate,
  DateTime endDate,
) {
  final dueOnly = item.dueDate == null ? null : _pdfDateOnly(item.dueDate!);
  if (dueOnly != null) {
    final assignedDate = dueOnly.isBefore(startDate) ? startDate : dueOnly;
    if (!assignedDate.isAfter(endDate)) {
      return _FinanceWeeklyPlacementBand.committed;
    }
    return _FinanceWeeklyPlacementBand.outsideWindow;
  }
  if (item.itemType == 'Saldo general') {
    if (item.bucket == FinanzasPaymentCenterPriorityBucket.postergable) {
      return _FinanceWeeklyPlacementBand.outsideWindow;
    }
    return _FinanceWeeklyPlacementBand.suggested;
  }
  if (item.itemType == 'Factura' ||
      item.itemType == 'Convenio' ||
      item.itemType == 'Pago fijo') {
    return _FinanceWeeklyPlacementBand.riskReview;
  }
  if (item.bucket == FinanzasPaymentCenterPriorityBucket.obligatorio ||
      item.bucket == FinanzasPaymentCenterPriorityBucket.urgente ||
      item.bucket == FinanzasPaymentCenterPriorityBucket.recomendado) {
    return _FinanceWeeklyPlacementBand.suggested;
  }
  return _FinanceWeeklyPlacementBand.outsideWindow;
}

int _compareFinanceWeeklyItems(
  FinanzasPaymentCenterOperationalItem a,
  FinanzasPaymentCenterOperationalItem b,
) {
  final aDue = a.dueDate == null ? null : _pdfDateOnly(a.dueDate!);
  final bDue = b.dueDate == null ? null : _pdfDateOnly(b.dueDate!);
  if (aDue != null && bDue == null) return -1;
  if (aDue == null && bDue != null) return 1;
  if (aDue != null && bDue != null) {
    final dueCompare = aDue.compareTo(bDue);
    if (dueCompare != 0) return dueCompare;
  }
  final priorityCompare = b.priorityScore.compareTo(a.priorityScore);
  if (priorityCompare != 0) return priorityCompare;
  final amountCompare = b.amountSuggested.compareTo(a.amountSuggested);
  if (amountCompare != 0) return amountCompare;
  return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
}

int _compareFinanceBudgetWeekProviderSummaries(
  FinanzasPaymentCenterBudgetWeekProviderSummary a,
  FinanzasPaymentCenterBudgetWeekProviderSummary b,
) {
  final committedCompare = b.committedWeekAmount.compareTo(
    a.committedWeekAmount,
  );
  if (committedCompare != 0) return committedCompare;
  final pressureCompare = b.weekPressureAmount.compareTo(a.weekPressureAmount);
  if (pressureCompare != 0) return pressureCompare;
  final riskCompare = b.riskReviewAmount.compareTo(a.riskReviewAmount);
  if (riskCompare != 0) return riskCompare;
  final outsideCompare = b.outsideWindowAmount.compareTo(a.outsideWindowAmount);
  if (outsideCompare != 0) return outsideCompare;
  final priorityCompare = b.priorityScore.compareTo(a.priorityScore);
  if (priorityCompare != 0) return priorityCompare;
  return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
}

String _buildFinanceWeeklyDecisionHeadline({
  required double availableBudgetAmount,
  required double fridayCommittedAmount,
  required double fridayPressureAmount,
}) {
  if (fridayCommittedAmount <= 0.009 && fridayPressureAmount <= 0.009) {
    return 'La junta del viernes no trae presion inmediata aterrizada.';
  }
  if (fridayCommittedAmount > availableBudgetAmount) {
    return 'Ni el compromiso visible al viernes cabe con la caja protegida.';
  }
  if (fridayPressureAmount > availableBudgetAmount) {
    return 'La base al viernes si cabe, pero la presion adicional ya requiere priorizacion.';
  }
  if (fridayPressureAmount > 0.009) {
    return 'La ventana del viernes cabe completa, pero con foco claro en prioridades.';
  }
  return 'El compromiso visible al viernes si cabe con la caja actual.';
}

String _buildFinanceWeeklyDecisionNarrative({
  required _FinanceWeeklyCut cut,
  required double availableBudgetAmount,
  required double fridayCommittedAmount,
  required double fridayPressureAmount,
  required FinanzasPaymentCenterBudgetWeekDaySummary? peakDay,
  required double overdueVisibleAmount,
  required int delayedAgreementCount,
}) {
  final peakDayLine = peakDay == null || peakDay.pressureAmount <= 0.009
      ? ''
      : ' El pico visible cae el ${_formatLongDateSpanish(peakDay.date)} con ${_formatCurrency(peakDay.pressureAmount)}.';
  final overdueLine = overdueVisibleAmount > 0.009
      ? ' Siguen ${_formatCurrency(overdueVisibleAmount)} vencidos abiertos al corte.'
      : '';
  final agreementLine = delayedAgreementCount > 0
      ? ' Ademas hay $delayedAgreementCount convenios atrasados en seguimiento.'
      : '';
  if (fridayCommittedAmount > availableBudgetAmount) {
    return 'Con la caja protegida visible por ${_formatCurrency(availableBudgetAmount)}, la junta del viernes ${cut.fridayWindowLabel} ya trae ${_formatCurrency(fridayCommittedAmount)} comprometidos. Faltan ${_formatCurrency((fridayCommittedAmount - availableBudgetAmount).abs())} incluso antes de meter presion adicional.$peakDayLine$overdueLine$agreementLine';
  }
  if (fridayPressureAmount > availableBudgetAmount) {
    return 'Lo comprometido por ${_formatCurrency(fridayCommittedAmount)} si cabe al viernes y deja ${_formatCurrency(availableBudgetAmount - fridayCommittedAmount)} libres. Si se intenta absorber tambien la presion adicional, faltan ${_formatCurrency((fridayPressureAmount - availableBudgetAmount).abs())}.$peakDayLine$overdueLine$agreementLine';
  }
  if (fridayPressureAmount > 0.009) {
    return 'La presion total visible para la junta del viernes suma ${_formatCurrency(fridayPressureAmount)} y todavia deja ${_formatCurrency(availableBudgetAmount - fridayPressureAmount)} libres despues de proteger reservas.$peakDayLine$overdueLine$agreementLine';
  }
  return 'Hoy no aparece una presion aterrizada para la junta del viernes. La caja queda libre para revisar convenios, vencimientos y arrastre sin perder la lectura real del banco.$overdueLine$agreementLine';
}

DateTime? _findFinanceWeeklyProviderDueDate(
  FinanzasPaymentCenterBudgetWeekProviderSummary provider,
) {
  for (final item in provider.items) {
    if (item.dueDate != null) return _pdfDateOnly(item.dueDate!);
  }
  return null;
}

String _buildFinanceWeeklyProviderReading(
  FinanzasPaymentCenterBudgetWeekProviderSummary provider,
  FinanzasPaymentCenterBudgetWeekSummary week,
) {
  final focusItem = provider.primaryActionItem;
  final dueDate = _findFinanceWeeklyProviderDueDate(provider);
  final duePrefix = dueDate == null
      ? ''
      : dueDate.isBefore(week.startDate)
      ? 'Trae arrastre vencido. '
      : !dueDate.isAfter(week.endDate)
      ? 'Tiene fecha dentro de la semana. '
      : 'Su siguiente fecha cae fuera de la ventana. ';
  if (focusItem != null && focusItem.recommendation.trim().isNotEmpty) {
    return '$duePrefix${focusItem.recommendation.trim()}';
  }
  if (provider.committedWeekAmount > 0.009) {
    return '${duePrefix}Mantiene compromiso visible por ${_formatCurrency(provider.committedWeekAmount)}.';
  }
  if (provider.suggestedAdditionalAmount > 0.009) {
    return '${duePrefix}Trae presion sugerida que todavia requiere priorizacion real.';
  }
  if (provider.riskReviewAmount > 0.009) {
    return '${duePrefix}Tiene monto en riesgo a revisar antes de presupuestarlo.';
  }
  return '${duePrefix}Mantiene arrastre abierto fuera de la semana visible.';
}

String _buildFinanceWeeklyMovementReading(
  FinanzasPaymentCenterOperationalItem item,
  FinanzasPaymentCenterBudgetWeekSummary week,
) {
  final recommendation = item.recommendation.trim();
  if (recommendation.isNotEmpty) return recommendation;
  final band = _resolveFinanceWeeklyPlacement(
    item,
    week.startDate,
    week.endDate,
  );
  final dueDate = item.dueDate == null ? null : _pdfDateOnly(item.dueDate!);
  switch (band) {
    case _FinanceWeeklyPlacementBand.committed:
      if (dueDate != null && dueDate.isBefore(week.startDate)) {
        return 'Ya viene vencido y cae desde el primer dia visible.';
      }
      return 'Tiene fecha visible dentro de la semana.';
    case _FinanceWeeklyPlacementBand.suggested:
      return 'Trae presion visible, pero sin fecha aterrizada dentro de la semana.';
    case _FinanceWeeklyPlacementBand.outsideWindow:
      return 'Sigue abierto, pero su fecha ya queda fuera de esta ventana.';
    case _FinanceWeeklyPlacementBand.riskReview:
      return 'Requiere criterio o fecha clara antes de presupuestarse.';
  }
}

String _buildFinanceWeeklyOutsideWindowReading(
  FinanzasPaymentCenterBudgetWeekProviderSummary provider,
  FinanzasPaymentCenterBudgetWeekSummary week,
) {
  final dueDate = _findFinanceWeeklyProviderDueDate(provider);
  final dueLine = dueDate == null
      ? 'No trae fecha aterrizada visible.'
      : dueDate.isAfter(week.endDate)
      ? 'La siguiente fecha visible cae despues del ${_formatLongDateSpanish(week.endDate)}.'
      : 'Sigue cargando movimientos previos a la ventana actual.';
  return '$dueLine Mantiene ${_formatCurrency(provider.outsideWindowAmount)} fuera de la semana.';
}

String _formatOptionalDate(DateTime? value) {
  if (value == null) return 'Sin fecha';
  return _formatShortDate(value);
}

DateTime _pdfDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isOnReportDay(DateTime? value, DateTime dayStart) {
  if (value == null) return false;
  return _pdfDateOnly(value).isAtSameMomentAs(dayStart);
}

String _sanitizePdfText(String value) {
  if (value.trim().isEmpty) return value.trim();
  const replacements = <String, String>{
    'Á': 'A',
    'À': 'A',
    'Ä': 'A',
    'Â': 'A',
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'É': 'E',
    'È': 'E',
    'Ë': 'E',
    'Ê': 'E',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'Í': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'Î': 'I',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'Ó': 'O',
    'Ò': 'O',
    'Ö': 'O',
    'Ô': 'O',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'Ú': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'Û': 'U',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'Ñ': 'N',
    'ñ': 'n',
    '’': '\'',
    '“': '"',
    '”': '"',
    '–': '-',
    '—': '-',
    '•': '-',
    '·': '|',
    '\u00A0': ' ',
    '\u202F': ' ',
  };
  var normalized = value;
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  return normalized.trim();
}

class _OperationsWeeklyCut {
  final DateTime weekStart;
  final DateTime friday;
  final DateTime cutoffAt;

  const _OperationsWeeklyCut({
    required this.weekStart,
    required this.friday,
    required this.cutoffAt,
  });

  String get windowLabel =>
      'Semana operativa ${_formatLongDateSpanish(weekStart)} al ${_formatLongDateSpanish(friday)}';
}

class _OperationsWeeklyOtRow {
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
  final String diagnosis;
  final String workSummary;
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final double? estimatedCost;
  final double? actualCost;

  const _OperationsWeeklyOtRow({
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
    required this.diagnosis,
    required this.workSummary,
    required this.requestedAt,
    required this.updatedAt,
    required this.estimatedCost,
    required this.actualCost,
  });

  factory _OperationsWeeklyOtRow.fromJson(Map<String, dynamic> json) {
    return _OperationsWeeklyOtRow(
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
      diagnosis: _cleanString(json['diagnosis']),
      workSummary: _cleanString(json['work_summary']),
      requestedAt: DateTime.tryParse((json['requested_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      estimatedCost: _toNullableDouble(json['cost_estimated_total']),
      actualCost: _toNullableDouble(json['cost_actual_total']),
    );
  }

  bool get isOpen => !isMaintenanceClosedStatus(status);
  bool get isClosed => status == 'cerrado';
  bool get isRejected => status == 'rechazado';
  bool get isHighPriority => priority == 'alta';
  bool get hasParo => impact == 'paro_total' || impact == 'paro_parcial';
  bool get isCriticalOpen => isOpen && (isHighPriority || hasParo);
  bool get isWaitingAction =>
      status == 'cotizacion' || status == 'autorizacion_finanzas';
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

  String get shortDescription => _truncate(problemDescription, 70);

  double ageHoursAt(DateTime reference) {
    final base = requestedAt ?? updatedAt;
    if (base == null) return 0;
    final minutes = reference.difference(base).inMinutes;
    if (minutes <= 0) return 0;
    return minutes / 60;
  }

  String ageHoursLabel(DateTime reference) {
    return ageHoursAt(reference).toStringAsFixed(1);
  }

  bool isDelayed(_OperationsWeeklyCut cut) {
    if (!isOpen) return false;
    if (requestedAt != null && requestedAt!.isBefore(cut.weekStart)) {
      return true;
    }
    return ageHoursAt(cut.cutoffAt) >= 72;
  }

  int riskScore(_OperationsWeeklyCut cut) {
    var score = 0;
    if (isHighPriority) score += 5;
    if (impact == 'paro_total') score += 5;
    if (impact == 'paro_parcial') score += 2;
    if (isDelayed(cut)) score += 4;
    if (isWaitingAction) score += 3;
    if (missingResponsible) score += 3;
    if (status == 'supervision') score += 1;
    if (ageHoursAt(cut.cutoffAt) >= 168) score += 4;
    return score;
  }

  String blockerLabel(_OperationsWeeklyCut cut) {
    final reasons = <String>[];
    if (isWaitingAction) {
      reasons.add(
        status == 'cotizacion' ? 'Espera cotizacion' : 'Espera autorizacion',
      );
    }
    if (status == 'aviso_falla') reasons.add('Pendiente diagnostico');
    if (status == 'supervision') reasons.add('Pendiente cierre');
    if (missingResponsible) reasons.add('Sin responsable');
    if ((status == 'cotizacion' || status == 'autorizacion_finanzas') &&
        diagnosis.isEmpty) {
      reasons.add('Sin diagnostico');
    }
    if (reasons.isEmpty && isDelayed(cut)) reasons.add('Atrasada');
    if (reasons.isEmpty) reasons.add('Seguimiento');
    return reasons.join(' | ');
  }

  String focusReason(_OperationsWeeklyCut cut) {
    final reasons = <String>[];
    if (isDelayed(cut)) reasons.add('Atrasada');
    if (isHighPriority) reasons.add('Alta');
    if (impact == 'paro_total') reasons.add('Paro total');
    if (impact == 'paro_parcial') reasons.add('Paro parcial');
    if (status == 'cotizacion') reasons.add('Cotizacion');
    if (status == 'autorizacion_finanzas') reasons.add('Autorizacion');
    if (missingResponsible) reasons.add('Sin responsable');
    if (reasons.isEmpty) reasons.add('Seguimiento');
    return reasons.join(' | ');
  }
}

class _OperationsWeeklyAreaRow {
  final String areaLabel;
  final int openCount;
  final int criticalCount;
  final int delayedCount;
  final int waitingCount;
  final int closedWeekCount;

  const _OperationsWeeklyAreaRow({
    required this.areaLabel,
    required this.openCount,
    required this.criticalCount,
    required this.delayedCount,
    required this.waitingCount,
    required this.closedWeekCount,
  });
}

class _OperationsWeeklyEquipmentRow {
  final String equipmentLabel;
  final String areaLabel;
  final int openCount;
  final int criticalCount;
  final int delayedCount;
  final int waitingCount;

  const _OperationsWeeklyEquipmentRow({
    required this.equipmentLabel,
    required this.areaLabel,
    required this.openCount,
    required this.criticalCount,
    required this.delayedCount,
    required this.waitingCount,
  });
}

class _OperationsWeeklyInsights {
  final int openCount;
  final int criticalOpenCount;
  final int delayedOpenCount;
  final int waitingActionCount;
  final int closedWeekCount;
  final int rejectedWeekCount;
  final List<_OperationsWeeklyOtRow> openRows;
  final List<_OperationsWeeklyOtRow> resolvedWeekRows;
  final List<_OperationsWeeklyAreaRow> areaRows;
  final List<_OperationsWeeklyEquipmentRow> equipmentRows;
  final List<_OperationsWeeklyOtRow> focusRows;
  final List<String> executiveSummary;
  final List<String> alerts;
  final List<String> closeoutPrompts;

  const _OperationsWeeklyInsights({
    required this.openCount,
    required this.criticalOpenCount,
    required this.delayedOpenCount,
    required this.waitingActionCount,
    required this.closedWeekCount,
    required this.rejectedWeekCount,
    required this.openRows,
    required this.resolvedWeekRows,
    required this.areaRows,
    required this.equipmentRows,
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
  required pw.MemoryImage? logoImage,
  required String eyebrow,
  required String title,
  required String subtitle,
  required List<MapEntry<String, String>> badges,
  required PdfColor accent,
  required PdfColor accentSoft,
  required PdfColor accentBorder,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 2),
    padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(18),
      border: pw.Border.all(color: accentBorder, width: 1.2),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Container(
              width: 86,
              height: 50,
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'DICSA',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#223548'),
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: accentSoft,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      eyebrow,
                      style: pw.TextStyle(
                        color: accent,
                        fontSize: 9.8,
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
                  pw.SizedBox(height: 5),
                  pw.Text(subtitle, style: _mutedStyle(fontSize: 10.2)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 10,
          runSpacing: 8,
          children: badges
              .map((badge) => _pdfMetaChip(badge.key, badge.value, accent))
              .toList(growable: false),
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
            color: PdfColor.fromHex('#223548'),
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

pw.Widget _pdfTableWithOptionalNote({required pw.Widget child, String? note}) {
  final normalizedNote = (note ?? '').trim();
  if (normalizedNote.isEmpty) return child;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(normalizedNote, style: _mutedStyle(fontSize: 9.6)),
      pw.SizedBox(height: 8),
      child,
    ],
  );
}

List<pw.Widget> _pdfChunkedTableSections({
  required String title,
  required PdfColor accent,
  required List<String> headers,
  required List<List<String>> rows,
  required String emptyLabel,
  required PdfColor headerColor,
  required int maxRowsPerSection,
  bool compact = false,
  bool startOnNewPage = false,
  String? introNote,
}) {
  final widgets = <pw.Widget>[];
  if (startOnNewPage) {
    widgets.add(pw.NewPage());
  } else {
    widgets.add(pw.SizedBox(height: 14));
  }
  if (rows.isEmpty) {
    widgets.add(
      _pdfSection(
        title: title,
        accent: accent,
        child: _pdfTableWithOptionalNote(
          note: introNote,
          child: _pdfSimpleTable(
            headers: headers,
            rows: rows,
            emptyLabel: emptyLabel,
            headerColor: headerColor,
            compact: compact,
          ),
        ),
      ),
    );
    return widgets;
  }

  final chunkSize = maxRowsPerSection <= 0 ? rows.length : maxRowsPerSection;
  final chunks = <List<List<String>>>[];
  for (var index = 0; index < rows.length; index += chunkSize) {
    final end = (index + chunkSize < rows.length)
        ? index + chunkSize
        : rows.length;
    chunks.add(rows.sublist(index, end));
  }

  for (var index = 0; index < chunks.length; index++) {
    if (index > 0) {
      widgets.add(pw.SizedBox(height: 14));
    }
    final sectionTitle = chunks.length == 1
        ? title
        : '$title (${index + 1}/${chunks.length})';
    widgets.add(
      _pdfSection(
        title: sectionTitle,
        accent: accent,
        child: _pdfTableWithOptionalNote(
          note: index == 0 ? introNote : null,
          child: _pdfSimpleTable(
            headers: headers,
            rows: chunks[index],
            emptyLabel: emptyLabel,
            headerColor: headerColor,
            compact: compact,
          ),
        ),
      ),
    );
  }
  return widgets;
}

pw.Widget _pdfMetaChip(String label, String value, PdfColor accent) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(8),
      color: PdfColor.fromHex('#F7FAFC'),
      border: pw.Border.all(color: PdfColor.fromHex('#D6E3EB'), width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: <pw.Widget>[
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#60758C'),
            fontSize: 8.6,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#203549'),
            fontSize: 10.4,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

pw.PageTheme _managementReportPdfPageTheme(PdfPageFormat pageFormat) {
  return pw.PageTheme(
    pageFormat: pageFormat,
    margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
    buildBackground: (context) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Container(color: PdfColors.white),
    ),
  );
}

Future<pw.MemoryImage?> _tryLoadManagementReportLogo() async {
  try {
    final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
    return pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {
    return null;
  }
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

DateTime _nextOrSameFriday(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final delta = (DateTime.friday - normalized.weekday + 7) % 7;
  return normalized.add(Duration(days: delta));
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

String _formatQuantity(double value, {int decimals = 2}) {
  final sign = value < 0 ? '-' : '';
  final absolute = value.abs().toStringAsFixed(decimals);
  final parts = absolute.split('.');
  final whole = parts.first;
  final decimal = parts.length > 1 ? parts.last : '';
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final indexFromEnd = whole.length - i;
    buffer.write(whole[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return decimal.isEmpty
      ? '$sign${buffer.toString()}'
      : '$sign${buffer.toString()}.$decimal';
}

String _formatPercent(double value, {int decimals = 1}) {
  return '${value.toStringAsFixed(decimals)}%';
}

String _formatSignedCount(int value) {
  if (value > 0) return '+$value';
  return '$value';
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

Color _managementAccentInk(Color color) {
  return color;
}

String _deriveSalesReportStatusKey({
  required String baseStatus,
  required String operationType,
  required String documentNumber,
  required DateTime? documentDate,
  required DateTime? settlementDate,
  required double paidAmount,
  required double approvedAmount,
}) {
  const tolerance = 0.5;
  final normalizedBaseStatus = _normalizeTag(baseStatus);
  final normalizedPaidAmount = paidAmount < 0 ? 0.0 : paidAmount;
  final normalizedApprovedAmount = approvedAmount < 0 ? 0.0 : approvedAmount;
  final pendingBalance = normalizedApprovedAmount - normalizedPaidAmount;
  final isSettled = pendingBalance <= tolerance;
  final hasDocumentEvidence =
      documentNumber.trim().isNotEmpty || documentDate != null;

  if (normalizedBaseStatus == 'cancelada' ||
      normalizedBaseStatus == 'porrevisar' ||
      normalizedBaseStatus == 'pagada' ||
      normalizedBaseStatus == 'chequecanjeado') {
    return normalizedBaseStatus;
  }
  if (operationType == 'factura') {
    if (settlementDate != null || normalizedPaidAmount > tolerance) {
      return isSettled ? 'pagada' : 'pagoparcial';
    }
    return hasDocumentEvidence ? 'facturadapendientepago' : 'pendientefactura';
  }
  if (settlementDate != null) {
    return 'chequecanjeado';
  }
  if (normalizedPaidAmount > tolerance) {
    return 'chequependientecanje';
  }
  return hasDocumentEvidence ? 'chequerecibido' : 'pendientecheque';
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
