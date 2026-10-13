import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../../shared/ui_contract_core/theme/contract_buttons.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../personnel/hr_job_position_picker.dart';
import 'hr_staffing.dart';

class HrStaffingEditor extends StatefulWidget {
  final List<HrStaffingTarget> targets;
  final List<String> companies;
  final Future<List<String>> Function() loadPositions;
  final Future<String> Function(String) createPosition;
  final Future<void> Function(List<HrStaffingSave>) onSave;
  const HrStaffingEditor({
    super.key,
    this.targets = const [],
    required this.companies,
    required this.loadPositions,
    required this.createPosition,
    required this.onSave,
  });
  @override
  State<HrStaffingEditor> createState() => _HrStaffingEditorState();
}

class _HrStaffingEditorState extends State<HrStaffingEditor> {
  late String? _company = widget.targets.firstOrNull?.company,
      _position = widget.targets.firstOrNull?.position;
  late final _count = TextEditingController(
    text: widget.targets.length == 1
        ? '${widget.targets.single.requiredCount}'
        : '',
  );
  final _countFocus = FocusNode();
  String? _error;
  bool _saving = false;
  List<HrStaffingSave>? _pending;
  bool get _locked =>
      _saving || (_pending?.any((op) => op.confirmationPending) ?? false);
  @override
  void dispose() {
    _count.dispose();
    _countFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final count = int.tryParse(_count.text);
    if ((_company ?? '').isEmpty ||
        (_position ?? '').isEmpty ||
        count == null ||
        count < 0 ||
        count > 100000) {
      setState(
        () => _error =
            'Selecciona empresa y puesto e indica una cantidad entre 0 y 100,000.',
      );
      return;
    }
    _pending ??= widget.targets.isEmpty
        ? [
            HrStaffingSave(
              company: _company!,
              position: _position!,
              requiredCount: count,
            ),
          ]
        : [
            for (final t in widget.targets)
              HrStaffingSave(
                id: t.id,
                revision: t.revision,
                company: t.company,
                position: t.position,
                requiredCount: count,
              ),
          ];
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_pending!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = hrStaffingError(e);
          if (!_pending!.any((op) => op.confirmationPending)) _pending = null;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _companyPicker() async {
    if (_locked) return;
    final value = await showSearchablePickerDialog<String>(
      context,
      title: 'Empresa',
      initialValue: _company,
      options: [
        for (final c in widget.companies)
          SearchablePickerOption(value: c, label: c),
      ],
    );
    if (value != null && mounted) setState(() => _company = value);
  }

  Future<void> _positionPicker() async {
    if (_locked) return;
    final value = await showHrJobPositionPicker(
      context,
      current: _position ?? '',
      load: widget.loadPositions,
      create: widget.createPosition,
    );
    if (value != null && mounted) setState(() => _position = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return PopScope(
      canPop: !_saving,
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (!_saving) Navigator.pop(context);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ContractDialogShell(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.targets.isEmpty
                          ? 'Agregar plantilla'
                          : widget.targets.length == 1
                          ? 'Editar plantilla'
                          : 'Editar ${widget.targets.length} plantillas',
                      style: TextStyle(
                        color: t.onGlass,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (widget.targets.isEmpty) ...[
                      Text('Empresa', style: TextStyle(color: t.badgeText)),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        key: const ValueKey('staffingCompany'),
                        style: contractSecondaryButtonStyle(context),
                        onPressed: _locked ? null : _companyPicker,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_company ?? 'Selecciona empresa'),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Puesto', style: TextStyle(color: t.badgeText)),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        key: const ValueKey('staffingPosition'),
                        style: contractSecondaryButtonStyle(context),
                        onPressed: _locked ? null : _positionPicker,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (_position ?? '').isEmpty
                                    ? 'Selecciona o agrega un puesto'
                                    : _position!,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ] else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: SingleChildScrollView(
                          child: Text(
                            widget.targets
                                .map((t) => '${t.company} · ${t.position}')
                                .join('\n'),
                            style: TextStyle(color: t.badgeText, fontSize: 15),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Plantilla requerida',
                      style: TextStyle(
                        color: t.onGlass,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('staffingCount'),
                      controller: _count,
                      focusNode: _countFocus,
                      autofocus: widget.targets.isNotEmpty,
                      enabled: !_locked,
                      style: TextStyle(color: t.onGlass),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: contractGlassFieldDecoration(
                        context,
                        hintText: 'Total de personas necesarias',
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Captura el total necesario, incluyendo al personal actual. Usa 0 si ya no se requiere este puesto.',
                      style: TextStyle(color: t.badgeText, fontSize: 13),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          _error!,
                          style: TextStyle(color: t.onGlass),
                        ),
                      ),
                    if (!_saving && _locked)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'La confirmación está pendiente. Reintenta el mismo guardado para evitar duplicados.',
                          style: TextStyle(color: t.badgeText),
                        ),
                      ),
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          style: contractPrimaryButtonStyle(context),
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving
                                ? 'Guardando…'
                                : _locked
                                ? 'Reintentar guardado'
                                : 'Guardar plantilla',
                          ),
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
  }
}
