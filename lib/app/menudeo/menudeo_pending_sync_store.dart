import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class MenudeoPendingSyncEntry {
  final String id;
  final String scope;
  final String operation;
  final String fingerprint;
  final String createdAtIso;
  final Map<String, dynamic> payload;

  const MenudeoPendingSyncEntry({
    required this.id,
    required this.scope,
    required this.operation,
    required this.fingerprint,
    required this.createdAtIso,
    required this.payload,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'scope': scope,
      'operation': operation,
      'fingerprint': fingerprint,
      'created_at': createdAtIso,
      'payload': payload,
    };
  }

  static MenudeoPendingSyncEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final payload = raw['payload'];
    if (payload is! Map) return null;
    return MenudeoPendingSyncEntry(
      id: (raw['id'] ?? '').toString(),
      scope: (raw['scope'] ?? '').toString(),
      operation: (raw['operation'] ?? '').toString(),
      fingerprint: (raw['fingerprint'] ?? '').toString(),
      createdAtIso: (raw['created_at'] ?? '').toString(),
      payload: Map<String, dynamic>.from(payload),
    );
  }
}

class MenudeoPendingSyncStore {
  static const String _storageKey = 'menudeo_pending_sync_queue';

  static Future<List<MenudeoPendingSyncEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <MenudeoPendingSyncEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <MenudeoPendingSyncEntry>[];
      return decoded
          .map(MenudeoPendingSyncEntry.fromJson)
          .whereType<MenudeoPendingSyncEntry>()
          .toList(growable: true);
    } catch (_) {
      return const <MenudeoPendingSyncEntry>[];
    }
  }

  static Future<List<MenudeoPendingSyncEntry>> loadEntriesForScope(
    String scope,
  ) async {
    final entries = await loadEntries();
    return entries
        .where((entry) => entry.scope == scope)
        .toList(growable: false);
  }

  static Future<int> countForScope(String scope) async {
    final entries = await loadEntriesForScope(scope);
    return entries.length;
  }

  static Future<void> enqueue({
    required String scope,
    required String operation,
    required String fingerprint,
    required Map<String, dynamic> payload,
  }) async {
    final entries = await loadEntries();
    entries.removeWhere(
      (entry) => entry.scope == scope && entry.fingerprint == fingerprint,
    );
    entries.add(
      MenudeoPendingSyncEntry(
        id: _nextId(scope),
        scope: scope,
        operation: operation,
        fingerprint: fingerprint,
        createdAtIso: DateTime.now().toIso8601String(),
        payload: payload,
      ),
    );
    await _saveEntries(entries);
  }

  static Future<void> removeById(String id) async {
    final entries = await loadEntries();
    entries.removeWhere((entry) => entry.id == id);
    await _saveEntries(entries);
  }

  static Future<void> removeByFingerprint({
    required String scope,
    required String fingerprint,
  }) async {
    final entries = await loadEntries();
    entries.removeWhere(
      (entry) => entry.scope == scope && entry.fingerprint == fingerprint,
    );
    await _saveEntries(entries);
  }

  static Future<void> _saveEntries(
    List<MenudeoPendingSyncEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(
        entries.map((entry) => entry.toJson()).toList(growable: false),
      ),
    );
  }

  static String _nextId(String scope) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$scope-$now-$random';
  }
}
