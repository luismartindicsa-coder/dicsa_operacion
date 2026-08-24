import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../direction/analysis/menudeo/menudeo_analysis_models.dart';
import '../direction/analysis/menudeo/menudeo_analysis_repository.dart';
import '../finanzas/finanzas_bank_accounts_store.dart';
import '../finanzas/finanzas_provider_accounts_store.dart';
import '../shared/direction_vault/direction_vault_repository.dart';

class ContabilidadPeriodicFlowDataset {
  final DateTimeRange range;
  final double invoicedAmount;
  final int invoiceCount;
  final double paidOnTimeAmount;
  final double paidLateAmount;
  final double paidHistoricalOverdueAmount;
  final int paidHistoricalOverdueCount;
  final double pendingAmount;
  final int pendingInvoiceCount;
  final int unlinkedPaymentCount;
  final List<ContabilidadPeriodicFlowRow> rows;

  const ContabilidadPeriodicFlowDataset({
    required this.range,
    required this.invoicedAmount,
    required this.invoiceCount,
    required this.paidOnTimeAmount,
    required this.paidLateAmount,
    required this.paidHistoricalOverdueAmount,
    required this.paidHistoricalOverdueCount,
    required this.pendingAmount,
    required this.pendingInvoiceCount,
    required this.unlinkedPaymentCount,
    required this.rows,
  });

  double get paidAmount => paidOnTimeAmount + paidLateAmount;
  double get periodNet => invoicedAmount - paidAmount;
}

class ContabilidadPeriodicFlowRow {
  final String folio;
  final String provider;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double invoicedAmount;
  final double paidAmount;
  final double pendingAmount;
  final bool hasLatePayment;

  const ContabilidadPeriodicFlowRow({
    required this.folio,
    required this.provider,
    required this.invoiceDate,
    required this.dueDate,
    required this.invoicedAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.hasLatePayment,
  });
}

class ContabilidadPeriodicIncomeDataset {
  final double invoicedAmount;
  final int invoiceCount;
  final double collectedCurrentAmount;
  final double pendingAmount;
  final int pendingInvoiceCount;
  final double collectedHistoricalOverdueAmount;
  final int collectedHistoricalOverdueCount;
  final int unlinkedCollectionCount;

  const ContabilidadPeriodicIncomeDataset({
    required this.invoicedAmount,
    required this.invoiceCount,
    required this.collectedCurrentAmount,
    required this.pendingAmount,
    required this.pendingInvoiceCount,
    required this.collectedHistoricalOverdueAmount,
    required this.collectedHistoricalOverdueCount,
    required this.unlinkedCollectionCount,
  });
}

class ContabilidadPeriodicOperationalDataset {
  final double vaultInflows;
  final double vaultOutflows;
  final double vaultInternalTransfers;
  final double cashInflows;
  final double cashOutflows;

  const ContabilidadPeriodicOperationalDataset({
    required this.vaultInflows,
    required this.vaultOutflows,
    required this.vaultInternalTransfers,
    required this.cashInflows,
    required this.cashOutflows,
  });

  double get operationalNet =>
      vaultInflows + cashInflows - vaultOutflows - cashOutflows;
}

class ContabilidadFlowDataset {
  final DateTimeRange? range;
  final ContabilidadFlowSnapshot snapshot;
  final List<ContabilidadFlowSourceRow> sources;
  final List<ContabilidadFlowTimelinePoint> timeline;
  final List<ContabilidadFlowBreakdownRow> bankCategoryRows;
  final List<ContabilidadFlowBreakdownRow> cashRubricRows;
  final List<ContabilidadFlowAuditNote> auditNotes;
  final List<String> notes;

  const ContabilidadFlowDataset({
    required this.range,
    required this.snapshot,
    required this.sources,
    required this.timeline,
    required this.bankCategoryRows,
    required this.cashRubricRows,
    required this.auditNotes,
    required this.notes,
  });
}

enum ContabilidadFlowAuditLevel { ok, warning, risk }

class ContabilidadFlowAuditNote {
  final ContabilidadFlowAuditLevel level;
  final String title;
  final String detail;

  const ContabilidadFlowAuditNote({
    required this.level,
    required this.title,
    required this.detail,
  });
}

