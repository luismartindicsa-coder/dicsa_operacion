import 'package:flutter/material.dart';

import '../../../ui_contract_core/dialogs/contract_popup_surface.dart';
import '../../../ui_contract_core/theme/contract_buttons.dart';
import '../../../ui_contract_core/theme/glass_styles.dart';
import 'grid_filter_state.dart';

class GridFilterDialog extends StatefulWidget {
  final String title;
  final GridFilterState initialState;
  final ValueChanged<GridFilterState>? onApply;
  final VoidCallback? onClear;
  final VoidCallback? onCancel;

  const GridFilterDialog({
    super.key,
    required this.title,
    required this.initialState,
    this.onApply,
    this.onClear,
    this.onCancel,
  });

  @override
  State<GridFilterDialog> createState() => _GridFilterDialogState();
}

class _GridFilterDialogState extends State<GridFilterDialog> {
  late GridFilterState _state;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _searchController = TextEditingController(text: _state.search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    return ContractPopupSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF14373B),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _state = _state.copyWith(search: value);
              });
            },
            decoration: contractGlassFieldDecoration(
              context,
              hintText: 'Buscar',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: _state.visibleOptions
                    .map(
                      (option) => CheckboxListTile(
                        dense: true,
                        value: option.selected,
                        onChanged: (_) => _toggleOption(option.value),
                        title: Text(option.label),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: contractSecondaryButtonStyle(context),
                onPressed: () {
                  widget.onCancel?.call();
                  Navigator.of(context).maybePop();
                },
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: contractSecondaryButtonStyle(context),
                onPressed: _clear,
                child: const Text('Limpiar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: contractPrimaryButtonStyle(context),
                onPressed: () {
                  widget.onApply?.call(_state);
                  Navigator.of(context).maybePop(_state);
                },
                child: const Text('Aplicar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
