import 'package:flutter/widgets.dart';

@immutable
class MarqueeRowHit {
  final String id;
  final int rowIndex;
  final Rect rect;

  const MarqueeRowHit({
    required this.id,
    required this.rowIndex,
    required this.rect,
  });
}

List<MarqueeRowHit> resolveRowsInsideRect({
  required Rect selectionRect,
  required Iterable<MarqueeRowHit> rows,
}) {
  return rows.where((row) => row.rect.overlaps(selectionRect)).toList()
    ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
}
