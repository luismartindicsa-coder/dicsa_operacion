import 'package:supabase_flutter/supabase_flutter.dart';

import '../compras/compras_tickets_store.dart';
import '../mayoreo/mayoreo_financial_status.dart';
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

String? finBankMovementDirectionValidationMessage({
  required String category,
  required double creditAmount,
  required double debitAmount,
}) {
  final normalizedCategory = category.trim().toUpperCase();
  if (normalizedCategory == 'VENTAS') {
    if (creditAmount <= 0.009 || debitAmount > 0.009) {
      return 'La categoría VENTAS debe registrarse como abono, no como cargo.';
    }
  }
  return null;
}

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
  final double? appliedSupplierAmount;
  final double settlementDifferenceAmount;
  final String? settlementDifferenceReason;
  final String? settlementDifferenceNote;
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
    required this.appliedSupplierAmount,
    required this.settlementDifferenceAmount,
    required this.settlementDifferenceReason,
    required this.settlementDifferenceNote,
    required this.linkedFixedPaymentId,
    required this.linkedExternalRef,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasLinkedSupplierInvoice =>
      sourceType == 'COMPRA_FACTURA' &&
      linkedSupplierInvoiceId != null &&
      linkedSupplierInvoiceId!.trim().isNotEmpty;

  double get effectiveSupplierAppliedAmount =>
      resolveEffectiveSupplierAppliedAmount(
        debitAmount: debitAmount,
        appliedSupplierAmount: appliedSupplierAmount,
      );

  double get effectiveSettlementDifferenceAmount => hasLinkedSupplierInvoice
      ? computeSupplierSettlementDifferenceAmount(
          debitAmount: debitAmount,
          appliedSupplierAmount: appliedSupplierAmount,
        )
      : 0;

  FinanzasBankMovementRecord copyWith({
    String? id,
    DateTime? date,
    String? company,
    String? branch,
    String? accountKey,
    String? counterpartyCompanyId,
    String? counterpartyNameSnapshot,
    String? category,
    String? comment,
    String? reference,
    double? creditAmount,
    double? debitAmount,
    String? sourceType,
    String? linkedSupplierInvoiceId,
    double? appliedSupplierAmount,
    bool clearAppliedSupplierAmount = false,
    double? settlementDifferenceAmount,
    String? settlementDifferenceReason,
    bool clearSettlementDifferenceReason = false,
    String? settlementDifferenceNote,
    bool clearSettlementDifferenceNote = false,
    String? linkedFixedPaymentId,
    String? linkedExternalRef,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanzasBankMovementRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      company: company ?? this.company,
      branch: branch ?? this.branch,
      accountKey: accountKey ?? this.accountKey,
      counterpartyCompanyId:
          counterpartyCompanyId ?? this.counterpartyCompanyId,
      counterpartyNameSnapshot:
          counterpartyNameSnapshot ?? this.counterpartyNameSnapshot,
      category: category ?? this.category,
      comment: comment ?? this.comment,
      reference: reference ?? this.reference,
      creditAmount: creditAmount ?? this.creditAmount,
      debitAmount: debitAmount ?? this.debitAmount,
      sourceType: sourceType ?? this.sourceType,
      linkedSupplierInvoiceId:
          linkedSupplierInvoiceId ?? this.linkedSupplierInvoiceId,
      appliedSupplierAmount: clearAppliedSupplierAmount
          ? null
          : appliedSupplierAmount ?? this.appliedSupplierAmount,
      settlementDifferenceAmount:
          settlementDifferenceAmount ?? this.settlementDifferenceAmount,
      settlementDifferenceReason: clearSettlementDifferenceReason
          ? null
          : settlementDifferenceReason ?? this.settlementDifferenceReason,
      settlementDifferenceNote: clearSettlementDifferenceNote
          ? null
          : settlementDifferenceNote ?? this.settlementDifferenceNote,
      linkedFixedPaymentId: linkedFixedPaymentId ?? this.linkedFixedPaymentId,
      linkedExternalRef: linkedExternalRef ?? this.linkedExternalRef,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() {
    final json = <String, dynamic>{
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
    final hasSupplierDeltaMetadata =
        (appliedSupplierAmount != null &&
            (appliedSupplierAmount! - debitAmount).abs() > 0.009) ||
        settlementDifferenceAmount.abs() > 0.009 ||
        (settlementDifferenceReason != null &&
            settlementDifferenceReason!.trim().isNotEmpty) ||
        (settlementDifferenceNote != null &&
            settlementDifferenceNote!.trim().isNotEmpty);
    if (hasSupplierDeltaMetadata) {
      json['applied_supplier_amount'] = appliedSupplierAmount;
      json['settlement_difference_amount'] = settlementDifferenceAmount;
      json['settlement_difference_reason'] = settlementDifferenceReason;
      json['settlement_difference_note'] = settlementDifferenceNote;
    }
    return json;
  }

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
      appliedSupplierAmount: (row['applied_supplier_amount'] as num?)
          ?.toDouble(),
      settlementDifferenceAmount:
          ((row['settlement_difference_amount'] as num?) ?? 0).toDouble(),
      settlementDifferenceReason: row['settlement_difference_reason']
          ?.toString(),
      settlementDifferenceNote: row['settlement_difference_note']?.toString(),
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
      return await loadMovementsStrict();
    } catch (_) {
      return const <FinanzasBankMovementRecord>[];
    }
  }

  static Future<List<FinanzasBankMovementRecord>> loadMovementsStrict() async {
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
  }

  static Future<void> saveMovement(FinanzasBankMovementRecord row) async {
    final directionError = finBankMovementDirectionValidationMessage(
      category: row.category,
      creditAmount: row.creditAmount,
      debitAmount: row.debitAmount,
    );
    if (directionError != null) {
      throw ArgumentError(directionError);
    }
    final resolvedCounterpartyId = await _ensureCounterpartyExistsInFinanzas(
      counterpartyCompanyId: row.counterpartyCompanyId,
      counterpartyNameSnapshot: row.counterpartyNameSnapshot,
    );
    final hasLinkedSupplierInvoice =
        row.sourceType == 'COMPRA_FACTURA' &&
        row.linkedSupplierInvoiceId != null &&
        row.linkedSupplierInvoiceId!.trim().isNotEmpty;
    final appliedSupplierAmount = hasLinkedSupplierInvoice
        ? row.effectiveSupplierAppliedAmount
        : null;
    final settlementDifferenceAmount = hasLinkedSupplierInvoice
        ? row.effectiveSettlementDifferenceAmount
        : 0.0;
    final settlementDifferenceReason =
        hasLinkedSupplierInvoice && settlementDifferenceAmount.abs() > 0.009
        ? row.settlementDifferenceReason?.trim()
        : null;
    final settlementDifferenceNote =
        hasLinkedSupplierInvoice && settlementDifferenceAmount.abs() > 0.009
        ? row.settlementDifferenceNote?.trim()
        : null;
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
      appliedSupplierAmount: appliedSupplierAmount,
      settlementDifferenceAmount: settlementDifferenceAmount,
      settlementDifferenceReason:
          settlementDifferenceReason == null ||
              settlementDifferenceReason.isEmpty
          ? null
          : settlementDifferenceReason,
      settlementDifferenceNote:
          settlementDifferenceNote == null || settlementDifferenceNote.isEmpty
          ? null
          : settlementDifferenceNote,
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

  static Future<FinanzasSupplierInvoiceRecord?> _loadSupplierInvoiceById(
    String? invoiceId,
  ) async {
    if (invoiceId == null || invoiceId.trim().isEmpty) return null;
    final invoices = await FinanzasProviderAccountsStore.loadInvoices();
    for (final row in invoices) {
      if (row.id == invoiceId) return row;
    }
    return null;
  }

  static Future<void> _persistSupplierInvoiceBalanceAndCoverage(
    FinanzasSupplierInvoiceRecord invoice, {
    required double nextBalanceAmount,
  }) async {
    final updatedInvoice = invoice.copyWith(
      balanceAmount: nextBalanceAmount,
      status: deriveSupplierInvoiceStatus(
        balanceAmount: nextBalanceAmount,
        dueDate: invoice.dueDate,
      ),
    );
    await FinanzasProviderAccountsStore.saveInvoice(updatedInvoice);
    await FinanzasProviderAccountsStore.syncAgreementStateForProvider(
      providerId: updatedInvoice.providerId,
      providerNameSnapshot: updatedInvoice.providerNameSnapshot,
    );

    final invoiceTickets =
        await FinanzasProviderAccountsStore.loadInvoiceTickets();
    final linkedTicketIds = invoiceTickets
        .where((row) => row.invoiceId == updatedInvoice.id)
        .map((row) => row.ticketId)
        .toSet();
    if (linkedTicketIds.isEmpty) return;

    final allTickets = await ComprasTicketsStore.loadTickets();
    final allApplications =
        await ComprasTicketsStore.loadTicketPaymentApplications();
    final linkedTickets = allTickets
        .where((ticket) => linkedTicketIds.contains(ticket.id))
        .toList(growable: false);
    if (linkedTickets.isEmpty) return;

    final directAppliedByTicketId = <String, double>{};
    for (final application in allApplications) {
      if (!linkedTicketIds.contains(application.ticketId)) continue;
      directAppliedByTicketId.update(
        application.ticketId,
        (value) => value + application.appliedAmount,
        ifAbsent: () => application.appliedAmount,
      );
    }

    final coverageByTicketId = computeInvoiceTicketCoverage(
      invoiceTotalAmount: updatedInvoice.totalAmount,
      invoiceBalanceAmount: updatedInvoice.balanceAmount,
      tickets: linkedTickets
          .map(
            (ticket) => InvoiceTicketSnapshot(
              ticketId: ticket.id,
              ticketAmount: ticket.amount < 0 ? 0.0 : ticket.amount,
              ticketDate: ticket.date,
              ticketNumber: ticket.ticket,
            ),
          )
          .toList(growable: false),
      directAppliedByTicketId: directAppliedByTicketId,
    );

    final updatedTickets = linkedTickets
        .map((ticket) {
          final coverage = coverageByTicketId[ticket.id];
          if (coverage == null) return ticket;
          return ticket.copyWith(
            pagoStatus: coverage.pagoStatus,
            coverageStatus: coverage.coverageStatus,
          );
        })
        .toList(growable: false);
    await ComprasTicketsStore.saveTickets(updatedTickets);
  }

  static Future<void> _applySupplierInvoiceSettlement({
    required FinanzasSupplierInvoiceRecord linkedInvoice,
    required FinanzasBankMovementRecord movement,
  }) async {
    final appliedAmount = movement.effectiveSupplierAppliedAmount;
    if (appliedAmount <= 0.009) return;
    assertSupplierSettlementAmountAllowed(
      debitAmount: movement.debitAmount.clamp(0, double.infinity).toDouble(),
      expectedSupplierAmount: linkedInvoice.balanceAmount,
      appliedSupplierAmount: movement.appliedSupplierAmount,
      differenceReason: movement.settlementDifferenceReason,
    );
    final nextBalanceAmount = (linkedInvoice.balanceAmount - appliedAmount)
        .clamp(0, linkedInvoice.totalAmount)
        .toDouble();
    await _persistSupplierInvoiceBalanceAndCoverage(
      linkedInvoice,
      nextBalanceAmount: nextBalanceAmount,
    );
  }

  static Future<void> _reverseSupplierInvoiceSettlement({
    required FinanzasSupplierInvoiceRecord linkedInvoice,
    required FinanzasBankMovementRecord movement,
  }) async {
    final reversedAmount = movement.effectiveSupplierAppliedAmount;
    if (reversedAmount <= 0.009) return;
    final nextBalanceAmount = (linkedInvoice.balanceAmount + reversedAmount)
        .clamp(0, linkedInvoice.totalAmount)
        .toDouble();
    await _persistSupplierInvoiceBalanceAndCoverage(
      linkedInvoice,
      nextBalanceAmount: nextBalanceAmount,
    );
  }

  static Future<void> deleteMovementAndReverse(
    FinanzasBankMovementRecord movement,
  ) async {
    if (movement.linkedSupplierInvoiceId != null &&
        movement.linkedSupplierInvoiceId!.isNotEmpty) {
      final linkedInvoice = await _loadSupplierInvoiceById(
        movement.linkedSupplierInvoiceId,
      );
      if (linkedInvoice != null) {
        await _reverseSupplierInvoiceSettlement(
          linkedInvoice: linkedInvoice,
          movement: movement,
        );
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
            'id, approved_amount, paid_amount, status, operation_type, settlement_date, client_name_snapshot, document_number, document_date',
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
        final clientName = (row['client_name_snapshot'] ?? '').toString();
        final documentNumber = (row['document_number'] ?? '').toString();
        final documentDate = _tryParseDateTime(row['document_date'] as String?);
        final currentSettlementDate = _tryParseDateTime(
          row['settlement_date'] as String?,
        );
        final nextSettlementDate = operationType == 'cheque'
            ? nextPaidAmount >= approvedAmount - 0.009
                  ? currentSettlementDate
                  : null
            : nextPaidAmount > 0.009
            ? currentSettlementDate
            : null;
        final nextStatus = deriveMayoreoFinancialStatus(
          baseStatus: currentStatus,
          operationType: operationType,
          isPalomarAccount: isMayoreoPalomarClientName(clientName),
          documentNumber: documentNumber,
          documentDate: documentDate,
          settlementDate: nextSettlementDate,
          paidAmount: nextPaidAmount,
          approvedAmount: approvedAmount,
        );
        await Supabase.instance.client
            .from(_kMayoreoAccountsTable)
            .update(<String, dynamic>{
              'paid_amount': nextPaidAmount,
              'status': nextStatus,
              'settlement_date': nextSettlementDate?.toIso8601String(),
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
    final providerCounterpartyId =
        linkedSupplierInvoice?.providerId ?? movement.counterpartyCompanyId;
    if (linkedClientAccount != null) {
      await saveMovement(movement);
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
      await saveMovement(movement);
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
      await saveMovement(movement);
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

    assertSupplierSettlementAmountAllowed(
      debitAmount: movement.debitAmount.clamp(0, double.infinity).toDouble(),
      expectedSupplierAmount: linkedSupplierInvoice.balanceAmount,
      appliedSupplierAmount: movement.appliedSupplierAmount,
      differenceReason: movement.settlementDifferenceReason,
    );
    await saveMovement(movement);
    await _applySupplierInvoiceSettlement(
      linkedInvoice: linkedSupplierInvoice,
      movement: movement,
    );
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

  static Future<void> updateMovementAndApplySupplierSettlement({
    required FinanzasBankMovementRecord previousMovement,
    required FinanzasBankMovementRecord nextMovement,
  }) async {
    if (!previousMovement.hasLinkedSupplierInvoice ||
        !nextMovement.hasLinkedSupplierInvoice) {
      throw StateError(
        'La edicion protegida solo aplica a movimientos ligados a factura proveedor.',
      );
    }
    if (previousMovement.linkedSupplierInvoiceId !=
        nextMovement.linkedSupplierInvoiceId) {
      throw StateError(
        'No se puede cambiar la factura ligada desde esta edicion protegida.',
      );
    }
    assertSupplierSettlementAmountAllowed(
      debitAmount: nextMovement.debitAmount
          .clamp(0, double.infinity)
          .toDouble(),
      expectedSupplierAmount: previousMovement.effectiveSupplierAppliedAmount,
      appliedSupplierAmount: nextMovement.appliedSupplierAmount,
      differenceReason: nextMovement.settlementDifferenceReason,
    );
    final linkedInvoice = await _loadSupplierInvoiceById(
      previousMovement.linkedSupplierInvoiceId,
    );
    if (linkedInvoice == null) {
      await saveMovement(nextMovement);
      return;
    }
    await _reverseSupplierInvoiceSettlement(
      linkedInvoice: linkedInvoice,
      movement: previousMovement,
    );
    await saveMovement(nextMovement);
    final refreshedInvoice = await _loadSupplierInvoiceById(
      nextMovement.linkedSupplierInvoiceId,
    );
    if (refreshedInvoice == null) return;
    await _applySupplierInvoiceSettlement(
      linkedInvoice: refreshedInvoice,
      movement: nextMovement,
    );
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
          'id, approved_amount, paid_amount, status, operation_type, settlement_date, client_name_snapshot, document_number, document_date',
        )
        .eq('id', accountId)
        .limit(1);
    if ((rows as List).isEmpty) return;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final approvedAmount = ((row['approved_amount'] as num?) ?? 0).toDouble();
    final paidAmount = ((row['paid_amount'] as num?) ?? 0).toDouble();
    final currentStatus = (row['status'] ?? '').toString();
    final operationType = (row['operation_type'] ?? 'factura').toString();
    final clientName = (row['client_name_snapshot'] ?? '').toString();
    final documentNumber = (row['document_number'] ?? '').toString();
    final documentDate = _tryParseDateTime(row['document_date'] as String?);
    final nextPaidAmount = (paidAmount + normalizedAmount)
        .clamp(0, approvedAmount)
        .toDouble();
    final nextSettlementDate = operationType == 'cheque'
        ? nextPaidAmount >= approvedAmount - 0.009
              ? movementDate
              : null
        : nextPaidAmount > 0.009
        ? movementDate
        : null;
    final nextStatus = deriveMayoreoFinancialStatus(
      baseStatus: currentStatus,
      operationType: operationType,
      isPalomarAccount: isMayoreoPalomarClientName(clientName),
      documentNumber: documentNumber,
      documentDate: documentDate,
      settlementDate: nextSettlementDate,
      paidAmount: nextPaidAmount,
      approvedAmount: approvedAmount,
    );
    await Supabase.instance.client
        .from(_kMayoreoAccountsTable)
        .update(<String, dynamic>{
          'paid_amount': nextPaidAmount,
          'status': nextStatus,
          'settlement_date': nextSettlementDate?.toIso8601String(),
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
          'id, approved_amount, paid_amount, status, operation_type, settlement_date, client_name_snapshot, document_number, document_date',
        )
        .eq('id', accountId)
        .limit(1);
    if ((rows as List).isEmpty) return;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final approvedAmount = ((row['approved_amount'] as num?) ?? 0).toDouble();
    final paidAmount = ((row['paid_amount'] as num?) ?? 0).toDouble();
    final operationType = (row['operation_type'] ?? 'factura').toString();
    final currentStatus = (row['status'] ?? '').toString();
    final clientName = (row['client_name_snapshot'] ?? '').toString();
    final documentNumber = (row['document_number'] ?? '').toString();
    final documentDate = _tryParseDateTime(row['document_date'] as String?);
    final currentSettlementDate = _tryParseDateTime(
      row['settlement_date'] as String?,
    );
    final nextPaidAmount = (paidAmount - normalizedAmount)
        .clamp(0, approvedAmount)
        .toDouble();
    final nextSettlementDate = operationType == 'cheque'
        ? nextPaidAmount >= approvedAmount - 0.009
              ? currentSettlementDate
              : null
        : nextPaidAmount > 0.009
        ? currentSettlementDate
        : null;
    final nextStatus = deriveMayoreoFinancialStatus(
      baseStatus: currentStatus,
      operationType: operationType,
      isPalomarAccount: isMayoreoPalomarClientName(clientName),
      documentNumber: documentNumber,
      documentDate: documentDate,
      settlementDate: nextSettlementDate,
      paidAmount: nextPaidAmount,
      approvedAmount: approvedAmount,
    );
    await Supabase.instance.client
        .from(_kMayoreoAccountsTable)
        .update(<String, dynamic>{
          'paid_amount': nextPaidAmount,
          'status': nextStatus,
          'settlement_date': nextSettlementDate?.toIso8601String(),
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
