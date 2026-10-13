import 'package:flutter/material.dart';

import '../../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../../shared/utils/file_download_save.dart';
import '../direction_shipments_store.dart';
import '../direction_theme.dart';
import '../expected_income/expected_income_forms.dart';
import '../operating_program/operating_program_models.dart';
import 'direction_execution_repository.dart';
import 'shipment_comparison_pdf.dart';
import 'shipment_comparison_report.dart';

/// Hybrid tab, following Dirección's existing cards and shared capture dialogs.
/// Operation is a live prefill; only an explicit confirmation becomes a correction.
class DirectionExecutionView extends StatefulWidget {
  final String kind;
  final DirectionShipmentPlanningBundle bundle;
  final OperatingProgram? program;
  final DirectionExecutionRepository? repository;
  final Future<void> Function() onChanged;
  final Future<void> Function(DateTime) onWeekChanged;
  final ValueChanged<bool>? onBusyChanged;
  final DateTime? asOf;
  final Future<DirectionShipmentPlanningBundle> Function()? refreshReference;
  const DirectionExecutionView({
    super.key,
    required this.kind,
    required this.bundle,
    required this.onChanged,
    required this.onWeekChanged,
    this.program,
    this.repository,
    this.onBusyChanged,
    this.asOf,
    this.refreshReference,
  });
  @override
  State<DirectionExecutionView> createState() => _DirectionExecutionViewState();
}

