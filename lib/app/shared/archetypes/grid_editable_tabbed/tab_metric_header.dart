import 'package:flutter/material.dart';

import '../../ui_contract_core/theme/glass_styles.dart';

class GridTabbedMetricHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const GridTabbedMetricHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF14373B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF35565D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14373B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D6C74),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
