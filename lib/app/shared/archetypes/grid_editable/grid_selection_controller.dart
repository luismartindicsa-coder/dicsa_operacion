import 'package:flutter/foundation.dart';

import '../../ui_contract_core/keyboard/grid_keyboard_contract.dart';
import 'grid_scroll_visibility_coordinator.dart';

class GridSelectionController extends ChangeNotifier {
  final Set<String> selectedIds = <String>{};
  int? anchorIndex;

  void selectSingle(String id, {int? rowIndex}) {
    selectedIds
      ..clear()
      ..add(id);
    anchorIndex = rowIndex;
    notifyListeners();
  }

  void toggle(String id, {int? rowIndex}) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
      anchorIndex = rowIndex;
    }
    notifyListeners();
  }

  void selectRange(Iterable<String> ids, {required int anchorRowIndex}) {
    selectedIds
      ..clear()
      ..addAll(ids);
    anchorIndex = anchorRowIndex;
    notifyListeners();
  }

  bool isSelected(String id) => selectedIds.contains(id);

  void handlePointerSelection({
    required String id,
    required int rowIndex,
    required Iterable<String> Function(int start, int end) resolveRangeIds,
    GridScrollVisibilityCoordinator? visibilityCoordinator,
  }) {
    if (isRangeModifierPressed() && anchorIndex != null) {
      final start = anchorIndex! < rowIndex ? anchorIndex! : rowIndex;
      final end = anchorIndex! > rowIndex ? anchorIndex! : rowIndex;
      selectRange(resolveRangeIds(start, end), anchorRowIndex: anchorIndex!);
      visibilityCoordinator?.ensureGridRowVisible(rowIndex);
      return;
    }

    if (isSelectionModifierPressed()) {
      toggle(id, rowIndex: rowIndex);
      visibilityCoordinator?.ensureGridRowVisible(rowIndex);
      return;
    }

    selectSingle(id, rowIndex: rowIndex);
    visibilityCoordinator?.ensureGridRowVisible(rowIndex);
  }

  void clear() {
    selectedIds.clear();
    anchorIndex = null;
    notifyListeners();
  }
}
