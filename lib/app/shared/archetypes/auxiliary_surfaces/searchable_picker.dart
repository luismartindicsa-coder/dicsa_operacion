import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class SearchablePickerOption<T> {
  final T value;
  final String label;

  const SearchablePickerOption({required this.value, required this.label});
}

Future<T?> showSearchablePickerDialog<T>(
  BuildContext context, {
  required String title,
  required List<SearchablePickerOption<T>> options,
  T? initialValue,
  bool allowClear = false,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => _SearchablePickerDialog<T>(
      title: title,
      options: options,
      initialValue: initialValue,
      allowClear: allowClear,
    ),
  );
}

class _SearchablePickerDialog<T> extends StatefulWidget {
  final String title;
  final List<SearchablePickerOption<T>> options;
  final T? initialValue;
  final bool allowClear;

  const _SearchablePickerDialog({
    required this.title,
    required this.options,
    required this.initialValue,
    required this.allowClear,
  });

  @override
  State<_SearchablePickerDialog<T>> createState() =>
      _SearchablePickerDialogState<T>();
}

class _SearchablePickerDialogState<T>
    extends State<_SearchablePickerDialog<T>> {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final List<FocusNode> _itemFocusNodes = <FocusNode>[];
  final List<GlobalKey> _itemKeys = <GlobalKey>[];
  final ScrollController _listScrollController = ScrollController();
  String _query = '';
  int? _hoveredIndex;
  int? _focusedIndex;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _listScrollController.dispose();
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncFocusNodes(int count) {
    while (_itemFocusNodes.length < count) {
      _itemFocusNodes.add(FocusNode());
    }
    while (_itemFocusNodes.length > count) {
      _itemFocusNodes.removeLast().dispose();
    }
    while (_itemKeys.length < count) {
      _itemKeys.add(GlobalKey());
    }
    while (_itemKeys.length > count) {
      _itemKeys.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? widget.options
        : widget.options
              .where(
                (option) => option.label.toLowerCase().contains(normalized),
              )
              .toList();
    _syncFocusNodes(filtered.length);

    return Focus(
      autofocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          if (filtered.isEmpty) return KeyEventResult.handled;
          final activeIndex = (_focusedIndex ?? 0).clamp(
            0,
            filtered.length - 1,
          );
          Navigator.of(context).pop(filtered[activeIndex].value);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxHeight: 560),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF9FC8E7).withValues(alpha: 0.78),
                    const Color(0xFFB9CCE8).withValues(alpha: 0.72),
                    const Color(0xFF9ED7D6).withValues(alpha: 0.70),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE5F1FB).withValues(alpha: 0.78),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF76A6C2).withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Focus(
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) {
                        return KeyEventResult.ignored;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                          _itemFocusNodes.isNotEmpty) {
                        _itemFocusNodes.first.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: _searchablePickerFieldDecoration(
                        hintText: 'Buscar',
                      ),
                    ),
                  ),
                  if (widget.allowClear) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Limpiar selección'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Sin resultados'))
                        : ListView.builder(
                            controller: _listScrollController,
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final option = filtered[index];
                              final selected =
                                  option.value == widget.initialValue;
                              final hovered = _hoveredIndex == index;
                              final focused = _focusedIndex == index;
                              return Column(
                                children: [
                                  Focus(
                                    focusNode: _itemFocusNodes[index],
                                    onFocusChange: (hasFocus) {
                                      if (!mounted) return;
                                      setState(() {
                                        if (hasFocus) {
                                          _focusedIndex = index;
                                        } else if (_focusedIndex == index) {
                                          _focusedIndex = null;
                                        }
                                      });
                                      if (!hasFocus) return;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            final itemContext =
                                                _itemKeys[index].currentContext;
                                            if (itemContext == null) return;
                                            Scrollable.ensureVisible(
                                              itemContext,
                                              alignment: 0.5,
                                              duration: const Duration(
                                                milliseconds: 90,
                                              ),
                                              curve: Curves.easeOutCubic,
                                            );
                                          });
                                    },
                                    onKeyEvent: (_, event) {
                                      if (event is! KeyDownEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      final key = event.logicalKey;
                                      if (key == LogicalKeyboardKey.arrowUp) {
                                        if (index == 0) {
                                          _searchFocusNode.requestFocus();
                                        } else {
                                          _itemFocusNodes[index - 1]
                                              .requestFocus();
                                        }
                                        return KeyEventResult.handled;
                                      }
                                      if (key == LogicalKeyboardKey.arrowDown &&
                                          index < _itemFocusNodes.length - 1) {
                                        _itemFocusNodes[index + 1]
                                            .requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      if (key == LogicalKeyboardKey.enter ||
                                          key ==
                                              LogicalKeyboardKey.numpadEnter ||
                                          key == LogicalKeyboardKey.space) {
                                        Navigator.of(context).pop(option.value);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: MouseRegion(
                                      onEnter: (_) =>
                                          setState(() => _hoveredIndex = index),
                                      onExit: (_) {
                                        if (_hoveredIndex != index) return;
                                        setState(() => _hoveredIndex = null);
                                      },
                                      child: AnimatedContainer(
                                        key: _itemKeys[index],
                                        duration: const Duration(
                                          milliseconds: 1,
                                        ),
                                        curve: Curves.linear,
                                        decoration: BoxDecoration(
                                          color: focused
                                              ? const Color(
                                                  0xFFE3F0FC,
                                                ).withValues(alpha: 0.92)
                                              : hovered
                                              ? const Color(
                                                  0xFFE9F7EE,
                                                ).withValues(alpha: 0.98)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: focused
                                                ? const Color(
                                                    0xFF4E92D1,
                                                  ).withValues(alpha: 0.88)
                                                : hovered
                                                ? const Color(
                                                    0xFFBFD8D3,
                                                  ).withValues(alpha: 0.62)
                                                : Colors.transparent,
                                            width: focused
                                                ? 1.25
                                                : hovered
                                                ? 1.0
                                                : 0.0,
                                          ),
                                          boxShadow: hovered
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFBFD8D3,
                                                    ).withValues(alpha: 0.46),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          selected: selected,
                                          hoverColor: Colors.transparent,
                                          splashColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 2,
                                              ),
                                          title: Text(
                                            option.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF2D4661),
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          trailing: selected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Color(0xFF2D7A73),
                                                )
                                              : null,
                                          onTap: () => Navigator.of(
                                            context,
                                          ).pop(option.value),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (index < filtered.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: const Color(
                                        0xFFE5F1FB,
                                      ).withValues(alpha: 0.56),
                                    ),
                                ],
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

InputDecoration _searchablePickerFieldDecoration({String? hintText}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: const Color(0xFF8AA9C2).withValues(alpha: 0.52),
    ),
  );

  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: const Color(0xFF0B2B2B).withValues(alpha: 0.42),
      fontWeight: FontWeight.w400,
    ),
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFEAF3FC).withValues(alpha: 0.86),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: const Color(0xFF00A3FF).withValues(alpha: 0.8),
        width: 1.2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );
}
