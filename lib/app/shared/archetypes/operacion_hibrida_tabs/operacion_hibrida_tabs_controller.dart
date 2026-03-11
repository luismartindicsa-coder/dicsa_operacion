import 'package:flutter/foundation.dart';

class OperacionHibridaTabsController extends ChangeNotifier {
  String _activeTabId;
  final Map<String, Object?> _tabContext = <String, Object?>{};

  OperacionHibridaTabsController({required String initialTabId})
    : _activeTabId = initialTabId;

  String get activeTabId => _activeTabId;
  Object? contextFor(String tabId) => _tabContext[tabId];

  void activateTab(String tabId) {
    if (_activeTabId == tabId) return;
    _activeTabId = tabId;
    notifyListeners();
  }

  void setTabContext(String tabId, Object? value) {
    _tabContext[tabId] = value;
    notifyListeners();
  }
}
