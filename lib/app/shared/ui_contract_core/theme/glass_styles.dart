import 'dart:ui';

import 'package:flutter/material.dart';

import 'area_theme_scope.dart';

class ContractGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final double elevation;

  const ContractGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 14,
    this.elevation = 16,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final effectiveBlur = tokens.darkGlass ? blurSigma : blurSigma * 0.48;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.glassSurface,
            borderRadius: borderRadius,
            border: Border.all(
              color: tokens.darkGlass
                  ? tokens.accentDarkGlass
                        ? tokens.border.withValues(alpha: 0.42)
                        : Colors.white.withValues(alpha: 0.18)
                  : tokens.border.withValues(alpha: 0.78),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.darkGlass
                    ? tokens.glow.withValues(
                        alpha: tokens.accentDarkGlass ? 0.22 : 0.12,
                      )
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: tokens.darkGlass ? elevation + 8 : elevation + 8,
                offset: Offset(0, tokens.darkGlass ? 14 : 10),
              ),
              if (tokens.darkGlass)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: elevation + 10,
                  offset: const Offset(0, 18),
                )
              else
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.58),
                  blurRadius: elevation,
                  offset: const Offset(0, -2),
                ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: tokens.darkGlass
                  ? (tokens.accentDarkGlass
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tokens.primary.withValues(alpha: 0.12),
                              tokens.accent.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.28, 1.0],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ))
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.56),
                        tokens.surfaceTint.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.20),
                      ],
                      stops: const [0.0, 0.62, 1.0],
                    ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

InputDecoration contractGlassFieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
}) {
  final tokens = AreaThemeScope.of(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(
      color: tokens.darkGlass
          ? tokens.accentDarkGlass
                ? tokens.border.withValues(alpha: 0.36)
                : Colors.white.withValues(alpha: 0.16)
          : tokens.border.withValues(alpha: 0.9),
    ),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: tokens.onGlass.withValues(alpha: 0.62)),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: tokens.fieldSurface,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: tokens.darkGlass ? tokens.primary : tokens.primaryStrong,
        width: 1.4,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
