import 'package:flutter/material.dart';

const Color kOperationalActionPanelBg = Color(0x55FFFFFF);
const Color kOperationalActionPanelBorder = Color(0xA6FFFFFF);
const Color kOperationalMetricAccent = Color(0xFF4F8E8C);
const Color kOperationalMetricText = Color(0xFF0B2B2B);
const Color kOperationalMetricMuted = Color(0xFF2A4B49);

class OperationalGlassToolbarPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const OperationalGlassToolbarPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.64)),
      ),
      child: child,
    );
  }
}

class OperationalMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  const OperationalMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.width = 310,
    this.height = 64,
    this.margin = const EdgeInsets.only(right: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFBFD8D3).withOpacity(0.52),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.74)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kOperationalMetricAccent.withOpacity(0.20),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: kOperationalMetricAccent.withOpacity(0.34),
                ),
              ),
              child: Icon(icon, size: 18, color: kOperationalMetricText),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: kOperationalMetricMuted,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kOperationalMetricText,
                      height: 1.0,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kOperationalMetricMuted,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OperationalFolderTabItem {
  final String label;
  final IconData icon;

  const OperationalFolderTabItem({required this.label, required this.icon});
}

class OperationalFolderTabs extends StatelessWidget {
  final List<OperationalFolderTabItem> items;
  final TabController controller;
  final double maxWidth;

  const OperationalFolderTabs({
    super.key,
    required this.items,
    required this.controller,
    this.maxWidth = 310,
  }) : assert(items.length > 0);

  @override
  Widget build(BuildContext context) {
    Widget tabItem(int index, OperationalFolderTabItem item) {
      final selected = controller.index == index;
      final railFill = Colors.white.withOpacity(0.22);
      final activeFill = const Color(0x55FFFFFF);

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.animateTo(index),
            child: SizedBox(
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(top: selected ? 0 : 12, bottom: 2),
                    decoration: BoxDecoration(
                      color: selected ? activeFill : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        topRight: Radius.circular(13),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withOpacity(0.44)
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              color: kOperationalMetricText,
                              size: 20,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: kOperationalMetricText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: -1,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: railFill,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (_, __) {
        final railFill = Colors.white.withOpacity(0.22);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 7,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: railFill,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++) tabItem(i, items[i]),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OperationalSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final String? activeCellLabel;
  final bool compactOnSmallScreens;

  const OperationalSelectionInfo({
    super.key,
    required this.selectedCount,
    this.activeCellLabel,
    this.compactOnSmallScreens = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$selectedCount seleccionadas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.right,
            ),
            if (activeCellLabel != null)
              Text(
                'Celda: $activeCellLabel · Space',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kOperationalMetricMuted,
                ),
                textAlign: TextAlign.right,
              ),
          ],
        );

        if (compactOnSmallScreens && constraints.maxWidth < 240) {
          return Align(alignment: Alignment.centerRight, child: content);
        }
        return content;
      },
    );
  }
}

class OperationalTopBarLayout extends StatelessWidget {
  final Widget? actions;
  final Widget? rightInfo;
  final Widget? metric;
  final bool metricBelowActions;
  final double spacing;

  const OperationalTopBarLayout({
    super.key,
    this.actions,
    this.rightInfo,
    this.metric,
    this.metricBelowActions = true,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    final actionRow = (actions == null && rightInfo == null)
        ? null
        : OperationalGlassToolbarPanel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (actions == null) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: rightInfo ?? const SizedBox.shrink(),
                  );
                }
                if (rightInfo == null) {
                  return actions!;
                }
                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actions!,
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: rightInfo!,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: actions!),
                    const SizedBox(width: 10),
                    rightInfo!,
                  ],
                );
              },
            ),
          );

    final children = <Widget>[];
    if (metricBelowActions) {
      if (actionRow != null) children.add(actionRow);
      if (actionRow != null && metric != null)
        children.add(SizedBox(height: spacing));
      if (metric != null) children.add(metric!);
    } else {
      if (metric != null) children.add(metric!);
      if (metric != null && actionRow != null)
        children.add(SizedBox(height: spacing));
      if (actionRow != null) children.add(actionRow);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
