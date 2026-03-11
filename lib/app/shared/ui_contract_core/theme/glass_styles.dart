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
            color: Colors.white.withValues(alpha: 0.70),
            borderRadius: borderRadius,
            border: Border.all(color: tokens.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: tokens.glow.withValues(alpha: 0.14),
                blurRadius: elevation,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
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
    borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.9)),
  );
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.72),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: tokens.primaryStrong, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
