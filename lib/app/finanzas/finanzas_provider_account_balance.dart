import '../compras/compras_tickets_store.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_provider_accounts_store.dart';

class ProviderAccountBalance {
  final double facturadoAmount;
  final double sinFacturaAmount;
  final double pendienteFacturarAmount;
  final double adjustmentAmount;
  final double unappliedPaymentAmount;
  final int openInvoicesCount;
  final int openNonInvoiceTicketsCount;
  final DateTime? nextDueDate;

  const ProviderAccountBalance({
    required this.facturadoAmount,
    required this.sinFacturaAmount,
    required this.pendienteFacturarAmount,
    required this.adjustmentAmount,
    required this.unappliedPaymentAmount,
    required this.openInvoicesCount,
    required this.openNonInvoiceTicketsCount,
    required this.nextDueDate,
  });

  double get openAmount =>
      facturadoAmount +
      sinFacturaAmount +
      pendienteFacturarAmount +
      adjustmentAmount -
      unappliedPaymentAmount;

  double get payableAmount => openAmount.clamp(0.0, double.infinity);
}

/// All inputs belong to the same provider. Invoiced tickets are represented by
/// their invoice; direct payments are deducted only once through applications.
ProviderAccountBalance computeProviderAccountBalance({
  required List<ComprasTicketRecord> tickets,
  required List<FinanzasSupplierInvoiceRecord> invoices,
  required Set<String> invoicedTicketIds,
  required List<FinanzasBankMovementRecord> bankMovements,
  required List<ComprasProviderMovementRecord> directMovements,
  required List<ComprasTicketPaymentApplicationRecord> applications,
  required int creditDays,
}) {
  final appliedByInvoiceId = buildAppliedSupplierAmountByInvoiceId(
    bankMovements,
  );
  final appliedByTicketId = <String, double>{};
  final appliedByMovementId = <String, double>{};
  for (final application in applications) {
    appliedByTicketId.update(
      application.ticketId,
      (value) => value + application.appliedAmount,
      ifAbsent: () => application.appliedAmount,
    );
    appliedByMovementId.update(
      application.providerMovementId,
      (value) => value + application.appliedAmount,
      ifAbsent: () => application.appliedAmount,
    );
  }

  double facturado = 0;
  double sinFactura = 0;
  double pendienteFacturar = 0;
  var openInvoices = 0;
  var openTickets = 0;
  DateTime? nextDueDate;
  void includeDueDate(DateTime? date) {
    if (date != null && (nextDueDate == null || date.isBefore(nextDueDate!))) {
      nextDueDate = date;
    }
  }

  for (final invoice in invoices) {
    final remaining = effectiveSupplierInvoiceBalance(
      invoice,
      appliedByInvoiceId,
    );
    if (remaining <= 0.009) continue;
    facturado += remaining;
    openInvoices++;
    includeDueDate(invoice.dueDate);
  }

  for (final ticket in tickets) {
    if (ticket.facturaStatus == 'FACTURADO' ||
        invoicedTicketIds.contains(ticket.id)) {
      continue;
    }
    // Negative tickets are existing credits, not positive debt to be clamped.
    final remaining = ticket.amount <= 0
        ? ticket.amount
        : (ticket.amount - (appliedByTicketId[ticket.id] ?? 0))
              .clamp(0.0, ticket.amount)
              .toDouble();
    if (ticket.facturaStatus == 'SIN_FACTURA') {
      sinFactura += remaining;
    } else {
      pendienteFacturar += remaining;
    }
    if (remaining > 0.009) {
      openTickets++;
      includeDueDate(ticket.date.add(Duration(days: creditDays)));
    }
  }

  double adjustments = 0;
  double unappliedPayments = 0;
  for (final movement in directMovements) {
    if (movement.type == 'CARGO' || movement.type == 'AJUSTE') {
      // Positive corrections increase debt; negative corrections reduce it.
      adjustments += movement.amount;
    } else if (movement.type == 'ABONO' || movement.type == 'PAGO') {
      unappliedPayments +=
          (movement.amount - (appliedByMovementId[movement.id] ?? 0)).clamp(
            0.0,
            double.infinity,
          );
    }
  }

  return ProviderAccountBalance(
    facturadoAmount: facturado,
    sinFacturaAmount: sinFactura,
    pendienteFacturarAmount: pendienteFacturar,
    adjustmentAmount: adjustments,
    unappliedPaymentAmount: unappliedPayments,
    openInvoicesCount: openInvoices,
    openNonInvoiceTicketsCount: openTickets,
    nextDueDate: nextDueDate,
  );
}

Map<String, double> buildAppliedSupplierAmountByInvoiceId(
  Iterable<FinanzasBankMovementRecord> movements,
) {
  final appliedByInvoiceId = <String, double>{};
  for (final movement in movements) {
    final invoiceId = movement.linkedSupplierInvoiceId;
    if (invoiceId == null || invoiceId.isEmpty) continue;
    final applied = movement.effectiveSupplierAppliedAmount.clamp(
      0.0,
      double.infinity,
    );
    if (applied <= 0.009) continue;
    appliedByInvoiceId.update(
      invoiceId,
      (sum) => sum + applied,
      ifAbsent: () => applied,
    );
  }
  return appliedByInvoiceId;
}

double effectiveSupplierInvoiceBalance(
  FinanzasSupplierInvoiceRecord invoice,
  Map<String, double> appliedByInvoiceId,
) {
  final linkedPaid = appliedByInvoiceId[invoice.id];
  return linkedPaid == null
      ? invoice.balanceAmount.clamp(0.0, invoice.totalAmount).toDouble()
      : (invoice.totalAmount - linkedPaid)
            .clamp(0.0, invoice.totalAmount)
            .toDouble();
}
