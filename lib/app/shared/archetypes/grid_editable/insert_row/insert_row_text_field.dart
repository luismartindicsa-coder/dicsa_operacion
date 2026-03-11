import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui_contract_core/focus/editable_focus_coordinator.dart';
import '../../../ui_contract_core/focus/focus_contract.dart';

class InsertRowTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool selectAllOnFirstFocus;
  final VoidCallback? onActivated;

  const InsertRowTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
    this.selectAllOnFirstFocus = true,
    this.onActivated,
  });

  void _activate(BuildContext context) {
    final coordinator = EditableFocusCoordinator(
      focusNode: focusNode,
      controller: controller,
    );
    onActivated?.call();
    coordinator.activate(
      context,
      request: selectAllOnFirstFocus
          ? EditableFocusRequest.selectAll
          : EditableFocusRequest.placeCursorAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _activate(context),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onTap: () => _activate(context),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(hintText: hintText),
      ),
    );
  }
}
