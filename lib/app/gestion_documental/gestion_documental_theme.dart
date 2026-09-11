import 'package:flutter/material.dart';

import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';

// Area identity only. Glass, spacing and interaction come from DICSA's contract.
const documentalAreaTokens = ContractAreaTokens(
  primary: Color(0xFFFF93C5),
  primaryStrong: Color(0xFFAD326E),
  primarySoft: Color(0xFFFFD3E7),
  accent: Color(0xFFA82E66),
  surfaceTint: Color(0xFF54233D),
  border: Color(0xFFE18CB4),
  badgeBackground: Color(0xFF52213C),
  badgeText: Color(0xFFFFC7E2),
  glow: Color(0xFFE969A6),
  darkGlass: true,
  accentDarkGlass: true,
  glassSurface: Color(0xDB351525),
  fieldSurface: Color(0xF02C1220),
  onGlass: Color(0xFFFFF3F8),
);

final documentalDashboardConfig = EmptyAreaDashboardConfig(
  dashboardLabel: 'Gestión Documental',
  sidePanelLabel: 'Gestión Documental',
  headerTitleColor: documentalAreaTokens.onGlass,
  heroEyebrow: '',
  heroTitle: '',
  heroSubtitle: '',
  emptyTitle: '',
  emptySubtitle: '',
  contractTitle: '',
  contractSubtitle: '',
  contractFootnote: '',
  tokens: documentalAreaTokens,
  ink: documentalAreaTokens.onGlass,
  mutedInk: documentalAreaTokens.primarySoft,
  heroGradient: LinearGradient(colors: [Color(0xFF71304F), Color(0xFF351525)]),
  panelGradient: LinearGradient(colors: [Color(0xF03C192D), Color(0xF028101D)]),
  accentGradient: LinearGradient(
    colors: [Color(0xFFAD326E), Color(0xFF74304F)],
  ),
  backgroundGradientColors: [
    Color(0xFF24101B),
    Color(0xFF361426),
    Color(0xFF501D38),
  ],
  topLeftBlobColors: [Color(0xFF773B59), Color(0xFF29101E)],
  topRightBlobColors: [Color(0x88F089B9), Color(0x1140182B)],
  bottomLeftBlobColors: [Color(0x55E969A6), Color(0x11FFD3E7)],
  pillarGradientColors: [Color(0x77F2A1C8), Color(0xFF381425)],
  areaItems: [],
  showHeroPanel: false,
  showContractPanel: false,
  showPlaceholderCards: false,
  responsiveHeader: true,
);

ThemeData documentalMaterialTheme(ThemeData base) {
  const t = documentalAreaTokens;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: t.primaryStrong,
        brightness: Brightness.dark,
      ).copyWith(
        primary: t.primary,
        onPrimary: t.fieldSurface,
        secondary: t.accent,
        onSecondary: t.onGlass,
        surface: t.glassSurface,
        onSurface: t.onGlass,
        outline: t.border,
      );
  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.fieldSurface,
    canvasColor: t.fieldSurface,
    textTheme: base.textTheme.apply(
      bodyColor: t.onGlass,
      displayColor: t.onGlass,
    ),
    iconTheme: IconThemeData(color: t.primary),
    dividerColor: t.border.withValues(alpha: 0.22),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.primary,
      selectionColor: t.primary.withValues(alpha: 0.3),
      selectionHandleColor: t.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.fieldSurface,
      hintStyle: TextStyle(color: t.onGlass.withValues(alpha: 0.6)),
      prefixIconColor: t.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: t.border.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: t.primary, width: 1.5),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: TextStyle(color: t.onGlass),
    ),
  );
}
