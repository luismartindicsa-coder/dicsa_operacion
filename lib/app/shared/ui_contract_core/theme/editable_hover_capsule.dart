import 'package:flutter/material.dart';

import 'area_theme_scope.dart';

class ContractEditableHoverCapsule extends StatelessWidget {
  final Widget child;
  final bool hovered;
  final bool active;
  final bool selectedContext;
  final BorderRadius borderRadius;
  final Duration duration;
  final Curve curve;
  final EdgeInsetsGeometry padding;

  const ContractEditableHoverCapsule({
    super.key,
    required this.child,
    this.hovered = false,
    this.active = false,
    this.selectedContext = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.duration = const Duration(milliseconds: 110),
    this.curve = Curves.easeOutCubic,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final showHover = hovered && !active;
    final hoverTop = Color.lerp(
      tokens.surfaceTint,
      selectedContext ? tokens.primarySoft : tokens.primary,
      selectedContext ? 0.64 : 0.22,
    )!;
    final hoverBottom = Color.lerp(
      tokens.surfaceTint,
      selectedContext ? tokens.glow : tokens.accent,
      selectedContext ? 0.46 : 0.18,
    )!;
    final hoverBorder = Color.lerp(
      tokens.border,
      tokens.primaryStrong,
      showHover ? 0.46 : 0.22,
    )!;

    return AnimatedContainer(
      duration: duration,
      curve: curve,
      transform: Matrix4.identity()
        ..translateByDouble(0.0, showHover ? -0.8 : 0.0, 0.0, 1.0)
        ..scaleByDouble(
          showHover ? 1.012 : 1.0,
          showHover ? 1.012 : 1.0,
          1.0,
          1.0,
        ),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: showHover
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  hoverTop.withValues(alpha: selectedContext ? 0.88 : 0.72),
                  hoverBottom.withValues(alpha: selectedContext ? 0.72 : 0.62),
                ],
              )
            : null,
        color: active
            ? tokens.surfaceTint.withValues(alpha: 0.78)
            : Colors.transparent,
        border: Border.all(
          color: active
              ? tokens.primaryStrong.withValues(alpha: 0.88)
              : showHover
              ? hoverBorder.withValues(alpha: 0.72)
              : Colors.transparent,
          width: active ? 1.12 : 1.0,
        ),
        boxShadow: showHover
            ? [
                BoxShadow(
                  color: tokens.glow.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
