part of 'management_reports_operations_daily_pdf.dart';

/// Executive projections of the same analyses used by the individual PDFs.
/// Never builds/parses a PDF or infers metrics from catalog readiness flags.
Future<DirectionAreaSummary> loadDirectionExistingSummary(
  DirectionSummaryArea area,
  DateTime at,
) async {
  DirectionSummaryMetric count(String label, num value, [num? previous]) =>
      DirectionSummaryMetric(
        label,
        '$value',
        previous == null ? '—' : '$previous',
      );
  DirectionSummaryMetric money(String label, num value, [num? previous]) =>
      DirectionSummaryMetric(
        label,
        directionSummaryMoney(value),
        previous == null ? '—' : directionSummaryMoney(previous),
      );
  DirectionSummaryMetric kg(String label, num value, [num? previous]) =>
      DirectionSummaryMetric(
        label,
        directionSummaryNumber(value, 'kg'),
        previous == null ? '—' : directionSummaryNumber(previous, 'kg'),
      );
  DirectionAreaSummary result(
    List<DirectionSummaryMetric> metrics,
    List<String> alerts,
    List<String> notes, {
    String? basis,
  }) => DirectionAreaSummary(
    area: area,
    basis: basis ?? 'Semana del corte',
    metrics: metrics,
    alerts: alerts,
    notes: notes,
  );
  switch (area) {
    case DirectionSummaryArea.bascula:
      final cut = _resolveBasculaWeeklyCut(at);
      final i = _buildBasculaWeeklyInsights(
        await _loadBasculaWeeklySourceBundle(cut),
        cut,
      );
      return result(
        [
          kg('Material entrante', i.totalIncomingKg, i.previousIncomingKg),
          kg('Material saliente', i.totalOutgoingKg, i.previousOutgoingKg),
          count('Pesadas', i.currentWeighingCount, i.previousWeighingCount),
          count('Pesadas sin vínculo', i.unmatchedWeighingCount),
          DirectionSummaryMetric(
            'Tickets faltantes / duplicados',
            '${i.missingTicketCount} / ${i.duplicateWeighingCount}',
          ),
        ],
        i.alerts,
        [
          'Entradas y Salidas + Pesadas. Los kilos son flujo físico; no se suman a compras o ventas.',
        ],
      );
    case DirectionSummaryArea.logistica:
      final cut = _resolveLogisticsWeeklyCut(at);
      final i = _buildLogisticsWeeklyInsights(
        await _loadLogisticsWeeklySourceBundle(cut),
        cut,
      );
      return result(
        [
          count('Viajes programados', i.currentTripCount, i.previousTripCount),
          count('Viajes completados', i.completedTripCount),
          DirectionSummaryMetric(
            'Pendientes / en curso',
            '${i.pendingTripCount} / ${i.inProgressTripCount}',
          ),
          DirectionSummaryMetric(
            'Cancelados / sin asignación',
            '${i.canceledTripCount} / ${i.unassignedTripCount}',
          ),
          DirectionSummaryMetric(
            'Diésel solicitado',
            directionSummaryNumber(i.currentDieselRequestedLiters, 'L'),
          ),
          DirectionSummaryMetric(
            'Gasolina cargada',
            directionSummaryNumber(i.currentGasolineLoadedLiters, 'L'),
          ),
        ],
        i.alerts,
        [
          'Servicios con fecha comprometida en el corte. Litros solicitados/cargados no equivalen a consumo medido.',
          'Kilometraje y rendimiento no forman parte de este resumen.',
        ],
      );
    case DirectionSummaryArea.menudeo:
      final cut = _resolveMenudeoWeeklyCut(at);
      final i = _buildMenudeoWeeklyInsights(
        await _loadMenudeoWeeklySourceBundle(cut),
        cut,
      );
      return result(
        [
          money(
            'Compras registradas',
            i.purchaseRow.currentAmount,
            i.purchaseRow.previousAmount,
          ),
          money(
            'Ventas registradas',
            i.saleRow.currentAmount,
            i.saleRow.previousAmount,
          ),
          money(
            'Ventas menos compras',
            i.visibleCommercialSpread,
            i.saleRow.previousAmount - i.purchaseRow.previousAmount,
          ),
          count(
            'Tickets totales de compra y venta',
            i.purchaseRow.currentTicketCount + i.saleRow.currentTicketCount,
            i.purchaseRow.previousTicketCount + i.saleRow.previousTicketCount,
          ),
          count('Cortes abiertos', i.openCashCutCount),
          money('Diferencia de caja', i.totalCashDifference),
        ],
        i.alerts,
        [
          'Tickets, vales, cortes y ajustes de precios del área. El saldo comercial no es utilidad neta.',
        ],
      );
    case DirectionSummaryArea.ventas:
      final cut = _resolveSalesWeeklyCut(at);
      final i = _buildSalesWeeklyCollectionInsights(
        await _loadSalesCollectionAccountRows(cut, strictBankRead: true),
        cut,
      );
      return result(
        [
          money('Cobranza abierta actual', i.totalPendingBalance),
          money('Cobro visible en la semana', i.collectedWeekAmount),
          count('Cuentas abiertas', i.openRows.length),
          count('Promesas de pago vencidas', i.overdueEstimatedRows.length),
          count('Pendientes de facturar', i.pendingInvoiceRows.length),
        ],
        i.alerts,
        [
          'Cuentas Mayoreo conciliadas con abonos bancarios. Los saldos abiertos son actuales.',
          'Ajustes de precios y tiempos completos de pago no están incluidos.',
        ],
        basis: 'Cobranza actual y cobros de la semana',
      );
    case DirectionSummaryArea.rh:
      final cut = _resolveHrWeeklyCut(at);
      final source = await _loadHrWeeklySourceBundle(cut);
      final i = _buildHrWeeklyInsights(source, cut);
      final hasPeriod = source.selectedPeriodLabel.isNotEmpty;
      return result(
        [
          count('Plantilla activa', i.activeEmployees),
          DirectionSummaryMetric(
            'Asistencia',
            i.attendanceRate == null
                ? 'Sin registros'
                : '${i.attendanceRate!.toStringAsFixed(1)}%',
          ),
          DirectionSummaryMetric(
            'Faltas / registros de retardo',
            hasPeriod
                ? '${i.absenceDays} / ${i.lateRecordCount}'
                : 'Sin periodo',
          ),
          DirectionSummaryMetric(
            'Permisos pendientes',
            hasPeriod ? '${i.pendingPermissions}' : 'Sin periodo',
          ),
          DirectionSummaryMetric(
            'Nómina operativa del periodo',
            !hasPeriod || i.payroll.rows == 0
                ? 'Sin captura'
                : directionSummaryMoney(i.payroll.operationalTotal),
          ),
          DirectionSummaryMetric(
            'Cierre de nómina',
            !hasPeriod
                ? 'Sin periodo'
                : i.payrollClosed
                ? 'Cerrada'
                : 'Abierta',
          ),
        ],
        i.alerts,
        [
          i.periodResolutionNote,
          'Accidentes, reclutamiento y vacantes: captura pendiente.',
        ],
        basis:
            'Periodo RH: ${i.periodLabel.isEmpty ? 'sin periodo' : i.periodLabel}',
      );
    case DirectionSummaryArea.desarrolloComercial:
      final cut = _resolveCommercialDevelopmentWeeklyCut(at);
      final i = _buildCommercialDevelopmentWeeklyInsights(
        await _loadCommercialDevelopmentWeeklySourceBundle(cut),
        cut,
      );
      return result(
        [
          count('Prospectos activos actuales', i.totalActiveProspectCount),
          DirectionSummaryMetric(
            'Prospectos nuevos / meta semanal',
            '${i.newProspectCount} / ${i.weeklyProspectGoal}',
          ),
          count('Contactos nuevos', i.newContactCount),
          count('Seguimientos de la semana', i.weekFollowUpCount),
          count('Visitas de la semana', i.visitCount),
          count('Prospectos con seguimiento vencido', i.overdueProspectCount),
        ],
        i.alerts,
        i.coverageNotes,
        basis: 'Actividad semanal y cartera CRM actual',
      );
    case DirectionSummaryArea.gastos:
      final rows = (await _loadExpensesDailyPurchaseOrderRows())
          .map(
            (r) => ExpensesWeeklyOrder(
              id: r.id,
              folio: r.folio,
              orderDate: r.orderDate,
              status: r.status,
              vendor: r.vendorLabel,
              target: r.targetLabel,
              concept: r.conceptLabel,
              ot: r.isLinkedToOt ? r.otLabel : '',
              estimated: r.estimatedTotal.isFinite && r.estimatedTotal > 0
                  ? r.estimatedTotal
                  : null,
              actual: r.actualTotal?.isFinite == true ? r.actualTotal : null,
              purchasedAt: r.purchasedAt?.toLocal(),
              sentToCashAt: r.sentToCashAt?.toLocal(),
              createdAt: r.createdAt?.toLocal(),
            ),
          )
          .toList();
      final i = ExpensesWeeklyAnalysis(rows, ExpensesWeeklyCut(at));
      String actual(ExpensesWeeklySummary s) =>
          s.rows.isNotEmpty && s.withoutActual == s.rows.length
          ? 'Sin dato'
          : directionSummaryMoney(s.actual);
      return result(
        [
          DirectionSummaryMetric(
            'OC compradas: importe real conocido',
            actual(i.current),
            actual(i.previous),
          ),
          count('OC compradas', i.current.rows.length, i.previous.rows.length),
          count('OC pendientes actuales', i.pending.length),
          money('Estimado pendiente', i.pendingEstimate),
          count('Compras sobre presupuesto', i.current.overBudget),
        ],
        [
          if (i.current.withoutActual > 0)
            '${i.current.withoutActual} compras sin importe real; total parcial.',
          if (i.undatedPurchases.isNotEmpty)
            '${i.undatedPurchases.length} compras sin fecha de compra; no se asignan a una semana.',
          if (i.current.overBudget > 0)
            '${i.current.overBudget} compras excedieron el estimado comparable.',
        ],
        [
          'Compras de mantenimiento por fecha real de compra; no sumar a gastos contables ni al subconjunto ligado a OT.',
        ],
      );
    default:
      throw ArgumentError('Área sin proyección heredada: $area');
  }
}
