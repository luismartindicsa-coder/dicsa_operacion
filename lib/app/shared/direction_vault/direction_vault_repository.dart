import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cash_taxonomy/cash_taxonomy_repository.dart';

const String _kDirectionVaultVouchersTable = 'direction_vault_vouchers';
const String _kDirectionVaultVoucherLinesTable =
    'direction_vault_voucher_lines';
const String _kLegacyDirectionVaultArea = 'direccion_boveda_vouchers';

class DirectionVaultVoucherLineRecord {
  final String concept;
  final String unit;
  final String quantity;
  final String price;
  final String company;
  final String driver;
  final String destination;
  final String subconcept;
  final String mode;
  final String amount;
  final String comment;

  const DirectionVaultVoucherLineRecord({
    required this.concept,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.company,
    required this.driver,
    required this.destination,
    required this.subconcept,
    required this.mode,
    required this.amount,
    required this.comment,
  });

  double get amountValue => double.tryParse(amount.trim()) ?? 0;
}

class DirectionVaultVoucherRecord {
  final String id;
  final DateTime date;
  final String folio;
  final String type;
  final String person;
  final String rubric;
  final String comment;
  final List<DirectionVaultVoucherLineRecord> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DirectionVaultVoucherRecord({
    required this.id,
    required this.date,
    required this.folio,
    required this.type,
    required this.person,
    required this.rubric,
    required this.comment,
    required this.lines,
    required this.createdAt,
    required this.updatedAt,
  });

  double get total =>
      lines.fold<double>(0, (sum, line) => sum + line.amountValue);
}

class DirectionVaultRepository {
  DirectionVaultRepository._();

  static final DirectionVaultRepository instance = DirectionVaultRepository._();

  SupabaseClient get _supa => Supabase.instance.client;