class ContabilidadFlowSnapshot {
  final double realInflows;
  final double realOutflows;
  final double realNetFlow;
  final double internalTransfers;
  final double bankNetFlow;
  final double cashNetFlow;
  final int movementCount;

  const ContabilidadFlowSnapshot({
    required this.realInflows,
    required this.realOutflows,
    required this.realNetFlow,
    required this.internalTransfers,
    required this.bankNetFlow,
    required this.cashNetFlow,
    required this.movementCount,
  });
}

class ContabilidadFlowSourceRow {
  final String label;
  final String detail;
  final double realInflows;
  final double realOutflows;
  final double internalTransfers;

  const ContabilidadFlowSourceRow({
    required this.label,
    required this.detail,
    required this.realInflows,
    required this.realOutflows,
    required this.internalTransfers,
  });

  double get netFlow => realInflows - realOutflows;
}

class ContabilidadFlowTimelinePoint {
  final DateTime date;
  final double realInflows;
  final double realOutflows;
  final double internalTransfers;

  const ContabilidadFlowTimelinePoint({
    required this.date,
    required this.realInflows,
    required this.realOutflows,
    required this.internalTransfers,
  });

  double get netFlow => realInflows - realOutflows;
}

class ContabilidadFlowBreakdownRow {
  final String label;
  final double total;
  final int count;
  final double share;

  const ContabilidadFlowBreakdownRow({
    required this.label,
    required this.total,
    required this.count,
    required this.share,
  });
}

class ContabilidadFlowAnalysisStore {
  const ContabilidadFlowAnalysisStore();

