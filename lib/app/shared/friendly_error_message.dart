import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyErrorMessage(Object error, {String? fallbackMessage}) {
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
  if (error is SocketException) {
    return _networkUnavailableMessage(error);
  }

  final message = error.toString().trim();
  if (message.isEmpty) {
    return fallbackMessage ?? 'Ocurrio un error inesperado.';
  }
  if (_looksLikeNetworkError(message)) {
    return _networkUnavailableMessage(error);
  }
  return fallbackMessage ?? message;
}

bool _looksLikeNetworkError(String message) {
  return message.contains('Failed host lookup') ||
      message.contains('SocketException') ||
      message.contains('ClientException') ||
      message.contains("Can't assign requested address") ||
      message.contains('Connection refused') ||
      message.contains('Network is unreachable');
}

String _networkUnavailableMessage(Object error) {
  final message = error.toString();
  if (message.contains('Failed host lookup')) {
    return 'No se pudo resolver el host de Supabase. Revisa DNS o la conexion a internet.';
  }
  return 'No se pudo conectar con Supabase. Intenta de nuevo en un momento.';
}

String _pickFirst(String? a, String? b, String? c) {
  for (final value in [a, b, c]) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return 'Ocurrio un error inesperado.';
}
