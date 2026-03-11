import 'package:flutter/material.dart';

@immutable
class ContractAreaTokens {
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color accent;
  final Color surfaceTint;
  final Color border;
  final Color badgeBackground;
  final Color badgeText;
  final Color glow;

  const ContractAreaTokens({
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.accent,
    required this.surfaceTint,
    required this.border,
    required this.badgeBackground,
    required this.badgeText,
    required this.glow,
  });

  factory ContractAreaTokens.fallback() {
    return const ContractAreaTokens(
      primary: Color(0xFF3CB4E5),
      primaryStrong: Color(0xFF1E88C8),
      primarySoft: Color(0xFFB9E7F7),
      accent: Color(0xFF32D2A6),
      surfaceTint: Color(0xFFEAF7FB),
      border: Color(0xFFC7DCE8),
      badgeBackground: Color(0xFFDDF4EC),
      badgeText: Color(0xFF0D5C46),
      glow: Color(0xFF6EC7E8),
    );
  }
}
