import 'package:flutter/widgets.dart';

@immutable
class ActionPermission {
  final bool allowed;
  final String? disabledReason;

  const ActionPermission.allowed() : allowed = true, disabledReason = null;

  const ActionPermission.denied([this.disabledReason]) : allowed = false;
}
