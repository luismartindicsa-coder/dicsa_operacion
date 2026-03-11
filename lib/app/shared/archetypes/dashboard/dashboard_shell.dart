import 'package:flutter/material.dart';

class DashboardShell extends StatelessWidget {
  final Widget? topBar;
  final Widget? summaryBar;
  final List<Widget> widgets;
  final double spacing;
  final int columns;
  final double minTileWidth;

  const DashboardShell({
    super.key,
    this.topBar,
    this.summaryBar,
    required this.widgets,
    this.spacing = 12,
    this.columns = 2,
    this.minTileWidth = 280,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final computedColumns = columns > 0
            ? (constraints.maxWidth / minTileWidth).floor().clamp(1, columns)
            : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topBar != null) ...[topBar!, const SizedBox(height: 12)],
            if (summaryBar != null) ...[
              summaryBar!,
              const SizedBox(height: 12),
            ],
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: computedColumns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1.6,
                ),
                itemCount: widgets.length,
                itemBuilder: (_, index) => widgets[index],
              ),
            ),
          ],
        );
      },
    );
  }
}
