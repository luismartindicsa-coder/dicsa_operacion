import 'package:flutter/material.dart';

import '../../ui_contract_core/theme/glass_styles.dart';

class OperacionTabWorkspacePanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const OperacionTabWorkspacePanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
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
              ...?trailing == null ? null : [trailing!],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
