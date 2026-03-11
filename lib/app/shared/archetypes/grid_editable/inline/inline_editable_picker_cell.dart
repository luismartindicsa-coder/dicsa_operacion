import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui_contract_core/focus/editable_focus_coordinator.dart';
import '../../../ui_contract_core/focus/focus_contract.dart';
import '../../../ui_contract_core/theme/glass_styles.dart';

class InlineEditablePickerCell<T> extends StatelessWidget {
  final bool editing;
  final bool enabled;
  final String? label;
  final FocusNode focusNode;
  final String? hintText;
  final Future<T?> Function(BuildContext context)? onOpenPicker;
  final ValueChanged<T>? onChanged;
  final VoidCallback onEnterEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final Widget? prefixIcon;

  const InlineEditablePickerCell({
    super.key,
    required this.editing,
    required this.enabled,
    required this.label,
    required this.focusNode,
    this.hintText,
    this.onOpenPicker,
    this.onChanged,
    required this.onEnterEditMode,
    required this.onCancel,
    required this.onSave,
    this.prefixIcon,
  });

  Future<void> _activate(BuildContext context) async {
    final coordinator = EditableFocusCoordinator(focusNode: focusNode);
    onEnterEditMode();
    coordinator.activate(
      context,
      request: EditableFocusRequest.placeCursorAtEnd,
    );
    if (!enabled || onOpenPicker == null) return;
    final picked = await onOpenPicker!(context);
    if (picked != null) {
      onChanged?.call(picked);
      onSave();
    } else {
      onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return TapRegion(
        onTapOutside: (_) => onCancel(),
        child: AbsorbPointer(
          child: TextFormField(
            initialValue: label ?? '',
            focusNode: focusNode,
            enabled: enabled,
            readOnly: true,
            decoration: contractGlassFieldDecoration(
              context,
              hintText: hintText ?? 'Selecciona opción',
              prefixIcon:
                  prefixIcon ??
                  const Icon(Icons.arrow_drop_down_rounded, size: 22),
            ),
          ),
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!enabled) return;
        unawaited(_activate(context));
      },
      child: Text(label ?? ''),
    );
  }
}
