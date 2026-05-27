import 'package:supabase_flutter/supabase_flutter.dart';

import '../compras/compras_tickets_store.dart';

const String _kFinSupplierInvoicesTable = 'finanzas_supplier_invoices';
const String _kFinSupplierInvoiceTicketsTable =
    'finanzas_supplier_invoice_tickets';
const String _kFinSupplierAgreementsTable = 'finanzas_supplier_agreements';
const String _kFinSupplierAgreementInstallmentsTable =
    'finanzas_supplier_agreement_installments';

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
  final String folio;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double totalAmount;
  final double balanceAmount;
  final String status;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasSupplierInvoiceRecord({
    required this.id,
    required this.providerId,
    required this.providerNameSnapshot,
    required this.folio,
    required this.invoiceDate,
    required this.dueDate,
    required this.totalAmount,
    required this.balanceAmount,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  FinanzasSupplierInvoiceRecord copyWith({
    String? id,
    String? providerId,
    String? providerNameSnapshot,
    String? folio,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double? totalAmount,
    double? balanceAmount,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanzasSupplierInvoiceRecord(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerNameSnapshot: providerNameSnapshot ?? this.providerNameSnapshot,
      folio: folio ?? this.folio,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      totalAmount: totalAmount ?? this.totalAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'provider_id': providerId,
    'provider_name_snapshot': providerNameSnapshot,
    'invoice_folio': folio,
    'invoice_date': invoiceDate.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'total_amount': totalAmount,
    'balance_amount': balanceAmount,
    'status': status,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
  };

  factory FinanzasSupplierInvoiceRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasSupplierInvoiceRecord(
      id: (row['id'] ?? '').toString(),
      providerId: (row['provider_id'] ?? '').toString(),
      providerNameSnapshot: (row['provider_name_snapshot'] ?? '').toString(),
      folio: (row['invoice_folio'] ?? '').toString(),
      invoiceDate:
          _tryParseDateTime(row['invoice_date'] as String?) ?? DateTime.now(),
      dueDate: _tryParseDateTime(row['due_date'] as String?),
      totalAmount: ((row['total_amount'] as num?) ?? 0).toDouble(),
      balanceAmount: ((row['balance_amount'] as num?) ?? 0).toDouble(),
      status: (row['status'] as String?) ?? 'PENDIENTE',
      notes: (row['notes'] ?? '').toString(),
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
  final DateTime startDate;
  final String frequency;
  final double installmentAmount;
  final int installmentCount;
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
    required this.startDate,
    required this.frequency,
    required this.installmentAmount,
    required this.installmentCount,
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
    'start_date': startDate.toIso8601String(),
    'frequency': frequency,
    'installment_amount': installmentAmount,
    'installment_count': installmentCount,
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
      startDate:
          _tryParseDateTime(row['start_date'] as String?) ?? DateTime.now(),
      frequency: (row['frequency'] ?? 'SEMANAL').toString(),
      installmentAmount: ((row['installment_amount'] as num?) ?? 0).toDouble(),
      installmentCount: ((row['installment_count'] as num?) ?? 0).toInt(),
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
      amount: ((row['amount'] as num?) ?? 0).toDouble(),
      paidAmount: ((row['paid_amount'] as num?) ?? 0).toDouble(),
      status: (row['status'] ?? 'PENDIENTE').toString(),
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

  static Future<void> createAgreement({
    required FinanzasSupplierAgreementRecord agreement,
    required List<FinanzasSupplierAgreementInstallmentRecord> installments,
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
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
