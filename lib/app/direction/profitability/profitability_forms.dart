import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../direction_theme.dart';
import '../expected_income/expected_income_forms.dart';
import 'profitability_models.dart';

/// Auxiliary form cloned from IncomeFormDialog: same shell, focus, pickers,
/// Enter/Escape and retained draft on error. Supports any number of outputs.
class ProfitDistributionDialog extends StatefulWidget {
  final String title, description, note;
  final Map<String, String> options;
  final Map<String, double> values;
  final bool complete;
  final Future<void> Function(Map<String, double>, String) onSave;
  const ProfitDistributionDialog({
    super.key,
    required this.title,
    required this.description,
    required this.options,
    required this.values,
    required this.note,
    required this.complete,
    required this.onSave,
  });
  @override
  State<ProfitDistributionDialog> createState() =>
      _ProfitDistributionDialogState();
}

class _ProfitDistributionDialogState extends State<ProfitDistributionDialog> {
  late final _values = {...widget.values};
  late final _note = TextEditingController(text: widget.note);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _edit([String? key]) async {
    await showIncomeForm(
      context,
      title: key == null ? 'Agregar participación' : 'Editar participación',
      fields: [
        IncomeFormField(
          'key',
          'Empresa / salida comercial',
          key ?? '',
          options: widget.options,
        ),
        IncomeFormField(
          'percent',
          'Porcentaje',
          key == null ? null : _values[key]! * 100,
          numeric: true,
          min: .0001,
          max: 100,
        ),
      ],
      onSave: (v) async {
        final selected = profitText(v['key']);
        if (!widget.options.containsKey(selected)) {
          throw StateError('Selecciona una opción.');
        }
        if (selected != key && _values.containsKey(selected)) {
          throw StateError('La opción ya tiene una participación.');
        }
        setState(() {
          if (key != null) _values.remove(key);
          _values[selected] = (v['percent'] as num).toDouble() / 100;
        });
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final sum = _values.values.fold<double>(0, (s, v) => s + v);
    if (_note.text.trim().isEmpty ||
        _values.isEmpty ||
        sum > 1.000001 ||
        widget.complete && (sum - 1).abs() > .000001) {
      setState(
        () => _error = widget.complete
            ? 'El reparto debe sumar 100% e incluir su fundamento.'
            : 'El rendimiento debe sumar más de 0 y máximo 100%, con fundamento.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(Map.of(_values), _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => incomeThemed(
    context,
    AreaThemeScope(
      tokens: directionAreaTokens,
      child: PopScope(
        canPop: !_saving,
        child: ContractDialogShell(
          child: SizedBox(
            width: 700,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (!_saving) Navigator.pop(context);
                },
                const SingleActivator(LogicalKeyboardKey.enter): _save,
              },
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kDirectionSurfaceText,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        widget.description,
                        style: const TextStyle(color: kDirectionMutedText),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final key
                                in (_values.keys.toList()..sort(
                                  (a, b) => (widget.options[a] ?? a).compareTo(
                                    widget.options[b] ?? b,
                                  ),
                                )))
                              ListTile(
                                title: Text(widget.options[key] ?? key),
                                subtitle: Text(
                                  '${(_values[key]! * 100).toStringAsFixed(2)}%',
                                ),
                                onTap: _saving ? null : () => _edit(key),
                                trailing: IconButton(
                                  tooltip: 'Quitar participación',
                                  onPressed: _saving
                                      ? null
                                      : () =>
                                            setState(() => _values.remove(key)),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _edit,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar participación'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Total: ${(_values.values.fold<double>(0, (s, v) => s + v) * 100).toStringAsFixed(2)}%',
                                style: const TextStyle(
                                  color: kDirectionSurfaceText,
                                ),
                              ),
                            ),
                            TextField(
                              controller: _note,
                              autofocus: true,
                              enabled: !_saving,
                              decoration: const InputDecoration(
                                labelText: 'Fundamento / evidencia',
                              ),
                              style: const TextStyle(
                                color: kDirectionSurfaceText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: kDirectionDanger),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Guardando…' : 'Guardar'),
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

Future<bool?> showProfitDistribution(
  BuildContext context, {
  required String title,
  required String description,
  required Map<String, String> options,
  required Map<String, double> values,
  required String note,
  required bool complete,
  required Future<void> Function(Map<String, double>, String) onSave,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ProfitDistributionDialog(
    title: title,
    description: description,
    options: options,
    values: values,
    note: note,
    complete: complete,
    onSave: onSave,
  ),
);
