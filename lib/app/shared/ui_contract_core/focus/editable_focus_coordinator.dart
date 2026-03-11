import 'package:flutter/widgets.dart';

import 'focus_contract.dart';

class EditableFocusCoordinator {
  final FocusNode focusNode;
  final TextEditingController? controller;

  const EditableFocusCoordinator({required this.focusNode, this.controller});

  bool get hasFocus => focusNode.hasFocus;

  void activate(
    BuildContext context, {
    EditableFocusRequest request = EditableFocusRequest.focusOnly,
    VoidCallback? onActivated,
  }) {
    onActivated?.call();
    _schedule(context, request);
  }

  void cancelPointerSteal(
    BuildContext context, {
    EditableFocusRequest request = EditableFocusRequest.focusOnly,
  }) {
    _schedule(context, request);
  }

  void handleTapOutside({VoidCallback? onTapOutside}) {
    onTapOutside?.call();
  }

  void _schedule(BuildContext context, EditableFocusRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (request.requestFocus && !focusNode.hasFocus) {
        FocusScope.of(context).requestFocus(focusNode);
      }

      final textController = controller;
      if (textController == null) return;

      switch (request.selectionMode) {
        case EditableFocusSelectionMode.preserve:
          break;
        case EditableFocusSelectionMode.selectAll:
          textController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: textController.text.length,
          );
          break;
        case EditableFocusSelectionMode.collapseToEnd:
          final length = textController.text.length;
          textController.selection = TextSelection.collapsed(offset: length);
          break;
      }
    });
  }
}
