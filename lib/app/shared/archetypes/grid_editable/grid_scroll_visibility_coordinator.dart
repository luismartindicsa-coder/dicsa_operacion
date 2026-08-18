import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'grid_navigation_controller.dart';

class GridScrollVisibilityCoordinator {
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  GlobalKey keyForCell({
    required GridNavigationZone zone,
    required int rowIndex,
    required int columnIndex,
  }) {
    final id = _cellId(
      zone: zone,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
    );
    return _keys.putIfAbsent(id, GlobalKey.new);
  }

  Future<void> ensureVisible(
    GridCellPosition position, {
    Duration duration = const Duration(milliseconds: 90),
    Curve curve = Curves.easeOutCubic,
    double alignment = 0.45,
    bool allowSkipIfFullyVisible = true,
  }) async {
    final id = _cellId(
      zone: position.zone,
      rowIndex: position.rowIndex,
      columnIndex: position.columnIndex,
    );
    final context = _keys[id]?.currentContext;
    if (context == null) return;
    final renderObject = context.findRenderObject();
    final scrollableState = Scrollable.maybeOf(context);
    if (allowSkipIfFullyVisible &&
        renderObject is RenderObject &&
        scrollableState != null) {
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      final position = scrollableState.position;
      if (viewport != null &&
          position.hasPixels &&
          position.hasViewportDimension) {
        final leading = viewport.getOffsetToReveal(renderObject, 0.0).offset;
        final trailing = viewport.getOffsetToReveal(renderObject, 1.0).offset;
        final visibleStart = position.pixels;
        final visibleEnd = position.pixels + position.viewportDimension;
        final fullyVisible =
            leading >= visibleStart - 0.5 && trailing <= visibleEnd + 0.5;
        if (fullyVisible) return;
      }
    }
    await Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: curve,
      alignment: alignment,
    );
  }

  Future<void> ensureGridRowVisible(
    int rowIndex, {
    int columnIndex = 0,
    Duration duration = const Duration(milliseconds: 90),
    Curve curve = Curves.easeOutCubic,
    double alignment = 0.45,
    bool allowSkipIfFullyVisible = true,
  }) {
    return ensureVisible(
      GridCellPosition(
        zone: GridNavigationZone.grid,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      ),
      duration: duration,
      curve: curve,
      alignment: alignment,
      allowSkipIfFullyVisible: allowSkipIfFullyVisible,
    );
  }

  String _cellId({
    required GridNavigationZone zone,
    required int rowIndex,
    required int columnIndex,
  }) {
    return '${zone.name}:$rowIndex:$columnIndex';
  }
}
