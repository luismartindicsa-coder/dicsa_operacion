import 'package:supabase_flutter/supabase_flutter.dart';

import '../compras/compras_tickets_store.dart';
import 'finanzas_company_identity.dart';
import 'finanzas_evidence_store.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_financial_rules.dart';
import 'finanzas_provider_accounts_store.dart';

const String _kFinBankMovementsTable = 'finanzas_bank_movements';
const String _kMayoreoAccountsTable = 'mayoreo_accounts';
const String _kFinEvidenceTable = 'finanzas_evidence';
const String _kFinEvidenceBucket = 'finanzas_evidence';

const List<String> kFinBankCompanies = <String>['DICSA', 'VH'];
const List<String> kFinBankBranches = <String>['CELAYA', 'MAZATLAN'];

const List<String> kFinBankCategories = <String>[
  'VENTAS',
  'COMPRA DE MATERIAL',
  'GASTOS OPERATIVOS',
  'SERVICIOS',
  'GASTOS ADMINISTRATIVOS',
  'GASTOS FINANCIEROS',
  'NOMINA',
  'GASTOS PERSONALES',
  'MOVIMIENTOS INTERNOS',
  'AJUSTES',
  'OTROS',
];

const List<String> kFinBankMovementSourceTypes = <String>[
  'MANUAL',
  'COMPRA_FACTURA',
  'VENTA_FACTURA',
  'PAGO_FIJO',
];

