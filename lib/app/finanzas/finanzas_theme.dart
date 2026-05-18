import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens finanzasAreaTokens = ContractAreaTokens(
  primary: Color(0xFF9F231D),
  primaryStrong: Color(0xFF56110E),
  primarySoft: Color(0xFFFBE8E6),
  accent: Color(0xFF241313),
  surfaceTint: Color(0xFFF9EFEE),
  border: Color(0xFFE1B6B1),
  badgeBackground: Color(0xFFF6DBD8),
  badgeText: Color(0xFF7A1914),
  glow: Color(0xFF51110E),
);

const LinearGradient kFinanzasHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFBC2D25), Color(0xFF8B1D18), Color(0xFF241313)],
);

const LinearGradient kFinanzasPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFCEFED), Color(0xFFF4D0CB)],
);

const LinearGradient kFinanzasAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFD2CC), Color(0xFF241313)],
);

const Color kFinanzasInk = Color(0xFF56110E);
const Color kFinanzasMutedInk = Color(0xFF7A3531);
