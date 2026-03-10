import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppErrorReporter {
  static final Queue<String> _pendingMessages = Queue<String>();
  static bool _showingMessage = false;
  static String? _lastMessage;
  static DateTime? _lastShownAt;

  static void report(
    Object error,
    StackTrace stackTrace, {
    String? fallbackMessage,
  }) {
    debugPrintStack(stackTrace: stackTrace, label: error.toString());
    showMessage(_messageFrom(error, fallbackMessage: fallbackMessage));
  }

  static void showMessage(String message) {
    final text = message.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    if (_lastMessage == text &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 2)) {
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

    _showingMessage = true;
    final message = _pendingMessages.removeFirst();
    _lastMessage = message;
    _lastShownAt = DateTime.now();
    messenger
        .showSnackBar(
          SnackBar(
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
    if (error is PostgrestException) {
      return _pickFirst(
        error.message,
        error.details?.toString(),
        fallbackMessage,
      );
    }
    if (error is AuthException) {
      return _pickFirst(error.message, fallbackMessage, null);
    }
    if (error is FlutterError) {
      return fallbackMessage ?? error.toString();
    }
    if (error is Exception) {
      return fallbackMessage ?? error.toString();
    }
    return fallbackMessage ?? error.toString();
  }

  static String _pickFirst(String? a, String? b, String? c) {
    for (final value in [a, b, c]) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'Ocurrio un error inesperado.';
  }
}
