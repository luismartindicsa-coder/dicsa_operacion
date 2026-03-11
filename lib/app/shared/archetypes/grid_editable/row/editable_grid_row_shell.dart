import 'package:flutter/material.dart';

class EditableGridRowShell extends StatelessWidget {
  final bool selected;
  final bool hovering;
  final bool active;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Widget child;

  const EditableGridRowShell({
    super.key,
    required this.selected,
    required this.hovering,
    this.active = false,
    this.onTap,
    this.onSecondaryTapDown,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF00A3FF).withValues(alpha: 0.14)
        : hovering
        ? const Color(0xFFE9F7EE)
        : Colors.white;
    final borderColor = active
        ? const Color(0xFF00A3FF).withValues(alpha: 0.55)
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Card(
        margin: EdgeInsets.zero,
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: active ? 1.2 : 0),
        ),
        child: child,
      ),
    );
  }
}
