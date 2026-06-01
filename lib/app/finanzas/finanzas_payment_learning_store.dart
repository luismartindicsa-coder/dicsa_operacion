import 'package:supabase_flutter/supabase_flutter.dart';

const String _kFinPaymentLearningTable = 'finanzas_payment_center_learning';

const List<String> kFinPaymentLearningStatuses = <String>[
  'PENDIENTE',
  'REGISTRADO',
];

class FinanzasPaymentLearningRecord {
  final String id;
  final DateTime capturedAt;
  final String providerId;
  final String providerName;
  final String bucket;
  final String itemType;
  final String sourceLabel;
  final DateTime? dueDate;
  final String targetCompany;
  final String targetBranch;
  final String suggestedAction;
  final double suggestedAmount;
  final String recommendation;
  final String status;
  final String? executedAction;
  final double? executedAmount;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasPaymentLearningRecord({
    required this.id,
    required this.capturedAt,
    required this.providerId,
    required this.providerName,
    required this.bucket,
    required this.itemType,
    required this.sourceLabel,
    required this.dueDate,
    required this.targetCompany,
    required this.targetBranch,
    required this.suggestedAction,
    required this.suggestedAmount,
    required this.recommendation,
    required this.status,
    required this.executedAction,
    required this.executedAmount,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  FinanzasPaymentLearningRecord copyWith({
    String? id,
    DateTime? capturedAt,
    String? providerId,
    String? providerName,
    String? bucket,
    String? itemType,
    String? sourceLabel,
    DateTime? dueDate,
    String? targetCompany,
    String? targetBranch,
    String? suggestedAction,
    double? suggestedAmount,
    String? recommendation,
    String? status,
    String? executedAction,
    double? executedAmount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanzasPaymentLearningRecord(
      id: id ?? this.id,
      capturedAt: capturedAt ?? this.capturedAt,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      bucket: bucket ?? this.bucket,
      itemType: itemType ?? this.itemType,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      dueDate: dueDate ?? this.dueDate,
      targetCompany: targetCompany ?? this.targetCompany,
      targetBranch: targetBranch ?? this.targetBranch,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      suggestedAmount: suggestedAmount ?? this.suggestedAmount,
      recommendation: recommendation ?? this.recommendation,
      status: status ?? this.status,
      executedAction: executedAction ?? this.executedAction,
      executedAmount: executedAmount ?? this.executedAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'captured_at': capturedAt.toIso8601String(),
    'provider_id': providerId,
    'provider_name': providerName,
    'bucket': bucket,
    'item_type': itemType,
    'source_label': sourceLabel,
    'due_date': dueDate?.toIso8601String(),
    'target_company': targetCompany,
    'target_branch': targetBranch,
    'suggested_action': suggestedAction,
    'suggested_amount': suggestedAmount,
    'recommendation': recommendation,
    'status': status,
    'executed_action': executedAction,
    'executed_amount': executedAmount,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
  };

  factory FinanzasPaymentLearningRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasPaymentLearningRecord(
      id: (row['id'] ?? '').toString(),
      capturedAt:
          _tryParseDateTime(row['captured_at'] as String?) ?? DateTime.now(),
      providerId: (row['provider_id'] ?? '').toString(),
      providerName: (row['provider_name'] ?? '').toString(),
      bucket: (row['bucket'] ?? '').toString(),
      itemType: (row['item_type'] ?? '').toString(),
      sourceLabel: (row['source_label'] ?? '').toString(),
      dueDate: _tryParseDateTime(row['due_date'] as String?),
      targetCompany: (row['target_company'] ?? '').toString(),
      targetBranch: (row['target_branch'] ?? '').toString(),
      suggestedAction: (row['suggested_action'] ?? '').toString(),
      suggestedAmount: ((row['suggested_amount'] as num?) ?? 0).toDouble(),
      recommendation: (row['recommendation'] ?? '').toString(),
      status: (row['status'] ?? 'PENDIENTE').toString(),
      executedAction: row['executed_action']?.toString(),
      executedAmount: (row['executed_amount'] as num?)?.toDouble(),
      notes: (row['notes'] ?? '').toString(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasPaymentLearningStore {
  static Future<List<FinanzasPaymentLearningRecord>> loadLogs() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinPaymentLearningTable)
          .select()
          .order('captured_at', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasPaymentLearningRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasPaymentLearningRecord>[];
    }
  }

  static Future<void> saveLog(FinanzasPaymentLearningRecord row) async {
    await Supabase.instance.client.from(_kFinPaymentLearningTable).upsert(
      <Map<String, dynamic>>[row.toUpsertJson()],
      onConflict: 'id',
    );
  }

  static Future<void> saveLogs(List<FinanzasPaymentLearningRecord> rows) async {
    if (rows.isEmpty) return;
    await Supabase.instance.client
        .from(_kFinPaymentLearningTable)
        .upsert(
          rows.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'id',
        );
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