class _DirectionExecutionViewState extends State<DirectionExecutionView> {
  late final _repository = widget.repository ?? DirectionExecutionRepository();
  final Map<String, DirectionExecutionActual> _saved = {};
  bool _busy = false;
  String? _message;
  bool get _production => widget.kind == 'production';
  DateTime get _today {
    final d = widget.asOf ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  DateTime get _week => widget.bundle.weekStartDate;
  List<DirectionExecutionRow> get _rows => _rowsFor(widget.bundle);
  List<DirectionExecutionRow> _rowsFor(DirectionShipmentPlanningBundle bundle) {
    final confirmations = {for (final a in bundle.executionActuals) a.key: a};
    for (final a in _saved.values) {
      if (a.revision >= (confirmations[a.key]?.revision ?? 0)) {
        confirmations[a.key] = a;
      }
    }
    return buildDirectionExecutionRows(
      kind: widget.kind,
      week: bundle.weekStartDate,
      shipments: bundle.shipments,
      movements: bundle.shipmentMovements,
      production: bundle.productionActuals,
      confirmations: confirmations.values.toList(),
      plannedProduction: {
        for (final l in widget.program?.lines ?? <ProgramLine>[])
          directionExecutionKey(
            'production',
            _week.add(Duration(days: l.day)),
            l.material,
            '',
            l.shift == 0 ? 'DAY' : 'NIGHT',
          ): l.quantity,
      },
    );
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
    widget.onBusyChanged?.call(value);
  }

  Future<void> _exportComparison() async {
    if (_busy || _production) return;
    final week = _week;
    final assets = DefaultAssetBundle.of(context);
    _setBusy(true);
    setState(() => _message = 'Generando PDF…');
    try {
      final bundle = await widget.refreshReference?.call() ?? widget.bundle;
      if (!mounted) return;
      if (bundle.weekStartDate != week || _week != week) {
        throw StateError(
          'La semana cambió durante la lectura. Vuelve a generar el PDF.',
        );
      }
      final report = ShipmentComparisonReport(
        week: week,
        generatedAt: widget.asOf ?? DateTime.now(),
        rows: _rowsFor(bundle),
      );
      final bytes = await buildShipmentComparisonPdf(
        report,
        assetBundle: assets,
      );
      if (!mounted) return;
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName: report.fileName,
        dialogTitle: 'Guardar comparativo de embarques',
        throwOnPickerError: true,
      );
      if (mounted) {
        setState(
          () => _message = path == null
              ? 'PDF no guardado: no se eligió un archivo de destino.'
              : 'PDF guardado en $path',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'No se pudo generar o guardar el PDF. $e');
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _refreshAfterSave() async {
    try {
      await widget.onChanged();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Resultado guardado. La referencia se actualizará con la siguiente lectura automática.',
        );
      }
    }
  }

  Future<void> _edit(DirectionExecutionRow row) async {
    if (_busy || row.date.isAfter(_today)) return;
    final unit = directionShipmentMaterialByCode(row.material)?.isBulk == true
        ? 'kg'
        : 'pacas';
    final loads = row.confirmed ? row.confirmation!.loads : row.observedLoads;
    final effect = _production
        ? 'Se conserva lo planeado. Usa 0 solamente para confirmar que no hubo actividad.'
        : 'Al guardar, la agenda se actualiza con las cargas reales como embarcadas. Las previstas que no se realizaron quedan canceladas; 0 cancela las de este día, destino y material. Se conserva la referencia original.';
    _setBusy(true);
    try {
      final result = await showIncomeForm(
        context,
        title: row.confirmed
            ? 'Corregir resultado real'
            : 'Confirmar resultado real',
        description:
            '${_dateLabel(row.date)} · ${directionShipmentMaterialLabel(row.material)} · ${_production ? _shiftLabel(row.shift) : row.client}\n'
            'Planeado: ${row.baseline ?? 'sin referencia'} · Registrado: ${row.observed ?? 'sin captura'}. $effect',
        fields: [
          if (_production)
            IncomeFormField(
              'quantity',
              'Producción real (pacas)',
              row.actual,
              numeric: true,
              integer: true,
              max: 10000000,
            )
          else
            IncomeFormField(
              'loads',
              '$unit por embarque (separa con comas)',
              row.actual == null
                  ? ''
                  : loads.isEmpty
                  ? '${row.actual}'
                  : loads.join(', '),
            ),
          IncomeFormField(
            'notes',
            'Motivo o comentario',
            row.confirmation?.notes ?? '',
            optional: true,
          ),
        ],
        onSave: (v) async {
          final amounts = _production
              ? <int>[]
              : parseDirectionActualLoads(v['loads'] as String);
          final quantity = _production
              ? (v['quantity'] as num).toInt()
              : amounts.fold<int>(0, (a, b) => a + b);
          final actual = await _repository.save(
            row: row,
            quantity: quantity,
            loads: amounts,
            notes: v['notes'] as String,
            programId: widget.program?.id,
          );
          _saved[actual.key] = actual;
        },
      );
      if (result == true) await _refreshAfterSave();
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _clear(DirectionExecutionRow row) async {
    if (_busy) return;
    _setBusy(true);
    try {
      final accepted = await showContractConfirmationDialog(
        context,
        title: 'Usar dato de Operación',
        content: _production
            ? 'Este resultado volverá a tomar el registro de Operación. Se conserva el historial de correcciones y la referencia planeada.'
            : 'Se restaura la agenda anterior a esta confirmación; las cargas agregadas desde Real quedan canceladas. El resultado vuelve a tomar Operación. Se conserva el historial.',
        confirmText: 'Restablecer',
        tokens: directionAreaTokens,
      );
      if (accepted != true) return;
      final a = row.confirmation!;
      final saved = await _repository.save(
        row: row,
        quantity: a.quantity,
        loads: a.loads,
        notes: a.notes,
        clear: true,
      );
      _saved[saved.key] = saved;
      await _refreshAfterSave();
    } catch (e) {
      if (mounted) setState(() => _message = 'No se pudo restablecer. $e');
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _addShipment() async {
    if (_busy) return;
    final dates = {
      for (var d = 0; d < 6; d++)
        if (!_week.add(Duration(days: d)).isAfter(_today))
          programDate(_week.add(Duration(days: d))): _dateLabel(
            _week.add(Duration(days: d)),
          ),
    };
    if (dates.isEmpty) return;
    _setBusy(true);
    try {
      final result = await showIncomeForm(
        context,
        title: 'Registrar embarque real',
        description:
            'Registra una salida que aún no aparece en Operación. Se agregará a la agenda como embarcada. Si ya existe el mismo día, destino y material, corrige su renglón en Real.',
        fields: [
          IncomeFormField('date', 'Fecha', dates.keys.last, options: dates),
          const IncomeFormField('client', 'Destino', ''),
          IncomeFormField(
            'material',
            'Material',
            'PACA_NACIONAL',
            options: {
              for (final m in kDirectionShipmentMaterials) m.code: m.label,
            },
          ),
          const IncomeFormField(
            'loads',
            'Cantidad por embarque (pacas o kg del material)',
            '',
          ),
          const IncomeFormField(
            'notes',
            'Motivo o comentario',
            '',
            optional: true,
          ),
        ],
        onSave: (v) async {
          final row = DirectionExecutionRow(
            kind: 'shipment',
            date: DateTime.parse(v['date'] as String),
            material: v['material'] as String,
            client: directionExecutionClient(v['client'] as String),
          );
          if (row.client.isEmpty) {
            throw const FormatException('Captura el destino.');
          }
          if (_rows.any((r) => r.key == row.key)) {
            throw const FormatException(
              'El renglón ya existe. Confírmalo o corrígelo desde la lista.',
            );
          }
          final loads = parseDirectionActualLoads(v['loads'] as String);
          final a = await _repository.save(
            row: row,
            quantity: loads.fold(0, (a, b) => a + b),
            loads: loads,
            notes: v['notes'] as String,
          );
          _saved[a.key] = a;
        },
      );
      if (result == true) await _refreshAfterSave();
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final eligible = rows.where((r) => !r.date.isAfter(_today));
    return incomeThemed(
      context,
      DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: kDirectionSurfaceText),
        child: ListView(
          key: PageStorageKey('execution-${widget.kind}-${programDate(_week)}'),
          padding: const EdgeInsets.only(bottom: 18),
          children: [
            DirectionToolbarPanel(
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _production ? 'PRODUCCIÓN REAL' : 'EMBARQUES REALES',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Semana anterior',
                    onPressed: _busy
                        ? null
                        : () => widget.onWeekChanged(
                            _week.subtract(const Duration(days: 7)),
                          ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${programDate(_week)} – ${programDate(_week.add(Duration(days: _production ? 4 : 5)))}',
                  ),
                  IconButton(
                    tooltip: 'Semana siguiente',
                    onPressed: _busy
                        ? null
                        : () => widget.onWeekChanged(
                            _week.add(const Duration(days: 7)),
                          ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  if (!_production)
                    OutlinedButton.icon(
                      key: const ValueKey('export-shipment-comparison'),
                      onPressed: _busy ? null : _exportComparison,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF planeado vs real'),
                    ),
                  if (!_production)
                    OutlinedButton.icon(
                      onPressed: _busy || _week.isAfter(_today)
                          ? null
                          : _addShipment,
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar embarque real'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DirectionGlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${eligible.where((r) => r.confirmed).length} confirmados · ${eligible.where((r) => !r.confirmed && r.observed != null).length} por confirmar · ${eligible.where((r) => r.actual == null).length} sin captura',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _production
                          ? 'Precargado desde Operación. Confirma o corrige lo producido; se conserva el programa y los resultados ajustan las próximas propuestas.'
                          : 'Al confirmar se actualiza Planeado: las cargas reales quedan embarcadas, las no realizadas canceladas y las adicionales se agregan. La referencia original queda guardada para comparar.',
                    ),
                    if (_production)
                      Text(
                        widget.program == null
                            ? 'Sin programa guardado: puedes registrar lo real; la comparación quedará sin referencia.'
                            : 'Referencia para nuevas confirmaciones: programa v${widget.program!.version} · ${widget.program!.statusLabel}. Cada confirmación conserva su referencia original.',
                      ),
                    if (_production)
                      const Text(
                        'Para estimar nuevos ritmos se usan días terminados. La producción del día sigue tomando los registros de Operación.',
                      ),
                  ],
                ),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _message!,
                  style: const TextStyle(color: kDirectionWarning),
                ),
              ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay embarques planeados ni realizados en esta semana.',
                ),
              ),
            for (final row in rows) _card(row),
          ],
        ),
      ),
    );
  }

  Widget _card(DirectionExecutionRow row) {
    final unit = directionShipmentMaterialByCode(row.material)?.isBulk == true
        ? 'kg'
        : 'pacas';
    final future = row.date.isAfter(_today);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DirectionGlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_dateLabel(row.date)} · ${_production
                        ? _shiftLabel(row.shift)
                        : row.client.isEmpty
                        ? 'Sin destino'
                        : row.client} · ${directionShipmentMaterialLabel(row.material)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    future
                        ? 'Pendiente de ejecución'
                        : row.confirmed
                        ? 'Confirmado · revisión ${row.confirmation!.revision}'
                        : row.observed == null
                        ? 'Sin captura'
                        : 'Por confirmar',
                    style: TextStyle(
                      color: row.confirmed
                          ? kDirectionSuccess
                          : kDirectionMutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  Text('Planeado: ${row.baseline ?? '—'} $unit'),
                  Text('Registrado: ${row.observed ?? '—'} $unit'),
                  Text(
                    'Real: ${row.actual ?? '—'} $unit',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Diferencia: ${row.difference == null
                        ? '—'
                        : row.difference! > 0
                        ? '+${row.difference}'
                        : '${row.difference}'} $unit',
                  ),
                ],
              ),
              if (!_production && row.confirmed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    row.confirmation!.agendaSynced
                        ? row.actual == 0
                              ? 'Agenda actualizada · embarques cancelados'
                              : 'Agenda actualizada · ${row.confirmation!.loads.length} cargas embarcadas'
                        : 'Agenda pendiente de actualizar. Revisa y vuelve a confirmar este resultado.',
                    style: TextStyle(
                      color: row.confirmation!.agendaSynced
                          ? kDirectionSuccess
                          : kDirectionWarning,
                    ),
                  ),
                ),
              if (row.sourceChanged)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'El registro de origen cambió después de confirmar. Revisa la diferencia antes de volver a confirmar.',
                    style: TextStyle(color: kDirectionWarning),
                  ),
                ),
              if (row.confirmed && row.confirmation!.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(row.confirmation!.notes),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('edit-${row.key}'),
                    onPressed:
                        _busy || future || (!_production && row.client.isEmpty)
                        ? null
                        : () => _edit(row),
                    icon: Icon(
                      row.confirmed ? Icons.edit_outlined : Icons.check,
                    ),
                    label: Text(
                      row.confirmed
                          ? !_production && !row.confirmation!.agendaSynced
                                ? 'Actualizar agenda'
                                : 'Corregir'
                          : row.observed == null
                          ? 'Capturar real'
                          : 'Confirmar o corregir',
                    ),
                  ),
                  if (row.confirmed)
                    TextButton(
                      onPressed: _busy ? null : () => _clear(row),
                      child: const Text('Usar dato de Operación'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shiftLabel(String shift) =>
    shift == 'DAY' ? 'Turno día' : 'Turno noche';
String _dateLabel(DateTime date) =>
    '${const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][date.weekday - 1]} · ${programDate(date)}';

class DirectionExecutionTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int>? onChanged;
  const DirectionExecutionTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Planeado'),
            icon: Icon(Icons.event_note_outlined),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Real'),
            icon: Icon(Icons.fact_check_outlined),
          ),
        ],
        selected: {selected},
        onSelectionChanged: onChanged == null
            ? null
            : (v) => onChanged!(v.single),
      ),
    ),
  );
}
