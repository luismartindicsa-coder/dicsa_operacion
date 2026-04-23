import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens mayoreoAreaTokens = ContractAreaTokens(
  primary: Color(0xFFFBC20F),
  primaryStrong: Color(0xFF6A5200),
  primarySoft: Color(0xFFFFF0A6),
  accent: Color(0xFFFFE900),
  surfaceTint: Color(0xFFFFFBE7),
  border: Color(0xFFF0D15F),
  badgeBackground: Color(0xFFFFF3B8),
  badgeText: Color(0xFF6D5400),
  glow: Color(0xFFFFE54A),
);

const LinearGradient kMayoreoHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF88C12), Color(0xFFF9A411), Color(0xFFFBC40E)],
);

const LinearGradient kMayoreoPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFF8DF), Color(0xFFFFE97C)],
);

const Color kMayoreoInk = Color(0xFF5A4300);
const Color kMayoreoMutedInk = Color(0xFF7A6200);
