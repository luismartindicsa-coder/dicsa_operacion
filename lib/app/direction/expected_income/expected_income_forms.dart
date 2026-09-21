import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../direction_theme.dart';
import '../operating_program/operating_program_models.dart';
import 'expected_income_models.dart';
import 'expected_income_repository.dart';

Widget incomeThemed(BuildContext context, Widget child) {
  final base = Theme.of(context);
  final tokens = directionAreaTokens;
  return Theme(
    data: base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: tokens.primary,
        onPrimary: tokens.surfaceTint,
        surface: tokens.glassSurface,
        onSurface: tokens.onGlass,
        outline: tokens.border,
      ),
      iconTheme: IconThemeData(color: tokens.primary),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        labelStyle: TextStyle(color: tokens.onGlass),
      ),
    ),
    child: child,
  );
}

class IncomeFormField {
  final String keyName, label;
  final Object? initial;
  final Map<String, String>? options;
  final bool numeric, optional, integer;
  final double min, max;
  const IncomeFormField(
    this.keyName,
    this.label,
    this.initial, {
    this.options,
    this.numeric = false,
    this.optional = false,
    this.integer = false,
    this.min = 0,
    this.max = 1e12,
  });
}

/// Uses the shared modal and picker contract. Refresh remains deferred while
/// this form owns focus; Enter saves, Escape cancels, failures keep the draft.
class IncomeFormDialog extends StatefulWidget {
  final String title, description;
  final List<IncomeFormField> fields;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const IncomeFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.description = '',
  });
  @override
  State<IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<IncomeFormDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields.where(
      (f) => f.options == null && f.initial is! bool,
    ))
      f.keyName: TextEditingController(text: f.initial?.toString() ?? ''),
  };
  late final Map<String, dynamic> _values = {
    for (final f in widget.fields) f.keyName: f.initial,
  };
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    for (final f in widget.fields.where(
      (f) => _controllers.containsKey(f.keyName),
    )) {
      final text = _controllers[f.keyName]!.text.trim();
      _values[f.keyName] = f.numeric
          ? (text.isEmpty ? null : num.parse(text))
          : text;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_values);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => incomeThemed(
    context,
    PopScope(
      canPop: !_saving,
      child: AreaThemeScope(
        tokens: directionAreaTokens,
        child: ContractDialogShell(
          child: SizedBox(
            width: 660,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (!_saving) Navigator.pop(context);
                },
                const SingleActivator(LogicalKeyboardKey.enter): _save,
              },
              child: Form(
                key: _form,
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
                      if (widget.description.isNotEmpty)
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
                              for (final f in widget.fields)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
                                  child: _field(f),
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
    ),
  );

  Widget _field(IncomeFormField f) {
    if (f.initial is bool) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          f.label,
          style: const TextStyle(color: kDirectionSurfaceText),
        ),
        value: _values[f.keyName] as bool,
        onChanged: _saving
            ? null
            : (v) => setState(() => _values[f.keyName] = v),
      );
    }
    if (f.options != null) {
      return OutlinedButton(
        onPressed: _saving
            ? null
            : () async {
                final options = f.options!.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value));
                final selected = await showSearchablePickerDialog<String>(
                  context,
                  title: f.label,
                  options: [
                    for (final e in options)
                      SearchablePickerOption(value: e.key, label: e.value),
                  ],
                  initialValue: _values[f.keyName] as String?,
                );
                if (selected != null && mounted) {
                  setState(() => _values[f.keyName] = selected);
                }
              },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${f.label}: ${f.options![_values[f.keyName]] ?? 'Sin definir'}',
          ),
        ),
      );
    }
    return TextFormField(
      key: ValueKey(f.keyName),
      controller: _controllers[f.keyName],
      enabled: !_saving,
      autofocus: f == widget.fields.first,
      style: const TextStyle(color: kDirectionSurfaceText),
      keyboardType: f.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: f.label,
        filled: true,
        fillColor: directionAreaTokens.fieldSurface,
      ),
      onFieldSubmitted: (_) => _save(),
      validator: (v) {
        if ((v ?? '').trim().isEmpty) {
          return f.optional ? null : 'Campo requerido';
        }
        if (!f.numeric) return null;
        final number = num.tryParse(v!.trim());
        if (number == null ||
            !number.isFinite ||
            number < f.min ||
            number > f.max ||
            f.integer && number != number.round()) {
          return f.integer
              ? 'Captura un entero entre ${f.min.toInt()} y ${f.max.toInt()}.'
              : 'Captura un importe válido entre ${f.min} y ${f.max}.';
        }
        return null;
      },
    );
  }
}

