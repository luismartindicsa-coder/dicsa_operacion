import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'grid_keyboard_contract.dart';

typedef KeyAction = KeyEventResult Function();

KeyEventResult guardEditableInputKeys({
  required bool editableTextFocused,
  required KeyEvent event,
  KeyAction? onEscape,
  KeyAction? onEnter,
  KeyAction? onDeleteOutsideInput,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  final key = event.logicalKey;

  if (editableTextFocused) {
    if (isDeleteKey(key) || isEnterKey(key) || isEscapeKey(key)) {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  if (isEscapeKey(key) && onEscape != null) {
    return onEscape();
  }
  if (isEnterKey(key) && onEnter != null) {
    return onEnter();
  }
  if (isDeleteKey(key) && onDeleteOutsideInput != null) {
    return onDeleteOutsideInput();
  }
  return KeyEventResult.ignored;
}
