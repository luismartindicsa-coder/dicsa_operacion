import 'package:flutter/material.dart';

import 'action_permission.dart';

class VisibilityGuard extends StatelessWidget {
  final ActionPermission permission;
  final Widget child;
  final Widget? deniedChild;

  const VisibilityGuard({
    super.key,
    required this.permission,
    required this.child,
    this.deniedChild,
  });

  @override
  Widget build(BuildContext context) {
    if (permission.allowed) return child;
    return deniedChild ?? const SizedBox.shrink();
  }
}

class EnabledActionGuard extends StatelessWidget {
  final ActionPermission permission;
  final Widget Function(BuildContext context, bool enabled, String? reason)
  builder;

  const EnabledActionGuard({
    super.key,
    required this.permission,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, permission.allowed, permission.disabledReason);
  }
}
