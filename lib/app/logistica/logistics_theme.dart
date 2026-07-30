import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const Color kLogisticsSilverBackgroundTop = Color(0xFFF2F3F5);
const Color kLogisticsSilverBackgroundMiddle = Color(0xFFDDE1E6);
const Color kLogisticsSilverBackgroundBottom = Color(0xFFC7CDD4);

const Color kLogisticsSilverSurfaceTop = Color(0xFFF9FAFB);
const Color kLogisticsSilverSurfaceMiddle = Color(0xFFEEF0F2);
const Color kLogisticsSilverSurfaceBottom = Color(0xFFDDE1E5);

const Color kLogisticsSilverSurfaceElevated = Color(0xFFF4F5F7);
const Color kLogisticsSilverSurfaceInteractive = Color(0xFFE5E8EB);
const Color kLogisticsSilverSurfaceHover = Color(0xFFD7DCE2);

const Color kLogisticsSilverBorder = Color(0xFFB7BDC5);
const Color kLogisticsSilverBorderLight = Color(0xFFFFFFFF);
const Color kLogisticsSilverDivider = Color(0xFFC9CED4);

const Color kLogisticsSilverTextPrimary = Color(0xFF1C222A);
const Color kLogisticsSilverTextSecondary = Color(0xFF555E68);
const Color kLogisticsSilverTextMuted = Color(0xFF7A838D);

const Color kLogisticsSilverIcon = Color(0xFF69727C);
const Color kLogisticsSilverFooterTop = Color(0xFF69717B);
const Color kLogisticsSilverFooterBottom = Color(0xFF49515B);

const Color kLogisticsSilverGlow = Color(0xFFF7FAFD);
const Color kLogisticsSilverGlowEdge = Color(0xFFE6EBF1);

const LinearGradient kLogisticsHeroCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kLogisticsSilverBorderLight,
    kLogisticsSilverSurfaceTop,
    kLogisticsSilverSurfaceBottom,
  ],
  stops: [0.0, 0.48, 1.0],
);

const LinearGradient kLogisticsHeroIconGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kLogisticsSilverBorderLight,
    kLogisticsSilverSurfaceMiddle,
    kLogisticsSilverSurfaceBottom,
  ],
);

const LinearGradient kLogisticsPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kLogisticsSilverBorderLight,
    kLogisticsSilverSurfaceElevated,
    kLogisticsSilverSurfaceBottom,
  ],
  stops: [0.0, 0.58, 1.0],
);

const LinearGradient kLogisticsAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kLogisticsSilverSurfaceTop,
    kLogisticsSilverSurfaceInteractive,
    kLogisticsSilverSurfaceHover,
  ],
  stops: [0.0, 0.54, 1.0],
);

const LinearGradient kLogisticsModuleGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kLogisticsSilverBorderLight,
    kLogisticsSilverSurfaceTop,
    kLogisticsSilverSurfaceElevated,
  ],
  stops: [0.0, 0.50, 1.0],
);

const LinearGradient kLogisticsCapsuleGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kLogisticsSilverSurfaceTop, kLogisticsSilverSurfaceInteractive],
);

const ContractAreaTokens logisticsAreaTokens = ContractAreaTokens(
  primary: kLogisticsSilverIcon,
  primaryStrong: kLogisticsSilverTextPrimary,
  primarySoft: kLogisticsSilverSurfaceInteractive,
  accent: kLogisticsSilverSurfaceHover,
  surfaceTint: kLogisticsSilverSurfaceMiddle,
  border: kLogisticsSilverBorder,
  badgeBackground: kLogisticsSilverSurfaceInteractive,
  badgeText: kLogisticsSilverTextSecondary,
  glow: kLogisticsSilverGlowEdge,
  glassSurface: Color(0xF7F4F5F7),
  fieldSurface: Color(0xFFF4F5F7),
  onGlass: kLogisticsSilverTextPrimary,
);
