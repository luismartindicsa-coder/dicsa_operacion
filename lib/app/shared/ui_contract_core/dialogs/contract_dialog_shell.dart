import 'package:flutter/material.dart';

import '../theme/glass_styles.dart';

class ContractDialogShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets insetPadding;

  const ContractDialogShell({
    super.key,
    required this.child,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 24,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: ContractGlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        blurSigma: 14,
        padding: EdgeInsets.zero,
        child: child,
      ),
    );
  }
}
