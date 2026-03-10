import 'package:flutter/material.dart';

import '../shared/page_routes.dart';
import 'auth_access.dart';
import 'auth_gate.dart';

Future<void> signOutAndRouteToLogin(BuildContext context) async {
  await AuthSessionActions.signOut();
  if (!context.mounted) return;
  Navigator.of(
    context,
    rootNavigator: true,
  ).pushAndRemoveUntil(appPageRoute(page: const AuthGate()), (_) => false);
}
