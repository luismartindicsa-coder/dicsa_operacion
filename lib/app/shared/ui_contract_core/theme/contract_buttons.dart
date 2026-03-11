import 'package:flutter/material.dart';

import 'area_theme_scope.dart';

ButtonStyle contractPrimaryButtonStyle(BuildContext context) {
  final tokens = AreaThemeScope.of(context);
  return ElevatedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: tokens.primaryStrong,
    disabledBackgroundColor: tokens.primarySoft.withValues(alpha: 0.5),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

ButtonStyle contractSecondaryButtonStyle(BuildContext context) {
  final tokens = AreaThemeScope.of(context);
  return OutlinedButton.styleFrom(
    foregroundColor: tokens.primaryStrong,
    side: BorderSide(color: tokens.border.withValues(alpha: 0.9)),
    backgroundColor: Colors.white.withValues(alpha: 0.58),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

ButtonStyle contractGhostButtonStyle(BuildContext context) {
  final tokens = AreaThemeScope.of(context);
  return TextButton.styleFrom(
    foregroundColor: tokens.primaryStrong,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}
