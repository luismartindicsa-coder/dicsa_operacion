import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens comprasAreaTokens = ContractAreaTokens(
  primary: Color(0xFF191010),
  primaryStrong: Color(0xFF0C0707),
  primarySoft: Color(0xFFF0E4E2),
  accent: Color(0xFFB52A23),
  surfaceTint: Color(0xFFF1E9E8),
  border: Color(0xFFC9ACAA),
  badgeBackground: Color(0xFFE9D5D2),
  badgeText: Color(0xFF731C18),
  glow: Color(0xFF7E1712),
);

const LinearGradient kComprasHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF120B0B), Color(0xFF261212), Color(0xFFB52A23)],
);

const LinearGradient kComprasPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF5ECEB), Color(0xFFE7D3D0)],
);

const LinearGradient kComprasAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF0B9B3), Color(0xFF9C211B)],
);

const Color kComprasInk = Color(0xFF120808);
const Color kComprasMutedInk = Color(0xFF5C302D);
