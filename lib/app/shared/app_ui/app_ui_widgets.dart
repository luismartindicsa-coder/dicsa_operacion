import 'package:flutter/material.dart';

const Color kAppActionPanelBg = Color(0x55FFFFFF);
const Color kAppActionPanelBorder = Color(0xA6FFFFFF);
const Color kAppMetricAccent = Color(0xFF4F8E8C);
const Color kAppMetricText = Color(0xFF0B2B2B);
const Color kAppMetricMuted = Color(0xFF2A4B49);

const Color kOperationalActionPanelBg = kAppActionPanelBg;
const Color kOperationalActionPanelBorder = kAppActionPanelBorder;
const Color kOperationalMetricAccent = kAppMetricAccent;
const Color kOperationalMetricText = kAppMetricText;
const Color kOperationalMetricMuted = kAppMetricMuted;

class AppGlassToolbarPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppGlassToolbarPanel({
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
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.64)),
      ),
      child: child,
    );
  }
}

class AppMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  const AppMetricCard({
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
          color: const Color(0xFFBFD8D3).withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kAppMetricAccent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: kAppMetricAccent.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(icon, size: 18, color: kAppMetricText),
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
                      color: kAppMetricMuted,
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
                      color: kAppMetricText,
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
                        color: kAppMetricMuted,
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

class AppFolderTabItem {
  final String label;
  final IconData icon;

  const AppFolderTabItem({required this.label, required this.icon});
}

class AppFolderTabs extends StatelessWidget {
  final List<AppFolderTabItem> items;
  final TabController controller;
  final double maxWidth;
  final bool showBottomRail;
  final bool showSelectedRail;

  const AppFolderTabs({
    super.key,
    required this.items,
    required this.controller,
    this.maxWidth = 310,
    this.showBottomRail = true,
    this.showSelectedRail = true,
  }) : assert(items.length > 0);

  @override
  Widget build(BuildContext context) {
    Widget tabItem(int index, AppFolderTabItem item) {
      final selected = controller.index == index;
      final railFill = Colors.white.withValues(alpha: 0.22);
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
                            ? Colors.white.withValues(alpha: 0.44)
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
                            Icon(item.icon, color: kAppMetricText, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: kAppMetricText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (selected && showSelectedRail)
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
      builder: (context, child) {
        final railFill = Colors.white.withValues(alpha: 0.22);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                if (showBottomRail)
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

class AppSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final String? activeCellLabel;

  const AppSelectionInfo({
    super.key,
    required this.selectedCount,
    this.activeCellLabel,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      selectedCount == 1 ? '1 seleccionado' : '$selectedCount seleccionados',
      if (activeCellLabel != null && activeCellLabel!.trim().isNotEmpty)
        activeCellLabel!.trim(),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        parts.join(' • '),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kAppMetricMuted,
          height: 1.0,
        ),
      ),
    );
  }
}

typedef OperationalGlassToolbarPanel = AppGlassToolbarPanel;
typedef OperationalMetricCard = AppMetricCard;
typedef OperationalFolderTabItem = AppFolderTabItem;
typedef OperationalFolderTabs = AppFolderTabs;
typedef OperationalSelectionInfo = AppSelectionInfo;
