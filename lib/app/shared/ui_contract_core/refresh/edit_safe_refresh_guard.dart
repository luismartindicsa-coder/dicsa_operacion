class EditSafeRefreshGuard {
  bool _editing = false;

  bool get isEditing => _editing;

  void beginEditing() {
    _editing = true;
  }

  void endEditing() {
    _editing = false;
  }
}