Future<bool?> showIncomeForm(
  BuildContext context, {
  required String title,
  String description = '',
  required List<IncomeFormField> fields,
  required Future<void> Function(Map<String, dynamic>) onSave,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => IncomeFormDialog(
    title: title,
    description: description,
    fields: fields,
    onSave: onSave,
  ),
);

Future<bool?> editIncomeMaterial(
  BuildContext context,
  IncomeMaterialRule rule,
  ExpectedIncomeRepository repository,
) => showIncomeForm(
  context,
  title: 'Estimación · ${incomeMaterialName(rule.material)}',
  description:
      'Estos valores se usan cuando no hay peso o precio real. El precio por cliente tiene prioridad.',
  fields: [
    IncomeFormField(
      'kg',
      'Kg promedio por paca',
      rule.kgPerBale,
      numeric: true,
      min: 0.0001,
      max: 10000,
    ),
    IncomeFormField(
      'price',
      'Precio promedio por kg (MXN)',
      rule.price,
      numeric: true,
      optional: true,
      max: 100000,
    ),
  ],
  onSave: (v) => repository.saveMaterial(
    IncomeMaterialRule(
      rule.material,
      (v['kg'] as num).toDouble(),
      incomeNumber(v['price']),
    ),
  ),
);

Future<bool?> editIncomeClient(
  BuildContext context,
  String name,
  ExpectedIncomeData data,
  ExpectedIncomeRepository repository,
) {
  final existing = data.ruleFor(name);
  final key = existing?.key ?? incomeKey(name);
  final companies = data.catalogClients
      .where((c) => incomeKey('${c['name']}') == incomeKey(name))
      .toList();
  final clientId =
      existing?.clientId ??
      (companies.length == 1 ? companies.single['id'] as String : null);
  return showIncomeForm(
    context,
    title: 'Condiciones · ${existing?.name ?? name}',
    description:
        'Precios en MXN/kg. Vacío conserva el precio comercial de Mayoreo o el promedio del material. Los plazos se cuentan en días calendario.',
    fields: [
      IncomeFormField(
        'payment',
        'Tipo de pago',
        existing?.paymentType ?? 'FISCAL',
        options: const {
          'EFECTIVO': 'Efectivo',
          'FISCAL': 'Fiscal',
          'MIXTO': 'Mixto',
        },
      ),
      IncomeFormField(
        'unit',
        'Unidad del plazo',
        existing?.termUnit ?? 'DIAS',
        options: const {
          'INMEDIATO': 'Inmediato',
          'DIAS': 'Días',
          'SEMANAS': 'Semanas',
        },
      ),
      IncomeFormField(
        'term',
        'Plazo de pago',
        existing?.term ?? 0,
        numeric: true,
        integer: true,
        max: 365,
      ),
      IncomeFormField(
        'price',
        'Precio general del cliente',
        existing?.price,
        numeric: true,
        optional: true,
        max: 100000,
      ),
      for (final m in programMaterials)
        IncomeFormField(
          m,
          'Precio ${incomeMaterialName(m)}',
          data.priceOverrides['$key|$m'],
          numeric: true,
          optional: true,
          max: 100000,
        ),
      IncomeFormField(
        'usual',
        'Material habitual (informativo)',
        existing?.usualMaterial ?? '',
        options: {
          '': 'Sin preferencia',
          for (final m in programMaterials) m: incomeMaterialName(m),
        },
      ),
      IncomeFormField(
        'aliases',
        'Otros nombres del mismo cliente (separados por coma)',
        existing?.aliases.join(', ') ?? '',
        optional: true,
      ),
      IncomeFormField(
        'notes',
        'Reglas especiales',
        existing?.specialRules ?? '',
        optional: true,
      ),
      IncomeFormField(
        'active',
        'Condiciones activas',
        existing?.active ?? true,
      ),
    ],
    onSave: (v) => repository.saveClient(
      IncomeClientRule(
        key: key,
        name: existing?.name ?? name,
        clientId: clientId,
        paymentType: v['payment'] as String,
        termUnit: v['unit'] as String,
        term: (v['term'] as num).toInt(),
        price: incomeNumber(v['price']),
        usualMaterial: v['usual'] == '' ? null : v['usual'] as String,
        aliases: (v['aliases'] as String)
            .split(',')
            .map(incomeKey)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
        specialRules: v['notes'] as String,
        active: v['active'] as bool,
        revolving: existing?.revolving ?? key == 'EL PALOMAR',
      ),
      {
        for (final m in programMaterials)
          if (v[m] != null) m: (v[m] as num).toDouble(),
      },
    ),
  );
}

Future<bool?> editPalomarConfig(
  BuildContext context,
  PalomarIncomeConfig config,
  ExpectedIncomeRepository repository,
) => showIncomeForm(
  context,
  title: 'Disposición · El Palomar',
  description:
      'Al guardar se actualiza el flujo de la semana consultada con la disposición posible al cierre y su reparto efectivo/fiscal. Las remisiones reducen el saldo; los importes vacíos no habilitan una disposición.',
  fields: [
    IncomeFormField(
      'limit',
      'Límite vigente de la cuenta',
      config.creditLimit,
      numeric: true,
      optional: true,
    ),
    IncomeFormField(
      'draw',
      'Monto máximo a disponer',
      config.drawAmount,
      numeric: true,
      optional: true,
    ),
    IncomeFormField(
      'check1',
      'Máximo cheque efectivo 1',
      config.cashCheck1,
      numeric: true,
    ),
    IncomeFormField(
      'check2',
      'Máximo cheque efectivo 2',
      config.cashCheck2,
      numeric: true,
    ),
    IncomeFormField(
      'covered',
      'Requerir cuenta cubierta',
      config.requireCovered,
    ),
  ],
  onSave: (v) => repository.savePalomarConfig(
    PalomarIncomeConfig(
      creditLimit: incomeNumber(v['limit']),
      drawAmount: incomeNumber(v['draw']),
      cashCheck1: incomeNumber(v['check1'])!,
      cashCheck2: incomeNumber(v['check2'])!,
      requireCovered: v['covered'] as bool,
    ),
  ),
);
