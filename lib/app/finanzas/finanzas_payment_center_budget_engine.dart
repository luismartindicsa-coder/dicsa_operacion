import '../compras/compras_tickets_store.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_company_identity.dart';
import 'finanzas_financial_rules.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_payment_center_budget_models.dart';
import 'finanzas_payment_center_reserves_store.dart';
import 'finanzas_provider_accounts_store.dart';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Map<String, double> computeFinanzasPaymentCenterBalances(
  List<FinanzasBankMovementRecord> rows,
) {
  final map = <String, double>{};
  for (final row in rows) {
    map.update(
      row.accountKey,
      (value) => value + row.creditAmount - row.debitAmount,
      ifAbsent: () => row.creditAmount - row.debitAmount,
    );
  }
  return map;
}

FinanzasPaymentCenterOperationalSnapshot
buildFinanzasPaymentCenterOperationalSnapshot(
  FinanzasPaymentCenterSourceSnapshot source,
) {
  final rawBalances = computeFinanzasPaymentCenterBalances(
    source.bankMovements,
  );
  final reserveSummary = buildFinanzasPaymentCenterReserveImpactSummary(
    reserves: source.reserves,
    rawAccountBalances: rawBalances,
  );
  final items = buildFinanzasPaymentCenterOperationalItems(
    directory: source.directory,
    tickets: source.tickets,
    ticketApplications: source.ticketApplications,
    invoices: source.invoices,
    agreements: source.agreements,
    installments: source.installments,
    agreementInvoiceLinks: source.agreementInvoiceLinks,
    fixedPayments: source.fixedPayments,
    balances: reserveSummary.accountAvailableBalances,
  );
  _applyGlobalReserveCapToOperationalItems(
    items: items,
    totalAllowedAfterBlocking: reserveSummary.availableAfterBlocking,
  );
  final budgetToday = buildFinanzasPaymentCenterBudgetTodaySummary(
    items: items,
    realAccountBalances: rawBalances,
    reserveSummary: reserveSummary,
  );
  final budgetWeek = buildFinanzasPaymentCenterBudgetWeekSummary(
    items: items,
    realAccountBalances: rawBalances,
    reserveSummary: reserveSummary,
    startDate: budgetToday.today,
  );
  return FinanzasPaymentCenterOperationalSnapshot(
    realAccountBalances: rawBalances,
    accountBalances: reserveSummary.accountAvailableBalances,
    items: items,
    learningLogs: source.learningLogs,
    reserves: source.reserves,
    reserveSummary: reserveSummary,
    budgetToday: budgetToday,
    budgetWeek: budgetWeek,
  );
}

