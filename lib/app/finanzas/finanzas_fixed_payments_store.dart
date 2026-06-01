import 'package:supabase_flutter/supabase_flutter.dart';

import 'finanzas_financial_rules.dart';

const String _kFinFixedPaymentsTable = 'finanzas_fixed_payments';

const List<String> kFinFixedPaymentStatuses = <String>[
  'PENDIENTE',
  'PAGADO',
  'VENCIDO',
];

const List<String> kFinFixedPaymentExecutionMethods = <String>[
  'BANCO',
  'EFECTIVO',
];

const List<String> kFinFixedPaymentBranches = <String>['CELAYA', 'MAZATLAN'];

String finFixedPaymentBranchLabel(String value) {
  switch (value) {
    case 'MAZATLAN':
      return 'Mazatlan';
    default:
      return 'Celaya';
  }
}

String finFixedPaymentStatusLabel(String value) {
  switch (value) {
    case 'PAGADO':
      return 'Pagado';
    case 'VENCIDO':
      return 'Vencido';
    default:
      return 'Pendiente';
  }
}

String finFixedPaymentExecutionMethodLabel(String value) {
  switch (value) {
    case 'EFECTIVO':
      return 'Efectivo';
    default:
      return 'Banco';
  }
}

class FinanzasFixedPaymentRecord {
  final String id;
  final DateTime receivedDate;
  final String companyId;
  final String companyNameSnapshot;
  final String branch;
  final double amount;
  final DateTime paymentDate;
  final String status;
  final String notes;
  final String? executionMethod;
  final String? linkedBankMovementId;
  final DateTime? settledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasFixedPaymentRecord({
    required this.id,
    required this.receivedDate,
    required this.companyId,
    required this.companyNameSnapshot,
    required this.branch,
    required this.amount,
    required this.paymentDate,
    required this.status,
    required this.notes,
    required this.executionMethod,
    required this.linkedBankMovementId,
    required this.settledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  FinanzasFixedPaymentRecord copyWith({
    String? id,
    DateTime? receivedDate,
    String? companyId,
    String? companyNameSnapshot,
    String? branch,
    double? amount,
    DateTime? paymentDate,
    String? status,
    String? notes,
    String? executionMethod,
    String? linkedBankMovementId,
    DateTime? settledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanzasFixedPaymentRecord(
      id: id ?? this.id,
      receivedDate: receivedDate ?? this.receivedDate,
      companyId: companyId ?? this.companyId,
      companyNameSnapshot: companyNameSnapshot ?? this.companyNameSnapshot,
      branch: branch ?? this.branch,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      executionMethod: executionMethod ?? this.executionMethod,
      linkedBankMovementId: linkedBankMovementId ?? this.linkedBankMovementId,
      settledAt: settledAt ?? this.settledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'received_date': receivedDate.toIso8601String(),
    'company_id': companyId,
    'company_name_snapshot': companyNameSnapshot,
    'branch': branch,
    'amount': amount,
    'payment_date': paymentDate.toIso8601String(),
    'status': status,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
    'execution_method': executionMethod,
    'linked_bank_movement_id': linkedBankMovementId,
    'settled_at': settledAt?.toIso8601String(),
  };

  factory FinanzasFixedPaymentRecord.fromRemoteRow(Map<String, dynamic> row) {
    return FinanzasFixedPaymentRecord(
      id: (row['id'] ?? '').toString(),
      receivedDate:
          _tryParseDateTime(row['received_date'] as String?) ?? DateTime.now(),
      companyId: (row['company_id'] ?? '').toString(),
      companyNameSnapshot: (row['company_name_snapshot'] ?? '').toString(),
      branch: (row['branch'] ?? 'CELAYA').toString(),
      amount: ((row['amount'] as num?) ?? 0).toDouble(),
      paymentDate:
          _tryParseDateTime(row['payment_date'] as String?) ?? DateTime.now(),
      status: (row['status'] ?? 'PENDIENTE').toString(),
      notes: (row['notes'] ?? '').toString(),
      executionMethod: row['execution_method']?.toString(),
      linkedBankMovementId: row['linked_bank_movement_id']?.toString(),
      settledAt: _tryParseDateTime(row['settled_at'] as String?),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasFixedPaymentsStore {
  static Future<List<FinanzasFixedPaymentRecord>> loadPayments() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinFixedPaymentsTable)
          .select()
          .order('payment_date')
          .order('received_date', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasFixedPaymentRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .map(
            (row) => row.copyWith(
              status: deriveFixedPaymentOperationalStatus(
                persistedStatus: row.status,
                paymentDate: row.paymentDate,
              ),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasFixedPaymentRecord>[];
    }
  }

  static Future<void> savePayment(FinanzasFixedPaymentRecord row) async {
    await Supabase.instance.client.from(_kFinFixedPaymentsTable).upsert(
      <Map<String, dynamic>>[row.toUpsertJson()],
      onConflict: 'id',
    );
  }

  static Future<void> deletePayment(String id) async {
    await Supabase.instance.client
        .from(_kFinFixedPaymentsTable)
        .delete()
        .eq('id', id);
  }

  static Future<List<FinanzasFixedPaymentRecord>> loadOpenPayments() async {
    final rows = await loadPayments();
    return rows.where((row) => row.status != 'PAGADO').toList(growable: false);
  }

  static Future<void> markPaidByCash({
    required FinanzasFixedPaymentRecord row,
    DateTime? settledAt,
  }) async {
    await savePayment(
      row.copyWith(
        status: 'PAGADO',
        executionMethod: 'EFECTIVO',
        settledAt: settledAt ?? DateTime.now(),
      ),
    );
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
