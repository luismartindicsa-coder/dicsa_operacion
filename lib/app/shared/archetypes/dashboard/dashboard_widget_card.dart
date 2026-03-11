import 'package:flutter/material.dart';

import '../../ui_contract_core/theme/glass_styles.dart';

class DashboardWidgetCard extends StatefulWidget {
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  const DashboardWidgetCard({
    super.key,
    required this.title,
    required this.child,
    this.onTap,
  });

  @override
  State<DashboardWidgetCard> createState() => _DashboardWidgetCardState();
}

class _DashboardWidgetCardState extends State<DashboardWidgetCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _hovered ? -4.0 : 0.0, 0.0, 1.0),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ContractGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14373B),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
