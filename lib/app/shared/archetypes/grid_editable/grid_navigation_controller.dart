import 'package:flutter/foundation.dart';

enum GridNavigationZone { insertRow, grid }

@immutable
class GridCellPosition {
  final GridNavigationZone zone;
  final int rowIndex;
  final int columnIndex;

  const GridCellPosition({
    required this.zone,
    required this.rowIndex,
    required this.columnIndex,
  });
}

class GridNavigationController extends ChangeNotifier {
  int _insertColumnCount = 0;
  int _gridColumnCount = 0;
  int _rowCount = 0;
  GridCellPosition _active = const GridCellPosition(
    zone: GridNavigationZone.insertRow,
    rowIndex: -1,
    columnIndex: 0,
  );

  GridCellPosition get active => _active;

  void configure({
    required int insertColumnCount,
    required int gridColumnCount,
    required int rowCount,
  }) {
    _insertColumnCount = insertColumnCount;
    _gridColumnCount = gridColumnCount;
    _rowCount = rowCount;
    _active = GridCellPosition(
      zone: _active.zone,
      rowIndex: _active.zone == GridNavigationZone.grid && rowCount > 0
          ? _active.rowIndex.clamp(0, rowCount - 1)
          : -1,
      columnIndex: _clampColumn(
        _active.zone == GridNavigationZone.insertRow
            ? insertColumnCount
            : gridColumnCount,
        _active.columnIndex,
      ),
    );
    notifyListeners();
  }

  void focusInsertColumn(int columnIndex) {
    _active = GridCellPosition(
      zone: GridNavigationZone.insertRow,
      rowIndex: -1,
      columnIndex: _clampColumn(_insertColumnCount, columnIndex),
    );
    notifyListeners();
  }

  void focusGridCell({required int rowIndex, required int columnIndex}) {
    if (_rowCount <= 0) {
      focusInsertColumn(columnIndex);
      return;
    }
    _active = GridCellPosition(
      zone: GridNavigationZone.grid,
      rowIndex: rowIndex.clamp(0, _rowCount - 1),
      columnIndex: _clampColumn(_gridColumnCount, columnIndex),
    );
    notifyListeners();
  }

  void moveLeft() {
    if (_active.zone == GridNavigationZone.insertRow) {
      focusInsertColumn(_active.columnIndex - 1);
      return;
    }
    focusGridCell(
      rowIndex: _active.rowIndex,
      columnIndex: _active.columnIndex - 1,
    );
  }

  void moveRight() {
    if (_active.zone == GridNavigationZone.insertRow) {
      focusInsertColumn(_active.columnIndex + 1);
      return;
    }
    focusGridCell(
      rowIndex: _active.rowIndex,
      columnIndex: _active.columnIndex + 1,
    );
  }

  void moveDown() {
    if (_active.zone == GridNavigationZone.insertRow) {
      if (_rowCount <= 0) return;
      focusGridCell(rowIndex: 0, columnIndex: _active.columnIndex);
      return;
    }
    focusGridCell(
      rowIndex: (_active.rowIndex + 1).clamp(0, _rowCount - 1),
      columnIndex: _active.columnIndex,
    );
  }

  void moveUp() {
    if (_active.zone == GridNavigationZone.insertRow) return;
    if (_active.rowIndex <= 0) {
      focusInsertColumn(_active.columnIndex);
      return;
    }
    focusGridCell(
      rowIndex: _active.rowIndex - 1,
      columnIndex: _active.columnIndex,
    );
  }

  int _clampColumn(int count, int index) {
    if (count <= 0) return 0;
    return index.clamp(0, count - 1);
  }
}
