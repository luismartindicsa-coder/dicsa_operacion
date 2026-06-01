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
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.glassSurface,
            borderRadius: borderRadius,
            border: Border.all(
              color: tokens.darkGlass
                  ? Colors.white.withValues(alpha: 0.18)
                  : tokens.border.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.glow.withValues(
                  alpha: tokens.darkGlass ? 0.12 : 0.14,
                ),
                blurRadius: tokens.darkGlass ? elevation + 8 : elevation,
                offset: Offset(0, tokens.darkGlass ? 14 : 10),
              ),
              if (tokens.darkGlass)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: elevation + 10,
                  offset: const Offset(0, 18),
                ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: tokens.darkGlass
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    )
                  : null,
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
          ? Colors.white.withValues(alpha: 0.16)
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