FinanzasPaymentCenterReserveImpactSummary
buildFinanzasPaymentCenterReserveImpactSummary({
  required List<FinanzasPaymentCenterReserveRecord> reserves,
  required Map<String, double> rawAccountBalances,
  DateTime? today,
}) {
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  final activeReserves =
      reserves
          .where(
            (row) => isFinPaymentCenterReserveActiveOnDate(
              row,
              date: effectiveToday,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final dateCompare = _dateOnly(
            a.effectiveDate,
          ).compareTo(_dateOnly(b.effectiveDate));
          if (dateCompare != 0) return dateCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  final accountReserveAmounts = <String, double>{};
  var visibleReserveTotal = 0.0;
  var blockingReserveTotal = 0.0;
  var provisionalVisibleTotal = 0.0;
  var accountScopedBlockingTotal = 0.0;
  var globalBlockingTotal = 0.0;

  for (final reserve in activeReserves) {
    visibleReserveTotal += reserve.amount;
    if (reserve.classification == 'PROVISIONAL') {
      provisionalVisibleTotal += reserve.amount;
    }
    if (!reserve.blocksCash) continue;
    blockingReserveTotal += reserve.amount;
    final accountKey = reserve.accountKey;
    if (accountKey == null) {
      globalBlockingTotal += reserve.amount;
      continue;
    }
    accountScopedBlockingTotal += reserve.amount;
    accountReserveAmounts.update(
      accountKey,
      (value) => value + reserve.amount,
      ifAbsent: () => reserve.amount,
    );
  }

  final accountAvailableBalances = Map<String, double>.from(rawAccountBalances);
  for (final entry in accountReserveAmounts.entries) {
    final rawBalance = accountAvailableBalances[entry.key] ?? 0;
    accountAvailableBalances[entry.key] = (rawBalance - entry.value)
        .clamp(0, double.infinity)
        .toDouble();
  }

  final realTotalBalance = rawAccountBalances.values.fold<double>(
    0,
    (sum, value) => sum + value,
  );
  final availableAfterBlocking = (realTotalBalance - blockingReserveTotal)
      .clamp(0, double.infinity)
      .toDouble();

  return FinanzasPaymentCenterReserveImpactSummary(
    realTotalBalance: realTotalBalance,
    visibleReserveTotal: visibleReserveTotal,
    blockingReserveTotal: blockingReserveTotal,
    provisionalVisibleTotal: provisionalVisibleTotal,
    accountScopedBlockingTotal: accountScopedBlockingTotal,
    globalBlockingTotal: globalBlockingTotal,
    availableAfterBlocking: availableAfterBlocking,
    accountReserveAmounts: accountReserveAmounts,
    accountAvailableBalances: accountAvailableBalances,
    activeReserves: activeReserves,
  );
}

List<FinanzasPaymentCenterOperationalItem>
buildFinanzasPaymentCenterOperationalItems({
  required List<FinanzasCompanyDirectoryRecord> directory,
  required List<ComprasTicketRecord> tickets,
  required List<ComprasTicketPaymentApplicationRecord> ticketApplications,
  required List<FinanzasSupplierInvoiceRecord> invoices,
  required List<FinanzasSupplierAgreementRecord> agreements,
  required List<FinanzasSupplierAgreementInstallmentRecord> installments,
  required List<FinanzasSupplierAgreementInvoiceRecord> agreementInvoiceLinks,
  required List<FinanzasFixedPaymentRecord> fixedPayments,
  required Map<String, double> balances,
}) {
  final providerById = <String, FinanzasCompanyDirectoryRecord>{
    for (final row in directory.where(
      (company) =>
          company.active && company.source.trim().toUpperCase() != 'VENTAS',
    ))
      row.companyId: row,
  };
  final providerByAlias = <String, FinanzasCompanyDirectoryRecord>{
    for (final row in providerById.values)
      normalizeFinanzasCompanyAliasKey(
        row.linkedName.trim().isNotEmpty ? row.linkedName : row.companyName,
      ): row,
  };

  final installmentsByAgreementId =
      <String, List<FinanzasSupplierAgreementInstallmentRecord>>{};
  for (final row in installments) {
    installmentsByAgreementId
        .putIfAbsent(
          row.agreementId,
          () => <FinanzasSupplierAgreementInstallmentRecord>[],
        )
        .add(row);
  }
  final invoicesById = <String, FinanzasSupplierInvoiceRecord>{
    for (final invoice in invoices) invoice.id: invoice,
  };
  final agreementInvoiceLinksByInstallmentId =
      <String, List<FinanzasSupplierAgreementInvoiceRecord>>{};
  for (final link in agreementInvoiceLinks) {
    agreementInvoiceLinksByInstallmentId
        .putIfAbsent(
          link.installmentId,
          () => <FinanzasSupplierAgreementInvoiceRecord>[],
        )
        .add(link);
  }
  final linkedAgreementInvoiceIds = agreementInvoiceLinks
      .map((link) => link.invoiceId.trim())
      .where((invoiceId) => invoiceId.isNotEmpty)
      .toSet();

  final items = <FinanzasPaymentCenterOperationalItem>[];
  final agreementProviderIds = <String>{};
  final today = _dateOnly(DateTime.now());
  final comprasProviderIdByAlias = <String, String>{};
  for (final ticket in tickets) {
    final aliasKey = normalizeFinanzasCompanyAliasKey(
      ticket.providerNameSnapshot,
    );
    if (aliasKey.isNotEmpty) {
      comprasProviderIdByAlias.putIfAbsent(aliasKey, () => ticket.providerId);
    }
  }

  for (final payment in fixedPayments.where((row) => row.status != 'PAGADO')) {
    final dueDate = _dateOnly(payment.paymentDate);
    final bucket = payment.status == 'VENCIDO' || dueDate.isBefore(today)
        ? FinanzasPaymentCenterPriorityBucket.obligatorio
        : dueDate.isAtSameMomentAs(today) ||
              dueDate.isBefore(today.add(const Duration(days: 4)))
        ? FinanzasPaymentCenterPriorityBucket.urgente
        : dueDate.month == today.month && dueDate.year == today.year
        ? FinanzasPaymentCenterPriorityBucket.recomendado
        : FinanzasPaymentCenterPriorityBucket.postergable;
    final priority = _buildFinanzasPaymentCenterPriorityMeta(
      bucket: bucket,
      itemType: 'Pago fijo',
      dueDate: payment.paymentDate,
      agreementLabel: finFixedPaymentStatusLabel(payment.status),
      amountSuggested: payment.amount,
      hasAgreement: false,
      paymentStage: 'AL_CORRIENTE',
      providerManualPriority: 'NORMAL',
      providerPriorityNote: '',
      invoiceManualPriority: 'NORMAL',
      invoicePriorityNote: '',
      today: today,
    );
    items.add(
      FinanzasPaymentCenterOperationalItem(
        providerId: payment.companyId,
        providerName: payment.companyNameSnapshot,
        bucket: priority.bucket,
        itemType: 'Pago fijo',
        sourceLabel: payment.notes.trim().isEmpty
            ? 'Compromiso mensual'
            : payment.notes.trim(),
        dueDate: payment.paymentDate,
        agreementLabel: finFixedPaymentStatusLabel(payment.status),
        amountSuggested: payment.amount,
        amountTotal: payment.amount,
        targetCompany: payment.targetCompany,
        targetBranch: payment.branch,
        urgencyLabel: bucket.label,
        recommendation:
            bucket == FinanzasPaymentCenterPriorityBucket.obligatorio
            ? 'Cubrir pago fijo vencido'
            : bucket == FinanzasPaymentCenterPriorityBucket.urgente
            ? 'Reservar flujo para pago fijo'
            : bucket == FinanzasPaymentCenterPriorityBucket.recomendado
            ? 'Programar pago fijo del mes'
            : 'Pago fijo futuro',
        decisionReasons: priority.reasons,
        priorityScore: priority.score,
        allowPartialPayment: false,
        linkedFixedPaymentId: payment.id,
      ),
    );
  }

  for (final agreement in agreements) {
    final provider =
        providerById[agreement.providerId] ??
        providerByAlias[normalizeFinanzasCompanyAliasKey(
          agreement.providerNameSnapshot,
        )];
    if (provider == null) continue;
    agreementProviderIds.add(provider.companyId);
    final agreementInstallments =
        installmentsByAgreementId[agreement.id] ?? const [];
    for (final installment in agreementInstallments) {
      if (installment.status == 'PAGADO') continue;
      final dueDate = _dateOnly(installment.dueDate);
      final amount = (installment.amount - installment.paidAmount)
          .clamp(0, double.infinity)
          .toDouble();
      if (amount <= 0.009) continue;
      final bucket = dueDate.isBefore(today)
          ? FinanzasPaymentCenterPriorityBucket.obligatorio
          : dueDate.isAtSameMomentAs(today) ||
                dueDate.isBefore(today.add(const Duration(days: 4)))
          ? FinanzasPaymentCenterPriorityBucket.urgente
          : FinanzasPaymentCenterPriorityBucket.recomendado;
      final installmentLinks =
          agreementInvoiceLinksByInstallmentId[installment.id] ??
          const <FinanzasSupplierAgreementInvoiceRecord>[];
      final sourceLabel = agreement.agreementType == 'POR_FACTURAS'
          ? installmentLinks
                    .map((link) => invoicesById[link.invoiceId]?.folio ?? '')
                    .where((folio) => folio.isNotEmpty)
                    .join(' · ')
                    .trim()
                    .isEmpty
                ? 'Compromiso ${installment.sequenceNumber}'
                : installmentLinks
                      .map((link) => invoicesById[link.invoiceId]?.folio ?? '')
                      .where((folio) => folio.isNotEmpty)
                      .join(' · ')
          : 'Pago ${installment.sequenceNumber}';
      final priority = _buildFinanzasPaymentCenterPriorityMeta(
        bucket: bucket,
        itemType: 'Convenio',
        dueDate: installment.dueDate,
        agreementLabel: finSupplierAgreementStatusLabel(agreement.status),
        amountSuggested: amount,
        hasAgreement: true,
        paymentStage: provider.paymentStage,
        providerManualPriority: provider.manualPriority,
        providerPriorityNote: provider.priorityNote,
        invoiceManualPriority: 'NORMAL',
        invoicePriorityNote: '',
        today: today,
      );
      items.add(
        FinanzasPaymentCenterOperationalItem(
          providerId: provider.companyId,
          providerName: provider.companyName,
          bucket: priority.bucket,
          itemType: 'Convenio',
          sourceLabel: sourceLabel,
          dueDate: installment.dueDate,
          agreementLabel:
              '${finSupplierAgreementTypeLabel(agreement.agreementType)} · ${finSupplierAgreementFrequencyLabel(agreement.frequency)} · ${finSupplierAgreementStatusLabel(agreement.status)}',
          amountSuggested: amount,
          amountTotal: agreement.remainingAmount,
          targetCompany: agreement.targetCompany,
          targetBranch: agreement.targetBranch,
          urgencyLabel: bucket.label,
          recommendation: dueDate.isBefore(today)
              ? agreement.agreementType == 'POR_FACTURAS'
                    ? 'Cumplir facturas comprometidas'
                    : 'Cumplir convenio vencido'
              : agreement.agreementType == 'POR_FACTURAS'
              ? 'Respetar facturas comprometidas'
              : 'Respetar pago comprometido',
          decisionReasons: priority.reasons,
          priorityScore: priority.score,
          allowPartialPayment: agreement.agreementType == 'POR_MONTO',
          linkedAgreementId: agreement.id,
        ),
      );
    }
  }

  for (final invoice in invoices.where((row) => row.status != 'PAGADA')) {
    if (linkedAgreementInvoiceIds.contains(invoice.id)) continue;
    final provider =
        providerById[invoice.providerId] ??
        providerByAlias[normalizeFinanzasCompanyAliasKey(
          invoice.providerNameSnapshot,
        )];
    if (provider == null) continue;
    final dueDate = invoice.dueDate;
    final dueOnly = dueDate == null ? null : _dateOnly(dueDate);
    final providerHasAgreement = agreementProviderIds.contains(
      provider.companyId,
    );
    final bucket = dueOnly != null && dueOnly.isBefore(today)
        ? FinanzasPaymentCenterPriorityBucket.urgente
        : providerHasAgreement
        ? FinanzasPaymentCenterPriorityBucket.recomendado
        : invoice.status == 'VENCIDA' || provider.paymentStage == 'ATRASADO'
        ? FinanzasPaymentCenterPriorityBucket.urgente
        : provider.paymentStage == 'PAGO_SEMANAL'
        ? FinanzasPaymentCenterPriorityBucket.recomendado
        : FinanzasPaymentCenterPriorityBucket.postergable;
    final priority = _buildFinanzasPaymentCenterPriorityMeta(
      bucket: bucket,
      itemType: 'Factura',
      dueDate: dueDate,
      agreementLabel: providerHasAgreement
          ? 'Proveedor con convenio activo'
          : 'Sin convenio',
      amountSuggested: invoice.balanceAmount,
      hasAgreement: providerHasAgreement,
      paymentStage: provider.paymentStage,
      providerManualPriority: provider.manualPriority,
      providerPriorityNote: provider.priorityNote,
      invoiceManualPriority: invoice.manualPriority,
      invoicePriorityNote: invoice.priorityNote,
      today: today,
    );
    items.add(
      FinanzasPaymentCenterOperationalItem(
        providerId: provider.companyId,
        providerName: provider.companyName,
        bucket: priority.bucket,
        itemType: 'Factura',
        sourceLabel: invoice.folio,
        dueDate: dueDate,
        agreementLabel: providerHasAgreement
            ? 'Proveedor con convenio activo'
            : 'Sin convenio',
        amountSuggested: invoice.balanceAmount,
        amountTotal: invoice.totalAmount,
        targetCompany: invoice.targetCompany,
        targetBranch: invoice.targetBranch,
        urgencyLabel: bucket.label,
        recommendation: dueOnly != null && dueOnly.isBefore(today)
            ? 'Atender factura vencida'
            : providerHasAgreement
            ? 'Factura fuera de convenio; revisar junto al acuerdo vigente'
            : provider.paymentStage == 'ATRASADO'
            ? 'Proveedor con urgencia de pago'
            : 'Pago negociable',
        decisionReasons: priority.reasons,
        priorityScore: priority.score,
        allowPartialPayment: false,
        linkedInvoiceId: invoice.id,
      ),
    );
  }

  final ticketAmountsByProvider = computeOpenGeneralAmountsByProvider(
    tickets: tickets,
    applications: ticketApplications,
  );

  for (final provider in providerById.values) {
    if (agreementProviderIds.contains(provider.companyId)) continue;
    final comprasId = _resolveComprasProviderId(
      provider,
      comprasProviderIdByAlias,
    );
    final openAmount = ticketAmountsByProvider[comprasId] ?? 0;
    if (openAmount <= 0.009) continue;
    if (provider.paymentStage == 'AL_CORRIENTE') continue;
    final target = _inferTarget(provider);
    final bucket = provider.paymentStage == 'ATRASADO'
        ? FinanzasPaymentCenterPriorityBucket.urgente
        : FinanzasPaymentCenterPriorityBucket.recomendado;
    final priority = _buildFinanzasPaymentCenterPriorityMeta(
      bucket: bucket,
      itemType: 'Saldo general',
      dueDate: null,
      agreementLabel: 'Sin convenio',
      amountSuggested: openAmount,
      hasAgreement: false,
      paymentStage: provider.paymentStage,
      providerManualPriority: provider.manualPriority,
      providerPriorityNote: provider.priorityNote,
      invoiceManualPriority: 'NORMAL',
      invoicePriorityNote: '',
      today: today,
    );
    items.add(
      FinanzasPaymentCenterOperationalItem(
        providerId: provider.companyId,
        providerName: provider.companyName,
        bucket: priority.bucket,
        itemType: 'Saldo general',
        sourceLabel: 'Cuenta abierta',
        dueDate: null,
        agreementLabel: 'Sin convenio',
        amountSuggested: openAmount,
        amountTotal: openAmount,
        targetCompany: target.$1,
        targetBranch: target.$2,
        urgencyLabel: bucket.label,
        recommendation: provider.paymentStage == 'ATRASADO'
            ? 'Proveedor urgente sin convenio'
            : 'Preparar siguiente abono',
        decisionReasons: priority.reasons,
        priorityScore: priority.score,
        allowPartialPayment: true,
      ),
    );
  }

  final bucketOrder = <FinanzasPaymentCenterPriorityBucket, int>{
    FinanzasPaymentCenterPriorityBucket.obligatorio: 0,
    FinanzasPaymentCenterPriorityBucket.urgente: 1,
    FinanzasPaymentCenterPriorityBucket.recomendado: 2,
    FinanzasPaymentCenterPriorityBucket.postergable: 3,
  };
  items.sort((a, b) {
    final bucketCompare = (bucketOrder[a.bucket] ?? 99).compareTo(
      bucketOrder[b.bucket] ?? 99,
    );
    if (bucketCompare != 0) return bucketCompare;
    final aDue = a.dueDate ?? DateTime(2100);
    final bDue = b.dueDate ?? DateTime(2100);
    final dueCompare = aDue.compareTo(bDue);
    if (dueCompare != 0) return dueCompare;
    final scoreCompare = b.priorityScore.compareTo(a.priorityScore);
    if (scoreCompare != 0) return scoreCompare;
    return b.amountSuggested.compareTo(a.amountSuggested);
  });

  final decisions = optimizePaymentExecution(
    items: items
        .map(
          (item) => PaymentOptimizationSnapshot(
            id: item.stableKey,
            accountKey: buildFinBankAccountKey(
              company: item.targetCompany,
              branch: item.targetBranch,
            ),
            bucketKey: switch (item.bucket) {
              FinanzasPaymentCenterPriorityBucket.obligatorio => 'OBLIGATORIO',
              FinanzasPaymentCenterPriorityBucket.urgente => 'URGENTE',
              FinanzasPaymentCenterPriorityBucket.recomendado => 'RECOMENDADO',
              FinanzasPaymentCenterPriorityBucket.postergable => 'POSTERGABLE',
            },
            itemType: item.itemType,
            amountSuggested: item.amountSuggested,
            allowPartialPayment: item.allowPartialPayment,
            priorityScore: item.priorityScore,
            dueDate: item.dueDate,
          ),
        )
        .toList(growable: false),
    balances: balances,
  );

  for (final item in items) {
    final decision = decisions[item.stableKey];
    if (decision == null) continue;
    item.availableBalance = decision.availableBalance;
    item.canPayNow = decision.canPayNow;
    item.executionDecision = switch (decision.decisionKey) {
      'PAGAR_COMPLETO' => FinanzasPaymentCenterExecutionDecision.pagarCompleto,
      'ABONAR' => FinanzasPaymentCenterExecutionDecision.abonar,
      _ => FinanzasPaymentCenterExecutionDecision.esperar,
    };
    item.executionAmount = decision.executionAmount;
    item.executionSummary = decision.summary;
  }

  return items;
}

FinanzasPaymentCenterBudgetTodaySummary
buildFinanzasPaymentCenterBudgetTodaySummary({
  required List<FinanzasPaymentCenterOperationalItem> items,
  required Map<String, double> realAccountBalances,
  required FinanzasPaymentCenterReserveImpactSummary reserveSummary,
  DateTime? today,
}) {
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  final itemsByAccountAndGroup =
      <String, Map<String, List<FinanzasPaymentCenterOperationalItem>>>{};
  final riskItems = <FinanzasPaymentCenterOperationalItem>[];

  for (final item in items) {
    final accountKey = buildFinBankAccountKey(
      company: item.targetCompany,
      branch: item.targetBranch,
    );
    itemsByAccountAndGroup
        .putIfAbsent(
          accountKey,
          () => <String, List<FinanzasPaymentCenterOperationalItem>>{},
        )
        .putIfAbsent(
          _buildBudgetGroupingKey(item),
          () => <FinanzasPaymentCenterOperationalItem>[],
        )
        .add(item);
    if (_resolveBudgetBand(item, effectiveToday) ==
        FinanzasPaymentCenterBudgetBand.riesgoRevisar) {
      riskItems.add(item);
    }
  }

  final accountKeys = <String>{
    ...realAccountBalances.keys,
    ...reserveSummary.accountAvailableBalances.keys,
    ...itemsByAccountAndGroup.keys,
  }.toList(growable: false)..sort();

  final accounts = <FinanzasPaymentCenterBudgetAccountSummary>[];
  var minimumTodayAmount = 0.0;
  var recommendedAdditionalAmount = 0.0;
  var postergableAmount = 0.0;
  var riskReviewAmount = 0.0;
  var plannedTodayAmount = 0.0;

  for (final accountKey in accountKeys) {
    final providerItemsById =
        itemsByAccountAndGroup[accountKey] ??
        const <String, List<FinanzasPaymentCenterOperationalItem>>{};
    final providers = <FinanzasPaymentCenterBudgetProviderSummary>[];

    for (final entry in providerItemsById.entries) {
      final providerItems = List<FinanzasPaymentCenterOperationalItem>.from(
        entry.value,
      )..sort(_compareOperationalItemsForBudget);
      if (providerItems.isEmpty) continue;

      var providerMinimumToday = 0.0;
      var providerRecommendedAdditional = 0.0;
      var providerPostergable = 0.0;
      var providerRiskReview = 0.0;
      var providerTotalOpen = 0.0;
      var providerPlannedToday = 0.0;
      var providerPriorityScore = 0;
      final sourcePreviews = <String>{};

      for (final item in providerItems) {
        final amount = item.amountSuggested
            .clamp(0, double.infinity)
            .toDouble();
        final budgetBand = _resolveBudgetBand(item, effectiveToday);
        providerTotalOpen += amount;
        if (item.executionAmount > 0.009) {
          providerPlannedToday += item.executionAmount;
        }
        if (item.priorityScore > providerPriorityScore) {
          providerPriorityScore = item.priorityScore;
        }
        final preview = _buildBudgetSourcePreview(item);
        if (preview.isNotEmpty) {
          sourcePreviews.add(preview);
        }
        switch (budgetBand) {
          case FinanzasPaymentCenterBudgetBand.minimoHoy:
            providerMinimumToday += amount;
          case FinanzasPaymentCenterBudgetBand.recomendadoHoy:
            providerRecommendedAdditional += amount;
          case FinanzasPaymentCenterBudgetBand.postergable:
            providerPostergable += amount;
          case FinanzasPaymentCenterBudgetBand.riesgoRevisar:
            providerRiskReview += amount;
        }
      }

      final anchorItem = providerItems.first;
      providers.add(
        FinanzasPaymentCenterBudgetProviderSummary(
          providerId: anchorItem.providerId,
          providerName: anchorItem.providerName,
          accountKey: accountKey,
          targetCompany: anchorItem.targetCompany,
          targetBranch: anchorItem.targetBranch,
          minimumTodayAmount: providerMinimumToday,
          recommendedAdditionalAmount: providerRecommendedAdditional,
          postergableAmount: providerPostergable,
          riskReviewAmount: providerRiskReview,
          totalOpenAmount: providerTotalOpen,
          plannedTodayAmount: providerPlannedToday,
          itemCount: providerItems.length,
          priorityScore: providerPriorityScore,
          sourcePreviews: sourcePreviews.take(3).toList(growable: false),
          items: providerItems,
          primaryActionItem: _selectPrimaryBudgetActionItem(
            providerItems,
            effectiveToday,
          ),
        ),
      );
    }

    providers.sort(_compareBudgetProviderSummaries);
    final accountTarget = _parseBudgetAccountTarget(
      accountKey,
      fallbackCompany: providers.isNotEmpty
          ? providers.first.targetCompany
          : null,
      fallbackBranch: providers.isNotEmpty
          ? providers.first.targetBranch
          : null,
    );
    final accountMinimumToday = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.minimumTodayAmount,
    );
    final accountRecommendedAdditional = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.recommendedAdditionalAmount,
    );
    final accountPostergable = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.postergableAmount,
    );
    final accountRiskReview = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.riskReviewAmount,
    );
    final accountPlannedToday = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.plannedTodayAmount,
    );
    final realBalance = realAccountBalances[accountKey] ?? 0;
    final availableBalance =
        reserveSummary.accountAvailableBalances[accountKey] ?? realBalance;

    accounts.add(
      FinanzasPaymentCenterBudgetAccountSummary(
        accountKey: accountKey,
        targetCompany: accountTarget.$1,
        targetBranch: accountTarget.$2,
        realBalance: realBalance,
        reserveAmount: reserveSummary.accountReserveAmounts[accountKey] ?? 0,
        availableBalance: availableBalance,
        minimumTodayAmount: accountMinimumToday,
        recommendedAdditionalAmount: accountRecommendedAdditional,
        postergableAmount: accountPostergable,
        riskReviewAmount: accountRiskReview,
        plannedTodayAmount: accountPlannedToday,
        providers: providers,
      ),
    );

    minimumTodayAmount += accountMinimumToday;
    recommendedAdditionalAmount += accountRecommendedAdditional;
    postergableAmount += accountPostergable;
    riskReviewAmount += accountRiskReview;
    plannedTodayAmount += accountPlannedToday;
  }

  accounts.sort(_compareBudgetAccountSummaries);
  riskItems.sort(_compareOperationalItemsForBudget);

  return FinanzasPaymentCenterBudgetTodaySummary(
    today: effectiveToday,
    realTotalBalance: reserveSummary.realTotalBalance,
    protectedReserveTotal: reserveSummary.blockingReserveTotal,
    availableBudgetAmount: reserveSummary.availableAfterBlocking,
    minimumTodayAmount: minimumTodayAmount,
    recommendedAdditionalAmount: recommendedAdditionalAmount,
    postergableAmount: postergableAmount,
    riskReviewAmount: riskReviewAmount,
    plannedTodayAmount: plannedTodayAmount,
    accounts: accounts,
    riskItems: riskItems,
  );
}

