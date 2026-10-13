import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui_contract_core/dialogs/contract_popup_surface.dart';
import '../../../ui_contract_core/theme/area_theme_scope.dart';
import '../../../ui_contract_core/theme/contract_buttons.dart';
import '../../../ui_contract_core/theme/glass_styles.dart';
import 'grid_filter_state.dart';

class GridFilterDialog extends StatefulWidget {
  final String title;
  final GridFilterState initialState;
  final ValueChanged<GridFilterState>? onApply;
  final VoidCallback? onClear;
  final VoidCallback? onCancel;
  final bool keyboardNavigation;

  const GridFilterDialog({
    super.key,
    required this.title,
    required this.initialState,
    this.onApply,
    this.onClear,
    this.onCancel,
    this.keyboardNavigation = false,
  });

  @override
  State<GridFilterDialog> createState() => _GridFilterDialogState();
}

class _GridFilterDialogState extends State<GridFilterDialog> {
  late GridFilterState _state;
  late final TextEditingController _searchController;
  final _searchFocus = FocusNode();
  final _optionFocus = <String, FocusNode>{};

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _searchController = TextEditingController(text: _state.search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    for (final focus in _optionFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  void _apply() {
    widget.onApply?.call(_state);
    Navigator.of(context).maybePop(_state);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!widget.keyboardNavigation || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final visible = _state.visibleOptions;
    final index = visible.indexWhere(
      (o) => _optionFocus[o.value]?.hasFocus == true,
    );
    if (index < 0 && !_searchFocus.hasFocus) return KeyEventResult.ignored;
    final next = index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
    if (next < 0) {
      _searchFocus.requestFocus();
    } else if (next < visible.length) {
      final focus = _optionFocus[visible[next].value];
      focus?.requestFocus();
      if (focus?.context != null) {
        Scrollable.ensureVisible(focus!.context!, alignment: .5);
      }
    }
    return KeyEventResult.handled;
  }

  void _toggleOption(String value) {
    setState(() {
      _state = _state.copyWith(
        options: _state.options
            .map(
              (option) => option.value == value
                  ? option.copyWith(selected: !option.selected)
                  : option,
            )
            .toList(),
      );
    });
  }

  void _toggleVisibleSelection() {
    final visible = _state.visibleOptions.map((option) => option.value).toSet();
    if (visible.isEmpty) return;
    final allVisibleSelected = _state.visibleOptions.every(
      (option) => option.selected,
    );
    setState(() {
      _state = _state.copyWith(
        options: _state.options.map((option) {
          if (!visible.contains(option.value)) return option;
          return option.copyWith(selected: !allVisibleSelected);
        }).toList(),
      );
    });
  }

  void _clear() {
    setState(() {
      _state = _state.copyWith(
        search: '',
        options: _state.options
            .map((option) => option.copyWith(selected: false))
            .toList(),
      );
      _searchController.clear();
    });
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final allVisibleSelected =
        _state.visibleOptions.isNotEmpty &&
        _state.visibleOptions.every((option) => option.selected);
    final dialog = Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(
          minWidth: 260,
          maxWidth: 420,
          minHeight: 420,
          maxHeight: 520,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: tokens.onGlass,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: widget.keyboardNavigation,
              focusNode: _searchFocus,
              onSubmitted: widget.keyboardNavigation ? (_) => _apply() : null,
              controller: _searchController,
              style: TextStyle(
                color: tokens.onGlass,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: tokens.accent,
              onChanged: (value) {
                setState(() {
                  _state = _state.copyWith(search: value);
                });
              },
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Buscar',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: tokens.primarySoft,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.primarySoft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 6,
                      ),
                    ),
                    onPressed: _toggleVisibleSelection,
                    child: Text(
                      allVisibleSelected
                          ? 'Deseleccionar visibles'
                          : 'Seleccionar visibles',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_state.selectedValues.length} seleccionados',
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 250,
                  maxHeight: 280,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _state.visibleOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final option = _state.visibleOptions[index];
                    return _GridFilterOptionTile(
                      focusNode: widget.keyboardNavigation
                          ? _optionFocus.putIfAbsent(
                              option.value,
                              () => FocusNode(),
                            )
                          : null,
                      label: option.label,
                      selected: option.selected,
                      onTap: () => _toggleOption(option.value),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: () {
                    widget.onCancel?.call();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Cancelar'),
                ),
                OutlinedButton(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: _clear,
                  child: const Text('Limpiar'),
                ),
                ElevatedButton(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: _apply,
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Focus(onKeyEvent: _handleKey, child: dialog);
  }
}

class _GridFilterOptionTile extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const _GridFilterOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<_GridFilterOptionTile> createState() => _GridFilterOptionTileState();
}

class _GridFilterOptionTileState extends State<_GridFilterOptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final active = widget.selected || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          focusNode: widget.focusNode,
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? tokens.primaryStrong.withValues(alpha: 0.16)
                  : tokens.fieldSurface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? tokens.primaryStrong.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? tokens.primaryStrong.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: active
                          ? tokens.primaryStrong.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.28),
                      width: 1.8,
                    ),
                  ),
                  child: widget.selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: tokens.accent,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.onGlass,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
