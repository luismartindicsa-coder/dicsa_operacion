import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui_contract_core/dialogs/contract_popup_surface.dart';
import '../../ui_contract_core/theme/area_theme_scope.dart';

Future<DateTime?> showContractDatePickerSurface(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Selecciona fecha',
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => _ContractDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    ),
  );
}

class _ContractDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const _ContractDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  @override
  State<_ContractDatePickerDialog> createState() =>
      _ContractDatePickerDialogState();
}

class _ContractDatePickerDialogState extends State<_ContractDatePickerDialog> {
  late DateTime _tempDate = DateUtils.dateOnly(widget.initialDate);

  WidgetStateProperty<Color?> _stateColor({
    Color? normal,
    Color? selected,
    Color? disabled,
    Color? hovered,
  }) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabled ?? normal;
      if (states.contains(WidgetState.selected)) return selected ?? normal;
      if (states.contains(WidgetState.hovered)) return hovered ?? normal;
      return normal;
    });
  }

  DateTime _clamp(DateTime value) {
    if (value.isBefore(widget.firstDate)) return widget.firstDate;
    if (value.isAfter(widget.lastDate)) return widget.lastDate;
    return value;
  }

  void _moveDays(int days) {
    setState(() {
      _tempDate = DateUtils.dateOnly(
        _clamp(_tempDate.add(Duration(days: days))),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          _moveDays(-1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          _moveDays(1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          _moveDays(-7);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          _moveDays(7);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          Navigator.of(context).pop(DateUtils.dateOnly(_tempDate));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ContractPopupSurface(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: tokens.primaryStrong,
                    onPrimary: Colors.white,
                    surface: const Color(0xFFFFFAF6),
                    onSurface: const Color(0xFF2D2A28),
                    secondary: tokens.primaryStrong,
                  ),
                  datePickerTheme: DatePickerThemeData(
                    backgroundColor: const Color(0xFFFFFAF6),
                    surfaceTintColor: Colors.transparent,
                    headerForegroundColor: tokens.primaryStrong,
                    dayForegroundColor: _stateColor(
                      normal: tokens.primaryStrong,
                      selected: Colors.white,
                      disabled: tokens.badgeText.withValues(alpha: 0.35),
                    ),
                    dayBackgroundColor: _stateColor(
                      selected: tokens.primaryStrong,
                      hovered: tokens.primarySoft.withValues(alpha: 0.42),
                    ),
                    todayForegroundColor: _stateColor(
                      normal: tokens.primaryStrong,
                      selected: Colors.white,
                    ),
                    todayBackgroundColor: _stateColor(
                      normal: Colors.transparent,
                      selected: tokens.primaryStrong,
                    ),
                    todayBorder: BorderSide(
                      color: tokens.primaryStrong.withValues(alpha: 0.72),
                    ),
                    yearForegroundColor: _stateColor(
                      normal: tokens.primaryStrong,
                      selected: Colors.white,
                    ),
                    yearBackgroundColor: _stateColor(
                      selected: tokens.primaryStrong,
                      hovered: tokens.primarySoft.withValues(alpha: 0.42),
                    ),
                    rangeSelectionBackgroundColor: tokens.primarySoft
                        .withValues(alpha: 0.28),
                    dividerColor: tokens.primarySoft.withValues(alpha: 0.20),
                    cancelButtonStyle: OutlinedButton.styleFrom(
                      foregroundColor: tokens.primaryStrong,
                      backgroundColor: Colors.white.withValues(alpha: 0.55),
                      side: BorderSide(
                        color: tokens.primarySoft.withValues(alpha: 0.9),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    confirmButtonStyle: FilledButton.styleFrom(
                      backgroundColor: tokens.primaryStrong,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.primaryStrong,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 320,
                  child: CalendarDatePicker(
                    key: ValueKey<DateTime>(_tempDate),
                    initialDate: _tempDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    onDateChanged: (value) {
                      setState(() {
                        _tempDate = DateUtils.dateOnly(value);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.primaryStrong,
                      backgroundColor: Colors.white.withValues(alpha: 0.55),
                      side: BorderSide(
                        color: tokens.primarySoft.withValues(alpha: 0.9),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.primaryStrong,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(DateUtils.dateOnly(_tempDate)),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
