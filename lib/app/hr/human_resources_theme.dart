import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens humanResourcesAreaTokens = ContractAreaTokens(
  primary: Color(0xFF6F3FE8),
  primaryStrong: Color(0xFF2B114F),
  primarySoft: Color(0xFFEEE5FF),
  accent: Color(0xFFA66BFF),
  surfaceTint: Color(0xFFF6F1FF),
  border: Color(0xFFD6C6F4),
  badgeBackground: Color(0xFFE9DEFF),
  badgeText: Color(0xFF5B2AB5),
  glow: Color(0xFF8D63E8),
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
