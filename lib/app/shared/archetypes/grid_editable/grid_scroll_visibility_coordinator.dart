import 'package:flutter/material.dart';

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
  }) async {
    final id = _cellId(
      zone: position.zone,
      rowIndex: position.rowIndex,
      columnIndex: position.columnIndex,
    );
    final context = _keys[id]?.currentContext;
    if (context == null) return;
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
