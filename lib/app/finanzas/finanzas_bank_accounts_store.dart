import 'package:supabase_flutter/supabase_flutter.dart';

import '../compras/compras_tickets_store.dart';
import 'finanzas_provider_accounts_store.dart';

const String _kFinBankMovementsTable = 'finanzas_bank_movements';
const String _kMayoreoAccountsTable = 'mayoreo_accounts';

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
  final double approvedAmount;
  final double paidAmount;
  final String status;
  final DateTime? settlementDate;

  const FinanzasClientPaymentAccountRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.documentNumber,
    required this.approvedAmount,
    required this.paidAmount,
    required this.status,
    required this.settlementDate,
  });

  double get pendingBalance => approvedAmount - paidAmount;

  bool get isOpen =>
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
    await Supabase.instance.client.from(_kFinBankMovementsTable).upsert(
      <Map<String, dynamic>>[row.toUpsertJson()],
      onConflict: 'id',
    );
  }

  static Future<List<FinanzasClientPaymentAccountRecord>>
  loadOpenClientAccounts() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kMayoreoAccountsTable)
          .select(
            'id, client_id, client_name_snapshot, document_number, approved_amount, paid_amount, status, settlement_date',
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

  static Future<void> createMovementAndApply({
    required FinanzasBankMovementRecord movement,
    FinanzasSupplierInvoiceRecord? linkedSupplierInvoice,
    FinanzasClientPaymentAccountRecord? linkedClientAccount,
  }) async {
    await saveMovement(movement);
    if (linkedClientAccount != null) {
      await Supabase.instance.client
          .from(_kMayoreoAccountsTable)
          .update(<String, dynamic>{
            'paid_amount': linkedClientAccount.approvedAmount,
            'status': 'pagada',
            'settlement_date': movement.date.toIso8601String(),
          })
          .eq('id', linkedClientAccount.id);
      return;
    }
    if (linkedSupplierInvoice == null) return;

    final paidInvoice = linkedSupplierInvoice.copyWith(
      balanceAmount: 0,
      status: 'PAGADA',
    );
    await FinanzasProviderAccountsStore.saveInvoice(paidInvoice);

    final invoiceTickets =
        await FinanzasProviderAccountsStore.loadInvoiceTickets();
    final linkedTicketIds = invoiceTickets
        .where((row) => row.invoiceId == linkedSupplierInvoice.id)
        .map((row) => row.ticketId)
        .toSet();
    if (linkedTicketIds.isEmpty) return;
    final allTickets = await ComprasTicketsStore.loadTickets();
    final updatedTickets = allTickets
        .where((ticket) => linkedTicketIds.contains(ticket.id))
        .map(
          (ticket) =>
              ticket.copyWith(pagoStatus: 'PAGADO', coverageStatus: 'CUBIERTO'),
        )
        .toList(growable: false);
    if (updatedTickets.isEmpty) return;
    await ComprasTicketsStore.saveTickets(updatedTickets);
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
