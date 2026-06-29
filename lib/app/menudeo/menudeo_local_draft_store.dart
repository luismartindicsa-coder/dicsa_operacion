import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MenudeoLocalDraftStore {
  static const String _draftPrefix = 'menudeo_local_draft::';

  static Future<void> saveDraft({
    required String key,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'saved_at': DateTime.now().toIso8601String(),
      'payload': payload,
    };
    await prefs.setString('$_draftPrefix$key', jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_draftPrefix$key');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final payload = decoded['payload'];
      if (payload is! Map) return null;
      return Map<String, dynamic>.from(payload);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_draftPrefix$key');
  }
}
