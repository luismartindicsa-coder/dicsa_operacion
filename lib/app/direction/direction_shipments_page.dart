import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/general_dashboard_page.dart';
import '../gerencia/gerencia_dashboard_page.dart';
import '../maintenance/maintenance_statuses.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'direction_maintenance_page.dart';
import 'direction_shipments_store.dart';
import 'direction_theme.dart';

class DirectionShipmentsPage extends StatefulWidget {
  final bool instantOpen;

  const DirectionShipmentsPage({super.key, this.instantOpen = false});

  @override
  State<DirectionShipmentsPage> createState() => _DirectionShipmentsPageState();
}

class _DirectionShipmentsPageState extends State<DirectionShipmentsPage> {
  static const Duration _kSilentReloadInterval = Duration(seconds: 20);

  bool _menuOpen = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _runningMutation = false;
  String? _error;
  late DateTime _visibleWeekStartDate;
  DirectionShipmentPlanningBundle? _bundle;
  Timer? _reloadTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _visibleWeekStartDate = DirectionShipmentsStore.currentWeekStartDate();
    unawaited(_load());
    _reloadTimer = Timer.periodic(
      _kSilentReloadInterval,
      (_) => unawaited(_load(silent: true)),
    );
    _channel = Supabase.instance.client
        .channel('direction-shipments-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direction_shipment_plans',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direction_production_capacity_impacts',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dashboard_yard_manual_counts',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_orders',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements_v2',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gerencia_bale_weekly_plans',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gerencia_bale_weekly_plan_lines',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent || _bundle == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final bundle = await DirectionShipmentsStore.loadWeek(
        _visibleWeekStartDate,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent || _bundle == null) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar Embarques: $e';
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openMaintenance() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionMaintenancePage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openGerencia() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const GerenciaDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  bool get _isViewingCurrentWeek =>
      _visibleWeekStartDate == DirectionShipmentsStore.currentWeekStartDate();

  bool get _canGoToNextWeek => _visibleWeekStartDate.isBefore(
    DirectionShipmentsStore.currentWeekStartDate(),
  );

  Future<void> _changeVisibleWeek(DateTime nextWeekStartDate) async {
    final normalized = DirectionShipmentsStore.normalizeWeekStartDate(
      nextWeekStartDate,
    );
    if (normalized == _visibleWeekStartDate) return;
    setState(() => _visibleWeekStartDate = normalized);
    await _load();
  }

  Future<void> _openPreviousWeek() async {
    await _changeVisibleWeek(
      _visibleWeekStartDate.subtract(const Duration(days: 7)),
    );
  }

  Future<void> _openCurrentWeek() async {
    await _changeVisibleWeek(DirectionShipmentsStore.currentWeekStartDate());
  }

  Future<void> _openNextWeek() async {
    if (!_canGoToNextWeek) return;
    await _changeVisibleWeek(
      _visibleWeekStartDate.add(const Duration(days: 7)),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _createShipment() async {
    final bundle = _bundle;
    if (bundle == null) return;
    final draft = await _showShipmentDialog(weekStart: bundle.weekStartDate);
    if (draft == null) return;
    await _saveNewShipmentDraft(draft);
  }

  Future<void> _saveNewShipmentDraft(
    _ShipmentDraft draft, {
    String successMessage = 'Embarque guardado.',
  }) async {
    setState(() => _runningMutation = true);
    try {
      await DirectionShipmentsStore.createShipmentPlan(
        shipDate: draft.shipDate,
        clientName: draft.clientName,
        materialCode: draft.materialCode,
        materialScope: draft.materialScope,
        quantityUnit: draft.quantityUnit,
        plannedQuantity: draft.plannedQuantity,
        priority: draft.priority,
        status: draft.status,
        notes: draft.notes,
      );
      _toast(successMessage);
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo guardar el embarque: $e');
    } finally {
      if (mounted) setState(() => _runningMutation = false);
    }
  }

  Future<void> _editShipment(DirectionShipmentPlanRecord plan) async {
    final draft = await _showShipmentDialog(
      weekStart: _visibleWeekStartDate,
      initial: plan,
    );
    if (draft == null) return;
    setState(() => _runningMutation = true);
    try {
      await DirectionShipmentsStore.updateShipmentPlan(
        plan,
        shipDate: draft.shipDate,
        clientName: draft.clientName,
        materialCode: draft.materialCode,
        materialScope: draft.materialScope,
        quantityUnit: draft.quantityUnit,
        plannedQuantity: draft.plannedQuantity,
        priority: draft.priority,
        status: draft.status,
        notes: draft.notes,
      );
      _toast('Embarque actualizado.');
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo actualizar el embarque: $e');
    } finally {
      if (mounted) setState(() => _runningMutation = false);
    }
  }

  Future<void> _openSuggestedShipments() async {
    final bundle = _bundle;
    if (bundle == null) return;
    final suggestion = await _showSuggestedShipmentsDialog(bundle);
    if (suggestion == null) return;
    final draft = await _showShipmentDialog(
      weekStart: bundle.weekStartDate,
      initialDraft: _draftFromSuggestion(suggestion),
    );
    if (draft == null) return;
    await _saveNewShipmentDraft(
      draft,
      successMessage: 'Embarque sugerido guardado.',
    );
  }

  Future<void> _deleteShipment(DirectionShipmentPlanRecord plan) async {
    final ok = await _confirmAction(
      title: 'Borrar embarque',
      message:
          'Se eliminará el embarque de ${plan.clientName} del ${_shortDate(plan.shipDate)}. Esta acción no se puede deshacer.',
      confirmText: 'Borrar',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _runningMutation = true);
    try {
      await DirectionShipmentsStore.deleteShipmentPlan(plan.id);
      _toast('Embarque eliminado.');
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo borrar el embarque: $e');
    } finally {
      if (mounted) setState(() => _runningMutation = false);
    }
  }

  Future<void> _createImpact({_CapacityImpactDraft? preset}) async {
    final bundle = _bundle;
    if (bundle == null) return;
    final draft = await _showCapacityImpactDialog(
      weekStart: bundle.weekStartDate,
      initialDraft: preset,
    );
    if (draft == null) return;
    setState(() => _runningMutation = true);
    try {
      await DirectionShipmentsStore.createCapacityImpact(
        machineKey: draft.machineKey,
        startDate: draft.startDate,
        endDate: draft.endDate,
        impactPercent: draft.impactPercent,
        notes: draft.notes,
      );
      _toast('Afectación de capacidad guardada.');
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo guardar la afectación: $e');
    } finally {
      if (mounted) setState(() => _runningMutation = false);
    }
  }

  Future<void> _editImpact(
    DirectionProductionCapacityImpactRecord impact,
  ) async {
    final draft = await _showCapacityImpactDialog(
      weekStart: _visibleWeekStartDate,
      initial: impact,
    );
    if (draft == null) return;
    setState(() => _runningMutation = true);
    try {
      await DirectionShipmentsStore.updateCapacityImpact(
        impact,
        machineKey: draft.machineKey,
        startDate: draft.startDate,
        endDate: draft.endDate,
        impactPercent: draft.impactPercent,
        notes: draft.notes,
        isActive: draft.isActive,
      );
      _toast('Afectación actualizada.');
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo actualizar la afectación: $e');
    } finally {
      if (mounted) setState(() => _runningMutation = false);
    }
  }

  Future<void> _deleteImpact(
    DirectionProductionCapacityImpactRecord impact,
  ) async {
    final ok = await _confirmAction(
      title: 'Borrar afectación',
      message:
          'Se eliminará la afectación de ${directionMachineKeyLabel(impact.machineKey)} entre ${_shortDate(impact.startDate)} y ${_shortDate(impact.endDate)}.',
      confirmText: 'Borrar',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _runningMutation = true);
    try {
      await DirectionShipmentsStore.deleteCapacityImpact(impact.id);
      _toast('Afectación eliminada.');
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo borrar la afectación: $e');
    } finally {
      if (mounted) setState(() => _runningMutation = false);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    bool destructive = false,
  }) {
    return showContractConfirmationDialog(
      context,
      title: title,
      content: message,
      confirmText: confirmText,
      destructive: destructive,
      tokens: directionAreaTokens,
    );
  }

  Future<_ShipmentDraft?> _showShipmentDialog({
    required DateTime weekStart,
    DirectionShipmentPlanRecord? initial,
    _ShipmentDraft? initialDraft,
  }) {
    final dates = <DateTime>[
      for (var i = 0; i < 6; i++) weekStart.add(Duration(days: i)),
    ];
    final initialMaterial =
        directionShipmentMaterialByCode(
          initial?.materialCode ?? initialDraft?.materialCode ?? '',
        ) ??
        kDirectionShipmentMaterials.first;
    final clientC = TextEditingController(
      text: initial?.clientName ?? initialDraft?.clientName ?? '',
    );
    final unitsC = TextEditingController(
      text:
          initial?.plannedQuantity.toString() ??
          initialDraft?.plannedQuantity.toString() ??
          '',
    );
    final notesC = TextEditingController(
      text: initial?.notes ?? initialDraft?.notes ?? '',
    );
    var selectedDate =
        initial?.shipDate ?? initialDraft?.shipDate ?? dates.first;
    var selectedMaterial = initialMaterial.code;
    var selectedPriority =
        initial?.priority ?? initialDraft?.priority ?? 'normal';
    var selectedStatus = initial?.status ?? initialDraft?.status ?? 'planeado';

    return showDialog<_ShipmentDraft>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedMaterialOption =
                directionShipmentMaterialByCode(selectedMaterial) ??
                kDirectionShipmentMaterials.first;
            return _DirectionFormDialog(
              icon: Icons.local_shipping_rounded,
              title: initial == null ? 'Nuevo embarque' : 'Editar embarque',
              subtitle:
                  'Captura ejecutiva corta para programar la salida sin perder el pulso del piso, sea material empacado o a granel.',
              maxWidth: 880,
              onClose: () => Navigator.of(dialogContext).pop(),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DialogSectionCard(
                    title: 'Cliente y cantidad',
                    subtitle: 'Solo lo esencial para colocar el embarque.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 430,
                              child: _DirectionDialogField(
                                label: 'Cliente',
                                child: TextField(
                                  controller: clientC,
                                  style: _dialogInputTextStyle(),
                                  decoration: InputDecoration.collapsed(
                                    hintText: 'Nombre corto del cliente',
                                    hintStyle: _dialogHintTextStyle(),
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: _DirectionDialogField(
                                label: selectedMaterialOption.quantityLabel,
                                child: TextField(
                                  controller: unitsC,
                                  style: _dialogInputTextStyle(),
                                  decoration: InputDecoration.collapsed(
                                    hintText:
                                        'Cantidad en ${selectedMaterialOption.shortUnitLabel}',
                                    hintStyle: _dialogHintTextStyle(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DirectionDialogField(
                          label: 'Modo de captura',
                          compact: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${selectedMaterialOption.scopeLabel} · se planea en ${selectedMaterialOption.shortUnitLabel}',
                                  style: _dialogInputTextStyle(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DialogSectionCard(
                    title: 'Día y material',
                    subtitle:
                        'Separa rápido entre material empacado y material a granel.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _DialogLabel(label: 'Día de embarque'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final date in dates)
                              _DialogChoiceChip(
                                label:
                                    '${_weekdayLabel(date)} · ${_shortDate(date)}',
                                selected: _isSameDate(selectedDate, date),
                                onSelected: () =>
                                    setDialogState(() => selectedDate = date),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _DialogLabel(label: 'Empacado'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final material
                                in kDirectionShipmentMaterials.where(
                                  (item) => item.isPacked,
                                ))
                              _DialogChoiceChip(
                                label:
                                    '${material.label} · ${material.shortUnitLabel}',
                                selected: selectedMaterial == material.code,
                                onSelected: () => setDialogState(
                                  () => selectedMaterial = material.code,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _DialogLabel(label: 'Granel'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final material
                                in kDirectionShipmentMaterials.where(
                                  (item) => item.isBulk,
                                ))
                              _DialogChoiceChip(
                                label:
                                    '${material.label} · ${material.shortUnitLabel}',
                                selected: selectedMaterial == material.code,
                                onSelected: () => setDialogState(
                                  () => selectedMaterial = material.code,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DialogSectionCard(
                    title: 'Prioridad y estatus',
                    subtitle:
                        'Esto alimenta la lectura rápida dentro de la planeación semanal.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _DialogLabel(label: 'Prioridad'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final priority in const [
                              ('alta', 'Alta'),
                              ('normal', 'Normal'),
                              ('flexible', 'Flexible'),
                            ])
                              _DialogChoiceChip(
                                label: priority.$2,
                                selected: selectedPriority == priority.$1,
                                onSelected: () => setDialogState(
                                  () => selectedPriority = priority.$1,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _DialogLabel(label: 'Estado'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final status in const [
                              ('planeado', 'Planeado'),
                              ('confirmado', 'Confirmado'),
                              ('movido', 'Movido'),
                              ('embarcado', 'Embarcado'),
                              ('cancelado', 'Cancelado'),
                            ])
                              _DialogChoiceChip(
                                label: status.$2,
                                selected: selectedStatus == status.$1,
                                onSelected: () => setDialogState(
                                  () => selectedStatus = status.$1,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DialogSectionCard(
                    title: 'Nota corta',
                    subtitle: 'Solo si ayuda a dar contexto a Dirección.',
                    child: _DirectionDialogField(
                      label: 'Observación',
                      child: TextField(
                        controller: notesC,
                        style: _dialogInputTextStyle(),
                        decoration: InputDecoration.collapsed(
                          hintText: 'Observación opcional',
                          hintStyle: _dialogHintTextStyle(),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  style: _secondaryActionButtonStyle(context),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: _primaryActionButtonStyle(context),
                  onPressed: () {
                    final clientName = clientC.text.trim();
                    final plannedQuantity =
                        int.tryParse(unitsC.text.trim()) ?? 0;
                    if (clientName.isEmpty || plannedQuantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Captura cliente y una cantidad válida de ${selectedMaterialOption.shortUnitLabel}.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _ShipmentDraft(
                        shipDate: selectedDate,
                        clientName: clientName,
                        materialCode: selectedMaterialOption.code,
                        materialScope: selectedMaterialOption.scope,
                        quantityUnit: selectedMaterialOption.quantityUnit,
                        plannedQuantity: plannedQuantity,
                        priority: selectedPriority,
                        status: selectedStatus,
                        notes: notesC.text.trim(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Guardar embarque'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<_CapacityImpactDraft?> _showCapacityImpactDialog({
    required DateTime weekStart,
    DirectionProductionCapacityImpactRecord? initial,
    _CapacityImpactDraft? initialDraft,
  }) {
    final dates = <DateTime>[
      for (var i = 0; i < 6; i++) weekStart.add(Duration(days: i)),
    ];
    final notesC = TextEditingController(
      text: initial?.notes ?? initialDraft?.notes ?? '',
    );
    var selectedMachine =
        initial?.machineKey ?? initialDraft?.machineKey ?? 'c1';
    var selectedStartDate =
        initial?.startDate ?? initialDraft?.startDate ?? dates.first;
    var selectedEndDate = initial?.endDate ?? initialDraft?.endDate ?? dates[1];
    var selectedPercent =
        initial?.impactPercent ?? initialDraft?.impactPercent ?? 100;
    var selectedActive = initial?.isActive ?? true;

    if (selectedEndDate.isBefore(selectedStartDate)) {
      selectedEndDate = selectedStartDate;
    }

    return showDialog<_CapacityImpactDraft>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final endDateChoices = dates
                .where((date) => !date.isBefore(selectedStartDate))
                .toList(growable: false);
            return _DirectionFormDialog(
              icon: Icons.build_circle_outlined,
              title: initial == null
                  ? 'Nueva alerta rápida'
                  : 'Editar alerta rápida',
              subtitle:
                  'La afectación manual sí pega directo en la proyección para que el semáforo sea más real.',
              maxWidth: 820,
              onClose: () => Navigator.of(dialogContext).pop(),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DialogSectionCard(
                    title: 'Compactadora y rango',
                    subtitle:
                        'Confirma qué equipo se afecta y en qué días de la semana.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _DialogLabel(label: 'Compactadora'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final machine in const [
                              ('c1', 'Compactadora 1'),
                              ('c2', 'Compactadora 2'),
                              ('ambas', 'Compactadoras 1 y 2'),
                            ])
                              _DialogChoiceChip(
                                label: machine.$2,
                                selected: selectedMachine == machine.$1,
                                onSelected: () => setDialogState(
                                  () => selectedMachine = machine.$1,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _DialogLabel(label: 'Desde'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final date in dates)
                              _DialogChoiceChip(
                                label:
                                    '${_weekdayLabel(date)} · ${_shortDate(date)}',
                                selected: _isSameDate(selectedStartDate, date),
                                onSelected: () => setDialogState(() {
                                  selectedStartDate = date;
                                  if (selectedEndDate.isBefore(date)) {
                                    selectedEndDate = date;
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _DialogLabel(label: 'Hasta'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final date in endDateChoices)
                              _DialogChoiceChip(
                                label:
                                    '${_weekdayLabel(date)} · ${_shortDate(date)}',
                                selected: _isSameDate(selectedEndDate, date),
                                onSelected: () => setDialogState(
                                  () => selectedEndDate = date,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DialogSectionCard(
                    title: 'Impacto esperado',
                    subtitle:
                        'El porcentaje representa la parte de capacidad que se pierde.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final impact in const [
                              (100, 'Fuera total (100%)'),
                              (75, 'Afectación fuerte (75%)'),
                              (50, 'Capacidad media (50%)'),
                              (25, 'Afectación ligera (25%)'),
                            ])
                              _DialogChoiceChip(
                                label: impact.$2,
                                selected: selectedPercent == impact.$1,
                                onSelected: () => setDialogState(
                                  () => selectedPercent = impact.$1,
                                ),
                              ),
                          ],
                        ),
                        if (initial != null) ...[
                          const SizedBox(height: 12),
                          const _DialogLabel(label: 'Seguimiento'),
                          _DialogChoiceChip(
                            label: selectedActive
                                ? 'Sigue activa'
                                : 'Marcada como recuperada',
                            selected: selectedActive,
                            onSelected: () => setDialogState(
                              () => selectedActive = !selectedActive,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DialogSectionCard(
                    title: 'Nota operativa',
                    subtitle:
                        'Ejemplo: manguera tronada, sin motor, esperando refacción.',
                    child: _DirectionDialogField(
                      label: 'Nota',
                      child: TextField(
                        controller: notesC,
                        style: _dialogInputTextStyle(),
                        decoration: InputDecoration.collapsed(
                          hintText:
                              'Detalle corto para entender por qué se descuenta capacidad',
                          hintStyle: _dialogHintTextStyle(),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  style: _secondaryActionButtonStyle(context),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: _primaryActionButtonStyle(context),
                  onPressed: () {
                    if (selectedEndDate.isBefore(selectedStartDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La fecha final no puede ser menor que la inicial.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _CapacityImpactDraft(
                        machineKey: selectedMachine,
                        startDate: selectedStartDate,
                        endDate: selectedEndDate,
                        impactPercent: selectedPercent,
                        notes: notesC.text.trim(),
                        isActive: selectedActive,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Guardar alerta'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: directionAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const DirectionExecutiveBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, _) => DirectionHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => DirectionHeaderBrand(
            contentAnim: contentAnim,
            title: 'Embarques Dirección',
          ),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DirectionHeaderButton(
                label: _runningMutation ? 'Guardando...' : 'Actualizar',
                icon: Icons.refresh_rounded,
                width: 144,
                onTap: _runningMutation ? null : () => _load(),
              ),
              const SizedBox(width: 10),
              DirectionHeaderButton(
                label: 'Dashboard',
                icon: Icons.space_dashboard_rounded,
                onTap: _openDashboard,
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1460),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 56, right: 4),
                    child: _buildBody(),
                  ),
                ),
              ),
              _buildOverlayMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _bundle == null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: kDirectionSurfaceText),
          textAlign: TextAlign.center,
        ),
      );
    }

    final bundle = _bundle;
    if (bundle == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DirectionMetricCard(
                icon: Icons.inventory_2_outlined,
                title: 'PISO ACTUAL',
                value: '${bundle.activeFloorMaterialCount} materiales',
                detail: _floorCountMetricDetail(bundle),
                accent: _freshnessColor(bundle.floorCountFreshness),
              ),
              DirectionMetricCard(
                icon: Icons.trending_up_rounded,
                title: 'PROY. FUTURA',
                value: '${bundle.projectedMaterialCount} materiales',
                detail: _projectionMetricDetail(bundle),
                accent: kDirectionSuccess,
              ),
              DirectionMetricCard(
                icon: Icons.local_shipping_rounded,
                title: 'EMBARQUES',
                value: '${bundle.pendingShipmentCount} renglones',
                detail:
                    '${bundle.highPriorityShipmentCount} alta · ${bundle.confirmedShipmentCount} confirmados',
                accent: kDirectionGoldAccent,
              ),
              DirectionMetricCard(
                icon: Icons.warning_amber_rounded,
                title: 'RIESGO',
                value: '${bundle.atRiskShipmentCount} rojo',
                detail: '${bundle.tightShipmentCount} justo / amarillo',
                accent: bundle.atRiskShipmentCount > 0
                    ? kDirectionDanger
                    : kDirectionWarning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          DirectionToolbarPanel(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              spacing: 12,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(
                    'La proyección cruza conteo de piso fresco + producción esperada futura por historial promedio - compromisos previos. En el día del embarque solo cuenta turno día para completar saldo; la noche no salva la carga del mismo día. Mezcla pacas y kg según el material; no usa inventario sistema.',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WeekNavButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Semana anterior',
                      onPressed: _openPreviousWeek,
                    ),
                    OutlinedButton.icon(
                      style: _secondaryActionButtonStyle(context),
                      onPressed: _isViewingCurrentWeek
                          ? null
                          : _openCurrentWeek,
                      icon: const Icon(Icons.today_rounded, size: 18),
                      label: Text(
                        _isViewingCurrentWeek ? 'Semana actual' : 'Ir a actual',
                      ),
                    ),
                    _WeekNavButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Semana siguiente',
                      onPressed: _canGoToNextWeek ? _openNextWeek : null,
                    ),
                    OutlinedButton.icon(
                      style: _secondaryActionButtonStyle(context),
                      onPressed: _runningMutation
                          ? null
                          : () => _openSuggestedShipments(),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Embarques sugeridos'),
                    ),
                    FilledButton.icon(
                      style: _primaryActionButtonStyle(context),
                      onPressed: _runningMutation ? null : _createShipment,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuevo embarque'),
                    ),
                    OutlinedButton.icon(
                      style: _secondaryActionButtonStyle(context),
                      onPressed: _runningMutation
                          ? null
                          : () => _createImpact(),
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Alerta compactadora'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ExpectedProductionStrip(bundle: bundle),
          const SizedBox(height: 14),
          _CapacityAlertsPanel(
            bundle: bundle,
            onEditImpact: _editImpact,
            onDeleteImpact: _deleteImpact,
            onCreateImpactFromAlert: (alert) {
              final startDate = DateTime(
                alert.requestedAt.year,
                alert.requestedAt.month,
                alert.requestedAt.day,
              );
              return _createImpact(
                preset: _CapacityImpactDraft(
                  machineKey: alert.machineKey,
                  startDate: startDate,
                  endDate: startDate.add(const Duration(days: 1)),
                  impactPercent: 100,
                  notes: alert.problemSummary,
                  isActive: true,
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _ShipmentsGridPanel(
            bundle: bundle,
            onEditShipment: _editShipment,
            onDeleteShipment: _deleteShipment,
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayMenu() {
    const overlayWidth = 320.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: _menuOpen ? 0 : -(overlayWidth + 12),
      top: 0,
      width: overlayWidth,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_menuOpen,
        child: SingleChildScrollView(
          child: DirectionModuleMenuPanel(
            entries: [
              DirectionModuleMenuEntry(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Dirección',
                subtitle: 'Resumen ejecutivo principal',
                onTap: _openDashboard,
              ),
              const DirectionModuleMenuEntry(
                icon: Icons.local_shipping_rounded,
                title: 'Embarques',
                subtitle: 'Planeación semanal y semáforos',
                current: true,
              ),
              DirectionModuleMenuEntry(
                icon: Icons.build_circle_outlined,
                title: 'Mantenimiento OT',
                subtitle: 'Seguimiento de equipos y OT abiertas',
                onTap: _openMaintenance,
              ),
              DirectionModuleMenuEntry(
                icon: Icons.stacked_line_chart_rounded,
                title: 'Gerencia',
                subtitle: 'Pulso semanal de producción y embarque',
                onTap: _openGerencia,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ShipmentDraft _draftFromSuggestion(
    DirectionSuggestedShipmentRecord suggestion,
  ) {
    return _ShipmentDraft(
      shipDate: suggestion.suggestedDate,
      clientName: suggestion.clientName,
      materialCode: suggestion.materialCode,
      materialScope: suggestion.materialScope,
      quantityUnit: suggestion.quantityUnit,
      plannedQuantity: suggestion.suggestedQuantity,
      priority:
          suggestion.risk == DirectionShipmentRisk.tight ||
              suggestion.risk == DirectionShipmentRisk.atRisk
          ? 'alta'
          : 'normal',
      status: 'planeado',
      notes: 'Sugerido: ${suggestion.explanation}',
    );
  }

  Future<DirectionSuggestedShipmentRecord?> _showSuggestedShipmentsDialog(
    DirectionShipmentPlanningBundle bundle,
  ) {
    final suggestions = bundle.suggestedShipments;
    final totalSuggested = suggestions.fold<int>(
      0,
      (sum, item) => sum + item.suggestedQuantity,
    );
    final uniqueClients = suggestions
        .map((item) => item.clientName)
        .toSet()
        .length;
    return showDialog<DirectionSuggestedShipmentRecord>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      builder: (dialogContext) {
        return _DirectionFormDialog(
          icon: Icons.auto_awesome_rounded,
          title: 'Embarques sugeridos',
          subtitle:
              'Cruza meta semanal de Gerencia, historial real de salidas en paca y piso + proyección futura para esta semana.',
          maxWidth: 980,
          onClose: () => Navigator.of(dialogContext).pop(),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogSectionCard(
                title: 'Lectura rápida',
                subtitle:
                    'La sugerencia ya descuenta lo que sí salió y lo que ya está capturado en Embarques.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      label: '${suggestions.length} sugerencias',
                      accent: kDirectionOliveGlow,
                    ),
                    _InfoChip(
                      label: '$totalSuggested pacas sugeridas',
                      accent: kDirectionGoldAccent,
                    ),
                    _InfoChip(
                      label: '$uniqueClients clientes priorizados',
                      accent: kDirectionSuccess,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (suggestions.isEmpty)
                const _DialogSectionCard(
                  title: 'Sin sugerencias listas',
                  subtitle:
                      'Para la semana visible ya no queda hueco claro de meta o falta historial suficiente en los clientes priorizados.',
                  child: Text(
                    'Si capturas más conteo de piso o ajustas la meta semanal de Gerencia, este popup se recalcula solo.',
                    style: TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                )
              else
                _DialogSectionCard(
                  title: 'Semana ${_isoWeekNumber(bundle.weekStartDate)}',
                  subtitle:
                      'Prioridad aplicada: El Palomar, San Pablo, San Luis, Queretana, Bio Papel, Majose y Ricardo Mendieta.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < suggestions.length; i++) ...[
                        _SuggestedShipmentCard(
                          suggestion: suggestions[i],
                          onUse: () =>
                              Navigator.of(dialogContext).pop(suggestions[i]),
                        ),
                        if (i < suggestions.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: _secondaryActionButtonStyle(context),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class _ExpectedProductionStrip extends StatelessWidget {
  final DirectionShipmentPlanningBundle bundle;

  const _ExpectedProductionStrip({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proyección esperada por día',
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Se lista por material y unidad. No mezcla todo en una sola cifra porque aquí conviven pacas y kg.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semana ${_isoWeekNumber(bundle.weekStartDate)} · ${_shortDate(bundle.weekStartDate)} - ${_shortDate(bundle.weekEndDate)}',
            style: const TextStyle(
              color: kDirectionSubtleText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final day in bundle.expectedDays)
                _ExpectedDayCard(
                  day: day,
                  isToday: _isSameDate(day.date, DateTime.now()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpectedDayCard extends StatelessWidget {
  final DirectionProductionExpectationDay day;
  final bool isToday;

  const _ExpectedDayCard({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final projectedLines = _materialProjectionLines(
      day.expectedByMaterial,
      maxItems: 3,
    );
    final lossLines = _materialProjectionLines(day.lossByMaterial, maxItems: 2);
    return Container(
      width: 226,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isToday ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: isToday ? 0.22 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _weekdayLabel(day.date),
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kDirectionOliveGlow.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Hoy',
                    style: TextStyle(
                      color: kDirectionOliveGlow,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _shortDate(day.date),
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (projectedLines.isEmpty)
            const Text(
              'Sin producción esperada',
              style: TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in projectedLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: kDirectionSurfaceText,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
              ],
            ),
          if (lossLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Ajuste por equipo',
              style: TextStyle(
                color: kDirectionDanger,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            for (final line in lossLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '-$line',
                  style: const TextStyle(
                    color: kDirectionDanger,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CapacityAlertsPanel extends StatelessWidget {
  final DirectionShipmentPlanningBundle bundle;
  final Future<void> Function(DirectionProductionCapacityImpactRecord impact)
  onEditImpact;
  final Future<void> Function(DirectionProductionCapacityImpactRecord impact)
  onDeleteImpact;
  final Future<void> Function(DirectionCompactorMaintenanceAlert alert)
  onCreateImpactFromAlert;

  const _CapacityAlertsPanel({
    required this.bundle,
    required this.onEditImpact,
    required this.onDeleteImpact,
    required this.onCreateImpactFromAlert,
  });

  @override
  Widget build(BuildContext context) {
    final hasRows =
        bundle.impactSummaries.isNotEmpty ||
        bundle.maintenanceAlerts.isNotEmpty;
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capacidad de compactadoras',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las alertas manuales sí descuentan producción de la proyección. Las OT abiertas de mantenimiento solo avisan hasta que se confirme el impacto.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasRows)
            const Text(
              'No hay compactadoras afectadas ni OT abiertas que requieran atención en esta semana.',
              style: TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final summary in bundle.impactSummaries)
                  _ManualImpactCard(
                    summary: summary,
                    onEdit: () => onEditImpact(summary.impact),
                    onDelete: () => onDeleteImpact(summary.impact),
                  ),
                for (final alert in bundle.maintenanceAlerts)
                  _MaintenanceImpactCard(
                    alert: alert,
                    onCreateImpact: alert.confirmedByManualImpact
                        ? null
                        : () => onCreateImpactFromAlert(alert),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ManualImpactCard extends StatelessWidget {
  final DirectionCapacityImpactSummary summary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ManualImpactCard({
    required this.summary,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final impact = summary.impact;
    final accent = impact.impactPercent >= 75
        ? kDirectionDanger
        : kDirectionWarning;
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  directionMachineKeyLabel(impact.machineKey),
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${impact.impactPercent}%',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_shortDate(impact.startDate)} - ${_shortDate(impact.endDate)}',
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (summary.impactedMaterialCodes.isEmpty)
            const Text(
              'Ajusta la proyección del equipo en los días capturados. Si el histórico del equipo todavía no es suficiente, el semáforo se apoya más en piso actual.',
              style: TextStyle(
                color: kDirectionSurfaceText,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: '${summary.impactedDaysCount} día(s) ajustados',
                  accent: accent,
                ),
                for (final materialCode in summary.impactedMaterialCodes)
                  _InfoChip(
                    label: directionShipmentMaterialLabel(materialCode),
                    accent: kDirectionOliveGlow,
                  ),
              ],
            ),
          if (impact.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              impact.notes,
              style: const TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                style: _secondaryActionButtonStyle(context, dense: true),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Editar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: _dangerSecondaryButtonStyle(context, dense: true),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Borrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceImpactCard extends StatelessWidget {
  final DirectionCompactorMaintenanceAlert alert;
  final VoidCallback? onCreateImpact;

  const _MaintenanceImpactCard({
    required this.alert,
    required this.onCreateImpact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.folio.isEmpty ? 'OT abierta' : alert.folio,
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      (alert.confirmedByManualImpact
                              ? kDirectionSuccess
                              : kDirectionWarning)
                          .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  alert.confirmedByManualImpact ? 'Confirmada' : 'Pendiente',
                  style: TextStyle(
                    color: alert.confirmedByManualImpact
                        ? kDirectionSuccess
                        : kDirectionWarning,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${directionMachineKeyLabel(alert.machineKey)} · ${maintenanceStatusLabel(alert.status)}',
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aviso ${_shortDate(alert.requestedAt)}',
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (alert.problemSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              alert.problemSummary,
              style: const TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (onCreateImpact != null)
            FilledButton.icon(
              style: _primaryActionButtonStyle(context, dense: true),
              onPressed: onCreateImpact,
              icon: const Icon(Icons.add_alert_rounded, size: 18),
              label: const Text('Capturar impacto'),
            )
          else
            const Text(
              'Ya existe una alerta manual cubriendo este aviso.',
              style: TextStyle(
                color: kDirectionSuccess,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShipmentsGridPanel extends StatelessWidget {
  final DirectionShipmentPlanningBundle bundle;
  final Future<void> Function(DirectionShipmentPlanRecord plan) onEditShipment;
  final Future<void> Function(DirectionShipmentPlanRecord plan)
  onDeleteShipment;

  const _ShipmentsGridPanel({
    required this.bundle,
    required this.onEditShipment,
    required this.onDeleteShipment,
  });

  @override
  Widget build(BuildContext context) {
    final projections = bundle.projections;
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planeación semanal',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cada renglón muestra el saldo proyectado del material a la fecha del embarque, considerando piso actual, producción futura esperada y compromisos previos del mismo material.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (projections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay embarques capturados en esta semana todavía.',
                style: TextStyle(
                  color: kDirectionMutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in <DateTime>[
                  for (var i = 0; i < 6; i++)
                    bundle.weekStartDate.add(Duration(days: i)),
                ]) ...[
                  _ShipDayHeader(
                    date: day,
                    expectedDay: _expectedDayForDate(bundle.expectedDays, day),
                  ),
                  const SizedBox(height: 8),
                  ..._rowsForDay(
                    date: day,
                    projections: projections,
                    onEditShipment: onEditShipment,
                    onDeleteShipment: onDeleteShipment,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _rowsForDay({
    required DateTime date,
    required List<DirectionShipmentPlanProjection> projections,
    required Future<void> Function(DirectionShipmentPlanRecord plan)
    onEditShipment,
    required Future<void> Function(DirectionShipmentPlanRecord plan)
    onDeleteShipment,
  }) {
    final rows = projections
        .where((row) => _isSameDate(row.plan.shipDate, date))
        .toList(growable: false);
    if (rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Sin embarques capturados para este día.',
            style: TextStyle(
              color: kDirectionSubtleText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ];
    }
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ShipmentProjectionRow(
            projection: row,
            onEdit: () => onEditShipment(row.plan),
            onDelete: () => onDeleteShipment(row.plan),
          ),
        ),
    ];
  }
}

class _ShipDayHeader extends StatelessWidget {
  final DateTime date;
  final DirectionProductionExpectationDay? expectedDay;

  const _ShipDayHeader({required this.date, required this.expectedDay});

  @override
  Widget build(BuildContext context) {
    final projectedCount = expectedDay?.projectedMaterialCount ?? 0;
    final adjustedCount = expectedDay?.adjustedMaterialCount ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_weekdayLabel(date)} · ${_shortDate(date)}',
              style: const TextStyle(
                color: kDirectionSurfaceText,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: '$projectedCount materiales con salida',
                accent: kDirectionOliveGlow,
              ),
              if (adjustedCount > 0)
                _InfoChip(
                  label: '$adjustedCount con ajuste',
                  accent: kDirectionDanger,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShipmentProjectionRow extends StatelessWidget {
  final DirectionShipmentPlanProjection projection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShipmentProjectionRow({
    required this.projection,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final riskStyle = _riskStyle(projection.risk);
    final plan = projection.plan;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.clientName,
                      style: const TextStyle(
                        color: kDirectionSurfaceText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label: directionShipmentMaterialLabel(
                            plan.materialCode,
                          ),
                          accent: kDirectionOliveGlow,
                        ),
                        _InfoChip(
                          label: _formatMaterialQuantity(
                            plan.materialCode,
                            plan.plannedQuantity,
                          ),
                          accent: kDirectionGoldAccent,
                        ),
                        _InfoChip(
                          label: directionShipmentMaterialScopeLabel(
                            plan.materialCode,
                          ),
                          accent: kDirectionOliveMist,
                        ),
                        _InfoChip(
                          label: _priorityLabel(plan.priority),
                          accent: _priorityAccent(plan.priority),
                        ),
                        _InfoChip(
                          label: _statusLabel(plan.status),
                          accent: _statusAccent(plan.status),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RiskChip(style: riskStyle),
            ],
          ),
          if (plan.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              plan.notes,
              style: const TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProjectionStatCard(
                title: 'Saldo proyectado',
                accent: riskStyle.color,
                primary:
                    'Antes ${_formatMaterialQuantity(plan.materialCode, projection.projectedAvailableBeforeQuantity)}',
                secondary:
                    'Después ${_formatMaterialQuantity(plan.materialCode, projection.projectedRemainingAfterQuantity)}',
              ),
              _ProjectionStatCard(
                title: 'Producción esperada',
                accent: kDirectionSuccess,
                primary:
                    '+${_formatMaterialQuantity(plan.materialCode, projection.expectedFutureQuantity)}',
                secondary: 'Promedio histórico al día del embarque',
              ),
              _ProjectionStatCard(
                title: 'Compromisos previos',
                accent: kDirectionWarning,
                primary:
                    '-${_formatMaterialQuantity(plan.materialCode, projection.priorCommittedQuantity)}',
                secondary: 'Mismo tipo comprometido antes de este renglón',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: _secondaryActionButtonStyle(context, dense: true),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                style: _dangerSecondaryButtonStyle(context, dense: true),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Borrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  final _RiskStyle style;

  const _RiskChip({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.color.withValues(alpha: 0.28)),
      ),
      child: Text(
        style.label,
        style: TextStyle(color: style.color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _WeekNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _WeekNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: _secondaryActionButtonStyle(context, dense: true),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _SuggestedShipmentCard extends StatelessWidget {
  final DirectionSuggestedShipmentRecord suggestion;
  final VoidCallback onUse;

  const _SuggestedShipmentCard({required this.suggestion, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final riskStyle = _riskStyle(suggestion.risk);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.clientName,
                      style: const TextStyle(
                        color: kDirectionSurfaceText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label:
                              '${_weekdayLabel(suggestion.suggestedDate)} · ${_shortDate(suggestion.suggestedDate)}',
                          accent: kDirectionSuccess,
                        ),
                        _InfoChip(
                          label: directionShipmentMaterialLabel(
                            suggestion.materialCode,
                          ),
                          accent: kDirectionOliveGlow,
                        ),
                        _InfoChip(
                          label: _formatMaterialQuantity(
                            suggestion.materialCode,
                            suggestion.suggestedQuantity,
                          ),
                          accent: kDirectionGoldAccent,
                        ),
                        if (suggestion.noteMatched)
                          const _InfoChip(
                            label: 'Nota Gerencia',
                            accent: kDirectionWarning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RiskChip(style: riskStyle),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.explanation,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProjectionStatCard(
                title: 'Meta pendiente',
                accent: kDirectionWarning,
                primary:
                    '${suggestion.remainingGerenciaTargetQuantity} pacas por cubrir',
                secondary: 'Ya contempla lo real y lo ya planeado',
              ),
              _ProjectionStatCard(
                title: 'Piso + proyección',
                accent: riskStyle.color,
                primary:
                    'Antes ${_formatMaterialQuantity(suggestion.materialCode, suggestion.projectedAvailableBeforeQuantity)}',
                secondary:
                    'Después ${_formatMaterialQuantity(suggestion.materialCode, suggestion.projectedRemainingAfterQuantity)}',
              ),
              _ProjectionStatCard(
                title: 'Historial cliente',
                accent: kDirectionSuccess,
                primary: suggestion.historicalShipmentCount > 0
                    ? 'Prom ${suggestion.historicalAverageQuantity} pacas'
                    : 'Sin promedio fuerte',
                secondary: suggestion.lastShipmentDate == null
                    ? 'Sin salida previa clara en historial reciente'
                    : '${suggestion.historicalShipmentCount} salidas · última ${_shortDate(suggestion.lastShipmentDate!)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: _primaryActionButtonStyle(context, dense: true),
              onPressed: onUse,
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: const Text('Usar sugerencia'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionFormDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback onClose;
  final double maxWidth;

  const _DirectionFormDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    required this.onClose,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: AreaThemeScope(
        tokens: directionAreaTokens,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: directionAreaTokens.primary,
              secondary: directionAreaTokens.accent,
              surface: kDirectionMenuSurface,
              onSurface: kDirectionSurfaceText,
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: directionAreaTokens.primary,
              selectionColor: directionAreaTokens.primarySoft.withValues(
                alpha: 0.48,
              ),
              selectionHandleColor: directionAreaTokens.primary,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 840),
            child: DirectionGlassPanel(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              borderRadius: BorderRadius.circular(32),
              blurSigma: 34,
              fillColor: kDirectionOliveDeep.withValues(alpha: 0.78),
              borderColor: Colors.white.withValues(alpha: 0.26),
              shadowColor: Colors.black.withValues(alpha: 0.24),
              edgeHighlightColor: Colors.white.withValues(alpha: 0.70),
              bevelShadowColor: Colors.black.withValues(alpha: 0.18),
              glowColor: kDirectionOliveGlow.withValues(alpha: 0.10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DirectionDialogHeader(onClose: onClose),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          kDirectionInteractiveSurface.withValues(alpha: 0.88),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: kDirectionInteractiveSelected.withValues(
                              alpha: 0.92,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(icon, color: kDirectionSurfaceText),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: kDirectionSurfaceText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: kDirectionMutedText,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(child: SingleChildScrollView(child: body)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: actions,
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
    );
  }
}

class _DialogSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _DialogSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 22,
      fillColor: kDirectionInteractiveSurfaceStrong.withValues(alpha: 0.26),
      borderColor: Colors.white.withValues(alpha: 0.20),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.56),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kDirectionOliveGlow.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DirectionDialogHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _DirectionDialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            kDirectionInteractiveSurface.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DicsaLogoD(size: 32),
                SizedBox(width: 10),
                Text(
                  'DICSA',
                  style: TextStyle(
                    color: kDirectionSurfaceText,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
          _DirectionDialogHeaderAction(
            icon: Icons.close_rounded,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _DirectionDialogHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _DirectionDialogHeaderAction({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                kDirectionInteractiveSelected.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: onTap == null
                ? kDirectionMutedText.withValues(alpha: 0.42)
                : kDirectionSurfaceText,
          ),
        ),
      ),
    );
  }
}

class _DirectionDialogField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool compact;

  const _DirectionDialogField({
    required this.label,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
          : const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            kDirectionInteractiveSurfaceStrong.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: compact ? 0.20 : 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12,
              fontWeight: FontWeight.w900,
              color: kDirectionMutedText,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          child,
        ],
      ),
    );
  }
}

class _DialogChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _DialogChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [
                      Colors.white.withValues(alpha: 0.16),
                      kDirectionInteractiveSelected.withValues(alpha: 0.94),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.10),
                      kDirectionInteractiveSurfaceStrong.withValues(
                        alpha: 0.82,
                      ),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? kDirectionOliveGlow.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? kDirectionSurfaceText : kDirectionMutedText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectionStatCard extends StatelessWidget {
  final String title;
  final String primary;
  final String secondary;
  final Color accent;

  const _ProjectionStatCard({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 228,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            primary,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondary,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _InfoChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  final String label;

  const _DialogLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: kDirectionSurfaceText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ShipmentDraft {
  final DateTime shipDate;
  final String clientName;
  final String materialCode;
  final DirectionShipmentMaterialScope materialScope;
  final DirectionShipmentQuantityUnit quantityUnit;
  final int plannedQuantity;
  final String priority;
  final String status;
  final String notes;

  const _ShipmentDraft({
    required this.shipDate,
    required this.clientName,
    required this.materialCode,
    required this.materialScope,
    required this.quantityUnit,
    required this.plannedQuantity,
    required this.priority,
    required this.status,
    required this.notes,
  });
}

class _CapacityImpactDraft {
  final String machineKey;
  final DateTime startDate;
  final DateTime endDate;
  final int impactPercent;
  final String notes;
  final bool isActive;

  const _CapacityImpactDraft({
    required this.machineKey,
    required this.startDate,
    required this.endDate,
    required this.impactPercent,
    required this.notes,
    required this.isActive,
  });
}

class _RiskStyle {
  final String label;
  final Color color;

  const _RiskStyle({required this.label, required this.color});
}

_RiskStyle _riskStyle(DirectionShipmentRisk risk) {
  switch (risk) {
    case DirectionShipmentRisk.good:
      return const _RiskStyle(label: 'Verde', color: kDirectionSuccess);
    case DirectionShipmentRisk.tight:
      return const _RiskStyle(label: 'Amarillo', color: kDirectionWarning);
    case DirectionShipmentRisk.atRisk:
      return const _RiskStyle(label: 'Rojo', color: kDirectionDanger);
    case DirectionShipmentRisk.overdue:
      return const _RiskStyle(label: 'Vencido', color: kDirectionWarning);
    case DirectionShipmentRisk.shipped:
      return const _RiskStyle(label: 'Embarcado', color: kDirectionOliveGlow);
    case DirectionShipmentRisk.cancelled:
      return const _RiskStyle(label: 'Cancelado', color: kDirectionSubtleText);
    case DirectionShipmentRisk.unknown:
      return const _RiskStyle(label: 'Sin conteo', color: kDirectionWarning);
  }
}

Color _freshnessColor(DirectionFloorCountFreshness freshness) {
  switch (freshness) {
    case DirectionFloorCountFreshness.fresh:
      return kDirectionSuccess;
    case DirectionFloorCountFreshness.aging:
      return kDirectionWarning;
    case DirectionFloorCountFreshness.stale:
      return kDirectionDanger;
    case DirectionFloorCountFreshness.missing:
      return kDirectionWarning;
  }
}

String _floorCountMetricDetail(DirectionShipmentPlanningBundle bundle) {
  final freshness = _floorCountFreshnessLabel(bundle);
  final summary = _materialSummaryFromMap(
    bundle.floorCountByMaterial,
    maxItems: 2,
  );
  if (summary.isEmpty) return freshness;
  return '$freshness · $summary';
}

String _floorCountFreshnessLabel(DirectionShipmentPlanningBundle bundle) {
  switch (bundle.floorCountFreshness) {
    case DirectionFloorCountFreshness.fresh:
      return 'Conteo fresco · ${_freshnessAgeLabel(bundle.floorCountUpdatedAt)}';
    case DirectionFloorCountFreshness.aging:
      return 'Conteo con horas · ${_freshnessAgeLabel(bundle.floorCountUpdatedAt)}';
    case DirectionFloorCountFreshness.stale:
      return 'Conteo viejo · ${_freshnessAgeLabel(bundle.floorCountUpdatedAt)}';
    case DirectionFloorCountFreshness.missing:
      return 'Sin conteo reciente por tipo';
  }
}

String _freshnessAgeLabel(DateTime? updatedAt) {
  if (updatedAt == null) return 'sin hora';
  final age = DateTime.now().difference(updatedAt);
  if (age.inMinutes < 60) return 'hace ${age.inMinutes} min';
  if (age.inHours < 24) return 'hace ${age.inHours} h';
  return 'hace ${age.inDays} d';
}

String _projectionMetricDetail(DirectionShipmentPlanningBundle bundle) {
  final tomorrow = _expectedDayForDate(
    bundle.expectedDays,
    DateTime.now().add(const Duration(days: 1)),
  );
  if (tomorrow == null || tomorrow.projectedMaterialCount == 0) {
    return 'Mañana sin salida esperada';
  }
  return 'Mañana ${_materialSummaryFromMap(tomorrow.expectedByMaterial, maxItems: 2)}';
}

ButtonStyle _primaryActionButtonStyle(
  BuildContext context, {
  bool dense = false,
}) {
  return FilledButton.styleFrom(
    backgroundColor: kDirectionInteractiveSelected.withValues(alpha: 0.96),
    foregroundColor: kDirectionSurfaceText,
    disabledBackgroundColor: kDirectionInteractiveSurface.withValues(
      alpha: 0.58,
    ),
    disabledForegroundColor: kDirectionSurfaceText.withValues(alpha: 0.46),
    padding: EdgeInsets.symmetric(
      horizontal: dense ? 14 : 16,
      vertical: dense ? 10 : 12,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
    minimumSize: Size(0, dense ? 42 : 48),
    elevation: 0,
  );
}

ButtonStyle _secondaryActionButtonStyle(
  BuildContext context, {
  bool dense = false,
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: kDirectionSurfaceText,
    backgroundColor: kDirectionInteractiveSurfaceStrong.withValues(alpha: 0.58),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    padding: EdgeInsets.symmetric(
      horizontal: dense ? 14 : 16,
      vertical: dense ? 10 : 12,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
    minimumSize: Size(0, dense ? 42 : 48),
  );
}

ButtonStyle _dangerSecondaryButtonStyle(
  BuildContext context, {
  bool dense = false,
}) {
  final base = _secondaryActionButtonStyle(context, dense: dense);
  return base.copyWith(
    foregroundColor: const WidgetStatePropertyAll(kDirectionDanger),
    backgroundColor: WidgetStatePropertyAll(
      kDirectionInteractiveSurfaceStrong.withValues(alpha: 0.58),
    ),
    side: WidgetStatePropertyAll(
      BorderSide(color: kDirectionDanger.withValues(alpha: 0.28)),
    ),
  );
}

TextStyle _dialogInputTextStyle() => const TextStyle(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  color: kDirectionIvory,
);

TextStyle _dialogHintTextStyle() => TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: kDirectionMutedText.withValues(alpha: 0.84),
);

Color _priorityAccent(String priority) {
  switch (priority.trim().toLowerCase()) {
    case 'alta':
      return kDirectionDanger;
    case 'flexible':
      return kDirectionOliveMist;
    default:
      return kDirectionWarning;
  }
}

Color _statusAccent(String status) {
  switch (status.trim().toLowerCase()) {
    case 'confirmado':
      return kDirectionSuccess;
    case 'embarcado':
      return kDirectionOliveGlow;
    case 'movido':
      return kDirectionWarning;
    case 'cancelado':
      return kDirectionDanger;
    default:
      return kDirectionOliveMist;
  }
}

String _priorityLabel(String priority) {
  switch (priority.trim().toLowerCase()) {
    case 'alta':
      return 'Alta';
    case 'flexible':
      return 'Flexible';
    default:
      return 'Normal';
  }
}

String _statusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'confirmado':
      return 'Confirmado';
    case 'embarcado':
      return 'Embarcado';
    case 'movido':
      return 'Movido';
    case 'cancelado':
      return 'Cancelado';
    default:
      return 'Planeado';
  }
}

String _weekdayLabel(DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
      return 'Lunes';
    case DateTime.tuesday:
      return 'Martes';
    case DateTime.wednesday:
      return 'Miércoles';
    case DateTime.thursday:
      return 'Jueves';
    case DateTime.friday:
      return 'Viernes';
    case DateTime.saturday:
      return 'Sábado';
    case DateTime.sunday:
      return 'Domingo';
    default:
      return '';
  }
}

String _shortDate(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$dd/$mm/${date.year}';
}

int _isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final start = firstThursday.add(Duration(days: 4 - firstThursday.weekday));
  return ((thursday.difference(start).inDays) / 7).floor() + 1;
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DirectionProductionExpectationDay? _expectedDayForDate(
  List<DirectionProductionExpectationDay> expectedDays,
  DateTime date,
) {
  for (final day in expectedDays) {
    if (_isSameDate(day.date, date)) return day;
  }
  return null;
}

String _formatMaterialQuantity(String materialCode, int quantity) {
  final unit = directionShipmentMaterialUnitShortLabel(materialCode);
  return '$quantity $unit';
}

List<String> _materialProjectionLines(
  Map<String, int> quantities, {
  int maxItems = 3,
}) {
  final entries =
      quantities.entries
          .where((entry) => entry.value > 0)
          .toList(growable: false)
        ..sort(
          (a, b) => _materialSortKey(a.key).compareTo(_materialSortKey(b.key)),
        );
  return entries
      .take(maxItems)
      .map(
        (entry) =>
            '${directionShipmentMaterialLabel(entry.key)} ${_formatMaterialQuantity(entry.key, entry.value)}',
      )
      .toList(growable: false);
}

String _materialSummaryFromMap(
  Map<String, int> quantities, {
  int maxItems = 2,
}) {
  return _materialProjectionLines(quantities, maxItems: maxItems).join(' · ');
}

int _materialSortKey(String materialCode) {
  final option = directionShipmentMaterialByCode(materialCode);
  return option?.sortOrder ?? 999;
}
