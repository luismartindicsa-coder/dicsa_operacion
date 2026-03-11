import 'package:flutter/widgets.dart';

import 'editable_focus_coordinator.dart';
import 'focus_contract.dart';

bool isEditableTextFocused() {
  final primary = FocusManager.instance.primaryFocus;
  final context = primary?.context;
  if (context == null) return false;
  return isEditableTextContext(context);
}

bool isEditableTextContext(BuildContext context) {
  if (context.widget is EditableText) return true;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

void requestFocusNextFrame(BuildContext context, FocusNode focusNode) {
  EditableFocusCoordinator(focusNode: focusNode).activate(context);
}

void selectAllNextFrame(
  BuildContext context,
  FocusNode focusNode,
  TextEditingController controller,
) {
  EditableFocusCoordinator(
    focusNode: focusNode,
    controller: controller,
  ).activate(context, request: EditableFocusRequest.selectAll);
}

void placeCursorAtEndNextFrame(
  BuildContext context,
  FocusNode focusNode,
  TextEditingController controller,
) {
  EditableFocusCoordinator(
    focusNode: focusNode,
    controller: controller,
  ).activate(context, request: EditableFocusRequest.placeCursorAtEnd);
}