FinanzasPaymentCenterBudgetWeekSummary
buildFinanzasPaymentCenterBudgetWeekSummary({
  required List<FinanzasPaymentCenterOperationalItem> items,
  required Map<String, double> realAccountBalances,
  required FinanzasPaymentCenterReserveImpactSummary reserveSummary,
  DateTime? startDate,
}) {
  final effectiveStartDate = _dateOnly(startDate ?? DateTime.now());
  final endDate = effectiveStartDate.add(const Duration(days: 6));
  final itemsByAccountAndGroup =
      <String, Map<String, List<FinanzasPaymentCenterOperationalItem>>>{};
  final riskItems = <FinanzasPaymentCenterOperationalItem>[];
  final dayProviderSets = <String, Set<String>>{};
  final dayItemCounts = <String, int>{};
  final dayCommittedAmounts = <String, double>{};
  final daySuggestedAmounts = <String, double>{};

  for (var offset = 0; offset < 7; offset++) {
    final day = effectiveStartDate.add(Duration(days: offset));
    final key = day.toIso8601String();
    dayProviderSets[key] = <String>{};
    dayItemCounts[key] = 0;
    dayCommittedAmounts[key] = 0;
    daySuggestedAmounts[key] = 0;
  }

  for (final item in items) {
    final accountKey = buildFinBankAccountKey(
      company: item.targetCompany,
      branch: item.targetBranch,
    );
    itemsByAccountAndGroup
        .putIfAbsent(
          accountKey,
          () => <String, List<FinanzasPaymentCenterOperationalItem>>{},
        )
        .putIfAbsent(
          _buildBudgetGroupingKey(item),
          () => <FinanzasPaymentCenterOperationalItem>[],
        )
        .add(item);

    final placement = _resolveBudgetWeekPlacement(
      item,
      effectiveStartDate,
      endDate,
    );
    if (placement.band == _BudgetWeekPlacementBand.riskReview) {
      riskItems.add(item);
    }
    final assignedDate = placement.assignedDate;
    if (assignedDate == null) continue;
    final dayKey = assignedDate.toIso8601String();
    if (!dayProviderSets.containsKey(dayKey)) continue;
    dayProviderSets[dayKey]!.add(item.providerId);
    dayItemCounts.update(dayKey, (value) => value + 1);
    switch (placement.band) {
      case _BudgetWeekPlacementBand.committed:
        dayCommittedAmounts.update(
          dayKey,
          (value) => value + item.amountSuggested,
        );
      case _BudgetWeekPlacementBand.suggested:
        daySuggestedAmounts.update(
          dayKey,
          (value) => value + item.amountSuggested,
        );
      case _BudgetWeekPlacementBand.outsideWindow:
      case _BudgetWeekPlacementBand.riskReview:
        break;
    }
  }

  final accountKeys = <String>{
    ...realAccountBalances.keys,
    ...reserveSummary.accountAvailableBalances.keys,
    ...itemsByAccountAndGroup.keys,
  }.toList(growable: false)..sort();

  final accounts = <FinanzasPaymentCenterBudgetWeekAccountSummary>[];
  var committedWeekAmount = 0.0;
  var suggestedAdditionalAmount = 0.0;
  var outsideWindowAmount = 0.0;
  var riskReviewAmount = 0.0;
  var plannedWeekAmount = 0.0;

  for (final accountKey in accountKeys) {
    final providerItemsById =
        itemsByAccountAndGroup[accountKey] ??
        const <String, List<FinanzasPaymentCenterOperationalItem>>{};
    final providers = <FinanzasPaymentCenterBudgetWeekProviderSummary>[];

    for (final entry in providerItemsById.entries) {
      final providerItems = List<FinanzasPaymentCenterOperationalItem>.from(
        entry.value,
      )..sort(_compareOperationalItemsForBudget);
      if (providerItems.isEmpty) continue;

      var providerCommittedWeek = 0.0;
      var providerSuggestedAdditional = 0.0;
      var providerOutsideWindow = 0.0;
      var providerRiskReview = 0.0;
      var providerTotalOpen = 0.0;
      var providerPlannedWeek = 0.0;
      var providerPriorityScore = 0;
      DateTime? nextDueDate;
      final sourcePreviews = <String>{};

      for (final item in providerItems) {
        final amount = item.amountSuggested
            .clamp(0, double.infinity)
            .toDouble();
        final placement = _resolveBudgetWeekPlacement(
          item,
          effectiveStartDate,
          endDate,
        );
        providerTotalOpen += amount;
        if (item.priorityScore > providerPriorityScore) {
          providerPriorityScore = item.priorityScore;
        }
        final preview = _buildBudgetSourcePreview(item);
        if (preview.isNotEmpty) {
          sourcePreviews.add(preview);
        }
        final dueOnly = item.dueDate == null ? null : _dateOnly(item.dueDate!);
        if (dueOnly != null &&
            !dueOnly.isBefore(effectiveStartDate) &&
            !dueOnly.isAfter(endDate) &&
            (nextDueDate == null || dueOnly.isBefore(nextDueDate))) {
          nextDueDate = dueOnly;
        }
        switch (placement.band) {
          case _BudgetWeekPlacementBand.committed:
            providerCommittedWeek += amount;
            if (item.executionAmount > 0.009) {
              providerPlannedWeek += item.executionAmount;
            }
          case _BudgetWeekPlacementBand.suggested:
            providerSuggestedAdditional += amount;
            if (item.executionAmount > 0.009) {
              providerPlannedWeek += item.executionAmount;
            }
          case _BudgetWeekPlacementBand.outsideWindow:
            providerOutsideWindow += amount;
          case _BudgetWeekPlacementBand.riskReview:
            providerRiskReview += amount;
        }
      }

      final anchorItem = providerItems.first;
      providers.add(
        FinanzasPaymentCenterBudgetWeekProviderSummary(
          providerId: anchorItem.providerId,
          providerName: anchorItem.providerName,
          accountKey: accountKey,
          targetCompany: anchorItem.targetCompany,
          targetBranch: anchorItem.targetBranch,
          committedWeekAmount: providerCommittedWeek,
          suggestedAdditionalAmount: providerSuggestedAdditional,
          outsideWindowAmount: providerOutsideWindow,
          riskReviewAmount: providerRiskReview,
          totalOpenAmount: providerTotalOpen,
          plannedWeekAmount: providerPlannedWeek,
          itemCount: providerItems.length,
          priorityScore: providerPriorityScore,
          nextDueDate: nextDueDate,
          sourcePreviews: sourcePreviews.take(3).toList(growable: false),
          items: providerItems,
          primaryActionItem: _selectPrimaryBudgetWeekActionItem(
            providerItems,
            effectiveStartDate,
            endDate,
          ),
        ),
      );
    }

    providers.sort(_compareBudgetWeekProviderSummaries);
    final accountTarget = _parseBudgetAccountTarget(
      accountKey,
      fallbackCompany: providers.isNotEmpty
          ? providers.first.targetCompany
          : null,
      fallbackBranch: providers.isNotEmpty
          ? providers.first.targetBranch
          : null,
    );
    final accountCommittedWeek = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.committedWeekAmount,
    );
    final accountSuggestedAdditional = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.suggestedAdditionalAmount,
    );
    final accountOutsideWindow = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.outsideWindowAmount,
    );
    final accountRiskReview = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.riskReviewAmount,
    );
    final accountPlannedWeek = providers.fold<double>(
      0,
      (sum, provider) => sum + provider.plannedWeekAmount,
    );
    final realBalance = realAccountBalances[accountKey] ?? 0;
    final availableBalance =
        reserveSummary.accountAvailableBalances[accountKey] ?? realBalance;

    accounts.add(
      FinanzasPaymentCenterBudgetWeekAccountSummary(
        accountKey: accountKey,
        targetCompany: accountTarget.$1,
        targetBranch: accountTarget.$2,
        realBalance: realBalance,
        reserveAmount: reserveSummary.accountReserveAmounts[accountKey] ?? 0,
        availableBalance: availableBalance,
        committedWeekAmount: accountCommittedWeek,
        suggestedAdditionalAmount: accountSuggestedAdditional,
        outsideWindowAmount: accountOutsideWindow,
        riskReviewAmount: accountRiskReview,
        plannedWeekAmount: accountPlannedWeek,
        providers: providers,
      ),
    );

    committedWeekAmount += accountCommittedWeek;
    suggestedAdditionalAmount += accountSuggestedAdditional;
    outsideWindowAmount += accountOutsideWindow;
    riskReviewAmount += accountRiskReview;
    plannedWeekAmount += accountPlannedWeek;
  }

  accounts.sort(_compareBudgetWeekAccountSummaries);
  riskItems.sort(_compareOperationalItemsForBudget);

  final days = <FinanzasPaymentCenterBudgetWeekDaySummary>[];
  var cumulativeCommitted = 0.0;
  var cumulativeSuggested = 0.0;
  for (var offset = 0; offset < 7; offset++) {
    final day = effectiveStartDate.add(Duration(days: offset));
    final key = day.toIso8601String();
    final committed = dayCommittedAmounts[key] ?? 0;
    final suggested = daySuggestedAmounts[key] ?? 0;
    cumulativeCommitted += committed;
    cumulativeSuggested += committed + suggested;
    final providers = dayProviderSets[key]?.toList(growable: false) ?? const [];
    days.add(
      FinanzasPaymentCenterBudgetWeekDaySummary(
        date: day,
        committedAmount: committed,
        suggestedAdditionalAmount: suggested,
        providerCount: providers.length,
        itemCount: dayItemCounts[key] ?? 0,
        remainingAfterCommitted:
            reserveSummary.availableAfterBlocking - cumulativeCommitted,
        remainingAfterSuggested:
            reserveSummary.availableAfterBlocking - cumulativeSuggested,
        providerNames: providers,
      ),
    );
  }

  return FinanzasPaymentCenterBudgetWeekSummary(
    startDate: effectiveStartDate,
    endDate: endDate,
    realTotalBalance: reserveSummary.realTotalBalance,
    protectedReserveTotal: reserveSummary.blockingReserveTotal,
    availableBudgetAmount: reserveSummary.availableAfterBlocking,
    committedWeekAmount: committedWeekAmount,
    suggestedAdditionalAmount: suggestedAdditionalAmount,
    outsideWindowAmount: outsideWindowAmount,
    riskReviewAmount: riskReviewAmount,
    plannedWeekAmount: plannedWeekAmount,
    days: days,
    accounts: accounts,
    riskItems: riskItems,
  );
}

