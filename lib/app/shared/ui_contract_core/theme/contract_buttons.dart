import 'package:flutter/material.dart';

import 'area_theme_scope.dart';

ButtonStyle contractPrimaryButtonStyle(BuildContext context) {
  final tokens = AreaThemeScope.of(context);
  final darkGlass = tokens.darkGlass;
  return ElevatedButton.styleFrom(
    foregroundColor: darkGlass
        ? (tokens.accentDarkGlass ? Colors.white : const Color(0xFF0B0E12))
        : Colors.white,
    backgroundColor: darkGlass
        ? (tokens.accentDarkGlass ? tokens.primaryStrong : tokens.accent)
        : tokens.primaryStrong,
    disabledBackgroundColor: darkGlass
        ? tokens.fieldSurface.withValues(alpha: 0.72)
        : tokens.primarySoft.withValues(alpha: 0.5),
    disabledForegroundColor: darkGlass
        ? (tokens.accentDarkGlass
              ? Colors.white.withValues(alpha: 0.64)
              : tokens.onGlass.withValues(alpha: 0.42))
        : Colors.white.withValues(alpha: 0.7),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    shadowColor: darkGlass && tokens.accentDarkGlass
        ? tokens.glow.withValues(alpha: 0.24)
        : null,
  );
}

ButtonStyle contractDestructiveButtonStyle(BuildContext context) {
  final tokens = AreaThemeScope.of(context);
  return ElevatedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: tokens.primaryStrong,
    disabledBackgroundColor: tokens.primaryStrong.withValues(alpha: 0.44),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    shadowColor: tokens.glow.withValues(alpha: 0.14),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle contractSecondaryButtonStyle(BuildContext context) {
  final tokens = AreaThemeScope.of(context);
  return OutlinedButton.styleFrom(
    foregroundColor: tokens.darkGlass
        ? (tokens.accentDarkGlass ? tokens.onGlass : tokens.onGlass)
        : tokens.primaryStrong,
    side: BorderSide(
      color: tokens.darkGlass
          ? (tokens.accentDarkGlass
                ? tokens.border.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.14))
          : tokens.border.withValues(alpha: 0.9),
    ),
    backgroundColor: tokens.darkGlass
        ? (tokens.accentDarkGlass
              ? tokens.glassSurface.withValues(alpha: 0.92)
              : tokens.fieldSurface.withValues(alpha: 0.72))
        : Colors.white.withValues(alpha: 0.58),
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
