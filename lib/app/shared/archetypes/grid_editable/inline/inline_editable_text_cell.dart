import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui_contract_core/focus/editable_focus_coordinator.dart';
import '../../../ui_contract_core/focus/focus_contract.dart';

class InlineEditableTextCell extends StatelessWidget {
  final bool editing;
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String displayText;
  final VoidCallback onEnterEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const InlineEditableTextCell({
    super.key,
    required this.editing,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.displayText,
    required this.onEnterEditMode,
    required this.onCancel,
    required this.onSave,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final coordinator = EditableFocusCoordinator(
      focusNode: focusNode,
      controller: controller,
    );

    if (editing) {
      return TapRegion(
        onTapOutside: (_) =>
            coordinator.handleTapOutside(onTapOutside: onCancel),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onTap: () => coordinator.cancelPointerSteal(
            context,
            request: EditableFocusRequest.placeCursorAtEnd,
          ),
          onSubmitted: (_) => onSave(),
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!enabled) return;
        onEnterEditMode();
        coordinator.activate(
          context,
          request: EditableFocusRequest.placeCursorAtEnd,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                onEnterEditMode();
                coordinator.activate(
                  context,
                  request: EditableFocusRequest.placeCursorAtEnd,
                );
              }
            : null,
        child: Text(displayText),
      ),
    );
  }
}