class FinanzasBankMovementRecord {
  final String id;
  final DateTime date;
  final String company;
  final String branch;
  final String accountKey;
  final String? counterpartyCompanyId;
  final String counterpartyNameSnapshot;
  final String category;
  final String comment;
  final String reference;
  final double creditAmount;
  final double debitAmount;
  final String sourceType;
  final String? linkedSupplierInvoiceId;
  final String? linkedFixedPaymentId;
  final String? linkedExternalRef;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasBankMovementRecord({
    required this.id,
    required this.date,
    required this.company,
    required this.branch,
    required this.accountKey,
    required this.counterpartyCompanyId,
    required this.counterpartyNameSnapshot,
    required this.category,
    required this.comment,
    required this.reference,
    required this.creditAmount,
    required this.debitAmount,
    required this.sourceType,
    required this.linkedSupplierInvoiceId,
    required this.linkedFixedPaymentId,
    required this.linkedExternalRef,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'movement_date': date.toIso8601String(),
    'company': company,
    'branch': branch,
    'account_key': accountKey,
    'counterparty_company_id': counterpartyCompanyId,
    'counterparty_name_snapshot': counterpartyNameSnapshot,
    'category': category,
    'comment': comment.trim().isEmpty ? null : comment.trim(),
    'reference': reference.trim().isEmpty ? null : reference.trim(),
    'credit_amount': creditAmount,
    'debit_amount': debitAmount,
    'source_type': sourceType,
    'linked_supplier_invoice_id': linkedSupplierInvoiceId,
    'linked_fixed_payment_id': linkedFixedPaymentId,
    'linked_external_ref': linkedExternalRef,
  };

  factory FinanzasBankMovementRecord.fromRemoteRow(Map<String, dynamic> row) {
    return FinanzasBankMovementRecord(
      id: (row['id'] ?? '').toString(),
      date:
          _tryParseDateTime(row['movement_date'] as String?) ?? DateTime.now(),
      company: (row['company'] ?? 'DICSA').toString(),
      branch: (row['branch'] ?? 'CELAYA').toString(),
      accountKey: (row['account_key'] ?? '').toString(),
      counterpartyCompanyId: row['counterparty_company_id']?.toString(),
      counterpartyNameSnapshot: (row['counterparty_name_snapshot'] ?? '')
          .toString(),
      category: (row['category'] ?? 'OTROS').toString(),
      comment: (row['comment'] ?? '').toString(),
      reference: (row['reference'] ?? '').toString(),
      creditAmount: ((row['credit_amount'] as num?) ?? 0).toDouble(),
      debitAmount: ((row['debit_amount'] as num?) ?? 0).toDouble(),
      sourceType: (row['source_type'] ?? 'MANUAL').toString(),
      linkedSupplierInvoiceId: row['linked_supplier_invoice_id']?.toString(),
      linkedFixedPaymentId: row['linked_fixed_payment_id']?.toString(),
      linkedExternalRef: row['linked_external_ref']?.toString(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasClientPaymentAccountRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String documentNumber;
  final String operationType;
  final double approvedAmount;
  final double paidAmount;
  final String status;
  final DateTime? settlementDate;

  const FinanzasClientPaymentAccountRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.documentNumber,
    required this.operationType,
    required this.approvedAmount,
    required this.paidAmount,
    required this.status,
    required this.settlementDate,
  });

  double get pendingBalance => approvedAmount - paidAmount;

  bool get isOpen =>
      operationType == 'factura' &&
      status != 'pagada' &&
      status != 'chequeCanjeado' &&
      status != 'cancelada' &&
      pendingBalance > 0.009;

  factory FinanzasClientPaymentAccountRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasClientPaymentAccountRecord(
      id: (row['id'] ?? '').toString(),
      clientId: (row['client_id'] ?? '').toString(),
      clientName: (row['client_name_snapshot'] ?? '').toString(),
      documentNumber: (row['document_number'] ?? '').toString(),
      operationType: ((row['operation_type'] ?? 'factura').toString())
          .toLowerCase(),
      approvedAmount: ((row['approved_amount'] as num?) ?? 0).toDouble(),
      paidAmount: ((row['paid_amount'] as num?) ?? 0).toDouble(),
      status: (row['status'] ?? '').toString(),
      settlementDate: _tryParseDateTime(row['settlement_date'] as String?),
    );
  }
}

class FinanzasBankAccountsStore {
  static Future<List<FinanzasBankMovementRecord>> loadMovements() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinBankMovementsTable)
          .select()
          .order('movement_date', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasBankMovementRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasBankMovementRecord>[];
    }
  }

  static Future<void> saveMovement(FinanzasBankMovementRecord row) async {
    final resolvedCounterpartyId = await _ensureCounterpartyExistsInFinanzas(
      counterpartyCompanyId: row.counterpartyCompanyId,
      counterpartyNameSnapshot: row.counterpartyNameSnapshot,
    );
    final resolvedRow = FinanzasBankMovementRecord(
      id: row.id,
      date: row.date,
      company: row.company,
      branch: row.branch,
      accountKey: row.accountKey,
      counterpartyCompanyId: resolvedCounterpartyId,
      counterpartyNameSnapshot: row.counterpartyNameSnapshot,
      category: row.category,
      comment: row.comment,
      reference: row.reference,
      creditAmount: row.creditAmount,
      debitAmount: row.debitAmount,
      sourceType: row.sourceType,
      linkedSupplierInvoiceId: row.linkedSupplierInvoiceId,
      linkedFixedPaymentId: row.linkedFixedPaymentId,
      linkedExternalRef: row.linkedExternalRef,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
    await Supabase.instance.client.from(_kFinBankMovementsTable).upsert(
      <Map<String, dynamic>>[resolvedRow.toUpsertJson()],
      onConflict: 'id',
    );
  }

  static Future<String?> _ensureCounterpartyExistsInFinanzas({
    required String? counterpartyCompanyId,
    required String counterpartyNameSnapshot,
  }) async {
    final resolved = await FinanzasCompanyIdentityResolver.ensureCompanyExists(
      externalCompanyId: counterpartyCompanyId,
      companyNameSnapshot: counterpartyNameSnapshot,
    );
    return resolved.companyId;
  }

  static Future<void> deleteMovement(String id) async {
    await Supabase.instance.client
        .from(_kFinBankMovementsTable)
        .delete()
        .eq('id', id);
  }

  static Future<void> deleteMovementAndReverse(
    FinanzasBankMovementRecord movement,
  ) async {
    if (movement.linkedSupplierInvoiceId != null &&
        movement.linkedSupplierInvoiceId!.isNotEmpty) {
      final invoices = await FinanzasProviderAccountsStore.loadInvoices();
      FinanzasSupplierInvoiceRecord? linkedInvoice;
      for (final row in invoices) {
        if (row.id == movement.linkedSupplierInvoiceId) {
          linkedInvoice = row;
          break;
        }
      }
      if (linkedInvoice != null) {
        final reversedAmount = movement.debitAmount
            .clamp(0, double.infinity)
            .toDouble();
        final nextBalanceAmount = (linkedInvoice.balanceAmount + reversedAmount)
            .clamp(0, linkedInvoice.totalAmount)
            .toDouble();
        final updatedInvoice = linkedInvoice.copyWith(
          balanceAmount: nextBalanceAmount,
          status: deriveSupplierInvoiceStatus(
            balanceAmount: nextBalanceAmount,
            dueDate: linkedInvoice.dueDate,
          ),
        );
        await FinanzasProviderAccountsStore.saveInvoice(updatedInvoice);
        await FinanzasProviderAccountsStore.syncAgreementStateForProvider(
          providerId: linkedInvoice.providerId,
          providerNameSnapshot: linkedInvoice.providerNameSnapshot,
        );

        final invoiceTickets =
            await FinanzasProviderAccountsStore.loadInvoiceTickets();
        final linkedTicketIds = invoiceTickets
            .where((row) => row.invoiceId == updatedInvoice.id)
            .map((row) => row.ticketId)
            .toSet();
        if (linkedTicketIds.isNotEmpty) {
          final allTickets = await ComprasTicketsStore.loadTickets();
          final allApplications =
              await ComprasTicketsStore.loadTicketPaymentApplications();
          final linkedTickets =
              allTickets
                  .where((ticket) => linkedTicketIds.contains(ticket.id))
                  .toList(growable: false)
                ..sort((a, b) {
                  final dateCompare = a.date.compareTo(b.date);
                  if (dateCompare != 0) return dateCompare;
                  return a.ticket.compareTo(b.ticket);
                });
          final directAppliedByTicketId = <String, double>{};
          for (final application in allApplications) {
            if (!linkedTicketIds.contains(application.ticketId)) continue;
            directAppliedByTicketId.update(
              application.ticketId,
              (value) => value + application.appliedAmount,
              ifAbsent: () => application.appliedAmount,
            );
          }
          var invoicePaidRemaining =
              (linkedInvoice.totalAmount - nextBalanceAmount)
                  .clamp(0, linkedInvoice.totalAmount)
                  .toDouble();
          final updatedTickets = linkedTickets
              .map((ticket) {
                final ticketCoverableAmount = ticket.amount < 0
                    ? 0.0
                    : ticket.amount;
                final directApplied = (directAppliedByTicketId[ticket.id] ?? 0)
                    .clamp(0, ticketCoverableAmount)
                    .toDouble();
                final pendingAfterDirect = (ticket.amount - directApplied)
                    .clamp(0, double.infinity)
                    .toDouble();
                final invoiceApplied = invoicePaidRemaining > pendingAfterDirect
                    ? pendingAfterDirect
                    : invoicePaidRemaining;
                invoicePaidRemaining = (invoicePaidRemaining - invoiceApplied)
                    .clamp(0, double.infinity)
                    .toDouble();
                final totalApplied = (directApplied + invoiceApplied)
                    .clamp(0, ticketCoverableAmount)
                    .toDouble();
                final fullyCovered =
                    totalApplied >= ticketCoverableAmount - 0.009;
                final hasAbono = totalApplied > 0.009 && !fullyCovered;
                return ticket.copyWith(
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
              })
              .toList(growable: false);
          if (updatedTickets.isNotEmpty) {
            await ComprasTicketsStore.saveTickets(updatedTickets);
          }
        }
      }
    }

    if (movement.linkedFixedPaymentId != null &&
        movement.linkedFixedPaymentId!.isNotEmpty) {
      final payments = await FinanzasFixedPaymentsStore.loadPayments();
      FinanzasFixedPaymentRecord? linkedPayment;
      for (final row in payments) {
        if (row.id == movement.linkedFixedPaymentId) {
          linkedPayment = row;
          break;
        }
      }
      if (linkedPayment != null) {
        await FinanzasFixedPaymentsStore.savePayment(
          linkedPayment.copyWith(
            status: deriveFixedPaymentOperationalStatus(
              persistedStatus: 'PENDIENTE',
              paymentDate: linkedPayment.paymentDate,
            ),
            executionMethod: null,
            linkedBankMovementId: null,
            settledAt: null,
          ),
        );
      }
    }

    if (movement.sourceType == 'VENTA_FACTURA' &&
        movement.linkedExternalRef != null &&
        movement.linkedExternalRef!.isNotEmpty) {
      final rows = await Supabase.instance.client
          .from(_kMayoreoAccountsTable)
          .select(
            'id, approved_amount, paid_amount, status, operation_type, settlement_date',
          )
          .eq('id', movement.linkedExternalRef!)
          .limit(1);
      if ((rows as List).isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first as Map);
        final approvedAmount = ((row['approved_amount'] as num?) ?? 0)
            .toDouble();
        final paidAmount = ((row['paid_amount'] as num?) ?? 0).toDouble();
        final nextPaidAmount = (paidAmount - movement.creditAmount)
            .clamp(0, approvedAmount)
            .toDouble();
        final operationType = (row['operation_type'] ?? 'factura').toString();
        final currentStatus = (row['status'] ?? '').toString();
        String nextStatus = currentStatus;
        if (nextPaidAmount <= 0.009) {
          nextStatus = operationType == 'cheque'
              ? 'chequePendienteCanje'
              : 'facturadaPendientePago';
        } else if (nextPaidAmount < approvedAmount - 0.009) {
          nextStatus = operationType == 'cheque'
              ? 'chequePendienteCanje'
              : 'facturadaPendientePago';
        }
        await Supabase.instance.client
            .from(_kMayoreoAccountsTable)
            .update(<String, dynamic>{
              'paid_amount': nextPaidAmount,
              'status': nextStatus,
              'settlement_date': nextPaidAmount >= approvedAmount - 0.009
                  ? row['settlement_date']
                  : null,
            })
            .eq('id', movement.linkedExternalRef!);
      }
    }

    final evidenceRows = await Supabase.instance.client
        .from(_kFinEvidenceTable)
        .select('storage_path')
        .eq('owner_type', kFinanzasEvidenceOwnerTypeBankMovement)
        .eq('owner_id', movement.id);
    final storagePaths = (evidenceRows as List)
        .map((row) => (row as Map)['storage_path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (storagePaths.isNotEmpty) {
      try {
        await Supabase.instance.client.storage
            .from(_kFinEvidenceBucket)
            .remove(storagePaths);
      } catch (_) {}
    }
    await Supabase.instance.client
        .from(_kFinEvidenceTable)
        .delete()
        .eq('owner_type', kFinanzasEvidenceOwnerTypeBankMovement)
        .eq('owner_id', movement.id);

    await deleteMovement(movement.id);
  }

  static Future<List<FinanzasClientPaymentAccountRecord>>
  loadOpenClientAccounts() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kMayoreoAccountsTable)
          .select(
            'id, client_id, client_name_snapshot, document_number, operation_type, approved_amount, paid_amount, status, settlement_date',
          )
          .order('document_date', ascending: false)
          .order('sale_date', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasClientPaymentAccountRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((row) => row.isOpen)
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasClientPaymentAccountRecord>[];
    }
  }

  static Future<List<FinanzasFixedPaymentRecord>> loadOpenFixedPayments() {
    return FinanzasFixedPaymentsStore.loadOpenPayments();
  }

  static Future<void> createMovementAndApply({
    required FinanzasBankMovementRecord movement,
    FinanzasSupplierInvoiceRecord? linkedSupplierInvoice,
    FinanzasClientPaymentAccountRecord? linkedClientAccount,
    FinanzasFixedPaymentRecord? linkedFixedPayment,
  }) async {
    await saveMovement(movement);
    final providerCounterpartyId =
        linkedSupplierInvoice?.providerId ?? movement.counterpartyCompanyId;
    if (linkedClientAccount != null) {
      await _applyClientPaymentMovementToMayoreoAccount(
        accountId: linkedClientAccount.id,
        movementDate: movement.date,
        appliedAmount: movement.creditAmount,
      );
      return;
    }
    if (linkedFixedPayment != null) {
      final appliedAmount = movement.debitAmount
          .clamp(0, double.infinity)
          .toDouble();
      assertFullSettlementAmount(
        appliedAmount: appliedAmount,
        expectedAmount: linkedFixedPayment.amount,
        contextLabel: 'El pago fijo',
      );
      await FinanzasFixedPaymentsStore.savePayment(
        linkedFixedPayment.copyWith(
          status: 'PAGADO',
          executionMethod: 'BANCO',
          linkedBankMovementId: movement.id,
          settledAt: movement.date,
        ),
      );
      return;
    }
    if (linkedSupplierInvoice == null) {
      if (providerCounterpartyId != null &&
          movement.debitAmount > 0.009 &&
          movement.sourceType != 'VENTA_FACTURA') {
        await FinanzasProviderAccountsStore.syncAgreementStateForProvider(
          providerId: providerCounterpartyId,
          providerNameSnapshot: movement.counterpartyNameSnapshot,
        );
      }
      return;
    }

    final appliedAmount = movement.debitAmount
        .clamp(0, double.infinity)
        .toDouble();
    if (appliedAmount <= 0.009) return;
    assertFullSettlementAmount(
      appliedAmount: appliedAmount,
      expectedAmount: linkedSupplierInvoice.balanceAmount,
      contextLabel: 'La factura proveedor',
    );
    final nextBalanceAmount =
        (linkedSupplierInvoice.balanceAmount - appliedAmount)
            .clamp(0, linkedSupplierInvoice.totalAmount)
            .toDouble();
    final updatedInvoice = linkedSupplierInvoice.copyWith(
      balanceAmount: nextBalanceAmount,
      status: deriveSupplierInvoiceStatus(
        balanceAmount: nextBalanceAmount,
        dueDate: linkedSupplierInvoice.dueDate,
      ),
    );
    await FinanzasProviderAccountsStore.saveInvoice(updatedInvoice);
    await FinanzasProviderAccountsStore.syncAgreementStateForProvider(
      providerId: linkedSupplierInvoice.providerId,
      providerNameSnapshot: linkedSupplierInvoice.providerNameSnapshot,
    );

    final invoiceTickets =
        await FinanzasProviderAccountsStore.loadInvoiceTickets();
    final linkedTicketIds = invoiceTickets
        .where((row) => row.invoiceId == linkedSupplierInvoice.id)
        .map((row) => row.ticketId)
        .toSet();
    if (linkedTicketIds.isEmpty) return;
    final allTickets = await ComprasTicketsStore.loadTickets();
    final allApplications =
        await ComprasTicketsStore.loadTicketPaymentApplications();
    final linkedTickets =
        allTickets
            .where((ticket) => linkedTicketIds.contains(ticket.id))
            .toList(growable: false)
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.ticket.compareTo(b.ticket);
          });
    final directAppliedByTicketId = <String, double>{};
    for (final application in allApplications) {
      if (!linkedTicketIds.contains(application.ticketId)) continue;
      directAppliedByTicketId.update(
        application.ticketId,
        (value) => value + application.appliedAmount,
        ifAbsent: () => application.appliedAmount,
      );
    }
    var invoicePaidRemaining =
        (linkedSupplierInvoice.totalAmount - nextBalanceAmount)
            .clamp(0, linkedSupplierInvoice.totalAmount)
            .toDouble();
    final updatedTickets = linkedTickets
        .map((ticket) {
          final ticketCoverableAmount = ticket.amount < 0 ? 0.0 : ticket.amount;
          final directApplied = (directAppliedByTicketId[ticket.id] ?? 0)
              .clamp(0, ticketCoverableAmount)
              .toDouble();
          final pendingAfterDirect = (ticket.amount - directApplied)
              .clamp(0, double.infinity)
              .toDouble();
          final invoiceApplied = invoicePaidRemaining > pendingAfterDirect
              ? pendingAfterDirect
              : invoicePaidRemaining;
          invoicePaidRemaining = (invoicePaidRemaining - invoiceApplied)
              .clamp(0, double.infinity)
              .toDouble();
          final totalApplied = (directApplied + invoiceApplied)
              .clamp(0, ticketCoverableAmount)
              .toDouble();
          final fullyCovered = totalApplied >= ticketCoverableAmount - 0.009;
          final hasAbono = totalApplied > 0.009 && !fullyCovered;
          return ticket.copyWith(
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
        })
        .toList(growable: false);
    if (updatedTickets.isEmpty) return;
    await ComprasTicketsStore.saveTickets(updatedTickets);
  }

  static Future<void> updateMovementAndApplyClientPayment({
    required FinanzasBankMovementRecord previousMovement,
    required FinanzasBankMovementRecord nextMovement,
  }) async {
    if (previousMovement.sourceType == 'VENTA_FACTURA' &&
        previousMovement.linkedExternalRef != null &&
        previousMovement.linkedExternalRef!.isNotEmpty) {
      await _reverseClientPaymentMovementFromMayoreoAccount(
        accountId: previousMovement.linkedExternalRef!,
        reversedAmount: previousMovement.creditAmount,
      );
    }
    await saveMovement(nextMovement);
    if (nextMovement.sourceType == 'VENTA_FACTURA' &&
        nextMovement.linkedExternalRef != null &&
        nextMovement.linkedExternalRef!.isNotEmpty) {
      await _applyClientPaymentMovementToMayoreoAccount(
        accountId: nextMovement.linkedExternalRef!,
        movementDate: nextMovement.date,
        appliedAmount: nextMovement.creditAmount,
      );
    }
  }

  static Future<void> _applyClientPaymentMovementToMayoreoAccount({
    required String accountId,
    required DateTime movementDate,
    required double appliedAmount,
  }) async {
    final normalizedAmount = appliedAmount.clamp(0, double.infinity).toDouble();
    if (normalizedAmount <= 0.009 || accountId.trim().isEmpty) return;
    final rows = await Supabase.instance.client
        .from(_kMayoreoAccountsTable)
        .select(
          'id, approved_amount, paid_amount, status, operation_type, settlement_date',
        )
        .eq('id', accountId)
        .limit(1);
    if ((rows as List).isEmpty) return;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final approvedAmount = ((row['approved_amount'] as num?) ?? 0).toDouble();
    final paidAmount = ((row['paid_amount'] as num?) ?? 0).toDouble();
    final currentStatus = (row['status'] ?? '').toString();
    final nextPaidAmount = (paidAmount + normalizedAmount)
        .clamp(0, approvedAmount)
        .toDouble();
    final fullySettled = nextPaidAmount >= approvedAmount - 0.009;
    final partiallySettled = nextPaidAmount > 0.009 && !fullySettled;
    await Supabase.instance.client
        .from(_kMayoreoAccountsTable)
        .update(<String, dynamic>{
          'paid_amount': nextPaidAmount,
          'status': fullySettled
              ? 'pagada'
              : partiallySettled
              ? 'pagoParcial'
              : currentStatus,
          'settlement_date': nextPaidAmount > 0.009
              ? movementDate.toIso8601String()
              : null,
        })
        .eq('id', accountId);
  }

  static Future<void> _reverseClientPaymentMovementFromMayoreoAccount({
    required String accountId,
    required double reversedAmount,
  }) async {
    final normalizedAmount = reversedAmount
        .clamp(0, double.infinity)
        .toDouble();
    if (normalizedAmount <= 0.009 || accountId.trim().isEmpty) return;
    final rows = await Supabase.instance.client
        .from(_kMayoreoAccountsTable)
        .select(
          'id, approved_amount, paid_amount, status, operation_type, settlement_date',
        )
        .eq('id', accountId)
        .limit(1);
    if ((rows as List).isEmpty) return;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final approvedAmount = ((row['approved_amount'] as num?) ?? 0).toDouble();
    final paidAmount = ((row['paid_amount'] as num?) ?? 0).toDouble();
    final operationType = (row['operation_type'] ?? 'factura').toString();
    final nextPaidAmount = (paidAmount - normalizedAmount)
        .clamp(0, approvedAmount)
        .toDouble();
    final nextStatus = nextPaidAmount <= 0.009
        ? operationType == 'cheque'
              ? 'chequePendienteCanje'
              : 'facturadaPendientePago'
        : nextPaidAmount >= approvedAmount - 0.009
        ? operationType == 'cheque'
              ? 'chequeCanjeado'
              : 'pagada'
        : operationType == 'cheque'
        ? 'chequePendienteCanje'
        : 'pagoParcial';
    await Supabase.instance.client
        .from(_kMayoreoAccountsTable)
        .update(<String, dynamic>{
          'paid_amount': nextPaidAmount,
          'status': nextStatus,
          'settlement_date': nextPaidAmount >= approvedAmount - 0.009
              ? row['settlement_date']
              : null,
        })
        .eq('id', accountId);
  }
}

String buildFinBankAccountKey({
  required String company,
  required String branch,
}) {
  return '${company.trim().toUpperCase()}_${branch.trim().toUpperCase()}';
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
