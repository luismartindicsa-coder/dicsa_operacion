import 'package:flutter/widgets.dart';

enum EditableFocusSelectionMode { preserve, selectAll, collapseToEnd }

@immutable
class EditableFocusRequest {
  final EditableFocusSelectionMode selectionMode;
  final bool requestFocus;

  const EditableFocusRequest({
    this.selectionMode = EditableFocusSelectionMode.preserve,
    this.requestFocus = true,
  });

  static const EditableFocusRequest focusOnly = EditableFocusRequest();
  static const EditableFocusRequest selectAll = EditableFocusRequest(
    selectionMode: EditableFocusSelectionMode.selectAll,
  );
  static const EditableFocusRequest placeCursorAtEnd = EditableFocusRequest(
    selectionMode: EditableFocusSelectionMode.collapseToEnd,
  );
}
