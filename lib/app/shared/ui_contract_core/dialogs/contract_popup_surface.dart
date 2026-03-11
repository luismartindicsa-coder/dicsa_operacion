import 'package:flutter/material.dart';

import '../theme/glass_styles.dart';

class ContractPopupSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;

  const ContractPopupSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.constraints = const BoxConstraints(
      minWidth: 220,
      maxWidth: 360,
      maxHeight: 420,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: constraints,
      child: ContractGlassCard(
        padding: padding,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: child,
      ),
    );
  }
}
