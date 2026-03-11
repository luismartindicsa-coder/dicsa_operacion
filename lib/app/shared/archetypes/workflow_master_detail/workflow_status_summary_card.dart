import 'package:flutter/material.dart';

import '../../ui_contract_core/theme/glass_styles.dart';

class WorkflowStatusSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? accentColor;

  const WorkflowStatusSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4D6C74),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accentColor ?? const Color(0xFF14373B),
            ),
          ),
        ],
      ),
    );
  }
}
