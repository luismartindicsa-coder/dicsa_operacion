import 'package:flutter/material.dart';

class WorkflowMasterDetailShell extends StatelessWidget {
  final Widget? topBar;
  final Widget? summary;
  final Widget master;
  final Widget detail;
  final double masterFlex;
  final double detailFlex;

  const WorkflowMasterDetailShell({
    super.key,
    this.topBar,
    this.summary,
    required this.master,
    required this.detail,
    this.masterFlex = 1,
    this.detailFlex = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topBar != null) ...[topBar!, const SizedBox(height: 8)],
        if (summary != null) ...[summary!, const SizedBox(height: 8)],
        Expanded(
          child: Row(
            children: [
              Expanded(flex: masterFlex.round(), child: master),
              const SizedBox(width: 12),
              Expanded(flex: detailFlex.round(), child: detail),
            ],
          ),
        ),
      ],
    );
  }
}
