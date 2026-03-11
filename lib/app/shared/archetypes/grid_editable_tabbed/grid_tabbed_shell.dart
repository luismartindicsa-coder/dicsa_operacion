import 'package:flutter/material.dart';

class GridTabbedShell extends StatelessWidget {
  final Widget tabs;
  final Widget? topBar;
  final Widget? actionsBar;
  final Widget? metrics;
  final Widget body;

  const GridTabbedShell({
    super.key,
    required this.tabs,
    this.topBar,
    this.actionsBar,
    this.metrics,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topBar != null) ...[topBar!, const SizedBox(height: 8)],
        tabs,
        const SizedBox(height: 8),
        if (actionsBar != null) ...[actionsBar!, const SizedBox(height: 8)],
        if (metrics != null) ...[metrics!, const SizedBox(height: 8)],
        Expanded(child: body),
      ],
    );
  }
}
