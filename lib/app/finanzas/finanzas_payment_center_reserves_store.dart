import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'finanzas_bank_accounts_store.dart';

const String _kFinPaymentCenterReservesTable =
    'finanzas_payment_center_reserves';
const String kFinPaymentCenterReservesUnavailableMessage =
    'Las reservas protegidas aun no estan habilitadas en esta base. Falta aplicar la migracion de Centro de pagos.';
bool _finPaymentCenterReservesRemoteUnavailable = false;

const List<String> kFinPaymentCenterReserveTypes = <String>[
  'NOMINA',
  'IMPUESTOS',
  'COLCHON_CUENTA',
  'EXTRAORDINARIO',
];

const List<String> kFinPaymentCenterReserveClassifications = <String>[
  'DURA',
  'PROVISIONAL',
];

const List<String> kFinPaymentCenterReserveScopeTypes = <String>[
  'GLOBAL',
  'CUENTA',
];

String finPaymentCenterReserveTypeLabel(String value) {
  switch (value) {
    case 'NOMINA':
      return 'Nomina';
    case 'IMPUESTOS':
      return 'Impuestos';
    case 'COLCHON_CUENTA':
      return 'Colchon de cuenta';
    default:
      return 'Extraordinario';
  }
}

String finPaymentCenterReserveClassificationLabel(String value) {
  switch (value) {
    case 'PROVISIONAL':
      return 'Provisional';
    default:
      return 'Dura';
  }
}

String finPaymentCenterReserveScopeLabel(String value) {
  switch (value) {
    case 'CUENTA':
      return 'Cuenta';
    default:
      return 'Global';
  }
}

