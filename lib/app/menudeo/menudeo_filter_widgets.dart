import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import 'menudeo_theme.dart';

class MenudeoDateFilterResult {
  final DateTimeRange? range;
  final bool clear;

  const MenudeoDateFilterResult({this.range, this.clear = false});
}

class MenudeoGridHeaderFilterCell extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool active;
  final Future<void> Function()? onTap;

  const MenudeoGridHeaderFilterCell({
    super.key,
    required this.label,
    required this.style,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onTap != null) ...[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onTap!.call(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFC96A4A)
                    : const Color(0xFFF3D9CF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? const Color(0xFF8E3F2A)
                      : const Color(0xFFE4B9A8),
                ),
              ),
              child: Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 15,
                color: active ? Colors.white : const Color(0xFF7A3422),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class MenudeoGridPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalRows;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSizeChanged;

  const MenudeoGridPager({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalRows,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.66)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
            ),
            Text(
              'Página ${currentPage + 1} de $totalPages',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.primaryStrong,
              ),
            ),
            OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Siguiente'),
            ),
            const Text('Filas/pág:'),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<int>(
                initialValue: pageSize,
                isDense: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.82),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: tokens.primarySoft.withValues(alpha: 0.9),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: tokens.primaryStrong.withValues(alpha: 0.4),
                      width: 1.4,
                    ),
                  ),
                ),
                items: const [40, 80, 120]
                    .map(
                      (size) => DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onPageSizeChanged(value);
                },
              ),
            ),
            Text(
              'Total: $totalRows',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Set<String>?> showMenudeoValueFilterDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
  required Set<String> initialValues,
}) {
  final normalizedOptions =
      options
          .map((option) => option.trim())
          .where((option) => option.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return showDialog<Set<String>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      final itemFocusNodes = <FocusNode>[];
      var query = '';
      final selectedValues = <String>{...initialValues};
      int? focusedIndex;

      void syncNodes(int target) {
        while (itemFocusNodes.length < target) {
          itemFocusNodes.add(FocusNode());
        }
        while (itemFocusNodes.length > target) {
          itemFocusNodes.removeLast().dispose();
        }
      }

      return AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = AreaThemeScope.of(context);
            final filtered = normalizedOptions
                .where(
                  (option) =>
                      option.toLowerCase().contains(query.trim().toLowerCase()),
                )
                .toList(growable: false);
            syncNodes(filtered.length);
            return Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(dialogContext).pop();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  Navigator.of(dialogContext).pop(<String>{...selectedValues});
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                    maxHeight: 560,
                  ),
                  child: ContractPopupSurface(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: tokens.primaryStrong,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Focus(
                          onKeyEvent: (_, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown &&
                                itemFocusNodes.isNotEmpty) {
                              itemFocusNodes.first.requestFocus();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: searchC,
                            focusNode: searchFocus,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Buscar',
                              prefixIcon: const Icon(Icons.search_rounded),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.82),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: tokens.primarySoft.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: tokens.primaryStrong.withValues(
                                    alpha: 0.42,
                                  ),
                                  width: 1.4,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: tokens.primarySoft.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                            onChanged: (value) =>
                                setLocalState(() => query = value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                setLocalState(selectedValues.clear),
                            child: Text(
                              'Limpiar selección',
                              style: TextStyle(color: tokens.primaryStrong),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('Sin resultados'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final option = filtered[i];
                                    final selected = selectedValues.contains(
                                      option,
                                    );
                                    final highlighted = focusedIndex == i;
                                    return Focus(
                                      focusNode: itemFocusNodes[i],
                                      onFocusChange: (hasFocus) {
                                        setLocalState(
                                          () => focusedIndex = hasFocus
                                              ? i
                                              : focusedIndex == i
                                              ? null
                                              : focusedIndex,
                                        );
                                      },
                                      onKeyEvent: (_, event) {
                                        if (event is! KeyDownEvent) {
                                          return KeyEventResult.ignored;
                                        }
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.arrowUp) {
                                          if (i == 0) {
                                            searchFocus.requestFocus();
                                          } else {
                                            itemFocusNodes[i - 1]
                                                .requestFocus();
                                          }
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.arrowDown &&
                                            i < itemFocusNodes.length - 1) {
                                          itemFocusNodes[i + 1].requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.enter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey
                                                    .numpadEnter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.space) {
                                          setLocalState(() {
                                            if (!selectedValues.add(option)) {
                                              selectedValues.remove(option);
                                            }
                                          });
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => setLocalState(() {
                                          if (!selectedValues.add(option)) {
                                            selectedValues.remove(option);
                                          }
                                        }),
                                        onHover: (value) {
                                          if (value) {
                                            setLocalState(
                                              () => focusedIndex = i,
                                            );
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 140,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? tokens.badgeBackground
                                                      .withValues(alpha: 0.76)
                                                : highlighted
                                                ? Colors.white.withValues(
                                                    alpha: 0.72,
                                                  )
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? tokens.primaryStrong
                                                        .withValues(alpha: 0.26)
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    fontWeight: selected
                                                        ? FontWeight.w900
                                                        : FontWeight.w700,
                                                    color: tokens.primaryStrong,
                                                  ),
                                                ),
                                              ),
                                              if (selected)
                                                Icon(
                                                  Icons.check_rounded,
                                                  size: 18,
                                                  color: tokens.primaryStrong,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: contractSecondaryButtonStyle(
                                dialogContext,
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: contractPrimaryButtonStyle(dialogContext),
                              onPressed: () => Navigator.of(
                                dialogContext,
                              ).pop(<String>{...selectedValues}),
                              child: const Text('Aplicar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Future<MenudeoDateFilterResult?> showMenudeoDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<MenudeoDateFilterResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? bounds.start).year,
        (initialRange?.start ?? bounds.start).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

      return AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = AreaThemeScope.of(context);
            final monthFirst = DateTime(
              displayMonth.year,
              displayMonth.month,
              1,
            );
            final leading = (monthFirst.weekday + 6) % 7;
            final gridStart = monthFirst.subtract(Duration(days: leading));
            final previewEnd = end ?? hover;

            bool withinBounds(DateTime day) {
              final d = dateOnly(day);
              return !d.isBefore(dateOnly(bounds.start)) &&
                  !d.isAfter(dateOnly(bounds.end));
            }

            bool inPreviewRange(DateTime day) {
              if (start == null || previewEnd == null) return false;
              final a = dateOnly(start!);
              final b = dateOnly(previewEnd);
              final from = a.isBefore(b) ? a : b;
              final to = a.isBefore(b) ? b : a;
              final d = dateOnly(day);
              return !d.isBefore(from) && !d.isAfter(to);
            }

            MenudeoDateFilterResult? buildResult() {
              if (start == null) return null;
              final s = dateOnly(start!);
              final e = dateOnly(end ?? start!);
              final from = s.isBefore(e) ? s : e;
              final to = s.isBefore(e) ? e : s;
              return MenudeoDateFilterResult(
                range: DateTimeRange(start: from, end: to),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ContractPopupSurface(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 516,
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtro: $label',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setLocalState(
                            () => displayMonth = DateTime(
                              displayMonth.year,
                              displayMonth.month - 1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_monthNameEs(monthFirst.month)} ${monthFirst.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setLocalState(
                            () => displayMonth = DateTime(
                              displayMonth.year,
                              displayMonth.month + 1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final dayLabel in [
                          'L',
                          'M',
                          'M',
                          'J',
                          'V',
                          'S',
                          'D',
                        ])
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  dayLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.08,
                          ),
                      itemBuilder: (_, index) {
                        final day = gridStart.add(Duration(days: index));
                        final inMonth = day.month == monthFirst.month;
                        final allowed = withinBounds(day);
                        final active =
                            (start != null && isSameDay(day, start!)) ||
                            (end != null && isSameDay(day, end!));
                        final inRange = inPreviewRange(day) && allowed;
                        return MouseRegion(
                          onEnter: (_) {
                            if (start != null && end == null && allowed) {
                              setLocalState(() => hover = dateOnly(day));
                            }
                          },
                          child: GestureDetector(
                            onTap: !allowed
                                ? null
                                : () {
                                    final picked = dateOnly(day);
                                    setLocalState(() {
                                      if (start == null || end != null) {
                                        start = picked;
                                        end = null;
                                        hover = null;
                                      } else {
                                        end = picked;
                                        hover = null;
                                      }
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: active
                                    ? tokens.primaryStrong.withValues(
                                        alpha: 0.18,
                                      )
                                    : inRange
                                    ? tokens.primarySoft.withValues(alpha: 0.24)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? tokens.primaryStrong.withValues(
                                          alpha: 0.46,
                                        )
                                      : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: active
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: !allowed
                                        ? tokens.badgeText.withValues(
                                            alpha: 0.28,
                                          )
                                        : inMonth
                                        ? tokens.primaryStrong
                                        : tokens.badgeText.withValues(
                                            alpha: 0.55,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      start == null
                          ? 'Selecciona fecha inicial'
                          : end == null
                          ? 'Selecciona fecha final'
                          : '${_fmtDate(start!)} - ${_fmtDate(end!)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.badgeText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: contractSecondaryButtonStyle(dialogContext),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: contractSecondaryButtonStyle(dialogContext),
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            const MenudeoDateFilterResult(clear: true),
                          ),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: contractPrimaryButtonStyle(dialogContext),
                          onPressed: start == null
                              ? null
                              : () =>
                                    Navigator.pop(dialogContext, buildResult()),
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

String _fmtDate(DateTime value) {
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
