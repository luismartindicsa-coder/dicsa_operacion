import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'insert_row_text_field.dart';

class InsertRowNumberField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool allowDecimal;
  final bool selectAllOnFirstFocus;
  final VoidCallback? onActivated;

  const InsertRowNumberField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.allowDecimal = true,
    this.selectAllOnFirstFocus = true,
    this.onActivated,
  });

  @override
  Widget build(BuildContext context) {
    return InsertRowTextField(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      selectAllOnFirstFocus: selectAllOnFirstFocus,
      onActivated: onActivated,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
    );
  }
}