class FinanzasPaymentCenterReserveRecord {
  final String id;
  final String name;
  final String reserveType;
  final String classification;
  final String scopeType;
  final String? targetCompany;
  final String? targetBranch;
  final double amount;
  final DateTime effectiveDate;
  final DateTime? endDate;
  final String note;
  final bool blocksCash;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasPaymentCenterReserveRecord({
    required this.id,
    required this.name,
    required this.reserveType,
    required this.classification,
    required this.scopeType,
    required this.targetCompany,
    required this.targetBranch,
    required this.amount,
    required this.effectiveDate,
    required this.endDate,
    required this.note,
    required this.blocksCash,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isGlobal => scopeType == 'GLOBAL';
  bool get isAccountScoped => scopeType == 'CUENTA';

  String? get accountKey {
    if (!isAccountScoped || targetCompany == null || targetBranch == null) {
      return null;
    }
    return buildFinBankAccountKey(
      company: targetCompany!,
      branch: targetBranch!,
    );
  }

  FinanzasPaymentCenterReserveRecord copyWith({
    String? id,
    String? name,
    String? reserveType,
    String? classification,
    String? scopeType,
    String? targetCompany,
    bool clearTargetCompany = false,
    String? targetBranch,
    bool clearTargetBranch = false,
    double? amount,
    DateTime? effectiveDate,
    DateTime? endDate,
    bool clearEndDate = false,
    String? note,
    bool? blocksCash,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanzasPaymentCenterReserveRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      reserveType: reserveType ?? this.reserveType,
      classification: classification ?? this.classification,
      scopeType: scopeType ?? this.scopeType,
      targetCompany: clearTargetCompany
          ? null
          : targetCompany ?? this.targetCompany,
      targetBranch: clearTargetBranch
          ? null
          : targetBranch ?? this.targetBranch,
      amount: amount ?? this.amount,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      note: note ?? this.note,
      blocksCash: blocksCash ?? this.blocksCash,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'reserve_name': name.trim(),
    'reserve_type': reserveType,
    'classification': classification,
    'scope_type': scopeType,
    'target_company': isGlobal ? null : targetCompany,
    'target_branch': isGlobal ? null : targetBranch,
    'amount': amount,
    'effective_date': effectiveDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'note': note.trim(),
    'blocks_cash': blocksCash,
    'is_active': isActive,
  };

  factory FinanzasPaymentCenterReserveRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return FinanzasPaymentCenterReserveRecord(
      id: (row['id'] ?? '').toString(),
      name: (row['reserve_name'] ?? '').toString(),
      reserveType: (row['reserve_type'] ?? 'EXTRAORDINARIO').toString(),
      classification: (row['classification'] ?? 'DURA').toString(),
      scopeType: (row['scope_type'] ?? 'GLOBAL').toString(),
      targetCompany: row['target_company']?.toString(),
      targetBranch: row['target_branch']?.toString(),
      amount: ((row['amount'] as num?) ?? 0).toDouble(),
      effectiveDate:
          _tryParseDateTime(row['effective_date'] as String?) ?? DateTime.now(),
      endDate: _tryParseDateTime(row['end_date'] as String?),
      note: (row['note'] ?? '').toString(),
      blocksCash: row['blocks_cash'] as bool? ?? true,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

bool isFinPaymentCenterReserveActiveOnDate(
  FinanzasPaymentCenterReserveRecord row, {
  DateTime? date,
}) {
  if (!row.isActive) return false;
  final effectiveDate = DateUtils.dateOnly(date ?? DateTime.now());
  final reserveStart = DateUtils.dateOnly(row.effectiveDate);
  final reserveEnd = row.endDate == null
      ? null
      : DateUtils.dateOnly(row.endDate!);
  if (reserveStart.isAfter(effectiveDate)) return false;
  if (reserveEnd != null && reserveEnd.isBefore(effectiveDate)) return false;
  return true;
}

bool isMissingPaymentCenterReservesFeatureError(Object error) {
  if (error is PostgrestException) {
    final message = [
      error.message,
      error.details?.toString(),
      error.hint?.toString(),
    ].join(' ').toLowerCase();
    return error.code?.toString() == 'PGRST205' ||
        message.contains(_kFinPaymentCenterReservesTable) ||
        message.contains('schema cache');
  }
  final message = error.toString().toLowerCase();
  return message.contains(_kFinPaymentCenterReservesTable) ||
      message.contains('reservas protegidas') ||
      message.contains('centro de pagos');
}

class FinanzasPaymentCenterReservesStore {
  static Future<List<FinanzasPaymentCenterReserveRecord>> loadReserves() async {
    if (_finPaymentCenterReservesRemoteUnavailable) {
      return const <FinanzasPaymentCenterReserveRecord>[];
    }
    try {
      final rows = await Supabase.instance.client
          .from(_kFinPaymentCenterReservesTable)
          .select()
          .order('is_active', ascending: false)
          .order('effective_date')
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasPaymentCenterReserveRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (isMissingPaymentCenterReservesFeatureError(error)) {
        _finPaymentCenterReservesRemoteUnavailable = true;
        debugPrint(
          'FinanzasPaymentCenterReservesStore: $kFinPaymentCenterReservesUnavailableMessage',
        );
      }
      return const <FinanzasPaymentCenterReserveRecord>[];
    } catch (_) {
      return const <FinanzasPaymentCenterReserveRecord>[];
    }
  }

  static Future<void> saveReserve(
    FinanzasPaymentCenterReserveRecord row,
  ) async {
    if (_finPaymentCenterReservesRemoteUnavailable) {
      throw StateError(
        '$kFinPaymentCenterReservesUnavailableMessage ($_kFinPaymentCenterReservesTable)',
      );
    }
    try {
      await Supabase.instance.client
          .from(_kFinPaymentCenterReservesTable)
          .upsert(<Map<String, dynamic>>[row.toUpsertJson()], onConflict: 'id');
    } on PostgrestException catch (error) {
      if (isMissingPaymentCenterReservesFeatureError(error)) {
        _finPaymentCenterReservesRemoteUnavailable = true;
        throw StateError(
          '$kFinPaymentCenterReservesUnavailableMessage ($_kFinPaymentCenterReservesTable)',
        );
      }
      rethrow;
    }
  }

  static Future<void> deleteReserve(String id) async {
    if (_finPaymentCenterReservesRemoteUnavailable) {
      throw StateError(
        '$kFinPaymentCenterReservesUnavailableMessage ($_kFinPaymentCenterReservesTable)',
      );
    }
    try {
      await Supabase.instance.client
          .from(_kFinPaymentCenterReservesTable)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (error) {
      if (isMissingPaymentCenterReservesFeatureError(error)) {
        _finPaymentCenterReservesRemoteUnavailable = true;
        throw StateError(
          '$kFinPaymentCenterReservesUnavailableMessage ($_kFinPaymentCenterReservesTable)',
        );
      }
      rethrow;
    }
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
