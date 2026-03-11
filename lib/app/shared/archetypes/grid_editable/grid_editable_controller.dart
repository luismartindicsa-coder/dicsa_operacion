import 'package:flutter/foundation.dart';

class GridEditableController extends ChangeNotifier {
  int activeInsertColumn = 0;
  int activeGridColumn = 0;
  int activeRowIndex = 0;
  bool editing = false;

  void activateInsertColumn(int index) {
    activeInsertColumn = index;
    editing = false;
    notifyListeners();
  }

  void activateGridCell({required int rowIndex, required int columnIndex}) {
    activeRowIndex = rowIndex;
    activeGridColumn = columnIndex;
    editing = false;
    notifyListeners();
  }

  void beginEditing() {
    editing = true;
    notifyListeners();
  }

  void endEditing() {
    editing = false;
    notifyListeners();
  }

  void resetGridFocus() {
    activeInsertColumn = 0;
    activeGridColumn = 0;
    activeRowIndex = 0;
    editing = false;
    notifyListeners();
  }
}
