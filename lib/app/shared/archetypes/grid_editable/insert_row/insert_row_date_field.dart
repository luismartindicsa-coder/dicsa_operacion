import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui_contract_core/focus/editable_focus_coordinator.dart';
import '../../../ui_contract_core/focus/focus_contract.dart';
import '../../../ui_contract_core/theme/glass_styles.dart';

class InsertRowDateField extends StatelessWidget {
  final DateTime? value;
  final FocusNode focusNode;
  final String? hintText;
  final Future<DateTime?> Function(BuildContext context)? onOpenPicker;
  final ValueChanged<DateTime>? onChanged;
  final bool enabled;
  final VoidCallback? onActivated;

  const InsertRowDateField({
    super.key,
    required this.value,
    required this.focusNode,
    this.hintText,
    this.onOpenPicker,
    this.onChanged,
    this.enabled = true,
    this.onActivated,
  });

  String _displayText(BuildContext context) {
    final value = this.value;
    if (value == null) return '';
    return MaterialLocalizations.of(context).formatCompactDate(value);
  }

  Future<void> _activate(BuildContext context) async {
    final coordinator = EditableFocusCoordinator(focusNode: focusNode);
    onActivated?.call();
    coordinator.activate(
      context,
      request: EditableFocusRequest.placeCursorAtEnd,
    );
    if (!enabled || onOpenPicker == null) return;
    final picked = await onOpenPicker!(context);
    if (picked != null) {
      onChanged?.call(DateUtils.dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        unawaited(_activate(context));
      },
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
}
