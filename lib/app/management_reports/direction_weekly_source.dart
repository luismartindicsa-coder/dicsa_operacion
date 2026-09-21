import 'package:supabase_flutter/supabase_flutter.dart';

import '../commercial/commercial_store.dart';
import '../direction/direction_shipments_store.dart';
import '../finanzas/finanzas_bank_accounts_store.dart';
import '../gerencia/gerencia_bale_weekly_tracking_store.dart';
import '../maintenance/maintenance_statuses.dart';
import '../shared/direction_vault/direction_vault_repository.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'accounting_weekly_analysis.dart';
import 'accounting_weekly_source.dart';
import 'direction_weekly_summary.dart';
import 'documental_weekly_analysis.dart';
import 'documental_weekly_source.dart';
import 'gerencia_weekly_analysis.dart';
import 'management_reports_history_store.dart';
import 'management_reports_operations_daily_pdf.dart';
import 'management_reports_registry.dart';
import 'operations_weekly_analysis.dart';
import 'operations_weekly_source.dart';

/// Independent read-only sources, with one shared commercial query. A source
/// error is isolated to affected areas by collectDirectionAreaSummaries.
Future<List<DirectionAreaSummary>> loadDirectionWeeklySource(
  DateTime generatedAt,
) {
  final cut = AccountingWeeklyCut(generatedAt);
  final fridayEnd = DateTime(
    cut.friday.year,
    cut.friday.month,
    cut.friday.day,
    23,
    59,
    59,
    999,
  );
  final at = generatedAt.isAfter(fridayEnd) ? fridayEnd : generatedAt;
  // Lazy: attach consumers before starting the request so errors are handled.
  Future<List<CommercialMarketEventRecord>>? market;
  Future<List<CommercialMarketEventRecord>> events() =>
      market ??= loadAccountingMarketEvents(cut);
  return collectDirectionAreaSummaries({
    for (final area in [
      DirectionSummaryArea.bascula,
      DirectionSummaryArea.logistica,
      DirectionSummaryArea.menudeo,
      DirectionSummaryArea.desarrolloComercial,
      DirectionSummaryArea.gastos,
      DirectionSummaryArea.rh,
    ])
      area: () => loadDirectionExistingSummary(area, at),
    DirectionSummaryArea.operaciones: () async =>
        summarizeDirectionOperations(await loadOperationsWeeklySource(at), at),
    DirectionSummaryArea.compras: () async =>
        summarizeDirectionTrade(await events(), cut, purchases: true),
    DirectionSummaryArea.ventas: () async {
      final loaded = await Future.wait<dynamic>([
        events(),
        loadDirectionExistingSummary(DirectionSummaryArea.ventas, at),
      ]);
      final trade = summarizeDirectionTrade(
        loaded[0] as List<CommercialMarketEventRecord>,
        cut,
        purchases: false,
      );
      final collection = loaded[1] as DirectionAreaSummary;
      return DirectionAreaSummary(
        area: trade.area,
        basis: 'Ventas semanales y cobranza actual',
        metrics: [...trade.metrics.take(2), ...collection.metrics.take(4)],
        alerts: [...trade.alerts, ...collection.alerts],
        notes: [...trade.notes, ...collection.notes],
      );
    },
    DirectionSummaryArea.contabilidad: () async => summarizeDirectionAccounting(
      await loadAccountingWeeklySource(at, marketEvents: events()),
    ),
    DirectionSummaryArea.gestion: () async =>
        summarizeDirectionDocumental(await loadDocumentalWeeklySource()),
    DirectionSummaryArea.gerencia: () async {
      final bundles = await Future.wait([
        GerenciaBaleWeeklyTrackingStore.loadWeekForReport(cut.current.start),
        GerenciaBaleWeeklyTrackingStore.loadWeekForReport(cut.previous.start),
      ]);
      return summarizeDirectionGoals(
        GerenciaWeeklyAnalysis(bundles[0], at),
        GerenciaWeeklyAnalysis(
          bundles[1],
          at.subtract(const Duration(days: 7)),
        ),
      );
    },
    DirectionSummaryArea.inventario: () async {
      final rows = await Future.wait([
        _rows(
          'v_inventory_general_balance_v2',
          'code,name,on_hand_kg,on_hand_units',
          order: 'code',
        ),
        _rows(
          'v_inventory_commercial_balance_v2',
          'code,name,on_hand_kg,on_hand_units',
          order: 'code',
        ),
      ]);
      return summarizeDirectionInventory(rows[0], rows[1]);
    },
    DirectionSummaryArea.almacen: () async => summarizeDirectionWarehouse(
      await _rows(
        'inventory_items',
        'id,code,name,current_stock,minimum_stock,is_active',
      ),
    ),
    DirectionSummaryArea.embarques: () async {
      final rows = await fetchAllSupabaseRows(
        (from, to) => Supabase.instance.client
            .from('direction_shipment_plans')
            .select(
              'id,ship_date,client_name,commercial_material_code,planning_material_code,material_scope,quantity_unit,planned_units,priority,status,notes,created_at,updated_at',
            )
            .gte('ship_date', _date(cut.previous.start))
            .lte('ship_date', _date(cut.current.end))
            .order('ship_date')
            .order('id')
            .range(from, to),
        pageSize: 500,
      );
      return summarizeDirectionShipments(
        rows.map(DirectionShipmentPlanRecord.fromRow).toList(),
        cut,
      );
    },
    DirectionSummaryArea.boveda: () async => summarizeDirectionVault(
      await DirectionVaultRepository.instance.loadVouchers(
        migrateLegacy: false,
        strictLegacyRead: true,
      ),
      cut,
    ),
    DirectionSummaryArea.finanzas: () async {
      final rows = await Future.wait<dynamic>([
        FinanzasBankAccountsStore.loadMovementsStrict(),
        _rows(
          'finanzas_supplier_invoices',
          'id,invoice_date,due_date,balance_amount,status',
        ),
      ]);
      return summarizeDirectionFinance(
        rows[0] as List<FinanzasBankMovementRecord>,
        rows[1] as List<Map<String, dynamic>>,
        cut,
        generatedAt,
      );
    },
    DirectionSummaryArea.supervision: () async => summarizeDirectionHistory(
      await ManagementReportsHistoryStore.loadAll(),
      cut,
    ),
  });
}

