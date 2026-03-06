import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_gate.dart';
import '../dashboard/dashboard_page.dart';
import '../maintenance/maintenance_page.dart';
import 'inventory_page.dart';
import 'weighings_page.dart';
import 'services_shell.dart'; // ajusta el path si lo guardaste en /ui/ o /app/
import '../shared/page_routes.dart';

const double _kActionsW = 150; // prueba 150-170 si quieres más aire

const Color _kGlassMenuBg = Color(0xE6EAF2F9);
const Color _kFilterAccent = Color(0xFF4F8E8C);
const Color _kFilterAccentSoft = Color(0xFFE2EEEC);
const double _kCommentColW = 230;
const double _kTableContentW =
    90 + 190 + 190 + 130 + 190 + 140 + 130 + _kCommentColW + 10 + _kActionsW;

class _FilterDialogResult {
  final Set<String> selectedValues;
  const _FilterDialogResult({required this.selectedValues});
}

class _PickerOption<T> {
  final T value;
  final String label;
  const _PickerOption({required this.value, required this.label});
}

class _FocusFirstPickerItemIntent extends Intent {
  const _FocusFirstPickerItemIntent();
}

class _DateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;
  const _DateFilterDialogResult({this.range, this.clear = false});
}

String _fmtDateLabel(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

String _monthNameEs(int month) {
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return months[(month - 1).clamp(0, 11)];
}

Future<_DateFilterDialogResult?> _showDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_DateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? DateTime.now()).year,
        (initialRange?.start ?? DateTime.now()).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
      bool withinBounds(DateTime day) {
        final d = dateOnly(day);
        return !d.isBefore(dateOnly(bounds.start)) &&
            !d.isAfter(dateOnly(bounds.end));
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
          final leading = (monthFirst.weekday + 6) % 7; // monday=0
          final gridStart = monthFirst.subtract(Duration(days: leading));
          final rangePreviewEnd = end ?? hover;
          _DateFilterDialogResult? buildApplyResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _DateFilterDialogResult(
              range: DateTimeRange(start: from, end: to),
            );
          }

          bool inPreviewRange(DateTime day) {
            if (start == null || rangePreviewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(rangePreviewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(dialogContext);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                final applyResult = buildApplyResult();
                if (applyResult != null) {
                  Navigator.pop(dialogContext, applyResult);
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _filterDialogDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setLocalState(() {
                                    displayMonth = DateTime(
                                      displayMonth.year,
                                      displayMonth.month - 1,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_monthNameEs(monthFirst.month)[0].toUpperCase()}${_monthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setLocalState(() {
                                    displayMonth = DateTime(
                                      displayMonth.year,
                                      displayMonth.month + 1,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Expanded(child: Center(child: Text('L'))),
                              Expanded(child: Center(child: Text('M'))),
                              Expanded(child: Center(child: Text('M'))),
                              Expanded(child: Center(child: Text('J'))),
                              Expanded(child: Center(child: Text('V'))),
                              Expanded(child: Center(child: Text('S'))),
                              Expanded(child: Center(child: Text('D'))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 250,
                            child: Column(
                              children: List.generate(6, (row) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(7, (col) {
                                      final day = gridStart.add(
                                        Duration(days: row * 7 + col),
                                      );
                                      final inMonth =
                                          day.month == displayMonth.month;
                                      final allowed = withinBounds(day);
                                      final selectedStart =
                                          start != null &&
                                          isSameDay(day, start!);
                                      final selectedEnd =
                                          end != null && isSameDay(day, end!);
                                      final inRange = inPreviewRange(day);
                                      final active =
                                          selectedStart || selectedEnd;

                                      final bgColor = active
                                          ? _kFilterAccent
                                          : inRange
                                          ? _kFilterAccentSoft.withOpacity(0.8)
                                          : Colors.transparent;

                                      final txtColor = active
                                          ? Colors.white
                                          : !allowed
                                          ? Colors.black38
                                          : inMonth
                                          ? const Color(0xFF0B2B2B)
                                          : Colors.black54;

                                      return Expanded(
                                        child: MouseRegion(
                                          onHover: (_) {
                                            if (start != null &&
                                                end == null &&
                                                allowed) {
                                              setLocalState(
                                                () => hover = dateOnly(day),
                                              );
                                            }
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: !allowed
                                                ? null
                                                : () {
                                                    final picked = dateOnly(
                                                      day,
                                                    );
                                                    setLocalState(() {
                                                      if (start == null ||
                                                          end != null) {
                                                        start = picked;
                                                        end = null;
                                                        hover = null;
                                                        return;
                                                      }
                                                      if (picked.isBefore(
                                                        start!,
                                                      )) {
                                                        start = picked;
                                                        hover = null;
                                                        return;
                                                      }
                                                      end = picked;
                                                      hover = null;
                                                    });
                                                  },
                                            child: Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                                border: inRange && !active
                                                    ? Border.all(
                                                        color: _kFilterAccent
                                                            .withOpacity(0.35),
                                                      )
                                                    : null,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${day.day}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: active
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                    color: txtColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            start == null
                                ? 'Selecciona fecha inicial'
                                : end == null
                                ? 'Mueve el mouse y selecciona fecha final'
                                : '${_fmtDateLabel(start!)} - ${_fmtDateLabel(end!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A4B49),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _filterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                style: _filterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _DateFilterDialogResult(clear: true),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: _filterFilledButtonStyle(),
                                onPressed: start == null
                                    ? null
                                    : () => Navigator.pop(
                                        dialogContext,
                                        buildApplyResult(),
                                      ),
                                child: const Text('Aplicar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<T?> _showSearchablePickerDialog<T>(
  BuildContext context, {
  required String title,
  required List<_PickerOption<T>> options,
  T? initialValue,
}) async {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (_) => _SearchablePickerDialog<T>(
      title: title,
      options: options,
      initialValue: initialValue,
    ),
  );
}

Future<DateTime?> _showGlassDatePickerDialog(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  DateTime tempDate = DateUtils.dateOnly(initialDate);

  DateTime clampDate(DateTime value) {
    if (value.isBefore(firstDate)) return firstDate;
    if (value.isAfter(lastDate)) return lastDate;
    return value;
  }

  void moveDateByDays(void Function(void Function()) setInnerState, int days) {
    setInnerState(() {
      tempDate = DateUtils.dateOnly(
        clampDate(tempDate.add(Duration(days: days))),
      );
    });
  }

  void deferredPop(BuildContext ctx, [DateTime? value]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop(value);
    });
  }

  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (innerContext, setInnerState) {
          return FocusScope(
            autofocus: true,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.escape) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowLeft) {
                  moveDateByDays(setInnerState, -1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  moveDateByDays(setInnerState, 1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  moveDateByDays(setInnerState, -7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  moveDateByDays(setInnerState, 7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext, DateUtils.dateOnly(tempDate));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Theme(
                data: Theme.of(innerContext).copyWith(
                  colorScheme: Theme.of(innerContext).colorScheme.copyWith(
                    primary: const Color(0xFF6A99C7),
                    onPrimary: Colors.white,
                    surface: const Color(0xFFEAF2F9),
                  ),
                ),
                child: AlertDialog(
                  backgroundColor: const Color(0xFFEAF2F9).withOpacity(0.98),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: const Color(0xFF8AA9C2).withOpacity(0.42),
                    ),
                  ),
                  title: const Text('Selecciona fecha'),
                  content: SizedBox(
                    width: 320,
                    child: CalendarDatePicker(
                      key: ValueKey<DateTime>(tempDate),
                      initialDate: tempDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (d) {
                        setInnerState(() {
                          tempDate = DateUtils.dateOnly(d);
                        });
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5478),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6A99C7),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(DateUtils.dateOnly(tempDate)),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _SearchablePickerDialog<T> extends StatefulWidget {
  final String title;
  final List<_PickerOption<T>> options;
  final T? initialValue;

  const _SearchablePickerDialog({
    required this.title,
    required this.options,
    required this.initialValue,
  });

  @override
  State<_SearchablePickerDialog<T>> createState() =>
      _SearchablePickerDialogState<T>();
}

class _SearchablePickerDialogState<T>
    extends State<_SearchablePickerDialog<T>> {
  String _query = '';
  final FocusNode _searchFocusNode = FocusNode();
  final List<FocusNode> _itemFocusNodes = <FocusNode>[];
  int? _hoveredIndex;
  int? _focusedIndex;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncItemFocusNodes(int count) {
    while (_itemFocusNodes.length < count) {
      _itemFocusNodes.add(FocusNode());
    }
    while (_itemFocusNodes.length > count) {
      _itemFocusNodes.removeLast().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.label.toLowerCase().contains(q))
              .toList();
    _syncItemFocusNodes(filtered.length);
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.70;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF9CC7E5).withOpacity(0.44),
                    const Color(0xFFDDEAF5).withOpacity(0.40),
                    const Color(0xFF8BE0CF).withOpacity(0.30),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.72)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B2B2B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Focus(
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                          _itemFocusNodes.isNotEmpty) {
                        _itemFocusNodes.first.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Shortcuts(
                      shortcuts: const <ShortcutActivator, Intent>{
                        SingleActivator(LogicalKeyboardKey.arrowDown):
                            _FocusFirstPickerItemIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          _FocusFirstPickerItemIntent:
                              CallbackAction<_FocusFirstPickerItemIntent>(
                                onInvoke: (_) {
                                  if (_itemFocusNodes.isNotEmpty) {
                                    _itemFocusNodes.first.requestFocus();
                                  }
                                  return null;
                                },
                              ),
                        },
                        child: TextField(
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: _glassFieldDecoration(
                            hintText: 'Buscar...',
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Sin resultados',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final option = filtered[i];
                              final selected =
                                  option.value == widget.initialValue;
                              final active =
                                  _hoveredIndex == i || _focusedIndex == i;
                              return Focus(
                                focusNode: _itemFocusNodes[i],
                                onFocusChange: (hasFocus) {
                                  if (!mounted) return;
                                  setState(() {
                                    if (hasFocus) {
                                      _focusedIndex = i;
                                    } else if (_focusedIndex == i) {
                                      _focusedIndex = null;
                                    }
                                  });
                                },
                                onKeyEvent: (_, event) {
                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  final key = event.logicalKey;
                                  if (key == LogicalKeyboardKey.arrowUp) {
                                    if (i == 0) {
                                      _searchFocusNode.requestFocus();
                                    } else {
                                      _itemFocusNodes[i - 1].requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  }
                                  if (key == LogicalKeyboardKey.arrowDown &&
                                      i < _itemFocusNodes.length - 1) {
                                    _itemFocusNodes[i + 1].requestFocus();
                                    return KeyEventResult.handled;
                                  }
                                  if (key == LogicalKeyboardKey.enter ||
                                      key == LogicalKeyboardKey.numpadEnter ||
                                      key == LogicalKeyboardKey.space) {
                                    Navigator.pop(context, option.value);
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: MouseRegion(
                                  onEnter: (_) =>
                                      setState(() => _hoveredIndex = i),
                                  onExit: (_) {
                                    if (_hoveredIndex == i) {
                                      setState(() => _hoveredIndex = null);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 60),
                                    curve: Curves.easeOutCubic,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(
                                              0xFFA9E8CF,
                                            ).withOpacity(0.48)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: active
                                            ? const Color(
                                                0xFF0B72FF,
                                              ).withOpacity(0.56)
                                            : Colors.transparent,
                                        width: active ? 1.0 : 0.8,
                                      ),
                                      boxShadow: active
                                          ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF75C8A5,
                                                ).withOpacity(0.22),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.40,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        selected: selected,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        title: Text(
                                          option.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: selected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Color(0xFF0B72FF),
                                              )
                                            : null,
                                        onTap: () => Navigator.pop(
                                          context,
                                          option.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeAheadDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) labelOf;
  final InputDecoration decoration;
  final bool isDense;
  final bool isExpanded;
  final double? menuMaxHeight;
  final BorderRadius? borderRadius;
  final Color? dropdownColor;
  final List<Widget> Function(BuildContext)? selectedItemBuilder;

  const _TypeAheadDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelOf,
    required this.decoration,
    this.isDense = true,
    this.isExpanded = true,
    this.menuMaxHeight,
    this.borderRadius,
    this.dropdownColor,
    this.selectedItemBuilder,
  });

  @override
  State<_TypeAheadDropdownField<T>> createState() =>
      _TypeAheadDropdownFieldState<T>();
}

class _TypeAheadDropdownFieldState<T>
    extends State<_TypeAheadDropdownField<T>> {
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey<T?>(widget.value),
      initialValue: widget.value,
      isDense: widget.isDense,
      isExpanded: widget.isExpanded,
      menuMaxHeight: widget.menuMaxHeight,
      borderRadius: widget.borderRadius,
      dropdownColor: widget.dropdownColor,
      decoration: widget.decoration,
      selectedItemBuilder: widget.selectedItemBuilder,
      items: widget.items,
      onChanged: widget.onChanged,
    );
  }
}

class _FitText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _FitText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}

InputDecoration _glassFieldDecoration({String? hintText}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.white.withOpacity(0.58), width: 1),
  );

  return InputDecoration(
    hintText: hintText,
    isDense: true,
    filled: true,
    fillColor: Colors.white.withOpacity(0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: const Color(0xFF00A3FF).withOpacity(0.8),
        width: 1.2,
      ),
    ),
  );
}

BoxDecoration _filterDialogDecoration() {
  return BoxDecoration(
    color: Colors.white.withOpacity(0.62),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.68)),
  );
}

ButtonStyle _filterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: const Color(0xFF2A4B49).withOpacity(0.25)),
    backgroundColor: Colors.white.withOpacity(0.40),
  );
}

ButtonStyle _filterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _kFilterAccent,
    foregroundColor: Colors.white,
  );
}

ButtonStyle _actionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    backgroundColor: Colors.white.withOpacity(0.34),
    side: BorderSide(color: Colors.white.withOpacity(0.72)),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withOpacity(0.28),
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 1.5;
      if (states.contains(WidgetState.hovered)) return 6;
      return 0;
    }),
  );
}

ButtonStyle _actionFilledButtonStyle() {
  return FilledButton.styleFrom(
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withOpacity(0.30),
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 2;
      if (states.contains(WidgetState.hovered)) return 7;
      return 0;
    }),
  );
}

Future<bool?> _showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmText,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.62),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.68)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.09),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: FocusScope(
                autofocus: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          autofocus: true,
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(confirmText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage>
    with WidgetsBindingObserver {
  final supa = Supabase.instance.client;
  final TextEditingController _draftNotesC = TextEditingController();
  final FocusNode _draftNotesFocusNode = FocusNode(
    debugLabel: 'insert_notes_focus',
  );
  final FocusNode _insertFocusNode = FocusNode(debugLabel: 'insert_row_focus');
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'services_rows_focus');
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'services_rows_viewport',
  );
  final Map<String, GlobalKey<_ServiceDataRowState>> _rowKeys =
      <String, GlobalKey<_ServiceDataRowState>>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};
  RealtimeChannel? _servicesRealtimeChannel;
  Timer? _autoRefreshTimer;
  Timer? _deferredRefreshTimer;
  bool _refreshingRows = false;
  bool _refreshQueued = false;
  DateTime? _lastBackgroundRefreshAt;
  String _rowsSnapshotSignature = '';
  // ===== catálogos (para dropdowns) =====
  bool _loadingCats = true;
  List<_Opt> _clients = []; // sites type='cliente'
  List<_Opt> _materials = []; // materials (área LOGISTICA)
  List<_Opt> _drivers = []; // employees is_driver=true
  List<_Opt> _vehicles = []; // vehicles status='activo'

  // ===== rows =====
  bool _loadingRows = true;
  List<Map<String, dynamic>> _rows = [];
  String? _selectedRowId;
  final Set<String> _bulkSelectedRowIds = <String>{};
  bool _gridEditMode = false;
  static const int _insertColumnCount = 10;
  static const int _gridColumnCount = 9;
  static const List<String> _gridColumnLabels = <String>[
    'FECHA',
    'EMPRESA',
    'MATERIAL',
    'TIPO',
    'CHOFER',
    'UNIDAD',
    'PARA EL DÍA',
    'COMENTARIO',
    'ESTADO',
  ];
  int _activeGridColumn = 0;
  int _activeInsertColumn = 0;
  int _gridSaveSignal = 0;
  int _gridCancelSignal = 0;
  bool _bulkDeleting = false;
  bool _insertRowActive = false;
  int _currentPage = 0;
  int _pageSize = 40;
  bool _exportingCsv = false;
  bool _marqueeActive = false;
  Offset? _marqueeStartLocal;
  Offset? _marqueePointerLocal;
  Offset? _marqueeStartContent;
  Offset? _marqueeCurrentContent;
  bool _marqueeAdditive = false;
  Set<String> _marqueeBaseSelection = <String>{};
  Timer? _marqueeAutoScrollTimer;
  double _marqueeAutoScrollVelocity = 0;
  static const Duration _backgroundRefreshMinGap = Duration(seconds: 12);
  static const Duration _backgroundRefreshRetryDelay = Duration(seconds: 8);

  // ===== inline insert (fila superior) =====
  late _ServiceDraft _draft;

  static const _directions = <String>['recoleccion', 'entrega'];
  static const _statuses = <String>[
    'programado',
    'confirmado',
    'en_ruta',
    'en_sitio',
    'completado',
    'cancelado',
  ];
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _deferredRefreshTimer?.cancel();
    _marqueeAutoScrollTimer?.cancel();
    _servicesRealtimeChannel?.unsubscribe();
    _insertFocusNode.removeListener(_syncInsertRowFocusState);
    _draftNotesFocusNode.removeListener(_syncInsertRowFocusState);
    _rowsScrollController.dispose();
    _insertFocusNode.dispose();
    _draftNotesFocusNode.dispose();
    _rowsFocusNode.dispose();
    _draftNotesC.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _insertFocusNode.addListener(_syncInsertRowFocusState);
    _draftNotesFocusNode.addListener(_syncInsertRowFocusState);
    _draft = _ServiceDraft.empty();
    _bootstrap();
    _setupAutoRefresh();
  }

  void _syncInsertRowFocusState() {
    final next = _insertFocusNode.hasFocus || _draftNotesFocusNode.hasFocus;
    if (!mounted) return;
    var shouldSetState = false;
    if (_insertRowActive != next) {
      _insertRowActive = next;
      shouldSetState = true;
    }
    if (_draftNotesFocusNode.hasFocus && _activeInsertColumn != 7) {
      _activeInsertColumn = 7;
      shouldSetState = true;
    }
    if (shouldSetState) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRowsIfIdle(force: true);
    }
  }

  Future<void> _bootstrap() async {
    await _loadCatalogs();
    _initDraftDefaults();
    await _loadRows();
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshRowsIfIdle();
    });

    _servicesRealtimeChannel?.unsubscribe();
    _servicesRealtimeChannel = supa
        .channel('services-auto-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          callback: (_) {
            _refreshRowsIfIdle();
          },
        )
        .subscribe();
  }

  bool get _hasDraftChanges =>
      _draft.serviceDate != null ||
      _draft.dueDate != null ||
      _draft.direction != null ||
      _draft.status != null ||
      _draft.clientId != null ||
      _draft.materialId != null ||
      _draft.driverEmployeeId != null ||
      _draft.vehicleId != null ||
      _draft.notes.trim().isNotEmpty;

  bool get _hasRowsInEditingState {
    if (_gridEditMode) return true;
    for (final key in _rowKeys.values) {
      if (key.currentState?.isEditing ?? false) return true;
    }
    return false;
  }

  bool get _shouldDeferBackgroundRefresh =>
      _insertRowActive || _hasDraftChanges || _hasRowsInEditingState;

  String _rowsSignature(List<Map<String, dynamic>> rows) => jsonEncode(rows);

  void _queueDeferredBackgroundRefresh([Duration? delay]) {
    if (!mounted) return;
    _refreshQueued = true;
    _deferredRefreshTimer?.cancel();
    _deferredRefreshTimer = Timer(delay ?? _backgroundRefreshRetryDelay, () {
      _deferredRefreshTimer = null;
      unawaited(_refreshRowsIfIdle());
    });
  }

  Future<void> _refreshRowsIfIdle({bool force = false}) async {
    if (!mounted || _refreshingRows) return;
    if (!force && _shouldDeferBackgroundRefresh) {
      _queueDeferredBackgroundRefresh();
      return;
    }
    if (!force && _lastBackgroundRefreshAt != null) {
      final elapsed = DateTime.now().difference(_lastBackgroundRefreshAt!);
      if (elapsed < _backgroundRefreshMinGap) {
        _queueDeferredBackgroundRefresh(_backgroundRefreshMinGap - elapsed);
        return;
      }
    }
    _refreshingRows = true;
    try {
      await _loadRows(showLoader: false, onlyApplyIfChanged: true);
      _lastBackgroundRefreshAt = DateTime.now();
      if (_refreshQueued && !_shouldDeferBackgroundRefresh) {
        _refreshQueued = false;
      } else if (_refreshQueued) {
        _queueDeferredBackgroundRefresh();
      }
    } finally {
      _refreshingRows = false;
    }
  }

  Future<void> _goToEntriesAndOutputs() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToProduction() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryProductionPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWeighings() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WeighingsPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToMaintenance() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MaintenancePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _loadCatalogs() async {
    setState(() => _loadingCats = true);

    // CLIENTES (sites)
    final clients = await supa
        .from('sites')
        .select('id,name,type')
        .eq('type', 'cliente')
        .eq('is_active', true)
        .order('name');

    // MATERIALES (área LOGISTICA) -> join via materials + areas
    final mats = await supa
        .from('materials')
        .select('id,name,areas(name)')
        .eq('is_active', true)
        .eq('areas.name', 'LOGISTICA')
        .order('name');

    // CHOFERES
    final drivers = await supa
        .from('employees')
        .select('id,full_name')
        .eq('is_driver', true)
        .eq('is_active', true)
        .order('full_name');

    // UNIDADES activas
    final vehicles = await supa
        .from('vehicles')
        .select('id,code,status')
        .eq('status', 'activo')
        .order('code');

    setState(() {
      _clients = (clients as List)
          .map(
            (e) => _Opt(
              id: e['id'] as String,
              label: (e['name'] as String).trim(),
            ),
          )
          .toList();
      _materials = (mats as List)
          .map(
            (e) => _Opt(
              id: e['id'] as String,
              label: (e['name'] as String).trim(),
            ),
          )
          .toList();
      _drivers = (drivers as List)
          .map(
            (e) => _Opt(
              id: e['id'] as String,
              label: (e['full_name'] as String).trim(),
            ),
          )
          .toList();
      _vehicles = (vehicles as List)
          .map(
            (e) => _Opt(
              id: e['id'] as String,
              label: (e['code'] as String).trim(),
            ),
          )
          .toList();

      _loadingCats = false;
    });
  }

  void _initDraftDefaults() {
    _draft = const _ServiceDraft(
      serviceDate: null,
      dueDate: null,
      direction: null,
      status: null,
      clientId: null,
      materialId: null,
      driverEmployeeId: null,
      vehicleId: null,
      notes: '',
    );

    // IMPORTANTÍSIMO: limpia controllers (si no, se quedan con lo último)
    _draftNotesC.text = '';
    _activeInsertColumn = 0;
  }

  Future<bool> _loadRows({
    bool showLoader = true,
    bool onlyApplyIfChanged = false,
  }) async {
    if (showLoader) {
      setState(() => _loadingRows = true);
    }

    final data = await supa
        .from('v_services_grid')
        .select('*')
        .order('service_date', ascending: false)
        .order('created_at', ascending: false);

    final nextRows = (data as List).cast<Map<String, dynamic>>();
    final nextSignature = _rowsSignature(nextRows);
    if (onlyApplyIfChanged && nextSignature == _rowsSnapshotSignature) {
      if (showLoader && mounted) {
        setState(() => _loadingRows = false);
      }
      return false;
    }
    final ids = nextRows.map((r) => r['id'] as String).toSet();
    final visibleIds = nextRows
        .where((r) => _matchesFilters(r))
        .map((r) => r['id'] as String)
        .toSet();
    final nextSelected =
        ids.contains(_selectedRowId) && visibleIds.contains(_selectedRowId)
        ? _selectedRowId
        : null;
    _rowKeys.removeWhere((id, _) => !ids.contains(id));

    setState(() {
      _rows = nextRows;
      _rowsSnapshotSignature = nextSignature;
      _selectedRowId = nextSelected;
      _bulkSelectedRowIds.removeWhere((id) => !ids.contains(id));
      _clampCurrentPage();
      if (showLoader) _loadingRows = false;
    });
    return true;
  }

  GlobalKey<_ServiceDataRowState> _rowKeyFor(String id) {
    return _rowKeys.putIfAbsent(
      id,
      () => GlobalKey<_ServiceDataRowState>(debugLabel: 'row_$id'),
    );
  }

  String _cellTextForColumn(Map<String, dynamic> row, String columnId) {
    String byKeys(List<String> keys) {
      for (final k in keys) {
        final v = row[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    switch (columnId) {
      case 'fecha':
        return _fmtUiDate(_parseDate(row['service_date']));
      case 'empresa':
        return byKeys(['client_name', 'client_label']).isNotEmpty
            ? byKeys(['client_name', 'client_label'])
            : (_labelOf(_clients, row['client_id'] as String?) ?? '');
      case 'material':
        return byKeys(['material_type', 'material_name']).isNotEmpty
            ? byKeys(['material_type', 'material_name'])
            : (_labelOf(_materials, row['material_id'] as String?) ?? '');
      case 'tipo':
        return _uiLabel(((row['direction'] as String?) ?? '').trim());
      case 'chofer':
        return byKeys([
              'driver_name',
              'driver_full_name',
              'driver_employee_name',
            ]).isNotEmpty
            ? byKeys([
                'driver_name',
                'driver_full_name',
                'driver_employee_name',
              ])
            : (_labelOf(_drivers, row['driver_employee_id'] as String?) ?? '');
      case 'unidad':
        return byKeys(['vehicle_code', 'vehicle_name']).isNotEmpty
            ? byKeys(['vehicle_code', 'vehicle_name'])
            : (_labelOf(_vehicles, row['vehicle_id'] as String?) ?? '');
      case 'para_dia':
        return row['due_date'] == null
            ? ''
            : _fmtUiDate(_parseDate(row['due_date']));
      case 'comentario':
        return ((row['notes'] ?? '') as String).trim();
      case 'estado':
        return _uiLabel(((row['status'] as String?) ?? '').trim());
      default:
        return '';
    }
  }

  bool _matchesFilters(Map<String, dynamic> row, {String? excludeColumn}) {
    for (final entry in _columnDateRangeFilters.entries) {
      if (entry.key == excludeColumn) continue;
      final value = _dateValueForColumn(row, entry.key);
      if (value == null) return false;
      final dateOnly = DateUtils.dateOnly(value);
      final start = DateUtils.dateOnly(entry.value.start);
      final end = DateUtils.dateOnly(entry.value.end);
      if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) return false;
    }

    for (final entry in _columnValueFilters.entries) {
      if (entry.key == excludeColumn) continue;
      if (entry.value.isEmpty) continue;
      final value = _cellTextForColumn(row, entry.key);
      if (!entry.value.contains(value)) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> get _filteredRows {
    return _rows.where((r) => _matchesFilters(r)).toList();
  }

  List<Map<String, dynamic>> get _visibleRows {
    final filtered = _filteredRows;
    final start = _currentPage * _pageSize;
    if (start >= filtered.length) return <Map<String, dynamic>>[];
    final end = (start + _pageSize < filtered.length)
        ? start + _pageSize
        : filtered.length;
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final total = _filteredRows.length;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  void _clampCurrentPage() {
    final maxPage = _totalPages - 1;
    if (_currentPage > maxPage) _currentPage = maxPage;
    if (_currentPage < 0) _currentPage = 0;
  }

  Future<void> _deleteSelectedRows() async {
    final selectedIds = _currentSelectionIds();
    if (selectedIds.isEmpty) {
      _toast('Selecciona al menos una fila');
      return;
    }
    if (_bulkDeleting) return;
    final ok = await _showGlassConfirmDialog(
      context,
      title: 'Eliminar seleccionados',
      content:
          '¿Seguro que deseas eliminar ${_fmtCountInt(selectedIds.length)} servicio(s)?',
      confirmText: 'Eliminar',
    );
    if (ok != true) return;

    setState(() => _bulkDeleting = true);
    try {
      final ids = selectedIds.toList();
      await supa.from('services').delete().inFilter('id', ids);
      _selectedRowId = null;
      _bulkSelectedRowIds.clear();
      _toast('Eliminados ${_fmtCountInt(ids.length)} servicio(s)');
      await _loadRows();
    } finally {
      if (mounted) {
        setState(() => _bulkDeleting = false);
      }
    }
  }

  String _csvEscape(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    final escaped = text.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('\r') ||
        escaped.contains('"');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Future<void> _exportServicesCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final data = await supa
          .from('services')
          .select(
            'id,service_date,due_date,direction,status,client_id,material_id,driver_employee_id,vehicle_id,weight_kg,notes,area,client_name,material_type,created_at',
          )
          .order('created_at');

      final rows = (data as List).cast<Map<String, dynamic>>();
      const headers = <String>[
        'id',
        'service_date',
        'due_date',
        'direction',
        'status',
        'client_id',
        'material_id',
        'driver_employee_id',
        'vehicle_id',
        'weight_kg',
        'notes',
        'area',
        'client_name',
        'material_type',
        'created_at',
      ];

      final sb = StringBuffer();
      sb.write('\uFEFF');
      sb.writeln(headers.join(','));
      for (final row in rows) {
        final line = headers.map((h) => _csvEscape(row[h])).join(',');
        sb.writeln(line);
      }

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'services_backup_$stamp.csv';
      final env = Platform.environment;
      final targetDirs = <Directory>[];

      if (Platform.isWindows) {
        final userProfile = env['USERPROFILE'];
        final homeDrive = env['HOMEDRIVE'];
        final homePath = env['HOMEPATH'];
        final oneDrive = env['OneDrive'];

        if (userProfile != null && userProfile.isNotEmpty) {
          targetDirs.add(Directory('$userProfile\\Downloads'));
        }
        if (oneDrive != null && oneDrive.isNotEmpty) {
          targetDirs.add(Directory('$oneDrive\\Downloads'));
        }
        if (homeDrive != null &&
            homeDrive.isNotEmpty &&
            homePath != null &&
            homePath.isNotEmpty) {
          targetDirs.add(Directory('$homeDrive$homePath\\Downloads'));
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          targetDirs.add(Directory('$home/Downloads'));
          targetDirs.add(Directory('$home/Descargas'));
        }
      }

      String? savedPath;
      Object? lastWriteError;

      for (final dir in targetDirs) {
        try {
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(sb.toString(), encoding: utf8);
          savedPath = file.path;
          break;
        } catch (e) {
          lastWriteError = e;
        }
      }

      if (savedPath == null) {
        _toast(
          'No se pudo guardar en Descargas: ${lastWriteError ?? 'sin detalle'}',
        );
        return;
      }

      _toast('CSV exportado en: $savedPath');
    } on PostgrestException catch (e) {
      _toast('CSV no disponible (Supabase): ${e.message}');
    } on FileSystemException catch (e) {
      _toast('No se pudo guardar CSV: ${e.message}');
    } catch (e) {
      _toast('No se pudo exportar el CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  bool _hasActiveFilter(String columnId) {
    return (_columnValueFilters[columnId]?.isNotEmpty ?? false) ||
        _columnDateRangeFilters.containsKey(columnId);
  }

  bool _isDateFilterColumn(String columnId) {
    return columnId == 'fecha' || columnId == 'para_dia';
  }

  DateTime? _dateValueForColumn(Map<String, dynamic> row, String columnId) {
    switch (columnId) {
      case 'fecha':
        return _parseDate(row['service_date']);
      case 'para_dia':
        if (row['due_date'] == null) return null;
        return _parseDate(row['due_date']);
      default:
        return null;
    }
  }

  DateTimeRange _dateBoundsForColumn(String columnId) {
    DateTime? minDate;
    DateTime? maxDate;
    for (final row in _rows) {
      final d = _dateValueForColumn(row, columnId);
      if (d == null) continue;
      final dateOnly = DateUtils.dateOnly(d);
      if (minDate == null || dateOnly.isBefore(minDate)) minDate = dateOnly;
      if (maxDate == null || dateOnly.isAfter(maxDate)) maxDate = dateOnly;
    }
    if (minDate != null && maxDate != null) {
      return DateTimeRange(start: minDate, end: maxDate);
    }
    final now = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: DateTime(now.year - 3, 1, 1),
      end: DateTime(now.year + 3, 12, 31),
    );
  }

  List<String> _columnDistinctValues(String columnId, {String search = ''}) {
    final lowerSearch = search.trim().toLowerCase();
    final values = <String>{};

    for (final row in _rows) {
      if (!_matchesFilters(row, excludeColumn: columnId)) continue;
      final value = _cellTextForColumn(row, columnId);
      if (value.isEmpty) continue;
      if (lowerSearch.isNotEmpty &&
          !value.toLowerCase().contains(lowerSearch)) {
        continue;
      }
      values.add(value);
    }

    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (_isDateFilterColumn(columnId)) {
      final currentRange = _columnDateRangeFilters[columnId];
      final bounds = _dateBoundsForColumn(columnId);
      final result = await _showDateRangeFilterDialog(
        context,
        label: label,
        bounds: bounds,
        initialRange: currentRange,
      );
      if (!mounted || result == null) return;
      setState(() {
        if (result.clear) {
          _columnDateRangeFilters.remove(columnId);
        } else if (result.range != null) {
          _columnDateRangeFilters[columnId] = DateTimeRange(
            start: DateUtils.dateOnly(result.range!.start),
            end: DateUtils.dateOnly(result.range!.end),
          );
        }
        _columnValueFilters.remove(columnId);
        _clampCurrentPage();
        final visibleIds = _filteredRows.map((r) => r['id'] as String).toSet();
        _bulkSelectedRowIds.removeWhere((id) => !visibleIds.contains(id));
        if (!visibleIds.contains(_selectedRowId)) {
          _selectedRowId = null;
        }
      });
      return;
    }

    final initialSelected = {...(_columnValueFilters[columnId] ?? <String>{})};

    final result = await showDialog<_FilterDialogResult>(
      context: context,
      builder: (dialogContext) {
        final localSelected = <String>{...initialSelected};
        String localSearch = '';

        return StatefulBuilder(
          builder: (_, setLocalState) {
            final options = _columnDistinctValues(
              columnId,
              search: localSearch,
            );
            final allVisibleSelected =
                options.isNotEmpty && options.every(localSelected.contains);

            void applyAndClose() {
              Navigator.pop(
                dialogContext,
                _FilterDialogResult(selectedValues: localSelected),
              );
            }

            return Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  applyAndClose();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 420,
                      constraints: const BoxConstraints(maxHeight: 560),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _filterDialogDecoration(),
                      child: FocusScope(
                        autofocus: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filtro: $label',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0B2B2B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              onChanged: (v) =>
                                  setLocalState(() => localSearch = v),
                              onSubmitted: (_) => applyAndClose(),
                              decoration: _glassFieldDecoration(
                                hintText: 'Buscar',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2A4B49),
                                  ),
                                  onPressed: () {
                                    setLocalState(() {
                                      if (allVisibleSelected) {
                                        localSelected.removeAll(options);
                                      } else {
                                        localSelected.addAll(options);
                                      }
                                    });
                                  },
                                  child: Text(
                                    allVisibleSelected
                                        ? 'Deseleccionar visibles'
                                        : 'Seleccionar visibles',
                                  ),
                                ),
                                const Spacer(),
                                Text('${localSelected.length} seleccionados'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: options.isEmpty
                                  ? const Center(
                                      child: Text('Sin valores para mostrar'),
                                    )
                                  : ListView.builder(
                                      itemCount: options.length,
                                      itemBuilder: (_, i) {
                                        final value = options[i];
                                        final checked = localSelected.contains(
                                          value,
                                        );
                                        return CheckboxListTile(
                                          dense: true,
                                          value: checked,
                                          title: Text(
                                            value,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onChanged: (v) {
                                            setLocalState(() {
                                              if (v ?? false) {
                                                localSelected.add(value);
                                              } else {
                                                localSelected.remove(value);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  style: _filterOutlinedButtonStyle(),
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: _filterOutlinedButtonStyle(),
                                  onPressed: () {
                                    Navigator.pop(
                                      dialogContext,
                                      const _FilterDialogResult(
                                        selectedValues: <String>{},
                                      ),
                                    );
                                  },
                                  child: const Text('Limpiar'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: _filterFilledButtonStyle(),
                                  onPressed: applyAndClose,
                                  child: const Text('Aplicar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      if (result.selectedValues.isEmpty) {
        _columnValueFilters.remove(columnId);
      } else {
        _columnValueFilters[columnId] = result.selectedValues;
      }
      _columnDateRangeFilters.remove(columnId);

      _clampCurrentPage();
      final visibleIds = _filteredRows.map((r) => r['id'] as String).toSet();
      _bulkSelectedRowIds.removeWhere((id) => !visibleIds.contains(id));
      if (!visibleIds.contains(_selectedRowId)) {
        _selectedRowId = null;
      }
    });
  }

  void _ensureRowVisible(String id, {int? moveDelta}) {
    final rowIndex = _visibleRows.indexWhere((r) => r['id'] == id);
    if (rowIndex == -1) return;
    final rowContext = _rowKeyFor(id).currentContext;
    if (rowContext == null) {
      if (!_rowsScrollController.hasClients) return;
      const estimatedRowExtent = 76.0;
      final targetOffset = (rowIndex * estimatedRowExtent)
          .clamp(0.0, _rowsScrollController.position.maxScrollExtent)
          .toDouble();
      _rowsScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final alignmentPolicy = moveDelta == null
        ? ScrollPositionAlignmentPolicy.explicit
        : (moveDelta > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    Scrollable.ensureVisible(
      rowContext,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      alignmentPolicy: alignmentPolicy,
    );
  }

  double get _rowsScrollOffset =>
      _rowsScrollController.hasClients ? _rowsScrollController.offset : 0;

  Offset _localToContent(Offset local) =>
      Offset(local.dx, local.dy + _rowsScrollOffset);

  Rect _marqueeRectContent() {
    final start = _marqueeStartContent ?? Offset.zero;
    final current = _marqueeCurrentContent ?? start;
    return Rect.fromPoints(start, current);
  }

  Rect _marqueeRectForPaint() =>
      _marqueeRectContent().shift(Offset(0, -_rowsScrollOffset));

  Rect _clampRectToViewport(Rect rectViewport) {
    final viewportContext = _rowsViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return rectViewport;
    final width = viewportBox.size.width;
    final height = viewportBox.size.height;
    final left = rectViewport.left.clamp(0.0, width).toDouble();
    final top = rectViewport.top.clamp(0.0, height).toDouble();
    final right = rectViewport.right.clamp(0.0, width).toDouble();
    final bottom = rectViewport.bottom.clamp(0.0, height).toDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Set<String> _marqueeIntersectedIds(Rect rectContent) {
    final viewportContext = _rowsViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return const <String>{};

    final scrollOffset = _rowsScrollOffset;
    final hits = <String>{};
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      final rowContext = _rowKeyFor(id).currentContext;
      final rowBox = rowContext?.findRenderObject() as RenderBox?;
      if (rowBox == null || !rowBox.hasSize) continue;
      final rowTopLeftGlobal = rowBox.localToGlobal(Offset.zero);
      final rowTopLeftViewport = viewportBox.globalToLocal(rowTopLeftGlobal);
      final viewportRect = Rect.fromLTWH(
        rowTopLeftViewport.dx,
        rowTopLeftViewport.dy,
        rowBox.size.width,
        rowBox.size.height,
      );
      final rowRectContent = viewportRect.shift(Offset(0, scrollOffset));
      if (rowRectContent.overlaps(rectContent)) {
        hits.add(id);
      }
    }
    return hits;
  }

  void _applyMarqueeSelection() {
    if (!_marqueeActive) return;
    final rect = _marqueeRectContent();
    final hit = _marqueeIntersectedIds(rect);
    final next = _marqueeAdditive ? ({..._marqueeBaseSelection, ...hit}) : hit;
    if (!mounted) return;
    setState(() {
      if (next.isEmpty) {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
        return;
      }
      String? primary;
      if (_selectedRowId != null && next.contains(_selectedRowId)) {
        primary = _selectedRowId;
      } else {
        for (final row in _visibleRows) {
          final id = row['id'] as String;
          if (next.contains(id)) {
            primary = id;
            break;
          }
        }
      }
      _selectedRowId = primary;
      _bulkSelectedRowIds
        ..clear()
        ..addAll(next);
    });
  }

  void _syncMarqueeAutoScroll() {
    final viewportContext = _rowsViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (!_marqueeActive ||
        _marqueePointerLocal == null ||
        viewportBox == null) {
      _marqueeAutoScrollVelocity = 0;
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }
    if (!_rowsScrollController.hasClients) {
      _marqueeAutoScrollVelocity = 0;
      return;
    }
    const edge = 64.0;
    const maxVelocity = 18.0;
    final h = viewportBox.size.height;
    final y = _marqueePointerLocal!.dy;
    if (y < edge) {
      _marqueeAutoScrollVelocity = -((edge - y) / edge) * maxVelocity;
    } else if (y > h - edge) {
      _marqueeAutoScrollVelocity = ((y - (h - edge)) / edge) * maxVelocity;
    } else {
      _marqueeAutoScrollVelocity = 0;
    }
    if (_marqueeAutoScrollVelocity == 0) {
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }
    _marqueeAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickMarqueeAutoScroll(),
    );
  }

  void _tickMarqueeAutoScroll() {
    if (!_marqueeActive ||
        _marqueeAutoScrollVelocity == 0 ||
        !_rowsScrollController.hasClients) {
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }
    final pos = _rowsScrollController.position;
    final next = (pos.pixels + _marqueeAutoScrollVelocity).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (next == pos.pixels) return;
    _rowsScrollController.jumpTo(next.toDouble());
    if (_marqueePointerLocal != null) {
      _marqueeCurrentContent = _localToContent(_marqueePointerLocal!);
      _applyMarqueeSelection();
      if (mounted) setState(() {});
    }
  }

  void _startMarqueeSelection(Offset local) {
    _marqueeStartLocal = local;
    _marqueePointerLocal = local;
    _marqueeStartContent = _localToContent(local);
    _marqueeCurrentContent = _marqueeStartContent;
    _marqueeAdditive = _isCtrlOrCmdPressed();
    _marqueeBaseSelection = _currentSelectionIds();
    _marqueeActive = false;
  }

  void _updateMarqueeSelection(Offset local) {
    if (_marqueeStartLocal == null) return;
    _marqueePointerLocal = local;
    _marqueeCurrentContent = _localToContent(local);
    final shouldActivate = (local - _marqueeStartLocal!).distance > 6;
    if (!shouldActivate && !_marqueeActive) return;
    if (!_marqueeActive && mounted) {
      setState(() => _marqueeActive = true);
    }
    _applyMarqueeSelection();
    _syncMarqueeAutoScroll();
  }

  void _endMarqueeSelection() {
    _marqueeAutoScrollVelocity = 0;
    _marqueeAutoScrollTimer?.cancel();
    _marqueeAutoScrollTimer = null;
    _marqueeStartLocal = null;
    _marqueePointerLocal = null;
    _marqueeStartContent = null;
    _marqueeCurrentContent = null;
    _marqueeAdditive = false;
    _marqueeBaseSelection = <String>{};
    if (_marqueeActive && mounted) {
      setState(() => _marqueeActive = false);
    } else {
      _marqueeActive = false;
    }
  }

  void _selectRow(
    String id, {
    bool focusTable = true,
    bool allowToggle = false,
    bool ensureVisible = true,
    bool additive = false,
    bool additiveToggle = true,
    int? moveDelta,
  }) {
    if (additive) {
      setState(() {
        final previouslySelectedId = _selectedRowId;
        if (_bulkSelectedRowIds.isEmpty &&
            previouslySelectedId != null &&
            previouslySelectedId != id) {
          _bulkSelectedRowIds.add(previouslySelectedId);
        }
        if (_bulkSelectedRowIds.contains(id) && additiveToggle) {
          _bulkSelectedRowIds.remove(id);
          if (_selectedRowId == id) {
            _selectedRowId = _bulkSelectedRowIds.isEmpty
                ? null
                : _bulkSelectedRowIds.last;
          }
        } else {
          _bulkSelectedRowIds.add(id);
          _selectedRowId = id;
        }
      });
      if (focusTable) _rowsFocusNode.requestFocus();
      if (!ensureVisible) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(id, moveDelta: moveDelta);
      });
      return;
    }

    if (allowToggle && _selectedRowId == id) {
      setState(() {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
      });
      if (focusTable) _rowsFocusNode.requestFocus();
      return;
    }
    if (_selectedRowId == id && !focusTable) return;

    setState(() {
      _selectedRowId = id;
      _bulkSelectedRowIds.clear();
    });
    if (focusTable) _rowsFocusNode.requestFocus();
    if (!ensureVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(id, moveDelta: moveDelta);
    });
  }

  void _moveSelectedRow(int delta) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;

    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((r) => r['id'] == _selectedRowId);
    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = delta >= 0 ? 0 : rows.length - 1;
    } else {
      final rawIndex = currentIndex + delta;
      nextIndex = ((rawIndex % rows.length) + rows.length) % rows.length;
    }

    _selectRow(
      rows[nextIndex]['id'] as String,
      focusTable: false,
      ensureVisible: true,
      moveDelta: delta,
    );
  }

  bool _isCtrlOrCmdPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _extendSelectionWithArrow(int delta) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((r) => r['id'] == _selectedRowId);
    if (currentIndex != -1) {
      final currentId = rows[currentIndex]['id'] as String;
      if (!_bulkSelectedRowIds.contains(currentId)) {
        _bulkSelectedRowIds.add(currentId);
      }
    }
    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = delta >= 0 ? 0 : rows.length - 1;
    } else {
      final rawIndex = currentIndex + delta;
      nextIndex = ((rawIndex % rows.length) + rows.length) % rows.length;
    }
    _selectRow(
      rows[nextIndex]['id'] as String,
      focusTable: false,
      ensureVisible: true,
      additive: true,
      additiveToggle: false,
      moveDelta: delta,
    );
  }

  void _ensureGridSelection() {
    if (_selectedRowId != null || _visibleRows.isEmpty) return;
    _selectRow(
      _visibleRows.first['id'] as String,
      focusTable: false,
      ensureVisible: true,
    );
  }

  void _moveGridColumn(int delta) {
    _ensureGridSelection();
    setState(() {
      final rawIndex = _activeGridColumn + delta;
      _activeGridColumn =
          ((rawIndex % _gridColumnCount) + _gridColumnCount) % _gridColumnCount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusCommentIfActiveCell();
    });
  }

  void _setPrimarySelectedKeepBulk(
    String id, {
    bool ensureVisible = true,
    int? moveDelta,
  }) {
    if (_selectedRowId == id) return;
    setState(() => _selectedRowId = id);
    if (!ensureVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(id, moveDelta: moveDelta);
    });
  }

  void _moveGridRow(int delta) {
    _ensureGridSelection();
    if (_hasExplicitMultiSelection) {
      final candidateRows = _visibleRows
          .where((r) => _bulkSelectedRowIds.contains(r['id'] as String))
          .toList();
      if (candidateRows.isEmpty) return;
      final currentIndex = _selectedRowId == null
          ? -1
          : candidateRows.indexWhere((r) => r['id'] == _selectedRowId);
      final nextIndex = currentIndex == -1
          ? (delta >= 0 ? 0 : candidateRows.length - 1)
          : (((currentIndex + delta) % candidateRows.length) +
                    candidateRows.length) %
                candidateRows.length;
      _setPrimarySelectedKeepBulk(
        candidateRows[nextIndex]['id'] as String,
        ensureVisible: true,
        moveDelta: delta,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusCommentIfActiveCell();
      });
      return;
    }
    _moveSelectedRow(delta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusCommentIfActiveCell();
    });
  }

  void _activateGridCellFromKeyboard() {
    _ensureGridSelection();
    final rowState = _selectedRowState();
    if (rowState == null) return;
    if (!rowState.isEditing) {
      rowState.startEditingFromKeyboard();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final refreshed = _selectedRowState();
        if (refreshed == null) return;
        unawaited(refreshed.activateGridCell(_activeGridColumn));
      });
      return;
    }
    unawaited(rowState.activateGridCell(_activeGridColumn));
  }

  void _focusCommentIfActiveCell() {
    if (_activeGridColumn != 7) return;
    final rowState = _selectedRowState();
    if (rowState == null || !rowState.isEditing) return;
    rowState.focusCommentField();
  }

  String get _activeGridColumnLabel {
    if (_activeGridColumn < 0 ||
        _activeGridColumn >= _gridColumnLabels.length) {
      return 'CELDA';
    }
    return _gridColumnLabels[_activeGridColumn];
  }

  bool get _hasExplicitMultiSelection {
    final primary = _selectedRowId;
    return primary != null &&
        _bulkSelectedRowIds.length > 1 &&
        _bulkSelectedRowIds.contains(primary);
  }

  List<_ServiceDataRowState> _selectedRowStates() {
    if (!_hasExplicitMultiSelection) {
      final id = _selectedRowId;
      if (id == null) return const <_ServiceDataRowState>[];
      final state = _rowKeys[id]?.currentState;
      if (state == null) return const <_ServiceDataRowState>[];
      return <_ServiceDataRowState>[state];
    }

    final primaryId = _selectedRowId;
    final orderedIds = <String>[];
    if (primaryId != null && _bulkSelectedRowIds.contains(primaryId)) {
      orderedIds.add(primaryId);
    }
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      if (_bulkSelectedRowIds.contains(id) && !orderedIds.contains(id)) {
        orderedIds.add(id);
      }
    }
    for (final id in _bulkSelectedRowIds) {
      if (!orderedIds.contains(id)) orderedIds.add(id);
    }
    return orderedIds
        .map((id) => _rowKeys[id]?.currentState)
        .whereType<_ServiceDataRowState>()
        .toList();
  }

  _ServiceDataRowState? _selectedRowState() {
    final id = _selectedRowId;
    if (id == null) return null;
    return _rowKeys[id]?.currentState;
  }

  void _handleEnterOnSelectedRow() {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    final anyNotEditing = states.any((s) => !s.isEditing);
    if (anyNotEditing) {
      setState(() => _activeGridColumn = 0);
      for (final state in states) {
        state.startEditingFromKeyboard();
      }
      return;
    }
    unawaited(Future.wait(states.map((s) => s.saveFromKeyboard())));
  }

  void _handleEscapeOnSelectedRow() {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    final anyEditing = states.any((s) => s.isEditing);
    if (anyEditing) {
      for (final state in states) {
        state.cancelEditingFromKeyboard();
      }
      return;
    }
    if (_selectedRowId != null || _bulkSelectedRowIds.isNotEmpty) {
      setState(() {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
      });
    }
  }

  void _handleDeleteOnSelectedRow() {
    if (_hasExplicitMultiSelection) {
      unawaited(_deleteSelectedRows());
      return;
    }
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    unawaited(states.first.deleteWithConfirmation());
  }

  List<MapEntry<String, String>> _rowContextActions() {
    final states = _selectedRowStates();
    final multiContext = _hasExplicitMultiSelection;
    final anyEditing = states.any((s) => s.isEditing);
    if (multiContext) {
      return <MapEntry<String, String>>[
        if (!anyEditing) const MapEntry('edit', 'EDITAR SELECCION'),
        if (anyEditing) ...const [
          MapEntry('save', 'GUARDAR SELECCION'),
          MapEntry('cancel', 'CANCELAR SELECCION'),
        ],
        const MapEntry('delete', 'ELIMINAR SELECCION'),
      ];
    }
    return <MapEntry<String, String>>[
      if (!anyEditing) const MapEntry('edit', 'EDITAR'),
      if (anyEditing) ...const [
        MapEntry('save', 'ACTUALIZAR'),
        MapEntry('cancel', 'CANCELAR'),
      ],
      const MapEntry('delete', 'ELIMINAR'),
    ];
  }

  Future<String?> _showRowsContextMenu(Offset globalPosition) {
    final actions = _rowContextActions();
    final mediaSize = MediaQuery.of(context).size;
    const menuWidth = 228.0;
    final left = globalPosition.dx.clamp(
      8.0,
      mediaSize.width - menuWidth - 8.0,
    );
    final top = globalPosition.dy.clamp(8.0, mediaSize.height - 8.0);
    return showGeneralDialog<String>(
      context: context,
      barrierLabel: 'context_menu',
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (dialogContext, _, __) {
        int? hoveredIndex;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              left: left.toDouble(),
              top: top.toDouble(),
              child: StatefulBuilder(
                builder: (context, setMenuState) {
                  return Focus(
                    autofocus: true,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.escape) {
                        Navigator.of(dialogContext).pop();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: menuWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE6EAF2F9),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.72),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                MouseRegion(
                                  onEnter: (_) =>
                                      setMenuState(() => hoveredIndex = i),
                                  onExit: (_) {
                                    if (hoveredIndex == i) {
                                      setMenuState(() => hoveredIndex = null);
                                    }
                                  },
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => Navigator.of(
                                      dialogContext,
                                    ).pop(actions[i].key),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 80,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: hoveredIndex == i
                                            ? const Color(
                                                0xFFA9E8CF,
                                              ).withOpacity(0.55)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: hoveredIndex == i
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF75C8A5,
                                                  ).withOpacity(0.30),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : const [],
                                      ),
                                      child: Text(
                                        actions[i].value,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: actions[i].key == 'delete'
                                              ? const Color(0xFF8A1F1F)
                                              : const Color(0xFF1C3E5D),
                                          decoration: TextDecoration.none,
                                          decorationColor: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (i != actions.length - 1)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.white.withOpacity(0.44),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openRowsContextMenuAt(
    Offset globalPosition, {
    String? rowId,
  }) async {
    if (rowId != null && !_currentSelectionIds().contains(rowId)) {
      _selectRow(
        rowId,
        allowToggle: false,
        additive: false,
        ensureVisible: false,
      );
    }
    final choice = await _showRowsContextMenu(globalPosition);
    if (choice == null || !mounted) return;
    final states = _selectedRowStates();
    switch (choice) {
      case 'edit':
        if (states.isEmpty) return;
        setState(() => _activeGridColumn = 0);
        for (final state in states) {
          state.startEditingFromKeyboard();
        }
        return;
      case 'save':
        if (states.isEmpty) return;
        await Future.wait(states.map((s) => s.saveFromKeyboard()));
        return;
      case 'cancel':
        if (states.isEmpty) return;
        for (final state in states) {
          state.cancelEditingFromKeyboard();
        }
        return;
      case 'delete':
        _handleDeleteOnSelectedRow();
        return;
      default:
        return;
    }
  }

  Future<void> _insertDraft() async {
    final missing = <String>[];
    if (_draft.serviceDate == null) missing.add('Fecha');
    if (_draft.clientId == null) missing.add('Empresa');
    if (_draft.materialId == null) missing.add('Material');
    if (missing.isNotEmpty) {
      await _showInsertMissingFieldsDialog(missing);
      return;
    }

    await supa.from('services').insert({
      'service_date': _fmtDbDate(_draft.serviceDate!),
      'due_date': _draft.dueDate == null ? null : _fmtDbDate(_draft.dueDate!),
      'direction': _draft.direction ?? 'recoleccion',
      'status': _draft.status ?? 'programado',
      'client_id': _draft.clientId,
      'material_id': _draft.materialId,
      'driver_employee_id': _draft.driverEmployeeId,
      'vehicle_id': _draft.vehicleId,
      'notes': _draft.notes.trim().isEmpty ? null : _draft.notes.trim(),
      'area': 'LOGISTICA',
      'client_name': _labelOf(_clients, _draft.clientId) ?? 'SIN_CLIENTE',
      'material_type':
          _labelOf(_materials, _draft.materialId) ?? 'SIN_MATERIAL',
    });

    _toast('Servicio agregado');
    _initDraftDefaults();
    await _loadRows();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _insertFocusNode.requestFocus();
    });
  }

  Future<void> _showInsertMissingFieldsDialog(List<String> missing) async {
    final detail = missing.join(', ');
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: BoxDecoration(
                  color: const Color(0xE6EAF2F9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.72)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No se puede agregar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF173248),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completa estos campos primero: $detail',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F3C54),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Entendido'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRow(String id) async {
    await supa.from('services').delete().eq('id', id);
    _toast('Eliminado');
    _bulkSelectedRowIds.remove(id);
    await _loadRows();
  }

  Future<void> _updateRow(String id, Map<String, dynamic> patch) async {
    await supa.from('services').update(patch).eq('id', id);
    // refresco rápido: actualiza local si puedes
    final idx = _rows.indexWhere((r) => r['id'] == id);
    if (idx != -1) {
      setState(() => _rows[idx] = {..._rows[idx], ...patch});
    } else {
      await _loadRows();
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _fmtUiDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  String _fmtCountInt(int value) {
    final raw = value.toString();
    final sign = raw.startsWith('-') ? '-' : '';
    final digits = sign.isEmpty ? raw : raw.substring(1);
    final sb = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final idxFromEnd = digits.length - i;
      sb.write(digits[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        sb.write(',');
      }
    }
    return '$sign$sb';
  }

  String _fmtKg(num value, {int decimals = 2}) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = _fmtCountInt(int.tryParse(parts[0]) ?? 0);
    if (decimals <= 0 || parts.length < 2) return whole;
    return '$whole.${parts[1]}';
  }

  double _numFromAny(dynamic raw) {
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? 0;
  }

  Set<String> _currentSelectionIds() {
    final ids = <String>{};
    final primary = _selectedRowId;
    if (primary != null) ids.add(primary);
    ids.addAll(_bulkSelectedRowIds);
    return ids;
  }

  int get _selectedCount => _currentSelectionIds().length;

  double get _selectedWeightSum {
    final ids = _currentSelectionIds();
    if (ids.isEmpty) return 0;
    var sum = 0.0;
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      if (!ids.contains(id)) continue;
      sum += _numFromAny(row['weight_kg']);
    }
    return sum;
  }

  double get _selectedWeightAvg {
    final count = _selectedCount;
    if (count == 0) return 0;
    return _selectedWeightSum / count;
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.parse(v.substring(0, 4));
      final m = int.parse(v.substring(5, 7));
      final d = int.parse(v.substring(8, 10));
      return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  String? _labelOf(List<_Opt> list, String? id) {
    if (id == null) return null;
    for (final o in list) {
      if (o.id == id) return o.label;
    }
    return null;
  }

  String _uiUpper(String v) => v.replaceAll('_', ' ').toUpperCase();
  String _uiLabel(String v) {
    return v
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  bool get _isDraftCommentFocused => _draftNotesFocusNode.hasFocus;

  bool get _isDraftCommentCaretAtStart {
    if (!_isDraftCommentFocused) return false;
    final sel = _draftNotesC.selection;
    return sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset == 0 &&
        sel.extentOffset == 0;
  }

  bool get _isDraftCommentCaretAtEnd {
    if (!_isDraftCommentFocused) return false;
    final sel = _draftNotesC.selection;
    final end = _draftNotesC.text.length;
    return sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset == end &&
        sel.extentOffset == end;
  }

  void _setActiveInsertColumn(int value) {
    setState(() {
      _activeInsertColumn =
          ((value % _insertColumnCount) + _insertColumnCount) %
          _insertColumnCount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_activeInsertColumn == 7) {
        FocusScope.of(context).requestFocus(_draftNotesFocusNode);
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
        _insertFocusNode.requestFocus();
      }
    });
  }

  void _moveInsertColumn(int delta) {
    _setActiveInsertColumn(_activeInsertColumn + delta);
  }

  int _gridToInsertColumn(int gridColumn) {
    if (gridColumn < 0) return 0;
    if (gridColumn > 8) return 8;
    return gridColumn;
  }

  int _insertToGridColumn(int insertColumn) {
    if (insertColumn < 0) return 0;
    if (insertColumn > 8) return 8;
    return insertColumn;
  }

  void _focusInsertRowFromGrid() {
    setState(() {
      _activeInsertColumn = _gridToInsertColumn(_activeGridColumn);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_activeInsertColumn == 7) {
        FocusScope.of(context).requestFocus(_draftNotesFocusNode);
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
        _insertFocusNode.requestFocus();
      }
    });
  }

  void _focusGridFromInsert() {
    final firstVisibleId = _visibleRows.isEmpty
        ? null
        : _visibleRows.first['id'] as String;
    setState(() {
      _activeGridColumn = _insertToGridColumn(_activeInsertColumn);
      if (firstVisibleId != null) {
        _selectedRowId = firstVisibleId;
        _bulkSelectedRowIds.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowsFocusNode.requestFocus();
      if (firstVisibleId != null) {
        _ensureRowVisible(firstVisibleId);
      }
    });
  }

  Future<String?> _pickInlineOptId({
    required String title,
    required List<_Opt> options,
    required String? currentId,
  }) async {
    return _showSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: currentId,
      options: options
          .map((o) => _PickerOption<String>(value: o.id, label: o.label))
          .toList(),
    );
  }

  Future<String?> _pickInlineString({
    required String title,
    required List<String> options,
    required String? current,
    required String Function(String) format,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (_, i) {
              final value = options[i];
              final selected = value == current;
              return ListTile(
                dense: true,
                title: Text(format(value)),
                trailing: selected ? const Icon(Icons.check, size: 18) : null,
                onTap: () => Navigator.of(dialogContext).pop(value),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickInlineDate(DateTime? current) async {
    return _showGlassDatePickerDialog(
      context,
      initialDate: current ?? DateUtils.dateOnly(DateTime.now()),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    switch (_activeInsertColumn) {
      case 0:
        final d = await _pickInlineDate(_draft.serviceDate);
        if (!mounted || d == null) return;
        setState(() => _draft = _draft.copyWith(serviceDate: d));
        return;
      case 1:
        final id = await _pickInlineOptId(
          title: 'Empresa',
          options: _clients,
          currentId: _draft.clientId,
        );
        if (!mounted || id == null) return;
        setState(() => _draft = _draft.copyWith(clientId: id));
        return;
      case 2:
        final id = await _pickInlineOptId(
          title: 'Material',
          options: _materials,
          currentId: _draft.materialId,
        );
        if (!mounted || id == null) return;
        setState(() => _draft = _draft.copyWith(materialId: id));
        return;
      case 3:
        final v = await _pickInlineString(
          title: 'Tipo',
          options: _directions,
          current: _draft.direction,
          format: _uiLabel,
        );
        if (!mounted || v == null) return;
        setState(() => _draft = _draft.copyWith(direction: v));
        return;
      case 4:
        final id = await _pickInlineOptId(
          title: 'Chofer',
          options: _drivers,
          currentId: _draft.driverEmployeeId,
        );
        if (!mounted || id == null) return;
        setState(() => _draft = _draft.copyWith(driverEmployeeId: id));
        return;
      case 5:
        final id = await _pickInlineOptId(
          title: 'Unidad',
          options: _vehicles,
          currentId: _draft.vehicleId,
        );
        if (!mounted || id == null) return;
        setState(() => _draft = _draft.copyWith(vehicleId: id));
        return;
      case 6:
        final d = await _pickInlineDate(_draft.dueDate);
        if (!mounted || d == null) return;
        setState(() => _draft = _draft.copyWith(dueDate: d));
        return;
      case 7:
        _setActiveInsertColumn(7);
        return;
      case 8:
        final v = await _pickInlineString(
          title: 'Estado',
          options: _statuses,
          current: _draft.status,
          format: _uiLabel,
        );
        if (!mounted || v == null) return;
        setState(() => _draft = _draft.copyWith(status: v));
        return;
      case 9:
        await _insertDraft();
        return;
      default:
        return;
    }
  }

  void _clearActiveInsertCell() {
    switch (_activeInsertColumn) {
      case 0:
        setState(() => _draft = _draft.copyWith(serviceDate: null));
        return;
      case 1:
        setState(() => _draft = _draft.copyWith(clientId: null));
        return;
      case 2:
        setState(() => _draft = _draft.copyWith(materialId: null));
        return;
      case 3:
        setState(() => _draft = _draft.copyWith(direction: null));
        return;
      case 4:
        setState(() => _draft = _draft.copyWith(driverEmployeeId: null));
        return;
      case 5:
        setState(() => _draft = _draft.copyWith(vehicleId: null));
        return;
      case 6:
        setState(() => _draft = _draft.copyWith(dueDate: null));
        return;
      case 7:
        _draftNotesC.clear();
        setState(() => _draft = _draft.copyWith(notes: ''));
        return;
      case 8:
        setState(() => _draft = _draft.copyWith(status: null));
        return;
      default:
        return;
    }
  }

  Widget _buildInlineInsertRow() {
    return Card(
      elevation: 0.4,
      color: _insertRowActive
          ? const Color(0xFFD9ECFA)
          : const Color(0xFFE7F1F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _insertRowActive
              ? const Color(0xFF3C8DCC).withOpacity(0.55)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget insertCellFrame(int columnIndex, Widget child) {
              final active = _activeInsertColumn == columnIndex;
              if (!active) return child;
              return DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0B72FF).withOpacity(0.80),
                    width: 1.15,
                  ),
                ),
                child: child,
              );
            }

            return Focus(
              focusNode: _insertFocusNode,
              autofocus: false,
              onKeyEvent: (_, event) {
                if (_isEditableTextFocused()) {
                  return KeyEventResult.ignored;
                }
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.arrowLeft) {
                  if (_isDraftCommentFocused && !_isDraftCommentCaretAtStart) {
                    return KeyEventResult.ignored;
                  }
                  _moveInsertColumn(-1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  if (_isDraftCommentFocused && !_isDraftCommentCaretAtEnd) {
                    return KeyEventResult.ignored;
                  }
                  _moveInsertColumn(1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  // Top boundary: insert row is the highest keyboard row.
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  _focusGridFromInsert();
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.space) {
                  if (_isDraftCommentFocused) {
                    return KeyEventResult.ignored;
                  }
                  unawaited(_activateInsertCellFromKeyboard());
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.delete ||
                    key == LogicalKeyboardKey.backspace) {
                  if (_isDraftCommentFocused) {
                    return KeyEventResult.ignored;
                  }
                  _clearActiveInsertCell();
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  unawaited(_insertDraft());
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SizedBox(
                width: constraints.maxWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: _kTableContentW,
                    child: Row(
                      children: [
                        insertCellFrame(
                          0,
                          SizedBox(
                            width: 90,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                _setActiveInsertColumn(0);
                                final d = await _pickInlineDate(
                                  _draft.serviceDate,
                                );
                                if (!mounted || d == null) return;
                                setState(
                                  () =>
                                      _draft = _draft.copyWith(serviceDate: d),
                                );
                              },
                              onLongPress: () => setState(
                                () =>
                                    _draft = _draft.copyWith(serviceDate: null),
                              ),
                              child: InputDecorator(
                                decoration: _glassFieldDecoration(),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _FitText(
                                        _draft.serviceDate == null
                                            ? '—'
                                            : _fmtUiDate(_draft.serviceDate!),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_month, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        insertCellFrame(
                          1,
                          SizedBox(
                            width: 190,
                            child: _DropOptInline(
                              valueId: _draft.clientId,
                              items: _clients,
                              onTapStart: () => _setActiveInsertColumn(1),
                              onChanged: (id) => setState(
                                () => _draft = _draft.copyWith(clientId: id),
                              ),
                            ),
                          ),
                        ),
                        insertCellFrame(
                          2,
                          SizedBox(
                            width: 190,
                            child: _DropOptInline(
                              valueId: _draft.materialId,
                              items: _materials,
                              onTapStart: () => _setActiveInsertColumn(2),
                              onChanged: (id) => setState(
                                () => _draft = _draft.copyWith(materialId: id),
                              ),
                            ),
                          ),
                        ),
                        insertCellFrame(
                          3,
                          SizedBox(
                            width: 130,
                            child: _DropStrInline(
                              value: _draft.direction ?? _directions.first,
                              items: _directions,
                              format: _uiLabel,
                              onTapStart: () => _setActiveInsertColumn(3),
                              onChanged: (v) => setState(
                                () => _draft = _draft.copyWith(direction: v),
                              ),
                            ),
                          ),
                        ),
                        insertCellFrame(
                          4,
                          SizedBox(
                            width: 190,
                            child: _DropOptInline(
                              valueId: _draft.driverEmployeeId,
                              items: _drivers,
                              onTapStart: () => _setActiveInsertColumn(4),
                              onChanged: (id) => setState(
                                () => _draft = _draft.copyWith(
                                  driverEmployeeId: id,
                                ),
                              ),
                            ),
                          ),
                        ),
                        insertCellFrame(
                          5,
                          SizedBox(
                            width: 140,
                            child: _DropOptInline(
                              valueId: _draft.vehicleId,
                              items: _vehicles,
                              onTapStart: () => _setActiveInsertColumn(5),
                              onChanged: (id) => setState(
                                () => _draft = _draft.copyWith(vehicleId: id),
                              ),
                            ),
                          ),
                        ),
                        insertCellFrame(
                          6,
                          SizedBox(
                            width: 130,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                _setActiveInsertColumn(6);
                                final d = await _pickInlineDate(_draft.dueDate);
                                if (!mounted || d == null) return;
                                setState(
                                  () => _draft = _draft.copyWith(dueDate: d),
                                );
                              },
                              onLongPress: () => setState(
                                () => _draft = _draft.copyWith(dueDate: null),
                              ),
                              child: InputDecorator(
                                decoration: _glassFieldDecoration(),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _FitText(
                                        _draft.dueDate == null
                                            ? '—'
                                            : _fmtUiDate(_draft.dueDate!),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        insertCellFrame(
                          7,
                          SizedBox(
                            width: _kCommentColW,
                            child: Focus(
                              onKeyEvent: (_, event) {
                                if (event is! KeyDownEvent) {
                                  return KeyEventResult.ignored;
                                }
                                final key = event.logicalKey;
                                if (key == LogicalKeyboardKey.enter ||
                                    key == LogicalKeyboardKey.numpadEnter) {
                                  unawaited(_insertDraft());
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: _draftNotesC,
                                focusNode: _draftNotesFocusNode,
                                decoration: _glassFieldDecoration(),
                                onTap: () {
                                  if (!_draftNotesFocusNode.hasFocus) {
                                    _draftNotesFocusNode.requestFocus();
                                  }
                                },
                                onChanged: (t) => setState(
                                  () => _draft = _draft.copyWith(notes: t),
                                ),
                                onSubmitted: (_) {
                                  _insertDraft();
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        insertCellFrame(
                          8,
                          SizedBox(
                            width: _kActionsW,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: _kActionsW - 50,
                                  child: _DropStrInline(
                                    value: _draft.status ?? _statuses.first,
                                    items: _statuses,
                                    format: _uiLabel,
                                    onTapStart: () => _setActiveInsertColumn(8),
                                    onChanged: (v) => setState(
                                      () => _draft = _draft.copyWith(status: v),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                insertCellFrame(
                                  9,
                                  Tooltip(
                                    message: 'AGREGAR',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: _insertDraft,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF19C37D,
                                          ).withOpacity(0.92),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.52,
                                            ),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildServicesTopActionsBar() {
    final cellMode = _gridEditMode || (_selectedRowState()?.isEditing ?? false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Card(
        elevation: 0,
        color: Colors.white.withOpacity(0.34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: _actionOutlinedButtonStyle(),
                      onPressed: _exportingCsv ? null : _exportServicesCsv,
                      icon: Icon(
                        _exportingCsv
                            ? Icons.hourglass_top
                            : Icons.download_rounded,
                      ),
                      label: const Text('Descargar CSV'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: _actionOutlinedButtonStyle(),
                      onPressed: () => setState(() {
                        _gridEditMode = !_gridEditMode;
                        if (_gridEditMode) {
                          _activeGridColumn = 0;
                          _ensureGridSelection();
                        } else {
                          _gridCancelSignal++;
                        }
                      }),
                      icon: Icon(
                        _gridEditMode
                            ? Icons.grid_off
                            : Icons.grid_view_rounded,
                      ),
                      label: Text(
                        _gridEditMode
                            ? 'Salir de cuadrícula'
                            : 'Edición en cuadrícula',
                      ),
                    ),
                    if (_gridEditMode) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: _actionFilledButtonStyle(),
                        onPressed: () => setState(() {
                          _gridSaveSignal++;
                          _gridEditMode = false;
                        }),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar'),
                      ),
                    ],
                    if (_selectedCount > 0) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: _actionFilledButtonStyle(),
                        onPressed: _bulkDeleting ? null : _deleteSelectedRows,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          'Eliminar (${_fmtCountInt(_selectedCount)})',
                        ),
                      ),
                    ],
                  ],
                ),
              );

              final info = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_fmtCountInt(_selectedCount)} seleccionadas',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_selectedCount > 0)
                    Text(
                      'Suma: ${_fmtKg(_selectedWeightSum)} kg · Promedio: ${_fmtKg(_selectedWeightAvg)} kg',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                  if (cellMode)
                    Text(
                      'Celda: $_activeGridColumnLabel · Space',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                ],
              );

              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: actions),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: actions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  info,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ServicesShell(
      headerTitle: 'Programación de Viajes y Servicios',
      activeOverlayModule: ServicesOverlayNavModule.servicios,
      onLogout: () async {
        final ok = await _showGlassConfirmDialog(
          context,
          title: 'Cerrar sesión',
          content: '¿Seguro que deseas cerrar tu sesión?',
          confirmText: 'Cerrar sesión',
        );
        if (ok != true) return;
        await supa.auth.signOut();
        if (!mounted) return;
        _toast('Sesión cerrada');
        Navigator.of(this.context).pushAndRemoveUntil(
          appPageRoute(page: const AuthGate()),
          (_) => false,
        );
      },
      onGoToOperacion: () async {
        final user = supa.auth.currentUser;
        final email = user?.email?.toLowerCase();
        final allowed = {'operacion@dicsamx.com', 'administracion@dicsamx.com'};
        if (email == null || !allowed.contains(email)) {
          _toast('Acceso no autorizado');
          return;
        }

        if (!mounted) return;
        final nav = Navigator.of(this.context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          nav.pushReplacement(
            appPageRoute(
              page: const DashboardPage(instantOpen: true),
              duration: const Duration(milliseconds: 420),
              reverseDuration: const Duration(milliseconds: 360),
            ),
          );
        }
      },
      onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
      onGoToProduction: _goToProduction,
      onGoToServices: () async {},
      onGoToWeighings: _goToWeighings,
      onGoToMaintenance: _goToMaintenance,
      onGoToCatalogs: null,
      topContent: _loadingCats || _loadingRows
          ? null
          : _buildServicesTopActionsBar(),
      child: _loadingCats || _loadingRows
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== rows =====
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: constraints.maxHeight,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: _HeaderRow(
                                hasActiveFilter: _hasActiveFilter,
                                onOpenFilter: _openColumnFilter,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: _buildInlineInsertRow(),
                            ),
                            Expanded(
                              child: Focus(
                                focusNode: _rowsFocusNode,
                                autofocus: false,
                                onKeyEvent: (_, event) {
                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  final key = event.logicalKey;
                                  final editingAnyRow =
                                      _selectedRowState()?.isEditing ?? false;
                                  final keyboardCellMode =
                                      _gridEditMode || editingAnyRow;
                                  final allowVerticalCellNavigation =
                                      _gridEditMode ||
                                      _hasExplicitMultiSelection;
                                  final selectedState = _selectedRowState();
                                  final firstVisibleRowId = _visibleRows.isEmpty
                                      ? null
                                      : _visibleRows.first['id'] as String;
                                  final isAtFirstVisibleRow =
                                      firstVisibleRowId != null &&
                                      _selectedRowId == firstVisibleRowId;
                                  final inCommentTextEditing =
                                      _activeGridColumn == 7 &&
                                      (selectedState?.isCommentFocused ??
                                          false);
                                  final commentCaretAtStart =
                                      inCommentTextEditing &&
                                      (selectedState?.isCommentCaretAtStart ??
                                          false);
                                  final commentCaretAtEnd =
                                      inCommentTextEditing &&
                                      (selectedState?.isCommentCaretAtEnd ??
                                          false);
                                  final anyTextEditingFocused =
                                      _isEditableTextFocused();
                                  if (anyTextEditingFocused) {
                                    if (key == LogicalKeyboardKey.space) {
                                      return KeyEventResult.ignored;
                                    }
                                    if (key == LogicalKeyboardKey.arrowLeft) {
                                      if (commentCaretAtStart) {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        _moveGridColumn(-1);
                                        _rowsFocusNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    }
                                    if (key == LogicalKeyboardKey.arrowRight) {
                                      if (commentCaretAtEnd) {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        _moveGridColumn(1);
                                        _rowsFocusNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    }
                                    return KeyEventResult.ignored;
                                  }
                                  if (keyboardCellMode) {
                                    if (key == LogicalKeyboardKey.arrowRight) {
                                      if (inCommentTextEditing) {
                                        return KeyEventResult.ignored;
                                      }
                                      _moveGridColumn(1);
                                      return KeyEventResult.handled;
                                    }
                                    if (key == LogicalKeyboardKey.arrowLeft) {
                                      if (inCommentTextEditing) {
                                        return KeyEventResult.ignored;
                                      }
                                      _moveGridColumn(-1);
                                      return KeyEventResult.handled;
                                    }
                                    if (key == LogicalKeyboardKey.arrowDown) {
                                      if (allowVerticalCellNavigation) {
                                        _moveGridRow(1);
                                      } else {
                                        _moveSelectedRow(1);
                                      }
                                      return KeyEventResult.handled;
                                    }
                                    if (key == LogicalKeyboardKey.arrowUp) {
                                      if (!_hasExplicitMultiSelection &&
                                          isAtFirstVisibleRow) {
                                        _focusInsertRowFromGrid();
                                        return KeyEventResult.handled;
                                      }
                                      if (allowVerticalCellNavigation) {
                                        _moveGridRow(-1);
                                      } else {
                                        _moveSelectedRow(-1);
                                      }
                                      return KeyEventResult.handled;
                                    }
                                    if (key == LogicalKeyboardKey.space) {
                                      if (inCommentTextEditing) {
                                        return KeyEventResult.ignored;
                                      }
                                      _activateGridCellFromKeyboard();
                                      return KeyEventResult.handled;
                                    }
                                    if (key == LogicalKeyboardKey.enter ||
                                        key == LogicalKeyboardKey.numpadEnter) {
                                      if (_gridEditMode) {
                                        setState(() {
                                          _gridSaveSignal++;
                                          _gridEditMode = false;
                                        });
                                      } else {
                                        _handleEnterOnSelectedRow();
                                      }
                                      return KeyEventResult.handled;
                                    }
                                    if (key == LogicalKeyboardKey.escape) {
                                      if (_gridEditMode) {
                                        setState(() {
                                          _gridCancelSignal++;
                                          _gridEditMode = false;
                                        });
                                      } else {
                                        _handleEscapeOnSelectedRow();
                                      }
                                      return KeyEventResult.handled;
                                    }
                                    if (key == LogicalKeyboardKey.delete ||
                                        key == LogicalKeyboardKey.backspace) {
                                      if (!_gridEditMode) {
                                        return KeyEventResult.ignored;
                                      }
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  if (key == LogicalKeyboardKey.arrowDown) {
                                    if (_isCtrlOrCmdPressed()) {
                                      _extendSelectionWithArrow(1);
                                    } else {
                                      _moveSelectedRow(1);
                                    }
                                    return KeyEventResult.handled;
                                  }
                                  if (key == LogicalKeyboardKey.arrowUp) {
                                    if (_isCtrlOrCmdPressed()) {
                                      _extendSelectionWithArrow(-1);
                                    } else if (firstVisibleRowId == null ||
                                        _selectedRowId == null ||
                                        isAtFirstVisibleRow) {
                                      _focusInsertRowFromGrid();
                                    } else {
                                      _moveSelectedRow(-1);
                                    }
                                    return KeyEventResult.handled;
                                  }
                                  if (key == LogicalKeyboardKey.enter ||
                                      key == LogicalKeyboardKey.numpadEnter) {
                                    _handleEnterOnSelectedRow();
                                    return KeyEventResult.handled;
                                  }
                                  if (key == LogicalKeyboardKey.escape) {
                                    _handleEscapeOnSelectedRow();
                                    return KeyEventResult.handled;
                                  }
                                  if (key == LogicalKeyboardKey.delete ||
                                      key == LogicalKeyboardKey.backspace) {
                                    _handleDeleteOnSelectedRow();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: _visibleRows.isEmpty
                                    ? Center(
                                        child: Text(
                                          _uiUpper('No hay servicios todavía'),
                                        ),
                                      )
                                    : Listener(
                                        behavior: HitTestBehavior.translucent,
                                        onPointerDown: (event) =>
                                            _startMarqueeSelection(
                                              event.localPosition,
                                            ),
                                        onPointerMove: (event) =>
                                            _updateMarqueeSelection(
                                              event.localPosition,
                                            ),
                                        onPointerUp: (_) =>
                                            _endMarqueeSelection(),
                                        onPointerCancel: (_) =>
                                            _endMarqueeSelection(),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onSecondaryTapDown: (details) {
                                            if (_selectedCount <= 0) return;
                                            unawaited(
                                              _openRowsContextMenuAt(
                                                details.globalPosition,
                                              ),
                                            );
                                          },
                                          child: Stack(
                                            key: _rowsViewportKey,
                                            children: [
                                              Positioned.fill(
                                                child: AbsorbPointer(
                                                  absorbing: _marqueeActive,
                                                  child: ListView.builder(
                                                    controller:
                                                        _rowsScrollController,
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          0,
                                                          12,
                                                          20,
                                                        ),
                                                    itemCount:
                                                        _visibleRows.length,
                                                    itemBuilder: (_, i) {
                                                      final row =
                                                          _visibleRows[i];
                                                      final rowId =
                                                          row['id'] as String;
                                                      return _ServiceDataRow(
                                                        key: _rowKeyFor(rowId),
                                                        row: row,
                                                        clients: _clients,
                                                        materials: _materials,
                                                        drivers: _drivers,
                                                        vehicles: _vehicles,
                                                        directions: _directions,
                                                        statuses: _statuses,
                                                        uiLabel: _uiLabel,
                                                        parseDate: _parseDate,
                                                        fmtDateDb: _fmtDbDate,
                                                        fmtDateUi: _fmtUiDate,
                                                        onDelete: _deleteRow,
                                                        onUpdate: _updateRow,
                                                        isSelected:
                                                            _selectedRowId ==
                                                            rowId,
                                                        isChecked:
                                                            _bulkSelectedRowIds
                                                                .contains(
                                                                  rowId,
                                                                ),
                                                        gridEditMode:
                                                            _gridEditMode,
                                                        gridSaveSignal:
                                                            _gridSaveSignal,
                                                        gridCancelSignal:
                                                            _gridCancelSignal,
                                                        activeGridColumn:
                                                            _activeGridColumn,
                                                        showRowActions: true,
                                                        onOpenContextMenu:
                                                            (position) =>
                                                                _openRowsContextMenuAt(
                                                                  position,
                                                                  rowId: rowId,
                                                                ),
                                                        onSelect: (additive) =>
                                                            _selectRow(
                                                              rowId,
                                                              allowToggle:
                                                                  false,
                                                              additive:
                                                                  additive,
                                                              ensureVisible:
                                                                  false,
                                                            ),
                                                        onActivateColumn:
                                                            (columnIndex) {
                                                              _selectRow(
                                                                rowId,
                                                                allowToggle:
                                                                    false,
                                                                additive: false,
                                                                ensureVisible:
                                                                    false,
                                                              );
                                                              setState(() {
                                                                _activeGridColumn =
                                                                    columnIndex;
                                                              });
                                                            },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              if (_marqueeActive)
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: CustomPaint(
                                                      painter: _MarqueeSelectionPainter(
                                                        rect: _clampRectToViewport(
                                                          _marqueeRectForPaint(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                              child: Card(
                                elevation: 0,
                                color: Colors.white.withOpacity(0.30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      OutlinedButton.icon(
                                        style: _actionOutlinedButtonStyle(),
                                        onPressed: _currentPage > 0
                                            ? () =>
                                                  setState(() => _currentPage--)
                                            : null,
                                        icon: const Icon(Icons.chevron_left),
                                        label: const Text('Anterior'),
                                      ),
                                      Text(
                                        'Página ${_fmtCountInt(_currentPage + 1)} de ${_fmtCountInt(_totalPages)}',
                                      ),
                                      OutlinedButton.icon(
                                        style: _actionOutlinedButtonStyle(),
                                        onPressed:
                                            _currentPage < _totalPages - 1
                                            ? () =>
                                                  setState(() => _currentPage++)
                                            : null,
                                        icon: const Icon(Icons.chevron_right),
                                        label: const Text('Siguiente'),
                                      ),
                                      const Text('Filas/pág:'),
                                      SizedBox(
                                        width: 90,
                                        child: DropdownButtonFormField<int>(
                                          value: _pageSize,
                                          isDense: true,
                                          decoration: _glassFieldDecoration(),
                                          items: const [40, 80, 120]
                                              .map(
                                                (s) => DropdownMenuItem<int>(
                                                  value: s,
                                                  child: Text('$s'),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setState(() {
                                              _pageSize = v;
                                              _currentPage = 0;
                                              _clampCurrentPage();
                                            });
                                          },
                                        ),
                                      ),
                                      Text(
                                        'Total: ${_fmtCountInt(_filteredRows.length)}',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ====== header visual ======
class _HeaderRow extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final void Function(String columnId, String label) onOpenFilter;

  const _HeaderRow({required this.hasActiveFilter, required this.onOpenFilter});

  @override
  Widget build(BuildContext context) {
    TextStyle s = const TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    return Card(
      elevation: 0,
      color: Colors.black.withOpacity(0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _kTableContentW,
                  child: Row(
                    children: [
                      _HCell(
                        'FECHA',
                        90,
                        s,
                        active: hasActiveFilter('fecha'),
                        onFilter: () => onOpenFilter('fecha', 'FECHA'),
                      ),
                      _HCell(
                        'EMPRESA',
                        190,
                        s,
                        active: hasActiveFilter('empresa'),
                        onFilter: () => onOpenFilter('empresa', 'EMPRESA'),
                      ),
                      _HCell(
                        'MATERIAL',
                        190,
                        s,
                        active: hasActiveFilter('material'),
                        onFilter: () => onOpenFilter('material', 'MATERIAL'),
                      ),
                      _HCell(
                        'TIPO',
                        130,
                        s,
                        active: hasActiveFilter('tipo'),
                        onFilter: () => onOpenFilter('tipo', 'TIPO'),
                      ),
                      _HCell(
                        'CHOFER',
                        190,
                        s,
                        active: hasActiveFilter('chofer'),
                        onFilter: () => onOpenFilter('chofer', 'CHOFER'),
                      ),
                      _HCell(
                        'UNIDAD',
                        140,
                        s,
                        active: hasActiveFilter('unidad'),
                        onFilter: () => onOpenFilter('unidad', 'UNIDAD'),
                      ),
                      _HCell(
                        'PARA EL DÍA',
                        130,
                        s,
                        active: hasActiveFilter('para_dia'),
                        onFilter: () => onOpenFilter('para_dia', 'PARA EL DÍA'),
                      ),
                      SizedBox(
                        width: _kCommentColW,
                        child: _HCellExpand(
                          'COMENTARIO',
                          s,
                          active: hasActiveFilter('comentario'),
                          onFilter: () =>
                              onOpenFilter('comentario', 'COMENTARIO'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: _kActionsW,
                        child: Row(
                          children: [
                            Expanded(
                              child: _HCellExpand(
                                'ESTADO',
                                s,
                                active: hasActiveFilter('estado'),
                                onFilter: () =>
                                    onOpenFilter('estado', 'ESTADO'),
                              ),
                            ),
                            const SizedBox(width: 34),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  final String t;
  final double w;
  final TextStyle s;
  final bool active;
  final VoidCallback onFilter;
  const _HCell(
    this.t,
    this.w,
    this.s, {
    required this.active,
    required this.onFilter,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      child: _HCellExpand(t, s, active: active, onFilter: onFilter),
    );
  }
}

class _HCellExpand extends StatelessWidget {
  final String t;
  final TextStyle s;
  final bool active;
  final VoidCallback onFilter;
  const _HCellExpand(
    this.t,
    this.s, {
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onFilter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active
                  ? _kFilterAccent
                  : _kFilterAccentSoft.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? _kFilterAccent.withOpacity(0.55)
                    : const Color(0xFF0B2B2B).withOpacity(0.15),
              ),
            ),
            child: Icon(
              active ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 15,
              color: active ? Colors.white : const Color(0xFF2A4B49),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(t, style: s, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ====== row editable ======
class _ServiceDataRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<_Opt> clients;
  final List<_Opt> materials;
  final List<_Opt> drivers;
  final List<_Opt> vehicles;
  final List<String> directions;
  final List<String> statuses;

  final String Function(String) uiLabel;
  final DateTime Function(dynamic) parseDate;
  final String Function(DateTime) fmtDateDb;
  final String Function(DateTime) fmtDateUi;

  final Future<void> Function(String id) onDelete;
  final Future<void> Function(String id, Map<String, dynamic> patch) onUpdate;
  final bool isSelected;
  final bool isChecked;
  final bool gridEditMode;
  final int gridSaveSignal;
  final int gridCancelSignal;
  final int activeGridColumn;
  final bool showRowActions;
  final ValueChanged<Offset>? onOpenContextMenu;
  final ValueChanged<bool> onSelect;
  final ValueChanged<int> onActivateColumn;

  const _ServiceDataRow({
    super.key,
    required this.row,
    required this.clients,
    required this.materials,
    required this.drivers,
    required this.vehicles,
    required this.directions,
    required this.statuses,
    required this.uiLabel,
    required this.parseDate,
    required this.fmtDateDb,
    required this.fmtDateUi,
    required this.onDelete,
    required this.onUpdate,
    required this.isSelected,
    required this.isChecked,
    required this.gridEditMode,
    required this.gridSaveSignal,
    required this.gridCancelSignal,
    required this.activeGridColumn,
    required this.showRowActions,
    this.onOpenContextMenu,
    required this.onSelect,
    required this.onActivateColumn,
  });

  @override
  State<_ServiceDataRow> createState() => _ServiceDataRowState();
}

class _ServiceDataRowState extends State<_ServiceDataRow> {
  bool _editing = false;
  bool _hovering = false;
  int? _hoveredEditableColumn;
  bool _hoverActionsButton = false;

  late DateTime _serviceDate;
  DateTime? _dueDate;

  String? _clientId;
  String? _materialId;
  String _direction = 'recoleccion';
  String _status = 'programado';

  String? _driverId;
  String? _vehicleId;
  late TextEditingController _notes;
  final FocusNode _notesFocusNode = FocusNode(debugLabel: 'row_notes_focus');

  String get id => widget.row['id'] as String;
  bool get isEditing => _editing;
  String get commentText => _notes.text;
  bool get isCommentFocused => _notesFocusNode.hasFocus;
  bool get isCommentCaretAtStart {
    if (!_notesFocusNode.hasFocus) return false;
    final sel = _notes.selection;
    return sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset == 0 &&
        sel.extentOffset == 0;
  }

  bool get isCommentCaretAtEnd {
    if (!_notesFocusNode.hasFocus) return false;
    final sel = _notes.selection;
    final end = _notes.text.length;
    return sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset == end &&
        sel.extentOffset == end;
  }

  @override
  void initState() {
    super.initState();
    _syncFromRow();
  }

  void _syncFromRow() {
    final r = widget.row;
    _serviceDate = widget.parseDate(r['service_date']);
    _dueDate = (r['due_date'] == null) ? null : widget.parseDate(r['due_date']);

    _clientId = r['client_id'] as String?;
    _materialId = r['material_id'] as String?;

    _direction = (r['direction'] as String?) ?? 'recoleccion';
    _status = (r['status'] as String?) ?? 'programado';

    _driverId = r['driver_employee_id'] as String?;
    _vehicleId = r['vehicle_id'] as String?;

    _notes = TextEditingController(text: (r['notes'] ?? '') as String);
    _editing = widget.gridEditMode;
  }

  @override
  void didUpdateWidget(covariant _ServiceDataRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gridEditMode != oldWidget.gridEditMode) {
      if (widget.gridEditMode) {
        _setEditing(true);
      } else {
        _setEditing(false);
      }
    }
    if (widget.gridSaveSignal != oldWidget.gridSaveSignal) {
      unawaited(_save(keepEditing: false));
    }
    if (widget.gridCancelSignal != oldWidget.gridCancelSignal) {
      setState(() {
        _notes.dispose();
        _syncFromRow();
      });
    }
  }

  @override
  void dispose() {
    _notesFocusNode.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setEditing(bool v) => setState(() => _editing = v);

  void startEditingFromKeyboard() {
    if (_editing) return;
    _setEditing(true);
  }

  void cancelEditingFromKeyboard() {
    if (!_editing) return;
    setState(() {
      _notes.dispose();
      _syncFromRow();
      _editing = false;
    });
  }

  Future<void> saveFromKeyboard() async {
    if (!_editing) return;
    await _save();
  }

  Future<void> deleteWithConfirmation() async {
    final ok = await _showGlassConfirmDialog(
      context,
      title: 'Eliminar servicio',
      content: '¿Seguro que quieres eliminarlo?',
      confirmText: 'Eliminar',
    );
    if (!mounted) return;
    if (ok == true) {
      await widget.onDelete(id);
    }
  }

  Future<void> activateGridCell(int columnIndex) async {
    if (!_editing) return;
    switch (columnIndex) {
      case 0:
        await _pickServiceDate();
        return;
      case 1:
        final next = await _pickOptId(
          title: 'Empresa',
          options: widget.clients,
          currentId: _clientId,
        );
        if (!mounted || next == null) return;
        setState(() => _clientId = next);
        return;
      case 2:
        final next = await _pickOptId(
          title: 'Material',
          options: widget.materials,
          currentId: _materialId,
        );
        if (!mounted || next == null) return;
        setState(() => _materialId = next);
        return;
      case 3:
        final next = await _pickStringOption(
          title: 'Tipo',
          options: widget.directions,
          current: _direction,
          format: widget.uiLabel,
        );
        if (!mounted || next == null) return;
        setState(() => _direction = next);
        return;
      case 4:
        final next = await _pickOptId(
          title: 'Chofer',
          options: widget.drivers,
          currentId: _driverId,
        );
        if (!mounted || next == null) return;
        setState(() => _driverId = next);
        return;
      case 5:
        final next = await _pickOptId(
          title: 'Unidad',
          options: widget.vehicles,
          currentId: _vehicleId,
        );
        if (!mounted || next == null) return;
        setState(() => _vehicleId = next);
        return;
      case 6:
        await _pickDueDate();
        return;
      case 8:
        final next = await _pickStringOption(
          title: 'Estado',
          options: widget.statuses,
          current: _status,
          format: widget.uiLabel,
        );
        if (!mounted || next == null) return;
        setState(() => _status = next);
        return;
      case 7:
        focusCommentField();
        return;
      default:
        return;
    }
  }

  void focusCommentField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_notesFocusNode);
      _notes.selection = TextSelection.collapsed(offset: _notes.text.length);
    });
  }

  Future<String?> _pickOptId({
    required String title,
    required List<_Opt> options,
    required String? currentId,
  }) async {
    return _showSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: currentId,
      options: options
          .map((o) => _PickerOption<String>(value: o.id, label: o.label))
          .toList(),
    );
  }

  Future<String?> _pickStringOption({
    required String title,
    required List<String> options,
    required String current,
    required String Function(String) format,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final value = options[i];
                final selected = value == current;
                return ListTile(
                  dense: true,
                  title: Text(format(value)),
                  trailing: selected ? const Icon(Icons.check, size: 18) : null,
                  onTap: () => Navigator.of(dialogContext).pop(value),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _save({bool keepEditing = false}) async {
    final patch = <String, dynamic>{
      'service_date': widget.fmtDateDb(_serviceDate),
      'due_date': _dueDate == null ? null : widget.fmtDateDb(_dueDate!),
      'direction': _direction,
      'status': _status,
      'client_id': _clientId,
      'material_id': _materialId,
      'driver_employee_id': _driverId,
      'vehicle_id': _vehicleId,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),

      // compat legacy si tu tabla aún los tiene NOT NULL
      'client_name': _labelOf(widget.clients, _clientId) ?? 'SIN_CLIENTE',
      'material_type':
          _labelOf(widget.materials, _materialId) ?? 'SIN_MATERIAL',
    };

    await widget.onUpdate(id, patch);
    _setEditing(keepEditing);
  }

  String? _labelOf(List<_Opt> list, String? id) {
    if (id == null) return null;
    for (final o in list) {
      if (o.id == id) return o.label;
    }
    return null;
  }

  Future<void> _pickServiceDate() async {
    final picked = await _pickDateWithKeyboard(_serviceDate);
    if (picked != null) {
      setState(() => _serviceDate = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await _pickDateWithKeyboard(_dueDate ?? _serviceDate);
    if (picked != null) setState(() => _dueDate = DateUtils.dateOnly(picked));
  }

  Future<DateTime?> _pickDateWithKeyboard(DateTime initialDate) async {
    return _showGlassDatePickerDialog(
      context,
      initialDate: initialDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
  }

  bool _isAdditiveSelectionPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  @override
  Widget build(BuildContext context) {
    final isPrimarySelected = widget.isSelected;
    final isMultiSelected = widget.isChecked;
    final hasSelection = isPrimarySelected || isMultiSelected;
    final hoverOnly = _hovering && !hasSelection;
    final highlighted = hasSelection || _hovering;
    final rowBg = _editing
        ? const Color(0xFFCBEFE2)
        : hasSelection
        ? const Color(0xFF00A3FF).withOpacity(isPrimarySelected ? 0.16 : 0.13)
        : hoverOnly
        ? const Color(0xFFE9F7EE)
        : Colors.white;
    Widget gridCellFrame(int columnIndex, Widget child) {
      final active =
          _editing &&
          widget.isSelected &&
          widget.activeGridColumn == columnIndex;
      if (!active) return child;
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF0B72FF).withOpacity(0.85),
            width: 1.2,
          ),
        ),
        child: child,
      );
    }

    void previewEditableCellTap(int col) {
      if (_isAdditiveSelectionPressed()) {
        widget.onSelect(true);
        return;
      }
      widget.onSelect(false);
      widget.onActivateColumn(col);
    }

    void enterEditingFromPointer(int col) {
      if (_isAdditiveSelectionPressed()) {
        widget.onSelect(true);
        return;
      }
      widget.onSelect(false);
      widget.onActivateColumn(col);
      if (!_editing) {
        setState(() => _editing = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(activateGridCell(col));
      });
    }

    Widget previewEditableCell({required int col, required Widget child}) {
      final hovered = !_editing && _hoveredEditableColumn == col;
      final top = hasSelection
          ? const Color(0xFFD9EBFB).withOpacity(0.64)
          : const Color(0xFFDDEFE6).withOpacity(0.84);
      final bottom = hasSelection
          ? const Color(0xFFCCE5FA).withOpacity(0.42)
          : const Color(0xFFCFE8DD).withOpacity(0.56);
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (_editing) return;
          if (_hoveredEditableColumn != col) {
            setState(() => _hoveredEditableColumn = col);
          }
        },
        onExit: (_) {
          if (_hoveredEditableColumn == col) {
            setState(() => _hoveredEditableColumn = null);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: hovered
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top, bottom],
                  )
                : null,
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF7FCBAA).withOpacity(0.22),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (event.buttons != kPrimaryMouseButton) return;
              previewEditableCellTap(col);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => enterEditingFromPointer(col),
              child: child,
            ),
          ),
        ),
      );
    }

    Widget readonlyCell({
      required Widget child,
      bool showDivider = true,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 4),
    }) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: child),
            if (showDivider)
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.only(left: 8, right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D5E2).withOpacity(0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      );
    }

    return TapRegion(
      onTapOutside: (_) {
        if (_editing) {
          cancelEditingFromKeyboard();
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: (details) {
            widget.onOpenContextMenu?.call(details.globalPosition);
          },
          onTapDown: (_) {
            if (_editing) return;
            widget.onSelect(_isAdditiveSelectionPressed());
          },
          child: AnimatedContainer(
            duration: Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0.0,
              highlighted ? -2.0 : 0.0,
              0.0,
            ),
            child: Card(
              elevation: highlighted ? 4 : 0.5,
              color: rowBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: widget.isSelected
                      ? const Color(0xFF00A3FF).withOpacity(0.65)
                      : Colors.white.withOpacity(0.0),
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: _kTableContentW,
                          child: Row(
                            children: [
                              // FECHA
                              gridCellFrame(
                                0,
                                SizedBox(
                                  width: 90,
                                  child: _editing
                                      ? InkWell(
                                          onTap: () {
                                            widget.onActivateColumn(0);
                                            _pickServiceDate();
                                          },
                                          child: _CellBox(
                                            text: widget.fmtDateUi(
                                              _serviceDate,
                                            ),
                                            icon: Icons.calendar_month,
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 0,
                                          child: readonlyCell(
                                            child: _FitText(
                                              widget.fmtDateUi(_serviceDate),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // EMPRESA
                              gridCellFrame(
                                1,
                                SizedBox(
                                  width: 190,
                                  child: _editing
                                      ? _DropOptInline(
                                          valueId: _clientId,
                                          items: widget.clients,
                                          onTapStart: () =>
                                              widget.onActivateColumn(1),
                                          onChanged: (v) =>
                                              setState(() => _clientId = v),
                                        )
                                      : previewEditableCell(
                                          col: 1,
                                          child: readonlyCell(
                                            child: _FitText(
                                              _labelOf(
                                                    widget.clients,
                                                    _clientId,
                                                  ) ??
                                                  '—',
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // MATERIAL
                              gridCellFrame(
                                2,
                                SizedBox(
                                  width: 190,
                                  child: _editing
                                      ? _DropOptInline(
                                          valueId: _materialId,
                                          items: widget.materials,
                                          onTapStart: () =>
                                              widget.onActivateColumn(2),
                                          onChanged: (v) =>
                                              setState(() => _materialId = v),
                                        )
                                      : previewEditableCell(
                                          col: 2,
                                          child: readonlyCell(
                                            child: _ServiceMaterialBadge(
                                              text:
                                                  _labelOf(
                                                    widget.materials,
                                                    _materialId,
                                                  ) ??
                                                  '—',
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // TIPO (recolección/entrega)
                              gridCellFrame(
                                3,
                                SizedBox(
                                  width: 130,
                                  child: _editing
                                      ? _DropStrInline(
                                          value: _direction,
                                          items: widget.directions,
                                          format: widget.uiLabel,
                                          onTapStart: () =>
                                              widget.onActivateColumn(3),
                                          onChanged: (v) =>
                                              setState(() => _direction = v),
                                        )
                                      : previewEditableCell(
                                          col: 3,
                                          child: readonlyCell(
                                            child: _FitText(
                                              widget.uiLabel(_direction),
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // CHOFER
                              gridCellFrame(
                                4,
                                SizedBox(
                                  width: 190,
                                  child: _editing
                                      ? _DropOptInline(
                                          valueId: _driverId,
                                          items: widget.drivers,
                                          onTapStart: () =>
                                              widget.onActivateColumn(4),
                                          onChanged: (v) =>
                                              setState(() => _driverId = v),
                                        )
                                      : previewEditableCell(
                                          col: 4,
                                          child: readonlyCell(
                                            child: _FitText(
                                              _labelOf(
                                                    widget.drivers,
                                                    _driverId,
                                                  ) ??
                                                  '—',
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // UNIDAD
                              gridCellFrame(
                                5,
                                SizedBox(
                                  width: 140,
                                  child: _editing
                                      ? _DropOptInline(
                                          valueId: _vehicleId,
                                          items: widget.vehicles,
                                          onTapStart: () =>
                                              widget.onActivateColumn(5),
                                          onChanged: (v) =>
                                              setState(() => _vehicleId = v),
                                        )
                                      : previewEditableCell(
                                          col: 5,
                                          child: readonlyCell(
                                            child: _ServiceUnitBadge(
                                              text:
                                                  _labelOf(
                                                    widget.vehicles,
                                                    _vehicleId,
                                                  ) ??
                                                  '—',
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // PARA EL DÍA (due_date)
                              gridCellFrame(
                                6,
                                SizedBox(
                                  width: 130,
                                  child: _editing
                                      ? InkWell(
                                          onTap: () {
                                            widget.onActivateColumn(6);
                                            _pickDueDate();
                                          },
                                          child: _CellBox(
                                            text: _dueDate == null
                                                ? '—'
                                                : widget.fmtDateUi(_dueDate!),
                                            icon: Icons.calendar_today,
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 6,
                                          child: readonlyCell(
                                            child: _FitText(
                                              _dueDate == null
                                                  ? '—'
                                                  : widget.fmtDateUi(_dueDate!),
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              // COMENTARIO
                              gridCellFrame(
                                7,
                                SizedBox(
                                  width: _kCommentColW,
                                  child: _editing
                                      ? TextField(
                                          controller: _notes,
                                          focusNode: _notesFocusNode,
                                          decoration: _glassFieldDecoration(),
                                          onTap: () {
                                            widget.onActivateColumn(7);
                                            if (!_notesFocusNode.hasFocus) {
                                              _notesFocusNode.requestFocus();
                                            }
                                          },
                                        )
                                      : previewEditableCell(
                                          col: 7,
                                          child: readonlyCell(
                                            showDivider: false,
                                            child: _FitText(
                                              (widget.row['notes'] ?? '')
                                                  as String,
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // ACCIONES
                              // ACCIONES
                              gridCellFrame(
                                8,
                                SizedBox(
                                  width: _kActionsW,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_editing)
                                        SizedBox(
                                          width:
                                              _kActionsW -
                                              54, // deja espacio al menú (⋯)
                                          child: _DropStrInline(
                                            value: _status,
                                            items: widget.statuses,
                                            format: widget.uiLabel,
                                            onTapStart: () =>
                                                widget.onActivateColumn(8),
                                            onChanged: (v) =>
                                                setState(() => _status = v),
                                          ),
                                        )
                                      else
                                        Flexible(
                                          child: _StatusPill(
                                            text: widget.uiLabel(_status),
                                          ),
                                        ),

                                      if (widget.showRowActions) ...[
                                        const SizedBox(width: 6),
                                        MouseRegion(
                                          onEnter: (_) => setState(
                                            () => _hoverActionsButton = true,
                                          ),
                                          onExit: (_) => setState(
                                            () => _hoverActionsButton = false,
                                          ),
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) => widget
                                                .onOpenContextMenu
                                                ?.call(details.globalPosition),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: _hoverActionsButton
                                                    ? Colors.white.withOpacity(
                                                        0.62,
                                                      )
                                                    : Colors.white.withOpacity(
                                                        0.42,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.72),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(
                                                          _hoverActionsButton
                                                              ? 0.15
                                                              : 0.08,
                                                        ),
                                                    blurRadius:
                                                        _hoverActionsButton
                                                        ? 14
                                                        : 8,
                                                    offset: Offset(
                                                      0,
                                                      _hoverActionsButton
                                                          ? 7
                                                          : 4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.more_horiz,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================
// UI helpers
// ======================

class _CellBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const _CellBox({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
          Icon(icon, size: 16),
        ],
      ),
    );
  }
}

class _MarqueeSelectionPainter extends CustomPainter {
  final Rect rect;

  const _MarqueeSelectionPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    if (rect.isEmpty) return;
    final fill = Paint()..color = const Color(0xFF4B8DBD).withOpacity(0.18);
    final stroke = Paint()
      ..color = const Color(0xFF3C7FB0).withOpacity(0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _MarqueeSelectionPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

class _ServiceMaterialBadge extends StatelessWidget {
  final String text;

  const _ServiceMaterialBadge({required this.text});

  ({Color bg, Color fg}) _colors(String label) {
    final key = label.trim().toUpperCase();
    if (key.contains('METAL')) {
      return (bg: const Color(0xFFD9E6F7), fg: const Color(0xFF24435E));
    }
    if (key.contains('CARTON')) {
      return (bg: const Color(0xFFD2EEE9), fg: const Color(0xFF1F4F4B));
    }
    if (key.contains('CHATARRA')) {
      return (bg: const Color(0xFFE0DCF7), fg: const Color(0xFF3F3A6C));
    }
    return (bg: const Color(0xFFE2E8F2), fg: const Color(0xFF31475F));
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors(text);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.8,
            fontWeight: FontWeight.w800,
            color: c.fg,
            letterSpacing: 0.15,
          ),
        ),
      ),
    );
  }
}

class _ServiceUnitBadge extends StatelessWidget {
  final String text;

  const _ServiceUnitBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDEE3EE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF36485C),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  const _StatusPill({required this.text});

  LinearGradient _gradientFor(String key) {
    switch (key) {
      case 'PROGRAMADO':
        return const LinearGradient(
          begin: Alignment(-0.85, -0.1),
          end: Alignment(0.9, 0.1),
          colors: [Color(0xFF3AB0FF), Color(0xFF0B72FF)],
        );
      case 'EN RUTA':
      case 'EN_RUTA':
      case 'ENRUTA':
        return const LinearGradient(
          begin: Alignment(-0.8, -0.1),
          end: Alignment(0.9, 0.12),
          colors: [Color(0xFF00E0B0), Color(0xFF00A3FF)],
        );
      case 'CONFIRMADO':
        return const LinearGradient(
          begin: Alignment(-0.8, -0.08),
          end: Alignment(0.9, 0.12),
          colors: [Color(0xFF6EE7A3), Color(0xFF19C37D)],
        );
      case 'CANCELADO':
        return const LinearGradient(
          begin: Alignment(-0.7, -0.05),
          end: Alignment(0.9, 0.08),
          colors: [Color(0xFFFFC4C4), Color(0xFFFF8A8A)],
        );
      case 'COMPLETADO':
      case 'COMPLETED':
        return const LinearGradient(
          begin: Alignment(-0.85, -0.08),
          end: Alignment(0.9, 0.12),
          colors: [Color(0xFF4B6CB7), Color(0xFF182848)],
        );
      case 'EN SITIO':
      case 'EN_SITIO':
      case 'ENSITIO':
        return const LinearGradient(
          begin: Alignment(-0.8, -0.06),
          end: Alignment(0.9, 0.12),
          colors: [Color(0xFFB89BFF), Color(0xFF6C63FF)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFEEEEEE), Color(0xFFDDDDDD)],
        );
    }
  }

  Color _textColorForGradient(LinearGradient g) {
    // approximate by sampling middle color between first two stops
    final c1 = g.colors.first;
    final c2 = g.colors.length > 1 ? g.colors[1] : c1;
    final avg = Color.fromARGB(
      ((c1.alpha + c2.alpha) ~/ 2),
      ((c1.red + c2.red) ~/ 2),
      ((c1.green + c2.green) ~/ 2),
      ((c1.blue + c2.blue) ~/ 2),
    );
    return avg.computeLuminance() > 0.55
        ? const Color(0xFF0B2B2B)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final key = text.toUpperCase().trim();
    final gradient = _gradientFor(key);
    final textColor = _textColorForGradient(gradient);

    // subtle glow color derived from last gradient stop
    final glow = gradient.colors.last.withOpacity(0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: glow,
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
          shadows: [Shadow(color: glow.withOpacity(0.6), blurRadius: 6)],
        ),
      ),
    );
  }
}

// Dropdown inline de _Opt (id/label)
class _DropOptInline extends StatelessWidget {
  final String? valueId;
  final List<_Opt> items;
  final VoidCallback? onTapStart;
  final ValueChanged<String?> onChanged;

  const _DropOptInline({
    required this.valueId,
    required this.items,
    this.onTapStart,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safe = items.any((e) => e.id == valueId) ? valueId : null;
    String selectedLabel = '—';
    if (safe != null) {
      for (final e in items) {
        if (e.id == safe) {
          selectedLabel = e.label;
          break;
        }
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        onTapStart?.call();
        final selected = await _showSearchablePickerDialog<String>(
          context,
          title: 'Seleccionar',
          initialValue: safe,
          options: items
              .map((e) => _PickerOption<String>(value: e.id, label: e.label))
              .toList(),
        );
        if (selected == null) return;
        onChanged(selected);
      },
      child: InputDecorator(
        decoration: _glassFieldDecoration(),
        child: Row(
          children: [
            Expanded(
              child: _FitText(
                selectedLabel,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

// Dropdown inline de String (con formato)
class _DropStrInline extends StatelessWidget {
  final String value;
  final List<String> items;
  final String Function(String) format;
  final VoidCallback? onTapStart;
  final ValueChanged<String> onChanged;

  const _DropStrInline({
    required this.value,
    required this.items,
    required this.format,
    this.onTapStart,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safe = items.contains(value)
        ? value
        : (items.isEmpty ? value : items.first);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => onTapStart?.call(),
      child: _TypeAheadDropdownField<String>(
        value: safe,
        labelOf: format,
        menuMaxHeight: 320,
        borderRadius: BorderRadius.circular(16),
        dropdownColor: _kGlassMenuBg,
        decoration: _glassFieldDecoration(),
        selectedItemBuilder: (context) => items
            .map(
              (e) => Align(
                alignment: Alignment.centerLeft,
                child: _FitText(
                  format(e),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            )
            .toList(),
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: _FitText(
                  format(e),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
      ),
    );
  }
}

// ======================
// Models
// ======================

class _Opt {
  final String id;
  final String label;
  const _Opt({required this.id, required this.label});
}

class _ServiceDraft {
  final DateTime? serviceDate;
  final DateTime? dueDate;

  // Que siempre existan:
  final String? direction;
  final String? status;

  final String? clientId;
  final String? materialId;
  final String? driverEmployeeId;
  final String? vehicleId;
  final String notes;

  const _ServiceDraft({
    required this.serviceDate,
    required this.dueDate,
    required this.direction,
    required this.status,
    required this.clientId,
    required this.materialId,
    required this.driverEmployeeId,
    required this.vehicleId,
    required this.notes,
  });

  factory _ServiceDraft.empty() => const _ServiceDraft(
    serviceDate: null,
    dueDate: null,
    direction: null,
    status: null,
    clientId: null,
    materialId: null,
    driverEmployeeId: null,
    vehicleId: null,
    notes: '',
  );

  static const _unset = Object();

  _ServiceDraft copyWith({
    Object? serviceDate = _unset,
    Object? dueDate = _unset,
    Object? direction = _unset,
    Object? status = _unset,
    Object? clientId = _unset,
    Object? materialId = _unset,
    Object? driverEmployeeId = _unset,
    Object? vehicleId = _unset,
    String? notes,
  }) {
    return _ServiceDraft(
      serviceDate: serviceDate == _unset
          ? this.serviceDate
          : serviceDate as DateTime?,
      dueDate: dueDate == _unset ? this.dueDate : dueDate as DateTime?,
      direction: direction == _unset ? this.direction : direction as String?,
      status: status == _unset ? this.status : status as String?,
      clientId: clientId == _unset ? this.clientId : clientId as String?,
      materialId: materialId == _unset
          ? this.materialId
          : materialId as String?,
      driverEmployeeId: driverEmployeeId == _unset
          ? this.driverEmployeeId
          : driverEmployeeId as String?,
      vehicleId: vehicleId == _unset ? this.vehicleId : vehicleId as String?,
      notes: notes ?? this.notes,
    );
  }
}
