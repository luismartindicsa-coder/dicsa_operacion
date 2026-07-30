import 'package:flutter/material.dart';

import '../logistica/logistics_theme.dart';

class ServicesVisualModeScope extends InheritedWidget {
  final bool logisticsSilverMode;

  const ServicesVisualModeScope({
    super.key,
    required this.logisticsSilverMode,
    required super.child,
  });

  static bool isLogisticsSilver(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ServicesVisualModeScope>()
            ?.logisticsSilverMode ??
        false;
  }

  @override
  bool updateShouldNotify(ServicesVisualModeScope oldWidget) {
    return logisticsSilverMode != oldWidget.logisticsSilverMode;
  }
}

class ServicesVisualPalette {
  final bool logisticsSilver;

  const ServicesVisualPalette._({required this.logisticsSilver});

  factory ServicesVisualPalette.of(BuildContext context) {
    return ServicesVisualPalette._(
      logisticsSilver: ServicesVisualModeScope.isLogisticsSilver(context),
    );
  }

  Color get textPrimary =>
      logisticsSilver ? kLogisticsSilverTextPrimary : const Color(0xFF0B2B2B);

  Color get textSecondary =>
      logisticsSilver ? kLogisticsSilverTextSecondary : const Color(0xFF2A4B49);

  Color get textMuted =>
      logisticsSilver ? kLogisticsSilverTextMuted : const Color(0xFF48637E);

  Color get icon =>
      logisticsSilver ? kLogisticsSilverIcon : const Color(0xFF0B2B2B);

  Color get surfaceBase => logisticsSilver
      ? const Color(0xF6F7F9FB)
      : Colors.white.withValues(alpha: 0.62);

  Color get surfaceElevated => logisticsSilver
      ? const Color(0xFFF3F5F7)
      : Colors.white.withValues(alpha: 0.40);

  Color get surfaceInteractive => logisticsSilver
      ? kLogisticsSilverSurfaceInteractive
      : const Color(0xFFEAF2F9);

  Color get surfaceHover =>
      logisticsSilver ? kLogisticsSilverSurfaceHover : const Color(0xFFE2EEEC);

  Color get fieldFill => logisticsSilver
      ? const Color(0xFFF8F9FB)
      : Colors.white.withValues(alpha: 0.45);

  Color get fieldFillStrong => logisticsSilver
      ? const Color(0xFFFBFCFD)
      : Colors.white.withValues(alpha: 0.88);

  Color get border => logisticsSilver
      ? kLogisticsSilverBorder.withValues(alpha: 0.92)
      : Colors.white.withValues(alpha: 0.55);

  Color get borderStrong => logisticsSilver
      ? const Color(0xFFFFFFFF)
      : Colors.white.withValues(alpha: 0.68);

  Color get divider =>
      logisticsSilver ? kLogisticsSilverDivider : const Color(0x330B2B2B);

  Color get shadow => logisticsSilver
      ? const Color(0x2A1F2630)
      : Colors.black.withValues(alpha: 0.06);

  Color get deepShadow => logisticsSilver
      ? const Color(0x33192028)
      : Colors.black.withValues(alpha: 0.18);

  Color get glow => logisticsSilver
      ? kLogisticsSilverGlowEdge.withValues(alpha: 0.28)
      : const Color(0xFF0E86FF).withValues(alpha: 0.20);

  Color get filterAccent =>
      logisticsSilver ? const Color(0xFF727A84) : const Color(0xFF4F8E8C);

  Color get filterAccentSoft =>
      logisticsSilver ? const Color(0xFFE7EAEE) : const Color(0xFFE2EEEC);

  Color get buttonFill =>
      logisticsSilver ? const Color(0xFFD6DBE0) : const Color(0xFF4F8E8C);

  Color get buttonFillForeground =>
      logisticsSilver ? kLogisticsSilverTextPrimary : Colors.white;

  Color get menuSurface =>
      logisticsSilver ? const Color(0xF0F3F5F8) : const Color(0xE40B2B2B);

  Color get menuSoftFill => logisticsSilver
      ? const Color(0xFFFFFFFF)
      : Colors.white.withValues(alpha: 0.08);

  Color get menuSoftFillActive => logisticsSilver
      ? const Color(0xFFF7F8FA)
      : Colors.white.withValues(alpha: 0.14);

  Color get menuText =>
      logisticsSilver ? kLogisticsSilverTextPrimary : Colors.white;

  Color get menuTextMuted => logisticsSilver
      ? kLogisticsSilverTextSecondary
      : Colors.white.withValues(alpha: 0.72);

  Color get menuChevron => logisticsSilver
      ? kLogisticsSilverIcon
      : Colors.white.withValues(alpha: 0.78);

  Color get selectedRowFill => logisticsSilver
      ? const Color(0xFFE1E6EB)
      : const Color(0xFF00A3FF).withValues(alpha: 0.16);

  Color get selectedRowSecondaryFill => logisticsSilver
      ? const Color(0xFFD8DEE5)
      : const Color(0xFF00A3FF).withValues(alpha: 0.13);

  Color get editingRowFill =>
      logisticsSilver ? const Color(0xFFECEFF3) : const Color(0xFFDCEBFF);

  Color get hoverRowFill =>
      logisticsSilver ? const Color(0xFFF6F8FA) : const Color(0xFFEEF5FF);

  LinearGradient get glassCardGradient => logisticsSilver
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kLogisticsSilverSurfaceTop,
            kLogisticsSilverSurfaceMiddle,
            kLogisticsSilverSurfaceBottom,
          ],
        )
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.68),
            Colors.white.withValues(alpha: 0.56),
          ],
        );

  LinearGradient get buttonGradient => logisticsSilver
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFEFF), Color(0xFFE7EAEE), Color(0xFFD2D8DE)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x3398BCD9), Color(0x22FFFFFF)],
        );

  LinearGradient get menuPanelGradient => logisticsSilver
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F9FA), Color(0xFFE7EAEE), Color(0xFFD2D8E0)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x00000000), Color(0x00000000)],
        );

  LinearGradient get menuEmphasisGradient => logisticsSilver
      ? const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEBEEF2), Color(0xFFD6DBE0)],
        )
      : const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2196F3), Color(0xFF1DE9B6)],
        );
}
