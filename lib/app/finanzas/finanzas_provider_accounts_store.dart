import 'package:supabase_flutter/supabase_flutter.dart';

import '../compras/compras_tickets_store.dart';
import 'finanzas_financial_rules.dart';

const String _kFinSupplierInvoicesTable = 'finanzas_supplier_invoices';
const String _kFinSupplierInvoiceTicketsTable =
    'finanzas_supplier_invoice_tickets';
const String _kFinSupplierAgreementsTable = 'finanzas_supplier_agreements';
const String _kFinSupplierAgreementInstallmentsTable =
    'finanzas_supplier_agreement_installments';
const String _kFinSupplierAgreementInvoicesTable =
    'finanzas_supplier_agreement_invoices';
const String _kFinBankMovementsTable = 'finanzas_bank_movements';

const List<String> kFinSupplierInvoiceStatuses = <String>[
  'PENDIENTE',
  'PARCIAL',
  'PAGADA',
  'VENCIDA',
  'CONVENIO',
];

String finSupplierInvoiceStatusLabel(String value) {
  switch (value) {
    case 'PARCIAL':
      return 'Parcial';
    case 'PAGADA':
      return 'Pagada';
    case 'VENCIDA':
      return 'Vencida';
    case 'CONVENIO':
      return 'Convenio';
    default:
      return 'Pendiente';
  }
}

const List<String> kFinSupplierAgreementFrequencies = <String>[
  'SEMANAL',
  'QUINCENAL',
  'MENSUAL',
];

const List<String> kFinSupplierAgreementTypes = <String>[
  'POR_MONTO',
  'POR_FACTURAS',
];

String finSupplierAgreementFrequencyLabel(String value) {
  switch (value) {
    case 'QUINCENAL':
      return 'Quincenal';
    case 'MENSUAL':
      return 'Mensual';
    default:
      return 'Semanal';
  }
}

String finSupplierAgreementTypeLabel(String value) {
  switch (value) {
    case 'POR_FACTURAS':
      return 'Por facturas';
    default:
      return 'Por monto';
  }
}

String finSupplierAgreementStatusLabel(String value) {
  switch (value) {
    case 'CUMPLIDO':
      return 'Cumplido';
    case 'ATRASADO':
      return 'Atrasado';
    case 'CANCELADO':
      return 'Cancelado';
    default:
      return 'Activo';
  }
}

class FinanzasSupplierInvoiceRecord {
  final String id;
  final String providerId;
  final String providerNameSnapshot;
  final String targetCompany;
  final String targetBranch;
  final String folio;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double totalAmount;
  final double balanceAmount;
  final String status;
  final String notes;
  final String manualPriority;
  final String priorityNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasSupplierInvoiceRecord({
    required this.id,
    required this.providerId,
    required this.providerNameSnapshot,
    required this.targetCompany,
    required this.targetBranch,
    required this.folio,
    required this.invoiceDate,
    required this.dueDate,
    required this.totalAmount,
    required this.balanceAmount,
    required this.status,
    required this.notes,
    required this.manualPriority,
    required this.priorityNote,
    required this.createdAt,
    required this.updatedAt,
  });

