import 'package:flutter/material.dart';

import '../shared/app_error_reporter.dart';
import '../shared/page_routes.dart';
import 'auth_access.dart';
import 'auth_gate.dart';

bool _routingToLogin = false;

Future<void> routeToLogin({bool animated = true}) async {
  if (_routingToLogin) return;

  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;

  _routingToLogin = true;
  try {
    navigator.pushAndRemoveUntil(
      appPageRoute(
        page: const AuthGate(),
        routeAnimation: animated,
        fade: animated,
        duration: animated ? const Duration(milliseconds: 480) : Duration.zero,
        reverseDuration: animated
            ? const Duration(milliseconds: 480)
            : Duration.zero,
      ),
      (_) => false,
    );
    await Future<void>.delayed(Duration.zero);
  } finally {
    _routingToLogin = false;
  }
}

Future<void> signOutAndRouteToLogin(BuildContext context) async {
  await AuthSessionActions.signOut();
  if (!context.mounted && appNavigatorKey.currentState == null) return;
  await routeToLogin();
}