void _applyGlobalReserveCapToOperationalItems({
  required List<FinanzasPaymentCenterOperationalItem> items,
  required double totalAllowedAfterBlocking,
}) {
  var remaining = totalAllowedAfterBlocking;
  for (final item in items) {
    if (item.executionAmount <= 0.009) continue;
    if (remaining >= item.executionAmount - 0.009) {
      remaining -= item.executionAmount;
      continue;
    }
    if (remaining <= 0.009) {
      item.canPayNow = false;
      item.executionDecision = FinanzasPaymentCenterExecutionDecision.esperar;
      item.executionAmount = 0;
      item.executionSummary =
          'Las reservas globales protegidas consumen el margen restante.';
      continue;
    }
    if (item.allowPartialPayment) {
      item.canPayNow = true;
      item.executionDecision = FinanzasPaymentCenterExecutionDecision.abonar;
      item.executionAmount = remaining;
      item.executionSummary =
          'Las reservas globales protegidas recortan este movimiento al margen restante.';
      remaining = 0;
      continue;
    }
    item.canPayNow = false;
    item.executionDecision = FinanzasPaymentCenterExecutionDecision.esperar;
    item.executionAmount = 0;
    item.executionSummary =
        'Las reservas globales protegidas absorben el margen disponible para este movimiento.';
  }
}

