import 'package:flutter/material.dart';

class OperacionHibridaTabsShell extends StatelessWidget {
  final Widget? topBar;
  final Widget? summary;
  final Widget? actionsBar;
  final Widget tabs;
  final Widget body;

  const OperacionHibridaTabsShell({
    super.key,
    this.topBar,
    this.summary,
    this.actionsBar,
    required this.tabs,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topBar != null) ...[topBar!, const SizedBox(height: 8)],
        if (summary != null) ...[summary!, const SizedBox(height: 8)],
        if (actionsBar != null) ...[actionsBar!, const SizedBox(height: 8)],
        tabs,
        const SizedBox(height: 8),
        Expanded(child: body),
      ],
    );
  }
}
