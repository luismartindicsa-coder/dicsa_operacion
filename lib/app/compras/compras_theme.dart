import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens comprasAreaTokens = ContractAreaTokens(
  primary: Color(0xFFD9DEE3),
  primaryStrong: Color(0xFFF8FAFC),
  primarySoft: Color(0xFF232A31),
  accent: Color(0xFFB7C0C8),
  surfaceTint: Color(0xFF8C98A4),
  border: Color(0xFF5F6B77),
  badgeBackground: Color(0xFF1D242B),
  badgeText: Color(0xFFF4F7FA),
  glow: Color(0xFFD6DDE5),
  darkGlass: true,
  glassSurface: Color(0x52303840),
  fieldSurface: Color(0x7A151A20),
  onGlass: Color(0xFFF4F7FA),
);

const LinearGradient kComprasHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF050608), Color(0xFF15191E), Color(0xFF3C434A)],
);

const LinearGradient kComprasPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF14191E), Color(0xFF202730)],
);

const LinearGradient kComprasAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF9FBFD), Color(0xFF7E8791)],
);

const Color kComprasInk = Color(0xFFF4F7FA);
const Color kComprasMutedInk = Color(0xFFB2BCC6);
