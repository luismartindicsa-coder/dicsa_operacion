import 'package:flutter/material.dart';

import '../../ui_contract_core/theme/glass_styles.dart';

class WorkflowItemActionsBar extends StatelessWidget {
  final List<Widget> actions;

  const WorkflowItemActionsBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Wrap(spacing: 10, runSpacing: 10, children: actions),
    );
  }
}
