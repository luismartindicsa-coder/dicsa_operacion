import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../../shared/ui_contract_core/theme/contract_buttons.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../human_resources_theme.dart';
import 'hr_job_positions.dart';

/// Auxiliary picker: same search focus, arrows, Enter/Space and Escape as the
/// shared SearchablePicker, with explicit creation of a reusable catalog value.
Future<String?> showHrJobPositionPicker(
  BuildContext context, {
  required String current,
  required Future<List<String>> Function() load,
  required Future<String> Function(String) create,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => AreaThemeScope(
    tokens: humanResourcesAreaTokens,
    child: HrJobPositionPicker(current: current, load: load, create: create),
  ),
);

class HrJobPositionPicker extends StatefulWidget {
  final String current;
  final Future<List<String>> Function() load;
  final Future<String> Function(String) create;
  const HrJobPositionPicker({
    super.key,
    required this.current,
    required this.load,
    required this.create,
  });
  @override
  State<HrJobPositionPicker> createState() => _HrJobPositionPickerState();
}

class _HrJobPositionPickerState extends State<HrJobPositionPicker> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _nodes = <String, FocusNode>{};
  final _keys = <String, GlobalKey>{};
  List<String> _options = [];
  bool _loading = true, _saving = false, _loadFailed = false;
  String? _focusedName;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      final options = await widget.load();
      if (mounted) {
        setState(
          () => _options = hrJobPositionOptions([...options, widget.current]),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error =
              'No se pudo cargar el catálogo de puestos. Reintenta para consultar las opciones.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_loading || _saving) return;
    final query = normalizeHrJobPosition(_search.text);
    final match = _options
        .where((name) => hrJobPositionKey(name) == hrJobPositionKey(query))
        .firstOrNull;
    if (match != null) {
      Navigator.of(context).pop(match);
      return;
    }
    if (query.isEmpty || query.length > 120 || _loadFailed) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.create(query);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar el puesto. Tu texto se conserva; puedes reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final query = hrJobPositionKey(_search.text);
    final filtered = _options
        .where((name) => hrJobPositionKey(name).contains(query))
        .toList();
    final exists = _options.any((name) => hrJobPositionKey(name) == query);
    for (final name in filtered) {
      _nodes.putIfAbsent(name, FocusNode.new);
      _keys.putIfAbsent(name, GlobalKey.new);
    }
    return PopScope(
      canPop: !_saving,
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (!_saving) Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ContractDialogShell(
          child: SizedBox(
            width: 510,
            height: 540,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Puesto del colaborador',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: tokens.onGlass,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.arrowDown &&
                          filtered.isNotEmpty &&
                          !_saving) {
                        _nodes[filtered.first]!.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      key: const ValueKey('jobPositionSearch'),
                      autofocus: true,
                      focusNode: _searchFocus,
                      controller: _search,
                      enabled: !_saving,
                      maxLength: 120,
                      style: TextStyle(color: tokens.onGlass),
                      cursorColor: tokens.accent,
                      decoration:
                          contractGlassFieldDecoration(
                            context,
                            hintText: 'Buscar o escribir un nuevo puesto',
                            prefixIcon: Icon(
                              Icons.search,
                              color: tokens.accent,
                            ),
                          ).copyWith(
                            counterStyle: TextStyle(color: tokens.badgeText),
                          ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(color: tokens.onGlass),
                      ),
                    ),
                  if (_loadFailed)
                    TextButton(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: _loading || _saving ? null : _load,
                      child: const Text('Reintentar carga'),
                    ),
                  if (query.isNotEmpty &&
                      !exists &&
                      !_loading &&
                      !_loadFailed) ...[
                    ElevatedButton.icon(
                      style: contractPrimaryButtonStyle(context),
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(
                        'Agregar «${normalizeHrJobPosition(_search.text)}»',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Expanded(
                    child: _loading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: tokens.accent,
                            ),
                          )
                        : filtered.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty
                                  ? 'Escribe el primer puesto para agregarlo.'
                                  : 'No hay puestos coincidentes.',
                              style: TextStyle(color: tokens.badgeText),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              // Keep all catalog entries attached so arrows can
                              // focus and reveal options beyond the viewport.
                              children: List.generate(filtered.length, (index) {
                                final name = filtered[index];
                                return Focus(
                                  focusNode: _nodes[name],
                                  onFocusChange: (focused) {
                                    setState(
                                      () =>
                                          _focusedName = focused ? name : null,
                                    );
                                    if (focused) {
                                      final context =
                                          _keys[name]?.currentContext;
                                      if (context != null) {
                                        Scrollable.ensureVisible(
                                          context,
                                          alignment: .5,
                                        );
                                      }
                                    }
                                  },
                                  onKeyEvent: (_, event) {
                                    if (event is! KeyDownEvent || _saving) {
                                      return KeyEventResult.ignored;
                                    }
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowUp) {
                                      (index == 0
                                              ? _searchFocus
                                              : _nodes[filtered[index - 1]]!)
                                          .requestFocus();
                                      return KeyEventResult.handled;
                                    }
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowDown) {
                                      if (index + 1 < filtered.length) {
                                        _nodes[filtered[index + 1]]!
                                            .requestFocus();
                                      }
                                      return KeyEventResult.handled;
                                    }
                                    if ([
                                      LogicalKeyboardKey.enter,
                                      LogicalKeyboardKey.numpadEnter,
                                      LogicalKeyboardKey.space,
                                    ].contains(event.logicalKey)) {
                                      Navigator.of(context).pop(name);
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: ListTile(
                                    key: _keys[name],
                                    enabled: !_saving,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    selected:
                                        _focusedName == name ||
                                        hrJobPositionKey(widget.current) ==
                                            hrJobPositionKey(name),
                                    selectedTileColor: tokens.surfaceTint
                                        .withValues(alpha: .35),
                                    title: Text(
                                      name,
                                      style: TextStyle(color: tokens.onGlass),
                                    ),
                                    trailing:
                                        hrJobPositionKey(widget.current) ==
                                            hrJobPositionKey(name)
                                        ? Icon(
                                            Icons.check,
                                            color: tokens.accent,
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.of(context).pop(name),
                                  ),
                                );
                              }),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(''),
                        child: const Text('Sin puesto'),
                      ),
                      TextButton(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ],
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
