import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class SessionExpiryService {
  SessionExpiryService._();
  static final SessionExpiryService instance = SessionExpiryService._();

  static const Duration sessionDuration = Duration(hours: 5);
  static const String _kSessionStartedAtMs = 'session_started_at_ms';

  Timer? _expiryTimer;

  Future<DateTime?> sessionStartedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final startedAtMs = prefs.getInt(_kSessionStartedAtMs);
    if (startedAtMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  }

  Future<bool> isExpired() async {
    final startedAt = await sessionStartedAt();
    if (startedAt == null) return false;
    return DateTime.now().difference(startedAt) >= sessionDuration;
  }

  Future<void> markSessionStarted({
    DateTime? startedAt,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.containsKey(_kSessionStartedAtMs)) return;
    final value = (startedAt ?? DateTime.now()).millisecondsSinceEpoch;
    await prefs.setInt(_kSessionStartedAtMs, value);
  }

  Future<void> clearSessionStart() async {
    _expiryTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionStartedAtMs);
  }

  Future<void> schedule({required Future<void> Function() onExpired}) async {
    _expiryTimer?.cancel();
    final startedAt = await sessionStartedAt();
    if (startedAt == null) return;
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = sessionDuration - elapsed;

    if (remaining <= Duration.zero) {
      await onExpired();
      return;
    }

    _expiryTimer = Timer(remaining, () {
      unawaited(onExpired());
    });
  }
}
