import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';

/// Page palette reserved for Pesadas and Entradas y Salidas.
abstract final class OperationsRedColors {
  static const primary = Color(0xFFC43C45);
  static const strong = Color(0xFF8F2028);
  static const ink = Color(0xFF4A1518);
  static const muted = Color(0xFF783438);
  static const soft = Color(0xFFF8DADC);
  static const surface = Color(0xFFFFF3F1);
  static const field = Color(0xFFFFF8F7);
  static const border = Color(0xFFDB9AA0);
  static const hover = Color(0xFFFCE8E7);
  static const selection = Color(0xFFF5C7CD);
  static const accent = Color(0xFFD95761);
  static const glow = Color(0xFFF5A8A1);
  static const shadow = Color(0xFF7E2934);
  static const backgroundTop = Color(0xFFFFD8D2);
  static const backgroundMiddle = Color(0xFFE87878);
  static const backgroundBottom = Color(0xFFB73545);
}

const operationsRedTokens = ContractAreaTokens(
  primary: OperationsRedColors.primary,
  primaryStrong: OperationsRedColors.strong,
  primarySoft: OperationsRedColors.soft,
  accent: OperationsRedColors.accent,
  surfaceTint: OperationsRedColors.surface,
  border: OperationsRedColors.border,
  badgeBackground: OperationsRedColors.soft,
  badgeText: OperationsRedColors.ink,
  glow: OperationsRedColors.glow,
  onGlass: OperationsRedColors.ink,
);

/// Keeps shared legacy controls unchanged outside the two red pages.
Color operationsPageColor(BuildContext context, Color legacy, Color red) =>
    OperationsRedTheme.isActive(context) ? red : legacy;

class OperationsRedTheme extends StatelessWidget {
  final Widget child;

  const OperationsRedTheme({super.key, required this.child});

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OperationsRedScope>() != null;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: OperationsRedColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: OperationsRedColors.strong,
          onPrimary: Colors.white,
          primaryContainer: OperationsRedColors.soft,
          onPrimaryContainer: OperationsRedColors.ink,
          secondary: OperationsRedColors.primary,
          onSecondary: Colors.white,
          secondaryContainer: OperationsRedColors.hover,
          onSecondaryContainer: OperationsRedColors.ink,
          tertiary: OperationsRedColors.accent,
          surface: OperationsRedColors.surface,
          onSurface: OperationsRedColors.ink,
          onSurfaceVariant: OperationsRedColors.muted,
          outline: OperationsRedColors.border,
          outlineVariant: OperationsRedColors.soft,
          surfaceTint: OperationsRedColors.primary,
        );
    return _OperationsRedScope(
      child: AreaThemeScope(
        tokens: operationsRedTokens,
        child: Theme(
          data: base.copyWith(
            colorScheme: scheme,
            textTheme: base.textTheme.apply(
              bodyColor: OperationsRedColors.ink,
              displayColor: OperationsRedColors.ink,
            ),
            iconTheme: base.iconTheme.copyWith(
              color: OperationsRedColors.strong,
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: OperationsRedColors.strong,
              selectionColor: OperationsRedColors.selection,
              selectionHandleColor: OperationsRedColors.strong,
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: OperationsRedColors.primary,
            ),
            dropdownMenuTheme: const DropdownMenuThemeData(
              menuStyle: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(
                  OperationsRedColors.surface,
                ),
              ),
            ),
            popupMenuTheme: const PopupMenuThemeData(
              color: OperationsRedColors.surface,
              surfaceTintColor: OperationsRedColors.primary,
            ),
            tooltipTheme: TooltipThemeData(
              decoration: BoxDecoration(
                color: OperationsRedColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// InheritedTheme is captured by dialog, popup and menu routes. Recreate the
// area scope there as well so contract controls retain the host page's tokens.
class _OperationsRedScope extends InheritedTheme {
  const _OperationsRedScope({required super.child});

  @override
  Widget wrap(BuildContext context, Widget child) =>
      OperationsRedTheme(child: child);

  @override
  bool updateShouldNotify(_OperationsRedScope oldWidget) => false;
}
