import 'package:flutter/material.dart';

class GridEditableShell extends StatelessWidget {
  final Widget? topBar;
  final Widget? insertRow;
  final Widget body;
  final Widget? footer;

  const GridEditableShell({
    super.key,
    this.topBar,
    this.insertRow,
    required this.body,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...?topBar == null ? null : [topBar!, const SizedBox(height: 8)],
        ...?insertRow == null ? null : [insertRow!, const SizedBox(height: 8)],
        Expanded(child: body),
        ...?footer == null ? null : [const SizedBox(height: 8), footer!],
      ],
    );
  }
}
