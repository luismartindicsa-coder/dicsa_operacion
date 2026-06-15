import '../compras/compras_tickets_store.dart';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class AgreementInstallmentSnapshot {
  final int sequenceNumber;
  final DateTime dueDate;
  final double amount;
  final double paidAmount;
  final String status;

  const AgreementInstallmentSnapshot({
    required this.sequenceNumber,
    required this.dueDate,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });
}

class AgreementSummarySnapshot {
  final double remainingAmount;
  final DateTime? nextDueDate;
  final String status;

  const AgreementSummarySnapshot({
    required this.remainingAmount,
    required this.nextDueDate,
    required this.status,
  });
}

class InvoiceTicketSnapshot {
  final String ticketId;
  final double ticketAmount;
  final DateTime ticketDate;
  final String ticketNumber;

  const InvoiceTicketSnapshot({
    required this.ticketId,
    required this.ticketAmount,
    required this.ticketDate,
    required this.ticketNumber,
  });
}

class TicketCoverageSnapshot {
  final double appliedAmount;
  final String pagoStatus;
  final String coverageStatus;

  const TicketCoverageSnapshot({
    required this.appliedAmount,
    required this.pagoStatus,
    required this.coverageStatus,
  });
}

class PaymentOptimizationSnapshot {
  final String id;
  final String accountKey;
  final String bucketKey;
  final String itemType;
  final double amountSuggested;
  final bool allowPartialPayment;
  final int priorityScore;
  final DateTime? dueDate;

  const PaymentOptimizationSnapshot({
    required this.id,
    required this.accountKey,
    required this.bucketKey,
    required this.itemType,
    required this.amountSuggested,
    required this.allowPartialPayment,
    required this.priorityScore,
    required this.dueDate,
  });
}

class PaymentOptimizationDecisionSnapshot {
  final bool canPayNow;
  final String decisionKey;
  final double executionAmount;
  final double availableBalance;
  final String summary;

  const PaymentOptimizationDecisionSnapshot({
    required this.canPayNow,
    required this.decisionKey,
    required this.executionAmount,
    required this.availableBalance,
    required this.summary,
  });
}

String deriveFixedPaymentOperationalStatus({
  required String persistedStatus,
  required DateTime paymentDate,
  DateTime? today,
}) {
  if (persistedStatus == 'PAGADO') return persistedStatus;
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  final dueDate = _dateOnly(paymentDate);
  return dueDate.isBefore(effectiveToday) ? 'VENCIDO' : 'PENDIENTE';
}

void assertFullSettlementAmount({
  required double appliedAmount,
  required double expectedAmount,
  required String contextLabel,
}) {
  if ((appliedAmount - expectedAmount).abs() > 0.009) {
    throw StateError(
      '$contextLabel debe liquidarse completo por ${expectedAmount.toStringAsFixed(2)}.',
    );
  }
}

String deriveSupplierInvoiceStatus({
  required double balanceAmount,
  required DateTime? dueDate,
  DateTime? today,
}) {
  if (balanceAmount <= 0.009) return 'PAGADA';
  if (dueDate == null) return 'PARCIAL';
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  return _dateOnly(dueDate).isBefore(effectiveToday) ? 'VENCIDA' : 'PARCIAL';
}

String deriveAgreementInstallmentStatus({
  required DateTime dueDate,
  required double amount,
  required double paidAmount,
  DateTime? today,
}) {
  if (paidAmount >= amount - 0.009) return 'PAGADO';
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  return _dateOnly(dueDate).isBefore(effectiveToday) ? 'VENCIDO' : 'PENDIENTE';
}

AgreementSummarySnapshot recomputeAgreementSummary({
  required String currentStatus,
  required List<AgreementInstallmentSnapshot> installments,
  DateTime? today,
}) {
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  final ordered = installments.toList(growable: false)
    ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
  double remaining = 0;
  DateTime? nextDueDate;
  var hasOverdue = false;

  for (final installment in ordered) {
    if (installment.status == 'PAGADO' || installment.status == 'CANCELADO') {
      continue;
    }
    remaining += (installment.amount - installment.paidAmount)
        .clamp(0, double.infinity)
        .toDouble();
    nextDueDate ??= installment.dueDate;
    if (_dateOnly(installment.dueDate).isBefore(effectiveToday)) {
      hasOverdue = true;
    }
  }

  final status = currentStatus == 'CANCELADO'
      ? 'CANCELADO'
      : remaining <= 0.009
      ? 'CUMPLIDO'
      : hasOverdue
      ? 'ATRASADO'
      : 'ACTIVO';

  return AgreementSummarySnapshot(
    remainingAmount: remaining,
    nextDueDate: nextDueDate,
    status: status,
  );
}

