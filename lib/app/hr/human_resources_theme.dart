import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens humanResourcesAreaTokens = ContractAreaTokens(
  primary: Color(0xFF9F6BFF),
  primaryStrong: Color(0xFF2B114F),
  primarySoft: Color(0xFFEEE5FF),
  accent: Color(0xFFB68CFF),
  surfaceTint: Color(0xFF6E47A8),
  border: Color(0xFFB084FF),
  badgeBackground: Color(0xFF34204E),
  badgeText: Color(0xFFC79CFF),
  glow: Color(0xFFB68CFF),
  darkGlass: true,
  glassSurface: Color(0xE025163A),
  fieldSurface: Color(0xD925163A),
  onGlass: Color(0xFFFFFFFF),
);

const LinearGradient kHumanResourcesPanelGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFF2EBFF), Color(0xFFE2D2FF)],
);

const LinearGradient kHumanResourcesPanelHighlightGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFC7AEFF), Color(0xFF8453F0)],
);

const LinearGradient kHumanResourcesPanelAccentGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF7A4AF0), Color(0xFF2B114F)],
);

const Color kHumanResourcesPanelShadow = Color(0xFF2C1554);
const Color kHumanResourcesSurfaceText = Color(0xFF221836);
const Color kHumanResourcesMutedText = Color(0xFF675985);
