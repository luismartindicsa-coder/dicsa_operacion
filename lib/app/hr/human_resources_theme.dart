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

/// Payroll status palette shared by Prenómina and Nómina.
({Color background, Color border, Color foreground})
humanResourcesPayrollStatusColors(String label) => switch (label) {
  'Revisión RH' => (
    background: const Color(0xFFF4E3EA),
    border: const Color(0xFFD69BB3),
    foreground: const Color(0xFF7A284C),
  ),
  'Publicado' => (
    background: const Color(0xFFDCC5FF),
    border: const Color(0xFF8B5CF6),
    foreground: const Color(0xFF24103D),
  ),
  'Listo' => (
    background: const Color(0xFFEFE4FF),
    border: humanResourcesAreaTokens.border,
    foreground: humanResourcesAreaTokens.surfaceTint,
  ),
  _ => (
    background: const Color(0xFFE8D9FF),
    border: const Color(0x66B084FF),
    foreground: const Color(0xFF24103D),
  ),
};

/// Shared compact header for RH operational dialogs.
/// Employee identity stays in the fixed side card, leaving the dialog body
/// with enough vertical space to operate and scroll.
class HumanResourcesCompactDialogHeader extends StatelessWidget {
  final String title;
  final String contextLabel;
  final VoidCallback onClose;

  const HumanResourcesCompactDialogHeader({
    super.key,
    required this.title,
    required this.contextLabel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24103D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                contextLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6E47A8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onClose,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF1E6FF).withValues(alpha: 0.92),
            foregroundColor: const Color(0xFF6E47A8),
            side: const BorderSide(color: Color(0x66B084FF)),
          ),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
        ),
      ],
    );
  }
}