enum _BudgetWeekPlacementBand {
  committed,
  suggested,
  outsideWindow,
  riskReview,
}

class _BudgetWeekPlacement {
  final _BudgetWeekPlacementBand band;
  final DateTime? assignedDate;

  const _BudgetWeekPlacement({required this.band, required this.assignedDate});
}

FinanzasPaymentCenterBudgetBand _resolveBudgetBand(
  FinanzasPaymentCenterOperationalItem item,
  DateTime today,
) {
  final dueOnly = item.dueDate == null ? null : _dateOnly(item.dueDate!);
  final recommendedHorizon = today.add(const Duration(days: 4));

  if (item.bucket == FinanzasPaymentCenterPriorityBucket.obligatorio) {
    return FinanzasPaymentCenterBudgetBand.minimoHoy;
  }

  switch (item.itemType) {
    case 'Convenio':
    case 'Pago fijo':
      if (dueOnly == null) {
        return FinanzasPaymentCenterBudgetBand.riesgoRevisar;
      }
      if (!dueOnly.isAfter(today)) {
        return FinanzasPaymentCenterBudgetBand.minimoHoy;
      }
      if (!dueOnly.isAfter(recommendedHorizon)) {
        return FinanzasPaymentCenterBudgetBand.recomendadoHoy;
      }
      return FinanzasPaymentCenterBudgetBand.postergable;
    case 'Factura':
      if (dueOnly == null) {
        return FinanzasPaymentCenterBudgetBand.riesgoRevisar;
      }
      if (!dueOnly.isAfter(today)) {
        return FinanzasPaymentCenterBudgetBand.minimoHoy;
      }
      if (!dueOnly.isAfter(recommendedHorizon) ||
          item.bucket == FinanzasPaymentCenterPriorityBucket.urgente) {
        return FinanzasPaymentCenterBudgetBand.recomendadoHoy;
      }
      return FinanzasPaymentCenterBudgetBand.postergable;
    case 'Saldo general':
      if (item.bucket == FinanzasPaymentCenterPriorityBucket.urgente) {
        return FinanzasPaymentCenterBudgetBand.recomendadoHoy;
      }
      return FinanzasPaymentCenterBudgetBand.postergable;
    default:
      if (dueOnly == null) {
        return FinanzasPaymentCenterBudgetBand.postergable;
      }
      if (!dueOnly.isAfter(today)) {
        return FinanzasPaymentCenterBudgetBand.minimoHoy;
      }
      if (!dueOnly.isAfter(recommendedHorizon)) {
        return FinanzasPaymentCenterBudgetBand.recomendadoHoy;
      }
      return FinanzasPaymentCenterBudgetBand.postergable;
  }
}

