import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// An immutable, retryable unit of work. Never falls back to sequential writes.
class AtomicSave {
  final String requestId;
  final List<Map<String, dynamic>> operations;
  final List<Map<String, dynamic>> checks;

  AtomicSave({
    required List<Map<String, dynamic>> operations,
    List<Map<String, dynamic>> checks = const [],
    String? requestId,
  }) : requestId = requestId ?? const Uuid().v4(),
       operations = _copy(operations),
       checks = _copy(checks);

  static List<Map<String, dynamic>> _copy(List<Map<String, dynamic>> value) =>
      (jsonDecode(jsonEncode(value)) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

  Future<List<Map<String, dynamic>>> commit(SupabaseClient client) async {
    Future<List<Map<String, dynamic>>> send() async {
      final result = await client.rpc(
        'app_commit_preserving_data',
        params: {
          'p_request_id': requestId,
          'p_operations': operations,
          'p_checks': checks,
        },
      );
      return (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }

    try {
      return await send();
    } on PostgrestException {
      rethrow; // Validation/conflict failures must not silently overwrite data.
    } catch (_) {
      // A response may be lost after commit; the same receipt prevents duplicates.
      return send();
    }
  }
}

bool sameStoredValue(dynamic a, dynamic b) {
  if (a is num && b is num) return a == b;
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (i) => sameStoredValue(a[i], b[i]),
        ).every((v) => v);
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && sameStoredValue(a[k], b[k]));
  }
  return a == b;
}

/// Only changes fields edited since loading; absence in a stale screen is not
/// evidence that a newly added server row should be deleted.
List<Map<String, dynamic>> preservingRowChanges({
  required String table,
  required List<Map<String, dynamic>> before,
  required List<Map<String, dynamic>> after,
  List<Map<String, dynamic>>? expected,
}) {
  final oldRows = {for (final r in before) r['id'].toString(): r};
  final originals = {for (final r in expected ?? before) r['id'].toString(): r};
  final nextRows = {for (final r in after) r['id'].toString(): r};
  if (oldRows.length != before.length ||
      nextRows.length != after.length ||
      [
        ...before,
        ...after,
      ].any((r) => r['id'] == null || '${r['id']}'.isEmpty)) {
    throw StateError('El guardado requiere identificadores únicos.');
  }
  final operations = <Map<String, dynamic>>[];
  for (final row in after) {
    final id = row['id'].toString();
    final old = oldRows[id];
    if (old == null) {
      operations.add({
        'table': table,
        'action': 'insert',
        'id': id,
        'values': row,
      });
      continue;
    }
    final patch = <String, dynamic>{
      for (final key in row.keys)
        if (key != 'id' && !sameStoredValue(old[key], row[key])) key: row[key],
    };
    if (patch.isNotEmpty) {
      operations.add({
        'table': table,
        'action': 'update',
        'id': id,
        'values': patch,
        'expected': {for (final key in patch.keys) key: originals[id]?[key]},
      });
    }
  }
  for (final id in oldRows.keys.where((id) => !nextRows.containsKey(id))) {
    operations.add({
      'table': table,
      'action': 'delete',
      'id': id,
      'expected': originals[id],
    });
  }
  return operations;
}
