import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui_contract_core/dialogs/contract_popup_surface.dart';
import '../../ui_contract_core/theme/area_theme_scope.dart';
import '../../ui_contract_core/theme/contract_tokens.dart';

Future<DateTime?> showContractDatePickerSurface(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Selecciona fecha',
  ContractAreaTokens? tokens,
}) {
  final resolvedTokens = tokens ?? AreaThemeScope.of(context);
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => AreaThemeScope(
      tokens: resolvedTokens,
      child: Theme(
        data: _datePickerTheme(context, resolvedTokens),
        child: _ContractDatePickerDialog(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          title: title,
        ),
      ),
    ),
  );
}

Future<DateTimeRange?> showContractDateRangePickerSurface(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  String title = 'Selecciona el rango de fechas',
  ContractAreaTokens? tokens,
}) {
  final resolvedTokens = tokens ?? AreaThemeScope.of(context);
  return showDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => AreaThemeScope(
      tokens: resolvedTokens,
      child: Theme(
        data: _datePickerTheme(context, resolvedTokens),
        child: _ContractDateRangePickerDialog(
          firstDate: firstDate,
          lastDate: lastDate,
          initialDateRange: initialDateRange,
          title: title,
        ),
      ),
    ),
  );
}

ThemeData _datePickerTheme(BuildContext context, ContractAreaTokens tokens) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: tokens.primary,
      onPrimary: tokens.onGlass,
      secondary: tokens.accent,
      onSecondary: tokens.onGlass,
      surface: tokens.fieldSurface,
      onSurface: tokens.onGlass,
      outline: tokens.border,
    ),
    scaffoldBackgroundColor: tokens.fieldSurface,
    canvasColor: tokens.fieldSurface,
    dialogTheme: const DialogThemeData(backgroundColor: Colors.transparent),
    iconTheme: IconThemeData(color: tokens.onGlass),
    textTheme: base.textTheme.apply(
      bodyColor: tokens.onGlass,
      displayColor: tokens.onGlass,
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
  late DateTime _selected = _dateOnly(widget.initialDate);
  late DateTime _displayMonth = DateTime(_selected.year, _selected.month, 1);

  @override
  Widget build(BuildContext context) {
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
          _moveBy(-1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          _moveBy(1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          _moveBy(-7);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          _moveBy(7);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          Navigator.of(context).pop(_selected);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ContractPopupSurface(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: EdgeInsets.zero,
          child: _DatePickerShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogTitle(widget.title),
                const SizedBox(height: 14),
                _CalendarPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ContractCalendarHeader(
                        displayMonth: _displayMonth,
                        onPrevious: () => setState(
                          () => _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month - 1,
                            1,
                          ),
                        ),
                        onNext: () => setState(
                          () => _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month + 1,
                            1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ContractMonthGrid(
                        displayMonth: _displayMonth,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        selectedStart: _selected,
                        selectedEnd: _selected,
                        onDayTap: (picked) =>
                            setState(() => _selected = picked),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DialogActions(
                  confirmText: 'Aceptar',
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: () => Navigator.of(context).pop(_selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _moveBy(int days) {
    setState(() {
      _selected = _clamp(_selected.add(Duration(days: days)));
      _displayMonth = DateTime(_selected.year, _selected.month, 1);
    });
  }

  DateTime _clamp(DateTime value) {
    if (value.isBefore(widget.firstDate)) return _dateOnly(widget.firstDate);
    if (value.isAfter(widget.lastDate)) return _dateOnly(widget.lastDate);
    return _dateOnly(value);
  }
}

class _ContractDateRangePickerDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialDateRange;
  final String title;

  const _ContractDateRangePickerDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialDateRange,
    required this.title,
  });

  @override
  State<_ContractDateRangePickerDialog> createState() =>
      _ContractDateRangePickerDialogState();
}

class _ContractDateRangePickerDialogState
    extends State<_ContractDateRangePickerDialog> {
  late DateTime _displayMonth;
  DateTime? _start;
  DateTime? _end;
  DateTime? _hover;

  @override
  void initState() {
    super.initState();
    _start = widget.initialDateRange == null
        ? null
        : _dateOnly(widget.initialDateRange!.start);
    _end = widget.initialDateRange == null
        ? null
        : _dateOnly(widget.initialDateRange!.end);
    final base = _start ?? widget.firstDate;
    _displayMonth = DateTime(base.year, base.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ContractPopupSurface(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
          padding: EdgeInsets.zero,
          child: _DatePickerShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogTitle(widget.title),
                const SizedBox(height: 14),
                _CalendarPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ContractCalendarHeader(
                        displayMonth: _displayMonth,
                        onPrevious: () => setState(
                          () => _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month - 1,
                            1,
                          ),
                        ),
                        onNext: () => setState(
                          () => _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month + 1,
                            1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ContractMonthGrid(
                        displayMonth: _displayMonth,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        selectedStart: _start,
                        selectedEnd: _end,
                        hoverDate: _hover,
                        onHoverDate: (value) => setState(() => _hover = value),
                        onDayTap: (picked) {
                          setState(() {
                            if (_start == null || _end != null) {
                              _start = picked;
                              _end = null;
                              _hover = null;
                            } else {
                              _end = picked;
                              _hover = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _start == null
                      ? 'Selecciona fecha inicial'
                      : _end == null
                      ? 'Selecciona fecha final'
                      : '${_formatDate(_start!)} - ${_formatDate(_end!)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.badgeText,
                  ),
                ),
                const SizedBox(height: 14),
                _DialogActions(
                  confirmText: 'Aplicar',
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: _start == null
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(_orderedRange(_start!, _end ?? _start!)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final String title;

  const _DialogTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: tokens.onGlass,
      ),
    );
  }
}

class _DatePickerShell extends StatelessWidget {
  final Widget child;

  const _DatePickerShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            tokens.glassSurface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  final Widget child;

  const _CalendarPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            tokens.fieldSurface.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

class _DialogActions extends StatelessWidget {
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  const _DialogActions({
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.onGlass,
            backgroundColor: tokens.fieldSurface.withValues(alpha: 0.96),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          onPressed: onCancel,
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: tokens.accent,
            foregroundColor: tokens.onGlass,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          onPressed: onConfirm,
          child: Text(confirmText),
        ),
      ],
    );
  }
}

class _ContractCalendarHeader extends StatelessWidget {
  final DateTime displayMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ContractCalendarHeader({
    required this.displayMonth,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        _CalendarNavButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: Center(
            child: Text(
              '${_monthNameEs(displayMonth.month)} ${displayMonth.year}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: tokens.onGlass,
              ),
            ),
          ),
        ),
        _CalendarNavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalendarNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tokens.glassSurface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: tokens.onGlass),
      ),
    );
  }
}

class _ContractMonthGrid extends StatelessWidget {
  final DateTime displayMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? selectedStart;
  final DateTime? selectedEnd;
  final DateTime? hoverDate;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime?>? onHoverDate;

  const _ContractMonthGrid({
    required this.displayMonth,
    required this.firstDate,
    required this.lastDate,
    required this.selectedStart,
    required this.selectedEnd,
    required this.onDayTap,
    this.hoverDate,
    this.onHoverDate,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
    final leading = (monthFirst.weekday + 6) % 7;
    final gridStart = monthFirst.subtract(Duration(days: leading));
    return Column(
      children: [
        Row(
          children: [
            for (final label in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tokens.badgeText,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.08,
          ),
          itemBuilder: (_, index) {
            final day = gridStart.add(Duration(days: index));
            final inMonth = day.month == monthFirst.month;
            final allowed = _isWithinBounds(day, firstDate, lastDate);
            final active =
                (selectedStart != null && _isSameDay(day, selectedStart!)) ||
                (selectedEnd != null && _isSameDay(day, selectedEnd!));
            final inRange = _isInPreviewRange(
              day,
              selectedStart,
              selectedEnd ?? hoverDate,
            );
            return MouseRegion(
              onEnter: (_) {
                if (selectedStart != null &&
                    selectedEnd == null &&
                    allowed &&
                    onHoverDate != null) {
                  onHoverDate!(_dateOnly(day));
                }
              },
              child: GestureDetector(
                onTap: !allowed ? null : () => onDayTap(_dateOnly(day)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: active
                        ? tokens.accent.withValues(alpha: 0.94)
                        : inRange
                        ? tokens.primarySoft.withValues(alpha: 0.24)
                        : tokens.glassSurface.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? tokens.primary.withValues(alpha: 0.56)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                        color: !allowed
                            ? tokens.badgeText.withValues(alpha: 0.28)
                            : inMonth
                            ? tokens.onGlass
                            : tokens.badgeText.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

bool _isWithinBounds(DateTime day, DateTime firstDate, DateTime lastDate) {
  final d = _dateOnly(day);
  return !d.isBefore(_dateOnly(firstDate)) && !d.isAfter(_dateOnly(lastDate));
}

bool _isInPreviewRange(DateTime day, DateTime? start, DateTime? previewEnd) {
  if (start == null || previewEnd == null) return false;
  final a = _dateOnly(start);
  final b = _dateOnly(previewEnd);
  final from = a.isBefore(b) ? a : b;
  final to = a.isBefore(b) ? b : a;
  final d = _dateOnly(day);
  return !d.isBefore(from) && !d.isAfter(to);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTimeRange _orderedRange(DateTime start, DateTime end) {
  final a = _dateOnly(start);
  final b = _dateOnly(end);
  return a.isBefore(b)
      ? DateTimeRange(start: a, end: b)
      : DateTimeRange(start: b, end: a);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String _monthNameEs(int month) {
  const names = <String>[
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return names[month];
}
