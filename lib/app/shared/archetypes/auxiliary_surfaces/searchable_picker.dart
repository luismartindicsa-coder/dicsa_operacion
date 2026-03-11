import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../../ui_contract_core/theme/contract_buttons.dart';
import '../../ui_contract_core/theme/glass_styles.dart';

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
  String _query = '';
  int? _hoveredIndex;
  int? _focusedIndex;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
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
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ContractDialogShell(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF14373B),
                  ),
                ),
                const SizedBox(height: 10),
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
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: contractGlassFieldDecoration(
                      context,
                      hintText: 'Buscar',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    ),
                  ),
                ),
                if (widget.allowClear) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: contractGhostButtonStyle(context),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Limpiar selección'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('Sin resultados'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final option = filtered[index];
                            final selected =
                                option.value == widget.initialValue;
                            final active =
                                _hoveredIndex == index ||
                                _focusedIndex == index;
                            return Focus(
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
                                    _itemFocusNodes[index - 1].requestFocus();
                                  }
                                  return KeyEventResult.handled;
                                }
                                if (key == LogicalKeyboardKey.arrowDown &&
                                    index < _itemFocusNodes.length - 1) {
                                  _itemFocusNodes[index + 1].requestFocus();
                                  return KeyEventResult.handled;
                                }
                                if (key == LogicalKeyboardKey.enter ||
                                    key == LogicalKeyboardKey.numpadEnter ||
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
                                  if (_hoveredIndex == index) {
                                    setState(() => _hoveredIndex = null);
                                  }
                                },
                                child: ListTile(
                                  dense: true,
                                  selected: selected || active,
                                  selectedTileColor: const Color(
                                    0xFFA9E8CF,
                                  ).withValues(alpha: 0.28),
                                  title: Text(option.label),
                                  onTap: () =>
                                      Navigator.of(context).pop(option.value),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