  /// Reads only invoices issued in the selected period. Payments are counted
  /// only when their bank movement is explicitly linked to one of those
  /// invoices and also happened within that same period.
  Future<ContabilidadPeriodicFlowDataset> loadPeriodic({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) async {
    final range = _resolveRange(windowDays: windowDays, dateRange: dateRange);
    final results = await Future.wait<dynamic>([
      FinanzasProviderAccountsStore.loadInvoices(),
      FinanzasBankAccountsStore.loadMovementsStrict(),
    ]);
    final invoices = results[0] as List<FinanzasSupplierInvoiceRecord>;
    final movements = results[1] as List<FinanzasBankMovementRecord>;
    final periodInvoices = invoices
        .where(
          (invoice) =>
              _withinRange(invoice.invoiceDate, range) &&
              !_isExcludedSupplierInvoice(invoice),
        )
        .toList(growable: false);
    final invoicesById = <String, FinanzasSupplierInvoiceRecord>{
      for (final invoice in invoices) invoice.id: invoice,
    };
    final invoiceIds = periodInvoices.map((invoice) => invoice.id).toSet();
    final paymentsByInvoiceId = <String, List<FinanzasBankMovementRecord>>{};
    var unlinkedPaymentCount = 0;
    var paidHistoricalOverdueAmount = 0.0;
    var paidHistoricalOverdueCount = 0;

    for (final movement in movements) {
      if (!_withinRange(movement.date, range) || movement.debitAmount <= 0) {
        continue;
      }
      if (movement.sourceType != 'COMPRA_FACTURA') continue;
      final invoiceId = movement.linkedSupplierInvoiceId?.trim() ?? '';
      if (invoiceId.isEmpty) {
        unlinkedPaymentCount++;
        continue;
      }
      if (invoiceIds.contains(invoiceId)) {
        paymentsByInvoiceId.putIfAbsent(invoiceId, () => []).add(movement);
        continue;
      }
      final invoice = invoicesById[invoiceId];
      final dueDate = invoice?.dueDate;
      if (invoice != null &&
          _dateOnly(invoice.invoiceDate).isBefore(_dateOnly(range.start)) &&
          dueDate != null &&
          _dateOnly(movement.date).isAfter(_dateOnly(dueDate))) {
        paidHistoricalOverdueAmount += movement.effectiveSupplierAppliedAmount;
        paidHistoricalOverdueCount++;
      }
    }

    var invoicedAmount = 0.0;
    var paidOnTimeAmount = 0.0;
    var paidLateAmount = 0.0;
    var pendingAmount = 0.0;
    var pendingInvoiceCount = 0;
    final rows = <ContabilidadPeriodicFlowRow>[];
    for (final invoice in periodInvoices) {
      final payments = paymentsByInvoiceId[invoice.id] ?? const [];
      var paidForInvoice = 0.0;
      var hasLatePayment = false;
      for (final payment in payments) {
        final applied = payment.effectiveSupplierAppliedAmount;
        if (applied <= 0) continue;
        paidForInvoice += applied;
        final dueDate = invoice.dueDate;
        final late =
            dueDate != null &&
            _dateOnly(payment.date).isAfter(_dateOnly(dueDate));
        if (late) {
          paidLateAmount += applied;
          hasLatePayment = true;
        } else {
          paidOnTimeAmount += applied;
        }
      }
      final pending = (invoice.totalAmount - paidForInvoice).clamp(
        0.0,
        double.infinity,
      );
      invoicedAmount += invoice.totalAmount;
      pendingAmount += pending;
      if (pending > 0.009) pendingInvoiceCount++;
      rows.add(
        ContabilidadPeriodicFlowRow(
          folio: invoice.folio,
          provider: invoice.providerNameSnapshot,
          invoiceDate: _dateOnly(invoice.invoiceDate),
          dueDate: invoice.dueDate == null ? null : _dateOnly(invoice.dueDate!),
          invoicedAmount: invoice.totalAmount,
          paidAmount: paidForInvoice,
          pendingAmount: pending,
          hasLatePayment: hasLatePayment,
        ),
      );
    }
    rows.sort((a, b) => b.invoicedAmount.compareTo(a.invoicedAmount));
    return ContabilidadPeriodicFlowDataset(
      range: range,
      invoicedAmount: invoicedAmount,
      invoiceCount: periodInvoices.length,
      paidOnTimeAmount: paidOnTimeAmount,
      paidLateAmount: paidLateAmount,
      paidHistoricalOverdueAmount: paidHistoricalOverdueAmount,
      paidHistoricalOverdueCount: paidHistoricalOverdueCount,
      pendingAmount: pendingAmount,
      pendingInvoiceCount: pendingInvoiceCount,
      unlinkedPaymentCount: unlinkedPaymentCount,
      rows: rows,
    );
  }

  /// Sales invoices live in Mayoreo accounts. Collections are accepted only
  /// from bank credits linked to the same account, so unlinked credits never
  /// inflate the period's collection metric.
  Future<ContabilidadPeriodicIncomeDataset> loadPeriodicIncome({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) async {
    final range = _resolveRange(windowDays: windowDays, dateRange: dateRange);
    final results = await Future.wait<dynamic>([
      Supabase.instance.client
          .from('mayoreo_accounts')
          .select(
            'id,operation_type,status,approved_amount,document_number,document_date,estimated_payment_date',
          ),
      FinanzasBankAccountsStore.loadMovementsStrict(),
    ]);
    final accountRows = (results[0] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final movements = results[1] as List<FinanzasBankMovementRecord>;
    final accountsById = <String, Map<String, dynamic>>{
      for (final row in accountRows) (row['id'] ?? '').toString(): row,
    };
    final periodAccountIds = <String>{};
    var invoicedAmount = 0.0;
    var invoiceCount = 0;
    for (final row in accountRows) {
      if ((row['operation_type'] ?? 'factura').toString().toLowerCase() !=
          'factura') {
        continue;
      }
      if ((row['status'] ?? '').toString().toLowerCase() == 'cancelada') {
        continue;
      }
      if ((row['document_number'] ?? '').toString().trim().isEmpty) {
        continue;
      }
      final invoiceDate = _parseRemoteDate(row['document_date']);
      if (invoiceDate == null || !_withinRange(invoiceDate, range)) continue;
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;
      periodAccountIds.add(id);
      invoiceCount++;
      invoicedAmount += ((row['approved_amount'] as num?) ?? 0).toDouble();
    }

    final collectedByAccountId = <String, double>{};
    var historicalOverdueAmount = 0.0;
    var historicalOverdueCount = 0;
    var unlinkedCollectionCount = 0;
    for (final movement in movements) {
      if (!_withinRange(movement.date, range) || movement.creditAmount <= 0) {
        continue;
      }
      if (movement.sourceType != 'VENTA_FACTURA') continue;
      final accountId = movement.linkedExternalRef?.trim() ?? '';
      if (accountId.isEmpty) {
        unlinkedCollectionCount++;
        continue;
      }
      if (periodAccountIds.contains(accountId)) {
        collectedByAccountId.update(
          accountId,
          (value) => value + movement.creditAmount,
          ifAbsent: () => movement.creditAmount,
        );
        continue;
      }
      final account = accountsById[accountId];
      if (account == null) continue;
      if ((account['operation_type'] ?? 'factura').toString().toLowerCase() !=
              'factura' ||
          (account['status'] ?? '').toString().toLowerCase() == 'cancelada' ||
          (account['document_number'] ?? '').toString().trim().isEmpty) {
        continue;
      }
      final invoiceDate = _parseRemoteDate(account['document_date']);
      final dueDate = _parseRemoteDate(account['estimated_payment_date']);
      if (invoiceDate != null &&
          _dateOnly(invoiceDate).isBefore(_dateOnly(range.start)) &&
          dueDate != null &&
          _dateOnly(movement.date).isAfter(_dateOnly(dueDate))) {
        historicalOverdueAmount += movement.creditAmount;
        historicalOverdueCount++;
      }
    }

    var collectedCurrentAmount = 0.0;
    var pendingAmount = 0.0;
    var pendingInvoiceCount = 0;
    for (final row in accountRows) {
      final id = (row['id'] ?? '').toString();
      if (!periodAccountIds.contains(id)) continue;
      final approved = ((row['approved_amount'] as num?) ?? 0).toDouble();
      final collected = collectedByAccountId[id] ?? 0.0;
      collectedCurrentAmount += collected;
      final pending = (approved - collected).clamp(0.0, double.infinity);
      pendingAmount += pending;
      if (pending > 0.009) pendingInvoiceCount++;
    }
    return ContabilidadPeriodicIncomeDataset(
      invoicedAmount: invoicedAmount,
      invoiceCount: invoiceCount,
      collectedCurrentAmount: collectedCurrentAmount,
      pendingAmount: pendingAmount,
      pendingInvoiceCount: pendingInvoiceCount,
      collectedHistoricalOverdueAmount: historicalOverdueAmount,
      collectedHistoricalOverdueCount: historicalOverdueCount,
      unlinkedCollectionCount: unlinkedCollectionCount,
    );
  }

  Future<ContabilidadPeriodicOperationalDataset> loadPeriodicOperational({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) async {
    final range = _resolveRange(windowDays: windowDays, dateRange: dateRange);
    final results = await Future.wait<dynamic>([
      DirectionVaultRepository.instance.loadVouchers(),
      MenudeoAnalysisRepository().loadCashDataset(
        windowDays: windowDays,
        dateRange: dateRange,
      ),
    ]);
    final vaultRows = results[0] as List<DirectionVaultVoucherRecord>;
    final cash = results[1] as MenudeoCashDataset;
    var vaultInflows = 0.0;
    var vaultOutflows = 0.0;
    var vaultInternalTransfers = 0.0;
    for (final row in vaultRows) {
      if (!_withinRange(row.date, range)) continue;
      if (_isExcludedVaultVoucher(row)) continue;
      if (_isInternalVaultMovement(row)) {
        vaultInternalTransfers += row.total;
      } else if (row.type == 'deposit') {
        vaultInflows += row.total;
      } else {
        vaultOutflows += row.total;
      }
    }
    return ContabilidadPeriodicOperationalDataset(
      vaultInflows: vaultInflows,
      vaultOutflows: vaultOutflows,
      vaultInternalTransfers: vaultInternalTransfers,
      cashInflows: cash.snapshot.deposits,
      cashOutflows: cash.snapshot.expenses,
    );
  }

  Future<ContabilidadFlowDataset> load({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) async {
    final range = _resolveRange(windowDays: windowDays, dateRange: dateRange);
    final results = await Future.wait<dynamic>([
      FinanzasBankAccountsStore.loadMovementsStrict(),
      DirectionVaultRepository.instance.loadVouchers(),
      MenudeoAnalysisRepository().loadCashDataset(
        windowDays: windowDays,
        dateRange: dateRange,
      ),
    ]);

    final bankRows = results[0] as List<FinanzasBankMovementRecord>;
    final vaultRows = results[1] as List<DirectionVaultVoucherRecord>;
    final menudeoCash = results[2] as MenudeoCashDataset;

    final timeline =
        <DateTime, ({double inflows, double outflows, double internal})>{};
    final bankCategories = <String, ({double total, int count})>{};
    final cashRubrics = <String, ({double total, int count})>{};
    final auditNotes = <ContabilidadFlowAuditNote>[
      const ContabilidadFlowAuditNote(
        level: ContabilidadFlowAuditLevel.ok,
        title: 'Bancos',
        detail:
            'La fuente viene de movimientos transaccionales de Finanzas y ahora falla si no responde.',
      ),
      const ContabilidadFlowAuditNote(
        level: ContabilidadFlowAuditLevel.ok,
        title: 'Bóveda',
        detail:
            'La fuente ya sale de movimientos transaccionales de Bóveda y conserva detalle por voucher y por renglón.',
      ),
      const ContabilidadFlowAuditNote(
        level: ContabilidadFlowAuditLevel.ok,
        title: 'Menudeo',
        detail:
            'La caja operativa ya entra separando depósitos, egresos e internos para no inflar salidas.',
      ),
    ];

    var bankRealInflows = 0.0;
    var bankRealOutflows = 0.0;
    var bankInternal = 0.0;
    var bankMovementCount = 0;
    var bankHeuristicInternalCount = 0;

    for (final row in bankRows) {
      if (!_withinRange(row.date, range)) continue;
      bankMovementCount++;
      final amount = row.creditAmount > 0 ? row.creditAmount : row.debitAmount;
      final date = _dateOnly(row.date);
      final internalReason = _internalBankMovementReason(row);
      if (internalReason != null) {
        bankInternal += amount;
        if (internalReason ==
            _BankInternalReason.heuristicCounterpartyTransfer) {
          bankHeuristicInternalCount++;
        }
        _accumulateTimeline(timeline, date: date, internal: amount);
        continue;
      }

      if (row.creditAmount > 0) {
        bankRealInflows += row.creditAmount;
        _accumulateTimeline(timeline, date: date, inflows: row.creditAmount);
      }
      if (row.debitAmount > 0) {
        final category = row.category.trim().isEmpty
            ? 'Sin categoría'
            : row.category.trim();
        final current = bankCategories[category] ?? (total: 0.0, count: 0);
        bankCategories[category] = (
          total: current.total + row.debitAmount,
          count: current.count + 1,
        );
        bankRealOutflows += row.debitAmount;
        _accumulateTimeline(timeline, date: date, outflows: row.debitAmount);
      }
    }

    var vaultRealInflows = 0.0;
    var vaultRealOutflows = 0.0;
    var vaultInternal = 0.0;
    var vaultMovementCount = 0;

    for (final row in vaultRows) {
      if (!_withinRange(row.date, range)) continue;
      if (_isExcludedVaultVoucher(row)) continue;
      vaultMovementCount++;
      final date = _dateOnly(row.date);
      if (_isInternalVaultMovement(row)) {
        vaultInternal += row.total;
        _accumulateTimeline(timeline, date: date, internal: row.total);
        continue;
      }

      final rubric = row.rubric.trim().isEmpty
          ? 'Sin rubro'
          : row.rubric.trim();
      final current = cashRubrics[rubric] ?? (total: 0.0, count: 0);
      cashRubrics[rubric] = (
        total: current.total + row.total,
        count: current.count + 1,
      );

      if (row.type == 'deposit') {
        vaultRealInflows += row.total;
        _accumulateTimeline(timeline, date: date, inflows: row.total);
      } else {
        vaultRealOutflows += row.total;
        _accumulateTimeline(timeline, date: date, outflows: row.total);
      }
    }

    final menudeoRealInflows = menudeoCash.timeline.fold<double>(
      0,
      (sum, point) => sum + point.deposits,
    );
    final menudeoRealOutflows = menudeoCash.timeline.fold<double>(
      0,
      (sum, point) => sum + point.expenses,
    );
    final menudeoMovementCount = menudeoCash.rubricRows.fold<int>(
      0,
      (sum, row) => sum + row.count,
    );

    for (final point in menudeoCash.timeline) {
      _accumulateTimeline(
        timeline,
        date: _dateOnly(point.date),
        inflows: point.deposits,
        outflows: point.expenses,
      );
    }

    for (final row in menudeoCash.expenseRubricRows.take(12)) {
      final current = cashRubrics[row.label] ?? (total: 0.0, count: 0);
      cashRubrics[row.label] = (
        total: current.total + row.total,
        count: current.count + row.count,
      );
    }

    final realInflows = bankRealInflows + vaultRealInflows + menudeoRealInflows;
    final realOutflows =
        bankRealOutflows + vaultRealOutflows + menudeoRealOutflows;
    final internalTransfers = bankInternal + vaultInternal;
    final bankNetFlow = bankRealInflows - bankRealOutflows;
    final cashNetFlow =
        (vaultRealInflows + menudeoRealInflows) -
        (vaultRealOutflows + menudeoRealOutflows);

    final timelineRows =
        timeline.entries
            .map(
              (entry) => ContabilidadFlowTimelinePoint(
                date: entry.key,
                realInflows: entry.value.inflows,
                realOutflows: entry.value.outflows,
                internalTransfers: entry.value.internal,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    final totalBreakdownBase = realOutflows <= 0 ? 1.0 : realOutflows;
    final bankCategoryRows =
        bankCategories.entries
            .map(
              (entry) => ContabilidadFlowBreakdownRow(
                label: entry.key,
                total: entry.value.total,
                count: entry.value.count,
                share: entry.value.total / totalBreakdownBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.total.compareTo(a.total));
    final cashRubricRows =
        cashRubrics.entries
            .map(
              (entry) => ContabilidadFlowBreakdownRow(
                label: entry.key,
                total: entry.value.total,
                count: entry.value.count,
                share: entry.value.total / totalBreakdownBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.total.compareTo(a.total));

    final notes = <String>[
      'Flujo General consolida bancos, bóveda y menudeo para leer liquidez del periodo; no representa utilidad por sí solo.',
      'Los movimientos internos se muestran aparte para no inflar entradas o salidas reales.',
      'Menudeo aporta el desglose fino del efectivo operativo porque ahí viven los rubros y conceptos más aterrizados.',
    ];
    if (vaultInternal > 0) {
      notes.add(
        'Bóveda aporta el tránsito de efectivo; traspasos a caja permanecen como movimiento interno, no como gasto real.',
      );
    }
    if (menudeoCash.snapshot.cutsWithDifference > 0) {
      notes.add(
        'Se detectaron ${menudeoCash.snapshot.cutsWithDifference} cortes con diferencia en menudeo dentro de la ventana filtrada.',
      );
    }
    if (menudeoCash.snapshot.pendingChecks > 0) {
      notes.add(
        'Hay ${menudeoCash.snapshot.pendingChecks} checks pendientes en cortes de caja del periodo.',
      );
    }
    if (bankHeuristicInternalCount > 0) {
      auditNotes.add(
        ContabilidadFlowAuditNote(
          level: ContabilidadFlowAuditLevel.warning,
          title: 'Internos por contexto',
          detail:
              'Se excluyeron $bankHeuristicInternalCount movimiento(s) bancario(s) como internos por contexto de traspaso entre caja y bóveda, no solo por categoría.',
        ),
      );
    }

    return ContabilidadFlowDataset(
      range: range,
      snapshot: ContabilidadFlowSnapshot(
        realInflows: realInflows,
        realOutflows: realOutflows,
        realNetFlow: realInflows - realOutflows,
        internalTransfers: internalTransfers,
        bankNetFlow: bankNetFlow,
        cashNetFlow: cashNetFlow,
        movementCount:
            bankMovementCount + vaultMovementCount + menudeoMovementCount,
      ),
      sources: [
        ContabilidadFlowSourceRow(
          label: 'Bancos',
          detail: 'Finanzas · cuentas bancarias',
          realInflows: bankRealInflows,
          realOutflows: bankRealOutflows,
          internalTransfers: bankInternal,
        ),
        ContabilidadFlowSourceRow(
          label: 'Bóveda',
          detail: 'Dirección · efectivo concentrado',
          realInflows: vaultRealInflows,
          realOutflows: vaultRealOutflows,
          internalTransfers: vaultInternal,
        ),
        ContabilidadFlowSourceRow(
          label: 'Menudeo',
          detail: 'Caja operativa ya depurada',
          realInflows: menudeoRealInflows,
          realOutflows: menudeoRealOutflows,
          internalTransfers: 0,
        ),
      ],
      timeline: timelineRows,
      bankCategoryRows: bankCategoryRows,
      cashRubricRows: cashRubricRows,
      auditNotes: auditNotes,
      notes: notes,
    );
  }

  DateTimeRange _resolveRange({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) {
    if (dateRange != null) return dateRange;
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: windowDays - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return DateTimeRange(start: start, end: end);
  }

  _BankInternalReason? _internalBankMovementReason(
    FinanzasBankMovementRecord row,
  ) {
    final category = _normalize(row.category);
    if (category == 'MOVIMIENTOS INTERNOS') {
      return _BankInternalReason.explicitCategory;
    }
    final comment = _normalize(row.comment);
    final reference = _normalize(row.reference);
    final counterparty = _normalize(row.counterpartyNameSnapshot);
    final mentionsCashArea =
        counterparty.contains('BOVEDA') ||
        counterparty.contains('CAJA') ||
        counterparty.contains('MENUDEO');
    final mentionsInternalContext =
        comment.contains('INTERNO') ||
        comment.contains('TRASPASO') ||
        comment.contains('REPOSICION') ||
        reference.contains('INTERNO') ||
        reference.contains('TRASPASO') ||
        reference.contains('REPOSICION');
    if (mentionsCashArea && mentionsInternalContext) {
      return _BankInternalReason.heuristicCounterpartyTransfer;
    }
    return null;
  }

  bool _isInternalVaultMovement(DirectionVaultVoucherRecord row) {
    final rubricNormalized = _normalize(row.rubric);
    if (rubricNormalized == 'REPOSICION DE FONDO') return true;
    if (rubricNormalized == 'MOVIMIENTOS INTERNOS') return true;
    for (final line in row.lines) {
      final values = <String>[
        line.concept,
        line.subconcept,
        line.destination,
        line.comment,
      ];
      for (final value in values) {
        final normalized = _normalize(value);
        if (normalized == 'BOVEDA') return true;
        if (normalized == 'CAJA GRANDE') return true;
        if (normalized.contains('TRANSFERENCIA')) return true;
        if (normalized.contains('INTERNO')) return true;
      }
    }
    return false;
  }

  bool _isExcludedSupplierInvoice(FinanzasSupplierInvoiceRecord invoice) {
    return _normalize(
      invoice.providerNameSnapshot,
    ).contains('MARICRUZ QUIROGA');
  }

  bool _isExcludedVaultVoucher(DirectionVaultVoucherRecord row) {
    final values = <String>[row.person, row.comment];
    for (final line in row.lines) {
      values.addAll(<String>[
        line.concept,
        line.company,
        line.driver,
        line.destination,
        line.subconcept,
        line.comment,
      ]);
    }
    return values.any((value) {
      final normalized = _normalize(value);
      return normalized.contains('BIANCA') ||
          normalized.contains('MARICRUZ QUIROGA');
    });
  }

  bool _withinRange(DateTime value, DateTimeRange range) {
    final current = DateTime(value.year, value.month, value.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !current.isBefore(start) && !current.isAfter(end);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime? _parseRemoteDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  void _accumulateTimeline(
    Map<DateTime, ({double inflows, double outflows, double internal})>
    timeline, {
    required DateTime date,
    double inflows = 0,
    double outflows = 0,
    double internal = 0,
  }) {
    final current =
        timeline[date] ?? (inflows: 0.0, outflows: 0.0, internal: 0.0);
    timeline[date] = (
      inflows: current.inflows + inflows,
      outflows: current.outflows + outflows,
      internal: current.internal + internal,
    );
  }

  String _normalize(String value) {
    const accents = <String, String>{
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'á': 'A',
      'à': 'A',
      'ä': 'A',
      'â': 'A',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'é': 'E',
      'è': 'E',
      'ë': 'E',
      'ê': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'í': 'I',
      'ì': 'I',
      'ï': 'I',
      'î': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'ó': 'O',
      'ò': 'O',
      'ö': 'O',
      'ô': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'ú': 'U',
      'ù': 'U',
      'ü': 'U',
      'û': 'U',
      'Ñ': 'N',
      'ñ': 'N',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      buffer.write(
        accents[String.fromCharCode(rune)] ?? String.fromCharCode(rune),
      );
    }
    return buffer.toString().trim().toUpperCase();
  }
}

class ContabilidadFlowSourceException implements Exception {
  final String message;

  const ContabilidadFlowSourceException(this.message);

  @override
  String toString() => message;
}

enum _BankInternalReason { explicitCategory, heuristicCounterpartyTransfer }
