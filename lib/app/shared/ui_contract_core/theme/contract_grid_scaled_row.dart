import 'package:flutter/material.dart';

class ContractGridScaledRow extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;
  final BoxFit fit;

  const ContractGridScaledRow({
    super.key,
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.fit = BoxFit.scaleDown,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(fit: fit, alignment: alignment, child: child),
        );
      },
    );
  }
}
