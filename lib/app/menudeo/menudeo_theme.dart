import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens menudeoAreaTokens = ContractAreaTokens(
  primary: Color(0xFF1149B5),
  primaryStrong: Color(0xFF06152E),
  primarySoft: Color(0xFFD6E1F2),
  accent: Color(0xFF245FCF),
  surfaceTint: Color(0xFFEEF3FA),
  border: Color(0xFF9EB3D6),
  badgeBackground: Color(0xFFDFE9F8),
  badgeText: Color(0xFF123B89),
  glow: Color(0xFF3F69BD),
);

const LinearGradient kMenudeoPanelGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFC9D9F6), Color(0xFF96B0E6)],
);

const LinearGradient kMenudeoPanelHighlightGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF3E6ED9), Color(0xFF0F45AD)],
);

const LinearGradient kMenudeoPanelAccentGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF0A2C72), Color(0xFF041327)],
);

const Color kMenudeoPanelShadow = Color(0xFF081E42);
const Color kMenudeoSurfaceText = Color(0xFF1E2633);
const Color kMenudeoMutedText = Color(0xFF395173);
