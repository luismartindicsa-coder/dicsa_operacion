import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'friendly_error_message.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppErrorReporter {
  static final Queue<String> _pendingMessages = Queue<String>();
  static bool _showingMessage = false;
  static String? _lastMessage;
  static DateTime? _lastShownAt;
  static int _snackBarSerial = 0;

  static void report(
    Object error,
    StackTrace stackTrace, {
    String? fallbackMessage,
  }) {
    if (!isNetworkError(error)) {
      debugPrintStack(stackTrace: stackTrace, label: error.toString());
    }
    showMessage(_messageFrom(error, fallbackMessage: fallbackMessage));
  }

  static void showMessage(String message) {
    final text = message.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final dedupeWindow = _isNetworkMessage(text)
        ? const Duration(seconds: 20)
        : const Duration(seconds: 2);
    if (_lastMessage == text &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < dedupeWindow) {
      return;
    }

    if (_showingMessage && _lastMessage == text) {
      return;
    }

    if (_pendingMessages.contains(text)) {
      return;
    }

    _pendingMessages.add(text);
    _flush();
  }

  static void _flush() {
    if (_showingMessage || _pendingMessages.isEmpty) return;
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
      return;
    }

    _showingMessage = true;
    final message = _pendingMessages.removeFirst();
    _lastMessage = message;
    _lastShownAt = DateTime.now();
    messenger
        .showSnackBar(
          SnackBar(
            key: ValueKey<String>('app-error-${_snackBarSerial++}'),
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        )
        .closed
        .whenComplete(() {
          _showingMessage = false;
          _flush();
        });
  }

  static String _messageFrom(Object error, {String? fallbackMessage}) {
    if (error is FlutterError) {
      return fallbackMessage ?? error.toString();
    }
    return friendlyErrorMessage(error, fallbackMessage: fallbackMessage);
  }

  static bool _isNetworkMessage(String message) {
    return message.contains('No se pudo resolver el host de Supabase') ||
        message.contains('No se pudo conectar con Supabase');
  }
}
