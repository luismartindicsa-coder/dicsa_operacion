import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../services/services_shell.dart';
import '../services/services_visual_mode.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'logistics_area_chrome.dart';
import 'logistics_navigation.dart';
import 'logistics_operations_store.dart';
import 'logistics_resource_profile_store.dart';
import 'logistics_theme.dart';

// Manual unit status owned by Logistics; no automatic service/maintenance inference.
class LogisticsUnitsPage extends StatelessWidget {
  const LogisticsUnitsPage({super.key});
  @override
  Widget build(BuildContext context) => const _OperationsWorkspace(fleet: true);
}

// Workflow Master-Detail (Mantenimiento) with auxiliary capture dialogs.
class LogisticsIncidentsPage extends StatelessWidget {
  final String? vehicleId;
  const LogisticsIncidentsPage({super.key, this.vehicleId});
  @override
  Widget build(BuildContext context) =>
      _OperationsWorkspace(fleet: false, vehicleId: vehicleId);
}

ThemeData _theme(ThemeData base) => base.copyWith(
  canvasColor: kLogisticsSilverSurfaceTop,
  colorScheme: ColorScheme.fromSeed(
    seedColor: logisticsAreaTokens.primary,
    primary: logisticsAreaTokens.primaryStrong,
    surface: kLogisticsSilverSurfaceTop,
    onSurface: kLogisticsSilverTextPrimary,
  ),
  textTheme: base.textTheme.apply(
    bodyColor: kLogisticsSilverTextPrimary,
    displayColor: kLogisticsSilverTextPrimary,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: logisticsAreaTokens.fieldSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: logisticsAreaTokens.border),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: kLogisticsSilverSurfaceTop,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  chipTheme: base.chipTheme.copyWith(
    backgroundColor: logisticsAreaTokens.badgeBackground,
    labelStyle: TextStyle(color: logisticsAreaTokens.badgeText),
    side: BorderSide(color: logisticsAreaTokens.border),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: logisticsAreaTokens.primaryStrong,
      foregroundColor: kLogisticsSilverSurfaceTop,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: logisticsAreaTokens.primaryStrong,
      side: BorderSide(color: logisticsAreaTokens.border),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: logisticsAreaTokens.primaryStrong,
    ),
  ),
);

class _OperationsWorkspace extends StatefulWidget {
  final bool fleet;
  final String? vehicleId;
  const _OperationsWorkspace({required this.fleet, this.vehicleId});
  @override
  State<_OperationsWorkspace> createState() => _OperationsWorkspaceState();
}

