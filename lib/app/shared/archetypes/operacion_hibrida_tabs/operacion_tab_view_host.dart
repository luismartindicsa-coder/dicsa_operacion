import 'package:flutter/material.dart';

class OperacionTabViewHost extends StatelessWidget {
  final String activeTabId;
  final Map<String, Widget> tabViews;
  final Widget? fallback;

  const OperacionTabViewHost({
    super.key,
    required this.activeTabId,
    required this.tabViews,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child:
          tabViews[activeTabId] ??
          fallback ??
          const SizedBox.shrink(key: ValueKey('operacion_empty')),
    );
  }
}
