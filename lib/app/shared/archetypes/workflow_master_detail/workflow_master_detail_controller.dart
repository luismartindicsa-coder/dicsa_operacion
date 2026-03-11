import 'package:flutter/foundation.dart';

class WorkflowMasterDetailController extends ChangeNotifier {
  String? _selectedId;

  String? get selectedId => _selectedId;

  void select(String id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void clear() {
    if (_selectedId == null) return;
    _selectedId = null;
    notifyListeners();
  }
}