class _OperationsWorkspaceState extends State<_OperationsWorkspace>
    with WidgetsBindingObserver {
  LogisticsOperationsBundle? _bundle;
  Timer? _refresh;
  final _incidentScroll = ScrollController();
  final _incidentFocus = FocusNode();
  bool _loading = false, _editing = false, _canDirection = false;
  String? _error, _selected;
  String _query = '', _filter = '';
  String get _label => widget.fleet
      ? kLogisticsNavFleetStatusLabel
      : kLogisticsNavIncidentsLabel;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _filter = widget.fleet ? 'Todas' : 'Abiertas';
    unawaited(_load());
    unawaited(_resolveAccess());
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_editing) unawaited(_load());
    });
  }

  Future<void> _resolveAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (mounted) {
      setState(() => _canDirection = AuthAccess.isDirectionRole(profile));
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _incidentScroll.dispose();
    _incidentFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_editing) unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final bundle = await LogisticsOperationsStore.load(fleet: widget.fleet);
      if (mounted) {
        setState(() {
          _bundle = bundle;
          _error = bundle.issues.values
              .map((issue) => issue.message)
              .join("\n");
          if (_error!.isEmpty) _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron cargar los datos de Logística.',
        );
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _edit({
    LogisticsIncident? incident,
    String? vehicleId,
    bool resolve = false,
  }) async {
    if (_bundle == null || _editing) return;
    _editing = true;
    final sources = await LogisticsOperationsStore.loadIncidentFormSources(
      _bundle!,
    );
    if (!mounted) {
      _editing = false;
      return;
    }
    final id = await showLogisticsContractDialog<String>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: logisticsAreaTokens,
        child: Theme(
          data: _theme(Theme.of(context)),
          child: _IncidentDialog(
            bundle: sources,
            initial: incident,
            vehicleId: vehicleId,
            resolve: resolve,
          ),
        ),
      ),
    );
    _editing = false;
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    if (id != null) {
      setState(() => _selected = id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incidencia guardada.')));
      }
    }
  }

  void _navigate(String label) {
    if (label == _label ||
        (label == kLogisticsNavDirectionDashboardLabel && !_canDirection)) {
      return;
    }
    final page = logisticsPageFor(label);
    if (page != null) {
      unawaited(
        Navigator.of(context).pushReplacement(appPageRoute(page: page)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ServicesVisualModeScope(
    logisticsSilverMode: true,
    child: AreaThemeScope(
      tokens: logisticsAreaTokens,
      child: Theme(
        data: _theme(Theme.of(context)),
        child: ServicesShell(
          headerTitle: _label,
          servicesNavLabel: _label,
          sideMenuWidth: kLogisticsSideMenuWidth,
          customSideMenuBuilder: (context, close) => LogisticsAreaSidePanel(
            currentLabel: _label,
            canReturnToDirection: _canDirection,
            onNavigate: (label) {
              close();
              _navigate(label);
            },
          ),
          onLogout: () => signOutAndRouteToLogin(context),
          child: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_error != null)
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  if (_bundle == null)
                    Expanded(
                      child: Center(
                        child: _error == null
                            ? const CircularProgressIndicator()
                            : const Text('Datos no disponibles.'),
                      ),
                    )
                  else ...[
                    _toolbar(),
                    const SizedBox(height: 12),
                    Expanded(child: widget.fleet ? _fleet() : _incidents()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _toolbar() => Wrap(
    spacing: 12,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 300,
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: widget.fleet ? 'Buscar unidad' : 'Buscar incidencia',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      SizedBox(
        width: 230,
        child: DropdownButtonFormField<String>(
          initialValue: _filter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Mostrar'),
          items:
              (widget.fleet
                      ? [
                          'Todas',
                          'Con advertencias',
                          'Disponible',
                          'Asignada',
                          'En ruta',
                          'En revisión',
                          'En mantenimiento',
                          'Fuera de servicio',
                          'Sin capturar',
                          'Sin datos',
                        ]
                      : ['Abiertas', 'Resueltas', 'Todas'])
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _filter = v);
          },
        ),
      ),
      if (!widget.fleet)
        FilledButton.icon(
          onPressed: _bundle!.available('logistics_trip_incidents')
              ? () => _edit(vehicleId: widget.vehicleId)
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Nueva incidencia'),
        ),
      if (widget.vehicleId != null && !widget.fleet)
        InputChip(
          label: const Text('Incidencias de esta unidad'),
          onDeleted: () => Navigator.of(
            context,
          ).pushReplacement(appPageRoute(page: const LogisticsIncidentsPage())),
        ),
    ],
  );
  Future<void> _editUnit(LogisticsVehicleProfileRecord vehicle) async {
    if (_editing || !_bundle!.available('logistics_unit_states')) return;
    _editing = true;
    final saved = await showLogisticsContractDialog<bool>(
      context: context,
      builder: (_) => Theme(
        data: _theme(Theme.of(context)),
        child: _UnitStateDialog(
          vehicle: vehicle,
          initial: _bundle!.unitStates[vehicle.vehicleId],
        ),
      ),
    );
    _editing = false;
    if (!mounted) return;
    await _load();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de la unidad guardado.')),
      );
    }
  }

  Widget _fleet() {
    if (!_bundle!.available('vehicles')) {
      return const Center(child: Text('Catálogo de unidades no disponible.'));
    }
    final statesAvailable = _bundle!.available('logistics_unit_states');
    String status(LogisticsVehicleProfileRecord v) => !statesAvailable
        ? 'Sin datos'
        : logisticsUnitStatuses[_bundle!.unitStates[v.vehicleId]?.status] ??
              'Sin capturar';
    bool warning(LogisticsVehicleProfileRecord v) =>
        _bundle!.unitStates[v.vehicleId]?.warning ?? false;
    final vehicles = _bundle!.vehicles
        .where(
          (v) => '${v.vehicleCode} ${v.sourceVehicleType}'
              .toUpperCase()
              .contains(_query.trim().toUpperCase()),
        )
        .where(
          (v) =>
              _filter == 'Todas' ||
              (_filter == 'Con advertencias'
                  ? warning(v)
                  : status(v) == _filter),
        )
        .toList();
    if (vehicles.isEmpty) {
      return const Center(child: Text('No hay unidades con estos filtros.'));
    }
    return ListView.separated(
      itemCount: vehicles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        final record = _bundle!.unitStates[vehicle.vehicleId];
        return _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    vehicle.vehicleCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  Chip(label: Text(status(vehicle))),
                  Text(logisticsUnitTypeLabel(vehicle.logisticsUnitType)),
                ],
              ),
              if (record != null) ...[
                if (record.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(record.notes),
                  ),
                if (DateTime.tryParse(record.updatedAt) case final date?)
                  Text(
                    'Actualizado: ${logisticsDate(date.toLocal())} ${TimeOfDay.fromDateTime(date.toLocal()).format(context)}',
                  ),
                if (record.warning)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Advertencia informativa para la programación.',
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else if (statesAvailable)
                const Text('Aún no se ha capturado el estado de esta unidad.'),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: statesAvailable
                        ? () => _editUnit(vehicle)
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Actualizar estado'),
                  ),
                  TextButton.icon(
                    onPressed: () => _edit(vehicleId: vehicle.vehicleId),
                    icon: const Icon(Icons.add_alert_outlined),
                    label: const Text('Reportar incidencia'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      appPageRoute(
                        page: LogisticsIncidentsPage(
                          vehicleId: vehicle.vehicleId,
                        ),
                      ),
                    ),
                    child: const Text('Ver incidencias'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _incidents() {
    if (!_bundle!.available('logistics_trip_incidents')) {
      return const Center(child: Text('Incidencias no disponibles.'));
    }
    final query = _query.trim().toUpperCase();
    final rows = _bundle!.incidents
        .where(
          (i) => widget.vehicleId == null || i.vehicleId == widget.vehicleId,
        )
        .where(
          (i) =>
              _filter == 'Todas' || (_filter == 'Abiertas' ? i.open : !i.open),
        )
        .where(
          (i) =>
              '${i.summary} ${i.serviceLabel} ${i.vehicleCode} ${i.driverName} ${i.responsible}'
                  .toUpperCase()
                  .contains(query),
        )
        .toList();
    if (rows.isEmpty) {
      return const Center(child: Text('No hay incidencias con estos filtros.'));
    }
    final selected =
        rows.where((i) => i.id == _selected).firstOrNull ?? rows.first;
    final rowExtent = 84 + MediaQuery.textScalerOf(context).scale(40);
    Widget list() => Focus(
      focusNode: _incidentFocus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            ![
              LogicalKeyboardKey.arrowUp,
              LogicalKeyboardKey.arrowDown,
            ].contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        final index = rows.indexOf(selected);
        final next =
            (index +
                    (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1))
                .clamp(0, rows.length - 1);
        setState(() => _selected = rows[next].id);
        if (_incidentScroll.hasClients) {
          final top = next * rowExtent;
          final bottom = top + rowExtent;
          final view = _incidentScroll.position.viewportDimension;
          final offset = top < _incidentScroll.offset
              ? top
              : bottom > _incidentScroll.offset + view
              ? bottom - view
              : _incidentScroll.offset;
          _incidentScroll.animateTo(
            offset.clamp(0, _incidentScroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
        return KeyEventResult.handled;
      },
      child: ListView.builder(
        controller: _incidentScroll,
        itemExtent: rowExtent,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return Card(
            key: ValueKey(row.id),
            clipBehavior: Clip.antiAlias,
            color: logisticsAreaTokens.fieldSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: logisticsAreaTokens.border),
            ),
            child: ListTile(
              selected: row.id == selected.id,
              selectedTileColor: logisticsAreaTokens.primarySoft,
              title: Text(
                row.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${logisticsDate(row.reportedAt)} · ${logisticsIncidentTypes[row.type]}\n${row.vehicleCode} · ${logisticsIncidentStatuses[row.status]}',
              ),
              isThreeLine: true,
              onTap: () {
                _incidentFocus.requestFocus();
                setState(() => _selected = row.id);
              },
            ),
          );
        },
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 850) {
          return Column(
            children: [
              SizedBox(height: 200, child: list()),
              const SizedBox(height: 12),
              Expanded(child: _detail(selected)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 340, child: list()),
            const SizedBox(width: 16),
            Expanded(child: _detail(selected)),
          ],
        );
      },
    );
  }

  Widget _detail(LogisticsIncident row) => _panel(
    child: ListView(
      children: [
        Text(
          row.summary,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            Chip(
              label: Text(logisticsIncidentStatuses[row.status] ?? row.status),
            ),
            Chip(
              label: Text(
                'Impacto ${logisticsIncidentImpacts[row.impact]?.toLowerCase()}',
              ),
            ),
          ],
        ),
        Text('Tipo: ${logisticsIncidentTypes[row.type]}'),
        Text(
          'Reportada: ${logisticsDate(row.reportedAt)} ${TimeOfDay.fromDateTime(row.reportedAt).format(context)}',
        ),
        Text(
          'Servicio: ${row.serviceLabel.isEmpty ? 'General' : row.serviceLabel}',
        ),
        Text(
          'Unidad: ${row.vehicleCode.isEmpty ? 'Sin unidad' : row.vehicleCode}',
        ),
        Text(
          'Chofer: ${row.driverName.isEmpty ? 'Sin chofer' : row.driverName}',
        ),
        Text(
          'Responsable: ${row.responsible.isEmpty ? 'Por asignar' : row.responsible}',
        ),
        const SizedBox(height: 18),
        const Text(
          'Acción realizada',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(row.action.isEmpty ? 'Sin acción registrada' : row.action),
        if (row.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(row.notes),
        ],
        if (row.resolvedAt != null) ...[
          const SizedBox(height: 12),
          Text('Resuelta: ${logisticsDate(row.resolvedAt!)}'),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _edit(incident: row),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar seguimiento'),
            ),
            if (row.open)
              FilledButton.icon(
                onPressed: () => _edit(incident: row, resolve: true),
                icon: const Icon(Icons.task_alt),
                label: const Text('Resolver incidencia'),
              ),
            if (row.serviceId.isNotEmpty)
              TextButton(
                onPressed: () => _navigate(kLogisticsNavControlDailyLabel),
                child: const Text('Abrir Control Diario'),
              ),
          ],
        ),
      ],
    ),
  );
  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: kLogisticsPanelGradient,
      border: Border.all(color: kLogisticsSilverBorder),
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class _IncidentDialog extends StatefulWidget {
  final LogisticsOperationsBundle bundle;
  final LogisticsIncident? initial;
  final String? vehicleId;
  final bool resolve;
  const _IncidentDialog({
    required this.bundle,
    this.initial,
    this.vehicleId,
    this.resolve = false,
  });
  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _summary, _action, _responsible, _notes;
  late String _type, _impact, _status, _serviceId, _vehicleId, _driverId;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final row = widget.initial;
    _summary = TextEditingController(text: row?.summary ?? '');
    _action = TextEditingController(text: row?.action ?? '');
    _responsible = TextEditingController(text: row?.responsible ?? '');
    _notes = TextEditingController(text: row?.notes ?? '');
    _type = row?.type ?? 'RETRASO';
    _impact = row?.impact ?? 'MEDIA';
    _status = widget.resolve ? 'RESUELTA' : row?.status ?? 'ABIERTA';
    _serviceId = row?.serviceId ?? '';
    _vehicleId = row?.vehicleId ?? widget.vehicleId ?? '';
    _driverId = row?.driverId ?? '';
  }

  @override
  void dispose() {
    _summary.dispose();
    _action.dispose();
    _responsible.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _snapshot(
    String id,
    String? originalId,
    String? originalLabel,
    String? currentLabel,
  ) {
    if (widget.initial != null && id == originalId) return originalLabel ?? '';
    return id.isEmpty ? '' : currentLabel ?? '';
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final service = widget.bundle.services
        .where((s) => s.id == _serviceId)
        .firstOrNull;
    final vehicle = widget.bundle.vehicles
        .where((v) => v.vehicleId == _vehicleId)
        .firstOrNull;
    try {
      final id = await LogisticsOperationsStore.saveIncident({
        'service_id': _serviceId.isEmpty ? null : _serviceId,
        'vehicle_id': _vehicleId.isEmpty ? null : _vehicleId,
        'driver_employee_id': _driverId.isEmpty ? null : _driverId,
        'service_label': _snapshot(
          _serviceId,
          widget.initial?.serviceId,
          widget.initial?.serviceLabel,
          service?.label,
        ),
        'vehicle_code': _snapshot(
          _vehicleId,
          widget.initial?.vehicleId,
          widget.initial?.vehicleCode,
          vehicle?.vehicleCode,
        ),
        'driver_name': _snapshot(
          _driverId,
          widget.initial?.driverId,
          widget.initial?.driverName,
          widget.bundle.drivers[_driverId],
        ),
        'incident_type': _type,
        'impact_level': _impact,
        'resolution_status': _status,
        'summary': _summary.text.trim(),
        'action_taken': _action.text.trim(),
        'responsible_name': _responsible.text.trim(),
        'notes': _notes.text.trim(),
        'reported_at': (widget.initial?.reportedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
      }, original: widget.initial);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : e is LogisticsSourceIssue
              ? e.message
              : 'No se pudo guardar la incidencia. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickService() async {
    final selected = await showSearchablePickerDialog<String>(
      context,
      title: 'Seleccionar servicio',
      options: [
        const SearchablePickerOption(
          value: '',
          label: 'General / sin servicio',
        ),
        ...widget.bundle.services.map(
          (s) => SearchablePickerOption(value: s.id, label: s.label),
        ),
      ],
      initialValue: _serviceId,
    );
    if (selected == null || !mounted) return;
    final service = widget.bundle.services
        .where((s) => s.id == selected)
        .firstOrNull;
    setState(() {
      _serviceId = selected;
      if (service != null) {
        _vehicleId = service.vehicleId;
        _driverId = service.driverId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.bundle.services
        .where((s) => s.id == _serviceId)
        .firstOrNull;
    final vehicle = widget.bundle.vehicles
        .where((v) => v.vehicleId == _vehicleId)
        .firstOrNull;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          widget.initial == null
              ? 'Nueva incidencia'
              : widget.resolve
              ? 'Resolver incidencia'
              : 'Editar seguimiento',
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final issue in widget.bundle.issues.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(issue.message),
                    ),
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
                  OutlinedButton.icon(
                    onPressed: _saving || !widget.bundle.available('services')
                        ? null
                        : _pickService,
                    icon: const Icon(Icons.route),
                    label: Text(
                      service?.label ??
                          (_serviceId.isNotEmpty
                              ? widget.initial!.serviceLabel
                              : 'Seleccionar servicio (opcional)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving || !widget.bundle.available('vehicles')
                        ? null
                        : () async {
                            final selected =
                                await showSearchablePickerDialog<String>(
                                  context,
                                  title: 'Seleccionar unidad',
                                  initialValue: _vehicleId,
                                  options: [
                                    const SearchablePickerOption(
                                      value: '',
                                      label: 'Sin unidad',
                                    ),
                                    ...widget.bundle.vehicles.map(
                                      (v) => SearchablePickerOption(
                                        value: v.vehicleId,
                                        label: v.vehicleCode,
                                      ),
                                    ),
                                  ],
                                );
                            if (selected != null && mounted) {
                              setState(() => _vehicleId = selected);
                            }
                          },
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      vehicle?.vehicleCode ??
                          (_vehicleId.isNotEmpty
                              ? widget.initial?.vehicleCode ?? 'Unidad'
                              : 'Seleccionar unidad (opcional)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _select(
                        'Tipo',
                        _type,
                        logisticsIncidentTypes,
                        (v) => _type = v,
                        width: 240,
                      ),
                      _select(
                        'Impacto',
                        _impact,
                        logisticsIncidentImpacts,
                        (v) => _impact = v,
                        width: 170,
                      ),
                      _select(
                        'Estado',
                        _status,
                        logisticsIncidentStatuses,
                        (v) => _status = v,
                        width: 220,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _summary,
                    autofocus: true,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Describe la incidencia'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _responsible,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Responsable de seguimiento',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _action,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Acción realizada',
                    ),
                    validator: (v) =>
                        _status == 'RESUELTA' && (v ?? '').trim().isEmpty
                        ? 'Indica cómo se resolvió'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar incidencia'),
          ),
        ],
      ),
    );
  }

  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> change, {
    required double width,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: _saving
          ? null
          : (v) {
              if (v != null) setState(() => change(v));
            },
    ),
  );
}

class _UnitStateDialog extends StatefulWidget {
  final LogisticsVehicleProfileRecord vehicle;
  final LogisticsManualUnitState? initial;
  const _UnitStateDialog({required this.vehicle, this.initial});
  @override
  State<_UnitStateDialog> createState() => _UnitStateDialogState();
}

class _UnitStateDialogState extends State<_UnitStateDialog> {
  late String _status;
  late final TextEditingController _notes;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _status = widget.initial?.status ?? 'DISPONIBLE';
    _notes = TextEditingController(text: widget.initial?.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LogisticsOperationsStore.saveUnitState(
        vehicleId: widget.vehicle.vehicleId,
        status: _status,
        notes: _notes.text,
        original: widget.initial,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is LogisticsSourceIssue
              ? error.message
              : error is StateError
              ? error.message
              : 'No se pudo guardar el estado. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('Estado de ${widget.vehicle.vehicleCode}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
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
              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Estado de la unidad',
                ),
                items: logisticsUnitStatuses.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _status = v);
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                autofocus: true,
                enabled: !_saving,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Observaciones'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Este estado es informativo y permite seguir programando la unidad.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Guardar estado'),
        ),
      ],
    ),
  );
}
