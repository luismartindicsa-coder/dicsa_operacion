import 'package:flutter/services.dart';

bool isDeleteKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.delete ||
      key == LogicalKeyboardKey.backspace;
}

bool isEnterKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter;
}

bool isEscapeKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.escape;
}

bool isOpenCellKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.space;
}

bool isHorizontalNavigationKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight;
}

bool isVerticalNavigationKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown;
}

bool isSelectionModifierPressed() {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight);
}

bool isRangeModifierPressed() {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.shiftLeft) ||
      keys.contains(LogicalKeyboardKey.shiftRight);
}