FinanzasPaymentCenterOperationalItem? _selectPrimaryBudgetActionItem(
  List<FinanzasPaymentCenterOperationalItem> items,
  DateTime today,
) {
  for (final band in const <FinanzasPaymentCenterBudgetBand>[
    FinanzasPaymentCenterBudgetBand.minimoHoy,
    FinanzasPaymentCenterBudgetBand.recomendadoHoy,
  ]) {
    for (final item in items) {
      if (_resolveBudgetBand(item, today) == band) {
        return item;
      }
    }
  }
  for (final item in items) {
    if (item.executionAmount > 0.009) return item;
  }
  return items.isEmpty ? null : items.first;
}

_BudgetWeekPlacement _resolveBudgetWeekPlacement(
  FinanzasPaymentCenterOperationalItem item,
  DateTime startDate,
  DateTime endDate,
) {
  final dueOnly = item.dueDate == null ? null : _dateOnly(item.dueDate!);
  if (dueOnly != null) {
    final assignedDate = dueOnly.isBefore(startDate) ? startDate : dueOnly;
    if (!assignedDate.isAfter(endDate)) {
      return _BudgetWeekPlacement(
        band: _BudgetWeekPlacementBand.committed,
        assignedDate: assignedDate,
      );
    }
    return const _BudgetWeekPlacement(
      band: _BudgetWeekPlacementBand.outsideWindow,
      assignedDate: null,
    );
  }

  if (item.itemType == 'Saldo general') {
    if (item.bucket == FinanzasPaymentCenterPriorityBucket.postergable) {
      return const _BudgetWeekPlacement(
        band: _BudgetWeekPlacementBand.outsideWindow,
        assignedDate: null,
      );
    }
    return _BudgetWeekPlacement(
      band: _BudgetWeekPlacementBand.suggested,
      assignedDate: startDate,
    );
  }

  if (item.itemType == 'Factura' ||
      item.itemType == 'Convenio' ||
      item.itemType == 'Pago fijo') {
    return const _BudgetWeekPlacement(
      band: _BudgetWeekPlacementBand.riskReview,
      assignedDate: null,
    );
  }

  if (item.bucket == FinanzasPaymentCenterPriorityBucket.obligatorio ||
      item.bucket == FinanzasPaymentCenterPriorityBucket.urgente ||
      item.bucket == FinanzasPaymentCenterPriorityBucket.recomendado) {
    return _BudgetWeekPlacement(
      band: _BudgetWeekPlacementBand.suggested,
      assignedDate: startDate,
    );
  }

  return const _BudgetWeekPlacement(
    band: _BudgetWeekPlacementBand.outsideWindow,
    assignedDate: null,
  );
}