Map<String, TicketCoverageSnapshot> computeInvoiceTicketCoverage({
  required double invoiceTotalAmount,
  required double invoiceBalanceAmount,
  required List<InvoiceTicketSnapshot> tickets,
  required Map<String, double> directAppliedByTicketId,
}) {
  final ordered = tickets.toList(growable: false)
    ..sort((a, b) {
      final dateCompare = a.ticketDate.compareTo(b.ticketDate);
      if (dateCompare != 0) return dateCompare;
      return a.ticketNumber.compareTo(b.ticketNumber);
    });
  var invoicePaidRemaining = (invoiceTotalAmount - invoiceBalanceAmount)
      .clamp(0, invoiceTotalAmount)
      .toDouble();
  final result = <String, TicketCoverageSnapshot>{};

  for (final ticket in ordered) {
    final directApplied = (directAppliedByTicketId[ticket.ticketId] ?? 0)
        .clamp(0, ticket.ticketAmount)
        .toDouble();
    final pendingAfterDirect = (ticket.ticketAmount - directApplied)
        .clamp(0, double.infinity)
        .toDouble();
    final invoiceApplied = invoicePaidRemaining > pendingAfterDirect
        ? pendingAfterDirect
        : invoicePaidRemaining;
    invoicePaidRemaining = (invoicePaidRemaining - invoiceApplied)
        .clamp(0, double.infinity)
        .toDouble();
    final totalApplied = (directApplied + invoiceApplied)
        .clamp(0, ticket.ticketAmount)
        .toDouble();
    final fullyCovered = totalApplied >= ticket.ticketAmount - 0.009;
    final hasAbono = totalApplied > 0.009 && !fullyCovered;
    result[ticket.ticketId] = TicketCoverageSnapshot(
      appliedAmount: totalApplied,
      pagoStatus: fullyCovered
          ? 'PAGADO'
          : hasAbono
          ? 'ABONO'
          : 'PENDIENTE_DE_PAGO',
      coverageStatus: fullyCovered
          ? 'CUBIERTO'
          : hasAbono
          ? 'PARCIAL'
          : 'SIN_CUBRIR',
    );
  }

  return result;
}

Map<String, double> computeOpenGeneralAmountsByProvider({
  required List<ComprasTicketRecord> tickets,
  required List<ComprasTicketPaymentApplicationRecord> applications,
}) {
  final directAppliedByTicketId = <String, double>{};
  for (final application in applications) {
    directAppliedByTicketId.update(
      application.ticketId,
      (value) => value + application.appliedAmount,
      ifAbsent: () => application.appliedAmount,
    );
  }

  final result = <String, double>{};
  for (final ticket in tickets.where(
    (row) => row.facturaStatus != 'FACTURADO',
  )) {
    final openTicketAmount = ticket.amount <= 0 ? 0.0 : ticket.amount;
    final applied = (directAppliedByTicketId[ticket.id] ?? 0)
        .clamp(0, openTicketAmount)
        .toDouble();
    final remaining = (openTicketAmount - applied).clamp(0, double.infinity);
    if (remaining <= 0.009) continue;
    result.update(
      ticket.providerId,
      (value) => value + remaining,
      ifAbsent: () => remaining.toDouble(),
    );
  }
  return result;
}

