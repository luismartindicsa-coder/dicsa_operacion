import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui_contract_core/focus/editable_focus_coordinator.dart';
import '../../../ui_contract_core/focus/focus_contract.dart';
import '../../../ui_contract_core/theme/glass_styles.dart';

class InlineEditableDateCell extends StatelessWidget {
  final bool editing;
  final bool enabled;
  final DateTime? value;
  final FocusNode focusNode;
  final String? hintText;
  final Future<DateTime?> Function(BuildContext context)? onOpenPicker;
  final ValueChanged<DateTime>? onChanged;
  final VoidCallback onEnterEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const InlineEditableDateCell({
    super.key,
    required this.editing,
    required this.enabled,
    required this.value,
    required this.focusNode,
    this.hintText,
    this.onOpenPicker,
    this.onChanged,
    required this.onEnterEditMode,
    required this.onCancel,
    required this.onSave,
  });

  String _displayText(BuildContext context) {
    final value = this.value;
    if (value == null) return '';
    return MaterialLocalizations.of(context).formatCompactDate(value);
  }

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
      onChanged?.call(DateUtils.dateOnly(picked));
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
            initialValue: _displayText(context),
            focusNode: focusNode,
            enabled: enabled,
            readOnly: true,
            decoration: contractGlassFieldDecoration(
              context,
              hintText: hintText ?? 'Selecciona fecha',
              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
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
      child: Text(_displayText(context)),
    );
  }
}