FinanzasPaymentCenterOperationalItem? _selectPrimaryBudgetWeekActionItem(
  List<FinanzasPaymentCenterOperationalItem> items,
  DateTime startDate,
  DateTime endDate,
) {
  for (final band in const <_BudgetWeekPlacementBand>[
    _BudgetWeekPlacementBand.committed,
    _BudgetWeekPlacementBand.suggested,
    _BudgetWeekPlacementBand.riskReview,
  ]) {
    for (final item in items) {
      if (_resolveBudgetWeekPlacement(item, startDate, endDate).band == band) {
        return item;
      }
    }
  }
  for (final item in items) {
    if (item.executionAmount > 0.009) return item;
  }
  return items.isEmpty ? null : items.first;
}

String _buildBudgetGroupingKey(FinanzasPaymentCenterOperationalItem item) {
  if (item.linkedInvoiceId != null && item.linkedInvoiceId!.trim().isNotEmpty) {
    return 'invoice:${item.linkedInvoiceId!.trim()}';
  }
  if (item.linkedAgreementId != null &&
      item.linkedAgreementId!.trim().isNotEmpty) {
    final dueStamp = item.dueDate == null
        ? 'sin_fecha'
        : _dateOnly(item.dueDate!).toIso8601String();
    return 'agreement:${item.linkedAgreementId!.trim()}:$dueStamp:${item.sourceLabel.trim()}';
  }
  if (item.linkedFixedPaymentId != null &&
      item.linkedFixedPaymentId!.trim().isNotEmpty) {
    return 'fixed:${item.linkedFixedPaymentId!.trim()}';
  }
  return 'provider:${item.providerId}';
}

String _buildBudgetSourcePreview(FinanzasPaymentCenterOperationalItem item) {
  final source = item.sourceLabel.trim();
  if (source.isEmpty) return item.itemType;
  if (item.dueDate == null) return source;
  final dueDate = _dateOnly(item.dueDate!);
  final day = dueDate.day.toString().padLeft(2, '0');
  final month = dueDate.month.toString().padLeft(2, '0');
  return '$source · $day/$month';
}

