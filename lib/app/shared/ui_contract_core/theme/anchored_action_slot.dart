import 'package:flutter/material.dart';

class AnchoredActionSlot extends StatelessWidget {
  final double width;
  final double trailingWidth;
  final double gap;
  final Widget leading;
  final Widget? trailing;
  final AlignmentGeometry alignment;

  const AnchoredActionSlot({
    super.key,
    required this.width,
    required this.trailingWidth,
    required this.leading,
    this.trailing,
    this.gap = 0,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTrailingWidth = trailing == null ? 0.0 : trailingWidth;
    final effectiveGap = trailing == null ? 0.0 : gap;
    final leadingWidth = (width - effectiveTrailingWidth - effectiveGap).clamp(
      0.0,
      width,
    );

    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: leadingWidth,
            child: Align(alignment: alignment, child: leading),
          ),
          if (trailing != null && effectiveGap > 0)
            SizedBox(width: effectiveGap),
          if (trailing != null)
            SizedBox(width: effectiveTrailingWidth, child: trailing),
        ],
      ),
    );
  }
}