Map<String, PaymentOptimizationDecisionSnapshot> optimizePaymentExecution({
  required List<PaymentOptimizationSnapshot> items,
  required Map<String, double> balances,
}) {
  final availableByAccount = Map<String, double>.from(balances);
  final itemsByAccount = <String, List<PaymentOptimizationSnapshot>>{};
  for (final item in items) {
    itemsByAccount
        .putIfAbsent(item.accountKey, () => <PaymentOptimizationSnapshot>[])
        .add(item);
  }

  final decisions = <String, PaymentOptimizationDecisionSnapshot>{};

  for (final entry in itemsByAccount.entries) {
    var available = availableByAccount[entry.key] ?? 0;
    final rows = entry.value;
    for (final item in rows) {
      decisions[item.id] = PaymentOptimizationDecisionSnapshot(
        canPayNow: false,
        decisionKey: 'ESPERAR',
        executionAmount: 0,
        availableBalance: available,
        summary: available <= 0.009
            ? 'No hay saldo disponible en la cuenta objetivo.'
            : 'Pendiente en espera mientras se optimiza esta cuenta.',
      );
    }

    final completeCandidates =
        rows
            .where((item) => item.amountSuggested > 0.009)
            .toList(growable: false)
          ..sort((a, b) {
            final valueCompare = _optimizationValueSnapshot(
              b,
            ).compareTo(_optimizationValueSnapshot(a));
            if (valueCompare != 0) return valueCompare;
            final bucketCompare = _bucketBaseScoreKey(
              b.bucketKey,
            ).compareTo(_bucketBaseScoreKey(a.bucketKey));
            if (bucketCompare != 0) return bucketCompare;
            final dueA = a.dueDate ?? DateTime(2100);
            final dueB = b.dueDate ?? DateTime(2100);
            return dueA.compareTo(dueB);
          });

    for (final item in completeCandidates) {
      if (available >= item.amountSuggested - 0.009) {
        decisions[item.id] = PaymentOptimizationDecisionSnapshot(
          canPayNow: true,
          decisionKey: 'PAGAR_COMPLETO',
          executionAmount: item.amountSuggested,
          availableBalance: available,
          summary:
              'La optimización de esta cuenta sugiere liquidarlo completo por mejor impacto/costo.',
        );
        available -= item.amountSuggested;
      }
    }

    final partialCandidates =
        rows
            .where((item) {
              final current = decisions[item.id]!;
              return current.decisionKey == 'ESPERAR' &&
                  _canUsePartialOptimizationSnapshot(item) &&
                  item.bucketKey != 'POSTERGABLE';
            })
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.priorityScore.compareTo(a.priorityScore);
            if (scoreCompare != 0) return scoreCompare;
            final amountCompare = a.amountSuggested.compareTo(
              b.amountSuggested,
            );
            if (amountCompare != 0) return amountCompare;
            final dueA = a.dueDate ?? DateTime(2100);
            final dueB = b.dueDate ?? DateTime(2100);
            return dueA.compareTo(dueB);
          });

    if (available > 0.009 && partialCandidates.isNotEmpty) {
      final item = partialCandidates.first;
      decisions[item.id] = PaymentOptimizationDecisionSnapshot(
        canPayNow: false,
        decisionKey: 'ABONAR',
        executionAmount: available.clamp(0, item.amountSuggested).toDouble(),
        availableBalance: available,
        summary: item.itemType == 'Saldo general'
            ? 'La optimización propone usar el remanente en saldo general para bajar presión sin sacrificar cierres completos.'
            : 'La optimización propone usar el remanente en este convenio por monto antes de abrir otro frente de pago.',
      );
      available = 0;
    }

    final unresolvedCritical = rows.any((item) {
      final current = decisions[item.id]!;
      return (item.bucketKey == 'OBLIGATORIO' || item.bucketKey == 'URGENTE') &&
          current.decisionKey == 'ESPERAR';
    });

    final surplusCandidates =
        rows
            .where((item) {
              final current = decisions[item.id]!;
              return current.decisionKey == 'ESPERAR' &&
                  item.amountSuggested > 0.009 &&
                  (item.bucketKey == 'RECOMENDADO' ||
                      item.bucketKey == 'POSTERGABLE');
            })
            .toList(growable: false)
          ..sort((a, b) {
            final closableCompare =
                b.allowPartialPayment == a.allowPartialPayment
                ? 0
                : (a.allowPartialPayment ? 1 : -1);
            if (closableCompare != 0) return closableCompare;
            final valueCompare = _optimizationValueSnapshot(
              b,
            ).compareTo(_optimizationValueSnapshot(a));
            if (valueCompare != 0) return valueCompare;
            final amountCompare = a.amountSuggested.compareTo(
              b.amountSuggested,
            );
            if (amountCompare != 0) return amountCompare;
            final dueA = a.dueDate ?? DateTime(2100);
            final dueB = b.dueDate ?? DateTime(2100);
            return dueA.compareTo(dueB);
          });

    if (!unresolvedCritical && available > 0.009) {
      for (final item in surplusCandidates.where(
        (item) => available >= item.amountSuggested - 0.009,
      )) {
        decisions[item.id] = PaymentOptimizationDecisionSnapshot(
          canPayNow: true,
          decisionKey: 'PAGAR_COMPLETO',
          executionAmount: item.amountSuggested,
          availableBalance: available,
          summary:
              'Ya quedó cubierto lo crítico de esta cuenta y sobra flujo hoy; conviene adelantar este pago para salir de deuda más rápido.',
        );
        available -= item.amountSuggested;
        if (available <= 0.009) break;
      }
    }

    if (!unresolvedCritical && available > 0.009) {
      final surplusPartial = surplusCandidates
          .cast<PaymentOptimizationSnapshot?>()
          .firstWhere(
            (item) =>
                item != null &&
                decisions[item.id]!.decisionKey == 'ESPERAR' &&
                _canUsePartialOptimizationSnapshot(item),
            orElse: () => null,
          );
      if (surplusPartial != null) {
        decisions[surplusPartial.id] = PaymentOptimizationDecisionSnapshot(
          canPayNow: false,
          decisionKey: 'ABONAR',
          executionAmount: available
              .clamp(0, surplusPartial.amountSuggested)
              .toDouble(),
          availableBalance: available,
          summary: surplusPartial.itemType == 'Saldo general'
              ? 'Lo crítico ya quedó cubierto y sobra flujo hoy; conviene abonar este saldo general para bajar deuda antes de la próxima semana.'
              : 'Lo crítico ya quedó cubierto y sobra flujo hoy; conviene adelantar abono a este convenio por monto.',
        );
        available = 0;
      }
    }

    for (final item in rows.where(
      (item) => decisions[item.id]!.decisionKey == 'ESPERAR',
    )) {
      final originalAvailable = availableByAccount[entry.key] ?? 0;
      decisions[item.id] = PaymentOptimizationDecisionSnapshot(
        canPayNow: false,
        decisionKey: 'ESPERAR',
        executionAmount: 0,
        availableBalance: originalAvailable,
        summary: originalAvailable <= 0.009
            ? 'No hay saldo disponible en la cuenta objetivo.'
            : 'Hay mejores combinaciones de pago dentro de esta misma cuenta antes que este pendiente.',
      );
    }
    availableByAccount[entry.key] = available;
  }

  return decisions;
}