int _compareOperationalItemsForBudget(
  FinanzasPaymentCenterOperationalItem a,
  FinanzasPaymentCenterOperationalItem b,
) {
  final aDue = a.dueDate == null ? null : _dateOnly(a.dueDate!);
  final bDue = b.dueDate == null ? null : _dateOnly(b.dueDate!);
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

int _compareBudgetProviderSummaries(
  FinanzasPaymentCenterBudgetProviderSummary a,
  FinanzasPaymentCenterBudgetProviderSummary b,
) {
  final minimumCompare = b.minimumTodayAmount.compareTo(a.minimumTodayAmount);
  if (minimumCompare != 0) return minimumCompare;
  final recommendedCompare = b.recommendedTodayAmount.compareTo(
    a.recommendedTodayAmount,
  );
  if (recommendedCompare != 0) return recommendedCompare;
  final plannedCompare = b.plannedTodayAmount.compareTo(a.plannedTodayAmount);
  if (plannedCompare != 0) return plannedCompare;
  final riskCompare = b.riskReviewAmount.compareTo(a.riskReviewAmount);
  if (riskCompare != 0) return riskCompare;
  final priorityCompare = b.priorityScore.compareTo(a.priorityScore);
  if (priorityCompare != 0) return priorityCompare;
  return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
}

int _compareBudgetAccountSummaries(
  FinanzasPaymentCenterBudgetAccountSummary a,
  FinanzasPaymentCenterBudgetAccountSummary b,
) {
  final minimumCompare = b.minimumTodayAmount.compareTo(a.minimumTodayAmount);
  if (minimumCompare != 0) return minimumCompare;
  final recommendedCompare = b.recommendedTodayAmount.compareTo(
    a.recommendedTodayAmount,
  );
  if (recommendedCompare != 0) return recommendedCompare;
  final availableCompare = b.availableBalance.compareTo(a.availableBalance);
  if (availableCompare != 0) return availableCompare;
  return a.accountKey.compareTo(b.accountKey);
}

int _compareBudgetWeekProviderSummaries(
  FinanzasPaymentCenterBudgetWeekProviderSummary a,
  FinanzasPaymentCenterBudgetWeekProviderSummary b,
) {
  final committedCompare = b.committedWeekAmount.compareTo(
    a.committedWeekAmount,
  );
  if (committedCompare != 0) return committedCompare;
  final pressureCompare = b.weekPressureAmount.compareTo(a.weekPressureAmount);
  if (pressureCompare != 0) return pressureCompare;
  final plannedCompare = b.plannedWeekAmount.compareTo(a.plannedWeekAmount);
  if (plannedCompare != 0) return plannedCompare;
  final riskCompare = b.riskReviewAmount.compareTo(a.riskReviewAmount);
  if (riskCompare != 0) return riskCompare;
  final outsideCompare = b.outsideWindowAmount.compareTo(a.outsideWindowAmount);
  if (outsideCompare != 0) return outsideCompare;
  final priorityCompare = b.priorityScore.compareTo(a.priorityScore);
  if (priorityCompare != 0) return priorityCompare;
  return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
}

int _compareBudgetWeekAccountSummaries(
  FinanzasPaymentCenterBudgetWeekAccountSummary a,
  FinanzasPaymentCenterBudgetWeekAccountSummary b,
) {
  final committedCompare = b.committedWeekAmount.compareTo(
    a.committedWeekAmount,
  );
  if (committedCompare != 0) return committedCompare;
  final pressureCompare = b.weekPressureAmount.compareTo(a.weekPressureAmount);
  if (pressureCompare != 0) return pressureCompare;
  final availableCompare = b.availableBalance.compareTo(a.availableBalance);
  if (availableCompare != 0) return availableCompare;
  return a.accountKey.compareTo(b.accountKey);
}

(String, String) _parseBudgetAccountTarget(
  String accountKey, {
  String? fallbackCompany,
  String? fallbackBranch,
}) {
  final parts = accountKey.split('_');
  if (parts.length >= 2) {
    return (parts.first, parts.sublist(1).join('_'));
  }
  return (fallbackCompany ?? 'DICSA', fallbackBranch ?? 'CELAYA');
}

int _finanzasPaymentCenterBucketBaseScore(
  FinanzasPaymentCenterPriorityBucket bucket,
) {
  switch (bucket) {
    case FinanzasPaymentCenterPriorityBucket.obligatorio:
      return 400;
    case FinanzasPaymentCenterPriorityBucket.urgente:
      return 300;
    case FinanzasPaymentCenterPriorityBucket.recomendado:
      return 200;
    case FinanzasPaymentCenterPriorityBucket.postergable:
      return 100;
  }
}

FinanzasPaymentCenterPriorityBucket _maxUrgencyBucket(
  FinanzasPaymentCenterPriorityBucket current,
  FinanzasPaymentCenterPriorityBucket minimum,
) {
  final order = <FinanzasPaymentCenterPriorityBucket, int>{
    FinanzasPaymentCenterPriorityBucket.obligatorio: 0,
    FinanzasPaymentCenterPriorityBucket.urgente: 1,
    FinanzasPaymentCenterPriorityBucket.recomendado: 2,
    FinanzasPaymentCenterPriorityBucket.postergable: 3,
  };
  return (order[current] ?? 99) <= (order[minimum] ?? 99) ? current : minimum;
}

FinanzasPaymentCenterPriorityMeta _buildFinanzasPaymentCenterPriorityMeta({
  required FinanzasPaymentCenterPriorityBucket bucket,
  required String itemType,
  required DateTime? dueDate,
  required String agreementLabel,
  required double amountSuggested,
  required bool hasAgreement,
  required String paymentStage,
  required String providerManualPriority,
  required String providerPriorityNote,
  required String invoiceManualPriority,
  required String invoicePriorityNote,
  required DateTime today,
}) {
  final reasons = <String>[];
  var effectiveBucket = bucket;
  var score = _finanzasPaymentCenterBucketBaseScore(effectiveBucket);
  final dueOnly = dueDate == null ? null : _dateOnly(dueDate);
  if (dueOnly != null) {
    if (dueOnly.isBefore(today)) {
      reasons.add('Ya venció');
      score += 60;
    } else if (dueOnly.isAtSameMomentAs(today)) {
      reasons.add('Vence hoy');
      score += 45;
    } else if (dueOnly.isBefore(today.add(const Duration(days: 4)))) {
      reasons.add('Vence esta semana');
      score += 25;
    }
  }
  if (itemType == 'Pago fijo') {
    reasons.add('Compromiso fijo del mes');
    score += 40;
  }
  if (itemType == 'Convenio') {
    reasons.add('Compromiso pactado con proveedor');
    score += 35;
  }
  if (invoiceManualPriority == 'CRITICA') {
    effectiveBucket = _maxUrgencyBucket(
      effectiveBucket,
      FinanzasPaymentCenterPriorityBucket.obligatorio,
    );
    reasons.add('Prioridad manual crítica en factura');
    score += 110;
    if (invoicePriorityNote.trim().isNotEmpty) {
      reasons.add('Nota factura: ${invoicePriorityNote.trim()}');
    }
  } else if (invoiceManualPriority == 'ALTA') {
    effectiveBucket = _maxUrgencyBucket(
      effectiveBucket,
      FinanzasPaymentCenterPriorityBucket.urgente,
    );
    reasons.add('Prioridad manual alta en factura');
    score += 60;
    if (invoicePriorityNote.trim().isNotEmpty) {
      reasons.add('Nota factura: ${invoicePriorityNote.trim()}');
    }
  } else if (providerManualPriority == 'CRITICA') {
    effectiveBucket = _maxUrgencyBucket(
      effectiveBucket,
      FinanzasPaymentCenterPriorityBucket.urgente,
    );
    reasons.add('Proveedor con prioridad crítica');
    score += 80;
    if (providerPriorityNote.trim().isNotEmpty) {
      reasons.add('Nota proveedor: ${providerPriorityNote.trim()}');
    }
  } else if (providerManualPriority == 'ALTA') {
    effectiveBucket = _maxUrgencyBucket(
      effectiveBucket,
      FinanzasPaymentCenterPriorityBucket.recomendado,
    );
    reasons.add('Proveedor con prioridad alta');
    score += 36;
    if (providerPriorityNote.trim().isNotEmpty) {
      reasons.add('Nota proveedor: ${providerPriorityNote.trim()}');
    }
  }
  if (itemType == 'Factura' && hasAgreement) {
    reasons.add('Proveedor con convenio activo');
    score += 10;
  }
  if (paymentStage == 'ATRASADO') {
    reasons.add('Proveedor marcado como atrasado');
    score += 30;
  } else if (paymentStage == 'PAGO_SEMANAL') {
    reasons.add('Proveedor de pago semanal');
    score += 14;
  } else if (paymentStage == 'CONVENIO') {
    reasons.add('Proveedor bajo convenio');
    score += 20;
  }
  if (agreementLabel.contains('Vencid') || agreementLabel.contains('Atrasad')) {
    reasons.add('Estado sensible');
    score += 18;
  }
  if (amountSuggested >= 100000) {
    reasons.add('Monto alto');
    score += 12;
  } else if (amountSuggested >= 25000) {
    reasons.add('Monto relevante');
    score += 6;
  }
  score +=
      (_finanzasPaymentCenterBucketBaseScore(effectiveBucket) -
      _finanzasPaymentCenterBucketBaseScore(bucket));
  return FinanzasPaymentCenterPriorityMeta(
    bucket: effectiveBucket,
    reasons: reasons,
    score: score,
  );
}

(String, String) _inferTarget(FinanzasCompanyDirectoryRecord provider) {
  final raw =
      '${provider.companyName} ${provider.linkedName} ${provider.location} ${provider.paymentNotes}'
          .toUpperCase();
  final company = raw.contains('VH') ? 'VH' : 'DICSA';
  final branch = raw.contains('MAZATLAN') ? 'MAZATLAN' : 'CELAYA';
  return (company, branch);
}

String _resolveComprasProviderId(
  FinanzasCompanyDirectoryRecord company,
  Map<String, String> comprasProviderIdByAlias,
) {
  if (company.source.trim().toUpperCase() == 'COMPRAS' &&
      company.companyId.startsWith('compras_')) {
    return company.companyId.substring('compras_'.length);
  }
  final aliasKey = normalizeFinanzasCompanyAliasKey(
    company.linkedName.trim().isNotEmpty
        ? company.linkedName
        : company.companyName,
  );
  final aliasMatch = comprasProviderIdByAlias[aliasKey];
  if (aliasMatch != null && aliasMatch.trim().isNotEmpty) {
    return aliasMatch;
  }
  return company.companyId;
}
