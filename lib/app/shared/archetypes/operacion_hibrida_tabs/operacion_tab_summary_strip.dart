import 'package:flutter/material.dart';

import '../../ui_contract_core/theme/glass_styles.dart';

class OperacionTabSummaryStrip extends StatelessWidget {
  final List<Widget> children;

  const OperacionTabSummaryStrip({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Wrap(spacing: 12, runSpacing: 12, children: children),
    );
  }
}