  FinanzasSupplierInvoiceRecord copyWith({
    String? id,
    String? providerId,
    String? providerNameSnapshot,
    String? targetCompany,
    String? targetBranch,
    String? folio,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double? totalAmount,
    double? balanceAmount,
    String? status,
    String? notes,
    String? manualPriority,
    String? priorityNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanzasSupplierInvoiceRecord(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerNameSnapshot: providerNameSnapshot ?? this.providerNameSnapshot,
      targetCompany: targetCompany ?? this.targetCompany,
      targetBranch: targetBranch ?? this.targetBranch,
      folio: folio ?? this.folio,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      totalAmount: totalAmount ?? this.totalAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      manualPriority: manualPriority ?? this.manualPriority,
      priorityNote: priorityNote ?? this.priorityNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'provider_id': providerId,
    'provider_name_snapshot': providerNameSnapshot,
    'target_company': targetCompany,
    'target_branch': targetBranch,
    'invoice_folio': folio,
    'invoice_date': invoiceDate.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'total_amount': totalAmount,
    'balance_amount': balanceAmount,
    'status': status,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
    'manual_priority': manualPriority,
    'priority_note': priorityNote.trim().isEmpty ? null : priorityNote.trim(),
  };

  factory FinanzasSupplierInvoiceRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasSupplierInvoiceRecord(
      id: (row['id'] ?? '').toString(),
      providerId: (row['provider_id'] ?? '').toString(),
      providerNameSnapshot: (row['provider_name_snapshot'] ?? '').toString(),
      targetCompany: (row['target_company'] ?? 'DICSA').toString(),
      targetBranch: (row['target_branch'] ?? 'CELAYA').toString(),
      folio: (row['invoice_folio'] ?? '').toString(),
      invoiceDate:
          _tryParseDateTime(row['invoice_date'] as String?) ?? DateTime.now(),
      dueDate: _tryParseDateTime(row['due_date'] as String?),
      totalAmount: ((row['total_amount'] as num?) ?? 0).toDouble(),
      balanceAmount: ((row['balance_amount'] as num?) ?? 0).toDouble(),
      status: (row['status'] as String?) ?? 'PENDIENTE',
      notes: (row['notes'] ?? '').toString(),
      manualPriority: (row['manual_priority'] ?? 'NORMAL').toString(),
      priorityNote: (row['priority_note'] ?? '').toString(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasSupplierInvoiceTicketRecord {
  final String id;
  final String invoiceId;
  final String ticketId;
  final double appliedAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasSupplierInvoiceTicketRecord({
    required this.id,
    required this.invoiceId,
    required this.ticketId,
    required this.appliedAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'invoice_id': invoiceId,
    'ticket_id': ticketId,
    'applied_amount': appliedAmount,
  };

  factory FinanzasSupplierInvoiceTicketRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasSupplierInvoiceTicketRecord(
      id: (row['id'] ?? '').toString(),
      invoiceId: (row['invoice_id'] ?? '').toString(),
      ticketId: (row['ticket_id'] ?? '').toString(),
      appliedAmount: ((row['applied_amount'] as num?) ?? 0).toDouble(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasSupplierAgreementRecord {
  final String id;
  final String providerId;
  final String providerNameSnapshot;
  final String targetCompany;
  final String targetBranch;
  final DateTime startDate;
  final String agreementType;
  final String frequency;
  final double installmentAmount;
  final int installmentCount;
  final int invoicesPerPeriod;
  final int scheduledInvoiceCount;
  final double totalAmount;
  final double remainingAmount;
  final DateTime? nextDueDate;
  final String status;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasSupplierAgreementRecord({
    required this.id,
    required this.providerId,
    required this.providerNameSnapshot,
    required this.targetCompany,
    required this.targetBranch,
    required this.startDate,
    required this.agreementType,
    required this.frequency,
    required this.installmentAmount,
    required this.installmentCount,
    required this.invoicesPerPeriod,
    required this.scheduledInvoiceCount,
    required this.totalAmount,
    required this.remainingAmount,
    required this.nextDueDate,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'provider_id': providerId,
    'provider_name_snapshot': providerNameSnapshot,
    'target_company': targetCompany,
    'target_branch': targetBranch,
    'start_date': startDate.toIso8601String(),
    'agreement_type': agreementType,
    'frequency': frequency,
    'installment_amount': installmentAmount,
    'installment_count': installmentCount,
    'invoices_per_period': invoicesPerPeriod,
    'scheduled_invoice_count': scheduledInvoiceCount,
    'total_amount': totalAmount,
    'remaining_amount': remainingAmount,
    'next_due_date': nextDueDate?.toIso8601String(),
    'status': status,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
  };

  factory FinanzasSupplierAgreementRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasSupplierAgreementRecord(
      id: (row['id'] ?? '').toString(),
      providerId: (row['provider_id'] ?? '').toString(),
      providerNameSnapshot: (row['provider_name_snapshot'] ?? '').toString(),
      targetCompany: (row['target_company'] ?? 'DICSA').toString(),
      targetBranch: (row['target_branch'] ?? 'CELAYA').toString(),
      startDate:
          _tryParseDateTime(row['start_date'] as String?) ?? DateTime.now(),
      agreementType: (row['agreement_type'] ?? 'POR_MONTO').toString(),
      frequency: (row['frequency'] ?? 'SEMANAL').toString(),
      installmentAmount: ((row['installment_amount'] as num?) ?? 0).toDouble(),
      installmentCount: ((row['installment_count'] as num?) ?? 0).toInt(),
      invoicesPerPeriod: ((row['invoices_per_period'] as num?) ?? 0).toInt(),
      scheduledInvoiceCount: ((row['scheduled_invoice_count'] as num?) ?? 0)
          .toInt(),
      totalAmount: ((row['total_amount'] as num?) ?? 0).toDouble(),
      remainingAmount: ((row['remaining_amount'] as num?) ?? 0).toDouble(),
      nextDueDate: _tryParseDateTime(row['next_due_date'] as String?),
      status: (row['status'] ?? 'ACTIVO').toString(),
      notes: (row['notes'] ?? '').toString(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasSupplierAgreementInstallmentRecord {
  final String id;
  final String agreementId;
  final int sequenceNumber;
  final DateTime dueDate;
  final String commitmentType;
  final int scheduledInvoiceCount;
  final double amount;
  final double paidAmount;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasSupplierAgreementInstallmentRecord({
    required this.id,
    required this.agreementId,
    required this.sequenceNumber,
    required this.dueDate,
    required this.commitmentType,
    required this.scheduledInvoiceCount,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'agreement_id': agreementId,
    'sequence_number': sequenceNumber,
    'due_date': dueDate.toIso8601String(),
    'commitment_type': commitmentType,
    'scheduled_invoice_count': scheduledInvoiceCount,
    'amount': amount,
    'paid_amount': paidAmount,
    'status': status,
  };

  factory FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasSupplierAgreementInstallmentRecord(
      id: (row['id'] ?? '').toString(),
      agreementId: (row['agreement_id'] ?? '').toString(),
      sequenceNumber: ((row['sequence_number'] as num?) ?? 0).toInt(),
      dueDate: _tryParseDateTime(row['due_date'] as String?) ?? DateTime.now(),
      commitmentType: (row['commitment_type'] ?? 'MONTO').toString(),
      scheduledInvoiceCount: ((row['scheduled_invoice_count'] as num?) ?? 0)
          .toInt(),
      amount: ((row['amount'] as num?) ?? 0).toDouble(),
      paidAmount: ((row['paid_amount'] as num?) ?? 0).toDouble(),
      status: (row['status'] ?? 'PENDIENTE').toString(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasSupplierAgreementInvoiceRecord {
  final String id;
  final String agreementId;
  final String installmentId;
  final String invoiceId;
  final int sequenceNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasSupplierAgreementInvoiceRecord({
    required this.id,
    required this.agreementId,
    required this.installmentId,
    required this.invoiceId,
    required this.sequenceNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'agreement_id': agreementId,
    'installment_id': installmentId,
    'invoice_id': invoiceId,
    'sequence_number': sequenceNumber,
  };

  factory FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasSupplierAgreementInvoiceRecord(
      id: (row['id'] ?? '').toString(),
      agreementId: (row['agreement_id'] ?? '').toString(),
      installmentId: (row['installment_id'] ?? '').toString(),
      invoiceId: (row['invoice_id'] ?? '').toString(),
      sequenceNumber: ((row['sequence_number'] as num?) ?? 0).toInt(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasProviderAccountsStore {
  static Future<List<FinanzasSupplierInvoiceRecord>> loadInvoices() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinSupplierInvoicesTable)
          .select()
          .order('invoice_date', ascending: false)
          .order('invoice_folio', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasSupplierInvoiceRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasSupplierInvoiceRecord>[];
    }
  }

  static Future<List<FinanzasSupplierInvoiceTicketRecord>>
  loadInvoiceTickets() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinSupplierInvoiceTicketsTable)
          .select()
          .order('created_at');
      return (rows as List)
          .map(
            (row) => FinanzasSupplierInvoiceTicketRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasSupplierInvoiceTicketRecord>[];
    }
  }

  static Future<void> createInvoice({
    required FinanzasSupplierInvoiceRecord invoice,
    required List<ComprasTicketRecord> tickets,
  }) async {
    await Supabase.instance.client.from(_kFinSupplierInvoicesTable).upsert(
      <Map<String, dynamic>>[invoice.toUpsertJson()],
      onConflict: 'id',
    );
    if (tickets.isNotEmpty) {
      await Supabase.instance.client
          .from(_kFinSupplierInvoiceTicketsTable)
          .upsert(
            tickets
                .map(
                  (ticket) => FinanzasSupplierInvoiceTicketRecord(
                    id: 'fin-inv-ticket-${invoice.id}-${ticket.id}-${DateTime.now().microsecondsSinceEpoch}',
                    invoiceId: invoice.id,
                    ticketId: ticket.id,
                    appliedAmount: ticket.amount,
                    createdAt: null,
                    updatedAt: null,
                  ).toUpsertJson(),
                )
                .toList(growable: false),
            onConflict: 'ticket_id',
          );
      await ComprasTicketsStore.saveTickets(
        tickets
            .map((ticket) => ticket.copyWith(facturaStatus: 'FACTURADO'))
            .toList(growable: false),
      );
    }
  }

  static Future<void> saveInvoice(FinanzasSupplierInvoiceRecord invoice) async {
    await Supabase.instance.client.from(_kFinSupplierInvoicesTable).upsert(
      <Map<String, dynamic>>[invoice.toUpsertJson()],
      onConflict: 'id',
    );
  }

  static Future<List<FinanzasSupplierAgreementRecord>> loadAgreements() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinSupplierAgreementsTable)
          .select()
          .order('start_date', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasSupplierAgreementRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasSupplierAgreementRecord>[];
    }
  }

  static Future<List<FinanzasSupplierAgreementInstallmentRecord>>
  loadAgreementInstallments() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinSupplierAgreementInstallmentsTable)
          .select()
          .order('due_date')
          .order('sequence_number');
      return (rows as List)
          .map(
            (row) => FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasSupplierAgreementInstallmentRecord>[];
    }
  }

  static Future<List<FinanzasSupplierAgreementInvoiceRecord>>
  loadAgreementInvoices() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinSupplierAgreementInvoicesTable)
          .select()
          .order('sequence_number')
          .order('created_at');
      return (rows as List)
          .map(
            (row) => FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasSupplierAgreementInvoiceRecord>[];
    }
  }

  static Future<void> createAgreement({
    required FinanzasSupplierAgreementRecord agreement,
    required List<FinanzasSupplierAgreementInstallmentRecord> installments,
    List<FinanzasSupplierAgreementInvoiceRecord> invoiceLinks =
        const <FinanzasSupplierAgreementInvoiceRecord>[],
  }) async {
    await Supabase.instance.client.from(_kFinSupplierAgreementsTable).upsert(
      <Map<String, dynamic>>[agreement.toUpsertJson()],
      onConflict: 'id',
    );
    if (installments.isEmpty) return;
    await Supabase.instance.client
        .from(_kFinSupplierAgreementInstallmentsTable)
        .upsert(
          installments.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'id',
        );
    if (invoiceLinks.isEmpty) return;
    await Supabase.instance.client
        .from(_kFinSupplierAgreementInvoicesTable)
        .upsert(
          invoiceLinks.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'id',
        );
  }

  static Future<void> saveAgreement(
    FinanzasSupplierAgreementRecord agreement,
  ) async {
    await Supabase.instance.client.from(_kFinSupplierAgreementsTable).upsert(
      <Map<String, dynamic>>[agreement.toUpsertJson()],
      onConflict: 'id',
    );
  }

  static Future<void> saveAgreementInstallment(
    FinanzasSupplierAgreementInstallmentRecord installment,
  ) async {
    await Supabase.instance.client
        .from(_kFinSupplierAgreementInstallmentsTable)
        .upsert(<Map<String, dynamic>>[installment.toUpsertJson()]);
  }

  static Future<void> replaceAgreementStructure({
    required FinanzasSupplierAgreementRecord agreement,
    required List<FinanzasSupplierAgreementInstallmentRecord> installments,
    List<FinanzasSupplierAgreementInvoiceRecord> invoiceLinks =
        const <FinanzasSupplierAgreementInvoiceRecord>[],
  }) async {
    await saveAgreement(agreement);
    await Supabase.instance.client
        .from(_kFinSupplierAgreementInvoicesTable)
        .delete()
        .eq('agreement_id', agreement.id);
    await Supabase.instance.client
        .from(_kFinSupplierAgreementInstallmentsTable)
        .delete()
        .eq('agreement_id', agreement.id);
    if (installments.isNotEmpty) {
      await Supabase.instance.client
          .from(_kFinSupplierAgreementInstallmentsTable)
          .upsert(
            installments
                .map((row) => row.toUpsertJson())
                .toList(growable: false),
            onConflict: 'id',
          );
    }
    if (invoiceLinks.isNotEmpty) {
      await Supabase.instance.client
          .from(_kFinSupplierAgreementInvoicesTable)
          .upsert(
            invoiceLinks
                .map((row) => row.toUpsertJson())
                .toList(growable: false),
            onConflict: 'id',
          );
    }
  }

  static Future<void> cancelAgreement({
    required FinanzasSupplierAgreementRecord agreement,
    required List<FinanzasSupplierAgreementInstallmentRecord> installments,
  }) async {
    await saveAgreement(
      FinanzasSupplierAgreementRecord(
        id: agreement.id,
        providerId: agreement.providerId,
        providerNameSnapshot: agreement.providerNameSnapshot,
        targetCompany: agreement.targetCompany,
        targetBranch: agreement.targetBranch,
        startDate: agreement.startDate,
        agreementType: agreement.agreementType,
        frequency: agreement.frequency,
        installmentAmount: agreement.installmentAmount,
        installmentCount: agreement.installmentCount,
        invoicesPerPeriod: agreement.invoicesPerPeriod,
        scheduledInvoiceCount: agreement.scheduledInvoiceCount,
        totalAmount: agreement.totalAmount,
        remainingAmount: agreement.remainingAmount,
        nextDueDate: agreement.nextDueDate,
        status: 'CANCELADO',
        notes: agreement.notes,
        createdAt: agreement.createdAt,
        updatedAt: agreement.updatedAt,
      ),
    );
    final pendingInstallments = installments
        .where((row) => row.status != 'PAGADO')
        .map(
          (row) => FinanzasSupplierAgreementInstallmentRecord(
            id: row.id,
            agreementId: row.agreementId,
            sequenceNumber: row.sequenceNumber,
            dueDate: row.dueDate,
            commitmentType: row.commitmentType,
            scheduledInvoiceCount: row.scheduledInvoiceCount,
            amount: row.amount,
            paidAmount: row.paidAmount,
            status: 'CANCELADO',
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList(growable: false);
    if (pendingInstallments.isEmpty) return;
    await Supabase.instance.client
        .from(_kFinSupplierAgreementInstallmentsTable)
        .upsert(
          pendingInstallments
              .map((row) => row.toUpsertJson())
              .toList(growable: false),
          onConflict: 'id',
        );
  }

  static Future<void> syncAgreementStateForProvider({
    required String providerId,
  }) async {
    final agreements = await loadAgreements();
    final providerAgreements = agreements
        .where(
          (row) => row.providerId == providerId && row.status != 'CANCELADO',
        )
        .toList(growable: false);
    if (providerAgreements.isEmpty) return;

    final invoices = await loadInvoices();
    final invoicesById = <String, FinanzasSupplierInvoiceRecord>{
      for (final row in invoices) row.id: row,
    };
    final installments = await loadAgreementInstallments();
    final links = await loadAgreementInvoices();
    final linksByInstallmentId =
        <String, List<FinanzasSupplierAgreementInvoiceRecord>>{};
    for (final link in links) {
      linksByInstallmentId
          .putIfAbsent(
            link.installmentId,
            () => <FinanzasSupplierAgreementInvoiceRecord>[],
          )
          .add(link);
    }
    final comprasProviderId = providerId.startsWith('compras_')
        ? providerId.substring('compras_'.length)
        : providerId;
    final cashMovements =
        (await ComprasTicketsStore.loadProviderMovements())
            .where(
              (row) =>
                  row.providerId == comprasProviderId &&
                  (row.type == 'ABONO' || row.type == 'PAGO'),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.id.compareTo(b.id);
          });
    final bankMovementRows = await Supabase.instance.client
        .from(_kFinBankMovementsTable)
        .select('id, movement_date, counterparty_company_id, debit_amount')
        .eq('counterparty_company_id', providerId)
        .order('movement_date')
        .order('created_at');
    final bankPayments =
        (bankMovementRows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where((row) => ((row['debit_amount'] as num?) ?? 0) > 0)
            .map(
              (row) => (
                id: (row['id'] ?? '').toString(),
                date:
                    _tryParseDateTime(row['movement_date'] as String?) ??
                    DateTime.now(),
                amount: ((row['debit_amount'] as num?) ?? 0).toDouble(),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.id.compareTo(b.id);
          });

    for (final agreement in providerAgreements) {
      final agreementInstallments =
          installments
              .where((row) => row.agreementId == agreement.id)
              .toList(growable: false)
            ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
      if (agreementInstallments.isEmpty) continue;

      late final List<FinanzasSupplierAgreementInstallmentRecord>
      updatedInstallments;
      if (agreement.agreementType == 'POR_FACTURAS') {
        updatedInstallments = agreementInstallments
            .map((installment) {
              if (installment.status == 'CANCELADO') return installment;
              final linkedRows =
                  linksByInstallmentId[installment.id] ??
                  const <FinanzasSupplierAgreementInvoiceRecord>[];
              final paidAmount = linkedRows
                  .fold<double>(0, (sum, link) {
                    final invoice = invoicesById[link.invoiceId];
                    if (invoice == null) return sum;
                    final invoicePaid =
                        (invoice.totalAmount - invoice.balanceAmount)
                            .clamp(0, invoice.totalAmount)
                            .toDouble();
                    return sum + invoicePaid;
                  })
                  .clamp(0, installment.amount)
                  .toDouble();
              final status = deriveAgreementInstallmentStatus(
                dueDate: installment.dueDate,
                amount: installment.amount,
                paidAmount: paidAmount,
              );
              return FinanzasSupplierAgreementInstallmentRecord(
                id: installment.id,
                agreementId: installment.agreementId,
                sequenceNumber: installment.sequenceNumber,
                dueDate: installment.dueDate,
                commitmentType: installment.commitmentType,
                scheduledInvoiceCount: installment.scheduledInvoiceCount,
                amount: installment.amount,
                paidAmount: paidAmount,
                status: status,
                createdAt: installment.createdAt,
                updatedAt: installment.updatedAt,
              );
            })
            .toList(growable: false);
      } else {
        var executedAmount = 0.0;
        for (final movement in cashMovements) {
          if (!movement.date.isBefore(agreement.startDate)) {
            executedAmount += movement.amount;
          }
        }
        for (final movement in bankPayments) {
          if (!movement.date.isBefore(agreement.startDate)) {
            executedAmount += movement.amount;
          }
        }
        var remainingExecuted = executedAmount.clamp(0, double.infinity);
        updatedInstallments = agreementInstallments
            .map((installment) {
              if (installment.status == 'CANCELADO') return installment;
              final paidAmount = remainingExecuted > installment.amount
                  ? installment.amount
                  : remainingExecuted;
              remainingExecuted = (remainingExecuted - paidAmount)
                  .clamp(0, double.infinity)
                  .toDouble();
              final status = deriveAgreementInstallmentStatus(
                dueDate: installment.dueDate,
                amount: installment.amount,
                paidAmount: paidAmount.toDouble(),
              );
              return FinanzasSupplierAgreementInstallmentRecord(
                id: installment.id,
                agreementId: installment.agreementId,
                sequenceNumber: installment.sequenceNumber,
                dueDate: installment.dueDate,
                commitmentType: installment.commitmentType,
                scheduledInvoiceCount: installment.scheduledInvoiceCount,
                amount: installment.amount,
                paidAmount: paidAmount.toDouble(),
                status: status,
                createdAt: installment.createdAt,
                updatedAt: installment.updatedAt,
              );
            })
            .toList(growable: false);
      }

      await Supabase.instance.client
          .from(_kFinSupplierAgreementInstallmentsTable)
          .upsert(
            updatedInstallments
                .map((row) => row.toUpsertJson())
                .toList(growable: false),
            onConflict: 'id',
          );

      final agreementSummary = recomputeAgreementSummary(
        currentStatus: agreement.status,
        installments: updatedInstallments
            .map(
              (row) => AgreementInstallmentSnapshot(
                sequenceNumber: row.sequenceNumber,
                dueDate: row.dueDate,
                amount: row.amount,
                paidAmount: row.paidAmount,
                status: row.status,
              ),
            )
            .toList(growable: false),
      );
      final recomputedAgreement = FinanzasSupplierAgreementRecord(
        id: agreement.id,
        providerId: agreement.providerId,
        providerNameSnapshot: agreement.providerNameSnapshot,
        targetCompany: agreement.targetCompany,
        targetBranch: agreement.targetBranch,
        startDate: agreement.startDate,
        agreementType: agreement.agreementType,
        frequency: agreement.frequency,
        installmentAmount: agreement.installmentAmount,
        installmentCount: agreement.installmentCount,
        invoicesPerPeriod: agreement.invoicesPerPeriod,
        scheduledInvoiceCount: agreement.scheduledInvoiceCount,
        totalAmount: agreement.totalAmount,
        remainingAmount: agreementSummary.remainingAmount,
        nextDueDate: agreementSummary.nextDueDate,
        status: agreementSummary.status,
        notes: agreement.notes,
        createdAt: agreement.createdAt,
        updatedAt: agreement.updatedAt,
      );
      await saveAgreement(recomputedAgreement);
    }
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
