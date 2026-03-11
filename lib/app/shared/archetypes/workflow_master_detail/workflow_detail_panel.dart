import 'package:flutter/material.dart';

import '../../ui_contract_core/theme/glass_styles.dart';

class WorkflowDetailPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? headerActions;

  const WorkflowDetailPanel({
    super.key,
    required this.title,
    required this.child,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14373B),
                  ),
                ),
              ),
              ...?headerActions == null ? null : [headerActions!],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
