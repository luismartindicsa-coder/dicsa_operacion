import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inline_editable_text_cell.dart';

class InlineEditableNumberCell extends StatelessWidget {
  final bool editing;
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String displayText;
  final VoidCallback onEnterEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool allowDecimal;

  const InlineEditableNumberCell({
    super.key,
    required this.editing,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.displayText,
    required this.onEnterEditMode,
    required this.onCancel,
    required this.onSave,
    this.allowDecimal = true,
  });

  @override
  Widget build(BuildContext context) {
    return InlineEditableTextCell(
      editing: editing,
      enabled: enabled,
      controller: controller,
      focusNode: focusNode,
      displayText: displayText,
      onEnterEditMode: onEnterEditMode,
      onCancel: onCancel,
      onSave: onSave,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
    );
  }
}