double _optimizationValueSnapshot(PaymentOptimizationSnapshot item) {
  final closabilityBonus = item.allowPartialPayment ? 0 : 95;
  final urgencyWeight = _bucketBaseScoreKey(item.bucketKey).toDouble() * 12;
  final sizePenalty = item.amountSuggested / 1500;
  final priorityWeight = item.priorityScore.toDouble();
  final agreementBonus =
      item.itemType == 'Convenio' && !item.allowPartialPayment ? 42 : 0;
  final fixedPaymentBonus = item.itemType == 'Pago fijo' ? 38 : 0;
  final invoiceBonus = item.itemType == 'Factura' ? 24 : 0;
  return closabilityBonus +
      urgencyWeight +
      priorityWeight +
      agreementBonus +
      fixedPaymentBonus +
      invoiceBonus -
      sizePenalty;
}

int _bucketBaseScoreKey(String bucketKey) {
  switch (bucketKey) {
    case 'OBLIGATORIO':
      return 4;
    case 'URGENTE':
      return 3;
    case 'RECOMENDADO':
      return 2;
    default:
      return 1;
  }
}

bool _canUsePartialOptimizationSnapshot(PaymentOptimizationSnapshot item) {
  if (!item.allowPartialPayment) return false;
  return item.itemType == 'Saldo general' || item.itemType == 'Convenio';
}
