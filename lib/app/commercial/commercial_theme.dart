import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens commercialAreaTokens = ContractAreaTokens(
  primary: Color(0xFFE2B14F),
  primaryStrong: Color(0xFFF5D78A),
  primarySoft: Color(0xFF2A2B1C),
  accent: Color(0xFF8BC6A2),
  surfaceTint: Color(0xFF556B5D),
  border: Color(0xFF7C8F82),
  badgeBackground: Color(0xFF1A221E),
  badgeText: Color(0xFFEAF3EC),
  glow: Color(0xFF8BC6A2),
  darkGlass: true,
  glassSurface: Color(0x52303A34),
  fieldSurface: Color(0x7A111915),
  onGlass: Color(0xFFF1F5F2),
);

const LinearGradient kCommercialHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B0F0D), Color(0xFF151C18), Color(0xFF213128)],
);

const LinearGradient kCommercialPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF141B17), Color(0xFF212B25)],
);

const LinearGradient kCommercialAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF5D78A), Color(0xFF8BC6A2), Color(0xFF1A221E)],
);

const Color kCommercialInk = Color(0xFFF1F5F2);
const Color kCommercialMutedInk = Color(0xFFBBC8C0);