Future<List<Map<String, dynamic>>> _rows(
  String table,
  String fields, {
  String order = 'id',
}) => fetchAllSupabaseRows(
  (from, to) => Supabase.instance.client
      .from(table)
      .select(fields)
      .order(order)
      .range(from, to),
  pageSize: 500,
);

DirectionSummaryMetric _count(String label, num n, [num? previous]) =>
    DirectionSummaryMetric(label, '$n', previous == null ? '—' : '$previous');
DirectionSummaryMetric _money(String label, num? n, [num? previous]) =>
    DirectionSummaryMetric(
      label,
      directionSummaryMoney(n),
      previous == null ? '—' : directionSummaryMoney(previous),
    );
DirectionSummaryMetric _kg(String label, num? n, [num? previous]) =>
    DirectionSummaryMetric(
      label,
      directionSummaryNumber(n, 'kg'),
      previous == null ? '—' : directionSummaryNumber(previous, 'kg'),
    );
String _date(DateTime d) => d.toIso8601String().substring(0, 10);
double _number(Object? value) => double.tryParse('$value') ?? 0;

DirectionAreaSummary summarizeDirectionOperations(
  OperationsWeeklySource source,
  DateTime at,
) {
  final i = OperationsWeeklyAnalysis(source, at);
  final open = i.costs
      .where(
        (r) => !isMaintenanceClosedStatus(
          normalizeMaintenanceStatus(r.order['status']),
        ),
      )
      .length;
  return DirectionAreaSummary(
    area: DirectionSummaryArea.operaciones,
    basis: 'Producción semanal y estado actual de OT',
    metrics: [
      _kg(
        'Producción con peso registrado',
        i.currentProduction.hasWeight ? i.currentProduction.kg : null,
        i.previousProduction.hasWeight ? i.previousProduction.kg : null,
      ),
      DirectionSummaryMetric(
        'Unidades producidas',
        i.currentProduction.hasUnits
            ? '${i.currentProduction.units}'
            : 'Sin dato',
        i.previousProduction.hasUnits
            ? '${i.previousProduction.units}'
            : 'Sin dato',
      ),
      _count('OT abiertas en seguimiento', open),
      _count(
        'OT con compra semanal ligada',
        i.costs.where((r) => r.purchases.rows.isNotEmpty).length,
      ),
      DirectionSummaryMetric(
        'Compras ligadas a OT: real conocido',
        i.expenses.current.rows.isNotEmpty &&
                i.expenses.current.withoutActual ==
                    i.expenses.current.rows.length
            ? 'Sin dato'
            : directionSummaryMoney(i.expenses.current.actual),
        i.expenses.previous.rows.isNotEmpty &&
                i.expenses.previous.withoutActual ==
                    i.expenses.previous.rows.length
            ? 'Sin dato'
            : directionSummaryMoney(i.expenses.previous.actual),
      ),
    ],
    alerts: [
      if (open > 0) '$open OT abiertas requieren seguimiento.',
      ...i.warnings,
    ],
    notes: [
      'Incluye Producción y Mantenimiento. Inventario y Almacén tienen bloques propios.',
      'Incidencias de patio: captura pendiente. Unidades de diferentes materiales no equivalen a kilos.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionTrade(
  List<CommercialMarketEventRecord> events,
  AccountingWeeklyCut cut, {
  required bool purchases,
}) {
  final area = purchases
      ? DirectionSummaryArea.compras
      : DirectionSummaryArea.ventas;
  final source = purchases ? 'mayoreo_compras' : 'mayoreo_ventas';
  final flow = purchases ? 'purchase' : 'sale';
  final valid = events.where((r) => r.sourceArea == source && r.flow == flow);
  final current = AccountingTradeTotals(
    valid.where((r) => cut.contains(r.eventAt)),
  );
  final previous = AccountingTradeTotals(
    valid.where((r) => cut.contains(r.eventAt, prior: true)),
  );
  return DirectionAreaSummary(
    area: area,
    basis: 'Operaciones comerciales de la semana',
    metrics: [
      _money(
        purchases ? 'Compras registradas' : 'Ventas registradas',
        purchases ? current.purchases : current.sales,
        purchases ? previous.purchases : previous.sales,
      ),
      _kg(
        purchases ? 'Kilos comprados' : 'Kilos vendidos',
        purchases ? current.purchasedKg : current.soldKg,
        purchases ? previous.purchasedKg : previous.soldKg,
      ),
      _count(
        'Operaciones registradas',
        current.events.length,
        previous.events.length,
      ),
      DirectionSummaryMetric(
        'Precio ponderado por kg',
        directionSummaryMoney(
          purchases ? current.purchasePrice : current.salePrice,
        ),
        directionSummaryMoney(
          purchases ? previous.purchasePrice : previous.salePrice,
        ),
      ),
    ],
    notes: [
      'Misma base que Resultado Comercial. Importe de operación, no flujo de efectivo; no sumar al consolidado de Contabilidad.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionAccounting(
  AccountingWeeklySource source,
) {
  final i = AccountingWeeklyAnalysis(source);
  final a = source.currentStatement.snapshot,
      b = source.previousStatement.snapshot;
  return DirectionAreaSummary(
    area: DirectionSummaryArea.contabilidad,
    basis: 'Mismos días: semana del corte vs anterior',
    metrics: [
      _money(
        'Resultado comercial consolidado',
        i.current.result,
        i.previous.result,
      ),
      _money('Ventas de material cobradas', a.revenue, b.revenue),
      _money('Compras de material pagadas', a.commercialCost, b.commercialCost),
      _money(
        'Utilidad bruta del estado de resultados',
        a.commercialResult,
        b.commercialResult,
      ),
      _money(
        'Gastos del estado de resultados',
        a.recognizedExpenses,
        b.recognizedExpenses,
      ),
      _money(
        'Utilidad neta del estado de resultados',
        a.periodResult,
        b.periodResult,
      ),
    ],
    alerts: [
      ...source.currentStatement.warnings,
      ...source.previousStatement.warnings,
    ],
    notes: [
      'Resultado comercial = ventas menos compras registradas del periodo; no representa costo de ventas ni utilidad neta.',
      'Estado de resultados sobre cobros y pagos de Bancos, Bóveda y Menudeo, con las reglas de la pantalla contable.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionDocumental(
  DocumentalWeeklySource source,
) {
  final i = DocumentalWeeklyAnalysis(source);
  return DirectionAreaSummary(
    area: DirectionSummaryArea.gestion,
    basis: 'Situación actual al ${_date(i.today)}',
    metrics: [
      _count('Expedientes registrados', i.records.length),
      _count('Activos', i.active.length),
      _count('Vencidos', i.expired.length),
      _count('Vencen en 0 a 5 días', i.critical.length),
      _count('Riesgos del calendario', i.risks.length),
      _count('Eventos próximos: 30 días', i.agenda.length),
    ],
    alerts: [
      if (i.expired.isNotEmpty)
        '${i.expired.length} expedientes vencidos; asignar regularización.',
      if (i.critical.isNotEmpty)
        '${i.critical.length} expedientes vencen en cinco días o menos.',
      if (i.risks.isNotEmpty)
        '${i.risks.length} eventos requieren atención por vencimiento, renovación o ejecución.',
    ],
    notes: [
      'Incluye las 11 categorías del área: permisos, cursos, contratos, seguros, trámites y agenda, entre otras.',
      'Manifiestos: control documental. Cantidades/destino de residuos y subsidios: cobertura pendiente.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionGoals(
  GerenciaWeeklyAnalysis current,
  GerenciaWeeklyAnalysis previous,
) {
  final withTarget = current.goals.where((g) => g.hasTarget).toList();
  return DirectionAreaSummary(
    area: DirectionSummaryArea.gerencia,
    basis: 'Plan vigente y avance semanal hasta el corte',
    metrics: [
      _count(
        'Pacas producidas del plan',
        current.actual('Produccion'),
        previous.actual('Produccion'),
      ),
      _count(
        'Pacas embarcadas del plan',
        current.actual('Embarque'),
        previous.actual('Embarque'),
      ),
      _count('Metas definidas', withTarget.length),
      _count(
        'Metas alcanzadas',
        withTarget.where((g) => g.actual >= g.target!).length,
      ),
      _count(
        'Frentes sin meta',
        current.goals.where((g) => !g.hasTarget).length,
      ),
    ],
    alerts: [
      if (!current.bundle.hasPlan) 'No hay plan de metas para esta semana.',
      if (current.bundle.unmappedProductionCodes.isNotEmpty ||
          current.bundle.unmappedShipmentCodes.isNotEmpty)
        'Hay materiales de producción o salida fuera del catálogo de metas; no están incluidos en los avances del plan.',
      for (final g in current.priorities)
        '${g.front} · ${g.material}: ${g.state}.',
    ],
    notes: [
      'Se conserva la duración del plan de Gerencia; avance acumulado hasta el corte de viernes. Sin meta no equivale a 0% de cumplimiento.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionInventory(
  List<Map<String, dynamic>> general,
  List<Map<String, dynamic>> commercial,
) {
  double kg(List<Map<String, dynamic>> rows) =>
      rows.fold(0, (s, r) => s + _number(r['on_hand_kg']));
  final negative = [
    ...general,
    ...commercial,
  ].where((r) => _number(r['on_hand_kg']) < 0).length;
  return DirectionAreaSummary(
    area: DirectionSummaryArea.inventario,
    basis: 'Existencia actual del sistema; no cierre histórico',
    metrics: [
      _kg('Existencia en nivel general', kg(general)),
      _kg('Existencia en nivel comercial', kg(commercial)),
      _count('Materiales generales', general.length),
      _count('Materiales comerciales', commercial.length),
      _count('Materiales con saldo negativo', negative),
    ],
    alerts: [
      if (negative > 0)
        '$negative materiales tienen saldo negativo; revisar movimientos y transformaciones.',
    ],
    notes: [
      'Los dos niveles se presentan por separado: no sumarlos como inventario total. No sustituye el conteo físico de patio.',
      'Catálogos de materiales soportan esta lectura; directorios y catálogos se integran en sus áreas.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionWarehouse(
  List<Map<String, dynamic>> rows,
) {
  final active = rows.where((r) => r['is_active'] != false).toList();
  final low = active
      .where((r) => _number(r['current_stock']) <= _number(r['minimum_stock']))
      .toList();
  final empty = active.where((r) => _number(r['current_stock']) <= 0).length;
  return DirectionAreaSummary(
    area: DirectionSummaryArea.almacen,
    basis: 'Existencias actuales de artículos activos',
    metrics: [
      _count('Artículos activos', active.length),
      _count('En mínimo o bajo mínimo', low.length),
      _count('Sin existencias', empty),
    ],
    alerts: [
      if (low.isNotEmpty)
        '${low.length} artículos requieren revisar reposición; $empty sin existencias.',
    ],
    notes: [
      'No se suman unidades de artículos distintos. Movimientos y cortes mantienen su detalle en Almacén.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionShipments(
  List<DirectionShipmentPlanRecord> rows,
  AccountingWeeklyCut cut,
) {
  final current = rows.where((r) => cut.contains(r.shipDate)).toList();
  final previous = rows
      .where((r) => cut.contains(r.shipDate, prior: true))
      .toList();
  int units(
    List<DirectionShipmentPlanRecord> records,
    DirectionShipmentQuantityUnit unit,
    bool shipped,
  ) => records
      .where(
        (r) =>
            !r.isCancelled && r.quantityUnit == unit && r.isShipped == shipped,
      )
      .fold(0, (s, r) => s + r.plannedQuantity);
  final pending = current.where((r) => r.isActive).length;
  return DirectionAreaSummary(
    area: DirectionSummaryArea.embarques,
    basis: 'Fecha de embarque del corte; estatus actual',
    metrics: [
      _count(
        'Embarques programados',
        current.where((r) => !r.isCancelled).length,
        previous.where((r) => !r.isCancelled).length,
      ),
      _count(
        'Pacas marcadas embarcadas',
        units(current, DirectionShipmentQuantityUnit.bales, true),
        units(previous, DirectionShipmentQuantityUnit.bales, true),
      ),
      _kg(
        'Kg a granel marcados embarcados',
        units(current, DirectionShipmentQuantityUnit.kilograms, true),
        units(previous, DirectionShipmentQuantityUnit.kilograms, true),
      ),
      _count('Embarques pendientes', pending),
      _count('Cancelados', current.where((r) => r.isCancelled).length),
    ],
    alerts: [
      if (pending > 0) '$pending embarques del corte siguen pendientes.',
    ],
    notes: [
      'Cantidades de la planeación marcadas como embarcadas; no equivalen a peso certificado de Báscula. Pacas y kilos no se mezclan.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionVault(
  List<DirectionVaultVoucherRecord> rows,
  AccountingWeeklyCut cut,
) {
  final current = rows.where((r) => cut.contains(r.date)).toList();
  final previous = rows
      .where((r) => cut.contains(r.date, prior: true))
      .toList();
  double sum(List<DirectionVaultVoucherRecord> items, String type) =>
      items.where((r) => r.type == type).fold(0, (s, r) => s + r.total);
  final incomplete = current.where((r) => r.lines.isEmpty).length;
  return DirectionAreaSummary(
    area: DirectionSummaryArea.boveda,
    basis: 'Vales fechados en la semana',
    metrics: [
      _money(
        'Entradas registradas',
        sum(current, 'deposit'),
        sum(previous, 'deposit'),
      ),
      _money(
        'Salidas registradas',
        sum(current, 'expense'),
        sum(previous, 'expense'),
      ),
      _money(
        'Flujo neto de vales',
        sum(current, 'deposit') - sum(current, 'expense'),
        sum(previous, 'deposit') - sum(previous, 'expense'),
      ),
      _count('Vales', current.length, previous.length),
      _count('Vales sin partidas', incomplete),
    ],
    alerts: [
      if (incomplete > 0)
        '$incomplete vales sin partidas; los importes son parciales.',
    ],
    notes: [
      'Entradas y salidas registradas en Bóveda. Incluye traspasos: no sumar este flujo a ventas ni a utilidad contable.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionFinance(
  List<FinanzasBankMovementRecord> movements,
  List<Map<String, dynamic>> invoices,
  AccountingWeeklyCut cut,
  DateTime generatedAt,
) {
  final current = movements.where((r) => cut.contains(r.date)).toList();
  final previous = movements
      .where((r) => cut.contains(r.date, prior: true))
      .toList();
  double credits(List<FinanzasBankMovementRecord> rows) =>
      rows.fold(0, (s, r) => s + r.creditAmount);
  double debits(List<FinanzasBankMovementRecord> rows) =>
      rows.fold(0, (s, r) => s + r.debitAmount);
  final today = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
  final open = invoices
      .where(
        (r) => _number(r['balance_amount']) > .009 && r['status'] != 'PAGADA',
      )
      .toList();
  final overdue = open.where((r) {
    final date = DateTime.tryParse('${r['due_date']}');
    return date != null && date.isBefore(today);
  }).toList();
  double amount(List<Map<String, dynamic>> rows) =>
      rows.fold(0, (s, r) => s + _number(r['balance_amount']));
  return DirectionAreaSummary(
    area: DirectionSummaryArea.finanzas,
    basis: 'Flujo semanal y facturas por pagar actuales',
    metrics: [
      _money('Abonos bancarios', credits(current), credits(previous)),
      _money('Cargos bancarios', debits(current), debits(previous)),
      _money(
        'Flujo bancario neto',
        credits(current) - debits(current),
        credits(previous) - debits(previous),
      ),
      _money('Saldo actual de facturas por pagar', amount(open)),
      _money('Facturas vencidas: saldo actual', amount(overdue)),
      _count('Facturas vencidas', overdue.length),
    ],
    alerts: [
      if (overdue.isNotEmpty)
        '${overdue.length} facturas vencidas por ${directionSummaryMoney(amount(overdue))}; revisar pago o convenio.',
    ],
    notes: [
      'Abonos/cargos incluyen movimientos internos; flujo bancario no equivale a resultado contable.',
      'Facturas por pagar no es deuda total ni presupuesto disponible. Reservas, convenios y programación se detallan en Finanzas.',
    ],
  );
}

DirectionAreaSummary summarizeDirectionHistory(
  List<ManagementReportRunRecord> rows,
  AccountingWeeklyCut cut,
) {
  final friday = rows
      .where(
        (r) =>
            r.frequency == ManagementReportFrequency.weeklyFriday &&
            cut.contains(r.generatedAt) &&
            r.areaKey != ManagementAreaKey.direccionGeneral,
      )
      .toList();
  final reported = friday.map((r) => r.areaKey).toSet();
  final expected = managementAreaCatalog
      .where(
        (a) =>
            a.key != ManagementAreaKey.direccionGeneral &&
            a.reportsFor(ManagementReportFrequency.weeklyFriday).isNotEmpty,
      )
      .toList();
  return DirectionAreaSummary(
    area: DirectionSummaryArea.supervision,
    basis: 'Historial de este dispositivo, hasta 60 registros',
    metrics: [
      DirectionSummaryMetric(
        'Áreas con PDF de viernes en historial',
        '${reported.length} / ${expected.length}',
      ),
      _count('PDF de viernes generados en el corte', friday.length),
      _count(
        'PDF diarios generados en el corte',
        rows
            .where(
              (r) =>
                  r.frequency == ManagementReportFrequency.daily &&
                  cut.contains(r.generatedAt),
            )
            .length,
      ),
    ],
    notes: [
      'No acredita entrega ni cumplimiento corporativo. Un reporte puede haberse generado en otro dispositivo.',
      'Este consolidado consulta las bases aunque las áreas no hayan generado sus PDFs individuales. El PDF actual se registra después de guardarse.',
    ],
  );
}
