part of 'maintenance_page.dart';

// Auxiliary capture form. Persist the OT only after the operator completes it;
// keep all existing workflow, purchase links and detail persistence downstream.
class _MaintenanceQuickCreateDialog extends StatefulWidget {
  final List<String> areas;
  final List<Map<String, dynamic>> vehicles;
  final String requester;
  final Future<String> Function(Map<String, dynamic>) onCreate;
  const _MaintenanceQuickCreateDialog({
    required this.areas,
    required this.vehicles,
    required this.requester,
    required this.onCreate,
  });
  @override
  State<_MaintenanceQuickCreateDialog> createState() =>
      _MaintenanceQuickCreateDialogState();
}

class _MaintenanceQuickCreateDialogState
    extends State<_MaintenanceQuickCreateDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _equipment = TextEditingController();
  final _responsible = TextEditingController();
  late final TextEditingController _requester;
  String? _area, _vehicleId;
  String _priority = 'media', _impact = 'sin_impacto', _serial = '';
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _requester = TextEditingController(text: widget.requester);
  }

  @override
  void dispose() {
    _description.dispose();
    _equipment.dispose();
    _responsible.dispose();
    _requester.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.onCreate({
        'area_label': _area,
        'equipment_id': _vehicleId,
        'equipment_label': _equipment.text.trim(),
        'equipment_serial': _serial.isEmpty ? null : _serial,
        'problem_description': _description.text.trim(),
        'priority': _priority,
        'impact': _impact,
        'requester_name': _requester.text.trim().isEmpty
            ? null
            : _requester.text.trim(),
        'assigned_to_name': _responsible.text.trim().isEmpty
            ? null
            : _responsible.text.trim(),
        'assigned_at': _responsible.text.trim().isEmpty
            ? null
            : DateTime.now().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo crear la OT. Conservamos los datos para que intentes de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickVehicle() async {
    final selected = await shared_picker.showSearchablePickerDialog<String>(
      context,
      title: 'Seleccionar unidad',
      initialValue: _vehicleId,
      options: widget.vehicles
          .map(
            (v) => shared_picker.SearchablePickerOption(
              value: v['id'].toString(),
              label: v['code'].toString(),
            ),
          )
          .toList(),
    );
    if (selected == null || !mounted) return;
    final vehicle = widget.vehicles.firstWhere(
      (v) => v['id'].toString() == selected,
    );
    setState(() {
      _vehicleId = selected;
      _equipment.text = (vehicle['code'] ?? '').toString();
      _serial = (vehicle['serial_number'] ?? '').toString();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Nueva orden de trabajo'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _description,
                  autofocus: true,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _maintenanceInputDecoration(
                    labelText: '¿Qué necesita atención?',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Describe el problema o trabajo a realizar'
                      : null,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        initialValue: _area,
                        isExpanded: true,
                        decoration: _maintenanceInputDecoration(
                          labelText: 'Área',
                        ),
                        items: widget.areas
                            .map(
                              (a) => DropdownMenuItem(value: a, child: Text(a)),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _area = v),
                        validator: (v) =>
                            v == null ? 'Selecciona el área' : null,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        isExpanded: true,
                        decoration: _maintenanceInputDecoration(
                          labelText: 'Prioridad',
                        ),
                        items: _kPriorityLabel.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v != null) setState(() => _priority = v);
                              },
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _impact,
                        isExpanded: true,
                        decoration: _maintenanceInputDecoration(
                          labelText: 'Impacto',
                        ),
                        items: _kImpactLabel.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v != null) setState(() => _impact = v);
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _equipment,
                  enabled: !_saving,
                  onChanged: (_) {
                    _vehicleId = null;
                    _serial = '';
                  },
                  decoration:
                      _maintenanceInputDecoration(
                        labelText: 'Equipo o ubicación (opcional)',
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: 'Seleccionar unidad',
                          onPressed: _saving || widget.vehicles.isEmpty
                              ? null
                              : _pickVehicle,
                          icon: const Icon(Icons.local_shipping_outlined),
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _requester,
                  enabled: !_saving,
                  decoration: _maintenanceInputDecoration(
                    labelText: 'Solicitante (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _responsible,
                  enabled: !_saving,
                  decoration: _maintenanceInputDecoration(
                    labelText: 'Responsable (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: _maintenanceDialogOutlinedButtonStyle(),
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: _maintenanceDialogFilledButtonStyle(),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Creando…' : 'Crear OT'),
        ),
      ],
    ),
  );
}