  Future<List<DirectionVaultVoucherRecord>> loadVouchers() async {
    final remoteVouchers = await _loadRemoteVouchers();
    final legacyVouchers = await _loadLegacyVouchers();
    if (legacyVouchers.isEmpty) return remoteVouchers;

    final remoteIds = remoteVouchers
        .map((row) => row.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final missingLegacy = legacyVouchers
        .where((row) => !remoteIds.contains(row.id.trim()))
        .toList(growable: false);

    if (missingLegacy.isNotEmpty) {
      for (final row in missingLegacy) {
        await upsertVoucher(row);
      }
    }

    final mergedById = <String, DirectionVaultVoucherRecord>{
      for (final row in remoteVouchers) row.id: row,
      for (final row in missingLegacy) row.id: row,
    };
    final merged = mergedById.values.toList(growable: false);
    merged.sort(_compareVoucherRecords);
    return merged;
  }

  Future<void> upsertVoucher(DirectionVaultVoucherRecord record) async {
    final normalizedId = record.id.trim().isEmpty
        ? 'dir-vault-${DateTime.now().microsecondsSinceEpoch}'
        : record.id.trim();
    await _supa.from(_kDirectionVaultVouchersTable).upsert(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': normalizedId,
          'voucher_date': _dateOnly(record.date).toIso8601String(),
          'folio': record.folio.trim(),
          'voucher_type': record.type.trim(),
          'person_label': record.person.trim(),
          'rubric': record.rubric.trim(),
          'comment': record.comment.trim(),
          'total_amount': record.total,
        },
      ],
      onConflict: 'id',
    );
    await _supa
        .from(_kDirectionVaultVoucherLinesTable)
        .delete()
        .eq('voucher_id', normalizedId);
    if (record.lines.isEmpty) return;
    await _supa
        .from(_kDirectionVaultVoucherLinesTable)
        .insert(
          record.lines
              .asMap()
              .entries
              .map((entry) {
                final index = entry.key;
                final line = entry.value;
                return <String, dynamic>{
                  'id': '$normalizedId-line-${index + 1}',
                  'voucher_id': normalizedId,
                  'line_order': index + 1,
                  'concept': line.concept.trim(),
                  'unit': line.unit.trim(),
                  'quantity': line.quantity.trim(),
                  'price': line.price.trim(),
                  'company': line.company.trim(),
                  'driver': line.driver.trim(),
                  'destination': line.destination.trim(),
                  'subconcept': line.subconcept.trim(),
                  'mode': line.mode.trim(),
                  'amount': line.amountValue,
                  'comment': line.comment.trim(),
                };
              })
              .toList(growable: false),
        );
  }

  Future<void> deleteVouchers(List<String> ids) async {
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) return;
    await _supa
        .from(_kDirectionVaultVouchersTable)
        .delete()
        .inFilter('id', normalized);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<List<DirectionVaultVoucherRecord>> _loadRemoteVouchers() async {
    final voucherRows = await _supa
        .from(_kDirectionVaultVouchersTable)
        .select()
        .order('voucher_date', ascending: false)
        .order('created_at', ascending: false);
    final vouchers = (voucherRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    if (vouchers.isEmpty) return const <DirectionVaultVoucherRecord>[];
    final ids = vouchers
        .map((row) => (row['id'] ?? '').toString())
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    final lineRows = await _supa
        .from(_kDirectionVaultVoucherLinesTable)
        .select()
        .inFilter('voucher_id', ids)
        .order('line_order', ascending: true)
        .order('created_at', ascending: true);
    final linesByVoucher = <String, List<DirectionVaultVoucherLineRecord>>{};
    for (final raw in (lineRows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final voucherId = (row['voucher_id'] ?? '').toString();
      linesByVoucher
          .putIfAbsent(voucherId, () => <DirectionVaultVoucherLineRecord>[])
          .add(_lineFromRemoteRow(row));
    }
    return vouchers
        .map(
          (row) => DirectionVaultVoucherRecord(
            id: (row['id'] ?? '').toString(),
            date:
                DateTime.tryParse((row['voucher_date'] ?? '').toString()) ??
                DateTime.now(),
            folio: (row['folio'] ?? '').toString(),
            type: (row['voucher_type'] ?? 'expense').toString(),
            person: (row['person_label'] ?? '').toString(),
            rubric: (row['rubric'] ?? '').toString(),
            comment: (row['comment'] ?? '').toString(),
            lines: List<DirectionVaultVoucherLineRecord>.unmodifiable(
              linesByVoucher[(row['id'] ?? '').toString()] ??
                  const <DirectionVaultVoucherLineRecord>[],
            ),
            createdAt: _tryParseDateTime(row['created_at']),
            updatedAt: _tryParseDateTime(row['updated_at']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<DirectionVaultVoucherRecord>> _loadLegacyVouchers() async {
    final payload = await CashTaxonomyRepository.instance.loadArea(
      _kLegacyDirectionVaultArea,
    );
    final rows = payload?['rows'];
    if (rows is! List) return const <DirectionVaultVoucherRecord>[];
    return rows
        .whereType<Map>()
        .map((row) => _voucherFromLegacyRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static DirectionVaultVoucherLineRecord _lineFromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return DirectionVaultVoucherLineRecord(
      concept: (row['concept'] ?? '').toString(),
      unit: (row['unit'] ?? '').toString(),
      quantity: (row['quantity'] ?? '').toString(),
      price: (row['price'] ?? '').toString(),
      company: (row['company'] ?? '').toString(),
      driver: (row['driver'] ?? '').toString(),
      destination: (row['destination'] ?? '').toString(),
      subconcept: (row['subconcept'] ?? '').toString(),
      mode: (row['mode'] ?? '').toString(),
      amount: (((row['amount'] as num?) ?? 0).toDouble()).toStringAsFixed(2),
      comment: (row['comment'] ?? '').toString(),
    );
  }

  static DirectionVaultVoucherRecord _voucherFromLegacyRow(
    Map<String, dynamic> row,
  ) {
    final rawId = (row['id'] ?? '').toString().trim();
    final rawLines = row['lines'];
    return DirectionVaultVoucherRecord(
      id: rawId.isEmpty
          ? 'dir-vault-${DateTime.now().microsecondsSinceEpoch}'
          : rawId,
      date:
          _tryParseLegacyVoucherDate((row['date'] ?? '').toString()) ??
          DateTime.now(),
      folio: (row['folio'] ?? '').toString(),
      type: (row['type'] ?? 'expense').toString() == 'deposit'
          ? 'deposit'
          : 'expense',
      person: (row['person'] ?? '').toString(),
      rubric: (row['rubric'] ?? '').toString(),
      comment: (row['comment'] ?? '').toString(),
      lines: List<DirectionVaultVoucherLineRecord>.unmodifiable(
        rawLines is List
            ? rawLines
                  .whereType<Map>()
                  .map(
                    (line) =>
                        _lineFromLegacyRow(Map<String, dynamic>.from(line)),
                  )
                  .toList(growable: false)
            : const <DirectionVaultVoucherLineRecord>[],
      ),
      createdAt: null,
      updatedAt: null,
    );
  }

  static DirectionVaultVoucherLineRecord _lineFromLegacyRow(
    Map<String, dynamic> row,
  ) {
    final rawAmount = row['amount'];
    final amountValue = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString().trim() ?? '') ?? 0;
    return DirectionVaultVoucherLineRecord(
      concept: (row['concept'] ?? '').toString(),
      unit: (row['unit'] ?? '').toString(),
      quantity: (row['quantity'] ?? '').toString(),
      price: (row['price'] ?? '').toString(),
      company: (row['company'] ?? '').toString(),
      driver: (row['driver'] ?? '').toString(),
      destination: (row['destination'] ?? '').toString(),
      subconcept: (row['subconcept'] ?? '').toString(),
      mode: (row['mode'] ?? '').toString(),
      amount: amountValue.toStringAsFixed(2),
      comment: (row['comment'] ?? '').toString(),
    );
  }

  static DateTime? _tryParseLegacyVoucherDate(String raw) {
    final value = raw.trim();
    final parts = value.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(value);
  }

  static int _compareVoucherRecords(
    DirectionVaultVoucherRecord a,
    DirectionVaultVoucherRecord b,
  ) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    final createdCompare = (b.createdAt ?? b.date).compareTo(
      a.createdAt ?? a.date,
    );
    if (createdCompare != 0) return createdCompare;
    final aFolioSort = int.tryParse(a.folio.replaceAll(RegExp(r'[^0-9]'), ''));
    final bFolioSort = int.tryParse(b.folio.replaceAll(RegExp(r'[^0-9]'), ''));
    if (aFolioSort != null && bFolioSort != null && aFolioSort != bFolioSort) {
      return bFolioSort.compareTo(aFolioSort);
    }
    return b.folio.compareTo(a.folio);
  }

  static DateTime? _tryParseDateTime(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

void debugDirectionVaultRepositoryError(
  String action,
  Object error,
  StackTrace stackTrace,
) {
  debugPrint('DirectionVaultRepository.$action failed: $error\n$stackTrace');
}
