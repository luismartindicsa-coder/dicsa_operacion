import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/archetypes/grid_editable/inline/inline_editable_number_cell.dart';
import '../../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../../shared/utils/file_download_save.dart';
import '../direction_shipments_store.dart';
import '../direction_theme.dart';
import 'operating_program_engine.dart';
import 'operating_program_models.dart';
import 'operating_program_pdf.dart';
import 'operating_program_repository.dart';

class OperatingProgramView extends StatefulWidget {
  final DirectionShipmentPlanningBundle bundle;
  final Future<void> Function(DateTime) onWeekChanged;
  final OperatingProgramRepository? repository;
  const OperatingProgramView({
    super.key,
    required this.bundle,
    required this.onWeekChanged,
    this.repository,
  });
  @override
  State<OperatingProgramView> createState() => OperatingProgramViewState();
}

class OperatingProgramViewState extends State<OperatingProgramView> {
  late final OperatingProgramRepository _repository;
  late ProgramConditions _conditions;
  late List<ProgramDemand> _demands;
  List<ProgramLine> _lines = emptyProgramLines();
  List<ProgramLine>? _actual;
  List<OperatingProgram> _versions = [];
  OperatingProgram? _selected;
  bool _loading = true, _busy = false, _dirty = false, _yardConfirmed = false;
  bool _loadFailed = false;
  final Set<String> _invalidFields = {};
  int _versionsRequest = 0;
  int _dayShareRevision = 0;
  String? _error, _actualError;
  String? _exportMessage;
  bool _exportFailed = false;
  Timer? _timer;
  DateTime get _week => widget.bundle.weekStartDate;
  bool get _locked => _selected != null && _selected!.status != 'draft';
  bool get _editable => !_locked && !_loading && !_busy && !_loadFailed;
  bool get _canSave => _editable && _yardConfirmed && _invalidFields.isEmpty;
  bool get _sourcesChanged =>
      programDemandFingerprint(_demands) !=
      programDemandFingerprint(
        ProgramDemand.fromShipments(_week, widget.bundle.shipments),
      );
  ProgramEvaluation get _evaluation =>
      evaluateOperatingProgram(_week, _conditions, _demands, _lines);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OperatingProgramRepository();
    _conditions = ProgramConditions.fromReference(widget.bundle);
    _demands = ProgramDemand.fromShipments(_week, widget.bundle.shipments);
    unawaited(_loadVersions());
    unawaited(_loadActual());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) unawaited(_loadVersions(silent: true));
      unawaited(_loadActual());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadVersions({bool silent = false}) async {
    final request = ++_versionsRequest;
    try {
      final versions = await _repository.loadVersions(_week);
      if (!mounted || _busy || request != _versionsRequest) return;
      setState(() {
        _versions = versions;
        _loading = false;
        _loadFailed = false;
        _error = null;
        if (!_dirty && _selected == null && versions.isNotEmpty) {
          _select(
            versions.where((v) => v.operational).firstOrNull ?? versions.first,
          );
        } else if (!_dirty && _selected != null) {
          final refreshed = versions
              .where((v) => v.id == _selected!.id)
              .firstOrNull;
          if (refreshed != null) _select(refreshed);
        }
      });
    } catch (e) {
      if (!mounted || request != _versionsRequest) return;
      setState(() {
        _loading = false;
        _loadFailed = _versions.isEmpty;
        _error = 'No se pudo leer el historial del programa. $e';
      });
    }
  }

  Future<void> _loadActual() async {
    try {
      final actual = await _repository.loadActual(_week);
      if (mounted) {
        setState(() {
          _actual = actual;
          _actualError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _actualError = 'No se pudo consultar la producción real.',
        );
      }
    }
  }

  void _select(OperatingProgram program) {
    _selected = program;
    _conditions = program.conditions;
    _demands = program.demands;
    _lines = program.lines;
    _dirty = false;
    _invalidFields.clear();
    _yardConfirmed = true;
  }

  Future<bool> _discard() async {
    if (!_dirty) return true;
    return await showContractConfirmationDialog(
          context,
          title: 'Cambios sin guardar',
          content:
              '¿Descartar los ajustes del borrador? Las versiones guardadas se conservarán.',
          confirmText: 'Descartar ajustes',
          tokens: directionAreaTokens,
        ) ==
        true;
  }

  Future<bool> canLeave() async {
    if (_busy) return false;
    final allowed = await _discard();
    if (allowed && mounted) setState(() => _dirty = false);
    return allowed;
  }

  Future<void> _changeWeek(DateTime date) async {
    if (await _discard() && mounted) {
      setState(() => _dirty = false);
      await widget.onWeekChanged(date);
    }
  }

  Future<void> _save({bool generate = false}) async {
    if (!_canSave) return;
    _versionsRequest++;
    try {
      if (generate) {
        _syncProductionReference();
        final fresh = ProgramDemand.fromShipments(
          _week,
          widget.bundle.shipments,
        );
        final generated = generateOperatingProgram(_week, _conditions, fresh);
        setState(() {
          _demands = fresh;
          _lines = generated;
          _dirty = true;
        });
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      final saved = await _repository.saveDraft(
        week: _week,
        expectedVersion: _versions.isEmpty ? 0 : _versions.first.version,
        conditions: _conditions,
        demands: _demands,
        lines: _lines,
      );
      if (!mounted) return;
      setState(() {
        _versions = [saved, ..._versions];
        _select(saved);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se guardó el borrador. $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_loadVersions(silent: true));
      }
    }
  }

  Future<void> _approve({bool execute = false}) async {
    final selected = _selected;
    if (selected == null || _dirty || _busy) return;
    final ok = await showContractConfirmationDialog(
      context,
      title: execute
          ? 'Iniciar ejecución'
          : 'Aprobar programa v${selected.version}',
      content: execute
          ? 'La versión operativa pasará a En ejecución.'
          : 'Esta versión quedará fija como programa operativo de la semana. Los ajustes posteriores se guardarán en un nuevo borrador.',
      confirmText: execute ? 'Iniciar ejecución' : 'Aprobar',
      tokens: directionAreaTokens,
    );
    if (ok != true || !mounted) return;
    _versionsRequest++;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final approved = await _repository.approve(selected.id, execute: execute);
      if (mounted) setState(() => _select(approved));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se cambió el estado del programa. $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_loadVersions(silent: true));
      }
    }
  }

  Future<void> _export() async {
    final program = _selected;
    if (program == null || _dirty || _busy) return;
    setState(() {
      _busy = true;
      _exportFailed = false;
      _exportMessage = 'Generando PDF…';
    });
    try {
      final bytes = await buildOperatingProgramPdf(
        program,
        assetBundle: DefaultAssetBundle.of(context),
        operationalNotes: programPdfShipmentNotes(
          program,
          widget.bundle.shipments,
        ),
      );
      if (!mounted) return;
      setState(() => _exportMessage = 'Elige dónde guardar el PDF.');
      final path = await saveBytesAs(
        bytes: bytes,
        dialogTitle: 'Guardar programa operativo de cartón',
        throwOnPickerError: true,
        suggestedFileName:
            'programa_operativo_carton_${programDate(program.week)}_v${program.version}.pdf',
      );
      if (!mounted) return;
      _showExportResult(
        path == null
            ? 'No se guardó el PDF: no se eligió un archivo de destino.'
            : 'PDF guardado en $path',
      );
    } catch (e) {
      if (mounted) {
        final reason = e is StateError ? e.message : e.toString();
        _showExportResult(
          'No se pudo generar o guardar el PDF. $reason',
          failed: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showExportResult(String message, {bool failed = false}) {
    setState(() {
      _exportMessage = message;
      _exportFailed = failed;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
  }

  void _setCondition(ProgramConditions value) => setState(() {
    _conditions = value;
    _dirty = true;
  });

  void _syncProductionReference() {
    final fresh = ProgramConditions.fromReference(widget.bundle);
    _conditions = _conditions.copyWith(
      history: fresh.history,
      days: [
        for (var d = 0; d < 5; d++)
          ProgramDayCondition(
            working: _conditions.days[d].working,
            dayAvailable: _conditions.days[d].dayAvailable,
            nightAvailable: _conditions.days[d].nightAvailable,
            lossPercent: fresh.days[d].lossPercent,
            machineryNote: fresh.days[d].machineryNote,
          ),
      ],
    );
  }

  void _setQuantity(ProgramLine line, int quantity) => setState(() {
    _lines = [
      for (final item in _lines)
        item.key == line.key
            ? ProgramLine(line.day, line.shift, line.material, quantity)
            : item,
    ];
    _dirty = true;
  });

  Future<void> _move(BuildContext themedContext) async {
    var fromDay = 0, fromShift = 0, toDay = 1, toShift = 0;
    var material = programMaterials.first;
    var quantity = '';
    String? error;
    final moved = await showDialog<List<ProgramLine>>(
      context: themedContext,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          backgroundColor: directionAreaTokens.glassSurface,
          title: const Text(
            'Mover producción',
            style: TextStyle(color: kDirectionSurfaceText),
          ),
          content: SizedBox(
            width: 410,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: material,
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: [
                    for (var i = 0; i < 3; i++)
                      DropdownMenuItem(
                        value: programMaterials[i],
                        child: Text(programMaterialNames[i]),
                      ),
                  ],
                  onChanged: (v) => update(() => material = v!),
                ),
                for (final source in [true, false]) ...[
                  DropdownButtonFormField<int>(
                    initialValue: source ? fromDay : toDay,
                    decoration: InputDecoration(
                      labelText: source ? 'Día de origen' : 'Día de destino',
                    ),
                    items: [
                      for (var d = 0; d < 5; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text(programDayNames[d]),
                        ),
                    ],
                    onChanged: (v) => update(() {
                      if (source) {
                        fromDay = v!;
                      } else {
                        toDay = v!;
                      }
                    }),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: source ? fromShift : toShift,
                    decoration: InputDecoration(
                      labelText: source
                          ? 'Turno de origen'
                          : 'Turno de destino',
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Día')),
                      DropdownMenuItem(value: 1, child: Text('Noche')),
                    ],
                    onChanged: (v) => update(() {
                      if (source) {
                        fromShift = v!;
                      } else {
                        toShift = v!;
                      }
                    }),
                  ),
                ],
                // Let the field own its controller through the route's exit
                // animation, which outlives the showDialog future.
                TextFormField(
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => quantity = value,
                  decoration: const InputDecoration(labelText: 'Pacas a mover'),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: kDirectionDanger)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  Navigator.pop(
                    context,
                    moveProgramProduction(
                      _lines,
                      fromDay: fromDay,
                      fromShift: fromShift,
                      toDay: toDay,
                      toShift: toShift,
                      material: material,
                      quantity: int.tryParse(quantity) ?? 0,
                    ),
                  );
                } catch (_) {
                  update(
                    () => error = 'Revisa la cantidad disponible en el origen.',
                  );
                }
              },
              child: const Text('Mover'),
            ),
          ],
        ),
      ),
    );
    if (moved != null && mounted) {
      setState(() {
        _lines = moved;
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: kDirectionOliveGlow,
              brightness: Brightness.dark,
            ).copyWith(
              primary: kDirectionOliveGlow,
              onPrimary: kDirectionBg,
              surface: kDirectionInteractiveSurface,
              onSurface: kDirectionSurfaceText,
            ),
      ),
      child: Builder(builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
    final evaluation = _evaluation;
    final outOfScope = widget.bundle.shipments
        .where(
          (s) =>
              !s.isCancelled &&
              (!programMaterials.contains(s.materialCode) ||
                  s.quantityUnit != DirectionShipmentQuantityUnit.bales ||
                  s.shipDate.isAfter(_week.add(const Duration(days: 4)))),
        )
        .length;
    final unconfirmed = widget.bundle.shipments
        .where(
          (s) =>
              s.isActive &&
              s.status != 'confirmado' &&
              programMaterials.contains(s.materialCode) &&
              !s.shipDate.isAfter(_week.add(const Duration(days: 4))),
        )
        .length;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _discard() && mounted) {
          setState(() => _dirty = false);
          if (context.mounted) Navigator.of(context).pop(result);
        }
      },
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: kDirectionSurfaceText,
          fontSize: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DirectionGlassPanel(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Programa operativo de cartón\n${programDate(_week)} al ${programDate(_week.add(const Duration(days: 4)))}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${_selected?.statusLabel ?? 'Borrador'}${_dirty ? ' · Sin guardar' : ''}',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Semana anterior del programa',
                      onPressed: _busy
                          ? null
                          : () => _changeWeek(
                              _week.subtract(const Duration(days: 7)),
                            ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _changeWeek(
                              DirectionShipmentsStore.currentWeekStartDate(),
                            ),
                      child: const Text('Semana actual'),
                    ),
                    IconButton(
                      tooltip: 'Semana siguiente del programa',
                      onPressed:
                          !_busy &&
                              _week.isBefore(
                                DirectionShipmentsStore.currentWeekStartDate(),
                              )
                          ? () =>
                                _changeWeek(_week.add(const Duration(days: 7)))
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    if (_versions.isNotEmpty)
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_selected?.id),
                          initialValue: _selected?.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Historial de versiones',
                          ),
                          items: [
                            for (final v in _versions)
                              DropdownMenuItem(
                                value: v.id,
                                child: Text(
                                  'v${v.version} · ${v.statusLabel}${v.operational ? ' · Vigente' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (id) async {
                                  if (id != null &&
                                      await _discard() &&
                                      mounted) {
                                    setState(
                                      () => _select(
                                        _versions.firstWhere((v) => v.id == id),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null) _notice(_error!, danger: true),
              if (_sourcesChanged)
                _notice(
                  'Los embarques confirmados cambiaron. Crea un nuevo borrador o vuelve a generar antes de aprobar.',
                ),
              if (outOfScope > 0 || unconfirmed > 0)
                _notice(
                  '$unconfirmed embarques sin confirmar y $outOfScope registros de sábado, otros materiales o kg siguen en Embarques y no forman parte de este programa.',
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric(
                    'Embarques confirmados',
                    _materialTotals(
                      (m) => _demands
                          .where((d) => d.material == m)
                          .fold(0, (a, b) => a + b.quantity),
                    ),
                  ),
                  _metric(
                    'Patio inicial',
                    _materialTotals((m) => _conditions.yard[m] ?? 0),
                  ),
                  _metric(
                    'Producción requerida',
                    '${evaluation.requiredTotal} pacas\n${_materialTotals((m) => evaluation.requiredByMaterial[m] ?? 0)}',
                  ),
                  _metric(
                    'Programado / disponible',
                    '${programQuantity(_lines)} / ${_conditions.totalAvailable} pacas',
                  ),
                  _metric(
                    'Faltantes / validaciones',
                    '${evaluation.missingTotal} pacas · ${evaluation.violations.length} validaciones\n'
                        '${evaluation.historicalWarnings.length} avisos del histórico',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _historyReference(),
              const SizedBox(height: 12),
              DirectionGlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Condiciones de la semana',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _conditionNumber(
                          'Capacidad máxima diaria',
                          _conditions.dailyCapacity,
                          1,
                          10000,
                          (v) => _setCondition(
                            _conditions.copyWith(dailyCapacity: v),
                          ),
                        ),
                        _conditionNumber(
                          'Capacidad turno día (%)',
                          _conditions.dayShare,
                          0,
                          100,
                          (v) =>
                              _setCondition(_conditions.copyWith(dayShare: v)),
                          revision: _dayShareRevision,
                        ),
                        for (var i = 0; i < 3; i++)
                          _conditionNumber(
                            'Patio ${programMaterialNames[i]}',
                            _conditions.yard[programMaterials[i]] ?? 0,
                            0,
                            1000000,
                            (v) => _setCondition(
                              _conditions.copyWith(
                                yard: {
                                  ..._conditions.yard,
                                  programMaterials[i]: v,
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Confirmo el patio inicial del lunes por material',
                        style: TextStyle(
                          color: kDirectionSurfaceText,
                          fontSize: 12,
                        ),
                      ),
                      value: _yardConfirmed,
                      onChanged: _editable
                          ? (v) => setState(() {
                              _yardConfirmed = v!;
                              _dirty = true;
                            })
                          : null,
                    ),
                    const Text(
                      'Día/Noche parte del historial y se puede ajustar. Bloquear un turno reduce capacidad; no la transfiere al otro. Maquinaria: participación nominal C1 50% y C2 50%.',
                      style: TextStyle(color: kDirectionMutedText),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var d = 0; d < 5; d++)
                          SizedBox(width: 235, child: _dayCondition(d)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('generate-operating-program'),
                    onPressed: _canSave ? () => _save(generate: true) : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generar programa semanal'),
                  ),
                  OutlinedButton(
                    onPressed: _canSave && _dirty ? () => _save() : null,
                    child: const Text('Guardar nueva versión'),
                  ),
                  OutlinedButton(
                    onPressed: _editable ? () => _move(context) : null,
                    child: const Text('Mover producción'),
                  ),
                  if (_selected != null)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _selected = null;
                              _dirty = true;
                              _demands = ProgramDemand.fromShipments(
                                _week,
                                widget.bundle.shipments,
                              );
                              final fresh = ProgramConditions.fromReference(
                                widget.bundle,
                              );
                              _conditions = _conditions.copyWith(
                                history: fresh.history,
                                days: [
                                  for (var d = 0; d < 5; d++)
                                    ProgramDayCondition(
                                      working: _conditions.days[d].working,
                                      dayAvailable:
                                          _conditions.days[d].dayAvailable,
                                      nightAvailable:
                                          _conditions.days[d].nightAvailable,
                                      lossPercent: fresh.days[d].lossPercent,
                                      machineryNote:
                                          fresh.days[d].machineryNote,
                                    ),
                                ],
                              );
                            }),
                      child: const Text('Crear nuevo borrador'),
                    ),
                  FilledButton(
                    onPressed:
                        !_busy &&
                            !_dirty &&
                            !_sourcesChanged &&
                            _selected?.status == 'draft' &&
                            evaluation.valid &&
                            _demands.isNotEmpty
                        ? () => _approve()
                        : null,
                    child: const Text('Aprobar programa'),
                  ),
                  if (_selected?.status == 'approved' && _selected!.operational)
                    FilledButton(
                      onPressed: _busy ? null : () => _approve(execute: true),
                      child: const Text('Iniciar ejecución'),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('export-operating-program'),
                    onPressed: !_busy && !_dirty && _selected != null
                        ? _export
                        : null,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('PDF para operador'),
                  ),
                  if (_busy)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_exportMessage != null)
                _notice(_exportMessage!, danger: _exportFailed),
              _schedule(evaluation),
              if (evaluation.historicalWarnings.isNotEmpty)
                _notice(evaluation.historicalWarnings.join('\n')),
              if (!evaluation.valid)
                _notice(
                  [
                    ...evaluation.shortfalls.map(
                      (s) =>
                          '${programDate(s.shipment.date)} · ${s.shipment.destination} · ${directionShipmentMaterialLabel(s.shipment.material)}: faltan ${s.quantity} pacas. ${s.causes.join('; ')}.',
                    ),
                    ...evaluation.violations,
                  ].join('\n'),
                  danger: true,
                ),
              const SizedBox(height: 12),
              _actualComparison(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(String text, {bool danger = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(
        color: danger ? kDirectionDanger : kDirectionWarning,
        height: 1.4,
      ),
    ),
  );

  Widget _historyReference() {
    final history = _conditions.history;
    return DirectionGlassPanel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'Histórico de Producción · ${history?.observedWeeks.length ?? 0}/6 semanas',
        ),
        subtitle: Text(
          history == null
              ? 'Esta versión no tiene referencia guardada. Genera un nuevo borrador para vincularla.'
              : '${programDate(history.start)} al ${programDate(history.end)} · ${history.recordCount} registros de lunes a viernes',
        ),
        children: [
          if (history?.hasData == true) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Promedio de ${history!.observedWeeks.length} semanas con registros: '
                '${history.average().toStringAsFixed(1)} pacas/semana · '
                '${(history.average() / 5).toStringAsFixed(1)} pacas/día.\n'
                'El reparto sigue el ritmo de cada día y los turnos habituales de cada material. '
                'Los embarques, el patio y la capacidad configurada determinan cuánto se programa.\n'
                '${history.recordCount - history.legacyRecordCount} registros de Producción actual y '
                '${history.legacyRecordCount} del histórico anterior, sin sumar ambas fuentes en una misma semana.',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _editable
                    ? () => setState(() {
                        _conditions = _conditions.copyWith(
                          dayShare: history.dayShare,
                        );
                        _dayShareRevision++;
                        _invalidFields.remove('Capacidad turno día (%)');
                        _dirty = true;
                      })
                    : null,
                child: Text(
                  'Aplicar proporción histórica: ${history.dayShare}% Día / ${100 - history.dayShare}% Noche',
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                  color: kDirectionOliveGlow,
                  fontWeight: FontWeight.w700,
                ),
                columns: [
                  const DataColumn(label: Text('Promedio en pacas')),
                  for (final m in programMaterialNames)
                    for (final s in ['Día', 'Noche'])
                      DataColumn(label: Text('$m\n$s'), numeric: true),
                  const DataColumn(label: Text('Total'), numeric: true),
                ],
                rows: [
                  for (var d = 0; d < 5; d++)
                    DataRow(
                      cells: [
                        DataCell(Text(programDayNames[d])),
                        for (final m in programMaterials)
                          for (var s = 0; s < 2; s++)
                            DataCell(
                              Text(
                                history
                                    .average(day: d, shift: s, material: m)
                                    .toStringAsFixed(1),
                              ),
                            ),
                        DataCell(
                          Text(history.average(day: d).toStringAsFixed(1)),
                        ),
                      ],
                    ),
                  DataRow(
                    cells: [
                      const DataCell(Text('Semana')),
                      for (final m in programMaterials)
                        for (var s = 0; s < 2; s++)
                          DataCell(
                            Text(
                              history
                                  .average(shift: s, material: m)
                                  .toStringAsFixed(1),
                            ),
                          ),
                      DataCell(Text(history.average().toStringAsFixed(1))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Los días sin producción registrada dentro de una semana observada cuentan como cero. '
              'Las semanas completas sin registros se excluyen del promedio. '
              'La referencia queda guardada con cada versión; Generar programa semanal toma el histórico actualizado.',
            ),
          ] else
            const Text(
              'No hay observaciones suficientes de los tres materiales. '
              'El programa puede calcularse con la capacidad configurada, mostrando que carece de respaldo histórico.',
            ),
        ],
      ),
    );
  }

  String _materialTotals(int Function(String) value) => [
    for (var i = 0; i < 3; i++)
      '${programMaterialNames[i]} ${value(programMaterials[i])}',
  ].join(' · ');
  Widget _metric(String title, String value) => SizedBox(
    width: 244,
    child: DirectionGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kDirectionOliveGlow,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(height: 1.5)),
        ],
      ),
    ),
  );
  Widget _conditionNumber(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    int revision = 0,
  }) => SizedBox(
    width: 205,
    child: TextFormField(
      key: ValueKey('$label:${_selected?.id}:$revision'),
      initialValue: '$value',
      enabled: _editable,
      style: const TextStyle(color: kDirectionSurfaceText),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (text) {
        final v = int.tryParse(text ?? '');
        return v == null || v < min || v > max ? '$min a $max' : null;
      },
      onChanged: (text) {
        final v = int.tryParse(text);
        setState(() {
          _dirty = true;
          if (v == null || v < min || v > max) {
            _invalidFields.add(label);
          } else {
            _invalidFields.remove(label);
          }
        });
        if (v != null && v >= min && v <= max) onChanged(v);
      },
    ),
  );
  Widget _dayCondition(int day) {
    final c = _conditions.days[day];
    void setDay(ProgramDayCondition value) => _setCondition(
      _conditions.copyWith(days: [..._conditions.days]..[day] = value),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (c.working ? kDirectionOliveGlow : kDirectionWarning).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDirectionOliveMist.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${programDayNames[day]} · ${_conditions.available(day)} pacas',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final (label, checked, action)
              in <(String, bool, ValueChanged<bool>)>[
                ('Laborable', c.working, (v) => setDay(c.copyWith(working: v))),
                (
                  'Turno día',
                  c.dayAvailable,
                  (v) => setDay(c.copyWith(dayAvailable: v)),
                ),
                (
                  'Turno noche',
                  c.nightAvailable,
                  (v) => setDay(c.copyWith(nightAvailable: v)),
                ),
              ])
            Row(
              children: [
                Checkbox(
                  value: checked,
                  onChanged: _editable ? (v) => action(v!) : null,
                ),
                Text(label),
              ],
            ),
          if (c.lossPercent > 0)
            Text(
              '${c.machineryNote}\nPérdida total: ${c.lossPercent}%',
              style: const TextStyle(color: kDirectionWarning),
            ),
        ],
      ),
    );
  }

  static const _widths = [
    86.0,
    240.0,
    125.0,
    72.0,
    72.0,
    72.0,
    72.0,
    72.0,
    72.0,
    70.0,
    115.0,
  ];
  Widget _gridRow(List<Widget> cells, {bool header = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < cells.length; i++)
        Container(
          width: _widths[i],
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: kDirectionOliveMist.withValues(alpha: 0.14),
              ),
            ),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              color: header ? kDirectionOliveGlow : kDirectionSurfaceText,
              fontSize: 11,
              fontWeight: header ? FontWeight.w800 : FontWeight.w500,
            ),
            child: cells[i],
          ),
        ),
    ],
  );
  Widget _schedule(ProgramEvaluation evaluation) => DirectionGlassPanel(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _widths.reduce((a, b) => a + b),
        child: Column(
          children: [
            _gridRow([
              for (final text in [
                'Día',
                'Embarques y destinos',
                'Patio aplicado',
                'Nacional\nDía',
                'Nacional\nNoche',
                'Limpio\nDía',
                'Limpio\nNoche',
                'Americano\nDía',
                'Americano\nNoche',
                'Total día',
                'Estado',
              ])
                Text(text),
            ], header: true),
            for (var d = 0; d < 5; d++) ...[
              Container(
                color: !_conditions.days[d].working
                    ? kDirectionWarning.withValues(alpha: 0.08)
                    : null,
                child: _gridRow([
                  Text(
                    '${programDayNames[d]}\n${programDate(_week.add(Duration(days: d))).substring(5)}${!_conditions.days[d].working ? '\nNo laborable' : ''}',
                  ),
                  Text(
                    _demands
                            .where((s) => s.date.difference(_week).inDays == d)
                            .map(
                              (s) =>
                                  '${s.destination}: ${s.quantity} ${programMaterialNames[programMaterials.indexOf(s.material)]}',
                            )
                            .join('\n')
                            .isEmpty
                        ? 'Sin embarques confirmados'
                        : _demands
                              .where(
                                (s) => s.date.difference(_week).inDays == d,
                              )
                              .map(
                                (s) =>
                                    '${s.destination}: ${s.quantity} ${programMaterialNames[programMaterials.indexOf(s.material)]}',
                              )
                              .join('\n'),
                  ),
                  Text(
                    _materialTotals((m) => evaluation.yardApplied[d][m] ?? 0),
                  ),
                  for (final m in programMaterials)
                    for (var s = 0; s < 2; s++)
                      _ProgramQuantityCell(
                        key: ValueKey('${_selected?.id}:$d:$s:$m'),
                        label: '${programDayNames[d]} $m ${programShifts[s]}',
                        value: programQuantity(
                          _lines,
                          day: d,
                          shift: s,
                          material: m,
                        ),
                        blocked: _conditions.slotCapacity(d, s) == 0,
                        enabled: _editable,
                        onChanged: (v) =>
                            _setQuantity(ProgramLine(d, s, m, v), v),
                      ),
                  Text(
                    '${programQuantity(_lines, day: d)} / ${_conditions.available(d)}',
                  ),
                  Text(
                    evaluation.shortfalls.any(
                          (s) => s.shipment.date.difference(_week).inDays == d,
                        )
                        ? 'Faltante'
                        : (programQuantity(_lines, day: d) >
                                  _conditions.available(d) ||
                              [0, 1].any(
                                (s) =>
                                    programQuantity(_lines, day: d, shift: s) >
                                    _conditions.slotCapacity(d, s),
                              ))
                        ? 'Revisar capacidad'
                        : 'Cubierto',
                  ),
                ]),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: kDirectionOliveMist.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Text(
                  'Saldo al cierre · ${_materialTotals((m) => evaluation.closingBalances[d][m] ?? 0)}',
                  style: const TextStyle(
                    color: kDirectionMutedText,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            _gridRow([
              const Text('TOTAL'),
              Text('${_demands.fold<int>(0, (a, b) => a + b.quantity)} pacas'),
              Text(
                '${evaluation.yardApplied.fold<int>(0, (a, b) => a + b.values.fold<int>(0, (c, d) => c + d))} pacas',
              ),
              for (final m in programMaterials)
                for (var s = 0; s < 2; s++)
                  Text('${programQuantity(_lines, shift: s, material: m)}'),
              Text('${programQuantity(_lines)}'),
              Text(evaluation.valid ? 'Validado' : 'Revisar'),
            ], header: true),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Semana · ${_materialTotals((m) => programQuantity(_lines, material: m))} · Día ${programQuantity(_lines, shift: 0)} · Noche ${programQuantity(_lines, shift: 1)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _actualComparison() => DirectionGlassPanel(
    child: ExpansionTile(
      title: const Text(
        'Producción real vs programada',
        style: TextStyle(color: kDirectionSurfaceText),
      ),
      subtitle: Text(
        _selected == null
            ? 'Guarda una versión para conservar la referencia.'
            : 'Referencia: v${_selected!.version} · ${_selected!.statusLabel}',
        style: const TextStyle(color: kDirectionMutedText),
      ),
      children: [
        if (_actualError != null)
          _notice(_actualError!, danger: true)
        else if (_actual == null)
          const LinearProgressIndicator()
        else ...[
          const Text(
            'Día / turno / material · Programado / Real / Diferencia',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final line in _lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${programDayNames[line.day]} · ${line.shift == 0 ? 'Día' : 'Noche'} · ${programMaterialNames[programMaterials.indexOf(line.material)]} · '
                '${line.quantity} / ${programQuantity(_actual!, day: line.day, shift: line.shift, material: line.material)} / '
                '${programQuantity(_actual!, day: line.day, shift: line.shift, material: line.material) - line.quantity}',
              ),
            ),
        ],
      ],
    ),
  );
}

class _ProgramQuantityCell extends StatefulWidget {
  final int value;
  final bool enabled, blocked;
  final String label;
  final ValueChanged<int> onChanged;
  const _ProgramQuantityCell({
    super.key,
    required this.value,
    required this.enabled,
    required this.blocked,
    required this.label,
    required this.onChanged,
  });
  @override
  State<_ProgramQuantityCell> createState() => _ProgramQuantityCellState();
}

class _ProgramQuantityCellState extends State<_ProgramQuantityCell> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _editing = false, _hovering = false;
  int _before = 0;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _controller.addListener(() {
      if (_editing) widget.onChanged(int.tryParse(_controller.text) ?? 0);
    });
  }

  @override
  void didUpdateWidget(covariant _ProgramQuantityCell old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _cancel() {
    if (!_editing) return;
    setState(() => _editing = false);
    _controller.text = '$_before';
    widget.onChanged(_before);
    _focus.unfocus();
  }

  void _commit() {
    setState(() => _editing = false);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: Tooltip(
      message: widget.blocked
          ? 'Turno bloqueado. Retira o mueve cualquier cantidad existente.'
          : 'Enter confirma la celda; Esc o clic afuera cancela.',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape &&
                _editing) {
              _cancel();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: widget.blocked
                  ? kDirectionWarning.withValues(alpha: 0.14)
                  : _hovering && widget.enabled
                  ? kDirectionOliveGlow.withValues(alpha: 0.22)
                  : kDirectionOliveGlow.withValues(alpha: 0.06),
            ),
            child: InlineEditableNumberCell(
              editing: _editing,
              enabled: widget.enabled,
              controller: _controller,
              focusNode: _focus,
              displayText: widget.blocked && widget.value == 0
                  ? '—'
                  : '${widget.value}',
              allowDecimal: false,
              onEnterEditMode: () {
                if (_editing) return;
                _before = widget.value;
                setState(() => _editing = true);
              },
              onCancel: _cancel,
              onSave: _commit,
            ),
          ),
        ),
      ),
    ),
  );
}
